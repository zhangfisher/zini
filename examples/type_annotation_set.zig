//! 类型标注功能演示 - set() 方法的类型标注特性

const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== 类型标注功能演示 ===\n\n", .{});

    // 示例 1: 基本类型标注
    {
        std.debug.print("示例 1: 基本类型标注\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 使用类型标注设置值
        try config.set("count:u8", "255");
        try config.set("port:u16", "8080");
        try config.set("timeout:i32", "30");
        try config.set("rate:f64", "3.14159");
        try config.set("enabled", "true");
        try config.set("name", "MyApp");

        // 保存到文件
        const test_file = "type_demo.ini";
        try config.save(test_file);
        std.debug.print("  ✓ 配置已保存到 {s}\n", .{test_file});

        // 重新加载并验证
        var config2 = Ini.init(allocator);
        defer config2.deinit();

        try config2.load(test_file);

        const count = try config2.getU8("count");
        const port = try config2.getU16("port");
        const timeout = try config2.getI32("timeout");
        const rate = try config2.getF64("rate");
        const enabled = try config2.getBool("enabled");
        const name = config2.get("name").?;

        std.debug.print("  count (u8): {}\n", .{count});
        std.debug.print("  port (u16): {}\n", .{port});
        std.debug.print("  timeout (i32): {}\n", .{timeout});
        std.debug.print("  rate (f64): {d:.5}\n", .{rate});
        std.debug.print("  enabled (bool): {}\n", .{enabled});
        std.debug.print("  name (string): {s}\n", .{name});

        std.debug.print("  ✓ 类型标注验证成功\n\n", .{});
    }

    // 示例 2: 路径语法 + 类型标注
    {
        std.debug.print("示例 2: 路径语法 + 类型标注\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 路径语法配合类型标注
        try config.set("server.port:u16", "9000");
        try config.set("server.timeout:i32", "60");
        try config.set("server.enabled", "true");
        try config.set("database.port:u16", "5432");
        try config.set("database.pool_size:u32", "20");

        const content = try config.saveToString(allocator);
        defer allocator.free(content);

        std.debug.print("  生成的配置文件内容：\n", .{});
        std.debug.print("{s}\n", .{content});

        std.debug.print("  ✓ 路径语法与类型标注完美配合\n\n", .{});
    }

    // 示例 3: 混合使用类型标注和自动推断
    {
        std.debug.print("示例 3: 混合使用类型标注和自动推断\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 显式类型标注
        try config.set("max_connections:u32", "100");

        // 自动推断（不写类型标注）
        try config.set("app_name", "DemoApp");
        try config.set("debug_mode", "true");

        const content = try config.saveToString(allocator);
        defer allocator.free(content);

        std.debug.print("  生成的配置：\n", .{});
        std.debug.print("{s}\n", .{content});

        std.debug.print("  ✓ 混合使用灵活方便\n\n", .{});
    }

    // 示例 4: 读取并修改带类型标注的配置
    {
        std.debug.print("示例 4: 读取并修改配置\n", .{});
        const original_content =
            \\count:u8 = 100
            \\port:u16 = 8080
            \\timeout:i32 = 30
            \\enabled = true
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(original_content);

        std.debug.print("  原始配置：\n", .{});
        std.debug.print("  count: {} (类型: {s})\n", .{ try config.getU8("count"), config.getSchema("count").?..datatype.typeName() orelse "unknown" });
        std.debug.print("  port: {} (类型: {s})\n", .{ try config.getU16("port"), config.getSchema("port").?..datatype.typeName() orelse "unknown" });

        // 使用类型标注更新值
        try config.set("count:u8", "200");
        try config.set("port:u16", "9000");

        std.debug.print("\n  更新后的配置：\n", .{});
        const updated = try config.saveToString(allocator);
        defer allocator.free(updated);

        std.debug.print("{s}\n", .{updated});
        std.debug.print("  ✓ 配置更新成功\n\n", .{});
    }

    std.debug.print("=== 所有演示完成 ===\n", .{});

    std.debug.print("\n✨ 类型标注优势：\n", .{});
    std.debug.print("  • 明确类型：在配置文件中显式指定类型\n", .{});
    std.debug.print("  • 类型安全：读取时自动验证类型正确性\n", .{});
    std.debug.print("  • 灵活性：可选择使用类型标注或自动推断\n", .{});
    std.debug.print("  • 路径兼容：与路径语法完美配合\n", .{});

    // 清理测试文件
    std.fs.cwd().deleteFile("type_demo.ini") catch {};
}
