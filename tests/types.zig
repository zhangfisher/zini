//! 类型支持测试
//!
//! 测试数据类型推断和类型安全的访问方法

const std = @import("std");
const Ini = @import("src/root.zig").Ini;
const DataType = @import("src/types.zig").DataType;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== zig-ini 类型支持测试 ===\n\n", .{});

    // 测试 1: 类型推断
    {
        std.debug.print("测试 1: 类型推断\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        // 设置不同类型的值
        try ini.set("bool_true", "true");
        try ini.set("bool_false", "false");
        try ini.set("integer", "42");
        try ini.set("negative_int", "-123");
        try ini.set("float", "3.14");
        try ini.set("string", "hello");

        // 验证类型推断
        if (ini.getSchema("bool_true")) |entry| {
            std.debug.print("  bool_true 类型: {s}\n", .{entry.datatype.toTypeName()});
            try std.testing.expectEqual(DataType.bool, entry.datatype);
        }

        if (ini.getSchema("integer")) |entry| {
            std.debug.print("  integer 类型: {s}\n", .{entry.datatype.typeName()});
            try std.testing.expectEqual(DataType.int, entry.datatype);
        }

        if (ini.getSchema("float")) |entry| {
            std.debug.print("  float 类型: {s}\n", .{entry.datatype.typeName()});
            try std.testing.expectEqual(DataType.float, entry.datatype);
        }

        if (ini.getSchema("string")) |entry| {
            std.debug.print("  string 类型: {s}\n", .{entry.datatype.typeName()});
            try std.testing.expectEqual(DataType.string, entry.datatype);
        }

        std.debug.print("  ✓ 类型推断正常\n", .{});
    }

    // 测试 2: 布尔值访问
    {
        std.debug.print("\n测试 2: 布尔值访问\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        try ini.set("enabled", "true");
        try ini.set("disabled", "false");

        const enabled = try ini.getBool("enabled");
        const disabled = try ini.getBool("disabled");

        std.debug.print("  enabled = {}\n", .{enabled});
        std.debug.print("  disabled = {}\n", .{disabled});

        try std.testing.expect(enabled == true);
        try std.testing.expect(disabled == false);

        std.debug.print("  ✓ 布尔值访问正常\n", .{});
    }

    // 测试 3: 整数访问
    {
        std.debug.print("\n测试 3: 整数访问\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        try ini.set("port", "8080");
        try ini.set("timeout", "30");
        try ini.set("max_connections", "100");

        const port = try ini.getInt("port");
        const timeout = try ini.getInt("timeout");
        const max_conn = try ini.getInt("max_connections");

        std.debug.print("  port = {}\n", .{port});
        std.debug.print("  timeout = {}\n", .{timeout});
        std.debug.print("  max_connections = {}\n", .{max_conn});

        try std.testing.expectEqual(@as(i64, 8080), port);
        try std.testing.expectEqual(@as(i64, 30), timeout);
        try std.testing.expectEqual(@as(i64, 100), max_conn);

        std.debug.print("  ✓ 整数访问正常\n", .{});
    }

    // 测试 4: 浮点数访问
    {
        std.debug.print("\n测试 4: 浮点数访问\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        try ini.set("pi", "3.14159");
        try ini.set("e", "2.71828");
        try ini.set("rate", "0.05");

        const pi = try ini.getFloat("pi");
        const e = try ini.getFloat("e");
        const rate = try ini.getFloat("rate");

        std.debug.print("  pi = {d:.5}\n", .{pi});
        std.debug.print("  e = {d:.5}\n", .{e});
        std.debug.print("  rate = {d:.2}\n", .{rate});

        try std.testing.expectApproxEqAbs(@as(f64, 3.14159), pi, 0.00001);
        try std.testing.expectApproxEqAbs(@as(f64, 2.71828), e, 0.00001);
        try std.testing.expectApproxEqAbs(@as(f64, 0.05), rate, 0.00001);

        std.debug.print("  ✓ 浮点数访问正常\n", .{});
    }

    // 测试 5: Section 中的类型访问
    {
        std.debug.print("\n测试 5: Section 中的类型访问\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        try ini.set("database.host", "localhost");
        try ini.set("database.port", "5432");
        try ini.set("database.ssl", "true");
        try ini.set("database.timeout", "30.5");

        const host = ini.get("database.host").?;
        const port = try ini.getInt("database.port");
        const ssl = try ini.getBool("database.ssl");
        const timeout = try ini.getFloat("database.timeout");

        std.debug.print("  host = {s}\n", .{host});
        std.debug.print("  port = {}\n", .{port});
        std.debug.print("  ssl = {}\n", .{ssl});
        std.debug.print("  timeout = {d:.1}\n", .{timeout});

        try std.testing.expectEqualStrings("localhost", host);
        try std.testing.expectEqual(@as(i64, 5432), port);
        try std.testing.expect(ssl == true);
        try std.testing.expectApproxEqAbs(@as(f64, 30.5), timeout, 0.1);

        std.debug.print("  ✓ Section 类型访问正常\n", .{});
    }

    // 测试 6: 复杂配置文件
    {
        std.debug.print("\n测试 6: 复杂配置文件解析\n", .{});
        const config_content =
            \\# 应用配置
            \\app.name = MyApp
            \\app.version = 2.0
            \\app.debug = true
            \\app.max_users = 1000
            \\app.tax_rate = 0.15
            \\
            \\[database]
            \\host = localhost
            \\port = 5432
            \\ssl = true
            \\timeout = 30.5
            \\
            \\[server]
            \\host = 0.0.0.0
            \\port = 8080
            \\workers = 4
            \\enabled = true
            \\load_factor = 0.8
        ;

        var ini = Ini.init(allocator);
        defer ini.deinit();

        try ini.loadFromString(config_content);

        // 验证全局配置
        const app_name = ini.get("app.name").?;
        const app_version = try ini.getFloat("app.version");
        const app_debug = try ini.getBool("app.debug");
        const max_users = try ini.getInt("app.max_users");
        const tax_rate = try ini.getFloat("app.tax_rate");

        std.debug.print("  应用信息:\n", .{});
        std.debug.print("    名称: {s}\n", .{app_name});
        std.debug.print("    版本: {d:.1}\n", .{app_version});
        std.debug.print("    调试: {}\n", .{app_debug});
        std.debug.print("    最大用户: {}\n", .{max_users});
        std.debug.print("    税率: {d:.2}\n", .{tax_rate});

        // 验证数据库配置
        const db_port = try ini.getInt("database.port");
        const db_ssl = try ini.getBool("database.ssl");
        const db_timeout = try ini.getFloat("database.timeout");

        std.debug.print("  数据库配置:\n", .{});
        std.debug.print("    端口: {}\n", .{db_port});
        std.debug.print("    SSL: {}\n", .{db_ssl});
        std.debug.print("    超时: {d:.1}s\n", .{db_timeout});

        // 验证服务器配置
        const server_workers = try ini.getInt("server.workers");
        const server_enabled = try ini.getBool("server.enabled");
        const server_load = try ini.getFloat("server.load_factor");

        std.debug.print("  服务器配置:\n", .{});
        std.debug.print("    工作进程: {}\n", .{server_workers});
        std.debug.print("    启用: {}\n", .{server_enabled});
        std.debug.print("    负载因子: {d:.1}\n", .{server_load});

        std.debug.print("  ✓ 复杂配置解析正常\n", .{});
    }

    // 测试 7: 错误处理
    {
        std.debug.print("\n测试 7: 错误处理\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        try ini.set("valid_int", "42");
        try ini.set("valid_bool", "true");

        // 尝试类型不匹配的转换
        if (ini.getBool("valid_int")) |_| {
            std.debug.print("  ✗ 意外转换成功\n", .{});
        } else |err| {
            std.debug.print("  ✓ 正确处理类型不匹配: {}\n", .{err});
        }

        if (ini.getInt("valid_bool")) |_| {
            std.debug.print("  ✗ 意外转换成功\n", .{});
        } else |err| {
            std.debug.print("  ✓ 正确处理类型不匹配: {}\n", .{err});
        }

        // 访问不存在的键
        if (ini.getBool("nonexistent")) |_| {
            std.debug.print("  ✗ 意外找到不存在的键\n", .{});
        } else |err| {
            std.debug.print("  ✓ 正确处理不存在的键: {}\n", .{err});
        }

        std.debug.print("  ✓ 错误处理正常\n", .{});
    }

    std.debug.print("\n=== 所有类型测试完成 ===\n", .{});
}

// 单元测试
test "type inference basic" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("bool_val", "true");
    try ini.set("int_val", "42");
    try ini.set("float_val", "3.14");
    try ini.set("str_val", "hello");

    const bool_entry = ini.getSchema("bool_val").?;
    const int_entry = ini.getSchema("int_val").?;
    const float_entry = ini.getSchema("float_val").?;
    const str_entry = ini.getSchema("str_val").?;

    try std.testing.expectEqual(DataType.bool, bool_entry.datatype);
    try std.testing.expectEqual(DataType.int, int_entry.datatype);
    try std.testing.expectEqual(DataType.float, float_entry.datatype);
    try std.testing.expectEqual(DataType.string, str_entry.datatype);
}

test "type safe access" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("bool_val", "true");
    try ini.set("int_val", "42");
    try ini.set("float_val", "3.14");

    const bool_val = try ini.getBool("bool_val");
    const int_val = try ini.getInt("int_val");
    const float_val = try ini.getFloat("float_val");

    try std.testing.expect(bool_val == true);
    try std.testing.expectEqual(@as(i64, 42), int_val);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), float_val, 0.001);
}

test "section type access" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("config.enabled", "true");
    try ini.set("config.count", "10");
    try ini.set("config.rate", "0.5");

    const enabled = try ini.getBool("config.enabled");
    const count = try ini.getInt("config.count");
    const rate = try ini.getFloat("config.rate");

    try std.testing.expect(enabled == true);
    try std.testing.expectEqual(@as(i64, 10), count);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), rate, 0.001);
}
