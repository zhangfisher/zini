//! 完整功能验证测试

const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;
const DataType = @import("zini").DataType;

test "complete feature verification" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.init(allocator);
    defer config.deinit();

    // 1. 测试智能类型推断
    {
        try config.set("u8_val", "255");
        try config.set("u16_val", "65535");
        try config.set("bool_val", "true");
        try config.set("str_val", "hello");

        const u8_entry = config.getSchema("u8_val").?;
        try testing.expectEqual(DataType.u8, u8_entry.datatype);

        const u16_entry = config.getSchema("u16_val").?;
        try testing.expectEqual(DataType.u16, u16_entry.datatype);

        const bool_entry = config.getSchema("bool_val").?;
        try testing.expectEqual(DataType.bool, bool_entry.datatype);

        const str_entry = config.getSchema("str_val").?;
        try testing.expectEqual(DataType.string, str_entry.datatype);
    }

    // 2. 测试路径语法 + 类型推断
    {
        try config.set("server.port", "9000");      // 自动推断为 u16
        try config.set("server.enabled", "false");   // 自动推断为 bool
        try config.set("database.timeout:i32", "60"); // 显式标注

        const server_port = try config.getU16("server.port");
        const server_enabled = try config.getBool("server.enabled");
        const db_timeout = try config.getI32("database.timeout");

        try testing.expectEqual(@as(u16, 9000), server_port);
        try testing.expectEqual(false, server_enabled);
        try testing.expectEqual(@as(i32, 60), db_timeout);
    }

    // 3. 测试选择性写入
    {
        const content = try config.saveToString(allocator);
        defer allocator.free(content);

        // u16, bool 应该省略标注
        try testing.expect(std.mem.indexOf(u8, content, "port = 9000") != null);
        try testing.expect(std.mem.indexOf(u8, content, "enabled = false") != null);

        // u32 应该保留标注
        try testing.expect(std.mem.indexOf(u8, content, "timeout:i32 = 60") != null);

        // u8 应该保留标注
        try testing.expect(std.mem.indexOf(u8, content, "u8_val:u8 = 255") != null);
    }

    // 4. 测试显式类型标注
    {
        try config.set("explicit:u8", "100");
        const explicit_entry = config.getSchema("explicit").?;
        try testing.expectEqual(DataType.u8, explicit_entry.datatype);
    }

    std.debug.print("✅ 所有功能验证通过\n", .{});
}
