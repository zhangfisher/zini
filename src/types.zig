//! INI 库的类型系统
//!
//! 支持自动类型推断、显式类型标识和类型安全的值访问

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Item 标志位枚举
pub const ItemFlags = enum(u8) {
    /// 未指定标志
    none = 0,
    // 未来可以添加其他标志，如hasValidation, hasDescription等
};

/// Zig 基本数据类型
pub const DataType = enum(u8) {
    /// 字符串类型 - []const u8
    string = 0,
    /// 布尔类型 - bool
    boolean = 1,
    /// 整数类型 - i64
    number = 2,
    /// 浮点类型 - f64
    float = 3,

    /// 自动推断类型
    /// 推断规则：
    /// - 调用isString检查引号包裹 -> string
    /// - 调用isBoolean检查 -> boolean
    /// - 调用isNumeric判断：1->number, 2->float
    /// - 其他 -> string
    pub fn infer(value: []const u8) DataType {
        const string_mod = @import("string.zig");
        const trimmed = std.mem.trim(u8, value, " \t\r\n");

        // 空字符串视为string
        if (trimmed.len == 0) return .string;

        // 检查引号包裹
        if (string_mod.isString(trimmed)) return .string;

        // 检查布尔值
        if (string_mod.isBoolean(trimmed)) return .boolean;

        // 检查数值类型
        const numeric_type = string_mod.isNumeric(trimmed);
        if (numeric_type == 1) return .number;   // 整数
        if (numeric_type == 2) return .float;    // 浮点数

        // 默认为字符串
        return .string;
    }

    /// 获取类型名称
    pub fn toTypeName(self: DataType) []const u8 {
        return switch (self) {
            .string => "string",
            .boolean => "boolean",
            .number => "number",
            .float => "float",
        };
    }

    /// 检查是否为整数类型
    pub fn isNumber(self: DataType) bool {
        return self == .number;
    }

    /// 检查是否为浮点类型
    pub fn isFloat(self: DataType) bool {
        return self == .float;
    }

    /// 检查是否为布尔类型
    pub fn isBoolean(self: DataType) bool {
        return self == .boolean;
    }

    /// 检查是否为字符串类型
    pub fn isString(self: DataType) bool {
        return self == .string;
    }
};

/// 类型转换工具
pub const TypeConverter = struct {
    /// 转换为布尔值
    pub fn toBoolean(str: []const u8) !bool {
        const trimmed = std.mem.trim(u8, str, " \t\r\n");
        if (std.ascii.eqlIgnoreCase(trimmed, "true")) return true;
        if (std.ascii.eqlIgnoreCase(trimmed, "false")) return false;
        return error.InvalidBoolean;
    }

    /// 转换为整数 (i64)
    pub fn toNumber(str: []const u8) !i64 {
        const trimmed = std.mem.trim(u8, str, " \t\r\n");
        return std.fmt.parseInt(i64, trimmed, 10);
    }

    /// 转换为浮点数 (f64)
    pub fn toFloat(str: []const u8) !f64 {
        const trimmed = std.mem.trim(u8, str, " \t\r\n");
        return std.fmt.parseFloat(f64, trimmed);
    }

    /// 转换为字符串
    pub fn toString(str: []const u8) []const u8 {
        return std.mem.trim(u8, str, " \t\r\n");
    }
};

/// 数组值存储结构
pub fn ArrayValue(comptime T: type) type {
    return struct {
        allocator: Allocator,
        items: []T,

        const Self = @This();

        /// 创建数组
        pub fn init(allocator: Allocator, items: []T) Allocator.Error!Self {
            const items_copy = try allocator.dupe(T, items);
            return .{
                .allocator = allocator,
                .items = items_copy,
            };
        }

        /// 释放数组资源
        pub fn deinit(self: Self) void {
            self.allocator.free(self.items);
        }

        /// 获取长度
        pub fn len(self: Self) usize {
            return self.items.len;
        }

        /// 获取指定索引的元素
        pub fn get(self: Self, index: usize) ?T {
            if (index >= self.items.len) return null;
            return self.items[index];
        }
    };
}

/// 字符串数组（特殊处理，因为元素是动态分配的）
pub const StringArray = struct {
    allocator: Allocator,
    items: [][]const u8,

    /// 创建字符串数组
    pub fn init(allocator: Allocator, strings: []const []const u8) Allocator.Error!StringArray {
        const items_copy = try allocator.alloc([]const u8, strings.len);
        errdefer allocator.free(items_copy);

        for (strings, 0..) |s, i| {
            items_copy[i] = try allocator.dupe(u8, s);
        }

        return .{
            .allocator = allocator,
            .items = items_copy,
        };
    }

    /// 释放字符串数组资源
    pub fn deinit(self: StringArray) void {
        for (self.items) |s| {
            self.allocator.free(s);
        }
        self.allocator.free(self.items);
    }

    /// 获取长度
    pub fn len(self: StringArray) usize {
        return self.items.len;
    }

    /// 获取指定索引的字符串
    pub fn get(self: StringArray, index: usize) ?[]const u8 {
        if (index >= self.items.len) return null;
        return self.items[index];
    }
};

// 测试
test "DataType toTypeName" {
    try std.testing.expectEqualStrings("string", DataType.string.toTypeName());
    try std.testing.expectEqualStrings("boolean", DataType.boolean.toTypeName());
    try std.testing.expectEqualStrings("number", DataType.number.toTypeName());
    try std.testing.expectEqualStrings("float", DataType.float.toTypeName());
}

test "DataType type check methods" {
    // 测试各种类型的检查方法
    try std.testing.expect(DataType.string.isString());
    try std.testing.expect(!DataType.string.isNumber());
    try std.testing.expect(!DataType.string.isBoolean());
    try std.testing.expect(!DataType.string.isFloat());

    try std.testing.expect(!DataType.number.isString());
    try std.testing.expect(DataType.number.isNumber());
    try std.testing.expect(!DataType.number.isBoolean());
    try std.testing.expect(!DataType.number.isFloat());

    try std.testing.expect(!DataType.boolean.isString());
    try std.testing.expect(!DataType.boolean.isNumber());
    try std.testing.expect(DataType.boolean.isBoolean());
    try std.testing.expect(!DataType.boolean.isFloat());

    try std.testing.expect(!DataType.float.isString());
    try std.testing.expect(!DataType.float.isNumber());
    try std.testing.expect(!DataType.float.isBoolean());
    try std.testing.expect(DataType.float.isFloat());
}

test "DataType infer" {
    // 测试字符串推断（引号包裹）
    try std.testing.expectEqual(DataType.string, DataType.infer("'hello'"));
    try std.testing.expectEqual(DataType.string, DataType.infer("\"world\""));
    try std.testing.expectEqual(DataType.string, DataType.infer("  'test'  "));

    // 测试布尔值推断
    try std.testing.expectEqual(DataType.boolean, DataType.infer("true"));
    try std.testing.expectEqual(DataType.boolean, DataType.infer("false"));
    try std.testing.expectEqual(DataType.boolean, DataType.infer("  TRUE  "));
    try std.testing.expectEqual(DataType.boolean, DataType.infer("  False  "));

    // 测试整数推断
    try std.testing.expectEqual(DataType.number, DataType.infer("42"));
    try std.testing.expectEqual(DataType.number, DataType.infer("-100"));
    try std.testing.expectEqual(DataType.number, DataType.infer("+50"));
    try std.testing.expectEqual(DataType.number, DataType.infer("  123  "));
    try std.testing.expectEqual(DataType.number, DataType.infer("0"));

    // 测试浮点数推断
    try std.testing.expectEqual(DataType.float, DataType.infer("3.14"));
    try std.testing.expectEqual(DataType.float, DataType.infer("-0.5"));
    try std.testing.expectEqual(DataType.float, DataType.infer("+2.7"));
    try std.testing.expectEqual(DataType.float, DataType.infer("  1.5  "));
    try std.testing.expectEqual(DataType.float, DataType.infer("0.0"));

    // 测试默认字符串推断（非引号包裹的文本）
    try std.testing.expectEqual(DataType.string, DataType.infer("hello"));
    try std.testing.expectEqual(DataType.string, DataType.infer("test123"));
    try std.testing.expectEqual(DataType.string, DataType.infer("")); // 空字符串
    try std.testing.expectEqual(DataType.string, DataType.infer("abc123def"));
}

test "TypeConverter basic conversions" {
    // 测试布尔值转换
    {
        const result = try TypeConverter.toBoolean("true");
        try std.testing.expect(result);

        const result2 = try TypeConverter.toBoolean("false");
        try std.testing.expect(!result2);

        const result3 = try TypeConverter.toBoolean("  TRUE  ");
        try std.testing.expect(result3);
    }

    // 测试整数转换
    {
        const result = try TypeConverter.toNumber("42");
        try std.testing.expectEqual(@as(i64, 42), result);

        const result2 = try TypeConverter.toNumber("-100");
        try std.testing.expectEqual(@as(i64, -100), result2);

        const result3 = try TypeConverter.toNumber("+50");
        try std.testing.expectEqual(@as(i64, 50), result3);
    }

    // 测试浮点数转换
    {
        const result = try TypeConverter.toFloat("3.14");
        try std.testing.expectApproxEqAbs(@as(f64, 3.14), result, 0.001);

        const result2 = try TypeConverter.toFloat("-0.5");
        try std.testing.expectApproxEqAbs(@as(f64, -0.5), result2, 0.001);
    }

    // 测试字符串转换
    {
        const result = TypeConverter.toString("  hello  ");
        try std.testing.expectEqualStrings("hello", result);
    }
}

test "TypeConverter error cases" {
    // 测试无效布尔值
    {
        const result = TypeConverter.toBoolean("yes");
        try std.testing.expectError(error.InvalidBoolean, result);
    }

    // 测试无效整数
    {
        const result = TypeConverter.toNumber("abc");
        try std.testing.expectError(error.InvalidCharacter, result);
    }

    // 测试无效浮点数
    {
        const result = TypeConverter.toFloat("xyz");
        try std.testing.expectError(error.InvalidCharacter, result);
    }
}
