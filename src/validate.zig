//! INI 配置校验框架
//!
//! 提供灵活的校验机制，支持动态添加/移除校验器
//!
//! 核心组件：
//! - Validator：校验器接口
//! - ValidatorRegistry：校验器注册表
//! - ChoiceValidator：内置的 choices 校验器

const std = @import("std");
const Allocator = std.mem.Allocator;

// 导入字符串操作模块
const string_mod = @import("string.zig");

// 前向声明，避免循环依赖
const Schema = @import("ini.zig").Schema;

/// 校验器接口
pub const Validator = struct {
    /// 校验器名称
    name: []const u8,
    /// 校验函数：返回 true 表示通过，false 表示失败
    validate: *const fn (value: []const u8, schema: *const Schema) bool,

    pub fn init(name: []const u8, validate_fn: *const fn (value: []const u8, schema: *const Schema) bool) Validator {
        return .{
            .name = name,
            .validate = validate_fn,
        };
    }
};

/// 校验器注册表
pub const ValidatorRegistry = struct {
    allocator: Allocator,
    /// Map<key, []Validator>
    validators: std.StringHashMap(std.ArrayList(Validator)),

    const Self = @This();

    /// 创建注册表（自动添加内置的 ChoiceValidator）
    pub fn init(allocator: Allocator) Self {
        var registry = Self{
            .allocator = allocator,
            .validators = std.StringHashMap(std.ArrayList(Validator)).init(allocator),
        };

        // 自动添加内置的 ChoiceValidator（使用 "*" 作为通配符）
        const choice_validator = ChoiceValidator.create();
        registry.add("*", choice_validator) catch unreachable;

        return registry;
    }

    /// 释放注册表
    pub fn deinit(self: *Self) void {
        var iter = self.validators.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.validators.deinit();
    }

    /// 添加校验器（检查同名，存在则忽略）
    pub fn add(self: *Self, key: []const u8, validator: Validator) !void {
        const result = try self.validators.getOrPut(key);
        if (!result.found_existing) {
            result.value_ptr.* = .{
                .items = &.{},
                .capacity = 0,
            };
            try result.value_ptr.ensureTotalCapacity(self.allocator, 4);
        }

        // 检查是否存在同名校验器，存在则忽略
        for (result.value_ptr.items) |v| {
            if (std.mem.eql(u8, v.name, validator.name)) {
                return; // 同名存在，忽略
            }
        }

        try result.value_ptr.append(self.allocator, validator);
    }

    /// 移除校验器
    /// 如果 name 为空，移除指定 key 的所有校验器
    /// 如果 name 不为空，移除指定 key 的特定校验器
    pub fn remove(self: *Self, key: []const u8, name: []const u8) void {
        if (self.validators.fetchRemove(key)) |kv| {
            if (name.len == 0) {
                // 移除所有校验器
                @constCast(&kv.value).deinit(self.allocator);
            } else {
                // 移除特定校验器
                var list = @constCast(&kv.value);
                for (list.items, 0..) |validator, i| {
                    if (std.mem.eql(u8, validator.name, name)) {
                        _ = list.orderedRemove(i);
                        break;
                    }
                }
                // 放回修改后的列表
                self.validators.put(kv.key, kv.value) catch unreachable;
            }
        }
    }

    /// 校验指定 key 的值
    pub fn validate(self: *const Self, key: []const u8, value: []const u8, schema: *const Schema) bool {
        // 先检查 "*" 校验器（对所有 key 都生效）
        if (self.validators.get("*")) |global_list| {
            for (global_list.items) |validator| {
                if (!validator.validate(value, schema)) {
                    return false;
                }
            }
        }

        // 再检查用户添加的特定 key 的校验器
        if (self.validators.get(key)) |list| {
            for (list.items) |validator| {
                if (!validator.validate(value, schema)) {
                    return false;
                }
            }
        }

        return true;
    }
};

/// ChoiceValidator - 校验值是否在允许的 choices 中
pub const ChoiceValidator = struct {
    fn validateImpl(value: []const u8, schema: *const Schema) bool {
        if (schema.choices) |choices| {
            const trimmed = string_mod.trim(value);
            const idx = string_mod.find(choices, trimmed);
            return idx >= 0;
        }
        return true; // 没有 choices 限制
    }

    /// 创建 ChoiceValidator 实例
    pub fn create() Validator {
        return Validator.init("choice", validateImpl);
    }
};

/// 重新导出 split 和 join 函数以保持向后兼容
pub const split = string_mod.split;
pub const join = string_mod.join;

// 测试
test "split - basic" {
    const allocator = std.testing.allocator;

    const result = try split(allocator, "a,b,c", ",");
    defer {
        for (result) |item| allocator.free(item);
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("b", result[1]);
    try std.testing.expectEqualStrings("c", result[2]);
}

test "split - empty items" {
    const allocator = std.testing.allocator;

    const result = try split(allocator, "a,,c", ",");
    defer {
        for (result) |item| allocator.free(item);
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("c", result[1]);
}

test "join - basic" {
    const allocator = std.testing.allocator;

    const items = [_][]const u8{ "a", "b", "c" };
    const result = try join(allocator, &items, ",");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("a,b,c", result);
}

test "join - empty" {
    const allocator = std.testing.allocator;

    const items = [_][]const u8{};
    const result = try join(allocator, &items, ",");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "findIndex - found" {
    const items = [_][]const u8{ "a", "b", "c" };

    const idx = string_mod.find(&items, "b");
    try std.testing.expectEqual(@as(i32, 1), idx);
}

test "findIndex - not found" {
    const items = [_][]const u8{ "a", "b", "c" };

    const idx = string_mod.find(&items, "d");
    try std.testing.expectEqual(@as(i32, -1), idx);
}

test "ValidatorRegistry - add and validate" {
    const allocator = std.testing.allocator;

    var registry = ValidatorRegistry.init(allocator);
    defer registry.deinit();

    // 创建测试校验器
    const TestValidator = struct {
        fn validateImpl(value: []const u8, schema: *const Schema) bool {
            _ = schema;
            return std.mem.eql(u8, value, "ok");
        }
    };

    const validator = Validator.init("test", TestValidator.validateImpl);
    try registry.add("test_key", validator);

    // 创建测试 schema
    var schema = try Schema.init(allocator, "test_key", "value");
    defer schema.deinit(allocator);

    // 校验测试
    try std.testing.expect(registry.validate("test_key", "ok", &schema));
    try std.testing.expect(!registry.validate("test_key", "not_ok", &schema));
}

test "ValidatorRegistry - remove" {
    const allocator = std.testing.allocator;

    var registry = ValidatorRegistry.init(allocator);
    defer registry.deinit();

    // 添加校验器
    const TestValidator = struct {
        fn validateImpl(value: []const u8, schema: *const Schema) bool {
            _ = schema;
            return std.mem.eql(u8, value, "ok");
        }
    };

    const validator1 = Validator.init("test1", TestValidator.validateImpl);
    const validator2 = Validator.init("test2", TestValidator.validateImpl);

    try registry.add("key", validator1);
    try registry.add("key", validator2);

    var schema = try Schema.init(allocator, "key", "value");
    defer schema.deinit(allocator);

    // 初始状态：两个校验器都生效
    try std.testing.expect(registry.validate("key", "ok", &schema));

    // 移除特定校验器
    registry.remove("key", "test1");
    try std.testing.expect(registry.validate("key", "ok", &schema));

    // 移除所有校验器
    registry.remove("key", "");
    try std.testing.expect(registry.validate("key", "any_value", &schema));
}

test "ValidatorRegistry - duplicate detection" {
    const allocator = std.testing.allocator;

    var registry = ValidatorRegistry.init(allocator);
    defer registry.deinit();

    // 添加同名校验器两次
    const TestValidator = struct {
        fn validateImpl(value: []const u8, schema: *const Schema) bool {
            _ = schema;
            _ = value;
            return true;
        }
    };

    const validator = Validator.init("test", TestValidator.validateImpl);
    try registry.add("key", validator);
    try registry.add("key", validator); // 同名，应该被忽略

    var schema = try Schema.init(allocator, "key", "value");
    defer schema.deinit(allocator);

    // 只有一个校验器生效
    try std.testing.expectEqual(@as(usize, 1), registry.validators.get("key").?.items.len);
}
