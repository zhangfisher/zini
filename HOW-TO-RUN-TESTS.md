# 如何运行 Zini 测试

## 推荐方式

### 1. 快速测试（最简单）⭐
```cmd
quick-test.bat
```
使用 Zig 构建系统运行所有测试，最快最简单。

### 2. 详细测试
```cmd
run-tests-simple.bat
```
逐个运行每个测试文件，显示详细进度和结果。**最可靠的版本**。

### 3. 循环版本
```cmd
run-tests.bat
```
使用批处理循环运行所有测试。

## 其他选项

### 运行单个测试
```cmd
run-single-test.bat types
run-single-test.bat path_syntax
run-single-test.bat auto_type_inference
```

### 使用 Zig 命令直接运行
```cmd
# 运行所有测试
zig build test

# 运行特定测试
zig test tests/types.zig
zig test tests/path_syntax.zig
```

## 测试脚本对比

| 脚本 | 特点 | 推荐用途 |
|------|------|----------|
| `quick-test.bat` | 最快，使用构建系统 | 日常开发 ⭐ |
| `run-tests-simple.bat` | 详细输出，逐个运行 | 调试和验证 |
| `run-tests.bat` | 循环版本 | 高级用户 |
| `run-single-test.bat` | 单个测试 | 快速测试特定功能 |

## 预期输出

### 成功运行
```
========================================
     Zini Quick Test Suite
========================================

[SUCCESS] All tests passed!
```

### 详细输出
```
========================================
     Zini Test Suite Runner
========================================

[1/16] Testing: auto_type_inference
    [PASS] auto_type_inference
[2/16] Testing: benchmarks
    [PASS] benchmarks
...
[16/16] Testing: types
    [PASS] types

========================================
           Test Summary
========================================

Total Tests:  16
Passed:       16
Failed:       0

SUCCESS: All tests passed!
```

## 故障排除

### 如果遇到问题：

1. **确保在项目根目录运行**
   ```cmd
   cd E:\Work\Code\zig\zini
   quick-test.bat
   ```

2. **检查 Zig 安装**
   ```cmd
   zig version
   ```
   需要版本 0.16.0 或更高

3. **清理缓存（如果遇到奇怪错误）**
   ```cmd
   rmdir /s /q .zig-cache
   quick-test.bat
   ```

4. **使用最简单的脚本**
   ```cmd
   quick-test.bat
   ```
   这个脚本最不容易出错

## 当前状态

✅ **77/77 测试通过**

所有测试文件都已更新到最新的 API：
- ✅ 正确的导入路径 (`@import("zini")`)
- ✅ 正确的类型名称 (`Item` 而不是 `Schema`)
- ✅ 正确的 DataType 枚举值 (`.number`, `.boolean`, `.float`, `.string`)
- ✅ 正确的 API 方法名

---

**提示**: 日常开发推荐使用 `quick-test.bat`，它最简单且最快！
