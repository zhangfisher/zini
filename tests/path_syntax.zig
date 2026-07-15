//! 路径语法功能测试
//! 路径语法功能测试

const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;

test "path syntax basic functionality" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 使用路径语法设置值
    try config.set("server.port", "8080");
    try config.set("server.host", "localhost");
    try config.set("database.port", "5432");

    // 使用路径语法获取值
    const server_port = config.get("server.port");
    const server_host = config.get("server.host");
    const db_port = config.get("database.port");

    try testing.expectEqualStrings("8080", server_port.?);
    try testing.expectEqualStrings("localhost", server_host.?);
    try testing.expectEqualStrings("5432", db_port.?);
}

test "path syntax with typed methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 设置类型化值
    try config.set("app.debug", "true");
    try config.set("app.port", "3000");
    try config.set("app.timeout", "30.5");

    // 使用类型化方法获取
    const debug = try config.getBoolean("app.debug");
    const port = try config.getNumber("app.port");
    const timeout = try config.getFloat("app.timeout");

    try testing.expect(debug);
    try testing.expectEqual(@as(i64, 3000), port);
    try testing.expectApproxEqAbs(@as(f64, 30.5), timeout, 0.01);
}

test "path syntax multi-level" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 设置多级路径
    try config.set("server.config.timeout", "60");
    try config.set("server.config.retry", "3");

    // 获取多级路径
    const timeout = config.get("server.config.timeout");
    const retry = config.get("server.config.retry");

    try testing.expectEqualStrings("60", timeout orelse "");
    try testing.expectEqualStrings("3", retry orelse "");
}

test "path syntax edge cases" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 测试无效路径格式
    const result1 = config.get(".port");
    try testing.expect(result1 == null or result1.?.len == 0);

    const result2 = config.get("server.");
    try testing.expect(result2 == null or result2.?.len == 0);

    // 测试类型化方法的错误处理
    try testing.expectError(error.KeyNotFound, config.getU16(".port"));
    try testing.expectError(error.KeyNotFound, config.getU16("server."));
    try testing.expectError(error.KeyNotFound, config.getU16("nonexistent.port"));
}

test "path syntax backward compatibility" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 测试全局键（无点号）仍然工作
    try config.set("global_key", "global_value");
    try config.set("debug", "true");
    try config.set("port", "8080");

    const global_val = config.get("global_key");
    const debug = try config.getBoolean("debug");
    const port = try config.getNumber("port");

    try testing.expectEqualStrings("global_value", global_val orelse "");
    try testing.expect(debug);
    try testing.expectEqual(@as(i64, 8080), port);
}

pub fn main() !void {
    std.debug.print("=== 路径语法功能测试 ===\n\n", .{});

    // 运行所有测试
    try testPathSyntaxBasic();
    try testPathSyntaxSetAndGet();
    try testPathSyntaxMultiLevel();
    try testPathSyntaxEdgeCases();
    try testPathSyntaxTypeCoercion();
    try testBackwardCompatibility();

    std.debug.print("\n✅ 所有测试通过！\n", .{});
}

/// 测试基本路径语法功能
fn testPathSyntaxBasic() !void {
    std.debug.print("测试 1: 基本路径语法功能\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 使用路径语法设置值
    try config.set("server.port", "8080");
    try config.set("server.host", "localhost");
    try config.set("database.port", "5432");

    // 使用路径语法获取值
    const server_port = config.get("server.port");
    const server_host = config.get("server.host");
    const db_port = config.get("database.port");

    try testing.expectEqualStrings("8080", server_port.?);
    try testing.expectEqualStrings("localhost", server_host.?);
    try testing.expectEqualStrings("5432", db_port.?);

    std.debug.print("  ✓ 基本路径语法正常工作\n\n", .{});
}

/// 测试路径语法的设置和获取
fn testPathSyntaxSetAndGet() !void {
    std.debug.print("测试 2: 路径语法的设置和获取\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 设置类型化值
    try config.set("app.debug", "true");
    try config.set("app.port", "3000");
    try config.set("app.timeout", "30.5");

    // 使用类型化方法获取
    const debug = try config.getBoolean("app.debug");
    const port = try config.getNumber("app.port");
    const timeout = try config.getFloat("app.timeout");

    try testing.expect(debug);
    try testing.expectEqual(@as(i64, 3000), port);
    try testing.expectApproxEqAbs(@as(f64, 30.5), timeout, 0.01);

    std.debug.print("  ✓ 类型化获取方法工作正常\n\n", .{});
}

/// 测试多级路径
fn testPathSyntaxMultiLevel() !void {
    std.debug.print("测试 3: 多级路径支持\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 设置多级路径
    try config.set("server.config.timeout", "60");
    try config.set("server.config.retry", "3");

    // 获取多级路径
    const timeout = config.get("server.config.timeout");
    const retry = config.get("server.config.retry");

    try testing.expectEqualStrings("60", timeout orelse "");
    try testing.expectEqualStrings("3", retry orelse "");

    std.debug.print("  ✓ 多级路径正常工作\n\n", .{});
}

/// 测试边缘情况
fn testPathSyntaxEdgeCases() !void {
    std.debug.print("测试 4: 边缘情况处理\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 测试无效路径格式
    const result1 = config.get(".port");
    try testing.expect(result1 == null or result1.?.len == 0);

    const result2 = config.get("server.");
    try testing.expect(result2 == null or result2.?.len == 0);

    // 测试类型化方法的错误处理
    try testing.expectError(error.KeyNotFound, config.getU16(".port"));
    try testing.expectError(error.KeyNotFound, config.getU16("server."));
    try testing.expectError(error.KeyNotFound, config.getU16("nonexistent.port"));

    std.debug.print("  ✓ 边缘情况处理正确\n\n", .{});
}

/// 测试类型强制转换
fn testPathSyntaxTypeCoercion() !void {
    std.debug.print("测试 5: 类型强制转换\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 设置字符串值
    try config.set("numbers.u8_val", "255");
    try config.set("numbers.u16_val", "65535");
    try config.set("numbers.i32_val", "-2147483648");
    try config.set("numbers.f64_val", "3.14159");

    // 使用不同的类型方法获取
    const u8_val = try config.getU8("numbers.u8_val");
    const u16_val = try config.getU16("numbers.u16_val");
    const i32_val = try config.getI32("numbers.i32_val");
    const f64_val = try config.getF64("numbers.f64_val");

    try testing.expectEqual(@as(u8, 255), u8_val);
    try testing.expectEqual(@as(u16, 65535), u16_val);
    try testing.expectEqual(@as(i32, -2147483648), i32_val);
    try testing.expectApproxEqAbs(@as(f64, 3.14159), f64_val, 0.00001);

    std.debug.print("  ✓ 类型强制转换正确\n\n", .{});
}

/// 测试向后兼容性
fn testBackwardCompatibility() !void {
    std.debug.print("测试 6: 向后兼容性\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 测试全局键（无点号）仍然工作
    try config.set("global_key", "global_value");
    try config.set("debug", "true");
    try config.set("port", "8080");

    const global_val = config.get("global_key");
    const debug = config.getBoolean("debug");
    const port = config.getNumber("port");

    try testing.expectEqualStrings("global_value", global_val orelse "");
    try testing.expect(debug);
    try testing.expectEqual(@as(i64, 8080), port);

    std.debug.print("  ✓ 向后兼容性保持\n\n", .{});
}
