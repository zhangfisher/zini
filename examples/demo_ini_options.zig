//! IniOptions 功能演示
//! 演示内存优化和自动注释保留功能

const std = @import("std");
const Ini = @import("zini").Ini;
const IniOptions = @import("zini").IniOptions;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("\n=== IniOptions 功能演示 ===\n\n", .{});

    // 原始配置文件内容
    const original_content =
        \\# 数据库服务器地址
        \\# @title 数据库主机
        \\db_host = localhost
        \\
        \\# 连接超时时间（秒）
        \\# @title 连接超时
        \\db_timeout = 30
    ;

    std.debug.print("原始配置：\n{s}\n\n", .{original_content});

    // 场景1：使用默认API（内存优化）
    {
        std.debug.print("--- 场景1：默认API（内存优化 + 自动注释保留）---\n", .{});

        var ini = Ini.init(allocator);
        defer ini.deinit();

        try ini.loadFromString(original_content);

        // 验证：title 被加载，description 不被加载
        const schema1 = ini.getSchema("db_host").?;
        std.debug.print("db_host.title: {s}\n", .{schema1.title orelse "null"});
        std.debug.print("db_host.description: {s}\n\n", .{schema1.description orelse "null"});

        // 更新值
        try ini.set("db_host", "192.168.1.100");

        // 验证：title 被保留，description 仍为 null
        const schema2 = ini.getSchema("db_host").?;
        std.debug.print("更新后 db_host.value: {s}\n", .{schema2.value});
        std.debug.print("更新后 db_host.title: {s}（被保留）\n", .{schema2.title orelse "null"});
        std.debug.print("更新后 db_host.description: {s}\n\n", .{schema2.description orelse "null"});
    }

    // 场景2：使用完整功能（加载所有注释）
    {
        std.debug.print("--- 场景2：完整功能（加载所有注释）---\n", .{});

        var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
        defer ini.deinit();

        try ini.loadFromString(original_content);

        // 验证：title 和 description 都被加载
        const schema1 = ini.getSchema("db_host").?;
        std.debug.print("db_host.title: {s}\n", .{schema1.title orelse "null"});
        std.debug.print("db_host.description: {s}\n\n", .{schema1.description orelse "null"});

        // 更新值
        try ini.set("db_host", "192.168.1.200");

        // 验证：title 和 description 都被保留
        const schema2 = ini.getSchema("db_host").?;
        std.debug.print("更新后 db_host.value: {s}\n", .{schema2.value});
        std.debug.print("更新后 db_host.title: {s}（被保留）\n", .{schema2.title orelse "null"});
        std.debug.print("更新后 db_host.description: {s}（被保留）\n\n", .{schema2.description orelse "null"});
    }

    std.debug.print("=== 演示完成 ===\n", .{});
}
