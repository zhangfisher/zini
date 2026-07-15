# 测试脚本使用指南

## 快速开始

### Windows 用户

#### 方法 1: 快速测试（推荐）
```cmd
quick-test.bat
```

#### 方法 2: 详细测试输出
```cmd
run-tests.bat
```

#### 方法 3: PowerShell 版本
```powershell
.\run-tests.ps1
```

#### 方法 4: 运行单个测试
```cmd
run-single-test.bat types
```

### Linux/macOS 用户

```bash
# 添加执行权限（首次运行）
chmod +x run-tests.sh

# 运行所有测试
./run-tests.sh

# 或直接使用 zig
zig build test
```

## 测试脚本对比

| 脚本 | 平台 | 特点 | 推荐用途 |
|------|------|------|----------|
| `quick-test.bat` | Windows | 最简单，使用 `zig build test` | 日常开发 |
| `run-tests.bat` | Windows | 逐个运行，详细输出 | 调试测试问题 |
| `run-tests.ps1` | Windows | PowerShell，彩色输出 | PowerShell 用户 |
| `run-single-test.bat` | Windows | 运行单个测试 | 快速验证特定功能 |
| `run-tests.sh` | Linux/macOS | Shell 脚本，跨平台 | Unix 系统 |
| `zig build test` | 所有平台 | 原生命令 | CI/CD 环境 |

## 使用示例

### 运行所有测试

```cmd
# Windows
quick-test.bat

# Linux/macOS
./run-tests.sh
```

### 运行特定测试

```cmd
# Windows
run-single-test.bat path_syntax

# Linux/macOS  
zig test tests/path_syntax.zig
```

### 查看详细输出

```cmd
# Windows - 详细输出
run-tests.bat

# 直接使用 zig 命令
zig test tests/types.zig
```

## 预期输出

成功的测试运行应该显示：

```
========================================
     Zini 测试套件执行器
========================================

[1/16] Running test: auto_type_inference
    PASS: auto_type_inference
[2/16] Running test: benchmarks
    PASS: benchmarks
...
[16/16] Running test: types
    PASS: types

========================================
           Test Summary
========================================

Total:     16 tests
Passed:    16 tests
Failed:    0 tests

SUCCESS: All tests passed!
```

## 故障排除

### 问题：找不到 zig 命令
**解决方案：**
1. 确保 Zig 已安装：`zig version`
2. 将 Zig 添加到系统 PATH

### 问题：编译错误
**解决方案：**
1. 检查 Zig 版本：需要 0.16.0 或更高版本
2. 清理缓存：删除 `.zig-cache` 目录
3. 重新运行测试

### 问题：脚本无法执行
**解决方案：**
1. **Windows**: 确保从项目根目录运行
2. **Linux/macOS**: 添加执行权限 `chmod +x run-tests.sh`

## 集成到 CI/CD

### GitHub Actions
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    steps:
      - uses: actions/checkout@v3
      - uses: goto-bus-stop/setup-zig@v2
        with:
          zig-version: 0.16.0
      
      - name: Run tests
        run: zig build test
```

### GitLab CI
```yaml
test:
  script:
    - zig build test
  tags:
    - docker
```

## 最佳实践

1. **提交前运行测试**
   ```cmd
   quick-test.bat
   ```

2. **开发时频繁测试**
   - 使用 `run-single-test.bat` 快速验证功能
   - 或直接运行 `zig test tests/your_test.zig`

3. **调试失败的测试**
   - 使用 `run-tests.bat` 查看详细输出
   - 或直接运行测试文件查看完整错误信息

4. **性能测试**
   - `benchmarks.zig` 包含性能测试
   - 可通过 `run-single-test.bat benchmarks` 单独运行

## 当前测试状态

✅ **77/77 测试通过**

所有测试覆盖以下功能：
- 类型系统和类型推断
- INI 解析和序列化
- 路径语法支持
- 元数据和文档
- 多行字符串
- 验证器系统
- 错误处理
- 内存安全

---

**注意**: 所有测试脚本都需要从项目根目录运行。
