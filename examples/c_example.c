//! C API 示例程序

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zini.h"

void print_error(zini_error_t err) {
    if (err != ZINI_SUCCESS) {
        fprintf(stderr, "Error: %s\n", zini_error_string(err));
    }
}

int main(void) {
    printf("=== zini C API 示例 ===\n\n");

    // 创建解析器
    zini_t* parser = zini_new();
    if (parser == NULL) {
        fprintf(stderr, "Failed to create parser\n");
        return 1;
    }

    // 示例 1: 从字符串加载
    printf("示例 1: 从字符串加载\n");
    printf("---------------------\n");

    const char* content =
        "# 这是一个示例配置\n"
        "app_name=MyApp\n"
        "version=1.0.0\n"
        "debug=true\n"
        "port=8080\n"
        "\n"
        "[database]\n"
        "host=localhost\n"
        "port=5432\n"
        "username=admin\n"
        "password=secret\n"
        "ssl=true\n"
        "\n"
        "[features]\n"
        "enabled=true\n"
        "max_connections=100\n";

    zini_error_t err = zini_load_string(parser, content, strlen(content));
    if (err != ZINI_SUCCESS) {
        print_error(err);
        zini_free(parser);
        return 1;
    }

    // 读取全局值
    const char* app_name = zini_get(parser, "app_name");
    const char* version = zini_get(parser, "version");
    uint16_t port;
    zini_get_u16(parser, "port", &port);
    bool debug;
    zini_get_bool(parser, "debug", &debug);

    printf("应用名称: %s\n", app_name ? app_name : "(null)");
    printf("版本: %s\n", version ? version : "(null)");
    printf("端口: %u\n", port);
    printf("调试模式: %s\n", debug ? "true" : "false");

    printf("\n  ✓ 从字符串加载成功\n\n");

    // 示例 2: 读取 Section 值
    printf("示例 2: 读取 Section 值\n");
    printf("------------------------\n");

    const char* db_host = zini_get_section(parser, "database", "host");
    uint32_t db_port;
    zini_get_section_u32(parser, "database", "port", &db_port);
    const char* db_user = zini_get_section(parser, "database", "username");
    bool db_ssl;
    zini_get_section_bool(parser, "database", "ssl", &db_ssl);

    printf("数据库配置:\n");
    printf("  主机: %s\n", db_host ? db_host : "(null)");
    printf("  端口: %u\n", db_port);
    printf("  用户: %s\n", db_user ? db_user : "(null)");
    printf("  SSL: %s\n", db_ssl ? "enabled" : "disabled");

    printf("\n  ✓ Section 读取成功\n\n");

    // 示例 3: 设置值
    printf("示例 3: 设置和修改值\n");
    printf("---------------------\n");

    zini_set(parser, "new_key", "new_value");
    zini_set_section(parser, "features", "timeout", "30");

    const char* new_val = zini_get(parser, "new_key");
    uint32_t timeout;
    zini_get_section_u32(parser, "features", "timeout", &timeout);

    printf("新增键值: %s = %s\n", "new_key", new_val ? new_val : "(null)");
    printf("新增 section 值: features.timeout = %u\n", timeout);

    printf("\n  ✓ 值设置成功\n\n");

    // 示例 4: 检查 Section 是否存在
    printf("示例 4: 检查 Section\n");
    printf("---------------------\n");

    printf("Section 'database' 存在: %s\n", zini.has_section(parser, "database") ? "yes" : "no");
    printf("Section 'cache' 存在: %s\n", zini.has_section(parser, "cache") ? "yes" : "no");

    printf("\n  ✓ Section 检查成功\n\n");

    // 示例 5: 类型转换错误处理
    printf("示例 5: 错误处理\n");
    printf("-----------------\n");

    int64_t big_num;
    err = zini_get_int(parser, "app_name", &big_num);
    if (err != ZINI_SUCCESS) {
        printf("预期的类型转换错误: %s\n", zini_error_string(err));
    }

    const char* missing = zini_get(parser, "nonexistent");
    printf("不存在的键: %s\n", missing ? missing : "(null)");

    printf("\n  ✓ 错误处理成功\n\n");

    // 示例 6: 保存到文件
    printf("示例 6: 保存到文件\n");
    printf("-------------------\n");

    err = zini_save_file(parser, "test_output.ini");
    if (err == ZINI_SUCCESS) {
        printf("配置已保存到 test_output.ini\n");
    } else {
        print_error(err);
    }

    printf("\n  ✓ 文件保存成功\n\n");

    // 清理
    zini_free(parser);

    printf("=== 所有示例完成 ===\n");
    return 0;
}
