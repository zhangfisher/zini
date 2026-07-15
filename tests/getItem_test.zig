//! 简单测试 getItem 的 section.key 语法支持

const std = @import("std");
const Ini = @import("zini").Ini;

test "getItem section.key 语法简单测试" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 添加测试数据
    try ini.set("global_key", "global_value");
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");

    // 测试全局 key
    if (ini.getItem("global_key")) |schema| {
        try std.testing.expectEqualStrings("global_key", schema.key);
        try std.testing.expectEqualStrings("global_value", schema.value);
    } else {
        try std.testing.expect(false);
    }

    // 测试 section.key 语法
    if (ini.getItem("database.host")) |schema| {
        try std.testing.expectEqualStrings("host", schema.key);
        try std.testing.expectEqualStrings("localhost", schema.value);
    } else {
        try std.testing.expect(false);
    }

    if (ini.getItem("database.port")) |schema| {
        try std.testing.expectEqualStrings("port", schema.key);
        try std.testing.expectEqualStrings("5432", schema.value);
    } else {
        try std.testing.expect(false);
    }

    // 测试不存在的 key
    try std.testing.expect(ini.getItem("nonexistent") == null);
    try std.testing.expect(ini.getItem("database.nonexistent") == null);
}
