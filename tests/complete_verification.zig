//! 完整功能验证测试

const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;
const DataType = @import("zini").DataType;

test "complete feature verification" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var config = Ini.default(allocator);
    defer config.deinit();

    // 1. 测试智能类型推断
    {
        try config.set("number_val1", "255");
        try config.set("number_val2", "65535");
        try config.set("bool_val", "true");
        try config.set("str_val", "hello");

        const num1_entry = config.getItem("number_val1").?;
        try testing.expectEqual(DataType.number, num1_entry.datatype);

        const num2_entry = config.getItem("number_val2").?;
        try testing.expectEqual(DataType.number, num2_entry.datatype);

        const bool_entry = config.getItem("bool_val").?;
        try testing.expectEqual(DataType.boolean, bool_entry.datatype);

        const str_entry = config.getItem("str_val").?;
        try testing.expectEqual(DataType.string, str_entry.datatype);
    }

    // 2. 测试路径语法 + 类型推断
    {
        try config.set("server.port", "9000"); // 自动推断为 number
        try config.set("server.enabled", "false"); // 自动推断为 boolean
        try config.set("database.timeout:number", "60"); // 显式标注

        const server_port = config.getNumber("server.port");
        const server_enabled = config.getBoolean("server.enabled");
        const db_timeout = config.getNumber("database.timeout");

        try testing.expectEqual(@as(i64, 9000), server_port);
        try testing.expectEqual(false, server_enabled);
        try testing.expectEqual(@as(i64, 60), db_timeout);
    }

    // 3. 测试选择性写入
    {
        const content = try config.saveToString(allocator);
        defer allocator.free(content);

        // number, boolean 应该省略标注
        try testing.expect(std.mem.indexOf(u8, content, "port = 9000") != null);
        try testing.expect(std.mem.indexOf(u8, content, "enabled = false") != null);

        // 显式标注应该保留
        try testing.expect(std.mem.indexOf(u8, content, "timeout:number = 60") != null);

        // number 应该保留显式标注
        try testing.expect(std.mem.indexOf(u8, content, "number_val1:number = 255") != null);
    }

    // 4. 测试显式类型标注
    {
        try config.set("explicit:number", "100");
        const explicit_entry = config.getItem("explicit").?;
        try testing.expectEqual(DataType.number, explicit_entry.datatype);
    }

    std.debug.print("✅ 所有功能验证通过\n", .{});
}
