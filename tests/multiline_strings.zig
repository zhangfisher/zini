//! 多行字符串功能测试

const std = @import("std");
const Ini = @import("zini").Ini;

test "基本多行字符串" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\memo=```aaa
        \\sfsfsd
        \\dfsdfd
        \\```
    ;

    try ini.loadFromString(content);

    const memo = ini.get("memo").?;
    try std.testing.expectEqualStrings("aaa\nsfsfsd\ndfsdfd", memo);
}

test "多行字符串包含空行" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\content=```line1
        \\
        \\line3
        \\
        \\
        \\line6
        \\```
    ;

    try ini.loadFromString(content);

    const content_value = ini.get("content").?;
    try std.testing.expectEqualStrings("line1\n\nline3\n\n\nline6", content_value);
}

test "容错 - 缺少结束标识遇到新section" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\text=```line1
        \\line2
        \\
        \\[next_section]
        \\key=value
    ;

    try ini.loadFromString(content);

    const text = ini.get("text").?;
    try std.testing.expectEqualStrings("line1\nline2", text);

    const key = ini.get("next_section.key").?;
    try std.testing.expectEqualStrings("value", key);
}

test "类型约束 - 非字符串类型忽略多行" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\count:int = 42
        \\name:string = ```line1
        \\line2
        \\```
    ;

    try ini.loadFromString(content);

    const count = try ini.getInt("count");
    try std.testing.expectEqual(@as(i64, 42), count);

    const name = ini.get("name").?;
    try std.testing.expectEqualStrings("line1\nline2", name);
}

test "混合单行和多行" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\name=single line
        \\description=```multi
        \\line
        \\value
        \\```
        \\version=1.0.0
    ;

    try ini.loadFromString(content);

    const name = ini.get("name").?;
    try std.testing.expectEqualStrings("single line", name);

    const description = ini.get("description").?;
    try std.testing.expectEqualStrings("multi\nline\nvalue", description);

    const version = ini.get("version").?;
    try std.testing.expectEqualStrings("1.0.0", version);
}

test "空多行字符串" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\empty=```
        \\
        \\```
    ;

    try ini.loadFromString(content);

    const empty = ini.get("empty").?;
    try std.testing.expectEqualStrings("", empty);
}

test "包含特殊字符" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\sql=```SELECT * FROM users
        \\WHERE name = 'admin'
        \\AND status = 'active'
        \\```
    ;

    try ini.loadFromString(content);

    const sql = ini.get("sql").?;
    try std.testing.expectEqualStrings("SELECT * FROM users\nWHERE name = 'admin'\nAND status = 'active'", sql);
}

test "文件尾容错" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\last=```line1
        \\line2
        \\```
    ;

    try ini.loadFromString(content);

    const last = ini.get("last").?;
    try std.testing.expectEqualStrings("line1\nline2", last);
}

test "引号字符串不受影响" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\quoted="single line"
        \\multi=```actual
        \\multi
        \\line
        \\```
    ;

    try ini.loadFromString(content);

    const quoted = ini.get("quoted").?;
    try std.testing.expectEqualStrings("single line", quoted);

    const multi = ini.get("multi").?;
    try std.testing.expectEqualStrings("actual\nmulti\nline", multi);
}

test "全局和section混合" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\global_multi=```line1
        \\line2
        \\```
        \\
        \\[section]
        \\local_multi=```line3
        \\line4
        \\```
    ;

    try ini.loadFromString(content);

    const global_multi = ini.get("global_multi").?;
    try std.testing.expectEqualStrings("line1\nline2", global_multi);

    const local_multi = ini.get("section.local_multi").?;
    try std.testing.expectEqualStrings("line3\nline4", local_multi);
}

test "多行字符串trimAll处理" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\text=```
        \\line1
        \\line2
        \\
        \\```
    ;

    try ini.loadFromString(content);

    const text = ini.get("text").?;
    // 首尾空白应该被去除
    try std.testing.expectEqualStrings("line1\nline2", text);
}

test "多行字符串包含注释字符" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\comment=```This is a comment
        \\# This is also part of the string
        \\; This too
        \\```
    ;

    try ini.loadFromString(content);

    const comment = ini.get("comment").?;
    try std.testing.expectEqualStrings("This is a comment\n# This is also part of the string\n; This too", comment);
}
