@echo off
echo.
echo ========================================
echo     Zini Quick Test Suite
echo ========================================
echo.

cd /d "%~dp0"

zig build test

if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] All tests passed!
    exit /b 0
) else (
    echo.
    echo [FAILURE] Some tests failed
    exit /b 1
)
