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
    InvalidCharacter,
};

/// A single key-value schema with type information
pub const Schema = struct {
    key: []const u8,
    value: []const u8,
    datatype: DataType,
    /// 标题（从 @title 注释标记解析）
    title: ?[]const u8 = null,
    /// 描述（其他所有普通注释）
    description: ?[]const u8 = null,

    /// Create a new schema with automatic type inference
    pub fn init(allocator: Allocator, key: []const u8, value: []const u8) Allocator.Error!Schema {
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        return Schema{
            .key = key_copy,
            .value = value_copy,
            .datatype = DataType.infer(value),
        };
    }

    /// Create a new schema with explicit type
    pub fn initWithType(allocator: Allocator, key: []const u8, value: []const u8, datatype: DataType) Allocator.Error!Schema {
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        return Schema{
            .key = key_copy,
            .value = value_copy,
            .datatype = datatype,
        };
    }

    /// Free schema resources
    pub fn deinit(self: *Schema, allocator: Allocator) void {
        allocator.free(self.key);
        allocator.free(self.value);
        if (self.title) |title_text| {
            allocator.free(title_text);
        }
        if (self.description) |desc_text| {
            allocator.free(desc_text);
        }
    }

    /// Free schema resources except key (used when key is owned by HashMap)
    pub fn deinitWithoutKey(self: *Schema, allocator: Allocator) void {
        allocator.free(self.value);
        if (self.title) |title_text| {
            allocator.free(title_text);
        }
        if (self.description) |desc_text| {
            allocator.free(desc_text);
        }
    }

    /// Get value as boolean
    pub fn asBool(self: *const Schema) !bool {
        return TypeConverter.toBool(self.value);
    }

    /// Get value as u8
    pub fn asU8(self: *const Schema) !u8 {
        return TypeConverter.toU8(self.value);
    }

    /// Get value as u16
    pub fn asU16(self: *const Schema) !u16 {
        return TypeConverter.toU16(self.value);
    }

    /// Get value as u32
    pub fn asU32(self: *const Schema) !u32 {
        return TypeConverter.toU32(self.value);
    }

    /// Get value as u64
    pub fn asU64(self: *const Schema) !u64 {
        return TypeConverter.toU64(self.value);
    }

    /// Get value as i8
    pub fn asI8(self: *const Schema) !i8 {
        return TypeConverter.toI8(self.value);
    }

    /// Get value as i16
    pub fn asI16(self: *const Schema) !i16 {
        return TypeConverter.toI16(self.value);
    }

    /// Get value as i32
    pub fn asI32(self: *const Schema) !i32 {
        return TypeConverter.toI32(self.value);
    }

    /// Get value as i64
    pub fn asI64(self: *const Schema) !i64 {
        return TypeConverter.toI64(self.value);
    }

    /// Get value as f32
    pub fn asF32(self: *const Schema) !f32 {
        return TypeConverter.toF32(self.value);
    }

    /// Get value as f64
    pub fn asF64(self: *const Schema) !f64 {
        return TypeConverter.toF64(self.value);
    }

    /// Get value as integer (generic)
    pub fn asInt(self: *const Schema) !i64 {
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
    pub fn asFloat(self: *const Schema) !f64 {
        return switch (self.datatype) {
            .f32 => @floatCast(try self.asF32()),
            .f64 => try self.asF64(),
            .float => try self.asF64(),
            else => error.TypeMismatch,
        };
    }

    /// Get value as string
    pub fn asString(self: *const Schema) []const u8 {
        return TypeConverter.toString(self.value);
    }

    /// Check if value matches expected type
    pub fn isType(self: *const Schema, expected: DataType) bool {
        return self.datatype == expected;
    }
};

/// Parsed key result for <section>.<key> syntax
const ParsedKey = union(enum) {
    /// Global key (no dot found)
    global: []const u8,
    /// Section.key syntax (dot found)
    section_key: struct {
        section: []const u8,
        key: []const u8,
    },
};

/// Parse a key string into ParsedKey (supports <section>.<key> syntax)
/// Returns: ParsedKey.global if no dot found, ParsedKey.section_key if dot found
fn parseKey(key: []const u8) ParsedKey {
    if (std.mem.indexOfScalar(u8, key, '.')) |dot_index| {
        // Parse section.key syntax
        const section_name = key[0..dot_index];
        const actual_key = key[dot_index + 1 ..];
        return .{ .section_key = .{ .section = section_name, .key = actual_key } };
    }
    return .{ .global = key };
}

/// Main INI structure
pub const Ini = struct {
    allocator: Allocator,
    schemas: StringHashMap(Schema),
    sections: StringHashMap(Ini),

    /// Create a new empty Ini structure
    pub fn init(allocator: Allocator) Ini {
        return .{
            .allocator = allocator,
            .schemas = StringHashMap(Schema).init(allocator),
            .sections = StringHashMap(Ini).init(allocator),
        };
    }

    /// Free all resources
    pub fn deinit(self: *Ini) void {
        // Free global entries
        var schema_iter = self.schemas.iterator();
        while (schema_iter.next()) |schema| {
            // Free schema resources except key (key is owned by HashMap)
            @constCast(schema.value_ptr).deinitWithoutKey(self.allocator);
            // Free the key stored in the hash map (also frees Schema.key since they share allocation)
            self.allocator.free(schema.key_ptr.*);
        }
        self.schemas.deinit();

        // Free sections (now Inis instead of Sections)
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section| {
            // Recursively deinit the nested Ini
            section.value_ptr.deinit();
            // Free the section name key
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
            var schema_iter = self.schemas.iterator();
            while (schema_iter.next()) |schema| {
                schema.value_ptr.deinit(self.allocator);
                self.allocator.free(schema.key_ptr.*);
            }
            self.schemas.clearRetainingCapacity();

            var section_iter = self.sections.iterator();
            while (section_iter.next()) |section| {
                section.value_ptr.deinit();
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
        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(allocator);

        // Write global entries
        var schema_iter = self.schemas.iterator();
        while (schema_iter.next()) |entry| {
            try formatSchemaToBuffer(allocator, &buffer, entry.value_ptr.*);
        }

        // Blank line between global and sections
        if (self.schemas.count() > 0 and self.sections.count() > 0) {
            try buffer.append(allocator, '\n');
        }

        // Write sections (now Inis)
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section| {
            const section_name = section.key_ptr.*;
            const section_ini = section.value_ptr;

            const section_header = try std.fmt.allocPrint(allocator, "[{s}]\n", .{section_name});
            defer allocator.free(section_header);
            try buffer.appendSlice(allocator, section_header);

            var section_schema_iter = section_ini.schemas.iterator();
            while (section_schema_iter.next()) |schema| {
                try formatSchemaToBuffer(allocator, &buffer, schema.value_ptr.*);
            }

            try buffer.append(allocator, '\n');
        }

        return buffer.toOwnedSlice(allocator);
    }

    /// Helper function to format a single schema to buffer
    fn formatSchemaToBuffer(allocator: Allocator, buffer: *std.ArrayList(u8), schema: Schema) !void {
        // Write @title comment if present
        if (schema.title) |title| {
            const title_line = try std.fmt.allocPrint(allocator, "# @title {s}\n", .{title});
            defer allocator.free(title_line);
            try buffer.appendSlice(allocator, title_line);
        }

        // Write description comments if present
        if (schema.description) |desc| {
            var line_iter = std.mem.splitScalar(u8, desc, '\n');
            while (line_iter.next()) |line| {
                const desc_line = try std.fmt.allocPrint(allocator, "# {s}\n", .{line});
                defer allocator.free(desc_line);
                try buffer.appendSlice(allocator, desc_line);
            }
        }

        // Write key = value
        const key_value = try std.fmt.allocPrint(allocator, "{s} = {s}\n", .{ schema.key, schema.value });
        defer allocator.free(key_value);
        try buffer.appendSlice(allocator, key_value);
    }

    /// Write INI content to a writer
    fn writeTo(self: *const Ini, writer: anytype) Error!void {
        // Write global entries first
        var schema_iter = self.schemas.iterator();
        while (schema_iter.next()) |schema| {
            try writer.print("{s} = {s}\n", .{ schema.key_ptr.*, schema.value_ptr.value });
        }

        // Write sections (now Inis)
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section| {
            const section_name = section.key_ptr.*;
            const section_ini = section.value_ptr;

            try writer.print("[{s}]\n", .{section_name});

            var schema_iter2 = section_ini.schemas.iterator();
            while (schema_iter2.next()) |schema| {
                try writer.print("{s} = {s}\n", .{ schema.key_ptr.*, schema.value_ptr.value });
            }

            try writer.writeByte('\n');
        }
    }

    /// Get a global value
    pub fn get(self: *const Ini, key: []const u8) ?[]const u8 {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                // Get from section
                if (self.sections.get(parsed.section)) |section| {
                    return section.get(parsed.key);
                }
                return null;
            },
            .global => |global_key| {
                // Get from global schemas
                if (self.schemas.get(global_key)) |schema| {
                    return schema.value;
                }
                return null;
            },
        }
    }

    /// Get global schema（支持 section.key 语法）
    pub fn getSchema(self: *const Ini, key: []const u8) ?*const Schema {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                // Get from section
                if (self.sections.get(parsed.section)) |section| {
                    return section.getSchema(parsed.key);
                }
                return null;
            },
            .global => |global_key| {
                // Get from global schemas
                return if (self.schemas.getPtr(global_key)) |ptr| ptr else null;
            },
        }
    }

    /// 辅助函数：统一处理全局值的类型转换
    fn getGlobalTypedValue(comptime T: type, ini: *const Ini, key: []const u8, comptime converterFn: fn ([]const u8) anyerror!T) !T {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                // Get from section
                if (ini.sections.get(parsed.section)) |section| {
                    if (section.get(parsed.key)) |value_str| {
                        return converterFn(value_str);
                    }
                }
                return error.KeyNotFound;
            },
            .global => |global_key| {
                // Get from global schemas
                if (ini.schemas.get(global_key)) |schema| {
                    return converterFn(schema.value);
                }
                return error.KeyNotFound;
            },
        }
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

    /// Set a value (supports <section>.<key> syntax)
    pub fn set(self: *Ini, key: []const u8, value: []const u8) Allocator.Error!void {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                // Get or create section Ini
                const section_ini = try self.getOrCreateSectionInternal(parsed.section);
                // Recursively call set on the nested Ini
                try section_ini.set(parsed.key, value);
            },
            .global => |global_key| {
                // Set in global schemas
                if (self.schemas.get(global_key)) |_| {
                    // Remove old schema and add new one
                    const old_schema = self.schemas.fetchRemove(global_key).?;
                    // Free old schema's resources (not the key, it's the same as HashMap key)
                    self.allocator.free(old_schema.value.value);
                    if (old_schema.value.title) |title| self.allocator.free(title);
                    if (old_schema.value.description) |desc| self.allocator.free(desc);
                    self.allocator.free(old_schema.key);
                }

                // Add new schema - key ownership transferred to HashMap later
                const value_copy = try self.allocator.dupe(u8, value);

                const new_schema = Schema{
                    .key = undefined, // Will be set to HashMap key after put
                    .value = value_copy,
                    .datatype = DataType.infer(value),
                    .title = null,
                    .description = null,
                };

                // Put in HashMap - this creates the key copy
                const key_copy = try self.allocator.dupe(u8, global_key);
                try self.schemas.put(key_copy, new_schema);

                // Set the schema's key pointer to point to HashMap's key
                const stored_schema = self.schemas.getPtr(key_copy).?;
                stored_schema.key = key_copy;
            },
        }
    }

    /// Check if a key or section exists
    /// Supports:
    /// - <section>.<key> syntax: Check if key exists in section
    /// - <section> syntax: Check if section exists (no dot in name)
    /// - <key> syntax: Check if global key exists (if not a section name)
    pub fn has(self: *const Ini, key_or_section: []const u8) bool {
        switch (parseKey(key_or_section)) {
            .section_key => |parsed| {
                // Check in section
                if (self.sections.get(parsed.section)) |section| {
                    return section.get(parsed.key) != null;
                }
                return false;
            },
            .global => |global_key| {
                // No dot found: could be a section name or a global key
                // First check if it's a section
                if (self.sections.get(global_key) != null) {
                    return true; // Section exists
                }

                // Otherwise, check if it's a global key
                return self.schemas.contains(global_key);
            },
        }
    }

    /// Remove a key or section
    /// Supports:
    /// - <section>.<key> syntax: Remove key from section
    /// - <section> syntax: Remove entire section and all its keys (no dot in name)
    /// - <key> syntax: Remove global key (if not a section name)
    /// Returns: true if removed, false if not found
    pub fn remove(self: *Ini, key_or_section: []const u8) bool {
        switch (parseKey(key_or_section)) {
            .section_key => |parsed| {
                // Remove from section
                if (self.sections.getPtr(parsed.section)) |section| {
                    return section.remove(parsed.key);
                }
                return false;
            },
            .global => |global_key| {
                // No dot found: could be a section name or a global key
                // First try to remove as a section
                if (self.sections.fetchRemove(global_key)) |kv| {
                    // Section found, deinit it (safe to use constCast here as we're removing it)
                    @constCast(&kv.value).deinit();
                    self.allocator.free(kv.key);
                    return true; // Section removed
                }

                // Otherwise, try to remove as a global key
                if (self.schemas.fetchRemove(global_key)) |kv| {
                    // Free schema resources (kv.value is const)
                    // Use deinitWithoutKey since key is owned by HashMap
                    @constCast(&kv.value).deinitWithoutKey(self.allocator);
                    // Free the key stored in the hash map (also frees Schema.key since they share allocation)
                    self.allocator.free(kv.key);
                    return true; // Global key removed
                }

                return false; // Not found
            },
        }
    }

    /// Add a complete Schema object (supports <section>.<key> syntax)
    /// Unlike set(key, value) which accepts a string value and infers type,
    /// add accepts a pre-configured Schema object (with explicit type and documentation)
    ///
    /// This method performs a deep copy of the Schema object.
    /// The caller is still responsible for deinitializing the original Schema.
    pub fn add(self: *Ini, key: []const u8, schema: Schema) Allocator.Error!void {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                // Get or create section
                const section = try self.getOrCreateSectionInternal(parsed.section);

                // Remove old schema if exists
                if (section.schemas.fetchRemove(parsed.key)) |kv| {
                    const old_schema = kv.value;
                    // Call deinit to free old schema's resources (except key, owned by HashMap)
                    @constCast(&old_schema).deinitWithoutKey(self.allocator);
                    self.allocator.free(kv.key);
                }

                // Create new schema - key ownership transferred to HashMap later
                const value_copy = try self.allocator.dupe(u8, schema.value);

                const new_schema = Schema{
                    .key = undefined, // Will be set to HashMap key after put
                    .value = value_copy,
                    .datatype = schema.datatype,
                    .title = if (schema.title) |title| try self.allocator.dupe(u8, title) else null,
                    .description = if (schema.description) |desc| try self.allocator.dupe(u8, desc) else null,
                };

                // Put in HashMap - this creates the key copy
                const key_copy = try self.allocator.dupe(u8, parsed.key);
                try section.schemas.put(key_copy, new_schema);

                // Set the schema's key pointer to point to HashMap's key
                // (they now share the same allocation)
                const stored_schema = section.schemas.getPtr(key_copy).?;
                stored_schema.key = key_copy;
            },
            .global => |global_key| {
                // Remove old schema if exists
                if (self.schemas.fetchRemove(global_key)) |kv| {
                    const old_schema = kv.value;
                    // Call deinit to free old schema's resources (except key, owned by HashMap)
                    @constCast(&old_schema).deinitWithoutKey(self.allocator);
                    self.allocator.free(kv.key);
                }

                // Create new schema - key ownership transferred to HashMap later
                const value_copy = try self.allocator.dupe(u8, schema.value);

                const new_schema = Schema{
                    .key = undefined, // Will be set to HashMap key after put
                    .value = value_copy,
                    .datatype = schema.datatype,
                    .title = if (schema.title) |title| try self.allocator.dupe(u8, title) else null,
                    .description = if (schema.description) |desc| try self.allocator.dupe(u8, desc) else null,
                };

                // Put in HashMap - this creates the key copy
                const key_copy = try self.allocator.dupe(u8, global_key);
                try self.schemas.put(key_copy, new_schema);

                // Set the schema's key pointer to point to HashMap's key
                // (they now share the same allocation)
                const stored_schema = self.schemas.getPtr(key_copy).?;
                stored_schema.key = key_copy;
            },
        }
    }

    /// Internal helper: Get or create a section (as nested Ini)
    fn getOrCreateSectionInternal(self: *Ini, section_name: []const u8) Allocator.Error!*Ini {
        if (self.sections.getPtr(section_name)) |section| {
            return section;
        }

        // Create new section Ini (without nested sections)
        const name_copy = try self.allocator.dupe(u8, section_name);
        errdefer self.allocator.free(name_copy);

        const new_section = Ini{
            .allocator = self.allocator,
            .schemas = StringHashMap(Schema).init(self.allocator),
            .sections = StringHashMap(Ini).init(self.allocator),
        };

        try self.sections.put(name_copy, new_section);
        return self.sections.getPtr(section_name).?;
    }

    /// 遍历所有 schema（全局 + 所有 sections）
    /// context: 用户提供的上下文指针（支持计数器等外部变量修改）
    /// callback: 回调函数，接收 context 指针、section (null 表示全局) 和 schema 指针
    pub fn forEach(self: *const Ini, context_ptr: anytype, comptime callback: anytype) void {
        // 1. 遍历全局 schemas
        var schema_iter = self.schemas.iterator();
        while (schema_iter.next()) |entry| {
            callback(context_ptr, null, entry.value_ptr);
        }

        // 2. 遍历所有 sections
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section_entry| {
            const section_name = section_entry.key_ptr.*;
            var section_schema_iter = section_entry.value_ptr.schemas.iterator();
            while (section_schema_iter.next()) |schema_entry| {
                callback(context_ptr, section_name, schema_entry.value_ptr);
            }
        }
    }
};

/// Parser for INI format
const Parser = struct {
    allocator: Allocator,
    content: []const u8,
    pos: usize,
    ini: *Ini,
    current_section: ?*Ini = null,
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

        // Use the helper method to get or create section Ini
        self.current_section = try self.ini.getOrCreateSectionInternal(section_name);
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

        var key_full = trimAll(self.content[key_start..self.pos]);
        self.pos += 1; // Skip '='

        // Skip whitespace after =
        while (self.pos < self.content.len and self.content[self.pos] == ' ') {
            self.pos += 1;
        }

        // Parse key and optional type annotation: key:type = value
        var actual_key = key_full;
        var explicit_datatype: ?DataType = null;

        if (std.mem.indexOfScalar(u8, key_full, ':')) |colon_pos| {
            const key_part = key_full[0..colon_pos];
            const type_part = trimAll(key_full[colon_pos + 1 ..]);

            // 检查是否是有效的类型标识符
            if (DataType.parse(type_part)) |datatype| {
                actual_key = trimAll(key_part);
                explicit_datatype = datatype;
            } else {
                // 如果不是有效类型，保持原样
                actual_key = key_full;
            }
        }

        // 检查当前位置是否以 ``` 开头（多行字符串开始）
        // 先跳过空格检测
        var temp_pos = self.pos;
        while (temp_pos < self.content.len and
               (self.content[temp_pos] == ' ' or self.content[temp_pos] == '\t')) {
            temp_pos += 1;
        }

        const is_multiline = (temp_pos + 3 <= self.content.len and
            self.content[temp_pos] == '`' and
            self.content[temp_pos + 1] == '`' and
            self.content[temp_pos + 2] == '`');

        var value: []const u8 = undefined;

        if (is_multiline) {
            // 类型约束检查：非 string 类型忽略多行语法
            if (explicit_datatype == null or explicit_datatype.? == .string) {
                // 解析多行字符串（返回原始内容 slice）
                const multiline_content = self.parseMultilineValue();
                // 对 trimAll 后的内容进行内存分配
                const trimmed_multiline = trimAll(multiline_content);
                value = trimmed_multiline;
            } else {
                // 非字符串类型，按单行处理
                // 先跳过 ``` 标记
                while (self.pos < self.content.len and
                       (self.content[self.pos] == ' ' or self.content[self.pos] == '\t')) {
                    self.pos += 1;
                }
                self.pos += 3; // 跳过 ```

                // 读取单行值
                const single_value = self.parseSingleLineValue();
                value = single_value;

                // 处理引号
                if (value.len >= 2 and (value[0] == '"' or value[0] == '\'')) {
                    const quote = value[0];
                    if (value[value.len - 1] != quote) return Error.UnclosedQuote;
                    value = value[1 .. value.len - 1];
                }
            }
        } else {
            // 不是多行字符串，读取单行值
            value = self.parseSingleLineValue();

            // 处理引号
            if (value.len >= 2 and (value[0] == '"' or value[0] == '\'')) {
                const quote = value[0];
                if (value[value.len - 1] != quote) return Error.UnclosedQuote;
                value = value[1 .. value.len - 1];
            }
        }

        // Create schema with explicit or inferred type (without key - key will be set later)
        const value_copy = try self.allocator.dupe(u8, value);

        var schema = if (explicit_datatype) |datatype|
            Schema{
                .key = undefined, // Will be set after put
                .value = value_copy,
                .datatype = datatype,
                .title = null,
                .description = null,
            }
        else
            Schema{
                .key = undefined, // Will be set after put
                .value = value_copy,
                .datatype = DataType.infer(value),
                .title = null,
                .description = null,
            };

        // 设置文档注释（包含 title 和 description）
        try self.setSchemaDocumentation(&schema);

        if (self.current_section) |section| {
            // Put in HashMap - this creates the key copy
            const key_copy = try self.allocator.dupe(u8, actual_key);
            try section.schemas.put(key_copy, schema);

            // Set the schema's key pointer to point to HashMap's key
            const stored_schema = section.schemas.getPtr(key_copy).?;
            stored_schema.key = key_copy;
        } else {
            // Put in HashMap - this creates the key copy
            const key_copy = try self.allocator.dupe(u8, actual_key);
            try self.ini.schemas.put(key_copy, schema);

            // Set the schema's key pointer to point to HashMap's key
            const stored_schema = self.ini.schemas.getPtr(key_copy).?;
            stored_schema.key = key_copy;
        }

        if (self.pos < self.content.len and self.content[self.pos] == '\n') {
            self.pos += 1;
        }
    }

    /// 解析单行值（遇到换行符停止）
    fn parseSingleLineValue(self: *Parser) []const u8 {
        const value_start = self.pos;
        while (self.pos < self.content.len and self.content[self.pos] != '\n') {
            self.pos += 1;
        }
        return extractValueWithoutComment(self.content[value_start..self.pos]);
    }

    /// 检查是否遇到新的配置项（用于多行字符串容错）
    /// 不包括注释（# 或 ;），因为它们应该是多行字符串内容的一部分
    fn isNewConfigItem(self: *const Parser) bool {
        // 跳过当前行的空白
        var temp_pos = self.pos;
        while (temp_pos < self.content.len and
               (self.content[temp_pos] == ' ' or
                self.content[temp_pos] == '\t')) {
            temp_pos += 1;
        }

        // 检查是否在新行开头
        if (temp_pos >= self.content.len or self.content[temp_pos] != '\n') {
            return false;
        }

        // 跳过换行符和空白
        temp_pos += 1;
        while (temp_pos < self.content.len and
               (self.content[temp_pos] == ' ' or
                self.content[temp_pos] == '\t' or
                self.content[temp_pos] == '\r' or
                self.content[temp_pos] == '\n')) {
            temp_pos += 1;
        }

        if (temp_pos >= self.content.len) return true; // 文件尾

        // 检查是否是配置项开始
        const c = self.content[temp_pos];
        // 注释（# 或 ;）不应该结束多行字符串
        if (c == '#' or c == ';') return false;
        // Section 开始
        if (c == '[') return true;
        // 多行字符串结束标识 ``` 不应该结束多行字符串
        if (c == '`' and temp_pos + 2 <= self.content.len and
            self.content[temp_pos + 1] == '`' and
            self.content[temp_pos + 2] == '`') return false;

        // 检查是否是键值对格式（key=value）
        // 向前查找是否包含 '=' 符号
        var has_equals = false;
        var search_pos = temp_pos;
        while (search_pos < self.content.len and self.content[search_pos] != '\n') {
            if (self.content[search_pos] == '=') {
                has_equals = true;
                break;
            }
            search_pos += 1;
        }

        // 只有当这一行包含 '=' 时，才是新配置项
        return has_equals;
    }

    /// 解析多行字符串值（返回原始内容 slice，不分配内存）
    fn parseMultilineValue(self: *Parser) []const u8 {
        // 跳过 = 后的空白字符和开始的 ```
        // 跳过空白
        while (self.pos < self.content.len and
               (self.content[self.pos] == ' ' or
                self.content[self.pos] == '\t')) {
            self.pos += 1;
        }
        // 跳过开始的 ```
        self.pos += 3;

        // 记录内容开始位置
        const content_start = self.pos;

        // 收集多行内容（保持所有内容，包括空行、换行符等）
        while (self.pos < self.content.len) {
            // 检查是否遇到结束的 ```
            if (self.pos + 2 <= self.content.len and
                self.content[self.pos] == '`' and
                self.content[self.pos + 1] == '`' and
                self.content[self.pos + 2] == '`') {

                // 找到结束标识，返回原始内容
                const content = self.content[content_start..self.pos];
                self.pos += 3; // 跳过结束的 ```
                return content;
            }

            // 检查是否遇到新配置项（容错处理）
            // 只有在新行开头时才检查，避免在内容中间误判
            if (self.pos > 0 and self.content[self.pos - 1] == '\n') {
                if (self.isNewConfigItem()) {
                    // 新配置项代表多行字符串结束
                    const content = self.content[content_start..self.pos];
                    return content;
                }
            }

            self.pos += 1;
        }

        // 到达文件尾（容错处理）
        const content = self.content[content_start..self.pos];
        return content;
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

    /// 设置 schema 的文档字段（从累积的注释中提取 title 和 description）
    fn setSchemaDocumentation(self: *Parser, schema: *Schema) !void {
        if (self.pending_comments.items.len == 0) {
            return;
        }

        // 第一遍遍历：处理title并计算description所需的总大小
        var title_value: ?[]const u8 = null;
        var desc_count: usize = 0;
        var total_desc_size: usize = 0;

        for (self.pending_comments.items) |comment| {
            if (std.mem.startsWith(u8, comment, "@title")) {
                // 提取title值
                const title = trimAll(comment["@title".len..]);
                if (title.len > 0) {
                    title_value = title;
                }
            } else {
                // 计算description大小（包括换行符）
                total_desc_size += comment.len + 1;
                desc_count += 1;
            }
        }

        // 设置title
        if (title_value) |title| {
            schema.title = try self.allocator.dupe(u8, title);
        }

        // 设置description（单次分配）
        if (desc_count > 0) {
            // 调整大小（移除最后一个换行符）
            if (total_desc_size > 0) total_desc_size -= 1;

            const desc_buf = try self.allocator.alloc(u8, total_desc_size);
            var offset: usize = 0;
            var current_desc: usize = 0;

            // 第二遍遍历：拷贝description内容
            for (self.pending_comments.items) |comment| {
                if (!std.mem.startsWith(u8, comment, "@title")) {
                    @memcpy(desc_buf[offset..][0..comment.len], comment);
                    offset += comment.len;

                    // 添加换行符（除了最后一个）
                    if (current_desc < desc_count - 1) {
                        desc_buf[offset] = '\n';
                        offset += 1;
                    }
                    current_desc += 1;
                }
            }

            schema.description = desc_buf[0..offset];
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

    fn trimAll(s: []const u8) []const u8 {
        // 使用标准库的trim函数，功能相同但更高效且经过充分测试
        return std.mem.trim(u8, s, " \t\r\n");
    }

    fn trimLeft(s: []const u8) []const u8 {
        // 去除字符串左侧的空白字符
        var start: usize = 0;
        while (start < s.len and (s[start] == ' ' or s[start] == '\t' or s[start] == '\r')) {
            start += 1;
        }
        return s[start..];
    }

    /// 提取值（不再支持行尾注释）
    fn extractValueWithoutComment(s: []const u8) []const u8 {
        return trimAll(s);
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

    // Test section keys using section.key syntax
    try std.testing.expectEqualStrings("value1", ini.get("section1.key1").?);
    try std.testing.expectEqualStrings("quoted value", ini.get("section1.key2").?);
    try std.testing.expectEqualStrings("value3", ini.get("section2.key3").?);
}

test "save and load" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.set("section1.key1", "value1");
    try ini.set("section1.key2", "value2");

    const string = try ini.saveToString(allocator);
    defer allocator.free(string);

    var ini2 = Ini.init(allocator);
    defer ini2.deinit();
    try ini2.loadFromString(string);

    try std.testing.expectEqualStrings("value", ini2.get("global").?);
    try std.testing.expectEqualStrings("value1", ini2.get("section1.key1").?);
    try std.testing.expectEqualStrings("value2", ini2.get("section1.key2").?);
}

test "has() method" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.set("section1.key1", "value1");
    try ini.set("section1.key2", "value2");

    // Test global keys
    try std.testing.expect(ini.has("global"));
    try std.testing.expect(!ini.has("nonexistent"));

    // Test section keys
    try std.testing.expect(ini.has("section1.key1"));
    try std.testing.expect(ini.has("section1.key2"));
    try std.testing.expect(!ini.has("section1.nonexistent"));

    // Test nonexistent section
    try std.testing.expect(!ini.has("section2.key1"));
}

test "remove() method" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.set("section1.key1", "value1");
    try ini.set("section1.key2", "value2");

    // Test removing global keys
    try std.testing.expect(ini.remove("global"));
    try std.testing.expect(!ini.has("global"));
    try std.testing.expect(!ini.remove("nonexistent"));

    // Test removing section keys
    try std.testing.expect(ini.remove("section1.key1"));
    try std.testing.expect(!ini.has("section1.key1"));
    try std.testing.expect(ini.has("section1.key2"));

    // Test removing nonexistent key
    try std.testing.expect(!ini.remove("section1.nonexistent"));
}

test "add() method with Schema" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // Create Schemas with explicit types
    var schema = try Schema.initWithType(allocator, "test", "42", DataType.i64);
    defer schema.deinit(allocator);

    // Add to global (deep copy is made)
    try ini.add("count", schema);
    try std.testing.expect(ini.has("count"));
    try std.testing.expectEqual(@as(i64, 42), ini.getInt("count") catch unreachable);

    // Add to section
    var schema2 = try Schema.initWithType(allocator, "flag", "true", DataType.bool);
    defer schema2.deinit(allocator);

    try ini.add("settings.enabled", schema2);
    try std.testing.expect(ini.has("settings.enabled"));
    try std.testing.expectEqual(true, ini.getBool("settings.enabled") catch unreachable);

    // Test replacing existing key
    var schema3 = try Schema.initWithType(allocator, "test", "100", DataType.i64);
    defer schema3.deinit(allocator);

    try ini.add("count", schema3);
    try std.testing.expectEqual(@as(i64, 100), ini.getInt("count") catch unreachable);
}

test "has() method with section support" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.set("section1.key1", "value1");
    try ini.set("section2.key2", "value2");

    // Test global keys
    try std.testing.expect(ini.has("global"));
    try std.testing.expect(!ini.has("nonexistent"));

    // Test section keys with <section>.<key> syntax
    try std.testing.expect(ini.has("section1.key1"));
    try std.testing.expect(ini.has("section2.key2"));
    try std.testing.expect(!ini.has("section1.nonexistent"));

    // Test sections with <section> syntax
    try std.testing.expect(ini.has("section1"));
    try std.testing.expect(ini.has("section2"));
    try std.testing.expect(!ini.has("section3"));

    // Test that has() prefers sections over global keys with same name
    // (if both exist, section takes precedence)
    try ini.set("section3", "global_value");
    try std.testing.expect(ini.has("section3")); // Section exists
}

test "remove() method with section support" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.set("section1.key1", "value1");
    try ini.set("section1.key2", "value2");
    try ini.set("section2.key3", "value3");

    // Test removing global keys
    try std.testing.expect(ini.remove("global"));
    try std.testing.expect(!ini.has("global"));
    try std.testing.expect(!ini.remove("nonexistent"));

    // Test removing section keys with <section>.<key> syntax
    try std.testing.expect(ini.remove("section1.key1"));
    try std.testing.expect(!ini.has("section1.key1"));
    try std.testing.expect(ini.has("section1.key2"));

    // Test removing sections with <section> syntax
    try std.testing.expect(ini.remove("section2"));
    try std.testing.expect(!ini.has("section2"));
    try std.testing.expect(!ini.has("section2.key3"));

    // Test that remove() prefers sections over global keys
    try ini.set("section3", "global_value");
    try std.testing.expect(ini.remove("section3")); // Removes section
    try std.testing.expect(!ini.has("section3"));
}
