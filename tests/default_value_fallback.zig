//! 默认值回退功能测试
//!
//! 测试 Schema 的 getValue() 方法实现默认值回退机制

const std = @import("std");
const Ini = @import("zini").Ini;

test "默认值回退：value 为空时使用 default" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 添加带默认值的配置，value 为空
    var schema = try Ini.Schema.init(allocator, "port", "");
    defer schema.deinit(allocator);
    schema.default = try allocator.dupe(u8, "8080");

    try ini.addItem("port", schema);

    // 测试：value 为空，应该返回 default
    const schema_ptr = ini.getSchema("port").?;
    const port = try schema_ptr.asI16();
    try std.testing.expectEqual(@as(i16, 8080), port);
}

test "默认值回退：value 有值时优先使用 value" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    var schema = try Ini.Schema.init(allocator, "port", "9000");
    defer schema.deinit(allocator);
    schema.default = try allocator.dupe(u8, "8080");

    try ini.addItem("port", schema);

    const port = try ini.getI16("port");
    try std.testing.expectEqual(@as(i16, 9000), port);
}

test "默认值回退：value 和 default 都为空" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("empty", "");

    const schema = ini.getSchema("empty").?;
    // 空字符串转整数应该失败
    const result = schema.asI16();
    try std.testing.expectError(error.InvalidCharacter, result);
}

test "默认值回退：INI 文件解析（空 value 使用 default）" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default 8080
        \\port =
        \\# @default localhost
        \\host = 192.168.1.1
    ;

    try ini.loadFromString(content);

    // port 的 value 为空，应该使用 default 8080
    const port = try ini.getI16("port");
    try std.testing.expectEqual(@as(i16, 8080), port);

    // host 的 value 不为空，应该使用实际值
    const host = try ini.getString("host");
    try std.testing.expectEqualStrings("192.168.1.1", host);
}

test "默认值回退：只有 default 没有值的情况" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default 100
        \\timeout =
    ;

    try ini.loadFromString(content);

    // timeout 的 value 为空，应该使用 default 100
    const timeout = try ini.getI32("timeout");
    try std.testing.expectEqual(@as(i32, 100), timeout);
}

test "默认值回退：布尔类型默认值" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default true
        \\enabled =
    ;

    try ini.loadFromString(content);

    const enabled = try ini.getBool("enabled");
    try std.testing.expectEqual(true, enabled);
}

test "默认值回退：浮点数默认值" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default 3.14
        \\rate =
    ;

    try ini.loadFromString(content);

    const rate = try ini.getF64("rate");
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), rate, 0.001);
}

test "默认值回退：字符串类型默认值" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default default_value
        \\title =
    ;

    try ini.loadFromString(content);

    const title = try ini.getString("title");
    try std.testing.expectEqualStrings("default_value", title);
}
