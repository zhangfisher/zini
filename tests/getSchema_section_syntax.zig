//! getItem 方法支持 section.key 语法的测试

const std = @import("std");
const Ini = @import("zini").Ini;
const Item = @import("zini").Item;

test "getItem 支持 section.key 语法" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 添加全局配置
    try ini.set("global_key", "global_value");
    try ini.set("timeout", "30");

    // 添加 section 配置
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");
    try ini.set("server.host", "0.0.0.0");

    // 测试全局 key
    if (ini.getItem("global_key")) |item| {
        try std.testing.expectEqualStrings("global_key", item.key);
        try std.testing.expectEqualStrings("global_value", item.value);
    } else {
        try std.testing.expect(false); // 应该能找到
    }

    // 测试 section.key 语法
    if (ini.getItem("database.host")) |item| {
        try std.testing.expectEqualStrings("host", item.key);
        try std.testing.expectEqualStrings("localhost", item.value);
    } else {
        try std.testing.expect(false); // 应该能找到
    }

    if (ini.getItem("database.port")) |item| {
        try std.testing.expectEqualStrings("port", item.key);
        try std.testing.expectEqualStrings("5432", item.value);
    } else {
        try std.testing.expect(false); // 应该能找到
    }

    // 测试不存在的 key
    try std.testing.expect(ini.getItem("nonexistent") == null);
    try std.testing.expect(ini.getItem("database.nonexistent") == null);
    try std.testing.expect(ini.getItem("nonexistent.key") == null);
}

test "getItem 配合类型转换使用" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("timeout", "30");
    try ini.set("database.port", "5432");
    try ini.set("cache.enabled", "true");

    // 使用 getItem 获取全局配置然后转换类型
    if (ini.getItem("timeout")) |item| {
        const value = try item.asNumber();
        try std.testing.expectEqual(@as(i64, 30), value);
    }

    // 使用 getItem 获取 section 配置然后转换类型
    if (ini.getItem("database.port")) |item| {
        const value = try item.asNumber();
        try std.testing.expectEqual(@as(i64, 5432), value);
    }

    if (ini.getItem("cache.enabled")) |item| {
        const value = try item.asBoolean();
        try std.testing.expectEqual(true, value);
    }
}

test "getItem 配合 forEach 使用" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("app.name", "MyApp");
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");

    // 使用 forEach 遍历所有配置
    var count: usize = 0;
    ini.forEach("*", struct {
        fn callback(item: *const Item, section: ?[]const u8, ctx: *usize) void {
            _ = section;
            _ = item;
            ctx.* += 1;
        }
    }.callback, &count);

    try std.testing.expectEqual(@as(usize, 3), count);

    // 使用 getItem 验证特定配置
    try std.testing.expect(ini.getItem("app.name") != null);
    try std.testing.expect(ini.getItem("database.host") != null);
    try std.testing.expect(ini.getItem("database.port") != null);
}

test "getItem 访问 item 元数据" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("title_with_desc", "value");
    try ini.set("section.config", "value");

    // 访问全局 item 的元数据
    if (ini.getItem("title_with_desc")) |item| {
        try std.testing.expectEqualStrings("title_with_desc", item.key);
        try std.testing.expectEqualStrings("value", item.value);
        // item.datatype 应该是 string
        try std.testing.expect(item.datatype == .string);
    }

    // 访问 section item 的元数据
    if (ini.getItem("section.config")) |item| {
        try std.testing.expectEqualStrings("config", item.key);
        try std.testing.expectEqualStrings("value", item.value);
        // item.datatype 应该是 string
        try std.testing.expect(item.datatype == .string);
    }
}
