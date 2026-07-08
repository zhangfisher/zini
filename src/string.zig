//! 通用字符串操作工具模块
//!
//! 提供基础字符串处理功能，可用于任何场景
//!
//! 函数分类：
//! - 基础操作：trim, trimLeft, isEmpty
//! - 前缀/后缀检查：startsWith, endsWith
//! - 引号处理：unquote, isQuote
//! - 类型检测：isBoolean, isNumeric, isNumber, isFloat, isString
//! - 子串查找：indexOf, includes
//! - 字符分类：isWhitespace
//! - 数组操作：findIndex, split, join

const std = @import("std");
const Allocator = std.mem.Allocator;

// ==================== 基础操作 ====================

/// 去除字符串两侧的所有空白字符（空格、制表符、回车、换行）
pub fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

/// 去除字符串左侧的空白字符
pub fn trimLeft(s: []const u8) []const u8 {
    var start: usize = 0;
    while (start < s.len and (s[start] == ' ' or s[start] == '\t' or s[start] == '\r' or s[start] == '\n')) {
        start += 1;
    }
    return s[start..];
}

/// 检查字符串是否为空
pub fn isEmpty(str: []const u8) bool {
    return str.len == 0;
}

// ==================== 前缀/后缀检查 ====================

/// 检查字符串是否以指定前缀开头
pub fn startsWith(str: []const u8, prefix: []const u8) bool {
    if (prefix.len > str.len) return false;
    return std.mem.eql(u8, str[0..prefix.len], prefix);
}

/// 检查字符串是否以指定后缀结尾
pub fn endsWith(str: []const u8, suffix: []const u8) bool {
    if (suffix.len > str.len) return false;
    return std.mem.eql(u8, str[str.len - suffix.len ..], suffix);
}

// ==================== 引号处理 ====================

/// 去除字符串两端的引号（"或'）
/// 如果字符串两端没有匹配的引号，返回原字符串
pub fn unquote(str: []const u8) []const u8 {
    if (str.len >= 2 and isQuote(str[0]) and str[str.len - 1] == str[0]) {
        return str[1 .. str.len - 1];
    }
    return str;
}

/// 检查字符是否为引号（"或'）
pub fn isQuote(c: u8) bool {
    return c == '"' or c == '\'';
}

// ==================== 类型检测 ====================

/// 检查是否为布尔值
pub fn isBoolean(str: []const u8) bool {
    const trimmed = trim(str);
    return std.ascii.eqlIgnoreCase(trimmed, "true") or
           std.ascii.eqlIgnoreCase(trimmed, "false");
}

/// 检查是否为数值（整数或浮点数）
/// 返回值：0 = 不是数值, 1 = 整数, 2 = 浮点数
pub fn isNumeric(str: []const u8) u2 {
    const trimmed = trim(str);
    if (trimmed.len == 0) return 0;

    var i: usize = 0;
    var dot_count: usize = 0;
    var digit_count: usize = 0;

    // 检查符号
    if (trimmed[0] == '+' or trimmed[0] == '-') {
        if (trimmed.len == 1) return 0;
        i = 1;
    }

    // 检查字符和点
    while (i < trimmed.len) : (i += 1) {
        if (trimmed[i] == '.') {
            dot_count += 1;
            if (dot_count > 1) return 0; // 多个点，不是有效数值
        } else if (!std.ascii.isDigit(trimmed[i])) {
            return 0; // 包含非数字字符
        } else {
            digit_count += 1; // 统计数字数量
        }
    }

    // 至少需要有一个数字
    if (digit_count == 0) return 0;

    // 0 = 不是数值, 1 = 整数, 2 = 浮点数
    if (dot_count == 0) return 1; // 纯整数
    if (dot_count == 1) return 2; // 浮点数
    return 0;
}

/// 检查是否为整数（允许符号）
pub fn isNumber(str: []const u8) bool {
    return isNumeric(str) == 1;
}

/// 检查是否为浮点数
pub fn isFloat(str: []const u8) bool {
    return isNumeric(str) == 2;
}

/// 检查是否为字符串（引号包裹）
pub fn isString(str: []const u8) bool {
    const trimmed = trim(str);
    if (trimmed.len < 2) return false;

    const first = trimmed[0];
    const last = trimmed[trimmed.len - 1];

    return (first == '\'' and last == '\'') or
           (first == '"' and last == '"');
}

// ==================== 子串查找 ====================

/// 查找子字符串在字符串中的位置
/// 返回 null 如果未找到
pub fn indexOf(str: []const u8, substr: []const u8) ?usize {
    if (substr.len == 0) return 0;
    if (substr.len > str.len) return null;
    return std.mem.indexOf(u8, str, substr);
}

/// 检查字符串是否包含指定子字符串
pub fn includes(str: []const u8, substr: []const u8) bool {
    return indexOf(str, substr) != null;
}

// ==================== 字符分类 ====================

/// 检查字符是否为空白字符（空格、制表符、回车、换行）
pub fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

// ==================== 数组操作 ====================

/// 在字符串数组中查找指定字符串
/// 返回索引位置（>=0 表示找到，-1 表示未找到）
pub fn find(arr: []const []const u8, str: []const u8) i32 {
    for (arr, 0..) |item, index| {
        if (std.mem.eql(u8, item, str)) {
            return @intCast(index);
        }
    }
    return -1;
}

/// 分割字符串为字符串数组
/// 使用指定的分隔符，跳过空项
pub fn split(allocator: Allocator, str: []const u8, delimiter: []const u8) ![][]const u8 {
    var list = try std.ArrayList([]const u8).initCapacity(allocator, 10);
    errdefer {
        for (list.items) |item| allocator.free(item);
        list.deinit(allocator);
    }

    var iter = std.mem.splitSequence(u8, str, delimiter);
    while (iter.next()) |item| {
        if (item.len > 0) {
            const item_copy = try allocator.dupe(u8, item);
            errdefer allocator.free(item_copy);
            list.appendAssumeCapacity(item_copy);
        }
    }
    return list.toOwnedSlice(allocator);
}

/// 合并字符串数组为单个字符串
/// 使用指定的分隔符连接所有字符串
pub fn join(allocator: Allocator, slices: []const []const u8, delimiter: []const u8) ![]const u8 {
    if (slices.len == 0) return "";

    var total_len: usize = 0;
    for (slices) |slice| total_len += slice.len;
    total_len += delimiter.len * (slices.len - 1);

    var result = try allocator.alloc(u8, total_len);
    errdefer allocator.free(result);

    var offset: usize = 0;
    for (slices, 0..) |slice, i| {
        @memcpy(result[offset..][0..slice.len], slice);
        offset += slice.len;
        if (i < slices.len - 1) {
            @memcpy(result[offset..][0..delimiter.len], delimiter);
            offset += delimiter.len;
        }
    }
    return result;
}

// ==================== 测试 ====================

test "trim - 去除两侧空白" {
    try std.testing.expectEqualStrings("test", trim("  test  "));
    try std.testing.expectEqualStrings("test", trim("\r\ntest\r\n"));
    try std.testing.expectEqualStrings("test", trim("  \r\n\ttest\t\r\n  "));
    try std.testing.expectEqualStrings("test", trim("test")); // 无空白
}

test "trimLeft - 去除左侧空白" {
    try std.testing.expectEqualStrings("test  ", trimLeft("  test  "));
    try std.testing.expectEqualStrings("test\r\n", trimLeft("\r\ntest\r\n"));
    try std.testing.expectEqualStrings("test", trimLeft("test")); // 无空白
}

test "isEmpty - 检查空字符串" {
    try std.testing.expect(isEmpty(""));
    try std.testing.expect(isEmpty(""));
    try std.testing.expect(!isEmpty("test"));
    try std.testing.expect(!isEmpty(" ")); // 只包含空格
}

test "startsWith - 检查前缀" {
    try std.testing.expect(startsWith("hello world", "hello"));
    try std.testing.expect(startsWith("hello", "hello"));
    try std.testing.expect(!startsWith("hello world", "world"));
    try std.testing.expect(!startsWith("hello", "hello world"));
    try std.testing.expect(startsWith("", "")); // 空字符串
}

test "endsWith - 检查后缀" {
    try std.testing.expect(endsWith("hello world", "world"));
    try std.testing.expect(endsWith("hello", "hello"));
    try std.testing.expect(!endsWith("hello world", "hello"));
    try std.testing.expect(!endsWith("hello", "hello world"));
    try std.testing.expect(endsWith("", "")); // 空字符串
}

test "isQuote - 检查引号" {
    try std.testing.expect(isQuote('"'));
    try std.testing.expect(isQuote('\''));
    try std.testing.expect(!isQuote('a'));
    try std.testing.expect(!isQuote(' '));
}

test "unquote - 去除引号" {
    try std.testing.expectEqualStrings("test", unquote("\"test\""));
    try std.testing.expectEqualStrings("test", unquote("'test'"));
    try std.testing.expectEqualStrings("\"test", unquote("\"test")); // 不匹配
    try std.testing.expectEqualStrings("test\"", unquote("test\"")); // 不匹配
    try std.testing.expectEqualStrings("test", unquote("test")); // 无引号
}

test "indexOf - 查找子串位置" {
    const idx1 = indexOf("hello world", "world");
    try std.testing.expectEqual(@as(usize, 6), idx1.?);

    const idx2 = indexOf("hello world", "lo");
    try std.testing.expectEqual(@as(usize, 3), idx2.?);

    const idx3 = indexOf("hello", "world");
    try std.testing.expect(idx3 == null);

    const idx4 = indexOf("test", "");
    try std.testing.expectEqual(@as(usize, 0), idx4.?); // 空子串
}

test "includes - 检查包含子串" {
    try std.testing.expect(includes("hello world", "world"));
    try std.testing.expect(includes("hello world", "lo"));
    try std.testing.expect(includes("hello", "hello"));
    try std.testing.expect(!includes("hello world", "xyz"));
    try std.testing.expect(!includes("hello", "hello world"));
}

test "isWhitespace - 检查空白字符" {
    try std.testing.expect(isWhitespace(' '));
    try std.testing.expect(isWhitespace('\t'));
    try std.testing.expect(isWhitespace('\r'));
    try std.testing.expect(isWhitespace('\n'));
    try std.testing.expect(!isWhitespace('a'));
    try std.testing.expect(!isWhitespace('0'));
}

test "find - 在数组中查找字符串" {
    const items = [_][]const u8{ "a", "b", "c" };
    const idx1 = find(&items, "b");
    try std.testing.expectEqual(@as(i32, 1), idx1);

    const idx2 = find(&items, "a");
    try std.testing.expectEqual(@as(i32, 0), idx2);

    const idx3 = find(&items, "d");
    try std.testing.expectEqual(@as(i32, -1), idx3);
}

test "split - 分割字符串" {
    const allocator = std.testing.allocator;

    const result1 = try split(allocator, "a,b,c", ",");
    defer {
        for (result1) |item| allocator.free(item);
        allocator.free(result1);
    }
    try std.testing.expectEqual(@as(usize, 3), result1.len);
    try std.testing.expectEqualStrings("a", result1[0]);
    try std.testing.expectEqualStrings("b", result1[1]);
    try std.testing.expectEqualStrings("c", result1[2]);

    // 测试跳过空项
    const result2 = try split(allocator, "a,,c", ",");
    defer {
        for (result2) |item| allocator.free(item);
        allocator.free(result2);
    }
    try std.testing.expectEqual(@as(usize, 2), result2.len);
    try std.testing.expectEqualStrings("a", result2[0]);
    try std.testing.expectEqualStrings("c", result2[1]);
}

test "join - 合并字符串数组" {
    const allocator = std.testing.allocator;

    const items = [_][]const u8{ "a", "b", "c" };
    const result1 = try join(allocator, &items, ",");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("a,b,c", result1);

    // 测试空数组
    const empty_items = [_][]const u8{};
    const result2 = try join(allocator, &empty_items, ",");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("", result2);
}

test "isBoolean - 检查布尔值" {
    // 测试各种格式
    try std.testing.expect(isBoolean("true"));
    try std.testing.expect(isBoolean("false"));
    try std.testing.expect(isBoolean("TRUE"));
    try std.testing.expect(isBoolean("FALSE"));
    try std.testing.expect(isBoolean("TrUe"));
    try std.testing.expect(isBoolean("FaLsE"));

    // 测试带空白
    try std.testing.expect(isBoolean("  true  "));
    try std.testing.expect(isBoolean("  false  "));

    // 测试非布尔值
    try std.testing.expect(!isBoolean("yes"));
    try std.testing.expect(!isBoolean("no"));
    try std.testing.expect(!isBoolean("1"));
    try std.testing.expect(!isBoolean("0"));
    try std.testing.expect(!isBoolean(""));
}

test "isNumeric - 检查数值类型" {
    // 测试整数 (返回1)
    try std.testing.expectEqual(@as(u2, 1), isNumeric("42"));
    try std.testing.expectEqual(@as(u2, 1), isNumeric("-100"));
    try std.testing.expectEqual(@as(u2, 1), isNumeric("+50"));
    try std.testing.expectEqual(@as(u2, 1), isNumeric("  123  ")); // 带空白
    try std.testing.expectEqual(@as(u2, 1), isNumeric("0"));

    // 测试浮点数 (返回2)
    try std.testing.expectEqual(@as(u2, 2), isNumeric("3.14"));
    try std.testing.expectEqual(@as(u2, 2), isNumeric("-0.5"));
    try std.testing.expectEqual(@as(u2, 2), isNumeric("+2.7"));
    try std.testing.expectEqual(@as(u2, 2), isNumeric("  1.5  ")); // 带空白
    try std.testing.expectEqual(@as(u2, 2), isNumeric("0.0"));

    // 测试非数值 (返回0)
    try std.testing.expectEqual(@as(u2, 0), isNumeric("")); // 空字符串
    try std.testing.expectEqual(@as(u2, 0), isNumeric("abc"));
    try std.testing.expectEqual(@as(u2, 0), isNumeric("1.2.3")); // 多个点
    try std.testing.expectEqual(@as(u2, 0), isNumeric("1.a")); // 字符混合
    try std.testing.expectEqual(@as(u2, 0), isNumeric(".")); // 只有点
    try std.testing.expectEqual(@as(u2, 0), isNumeric("+")); // 只有符号
    try std.testing.expectEqual(@as(u2, 0), isNumeric("-")); // 只有负号
}

test "isNumber - 检查整数" {
    // 测试整数
    try std.testing.expect(isNumber("42"));
    try std.testing.expect(isNumber("-100"));
    try std.testing.expect(isNumber("+50"));
    try std.testing.expect(isNumber("  123  ")); // 带空白
    try std.testing.expect(isNumber("0"));

    // 测试非整数
    try std.testing.expect(!isNumber("3.14")); // 浮点数
    try std.testing.expect(!isNumber("")); // 空字符串
    try std.testing.expect(!isNumber("abc")); // 字符串
    try std.testing.expect(!isNumber("1.2.3")); // 多个点
}

test "isFloat - 检查浮点数" {
    // 测试浮点数
    try std.testing.expect(isFloat("3.14"));
    try std.testing.expect(isFloat("-0.5"));
    try std.testing.expect(isFloat("+2.7"));
    try std.testing.expect(isFloat("  1.5  ")); // 带空白
    try std.testing.expect(isFloat("0.0"));

    // 测试非浮点数
    try std.testing.expect(!isFloat("42")); // 整数
    try std.testing.expect(!isFloat("")); // 空字符串
    try std.testing.expect(!isFloat("abc")); // 字符串
    try std.testing.expect(!isFloat("1.2.3")); // 多个点
    try std.testing.expect(!isFloat(".")); // 只有点
}

test "isString - 检查引号包裹" {
    // 测试单引号
    try std.testing.expect(isString("'hello'"));
    try std.testing.expect(isString("'hello world'"));

    // 测试双引号
    try std.testing.expect(isString("\"hello\""));
    try std.testing.expect(isString("\"hello world\""));

    // 测试带空白
    try std.testing.expect(isString("  'hello'  "));
    try std.testing.expect(isString("  \"hello\"  "));

    // 测试非引号包裹
    try std.testing.expect(!isString("hello")); // 无引号
    try std.testing.expect(!isString("'hello")); // 不匹配
    try std.testing.expect(!isString("hello'")); // 不匹配
    try std.testing.expect(!isString("\"hello")); // 不匹配
    try std.testing.expect(!isString("hello\"")); // 不匹配
    try std.testing.expect(!isString("")); // 空字符串
    try std.testing.expect(!isString("'")); // 单个引号
    try std.testing.expect(!isString("\"")); // 单个引号
}
