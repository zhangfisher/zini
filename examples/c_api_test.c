// C API 测试示例
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zini.h"

int main() {
    printf("=== ZINI C API 功能测试 ===\n\n");

    // 测试新的类型获取函数
    printf("1. 测试基本创建和加载...\n");
    zini_t* parser = zini_new();
    if (!parser) {
        printf("❌ 创建 parser 失败\n");
        return 1;
    }
    printf("✓ Parser 创建成功\n");

    // 测试加载字符串
    const char* ini_content =
        "# 测试配置\n"
        "app_name = test_app\n"
        "version = 1.0\n"
        "enabled = true\n"
        "port = 8080\n"
        "temperature = -5\n"
        "score = -100\n"
        "balance = -1000\n"
        "timestamp = 1640000000\n"
        "pi = 3.14159\n"
        "ratio = 1.5\n"
        "\n"
        "[database]\n"
        "host = localhost\n"
        "port = 3306\n"
        "ssl = true\n";

    zini_error_t err = zini_load_string(parser, ini_content, strlen(ini_content));
    if (err != ZINI_SUCCESS) {
        printf("❌ 加载字符串失败: %s\n", zini_error_string(err));
        zini_free(parser);
        return 1;
    }
    printf("✓ 字符串加载成功\n\n");

    // 测试新的类型获取函数
    printf("2. 测试新增的类型获取函数...\n");

    // 测试 i8
    int8_t temperature = 0;
    err = zini_get_i8(parser, "temperature", &temperature);
    if (err == ZINI_SUCCESS) {
        printf("✓ i8 测试: temperature = %d (预期: -5)\n", temperature);
    } else {
        printf("❌ i8 测试失败: %s\n", zini_error_string(err));
    }

    // 测试 i16
    int16_t score = 0;
    err = zini_get_i16(parser, "score", &score);
    if (err == ZINI_SUCCESS) {
        printf("✓ i16 测试: score = %d (预期: -100)\n", score);
    } else {
        printf("❌ i16 测试失败: %s\n", zini_error_string(err));
    }

    // 测试 i32
    int32_t balance = 0;
    err = zini_get_i32(parser, "balance", &balance);
    if (err == ZINI_SUCCESS) {
        printf("✓ i32 测试: balance = %d (预期: -1000)\n", balance);
    } else {
        printf("❌ i32 测试失败: %s\n", zini_error_string(err));
    }

    // 测试 i64
    int64_t timestamp = 0;
    err = zini_get_i64(parser, "timestamp", &timestamp);
    if (err == ZINI_SUCCESS) {
        printf("✓ i64 测试: timestamp = %lld (预期: 1640000000)\n", (long long)timestamp);
    } else {
        printf("❌ i64 测试失败: %s\n", zini_error_string(err));
    }

    // 测试 f32
    float pi = 0.0f;
    err = zini_get_f32(parser, "pi", &pi);
    if (err == ZINI_SUCCESS) {
        printf("✓ f32 测试: pi = %.5f (预期: 3.14159)\n", pi);
    } else {
        printf("❌ f32 测试失败: %s\n", zini_error_string(err));
    }

    // 测试 f64
    double ratio = 0.0;
    err = zini_get_f64(parser, "ratio", &ratio);
    if (err == ZINI_SUCCESS) {
        printf("✓ f64 测试: ratio = %.2f (预期: 1.50)\n", ratio);
    } else {
        printf("❌ f64 测试失败: %s\n", zini_error_string(err));
    }

    printf("\n");

    // 测试 getItem 功能
    printf("3. 测试 getItem 功能...\n");
    zini_item_t item;
    err = zini_get_item(parser, "app_name", &item);
    if (err == ZINI_SUCCESS) {
        printf("✓ getItem 测试:\n");
        printf("  - key: %s\n", item.key);
        printf("  - value: %s\n", item.value);
        printf("  - datatype: %d\n", item.datatype);
    } else {
        printf("❌ getItem 测试失败: %s\n", zini_error_string(err));
    }

    printf("\n");

    // 测试 has 和 remove 功能
    printf("4. 测试 has 和 remove 功能...\n");

    // 测试 has
    bool has_result = zini_has_item(parser, "app_name");
    printf("✓ has('app_name'): %s (预期: true)\n", has_result ? "true" : "false");

    has_result = zini_has_item(parser, "nonexistent");
    printf("✓ has('nonexistent'): %s (预期: false)\n", has_result ? "true" : "false");

    // 测试 section.key 语法
    has_result = zini_has_item(parser, "database.host");
    printf("✓ has('database.host'): %s (预期: true)\n", has_result ? "true" : "false");

    // 测试 removeItem
    bool removed = zini_remove_item(parser, "version");
    printf("✓ removeItem('version'): %s (预期: true)\n", removed ? "true" : "false");

    has_result = zini_has_item(parser, "version");
    printf("✓ has('version') after removeItem: %s (预期: false)\n", has_result ? "true" : "false");

    printf("\n");

    // 测试 IniOptions 功能
    printf("5. 测试 IniOptions 功能...\n");

    zini_options_t default_opts = zini_options_default();
    printf("✓ 默认选项 flags: %u (预期: 0)\n", default_opts.flags);

    zini_options_t desc_opts = zini_options_with_description();
    printf("✓ 带描述的选项 flags: %u (预期: 1)\n", desc_opts.flags);

    zini_t* parser_with_opts = zini_init_with_options(desc_opts);
    if (parser_with_opts) {
        printf("✓ 使用选项创建 parser 成功\n");
        zini_free(parser_with_opts);
    } else {
        printf("❌ 使用选项创建 parser 失败\n");
    }

    printf("\n");

    // 测试保存功能
    printf("6. 测试保存功能...\n");
    err = zini_save_file(parser, "test_output.ini");
    if (err == ZINI_SUCCESS) {
        printf("✓ 保存文件成功: test_output.ini\n");
    } else {
        printf("❌ 保存文件失败: %s\n", zini_error_string(err));
    }

    // 清理
    zini_free(parser);
    printf("✓ 清理完成\n");

    printf("\n=== 所有测试完成 ===\n");
    return 0;
}
