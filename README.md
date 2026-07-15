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
- **🤖 智能 addItem** - `addItem` 方法支持自动类型推断，与 `set` 方法保持一致
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

### 从 GitHub 安装（推荐）

在您的 `build.zig.zon` 文件中添加 zini 依赖：

```zig
.dependencies = .{
    .zini = .{
        // 使用 GitHub 仓库 URL（推荐使用特定标签或提交哈希）
        .url = "https://github.com/zhangfisher/zini/archive/refs/tags/v1.0.0.tar.gz",
        .hash = "1220abcdefghijklmnopqrstuvwxyz", // 运行 zig build 后自动填充
    },
}
```

**GitHub URL 格式说明：**

1. **使用特定版本（推荐）：**

   ```zig
   // 最新稳定版本（推荐）
   .url = "https://github.com/zhangfisher/zini/archive/refs/tags/v1.0.0.tar.gz"

   // 或使用提交哈希
   .url = "https://github.com/zhangfisher/zini/archive/abc123def456.tar.gz"
   ```

2. **使用主分支（不推荐，可能不稳定）：**
   ```zig
   .url = "https://github.com/zhangfisher/zini/archive/refs/heads/main.tar.gz"
   ```

**在 build.zig 中添加依赖：**

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
# 首次添加依赖时，将 hash 设为任意值
# 运行以下命令，Zig 会提示正确的 hash
zig build

# 或者使用 zig fetch 直接获取正确的 URL 和 hash
zig fetch https://github.com/zhangfisher/zini/archive/refs/tags/v1.0.0.tar.gz
```

### 本地项目引用

如果您在本地开发或想使用本地副本：

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

    var ini = Ini.default(allocator);
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

## 快速入门

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 从配置数组初始化（推荐提供default）
    const items = [_]Ini.Item{
        .{ .key = "port", .default = "8080" },
        .{ .key = "debug", .default = "false" },
        .{ .key = "host", .default = "localhost" },
    };
    var ini = try Ini.init(allocator, &items);
    defer ini.deinit();

    // 再从文件加载（覆盖配置，但保留 default 值）
    try ini.load("config.ini");

    // 类型安全地获取配置值
    const port: i64 = try ini.getNumber("port");
    const debug: bool = try ini.getBoolean("debug");

    // 修改配置：try ini.set("port", "9090");
    // 重置为默认值：try ini.reset();
    // 保存文件：try ini.save("output.ini");
}
```

**最佳实践：** 从配置数组初始化时推荐同时提供 `value` 和 `default` 值，这样可以使用 `reset()` 恢复默认值；然后用 `load` 加载用户配置文件；始终使用类型安全的 getter 方法（`getNumber`、`getBoolean`、`getFloat`、`getString`）；记得 `defer ini.deinit()` 释放资源。

---

## 指南

### 数据类型

`zini` 将配置数据值收敛为`string`、`number`、`boolean`、`float`共四种，这样即可以实现自动数据类型识别和推断，又可以简化API。

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

### 读取配置值

`zini`提供四个基本的类型方法来读取配置值.

**Zig 代码示例：**

```zig
    const allocator = std.heap.page_allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();
    try ini.loadFromString(
        \\debug = true
        \\port = 8080
        \\rate = 3.14
        \\name = myapp
        \\[server]
        \\timeout = 5000
    );

    // 使用 4 个基本 getter 方法
    const debug: bool = try ini.getBoolean("debug");
    const port: i64 = try ini.getNumber("port");
    const rate: f64 = try ini.getFloat("rate");
    const name: []const u8 = try ini.getString("name");
    const timeout: i64 = try ini.getNumber("server.timeout");
```

- 支持通过点号语法访问 `Section` 中的配置项，如`ini.getString('server.timeout')`。
- 当`key`不存在时，`getBoolean`、`getNumber`、`getBoolean`、`getFloat`总是返回空，不会触发错误。因此最佳实践是，总是指定为配置项指定默认值。或者通过`hasItem`方法来判断是否存在指定的key

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

**重点**

- 默认情况下，`zini`不会加载注释内容，并且在保存时可以保持注释不会丢失。
- 可以在初始化时，通过`ini.options`的`LoadDescription`标识来指定是否加载注释，然后可以`item.description`访问注释内容。

```zig
  const allocator = testing.allocator;

    const content =
        \\ # 这是description注释
        \\ # @title 配置标题
        \\ key1 = value1
        \\ key2 = value2
    ;

    // 加载description
    var ini1 = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini1.deinit();

    const item = ini1.getItem("key1").?;
    try testing.expect(item.description != null);
```

### 元数据支持

`zini` 支持在注释中使用`# @<名称> <值>`为配置项额外添加标题、描述、默认值和选择项等元数据。

**支持的元数据：**

- **`@title`** - 配置项的标题
- **`@default`** - 配置项的默认值（用于 reset() 方法）
- **`@choices`** - 配置项的可选值列表（逗号分隔）

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
        std.debug.print("Title: {s}\n", item.title);
        std.debug.print("Default: {s}\n", item.default);
        std.debug.print("Choices: {s}\n", item.choices);
        std.debug.print("Description: {s}\n", item.description);
    }
}
```

- **注意**：默认情况下，`description`不加载以节约内存，但是保存时会保留注释内容。

### 多行字符串支持

支持 `Markdown` 风格的多行字符串，当值是多行字符串时，可以用三个反引号包裹。

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

### 默认值

作为配置文件，推荐所有配置项均应提供默认值。`zini`支持通过以下方式来提供默认值。

- **代码指定**

直接在代码中指定每个配置项的默认值。

```zig
 const allocator = std.heap.page_allocator;

    // 从配置数组初始化（推荐提供default）
    const items = [_]Ini.Item{
        .{ .key = "port", .default = "8080" },
        .{ .key = "debug", .default = "false" },
        .{ .key = "host", .default = "localhost" },
        .{ .key = "server.timeout", .default = "3000" },
    };
    var ini = try Ini.init(allocator, &items);
    defer ini.deinit();
    // 再从文件加载（覆盖配置，但保留 default 值）
    try ini.load("config.ini");
```

- **通过元数据指定**

在配置项前的注释中通过`@default`元数据指定。

```ini
# 服务器监听端口
# @title 监听端口
# @default 8080
port = 9000
```

- **单独指定**

```zig
var item = ini.getItem("server.timeout")
item.default="9000"
```

**注意**：

- 当执行`ini.save`时，会将`@default`写入到ini文件中，以便加载时能自动生效。

### 配置重置功能

当配置项指定了默认值后，可以通过`reset`方法进行重置，快速恢复所有配置为默认值。

**基本用法：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ini = Ini.default(allocator);
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

### 值选项验证

使用 `@choices` 元数据可以限制配置项的可选值范围，确保配置值在预期的选项列表中。

**功能特性：**

- **自动验证** - zini 自动验证配置值是否在 `@choices` 列表中
- **错误提示** - 无效值会触发验证错误，帮助发现配置问题
- **类型安全** - 配置时即进行验证，而非运行时才发现错误

**INI 文件示例：**

```ini
# @choices admin,user,guest
role = admin

# @choices debug,info,warn,error
log_level = error

# @choices localhost,127.0.0.1,192.168.1.1
db_host = localhost

# @choices small,medium,large
instance_type = medium
```

**Zig 代码示例：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 有效值：验证通过
    try ini.set("role", "admin");

    // 无效值：触发验证错误
    // try ini.set("role", "root"); // 错误：不在 choices 列表中
}

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

### 数据校验

`zini` 提供了极简高效的验证框架，支持自定义验证规则，确保配置值的正确性。

**验证器类型定义：**

```zig
/// 验证器函数指针类型
pub const Validator = *const fn (value: []const u8, item: *const Item) bool;
```

**添加验证器的两种方式：**

**1. 添加全局验证器（推荐用于通用规则）：**

```zig
// 定义验证器函数
fn portRangeValidator(value: []const u8, item: *const Item) bool {
    _ = item;
    const port = std.fmt.parseInt(u16, value, 10) catch return false;
    return port >= 1024 and port <= 65535;
}

// 添加到全局验证器注册表
try ini.validators.add("port_range", portRangeValidator);

// 添加全局验证器（对所有配置项生效）
try ini.validators.add("*", globalValidator);
```

**2. 为特定配置项添加验证器：**

```zig
// 定义端口范围验证器
fn portRangeValidator(value: []const u8, item: *const Item) bool {
    _ = item;
    const port = std.fmt.parseInt(u16, value, 10) catch return false;
    return port >= 1024 and port <= 65535;
}

// 注册验证器
try ini.validators.add("port_range", portRangeValidator);

// 为特定配置项指定验证器
try ini.set("port", "8080");
if (ini.getItem("port")) |item| {
    try item.addValidator("port_range");
}

// 或使用便捷方法：验证器自动注册
if (ini.getItem("port")) |item| {
    try item.addValidator("port_range", portRangeValidator);
}
```

**完整使用示例：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 定义验证器
    fn portRangeValidator(value: []const u8, item: *const Item) bool {
        _ = item;
        const port = std.fmt.parseInt(u16, value, 10) catch return false;
        return port >= 1024 and port <= 65535;
    }

    // 注册全局验证器
    try ini.validators.add("port_range", portRangeValidator);

    // 为配置项添加验证器
    try ini.set("port", "8080");
    if (ini.getItem("port")) |item| {
        try item.addValidator("port_range");
    }
    // 验证自动执行
    try ini.set("port", "9000");  // ✅ 验证通过
    try ini.set("port", "100");   // ❌ 验证失败，抛出错误
}
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

    var ini = Ini.default(allocator);
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
    if (ini.getItem("log_level")) |item| {
        item.converter = &converter;
    }
}
```

## API

### Ini 结构体

```zig
/// 创建空 INI 解析器（不加载 description）
pub fn default(allocator: Allocator) Ini

/// 创建带选项的 INI 解析器
pub fn initWithOptions(allocator: Allocator, options: IniOptions) Ini

/// 从 Items 数组初始化（推荐使用，支持自动类型推断）
pub fn init(allocator: Allocator, items: []const Item) !Ini

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

/// 添加配置项（支持自动类型推断）
/// 当 item.datatype 为 null 或 .string 时，自动根据值内容推断类型
/// 显式指定其他类型（.boolean、.number、.float）时保留该类型
pub fn addItem(self: *Ini, key: []const u8, item: Item) !void

/// 遍历指定范围的 Item
/// section: 迭代范围（"*"=全部，""=全局，"section_name"=指定section）
/// callback: 回调函数，接收 Item 指针和 section 名称（null 表示全局）
pub fn forEach(self: *const Ini, section: []const u8, callback: anytype) void

```

## 许可证

MIT License
