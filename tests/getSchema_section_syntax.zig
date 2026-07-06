//! getSchema 方法支持 section.key 语法的测试

const std = @import("std");
const Ini = @import("zini").Ini;
const Schema = @import("zini").Schema;

test "getSchema 支持 section.key 语法" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 添加全局配置
    try ini.set("global_key", "global_value");
    try ini.set("timeout", "30");

    // 添加 section 配置
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");
    try ini.set("server.host", "0.0.0.0");

    // 测试全局 key
    if (ini.getSchema("global_key")) |schema| {
        try std.testing.expectEqualStrings("global_key", schema.key);
        try std.testing.expectEqualStrings("global_value", schema.value);
    } else {
        try std.testing.expect(false); // 应该能找到
    }

    // 测试 section.key 语法
    if (ini.getSchema("database.host")) |schema| {
        try std.testing.expectEqualStrings("host", schema.key);
        try std.testing.expectEqualStrings("localhost", schema.value);
    } else {
        try std.testing.expect(false); // 应该能找到
    }

    if (ini.getSchema("database.port")) |schema| {
        try std.testing.expectEqualStrings("port", schema.key);
        try std.testing.expectEqualStrings("5432", schema.value);
    } else {
        try std.testing.expect(false); // 应该能找到
    }

    // 测试不存在的 key
    try std.testing.expect(ini.getSchema("nonexistent") == null);
    try std.testing.expect(ini.getSchema("database.nonexistent") == null);
    try std.testing.expect(ini.getSchema("nonexistent.key") == null);
}

test "getSchema 配合类型转换使用" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("timeout", "30");
    try ini.set("database.port", "5432");
    try ini.set("cache.enabled", "true");

    // 使用 getSchema 获取全局配置然后转换类型
    if (ini.getSchema("timeout")) |schema| {
        const value = try schema.asInt();
        try std.testing.expectEqual(@as(i64, 30), value);
    }

    // 使用 getSchema 获取 section 配置然后转换类型
    if (ini.getSchema("database.port")) |schema| {
        const value = try schema.asInt();
        try std.testing.expectEqual(@as(i64, 5432), value);
    }

    if (ini.getSchema("cache.enabled")) |schema| {
        const value = try schema.asBool();
        try std.testing.expectEqual(true, value);
    }
}

test "getSchema 配合 forEach 使用" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("app.name", "MyApp");
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");

    // 使用 forEach 遍历所有配置
    var count: usize = 0;
    ini.forEach(&count, struct {
        fn callback(ctx: *usize, section: ?[]const u8, schema: *const Schema) void {
            _ = section;
            _ = schema;
            const mctx = @constCast(ctx);
            mctx.* += 1;
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 3), count);

    // 使用 getSchema 验证特定配置
    try std.testing.expect(ini.getSchema("app.name") != null);
    try std.testing.expect(ini.getSchema("database.host") != null);
    try std.testing.expect(ini.getSchema("database.port") != null);
}

test "getSchema 访问 schema 元数据" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("title_with_desc", "value");
    try ini.set("section.config", "value");

    // 访问全局 schema 的元数据
    if (ini.getSchema("title_with_desc")) |schema| {
        try std.testing.expectEqualStrings("title_with_desc", schema.key);
        try std.testing.expectEqualStrings("value", schema.value);
        // schema.datatype 应该是 string
        try std.testing.expect(schema.datatype == .string);
    }

    // 访问 section schema 的元数据
    if (ini.getSchema("section.config")) |schema| {
        try std.testing.expectEqualStrings("config", schema.key);
        try std.testing.expectEqualStrings("value", schema.value);
        // schema.datatype 应该是 string
        try std.testing.expect(schema.datatype == .string);
    }
}
