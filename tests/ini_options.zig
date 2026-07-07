const std = @import("std");
const Ini = @import("zini").Ini;
const IniOptions = @import("zini").IniOptions;
const testing = std.testing;

test "Ini.init默认行为 - 不加载description" {
    const allocator = testing.allocator;

    const content =
        \\ # 这是description注释
        \\ # @title 配置标题
        \\ key1 = value1
    ;

    var ini = Ini.init(allocator); // API不变，但行为优化
    defer ini.deinit();

    try ini.loadFromString(content);

    const schema = ini.getSchema("key1").?;
    try testing.expect(schema.title != null); // title 应该被加载
    try testing.expectEqualStrings("配置标题", schema.title.?);

    try testing.expect(schema.description == null); // description 不应该被加载
}

test "Ini.initWithOptions.withDescription - 加载description" {
    const allocator = testing.allocator;

    const content =
        \\ # 这是description注释
        \\ # @title 配置标题
        \\ key1 = value1
    ;

    var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini.deinit();

    try ini.loadFromString(content);

    const schema = ini.getSchema("key1").?;
    try testing.expect(schema.title != null);
    try testing.expectEqualStrings("配置标题", schema.title.?);

    try testing.expect(schema.description != null); // description 应该被加载
    try testing.expectEqualStrings("这是description注释", schema.description.?);
}

test "自动注释保留 - save时自动恢复注释" {
    const allocator = testing.allocator;

    const original_content =
        \\ # 这是description注释
        \\ # @title 配置标题
        \\ key1 = value1
    ;

    // 使用默认API（不加载description）
    var ini = Ini.init(allocator);
    defer ini.deinit();
    try ini.loadFromString(original_content);

    // 验证初始状态：title被加载，description不被加载
    const schema1 = ini.getSchema("key1").?;
    try testing.expect(schema1.title != null);
    try testing.expectEqualStrings("配置标题", schema1.title.?);
    try testing.expect(schema1.description == null);

    // 修改值（set会保留title，description保持为null）
    try ini.set("key1", "new_value");

    // 验证set后的状态：title应该被保留
    const schema2 = ini.getSchema("key1").?;
    try testing.expect(schema2.title != null); // title被保留
    try testing.expectEqualStrings("配置标题", schema2.title.?);
    try testing.expect(schema2.description == null); // description仍为null

    // 验证值已更新
    try testing.expectEqualStrings("new_value", schema2.value);
}

test "内存优化 - 对比内存占用" {
    const allocator = testing.allocator;

    const content =
        \\ # 这是description注释
        \\ # @title 配置标题
        \\ key1 = value1
        \\ key2 = value2
    ;

    // 加载description
    var ini1 = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini1.deinit();
    try ini1.loadFromString(content);

    // 不加载description（默认）
    var ini2 = Ini.init(allocator);
    defer ini2.deinit();
    try ini2.loadFromString(content);

    // 验证ini1有description
    const schema1 = ini1.getSchema("key1").?;
    try testing.expect(schema1.description != null);

    // 验证ini2没有description
    const schema2 = ini2.getSchema("key1").?;
    try testing.expect(schema2.description == null);

    // 验证title都存在
    try testing.expect(schema1.title != null);
    try testing.expect(schema2.title != null);
}

test "IniOptions.withDescription - 创建选项" {
    const options = IniOptions.withDescription();
    try testing.expect(options.has(IniOptions.LoadDescription));
}

test "IniOptions默认 - 不包含LoadDescription" {
    const options = IniOptions{};
    try testing.expect(!options.has(IniOptions.LoadDescription));
}
