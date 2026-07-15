//! 默认值回退功能测试
//!
//! 测试 Item 的 getValue() 方法实现默认值回退机制

const std = @import("std");
const Ini = @import("zini").Ini;
const Item = @import("zini").Item;

test "默认值回退：value 为空时使用 default" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 添加带默认值的配置，value 为空
    var item = try Item.init(allocator, "port", "");
    defer item.deinit(allocator);
    item.default = try allocator.dupe(u8, "8080");

    try ini.addItem("port", item);

    // 测试：value 为空，应该返回 default
    const item_ptr = ini.getItem("port").?;
    const port = try item_ptr.asNumber();
    try std.testing.expectEqual(@as(i64, 8080), port);
}

test "默认值回退：value 有值时优先使用 value" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    var item = try Item.init(allocator, "port", "9000");
    defer item.deinit(allocator);
    item.default = try allocator.dupe(u8, "8080");

    try ini.addItem("port", item);

    const port = ini.getNumber("port");
    try std.testing.expectEqual(@as(i64, 9000), port);
}

test "默认值回退：value 和 default 都为空" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("empty", "");

    const item = ini.getItem("empty").?;
    // 空字符串转整数应该失败
    const result = item.asNumber();
    try std.testing.expectError(error.InvalidCharacter, result);
}

test "默认值回退：INI 文件解析（空 value 使用 default）" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\# @default 8080
        \\port =
        \\# @default localhost
        \\host = 192.168.1.1
    ;

    try ini.loadFromString(content);

    // port 的 value 为空，应该使用 default 8080
    const port = ini.getNumber("port");
    try std.testing.expectEqual(@as(i64, 8080), port);

    // host 的 value 不为空，应该使用实际值
    const host = ini.get("host");
    try std.testing.expectEqualStrings("192.168.1.1", host.?);
}

test "默认值回退：只有 default 没有值的情况" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\# @default 100
        \\timeout =
    ;

    try ini.loadFromString(content);

    // timeout 的 value 为空，应该使用 default 100
    const timeout = ini.getNumber("timeout");
    try std.testing.expectEqual(@as(i64, 100), timeout);
}

test "默认值回退：布尔类型默认值" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\# @default true
        \\enabled =
    ;

    try ini.loadFromString(content);

    const enabled = ini.getNumber("enabled");
    try std.testing.expectEqual(true, enabled);
}

test "默认值回退：浮点数默认值" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\# @default 3.14
        \\rate =
    ;

    try ini.loadFromString(content);

    const rate = ini.getFloat("rate");
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), rate, 0.001);
}

test "默认值回退：字符串类型默认值" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\# @default default_value
        \\title =
    ;

    try ini.loadFromString(content);

    const title = ini.get("title");
    try std.testing.expectEqualStrings("default_value", title.?);
}
