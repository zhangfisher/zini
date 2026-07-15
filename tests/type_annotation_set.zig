//! 类型标注功能测试

const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;
const DataType = @import("zini").DataType;

test "set with type annotation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 使用类型标注设置值
    try config.set("count:number", "123");
    try config.set("port:number", "8080");
    try config.set("timeout:number", "30");
    try config.set("rate:float", "3.14");
    try config.set("name", "test"); // 无类型标注，自动推断为 string

    // 保存到字符串
    const content = try config.saveToString(allocator);
    defer allocator.free(content);

    // 验证保存的内容包含类型标注
    try testing.expect(std.mem.indexOf(u8, content, "count:number = 123") != null);
    try testing.expect(std.mem.indexOf(u8, content, "port:number = 8080") != null);
    try testing.expect(std.mem.indexOf(u8, content, "timeout:number = 30") != null);
    try testing.expect(std.mem.indexOf(u8, content, "rate:float = 3.14") != null);
    try testing.expect(std.mem.indexOf(u8, content, "name = test") != null);

    // 重新加载并验证类型
    var config2 = Ini.default(allocator);
    defer config2.deinit();

    try config2.loadFromString(content);

    // 验证值的类型
    const count_entry = config2.getItem("count").?;
    try testing.expectEqual(DataType.number, count_entry.datatype);

    const port_entry = config2.getItem("port").?;
    try testing.expectEqual(DataType.number, port_entry.datatype);

    const timeout_entry = config2.getItem("timeout").?;
    try testing.expectEqual(DataType.number, timeout_entry.datatype);

    const rate_entry = config2.getItem("rate").?;
    try testing.expectEqual(DataType.float, rate_entry.datatype);

    const name_entry = config2.getItem("name").?;
    try testing.expectEqual(DataType.string, name_entry.datatype);
}

test "set with path syntax and type annotation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 路径语法 + 类型标注
    try config.set("server.port:number", "9000");
    try config.set("database.timeout:number", "60");

    const content = try config.saveToString(allocator);
    defer allocator.free(content);

    // 验证保存的内容
    try testing.expect(std.mem.indexOf(u8, content, "port:number = 9000") != null);
    try testing.expect(std.mem.indexOf(u8, content, "timeout:number = 60") != null);
}

test "set without type annotation - auto inference" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
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
