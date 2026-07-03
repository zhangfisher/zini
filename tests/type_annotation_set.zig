//! 类型标注功能测试

const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;
const DataType = @import("zini").DataType;

test "set with type annotation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.init(allocator);
    defer config.deinit();

    // 使用类型标注设置值
    try config.set("count:u8", "123");
    try config.set("port:u16", "8080");
    try config.set("timeout:i32", "30");
    try config.set("rate:f64", "3.14");
    try config.set("name", "test"); // 无类型标注，自动推断为 string

    // 保存到字符串
    const content = try config.saveToString(allocator);
    defer allocator.free(content);

    // 验证保存的内容包含类型标注
    try testing.expect(std.mem.indexOf(u8, content, "count:u8 = 123") != null);
    try testing.expect(std.mem.indexOf(u8, content, "port:u16 = 8080") != null);
    try testing.expect(std.mem.indexOf(u8, content, "timeout:i32 = 30") != null);
    try testing.expect(std.mem.indexOf(u8, content, "rate:f64 = 3.14") != null);
    try testing.expect(std.mem.indexOf(u8, content, "name = test") != null);

    // 重新加载并验证类型
    var config2 = Ini.init(allocator);
    defer config2.deinit();

    try config2.loadFromString(content);

    // 验证值的类型
    const count_entry = config2.getSchema("count").?;
    try testing.expectEqual(DataType.u8, count_entry.datatype);

    const port_entry = config2.getSchema("port").?;
    try testing.expectEqual(DataType.u16, port_entry.datatype);

    const timeout_entry = config2.getSchema("timeout").?;
    try testing.expectEqual(DataType.i32, timeout_entry.datatype);

    const rate_entry = config2.getSchema("rate").?;
    try testing.expectEqual(DataType.f64, rate_entry.datatype);

    const name_entry = config2.getSchema("name").?;
    try testing.expectEqual(DataType.string, name_entry.datatype);
}

test "set with path syntax and type annotation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.init(allocator);
    defer config.deinit();

    // 路径语法 + 类型标注
    try config.set("server.port:u16", "9000");
    try config.set("database.timeout:i32", "60");

    const content = try config.saveToString(allocator);
    defer allocator.free(content);

    // 验证保存的内容
    try testing.expect(std.mem.indexOf(u8, content, "port:u16 = 9000") != null);
    try testing.expect(std.mem.indexOf(u8, content, "timeout:i32 = 60") != null);
}

test "set without type annotation - auto inference" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.init(allocator);
    defer config.deinit();

    // 不带类型标注，自动推断
    try config.set("enabled", "true");
    try config.set("debug", "false");
    try config.set("port", "8080");
    try config.set("rate", "0.15");

    const content = try config.saveToString(allocator);
    defer allocator.free(content);

    // 布尔值不写入类型标注
    try testing.expect(std.mem.indexOf(u8, content, "enabled = true") != null);
    try testing.expect(std.mem.indexOf(u8, content, "debug = false") != null);

    // 数字类型应该写入类型标注（因为自动推断出了类型）
    // 但根据当前实现，我们只对显式标注的类型写入
    try testing.expect(std.mem.indexOf(u8, content, "port = 8080") != null);
    try testing.expect(std.mem.indexOf(u8, content, "rate = 0.15") != null);
}
