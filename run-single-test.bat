@echo off
setlocal enabledelayedexpansion

:: 检查参数
if "%~1"=="" (
    echo.
    echo Usage: run-single-test.bat ^<test_name^>
    echo.
    echo Available tests:
    echo   - auto_type_inference
    echo   - benchmarks
    echo   - complete_verification
    echo   - datatype_consistency
    echo   - default_value_fallback
    echo   - documentation
    echo   - getSchema_section_syntax
    echo   - getSchema_test
    echo   - ini_options
    echo   - metadata_system
    echo   - multiline_strings
    echo   - path_syntax
    echo   - reset_functionality
    echo   - schema_iteration
    echo   - type_annotation_set
    echo   - types
    echo.
    exit /b 1
)

:: 设置路径
set PROJECT_DIR=%~dp0
set TESTS_DIR=%PROJECT_DIR%tests
set TEST_NAME=%~1
set TEST_FILE=%TESTS_DIR%\%TEST_NAME%.zig

:: 检查文件是否存在
if not exist "%TEST_FILE%" (
    echo.
    echo Error: Test file not found: %TEST_FILE%
    echo.
    exit /b 1
)

:: 运行测试
echo.
echo ========================================
echo   Running Test: %TEST_NAME%
echo ========================================
echo.

zig test "%TEST_FILE%" --cache-dir "%PROJECT_DIR%.zig-cache" --main-pkg-path "%PROJECT_DIR%"

:: 检查结果
if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] Test passed: %TEST_NAME%
    endlocal
    exit /b 0
) else (
    echo.
    echo [FAILURE] Test failed: %TEST_NAME%
    endlocal
    exit /b 1
)
