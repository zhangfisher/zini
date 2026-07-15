@echo off
echo.
echo ========================================
echo     Zini Test Suite Runner
echo ========================================
echo.

cd /d "%~dp0"

set COUNT=0
set PASSED=0
set FAILED=0

:: Test 1
set /a COUNT+=1
echo [%COUNT%/16] Testing: auto_type_inference
zig test tests\auto_type_inference.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] auto_type_inference
    set /a PASSED+=1
) else (
    echo     [FAIL] auto_type_inference
    set /a FAILED+=1
)

:: Test 2
set /a COUNT+=1
echo [%COUNT%/16] Testing: benchmarks
zig test tests\benchmarks.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] benchmarks
    set /a PASSED+=1
) else (
    echo     [FAIL] benchmarks
    set /a FAILED+=1
)

:: Test 3
set /a COUNT+=1
echo [%COUNT%/16] Testing: complete_verification
zig test tests\complete_verification.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] complete_verification
    set /a PASSED+=1
) else (
    echo     [FAIL] complete_verification
    set /a FAILED+=1
)

:: Test 4
set /a COUNT+=1
echo [%COUNT%/16] Testing: datatype_consistency
zig test tests\datatype_consistency.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] datatype_consistency
    set /a PASSED+=1
) else (
    echo     [FAIL] datatype_consistency
    set /a FAILED+=1
)

:: Test 5
set /a COUNT+=1
echo [%COUNT%/16] Testing: default_value_fallback
zig test tests\default_value_fallback.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] default_value_fallback
    set /a PASSED+=1
) else (
    echo     [FAIL] default_value_fallback
    set /a FAILED+=1
)

:: Test 6
set /a COUNT+=1
echo [%COUNT%/16] Testing: documentation
zig test tests\documentation.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] documentation
    set /a PASSED+=1
) else (
    echo     [FAIL] documentation
    set /a FAILED+=1
)

:: Test 7
set /a COUNT+=1
echo [%COUNT%/16] Testing: getSchema_section_syntax
zig test tests\getSchema_section_syntax.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] getSchema_section_syntax
    set /a PASSED+=1
) else (
    echo     [FAIL] getSchema_section_syntax
    set /a FAILED+=1
)

:: Test 8
set /a COUNT+=1
echo [%COUNT%/16] Testing: getSchema_test
zig test tests\getSchema_test.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] getSchema_test
    set /a PASSED+=1
) else (
    echo     [FAIL] getSchema_test
    set /a FAILED+=1
)

:: Test 9
set /a COUNT+=1
echo [%COUNT%/16] Testing: ini_options
zig test tests\ini_options.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] ini_options
    set /a PASSED+=1
) else (
    echo     [FAIL] ini_options
    set /a FAILED+=1
)

:: Test 10
set /a COUNT+=1
echo [%COUNT%/16] Testing: metadata_system
zig test tests\metadata_system.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] metadata_system
    set /a PASSED+=1
) else (
    echo     [FAIL] metadata_system
    set /a FAILED+=1
)

:: Test 11
set /a COUNT+=1
echo [%COUNT%/16] Testing: multiline_strings
zig test tests\multiline_strings.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] multiline_strings
    set /a PASSED+=1
) else (
    echo     [FAIL] multiline_strings
    set /a FAILED+=1
)

:: Test 12
set /a COUNT+=1
echo [%COUNT%/16] Testing: path_syntax
zig test tests\path_syntax.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] path_syntax
    set /a PASSED+=1
) else (
    echo     [FAIL] path_syntax
    set /a FAILED+=1
)

:: Test 13
set /a COUNT+=1
echo [%COUNT%/16] Testing: reset_functionality
zig test tests\reset_functionality.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] reset_functionality
    set /a PASSED+=1
) else (
    echo     [FAIL] reset_functionality
    set /a FAILED+=1
)

:: Test 14
set /a COUNT+=1
echo [%COUNT%/16] Testing: schema_iteration
zig test tests\schema_iteration.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] schema_iteration
    set /a PASSED+=1
) else (
    echo     [FAIL] schema_iteration
    set /a FAILED+=1
)

:: Test 15
set /a COUNT+=1
echo [%COUNT%/16] Testing: type_annotation_set
zig test tests\type_annotation_set.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] type_annotation_set
    set /a PASSED+=1
) else (
    echo     [FAIL] type_annotation_set
    set /a FAILED+=1
)

:: Test 16
set /a COUNT+=1
echo [%COUNT%/16] Testing: types
zig test tests\types.zig --cache-dir .zig-cache --main-pkg-path . >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] types
    set /a PASSED+=1
) else (
    echo     [FAIL] types
    set /a FAILED+=1
)

:: Results
echo.
echo ========================================
echo           Test Summary
echo ========================================
echo.
echo Total Tests:  %COUNT%
echo Passed:       %PASSED%
echo Failed:       %FAILED%
echo.

if %FAILED% equ 0 (
    echo SUCCESS: All tests passed!
    exit /b 0
) else (
    echo FAILURE: %FAILED% test(s) failed
    exit /b 1
)
