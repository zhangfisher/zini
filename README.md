# zini

一个简洁高效、类型安全的 Zig 语言 INI 配置文件解析库，支持自动类型推断、多行字符串、转换器和验证器系统。

**仅 4 种基本类型，简洁 API，学习成本低，为 Zig 项目提供可靠的配置管理解决方案。**

---

## 关键特性

- **🎯 类型安全** - 仅 4 种基本类型（`string`、`boolean`、`number`、`float`），自动类型推断，编译时类型检查
- **🚀 简洁 API** - 只需 4 个 `getter` 方法，学习成本极低，符合 Zig 语言习惯
- **✨ 智能推断** - 根据值内容自动识别类型，支持布尔值、整数、浮点数、字符串
- **📝 多行字符串** - 支持 `Markdown` 风格的多行文本，适合模板和长文本
- **🏷️ 丰富元数据** - 支持 `title`、`default`、`choices` 等元数据
- **🔄 配置重置** - 支持 `reset()` 方法一键恢复默认值
- **🎯 精确操作** - 支持 `getSection()` 方法操作特定 `section`，点号语法访问
- **💾 内存优化** - 可选的描述加载模式，灵活控制内存占用
- **🔧 转换器系统** - 支持双向值转换，扩展配置值处理能力
- **✅ 验证器系统** - 可扩展的验证框架，支持自定义验证规则
- **✅ 注释保留** - 读写时保留注释内容
- **🔧 完整 INI 支持** - `Sections`、全局键值对、注释、引号字符串
- **🛡️ 内存安全** - 完善的内存管理，无泄漏，符合 Zig 安全标准
- **⚡ 零依赖** - 仅依赖 Zig 标准库，编译体积小
- **📈 高性能** - 高效的解析和序列化，适合生产环境使用

---

## 安装

### 系统要求

- **最低 Zig 版本**: 0.16.0
- **推荐 Zig 版本**: 0.16.0 或更高
- **操作系统**: Windows, Linux, macOS
- **架构**: x86_64, ARM64, ARM32

### 构建和测试

**运行测试：**

```bash
# 直接运行测试（推荐）
zig test src/ini.zig

# 或通过构建系统
zig build test
```

**查看所有可用的构建命令：**

```bash
zig build -h
```

```zig

const zini = b.dependency("zini", .{
.target = target,
.optimize = optimize,
});

const ini_module = zini.module("zini");
exe.root_module.addImport("zini", ini_module);

```

**获取正确的 hash：**

```bash
# 首次添加依赖时，让 Zig 自动计算 hash
zig build
```

### 本地项目引用

如果你在本地开发或想使用本地副本：

```zig
// 在 build.zig.zon 中
.dependencies = .{
    .zini = .{
        .path = "../zini",  // 相对路径
    },
}
```

### 从源码安装

**克隆仓库：**

```bash
git clone https://github.com/zhangfisher/zini.git
cd zini
```

**验证安装：**

```bash
# 运行测试
zig test src/ini.zig

# 查看所有可用命令
zig build --list-steps
```

### 验证安装

创建一个简单的测试文件 `test.zig`：

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("test", "success");
    std.debug.print("zini 安装成功！\n", .{});
}
```

运行测试：

```bash
zig build-exe test.zig --mod zini:zini
./test  # Linux/macOS
test.exe  # Windows
```

---

## 指南

### 自动类型推断

`zini` 可以根据值的内容自动识别类型，无需任何手动标注。

**推断规则：**

```ini
# 布尔值推断 - 识别 true/false
debug = true          # boolean
enabled = FALSE       # boolean

# 整数推断 - 纯数字（允许符号）
port = 8080           # number
timeout = -30         # number
buffer = +1024        # number

# 浮点数推断 - 包含小数点的数字
rate = 3.14           # float
temperature = -0.5    # float
factor = +2.7         # float

# 字符串推断 - 文本或引号包裹
name = myapp          # string (无引号)
message = "hello"     # string (双引号)
title = 'world'       # string (单引号)
```

**Zig 代码示例：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.loadFromString(
        \\debug = true
        \\port = 8080
        \\rate = 3.14
        \\name = myapp
    );

    // 使用 4 个基本 getter 方法
    const debug: bool = try ini.getBoolean("debug");
    const port: i64 = try ini.getNumber("port");
    const rate: f64 = try ini.getFloat("rate");
    const name: []const u8 = try ini.getString("name");

    std.debug.print("debug: {}, port: {}, rate: {d:.2}, name: {s}\n",
        .{debug, port, rate, name});
}
```

### 多行字符串支持

支持 Markdown 风格的多行字符串，用三个反引号包裹。

**INI 文件示例：**

````ini
# 电子邮件模板
email_template = ```
Dear {{name}},

Thank you for your purchase!

Best regards,
The Team
```
````

**Zig 代码示例：**

```zig
const email_template = try ini.getString("email_template");
const terms = try ini.getString("terms_of_service");

// 字符串会保持原始的换行和格式
std.debug.print("Email:\n{s}\n", .{email_template});
std.debug.print("Terms:\n{s}\n", .{terms});
```

### 转换器系统

zini 提供了强大的转换器系统，支持配置值的双向转换。

**转换器系统功能：**

- **双向转换**：支持读取时转换和保存时还原
- **类型扩展**：可以为特殊类型提供自定义解析逻辑
- **值标准化**：统一配置值的格式和表示
- **内置转换器**：提供日志级别、数据库引擎等常见转换器

**使用示例：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;
const Converter = @import("zini").Converter;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 定义日志级别转换器
    const log_level_converter = struct {
        fn from(input: []const u8) ![]const u8 {
            // 将 debug/info/warn/error 转换为 1/2/3/4
            if (std.mem.eql(u8, input, "debug")) return "1";
            if (std.mem.eql(u8, input, "info")) return "2";
            if (std.mem.eql(u8, input, "warn")) return "3";
            if (std.mem.eql(u8, input, "error")) return "4";
            return error.InvalidValue;
        }

        fn to(input: []const u8) ![]const u8 {
            // 将 1/2/3/4 转换回 debug/info/warn/error
            const num = try std.fmt.parseInt(u8, input, 10);
            return switch (num) {
                1 => "debug",
                2 => "info",
                3 => "warn",
                4 => "error",
                else => error.InvalidValue,
            };
        }
    };

    const converter = Converter{
        .from = log_level_converter.from,
        .to = log_level_converter.to,
    };

    // 为配置项设置转换器
    if (ini.items.getPtr("log_level")) |item| {
        item.converter = &converter;
    }
}
```

### 验证器系统

zini 提供了极简高效的验证框架，支持自定义验证规则。

**验证器系统功能：**

- **极简架构** - 验证器只是纯函数指针，零额外开销
- **清晰职责** - Item 知道自己配置了哪些验证器
- **内存优化** - 混合实例化策略，按需分配
- **灵活验证** - 支持全局验证器和指定验证器组合

**验证器类型定义：**

```zig
/// 验证器函数指针类型
pub const Validator = *const fn (value: []const u8, item: *const Item) bool;
```

**使用示例：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 定义端口范围验证器（纯函数）
    fn portRangeValidator(value: []const u8, item: *const Item) bool {
        _ = item;
        const port = std.fmt.parseInt(u16, value, 10) catch return false;
        return port >= 1024 and port <= 65535;
    }

    // 添加验证器（直接传递函数指针）
    try ini.validators.add("port_range", portRangeValidator);

    // 为配置项指定验证器
    try ini.set("port", "8080");
    if (ini.items.getPtr("port")) |item| {
        const names = try allocator.alloc([]const u8, 1);
        names[0] = try allocator.dupe(u8, "port_range");
        item.validators = names;
    }

    // 验证自动执行
    try ini.set("port", "9000");  // 验证通过
    try ini.set("port", "100");   // 验证失败，抛出错误
}
```

**内置验证器：**

zini 自动包含一个全局 `choiceValidator`，验证值是否在 `@choices` 列表中：

```zig
// 自动生效，无需手动添加
// @choices admin,user,guest
role = admin  // 验证通过
role = root   // 验证失败
```

**全局验证器：**

使用 `"*"` 作为名称添加全局验证器（对所有配置项生效）：

```zig
// 添加全局验证器
try ini.validators.add("*", globalValidator);
```

**验证流程：**

1. 先执行全局验证器（如 choiceValidator）
2. 再执行 Item 指定的验证器（通过 `item.validators` 设置）
3. 全部返回 true 才算验证通过

### 元数据支持

zini 支持丰富的元数据功能，可以为配置项添加标题、描述、默认值和选择项。

**支持的元数据：**

- **普通注释** - 配置项的描述信息（需要启用描述加载）
- **`@title`** - 配置项的标题
- **`@default`** - 配置项的默认值（用于 reset() 方法）
- **`@choices`** - 配置项的可选值列表（逗号分隔）

**INI 文件示例：**

```ini
# 数据库连接超时时间（秒）
# 超过此时间将抛出连接异常
# @title 连接超时
# @default 30
# @choices 10,20,30,60,120
timeout = 60

# 服务器监听端口
# @title 监听端口
# @default 8080
port = 9000

# 数据库主机地址
# @title 数据库主机
# @default localhost
# @choices localhost,127.0.0.1,db.example.com
db_host = localhost

# 启用调试模式
# @title 调试模式
# @default false
debug = true
```

**Zig 代码示例：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 启用描述加载以获取完整元数据
    var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini.deinit();

    try ini.loadFromString(
        \\# 数据库连接超时时间（秒）
        \\# 超过此时间将抛出连接异常
        \\# @title 连接超时
        \\# @default 30
        \\# @choices 10,20,30,60,120
        \\timeout = 60
    );

    // 获取配置项的完整信息
    if (ini.getItem("timeout")) |item| {
        std.debug.print("Key: {s}\n", .{schema.key});
        std.debug.print("Value: {s}\n", .{schema.value});
        std.debug.print("Type: {}\n", .{schema.datatype});

        if (schema.title) |title| {
            std.debug.print("Title: {s}\n", .{title});
        }

        if (schema.description) |desc| {
            std.debug.print("Description: {s}\n", .{desc});
        }

        if (schema.default) |default| {
            std.debug.print("Default: {s}\n", .{default});
        }

        if (schema.choices) |choices| {
            std.debug.print("Choices: {s}\n", .{choices});
        }
    }
}
```

### 内存优化

zini 提供了灵活的内存管理选项，根据需求选择合适的模式。

**默认模式（内存优化）：**

```zig
// 不加载 description，节省内存
var ini = Ini.init(allocator);
defer ini.deinit();
```

**完整模式（包含所有元数据）：**

```zig
// 加载所有元数据，包括 description
var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
defer ini.deinit();
```

**何时使用哪个模式：**

- **默认模式** - 适用于大多数场景，只需要配置值和基本元数据
- **完整模式** - 需要配置项的详细描述信息时使用

### 注释支持

支持行注释和行尾注释,注释符号`#`或`;`

```ini
# 这是井号注释
; 这是分号注释

[config]
# 全局配置项
timeout = 30   # 这是行尾注释

; 数据库配置
; host = localhost
port = 5432
```

### Section 操作

支持标准的 `INI Section` 语法，通过点号语法访问 `Section` 中的配置项。

**INI 文件示例：**

```ini
[database]
host = localhost
port = 5432
timeout = 30

[server]
port = 8080
host = 0.0.0.0
```

**Zig 代码示例：**

```zig
// 设置 section 中的值
try ini.set("database.host", "192.168.1.1");
try ini.set("database.port", "5432");

// 获取 section 中的值
const db_host = try ini.getString("database.host");
const db_port = try ini.getNumber("database.port");

// 删除键值对
ini.remove("database.old_key");
```

### 配置重置功能

zini 提供了强大的配置重置功能，可以快速恢复所有配置为默认值。

- 配置项使用`@default <默认值>`来指定默认值。

**基本用法：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default 8080
        \\port = 9000
        \\
        \\# @default localhost
        \\host = remotehost
        \\
        \\# @default true
        \\debug = false
    ;

    try ini.loadFromString(content);

    // 当前值
    std.debug.print("重置前:\n", .{});
    std.debug.print("  port: {}\n", .{try ini.getNumber("port")});
    std.debug.print("  host: {s}\n", .{try ini.getString("host")});
    std.debug.print("  debug: {}\n", .{try ini.getBoolean("debug")});

    // 重置所有配置为默认值
    try ini.reset();

    // 默认值
    std.debug.print("重置后:\n", .{});
    std.debug.print("  port: {}\n", .{try ini.getNumber("port)});
    std.debug.print("  host: {s}\n", .{try ini.getString("host")});
    std.debug.print("  debug: {}\n", .{try ini.getBoolean("debug")});
}
```

## API

### Ini 结构体

```zig
/// 创建默认 INI 解析器（不加载 description）
pub fn init(allocator: Allocator) Ini

/// 创建带选项的 INI 解析器
pub fn initWithOptions(allocator: Allocator, options: IniOptions) Ini

/// 释放资源
pub fn deinit(self: *Ini) void
```

### IniOptions

```zig
pub const IniOptions = struct {
    /// 加载 description 注释（默认关闭）
    pub const LoadDescription: u32 = 1;

    /// 创建加载 description 的选项
    pub fn withDescription() IniOptions
};
```

### 配置操作 API

```zig

/// 从文件加载配置
pub fn load(self: *Ini, path: []const u8) !void

/// 从字符串加载配置
pub fn loadFromString(self: *Ini, content: []const u8) !void

/// 保存到文件
pub fn save(self: *Ini, path: []const u8) !void

/// 保存为字符串
pub fn saveToString(self: *Ini, allocator: Allocator) ![]const u8

/// 设置配置值（支持 <section>.<key> 语法）
pub fn set(self: *Ini, key: []const u8, value: []const u8) !void

/// 获取原始字符串值
pub fn get(self: *const Ini, key: []const u8) ![]const u8

/// 获取字符串值
pub fn getString(self: *const Ini, key: []const u8) ![]const u8

/// 获取整数值 (i64)
pub fn getNumber(self: *const Ini, key: []const u8) !i64

/// 获取浮点数值 (f64)
pub fn getFloat(self: *const Ini, key: []const u8) !f64

/// 获取布尔值
pub fn getBoolean(self: *const Ini, key: []const u8) !bool

/// 检查键是否存在（支持 <section>.<key> 语法）
pub fn hasItem(self: *const Ini, key: []const u8) bool

/// 删除键值对（支持 <section>.<key> 语法）
pub fn removeItem(self: *Ini, key: []const u8) bool

/// 获取完整的 Item 信息（包含元数据）
pub fn getItem(self: *const Ini, key: []const u8) ?*const Item

/// 添加配置项
pub fn addItem(self: *Ini, key: []const u8, item: Item) !void

/// 遍历所有 Item（全局 + 所有 sections）
pub fn forEach(self: *const Ini, context_ptr: anytype, comptime callback: anytype) void

```

## 许可证

MIT License
