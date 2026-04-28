# zig-ini 库设计文档

## 概述

zig-ini 是一个专门为 Zig 语言设计的 INI 配置文件解析库，遵循 SOLID、KISS、DRY、YAGNI 等软件工程最佳实践。

## 核心设计原则

### 1. KISS (Keep It Simple, Stupid)
- **直观的 API**：`ini.set(key, value)`、`ini.get(key)` 等简单方法
- **单一数据结构**：主要只有 `Ini`、`Section`、`Entry` 三种类型
- **零学习曲线**：符合直觉的命名和使用方式

### 2. DRY (Don't Repeat Yourself)
- **统一的内存管理**：所有资源通过 `deinit()` 方法统一释放
- **复用的解析逻辑**：全局键值对和 Section 键值对使用相同的解析器
- **模块化设计**：解析器和序列化器功能独立，可复用

### 3. SOLID 原则

#### 单一职责原则 (S)
- `Ini`：负责整体配置管理
- `Section`：负责单个段管理
- `Entry`：负责键值对存储
- `Parser`：专门负责解析

#### 开放封闭原则 (O)
- 易于扩展新的解析特性
- 不需要修改现有代码

#### 里氏替换原则 (L)
- 所有结构体都支持相同的基本操作

#### 接口隔离原则 (I)
- 每个公共方法都有明确的单一用途
- 没有强制用户使用不需要的功能

#### 依赖倒置原则 (D)
- 依赖 `Allocator` 抽象而非具体实现

### 4. YAGNI (You Aren't Gonna Need It)
- 只实现 INI 格式的核心功能
- 不添加不常用的特性
- 保持代码库精简高效

## 核心特性

### 支持的 INI 功能

1. **全局键值对**
   ```ini
   app_name = MyApp
   version = 1.0.0
   ```

2. **配置段**
   ```ini
   [database]
   host = localhost
   port = 5432
   ```

3. **注释**
   ```ini
   # 这是注释
   ; 这也是注释
   ```

4. **引号字符串**
   ```ini
   message = "Hello World"
   path = 'C:\path\to\file'
   ```

### 内存安全

- **完善的资源管理**：所有分配的内存都有对应的释放
- **测试验证**：通过内存泄漏检测测试
- **错误处理**：明确的错误类型和错误传播

### 性能优化

- **高效的数据结构**：使用 `StringHashMap` 提供快速查找
- **预分配内存**：在序列化时预先计算所需内存大小
- **零拷贝解析**：尽可能避免不必要的内存分配

## API 设计

### 核心方法

```zig
// 创建和销毁
Ini.init(allocator) Ini
ini.deinit()

// 文件操作
ini.loadFile(path) Error!void
ini.saveFile(path) Error!void
ini.loadFromString(content) Error!void
ini.saveToString(allocator) []const u8

// 配置访问
ini.get(key) ?[]const u8
ini.getSection(section_name, key) ?[]const u8
ini.set(key, value) Error!void
ini.setSection(section_name, key, value) Error!void

// Section 操作
ini.hasSection(section_name) bool
ini.removeSection(section_name) bool
```

## 使用示例

### 基本使用

```zig
var ini = Ini.init(allocator);
defer ini.deinit();

try ini.set("app_name", "MyApp");
try ini.setSection("database", "host", "localhost");

const content = try ini.saveToString(allocator);
defer allocator.free(content);
```

### 高级用法

参见 `examples/advanced.zig` 获取更复杂的使用场景。

## 错误处理

库定义了明确的错误类型：

```zig
pub const Error = error{
    InvalidFormat,    // 格式错误
    EmptySectionName, // 空段名
    UnclosedQuote,    // 未闭合的引号
    FileNotFound,     // 文件未找到
    WriteError,       // 写入错误
    OutOfMemory,      // 内存不足
};
```

## 测试

库包含全面的测试覆盖：

- 基本解析测试
- 保存和加载循环测试
- 内存泄漏检测
- 边界情况测试

运行测试：
```bash
zig build test
```

## 未来扩展

可能的未来改进（按需添加）：

1. **多值支持**：一个键对应多个值
2. **类型转换**：自动转换为整数、布尔等类型
3. **默认值**：为缺失的键提供默认值
4. **环境变量替换**：支持 `${ENV_VAR}` 语法
5. **包含指令**：支持包含其他 INI 文件

## 贡献指南

欢迎贡献！请遵循：

1. 保持代码简洁
2. 添加相应测试
3. 更新文档
4. 遵循现有代码风格

## 许可证

MIT License
