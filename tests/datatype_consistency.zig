const std = @import("std");
const testing = std.testing;
const Ini = @import("zini").Ini;
const Item = @import("zini").Item;
const DataType = @import("zini").DataType;

// 测试 datatype 一致性：已存在的 Item 应该保持其原有类型
test "datatype consistency on update" {
    const allocator = std.testing.allocator;

    // 创建一个 Ini 实例并手动添加一个整数类型的配置项
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 手动创建一个明确类型的 Item（整数）
    var item = try Item.init(allocator, "port", "8080");
    defer item.deinit(allocator);

    // 强制设置为整数类型
    item.datatype = .number;

    // 添加到 Ini 中
    try ini.addItem("port", item);

    // 验证初始类型
    const initial_datatype = ini.items.get("port").?.datatype;
    try testing.expect(initial_datatype == .number); // 应该是整数类型

    // 现在用 set 方法更新值（传入一个看起来像数字的字符串）
    try ini.set("port", "9000");

    // 验证 datatype 仍然保持为 number 类型
    const updated_datatype = ini.items.get("port").?.datatype;
    try testing.expect(updated_datatype == .number); // 应该仍然是整数类型！

    // 验证值确实更新了
    const updated_value = ini.items.get("port").?.value;
    try testing.expectEqualStrings("9000", updated_value);

    std.debug.print("  ✓ datatype 一致性测试通过：更新后类型保持不变\n", .{});
}

test "datatype inference on new item creation" {
    const allocator = std.testing.allocator;

    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 创建新的配置项（不存在的键）
    try ini.set("count", "123");

    // 验证新创建的 Item 正确推断类型
    const new_item = ini.items.get("count").?;
    try testing.expect(new_item.datatype == .number); // 应该推断为整数类型

    std.debug.print("  ✓ 新 Item 类型推断测试通过\n", .{});
}

test "update preserves title and description" {
    const allocator = std.testing.allocator;

    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 创建带有 title 和 description 的 Item
    var item = try Item.init(allocator, "debug", "false");
    defer item.deinit(allocator);

    item.title = try allocator.dupe(u8, "Debug Mode");
    defer allocator.free(item.title.?);
    item.description = try allocator.dupe(u8, "Enable debug logging");
    defer allocator.free(item.description.?);

    try ini.addItem("debug", item);

    // 验证初始 metadata
    const initial_item = ini.items.get("debug").?;
    try testing.expect(initial_item.title != null);
    try testing.expect(initial_item.description != null);

    // 更新值
    try ini.set("debug", "true");

    // 验证 title 和 description 被保留
    const updated_item = ini.items.get("debug").?;
    try testing.expect(updated_item.title != null);
    try testing.expect(updated_item.description != null);
    try testing.expectEqualStrings("Debug Mode", updated_item.title.?);
    try testing.expectEqualStrings("Enable debug logging", updated_item.description.?);
    try testing.expectEqualStrings("true", updated_item.value);

    std.debug.print("  ✓ metadata 保留测试通过\n", .{});
}
