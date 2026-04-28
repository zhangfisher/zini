//! C API for zig-ini library (Module-based root)
//!
//! This file serves as the root source file for C library builds.
//! It imports the main module to avoid namespace conflicts with std.fs.

const std = @import("std");
const Ini = @import("root.zig").Ini;

/// Re-export all C API functions from capi.zig
pub usingnamespace @import("capi.zig");
