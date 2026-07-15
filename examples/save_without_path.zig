//! 演示记住文件路径的功能

const std = @import("std");
const Ini = @import("../src/ini.zig").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== 记住文件路径演示 ===\n\n", .{});

    // 示例 1: 加载后直接保存（不指定路径）
    {
        std.debug.print("示例 1: load() 后直接调用 save()\n", .{});

        // 创建一个临时文件
        const test_file = "test_config.ini";

        // 创建并写入初始配置
        {
            var config = Ini.default(allocator);
            defer config.deinit();

            try config.set("app_name", "TestApp");
            try config.set("version", "1.0.0");
            try config.set("database.host", "localhost");
            try config.set("database.port", "5432");

            // 首次保存需要指定路径
            try config.saveAndRemember(test_file);
            std.debug.print("  ✓ 首次保存到: {s}\n", .{test_file});
        }

        // 加载配置文件
        var config = Ini.default(allocator);
        defer config.deinit();

        try config.load(test_file);
        std.debug.print("  ✓ 从文件加载: {s}\n", .{test_file});

        // 修改配置
        try config.set("version", "1.1.0");
        try config.set("database.port", "3306");

        // 现在可以直接调用 save()，不需要指定路径
        try config.save();
        std.debug.print("  ✓ 使用 save() 保存（无需指定路径）\n", .{});

        // 验证保存的内容
        var config2 = Ini.default(allocator);
        defer config2.deinit();

        try config2.load(test_file);

        const version = config2.get("version").?;
        const db_port = try config2.getInt("database.port");

        std.debug.print("  ✓ 验证: version={s}, database.port={}\n", .{version, db_port});

        std.debug.print("\n", .{});
    }

    // 示例 2: 使用 saveTo 指定不同路径
    {
        std.debug.print("示例 2: 使用 saveTo() 保存到不同路径\n", .{});

        const file1 = "config1.ini";
        const file2 = "config2.ini";

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.set("key", "value1");

        // 保存到第一个文件
        try config.saveAndRemember(file1);
        std.debug.print("  ✓ 保存到: {s}\n", .{file1});

        // 修改值
        try config.set("key", "value2");

        // 保存到第二个文件（不改变记住的路径）
        try config.saveTo(file2);
        std.debug.print("  ✓ 保存到: {s}（记住的路径仍是 {s}）\n", .{file2, file1});

        // 再次调用 save()，应该保存到 file1
        try config.set("key", "value3");
        try config.save();
        std.debug.print("  ✓ save() 保存到记住的路径: {s}\n", .{file1});

        // 验证两个文件的内容
        var config1 = Ini.default(allocator);
        defer config1.deinit();
        try config1.load(file1);

        var config2 = Ini.default(allocator);
        defer config2.deinit();
        try config2.load(file2);

        std.debug.print("  ✓ {s} 内容: key={s}\n", .{file1, config1.get("key").?});
        std.debug.print("  ✓ {s} 内容: key={s}\n", .{file2, config2.get("key").?});

        std.debug.print("\n", .{});
    }

    std.debug.print("=== 演示完成 ===\n", .{});

    std.debug.print("\n提示：临时文件 test_config.ini, config1.ini, config2.ini 可供查看\n", .{});
}
