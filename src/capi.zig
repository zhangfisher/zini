//! C API for zig-ini library
//!
//! This module provides a C-compatible API for the zig-ini library.

const std = @import("std");

// 线本地存储用于 choices 指针数组转换
threadlocal var choices_buffer: [256][*c]const u8 = undefined;
threadlocal var choices_buffer_len: usize = 0;

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

/// Get a global string value
/// Returns null if key not found
export fn zini_get(parser: ?*zini_t, key: [*c]const u8) [*c]const u8 {
    if (parser == null or key == null) return null;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    const value = ini_ptr.get(key_slice) orelse return null;
    return value.ptr;
}

/// Get a string value
/// Returns null if key not found
export fn zini_get_string(parser: ?*zini_t, key: [*c]const u8) [*c]const u8 {
    if (parser == null or key == null) return null;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    const value = ini_ptr.getString(key_slice) catch return null;
    return value.ptr;
}

/// Get a number value (i64)
export fn zini_get_number(parser: ?*zini_t, key: [*c]const u8, out: ?*i64) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getNumber(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a float value (f64)
export fn zini_get_float(parser: ?*zini_t, key: [*c]const u8, out: ?*f64) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getFloat(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a boolean value
export fn zini_get_boolean(parser: ?*zini_t, key: [*c]const u8, out: ?*bool) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getBoolean(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Set a value (supports <section>.<key> syntax)
export fn zini_set(parser: ?*zini_t, key: [*c]const u8, value: [*c]const u8) zini_error_t {
    if (parser == null or key == null or value == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    const value_slice = std.mem.span(value);
    ini_ptr.set(key_slice, value_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Check if a key or section exists (supports <section>.<key> syntax)
export fn zini_has_item(parser: ?*zini_t, key: [*c]const u8) bool {
    if (parser == null or key == null) return false;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    return ini_ptr.hasItem(key_slice);
}

/// Remove a key or section (supports <section>.<key> syntax)
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

/// Get Item for a key (supports <section>.<key> syntax)
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

    return .SUCCESS;
}
