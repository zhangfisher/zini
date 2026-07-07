//! 真实场景演示：配置文件更新工具
//! 演示如何使用 IniOptions 进行内存优化和自动注释保留

const std = @import("std");
const Ini = @import("zini").Ini;
const IniOptions = @import("zini").IniOptions;

pub fn main() !void {
    var gpa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== 真实场景演示：配置文件更新工具 ===\n\n", .{});

    // 场景：需要更新配置文件中的某些值，但保留所有注释

    // ========================================
    // 场景1：使用默认API（内存优化）
    // ========================================
    {
        std.debug.print("--- 场景1：默认API（推荐）---\n", .{});
        std.debug.print("优点：内存优化 + 自动注释保留\n\n", .{});

        var ini = Ini.init(allocator);
        defer ini.deinit();

        // 加载配置文件
        try ini.load("examples/real_config.ini");

        // 更新配置项
        try ini.set("db_host", "192.168.1.100");
        try ini.set("db_port", "5433");
        try ini.set("server.port", "9090");

        // 验证更新后的配置
        std.debug.print("更新后的配置：\n", .{});
        std.debug.print("  db_host = {s}\n", .{ini.get("db_host").?});
        std.debug.print("  db_port = {s}\n", .{ini.get("db_port").?});
        std.debug.print("  server.port = {s}\n", .{ini.get("server.port").?});

        // 验证注释是否被保留
        const db_host_schema = ini.getSchema("db_host").?;
        std.debug.print("\n  db_host.title: {s}\n", .{db_host_schema.title orelse "null"});
        std.debug.print("  db_host.description: {s}\n", .{db_host_schema.description orelse "null（内存优化）"});

        const server_port_schema = ini.getSchema("server.port").?;
        std.debug.print("  server.port.title: {s}\n", .{server_port_schema.title orelse "null"});
        std.debug.print("  server.port.description: {s}\n", .{server_port_schema.description orelse "null（内存优化）"});

        // 保存配置（自动恢复注释）
        try ini.save("examples/real_config_updated.ini");

        std.debug.print("\n✓ 配置已保存到 examples/real_config_updated.ini\n", .{});
        std.debug.print("✓ 所有注释已自动保留\n\n", .{});
    }

    // ========================================
    // 场景2：使用完整功能（加载所有注释）
    // ========================================
    {
        std.debug.print("--- 场景2：完整功能（需要访问注释）---\n", .{});
        std.debug.print("适用场景：需要读取或处理注释内容\n\n", .{});

        var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
        defer ini.deinit();

        // 加载配置文件
        try ini.load("examples/real_config.ini");

        // 更新配置项
        try ini.set("db_host", "192.168.1.200");

        // 访问注释内容
        const db_host_schema = ini.getSchema("db_host").?;
        std.debug.print("db_host 注释信息：\n", .{});
        std.debug.print("  title: {s}\n", .{db_host_schema.title orelse "null"});
        std.debug.print("  description: {s}\n", .{db_host_schema.description orelse "null"});

        std.debug.print("\n✓ 可以访问完整的注释信息\n\n", .{});
    }

    // ========================================
    // 验证保存的文件
    // ========================================
    {
        std.debug.print("--- 验证保存的文件 ---\n", .{});

        var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
        defer ini.deinit();

        try ini.load("examples/real_config_updated.ini");

        std.debug.print("验证注释是否完整保留：\n", .{});

        const db_host = ini.getSchema("db_host").?;
        std.debug.print("  db_host.title: {s} ✓\n", .{db_host.title orelse "null"});
        std.debug.print("  db_host.description: {s} ✓\n", .{db_host.description orelse "null"});

        const db_port = ini.getSchema("db_port").?;
        std.debug.print("  db_port.title: {s} ✓\n", .{db_port.title orelse "null"});
        std.debug.print("  db_port.description: {s} ✓\n", .{db_port.description orelse "null"});

        const server_port = ini.getSchema("server.port").?;
        std.debug.print("  server.port.title: {s} ✓\n", .{server_port.title orelse "null"});
        std.debug.print("  server.port.description: {s} ✓\n", .{server_port.description orelse "null"});

        std.debug.print("\n✓ 所有注释完整保留\n", .{});
    }

    std.debug.print("\n=== 演示完成 ===\n", .{});
    std.debug.print("\n生成的文件：\n", .{});
    std.debug.print("  - examples/real_config_updated.ini（更新后的配置文件）\n", .{});
    std.debug.print("\n", .{});
}
