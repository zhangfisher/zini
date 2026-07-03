# zini

一个简洁高效、类型安全的 Zig 语言 INI 配置文件解析库，支持自动类型推断、显式类型标注和类型安全的值访问。

## ✨ 主要功能和特性

### 🎯 核心特性

- **类型安全** - 自动类型推断 + 显式类型标注 + 类型安全的值访问
- **简单的 API 设计** - 直观的接口，易于使用
- **完整的 INI 支持** - Sections、全局键值对、注释、数组
- **内存安全** - 完善的内存管理，无泄漏
- **零依赖** - 仅依赖 Zig 标准库
- **高性能** - 高效的解析和序列化

### 🏷️ 类型系统

**支持的类型：**
- 布尔值：`bool`
- 整数：`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `int`
- 浮点数：`f32`, `f64`, `float`
- 字符串：`string`
- 数组：`array`

**类型推断：**
```ini
# 自动推断类型
debug = true          # bool
port = 8080           # int
timeout = 30.5        # float
name = "myapp"        # string
ports = [80, 443]     # array
```

**显式类型标注：**
```ini
# 显式指定类型
count:u32 = 100
price:f64 = 99.99
enabled:bool = true
```

### 🔧 高级特性

- **位标识合并** - 自动合并 `key.subkey` 格式的位标识
- **数组支持** - 支持数组值和类型转换
- **行尾注释** - 支持 `//` 和 `#` 行尾注释
- **多格式数字** - 支持十进制、二进制 (`0b`)、十六进制 (`0x`)

## 📦 安装

### 通过 Zig 包管理器安装（推荐）

**在你的项目 `build.zig.zon` 中添加依赖：**

```zig
.dependencies = .{
    .zini = .{
        .url = "https://github.com/zhangfisher/zini/archive/master.tar.gz",
        .hash = "1220...", // 使用 zig build 命令获取正确的 hash
    }
}
```

**在你的项目 `build.zig` 中导入模块：**

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

### 从源码安装

**克隆仓库：**

```bash
git clone https://github.com/zhangfisher/zini.git
cd zini
```

**验证安装：**

```bash
# 运行测试
zig build test

# 运行示例
zig build run

# 查看所有可用命令
zig build --list-steps
```

**本地项目引用：**

如果你在本地开发或想使用本地副本：

```zig
// 在 build.zig.zon 中
.dependencies = .{
    .zini = .{
        .path = "../zini",  // 相对路径
    },
}
```

### 系统要求

- **最低 Zig 版本**: 0.16.0
- **推荐 Zig 版本**: 0.16.0 或更高
- **操作系统**: Windows, Linux, macOS
- **架构**: x86_64, ARM64, ARM32

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

#### 编译 C 库

```bash
# 编译静态和动态库
zig build lib

# 生成 C 头文件
zig build header
```

生成的文件：
- `zig-out/lib/libzini.a` - 静态库
- `zig-out/lib/libzini.so` / `.dll` / `.dylib` - 动态库
- `zig-out/include/zini.h` - C 头文件

#### 在 C 项目中使用

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

    // 读取配置
    const char* app_name = zini_get(ini, "app_name");
    int64_t port;
    zini_get_int(ini, "port", &port);

    printf("App: %s, Port: %lld\n", app_name, port);

    // 清理
    zini_free(ini);
    return 0;
}
```

**编译 C 程序：**

```bash
gcc -o myapp main.c -I./zig-out/include -L./zig-out/lib -lzini
```

### 从源码编译

```bash
# 克隆仓库
git clone https://github.com/yourusername/zini.git
cd zini

# 运行测试
zig build test

# 运行示例
zig build run

# 编译库
zig build install
```

## 🚀 快速开始

### 基础使用

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 创建 INI 配置
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 设置全局配置
    try ini.set("app_name", "myapp");
    try ini.set("version", "1.0.0");

    // 创建并设置 section
    try ini.setSection("database", "host", "localhost");
    try ini.setSection("database", "port", "5432");

    // 保存到文件
    try ini.save("config.ini");

    // 从文件加载
    var ini2 = Ini.init(allocator);
    defer ini2.deinit();
    try ini2.load("config.ini");

    // 读取配置
    const app_name = ini2.get("app_name").?;
    const db_host = ini2.getSection("database", "host").?;
}
```

### 生成的 INI 文件

```ini
app_name = myapp
version = 1.0.0

[database]
host = localhost
port = 5432
```

## 📚 使用指南

### 1. 自动类型推断

zini 可以自动推断值的类型：

```zig
var ini = Ini.init(allocator);
defer ini.deinit();

try ini.loadFromString(
    \\debug = true
    \\port = 8080
    \\timeout = 30.5
    \\name = myapp
);

// 读取时自动转换类型
const debug: bool = try ini.getBool("debug");
const port: u64 = try ini.getU64("port");
const timeout: f64 = try ini.getF64("timeout");
const name: []const u8 = ini.get("name").?;
```

### 2. 显式类型标注

使用 `key:type = value` 语法显式指定类型：

```ini
count:u32 = 100
price:f64 = 99.99
enabled:bool = true
```

```zig
// 解析时使用指定的类型
const entry = ini.getEntry("count").?;
std.debug.print("Type: {}\n", .{entry.datatype}); // u32
```

### 3. 数组支持

支持数组值的解析和访问：

```ini
ports = [80, 443, 8080]
allowed_ips = [192.168.1.1, 10.0.0.1]
```

```zig
// 获取数组
if (ini.getArray("ports")) |ports| {
    for (ports) |port_str| {
        const port = try std.fmt.parseInt(u16, port_str, 10);
        std.debug.print("Port: {}\n", .{port});
    }
}

// Section 数组
if (ini.getSectionArray("server", "ports")) |ports| {
    // ...
}
```

### 4. 位标识合并

自动合并 `key.subkey` 格式的位标识：

```ini
# 定义位标识
file.read = 1
file.write = 2
file.execute = 4

# 自动合并为 file = 7 (1 | 2 | 4)
```

```zig
// 访问合并后的值
const file_perms = try ini.getU8("file");
std.debug.print("File permissions: {}\n", .{file_perms}); // 7
```

### 5. 类型安全的值访问

使用类型化的 getter 方法确保类型安全：

```zig
// 布尔值
const debug = try ini.getBool("debug");

// 无符号整数
const port = try ini.getU16("port");
const count = try ini.getU32("count");

// 有符号整数
const offset = try ini.getI32("offset");

// 浮点数
const rate = try ini.getF64("rate");

// 通用方法
const value = try ini.getInt("key");    // i64
const num = try ini.getFloat("key");    // f64
```

### 6. Section 操作

```zig
// 检查 section 是否存在
if (ini.hasSection("database")) {
    // ...
}

// 获取 section 中的值
const db_host = ini.getSection("database", "host").?;
const db_port = try ini.getSectionU16("database", "port");

// 设置 section 中的值
try ini.setSection("database", "host", "192.168.1.1");

// 删除 section
_ = ini.removeSection("old_section");

// 获取或创建 section
const section = try ini.getOrCreateSection("new_section");
```

### 7. 注释支持

支持多种注释风格：

```ini
# 这是注释
; 这也是注释

key = value // 行尾注释

key2 = "value // not a comment" # 引号内的不是注释
```

### 8. 多格式数字

支持十进制、二进制、十六进制：

```ini
flags_dec = 255
flags_bin = 0b11111111
flags_hex = 0xFF
```

```zig
const flags = try ini.getU8("flags_dec");
std.debug.print("Flags: {}\n", .{flags}); // 255
```

## 📖 INI 格式支持

### 支持的语法

```ini
# 全局键值对
global_key = global_value

# Section
[section_name]
key1 = value1
key2 = "quoted value"

# 注释
; 这是单行注释
# 这也是单行注释

# 行尾注释
key = value // 行尾注释
```

### 格式规则

- **注释符号**：`#` 和 `;`
- **Section 语法**：`[section_name]`
- **键值分隔符**：`=`
- **引号字符串**：支持 `"` 和 `'`
- **数组**：`[value1, value2, ...]`
- **类型标注**：`key:type = value`

## 🧪 测试

```bash
# 运行所有测试
zig build test

# 运行特定测试
zig test src/ini.zig
zig test src/types.zig
```

## 📝 示例

查看 `examples/` 目录获取更多示例：

- `simple_types.zig` - 类型推断示例
- `type_annotation.zig` - 显式类型标注
- `arrays.zig` - 数组使用
- `bitmerge.zig` - 位标识合并
- `chinese_test.zig` - 中文支持

运行示例：

```bash
zig build run           # 主程序
zig build simple_types  # 类型示例
zig build arrays        # 数组示例
zig build bitmerge      # 位合并示例
```

## 🏗️ 设计原则

此库严格遵循工程最佳实践：

- **KISS** - 保持简单直观
- **DRY** - 消除代码重复
- **SOLID** - 单一职责、开放封闭原则
- **YAGNI** - 只实现必要功能

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 🔗 相关资源

- [Zig 官方文档](https://ziglang.org/documentation/master/)
- [Zig 0.16.0 发布说明](https://ziglang.org/download/0.16.0/release-notes.html)
- [INI 文件格式规范](https://en.wikipedia.org/wiki/INI_file)
