# 运行测试的推荐方法

## ⭐ 最推荐的方式

### 方法 1: 直接测试源码（最简单）
```cmd
zig test src/ini.zig
```
**优点：**
- ✅ 最简单直接
- ✅ 只测试当前平台
- ✅ 无跨平台执行错误
- ✅ 77/77 测试全部通过

### 方法 2: 使用构建系统
```cmd
zig build test
```
**注意：**
- 会为多个平台构建（Linux、Windows、ARM）
- 在 Windows 上会看到跨平台执行错误（正常现象）
- 核心测试仍然会通过（77/77）

## 其他测试方式

### 测试单个文件
```cmd
# 测试特定功能
zig test tests/types.zig
zig test tests/path_syntax.zig
```

### 使用快速脚本
```cmd
# 快速测试（推荐给不熟悉命令行的用户）
quick-test.bat
```

## 测试结果

当前测试状态：**✅ 77/77 测试通过**

所有测试涵盖：
- 类型系统和类型推断
- INI 解析和序列化
- 路径语法支持
- 元数据和文档
- 多行字符串
- 验证器系统
- 错误处理
- 内存安全

## 故障排除

### 问题：zig test src/ini.zig 编译错误
**解决：**
1. 检查 Zig 版本：`zig version`（需要 0.16.0+）
2. 清理缓存：删除 `.zig-cache` 目录

### 问题：zig build test 显示跨平台错误
**说明：**
- 这是正常现象
- build.zig 配置了多平台构建
- 当前平台的测试仍然会通过
- 可以忽略跨平台错误

### 问题：批处理脚本执行错误
**解决：**
1. 确保从项目根目录运行
2. 使用最简单的方法：`zig test src/ini.zig`

## CI/CD 集成

推荐在 CI/CD 中使用：

```yaml
# GitHub Actions
- name: Run tests
  run: zig test src/ini.zig

# 或使用构建系统
- name: Run tests  
  run: zig build test
```

## 总结

**对于大多数用户：**
```cmd
zig test src/ini.zig
```

这是最简单、最可靠的方法！

---

**提示**: `zig test src/ini.zig` 是 Zig 的标准测试方式，简单且高效。
