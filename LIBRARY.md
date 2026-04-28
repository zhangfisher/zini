# zini 库使用指南

## 作为 Zig 依赖使用

### 方法 1: 从本地路径引用

在你的项目 `build.zig` 中添加：

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 添加 zini 依赖
    const zini = b.dependency("zini", .{
        .target = target,
        .optimize = optimize,
    });

    // 获取 zini 模块
    const zini_module = zini.module("zini");

    // 创建你的可执行文件并导入模块
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zini", zini_module);

    b.installArtifact(exe);
}
```

在你的 `build.zig.zon` 中添加：

```zig
.{
    .name = "myapp",
    .version = "0.1.0",
    .dependencies = .{
        .zini = .{
            // 本地路径
            .path = "../path/to/zini",
        },
    },
}
```

### 方法 2: 从 Git 仓库引用

```zig
.{
    .name = "myapp",
    .version = "0.1.0",
    .dependencies = .{
        .zini = .{
            .url = "https://github.com/yourusername/zini/archive/main.tar.gz",
            .hash = "1220...", // 运行 zig build 获取正确的 hash
        },
    },
}
```

**获取正确的 hash：**

```bash
# 在项目目录中运行
zig build
# Zig 会提示 hash 不匹配并给出正确的 hash
```

### 方法 3: 使用 zig fetch

```bash
# 获取并添加依赖
zig fetch --save https://github.com/yourusername/zini/archive/main.tar.gz
```

## 使用示例

### 基础使用

在你的 Zig 代码中：

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 创建 INI 实例
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 加载配置文件
    try ini.load("config.ini");

    // 读取值
    const app_name = ini.get("app_name").?;
    const port = try ini.getU16("port");
    const debug = try ini.getBool("debug");

    std.debug.print("App: {s}, Port: {}, Debug: {}\n", .{app_name, port, debug});
}
```

### 读取 Section

```zig
// 读取 section 中的值
const db_host = ini.getSection("database", "host").?;
const db_port = try ini.getSectionU16("database", "port");

// 或者先获取 section
if (ini.getSectionPtr("database")) |section| {
    const host = section.get("host").?;
    const port = try section.getU16("port");
    std.debug.print("Database: {s}:{}\n", .{host, port});
}
```

### 写入配置

```zig
// 设置全局值
try ini.set("app_name", "myapp");
try ini.set("version", "1.0.0");

// 设置 section 值
try ini.setSection("database", "host", "localhost");
try ini.setSection("database", "port", "5432");

// 保存到文件
try ini.save("output.ini");
```

### 完整示例

```zig
const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 创建配置
    try ini.set("debug", "true");
    try ini.setSection("database", "host", "localhost");
    try ini.setSection("database", "port", "5432");
    try ini.save("config.ini");

    // 读取配置
    var ini2 = Ini.init(allocator);
    defer ini2.deinit();
    try ini2.load("config.ini");

    const debug = try ini2.getBool("debug");
    const db_host = ini2.getSection("database", "host").?;
    const db_port = try ini2.getSectionU16("database", "port");

    std.debug.print("Debug: {}, DB: {s}:{}\n", .{debug, db_host, db_port});
}
```

## 发布到包仓库

### 准备发布

1. **确保所有文件都在 build.zig.zon 的 paths 中**
   ```zig
   .paths = .{
       "build.zig",
       "build.zig.zon",
       "src",
       "LICENSE",
       "README.md",
   }
   ```

2. **推送到 GitHub**
   ```bash
   git add .
   git commit -m "Release version 0.0.1"
   git tag v0.0.1
   git push origin main --tags
   ```

3. **创建 Release tarball URL**
   - GitHub: `https://github.com/yourusername/zini/archive/refs/tags/v0.0.1.tar.gz`
   - 使用 `archive/refs/tags/` 路径确保获取特定版本

### 用户安装

用户可以在他们的 `build.zig.zon` 中使用：

```zig
.dependencies = .{
    .zini = .{
        .url = "https://github.com/yourusername/zini/archive/refs/tags/v0.0.1.tar.gz",
        .hash = "1220...", // 用户第一次运行时获取
    },
}
```

## API 参考

### 主要类型

- `Ini` - INI 解析器主类
- `Section` - INI section
- `Entry` - 键值对条目
- `Error` - 错误类型

### 主要方法

**Ini 类:**
- `init(allocator)` - 创建实例
- `deinit()` - 释放资源
- `load(path)` - 从文件加载
- `loadFromString(content)` - 从字符串加载
- `save(path)` - 保存到文件
- `get(key)` - 获取全局值
- `getSection(section, key)` - 获取 section 值
- `set(key, value)` - 设置全局值
- `setSection(section, key, value)` - 设置 section 值

**类型化的 getter:**
- `getBool(key)`, `getSectionBool(section, key)`
- `getU8/getU16/getU32/getU64(key)`
- `getI8/getI16/getI32/getI64(key)`
- `getF32/getF64(key)`
- `getInt(key)` (i64)
- `getFloat(key)` (f64)

## 故障排除

### Hash 不匹配

```
error: hash mismatch: expected ..., found ...
```

**解决方法:**
1. 删除 `.hash` 字段
2. 运行 `zig build`
3. Zig 会计算并显示正确的 hash
4. 将正确的 hash 添加回 `build.zig.zon`

### 模块未找到

```
error: module 'zini' not found
```

**解决方法:**
- 确保 `build.zig` 中正确配置了模块导入
- 检查 `zini.module("zini")` 名称是否匹配
- 确保依赖已正确添加到 `build.zig.zon`

### 编译错误

```
error: root_source_file not found
```

**解决方法:**
- 确保 `src/root.zig` 文件存在
- 检查 build.zig 中的路径是否正确

## 版本兼容性

- **最低 Zig 版本**: 0.16.0
- **推荐 Zig 版本**: 0.16.0 或更高

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件
