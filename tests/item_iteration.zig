//! Item 遍历功能测试
//!
//! 测试 forEach 方法的正确用法 - 使用匿名 Struct 闭包捕获外部状态

const std = @import("std");
const Ini = @import("zini").Ini;
const Item = @import("zini").Item;

test "forEach 基本功能测试 - 使用闭包捕获状态" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 添加配置
    try ini.set("item1", "value1");
    try ini.set("item2", "value2");

    // 使用闭包方式：传递外部变量的指针作为上下文
    var count: usize = 0;

    ini.forEach("*", struct {
        fn callback(item: *const Item, section: ?[]const u8, ctx: *usize) void {
            _ = section;
            const key = item.key orelse return;
            const value = item.value orelse return;

            std.debug.print("  {s} = {s}\n", .{ key, value });

            // ✅ 可以修改外部变量（通过指针）
            ctx.* += 1;
        }
    }.callback, &count);

    try std.testing.expectEqual(@as(usize, 2), count);
}

test "forEach 验证配置数据 - 在闭包中断言" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("expected_key", "expected_value");
    try ini.set("database.port", "5432");

    var found_expected = false;

    // 使用闭包方式：在回调中直接进行验证
    ini.forEach("*", struct {
        fn callback(item: *const Item, section: ?[]const u8, found: *bool) void {
            _ = section;
            const key = item.key orelse return;
            const value = item.value orelse return;

            if (std.mem.eql(u8, key, "expected_key")) {
                // ✅ 在闭包中编写断言
                if (!std.mem.eql(u8, value, "expected_value")) {
                    std.debug.print("错误: 期望 'expected_value', 实际 '{s}'\n", .{value});
                } else {
                    found.* = true; // 修改外部变量
                }
            }
        }
    }.callback, &found_expected);

    try std.testing.expect(found_expected);
}

test "forEach 过滤特定 section - 闭包捕获多个状态" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("global_key", "global_value");
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");

    // 使用命名结构体来避免类型不匹配
    const CountContext = struct {
        database_count: usize = 0,
        global_count: usize = 0,
    };

    var context = CountContext{};

    // 使用闭包方式：传递上下文结构的指针
    ini.forEach("*", struct {
        fn callback(item: *const Item, section: ?[]const u8, ctx: *CountContext) void {
            const key = item.key orelse return;
            const value = item.value orelse return;

            if (section) |section_name| {
                if (std.mem.eql(u8, section_name, "database")) {
                    std.debug.print("  Database: {s} = {s}\n", .{ key, value });
                    // ✅ 修改外部结构体字段
                    ctx.database_count += 1;
                }
            } else {
                std.debug.print("  Global: {s} = {s}\n", .{ key, value });
                // ✅ 修改外部结构体字段
                ctx.global_count += 1;
            }
        }
    }.callback, &context);

    try std.testing.expectEqual(@as(usize, 2), context.database_count);
    try std.testing.expectEqual(@as(usize, 1), context.global_count);
}

test "forEach 遍历所有配置 - 闭包统计总数" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 添加全局和 section 配置
    try ini.set("global_key", "global_value");
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");

    var total_count: usize = 0;

    // 遍历所有配置并统计总数
    ini.forEach("*", struct {
        fn callback(item: *const Item, section: ?[]const u8, ctx: *usize) void {
            _ = section;
            const key = item.key orelse return;
            const value = item.value orelse return;

            std.debug.print("  Item: {s} = {s}\n", .{ key, value });
            ctx.* += 1; // ✅ 修改外部计数器
        }
    }.callback, &total_count);

    try std.testing.expectEqual(@as(usize, 3), total_count);
}

test "forEach section 参数验证 - 闭包验证参数" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("global_key", "global_value");
    try ini.set("database.host", "localhost");

    // 使用命名结构体来避免类型不匹配
    const SectionContext = struct {
        section_count: usize = 0,
        global_count: usize = 0,
    };

    var context = SectionContext{};

    // 验证 section 参数正确传递
    ini.forEach("*", struct {
        fn callback(item: *const Item, section: ?[]const u8, ctx: *SectionContext) void {
            _ = item;
            if (section) |section_name| {
                if (section_name.len > 0) {
                    // ✅ 修改外部结构体字段
                    ctx.section_count += 1;
                } else {
                    std.debug.print("错误: section 名称不应该为空\n", .{});
                }
            } else {
                // ✅ 修改外部结构体字段
                ctx.global_count += 1;
            }
        }
    }.callback, &context);

    try std.testing.expectEqual(@as(usize, 1), context.section_count);
    try std.testing.expectEqual(@as(usize, 1), context.global_count);
}
