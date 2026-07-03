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
    /// 文档注释（从配置文件中解析出来的注释）
    doc: ?[]const u8 = null,
    /// 标题（从 @title 注释标记解析）
    title: ?[]const u8 = null,
    /// 描述（从 @description 注释标记解析）
    description: ?[]const u8 = null,

    /// Create a new entry with automatic type inference
    pub fn init(allocator: Allocator, key: []const u8, value: []const u8) Allocator.Error!Entry {
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        return Entry{
            .key = key_copy,
            .value = value_copy,
            .datatype = DataType.infer(value),
        };
    }

    /// Create a new entry with explicit type
    pub fn initWithType(allocator: Allocator, key: []const u8, value: []const u8, datatype: DataType) Allocator.Error!Entry {
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        return Entry{
            .key = key_copy,
            .value = value_copy,
            .datatype = datatype,
        };
    }

    /// Free entry resources
    pub fn deinit(self: *Entry, allocator: Allocator) void {
        allocator.free(self.key);
        allocator.free(self.value);
        if (self.doc) |doc_text| {
            allocator.free(doc_text);
        }
        if (self.title) |title_text| {
            allocator.free(title_text);
        }
        if (self.description) |desc_text| {
            allocator.free(desc_text);
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

/// Schema is an alias for Entry - provides type information for a key-value pair
pub const Schema = Entry;

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
            // Free entry resources (including doc, title, description)
            entry.value_ptr.deinit(allocator);
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
    pub fn getEntry(self: *const Section, key: []const u8) ?*const Entry {
        return if (self.entries.getPtr(key)) |ptr| ptr else null;
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
            // Free entry resources (including doc, title, description)
            entry.value_ptr.deinit(self.allocator);
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
        // 清空现有数据
        {
            var entry_iter = self.global_entries.iterator();
            while (entry_iter.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
                self.allocator.free(entry.key_ptr.*);
            }
            self.global_entries.clearRetainingCapacity();

            var section_iter = self.sections.iterator();
            while (section_iter.next()) |section| {
                section.value_ptr.deinit(self.allocator);
                self.allocator.free(section.key_ptr.*);
            }
            self.sections.clearRetainingCapacity();
        }

        var parser = Parser{
            .allocator = self.allocator,
            .content = content,
            .pos = 0,
            .ini = self,
            .current_section = null,
            .current_section_name = "",
            .pending_comments = undefined, // 将在 parse 中初始化
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
            // 计算 doc、title、description 注释的长度（顺序：doc → title → description）
            if (entry.value_ptr.doc) |doc| {
                // doc 可能包含多行，需要为每一行计算 "# " 前缀
                var line_count: usize = 0;
                var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                while (doc_lines.next()) |line| {
                    line_count += 1;
                    _ = line;
                }
                total_size += line_count * 2 + doc.len + line_count; // 每行 "# " + 内容 + 换行符
            }
            if (entry.value_ptr.title) |title| {
                total_size += 9 + title.len + 1; // "# @title xxx\n"
            }
            if (entry.value_ptr.description) |desc| {
                total_size += 16 + desc.len + 1; // "# @description xxx\n"
            }
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
                // 计算 doc、title、description 注释的长度（顺序：doc → title → description）
                if (entry.value_ptr.doc) |doc| {
                    // doc 可能包含多行，需要为每一行计算 "# " 前缀
                    var line_count: usize = 0;
                    var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                    while (doc_lines.next()) |line| {
                        line_count += 1;
                        _ = line;
                    }
                    total_size += line_count * 2 + doc.len + line_count; // 每行 "# " + 内容 + 换行符
                }
                if (entry.value_ptr.title) |title| {
                    total_size += 9 + title.len + 1; // "# @title xxx\n"
                }
                if (entry.value_ptr.description) |desc| {
                    total_size += 16 + desc.len + 1; // "# @description xxx\n"
                }
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
            // 按顺序写入注释：doc → @title → @description
            if (entry.value_ptr.doc) |doc| {
                // doc 可能包含多行，需要为每一行添加 "# " 前缀
                var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                while (doc_lines.next()) |line| {
                    result[pos] = '#';
                    pos += 1;
                    result[pos] = ' ';
                    pos += 1;
                    @memcpy(result[pos..][0..line.len], line);
                    pos += line.len;
                    result[pos] = '\n';
                    pos += 1;
                }
            }
            if (entry.value_ptr.title) |title| {
                result[pos] = '#';
                pos += 1;
                result[pos] = ' ';
                pos += 1;
                result[pos] = '@';
                pos += 1;
                result[pos] = 't';
                pos += 1;
                result[pos] = 'i';
                pos += 1;
                result[pos] = 't';
                pos += 1;
                result[pos] = 'l';
                pos += 1;
                result[pos] = 'e';
                pos += 1;
                result[pos] = ' ';
                pos += 1;
                @memcpy(result[pos..][0..title.len], title);
                pos += title.len;
                result[pos] = '\n';
                pos += 1;
            }
            if (entry.value_ptr.description) |desc| {
                result[pos] = '#';
                pos += 1;
                result[pos] = ' ';
                pos += 1;
                result[pos] = '@';
                pos += 1;
                @memcpy(result[pos..][0.."d".len], "d");
                pos += 1;
                @memcpy(result[pos..][0.."e".len], "e");
                pos += 1;
                @memcpy(result[pos..][0.."s".len], "s");
                pos += 1;
                @memcpy(result[pos..][0.."c".len], "c");
                pos += 1;
                @memcpy(result[pos..][0.."r".len], "r");
                pos += 1;
                @memcpy(result[pos..][0.."i".len], "i");
                pos += 1;
                @memcpy(result[pos..][0.."p".len], "p");
                pos += 1;
                @memcpy(result[pos..][0.."t".len], "t");
                pos += 1;
                @memcpy(result[pos..][0.."i".len], "i");
                pos += 1;
                @memcpy(result[pos..][0.."o".len], "o");
                pos += 1;
                @memcpy(result[pos..][0.."n".len], "n");
                pos += 1;
                result[pos] = ' ';
                pos += 1;
                @memcpy(result[pos..][0..desc.len], desc);
                pos += desc.len;
                result[pos] = '\n';
                pos += 1;
            }
            // 写入 key = value
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
                // 按顺序写入注释：doc → @title → @description
                if (entry.value_ptr.doc) |doc| {
                    // doc 可能包含多行，需要为每一行添加 "# " 前缀
                    var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                    while (doc_lines.next()) |line| {
                        result[pos] = '#';
                        pos += 1;
                        result[pos] = ' ';
                        pos += 1;
                        @memcpy(result[pos..][0..line.len], line);
                        pos += line.len;
                        result[pos] = '\n';
                        pos += 1;
                    }
                }
                if (entry.value_ptr.title) |title| {
                    result[pos] = '#';
                    pos += 1;
                    result[pos] = ' ';
                    pos += 1;
                    result[pos] = '@';
                    pos += 1;
                    result[pos] = 't';
                    pos += 1;
                    result[pos] = 'i';
                    pos += 1;
                    result[pos] = 't';
                    pos += 1;
                    result[pos] = 'l';
                    pos += 1;
                    result[pos] = 'e';
                    pos += 1;
                    result[pos] = ' ';
                    pos += 1;
                    @memcpy(result[pos..][0..title.len], title);
                    pos += title.len;
                    result[pos] = '\n';
                    pos += 1;
                }
                if (entry.value_ptr.description) |desc| {
                    result[pos] = '#';
                    pos += 1;
                    result[pos] = ' ';
                    pos += 1;
                    result[pos] = '@';
                    pos += 1;
                    @memcpy(result[pos..][0.."d".len], "d");
                    pos += 1;
                    @memcpy(result[pos..][0.."e".len], "e");
                    pos += 1;
                    @memcpy(result[pos..][0.."s".len], "s");
                    pos += 1;
                    @memcpy(result[pos..][0.."c".len], "c");
                    pos += 1;
                    @memcpy(result[pos..][0.."r".len], "r");
                    pos += 1;
                    @memcpy(result[pos..][0.."i".len], "i");
                    pos += 1;
                    @memcpy(result[pos..][0.."p".len], "p");
                    pos += 1;
                    @memcpy(result[pos..][0.."t".len], "t");
                    pos += 1;
                    @memcpy(result[pos..][0.."i".len], "i");
                    pos += 1;
                    @memcpy(result[pos..][0.."o".len], "o");
                    pos += 1;
                    @memcpy(result[pos..][0.."n".len], "n");
                    pos += 1;
                    result[pos] = ' ';
                    pos += 1;
                    @memcpy(result[pos..][0..desc.len], desc);
                    pos += desc.len;
                    result[pos] = '\n';
                    pos += 1;
                }
                // 写入 key = value
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

        return result[0..pos];
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
    pub fn getEntry(self: *const Ini, key: []const u8) ?*const Entry {
        return if (self.global_entries.getPtr(key)) |ptr| ptr else null;
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

    /// Set a global value

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

/// Parser for INI format
const Parser = struct {
    allocator: Allocator,
    content: []const u8,
    pos: usize,
    ini: *Ini,
    current_section: ?*Section = null,
    current_section_name: []const u8 = "", // 当前section的名称
    pending_comments: std.ArrayList([]const u8), // 累积的注释行

    fn parse(self: *Parser) Error!void {
        self.pending_comments = std.ArrayList([]const u8).empty;
        defer {
            for (self.pending_comments.items) |comment| {
                self.allocator.free(comment);
            }
            self.pending_comments.deinit(self.allocator);
        }

        while (self.pos < self.content.len) {
            self.skipWhitespace();
            if (self.pos >= self.content.len) break;

            const ch = self.content[self.pos];

            // Comment (# and ; supported)
            if (ch == '#' or ch == ';') {
                try self.accumulateComment();
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

        // Create entry with explicit or inferred type
        var entry = if (explicit_datatype) |datatype|
            try Entry.initWithType(self.allocator, actual_key, value, datatype)
        else
            try Entry.init(self.allocator, actual_key, value);

        // 设置文档注释（包含 title 和 description）
        try self.setEntryDocumentation(&entry);

        if (self.current_section) |section| {
            try section.entries.put(try self.allocator.dupe(u8, actual_key), entry);
        } else {
            try self.ini.global_entries.put(try self.allocator.dupe(u8, actual_key), entry);
        }

        if (self.pos < self.content.len and self.content[self.pos] == '\n') {
            self.pos += 1;
        }
    }

    /// 累积注释行到 pending_comments
    fn accumulateComment(self: *Parser) Error!void {
        // 跳过 # 字符
        self.pos += 1;
        const start = self.pos;

        // 找到行尾
        while (self.pos < self.content.len and self.content[self.pos] != '\n') {
            self.pos += 1;
        }

        // 提取注释内容并使用 trimAll 删除前后空格
        const comment_raw = self.content[start..self.pos];
        const comment_trimmed = trimAll(comment_raw);

        // 跳过空注释
        if (comment_trimmed.len == 0) {
            // 跳过换行符
            if (self.pos < self.content.len and self.content[self.pos] == '\n') {
                self.pos += 1;
            }
            return;
        }

        // 保存注释（包括 @title 和 @description 标记）
        try self.pending_comments.append(self.allocator, try self.allocator.dupe(u8, comment_trimmed));

        // 跳过换行符
        if (self.pos < self.content.len and self.content[self.pos] == '\n') {
            self.pos += 1;
        }
    }

    /// 获取并清空累积的注释，将多行注释合并为一个字符串
    fn getPendingDocumentation(self: *Parser) Allocator.Error!?[]const u8 {
        if (self.pending_comments.items.len == 0) {
            return null;
        }

        // 计算总大小
        var total_size: usize = 0;
        for (self.pending_comments.items) |comment| {
            total_size += comment.len;
            total_size += 1; // 换行符
        }

        // 分配内存
        const result = try self.allocator.alloc(u8, total_size);
        var offset: usize = 0;

        // 合并注释
        for (self.pending_comments.items) |comment| {
            @memcpy(result[offset..][0..comment.len], comment);
            offset += comment.len;
            if (offset < result.len) {
                result[offset] = '\n';
                offset += 1;
            }
        }

        // 清空累积的注释并释放内存
        for (self.pending_comments.items) |comment| {
            self.allocator.free(comment);
        }
        self.pending_comments.clearRetainingCapacity();

        return result[0 .. offset - 1]; // 移除最后的换行符
    }

    /// 设置 entry 的文档字段（从累积的注释中提取 title、description 和 doc）
    fn setEntryDocumentation(self: *Parser, entry: *Entry) !void {
        if (self.pending_comments.items.len == 0) {
            return;
        }

        var doc_comments = std.ArrayList([]const u8).empty;
        defer {
            for (doc_comments.items) |comment| {
                self.allocator.free(comment);
            }
            doc_comments.deinit(self.allocator);
        }

        // 遍历注释行，提取 title 和 description
        for (self.pending_comments.items) |comment| {
            if (std.mem.startsWith(u8, comment, "@title")) {
                const title_value = trimAll(comment["@title".len..]);
                if (title_value.len > 0) {
                    entry.title = try self.allocator.dupe(u8, title_value);
                }
            } else if (std.mem.startsWith(u8, comment, "@description")) {
                const desc_value = trimAll(comment["@description".len..]);
                if (desc_value.len > 0) {
                    entry.description = try self.allocator.dupe(u8, desc_value);
                }
            } else {
                // 普通注释行
                try doc_comments.append(self.allocator, try self.allocator.dupe(u8, comment));
            }
        }

        // 合并剩余的普通注释为 doc
        if (doc_comments.items.len > 0) {
            // 计算实际需要的总大小（注释内容 + 换行符）
            // 最后一个注释后面不需要换行符
            var total_size: usize = 0;
            for (doc_comments.items) |comment| {
                total_size += comment.len;
                total_size += 1; // 换行符
            }
            total_size -= 1; // 移除最后一个换行符

            const result = try self.allocator.alloc(u8, total_size);
            var offset: usize = 0;

            for (doc_comments.items, 0..) |comment, i| {
                @memcpy(result[offset..][0..comment.len], comment);
                offset += comment.len;
                // 不是最后一个注释时添加换行符
                if (i < doc_comments.items.len - 1) {
                    result[offset] = '\n';
                    offset += 1;
                }
            }

            entry.doc = result;
        }

        // 清空累积的注释并释放内存
        for (self.pending_comments.items) |comment| {
            self.allocator.free(comment);
        }
        self.pending_comments.clearRetainingCapacity();
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

    /// 删除字符串的前后空格（包括 \n, \r, \t, 空格）
    fn trimAll(s: []const u8) []const u8 {
        var start: usize = 0;
        var end: usize = s.len;

        // 删除前导空白字符
        while (start < end and (s[start] == ' ' or s[start] == '\t' or s[start] == '\r' or s[start] == '\n')) {
            start += 1;
        }

        // 删除尾随空白字符
        while (end > start and (s[end - 1] == ' ' or s[end - 1] == '\t' or s[end - 1] == '\r' or s[end - 1] == '\n')) {
            end -= 1;
        }

        return s[start..end];
    }

    /// 提取值（不再支持行尾注释）
    fn extractValueWithoutComment(s: []const u8) []const u8 {
        return trim(s);
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
