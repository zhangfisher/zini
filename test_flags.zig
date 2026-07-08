//! 测试 SchemFlags 功能

const std = @import("std");
const Ini = @import("src/root.zig").Ini;
const SchemFlags = @import("src/types.zig").SchemFlags;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("\n=== SchemFlags 功能测试 ===\n\n", .{});

    // 测试1：有 @type 标记时，flags.hasType = 1
    {
        std.debug.print("测试1：有 @type 标记时 flags.hasType = 1...\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        const content =
            \\# @type u16
            \\port = 8080
        ;

        try ini.loadFromString(content);
        const schema = ini.getSchema("port").?;

        if (schema.flags != SchemFlags.hasType) {
            std.debug.print("  ❌ 失败：期望 hasType，实际为 {}\n", .{@intFromEnum(schema.flags)});
            return error.TestFailed;
        }
        std.debug.print("  ✅ 通过（flags.hasType = 1）\n\n", .{});
    }

    // 测试2：没有 @type 标记时，flags.none = 0
    {
        std.debug.print("测试2：没有 @type 标记时 flags.none = 0...\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        const content =
            \\port = 8080
        ;

        try ini.loadFromString(content);
        const schema = ini.getSchema("port").?;

        if (schema.flags != SchemFlags.none) {
            std.debug.print("  ❌ 失败：期望 none，实际为 {}\n", .{@intFromEnum(schema.flags)});
            return error.TestFailed;
        }
        std.debug.print("  ✅ 通过（flags.none = 0）\n\n", .{});
    }

    // 测试3：保存时，有 flags.hasType 时写入 @type
    {
        std.debug.print("测试3：保存时 flags.hasType 时写入 @type...\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        const content =
            \\# @type u16
            \\port = 8080
        ;

        try ini.loadFromString(content);
        const saved = try ini.saveToString(allocator);
        defer allocator.free(saved);

        // 检查保存的字符串中是否包含 @type
        if (std.mem.indexOf(u8, saved, "@type") == null) {
            std.debug.print("  ❌ 失败：保存的内容中没有 @type 标记\n", .{});
            std.debug.print("  保存的内容：\n{s}\n", .{saved});
            return error.TestFailed;
        }

        // 检查是否包含正确的类型
        if (std.mem.indexOf(u8, saved, "@type u16") == null) {
            std.debug.print("  ❌ 失败：@type 标记不正确\n", .{});
            std.debug.print("  保存的内容：\n{s}\n", .{saved});
            return error.TestFailed;
        }

        std.debug.print("  ✅ 通过（正确写入 @type u16）\n\n", .{});
    }

    // 测试4：保存时，没有 flags.hasType 时不写入 @type
    {
        std.debug.print("测试4：保存时没有 flags.hasType 时不写入 @type...\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        const content =
            \\port = 8080
        ;

        try ini.loadFromString(content);
        const saved = try ini.saveToString(allocator);
        defer allocator.free(saved);

        // 检查保存的字符串中是否不包含 @type
        if (std.mem.indexOf(u8, saved, "@type") != null) {
            std.debug.print("  ❌ 失败：保存的内容中不应该有 @type 标记\n", .{});
            std.debug.print("  保存的内容：\n{s}\n", .{saved});
            return error.TestFailed;
        }

        std.debug.print("  ✅ 通过（不写入 @type）\n\n", .{});
    }

    // 测试5：通用类型（bool）有 flags.hasType 时也写入 @type
    {
        std.debug.print("测试5：通用类型 bool 有 flags.hasType 时也写入 @type...\n", .{});
        var ini = Ini.init(allocator);
        defer ini.deinit();

        const content =
            \\# @type bool
            \\enabled = true
        ;

        try ini.loadFromString(content);
        const saved = try ini.saveToString(allocator);
        defer allocator.free(saved);

        // 检查保存的字符串中是否包含 @type bool
        if (std.mem.indexOf(u8, saved, "@type bool") == null) {
            std.debug.print("  ❌ 失败：应该写入 @type bool\n", .{});
            std.debug.print("  保存的内容：\n{s}\n", .{saved});
            return error.TestFailed;
        }

        std.debug.print("  ✅ 通过（通用类型也写入 @type）\n\n", .{});
    }

    std.debug.print("\n✅ 所有 SchemFlags 测试通过！\n\n", .{});
}
