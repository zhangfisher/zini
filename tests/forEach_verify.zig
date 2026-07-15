//! forEach 参数顺序修改验证测试
//! 验证新的 API 签名：forEach(section, callback, context)

const std = @import("std");
const Ini = @import("zini").Ini;
const Item = @import("zini").Item;

test "forEach 新参数顺序验证" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 添加配置
    try ini.set("item1", "value1");
    try ini.set("item2", "value2");

    // 使用新的 API：forEach(section, callback, context)
    var count: usize = 0;
    ini.forEach("*", struct {
        fn callback(item: *const Item, section: ?[]const u8, ctx: *usize) void {
            _ = section;
            const key = item.key orelse return;
            const value = item.value orelse return;
            std.debug.print("  {s} = {s}\n", .{ key, value });
            ctx.* += 1;
        }
    }.callback, &count);

    try std.testing.expectEqual(@as(usize, 2), count);
    std.debug.print("✅ forEach 新参数顺序测试通过！\n", .{});
}

test "forEach 无context情况验证" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("test_key", "test_value");

    // 使用指针作为 context
    var call_count: usize = 0;
    ini.forEach("*", struct {
        fn callback(item: *const Item, section: ?[]const u8, ctx: *usize) void {
            _ = section;
            _ = item;
            ctx.* += 1;
        }
    }.callback, &call_count);

    try std.testing.expectEqual(@as(usize, 1), call_count);
    std.debug.print("✅ forEach context测试通过！\n", .{});
}
