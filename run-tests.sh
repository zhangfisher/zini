#!/bin/bash

# Zini 测试套件执行器 (Shell 版本)

echo ""
echo "========================================"
echo "     Zini 测试套件执行器"
echo "========================================"
echo ""

# 设置项目路径
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$PROJECT_DIR/tests"

# 测试文件列表
TEST_FILES=(
    "auto_type_inference.zig"
    "benchmarks.zig"
    "complete_verification.zig"
    "datatype_consistency.zig"
    "default_value_fallback.zig"
    "documentation.zig"
    "getSchema_section_syntax.zig"
    "getSchema_test.zig"
    "ini_options.zig"
    "metadata_system.zig"
    "multiline_strings.zig"
    "path_syntax.zig"
    "reset_functionality.zig"
    "schema_iteration.zig"
    "type_annotation_set.zig"
    "types.zig"
)

# 统计变量
TOTAL=0
PASSED=0
FAILED=0

# 记录开始时间
START_TIME=$(date +%s)

# 遍历所有测试文件
for TEST_FILE in "${TEST_FILES[@]}"; do
    TOTAL=$((TOTAL + 1))
    TEST_NAME=$(basename "$TEST_FILE" .zig)
    TEST_PATH="$TESTS_DIR/$TEST_FILE"

    echo "[$TOTAL/16] Running test: $TEST_NAME"

    # 运行测试文件
    if zig test "$TEST_PATH" --cache-dir "$PROJECT_DIR/.zig-cache" --main-pkg-path "$PROJECT_DIR" > /dev/null 2>&1; then
        echo "    PASS: $TEST_NAME"
        PASSED=$((PASSED + 1))
    else
        echo "    FAIL: $TEST_NAME"
        FAILED=$((FAILED + 1))
    fi
done

# 计算执行时间
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# 显示最终结果
echo ""
echo "========================================"
echo "           Test Summary"
echo "========================================"
echo ""
echo "Total:     $TOTAL tests"
echo "Passed:    $PASSED tests"
echo "Failed:    $FAILED tests"
echo "Duration:  ${DURATION}s"
echo ""

# 返回相应的退出码
if [ $FAILED -eq 0 ]; then
    echo "SUCCESS: All tests passed!"
    exit 0
else
    echo "FAILURE: $FAILED test(s) failed"
    exit 1
fi
