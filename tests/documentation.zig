//! 文档注释功能测试
//! 测试 @title 和普通注释的解析与保存

const std = @import("std");
const Ini = @import("zini").Ini;
const IniOptions = @import("zini").IniOptions;

test "解析 @title 注解" {
    const allocator = std.testing.allocator;
    var config = Ini.default(allocator);
    defer config.deinit();

    const content =
        \\# @title Database Host
        \\db_host = localhost
    ;

    try config.loadFromString(content);

    const schema = config.getItem("db_host");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expect(e.title != null);
    try std.testing.expectEqualStrings("Database Host", e.title.?);
    try std.testing.expect(e.description == null);
    try std.testing.expect(e.description == null);
}

test "解析普通注释到 description 字段" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# This is a regular comment
        \\# Second line of comment
        \\key = value
    ;

    try config.loadFromString(content);

    const schema = config.getItem("key");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expect(e.description != null);
    try std.testing.expectEqualStrings("This is a regular comment\nSecond line of comment", e.description.?);
    try std.testing.expect(e.title == null);
}

test "解析混合注解（@title 和普通注释）" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# Regular documentation comment
        \\# @title Database Configuration
        \\# Another comment
        \\db_host = localhost
    ;

    try config.loadFromString(content);

    const schema = config.getItem("db_host");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("Database Configuration", e.title.?);
    try std.testing.expectEqualStrings("Regular documentation comment\nAnother comment", e.description.?);
}

test "解析 section 中的注解" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\[database]
        \\# @title Connection Timeout
        \\# Timeout in seconds for database connection
        \\timeout = 30
    ;

    try config.loadFromString(content);

    const section = config.sections.get("database");
    try std.testing.expect(section != null);

    const schema = section.?.getItem("timeout");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("Connection Timeout", e.title.?);
    try std.testing.expectEqualStrings("Timeout in seconds for database connection", e.description.?);
}

test "解析多个不同注解的配置项" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# @title Server Host
        \\host = example.com
        \\
        \\# @title Server Port
        \\# The port number for the server
        \\port = 8080
        \\
        \\# Regular comment for timeout
        \\timeout = 30
    ;

    try config.loadFromString(content);

    const host_schema = config.getItem("host");
    try std.testing.expect(host_schema != null);
    if (host_schema) |e| {
        try std.testing.expectEqualStrings("Server Host", e.title.?);
        try std.testing.expect(e.description == null);
    }

    const port_schema = config.getItem("port");
    try std.testing.expect(port_schema != null);
    if (port_schema) |e| {
        try std.testing.expectEqualStrings("Server Port", e.title.?);
        try std.testing.expectEqualStrings("The port number for the server", e.description.?);
    }

    const timeout_schema = config.getItem("timeout");
    try std.testing.expect(timeout_schema != null);
    if (timeout_schema) |e| {
        try std.testing.expectEqualStrings("Regular comment for timeout", e.description.?);
        try std.testing.expect(e.title == null);
    }
}

test "解析没有注解的配置项" {
    const allocator = std.testing.allocator;
    var config = Ini.default(allocator);
    defer config.deinit();

    const content =
        \\key = value
    ;

    try config.loadFromString(content);

    const schema = config.getItem("key");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expect(e.description == null);
    try std.testing.expect(e.title == null);
    try std.testing.expect(e.description == null);
}

test "解析值为空的 @title" {
    const allocator = std.testing.allocator;
    var config = Ini.default(allocator);
    defer config.deinit();

    const content =
        \\# @title
        \\key = value
    ;

    try config.loadFromString(content);

    const schema = config.getItem("key");
    try std.testing.expect(schema != null);

    const e = schema.?;
    // 空的 @title 应该被忽略
    try std.testing.expect(e.title == null);
}

test "保存并加载带 @title 注解的配置" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# @title Database Host
        \\db_host = localhost
    ;

    try config.loadFromString(content);

    // 保存到字符串
    const saved = try config.saveToString(allocator);
    defer allocator.free(saved);

    // 重新加载
    var config2 = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config2.deinit();
    try config2.loadFromString(saved);

    const schema = config2.getItem("db_host");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("Database Host", e.title.?);
}

test "保存并加载保持注释格式" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# Regular comment
        \\db_host = localhost
    ;

    try config.loadFromString(content);

    // 保存到字符串
    const saved = try config.saveToString(allocator);
    defer allocator.free(saved);

    // 重新加载
    var config2 = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config2.deinit();
    try config2.loadFromString(saved);

    const schema = config2.getItem("db_host");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("Regular comment", e.description.?);
}

test "保存并加载混合注解" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# Regular comment
        \\# @title Database Host
        \\# Another comment
        \\db_host = localhost
    ;

    try config.loadFromString(content);

    // 保存到字符串
    const saved = try config.saveToString(allocator);
    defer allocator.free(saved);

    // 验证保存的格式正确
    try std.testing.expect(std.mem.indexOf(u8, saved, "# Regular comment") != null);
    try std.testing.expect(std.mem.indexOf(u8, saved, "# @title Database Host") != null);
    try std.testing.expect(std.mem.indexOf(u8, saved, "# Another comment") != null);

    // 重新加载
    var config2 = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config2.deinit();
    try config2.loadFromString(saved);

    const schema = config2.getItem("db_host");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("Database Host", e.title.?);
    try std.testing.expectEqualStrings("Regular comment\nAnother comment", e.description.?);
}

test "保存输出保留 @title 和注释" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# Regular comment
        \\# @title Database Host
        \\# Another comment
        \\db_host = localhost
    ;

    try config.loadFromString(content);

    const saved = try config.saveToString(allocator);
    defer allocator.free(saved);

    // 验证输出包含必要元素
    try std.testing.expect(std.mem.indexOf(u8, saved, "# Regular comment") != null);
    try std.testing.expect(std.mem.indexOf(u8, saved, "# @title Database Host") != null);
    try std.testing.expect(std.mem.indexOf(u8, saved, "# Another comment") != null);
}

test "解析并保存多行文档注释" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# First line of comment
        \\# Second line of comment
        \\# Third line of comment
        \\key = value
    ;

    try config.loadFromString(content);

    const schema = config.getItem("key");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expect(e.description != null);
    const expected = "First line of comment\nSecond line of comment\nThird line of comment";
    try std.testing.expectEqualStrings(expected, e.description.?);

    // 保存并重新加载验证
    const saved = try config.saveToString(allocator);
    defer allocator.free(saved);

    var config2 = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config2.deinit();
    try config2.loadFromString(saved);

    const schema2 = config2.getItem("key");
    try std.testing.expect(schema2 != null);
    try std.testing.expectEqualStrings(expected, schema2.?.description.?);
}

test "解析 section 中的混合注解" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\[database]
        \\# Database configuration section
        \\
        \\# @title Host
        \\# Database server host
        \\host = localhost
        \\
        \\# @title Port
        \\port = 3306
    ;

    try config.loadFromString(content);

    const section = config.sections.get("database");
    try std.testing.expect(section != null);

    const host_schema = section.?.getItem("host");
    try std.testing.expect(host_schema != null);
    if (host_schema) |e| {
        try std.testing.expectEqualStrings("Host", e.title.?);
        try std.testing.expectEqualStrings("Database configuration section\nDatabase server host", e.description.?);
    }

    const port_schema = section.?.getItem("port");
    try std.testing.expect(port_schema != null);
    if (port_schema) |e| {
        try std.testing.expectEqualStrings("Port", e.title.?);
        try std.testing.expect(e.description == null);
    }
}

test "分号注释与注解" {
    const allocator = std.testing.allocator;
    var config = Ini.default(allocator);
    defer config.deinit();

    const content =
        \\; @title Semicolon Comment Title
        \\key = value
    ;

    try config.loadFromString(content);

    const schema = config.getItem("key");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("Semicolon Comment Title", e.title.?);
}

test "注解中的尾部空格" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# @title Title with trailing spaces
        \\# Description with trailing spaces
        \\key = value
    ;

    try config.loadFromString(content);

    const schema = config.getItem("key");
    try std.testing.expect(schema != null);

    const e = schema.?;
    // trimAll 应该删除前后空格
    try std.testing.expectEqualStrings("Title with trailing spaces", e.title.?);
    try std.testing.expectEqualStrings("Description with trailing spaces", e.description.?);
}

test "解析各种空格的 @title" {
    const allocator = std.testing.allocator;
    var config = Ini.default(allocator);
    defer config.deinit();

    // 测试 # 后多个空格
    var content_buffer: [200]u8 = undefined;
    const content = try std.fmt.bufPrint(&content_buffer,
        \\#     @title Multiple Spaces
        \\key=value
    , .{});

    try config.loadFromString(content);
    const schema = config.getItem("key");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("Multiple Spaces", e.title.?);
}

test "解析 # 后没有空格的 @title" {
    const allocator = std.testing.allocator;
    var config = Ini.default(allocator);
    defer config.deinit();

    // 测试 # 后没有空格
    const content = "#@title No Space\nkey=value\n";

    try config.loadFromString(content);
    const schema = config.getItem("key");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("No Space", e.title.?);
}

test "解析包含 tab 字符的 @title" {
    const allocator = std.testing.allocator;
    var config = Ini.default(allocator);
    defer config.deinit();

    // 测试 tab 字符（使用拼接创建包含 tab 的字符串）
    const content = try std.fmt.allocPrint(allocator, "#\t@title\tTab Title\nkey=value\n", .{});
    defer allocator.free(content);

    try config.loadFromString(content);
    const schema = config.getItem("key");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("Tab Title", e.title.?);
}

test "保存时统一 @title 的空格格式" {
    const allocator = std.testing.allocator;
    var config = Ini.default(allocator);
    defer config.deinit();

    // 各种空格格式保存后统一
    const content = "#     @title    Multiple Spaces\nkey=value\n";

    try config.loadFromString(content);
    const saved = try config.saveToString(allocator);
    defer allocator.free(saved);

    // 验证保存后的格式是标准的
    try std.testing.expect(std.mem.indexOf(u8, saved, "# @title Multiple Spaces") != null);
}

test "解析注释后有空行的配置项" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# 这是端口
        \\
        \\port=8080
    ;

    try config.loadFromString(content);

    const schema = config.getItem("port");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("这是端口", e.description.?);
    try std.testing.expectEqualStrings("8080", e.value);
}

test "解析多个空行的配置项" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# @title 端口配置
        \\# 这是服务器端口
        \\
        \\
        \\
        \\port=8080
    ;

    try config.loadFromString(content);

    const schema = config.getItem("port");
    try std.testing.expect(schema != null);

    const e = schema.?;
    try std.testing.expectEqualStrings("端口配置", e.title.?);
    try std.testing.expectEqualStrings("这是服务器端口", e.description.?);
    try std.testing.expectEqualStrings("8080", e.value);
}

test "保存带空行的配置" {
    const allocator = std.testing.allocator;
    var config = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer config.deinit();

    const content =
        \\# 这是端口
        \\
        \\port=8080
    ;

    try config.loadFromString(content);
    const saved = try config.saveToString(allocator);
    defer allocator.free(saved);

    // 验证注释被保留
    try std.testing.expect(std.mem.indexOf(u8, saved, "# 这是端口") != null);
    // 验证空行不会被保留
    const lines = std.mem.count(u8, saved, "\n");
    try std.testing.expect(lines == 2); // "# 这是端口\nport = 8080\n"
}
