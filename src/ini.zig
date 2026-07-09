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

// 导入转换器系统
const Converter = @import("converter.zig").Converter;

// 导入字符串操作模块
const string_mod = @import("string.zig");

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
    InvalidValue, // 校验失败
    Overflow, // 数值溢出（转换器使用）
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

/// A single key-value Item with type information
pub const Item = struct {
    key: []const u8,
    value: []const u8,
    datatype: DataType,
    flags: types.ItemFlags,
    /// 标题（从 @title 注释标记解析）
    title: ?[]const u8 = null,
    /// 描述（其他所有普通注释）
    description: ?[]const u8 = null,
    /// 默认值（从 @default 注释标记解析）
    default: ?[]const u8 = null,
    /// 选择项（从 @choices 注释标记解析，多个值用逗号分隔）
    choices: ?[][]const u8 = null,
    /// 值转换器（用于配置文件和内部表示之间的转换）
    converter: ?*const Converter = null,

    /// Create a new Item with automatic type inference
    pub fn init(allocator: Allocator, key: []const u8, value: []const u8) Allocator.Error!Item {
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        return Item{
            .key = key_copy,
            .value = value_copy,
            .datatype = .string, // 移除 DataType.infer，默认为 string (0)
            .flags = .none, // 默认无标志
        };
    }

    /// Create a new Item with explicit type
    pub fn initWithType(allocator: Allocator, key: []const u8, value: []const u8, datatype: DataType) Allocator.Error!Item {
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        return Item{
            .key = key_copy,
            .value = value_copy,
            .datatype = datatype,
            .flags = .none, // 自动类型推断，无需设置标志
        };
    }

    /// Free Item resources
    pub fn deinit(self: *Item, allocator: Allocator) void {
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
        if (self.choices) |items| {
            for (items) |item| allocator.free(item);
            allocator.free(items);
        }
    }

    /// Free Item resources except key (used when key is owned by HashMap)
    pub fn deinitWithoutKey(self: *Item, allocator: Allocator) void {
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
        if (self.choices) |items| {
            for (items) |item| allocator.free(item);
            allocator.free(items);
        }
    }

    /// 获取值，支持默认值回退
    /// 当 value 为空时，如果 default 不为空，则返回 default
    /// 返回值始终非空（至少返回原始 value）
    pub fn getValue(self: *const Item) []const u8 {
        // 先检查 value 是否为空（直接检查长度，避免重复 trim）
        if (self.value.len > 0) {
            return self.value; // value 有内容，返回 value
        }

        // value 为空，尝试使用 default
        if (self.default) |default_value| {
            if (default_value.len > 0) {
                return default_value; // default 有内容，返回 default
            }
        }

        // 都为空，返回原始 value（空字符串）
        return self.value;
    }

    /// Get value as boolean
    pub fn asBoolean(self: *const Item) !bool {
        return TypeConverter.toBoolean(self.getValue());
    }

    /// Get value as number (i64)
    pub fn asNumber(self: *const Item) !i64 {
        return TypeConverter.toNumber(self.getValue());
    }

    /// Get value as float (f64)
    pub fn asFloat(self: *const Item) !f64 {
        return TypeConverter.toFloat(self.getValue());
    }

    /// Get value as string
    pub fn asString(self: *const Item) []const u8 {
        return TypeConverter.toString(self.getValue());
    }

    /// Check if value matches expected type
    pub fn isType(self: *const Item, expected: DataType) bool {
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
    if (string_mod.indexOf(key, ".")) |dot_index| {
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
    items: StringHashMap(Item),
    sections: StringHashMap(Ini),
    options: IniOptions, // 存储加载选项
    original_file_path: ?[]const u8 = null, // 记录原始文件路径，用于自动注释保留
    validators: @import("validate.zig").ValidatorRegistry, // 校验器注册表（公开字段）

    /// Create a new empty Ini structure（默认：内存优化，不加载 description）
    /// **行为变化**：从 v2.0 开始，默认不加载 description 以节省内存
    pub fn init(allocator: Allocator) Ini {
        return .{
            .allocator = allocator,
            .items = StringHashMap(Item).init(allocator),
            .sections = StringHashMap(Ini).init(allocator),
            .options = IniOptions{}, // 默认不加载 description
            .original_file_path = null,
            .validators = @import("validate.zig").ValidatorRegistry.init(allocator),
        };
    }

    /// Create a new empty Ini structure（带完整选项）
    /// 用于需要加载 description 或其他未来扩展功能的场景
    pub fn initWithOptions(allocator: Allocator, options: IniOptions) Ini {
        return .{
            .allocator = allocator,
            .items = StringHashMap(Item).init(allocator),
            .sections = StringHashMap(Ini).init(allocator),
            .options = options,
            .original_file_path = null,
            .validators = @import("validate.zig").ValidatorRegistry.init(allocator),
        };
    }

    /// Free all resources
    pub fn deinit(self: *Ini) void {
        // 释放原始文件路径
        if (self.original_file_path) |path| {
            self.allocator.free(path);
        }

        // Free global entries
        var item_iter = self.items.iterator();
        while (item_iter.next()) |item| {
            // Free Item resources except key (key is owned by HashMap)
            @constCast(item.value_ptr).deinitWithoutKey(self.allocator);
            // Free the key stored in the hash map (also frees Item.key since they share allocation)
            self.allocator.free(item.key_ptr.*);
        }
        self.items.deinit();

        // Free sections (now Inis instead of Sections)
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section| {
            // Recursively deinit the nested Ini
            section.value_ptr.deinit();
            // Free the section name key
            self.allocator.free(section.key_ptr.*);
        }
        self.sections.deinit();

        // 释放 validators
        self.validators.deinit();
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
        // 使用堆分配避免栈溢出（1MB栈缓冲区风险）
        const buffer = try self.allocator.alloc(u8, max_size);
        defer self.allocator.free(buffer);
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
        // 先解析到临时对象，避免解析失败时数据丢失
        var temp_ini = Ini.initWithOptions(self.allocator, self.options);
        defer temp_ini.deinit();

        var parser = Parser{
            .allocator = self.allocator,
            .content = content,
            .pos = 0,
            .ini = &temp_ini,
            .current_section = null,
            .current_section_name = "",
            .pending_comments = undefined, // 将在 parse 中初始化
        };
        try parser.parse();

        // 解析成功，现在清空当前数据并从temp_ini重新加载
        // 清空现有数据
        {
            var item_iter = self.items.iterator();
            while (item_iter.next()) |item| {
                item.value_ptr.deinit(self.allocator);
                self.allocator.free(item.key_ptr.*);
            }
            self.items.clearRetainingCapacity();

            var section_iter = self.sections.iterator();
            while (section_iter.next()) |section| {
                section.value_ptr.deinit();
                self.allocator.free(section.key_ptr.*);
            }
            self.sections.clearRetainingCapacity();
        }

        // 通过add方法重新添加所有数据（会进行深拷贝）
        // 移动全局Items
        var item_iter = temp_ini.items.iterator();
        while (item_iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const item = entry.value_ptr.*;
            try self.addItem(key, item);
        }

        // 移动sections
        var section_iter = temp_ini.sections.iterator();
        while (section_iter.next()) |section_entry| {
            const section_name = section_entry.key_ptr.*;
            const section_ini = section_entry.value_ptr.*;

            var section_item_iter = section_ini.items.iterator();
            while (section_item_iter.next()) |item_entry| {
                const item_key = item_entry.key_ptr.*;
                const item = item_entry.value_ptr.*;
                const full_key = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ section_name, item_key });
                defer self.allocator.free(full_key);
                try self.addItem(full_key, item);
            }
        }
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

    /// 辅助函数：恢复数组字段
    fn restoreFieldArray(allocator: Allocator, target: *?[][]const u8, source: ?[][]const u8) !void {
        if (target.* == null and source != null) {
            var array_copy = try allocator.alloc([]const u8, source.?.len);
            errdefer allocator.free(array_copy);
            for (source.?, 0..) |item, i| {
                array_copy[i] = try allocator.dupe(u8, item);
            }
            target.* = array_copy;
        }
    }

    /// 辅助函数：将 source 中的元数据恢复到 target
    /// 规则：只恢复 target 中对应字段为空的配置项
    fn restoreDescriptions(source: *const Ini, target: *Ini) void {
        // 恢复全局 items 的元数据
        var item_iter = source.items.iterator();
        while (item_iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const source_item = entry.value_ptr.*;

            if (target.items.getPtr(key)) |target_item| {
                // 恢复所有元数据字段
                restoreField(target.allocator, &target_item.description, source_item.description);
                restoreField(target.allocator, &target_item.title, source_item.title);
                restoreField(target.allocator, &target_item.default, source_item.default);
                restoreFieldArray(target.allocator, &target_item.choices, source_item.choices) catch return;
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
        var item_iter = self.items.iterator();
        while (item_iter.next()) |entry| {
            formatItemToBuffer(allocator, &buffer, entry.value_ptr.*) catch |err| {
                return switch (err) {
                    error.Overflow, error.InvalidCharacter, error.InvalidValue => error.OutOfMemory,
                    else => |e| e,
                };
            };
        }

        // Blank line between global and sections
        if (self.items.count() > 0 and self.sections.count() > 0) {
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

            var section_item_iter = section_ini.items.iterator();
            while (section_item_iter.next()) |item| {
                formatItemToBuffer(allocator, &buffer, item.value_ptr.*) catch |err| {
                    return switch (err) {
                        error.Overflow, error.InvalidCharacter, error.InvalidValue => error.OutOfMemory,
                        else => |e| e,
                    };
                };
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

    /// Helper function to format a single Item to buffer
    fn formatItemToBuffer(allocator: Allocator, buffer: *std.ArrayList(u8), item: Item) !void {
        // 1. 先写入 description（普通注释，支持多行）
        if (item.description) |desc| {
            var line_iter = std.mem.splitScalar(u8, desc, '\n');
            while (line_iter.next()) |line| {
                const desc_line = try std.fmt.allocPrint(allocator, "# {s}\n", .{line});
                defer allocator.free(desc_line);
                try buffer.appendSlice(allocator, desc_line);
            }
        }

        // 2. 如果有任何元数据标记，写入空注释行分隔
        const has_metadata = item.title != null or item.default != null or item.choices != null;
        if (has_metadata and item.description != null) {
            try buffer.appendSlice(allocator, "#\n");
        }

        // 3. 写入元数据标记（title, default, choices）
        // 注意：只有非空值才写入对应的标记
        if (item.title) |title| try writeMetadataMark(allocator, buffer, "title", title);
        if (item.default) |def| try writeMetadataMark(allocator, buffer, "default", def);
        if (item.choices) |items| {
            const validate_module = @import("validate.zig");
            const choices_str = try validate_module.join(allocator, items, ",");
            defer allocator.free(choices_str);
            try writeMetadataMark(allocator, buffer, "choices", choices_str);
        }

        // 4. 写入 key = value
        // 应用转换器（如果存在）
        var output_value = item.value;
        if (item.converter) |converter| {
            output_value = try converter.to(item.value);
        }

        const key_value = try std.fmt.allocPrint(allocator, "{s} = {s}\n", .{ item.key, output_value });
        defer allocator.free(key_value);
        try buffer.appendSlice(allocator, key_value);
    }

    /// Write INI content to a writer
    fn writeTo(self: *const Ini, writer: anytype) Error!void {
        // Write global entries first
        var item_iter = self.items.iterator();
        while (item_iter.next()) |item| {
            try writer.print("{s} = {s}\n", .{ item.key_ptr.*, item.value_ptr.value });
        }

        // Write sections (now Inis)
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section| {
            const section_name = section.key_ptr.*;
            const section_ini = section.value_ptr;

            try writer.print("[{s}]\n", .{section_name});

            var item_iter2 = section_ini.items.iterator();
            while (item_iter2.next()) |item| {
                try writer.print("{s} = {s}\n", .{ item.key_ptr.*, item.value_ptr.value });
            }

            try writer.writeByte('\n');
        }
    }

    /// Get a global value as string (supports <section>.<key> syntax)
    /// This method is equivalent to getString() and provides default value fallback support.
    /// For error handling, it returns KeyNotFound error if the key doesn't exist.
    ///
    /// This pairs semantically with set() - both use error union types for consistency.
    pub fn get(self: *const Ini, key: []const u8) ![]const u8 {
        // 直接调用 getString，实现完全等效的行为
        return self.getString(key);
    }

    /// Get global Item（支持 section.key 语法）
    pub fn getItem(self: *const Ini, key: []const u8) ?*const Item {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                // Get from section
                if (self.sections.get(parsed.section)) |section| {
                    return section.getItem(parsed.key);
                }
                return null;
            },
            .global => |global_key| {
                // Get from global Items
                return if (self.items.getPtr(global_key)) |ptr| ptr else null;
            },
        }
    }

    /// 获取指定 key 的转换器（用于内部转换逻辑）
    fn getConverter(self: *Ini, key: []const u8) ?*const Converter {
        if (self.items.get(key)) |item| {
            return item.converter;
        }
        return null;
    }

    /// 校验指定 key 的值（私有方法）
    fn validate(self: *const Ini, key: []const u8, value: []const u8) !void {
        if (self.getItem(key)) |item| {
            if (!self.validators.validate(key, value, item)) {
                std.log.err("校验失败：key '{s}' 的值 '{s}' 不符合要求", .{ key, value });
                return error.InvalidValue;
            }
        }
    }

    /// Get global value as string
    pub fn getString(self: *const Ini, key: []const u8) ![]const u8 {
        if (self.getItem(key)) |item| {
            return item.asString();
        }
        return error.KeyNotFound;
    }

    /// Get global value as number (i64)
    pub fn getNumber(self: *const Ini, key: []const u8) !i64 {
        if (self.getItem(key)) |item| {
            return item.asNumber();
        }
        return error.KeyNotFound;
    }

    /// Get global value as boolean
    pub fn getBoolean(self: *const Ini, key: []const u8) !bool {
        if (self.getItem(key)) |item| {
            return item.asBoolean();
        }
        return error.KeyNotFound;
    }

    /// Get global value as float (f64)
    pub fn getFloat(self: *const Ini, key: []const u8) !f64 {
        if (self.getItem(key)) |item| {
            return item.asFloat();
        }
        return error.KeyNotFound;
    }

    /// Set a value (supports <section>.<key> syntax)
    pub fn set(self: *Ini, key: []const u8, value: []const u8) Error!void {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                // Get or create section Ini
                const section_ini = try self.getOrCreateSectionInternal(parsed.section);
                // Recursively call set on the nested Ini
                try section_ini.set(parsed.key, value);
            },
            .global => |global_key| {
                // 先校验再设置
                try self.validate(global_key, value);

                // Set in global items
                if (self.items.getPtr(global_key)) |item| {
                    // 应用转换器（如果存在）
                    var final_value = value;
                    if (item.converter) |converter| {
                        final_value = try converter.from(value);
                    }

                    // 先分配新内存，成功后再释放旧内存，避免错误时悬空指针
                    const new_value = try self.allocator.dupe(u8, final_value);
                    self.allocator.free(item.value);
                    item.value = new_value;
                    // datatype保持不变，确保类型一致性
                    // title、description、key自动保留，无需处理
                } else {
                    // 应用转换器（如果存在）
                    var final_value = value;
                    if (self.getConverter(global_key)) |converter| {
                        final_value = try converter.from(value);
                    }

                    // 创建临时 Item 用于添加（类型推断）
                    var temp_item = try Item.initWithType(
                        self.allocator,
                        global_key,
                        final_value,
                        DataType.infer(final_value)
                    );
                    defer temp_item.deinit(self.allocator);

                    // 调用 addItem 统一处理添加逻辑
                    try self.addItem(global_key, temp_item);
                }
            },
        }
    }

    /// Check if a key or section exists
    /// Supports:
    /// - <section>.<key> syntax: Check if key exists in section
    /// - <section> syntax: Check if section exists (no dot in name)
    /// - <key> syntax: Check if global key exists (if not a section name)
    pub fn hasItem(self: *const Ini, key_or_section: []const u8) bool {
        switch (parseKey(key_or_section)) {
            .section_key => |parsed| {
                // Check in section
                if (self.sections.get(parsed.section)) |section| {
                    return section.hasItem(parsed.key);
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
                return self.items.contains(global_key);
            },
        }
    }

    /// Remove a key or section
    /// Supports:
    /// - <section>.<key> syntax: Remove key from section
    /// - <section> syntax: Remove entire section and all its keys (no dot in name)
    /// - <key> syntax: Remove global key (if not a section name)
    /// Returns: true if removed, false if not found
    pub fn removeItem(self: *Ini, key_or_section: []const u8) bool {
        switch (parseKey(key_or_section)) {
            .section_key => |parsed| {
                // Remove from section
                if (self.sections.getPtr(parsed.section)) |section| {
                    return section.removeItem(parsed.key);
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
                if (self.items.fetchRemove(global_key)) |kv| {
                    // Free item resources (kv.value is const)
                    // Use deinitWithoutKey since key is owned by HashMap
                    @constCast(&kv.value).deinitWithoutKey(self.allocator);
                    // Free the key stored in the hash map (also frees Item.key since they share allocation)
                    self.allocator.free(kv.key);
                    return true; // Global key removed
                }

                return false; // Not found
            },
        }
    }

    /// Add a complete Item object (supports <section>.<key> syntax)
    /// Unlike set(key, value) which accepts a string value and infers type,
    /// addItem accepts a pre-configured Item object (with explicit type and documentation)
    ///
    /// This method performs a deep copy of the Item object.
    /// The caller is still responsible for deinitializing the original Item.
    pub fn addItem(self: *Ini, key: []const u8, item: Item) Allocator.Error!void {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                // Get or create section
                const section = try self.getOrCreateSectionInternal(parsed.section);

                // Remove old Item if exists
                if (section.items.fetchRemove(parsed.key)) |kv| {
                    const old_item = kv.value;
                    // Call deinit to free old Item's resources (except key, owned by HashMap)
                    @constCast(&old_item).deinitWithoutKey(self.allocator);
                    self.allocator.free(kv.key);
                }

                // Create new Item - key ownership transferred to HashMap later
                const value_copy = try self.allocator.dupe(u8, item.value);

                const new_item = Item{
                    .key = undefined, // Will be set to HashMap key after put
                    .value = value_copy,
                    .datatype = item.datatype,
                    .flags = item.flags, // 复制 flags
                    .title = if (item.title) |title| try self.allocator.dupe(u8, title) else null,
                    .description = if (item.description) |desc| try self.allocator.dupe(u8, desc) else null,
                    .default = if (item.default) |def| try self.allocator.dupe(u8, def) else null,
                    .choices = if (item.choices) |items| blk: {
                        var array_copy = try self.allocator.alloc([]const u8, items.len);
                        errdefer self.allocator.free(array_copy);
                        for (items, 0..) |elem, i| {
                            array_copy[i] = try self.allocator.dupe(u8, elem);
                        }
                        break :blk array_copy;
                    } else null,
                };

                // Put in HashMap - this creates the key copy
                const key_copy = try self.allocator.dupe(u8, parsed.key);
                try section.items.put(key_copy, new_item);

                // Set the Item's key pointer to point to HashMap's key
                // (they now share the same allocation)
                const stored_item = section.items.getPtr(key_copy).?;
                stored_item.key = key_copy;
            },
            .global => |global_key| {
                // Remove old Item if exists
                if (self.items.fetchRemove(global_key)) |kv| {
                    const old_item = kv.value;
                    // Call deinit to free old Item's resources (except key, owned by HashMap)
                    @constCast(&old_item).deinitWithoutKey(self.allocator);
                    self.allocator.free(kv.key);
                }

                // Create new Item - key ownership transferred to HashMap later
                const value_copy = try self.allocator.dupe(u8, item.value);

                const new_item = Item{
                    .key = undefined, // Will be set to HashMap key after put
                    .value = value_copy,
                    .datatype = item.datatype,
                    .flags = item.flags, // 复制 flags
                    .title = if (item.title) |title| try self.allocator.dupe(u8, title) else null,
                    .description = if (item.description) |desc| try self.allocator.dupe(u8, desc) else null,
                    .default = if (item.default) |def| try self.allocator.dupe(u8, def) else null,
                    .choices = if (item.choices) |items| blk: {
                        var array_copy = try self.allocator.alloc([]const u8, items.len);
                        errdefer self.allocator.free(array_copy);
                        for (items, 0..) |elem, i| {
                            array_copy[i] = try self.allocator.dupe(u8, elem);
                        }
                        break :blk array_copy;
                    } else null,
                };

                // Put in HashMap - this creates the key copy
                const key_copy = try self.allocator.dupe(u8, global_key);
                try self.items.put(key_copy, new_item);

                // Set the Item's key pointer to point to HashMap's key
                // (they now share the same allocation)
                const stored_item = self.items.getPtr(key_copy).?;
                stored_item.key = key_copy;
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
            .items = StringHashMap(Item).init(self.allocator),
            .sections = StringHashMap(Ini).init(self.allocator),
            .options = self.options, // 继承父 Ini 的选项
            .original_file_path = null, // section 不继承原始文件路径
            .validators = @import("validate.zig").ValidatorRegistry.init(self.allocator),
        };

        try self.sections.put(name_copy, new_section);
        return self.sections.getPtr(section_name).?;
    }

    /// 遍历所有 Item（全局 + 所有 sections）
    /// context: 用户提供的上下文指针（支持计数器等外部变量修改）
    /// callback: 回调函数，接收 context 指针、section (null 表示全局) 和 Item 指针
    pub fn forEach(self: *const Ini, context_ptr: anytype, comptime callback: anytype) void {
        // 1. 遍历全局 items
        var item_iter = self.items.iterator();
        while (item_iter.next()) |entry| {
            callback(context_ptr, null, entry.value_ptr);
        }

        // 2. 遍历所有 sections
        var section_iter = self.sections.iterator();
        while (section_iter.next()) |section_entry| {
            const section_name = section_entry.key_ptr.*;
            var section_item_iter = section_entry.value_ptr.items.iterator();
            while (section_item_iter.next()) |item_entry| {
                callback(context_ptr, section_name, item_entry.value_ptr);
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
        if (!string_mod.startsWith(comment, "@")) return null;

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
        // 使用trim清理所有空白字符（空格、制表符、回车、换行）
        // 这样 "# @title 1" 和 "# @title        1" 会解析出相同的值
        const value = string_mod.trim(rest[space_index + 1 ..]);

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

        const key_full = string_mod.trim(self.content[key_start..self.pos]);
        self.pos += 1; // Skip '='

        // Skip whitespace after =
        while (self.pos < self.content.len and self.content[self.pos] == ' ') {
            self.pos += 1;
        }

        // 检查当前位置是否以 ``` 开头（多行字符串开始）
        // 先跳过空格检测
        var temp_pos = self.pos;
        while (temp_pos < self.content.len and
            (self.content[temp_pos] == ' ' or self.content[temp_pos] == '\t'))
        {
            temp_pos += 1;
        }

        const is_multiline = (temp_pos + 3 <= self.content.len and
            self.content[temp_pos] == '`' and
            self.content[temp_pos + 1] == '`' and
            self.content[temp_pos + 2] == '`');

        var value: []const u8 = undefined;

        if (is_multiline) {
            // 解析多行字符串（返回原始内容 slice）
            const multiline_content = self.parseMultilineValue();
            // 对 trimAll 后的内容进行内存分配
            const trimmed_multiline = string_mod.trim(multiline_content);
            value = trimmed_multiline;
        } else {
            // 不是多行字符串，读取单行值
            value = self.parseSingleLineValue();

            // 处理引号
            if (value.len >= 2 and string_mod.isQuote(value[0])) {
                if (value[value.len - 1] != value[0]) return Error.UnclosedQuote;
                value = string_mod.unquote(value);
            }
        }

        // Create schema with inferred type (without key - key will be set later)
        const value_copy = try self.allocator.dupe(u8, value);

        var item = Item{
            .key = undefined, // Will be set after put
            .value = value_copy,
            .datatype = DataType.infer(value), // 自动推断类型
            .flags = .none, // 默认无标志
            .title = null,
            .description = null,
        };

        // 设置文档注释（包含 title 和 description）
        try self.setItemDocumentation(&item);

        // 应用转换器（如果存在）
        if (self.ini.getConverter(key_full)) |conv| {
            item.converter = conv;
            const converted = try conv.from(value_copy);
            self.allocator.free(value_copy);
            item.value = try self.allocator.dupe(u8, converted);
            item.datatype = DataType.infer(converted); // 自动推断类型

            // 转换 default 值（如果存在）
            if (item.default) |default_value| {
                const default_converted = try conv.from(default_value);
                // 先分配新内存，成功后再释放旧内存，避免内存泄漏
                const new_default = try self.allocator.dupe(u8, default_converted);
                self.allocator.free(default_value);
                item.default = new_default;
            }
        }

        if (self.current_section) |section| {
            // Put in HashMap - this creates the key copy
            const key_copy = try self.allocator.dupe(u8, key_full);
            try section.items.put(key_copy, item);

            // Set the Item's key pointer to point to HashMap's key
            const stored_item = section.items.getPtr(key_copy).?;
            stored_item.key = key_copy;
        } else {
            // Put in HashMap - this creates the key copy
            const key_copy = try self.allocator.dupe(u8, key_full);
            try self.ini.items.put(key_copy, item);

            // Set the Item's key pointer to point to HashMap's key
            const stored_item = self.ini.items.getPtr(key_copy).?;
            stored_item.key = key_copy;
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
                self.content[temp_pos] == '\t'))
        {
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
                self.content[temp_pos] == '\n'))
        {
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
                self.content[self.pos] == '\t'))
        {
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
                self.content[self.pos + 2] == '`')
            {

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

        // 提取注释内容并使用 trim 删除前后空格
        const comment_raw = self.content[start..self.pos];
        const comment_trimmed = string_mod.trim(comment_raw);

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

        // 计算总大小（带溢出检查）
        var total_size: usize = 0;
        for (self.pending_comments.items) |comment| {
            // 检查加法溢出
            total_size = std.math.add(usize, total_size, comment.len) catch return error.OutOfMemory;
            total_size = std.math.add(usize, total_size, 1) catch return error.OutOfMemory; // 换行符
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

    /// 设置 Item 的文档字段和元数据（从累积的注释中提取）
    fn setItemDocumentation(self: *Parser, item: *Item) !void {
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

                // 处理支持的元数据类型：title, default, choices
                if (std.mem.eql(u8, name, "title")) {
                    item.title = try self.allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, name, "default")) {
                    item.default = try self.allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, name, "choices")) {
                    const validate = @import("validate.zig");
                    item.choices = try validate.split(self.allocator, value, ",");
                }
                // 其他未知标记被忽略
            } else {
                // 不是元数据标记，作为description的一部分
                if (self.ini.options.has(IniOptions.LoadDescription)) {
                    try description_parts.append(self.allocator, try self.allocator.dupe(u8, comment));
                }
            }
        }

        // 合并description（带溢出检查）
        if (description_parts.items.len > 0) {
            var total_size: usize = 0;
            for (description_parts.items, 0..) |part, i| {
                total_size = std.math.add(usize, total_size, part.len) catch return error.OutOfMemory;
                if (i < description_parts.items.len - 1) {
                    total_size = std.math.add(usize, total_size, 1) catch return error.OutOfMemory; // \n
                }
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
            item.description = desc;
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
        while (self.pos < self.content.len and string_mod.isWhitespace(self.content[self.pos])) {
            self.pos += 1;
        }
    }

    /// 提取值（不再支持行尾注释）
    fn extractValueWithoutComment(s: []const u8) []const u8 {
        return string_mod.trim(s);
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
    try std.testing.expectEqualStrings("global_value", try ini.get("global_key"));

    // Test section keys using section.key syntax
    try std.testing.expectEqualStrings("value1", try ini.get("section1.key1"));
    try std.testing.expectEqualStrings("quoted value", try ini.get("section1.key2"));
    try std.testing.expectEqualStrings("value3", try ini.get("section2.key3"));
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

    try std.testing.expectEqualStrings("value", try ini2.get("global"));
    try std.testing.expectEqualStrings("value1", try ini2.get("section1.key1"));
    try std.testing.expectEqualStrings("value2", try ini2.get("section1.key2"));
}

test "has() method" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.set("section1.key1", "value1");
    try ini.set("section1.key2", "value2");

    // Test global keys
    try std.testing.expect(ini.hasItem("global"));
    try std.testing.expect(!ini.hasItem("nonexistent"));

    // Test section keys
    try std.testing.expect(ini.hasItem("section1.key1"));
    try std.testing.expect(ini.hasItem("section1.key2"));
    try std.testing.expect(!ini.hasItem("section1.nonexistent"));

    // Test nonexistent section
    try std.testing.expect(!ini.hasItem("section2.key1"));
}

test "remove() method" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.set("section1.key1", "value1");
    try ini.set("section1.key2", "value2");

    // Test removing global keys
    try std.testing.expect(ini.removeItem("global"));
    try std.testing.expect(!ini.hasItem("global"));
    try std.testing.expect(!ini.removeItem("nonexistent"));

    // Test removing section keys
    try std.testing.expect(ini.removeItem("section1.key1"));
    try std.testing.expect(!ini.hasItem("section1.key1"));
    try std.testing.expect(ini.hasItem("section1.key2"));

    // Test removing nonexistent key
    try std.testing.expect(!ini.removeItem("section1.nonexistent"));
}

test "add() method with Item" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // Create Items with explicit types
    var item = try Item.initWithType(allocator, "test", "42", DataType.number);
    defer item.deinit(allocator);

    // Add to global (deep copy is made)
    try ini.addItem("count", item);
    try std.testing.expect(ini.hasItem("count"));
    try std.testing.expectEqual(@as(i64, 42), ini.getNumber("count") catch unreachable);

    // Add to section
    var item2 = try Item.initWithType(allocator, "flag", "true", DataType.boolean);
    defer item2.deinit(allocator);

    try ini.addItem("settings.enabled", item2);
    try std.testing.expect(ini.hasItem("settings.enabled"));
    try std.testing.expectEqual(true, ini.getBoolean("settings.enabled") catch unreachable);

    // Test replacing existing key
    var item3 = try Item.initWithType(allocator, "test", "100", DataType.number);
    defer item3.deinit(allocator);

    try ini.addItem("count", item3);
    try std.testing.expectEqual(@as(i64, 100), ini.getNumber("count") catch unreachable);
}

test "has() method with section support" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.set("section1.key1", "value1");
    try ini.set("section2.key2", "value2");

    // Test global keys
    try std.testing.expect(ini.hasItem("global"));
    try std.testing.expect(!ini.hasItem("nonexistent"));

    // Test section keys with <section>.<key> syntax
    try std.testing.expect(ini.hasItem("section1.key1"));
    try std.testing.expect(ini.hasItem("section2.key2"));
    try std.testing.expect(!ini.hasItem("section1.nonexistent"));

    // Test sections with <section> syntax
    try std.testing.expect(ini.hasItem("section1"));
    try std.testing.expect(ini.hasItem("section2"));
    try std.testing.expect(!ini.hasItem("section3"));

    // Test that has() prefers sections over global keys with same name
    // (if both exist, section takes precedence)
    try ini.set("section3", "global_value");
    try std.testing.expect(ini.hasItem("section3")); // Section exists
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
    try std.testing.expect(ini.removeItem("global"));
    try std.testing.expect(!ini.hasItem("global"));
    try std.testing.expect(!ini.removeItem("nonexistent"));

    // Test removing section keys with <section>.<key> syntax
    try std.testing.expect(ini.removeItem("section1.key1"));
    try std.testing.expect(!ini.hasItem("section1.key1"));
    try std.testing.expect(ini.hasItem("section1.key2"));

    // Test removing sections with <section> syntax
    try std.testing.expect(ini.removeItem("section2"));
    try std.testing.expect(!ini.hasItem("section2"));
    try std.testing.expect(!ini.hasItem("section2.key3"));

    // Test that remove() prefers sections over global keys
    try ini.set("section3", "global_value");
    try std.testing.expect(ini.removeItem("section3")); // Removes section
    try std.testing.expect(!ini.hasItem("section3"));
}

test "choices 数组解析" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @choices red,green,blue
        \\color = red
    ;

    try ini.loadFromString(content);

    // 验证 choices 数组正确解析
    const item = ini.getItem("color").?;
    try std.testing.expect(item.choices != null);
    try std.testing.expectEqual(@as(usize, 3), item.choices.?.len);
    try std.testing.expectEqualStrings("red", item.choices.?[0]);
    try std.testing.expectEqualStrings("green", item.choices.?[1]);
    try std.testing.expectEqualStrings("blue", item.choices.?[2]);
}

test "choices 数组序列化" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 创建带 choices 的 Item
    var item = try Item.init(allocator, "color", "red");

    // 手动设置 choices 数组
    const choices = [_][]const u8{ "red", "green", "blue" };
    var choices_copy = try allocator.alloc([]const u8, choices.len);
    for (choices, 0..) |choice, i| {
        choices_copy[i] = try allocator.dupe(u8, choice);
    }
    item.choices = choices_copy;

    try ini.addItem("color", item);

    // 注意：item.deinit 会释放 choices_copy，所以不需要额外释放
    item.deinit(allocator);

    // 序列化
    const serialized = try ini.saveToString(allocator);
    defer allocator.free(serialized);

    // 验证序列化结果包含 @choices 标记
    try std.testing.expect(std.mem.indexOf(u8, serialized, "@choices") != null);
    try std.testing.expect(std.mem.indexOf(u8, serialized, "red,green,blue") != null);
}

test "内置 choices 校验器" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @choices red,green,blue
        \\color = red
    ;

    try ini.loadFromString(content);

    // 测试有效值
    try ini.set("color", "green");
    try std.testing.expectEqualStrings("green", try ini.get("color"));

    // 测试无效值（应该失败）
    try std.testing.expectError(error.InvalidValue, ini.set("color", "yellow"));
}

test "添加自定义校验器" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 创建自定义校验器
    const RangeValidator = struct {
        min: u64,
        max: u64,

        fn validateImpl(value: []const u8, item: *const Item) bool {
            _ = item;
            const num = std.fmt.parseInt(u64, value, 10) catch return false;
            return num >= 1024 and num <= 65535;
        }
    };

    const validator = @import("validate.zig").Validator.init("range", RangeValidator.validateImpl);

    // 添加校验器到 port 键
    try ini.validators.add("port", validator);

    // 先创建一个 port 键
    try ini.set("port", "8080");

    // 测试有效值
    try ini.set("port", "8080");
    try std.testing.expectEqualStrings("8080", try ini.get("port"));

    // 测试无效值（应该失败）
    try std.testing.expectError(error.InvalidValue, ini.set("port", "100"));
}

test "validators API - add 和 remove" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 创建测试校验器
    const TestValidator = struct {
        fn validateImpl(value: []const u8, item: *const Item) bool {
            _ = item;
            return std.mem.eql(u8, value, "ok");
        }
    };

    const validator1 = @import("validate.zig").Validator.init("test1", TestValidator.validateImpl);
    const validator2 = @import("validate.zig").Validator.init("test2", TestValidator.validateImpl);

    // 添加校验器
    try ini.validators.add("key", validator1);
    try ini.validators.add("key", validator2);

    // 创建测试键
    try ini.set("key", "ok");

    // 测试两个校验器都生效
    try std.testing.expectEqualStrings("ok", try ini.get("key"));

    // 移除特定校验器
    ini.validators.remove("key", "test1");
    try ini.set("key", "ok"); // 应该仍然有效

    // 移除所有校验器
    ini.validators.remove("key", "");
    try ini.set("key", "any_value"); // 现在应该接受任何值
}

test "choices 校验器 + 自定义校验器组合" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \\# @choices admin,user,guest
        \\role = user
    ;

    try ini.loadFromString(content);

    // 添加自定义校验器（只允许 user 和 guest）
    const RoleValidator = struct {
        fn validateImpl(value: []const u8, item: *const Item) bool {
            _ = item;
            // 只允许 user 和 guest
            return std.mem.eql(u8, value, "user") or std.mem.eql(u8, value, "guest");
        }
    };

    const validator = @import("validate.zig").Validator.init("role", RoleValidator.validateImpl);

    try ini.validators.add("role", validator);

    // 测试 user（通过 choices 和 role 校验）
    try ini.set("role", "user");

    // 测试 guest（通过 choices 和 role 校验）
    try ini.set("role", "guest");

    // 测试 admin（通过 choices 但失败 role 校验）
    try std.testing.expectError(error.InvalidValue, ini.set("role", "admin"));

    // 测试 yellow（失败 choices 校验）
    try std.testing.expectError(error.InvalidValue, ini.set("role", "yellow"));
}

// 转换器测试
test "basic converter functionality" {
    const allocator = std.testing.allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    // 定义日志级别转换器
    const log_level_converter = struct {
        fn from(input: []const u8) ![]const u8 {
            if (std.mem.eql(u8, input, "debug")) return "1";
            if (std.mem.eql(u8, input, "info")) return "2";
            if (std.mem.eql(u8, input, "warn")) return "3";
            if (std.mem.eql(u8, input, "error")) return "4";
            return error.InvalidValue;
        }
        fn to(input: []const u8) ![]const u8 {
            const num = try std.fmt.parseInt(u8, input, 10);
            return switch (num) {
                1 => "debug",
                2 => "info",
                3 => "warn",
                4 => "error",
                else => error.InvalidValue,
            };
        }
    };

    const converter = Converter{
        .from = log_level_converter.from,
        .to = log_level_converter.to,
    };

    // 加载配置
    const config =
        \\# 日志级别
        \\# @choices debug,info,warn,error
        \\log_level = error
    ;
    try ini.loadFromString(config);

    // 设置转换器并手动应用转换
    if (ini.items.getPtr("log_level")) |item| {
        item.converter = &converter;
        // 手动应用转换到现有值
        const current_value = item.value;
        const converted = try converter.from(current_value);
        ini.allocator.free(item.value);
        item.value = try ini.allocator.dupe(u8, converted);
        item.datatype = DataType.infer(converted);
    }

    // 验证转换后的值
    const value = try ini.get("log_level");
    try std.testing.expectEqualStrings("4", value);

    std.debug.print("  ✓ 转换器基本功能测试通过\n", .{});
}
