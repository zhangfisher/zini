//! C API for zig-ini library
//!
//! This module provides a C-compatible API for the zig-ini library.
//! API mirrors the Zig ini.zig API with 4 basic getters: getString, getNumber, getBoolean, getFloat

const std = @import("std");

// 线本地存储用于 choices 指针数组转换（优化：从 256 减少到 32）
threadlocal var choices_buffer: [32][*c]const u8 = undefined;
threadlocal var choices_buffer_len: usize = 0;

// 线本地存储用于 validators 指针数组转换（优化：从 256 减少到 32）
threadlocal var validators_buffer: [32][*c]const u8 = undefined;
threadlocal var validators_buffer_len: usize = 0;

// 线本地存储用于字符串返回（优化：使用线程本地存储代替全局）
threadlocal var string_buffer: [512:0]u8 = undefined;

// C 验证器注册表（优化：移除锁机制，减少代码大小）
var c_validators: std.StringHashMap(*const fn ([*c]const u8, ?*const void) bool) = undefined;
var c_validators_initialized = false;

fn getOrCreateCValidatorRegistry() *std.StringHashMap(*const fn ([*c]const u8, ?*const void) bool) {
    if (!c_validators_initialized) {
        c_validators = std.StringHashMap(*const fn ([*c]const u8, ?*const void) bool).init(std.heap.c_allocator);
        c_validators_initialized = true;
    }
    return &c_validators;
}

// 如果模块系统可用，使用导入的模块，否则直接导入
const Ini = if (@hasDecl(@import("root"), "zini"))
    @import("root").zini.Ini
else
    @import("ini.zig").Ini;

const DataType = if (@hasDecl(@import("root"), "zini"))
    @import("root").zini.DataType
else
    @import("types.zig").DataType;

const IniOptions = if (@hasDecl(@import("root"), "zini"))
    @import("root").zini.IniOptions
else
    @import("ini.zig").IniOptions;

// 导入验证器相关类型
const Item = if (@hasDecl(@import("root"), "zini"))
    @import("root").zini.Item
else
    @import("ini.zig").Item;

// 导入 Validator 类型
const Validator = if (@hasDecl(@import("root"), "zini"))
    @import("root").zini.Validator
else
    @import("validate.zig").Validator;

// 导入字符串操作模块
const string_mod = if (@hasDecl(@import("root"), "zini"))
    @import("root").zini.string_mod
else
    @import("string.zig");

/// Validator function pointer type for C API
/// Parameters:
///   - value: value to validate
///   - item: item containing the value (opaque pointer, cast to Item* if needed)
/// Returns: true if validation passes, false otherwise
pub const zini_validator_fn = ?*const anyopaque;

/// Opaque pointer to Ini structure
pub const zini_t = opaque {};

/// Item structure for C API
pub const zini_item_t = extern struct {
    key: [*c]const u8,
    value: [*c]const u8,
    datatype: DataType,
    flags: u32,
    title: [*c]const u8,
    description: [*c]const u8,
    default: [*c]const u8,
    choices_count: usize,
    choices: [*c]const [*c]const u8,
    validators_count: usize,
    validators: [*c]const [*c]const u8,
};

/// IniOptions for C API
pub const zini_options_t = extern struct {
    flags: u32,
};

/// Option flags
pub const ZINI_LOAD_DESCRIPTION: u32 = 1;

/// Error codes for C API
pub const zini_error_t = enum(c_int) {
    SUCCESS = 0,
    INVALID_FORMAT = -1,
    EMPTY_SECTION_NAME = -2,
    DUPLICATE_SECTION = -3,
    UNCLOSED_QUOTE = -4,
    INVALID_ESCAPE = -5,
    FILE_NOT_FOUND = -6,
    WRITE_ERROR = -7,
    OUT_OF_MEMORY = -8,
    TYPE_CONVERSION_ERROR = -9,
    OVERFLOW = -10,
    INVALID_CHARACTER = -11,
    KEY_NOT_FOUND = -12,
};

/// Convert library error to C error code
fn errorToCode(err: anyerror) zini_error_t {
    return switch (err) {
        error.InvalidFormat => .INVALID_FORMAT,
        error.EmptySectionName => .EMPTY_SECTION_NAME,
        error.DuplicateSection => .DUPLICATE_SECTION,
        error.UnclosedQuote => .UNCLOSED_QUOTE,
        error.InvalidEscape => .INVALID_ESCAPE,
        error.FileNotFound => .FILE_NOT_FOUND,
        error.WriteError => .WRITE_ERROR,
        error.OutOfMemory => .OUT_OF_MEMORY,
        error.TypeConversionError => .TYPE_CONVERSION_ERROR,
        error.Overflow => .OVERFLOW,
        error.InvalidCharacter => .INVALID_CHARACTER,
        error.KeyNotFound => .KEY_NOT_FOUND,
        else => .INVALID_FORMAT,
    };
}

/// Create a new Ini parser
export fn zini_new() ?*zini_t {
    const allocator = std.heap.c_allocator;
    const ini_ptr = allocator.create(Ini) catch return null;
    ini_ptr.* = Ini.init(allocator);
    return @ptrCast(ini_ptr);
}

/// Create a new Ini parser with options
export fn zini_init_with_options(options: zini_options_t) ?*zini_t {
    const allocator = std.heap.c_allocator;
    const ini_ptr = allocator.create(Ini) catch return null;

    // 将 C 选项转换为 Zig 选项
    const zig_options = IniOptions{ .flags = options.flags };
    ini_ptr.* = Ini.initWithOptions(allocator, zig_options);
    return @ptrCast(ini_ptr);
}

/// Create default options (no description loading)
export fn zini_options_default() zini_options_t {
    return .{ .flags = 0 };
}

/// Create options with description loading enabled
export fn zini_options_with_description() zini_options_t {
    return .{ .flags = ZINI_LOAD_DESCRIPTION };
}

/// Destroy an Ini parser and free all resources
export fn zini_free(parser: ?*zini_t) void {
    if (parser) |p| {
        const ini_ptr: *Ini = @ptrCast(@alignCast(p));
        ini_ptr.deinit();
        const allocator = std.heap.c_allocator;
        allocator.destroy(ini_ptr);
    }
}

/// Load INI from file
export fn zini_load_file(parser: ?*zini_t, path: [*c]const u8) zini_error_t {
    if (parser == null or path == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const path_slice = std.mem.span(path);

    // 直接调用 ini.zig 中的 load 方法
    ini_ptr.load(path_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Load INI from string
export fn zini_load_string(parser: ?*zini_t, content: [*c]const u8, len: usize) zini_error_t {
    if (parser == null or content == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const content_slice = content[0..len];

    // 直接调用 ini.zig 中的 loadFromString 方法
    ini_ptr.loadFromString(content_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Save INI to file
export fn zini_save_file(parser: ?*zini_t, path: [*c]const u8) zini_error_t {
    if (parser == null or path == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const path_slice = std.mem.span(path);

    // 直接调用 ini.zig 中的 save 方法
    ini_ptr.save(path_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global value (corresponds to ini.get)
/// Returns null if key not found
export fn zini_get(parser: ?*zini_t, key: [*c]const u8) [*c]const u8 {
    // 直接调用 zini_get_string 保持 C API 内部一致性
    return zini_get_string(parser, key);
}

/// Get a global string value (corresponds to ini.getString)
/// Returns null if key not found
/// Note: The returned string is valid until the next operation on the parser
export fn zini_get_string(parser: ?*zini_t, key: [*c]const u8) [*c]const u8 {
    if (parser == null or key == null) return null;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    const value = ini_ptr.getString(key_slice) catch return null;

    // 确保字符串正确 null 终止（将字符串复制到线程本地缓冲区）
    const len = @min(value.len, string_buffer.len - 1);
    @memcpy(string_buffer[0..len], value[0..len]);
    string_buffer[len] = 0;

    return @ptrCast(&string_buffer);
}

/// Get a global number value (corresponds to ini.getNumber - returns i64)
export fn zini_get_number(parser: ?*zini_t, key: [*c]const u8, out: ?*i64) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getNumber(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global float value (corresponds to ini.getFloat - returns f64)
export fn zini_get_float(parser: ?*zini_t, key: [*c]const u8, out: ?*f64) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getFloat(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global boolean value (corresponds to ini.getBoolean)
export fn zini_get_boolean(parser: ?*zini_t, key: [*c]const u8, out: ?*bool) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getBoolean(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Set a value (corresponds to ini.set, supports <section>.<key> syntax)
export fn zini_set(parser: ?*zini_t, key: [*c]const u8, value: [*c]const u8) zini_error_t {
    if (parser == null or key == null or value == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    const value_slice = std.mem.span(value);
    ini_ptr.set(key_slice, value_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Check if a key or section exists (corresponds to ini.hasItem, supports <section>.<key> syntax)
export fn zini_has_item(parser: ?*zini_t, key: [*c]const u8) bool {
    if (parser == null or key == null) return false;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    return ini_ptr.hasItem(key_slice);
}

/// Remove a key or section (corresponds to ini.removeItem, supports <section>.<key> syntax)
/// Returns: true if removed, false if key/section not found
export fn zini_remove_item(parser: ?*zini_t, key: [*c]const u8) bool {
    if (parser == null or key == null) return false;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    return ini_ptr.removeItem(key_slice);
}

/// Get error message for error code
export fn zini_error_string(err: zini_error_t) [*c]const u8 {
    return switch (err) {
        .SUCCESS => "Success",
        .INVALID_FORMAT => "Invalid format",
        .EMPTY_SECTION_NAME => "Empty section name",
        .DUPLICATE_SECTION => "Duplicate section",
        .UNCLOSED_QUOTE => "Unclosed quote",
        .INVALID_ESCAPE => "Invalid escape",
        .FILE_NOT_FOUND => "File not found",
        .WRITE_ERROR => "Write error",
        .OUT_OF_MEMORY => "Out of memory",
        .TYPE_CONVERSION_ERROR => "Type conversion error",
        .OVERFLOW => "Overflow",
        .INVALID_CHARACTER => "Invalid character",
        .KEY_NOT_FOUND => "Key not found",
    };
}

/// Get Item for a key (corresponds to ini.getItem, supports <section>.<key> syntax)
/// Returns: Item structure containing key, value, datatype, flags, title, description, default, choices
/// Note: The returned Item and its pointers are valid until the next operation on the parser
/// Warning: The choices pointer array is only valid until the next zini_get_item call
export fn zini_get_item(parser: ?*zini_t, key: [*c]const u8, item: ?*zini_item_t) zini_error_t {
    if (parser == null or key == null or item == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);

    const ini_item = ini_ptr.getItem(key_slice) orelse return .KEY_NOT_FOUND;

    item.?.*.key = if (ini_item.key.len > 0) ini_item.key.ptr else "";
    item.?.*.value = if (ini_item.value.len > 0) ini_item.value.ptr else "";
    item.?.*.datatype = ini_item.datatype;
    item.?.*.flags = @intFromEnum(ini_item.flags);
    item.?.*.title = if (ini_item.title) |title| title.ptr else null;
    item.?.*.description = if (ini_item.description) |desc| desc.ptr else null;
    item.?.*.default = if (ini_item.default) |def| def.ptr else null;

    // 处理 choices 数组
    if (ini_item.choices) |choices| {
        item.?.*.choices_count = choices.len;
        if (choices.len > 0) {
            // 将 Zig 字符串数组转换为 C 字符串指针数组
            // 限制最大数量以防止缓冲区溢出
            const copy_len = @min(choices.len, choices_buffer.len);
            choices_buffer_len = copy_len;
            for (choices[0..copy_len], 0..) |choice, i| {
                choices_buffer[i] = if (choice.len > 0) choice.ptr else "";
            }
            item.?.*.choices = &choices_buffer;
        } else {
            item.?.*.choices = null;
        }
    } else {
        item.?.*.choices_count = 0;
        item.?.*.choices = null;
    }

    // 处理 validators 数组
    if (ini_item.validators) |validators| {
        item.?.*.validators_count = validators.len;
        if (validators.len > 0) {
            // 将 Zig 字符串数组转换为 C 字符串指针数组
            const copy_len = @min(validators.len, validators_buffer.len);
            validators_buffer_len = copy_len;
            for (validators[0..copy_len], 0..) |validator, i| {
                validators_buffer[i] = if (validator.len > 0) validator.ptr else "";
            }
            item.?.*.validators = &validators_buffer;
        } else {
            item.?.*.validators = null;
        }
    } else {
        item.?.*.validators_count = 0;
        item.?.*.validators = null;
    }

    return .SUCCESS;
}

/// Add a validator to the registry
/// Parameters:
///   - parser: INI parser instance
///   - name: validator name (use "*" for global validators)
///   - validator: validator function pointer
/// Returns: error code
export fn zini_add_validator(parser: ?*zini_t, name: [*c]const u8, validator: zini_validator_fn) zini_error_t {
    if (parser == null or name == null or validator == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const name_slice = std.mem.span(name);

    // 将 C 验证器存储到注册表中
    const registry = getOrCreateCValidatorRegistry();
    const c_validator = @as(*const fn ([*c]const u8, ?*const void) bool, @ptrCast(@alignCast(validator)));

    // 复制验证器名称
    const name_copy = std.heap.c_allocator.dupe(u8, name_slice) catch return .OUT_OF_MEMORY;
    registry.put(name_copy, c_validator) catch {
        std.heap.c_allocator.free(name_copy);
        return .OUT_OF_MEMORY;
    };

    // 创建通用的 C 验证器包装器
    const c_validator_wrapper = struct {
        fn wrapper(value: []const u8, item: *const Item) bool {
            // 通过 item 的 validators 字段找到对应的 C 验证器
            if (item.validators) |validator_names| {
                if (validator_names.len > 0) {
                    const validator_name = validator_names[0]; // 使用第一个验证器名称
                    const reg = getOrCreateCValidatorRegistry();
                    if (reg.get(validator_name)) |cv| {
                        // 使用C堆分配内存来创建 null 终止字符串
                        const allocator = std.heap.c_allocator;
                        const len = @min(value.len, 1024 - 1);

                        // 分配内存
                        const c_value = allocator.allocSentinel(u8, len, 0) catch return false;

                        // 复制字符串内容
                        @memcpy(c_value[0..len], value[0..len]);

                        // 传递指针给C函数
                        const result = cv(@ptrCast(c_value.ptr), null);

                        // 立即释放内存
                        allocator.free(c_value[0..len]);

                        return result;
                    }
                }
            }

            return false;
        }
    }.wrapper;

    ini_ptr.validators.add(name_slice, c_validator_wrapper) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Remove a validator from the registry
/// Parameters:
///   - parser: INI parser instance
///   - name: validator name to remove (use "*" to reset global validators)
/// Returns: error code
export fn zini_remove_validator(parser: ?*zini_t, name: [*c]const u8) zini_error_t {
    if (parser == null or name == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const name_slice = std.mem.span(name);

    ini_ptr.validators.remove(name_slice);
    return .SUCCESS;
}

/// Set validators for an item
/// Parameters:
///   - parser: INI parser instance
///   - key: item key (supports <section>.<key> syntax)
///   - validator_names: array of validator names
///   - count: number of validator names
/// Returns: error code
export fn zini_set_item_validators(parser: ?*zini_t, key: [*c]const u8, validator_names: [*c]const [*c]const u8, count: usize) zini_error_t {
    if (parser == null or key == null or validator_names == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);

    const allocator = std.heap.c_allocator;

    // 创建 validators 数组
    const validators_array = allocator.alloc([]const u8, count) catch return .OUT_OF_MEMORY;
    errdefer {
        for (validators_array) |v| allocator.free(v);
        allocator.free(validators_array);
    }

    for (validators_array, 0..) |_, i| {
        const c_name = validator_names[i];
        if (c_name == null) continue;
        const name_slice = std.mem.span(c_name);
        validators_array[i] = allocator.dupe(u8, name_slice) catch {
            // 清理已分配的内存
            for (validators_array[0..i]) |v| allocator.free(v);
            allocator.free(validators_array);
            return .OUT_OF_MEMORY;
        };
    }

    // 尝试从全局 items 中获取并设置
    if (ini_ptr.items.getPtr(key_slice)) |item| {
        // 释放旧的 validators
        if (item.validators) |old_validators| {
            for (old_validators) |v| allocator.free(v);
            allocator.free(old_validators);
        }
        item.validators = validators_array;
        return .SUCCESS;
    }

    // 尝试从 sections 中获取
    if (string_mod.indexOf(key_slice, ".") != null) {
        const dot_index = string_mod.indexOf(key_slice, ".").?;
        const section_name = key_slice[0..dot_index];
        const item_key = key_slice[dot_index + 1 ..];

        if (ini_ptr.sections.getPtr(section_name)) |section| {
            if (section.items.getPtr(item_key)) |item| {
                // 释放旧的 validators
                if (item.validators) |old_validators| {
                    for (old_validators) |v| allocator.free(v);
                    allocator.free(old_validators);
                }
                item.validators = validators_array;
                return .SUCCESS;
            }
        }
    }

    // 清理分配的内存
    for (validators_array) |v| allocator.free(v);
    allocator.free(validators_array);

    return .KEY_NOT_FOUND;
}
