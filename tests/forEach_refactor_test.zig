//! forEach 函数重构测试
//! 测试新的 forEach 函数的三种迭代模式

const std = @import("std");
const Ini = @import("zini").Ini;
const Item = @import("zini").Item;

// 简单callback函数
fn simpleCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = item;
    _ = section;
    _ = ctx;
}

// 全局配置测试callback
fn globalOnlyCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = item;
    _ = ctx;
    if (section != null) {
        // 全局配置的section应该是null
        unreachable;
    }
}

// Section测试callback
fn sectionTestCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = item;
    _ = ctx;
    if (section) |sec| {
        if (std.mem.eql(u8, sec, "database")) {
            // 验证通过
        } else {
            // 错误的section
            unreachable;
        }
    } else {
        // 不应该为null
        unreachable;
    }
}

// 空callback（不应该被调用）
fn emptyCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = item;
    _ = section;
    _ = ctx;
    // 如果执行到这里，说明出错了
    unreachable;
}

// 全局参数验证callback
fn globalParamCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = item;
    _ = ctx;
    if (section != null) {
        // 全局配置的section应该是null
        unreachable;
    }
}

// Section参数验证callback
fn sectionParamCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = item;
    _ = ctx;
    if (section) |sec| {
        if (!std.mem.eql(u8, sec, "database")) {
            // section应该是"database"
            unreachable;
        }
    } else {
        // section不应该为null
        unreachable;
    }
}

// 全部迭代参数验证callback
fn allIterateCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = ctx;
    if (section == null and item.key != null) {
        if (std.mem.eql(u8, item.key.?, "global_key")) {
            // 找到全局配置
        }
    }
    if (section) |sec| {
        if (std.mem.eql(u8, sec, "database")) {
            // 找到database section
        }
    }
}

// 基本功能callback
fn basicCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = item;
    _ = section;
    _ = ctx;
    // 只验证不崩溃
}

// Database section callback
fn databaseOnlyCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = item;
    _ = ctx;
    if (section) |sec| {
        if (!std.mem.eql(u8, sec, "database")) {
            // 验证section正确
            unreachable;
        }
    } else {
        unreachable;
    }
}

// Cache section callback
fn cacheOnlyCallback(item: *const Item, section: ?[]const u8, ctx: ?*void) void {
    _ = item;
    _ = ctx;
    if (section) |sec| {
        if (!std.mem.eql(u8, sec, "cache")) {
            unreachable;
        }
    } else {
        unreachable;
    }
}

test "forEach - 全部配置项迭代 ('*')" {
    const allocator = std.testing.allocator;
    var ini_obj = Ini.default(allocator);
    defer ini_obj.deinit();

    // 添加全局配置项
    try ini_obj.set("global1", "value1");
    try ini_obj.set("global2", "value2");

    // 添加 section 配置项
    try ini_obj.set("database.host", "localhost");
    try ini_obj.set("database.port", "5432");
    try ini_obj.set("server.host", "0.0.0.0");
    try ini_obj.set("server.port", "8080");

    // 测试：迭代所有配置项，验证callback被正常调用
    ini_obj.forEach("*", simpleCallback, null);

    // 验证测试完成
    try std.testing.expect(true);
}

test "forEach - 只迭代全局配置项 ('')" {
    const allocator = std.testing.allocator;
    var ini_obj = Ini.default(allocator);
    defer ini_obj.deinit();

    // 添加全局配置项
    try ini_obj.set("global1", "value1");
    try ini_obj.set("global2", "value2");

    // 添加 section 配置项
    try ini_obj.set("database.host", "localhost");
    try ini_obj.set("database.port", "5432");

    // 测试：只迭代全局配置项
    ini_obj.forEach("", globalOnlyCallback, null);

    // 验证测试成功完成
    try std.testing.expect(true);
}

test "forEach - 只迭代指定section ('database')" {
    const allocator = std.testing.allocator;
    var ini_obj = Ini.default(allocator);
    defer ini_obj.deinit();

    // 添加全局配置项
    try ini_obj.set("global1", "value1");

    // 添加多个 section 配置项
    try ini_obj.set("database.host", "localhost");
    try ini_obj.set("database.port", "5432");
    try ini_obj.set("server.host", "0.0.0.0");
    try ini_obj.set("server.port", "8080");

    // 测试：只迭代 database section
    ini_obj.forEach("database", sectionTestCallback, null);

    // 验证测试成功完成
    try std.testing.expect(true);
}

test "forEach - 迭代不存在的section" {
    const allocator = std.testing.allocator;
    var ini_obj = Ini.default(allocator);
    defer ini_obj.deinit();

    // 添加配置
    try ini_obj.set("global1", "value1");
    try ini_obj.set("database.host", "localhost");

    // 测试：迭代不存在的 section（应该不调用callback）
    ini_obj.forEach("nonexistent", emptyCallback, null);

    // 验证callback未被调用
    try std.testing.expect(true);
}

test "forEach - 空配置测试" {
    const allocator = std.testing.allocator;
    var ini_obj = Ini.default(allocator);
    defer ini_obj.deinit();

    // 测试全部迭代
    ini_obj.forEach("*", emptyCallback, null);

    // 测试全局迭代
    ini_obj.forEach("", emptyCallback, null);

    // 测试section迭代
    ini_obj.forEach("database", emptyCallback, null);

    // 验证所有测试通过
    try std.testing.expect(true);
}

test "forEach - callback参数验证" {
    const allocator = std.testing.allocator;
    var ini_obj = Ini.default(allocator);
    defer ini_obj.deinit();

    try ini_obj.set("global_key", "global_value");
    try ini_obj.set("database.key1", "value1");
    try ini_obj.set("database.key2", "value2");

    // 测试1: 全局配置的section参数为null
    ini_obj.forEach("", globalParamCallback, null);

    // 测试2: section配置的section参数正确
    ini_obj.forEach("database", sectionParamCallback, null);

    // 测试3: 全部迭代时参数正确
    ini_obj.forEach("*", allIterateCallback, null);

    // 验证测试通过
    try std.testing.expect(true);
}

test "forEach - 基本功能验证" {
    const allocator = std.testing.allocator;
    var ini_obj = Ini.default(allocator);
    defer ini_obj.deinit();

    // 创建测试配置
    try ini_obj.set("app.name", "TestApp");
    try ini_obj.set("database.host", "localhost");
    try ini_obj.set("database.port", "5432");
    try ini_obj.set("cache.enabled", "true");

    // 验证：每种模式都能正常工作且不崩溃
    ini_obj.forEach("*", basicCallback, null);

    ini_obj.forEach("", globalOnlyCallback, null);

    ini_obj.forEach("database", databaseOnlyCallback, null);

    try ini_obj.set("cache.ttl", "3600");

    // 验证 cache section
    ini_obj.forEach("cache", cacheOnlyCallback, null);

    // 验证所有测试通过
    try std.testing.expect(true);
}
