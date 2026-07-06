//! INI 遍历功能测试
//!
//! 测试 forEach 方法

const std = @import("std");
const Ini = @import("zini").Ini;
const Schema = @import("zini").Schema;

test "遍历所有配置" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 添加全局配置
    try ini.set("app_name", "zig-ini");
    try ini.set("version", "1.0.0");
    try ini.set("debug", "true");

    // 添加 section 配置
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");
    try ini.set("server.host", "0.0.0.0");
    try ini.set("server.port", "8080");

    var count: usize = 0;

    // 遍历所有配置
    ini.forEach(&count, struct {
        fn callback(ctx: *usize, section: ?[]const u8, schema: *const Schema) void {
            _ = section;
            _ = schema;
            const mctx = @constCast(ctx);
            mctx.* += 1;
        }
    }.callback);

    // 验证统计结果
    // 3个全局配置 + 4个section配置 = 7个总配置
    try std.testing.expectEqual(@as(usize, 7), count);
}

test "Schema 字段验证" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global_key", "global_value");
    try ini.set("section.key", "section_value");

    var found_count: usize = 0;

    ini.forEach(&found_count, struct {
        fn callback(ctx: *usize, section: ?[]const u8, schema: *const Schema) void {
            const mctx = @constCast(ctx);
            if (section) |section_name| {
                // 验证 section 配置
                if (std.mem.eql(u8, section_name, "section")) {
                    if (std.mem.eql(u8, schema.key, "key") and
                        std.mem.eql(u8, schema.value, "section_value")) {
                        mctx.* += 1;
                    }
                }
            } else {
                // 验证全局配置
                if (std.mem.eql(u8, schema.key, "global_key") and
                    std.mem.eql(u8, schema.value, "global_value")) {
                    mctx.* += 1;
                }
            }
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 2), found_count);
}

test "类型转换测试" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("bool_true", "true");
    try ini.set("int_value", "42");
    try ini.set("float_value", "3.14");
    try ini.set("string_value", "hello");

    var test_count: usize = 0;
    var test_passed: usize = 0;

    ini.forEach(&.{&test_count, &test_passed}, struct {
        fn callback(ctx: *const struct { *usize, *usize }, section: ?[]const u8, schema: *const Schema) void {
            _ = section;
            const mctx = @constCast(ctx);
            mctx.*[0].* += 1;

            // 通过 schema 访问类型转换方法
            if (std.mem.eql(u8, schema.key, "bool_true")) {
                if (schema.asBool()) |value| {
                    if (value == true) mctx.*[1].* += 1;
                } else |_| {}
            } else if (std.mem.eql(u8, schema.key, "int_value")) {
                if (schema.asInt()) |value| {
                    if (value == 42) mctx.*[1].* += 1;
                } else |_| {}
            } else if (std.mem.eql(u8, schema.key, "float_value")) {
                if (schema.asFloat()) |value| {
                    if (@abs(value - 3.14) < 0.001) mctx.*[1].* += 1;
                } else |_| {}
            } else if (std.mem.eql(u8, schema.key, "string_value")) {
                const value = schema.asString();
                if (std.mem.eql(u8, value, "hello")) mctx.*[1].* += 1;
            }
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 4), test_count);
    try std.testing.expectEqual(@as(usize, 4), test_passed);
}

test "空配置测试" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    var count: usize = 0;
    ini.forEach(&count, struct {
        fn callback(ctx: *usize, section: ?[]const u8, schema: *const Schema) void {
            _ = section;
            _ = schema;
            const mctx = @constCast(ctx);
            mctx.* += 1;
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 0), count);
}

test "仅有全局配置的测试" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("key1", "value1");
    try ini.set("key2", "value2");

    var count: usize = 0;
    var all_global: bool = true;

    ini.forEach(&.{&count, &all_global}, struct {
        fn callback(ctx: *const struct { *usize, *bool }, section: ?[]const u8, schema: *const Schema) void {
            _ = schema;
            const mctx = @constCast(ctx);
            mctx.*[0].* += 1;
            // 验证都是全局配置
            if (section != null) mctx.*[1].* = false;
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expect(all_global);
}

test "仅有 sections 的测试" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("section1.key1", "value1");
    try ini.set("section2.key2", "value2");

    var count: usize = 0;
    var global_count: usize = 0;

    ini.forEach(&.{&count, &global_count}, struct {
        fn callback(ctx: *const struct { *usize, *usize }, section: ?[]const u8, schema: *const Schema) void {
            _ = schema;
            const mctx = @constCast(ctx);
            mctx.*[0].* += 1;
            // 如果是全局配置，增加全局计数
            if (section == null) mctx.*[1].* += 1;
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqual(@as(usize, 0), global_count);
}

test "过滤特定 section 配置" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global_key", "global_value");
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");
    try ini.set("server.host", "0.0.0.0");
    try ini.set("server.port", "8080");

    var database_count: usize = 0;

    ini.forEach(&database_count, struct {
        fn callback(ctx: *usize, section: ?[]const u8, schema: *const Schema) void {
            _ = schema;
            const mctx = @constCast(ctx);
            // 只统计 database section 的配置
            if (section) |section_name| {
                if (std.mem.eql(u8, section_name, "database")) {
                    mctx.* += 1;
                }
            }
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 2), database_count);
}

test "收集所有整数值" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("timeout", "30");
    try ini.set("retries", "3");
    try ini.set("cache.size", "100");
    try ini.set("cache.ttl", "3600");

    var int_count: usize = 0;

    ini.forEach(&int_count, struct {
        fn callback(count: *usize, section: ?[]const u8, schema: *const Schema) void {
            _ = section;
            if (schema.asInt()) |_| {
                const mcount = @constCast(count);
                mcount.* += 1;
            } else |_| {}
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 4), int_count);
}

test "验证配置完整性" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("valid_key", "valid_value");
    try ini.set("empty_key", "");
    try ini.set("section.good", "value");
    try ini.set("section.empty", "");

    var error_count: usize = 0;

    ini.forEach(&error_count, struct {
        fn callback(ctx: *usize, section: ?[]const u8, schema: *const Schema) void {
            _ = section;
            const mctx = @constCast(ctx);
            // 检查字符串类型的空值
            if (schema.datatype == .string and schema.value.len == 0) {
                mctx.* += 1;
            }
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 2), error_count);
}

test "大型配置文件性能测试" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 创建大量配置项
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "key_{d}", .{i});
        defer allocator.free(key);
        const value = try std.fmt.allocPrint(allocator, "value_{d}", .{i});
        defer allocator.free(value);
        try ini.set(key, value);
    }

    var j: usize = 0;
    while (j < 10) : (j += 1) {
        const section = try std.fmt.allocPrint(allocator, "section_{d}", .{j});
        defer allocator.free(section);
        var k: usize = 0;
        while (k < 10) : (k += 1) {
            const key = try std.fmt.allocPrint(allocator, "key_{d}", .{k});
            defer allocator.free(key);
            const value = try std.fmt.allocPrint(allocator, "value_{d}", .{k});
            defer allocator.free(value);

            // 构建完整的section.key格式
            const full_key = try std.fmt.allocPrint(allocator, "{s}.{s}", .{section, key});
            defer allocator.free(full_key);
            try ini.set(full_key, value);
        }
    }

    var count: usize = 0;

    ini.forEach(&count, struct {
        fn callback(ctx: *usize, section: ?[]const u8, schema: *const Schema) void {
            _ = section;
            _ = schema;
            const mctx = @constCast(ctx);
            mctx.* += 1;
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 200), count); // 100 + 10*10
}

test "访问 section 和 schema 信息" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global.timeout", "30");
    try ini.set("database.host", "localhost");
    try ini.set("database.port", "5432");

    var results = std.ArrayList([]const u8).empty;
    defer {
        for (results.items) |item| {
            allocator.free(item);
        }
        results.deinit(allocator);
    }

    ini.forEach(&results, struct {
        fn callback(list: *std.ArrayList([]const u8), section: ?[]const u8, schema: *const Schema) void {
            const mlist = @constCast(list);
            if (section) |section_name| {
                // 构建显示字符串
                const display = std.fmt.allocPrint(allocator, "[{s}] {s} = {s}", .{
                    section_name, schema.key, schema.value
                }) catch return;
                mlist.append(allocator, display) catch {};
            } else {
                // 全局配置
                const display = std.fmt.allocPrint(allocator, "{s} = {s}", .{
                    schema.key, schema.value
                }) catch return;
                mlist.append(allocator, display) catch {};
            }
        }
    }.callback);

    try std.testing.expectEqual(@as(usize, 3), results.items.len);
}
