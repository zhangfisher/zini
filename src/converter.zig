//! Value converter system for zini library
//!
//! This module provides type converters that transform configuration values
//! between human-friendly representations and efficient internal representations.

const std = @import("std");
const DataType = @import("types.zig").DataType;

/// Error types for converter operations
pub const Error = error{
    InvalidValue,
    Overflow,
    InvalidCharacter,
};

/// Value converter structure
///
/// Converters transform values between external representation (in config files)
/// and internal representation (in memory). For example, converting between
/// human-readable log levels ("debug", "info", "warn", "error") and efficient
/// numeric representations (1, 2, 3, 4).
///
/// ## Memory Management
/// - from/to functions return static strings or string literals
/// - Caller is responsible for copying strings that need to be retained
/// - No dynamic memory allocation inside converter functions
///
/// ## Example
/// ```zig
/// const log_level_converter = Converter{
///     .from = struct {
///         fn from(input: []const u8) Error![]const u8 {
///             if (std.mem.eql(u8, input, "debug")) return "1";
///             if (std.mem.eql(u8, input, "info")) return "2";
///             if (std.mem.eql(u8, input, "warn")) return "3";
///             if (std.mem.eql(u8, input, "error")) return "4";
///             return error.InvalidValue;
///         }
///     }.from,
///     .to = struct {
///         fn to(input: []const u8) Error![]const u8 {
///             const num = try std.fmt.parseInt(u8, input, 10);
///             return switch (num) {
///                 1 => "debug",
///                 2 => "info",
///                 3 => "warn",
///                 4 => "error",
///                 else => error.InvalidValue,
///             };
///         }
///     }.to,
/// };
/// ```
pub const Converter = struct {
    /// Convert from external representation to internal representation
    /// Returns: Static string or string literal (caller must copy if needed)
    from: *const fn (input: []const u8) Error![]const u8,

    /// Convert from internal representation to external representation
    /// Returns: Static string or string literal (caller must copy if needed)
    to: *const fn (input: []const u8) Error![]const u8,
};

/// Common predefined converters
pub const common = struct {
    /// Log level converter
    /// Converts between: debug/info/warn/error and 1/2/3/4
    pub const log_level = Converter{
        .from = logLevelFrom,
        .to = logLevelTo,
    };

    /// Database engine converter
    /// Converts between: mysql/postgresql/sqlite and 1/2/3
    pub const db_engine = Converter{
        .from = dbEngineFrom,
        .to = dbEngineTo,
    };
};

/// Log level converter: debug/info/warn/error → 1/2/3/4
fn logLevelFrom(input: []const u8) Error![]const u8 {
    if (std.mem.eql(u8, input, "debug")) return "1";
    if (std.mem.eql(u8, input, "info")) return "2";
    if (std.mem.eql(u8, input, "warn")) return "3";
    if (std.mem.eql(u8, input, "error")) return "4";
    return error.InvalidValue;
}

fn logLevelTo(input: []const u8) Error![]const u8 {
    const num = try std.fmt.parseInt(u8, input, 10);
    return switch (num) {
        1 => "debug",
        2 => "info",
        3 => "warn",
        4 => "error",
        else => error.InvalidValue,
    };
}

/// Database engine converter: mysql/postgresql/sqlite → 1/2/3
fn dbEngineFrom(input: []const u8) Error![]const u8 {
    if (std.mem.eql(u8, input, "mysql")) return "1";
    if (std.mem.eql(u8, input, "postgresql")) return "2";
    if (std.mem.eql(u8, input, "sqlite")) return "3";
    return error.InvalidValue;
}

fn dbEngineTo(input: []const u8) Error![]const u8 {
    const num = try std.fmt.parseInt(u8, input, 10);
    return switch (num) {
        1 => "mysql",
        2 => "postgresql",
        3 => "sqlite",
        else => error.InvalidValue,
    };
}

// Tests
test "log level converter from" {
    const converter = common.log_level;

    try std.testing.expectEqualStrings("1", try converter.from("debug"));
    try std.testing.expectEqualStrings("2", try converter.from("info"));
    try std.testing.expectEqualStrings("3", try converter.from("warn"));
    try std.testing.expectEqualStrings("4", try converter.from("error"));

    // Test invalid value
    try std.testing.expectError(error.InvalidValue, converter.from("invalid"));
}

test "log level converter to" {
    const converter = common.log_level;

    try std.testing.expectEqualStrings("debug", try converter.to("1"));
    try std.testing.expectEqualStrings("info", try converter.to("2"));
    try std.testing.expectEqualStrings("warn", try converter.to("3"));
    try std.testing.expectEqualStrings("error", try converter.to("4"));

    // Test invalid value
    try std.testing.expectError(error.InvalidValue, converter.to("5"));
}

test "database engine converter" {
    const converter = common.db_engine;

    try std.testing.expectEqualStrings("1", try converter.from("mysql"));
    try std.testing.expectEqualStrings("2", try converter.from("postgresql"));
    try std.testing.expectEqualStrings("3", try converter.from("sqlite"));

    try std.testing.expectEqualStrings("mysql", try converter.to("1"));
    try std.testing.expectEqualStrings("postgresql", try converter.to("2"));
    try std.testing.expectEqualStrings("sqlite", try converter.to("3"));
}