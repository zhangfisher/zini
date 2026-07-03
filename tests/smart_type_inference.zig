//! 智能类型推断和选择性写入测试

const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;
const DataType = @import("zini").DataType;

test "smart type inference - unsigned integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.init(allocator);
    defer config.deinit();

    // 测试不同范围的无符号整数
    try config.set("u8_val", "255");           // u8 范围
    try config.set("u16_val", "65535");       // u16 范围
    try config.set("u32_val", "4294967295");  // u32 范围
    try config.set("u64_val", "18446744073709551615"); // u64 范围

    // 验证类型推断
    const u8_entry = config.getSchema("u8_val").?;
    try testing.expectEqual(DataType.u8, u8_entry.datatype);

    const u16_entry = config.getSchema("u16_val").?;
    try testing.expectEqual(DataType.u16, u16_entry.datatype);

    const u32_entry = config.getSchema("u32_val").?;
    try testing.expectEqual(DataType.u32, u32_entry.datatype);

    const u64_entry = config.getSchema("u64_val").?;
    try testing.expectEqual(DataType.u64, u64_entry.datatype);

    std.debug.print("✅ 无符号整数类型推断正确\n", .{});
}

test "smart type inference - signed integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.init(allocator);
    defer config.deinit();

    // 测试有符号整数（负数）
    try config.set("i8_val", "-128");
    try config.set("i16_val", "-32768");
    try config.set("i32_val", "-2147483648");
    try config.set("positive_i8", "127");

    // 验证类型推断
    const i8_entry = config.getSchema("i8_val").?;
    try testing.expectEqual(DataType.i8, i8_entry.datatype);

    const i16_entry = config.getSchema("i16_val").?;
    try testing.expectEqual(DataType.i16, i16_entry.datatype);

    const i32_entry = config.getSchema("i32_val").?;
    try testing.expectEqual(DataType.i32, i32_entry.datatype);

    const pos_i8_entry = config.getSchema("positive_i8").?;
    try testing.expectEqual(DataType.i8, pos_i8_entry.datatype);

    std.debug.print("✅ 有符号整数类型推断正确\n", .{});
}

test "smart type inference - bool and float" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.init(allocator);
    defer config.deinit();

    try config.set("bool_val", "true");
    try config.set("float_val", "3.14");

    const bool_entry = config.getSchema("bool_val").?;
    try testing.expectEqual(DataType.bool, bool_entry.datatype);

    const float_entry = config.getSchema("float_val").?;
    try testing.expectEqual(DataType.float, float_entry.datatype);

    std.debug.print("✅ 布尔和浮点类型推断正确\n", .{});
}

test "selective type annotation in writing" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.init(allocator);
    defer config.deinit();

    // u16, bool, string 应该省略类型标注
    try config.set("port", "8080");           // u16，省略
    try config.set("enabled", "true");        // bool，省略
    try config.set("name", "MyApp");         // string，省略

    // 其他类型应该保留类型标注
    try config.set("max_conn:u8", "100");   // u8，保留
    try config.set("timeout:i32", "30");    // i32，保留

    const content = try config.saveToString(allocator);
    defer allocator.free(content);

    // 验证写入内容
    // u16, bool, string 不应该有类型标注
    try testing.expect(std.mem.indexOf(u8, content, "port = 8080") != null);
    try testing.expect(std.mem.indexOf(u8, content, "enabled = true") != null);
    try testing.expect(std.mem.indexOf(u8, content, "name = MyApp") != null);

    // u8, i32 应该有类型标注
    try testing.expect(std.mem.indexOf(u8, content, "max_conn:u8 = 100") != null);
    try testing.expect(std.mem.indexOf(u8, content, "timeout:i32 = 30") != null);

    std.debug.print("生成的配置：\n{s}\n", .{content});
    std.debug.print("✅ 选择性类型写入正确\n", .{});
}

test "mixed auto-inference and explicit annotation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.init(allocator);
    defer config.deinit();

    // 自动推断
    try config.set("auto_u8", "255");
    try config.set("auto_i16", "-1000");
    try config.set("auto_bool", "false");

    // 显式类型标注（覆盖自动推断）
    try config.set("explicit_u32:u32", "12345");

    const content = try config.saveToString(allocator);
    defer allocator.free(content);

    std.debug.print("混合推断和标注：\n{s}\n", .{content});

    // 验证
    try testing.expect(std.mem.indexOf(u8, content, "auto_u8:u8 = 255") != null); // u8 需要标注
    try testing.expect(std.mem.indexOf(u8, content, "auto_i16:i16 = -1000") != null); // i16 需要标注
    try testing.expect(std.mem.indexOf(u8, content, "auto_bool = false") != null); // bool 省略
    try testing.expect(std.mem.indexOf(u8, content, "explicit_u32:u32 = 12345") != null); // 显式标注保留

    std.debug.print("✅ 混合模式工作正常\n", .{});
}
