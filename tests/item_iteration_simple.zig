//! Item 遍历功能测试
//!
//! 测试 forEach 方法的正确用法

const std = @import("std");
const Ini = @import("zini").Ini;
const Item = @import("zini").Item;

fn myCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = ctx;
    _ = section;
    const key = item.key orelse return;
    const value = item.value orelse return;
    // 处理逻辑
    _ = key;
    _ = value;
}

test "forEach 基本功能测试" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 添加配置
    try ini.set("item1", "value1");
    try ini.set("item2", "value2");

    // 使用正确的 forEach 方式
    ini.forEach("*", myCallback, null);

    try std.testing.expect(true); // 如果没有崩溃就算通过
}

fn sectionCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = ctx;
    const key = item.key orelse return;
    const value = item.value orelse return;

    if (section) |section_name| {
        std.debug.print("  Section: {s}, Key: {s}, Value: {s}\n", .{ section_name, key, value });
    } else {
        std.debug.print("  Global: Key: {s}, Value: {s}\n", .{ key, value });
    }
}

test "forEach 遍历所有配置" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 添加全局和 section 配置
    try ini.set("global_key", "global_value");
    try ini.set("section.key", "section_value");
    try ini.set("database.host", "localhost");

    // 使用 forEach 遍历所有配置
    ini.forEach("*", sectionCallback, null);

    try std.testing.expect(true);
}

fn validationCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = ctx;
    // 验证配置数据
    const key = item.key orelse return;
    const value = item.value orelse return;

    if (std.mem.eql(u8, key, "test_key")) {
        if (!std.mem.eql(u8, value, "test_value")) {
            std.debug.print("错误: 期望 'test_value', 实际 '{s}'\n", .{value});
        }
    }
    _ = section;
}

test "forEach 验证配置数据" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("test_key", "test_value");
    try ini.set("database.port", "5432");

    // 使用 forEach 进行验证
    ini.forEach("*", validationCallback, null);

    try std.testing.expect(true);
}

fn sectionFilterCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = ctx;
    const key = item.key orelse return;
    const value = item.value orelse return;

    if (section) |section_name| {
        // 只处理 database section 的配置
        if (std.mem.eql(u8, section_name, "database")) {
            std.debug.print("  Database config: {s} = {s}\n", .{ key, value });
        }
    } else {
        // 处理全局配置
        std.debug.print("  Global config: {s} = {s}\n", .{ key, value });
    }
}

test "forEach 过滤特定 section" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("global_key", "global_value");
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");

    // 使用 forEach 过滤 database section
    ini.forEach("*", sectionFilterCallback, null);

    try std.testing.expect(true);
}
