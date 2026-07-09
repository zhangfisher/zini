const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;
const Schema = @import("zini").Schema;

// 测试元数据解析：@default
test "元数据解析：@default" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default 8080
        \\# 服务器端口
        \\# @title 侦听端口
        \\port = 9000
    ;

    try ini.loadFromString(content);
    const schema = ini.getSchema("port").?;

    try testing.expect(schema.default != null);
    try testing.expectEqualStrings("8080", schema.default.?);
    try testing.expectEqualStrings("9000", schema.value);
    try testing.expectEqualStrings("侦听端口", schema.title.?);

    std.debug.print("  ✓ @default 元数据解析测试通过\n", .{});
}

// 测试元数据解析：@enum
test "元数据解析：@enum" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @enum 8080,8081,8082
        \\# 端口配置
        \\port = 8080
    ;

    try ini.loadFromString(content);
    const schema = ini.getSchema("port").?;

    try testing.expect(schema.@"enum" != null);
    try testing.expectEqualStrings("8080,8081,8082", schema.@"enum".?);

    std.debug.print("  ✓ @enum 元数据解析测试通过\n", .{});
}

// 测试元数据写入和重新加载
test "元数据写入和重新加载" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 手动创建带有元数据的Schema
    var schema = try Schema.init(allocator, "port", "9000");
    defer schema.deinit(allocator);

    schema.title = try allocator.dupe(u8, "侦听端口");
    schema.default = try allocator.dupe(u8, "8080");
    schema.@"enum" = try allocator.dupe(u8, "8080,8081,8082");

    try ini.addItem("port", schema);

    // add()会深拷贝，所以需要手动释放这些字段
    allocator.free(schema.title.?);
    allocator.free(schema.default.?);
    allocator.free(schema.@"enum".?);

    // 将字段设为null，避免defer deinit再次释放
    schema.title = null;
    schema.default = null;
    schema.@"enum" = null;

    // 保存到字符串
    const saved = try ini.saveToString(allocator);
    defer allocator.free(saved);

    std.debug.print("  保存的内容:\n{s}\n", .{saved});

    // 重新加载
    var ini2 = Ini.init(allocator);
    defer ini2.deinit();
    try ini2.loadFromString(saved);

    // 验证元数据保留
    const loaded_schema = ini2.getSchema("port").?;
    try testing.expectEqualStrings("侦听端口", loaded_schema.title.?);
    try testing.expectEqualStrings("8080", loaded_schema.default.?);
    try testing.expectEqualStrings("8080,8081,8082", loaded_schema.@"enum".?);
    try testing.expectEqualStrings("9000", loaded_schema.value);

    std.debug.print("  ✓ 元数据写入和重新加载测试通过\n", .{});
}

// 测试向后兼容：现有@title功能
test "向后兼容：现有@title功能" {
    const allocator = std.testing.allocator;
    var ini = Ini.initWithOptions(allocator, .{ .flags = 1 }); // 启用LoadDescription
    defer ini.deinit();

    const content =
        \\# @title 测试标题
        \\# 普通描述
        \\key = value
    ;

    try ini.loadFromString(content);
    const schema = ini.getSchema("key").?;

    try testing.expectEqualStrings("测试标题", schema.title.?);
    try testing.expectEqualStrings("普通描述", schema.description.?);

    std.debug.print("  ✓ 向后兼容测试通过\n", .{});
}

// 测试空格兼容性
test "元数据解析：空格兼容性" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @title    标题
        \\# @default  8080
        \\# @enum   8080,8081
        \\key = value
    ;

    try ini.loadFromString(content);
    const schema = ini.getSchema("key").?;

    try testing.expectEqualStrings("标题", schema.title.?);
    try testing.expectEqualStrings("8080", schema.default.?);
    try testing.expectEqualStrings("8080,8081", schema.@"enum".?);

    std.debug.print("  ✓ 空格兼容性测试通过\n", .{});
}

// 测试只有部分元数据的情况
test "元数据解析：只有部分元数据" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default 8080
        \\port = 9000
    ;

    try ini.loadFromString(content);
    const schema = ini.getSchema("port").?;

    try testing.expect(schema.default != null);
    try testing.expect(schema.title == null);  // 没有title
    try testing.expect(schema.@"enum" == null); // 没有enum

    std.debug.print("  ✓ 部分元数据测试通过\n", .{});
}

// 测试写入顺序
test "元数据写入：正确的顺序" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 手动创建带有完整元数据的Schema
    var schema = try Schema.init(allocator, "db_host", "localhost");
    defer schema.deinit(allocator);

    schema.description = try allocator.dupe(u8, "数据库服务器地址");
    schema.title = try allocator.dupe(u8, "数据库主机");
    schema.default = try allocator.dupe(u8, "localhost");
    schema.@"enum" = try allocator.dupe(u8, "localhost,127.0.0.1");

    try ini.addItem("db_host", schema);

    // add()会深拷贝，所以需要手动释放这些字段
    allocator.free(schema.description.?);
    allocator.free(schema.title.?);
    allocator.free(schema.default.?);
    allocator.free(schema.@"enum".?);

    // 将字段设为null，避免defer deinit再次释放
    schema.description = null;
    schema.title = null;
    schema.default = null;
    schema.@"enum" = null;

    // 保存到字符串
    const saved = try ini.saveToString(allocator);
    defer allocator.free(saved);

    std.debug.print("  保存的格式:\n{s}\n", .{saved});

    // 验证顺序：description → #  → title → default → enum
    const expected =
        \\# 数据库服务器地址
        \\#
        \\# @title 数据库主机
        \\# @default localhost
        \\# @enum localhost,127.0.0.1
        \\db_host = localhost
        \\
    ;

    try testing.expectEqualStrings(expected, saved);

    std.debug.print("  ✓ 写入顺序测试通过\n", .{});
}
