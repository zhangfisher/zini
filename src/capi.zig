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

/// Opaque pointer to Ini structure
pub const zini_t = opaque {};

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

/// Get a global boolean value
export fn zini_get_bool(parser: ?*zini_t, key: [*c]const u8, out: ?*bool) zini_error_t {
    if (parser == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getBool(key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a section string value
export fn zini_get_section(parser: ?*zini_t, section: [*c]const u8, key: [*c]const u8) [*c]const u8 {
    if (parser == null or section == null or key == null) return null;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const section_slice = std.mem.span(section);
    const key_slice = std.mem.span(key);
    const value = ini_ptr.getSection(section_slice, key_slice) orelse return null;
    return value.ptr;
}

/// Get a section integer value
export fn zini_get_section_int(parser: ?*zini_t, section: [*c]const u8, key: [*c]const u8, out: ?*i64) zini_error_t {
    if (parser == null or section == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const section_slice = std.mem.span(section);
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getSectionInt(section_slice, key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a section u8 value
export fn zini_get_section_u8(parser: ?*zini_t, section: [*c]const u8, key: [*c]const u8, out: ?*u8) zini_error_t {
    if (parser == null or section == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const section_slice = std.mem.span(section);
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getSectionU8(section_slice, key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a section u16 value
export fn zini_get_section_u16(parser: ?*zini_t, section: [*c]const u8, key: [*c]const u8, out: ?*u16) zini_error_t {
    if (parser == null or section == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const section_slice = std.mem.span(section);
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getSectionU16(section_slice, key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a section u32 value
export fn zini_get_section_u32(parser: ?*zini_t, section: [*c]const u8, key: [*c]const u8, out: ?*u32) zini_error_t {
    if (parser == null or section == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const section_slice = std.mem.span(section);
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getSectionU32(section_slice, key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a section u64 value
export fn zini_get_section_u64(parser: ?*zini_t, section: [*c]const u8, key: [*c]const u8, out: ?*u64) zini_error_t {
    if (parser == null or section == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const section_slice = std.mem.span(section);
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getSectionU64(section_slice, key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Get a section boolean value
export fn zini_get_section_bool(parser: ?*zini_t, section: [*c]const u8, key: [*c]const u8, out: ?*bool) zini_error_t {
    if (parser == null or section == null or key == null or out == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const section_slice = std.mem.span(section);
    const key_slice = std.mem.span(key);
    out.?.* = ini_ptr.getSectionBool(section_slice, key_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Set a global value
export fn zini_set(parser: ?*zini_t, key: [*c]const u8, value: [*c]const u8) zini_error_t {
    if (parser == null or key == null or value == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const key_slice = std.mem.span(key);
    const value_slice = std.mem.span(value);
    ini_ptr.set(key_slice, value_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Set a section value
export fn zini_set_section(parser: ?*zini_t, section: [*c]const u8, key: [*c]const u8, value: [*c]const u8) zini_error_t {
    if (parser == null or section == null or key == null or value == null) return .INVALID_FORMAT;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const section_slice = std.mem.span(section);
    const key_slice = std.mem.span(key);
    const value_slice = std.mem.span(value);
    ini_ptr.setSection(section_slice, key_slice, value_slice) catch |err| return errorToCode(err);
    return .SUCCESS;
}

/// Check if a section exists
export fn zini_has_section(parser: ?*zini_t, section: [*c]const u8) bool {
    if (parser == null or section == null) return false;
    const ini_ptr: *Ini = @ptrCast(@alignCast(parser.?));
    const section_slice = std.mem.span(section);
    return ini_ptr.hasSection(section_slice);
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
