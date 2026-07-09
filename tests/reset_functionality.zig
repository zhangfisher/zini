//! reset() 方法功能测试

const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;

test "reset 基本功能：将配置重置为默认值" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default 8080
        \\port = 9000
        \\
        \\# @default localhost
        \\host = remotehost
        \\
        \\no_default = value
    ;

    try ini.loadFromString(content);

    // 验证初始值
    try testing.expectEqualStrings("9000", ini.getSchema("port").?.value);
    try testing.expectEqualStrings("remotehost", ini.getSchema("host").?.value);
    try testing.expectEqualStrings("value", ini.getSchema("no_default").?.value);

    // 重置配置
    try ini.reset();

    // 验证重置后的值
    try testing.expectEqualStrings("8080", ini.getSchema("port").?.value);
    try testing.expectEqualStrings("localhost", ini.getSchema("host").?.value);
    try testing.expectEqualStrings("value", ini.getSchema("no_default").?.value); // 无默认值，保持不变

    std.debug.print("  ✓ reset 基本功能测试通过\n", .{});
}

test "reset 处理 section 中的配置" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\[server]
        \\# @default 8080
        \\port = 9000
        \\
        \\[database]
        \\# @default localhost
        \\host = remotehost
    ;

    try ini.loadFromString(content);

    // 验证初始值
    try testing.expectEqualStrings("9000", ini.getSchema("server.port").?.value);
    try testing.expectEqualStrings("remotehost", ini.getSchema("database.host").?.value);

    // 重置配置
    try ini.reset();

    // 验证重置后的值
    try testing.expectEqualStrings("8080", ini.getSchema("server.port").?.value);
    try testing.expectEqualStrings("localhost", ini.getSchema("database.host").?.value);

    std.debug.print("  ✓ reset section 处理测试通过\n", .{});
}

test "reset 无默认值时保持原值" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\port = 9000
        \\host = remotehost
    ;

    try ini.loadFromString(content);

    // 验证初始值
    try testing.expectEqualStrings("9000", ini.getSchema("port").?.value);
    try testing.expectEqualStrings("remotehost", ini.getSchema("host").?.value);

    // 重置配置
    try ini.reset();

    // 验证值保持不变
    try testing.expectEqualStrings("9000", ini.getSchema("port").?.value);
    try testing.expectEqualStrings("remotehost", ini.getSchema("host").?.value);

    std.debug.print("  ✓ reset 无默认值测试通过\n", .{});
}

test "reset 混合场景：全局和 section" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default 8080
        \\global_port = 9000
        \\
        \\[server]
        \\# @default 8080
        \\port = 9000
        \\no_default = value
        \\
        \\[database]
        \\# @default localhost
        \\host = remotehost
    ;

    try ini.loadFromString(content);

    // 重置配置
    try ini.reset();

    // 验证全局配置
    try testing.expectEqualStrings("8080", ini.getSchema("global_port").?.value);

    // 验证 section 配置
    try testing.expectEqualStrings("8080", ini.getSchema("server.port").?.value);
    try testing.expectEqualStrings("value", ini.getSchema("server.no_default").?.value);
    try testing.expectEqualStrings("localhost", ini.getSchema("database.host").?.value);

    std.debug.print("  ✓ reset 混合场景测试通过\n", .{});
}

test "reset 内存安全验证" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @default 8080
        \\port = 9000
    ;

    try ini.loadFromString(content);

    // 获取原始 value 指针
    const old_value = ini.getSchema("port").?.value;

    // 重置配置
    try ini.reset();

    // 获取新的 value 指针
    const new_value = ini.getSchema("port").?.value;

    // 验证指针不同（内存重新分配）
    try testing.expect(old_value.ptr != new_value.ptr);
    try testing.expectEqualStrings("8080", new_value);

    std.debug.print("  ✓ reset 内存安全测试通过\n", .{});
}
