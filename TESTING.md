# Zini 测试指南

## 测试文件

本项目包含 16 个测试文件，覆盖了 zini 库的所有功能：

### 测试文件列表

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

## 运行测试

### 方式 1: 快速测试（推荐）

使用预配置的批处理文件：

```bash
# 运行所有测试
quick-test.bat

# 运行所有测试（详细输出）
run-tests.bat

# 运行单个测试
run-single-test.bat types
```

### 方式 2: 使用 Zig 构建系统

```bash
# 运行所有测试
zig build test

# 运行特定测试文件
zig test tests/types.zig
```

### 方式 3: 直接运行测试文件

```bash
# 运行单个测试文件
zig test tests/path_syntax.zig
```

## 测试结果

当前测试状态：**77/77 测试通过** ✅

所有测试都涵盖了以下方面：
- ✅ 基本功能测试
- ✅ 类型推断和类型安全
- ✅ 路径语法支持
- ✅ 元数据和文档
- ✅ 多行字符串
- ✅ 验证器系统
- ✅ 错误处理
- ✅ 内存安全

## 批处理文件说明

### quick-test.bat
最简单的测试方式，使用 `zig build test` 运行所有测试。

### run-tests.bat
详细的测试运行器，逐个运行每个测试文件并显示详细结果。

**功能：**
- 显示每个测试的运行状态
- 统计通过和失败的测试数量
- 计算成功率
- 测量执行时间
- 返回适当的退出码

### run-single-test.bat
运行单个测试文件的便捷脚本。

**使用方法：**
```bash
run-single-test.bat <test_name>
```

**示例：**
```bash
run-single-test.bat types
run-single-test.bat path_syntax
run-single-test.bat auto_type_inference
```

## 持续集成

这些测试可以集成到 CI/CD 流程中：

```yaml
# GitHub Actions 示例
- name: Run tests
  run: quick-test.bat
```

## 故障排除

### 常见问题

1. **编码问题**
   - 如果看到乱码，确保终端支持 UTF-8 编码
   - Windows: `chcp 65001`

2. **路径问题**
   - 确保从项目根目录运行脚本
   - 或使用绝对路径

3. **Zig 版本**
   - 确保使用 Zig 0.16.0 或更高版本
   - 检查: `zig version`

## 添加新测试

要添加新的测试文件：

1. 在 `tests/` 目录创建新的 `.zig` 文件
2. 使用标准的 Zig 测试语法：
   ```zig
   test "测试名称" {
       // 测试代码
   }
   ```
3. 更新相关批处理文件中的测试列表
4. 运行测试验证功能

## 测试覆盖率

当前测试覆盖了以下模块：

- **类型系统**: 完整覆盖
- **解析器**: 完整覆盖  
- **序列化**: 完整覆盖
- **验证器**: 完整覆盖
- **元数据**: 完整覆盖
- **路径语法**: 完整覆盖
- **多行字符串**: 完整覆盖

---

**注意**: 所有测试都应该在提交前通过，确保代码质量和功能正确性。
