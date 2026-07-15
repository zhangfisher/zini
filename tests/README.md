# Tests 目录使用指南

## 快速开始

### 推荐方式：直接使用 zig test

```bash
# 从项目根目录运行
zig test tests/auto_type_inference.zig
zig test tests/path_syntax.zig
zig test tests/types.zig

# 或从 tests 目录运行
cd tests
zig test path_syntax.zig
```

## 所有测试文件

1. **auto_type_inference.zig** - 自动类型推断测试
2. **benchmarks.zig** - 性能基准测试
3. **complete_verification.zig** - 完整功能验证测试
4. **datatype_consistency.zig** - 数据类型一致性测试
5. **default_value_fallback.zig** - 默认值回退功能测试
6. **documentation.zig** - 文档注释功能测试
7. **getSchema_section_syntax.zig** - getItem 方法 section.key 语法测试
8. **getSchema_test.zig** - getItem 方法基础测试
9. **ini_options.zig** - IniOptions 配置测试
10. **metadata_system.zig** - 元数据系统测试
11. **multiline_strings.zig** - 多行字符串功能测试
12. **path_syntax.zig** - 路径语法功能测试
13. **reset_functionality.zig** - reset 方法功能测试
14. **schema_iteration.zig** - forEach 遍历功能测试
15. **type_annotation_set.zig** - 类型标注功能测试
16. **types.zig** - 类型系统基础测试

## 使用构建系统

### 方法 1: 从 tests 目录使用 build.zig

```bash
cd tests
zig build test              # 运行所有测试
zig build types            # 运行单个测试
zig build path_syntax       # 运行 path_syntax 测试
```

### 方法 2: 从项目根目录使用

```bash
# 在项目根目录创建一个引用
zig build -Dtest_dir=types
```

## 运行所有测试

### 使用批处理文件（推荐）

**Windows 用户：**
```cmd
# 从项目根目录
run-tests-simple.bat
```

**Linux/macOS 用户：**
```bash
# 从项目根目录
./run-tests.sh
```

### 使用 Zig 命令

**Windows:**
```cmd
for %%f in (tests\*.zig) do zig test "%%f"
```

**Linux/macOS:**
```bash
for f in tests/*.zig; do zig test "$f"; done
```

## 单个测试示例

```bash
# 测试类型推断
zig test tests/auto_type_inference.zig

# 测试路径语法
zig test tests/path_syntax.zig

# 测试多行字符串
zig test tests/multiline_strings.zig

# 测试元数据
zig test tests/metadata_system.zig
```

## 预期结果

所有测试应该显示类似以下输出：

```
Test [1] test name...
Test [1] test name... PASSED
```

当前状态：**✅ 77/77 测试通过**

## 故障排除

### 问题：找不到导入模块
**错误：** `import "zini"` 失败

**解决方案：**
1. 确保从项目根目录运行
2. 或使用 `--main-pkg-path` 指定根目录：
   ```bash
   zig test tests/types.zig --main-pkg-path .
   ```

### 问题：编译错误
**解决方案：**
1. 检查 Zig 版本：`zig version`（需要 0.16.0+）
2. 清理缓存：删除 `.zig-cache` 目录

### 问题：跨平台路径
**解决方案：**
- Windows: 使用反斜杠 `\` 或正斜杠 `/`
- Linux/macOS: 使用正斜杠 `/`

## CI/CD 集成

```yaml
# GitHub Actions 示例
- name: Run tests
  run: |
    zig test tests/auto_type_inference.zig
    zig test tests/path_syntax.zig
    zig test tests/types.zig
```

---

**提示**: 最简单的方法是直接运行 `zig test tests/<filename>.zig`
