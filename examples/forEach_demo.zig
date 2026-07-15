//! forEach 函数重构示例
//! 展示新的 forEach 函数的三种迭代模式

const std = @import("std");
const Ini = @import("../src/ini.zig").Ini;

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 添加示例配置
    try ini.set("app.name", "DemoApp");
    try ini.set("app.version", "1.0.0");
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");
    try ini.set("cache.enabled", "true");
    try ini.set("cache.ttl", "3600");

    std.debug.print("=== forEach 函数重构示例 ===\n\n", .{});

    // 1. 迭代所有配置项 (section = "*")
    std.debug.print("1. 迭代所有配置项 ('*'):\n", .{});
    try demoForEachAll(&ini);

    // 2. 只迭代全局配置项 (section = "")
    std.debug.print("\n2. 只迭代全局配置项 (''):\n", .{});
    try demoForEachGlobal(&ini);

    // 3. 只迭代指定section (section = "section_name")
    std.debug.print("\n3. 只迭代database section:\n", .{});
    try demoForEachSection(&ini, "database");

    std.debug.print("\n=== 示例完成 ===\n", .{});
}

// 辅助函数：迭代所有配置项
fn demoForEachAll(ini: *const Ini) !void {
    var count: usize = 0;

    const Handler = struct {
        fn callback(item: *const Ini.Ini.Item, section: ?[]const u8, ctx: *usize) void {
            _ = section;
            const key = item.key orelse return;
            const value = item.value orelse return;

            std.debug.print("  {s} = {s}\n", .{ key, value });
            ctx.* += 1; // 修改外部计数器
        }
    };

    ini.forEach("*", Handler.callback, &count);

    std.debug.print("  迭代所有配置项完成，共 {d} 项\n", .{count});
}

// 辅助函数：迭代全局配置项
fn demoForEachGlobal(ini: *const Ini) !void {
    var app_count: usize = 0;

    const Context = struct {
        fn callback(item: *const Ini.Ini.Item, section: ?[]const u8, ctx: *usize) void {
            if (section == null and item.key) |key| {
                if (std.mem.startsWith(u8, key, "app.")) {
                    std.debug.print("  {s} = {s}\n", .{ key, item.value orelse "" });
                    ctx.* += 1;
                }
            }
        }
    };

    ini.forEach("", Context.callback, &app_count);

    std.debug.print("  迭代全局配置项完成，app 配置共 {d} 项\n", .{app_count});
}

// 辅助函数：迭代指定section
fn demoForEachSection(ini: *const Ini, section_name: []const u8) !void {
    var section_count: usize = 0;

    const Context = struct {
        fn callback(item: *const Ini.Ini.Item, section: ?[]const u8, ctx: *usize) void {
            if (section) |sec| {
                if (item.key) |key| {
                    std.debug.print("  [{s}] {s} = {s}\n", .{ sec, key, item.value orelse "" });
                    ctx.* += 1;
                }
            }
        }
    };

    ini.forEach(section_name, Context.callback, &section_count);

    std.debug.print("  迭代 {s} section 完成，共 {d} 项\n", .{ section_name, section_count });
}
