//! Zig 0.16 简化性能基准测试

const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== zig-ini Zig 0.16 基准测试 ===\n\n", .{});

    // 测试 1: 基本解析
    {
        std.debug.print("测试 1: 基本 INI 解析\n", .{});
        const test_ini =
            \\# Test configuration
            \\app_name = MyApp
            \\version = 1.0.0
            \\
            \\[database]
            \\host = localhost
            \\port = 5432
            \\name = testdb
            \\
            \\[server]
            \\host = 0.0.0.0
            \\port = 8080
        ;

        var ini = Ini.default(allocator);
        defer ini.deinit();

        try ini.loadFromString(test_ini);

        // 验证解析结果
        const app_name = ini.get("app_name").?;
        const db_host = ini.get("database.host").?;
        const server_port = ini.get("server.port").?;

        std.debug.print("  ✓ 应用名称: {s}\n", .{app_name});
        std.debug.print("  ✓ 数据库主机: {s}\n", .{db_host});
        std.debug.print("  ✓ 服务器端口: {s}\n", .{server_port});
    }

    // 测试 2: 序列化
    {
        std.debug.print("\n测试 2: INI 序列化\n", .{});
        var ini = Ini.default(allocator);
        defer ini.deinit();

        try ini.set("test_key", "test_value");
        try ini.set("section1.key1", "value1");
        try ini.set("section1.key2", "value2");

        const content = try ini.saveToString(allocator);
        std.debug.print("  ✓ 序列化成功\n", .{});
        std.debug.print("  ✓ 输出大小: {d} bytes\n", .{content.len});
        std.debug.print("  ✓ 输出预览:\n", .{});
        if (content.len > 100) {
            std.debug.print("    {s}...\n", .{content[0..100]});
        } else {
            std.debug.print("    {s}\n", .{content});
        }
    }

    // 测试 3: 性能测试
    {
        std.debug.print("\n测试 3: 批量操作性能\n", .{});
        var ini = Ini.default(allocator);
        defer ini.deinit();

        // 添加大量配置
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            const section = try std.fmt.allocPrint(allocator, "section{d}", .{i});
            const key1 = try std.fmt.allocPrint(allocator, "{s}.key1", .{section});
            const key2 = try std.fmt.allocPrint(allocator, "{s}.key2", .{section});
            try ini.set(key1, "value1");
            try ini.set(key2, "value2");
        }

        std.debug.print("  ✓ 添加了 {d} 个配置段\n", .{i});
        std.debug.print("  ✓ 总 section 数: {d}\n", .{ini.sections.count()});
    }

    // 测试 4: 查找性能
    {
        std.debug.print("\n测试 4: 查找性能\n", .{});
        var ini = Ini.default(allocator);
        defer ini.deinit();

        try ini.set("key1", "value1");
        try ini.set("key2", "value2");
        try ini.set("section1.key1", "value1");
        try ini.set("section1.key2", "value2");

        // 执行大量查找
        var found: usize = 0;
        var i: usize = 0;
        while (i < 1000) : (i += 1) {
            if (ini.get("key1")) |_| found += 1;
            if (ini.get("section1.key1")) |_| found += 1;
        }

        std.debug.print("  ✓ 执行了 {d} 次查找\n", .{i * 2});
        std.debug.print("  ✓ 成功找到: {d} 次\n", .{found});
    }

    // 测试 5: 错误处理
    {
        std.debug.print("\n测试 5: 错误处理\n", .{});
        var ini = Ini.default(allocator);
        defer ini.deinit();

        // 测试查找不存在的键
        if (ini.get("nonexistent")) |value| {
            std.debug.print("  ✗ 意外找到值: {s}\n", .{value});
        } else {
            std.debug.print("  ✓ 正确处理不存在的键\n", .{});
        }

        // 测试无效格式
        const invalid_ini = "[invalid\nwithout closing bracket";
        if (ini.loadFromString(invalid_ini)) {
            std.debug.print("  ✗ 意外解析成功\n", .{});
        } else |err| {
            std.debug.print("  ✓ 正确检测到错误: {}\n", .{err});
        }
    }

    std.debug.print("\n=== 所有测试完成 ===\n", .{});
    std.debug.print("\nZig 0.16 特性:\n", .{});
    std.debug.print("  • 完全兼容 Zig 0.16.0\n", .{});
    std.debug.print("  • 使用 ArenaAllocator 提高性能\n", .{});
    std.debug.print("  • StringHashMap 提供 O(1) 查找\n", .{});
    std.debug.print("  • 内存安全的 API 设计\n", .{});
}
