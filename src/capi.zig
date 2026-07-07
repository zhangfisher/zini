//! C API for zig-ini library
//!
//! This module provides a C-compatible API for the zig-ini library.

const std = @import("std");

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

/// Schema structure for C API
pub const zini_schema_t = extern struct {
    key: [*c]const u8,
    value: [*c]const u8,
    datatype: DataType,
    title: [*c]const u8,
    description: [*c]const u8,
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

/// Get a global integer value
export fn zini_get_int(parser: ?*zini_t, key: [*c]const u8, out: ?*i64) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getInt(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global u8 value
export fn zini_get_u8(parser: ?*zini_t, key: [*c]const u8, out: ?*u8) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getU8(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global u16 value
export fn zini_get_u16(parser: ?*zini_t, key: [*c]const u8, out: ?*u16) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getU16(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global u32 value
export fn zini_get_u32(parser: ?*zini_t, key: [*c]const u8, out: ?*u32) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getU32(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global u64 value
export fn zini_get_u64(parser: ?*zini_t, key: [*c]const u8, out: ?*u64) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getU64(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global i8 value
export fn zini_get_i8(parser: ?*zini_t, key: [*c]const u8, out: ?*i8) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getI8(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global i16 value
export fn zini_get_i16(parser: ?*zini_t, key: [*c]const u8, out: ?*i16) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getI16(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global i32 value
export fn zini_get_i32(parser: ?*zini_t, key: [*c]const u8, out: ?*i32) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getI32(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global i64 value
export fn zini_get_i64(parser: ?*zini_t, key: [*c]const u8, out: ?*i64) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getI64(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global f32 value
export fn zini_get_f32(parser: ?*zini_t, key: [*c]const u8, out: ?*f32) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getF32(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global f64 value
export fn zini_get_f64(parser: ?*zini_t, key: [*c]const u8, out: ?*f64) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getF64(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a global boolean value
export fn zini_get_bool(parser: ?*zini_t, key: [*c]const u8, out: ?*bool) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getBool(key_slice) catch |err| return errorToCode(err);
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

/// Check if a key exists (supports <section>.<key> syntax)
export fn zini_has(parser: ?*zini_t, key: [*c]const u8) bool {
    if (parser == null or key == null) return false;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    return ini_ptr.has(key_slice);
}

/// Remove a key (supports <section>.<key> syntax)
/// Returns: true if removed, false if key not found
export fn zini_remove(parser: ?*zini_t, key: [*c]const u8) bool {
    if (parser == null or key == null) return false;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    return ini_ptr.remove(key_slice);
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

/// Get Schema for a key (supports <section>.<key> syntax)
/// Returns: Schema structure containing key, value, datatype, title, description
/// Note: The returned Schema is valid until the next operation on the parser
export fn zini_get_schema(parser: ?*zini_t, key: [*c]const u8, schema: ?*zini_schema_t) zini_error_t {
    if (parser == null or key == null or schema == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);

    const ini_schema = ini_ptr.getSchema(key_slice) orelse return .KEY_NOT_FOUND;

    schema.?.*.key = if (ini_schema.key.len > 0) ini_schema.key.ptr else "";
    schema.?.*.value = if (ini_schema.value.len > 0) ini_schema.value.ptr else "";
    schema.?.*.datatype = ini_schema.datatype;
    schema.?.*.title = if (ini_schema.title) |title| title.ptr else null;
    schema.?.*.description = if (ini_schema.description) |desc| desc.ptr else null;

    return .SUCCESS;
}
