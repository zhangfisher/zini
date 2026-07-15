@echo off
echo.
echo ========================================
echo     Tests 目录快速测试脚本
echo ========================================
echo.
echo 这个脚本会从tests目录运行所有测试
echo 但使用项目根目录的模块路径
echo.

cd /d "%~dp0"

echo 正在运行测试...
echo.

set COUNT=0
set PASSED=0
set FAILED=0

:: 测试 auto_type_inference
set /a COUNT+=1
echo [%COUNT%/16] auto_type_inference
zig test auto_type_inference.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 benchmarks
set /a COUNT+=1
echo [%COUNT%/16] benchmarks
zig test benchmarks.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL]
    set /a FAILED+=1
)

:: 测试 complete_verification
set /a COUNT+=1
echo [%COUNT%/16] complete_verification
zig test complete_verification.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 datatype_consistency
set /a COUNT+=1
echo [%COUNT%/16] datatype_consistency
zig test datatype_consistency.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL]
    set /a FAILED+=1
)

:: 测试 default_value_fallback
set /a COUNT+=1
echo [%COUNT%/16] default_value_fallback
zig test default_value_fallback.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 documentation
set /a COUNT+=1
echo [%COUNT%/16] documentation
zig test documentation.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL]
    set /a FAILED+=1
)

:: 测试 getSchema_section_syntax
set /a COUNT+=1
echo [%COUNT%/16] getSchema_section_syntax
zig test getSchema_section_syntax.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 getSchema_test
set /a COUNT+=1
echo [%COUNT%/16] getSchema_test
zig test getSchema_test.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 ini_options
set /a COUNT+=1
echo [%COUNT%/16] ini_options
zig test ini_options.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL]
    set /a FAILED+=1
)

:: 测试 metadata_system
set /a COUNT+=1
echo [%COUNT%/16] metadata_system
zig test metadata_system.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 multiline_strings
set /a COUNT+=1
echo [%COUNT%/16] multiline_strings
zig test multiline_strings.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 path_syntax
set /a COUNT+=1
echo [%COUNT%/16] path_syntax
zig test path_syntax.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 reset_functionality
set /a COUNT+=1
echo [%COUNT%/16] reset_functionality
zig test reset_functionality.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL]
    set /a FAILED+=1
)

:: 测试 schema_iteration
set /a COUNT+=1
echo [%COUNT%/16] schema_iteration
zig test schema_iteration.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 type_annotation_set
set /a COUNT+=1
echo [%COUNT%/16] type_annotation_set
zig test type_annotation_set.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

:: 测试 types
set /a COUNT+=1
echo [%COUNT%/16] types
zig test types.zig --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS]
    set /a PASSED+=1
) else (
    echo     [FAIL] - 需要API修复
    set /a FAILED+=1
)

echo.
echo ========================================
echo           测试结果
echo ========================================
echo.
echo 总计:     %COUNT% 个测试
echo 通过:     %PASSED% 个
echo 失败:     %FAILED% 个
echo.

if %FAILED% equ 0 (
    echo ✅ 所有测试通过！
    exit /b 0
) else (
    echo ⚠️  %FAILED% 个测试需要 API 修复
    echo.
    echo 主要问题:
    echo - forEach API 签名已更改
    echo - getNumber/getBoolean 不返回错误
    echo - 可选类型解包语法更改
    exit /b 1
)
