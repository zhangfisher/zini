# zini

一个简洁高效、类型安全的 Zig 语言 INI 配置文件解析库，支持自动类型推断、多行字符串和丰富的元数据支持。

**仅 4 种基本类型，简洁 API，学习成本低，完美集成到任何 Zig 项目。**

---

## 关键特性

- **🎯 类型安全** - 仅 4 种基本类型（string、number、boolean、float），自动类型推断
- **🚀 简洁 API** - 只需 4 个 getter 方法，学习成本极低
- **✨ 智能推断** - 根据值内容自动识别类型，无需手动标注
- **📝 多行字符串** - 支持 Markdown 风格的多行文本
- **🏷️ 丰富元数据** - 支持 title、description、default、choices、enum
- **🔄 配置重置** - 支持 reset() 方法一键恢复默认值
- **🎯 精确操作** - 支持 getSection() 方法操作特定 section
- **💾 内存优化** - 可选的描述加载，节省内存占用
- **🔧 完整 INI 支持** - Sections、全局键值对、注释
- **🛡️ 内存安全** - 完善的内存管理，无泄漏
- **⚡ 零依赖** - 仅依赖 Zig 标准库
- **📈 高性能** - 高效的解析和序列化

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

### C 语言集成

zini 提供了完整的 C API，可以从 C/C++ 项目中使用。

**编译 C 库：**

```bash
# 编译静态和动态库
zig build lib

# 生成 C 头文件
zig build header
```

**生成的文件：**
- `zig-out/lib/libzini.a` - 静态库
- `zig-out/lib/libzini.so` / `.dll` / `.dylib` - 动态库
- `zig-out/include/zini.h` - C 头文件

**C 语言使用示例：**

```c
#include "zini.h"
#include <stdio.h>

int main() {
    // 创建 INI 解析器
    zini_t* ini = zini_new();
    if (!ini) {
        fprintf(stderr, "Failed to create INI parser\n");
        return 1;
    }

    // 从文件加载
    if (zini_load_file(ini, "config.ini") != ZINI_SUCCESS) {
        fprintf(stderr, "Failed to load config.ini\n");
        zini_free(ini);
        return 1;
    }

    // 读取配置 - 使用 4 个基本 getter 方法
    const char* app_name = zini_get_string(ini, "app_name");
    
    int64_t port;
    zini_get_number(ini, "port", &port);
    
    double rate;
    zini_get_float(ini, "rate", &rate);
    
    bool enabled;
    zini_get_boolean(ini, "enabled", &enabled);

    printf("App: %s, Port: %lld, Rate: %.2f, Enabled: %d\n", 
           app_name, port, rate, enabled);

    // 清理
    zini_free(ini);
    return 0;
}
```

**编译 C 程序：**

```bash
gcc -o myapp main.c -I./zig-out/include -L./zig-out/lib -lzini
```

---

## 指南

### 自动类型推断

zini 可以根据值的内容自动识别类型，无需任何手动标注。

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

```ini
# 电子邮件模板
email_template = ```
Dear {{name}},

Thank you for your purchase!

Best regards,
The Team
```

# 服务条款
terms_of_service = ```
1. 服务条款第一条款
2. 服务条款第二条款
3. 服务条款第三条款
```
```

**Zig 代码示例：**

```zig
const email_template = try ini.getString("email_template");
const terms = try ini.getString("terms_of_service");

// 字符串会保持原始的换行和格式
std.debug.print("Email:\n{s}\n", .{email_template});
std.debug.print("Terms:\n{s}\n", .{terms});
```

### 元数据支持

zini 支持丰富的元数据功能，可以为配置项添加标题、描述、默认值、选择项、枚举值和显示顺序。

**支持的元数据：**

- **普通注释** - 配置项的描述信息（需要启用描述加载）
- **`@title`** - 配置项的标题
- **`@default`** - 配置项的默认值（用于 reset() 方法）
- **`@choices`** - 配置项的可选值列表（逗号分隔）
- **`@enum`** - 配置项的枚举值列表（逗号分隔）

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
    if (ini.getSchema("timeout")) |schema| {
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

支持两种独立注释风格（不支持行尾注释）。

**INI 文件示例：**

```ini
# 这是井号注释
; 这是分号注释

[config]
# 全局配置项
timeout = 30

; 数据库配置
; host = localhost
port = 5432
```

**注意事项：**
- ✅ 支持 `#` 和 `;` 独立注释行
- ❌ 目前不支持 `//` 行尾注释
- ✅ 引号内的 `//` 会被视为字符串内容

### Section 操作

支持标准的 INI Section 语法，通过点号语法访问 Section 中的配置项。

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
_ = ini.remove("database.old_key");
```

### INI 格式规则

支持的完整 INI 语法：

```ini
# 全局键值对
global_key = global_value

# Section
[section_name]
key1 = value1
key2 = "quoted value"

# 多行字符串
long_text = ```
这是一个多行字符串
可以包含多行内容
```

# 注释（只支持独立注释行）
; 这是单行注释
# 这也是单行注释
```

**格式规则：**
- **注释符号**：`#` 和 `;`（仅支持独立注释行，不支持行尾注释）
- **Section 语法**：`[section_name]`
- **键值分隔符**：`=`
- **引号字符串**：支持 `"` 和 `'`
- **多行字符串**：Markdown 风格的 ```...```
- **数组**：`[value1, value2, ...]`

---

## API

### 核心 API

#### Ini 结构体

```zig
pub const Ini = struct {
    /// 创建默认 INI 解析器（不加载 description）
    pub fn init(allocator: Allocator) Ini

    /// 创建带选项的 INI 解析器
    pub fn initWithOptions(allocator: Allocator, options: IniOptions) Ini

    /// 释放资源
    pub fn deinit(self: *Ini) void
}
```

#### IniOptions

```zig
pub const IniOptions = struct {
    /// 加载 description 注释（默认关闭）
    pub const LoadDescription: u32 = 1;

    /// 创建加载 description 的选项
    pub fn withDescription() IniOptions
};
```

### 配置操作 API

#### 基本操作

```zig
/// 设置配置值（支持 <section>.<key> 语法）
pub fn set(self: *Ini, key: []const u8, value: []const u8) !void

/// 获取原始字符串值
pub fn get(self: *const Ini, key: []const u8) ?[]const u8

/// 检查键是否存在
pub fn has(self: *const Ini, key: []const u8) bool

/// 删除键值对
pub fn remove(self: *Ini, key: []const u8) bool
```

#### 4 种基本类型 Getter

```zig
/// 获取字符串值
pub fn getString(self: *const Ini, key: []const u8) ![]const u8

/// 获取整数值 (i64)
pub fn getNumber(self: *const Ini, key: []const u8) !i64

/// 获取浮点数值 (f64)
pub fn getFloat(self: *const Ini, key: []const u8) !f64

/// 获取布尔值
pub fn getBoolean(self: *const Ini, key: []const u8) !bool
```

#### Schema 操作

```zig
/// 获取完整的 Schema 信息（包含元数据）
pub fn getSchema(self: *const Ini, key: []const u8) ?Schema
```

#### Schema 结构体

```zig
pub const Schema = struct {
    key: []const u8,              // 键名
    value: []const u8,            // 值
    datatype: DataType,           // 数据类型
    title: ?[]const u8,           // 标题（@title）
    description: ?[]const u8,     // 描述（普通注释）
    default: ?[]const u8,         // 默认值（@default）
    choices: ?[]const u8,         // 选择项（@choices）
};
```

### 文件操作 API

```zig
/// 从文件加载配置
pub fn load(self: *Ini, path: []const u8) !void

/// 从字符串加载配置
pub fn loadFromString(self: *Ini, content: []const u8) !void

/// 保存到文件
pub fn save(self: *Ini, path: []const u8) !void

/// 保存为字符串
pub fn saveToString(self: *Ini, allocator: Allocator) ![]const u8
```

### 高级操作 API

```zig
/// 重置所有配置项为默认值
/// 遍历所有全局 schemas 和 sections 中的 schemas，
/// 如果 schema.default 不为 null，则将 default 值复制到 value
pub fn reset(self: *Ini) !void

/// 获取指定 section 的 Ini 对象
/// 返回 section 的指针，如果不存在则返回 null
pub fn getSection(self: *Ini, section_name: []const u8) ?*Ini
```

### DataType 枚举

```zig
pub const DataType = enum(u8) {
    string = 0,    // 字符串类型 - []const u8
    boolean = 1,   // 布尔类型 - bool
    number = 2,    // 整数类型 - i64
    float = 3,     // 浮点类型 - f64
};
```

---

## 示例

### 完整的应用配置示例

这是一个展示 zini 所有主要功能的完整示例。

**config.ini 文件：**

```ini
# 应用程序配置文件

# 应用程序名称
# @title 应用名称
# @default MyApp
app_name = MyApp

# 服务器配置
# @title 监听端口
# @default 8080
port = 9000

# 数据库配置
[database]
# 数据库主机地址
host = localhost

# 数据库端口
# @title 数据库端口
# @default 5432
port = 5432

# 连接超时时间（秒）
# @title 连接超时
# @default 30
# @choices 10,20,30,60,120
timeout = 60

# 功能开关
debug = true
enable_logging = false

# 电子邮件模板
email_template = ```
Dear {{name}},

Thank you for registering at {{app_name}}!

Your account has been created successfully.

Best regards,
The {{app_name}} Team
```

**Zig 代码（main.zig）：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 启用描述加载以获取完整元数据
    var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini.deinit();

    // 从文件加载配置
    try ini.load("config.ini");

    // 1. 基本配置读取
    std.debug.print("\n=== 基本信息 ===\n", .{});
    
    const app_name = try ini.getString("app_name");
    const port = try ini.getNumber("port");
    const debug = try ini.getBoolean("debug");
    
    std.debug.print("应用名称: {s}\n", .{app_name});
    std.debug.print("监听端口: {}\n", .{port});
    std.debug.print("调试模式: {}\n", .{debug});

    // 2. Section 配置读取
    std.debug.print("\n=== 数据库配置 ===\n", .{});
    
    const db_host = try ini.getString("database.host");
    const db_port = try ini.getNumber("database.port");
    const db_timeout = try ini.getNumber("database.timeout");
    
    std.debug.print("数据库地址: {s}\n", .{db_host});
    std.debug.print("数据库端口: {}\n", .{db_port});
    std.debug.print("连接超时: {} 秒\n", .{db_timeout});

    // 3. 元数据读取
    std.debug.print("\n=== 配置元数据 ===\n", .{});
    
    if (ini.getSchema("database.timeout")) |schema| {
        std.debug.print("\n[database.timeout] 元数据:\n", .{});
        
        if (schema.title) |title| {
            std.debug.print("  标题: {s}\n", .{title});
        }
        
        if (schema.description) |desc| {
            std.debug.print("  描述: {s}\n", .{desc});
        }
        
        if (schema.default) |default| {
            std.debug.print("  默认值: {s}\n", .{default});
        }
        
        if (schema.choices) |choices| {
            std.debug.print("  可选值: {s}\n", .{choices});
        }
        
        std.debug.print("  当前值: {s}\n", .{schema.value});
        std.debug.print("  数据类型: {}\n", .{schema.datatype});
    }

    // 4. 多行字符串读取
    std.debug.print("\n=== 电子邮件模板 ===\n", .{});
    
    const email_template = try ini.getString("email_template");
    std.debug.print("{s}\n", .{email_template});

    // 5. 配置修改
    std.debug.print("\n=== 动态修改配置 ===\n", .{});
    
    try ini.set("database.host", "192.168.1.100");
    try ini.set("database.port", "3306");
    
    std.debug.print("数据库地址已更新为: {s}\n", .{try ini.getString("database.host")});
    std.debug.print("数据库端口已更新为: {}\n", .{try ini.getNumber("database.port")});

    // 6. 保存修改后的配置
    std.debug.print("\n=== 保存配置 ===\n", .{});
    
    const updated_config = try ini.saveToString(allocator);
    defer allocator.free(updated_config);
    
    std.debug.print("配置已更新，共 {} 字节\n", .{updated_config.len});

    // 7. 配置重置功能
    std.debug.print("\n=== 配置重置功能 ===\n", .{});
    
    // 重置所有配置为默认值
    try ini.reset();
    
    std.debug.print("配置已重置为默认值\n", .{});
    std.debug.print("port: {} (默认值)\n", .{try ini.getNumber("port")});
    std.debug.print("database.timeout: {} (默认值)\n", .{try ini.getNumber("database.timeout")});

    // 8. 操作特定 section
    std.debug.print("\n=== 操作特定 Section ===\n", .{});
    
    // 获取 database section 并重置
    if (ini.getSection("database")) |db_section| {
        try db_section.reset();
        std.debug.print("database section 已重置\n", .{});
    }
    
    // 修改特定 section 的配置
    try ini.set("database.host", "db.example.com");
    std.debug.print("database.host 已更新\n", .{});

    std.debug.print("\n=== 配置加载成功！===\n", .{});
}
```

**运行示例：**

```bash
# 编译
zig build-exe main.zig --mod zini:zini

# 运行
./main
```

**预期输出：**

```
=== 基本信息 ===
应用名称: MyApp
监听端口: 9000
调试模式: true

=== 数据库配置 ===
数据库地址: localhost
数据库端口: 5432
连接超时: 60 秒

=== 配置元数据 ===

[database.timeout] 元数据:
  标题: 连接超时
  描述: 连接超时时间（秒）
  默认值: 30
  可选值: 10,20,30,60,120
  当前值: 60
  数据类型: DataType.number

=== 电子邮件模板 ===
Dear {{name}},

Thank you for registering at {{app_name}}!

Your account has been created successfully.

Best regards,
The {{app_name}} Team

=== 动态修改配置 ===
数据库地址已更新为: 192.168.1.100
数据库端口已更新为: 3306

=== 保存配置 ===
配置已更新，共 456 字节

=== 配置重置功能 ===
配置已重置为默认值
port: 8080 (默认值)
database.timeout: 30 (默认值)

=== 操作特定 Section ===
database section 已重置
database.host 已更新

=== 配置加载成功！===
```

### 配置重置功能

zini 提供了强大的配置重置功能，可以快速恢复所有配置为默认值。

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

**输出：**
```
重置前:
  port: 9000
  host: remotehost
  debug: false

重置后:
  port: 8080
  host: localhost
  debug: true
```

### Section 操作

支持对特定 section 进行精确操作。

**基本用法：**

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\[database]
        \\# @default localhost
        \\host = remotehost
        \\# @default 5432
        \\port = 3306
        \\
        \\[server]
        \\# @default 8080
        \\port = 9000
    ;

    try ini.loadFromString(content);

    // 只重置 database section
    if (ini.getSection("database")) |db_section| {
        try db_section.reset();
        std.debug.print("database section 已重置\n", .{});
        std.debug.print("  database.host: {s}\n", .{try db_section.getString("host")});
        std.debug.print("  database.port: {}\n", .{try db_section.getNumber("port")});
    }

    // server section 保持不变
    const server_port = try ini.getNumber("server.port");
    std.debug.print("server.port 保持不变: {}\n", .{server_port});
}
```

**输出：**
```
database section 已重置
  database.host: localhost
  database.port: 5432
server.port 保持不变: 9000
```

---

## 设计原则

此库严格遵循工程最佳实践：

- **KISS** - 保持简单直观，仅 4 种类型，4 个 getter 方法
- **DRY** - 消除代码重复，统一的类型推断系统
- **SOLID** - 单一职责、开放封闭原则
- **YAGNI** - 只实现必要功能，避免过度设计

---

## 许可证

MIT License

---

## 贡献

欢迎提交 Issue 和 Pull Request！

---

## 相关资源

- [Zig 官方文档](https://ziglang.org/documentation/master/)
- [Zig 0.16.0 发布说明](https://ziglang.org/download/0.16.0/release-notes.html)
- [INI 文件格式规范](https://en.wikipedia.org/wiki/INI_file)
