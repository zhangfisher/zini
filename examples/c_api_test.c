// C API 测试示例 - 使用4个基本getter方法
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "zini.h"

int main() {
    printf("=== ZINI C API 功能测试 ===\n\n");

    // 测试基本创建和加载
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
        "ratio = 1.5\n"
        "pi = 3.14159\n"
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

    // 测试4个基本getter方法
    printf("2. 测试4个基本getter方法...\n");

    // 测试 getString
    const char* app_name = zini_get_string(parser, "app_name");
    if (app_name) {
        printf("✓ getString: app_name = %s\n", app_name);
    } else {
        printf("❌ getString 失败\n");
    }

    // 测试 getNumber (返回 i64)
    int64_t port;
    err = zini_get_number(parser, "port", &port);
    if (err == ZINI_SUCCESS) {
        printf("✓ getNumber: port = %lld (预期: 8080)\n", (long long)port);
    } else {
        printf("❌ getNumber 失败: %s\n", zini_error_string(err));
    }

    // 测试 getFloat (返回 f64)
    double pi;
    err = zini_get_float(parser, "pi", &pi);
    if (err == ZINI_SUCCESS) {
        printf("✓ getFloat: pi = %.5f (预期: 3.14159)\n", pi);
    } else {
        printf("❌ getFloat 失败: %s\n", zini_error_string(err));
    }

    // 测试 getBoolean
    bool enabled;
    err = zini_get_boolean(parser, "enabled", &enabled);
    if (err == ZINI_SUCCESS) {
        printf("✓ getBoolean: enabled = %s (预期: true)\n", enabled ? "true" : "false");
    } else {
        printf("❌ getBoolean 失败: %s\n", zini_error_string(err));
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
