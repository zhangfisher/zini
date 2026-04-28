//! INI 库的类型系统
//!
//! 支持自动类型推断、显式类型标识和类型安全的值访问

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Zig 基本数据类型
pub const DataType = enum(u8) {
    // 基础类型（用于自动推断）
    /// 字符串类型
    string = 0,
    /// 布尔类型
    bool = 1,

    // 整数类型
    /// 8位无符号整数
    u8 = 10,
    /// 16位无符号整数
    u16 = 11,
    /// 32位无符号整数
    u32 = 12,
    /// 64位无符号整数
    u64 = 13,
    /// 8位有符号整数
    i8 = 14,
    /// 16位有符号整数
    i16 = 15,
    /// 32位有符号整数
    i32 = 16,
    /// 64位有符号整数
    i64 = 17,
    /// 有符号整数（自动推断）
    int = 18,

    // 浮点类型
    /// 32位浮点数
    f32 = 20,
    /// 64位浮点数
    f64 = 21,
    /// 浮点数（自动推断）
    float = 22,

    // 数组类型标记
    /// 数组类型（具体元素类型由 Entry.array_datatype 指定）
    array = 30,

    /// 获取类型名称
    pub fn typeName(self: DataType) []const u8 {
        return switch (self) {
            .string => "string",
            .bool => "bool",
            .u8 => "u8",
            .u16 => "u16",
            .u32 => "u32",
            .u64 => "u64",
            .i8 => "i8",
            .i16 => "i16",
            .i32 => "i32",
            .i64 => "i64",
            .int => "i64",
            .f32 => "f32",
            .f64 => "f64",
            .float => "f64",
            .array => "array",
        };
    }

    /// 解析类型标识符
    pub fn parse(type_str: []const u8) ?DataType {
        if (std.mem.eql(u8, type_str, "bool")) return .bool;
        if (std.mem.eql(u8, type_str, "u8")) return .u8;
        if (std.mem.eql(u8, type_str, "u16")) return .u16;
        if (std.mem.eql(u8, type_str, "u32")) return .u32;
        if (std.mem.eql(u8, type_str, "u64")) return .u64;
        if (std.mem.eql(u8, type_str, "i8")) return .i8;
        if (std.mem.eql(u8, type_str, "i16")) return .i16;
        if (std.mem.eql(u8, type_str, "i32")) return .i32;
        if (std.mem.eql(u8, type_str, "i64")) return .i64;
        if (std.mem.eql(u8, type_str, "int")) return .int;
        if (std.mem.eql(u8, type_str, "f32")) return .f32;
        if (std.mem.eql(u8, type_str, "f64")) return .f64;
        if (std.mem.eql(u8, type_str, "float")) return .float;
        if (std.mem.eql(u8, type_str, "string")) return .string;
        return null;
    }

    /// 检查是否为整数类型
    pub fn isInteger(self: DataType) bool {
        return switch (self) {
            .u8, .u16, .u32, .u64, .i8, .i16, .i32, .i64, .int => true,
            else => false,
        };
    }

    /// 检查是否为浮点类型
    pub fn isFloat(self: DataType) bool {
        return switch (self) {
            .f32, .f64, .float => true,
            else => false,
        };
    }

    /// 检查是否为布尔类型
    pub fn isBool(self: DataType) bool {
        return self == .bool;
    }

    /// 检查是否为字符串类型
    pub fn isString(self: DataType) bool {
        return self == .string;
    }

    /// 从字符串推断数据类型
    pub fn infer(str: []const u8) DataType {
        const trimmed = std.mem.trim(u8, str, " \t\r\n");

        if (trimmed.len == 0) {
            return .string;
        }

        // 检查布尔值
        if (isBoolValue(trimmed)) {
            return .bool;
        }

        // 检查整数
        if (isIntegerValue(trimmed)) {
            return .int;
        }

        // 检查浮点数
        if (isFloatValue(trimmed)) {
            return .float;
        }

        // 默认为字符串
        return .string;
    }

    /// 根据数值大小推断合适的无符号整数类型
    pub fn inferValueSize(value: u64) DataType {
        if (value <= std.math.maxInt(u8)) {
            return .u8;
        } else if (value <= std.math.maxInt(u16)) {
            return .u16;
        } else if (value <= std.math.maxInt(u32)) {
            return .u32;
        } else {
            return .u64;
        }
    }
};

/// 检查是否为布尔值
fn isBoolValue(str: []const u8) bool {
    return std.ascii.eqlIgnoreCase(str, "true") or
           std.ascii.eqlIgnoreCase(str, "false");
}

/// 检查是否为整数格式（支持十进制、0b二进制、0x十六进制）
/// 注意：0b 和 0x 前缀不支持负号
fn isIntegerValue(str: []const u8) bool {
    if (str.len == 0) return false;

    // 检查是否有符号
    const has_sign = str[0] == '+' or str[0] == '-';

    // 检查二进制前缀 0b（不支持负号）
    if (!has_sign and str.len >= 3 and str[0] == '0' and str[1] == 'b') {
        // 检查剩余字符都是 0 或 1
        for (str[2..]) |c| {
            if (c != '0' and c != '1') return false;
        }
        return true; // 至少有一个二进制位
    }

    // 检查十六进制前缀 0x（不支持负号）
    if (!has_sign and str.len >= 3 and str[0] == '0' and str[1] == 'x') {
        // 检查剩余字符都是十六进制数字
        for (str[2..]) |c| {
            if (!(std.ascii.isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F'))) {
                return false;
            }
        }
        return true; // 至少有一个十六进制位
    }

    // 检查十进制数字（支持符号）
    var start: usize = 0;
    if (has_sign) {
        if (str.len == 1) return false;
        start = 1;
    }

    // 检查所有字符都是十进制数字
    for (str[start..]) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }

    return true;
}

/// 检查是否为浮点数格式
fn isFloatValue(str: []const u8) bool {
    if (str.len == 0) return false;

    var start: usize = 0;
    // 处理符号
    if (str[0] == '+' or str[0] == '-') {
        if (str.len == 1) return false;
        start = 1;
    }

    var has_dot = false;
    var has_digit = false;

    for (str[start..]) |c| {
        if (c == '.') {
            if (has_dot) return false; // 多个小数点
            has_dot = true;
        } else if (std.ascii.isDigit(c)) {
            has_digit = true;
        } else {
            return false;
        }
    }

    // 必须有小数点和至少一个数字
    return has_dot and has_digit;
}

/// 类型转换工具
pub const TypeConverter = struct {
    /// 解析整数（支持 0b 二进制、0x 十六进制、十进制）
    /// 注意：0b 和 0x 前缀不支持负号
    fn parseInt(comptime T: type, str: []const u8) !T {
        const trimmed = std.mem.trim(u8, str, " \t\r\n");

        // 检查是否有符号
        const has_sign = trimmed.len > 0 and (trimmed[0] == '+' or trimmed[0] == '-');

        // 检查二进制前缀 0b（不支持负号）
        if (!has_sign and trimmed.len >= 3 and trimmed[0] == '0' and trimmed[1] == 'b') {
            const binary_str = trimmed[2..];
            return std.fmt.parseInt(T, binary_str, 2);
        }

        // 检查十六进制前缀 0x（不支持负号）
        if (!has_sign and trimmed.len >= 3 and trimmed[0] == '0' and trimmed[1] == 'x') {
            const hex_str = trimmed[2..];
            return std.fmt.parseInt(T, hex_str, 16);
        }

        // 默认十进制（支持符号）
        return std.fmt.parseInt(T, trimmed, 10);
    }

    /// 转换为布尔值
    pub fn toBool(str: []const u8) !bool {
        const trimmed = std.mem.trim(u8, str, " \t\r\n");
        if (std.ascii.eqlIgnoreCase(trimmed, "true")) return true;
        if (std.ascii.eqlIgnoreCase(trimmed, "false")) return false;
        return error.InvalidBool;
    }

    /// 转换为 u8
    pub fn toU8(str: []const u8) !u8 {
        return parseInt(u8, str);
    }

    /// 转换为 u16
    pub fn toU16(str: []const u8) !u16 {
        return parseInt(u16, str);
    }

    /// 转换为 u32
    pub fn toU32(str: []const u8) !u32 {
        return parseInt(u32, str);
    }

    /// 转换为 u64
    pub fn toU64(str: []const u8) !u64 {
        return parseInt(u64, str);
    }

    /// 转换为 i8
    pub fn toI8(str: []const u8) !i8 {
        return parseInt(i8, str);
    }

    /// 转换为 i16
    pub fn toI16(str: []const u8) !i16 {
        return parseInt(i16, str);
    }

    /// 转换为 i32
    pub fn toI32(str: []const u8) !i32 {
        return parseInt(i32, str);
    }

    /// 转换为 i64
    pub fn toI64(str: []const u8) !i64 {
        return parseInt(i64, str);
    }

    /// 转换为 f32
    pub fn toF32(str: []const u8) !f32 {
        const trimmed = std.mem.trim(u8, str, " \t\r\n");
        return std.fmt.parseFloat(f32, trimmed);
    }

    /// 转换为 f64
    pub fn toF64(str: []const u8) !f64 {
        const trimmed = std.mem.trim(u8, str, " \t\r\n");
        return std.fmt.parseFloat(f64, trimmed);
    }

    /// 转换为字符串（无需转换，直接返回）
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
test "DataType parse" {
    // 布尔类型
    try std.testing.expectEqual(DataType.bool, DataType.parse("bool").?);

    // 无符号整数
    try std.testing.expectEqual(DataType.u8, DataType.parse("u8").?);
    try std.testing.expectEqual(DataType.u16, DataType.parse("u16").?);
    try std.testing.expectEqual(DataType.u32, DataType.parse("u32").?);
    try std.testing.expectEqual(DataType.u64, DataType.parse("u64").?);

    // 有符号整数
    try std.testing.expectEqual(DataType.i8, DataType.parse("i8").?);
    try std.testing.expectEqual(DataType.i16, DataType.parse("i16").?);
    try std.testing.expectEqual(DataType.i32, DataType.parse("i32").?);
    try std.testing.expectEqual(DataType.i64, DataType.parse("i64").?);

    // 浮点数
    try std.testing.expectEqual(DataType.f32, DataType.parse("f32").?);
    try std.testing.expectEqual(DataType.f64, DataType.parse("f64").?);

    // 无效类型
    try std.testing.expect(DataType.parse("invalid") == null);
}

test "TypeConverter with specific types" {
    // u8 转换
    {
        const result = try TypeConverter.toU8("255");
        try std.testing.expectEqual(@as(u8, 255), result);
    }

    // i32 转换
    {
        const result = try TypeConverter.toI32("-12345");
        try std.testing.expectEqual(@as(i32, -12345), result);
    }

    // f32 转换
    {
        const result = try TypeConverter.toF32("3.14");
        try std.testing.expectApproxEqAbs(@as(f32, 3.14), result, 0.001);
    }

    // 类型溢出测试
    {
        // u8 溢出 - 256 超出 u8 范围
        const result = TypeConverter.toU8("256");
        try std.testing.expectError(error.Overflow, result);
    }
}
