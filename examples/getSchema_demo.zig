//! getSchema 功能演示 - 支持 Schema 查询和路径语法

const std = @import("std");
const Ini = @import("../src/ini.zig").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== getSchema 功能演示 ===\n\n", .{});

    // 示例 1: 基本 Schema 查询
    {
        std.debug.print("示例 1: 基本 Schema 查询\n", .{});
        std.debug.print("-----------------------\n", .{});

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.set("port:u16", "8080");
        try config.set("timeout:i32", "30");
        try config.set("enabled", "true");
        try config.set("name", "MyApp");

        // 使用 getSchema 查询类型信息
        const port_schema = config.getSchema("port").?;
        const timeout_schema = config.getSchema("timeout").?;
        const enabled_schema = config.getSchema("enabled").?;
        const name_schema = config.getSchema("name").?;

        std.debug.print("port -> 类型: {s}\n", .{port_schema.datatype.toTypeName()});
        std.debug.print("timeout -> 类型: {s}\n", .{timeout_schema.datatype.toTypeName()});
        std.debug.print("enabled -> 类型: {s}\n", .{enabled_schema.datatype.toTypeName()});
        std.debug.print("name -> 类型: {s}\n", .{name_schema.datatype.toTypeName()});

        std.debug.print("  ✓ 基本 Schema 查询成功\n\n", .{});
    }

    // 示例 2: 路径语法 Schema 查询
    {
        std.debug.print("示例 2: 路径语法 Schema 查询\n", .{});
        std.debug.print("--------------------------\n", .{});

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.set("server.port", "9000");
        try config.set("server.timeout:i32", "60");
        try config.set("database.pool_size:u32", "100");

        // 使用路径语法查询 section 中的 Schema
        if (config.getSchema("server.port")) |schema| {
            std.debug.print("server.port -> 类型: {s}\n", .{schema.datatype.toTypeName()});
        }

        if (config.getSchema("server.timeout")) |schema| {
            std.debug.print("server.timeout -> 类型: {s}\n", .{schema.datatype.toTypeName()});
        }

        if (config.getSchema("database.pool_size")) |schema| {
            std.debug.print("database.pool_size -> 类型: {s}\n", .{schema.datatype.toTypeName()});
        }

        std.debug.print("  ✓ 路径语法 Schema 查询成功\n\n", .{});
    }

    // 示例 3: Schema 验证和调试
    {
        std.debug.print("示例 3: Schema 验证和调试\n", .{});
        std.debug.print("-------------------\n", .{});

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.set("max_conn:u8", "200");
        try config.set("buffer_size:u16", "8192");

        // 验证类型约束
        const max_conn_schema = config.getSchema("max_conn").?;
        const buffer_size_schema = config.getSchema("buffer_size").?;

        std.debug.print("max_conn Schema:\n", .{});
        std.debug.print("  类型: {s}\n", .{max_conn_schema.datatype.toTypeName()});
        std.debug.print("  值: {s}\n", .{max_conn_schema.value});
        std.debug.print("  可接受的最大值: 255\n", .{});

        std.debug.print("buffer_size Schema:\n", .{});
        std.debug.print("  类型: {s}\n", .{buffer_size_schema.datatype.toTypeName()});
        std.debug.print("  值: {s}\n", .{buffer_size_schema.value});
        std.debug.print("  可接受的最大值: 65535\n", .{});

        std.debug.print("  ✓ Schema 验证完成\n\n", .{});
    }

    std.debug.print("=== 演示完成 ===\n\n", .{});

    std.debug.print("✨ getSchema() 的价值：\n", .{});
    std.debug.print("  1. 准确反映 Schema 本质：获取类型定义和约束\n", .{});
    std.debug.print("  2. 支持路径语法：getSchema(\"section.key\") 查询嵌套配置\n", .{});
    std.debug.print("  3. 调试和验证：检查配置项的类型是否符合预期\n", .{});
    std.debug.print("  4. 类型安全：提供运行时 Schema 信息访问\n", .{});
}
