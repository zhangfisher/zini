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

/// Ini 配置选项 - 位枚举
pub const IniOptions = struct {
    /// 位标志定义
    pub const LoadDescription: u32 = 1; // 加载 description 注释（默认关闭）

    flags: u32 = 0, // 默认值：不加载 description

    /// 创建加载 description 的选项（保留完整注释）
    pub fn withDescription() IniOptions {
        return .{ .flags = LoadDescription };
    }

    /// 检查是否设置了某个标志
    pub fn has(self: IniOptions, flag: u32) bool {
        return (self.flags & flag) != 0;
    }
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
    /// 默认值（从 @default 注释标记解析）
    default: ?[]const u8 = null,
    /// 枚举选项（从 @enum 注释标记解析，多个值用逗号分隔）
    @"enum": ?[]const u8 = null,

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
        if (self.default) |default_text| {
            allocator.free(default_text);
        }
        if (self.@"enum") |enum_text| {
            allocator.free(enum_text);
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
        if (self.default) |default_text| {
            allocator.free(default_text);
        }
        if (self.@"enum") |enum_text| {
            allocator.free(enum_text);
        }
    }

    /// 获取值，支持默认值回退
    /// 当 value 为空时，如果 default 不为空，则返回 default
    /// 返回值始终非空（至少返回原始 value）
    pub fn getValue(self: *const Schema) []const u8 {
        // 先检查 value 是否为空（直接检查长度，避免重复 trim）
        if (self.value.len > 0) {
            return self.value;  // value 有内容，返回 value
        }

        // value 为空，尝试使用 default
        if (self.default) |default_value| {
            if (default_value.len > 0) {
                return default_value;  // default 有内容，返回 default
            }
        }

        // 都为空，返回原始 value（空字符串）
        return self.value;
    }

    /// Get value as boolean
    pub fn asBool(self: *const Schema) !bool {
        return TypeConverter.toBool(self.getValue());
    }

    /// Get value as u8
    pub fn asU8(self: *const Schema) !u8 {
        return TypeConverter.toU8(self.getValue());
    }

    /// Get value as u16
    pub fn asU16(self: *const Schema) !u16 {
        return TypeConverter.toU16(self.getValue());
    }

    /// Get value as u32
    pub fn asU32(self: *const Schema) !u32 {
        return TypeConverter.toU32(self.getValue());
    }

    /// Get value as u64
    pub fn asU64(self: *const Schema) !u64 {
        return TypeConverter.toU64(self.getValue());
    }

    /// Get value as i8
    pub fn asI8(self: *const Schema) !i8 {
        return TypeConverter.toI8(self.getValue());
    }

    /// Get value as i16
    pub fn asI16(self: *const Schema) !i16 {
        return TypeConverter.toI16(self.getValue());
    }

    /// Get value as i32
    pub fn asI32(self: *const Schema) !i32 {
        return TypeConverter.toI32(self.getValue());
    }

    /// Get value as i64
    pub fn asI64(self: *const Schema) !i64 {
        return TypeConverter.toI64(self.getValue());
    }

    /// Get value as f32
    pub fn asF32(self: *const Schema) !f32 {
        return TypeConverter.toF32(self.getValue());
    }

    /// Get value as f64
    pub fn asF64(self: *const Schema) !f64 {
        return TypeConverter.toF64(self.getValue());
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
        return TypeConverter.toString(self.getValue());
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
    options: IniOptions, // 存储加载选项
    original_file_path: ?[]const u8 = null, // 记录原始文件路径，用于自动注释保留

    /// Create a new empty Ini structure（默认：内存优化，不加载 description）
    /// **行为变化**：从 v2.0 开始，默认不加载 description 以节省内存
    pub fn init(allocator: Allocator) Ini {
        return .{
            .allocator = allocator,
            .schemas = StringHashMap(Schema).init(allocator),
            .sections = StringHashMap(Ini).init(allocator),
            .options = IniOptions{}, // 默认不加载 description
            .original_file_path = null,
        };
    }

    /// Create a new empty Ini structure（带完整选项）
    /// 用于需要加载 description 或其他未来扩展功能的场景
    pub fn initWithOptions(allocator: Allocator, options: IniOptions) Ini {
        return .{
            .allocator = allocator,
            .schemas = StringHashMap(Schema).init(allocator),
            .sections = StringHashMap(Ini).init(allocator),
            .options = options,
            .original_file_path = null,
        };
    }

    /// Free all resources
    pub fn deinit(self: *Ini) void {
        // 释放原始文件路径
        if (self.original_file_path) |path| {
            self.allocator.free(path);
        }

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
        // 记录原始文件路径（用于自动注释保留）
        if (self.original_file_path) |old_path| {
            self.allocator.free(old_path);
        }
        self.original_file_path = self.allocator.dupe(u8, path) catch |err| {
            self.original_file_path = null;
            return err;
        };

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

    /// Save INI to file（自动处理注释保留）
    pub fn save(self: *Ini, path: []const u8) Error!void {
        // 尝试从原文件恢复缺失的注释
        if (self.original_file_path) |original_path| {
            _ = self.tryRestoreFromOriginal(original_path);
        }

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

    /// 尝试从原文件恢复缺失的元数据（仅恢复字段为空的项）
    fn tryRestoreFromOriginal(self: *Ini, path: []const u8) bool {
        // 创建临时实例加载原文件的元数据
        var temp_ini = Ini.initWithOptions(self.allocator, IniOptions.withDescription());
        defer temp_ini.deinit();

        // 尝试加载原文件（如果文件不存在或加载失败，返回 false）
        temp_ini.load(path) catch {
            return false;
        };

        // 恢复元数据到当前实例（只恢复对应字段为空的项）
        restoreDescriptions(&temp_ini, self);
        return true;
    }

    /// 辅助函数：恢复单个元数据字段
    fn restoreField(allocator: Allocator, target_field: *?[]const u8, source_field: ?[]const u8) void {
        if (target_field.* == null and source_field != null) {
            target_field.* = allocator.dupe(u8, source_field.?) catch return;
        }
    }

    /// 辅助函数：将 source 中的元数据恢复到 target
    /// 规则：只恢复 target 中对应字段为空的配置项
    fn restoreDescriptions(source: *const Ini, target: *Ini) void {
        // 恢复全局 schemas 的元数据
        var schema_iter = source.schemas.iterator();
        while (schema_iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const source_schema = entry.value_ptr.*;

            if (target.schemas.getPtr(key)) |target_schema| {
                // 恢复所有元数据字段
                restoreField(target.allocator, &target_schema.description, source_schema.description);
                restoreField(target.allocator, &target_schema.title, source_schema.title);
                restoreField(target.allocator, &target_schema.default, source_schema.default);
                restoreField(target.allocator, &target_schema.@"enum", source_schema.@"enum");
            }
        }

        // 恢复 sections 的元数据
        var section_iter = source.sections.iterator();
        while (section_iter.next()) |entry| {
            const section_name = entry.key_ptr.*;
            const source_section = entry.value_ptr.*;

            if (target.sections.getPtr(section_name)) |target_section| {
                restoreDescriptions(&source_section, target_section);
            }
        }
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

    /// Helper function to write a metadata mark line
    fn writeMetadataMark(allocator: Allocator, buffer: *std.ArrayList(u8), mark_name: []const u8, value: []const u8) !void {
        const line = try std.fmt.allocPrint(allocator, "# @{s} {s}\n", .{ mark_name, value });
        defer allocator.free(line);
        try buffer.appendSlice(allocator, line);
    }

    /// Helper function to format a single schema to buffer
    fn formatSchemaToBuffer(allocator: Allocator, buffer: *std.ArrayList(u8), schema: Schema) !void {
        // 1. 先写入 description（普通注释，支持多行）
        if (schema.description) |desc| {
            var line_iter = std.mem.splitScalar(u8, desc, '\n');
            while (line_iter.next()) |line| {
                const desc_line = try std.fmt.allocPrint(allocator, "# {s}\n", .{line});
                defer allocator.free(desc_line);
                try buffer.appendSlice(allocator, desc_line);
            }
        }

        // 2. 如果有任何元数据标记，写入空注释行分隔
        const has_metadata = schema.title != null or schema.default != null or schema.@"enum" != null;
        if (has_metadata and schema.description != null) {
            try buffer.appendSlice(allocator, "#\n");
        }

        // 3. 写入元数据标记（title, default, enum）
        // 注意：只有非空值才写入对应的标记
        if (schema.title) |title| try writeMetadataMark(allocator, buffer, "title", title);
        if (schema.default) |def| try writeMetadataMark(allocator, buffer, "default", def);
        if (schema.@"enum") |enm| try writeMetadataMark(allocator, buffer, "enum", enm);

        // 4. 写入 key = value
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

    /// 泛型类型获取辅助函数
    /// 使用 comptime 和 switch 语句消除样板代码
    pub fn getTyped(comptime T: type, self: *const Ini, key: []const u8) !T {
        if (self.getSchema(key)) |schema| {
            // 使用 switch 语句分发到对应的 Schema 方法
            return switch (T) {
                bool => schema.asBool(),
                u8 => schema.asU8(),
                u16 => schema.asU16(),
                u32 => schema.asU32(),
                u64 => schema.asU64(),
                i8 => schema.asI8(),
                i16 => schema.asI16(),
                i32 => schema.asI32(),
                i64 => schema.asI64(),
                f32 => schema.asF32(),
                f64 => schema.asF64(),
                []const u8 => schema.asString(),
                else => @compileError("Type " ++ @typeName(T) ++ " is not supported"),
            };
        }
        return error.KeyNotFound;
    }

    /// Get global value as boolean
    pub fn getBool(self: *const Ini, key: []const u8) !bool {
        return getTyped(bool, self, key);
    }

    /// Get global value as u8
    pub fn getU8(self: *const Ini, key: []const u8) !u8 {
        return getTyped(u8, self, key);
    }

    /// Get global value as u16
    pub fn getU16(self: *const Ini, key: []const u8) !u16 {
        return getTyped(u16, self, key);
    }

    /// Get global value as u32
    pub fn getU32(self: *const Ini, key: []const u8) !u32 {
        return getTyped(u32, self, key);
    }

    /// Get global value as u64
    pub fn getU64(self: *const Ini, key: []const u8) !u64 {
        return getTyped(u64, self, key);
    }

    /// Get global value as i8
    pub fn getI8(self: *const Ini, key: []const u8) !i8 {
        return getTyped(i8, self, key);
    }

    /// Get global value as i16
    pub fn getI16(self: *const Ini, key: []const u8) !i16 {
        return getTyped(i16, self, key);
    }

    /// Get global value as i32
    pub fn getI32(self: *const Ini, key: []const u8) !i32 {
        return getTyped(i32, self, key);
    }

    /// Get global value as i64
    pub fn getI64(self: *const Ini, key: []const u8) !i64 {
        return getTyped(i64, self, key);
    }

    /// Get global value as f32
    pub fn getF32(self: *const Ini, key: []const u8) !f32 {
        return getTyped(f32, self, key);
    }

    /// Get global value as f64
    pub fn getF64(self: *const Ini, key: []const u8) !f64 {
        return getTyped(f64, self, key);
    }

    /// Get global value as integer (generic)
    pub fn getInt(self: *const Ini, key: []const u8) !i64 {
        return getTyped(i64, self, key);
    }

    /// Get global value as float (generic)
    pub fn getFloat(self: *const Ini, key: []const u8) !f64 {
        return getTyped(f64, self, key);
    }

    /// Get global value as string
    pub fn getString(self: *const Ini, key: []const u8) ![]const u8 {
        return getTyped([]const u8, self, key);
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
                if (self.schemas.getPtr(global_key)) |schema| {
                    // 直接修改现有Schema，保持datatype、title、description、key不变
                    self.allocator.free(schema.value);
                    schema.value = try self.allocator.dupe(u8, value);
                    // datatype保持不变，确保类型一致性
                    // title、description、key自动保留，无需处理
                } else {
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
                }
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
                    .default = if (schema.default) |def| try self.allocator.dupe(u8, def) else null,
                    .@"enum" = if (schema.@"enum") |enm| try self.allocator.dupe(u8, enm) else null,
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
                    .default = if (schema.default) |def| try self.allocator.dupe(u8, def) else null,
                    .@"enum" = if (schema.@"enum") |enm| try self.allocator.dupe(u8, enm) else null,
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
            .options = self.options, // 继承父 Ini 的选项
            .original_file_path = null, // section 不继承原始文件路径
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

    /// 解析元数据标记（格式：@name value）
    /// 返回：{ name, value } 或 null（如果不是元数据标记）
    /// 注意：value部分使用trimAll清理所有空白字符，兼容各种空格格式
    fn parseMetadataMark(comment: []const u8) ?struct { name: []const u8, value: []const u8 } {
        if (!std.mem.startsWith(u8, comment, "@")) return null;

        const rest = comment[1..]; // 跳过@
        // 查找第一个空白字符（空格或tab）来分隔名称和值
        var separator_index: ?usize = null;
        for (rest, 0..) |c, i| {
            if (c == ' ' or c == '\t') {
                separator_index = i;
                break;
            }
        }

        const space_index = separator_index orelse return null;

        const name = rest[0..space_index];
        // 使用trimAll清理所有空白字符（空格、制表符、回车、换行）
        // 这样 "# @title 1" 和 "# @title        1" 会解析出相同的值
        const value = trimAll(rest[space_index + 1 ..]);

        if (value.len == 0) return null; // 空值无效

        return .{ .name = name, .value = value };
    }

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

    /// 设置 schema 的文档字段和元数据（从累积的注释中提取）
    fn setSchemaDocumentation(self: *Parser, schema: *Schema) !void {
        if (self.pending_comments.items.len == 0) {
            return;
        }

        // 用于累积非元数据的普通注释（description）
        var description_parts = std.ArrayList([]const u8).empty;
        defer {
            for (description_parts.items) |part| self.allocator.free(part);
            description_parts.deinit(self.allocator);
        }

        // 处理所有注释行
        for (self.pending_comments.items) |comment| {
            // 尝试解析为元数据标记
            if (parseMetadataMark(comment)) |metadata| {
                const name = metadata.name;
                const value = metadata.value;

                // 处理支持的元数据类型：title, default, enum
                if (std.mem.eql(u8, name, "title")) {
                    schema.title = try self.allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, name, "default")) {
                    schema.default = try self.allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, name, "enum")) {
                    schema.@"enum" = try self.allocator.dupe(u8, value);
                }
                // 其他未知标记被忽略
            } else {
                // 不是元数据标记，作为description的一部分
                if (self.ini.options.has(IniOptions.LoadDescription)) {
                    try description_parts.append(self.allocator, try self.allocator.dupe(u8, comment));
                }
            }
        }

        // 合并description
        if (description_parts.items.len > 0) {
            var total_size: usize = 0;
            for (description_parts.items, 0..) |part, i| {
                total_size += part.len;
                if (i < description_parts.items.len - 1) total_size += 1; // \n
            }

            const desc = try self.allocator.alloc(u8, total_size);
            var offset: usize = 0;
            for (description_parts.items, 0..) |part, i| {
                @memcpy(desc[offset..][0..part.len], part);
                offset += part.len;
                if (i < description_parts.items.len - 1) {
                    desc[offset] = '\n';
                    offset += 1;
                }
            }
            schema.description = desc;
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
