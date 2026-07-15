//! 智能类型推断和选择性写入测试

const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;
const DataType = @import("zini").DataType;

test "smart type inference - integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 测试不同范围的整数
    try config.set("small_val", "255");
    try config.set("medium_val", "65535");
    try config.set("large_val", "4294967295");
    try config.set("huge_val", "18446744073709551615");

    // 验证类型推断 - 都应该是 number (i64)
    const small_entry = config.getItem("small_val").?;
    try testing.expectEqual(DataType.number, small_entry.datatype);

    const medium_entry = config.getItem("medium_val").?;
    try testing.expectEqual(DataType.number, medium_entry.datatype);

    const large_entry = config.getItem("large_val").?;
    try testing.expectEqual(DataType.number, large_entry.datatype);

    const huge_entry = config.getItem("huge_val").?;
    try testing.expectEqual(DataType.number, huge_entry.datatype);

    std.debug.print("✅ 整数类型推断正确\n", .{});
}

test "smart type inference - signed integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 测试有符号整数（负数）
    try config.set("negative_val", "-128");
    try config.set("medium_negative", "-32768");
    try config.set("large_negative", "-2147483648");
    try config.set("positive_small", "127");

    // 验证类型推断 - 都应该是 number (i64)
    const neg_entry = config.getItem("negative_val").?;
    try testing.expectEqual(DataType.number, neg_entry.datatype);

    const med_neg_entry = config.getItem("medium_negative").?;
    try testing.expectEqual(DataType.number, med_neg_entry.datatype);

    const large_neg_entry = config.getItem("large_negative").?;
    try testing.expectEqual(DataType.number, large_neg_entry.datatype);

    const pos_small_entry = config.getItem("positive_small").?;
    try testing.expectEqual(DataType.number, pos_small_entry.datatype);

    std.debug.print("✅ 有符号整数类型推断正确\n", .{});
}

test "smart type inference - boolean and float" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    try config.set("bool_val", "true");
    try config.set("float_val", "3.14");

    const bool_entry = config.getItem("bool_val").?;
    try testing.expectEqual(DataType.boolean, bool_entry.datatype);

    const float_entry = config.getItem("float_val").?;
    try testing.expectEqual(DataType.float, float_entry.datatype);

    std.debug.print("✅ 布尔和浮点类型推断正确\n", .{});
}

test "selective type annotation in writing" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // number, boolean, string 应该省略类型标注
    try config.set("port", "8080"); // number，省略
    try config.set("enabled", "true"); // boolean，省略
    try config.set("name", "MyApp"); // string，省略

    // 其他类型应该保留类型标注
    try config.set("max_conn:number", "100"); // number，保留
    try config.set("timeout:number", "30"); // number，保留

    const content = try config.saveToString(allocator);
    defer allocator.free(content);

    // 验证写入内容
    // number, boolean, string 不应该有类型标注
    try testing.expect(std.mem.indexOf(u8, content, "port = 8080") != null);
    try testing.expect(std.mem.indexOf(u8, content, "enabled = true") != null);
    try testing.expect(std.mem.indexOf(u8, content, "name = MyApp") != null);

    // 带显式类型标注的应该保留
    try testing.expect(std.mem.indexOf(u8, content, "max_conn:number = 100") != null);
    try testing.expect(std.mem.indexOf(u8, content, "timeout:number = 30") != null);

    std.debug.print("生成的配置：\n{s}\n", .{content});
    std.debug.print("✅ 选择性类型写入正确\n", .{});
}

test "mixed auto-inference and explicit annotation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 自动推断
    try config.set("auto_number", "255");
    try config.set("auto_negative", "-1000");
    try config.set("auto_bool", "false");

    // 显式类型标注（覆盖自动推断）
    try config.set("explicit_number:number", "12345");

    const content = try config.saveToString(allocator);
    defer allocator.free(content);

    std.debug.print("混合推断和标注：\n{s}\n", .{content});

    // 验证 - 自动推断的类型会省略标注，只有显式标注的类型才保留
    try testing.expect(std.mem.indexOf(u8, content, "auto_number = 255") != null); // 自动推断，省略标注
    try testing.expect(std.mem.indexOf(u8, content, "auto_negative = -1000") != null); // 自动推断，省略标注
    try testing.expect(std.mem.indexOf(u8, content, "auto_bool = false") != null); // boolean 省略
    try testing.expect(std.mem.indexOf(u8, content, "explicit_number:number = 12345") != null); // 显式标注保留

    std.debug.print("✅ 混合模式工作正常\n", .{});
}
