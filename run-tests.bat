@echo off
setlocal enabledelayedexpansion

:: 项目路径设置
set PROJECT_DIR=%~dp0
set TESTS_DIR=%PROJECT_DIR%tests

echo.
echo ========================================
echo     Zini Test Suite Runner
echo ========================================
echo.

:: 测试文件列表
set TEST_FILES=auto_type_inference benchmarks complete_verification datatype_consistency default_value_fallback documentation getSchema_section_syntax getSchema_test ini_options metadata_system multiline_strings path_syntax reset_functionality schema_iteration type_annotation_set types

:: 初始化计数器
set TOTAL=0
set PASSED=0
set FAILED=0

:: 运行每个测试
for %%T in (%TEST_FILES%) do (
    set /a TOTAL+=1
    set NAME=%%T

    echo [!TOTAL!/16] Testing: !NAME!

    zig test "%TESTS_DIR%\%%T.zig" --cache-dir "%PROJECT_DIR%.zig-cache" --main-pkg-path "%PROJECT_DIR%" >nul 2>&1

    if !errorlevel! equ 0 (
        echo     [PASS] !NAME!
        set /a PASSED+=1
    ) else (
        echo     [FAIL] !NAME!
        set /a FAILED+=1
    )
)

:: 结果汇总
echo.
echo ========================================
echo           Test Summary
echo ========================================
echo.
echo Total Tests:  !TOTAL!
echo Passed:       !PASSED!
echo Failed:       !FAILED!
echo.

if !FAILED! equ 0 (
    echo SUCCESS: All tests passed!
    endlocal
    exit /b 0
) else (
    echo FAILURE: !FAILED! test(s) failed
    endlocal
    exit /b 1
)
