# INI 数组类型支持实施方案（`[]` 语法）

## 最终方案选择

**采用方案 B：`[]` 数组语法**

### 选择理由

1. **用户体验最佳**：`ports=[80,443,8080]` 比其他方案更简洁直观
2. **支持多行数组**：适合大型数组配置，保持可读性
3. **类型推断友好**：默认自动推断，可选显式标注
4. **符合直觉**：方括号是数组的标准表示法
5. **功能完整**：虽然代码量稍多，但功能更强大

---

## 语法设计

### 基本语法示例

```ini
# 单行数组（自动类型推断）
ports=[80,443,8080]
names=[alice,bob,charlie]
flags=[true,false,true]
rates=[3.14,2.71,1.41]

# 带显式类型标注
count:u8=[1,2,3]
timeout:i32=[100,200,300]

# 多行数组（支持大型数组）
allowed_ips=[
    192.168.1.1,
    10.0.0.1,
    172.16.0.1
]

# 空数组
empty=[]

# Section 中的数组
[database]
replicas=[1,2,3]
shards=[10,20,30,40]
```

### 语法规则

1. **开始标记**：值以 `[` 开头
2. **结束标记**：值以 `]` 结尾
3. **元素分隔**：使用逗号 `,` 分隔
4. **多行支持**：可以跨多行，自动识别 `]` 结束
5. **空元素**：连续逗号产生的空元素被跳过
6. **空格处理**：元素前后空格自动修剪

---

## API 使用指南

### 读取数组值的完整示例

#### 配置文件示例

```ini
# config.ini
ports=[80,443,8080]
names=[alice,bob,charlie]
flags=[true,false,true]

[database]
replicas=[1,2,3]
shards=[10,20,30,40]
```

#### 代码访问方式

**方式 1：通过 Ini 级别通用方法（推荐 - 最简洁）**

```zig
const allocator = std.testing.allocator;
var ini = Ini.init(allocator);
defer ini.deinit();

try ini.loadFromString("config.ini");

// 直接获取数组（支持 section.key 语法）
const ports = try ini.getArray(u16, "ports", allocator);
defer allocator.free(ports);

const names = try ini.getArray([]const u8, "names", allocator);
defer {
    for (names) |name| allocator.free(name);
    allocator.free(names);
}

// Section 中的数组（支持 section.key 语法）
const replicas = try ini.getArray(u8, "database.replicas", allocator);
defer allocator.free(replicas);

const shards = try ini.getArray(i32, "database.shards", allocator);
defer allocator.free(shards);
```

**方式 2：通过 getSchema + Schema 方法**

```zig
// 先获取 Schema，再转换
if (ini.getSchema("ports")) |schema| {
    if (schema.isArray) {
        const ports = try schema.asU16Array(allocator);
        defer allocator.free(ports);

        // 使用数组
        for (ports) |port| {
            std.debug.print("Port: {}\n", .{port});
        }
    }
}
```

**API 对比：**

```zig
// 单值访问（现有 API）
const port = try ini.getU16("port", allocator);
const enabled = try ini.getBool("enabled", allocator);

// 数组访问（新增 API - 保持一致性）
const ports = try ini.getArray(u16, "ports", allocator);
const flags = try ini.getArray(bool, "flags", allocator);
```

**完整使用示例：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.loadFromString("config.ini");

    // 获取全局数组
    const ports = try ini.getU16Array("ports", allocator);
    defer allocator.free(ports);

    std.debug.print("Ports: ", .{});
    for (ports) |port| {
        std.debug.print("{} ", .{port});
    }
    std.debug.print("\n", .{});

    // 获取 Section 中的数组
    const replicas = try ini.getU8Array("database.replicas", allocator);
    defer allocator.free(replicas);

    std.debug.print("Replicas: {any}\n", .{replicas});

    // 检查数组是否存在
    if (ini.has("ports")) {
        std.debug.print("ports 配置存在\n");
    }

    // 遍历所有数组配置
    var array_count: usize = 0;
    ini.forEach(&array_count, struct {
        fn callback(ctx: *usize, section: ?[]const u8, schema: *const Schema) void {
            if (schema.isArray) {
                const mctx = @constCast(ctx);
                mctx.* += 1;

                if (section) |section_name| {
                    std.debug.print("[{s}] {s} 是数组\n", .{section_name, schema.key});
                } else {
                    std.debug.print("{s} 是数组\n", .{schema.key});
                }
            }
        }
    }.callback);

    std.debug.print("总共 {} 个数组配置\n", .{array_count});
}
```

### 内存管理注意事项

**重要：数组访问都需要手动释放内存**

```zig
// ✅ 正确：使用 defer 释放
const ports = try schema.asU16Array(allocator);
defer allocator.free(ports);

// ✅ 正确：字符串数组的双重释放
const names = try schema.asStringArray(allocator);
defer {
    for (names) |name| allocator.free(name);  // 释放每个字符串
    allocator.free(names);                       // 释放数组本身
}

// ❌ 错误：忘记释放会导致内存泄漏
const ports = try schema.asU16Array(allocator);
// 忘记释放 -> 内存泄漏
```

### 类型推断规则

**自动推断类型：**

- `[80,443,8080]` → 推断为 `i64` 数组（可转换为 `u16`）
- `[true,false]` → 推断为 `bool` 数组
- `[3.14,2.71]` → 推断为 `f64` 数组
- `[alice,bob]` → 推断为 `string` 数组

**显式类型标注：**

```ini
count:u8=[1,2,3]        // 显式 u8 数组
timeout:i32=[100,200]   // 显式 i32 数组
rate:f64=[3.14,2.71]     // 显式 f64 数组
```

### 错误处理示例

```zig
// 检查是否为数组
if (ini.getSchema("key")) |schema| {
    if (!schema.isArray) {
        std.debug.print("这不是一个数组\n");
    }
}

// 尝试访问非数组会返回错误
if (ini.getSchema("single_value")) |schema| {
    if (schema.asU16Array(allocator)) |_| {
        // 不会执行到这里
    } else |err| {
        if (err == error.NotAnArray) {
            std.debug.print("错误：这不是一个数组\n");
        }
    }
}

// 类型不匹配错误
if (ini.getSchema("strings")) |schema| {
    // 字符串数组尝试当作整数数组访问
    if (schema.asU16Array(allocator)) |_| {
        // 不会执行
    } else |err| {
        // 会得到类型不匹配或转换错误
        std.debug.print("类型转换错误: {}\n", .{err});
    }
}
```

### 与 forEach 配合使用

```zig
// 遍历所有配置，筛选数组类型
var array_count: usize = 0;

ini.forEach(&.{&array_count}, struct {
    fn callback(ctx: *const struct {*usize}, section: ?[]const u8, schema: *const Schema) void {
        if (schema.isArray) {
            const mctx = @constCast(ctx);
            mctx.*[0].* += 1;

            if (section) |section_name| {
                std.debug.print("[{s}] {s} 是一个数组\n", .{section_name, schema.key});
            } else {
                std.debug.print("{s} 是一个数组\n", .{schema.key});
            }
        }
    }
}.callback);

std.debug.print("总共找到 {} 个数组配置\n", .{array_count});
```

---

## 实施步骤

### 步骤 1: Schema 结构体增强

**文件**：`src/ini.zig` 第34-41行

**修改前**：

```zig
pub const Schema = struct {
    key: []const u8,
    value: []const u8,
    datatype: DataType,
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
};
```

**修改后**：

```zig
pub const Schema = struct {
    key: []const u8,
    value: []const u8,
    datatype: DataType,
    isArray: bool = false,  // 新增：标识是否为数组类型
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
};
```

---

### 步骤 2: 添加数组检测和解析方法

**文件**：`src/ini.zig` Parser 结构体中新增方法

**新增方法**：

```zig
/// 检查值是否以 [ 开头（数组语法）
fn isArrayValue(value: []const u8) bool {
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    return trimmed.len > 0 and trimmed[0] == '[';
}

/// 解析数组值（支持多行）
fn parseArrayValue(self: *Parser, first_line: []const u8) ![]const u8 {
    var buffer = std.ArrayList(u8).init(self.allocator);
    errdefer buffer.deinit(self.allocator);

    // 跳过第一个 [
    var start_pos: usize = 0;
    while (start_pos < first_line.len and first_line[start_pos] != '[') {
        start_pos += 1;
    }
    if (start_pos >= first_line.len) return Error.InvalidArrayFormat;
    start_pos += 1; // 跳过 [

    // 检查第一行是否闭合 ]
    var content = std.mem.trim(u8, first_line[start_pos..], " \t\r\n");
    if (content.len > 0 and content[content.len - 1] == ']') {
        // 单行数组
        return try self.allocator.dupe(u8, content[0 .. content.len - 1]);
    }

    // 多行数组：收集内容直到找到 ]
    try buffer.appendSlice(self.allocator, content);

    while (self.pos < self.content.len) {
        // 读取下一行
        const line_start = self.pos;
        while (self.pos < self.content.len and self.content[self.pos] != '\n') {
            self.pos += 1;
        }

        const line = self.content[line_start..self.pos];
        const trimmed = std.mem.trim(u8, line, " \t\r\n");

        // 检查是否闭合 ]
        if (trimmed.len > 0 and trimmed[trimmed.len - 1] == ']') {
            // 数组结束
            const content_part = trimmed[0 .. trimmed.len - 1];
            if (content_part.len > 0) {
                try buffer.appendSlice(self.allocator, ",");
                try buffer.appendSlice(self.allocator, content_part);
            }
            self.pos += 1; // 跳过换行符
            break;
        }

        // 继续数组内容
        if (trimmed.len > 0) {
            try buffer.appendSlice(self.allocator, ",");
            try buffer.appendSlice(self.allocator, trimmed);
        }

        self.pos += 1; // 跳过换行符
    }

    return buffer.toOwnedSlice(self.allocator);
}
```

---

### 步骤 3: 修改 parseKeyValue 方法

**文件**：`src/ini.zig` parseKeyValue 方法

**修改逻辑**（在值解析部分）：

```zig
fn parseKeyValue(self: *Parser) Error!void {
    // ... 现有的 key 解析逻辑 ...

    // 获取值
    var value: []const u8 = undefined;

    // 检查是否是数组语法
    const single_line_value = self.parseSingleLineValue();
    if (isArrayValue(single_line_value)) {
        // 解析数组值（支持多行）
        value = try self.parseArrayValue(single_line_value);
    } else {
        // 现有的单值解析逻辑
        value = single_line_value;

        // 处理引号（现有逻辑保持不变）
        if (value.len >= 2 and (value[0] == '"' or value[0] == '\'')) {
            const quote = value[0];
            if (value[value.len - 1] != quote) return Error.UnclosedQuote;
            value = value[1 .. value.len - 1];
        }
    }

    // 类型标注解析（保持现有逻辑）
    var actual_key = key_full;
    var explicit_datatype: ?DataType = null;

    if (std.mem.indexOfScalar(u8, key_full, ':')) |colon_pos| {
        const key_part = key_full[0..colon_pos];
        const type_part = trimAll(key_full[colon_pos + 1 ..]);

        if (DataType.parse(type_part)) |datatype| {
            actual_key = trimAll(key_part);
            explicit_datatype = datatype;
        }
    }

    // 检查是否是数组（通过值判断）
    const is_array_type = isArrayValue(value);

    // 创建 Schema
    const value_copy = try self.allocator.dupe(u8, value);

    var schema = if (explicit_datatype) |datatype|
        Schema{
            .key = undefined,
            .value = value_copy,
            .datatype = datatype,
            .isArray = is_array_type,  // 设置数组标志
            .title = null,
            .description = null,
        }
    else
        Schema{
            .key = undefined,
            .value = value_copy,
            .datatype = DataType.infer(value),
            .isArray = is_array_type,  // 设置数组标志
            .title = null,
            .description = null,
        };

    // 设置文档注释（现有逻辑保持不变）
    try self.setSchemaDocumentation(&schema);

    // 存储到 HashMap（现有逻辑保持不变）
    if (self.current_section) |section| {
        const key_copy = try self.allocator.dupe(u8, actual_key);
        try section.schemas.put(key_copy, schema);
        const stored_schema = section.schemas.getPtr(key_copy).?;
        stored_schema.key = key_copy;
    } else {
        const key_copy = try self.allocator.dupe(u8, actual_key);
        try self.ini.schemas.put(key_copy, schema);
        const stored_schema = self.ini.schemas.getPtr(key_copy).?;
        stored_schema.key = key_copy;
    }

    // 跳过换行符（现有逻辑）
    if (self.pos < self.content.len and self.content[self.pos] == '\n') {
        self.pos += 1;
    }
}
```

---

### 步骤 4: 添加数组访问方法

**文件**：`src/ini.zig` 第180行后（Schema 结构体方法末尾）

**新增 Schema 级别方法**（约25行，复用现有 TypeConverter，使用 comptime 优化）：

```zig
/// 通用数组解析方法（comptime 泛型）
pub fn asArray(comptime T: type, self: *const Schema, allocator: Allocator) ![]const T {
    if (!self.isArray) return error.NotAnArray;

    // 字符串数组特殊处理（需要深拷贝）
    if (comptime std.meta.trait.isZigSlice(T) and
        comptime std.meta.trait.isPtrToConst(std.meta.Child(T))) {
        return parseArrayInternal(T, self, allocator, struct {
            fn converter(str: []const u8, alloc: Allocator) !T {
                return alloc.dupe(u8, str);
            }
        }.converter);
    }

    // 整数数组 - 复用 TypeConverter.toXXX 方法
    if (comptime T == u8) return parseArrayInternal(T, self, allocator, TypeConverter.toU8);
    if (comptime T == u16) return parseArrayInternal(T, self, allocator, TypeConverter.toU16);
    if (comptime T == u32) return parseArrayInternal(T, self, allocator, TypeConverter.toU32);
    if (comptime T == u64) return parseArrayInternal(T, self, allocator, TypeConverter.toU64);
    if (comptime T == i8) return parseArrayInternal(T, self, allocator, TypeConverter.toI8);
    if (comptime T == i16) return parseArrayInternal(T, self, allocator, TypeConverter.toI16);
    if (comptime T == i32) return parseArrayInternal(T, self, allocator, TypeConverter.toI32);
    if (comptime T == i64) return parseArrayInternal(T, self, allocator, TypeConverter.toI64);

    // 浮点数组
    if (comptime T == f32) return parseArrayInternal(T, self, allocator, TypeConverter.toF32);
    if (comptime T == f64) return parseArrayInternal(T, self, allocator, TypeConverter.toF64);

    // 布尔数组
    if (comptime T == bool) return parseArrayInternal(T, self, allocator, TypeConverter.toBool);

    return error.TypeMismatch;
}

/// 通用的数组解析内部实现（comptime 优化）
fn parseArrayInternal(
    comptime T: type,
    self: *const Schema,
    allocator: Allocator,
    comptime converterFn: fn ([]const u8) anyerror!T
) ![]const T {
    const parts = std.mem.splitSequence(u8, self.value, ",");
    var list = std.ArrayList(T).init(allocator);

    // 字符串数组需要特殊的错误处理
    if (comptime std.meta.trait.isZigSlice(T) and
        comptime std.meta.trait.isPtrToConst(std.meta.Child(T))) {
        errdefer {
            for (list.items) |item| allocator.free(item);
            list.deinit(allocator);
        }
    } else {
        errdefer list.deinit();
    }

    while (parts.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t\r\n");
        if (trimmed.len > 0) {
            const value = try converterFn(trimmed);
            try list.append(value);
        }
    }

    return list.toOwnedSlice(allocator);
}

/// 便捷的类型化数组访问方法（Schema 级别）
pub fn asIntArray(self: *const Schema, allocator: Allocator) ![]const i64 {
    return asArray(i64, self, allocator);
}

pub fn asStringArray(self: *const Schema, allocator: Allocator) ![]const []const u8 {
    return asArray([]const u8, self, allocator);
}

pub fn asU8Array(self: *const Schema, allocator: Allocator) ![]const u8 {
    return asArray(u8, self, allocator);
}

pub fn asU16Array(self: *const Schema, allocator: Allocator) ![]const u16 {
    return asArray(u16, self, allocator);
}

pub fn asI32Array(self: *const Schema, allocator: Allocator) ![]const i32 {
    return asArray(i32, self, allocator);
}

pub fn asFloatArray(self: *const Schema, allocator: Allocator) ![]const f64 {
    return asArray(f64, self, allocator);
}

pub fn asBoolArray(self: *const Schema, allocator: Allocator) ![]const bool {
    return asArray(bool, self, allocator);
}
```

---

### 步骤 5: 添加 Ini 级别的数组访问方法

**文件**：`src/ini.zig` Ini 结构体方法部分（第637行后，在现有 getXXX 方法之后）

**新增通用方法**（约15行，简洁高效）：

```zig
/// 通用数组获取方法（支持 section.key 语法）
/// 通过 key 获取指定类型的数组
pub fn getArray(comptime T: type, self: *const Ini, key: []const u8, allocator: Allocator) ![]const T {
    switch (parseKey(key)) {
        .section_key => |parsed| {
            // Get from section
            if (self.sections.get(parsed.section)) |section| {
                if (section.getSchema(parsed.key)) |schema| {
                    return schema.asArray(T, allocator);
                }
            }
            return error.KeyNotFound;
        },
        .global => |global_key| {
            // Get from global schemas
            if (self.schemas.get(global_key)) |schema| {
                return schema.asArray(T, allocator);
            }
            return error.KeyNotFound;
        },
    }
}
```

**API 设计优势：**

- ✅ **极简 API**：只有一个通用方法 `getArray(T, key, allocator)`
- ✅ **支持 section.key 语法**：`getArray(u16, "database.ports", allocator)`
- ✅ **类型安全**：编译时类型检查
- ✅ **代码量最小**：仅需15行（vs 40行的多个便捷方法）
- ✅ **使用简单**：`const ports = try ini.getArray(u16, "ports", allocator)`

**关键优化：**

- ✅ **复用 TypeConverter**：直接使用现有的 `toU8`, `toU16`, `toI32` 等方法
- ✅ **减少重复代码**：不需要重新实现多进制解析逻辑
- ✅ **保持一致性**：与现有的类型转换使用相同的逻辑
- ✅ **支持所有特性**：自动支持 0b、0x、十进制等所有现有特性

---

### 步骤 5: 更新序列化逻辑

**文件**：`src/ini.zig` formatSchemaToBuffer 方法

**修改逻辑**：

```zig
fn formatSchemaToBuffer(allocator: Allocator, buffer: *std.ArrayList(u8), schema: Schema) !void {
    // ... 现有的 title 和 description 处理 ...

    // 写入 key = value
    if (schema.isArray) {
        // 数组类型：转换为方括号语法
        const key_value = try std.fmt.allocPrint(allocator, "{s} = [{s}]\n", .{
            schema.key,
            schema.value
        });
        defer allocator.free(key_value);
        try buffer.appendSlice(allocator, key_value);
    } else {
        // 单值类型：保持现有格式
        const key_value = try std.fmt.allocPrint(allocator, "{s} = {s}\n", .{
            schema.key,
            schema.value
        });
        defer allocator.free(key_value);
        try buffer.appendSlice(allocator, key_value);
    }
}
```

---

### 步骤 6: 添加错误类型

**文件**：`src/ini.zig` Error 枚举

**新增错误类型**：

```zig
pub const Error = error{
    // 现有错误...
    InvalidFormat,
    EmptySectionName,
    DuplicateSection,
    UnclosedQuote,
    InvalidEscape,
    FileNotFound,
    WriteError,
    OutOfMemory,
    InvalidCharacter,

    // 新增数组相关错误
    NotAnArray,              // 尝试在非数组类型上调用数组方法
    InvalidArrayFormat,       // 数组格式错误（未闭合、空值等）
    ArrayElementTypeMismatch,// 数组元素类型转换失败
    ArrayOverflow,           // 数组元素值溢出目标类型
};
```

---

### 步骤 7: 创建测试文件

**文件**：`tests/array_types.zig`

**测试用例**（约300行）：

```zig
//! 数组类型支持测试（[] 语法）

const std = @import("std");
const Ini = @import("zini").Ini;
const Schema = @import("zini").Schema;

test "单行整数数组" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content = "ports=[80,443,8080]";
    try ini.loadFromString(content);

    if (ini.getSchema("ports")) |schema| {
        try std.testing.expect(schema.isArray);
        const ports = try schema.asU16Array(allocator);
        defer allocator.free(ports);

        try std.testing.expectEqual(@as(usize, 3), ports.len);
        try std.testing.expectEqual(@as(u16, 80), ports[0]);
        try std.testing.expectEqual(@as(u16, 443), ports[1]);
        try std.testing.expectEqual(@as(u16, 8080), ports[2]);
    }
}

test "多行数组" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\allowed_ips=[
        \\    192.168.1.1,
        \\    10.0.0.1,
        \\    172.16.0.1
        \\]
    ;

    try ini.loadFromString(content);

    if (ini.getSchema("allowed_ips")) |schema| {
        const ips = try schema.asStringArray(allocator);
        defer {
            for (ips) |ip| allocator.free(ip);
            allocator.free(ips);
        }

        try std.testing.expectEqual(@as(usize, 3), ips.len);
        try std.testing.expectEqualStrings("192.168.1.1", ips[0]);
        try std.testing.expectEqualStrings("10.0.0.1", ips[1]);
        try std.testing.expectEqualStrings("172.16.0.1", ips[2]);
    }
}

test "字符串数组" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content = "names=[alice,bob,charlie]";
    try ini.loadFromString(content);

    if (ini.getSchema("names")) |schema| {
        const names = try schema.asStringArray(allocator);
        defer {
            for (names) |name| allocator.free(name);
            allocator.free(names);
        }

        try std.testing.expectEqual(@as(usize, 3), names.len);
    }
}

test "布尔数组" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content = "flags=[true,false,true]";
    try ini.loadFromString(content);

    if (ini.getSchema("flags")) |schema| {
        const flags = try schema.asBoolArray(allocator);
        defer allocator.free(flags);

        try std.testing.expectEqual(@as(usize, 3), flags.len);
        try std.testing.expectEqual(true, flags[0]);
        try std.testing.expectEqual(false, flags[1]);
    }
}

test "浮点数组" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content = "rates=[3.14,2.71,1.41]";
    try ini.loadFromString(content);

    if (ini.getSchema("rates")) |schema| {
        const rates = try schema.asFloatArray(allocator);
        defer allocator.free(rates);

        try std.testing.expectEqual(@as(usize, 3), rates.len);
        try std.testing.expectApproxEqAbs(@as(f64, 3.14), rates[0], 0.001);
    }
}

test "显式类型标注" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content = "count:u8=[1,2,3]";
    try ini.loadFromString(content);

    if (ini.getSchema("count")) |schema| {
        try std.testing.expect(schema.isArray);
        try std.testing.expectEqual(.u8, schema.datatype);

        const count = try schema.asU8Array(allocator);
        defer allocator.free(count);

        try std.testing.expectEqual(@as(usize, 3), count.len);
    }
}

test "空数组" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content = "empty=[]";
    try ini.loadFromString(content);

    if (ini.getSchema("empty")) |schema| {
        try std.testing.expect(schema.isArray);
        const empty = try schema.asU16Array(allocator);
        defer allocator.free(empty);

        try std.testing.expectEqual(@as(usize, 0), empty.len);
    }
}

test "Section 中的数组" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\[database]
        \\replicas=[1,2,3]
        \\shards=[10,20,30,40]
    ;

    try ini.loadFromString(content);

    if (ini.getSchema("database.replicas")) |schema| {
        const replicas = try schema.asU8Array(allocator);
        defer allocator.free(replicas);

        try std.testing.expectEqual(@as(usize, 3), replicas.len);
    }

    if (ini.getSchema("database.shards")) |schema| {
        const shards = try schema.asI32Array(allocator);
        defer allocator.free(shards);

        try std.testing.expectEqual(@as(usize, 4), shards.len);
    }
}

test "序列化和反序列化" {
    const allocator = std.testing.allocator;
    var ini1 = Ini.init(allocator);
    defer ini1.deinit();

    try ini1.set("numbers", "[1,2,3,4,5]");

    const content = try ini1.saveToString(allocator);
    defer allocator.free(content);

    // 验证序列化包含方括号语法
    try std.testing.expect(std.mem.indexOf(u8, content, "numbers=[1,2,3,4,5]") != null);

    var ini2 = Ini.init(allocator);
    defer ini2.deinit();

    try ini2.loadFromString(content);

    if (ini2.getSchema("numbers")) |schema| {
        try std.testing.expect(schema.isArray);

        const numbers = try schema.asI32Array(allocator);
        defer allocator.free(numbers);

        try std.testing.expectEqual(@as(usize, 5), numbers.len);
        try std.testing.expectEqual(@as(i32, 1), numbers[0]);
    }
}

test "向后兼容性" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 旧格式应该继续工作
    const content =
        \\port = 8080
        \\name = MyApp
        \\enabled = true
    ;

    try ini.loadFromString(content);

    const port = try ini.getI32("port");
    try std.testing.expectEqual(@as(i32, 8080), port);

    const name = ini.get("name").?;
    try std.testing.expectEqualStrings("MyApp", name);

    const enabled = try ini.getBool("enabled");
    try std.testing.expect(enabled == true);
}

test "错误处理 - 非数组访问数组方法" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("single", "8080");

    if (ini.getSchema("single")) |schema| {
        try std.testing.expect(!schema.isArray);

        const result = schema.asU16Array(allocator);
        try std.testing.expectError(error.NotAnArray, result);
    }
}

test "多进制整数数组" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\binary=[0b1010,0b1100,0b1111]
        \\hex=[0xA,0xFF,0x123]
        \\decimal=[10,20,30]
    ;

    try ini.loadFromString(content);

    if (ini.getSchema("binary")) |schema| {
        const binary = try schema.asU16Array(allocator);
        defer allocator.free(binary);

        try std.testing.expectEqual(@as(u16, 10), binary[0]);  // 0b1010 = 10
        try std.testing.expectEqual(@as(u16, 12), binary[1]);  // 0b1100 = 12
        try std.testing.expectEqual(@as(u16, 15), binary[2]);  // 0b1111 = 15
    }

    if (ini.getSchema("hex")) |schema| {
        const hex = try schema.asU16Array(allocator);
        defer allocator.free(hex);

        try std.testing.expectEqual(@as(u16, 10), hex[0]);    // 0xA = 10
        try std.testing.expectEqual(@as(u16, 255), hex[1]);   // 0xFF = 255
        try std.testing.expectEqual(@as(u16, 291), hex[2]);   // 0x123 = 291
    }
}

test "带空格的数组值" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\numbers=[ 1 , 2 , 3 ]
        \\strings=[ a , b , c ]
    ;

    try ini.loadFromString(content);

    if (ini.getSchema("numbers")) |schema| {
        const numbers = try schema.asI32Array(allocator);
        defer allocator.free(numbers);

        try std.testing.expectEqual(@as(i32, 1), numbers[0]);
        try std.testing.expectEqual(@as(i32, 2), numbers[1]);
        try std.testing.expectEqual(@as(i32, 3), numbers[2]);
    }

    if (ini.getSchema("strings")) |schema| {
        const strings = try schema.asStringArray(allocator);
        defer {
            for (strings) |s| allocator.free(s);
            allocator.free(strings);
        }

        try std.testing.expectEqualStrings("a", strings[0]);
        try std.testing.expectEqualStrings("b", strings[1]);
        try std.testing.expectEqualStrings("c", strings[2]);
    }
}
```

---

### 步骤 8: 更新构建系统

**文件**：`build.zig`

**添加测试模块**：

```zig
// 数组类型测试
const array_types_mod = b.createModule(.{
    .root_source_file = b.path("tests/array_types.zig"),
    .target = target,
    .imports = &.{
        .{ .name = "zini", .module = mod },
    },
});

const array_types_tests = b.addTest(.{
    .root_module = array_types_mod,
});

const run_array_types_tests = b.addRunArtifact(array_types_tests);

// 在 test_step 中添加依赖
test_step.dependOn(&run_array_types_tests.step);
```

---

## 代码量总结

### 修改现有代码：约15行

- Schema 结构体：+1行
- parseKeyValue 方法：+10行
- formatSchemaToBuffer 方法：+5行

### 新增代码：约70行（简化后）

- isArrayValue 检测：+5行
- parseArrayValue 解析：+35行
- Schema 级别数组方法：+25行（复用 TypeConverter）
- Ini 级别通用方法：+15行（仅需 getArray）
- 错误类型：+4行
- 测试用例：约300行（单独文件）

**总实施代码量：约85行（不含测试）**

**简化效果：**

- ✅ **极简 API**：只有一个通用 `getArray(T, key, allocator)` 方法
- ✅ **代码量最小**：从135行减少到85行（减少37%）
- ✅ **保持功能完整**：支持所有类型和 section.key 语法
- ✅ **使用简单**：`const ports = try ini.getArray(u16, "ports", allocator)`

---

## 时间估算

### 各步骤时间估算

1. Schema 结构体增强：10分钟
2. 数组检测和解析方法：45分钟（最复杂部分）
3. parseKeyValue 修改：20分钟
4. 数组访问方法：30分钟
5. 序列化逻辑更新：15分钟
6. 错误类型添加：5分钟
7. 测试用例实施：60分钟
8. 构建系统更新：10分钟
9. 调试和验证：30分钟

**总计：约3-4小时**

---

## 风险评估

### 低风险部分

- Schema 结构体修改（向后兼容）
- 数组访问方法（新 API，不影响现有代码）
- 测试用例（独立验证）

### 中风险部分

- parseArrayValue 多行解析逻辑（需要仔细处理边界情况）
- 与现有多行字符串语法的交互（``` 冲突检测）

### 缓解措施

- 完善单元测试覆盖边界情况
- 逐步实施，每步验证编译和测试
- 保持现有功能的完整性

---

## 验证计划

### 功能验证

1. 运行所有新增测试用例
2. 验证向后兼容性（现有配置正常工作）
3. 测试边界情况（空数组、多行、类型转换）

### 性能验证

1. 大型数组解析性能测试
2. 内存分配验证
3. 与单值解析的性能对比

### 代码质量验证

1. 代码风格一致性检查
2. 内存安全性验证
3. API 易用性测试

---

## 总结

采用 **方案 B：`[]` 语法**，虽然代码量稍多（约100行），但提供了最佳的用户体验：

**核心优势：**

- ✅ 语法最简洁：`ports=[80,443,8080]`
- ✅ 支持多行：适合大型数组配置
- ✅ 类型推断：无需手动标注类型
- ✅ 功能完整：满足所有数组使用场景

**实施保障：**

- 实施时间：3-4小时
- 风险等级：中等（可控）
- 向后兼容：完全保持
