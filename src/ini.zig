//! INI file format parser and serializer with type support
//!
//! Features:
//! - Load/save INI files
//! - Support for sections and global keys
//! - Comments with ; or #
//! - Automatic type inference (bool, int, float, string)
//! - Type-safe value access
//! - Simple, intuitive API

const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

// 导入类型系统
const types = @import("types.zig");
pub const DataType = types.DataType;
const TypeConverter = types.TypeConverter;

/// 位标识条目（用于位合并）
const BitFlagEntry = struct {
    key: []const u8,
    value: []const u8,
    datatype: DataType,
};

/// Error types for INI operations
pub const Error = error{
    InvalidFormat,
    EmptySectionName,
    DuplicateSection,
    UnclosedQuote,
    InvalidEscape,
    FileNotFound,
    WriteError,
    OutOfMemory,
    TypeConversionError,
    Overflow,
    InvalidCharacter,
};

/// A single key-value entry with type information
pub const Entry = struct {
    key: []const u8,
    value: []const u8,
    datatype: DataType,
    /// 是否为数组
    is_array: bool = false,
    /// 数组元素的原始字符串值（仅当 is_array=true 时有效）
    array_items: ?[][]const u8 = null,

    /// 解析数组元素
    fn parseArrayItems(allocator: Allocator, trimmed: []const u8) ![][]const u8 {
        const array_content = trimmed[1 .. trimmed.len - 1];
        var items: std.ArrayList([]const u8) = .empty;
        defer items.deinit(allocator);

        var iter = std.mem.tokenizeScalar(u8, array_content, ',');
        while (iter.next()) |item| {
            const trimmed_item = std.mem.trim(u8, item, " \t\r\n");
            if (trimmed_item.len > 0) {
                try items.append(allocator, try allocator.dupe(u8, trimmed_item));
            }
        }
        return items.toOwnedSlice(allocator);
    }

    /// Create a new entry with automatic type inference
    pub fn init(allocator: Allocator, key: []const u8, value: []const u8) Allocator.Error!Entry {
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        const trimmed = std.mem.trim(u8, value, " \t\r\n");
        const is_array = trimmed.len >= 2 and trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']';

        var entry = Entry{
            .key = key_copy,
            .value = value_copy,
            .datatype = if (is_array) .array else DataType.infer(value),
            .is_array = is_array,
        };

        if (is_array) {
            entry.array_items = try parseArrayItems(allocator, trimmed);
        }

        return entry;
    }

    /// Create a new entry with explicit type
    pub fn initWithType(allocator: Allocator, key: []const u8, value: []const u8, datatype: DataType) Allocator.Error!Entry {
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        const trimmed = std.mem.trim(u8, value, " \t\r\n");
        const is_array = trimmed.len >= 2 and trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']';

        var entry = Entry{
            .key = key_copy,
            .value = value_copy,
            .datatype = if (is_array) .array else datatype,
            .is_array = is_array,
        };

        if (is_array) {
            entry.array_items = try parseArrayItems(allocator, trimmed);
        }

        return entry;
    }

    /// Free entry resources
    pub fn deinit(self: *Entry, allocator: Allocator) void {
        allocator.free(self.key);
        allocator.free(self.value);
        if (self.array_items) |items| {
            for (items) |item| {
                allocator.free(item);
            }
            allocator.free(items);
        }
    }

    /// Get value as boolean
    pub fn asBool(self: *const Entry) !bool {
        return TypeConverter.toBool(self.value);
    }

    /// Get value as u8
    pub fn asU8(self: *const Entry) !u8 {
        return TypeConverter.toU8(self.value);
    }

    /// Get value as u16
    pub fn asU16(self: *const Entry) !u16 {
        return TypeConverter.toU16(self.value);
    }

    /// Get value as u32
    pub fn asU32(self: *const Entry) !u32 {
        return TypeConverter.toU32(self.value);
    }

    /// Get value as u64
    pub fn asU64(self: *const Entry) !u64 {
        return TypeConverter.toU64(self.value);
    }

    /// Get value as i8
    pub fn asI8(self: *const Entry) !i8 {
        return TypeConverter.toI8(self.value);
    }

    /// Get value as i16
    pub fn asI16(self: *const Entry) !i16 {
        return TypeConverter.toI16(self.value);
    }

    /// Get value as i32
    pub fn asI32(self: *const Entry) !i32 {
        return TypeConverter.toI32(self.value);
    }

    /// Get value as i64
    pub fn asI64(self: *const Entry) !i64 {
        return TypeConverter.toI64(self.value);
    }

    /// Get value as f32
    pub fn asF32(self: *const Entry) !f32 {
        return TypeConverter.toF32(self.value);
    }

    /// Get value as f64
    pub fn asF64(self: *const Entry) !f64 {
        return TypeConverter.toF64(self.value);
    }

    /// Get value as integer (generic)
    pub fn asInt(self: *const Entry) !i64 {
        return switch (self.datatype) {
            .u8 => @intCast(try self.asU8()),
            .u16 => @intCast(try self.asU16()),
            .u32 => @intCast(try self.asU32()),
            .u64 => @intCast(try self.asU64()),
            .i8 => try self.asI8(),
            .i16 => try self.asI16(),
            .i32 => @intCast(try self.asI32()),
            .i64 => try self.asI64(),
            .int => try self.asI64(),
            else => error.TypeMismatch,
        };
    }

    /// Get value as float (generic)
    pub fn asFloat(self: *const Entry) !f64 {
        return switch (self.datatype) {
            .f32 => @floatCast(try self.asF32()),
            .f64 => try self.asF64(),
            .float => try self.asF64(),
            else => error.TypeMismatch,
        };
    }

    /// Get value as string
    pub fn asString(self: *const Entry) []const u8 {
        return TypeConverter.toString(self.value);
    }

    /// Check if value matches expected type
    pub fn isType(self: *const Entry, expected: DataType) bool {
        return self.datatype == expected;
    }
};

/// A section containing multiple entries
pub const Section = struct {
    name: []const u8,
    entries: StringHashMap(Entry),

    /// Create a new section
    pub fn init(allocator: Allocator, name: []const u8) Allocator.Error!Section {
        const name_copy = try allocator.dupe(u8, name);
        return .{
            .name = name_copy,
            .entries = StringHashMap(Entry).init(allocator),
        };
    }

    /// Free section resources
    pub fn deinit(self: *Section, allocator: Allocator) void {
        var entry_iter = self.entries.iterator();
        while (entry_iter.next()) |entry| {
            // Free entry value
            allocator.free(entry.value_ptr.value);
            allocator.free(entry.value_ptr.key);
            // Free the key stored in the hash map
            allocator.free(entry.key_ptr.*);
        }
        self.entries.deinit();
        allocator.free(self.name);
    }

    /// Get a value by key
    pub fn get(self: *const Section, key: []const u8) ?[]const u8 {
        if (self.entries.get(key)) |entry| {
            return entry.value;
        }
        return null;
    }

    /// Get entry by key
    pub fn getEntry(self: *const Section, key: []const u8) ?Entry {
        return if (self.entries.get(key)) |kv| kv.value else null;
    }

    /// 辅助函数：统一处理类型转换
    fn getTypedValue(comptime T: type, entries: *const StringHashMap(Entry), key: []const u8, comptime converterFn: fn ([]const u8) anyerror!T) !T {
        if (entries.get(key)) |entry| {
            return converterFn(entry.value);
        }
        return error.KeyNotFound;
    }

    /// Get value as boolean
    pub fn getBool(self: *const Section, key: []const u8) !bool {
        return getTypedValue(bool, &self.entries, key, TypeConverter.toBool);
    }

    /// Get value as u8
    pub fn getU8(self: *const Section, key: []const u8) !u8 {
        return getTypedValue(u8, &self.entries, key, TypeConverter.toU8);
    }

    /// Get value as u16
    pub fn getU16(self: *const Section, key: []const u8) !u16 {
        return getTypedValue(u16, &self.entries, key, TypeConverter.toU16);
    }

    /// Get value as u32
    pub fn getU32(self: *const Section, key: []const u8) !u32 {
        return getTypedValue(u32, &self.entries, key, TypeConverter.toU32);
    }

    /// Get value as u64
    pub fn getU64(self: *const Section, key: []const u8) !u64 {
        return getTypedValue(u64, &self.entries, key, TypeConverter.toU64);
    }

    /// Get value as i8
    pub fn getI8(self: *const Section, key: []const u8) !i8 {
        return getTypedValue(i8, &self.entries, key, TypeConverter.toI8);
    }

    /// Get value as i16
    pub fn getI16(self: *const Section, key: []const u8) !i16 {
        return getTypedValue(i16, &self.entries, key, TypeConverter.toI16);
    }

    /// Get value as i32
    pub fn getI32(self: *const Section, key: []const u8) !i32 {
        return getTypedValue(i32, &self.entries, key, TypeConverter.toI32);
    }

    /// Get value as i64
    pub fn getI64(self: *const Section, key: []const u8) !i64 {
        return getTypedValue(i64, &self.entries, key, TypeConverter.toI64);
    }

    /// Get value as f32
    pub fn getF32(self: *const Section, key: []const u8) !f32 {
        return getTypedValue(f32, &self.entries, key, TypeConverter.toF32);
    }

    /// Get value as f64
    pub fn getF64(self: *const Section, key: []const u8) !f64 {
        return getTypedValue(f64, &self.entries, key, TypeConverter.toF64);
    }

    /// Get value as integer (generic)
    pub fn getInt(self: *const Section, key: []const u8) !i64 {
        return self.getI64(key);
    }

    /// Get value as float (generic)
    pub fn getFloat(self: *const Section, key: []const u8) !f64 {
        return self.getF64(key);
    }

    /// Set a value by key
    pub fn set(self: *Section, allocator: Allocator, key: []const u8, value: []const u8) Allocator.Error!void {
        if (self.entries.get(key)) |_| {
            // Remove old entry and add new one
            const old_entry = self.entries.fetchRemove(key).?;
            // Manually free the entry's memory
            allocator.free(old_entry.value.value);
            allocator.free(old_entry.value.key);
            allocator.free(old_entry.key);
        }

        // Add new entry
        const new_entry = try Entry.init(allocator, key, value);
        try self.entries.put(try allocator.dupe(u8, key), new_entry);
    }

    /// Remove a key
    pub fn remove(self: *Section, allocator: Allocator, key: []const u8) bool {
        if (self.entries.fetchRemove(key)) |kv| {
            // Free entry value
            allocator.free(kv.value.value);
            allocator.free(kv.value.key);
            // Free the key stored in the hash map
            allocator.free(kv.key);
            return true;
        }
        return false;
    }
};

/// Main INI structure
pub const Ini = struct {
    allocator: Allocator,
    global_entries: StringHashMap(Entry),
    sections: StringHashMap(Section),

    /// Create a new empty Ini structure
    pub fn init(allocator: Allocator) Ini {
        return .{
            .allocator = allocator,
            .global_entries = StringHashMap(Entry).init(allocator),
            .sections = StringHashMap(Section).init(allocator),
        };
    }

    /// Free all resources
    pub fn deinit(self: *Ini) void {
        // Free global entries
        var entry_iter = self.global_entries.iterator();
        while (entry_iter.next()) |entry| {
            // Free entry value
            self.allocator.free(entry.value_ptr.value);
            self.allocator.free(entry.value_ptr.key);
            // Free the key stored in the hash map
            self.allocator.free(entry.key_ptr.*);
        }
        self.global_entries.deinit();

        // Free sections
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section| {
            section.value_ptr.deinit(self.allocator);
            self.allocator.free(section.key_ptr.*);
        }
        self.sections.deinit();
    }

    /// Load INI from file
    pub fn load(self: *Ini, path: []const u8) Error!void {
        // 使用 C 标准库 API（跨平台、简单、适合库代码）
        const c_path = try self.allocator.dupeZ(u8, path);
        defer self.allocator.free(c_path);

        const c_file = std.c.fopen(c_path.ptr, "rb");
        if (c_file == null) return Error.FileNotFound;
        defer _ = std.c.fclose(c_file.?);

        const max_size = 1024 * 1024;
        var buffer: [max_size]u8 = undefined;
        var total_read: usize = 0;

        while (total_read < max_size) {
            const bytes_read = std.c.fread(buffer[total_read..].ptr, 1, max_size - total_read, c_file.?);
            if (bytes_read == 0) break;
            total_read += bytes_read;
        }

        if (total_read == 0) return Error.InvalidFormat;
        try self.loadFromString(buffer[0..total_read]);
    }

    /// Load INI from string
    pub fn loadFromString(self: *Ini, content: []const u8) Error!void {
        var parser = Parser{
            .allocator = self.allocator,
            .content = content,
            .pos = 0,
            .ini = self,
            .current_section = null,
            .current_section_name = "",
            .bit_merge_groups = StringHashMap(BitMergeGroup).init(self.allocator),
        };
        try parser.parse();
    }

    /// Save INI to file
    pub fn save(self: *const Ini, path: []const u8) Error!void {
        // 使用 C 标准库 API（跨平台、简单、适合库代码）
        const c_path = try self.allocator.dupeZ(u8, path);
        defer self.allocator.free(c_path);

        const c_file = std.c.fopen(c_path.ptr, "wb");
        if (c_file == null) return Error.WriteError;
        defer _ = std.c.fclose(c_file.?);

        const content = try self.saveToString(self.allocator);
        defer self.allocator.free(content);

        const bytes_written = std.c.fwrite(content.ptr, 1, content.len, c_file.?);
        if (bytes_written != content.len) return Error.WriteError;
    }

    /// Save INI to string
    pub fn saveToString(self: *const Ini, allocator: Allocator) Allocator.Error![]const u8 {
        const content = try self.formatContent(allocator);
        return content;
    }

    /// Format INI content to string
    fn formatContent(self: *const Ini, allocator: Allocator) Allocator.Error![]const u8 {
        // Calculate total size needed
        var total_size: usize = 0;

        // Global entries
        var entry_iter = self.global_entries.iterator();
        while (entry_iter.next()) |entry| {
            total_size += entry.key_ptr.len + 3 + entry.value_ptr.value.len + 1; // "key = value\n"
        }

        // Blank line between global and sections
        if (self.global_entries.count() > 0 and self.sections.count() > 0) {
            total_size += 1;
        }

        // Sections
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section| {
            total_size += 1 + section.value_ptr.name.len + 2; // "[name]\n"
            var entry_iter2 = section.value_ptr.entries.iterator();
            while (entry_iter2.next()) |entry| {
                total_size += entry.key_ptr.len + 3 + entry.value_ptr.value.len + 1; // "key = value\n"
            }
            total_size += 1; // blank line after section
        }

        // Allocate buffer
        var result = try allocator.alloc(u8, total_size);
        errdefer allocator.free(result);
        var pos: usize = 0;

        // Write global entries
        entry_iter = self.global_entries.iterator();
        while (entry_iter.next()) |entry| {
            @memcpy(result[pos..][0..entry.key_ptr.len], entry.key_ptr.*);
            pos += entry.key_ptr.len;
            result[pos] = ' ';
            pos += 1;
            result[pos] = '=';
            pos += 1;
            result[pos] = ' ';
            pos += 1;
            @memcpy(result[pos..][0..entry.value_ptr.value.len], entry.value_ptr.value);
            pos += entry.value_ptr.value.len;
            result[pos] = '\n';
            pos += 1;
        }

        // Blank line
        if (self.global_entries.count() > 0 and self.sections.count() > 0) {
            result[pos] = '\n';
            pos += 1;
        }

        // Write sections
        section_iter = self.sections.iterator();
        while (section_iter.next()) |section| {
            result[pos] = '[';
            pos += 1;
            @memcpy(result[pos..][0..section.value_ptr.name.len], section.value_ptr.name);
            pos += section.value_ptr.name.len;
            result[pos] = ']';
            pos += 1;
            result[pos] = '\n';
            pos += 1;

            var entry_iter2 = section.value_ptr.entries.iterator();
            while (entry_iter2.next()) |entry| {
                @memcpy(result[pos..][0..entry.key_ptr.len], entry.key_ptr.*);
                pos += entry.key_ptr.len;
                result[pos] = ' ';
                pos += 1;
                result[pos] = '=';
                pos += 1;
                result[pos] = ' ';
                pos += 1;
                @memcpy(result[pos..][0..entry.value_ptr.value.len], entry.value_ptr.value);
                pos += entry.value_ptr.value.len;
                result[pos] = '\n';
                pos += 1;
            }

            result[pos] = '\n';
            pos += 1;
        }

        return result;
    }

    /// Write INI content to a writer
    fn writeTo(self: *const Ini, writer: anytype) Error!void {
        // Write global entries first
        var entry_iter = self.global_entries.iterator();
        while (entry_iter.next()) |entry| {
            try writer.print("{s} = {s}\n", .{ entry.key_ptr.*, entry.value_ptr.value });
        }

        // Write sections
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section| {
            try writer.print("[{s}]\n", .{section.value_ptr.name});

            var entry_iter2 = section.value_ptr.entries.iterator();
            while (entry_iter2.next()) |entry| {
                try writer.print("{s} = {s}\n", .{ entry.key_ptr.*, entry.value_ptr.value });
            }

            try writer.writeByte('\n');
        }
    }

    /// Get a global value
    pub fn get(self: *const Ini, key: []const u8) ?[]const u8 {
        if (self.global_entries.get(key)) |entry| {
            return entry.value;
        }
        return null;
    }

    /// Get global entry
    pub fn getEntry(self: *const Ini, key: []const u8) ?Entry {
        return if (self.global_entries.get(key)) |kv| kv.value else null;
    }

    /// 辅助函数：统一处理全局值的类型转换
    fn getGlobalTypedValue(comptime T: type, ini: *const Ini, key: []const u8, comptime converterFn: fn ([]const u8) anyerror!T) !T {
        if (ini.global_entries.get(key)) |entry| {
            return converterFn(entry.value);
        }
        return error.KeyNotFound;
    }

    /// Get global value as boolean
    pub fn getBool(self: *const Ini, key: []const u8) !bool {
        return getGlobalTypedValue(bool, self, key, TypeConverter.toBool);
    }

    /// Get global value as u8
    pub fn getU8(self: *const Ini, key: []const u8) !u8 {
        return getGlobalTypedValue(u8, self, key, TypeConverter.toU8);
    }

    /// Get global value as u16
    pub fn getU16(self: *const Ini, key: []const u8) !u16 {
        return getGlobalTypedValue(u16, self, key, TypeConverter.toU16);
    }

    /// Get global value as u32
    pub fn getU32(self: *const Ini, key: []const u8) !u32 {
        return getGlobalTypedValue(u32, self, key, TypeConverter.toU32);
    }

    /// Get global value as u64
    pub fn getU64(self: *const Ini, key: []const u8) !u64 {
        return getGlobalTypedValue(u64, self, key, TypeConverter.toU64);
    }

    /// Get global value as i8
    pub fn getI8(self: *const Ini, key: []const u8) !i8 {
        return getGlobalTypedValue(i8, self, key, TypeConverter.toI8);
    }

    /// Get global value as i16
    pub fn getI16(self: *const Ini, key: []const u8) !i16 {
        return getGlobalTypedValue(i16, self, key, TypeConverter.toI16);
    }

    /// Get global value as i32
    pub fn getI32(self: *const Ini, key: []const u8) !i32 {
        return getGlobalTypedValue(i32, self, key, TypeConverter.toI32);
    }

    /// Get global value as i64
    pub fn getI64(self: *const Ini, key: []const u8) !i64 {
        return getGlobalTypedValue(i64, self, key, TypeConverter.toI64);
    }

    /// Get global value as f32
    pub fn getF32(self: *const Ini, key: []const u8) !f32 {
        return getGlobalTypedValue(f32, self, key, TypeConverter.toF32);
    }

    /// Get global value as f64
    pub fn getF64(self: *const Ini, key: []const u8) !f64 {
        return getGlobalTypedValue(f64, self, key, TypeConverter.toF64);
    }

    /// Get global value as integer (generic)
    pub fn getInt(self: *const Ini, key: []const u8) !i64 {
        return self.getI64(key);
    }

    /// Get global value as float (generic)
    pub fn getFloat(self: *const Ini, key: []const u8) !f64 {
        return self.getF64(key);
    }

    /// Get a value from a section
    pub fn getSection(self: *const Ini, section_name: []const u8, key: []const u8) ?[]const u8 {
        if (self.sections.get(section_name)) |section| {
            return section.get(key);
        }
        return null;
    }

    /// Get entry from a section
    pub fn getSectionEntry(self: *const Ini, section_name: []const u8, key: []const u8) ?Entry {
        if (self.sections.get(section_name)) |section_kv| {
            if (section_kv.value.entries.get(key)) |entry_kv| {
                return entry_kv.value;
            }
        }
        return null;
    }

    /// 辅助函数：统一处理 section 值的类型转换
    fn getSectionTypedValue(comptime T: type, ini: *const Ini, section_name: []const u8, key: []const u8, comptime converterFn: fn ([]const u8) anyerror!T) !T {
        if (ini.getSection(section_name, key)) |value_str| {
            return converterFn(value_str);
        }
        return error.KeyNotFound;
    }

    /// Get section value as boolean
    pub fn getSectionBool(self: *const Ini, section_name: []const u8, key: []const u8) !bool {
        return getSectionTypedValue(bool, self, section_name, key, TypeConverter.toBool);
    }

    /// Get section value as u8
    pub fn getSectionU8(self: *const Ini, section_name: []const u8, key: []const u8) !u8 {
        return getSectionTypedValue(u8, self, section_name, key, TypeConverter.toU8);
    }

    /// Get section value as u16
    pub fn getSectionU16(self: *const Ini, section_name: []const u8, key: []const u8) !u16 {
        return getSectionTypedValue(u16, self, section_name, key, TypeConverter.toU16);
    }

    /// Get section value as u32
    pub fn getSectionU32(self: *const Ini, section_name: []const u8, key: []const u8) !u32 {
        return getSectionTypedValue(u32, self, section_name, key, TypeConverter.toU32);
    }

    /// Get section value as u64
    pub fn getSectionU64(self: *const Ini, section_name: []const u8, key: []const u8) !u64 {
        return getSectionTypedValue(u64, self, section_name, key, TypeConverter.toU64);
    }

    /// Get section value as i8
    pub fn getSectionI8(self: *const Ini, section_name: []const u8, key: []const u8) !i8 {
        return getSectionTypedValue(i8, self, section_name, key, TypeConverter.toI8);
    }

    /// Get section value as i16
    pub fn getSectionI16(self: *const Ini, section_name: []const u8, key: []const u8) !i16 {
        return getSectionTypedValue(i16, self, section_name, key, TypeConverter.toI16);
    }

    /// Get section value as i32
    pub fn getSectionI32(self: *const Ini, section_name: []const u8, key: []const u8) !i32 {
        return getSectionTypedValue(i32, self, section_name, key, TypeConverter.toI32);
    }

    /// Get section value as i64
    pub fn getSectionI64(self: *const Ini, section_name: []const u8, key: []const u8) !i64 {
        return getSectionTypedValue(i64, self, section_name, key, TypeConverter.toI64);
    }

    /// Get section value as f32
    pub fn getSectionF32(self: *const Ini, section_name: []const u8, key: []const u8) !f32 {
        return getSectionTypedValue(f32, self, section_name, key, TypeConverter.toF32);
    }

    /// Get section value as f64
    pub fn getSectionF64(self: *const Ini, section_name: []const u8, key: []const u8) !f64 {
        return getSectionTypedValue(f64, self, section_name, key, TypeConverter.toF64);
    }

    /// Get section value as integer (generic)
    pub fn getSectionInt(self: *const Ini, section_name: []const u8, key: []const u8) !i64 {
        return self.getSectionI64(section_name, key);
    }

    /// Get section value as float (generic)
    pub fn getSectionFloat(self: *const Ini, section_name: []const u8, key: []const u8) !f64 {
        return self.getSectionF64(section_name, key);
    }

    /// Get global array value
    /// 返回数组的原始字符串切片，调用者需要转换为具体类型
    pub fn getArray(self: *const Ini, key: []const u8) ?[][]const u8 {
        if (self.global_entries.getPtr(key)) |entry| {
            if (entry.is_array) {
                return entry.array_items;
            }
        }
        return null;
    }

    /// Get section array value
    /// 返回数组的原始字符串切片，调用者需要转换为具体类型
    pub fn getSectionArray(self: *const Ini, section_name: []const u8, key: []const u8) ?[][]const u8 {
        if (self.sections.get(section_name)) |section| {
            if (section.entries.getPtr(key)) |entry| {
                if (entry.is_array) {
                    return entry.array_items;
                }
            }
        }
        return null;
    }

    /// Set a global value
    pub fn set(self: *Ini, key: []const u8, value: []const u8) Allocator.Error!void {
        if (self.global_entries.get(key)) |_| {
            // Remove old entry and add new one
            const old_entry = self.global_entries.fetchRemove(key).?;
            // Manually free the entry's memory
            self.allocator.free(old_entry.value.value);
            self.allocator.free(old_entry.value.key);
            self.allocator.free(old_entry.key);
        }

        // Add new entry
        const new_entry = try Entry.init(self.allocator, key, value);
        try self.global_entries.put(try self.allocator.dupe(u8, key), new_entry);
    }

    /// Set a value in a section
    pub fn setSection(self: *Ini, section_name: []const u8, key: []const u8, value: []const u8) Allocator.Error!void {
        const section = try self.getOrCreateSection(section_name);
        try section.set(self.allocator, key, value);
    }

    /// Get or create a section
    pub fn getOrCreateSection(self: *Ini, section_name: []const u8) Allocator.Error!*Section {
        if (self.sections.getPtr(section_name)) |section| {
            return section;
        }
        const new_section = try Section.init(self.allocator, section_name);
        try self.sections.put(try self.allocator.dupe(u8, section_name), new_section);
        return self.sections.getPtr(section_name).?;
    }

    /// Check if a section exists
    pub fn hasSection(self: *const Ini, section_name: []const u8) bool {
        return self.sections.get(section_name) != null;
    }

    /// Remove a section
    pub fn removeSection(self: *Ini, section_name: []const u8) bool {
        if (self.sections.fetchRemove(section_name)) |kv| {
            kv.value.deinit(self.allocator);
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }
};

/// 位合并组（存储相同前缀的位标识）
const BitMergeGroup = struct {
    allocator: Allocator,
    prefix: []const u8,
    section_name: []const u8, // 空字符串表示全局
    datatype: DataType,
    entries: std.ArrayList(BitFlagEntry),

    fn init(allocator: Allocator, prefix: []const u8, section_name: []const u8, datatype: DataType) BitMergeGroup {
        return .{
            .allocator = allocator,
            .prefix = prefix,
            .section_name = section_name,
            .datatype = datatype,
            .entries = .empty,
        };
    }

    fn deinit(self: *BitMergeGroup) void {
        // 释放每个条目中分配的字符串
        for (self.entries.items) |item| {
            self.allocator.free(item.key);
            self.allocator.free(item.value);
        }
        self.entries.deinit(self.allocator);
        self.allocator.free(self.prefix);
        self.allocator.free(self.section_name);
    }
};

/// Parser for INI format
const Parser = struct {
    allocator: Allocator,
    content: []const u8,
    pos: usize,
    ini: *Ini,
    current_section: ?*Section = null,
    current_section_name: []const u8 = "", // 当前section的名称

    // 位合并收集器
    bit_merge_groups: StringHashMap(BitMergeGroup),

    fn parse(self: *Parser) Error!void {
        self.bit_merge_groups = StringHashMap(BitMergeGroup).init(self.allocator);
        defer {
            var iter = self.bit_merge_groups.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.deinit();
            }
            self.bit_merge_groups.deinit();
        }

        while (self.pos < self.content.len) {
            self.skipWhitespace();
            if (self.pos >= self.content.len) break;

            const ch = self.content[self.pos];

            // Comment
            if (ch == ';' or ch == '#') {
                try self.skipLine();
                continue;
            }

            // Section
            if (ch == '[') {
                try self.parseSection();
                continue;
            }

            // Key-value pair
            try self.parseKeyValue();
        }

        // 解析完成后，执行位合并
        try self.performBitMerge();
    }

    fn parseSection(self: *Parser) Error!void {
        self.pos += 1; // Skip '['
        const start = self.pos;

        while (self.pos < self.content.len and self.content[self.pos] != ']') {
            self.pos += 1;
        }

        if (self.pos >= self.content.len) return Error.InvalidFormat;
        if (self.pos == start) return Error.EmptySectionName;

        const section_name = self.content[start..self.pos];
        self.pos += 1; // Skip ']'

        const new_section = try Section.init(self.allocator, section_name);
        try self.ini.sections.put(try self.allocator.dupe(u8, section_name), new_section);

        self.current_section = self.ini.sections.getPtr(section_name).?;
        self.current_section_name = section_name;
    }

    fn parseKeyValue(self: *Parser) Error!void {
        const key_start = self.pos;
        while (self.pos < self.content.len and self.content[self.pos] != '=' and self.content[self.pos] != '\n') {
            self.pos += 1;
        }

        if (self.pos >= self.content.len or self.content[self.pos] != '=') {
            return Error.InvalidFormat;
        }

        var key_full = trim(self.content[key_start..self.pos]);
        self.pos += 1; // Skip '='

        // Skip whitespace after =
        while (self.pos < self.content.len and self.content[self.pos] == ' ') {
            self.pos += 1;
        }

        const value_start = self.pos;
        while (self.pos < self.content.len and self.content[self.pos] != '\n') {
            self.pos += 1;
        }

        // 使用新函数提取值并跳过行尾注释
        var value = extractValueWithoutComment(self.content[value_start..self.pos]);

        // Handle quoted strings
        if (value.len >= 2 and (value[0] == '"' or value[0] == '\'')) {
            const quote = value[0];
            if (value[value.len - 1] != quote) return Error.UnclosedQuote;
            value = value[1 .. value.len - 1];
        }

        // Parse key and optional type annotation: key:type = value
        var actual_key = key_full;
        var explicit_datatype: ?DataType = null;

        if (std.mem.indexOfScalar(u8, key_full, ':')) |colon_pos| {
            const key_part = key_full[0..colon_pos];
            const type_part = trim(key_full[colon_pos + 1 ..]);

            // 检查是否是有效的类型标识符
            if (DataType.parse(type_part)) |datatype| {
                actual_key = trim(key_part);
                explicit_datatype = datatype;
            } else {
                // 如果不是有效类型，保持原样
                actual_key = key_full;
            }
        }

        // 检查是否为位标识（key.subkey 格式）
        // 使用最后一个 . 作为分隔符，支持嵌套键如 file.owner.read
        if (std.mem.lastIndexOfScalar(u8, actual_key, '.')) |dot_pos| {
            const prefix = actual_key[0..dot_pos];
            const suffix = actual_key[dot_pos + 1 ..];

            // 只有当后缀不为空时才处理为位标识
            if (suffix.len > 0) {
                // 确定数据类型
                const datatype = explicit_datatype orelse DataType.infer(value);

                // 只有整数类型才进行位合并
                if (datatype.isInteger()) {
                    // 查找或创建位合并组
                    const group_key = try std.fmt.allocPrint(self.allocator, "{s}|{s}", .{ self.current_section_name, prefix });
                    errdefer self.allocator.free(group_key);

                    if (self.bit_merge_groups.getPtr(group_key)) |group| {
                        // 更新类型（使用第一个遇到的类型或显式类型）
                        if (explicit_datatype != null) {
                            group.datatype = explicit_datatype.?;
                        }
                        // 添加条目
                        try group.entries.append(self.allocator, BitFlagEntry{
                            .key = try self.allocator.dupe(u8, actual_key),
                            .value = try self.allocator.dupe(u8, value),
                            .datatype = datatype,
                        });
                    } else {
                        // 创建新组
                        var group = BitMergeGroup.init(self.allocator, try self.allocator.dupe(u8, prefix), try self.allocator.dupe(u8, self.current_section_name), datatype);
                        try group.entries.append(self.allocator, BitFlagEntry{
                            .key = try self.allocator.dupe(u8, actual_key),
                            .value = try self.allocator.dupe(u8, value),
                            .datatype = datatype,
                        });
                        try self.bit_merge_groups.put(group_key, group);
                    }

                    // 不存储原始的 key.subkey 条目
                    if (self.pos < self.content.len and self.content[self.pos] == '\n') {
                        self.pos += 1;
                    }
                    return;
                }
            }
        }

        // Create entry with explicit or inferred type
        const entry = if (explicit_datatype) |datatype|
            try Entry.initWithType(self.allocator, actual_key, value, datatype)
        else
            try Entry.init(self.allocator, actual_key, value);

        if (self.current_section) |section| {
            try section.entries.put(try self.allocator.dupe(u8, actual_key), entry);
        } else {
            try self.ini.global_entries.put(try self.allocator.dupe(u8, actual_key), entry);
        }

        if (self.pos < self.content.len and self.content[self.pos] == '\n') {
            self.pos += 1;
        }
    }

    fn skipLine(self: *Parser) Error!void {
        while (self.pos < self.content.len and self.content[self.pos] != '\n') {
            self.pos += 1;
        }
        if (self.pos < self.content.len and self.content[self.pos] == '\n') {
            self.pos += 1;
        }
    }

    fn skipWhitespace(self: *Parser) void {
        while (self.pos < self.content.len and (self.content[self.pos] == ' ' or self.content[self.pos] == '\t' or self.content[self.pos] == '\r' or self.content[self.pos] == '\n')) {
            self.pos += 1;
        }
    }

    fn trim(s: []const u8) []const u8 {
        var start: usize = 0;
        var end: usize = s.len;

        while (start < end and (s[start] == ' ' or s[start] == '\t' or s[start] == '\r')) {
            start += 1;
        }

        while (end > start and (s[end - 1] == ' ' or s[end - 1] == '\t' or s[end - 1] == '\r')) {
            end -= 1;
        }

        return s[start..end];
    }

    /// 提取值并跳过行尾注释（// 或 #）
    /// 支持引号字符串，引号内的注释符号不会被识别为注释
    fn extractValueWithoutComment(s: []const u8) []const u8 {
        var in_string = false;
        var string_quote: u8 = 0;

        for (s, 0..) |c, i| {
            // 处理引号字符串
            if (c == '"' or c == '\'') {
                if (!in_string) {
                    in_string = true;
                    string_quote = c;
                } else if (c == string_quote) {
                    in_string = false;
                    string_quote = 0;
                }
            }

            // 不在字符串内时检查注释符号
            if (!in_string) {
                // 检查 // 注释（两个连续的斜杠）
                if (c == '/' and i + 1 < s.len and s[i + 1] == '/') {
                    return trim(s[0..i]);
                }
                // 检查 # 注释
                if (c == '#') {
                    return trim(s[0..i]);
                }
            }
        }

        return trim(s);
    }

    /// 执行位合并操作
    fn performBitMerge(self: *Parser) Error!void {
        var iter = self.bit_merge_groups.iterator();

        while (iter.next()) |entry| {
            const group = entry.value_ptr;

            // 统一使用 u64 来计算，然后根据类型和结果值确定最终类型
            var merged: u64 = 0;

            // 统一处理所有整数类型的位合并
            inline for (.{ .u8, .u16, .u32, .u64 }) |int_type| {
                if (group.datatype == int_type) {
                    for (group.entries.items) |item| {
                        const val = try switch (int_type) {
                            .u8 => TypeConverter.toU8(item.value),
                            .u16 => TypeConverter.toU16(item.value),
                            .u32 => TypeConverter.toU32(item.value),
                            .u64 => TypeConverter.toU64(item.value),
                            else => unreachable,
                        };
                        merged |= val;
                    }
                }
            }

            // 处理有符号整数类型（转换为位模式）
            inline for (.{ .i8, .i16, .i32, .i64 }) |int_type| {
                if (group.datatype == int_type) {
                    for (group.entries.items) |item| {
                        const val = try switch (int_type) {
                            .i8 => TypeConverter.toI8(item.value),
                            .i16 => TypeConverter.toI16(item.value),
                            .i32 => TypeConverter.toI32(item.value),
                            .i64 => TypeConverter.toI64(item.value),
                            else => unreachable,
                        };
                        merged |= @as(u64, @bitCast(@as(i64, val)));
                    }
                }
            }

            // 处理自动推断类型
            if (group.datatype == .int) {
                for (group.entries.items) |item| {
                    const val = try TypeConverter.toU64(item.value);
                    merged |= val;
                }
            }

            // 非整数类型跳过
            if (!group.datatype.isInteger()) {
                continue;
            }

            // 确定最终使用的类型
            const final_type = if (group.datatype == .int)
                DataType.inferValueSize(merged)
            else
                group.datatype;

            // 根据结果值生成字符串
            const merged_value_str = try std.fmt.allocPrint(self.allocator, "{}", .{merged});
            errdefer self.allocator.free(merged_value_str);

            // 创建合并后的 entry
            const merged_entry = try Entry.initWithType(self.allocator, group.prefix, merged_value_str, final_type);

            // 存储到相应的位置
            if (group.section_name.len == 0) {
                // 全局
                try self.ini.global_entries.put(try self.allocator.dupe(u8, group.prefix), merged_entry);
            } else {
                // Section
                if (self.ini.sections.getPtr(group.section_name)) |section| {
                    try section.entries.put(try self.allocator.dupe(u8, group.prefix), merged_entry);
                }
            }

            self.allocator.free(merged_value_str);
        }
    }
};

// Tests
test "basic ini parsing" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# This is a comment
        \\global_key = global_value
        \\
        \\[section1]
        \\key1 = value1
        \\key2 = "quoted value"
        \\
        \\; Another comment
        \\[section2]
        \\key3 = value3
    ;

    try ini.loadFromString(content);

    // Test global key
    try std.testing.expectEqualStrings("global_value", ini.get("global_key").?);

    // Test section keys
    try std.testing.expectEqualStrings("value1", ini.getSection("section1", "key1").?);
    try std.testing.expectEqualStrings("quoted value", ini.getSection("section1", "key2").?);
    try std.testing.expectEqualStrings("value3", ini.getSection("section2", "key3").?);
}

test "save and load" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.setSection("section1", "key1", "value1");
    try ini.setSection("section1", "key2", "value2");

    const string = try ini.saveToString(allocator);
    defer allocator.free(string);

    var ini2 = Ini.init(allocator);
    defer ini2.deinit();
    try ini2.loadFromString(string);

    try std.testing.expectEqualStrings("value", ini2.get("global").?);
    try std.testing.expectEqualStrings("value1", ini2.getSection("section1", "key1").?);
    try std.testing.expectEqualStrings("value2", ini2.getSection("section1", "key2").?);
}
