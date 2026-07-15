# forEach 方法使用指南

## 推荐用法：闭包方式（支持上下文参数）

### 新的 API 签名
```zig
pub fn forEach(self: *const Ini, section: []const u8, callback: anytype, context: anytype) void
```

**参数说明：**
- `section`: 迭代范围（"*"=全部，""=全局，"section_name"=指定section）
- `callback`: 回调函数，接收 `(item: *const Item, section: ?[]const u8, context: T)` 三个参数
- `context`: 传递给回调函数的上下文参数（任何类型的指针）

### 基本语法
```zig
// 使用闭包方式：传递外部变量指针作为上下文
var count: usize = 0;

ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, ctx: *usize) void {
        _ = section;
        const key = item.key orelse return;
        const value = item.value orelse return;

        std.debug.print("  {s} = {s}\n", .{ key, value });

        // ✅ 可以修改外部变量
        ctx.* += 1;
    }
}.callback, &count);

// 验证统计结果
try std.testing.expectEqual(@as(usize, 2), count);
```

## 回调函数签名

```zig
fn callback(item: *const Item, section: ?[]const u8, context: *YourContextType) void
```

**参数说明：**
- `item`: 配置项指针
- `section`: section 名称（全局配置时为 null）
- `context`: 外部传入的上下文指针（可变，支持任何类型）

## 实用示例

### 示例 1: 捕获单个状态变量
```zig
var count: usize = 0;

ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, ctx: *usize) void {
        _ = section;
        const key = item.key orelse return;
        const value = item.value orelse return;

        std.debug.print("  {s} = {s}\n", .{ key, value });
        ctx.* += 1; // ✅ 修改外部变量
    }
}.callback, &count);
```

### 示例 2: 捕获多个状态变量（使用结构体）
```zig
// 使用命名结构体来避免类型不匹配
const CountContext = struct {
    database_count: usize = 0,
    global_count: usize = 0,
};

var context = CountContext{};

ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, ctx: *CountContext) void {
        const key = item.key orelse return;
        const value = item.value orelse return;

        if (section) |section_name| {
            if (std.mem.eql(u8, section_name, "database")) {
                std.debug.print("  Database: {s} = {s}\n", .{ key, value });
                ctx.database_count += 1; // ✅ 修改结构体字段
            }
        } else {
            std.debug.print("  Global: {s} = {s}\n", .{ key, value });
            ctx.global_count += 1; // ✅ 修改结构体字段
        }
    }
}.callback, &context);

try std.testing.expectEqual(@as(usize, 2), context.database_count);
try std.testing.expectEqual(@as(usize, 1), context.global_count);
```

### 示例 3: 在闭包中断言和验证
```zig
var found_expected = false;

ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, found: *bool) void {
        _ = section;
        const key = item.key orelse return;
        const value = item.value orelse return;

        if (std.mem.eql(u8, key, "expected_key")) {
            // ✅ 在闭包中直接编写断言
            if (!std.mem.eql(u8, value, "expected_value")) {
                std.debug.print("错误: 期望 'expected_value', 实际 '{s}'\n", .{value});
            } else {
                found.* = true; // ✅ 修改外部变量
            }
        }
    }
}.callback, &found_expected);

try std.testing.expect(found_expected);
```

### 示例 4: 复杂的数据收集
```zig
// 定义统计上下文结构
const ConfigStats = struct {
    total_count: usize = 0,
    number_count: usize = 0,
    string_count: usize = 0,
    boolean_count: usize = 0,
};

var stats = ConfigStats{};

ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, ctx: *ConfigStats) void {
        _ = section;
        const key = item.key orelse return;

        ctx.total_count += 1;
        if (item.datatype) |dt| {
            switch (dt) {
                .number => ctx.number_count += 1,
                .string => ctx.string_count += 1,
                .boolean => ctx.boolean_count += 1,
                else => {},
            }
        }
        _ = key;
    }
}.callback, &stats);

std.debug.print("统计: 总数={}, 数字={}, 字符串={}, 布尔={}\n", .{
    stats.total_count, stats.number_count, stats.string_count, stats.boolean_count
});
```

## ✅ 闭包方式的优势

### 1. **状态捕获和修改**
```zig
var count: usize = 0;
// ✅ 可以修改外部变量
ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, ctx: *usize) void {
        ctx.* += 1;
        _ = item;
        _ = section;
    }
}.callback);
```

### 2. **在闭包中断言**
```zig
var validation_passed: bool = true;

ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, passed: *bool) void {
        _ = section;
        const key = item.key orelse return;
        const value = item.value orelse return;

        // ✅ 可以编写验证逻辑
        if (std.mem.eql(u8, key, "critical_key") and
            !std.mem.eql(u8, value, "expected_value")) {
            passed.* = false;
        }
    }
}.callback, &validation_passed);

try std.testing.expect(validation_passed);
```

### 3. **灵活的状态管理**
```zig
// 可以传递任何类型的上下文
const MyContext = struct {
    errors: std.ArrayList(Error),
    warnings: usize = 0,
};

var context = MyContext{
    .errors = std.ArrayList(Error).init(allocator),
};

ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, ctx: *MyContext) void {
        // 复杂的验证逻辑
        _ = section;
        _ = item;
    }
}.callback, &context);
```

## 测试中的用法

### 完整的测试示例
```zig
test "forEach 完整功能测试" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("key1", "value1");
    try ini.set("database.port", "5432");

    var count: usize = 0;

    ini.forEach("*", struct {
        fn callback(item: *const Item, section: ?[]const u8, cnt: *usize) void {
            const key = item.key orelse return;
            const value = item.value orelse return;

            cnt.* += 1;

            if (section) |section_name| {
                if (std.mem.eql(u8, section_name, "database")) {
                    // ✅ 验证数据库配置
                    if (std.mem.eql(u8, key, "port")) {
                        if (!std.mem.eql(u8, value, "5432")) {
                            std.debug.print("错误: 端口应该是 5432\n", .{});
                        }
                    }
                }
            }
        }
    }.callback, &count);

    try std.testing.expectEqual(@as(usize, 2), count);
}
```

## 核心原则

**闭包方式的规则：**
- ✅ **推荐** 使用闭包方式，传递上下文参数
- ✅ **支持** 捕获和修改外部变量
- ✅ **支持** 在闭包中断言和验证
- ✅ **支持** 任何类型的上下文（简单类型或结构体）
- ✅ **灵活** 的状态管理

**推荐用法：**
```zig
var state: YourState = .{};

ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, ctx: *YourState) void {
        // 处理逻辑，可以修改 ctx 的内容
        _ = item;
        _ = section;
    }
}.callback, &state);
```

## 重要提示

### ✅ 使用命名结构体
当传递复杂上下文时，**必须使用命名结构体**而不是匿名结构体：

```zig
// ✅ 正确：使用命名结构体
const CountContext = struct {
    database_count: usize = 0,
    global_count: usize = 0,
};

var context = CountContext{};
ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, ctx: *CountContext) void {
        // ctx 的类型是 *CountContext
    }
}.callback, &context);

// ❌ 错误：使用匿名结构体会导致类型不匹配
var context = struct { database_count: usize = 0, global_count: usize = 0 }{};
ini.forEach("*", struct {
    fn callback(item: *const Item, section: ?[]const u8, ctx: *auto) void {
        // ctx 的类型无法推断
    }
}.callback, &context);
```

### 遍历范围
```zig
// 遍历所有配置（全局 + 所有 sections）
ini.forEach("*", callback, &context);

// 遍历全局配置
ini.forEach("", callback, &context);

// 遍历特定 section
ini.forEach("database", callback, &context);
```

---

**提示**: 闭包方式是 forEach 的推荐用法，通过传递上下文参数，您可以灵活地捕获外部状态、编写断言和修改外部变量！
