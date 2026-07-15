@echo off
echo.
echo ========================================
echo     Tests Directory Test Runner
echo ========================================
echo.

cd /d "%~dp0"

set COUNT=0
set PASSED=0
set FAILED=0

:: Test 1: auto_type_inference
set /a COUNT+=1
echo [%COUNT%/16] Testing: auto_type_inference
zig test auto_type_inference.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] auto_type_inference
    set /a PASSED+=1
) else (
    echo     [FAIL] auto_type_inference
    set /a FAILED+=1
)

:: Test 2: benchmarks
set /a COUNT+=1
echo [%COUNT%/16] Testing: benchmarks
zig test benchmarks.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] benchmarks
    set /a PASSED+=1
) else (
    echo     [FAIL] benchmarks
    set /a FAILED+=1
)

:: Test 3: complete_verification
set /a COUNT+=1
echo [%COUNT%/16] Testing: complete_verification
zig test complete_verification.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] complete_verification
    set /a PASSED+=1
) else (
    echo     [FAIL] complete_verification
    set /a FAILED+=1
)

:: Test 4: datatype_consistency
set /a COUNT+=1
echo [%COUNT%/16] Testing: datatype_consistency
zig test datatype_consistency.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] datatype_consistency
    set /a PASSED+=1
) else (
    echo     [FAIL] datatype_consistency
    set /a FAILED+=1
)

:: Test 5: default_value_fallback
set /a COUNT+=1
echo [%COUNT%/16] Testing: default_value_fallback
zig test default_value_fallback.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] default_value_fallback
    set /a PASSED+=1
) else (
    echo     [FAIL] default_value_fallback
    set /a FAILED+=1
)

:: Test 6: documentation
set /a COUNT+=1
echo [%COUNT%/16] Testing: documentation
zig test documentation.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] documentation
    set /a PASSED+=1
) else (
    echo     [FAIL] documentation
    set /a FAILED+=1
)

:: Test 7: getSchema_section_syntax
set /a COUNT+=1
echo [%COUNT%/16] Testing: getSchema_section_syntax
zig test getSchema_section_syntax.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] getSchema_section_syntax
    set /a PASSED+=1
) else (
    echo     [FAIL] getSchema_section_syntax
    set /a FAILED+=1
)

:: Test 8: getSchema_test
set /a COUNT+=1
echo [%COUNT%/16] Testing: getSchema_test
zig test getSchema_test.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] getSchema_test
    set /a PASSED+=1
) else (
    echo     [FAIL] getSchema_test
    set /a FAILED+=1
)

:: Test 9: ini_options
set /a COUNT+=1
echo [%COUNT%/16] Testing: ini_options
zig test ini_options.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] ini_options
    set /a PASSED+=1
) else (
    echo     [FAIL] ini_options
    set /a FAILED+=1
)

:: Test 10: metadata_system
set /a COUNT+=1
echo [%COUNT%/16] Testing: metadata_system
zig test metadata_system.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] metadata_system
    set /a PASSED+=1
) else (
    echo     [FAIL] metadata_system
    set /a FAILED+=1
)

:: Test 11: multiline_strings
set /a COUNT+=1
echo [%COUNT%/16] Testing: multiline_strings
zig test multiline_strings.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] multiline_strings
    set /a PASSED+=1
) else (
    echo     [FAIL] multiline_strings
    set /a FAILED+=1
)

:: Test 12: path_syntax
set /a COUNT+=1
echo [%COUNT%/16] Testing: path_syntax
zig test path_syntax.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] path_syntax
    set /a PASSED+=1
) else (
    echo     [FAIL] path_syntax
    set /a FAILED+=1
)

:: Test 13: reset_functionality
set /a COUNT+=1
echo [%COUNT%/16] Testing: reset_functionality
zig test reset_functionality.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] reset_functionality
    set /a PASSED+=1
) else (
    echo     [FAIL] reset_functionality
    set /a FAILED+=1
)

:: Test 14: schema_iteration
set /a COUNT+=1
echo [%COUNT%/16] Testing: schema_iteration
zig test schema_iteration.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] schema_iteration
    set /a PASSED+=1
) else (
    echo     [FAIL] schema_iteration
    set /a FAILED+=1
)

:: Test 15: type_annotation_set
set /a COUNT+=1
echo [%COUNT%/16] Testing: type_annotation_set
zig test type_annotation_set.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
if %errorlevel% equ 0 (
    echo     [PASS] type_annotation_set
    set /a PASSED+=1
) else (
    echo     [FAIL] type_annotation_set
    set /a FAILED+=1
)

:: Test 16: types
set /a COUNT+=1
echo [%COUNT%/16] Testing: types
zig test types.zig --cache-dir ..\.zig-cache --main-pkg-path .. >nul 2>&1
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
