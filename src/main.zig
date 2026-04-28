//! zig-ini 示例程序
//!
//! 展示如何使用 INI 库加载、修改和保存配置文件

const std = @import("std");
const Ini = @import("ini.zig").Ini;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    std.debug.print("=== INI 库示例 ===\n\n", .{});

    // 创建 INI 配置
    var ini = Ini.init(arena);
    defer ini.deinit();

    // 设置全局配置
    try ini.set("app_name", "zig-ini");
    try ini.set("version", "1.0.0");
    try ini.set("debug", "true");

    // 创建数据库配置段
    try ini.setSection("database", "host", "localhost");
    try ini.setSection("database", "port", "5432");
    try ini.setSection("database", "name", "mydb");

    // 创建服务器配置段
    try ini.setSection("server", "host", "0.0.0.0");
    try ini.setSection("server", "port", "8080");
    try ini.setSection("server", "workers", "4");

    std.debug.print("已创建配置:\n", .{});

    // 保存到字符串并显示
    const content = try ini.saveToString(arena);
    std.debug.print("{s}\n", .{content});

    std.debug.print("\n=== 读取配置示例 ===\n", .{});
    std.debug.print("应用名称: {s}\n", .{ini.get("app_name").?});
    std.debug.print("数据库主机: {s}\n", .{ini.getSection("database", "host").?});
    std.debug.print("服务器端口: {s}\n", .{ini.getSection("server", "port").?});

    std.debug.print("\n=== Section 列表 ===\n", .{});
    std.debug.print("database section 存在: {}\n", .{ini.hasSection("database")});
    std.debug.print("cache section 存在: {}\n", .{ini.hasSection("cache")});

    std.debug.print("\n示例完成!\n", .{});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    try std.testing.fuzz({}, testOne, .{});
}

fn testOne(context: void, smith: *std.testing.Smith) !void {
    _ = context;
    // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!

    const gpa = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);
    while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
        .add_data => {
            const slice = try list.addManyAsSlice(gpa, smith.value(u4));
            smith.bytes(slice);
        },
        .dup_data => {
            if (list.items.len == 0) continue;
            if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
            const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
            const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
            try list.appendSlice(gpa, list.items[off..][0..len]);
            try std.testing.expectEqualSlices(
                u8,
                list.items[off..][0..len],
                list.items[list.items.len - len ..],
            );
        },
    };
}
