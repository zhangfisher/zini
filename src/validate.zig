//! INI 配置校验框架
//!
//! 提供灵活的校验机制，支持动态添加/移除校验器
//!
//! 核心组件：
//! - Validator：校验器函数指针类型
//! - ValidatorRegistry：校验器注册表
//! - choiceValidator：内置的 choices 校验器

const std = @import("std");
const Allocator = std.mem.Allocator;

// 导入字符串操作模块
const string_mod = @import("string.zig");

// 前向声明，避免循环依赖
const Item = @import("ini.zig").Item;

/// 校验器函数指针类型
/// 参数：
///   - value: 要校验的值
///   - item: 包含该值的配置项
/// 返回：true 表示通过，false 表示失败
pub const Validator = *const fn (value: []const u8, item: *const Item) bool;

/// 校验器注册表
pub const ValidatorRegistry = struct {
    allocator: Allocator,
    /// 按名称索引的验证器函数（延迟实例化）
    validators: ?std.StringHashMap(Validator) = null,
    /// 全局验证器列表（对所有 Item 都生效，初始化时创建）
    global_validators: std.ArrayList(Validator),

    const Self = @This();

    /// 创建注册表（自动添加内置的 choiceValidator）
    pub fn init(allocator: Allocator) Self {
        var registry = Self{
            .allocator = allocator,
            .validators = null, // 延迟实例化命名验证器
            .global_validators = std.ArrayList(Validator).initCapacity(allocator, 1) catch unreachable, // 立即创建，容量为1
        };

        // 立即添加内置的 choice 验证器
        registry.global_validators.appendAssumeCapacity(choiceValidator);

        return registry;
    }

    /// 释放注册表
    pub fn deinit(self: *Self) void {
        // 清理命名验证器（如果存在）
        if (self.validators) |*validators_map| {
            var iter = validators_map.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            validators_map.deinit();
        }

        // 清理全局验证器
        self.global_validators.deinit(self.allocator);
    }

    /// 添加校验器
    /// 参数：
    ///   - name: 验证器名称，"*" 表示全局验证器
    ///   - validator: 验证器函数
    pub fn add(self: *Self, name: []const u8, validator: Validator) !void {
        if (std.mem.eql(u8, name, "*")) {
            // 全局验证器 - 直接添加到已存在的 global_validators
            try self.global_validators.append(self.allocator, validator);
        } else {
            // 命名验证器 - 延迟实例化 HashMap
            if (self.validators == null) {
                self.validators = std.StringHashMap(Validator).init(self.allocator);
            }
            const name_copy = try self.allocator.dupe(u8, name);
            try self.validators.?.put(name_copy, validator);
        }
    }

    /// 移除校验器
    /// 参数：
    ///   - name: 验证器名称，"*" 表示重置全局验证器（保留 choice）
    pub fn remove(self: *Self, name: []const u8) void {
        if (std.mem.eql(u8, name, "*")) {
            // 清空全局验证器（但保留 choice 验证器）
            self.global_validators.clearRetainingCapacity();
            self.global_validators.append(self.allocator, choiceValidator) catch unreachable;
        } else {
            // 移除命名验证器
            if (self.validators) |*validators_map| {
                if (validators_map.fetchRemove(name)) |kv| {
                    self.allocator.free(kv.key);
                }
            }
        }
    }

    /// 校验指定 Item 的值
    /// 参数：
    ///   - item: 要校验的配置项
    /// 返回：true 表示通过，false 表示失败
    pub fn validate(self: *const Self, item: *const Item) bool {
        // 1. 先执行全局验证器（总是存在）
        for (self.global_validators.items) |validator| {
            if (!validator(item.value, item)) {
                return false;
            }
        }

        // 2. 再执行 Item 指定的验证器（如果存在）
        if (item.validators) |validator_names| {
            if (self.validators) |validators_map| {
                for (validator_names) |name| {
                    if (validators_map.get(name)) |validator| {
                        if (!validator(item.value, item)) {
                            return false;
                        }
                    }
                }
            }
        }

        return true;
    }
};

/// choiceValidator - 校验值是否在允许的 choices 中
/// 这是一个普通的验证函数，可以直接作为 Validator 使用
fn choiceValidator(value: []const u8, item: *const Item) bool {
    if (item.choices) |choices| {
        const trimmed = string_mod.trim(value);
        return string_mod.find(choices, trimmed) >= 0;
    }
    return true; // 没有 choices 限制
}

// 测试
test "ValidatorRegistry - basic add and validate" {
    const allocator = std.testing.allocator;

    var registry = ValidatorRegistry.init(allocator);
    defer registry.deinit();

    // 创建测试校验器
    const TestValidator = struct {
        fn validateImpl(value: []const u8, item: *const Item) bool {
            _ = item;
            return std.mem.eql(u8, value, "ok");
        }
    };

    try registry.add("test", TestValidator.validateImpl);

    var item = try Item.init(allocator, "test_key", "ok"); // 值改为 "ok" 以通过验证
    defer item.deinit(allocator);

    // 设置验证器
    const validator_names = try allocator.alloc([]const u8, 1);
    validator_names[0] = try allocator.dupe(u8, "test");
    item.validators = validator_names;

    // 校验测试
    try std.testing.expect(registry.validate(&item));

    // 注意：不手动清理 validator_names，让 item.deinit() 处理
    // 避免双重释放
}

test "ValidatorRegistry - global validator" {
    const allocator = std.testing.allocator;

    var registry = ValidatorRegistry.init(allocator);
    defer registry.deinit();

    // 添加全局校验器
    const GlobalValidator = struct {
        fn validateImpl(value: []const u8, item: *const Item) bool {
            _ = item;
            return std.mem.eql(u8, value, "global_ok");
        }
    };

    try registry.add("*", GlobalValidator.validateImpl);

    var item = try Item.init(allocator, "any_key", "global_ok");
    defer item.deinit(allocator);

    // 全局校验器应该生效
    try std.testing.expect(registry.validate(&item));
}

test "ValidatorRegistry - remove" {
    const allocator = std.testing.allocator;

    var registry = ValidatorRegistry.init(allocator);
    defer registry.deinit();

    // 添加校验器
    const TestValidator = struct {
        fn validateImpl(value: []const u8, item: *const Item) bool {
            _ = item;
            _ = value;
            return true;
        }
    };

    try registry.add("test1", TestValidator.validateImpl);
    try registry.add("test2", TestValidator.validateImpl);

    var item = try Item.init(allocator, "key", "value");
    defer item.deinit(allocator);

    // 设置验证器
    const validator_names = try allocator.alloc([]const u8, 2);
    validator_names[0] = try allocator.dupe(u8, "test1");
    validator_names[1] = try allocator.dupe(u8, "test2");
    item.validators = validator_names;

    // 初始状态：两个校验器都生效
    try std.testing.expect(registry.validate(&item));

    // 移除特定校验器
    registry.remove("test1");
    try std.testing.expect(registry.validate(&item));

    // 移除所有全局校验器（保留 choice）
    registry.remove("*");
    try std.testing.expect(registry.validate(&item));

    // 注意：不手动清理 validator_names，让 item.deinit() 处理
    // 避免双重释放
}

test "choiceValidator - with choices" {
    const allocator = std.testing.allocator;

    var item = try Item.init(allocator, "test_key", "option1");
    defer item.deinit(allocator);

    // 设置 choices
    const choices = [_][]const u8{ "option1", "option2", "option3" };
    item.choices = try allocator.alloc([]const u8, choices.len);
    for (choices, 0..) |choice, i| {
        item.choices.?[i] = try allocator.dupe(u8, choice);
    }

    // choiceValidator 应该通过
    try std.testing.expect(choiceValidator("option1", &item));
    try std.testing.expect(choiceValidator("option2", &item));

    // 注意：不手动清理 item.choices，让 item.deinit() 处理
}

test "choiceValidator - without choices" {
    const allocator = std.testing.allocator;

    var item = try Item.init(allocator, "test_key", "any_value");
    defer item.deinit(allocator);

    // 没有 choices 限制，应该总是通过
    try std.testing.expect(choiceValidator("any_value", &item));
}

test "ValidatorRegistry - lazy instantiation" {
    const allocator = std.testing.allocator;

    var registry = ValidatorRegistry.init(allocator);
    defer registry.deinit();

    // 初始状态：validators 应该为 null（未使用命名验证器）
    try std.testing.expect(registry.validators == null);

    // 添加命名验证器后，应该实例化
    const TestValidator = struct {
        fn validateImpl(value: []const u8, item: *const Item) bool {
            _ = item;
            _ = value;
            return true;
        }
    };

    try registry.add("test", TestValidator.validateImpl);
    try std.testing.expect(registry.validators != null);

    // global_validators 应该总是存在（包含 choice 验证器）
    try std.testing.expect(registry.global_validators.items.len == 1);
}
