//! 简化的类型支持演示

const std = @import("std");
const Ini = @import("zini").Ini;
const DataType = @import("zini").DataType;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== zini 类型支持演示 ===\n\n", .{});

    // 示例 1: 类型安全访问
    {
        std.debug.print("示例 1: 类型安全访问\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        try config.set("enabled", "true");
        try config.set("count", "100");
        try config.set("rate", "0.15");
        try config.set("message", "Hello");

        const enabled = try config.getBool("enabled");
        const count = try config.getInt("count");
        const rate = try config.getFloat("rate");
        const message = config.get("message").?;

        std.debug.print("enabled (bool): {}\n", .{enabled});
        std.debug.print("count (int): {}\n", .{count});
        std.debug.print("rate (float): {d:.2}\n", .{rate});
        std.debug.print("message (string): {s}\n", .{message});

        const total = @as(f64, @floatFromInt(count)) * rate;
        std.debug.print("计算结果: {} * {d:.2} = {d:.2}\n", .{count, rate, total});

        std.debug.print("  ✓ 类型安全访问成功\n\n", .{});
    }

    // 示例 2: Section 类型访问
    {
        std.debug.print("示例 2: Section 类型访问\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        try config.set("database.port", "5432");
        try config.set("database.ssl", "true");
        try config.set("database.timeout", "30.5");

        const port = try config.getInt("database.port");
        const ssl = try config.getBool("database.ssl");
        const timeout = try config.getFloat("database.timeout");

        std.debug.print("port: {}\n", .{port});
        std.debug.print("ssl: {}\n", .{ssl});
        std.debug.print("timeout: {d:.1}s\n", .{timeout});

        std.debug.print("  ✓ Section 类型访问成功\n\n", .{});
    }

    // 示例 3: 配置文件加载
    {
        std.debug.print("示例 3: 配置文件加载\n", .{});
        const config_content =
            \\debug = true
            \\port = 8080
            \\timeout = 30.5
            \\
            \\[database]
            \\port = 5432
            \\ssl = true
            \\pool_size = 10
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const debug = try config.getBool("debug");
        const port = try config.getInt("port");
        const timeout = try config.getFloat("timeout");

        std.debug.print("debug: {}\n", .{debug});
        std.debug.print("port: {}\n", .{port});
        std.debug.print("timeout: {d:.1}s\n", .{timeout});

        const db_port = try config.getInt("database.port");
        const db_ssl = try config.getBool("database.ssl");

        std.debug.print("database.port: {}\n", .{db_port});
        std.debug.print("database.ssl: {}\n", .{db_ssl});

        std.debug.print("  ✓ 配置文件加载成功\n\n", .{});
    }

    std.debug.print("=== 所有演示完成 ===\n", .{});
}