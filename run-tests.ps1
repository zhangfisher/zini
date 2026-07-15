# Zini 测试套件执行器 (PowerShell 版本)

Write-Host ""
Write-Host "========================================"  -ForegroundColor Cyan
Write-Host "     Zini 测试套件执行器" -ForegroundColor Cyan
Write-Host "========================================"  -ForegroundColor Cyan
Write-Host ""

# 设置项目路径
$PROJECT_DIR = $PSScriptRoot
$TESTS_DIR = Join-Path $PROJECT_DIR "tests"

# 测试文件列表
$TEST_FILES = @(
    "auto_type_inference.zig",
    "benchmarks.zig",
    "complete_verification.zig",
    "datatype_consistency.zig",
    "default_value_fallback.zig",
    "documentation.zig",
    "getSchema_section_syntax.zig",
    "getSchema_test.zig",
    "ini_options.zig",
    "metadata_system.zig",
    "multiline_strings.zig",
    "path_syntax.zig",
    "reset_functionality.zig",
    "schema_iteration.zig",
    "type_annotation_set.zig",
    "types.zig"
)

# 统计变量
$TOTAL = 0
$PASSED = 0
$FAILED = 0

# 记录开始时间
$START_TIME = Get-Date

# 遍历所有测试文件
foreach ($TEST_FILE in $TEST_FILES) {
    $TOTAL++
    $TEST_NAME = [System.IO.Path]::GetFileNameWithoutExtension($TEST_FILE)
    $TEST_PATH = Join-Path $TESTS_DIR $TEST_FILE

    Write-Host "[$TOTAL/16] Running test: $TEST_NAME" -ForegroundColor Yellow

    # 运行测试文件
    $PROCESS = Start-Process -FilePath "zig" -ArgumentList "test", "`"$TEST_PATH`"", "--cache-dir", "$PROJECT_DIR\.zig-cache", "--main-pkg-path", "$PROJECT_DIR" -NoNewWindow -Wait -PassThru

    # 检查测试结果
    if ($PROCESS.ExitCode -eq 0) {
        Write-Host "    PASS: $TEST_NAME" -ForegroundColor Green
        $PASSED++
    } else {
        Write-Host "    FAIL: $TEST_NAME" -ForegroundColor Red
        $FAILED++
    }
}

# 计算执行时间
$END_TIME = Get-Date
$DURATION = $END_TIME - $START_TIME

# 显示最终结果
Write-Host ""
Write-Host "========================================"  -ForegroundColor Cyan
Write-Host "           Test Summary" -ForegroundColor Cyan
Write-Host "========================================"  -ForegroundColor Cyan
Write-Host ""
Write-Host "Total:     $TOTAL tests"
Write-Host "Passed:    $PASSED tests" -ForegroundColor Green
Write-Host "Failed:    $FAILED tests" -ForegroundColor Red
Write-Host "Duration:  $($DURATION.TotalSeconds.ToString('F2')) seconds"
Write-Host ""

# 返回相应的退出码
if ($FAILED -eq 0) {
    Write-Host "SUCCESS: All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILURE: $FAILED test(s) failed" -ForegroundColor Red
    exit 1
}
