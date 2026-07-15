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
    MissingKey, // Item.key 为 null 时返回（initWithItems 使用）
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
    key: ?[]const u8 = null,
    value: ?[]const u8 = null,
    datatype: ?DataType = null,
    flags: ?types.ItemFlags = null,
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
    /// 验证器名称数组（指定该 Item 配置了哪些验证器）
    validators: ?[][]const u8 = null,

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
        if (self.key) |k| allocator.free(k);
        if (self.value) |v| allocator.free(v);
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
        if (self.validators) |validator_names| {
            for (validator_names) |name| allocator.free(name);
            allocator.free(validator_names);
        }
    }

    /// Free Item resources except key (used when key is owned by HashMap)
    pub fn deinitWithoutKey(self: *Item, allocator: Allocator) void {
        if (self.value) |v| allocator.free(v);
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
        if (self.validators) |validator_names| {
            for (validator_names) |name| allocator.free(name);
            allocator.free(validator_names);
        }
    }

    /// 获取值，支持默认值回退
    /// 当 value 为 null 或空时，如果 default 不为空，则返回 default
    /// 返回值始终非空（至少返回空字符串）
    pub fn getValue(self: *const Item) []const u8 {
        // 先检查 value 是否有值
        if (self.value) |v| {
            if (v.len > 0) {
                return v; // value 有内容，返回 value
            }
        }

        // value 为 null 或空，尝试使用 default
        if (self.default) |default_value| {
            if (default_value.len > 0) {
                return default_value; // default 有内容，返回 default
            }
        }

        // 都为空，返回空字符串
        return "";
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

    /// 为 Item 添加验证器名称（自动初始化 validators 数组）
    /// 使用全局 C allocator，无需传递 allocator 参数
    pub fn addValidator(self: *Item, name: []const u8) !void {
        const allocator = std.heap.c_allocator;

        // 自动初始化 validators 数组
        if (self.validators == null) {
            self.validators = try allocator.alloc([]const u8, 0);
        }

        // 添加新的验证器名称
        const old_len = self.validators.?.len;
        const new_validators = try allocator.realloc(self.validators.?, old_len + 1);
        new_validators[old_len] = try allocator.dupe(u8, name);
        self.validators = new_validators;
    }

    /// 从 Item 移除验证器名称
    /// 使用全局 C allocator，无需传递 allocator 参数
    pub fn removeValidator(self: *Item, name: []const u8) !void {
        const allocator = std.heap.c_allocator;

        if (self.validators == null) return;

        const validator_names = self.validators.?;

        // 查找要删除的验证器索引
        const found_index = for (validator_names, 0..) |validator_name, i| {
            if (std.mem.eql(u8, validator_name, name)) {
                break i;
            }
        } else {
            return; // 未找到，直接返回
        };

        // 释放要删除的验证器名称
        allocator.free(validator_names[found_index]);

        // 创建新数组，复制前后元素（跳过要删除的）
        const new_len = validator_names.len - 1;
        if (new_len > 0) {
            const new_validators = try allocator.alloc([]const u8, new_len);

            // 复制前面的元素
            for (validator_names[0..found_index], 0..) |v, i| {
                new_validators[i] = v;
            }

            // 复制后面的元素
            for (validator_names[found_index + 1 ..], 0..) |v, i| {
                new_validators[found_index + i] = v;
            }

            // 释放旧数组
            allocator.free(validator_names);
            self.validators = new_validators;
        } else {
            // 最后一个元素，清空数组
            allocator.free(validator_names);
            self.validators = null;
        }
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
    file: ?[]const u8 = null, // 记录原始文件路径，用于自动注释保留
    validators: @import("validate.zig").ValidatorRegistry, // 校验器注册表（公开字段）

    /// Create a new empty Ini structure（默认：内存优化，不加载 description）
    /// **行为变化**：从 v2.0 开始，默认不加载 description 以节省内存
    pub fn default(allocator: Allocator) Ini {
        return .{
            .allocator = allocator,
            .items = StringHashMap(Item).init(allocator),
            .sections = StringHashMap(Ini).init(allocator),
            .options = IniOptions{}, // 默认不加载 description
            .file = null,
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
            .file = null,
            .validators = @import("validate.zig").ValidatorRegistry.init(allocator),
        };
    }

    /// Create a new Ini structure initialized with multiple Items
    ///
    /// This method provides a convenient way to create an Ini instance
    /// pre-populated with multiple configuration items. It performs deep
    /// copies of all items and ensures atomicity (all items added or none).
    ///
    /// ## Parameters
    /// - allocator: Memory allocator for all copies
    /// - items: Slice of Items to add (each must have non-null key)
    ///
    /// ## Returns
    /// - Error!Ini: Initialized Ini or error (OutOfMemory, MissingKey, InvalidValue)
    ///
    /// ## Memory Management
    /// - Caller is responsible for deinitializing returned Ini
    /// - Caller is responsible for deinitializing original Items
    /// - On error, all partial allocations are cleaned up automatically
    ///
    /// ## Example
    /// ```zig
    /// const items = [_]Item{
    ///     Item{ .key = "port", .value = "8080" },
    ///     Item{ .key = "host", .value = "localhost" },
    ///     Item{ .key = "debug.enabled", .value = "true" },
    /// };
    /// var ini = try Ini.init(allocator, &items);
    /// defer ini.deinit();
    /// ```
    pub fn init(allocator: Allocator, items: []const Item) Error!Ini {
        // Create empty Ini with default options
        var ini = default(allocator);
        errdefer ini.deinit(); // Rollback on any error

        // Process each item sequentially
        for (items) |item| {
            // Validate that key exists (required for addItem)
            const key = item.key orelse return error.MissingKey;

            // Use existing addItem logic (handles deep copy, sections, errors)
            try ini.addItem(key, item);
        }

        return ini;
    }

    /// Free all resources
    pub fn deinit(self: *Ini) void {
        // 释放原始文件路径
        if (self.file) |path| {
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
        if (self.file) |old_path| {
            self.allocator.free(old_path);
        }
        self.file = self.allocator.dupe(u8, path) catch |err| {
            self.file = null;
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
        if (self.file) |original_path| {
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
            const choices_str = try string_mod.join(allocator, items, ",");
            defer allocator.free(choices_str);
            try writeMetadataMark(allocator, buffer, "choices", choices_str);
        }

        // 4. 写入 key = value
        // 应用转换器（如果存在）
        var output_value = if (item.value) |v| v else "";
        if (item.converter) |converter| {
            if (item.value) |v| {
                output_value = try converter.to(v);
            }
        }

        const key_value = try std.fmt.allocPrint(allocator, "{s} = {s}\n", .{ if (item.key) |k| k else "", output_value });
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
    /// This pairs semantically with set() for consistency.
    /// Returns empty string if key not found.
    pub fn get(self: *const Ini, key: []const u8) []const u8 {
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

    /// 校验指定 Item 的值（私有方法）
    fn validate(self: *const Ini, item: *const Item) !void {
        if (!self.validators.validate(item)) {
            const key_str = if (item.key) |k| k else "";
            const value_str = if (item.value) |v| v else "";
            std.log.err("校验失败：key '{s}' 的值 '{s}' 不符合要求", .{ key_str, value_str });
            return error.InvalidValue;
        }
    }

    /// Get global value as string
    /// Returns empty string if key not found
    pub fn getString(self: *const Ini, key: []const u8) []const u8 {
        if (self.getItem(key)) |item| {
            return item.asString();
        }
        return "";
    }

    /// Get global value as number (i64)
    /// Returns 0 if key not found
    pub fn getNumber(self: *const Ini, key: []const u8) i64 {
        if (self.getItem(key)) |item| {
            return item.asNumber() catch 0;
        }
        return 0;
    }

    /// Get global value as boolean
    /// Returns false if key not found
    pub fn getBoolean(self: *const Ini, key: []const u8) bool {
        if (self.getItem(key)) |item| {
            return item.asBoolean() catch false;
        }
        return false;
    }

    /// Get global value as float (f64)
    /// Returns 0.0 if key not found
    pub fn getFloat(self: *const Ini, key: []const u8) f64 {
        if (self.getItem(key)) |item| {
            return item.asFloat() catch 0.0;
        }
        return 0.0;
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
                // Set in global items
                if (self.items.getPtr(global_key)) |item| {
                    // 先校验再设置（使用现有 item）
                    // 创建临时值用于验证
                    var temp_item = Item{
                        .key = item.key,
                        .value = value,
                        .datatype = DataType.infer(value),
                        .flags = item.flags orelse .none,
                        .title = item.title,
                        .description = item.description,
                        .default = item.default,
                        .choices = item.choices,
                        .converter = item.converter,
                        .validators = item.validators,
                    };
                    try self.validate(&temp_item);

                    // 应用转换器（如果存在）
                    var final_value = value;
                    if (item.converter) |converter| {
                        final_value = try converter.from(value);
                    }

                    // 先分配新内存，成功后再释放旧内存，避免错误时悬空指针
                    const new_value = try self.allocator.dupe(u8, final_value);
                    if (item.value) |old_value| {
                        self.allocator.free(old_value);
                    }
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
                    var temp_item = try Item.initWithType(self.allocator, global_key, final_value, DataType.infer(final_value));
                    defer temp_item.deinit(self.allocator);

                    // 先校验再设置（使用临时 item）
                    try self.validate(&temp_item);

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

    /// 部分更新 Item 字段（supports <section>.<key> syntax）
    /// 只更新非 null 字段，null 字段保持原值不变
    /// Key 不存在时返回 error.KeyNotFound
    pub fn updateItem(self: *Ini, key: []const u8, item: Item) Error!void {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                const section = try self.getOrCreateSectionInternal(parsed.section);
                if (section.items.getPtr(parsed.key)) |existing_item| {
                    try self.updateItemFields(existing_item, item);
                } else {
                    return error.KeyNotFound;
                }
            },
            .global => |global_key| {
                if (self.items.getPtr(global_key)) |existing_item| {
                    try self.updateItemFields(existing_item, item);
                } else {
                    return error.KeyNotFound;
                }
            },
        }
    }

    /// addItem 的别名函数
    /// 语义上更清晰：设置 Item（添加或更新）
    pub const setItem = addItem;

    /// 为 addItem 操作推断数据类型
    /// 当 value 可用时返回推断的类型，否则返回 .string
    fn inferDataTypeForAddItem(value: ?[]const u8) DataType {
        if (value) |v| {
            return DataType.infer(v);
        }
        return .string; // null 值默认为 string
    }

    /// Add a complete Item object (supports <section>.<key> syntax)
    /// Unlike set(key, value) which accepts a string value and infers type,
    /// addItem accepts a pre-configured Item object (with explicit type and documentation)
    ///
    /// This method performs a deep copy of the Item object.
    /// The caller is still responsible for deinitializing the original Item.
    pub fn addItem(self: *Ini, key: []const u8, item: Item) Error!void {
        switch (parseKey(key)) {
            .section_key => |parsed| {
                // Get or create section
                const section = try self.getOrCreateSectionInternal(parsed.section);

                // Check if Item exists and update it
                if (section.items.getPtr(parsed.key)) |existing_item| {
                    // UPDATE EXISTING ITEM - 非空更新
                    try self.updateItemFields(existing_item, item);
                } else {
                    // CREATE NEW ITEM - keep existing deep copy logic
                    // Create new Item - key ownership transferred to HashMap later
                    const value_copy = if (item.value) |v| try self.allocator.dupe(u8, v) else "";
                    const key_copy = try self.allocator.dupe(u8, parsed.key);
                    errdefer self.allocator.free(key_copy);

                    // 确定数据类型：未指定时自动推断
                    const final_datatype = if (item.datatype == null or item.datatype == .string)
                        inferDataTypeForAddItem(item.value)
                    else
                        item.datatype;

                    const new_item = Item{
                        .key = undefined, // Will be set to HashMap key after put
                        .value = value_copy,
                        .datatype = final_datatype,
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
                        .converter = item.converter,
                        .validators = if (item.validators) |names| blk: {
                            var array_copy = try self.allocator.alloc([]const u8, names.len);
                            errdefer self.allocator.free(array_copy);
                            for (names, 0..) |elem, i| {
                                array_copy[i] = try self.allocator.dupe(u8, elem);
                            }
                            break :blk array_copy;
                        } else null,
                    };

                    // Put in HashMap - this creates the key copy
                    try section.items.put(key_copy, new_item);

                    // Set the Item's key pointer to point to HashMap's key
                    const stored_item = section.items.getPtr(key_copy).?;
                    stored_item.key = key_copy;
                }
            },
            .global => |global_key| {
                // Check if Item exists and update it
                if (self.items.getPtr(global_key)) |existing_item| {
                    // UPDATE EXISTING ITEM - 非空更新
                    try self.updateItemFields(existing_item, item);
                } else {
                    // CREATE NEW ITEM - keep existing deep copy logic
                    const value_copy = if (item.value) |v| try self.allocator.dupe(u8, v) else "";
                    const key_copy = try self.allocator.dupe(u8, global_key);
                    errdefer self.allocator.free(key_copy);

                    // 确定数据类型：未指定时自动推断
                    const final_datatype = if (item.datatype == null or item.datatype == .string)
                        inferDataTypeForAddItem(item.value)
                    else
                        item.datatype;

                    const new_item = Item{
                        .key = undefined, // Will be set to HashMap key after put
                        .value = value_copy,
                        .datatype = final_datatype,
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
                        .converter = item.converter,
                        .validators = if (item.validators) |names| blk: {
                            var array_copy = try self.allocator.alloc([]const u8, names.len);
                            errdefer self.allocator.free(array_copy);
                            for (names, 0..) |elem, i| {
                                array_copy[i] = try self.allocator.dupe(u8, elem);
                            }
                            break :blk array_copy;
                        } else null,
                    };

                    // Put in HashMap - this creates the key copy
                    try self.items.put(key_copy, new_item);

                    // Set the Item's key pointer to point to HashMap's key
                    const stored_item = self.items.getPtr(key_copy).?;
                    stored_item.key = key_copy;
                }
            },
        }
    }

    /// 更新已存在 Item 的字段（只更新非 null 字段）
    /// 所有字段（包括 value, datatype, flags）只在非 null 时更新
    /// null 字段保持原值不变
    fn updateItemFields(self: *Ini, existing_item: *Item, new_item: Item) Error!void {
        // 1. 更新 value（仅当非 null 时）
        if (new_item.value) |new_value| {
            // 应用转换器
            var final_value = new_value;
            if (existing_item.converter) |converter| {
                final_value = converter.from(new_value) catch |err| switch (err) {
                    error.Overflow => return error.Overflow,
                    else => return err,
                };
            } else if (new_item.converter) |converter| {
                final_value = converter.from(new_value) catch |err| switch (err) {
                    error.Overflow => return error.Overflow,
                    else => return err,
                };
            }

            const value_copy = try self.allocator.dupe(u8, final_value);
            if (existing_item.value) |old_value| {
                self.allocator.free(old_value);
            }
            existing_item.value = value_copy;
        }

        // 2. 更新 datatype（更新时总是重新推断）
        if (new_item.value) |new_value| {
            // 更新 value 时总是重新推断类型（与 set 方法保持一致）
            existing_item.datatype = inferDataTypeForAddItem(new_value);
        } else if (new_item.datatype) |new_datatype| {
            // 只更新 datatype 但不更新 value 的情况
            if (new_datatype != .string) {
                // 保留显式指定的非 string 类型
                existing_item.datatype = new_datatype;
            } else {
                // string/null 表示需要推断
                const value_for_inference = existing_item.value;
                if (value_for_inference) |v| {
                    existing_item.datatype = inferDataTypeForAddItem(v);
                } else {
                    existing_item.datatype = .string;
                }
            }
        }

        // 3. 更新 flags（仅当非 null 时）
        if (new_item.flags) |new_flags| {
            existing_item.flags = new_flags;
        }

        // 4. 更新 Optional 字段（仅当非 null 时）
        if (new_item.title) |new_title| {
            try self.updateOptionalField(&existing_item.title, new_title);
        }
        if (new_item.description) |new_desc| {
            try self.updateOptionalField(&existing_item.description, new_desc);
        }
        if (new_item.default) |new_default| {
            try self.updateOptionalField(&existing_item.default, new_default);
        }
        if (new_item.choices) |new_choices| {
            try self.updateArrayField(&existing_item.choices, new_choices);
        }
        if (new_item.validators) |new_validators| {
            try self.updateArrayField(&existing_item.validators, new_validators);
        }

        // 5. 更新 converter（仅当非 null 时）
        if (new_item.converter) |new_converter| {
            existing_item.converter = new_converter;
        }
    }

    /// 辅助方法：更新 Optional 字段
    fn updateOptionalField(self: *Ini, field: *?[]const u8, new_value: []const u8) Allocator.Error!void {
        if (field.*) |old_value| {
            self.allocator.free(old_value);
        }
        field.* = try self.allocator.dupe(u8, new_value);
    }

    /// 辅助方法：更新数组字段
    fn updateArrayField(self: *Ini, field: *?[][]const u8, new_value: [][]const u8) Allocator.Error!void {
        // 释放旧数组
        if (field.*) |old_array| {
            for (old_array) |item| self.allocator.free(item);
            self.allocator.free(old_array);
        }

        // 深拷贝新数组
        var array_copy = try self.allocator.alloc([]const u8, new_value.len);
        errdefer self.allocator.free(array_copy);
        for (new_value, 0..) |elem, i| {
            array_copy[i] = try self.allocator.dupe(u8, elem);
        }
        field.* = array_copy;
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
            .file = null, // section 不继承原始文件路径
            .validators = @import("validate.zig").ValidatorRegistry.init(self.allocator),
        };

        try self.sections.put(name_copy, new_section);
        return self.sections.getPtr(section_name).?;
    }

    /// 内部方法：迭代指定 section 的配置项
    /// section_name: null 表示全局配置项，否则为指定的 section 名称
    /// context: 外部传入的上下文参数，将被传递给回调函数
    /// callback: 外部传入的回调函数，接收 Item 指针、section 名称和上下文参数
    fn forEachSection(self: *const Ini, section_name: ?[]const u8, callback: anytype, context: anytype) void {
        if (section_name) |name| {
            // 迭代指定 section 的配置项
            if (self.sections.get(name)) |section| {
                var item_iter = section.items.iterator();
                while (item_iter.next()) |entry| {
                    callback(entry.value_ptr, name, context);
                }
            }
        } else {
            // 迭代全局配置项
            var item_iter = self.items.iterator();
            while (item_iter.next()) |entry| {
                callback(entry.value_ptr, null, context);
            }
        }
    }

    /// 遍历指定范围的 Item
    /// section: 迭代范围（"*"=全部，""=全局，"section_name"=指定section）
    /// callback: 外部传入的回调函数，接收 Item 指针、section 名称（null 表示全局）和上下文参数
    /// context: 传递给回调函数的上下文参数（可以是任何类型的指针）
    pub fn forEach(self: *const Ini, section: []const u8, callback: anytype, context: anytype) void {
        // 情况1: 迭代所有配置项（全局 + 所有 sections）
        if (std.mem.eql(u8, section, "*")) {
            // 1. 迭代全局 items
            self.forEachSection(null, callback, context);

            // 2. 迭代所有 sections
            var section_iter = self.sections.iterator();
            while (section_iter.next()) |section_entry| {
                const section_name = section_entry.key_ptr.*;
                self.forEachSection(section_name, callback, context);
            }
            return;
        }

        // 情况2&3: 迭代全局配置项或指定 section
        // 如果 section 为空字符串，则传入 null（表示全局）
        // 否则传入指定的 section 名称
        self.forEachSection(if (section.len == 0) null else section, callback, context);
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
            value = try self.parseSingleLineValue();

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
        try self.setItemDocumentation(@constCast(&item));

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
    fn parseSingleLineValue(self: *Parser) Error![]const u8 {
        const value_start = self.pos;
        while (self.pos < self.content.len and self.content[self.pos] != '\n') {
            self.pos += 1;
        }
        return extractValueWithoutComment(self, self.content[value_start..self.pos]);
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
                    item.choices = try string_mod.split(self.allocator, value, ",");
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

    /// 提取值，支持行尾注释分离
    /// 识别并分离行尾注释（# 或 ;），返回值部分
    /// 将行尾注释累积到 parser.pending_comments
    fn extractValueWithoutComment(parser: *Parser, s: []const u8) Error![]const u8 {
        // 1. Trim 右侧空白
        const trimmed = string_mod.trim(s);

        // 2. 查找未引用的注释符（# 或 ;）
        var comment_start: ?usize = null;
        var in_quote = false;
        var quote_char: u8 = undefined;

        for (trimmed, 0..) |c, i| {
            if (c == '"' or c == '\'') {
                if (!in_quote) {
                    in_quote = true;
                    quote_char = c;
                } else if (c == quote_char) {
                    in_quote = false;
                }
            } else if (!in_quote and (c == '#' or c == ';')) {
                comment_start = i;
                break;
            }
        }

        // 3. 如果找到注释符
        if (comment_start) |start| {
            // 提取注释内容（跳过注释符）
            const comment_raw = trimmed[start + 1 ..];
            const comment_trimmed = string_mod.trim(comment_raw);

            // 将注释累积到 pending_comments
            if (comment_trimmed.len > 0) {
                try parser.pending_comments.append(parser.allocator, try parser.allocator.dupe(u8, comment_trimmed));
            }

            // 返回值部分（注释符之前的内容）
            return string_mod.trim(trimmed[0..start]);
        }

        // 4. 没有找到注释符，返回整个字符串
        return trimmed;
    }
};

// Tests
test "basic ini parsing" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
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
    try std.testing.expectEqualStrings("global_value", ini.get("global_key"));

    // Test section keys using section.key syntax
    try std.testing.expectEqualStrings("value1", ini.get("section1.key1"));
    try std.testing.expectEqualStrings("quoted value", ini.get("section1.key2"));
    try std.testing.expectEqualStrings("value3", ini.get("section2.key3"));
}

test "save and load" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    try ini.set("global", "value");
    try ini.set("section1.key1", "value1");
    try ini.set("section1.key2", "value2");

    const string = try ini.saveToString(allocator);
    defer allocator.free(string);

    var ini2 = Ini.default(allocator);
    defer ini2.deinit();
    try ini2.loadFromString(string);

    try std.testing.expectEqualStrings("value", ini2.get("global"));
    try std.testing.expectEqualStrings("value1", ini2.get("section1.key1"));
    try std.testing.expectEqualStrings("value2", ini2.get("section1.key2"));
}

test "has() method" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
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
    var ini = Ini.default(allocator);
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
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // Create Items with explicit types
    var item = try Item.initWithType(allocator, "test", "42", DataType.number);
    defer item.deinit(allocator);

    // Add to global (deep copy is made)
    try ini.addItem("count", item);
    try std.testing.expect(ini.hasItem("count"));
    try std.testing.expectEqual(@as(i64, 42), ini.getNumber("count"));

    // Add to section
    var item2 = try Item.initWithType(allocator, "flag", "true", DataType.boolean);
    defer item2.deinit(allocator);

    try ini.addItem("settings.enabled", item2);
    try std.testing.expect(ini.hasItem("settings.enabled"));
    try std.testing.expectEqual(true, ini.getBoolean("settings.enabled"));

    // Test replacing existing key
    var item3 = try Item.initWithType(allocator, "test", "100", DataType.number);
    defer item3.deinit(allocator);

    try ini.addItem("count", item3);
    try std.testing.expectEqual(@as(i64, 100), ini.getNumber("count"));
}

test "has() method with section support" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
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
    var ini = Ini.default(allocator);
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
    var ini = Ini.default(allocator);
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
    var ini = Ini.default(allocator);
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
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\# @choices red,green,blue
        \\color = red
    ;

    try ini.loadFromString(content);

    // 测试有效值
    try ini.set("color", "green");
    try std.testing.expectEqualStrings("green", ini.get("color"));

    // 测试无效值（应该失败）
    try std.testing.expectError(error.InvalidValue, ini.set("color", "yellow"));
}

test "添加自定义校验器" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
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

    // 添加校验器到注册表
    try ini.validators.add("port_range", RangeValidator.validateImpl);

    // 先创建一个 port 键，并指定验证器
    try ini.set("port", "8080");
    if (ini.items.getPtr("port")) |item| {
        const validator_names = try allocator.alloc([]const u8, 1);
        validator_names[0] = try allocator.dupe(u8, "port_range");
        item.validators = validator_names;
    }

    // 测试有效值
    try ini.set("port", "8080");
    try std.testing.expectEqualStrings("8080", ini.get("port"));

    // 测试无效值（应该失败）
    try std.testing.expectError(error.InvalidValue, ini.set("port", "100"));
}

test "validators API - add 和 remove" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 创建测试校验器
    const TestValidator = struct {
        fn validateImpl(value: []const u8, item: *const Item) bool {
            _ = item;
            return std.mem.eql(u8, value, "ok");
        }
    };

    // 添加校验器（直接传递函数指针）
    try ini.validators.add("test1", TestValidator.validateImpl);
    try ini.validators.add("test2", TestValidator.validateImpl);

    // 创建测试键，并指定验证器
    try ini.set("key", "ok");
    if (ini.items.getPtr("key")) |item| {
        const validator_names = try allocator.alloc([]const u8, 2);
        validator_names[0] = try allocator.dupe(u8, "test1");
        validator_names[1] = try allocator.dupe(u8, "test2");
        item.validators = validator_names;
    }

    // 测试两个校验器都生效
    try std.testing.expectEqualStrings("ok", ini.get("key"));

    // 移除特定校验器
    ini.validators.remove("test1");
    try std.testing.expectEqualStrings("ok", ini.get("key"));

    // 移除另一个校验器
    ini.validators.remove("test2");
    try std.testing.expectEqualStrings("ok", ini.get("key"));

    // 清空 item 的 validators，这样就不会有命名验证器生效
    if (ini.items.getPtr("key")) |item| {
        if (item.validators) |validator_names| {
            for (validator_names) |name| allocator.free(name);
            allocator.free(validator_names);
            item.validators = null;
        }
    }

    // 现在应该接受任何值（只有全局 choice 验证器，没有 choices 限制）
    try ini.set("key", "any_value"); // 应该成功
}

test "choices 校验器 + 自定义校验器组合" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
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

    // 添加校验器（直接传递函数指针）
    try ini.validators.add("role_restrict", RoleValidator.validateImpl);

    // 为 role Item 指定验证器
    if (ini.items.getPtr("role")) |item| {
        const validator_names = try allocator.alloc([]const u8, 1);
        validator_names[0] = try allocator.dupe(u8, "role_restrict");
        item.validators = validator_names;
    }

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
    var ini = Ini.default(allocator);
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
        if (item.value) |current_value| {
            const converted = try converter.from(current_value);
            ini.allocator.free(current_value);
            item.value = try ini.allocator.dupe(u8, converted);
            item.datatype = DataType.infer(converted);
        }
    }

    // 验证转换后的值
    const value = ini.get("log_level");
    try std.testing.expectEqualStrings("4", value);
    std.debug.print("  ✓ 转换器基本功能测试通过\n", .{});
}
test "Item.addValidator - 自动初始化" {
    // 使用 C allocator 来初始化 Item，与 addValidator/removeValidator 保持一致
    const allocator = std.heap.c_allocator;
    var item = try Item.init(allocator, "port", "8080");
    defer item.deinit(allocator);

    // 验证初始状态
    try std.testing.expect(item.validators == null);

    // 添加验证器（使用全局 C allocator，无需传递 allocator）
    try item.addValidator("port_range");

    // 验证自动初始化
    try std.testing.expect(item.validators != null);
    try std.testing.expectEqual(@as(usize, 1), item.validators.?.len);
    try std.testing.expectEqualStrings("port_range", item.validators.?[0]);

    std.debug.print("  ✓ Item.addValidator 自动初始化测试通过\n", .{});
}

test "Item.addValidator - 多个验证器" {
    // 使用 C allocator 来初始化 Item，与 addValidator/removeValidator 保持一致
    const allocator = std.heap.c_allocator;
    var item = try Item.init(allocator, "port", "8080");
    defer item.deinit(allocator);

    // 添加多个验证器
    try item.addValidator("port_range");
    try item.addValidator("positive");
    try item.addValidator("custom");

    // 验证结果
    try std.testing.expectEqual(@as(usize, 3), item.validators.?.len);
    try std.testing.expectEqualStrings("port_range", item.validators.?[0]);
    try std.testing.expectEqualStrings("positive", item.validators.?[1]);
    try std.testing.expectEqualStrings("custom", item.validators.?[2]);

    std.debug.print("  ✓ Item.addValidator 多个验证器测试通过\n", .{});
}

test "Item.removeValidator - 移除验证器" {
    // 使用 C allocator 来初始化 Item，与 addValidator/removeValidator 保持一致
    const allocator = std.heap.c_allocator;
    var item = try Item.init(allocator, "port", "8080");
    defer item.deinit(allocator);

    // 添加两个验证器
    try item.addValidator("port_range");
    try item.addValidator("positive");

    // 移除一个
    try item.removeValidator("port_range");

    // 验证结果
    try std.testing.expectEqual(@as(usize, 1), item.validators.?.len);
    try std.testing.expectEqualStrings("positive", item.validators.?[0]);

    std.debug.print("  ✓ Item.removeValidator 移除验证器测试通过\n", .{});
}

test "Item.removeValidator - 移除最后一个验证器" {
    // 使用 C allocator 来初始化 Item，与 addValidator/removeValidator 保持一致
    const allocator = std.heap.c_allocator;
    var item = try Item.init(allocator, "port", "8080");
    defer item.deinit(allocator);

    // 添加一个验证器
    try item.addValidator("port_range");

    // 移除它
    try item.removeValidator("port_range");

    // 验证结果（应该清空）
    try std.testing.expect(item.validators == null);

    std.debug.print("  ✓ Item.removeValidator 移除最后一个验证器测试通过\n", .{});
}

test "Item.removeValidator - 移除不存在的验证器" {
    // 使用 C allocator 来初始化 Item，与 addValidator/removeValidator 保持一致
    const allocator = std.heap.c_allocator;
    var item = try Item.init(allocator, "port", "8080");
    defer item.deinit(allocator);

    // 添加验证器
    try item.addValidator("port_range");

    // 尝试移除不存在的验证器（应该静默成功，不抛出错误）
    try item.removeValidator("nonexistent");

    // 验证原验证器仍然存在
    try std.testing.expectEqual(@as(usize, 1), item.validators.?.len);
    try std.testing.expectEqualStrings("port_range", item.validators.?[0]);

    std.debug.print("  ✓ Item.removeValidator 移除不存在的验证器测试通过\n", .{});
}

test "Item.addValidator - 内存安全测试" {
    // 使用 C allocator 来初始化 Item，与 addValidator/removeValidator 保持一致
    const allocator = std.heap.c_allocator;
    var item = try Item.init(allocator, "port", "8080");
    defer item.deinit(allocator);

    // 多次添加和移除
    try item.addValidator("v1");
    try item.addValidator("v2");
    try item.removeValidator("v1");
    try item.addValidator("v3");

    // 验证内存正确管理
    try std.testing.expectEqual(@as(usize, 2), item.validators.?.len);
    try std.testing.expectEqualStrings("v2", item.validators.?[0]);
    try std.testing.expectEqualStrings("v3", item.validators.?[1]);

    std.debug.print("  ✓ Item.addValidator 内存安全测试通过\n", .{});
}

test "Item.addValidator - 完整使用流程" {
    // 使用 C allocator 来初始化 Ini，与 addValidator/removeValidator 保持一致
    const allocator = std.heap.c_allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 创建测试验证器
    const PortValidator = struct {
        fn validateImpl(value: []const u8, item: *const Item) bool {
            _ = item;
            const num = std.fmt.parseInt(u64, value, 10) catch return false;
            return num >= 1024 and num <= 65535;
        }
    };

    // 注册验证器
    try ini.validators.add("port_range", PortValidator.validateImpl);

    // 设置值并使用便捷方法添加验证器
    try ini.set("port", "8080");
    if (ini.items.getPtr("port")) |item| {
        try item.addValidator("port_range"); // 使用新的便捷方法
    }

    // 验证验证器生效
    const port_item = ini.items.get("port").?;
    try std.testing.expectEqual(@as(usize, 1), port_item.validators.?.len);
    try std.testing.expectEqualStrings("port_range", port_item.validators.?[0]);

    // 移除验证器
    if (ini.items.getPtr("port")) |item| {
        try item.removeValidator("port_range");
    }

    // 验证移除后可以设置任何值
    try ini.set("port", "100"); // 应该成功（验证器已移除）

    std.debug.print("  ✓ Item.addValidator 完整使用流程测试通过\n", .{});
}

// ==================== 行尾注释测试 ====================

test "行尾注释 - 基本功能" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\port=8080      # 端口
        \\host=localhost    ;主机地址
        \\debug=true          # 调试模式
    ;

    try ini.loadFromString(content);

    // 验证值正确解析（不含注释）
    try std.testing.expectEqualStrings("8080", ini.get("port"));
    try std.testing.expectEqualStrings("localhost", ini.get("host"));
    try std.testing.expectEqualStrings("true", ini.get("debug"));
}

test "行尾注释 - 注释符前后空格" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\port=8080      #端口
        \\host=localhost    #    主机地址
        \\debug=true#调试模式
    ;

    try ini.loadFromString(content);

    // 验证值正确提取
    try std.testing.expectEqualStrings("8080", ini.get("port"));
    try std.testing.expectEqualStrings("localhost", ini.get("host"));
    try std.testing.expectEqualStrings("true", ini.get("debug"));
}

test "行尾注释 - 注释中的元数据标记" {
    const allocator = std.testing.allocator;
    var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini.deinit();

    const content =
        \\port=8080      #    端口 @title
        \\host=localhost    # @default 主机
    ;

    try ini.loadFromString(content);

    // 验证值正确解析
    try std.testing.expectEqualStrings("8080", ini.get("port"));
    try std.testing.expectEqualStrings("localhost", ini.get("host"));

    // 验证 @title 和 @default 作为普通注释，不是元数据
    const port_item = ini.getItem("port").?;
    try std.testing.expect(port_item.title == null); // 没有 title 元数据
    try std.testing.expect(port_item.default == null); // 没有 default 元数据

    // 但 description 包含完整的注释内容（如果启用了 description）
    if (port_item.description) |desc| {
        try std.testing.expect(std.mem.indexOf(u8, desc, "@title") != null);
    }
}

test "行尾注释 - 引号内注释符" {
    const allocator = std.testing.allocator;
    var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini.deinit();

    const content =
        \\message="hello # world"     # 这才是注释
        \\path='C:/path;value'    ; 另一个注释
    ;

    try ini.loadFromString(content);

    // 验证引号内的注释符不被视为行尾注释
    try std.testing.expectEqualStrings("hello # world", ini.get("message"));
    try std.testing.expectEqualStrings("C:/path;value", ini.get("path"));

    // 验证真正的注释被累积
    const message_item = ini.getItem("message").?;
    if (message_item.description) |desc| {
        try std.testing.expect(std.mem.indexOf(u8, desc, "这才是注释") != null);
    }
}

test "行尾注释 - 混合独立注释和行尾注释" {
    const allocator = std.testing.allocator;
    var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini.deinit();

    const content =
        \\# 这是独立注释
        \\port=8080      # 端口
        \\
        \\; 另一个独立注释
        \\host=localhost    # 主机地址
    ;

    try ini.loadFromString(content);

    // 验证值正确解析
    try std.testing.expectEqualStrings("8080", ini.get("port"));
    try std.testing.expectEqualStrings("localhost", ini.get("host"));

    // 验证注释被累积
    const port_item = ini.getItem("port").?;
    if (port_item.description) |desc| {
        // 应该包含独立注释和行尾注释
        try std.testing.expect(std.mem.indexOf(u8, desc, "这是独立注释") != null);
        try std.testing.expect(std.mem.indexOf(u8, desc, "端口") != null);
    }
}

test "行尾注释 - 多行值不支持行尾注释" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\memo=```xxxxx      #   x
        \\ddddddddddddddd #    y
        \\```
    ;

    try ini.loadFromString(content);

    // 验证多行内容包含注释符
    const value = ini.get("memo");
    try std.testing.expect(std.mem.indexOf(u8, value, "#") != null);
    try std.testing.expect(std.mem.indexOf(u8, value, "#   x") != null);
    try std.testing.expect(std.mem.indexOf(u8, value, "#    y") != null);
}

test "行尾注释 - 保存和加载" {
    const allocator = std.testing.allocator;
    var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini.deinit();

    const content =
        \\port=8080      # 端口
        \\host=localhost    # 主机地址
    ;

    try ini.loadFromString(content);

    // 保存为字符串
    const saved = try ini.saveToString(allocator);
    defer allocator.free(saved);

    // 重新加载
    var ini2 = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini2.deinit();
    try ini2.loadFromString(saved);

    // 验证值正确保留
    try std.testing.expectEqualStrings("8080", ini2.get("port"));
    try std.testing.expectEqualStrings("localhost", ini2.get("host"));

    // 验证注释被转换为独立注释行
    try std.testing.expect(std.mem.indexOf(u8, saved, "# 端口") != null);
    try std.testing.expect(std.mem.indexOf(u8, saved, "# 主机地址") != null);
}

test "行尾注释 - section 内的行尾注释" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\[database]
        \\host=localhost    # 数据库主机
        \\port=5432      # 数据库端口
        \\
        \\[server]
        \\port=8080      # 服务器端口
    ;

    try ini.loadFromString(content);

    // 验证 section 内的值正确解析
    try std.testing.expectEqualStrings("localhost", ini.get("database.host"));
    try std.testing.expectEqualStrings("5432", ini.get("database.port"));
    try std.testing.expectEqualStrings("8080", ini.get("server.port"));
}

test "行尾注释 - 空注释和空白注释" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\port=8080      #
        \\host=localhost    ;
        \\debug=true          #
    ;

    try ini.loadFromString(content);

    // 验证值正确解析
    try std.testing.expectEqualStrings("8080", ini.get("port"));
    try std.testing.expectEqualStrings("localhost", ini.get("host"));
    try std.testing.expectEqualStrings("true", ini.get("debug"));
}

test "行尾注释 - 分号和井号混合使用" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const content =
        \\port=8080      # 使用井号
        \\host=localhost    ; 使用分号
        \\debug=true          # 又是井号
    ;

    try ini.loadFromString(content);

    // 验证两种注释符都支持
    try std.testing.expectEqualStrings("8080", ini.get("port"));
    try std.testing.expectEqualStrings("localhost", ini.get("host"));
    try std.testing.expectEqualStrings("true", ini.get("debug"));
}

test "initWithItems - 基本初始化" {
    const allocator = std.testing.allocator;

    const items = [_]Item{
        Item{ .key = "port", .value = "8080" },
        Item{ .key = "host", .value = "localhost" },
    };

    var ini = try Ini.init(allocator, &items);
    defer ini.deinit();

    try std.testing.expectEqualStrings("8080", ini.get("port"));
    try std.testing.expectEqualStrings("localhost", ini.get("host"));
    try std.testing.expectEqual(@as(i64, 8080), ini.getNumber("port"));
}

test "initWithItems - section 语法支持" {
    const allocator = std.testing.allocator;

    const items = [_]Item{
        Item{ .key = "database.host", .value = "localhost" },
        Item{ .key = "database.port", .value = "5432" },
        Item{ .key = "debug", .value = "true" },
    };

    var ini = try Ini.init(allocator, &items);
    defer ini.deinit();

    try std.testing.expectEqualStrings("localhost", ini.get("database.host"));
    try std.testing.expectEqual(@as(i64, 5432), ini.getNumber("database.port"));
    try std.testing.expectEqual(true, ini.getBoolean("debug"));
}

test "initWithItems - 内存安全" {
    const allocator = std.testing.allocator;

    // 创建包含完整元数据的 Items
    var item1 = try Item.initWithType(allocator, "port", "8080", DataType.number);
    defer item1.deinit(allocator);

    var item2 = try Item.initWithType(allocator, "enabled", "true", DataType.boolean);
    defer item2.deinit(allocator);

    const items = [_]Item{ item1, item2 };

    var ini = try Ini.init(allocator, &items);
    defer ini.deinit();

    // 验证深拷贝成功
    try std.testing.expectEqualStrings("8080", ini.get("port"));
    try std.testing.expectEqual(true, ini.getBoolean("enabled"));

    // 原始 Items 仍然有效（调用者仍拥有它们）
    try std.testing.expectEqualStrings("8080", item1.value.?);
    try std.testing.expectEqualStrings("true", item2.value.?);
}

test "initWithItems - 缺少 key 错误" {
    const allocator = std.testing.allocator;

    const items = [_]Item{
        Item{ .key = "valid", .value = "123" },
        Item{ .key = null, .value = "invalid" }, // 缺少 key
    };

    const result = Ini.init(allocator, &items);
    try std.testing.expectError(error.MissingKey, result);
}

test "initWithItems - 空数组" {
    const allocator = std.testing.allocator;

    const items = [_]Item{};
    var ini = try Ini.init(allocator, &items);
    defer ini.deinit();

    // 应该创建空的 Ini
    try std.testing.expectEqual(@as(usize, 0), ini.items.count());
}

test "initWithItems - 部分失败回滚" {
    const allocator = std.testing.allocator;

    // 创建会中途失败的 Items
    const items = [_]Item{
        Item{ .key = "item1", .value = "value1" },
        Item{ .key = null, .value = "invalid" }, // 这会失败
        Item{ .key = "item3", .value = "value3" },
    };

    const result = Ini.init(allocator, &items);
    try std.testing.expectError(error.MissingKey, result);
}

test "initWithItems - 完整工作流" {
    const allocator = std.testing.allocator;

    // 1. 使用 initWithItems 创建配置
    const items = [_]Item{
        Item{ .key = "app.name", .value = "MyApp" },
        Item{ .key = "app.version", .value = "1.0.0" },
        Item{ .key = "server.port", .value = "8080" },
        Item{ .key = "server.host", .value = "0.0.0.0" },
        Item{ .key = "debug.enabled", .value = "true" },
    };

    var ini = try Ini.init(allocator, &items);
    defer ini.deinit();

    // 2. 验证所有值正确
    try std.testing.expectEqualStrings("MyApp", ini.get("app.name"));
    try std.testing.expectEqualStrings("1.0.0", ini.get("app.version"));
    try std.testing.expectEqual(@as(i64, 8080), ini.getNumber("server.port"));
    try std.testing.expectEqualStrings("0.0.0.0", ini.get("server.host"));
    try std.testing.expectEqual(true, ini.getBoolean("debug.enabled"));

    // 3. 验证可以继续操作
    try ini.set("app.name", "UpdatedApp");
    try std.testing.expectEqualStrings("UpdatedApp", ini.get("app.name"));

    // 4. 验证序列化正确
    const output = try ini.saveToString(allocator);
    defer allocator.free(output);

    // 验证 section 格式正确（注意：序列化时 key = value 之间有空格）
    try std.testing.expect(std.mem.indexOf(u8, output, "[app]") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "name = UpdatedApp") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "[server]") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "port = 8080") != null);
}

test "addItem - 新 Item 自动推断类型（datatype 为 null）" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const item = Item{
        .key = "count",
        .value = "42",
        .datatype = null, // 未指定类型
    };
    try ini.addItem("count", item);

    const stored = ini.items.get("count").?;
    try std.testing.expectEqual(DataType.number, stored.datatype.?);
    try std.testing.expectEqual(@as(i64, 42), ini.getNumber("count"));
}

test "addItem - 新 Item 自动推断类型（datatype 为 string）" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const item = Item{
        .key = "enabled",
        .value = "true",
        .datatype = DataType.string, // 显式设为 string
    };
    try ini.addItem("enabled", item);

    const stored = ini.items.get("enabled").?;
    try std.testing.expectEqual(DataType.boolean, stored.datatype.?);
    try std.testing.expectEqual(true, ini.getBoolean("enabled"));
}

test "addItem - 新 Item 保留显式非 string 类型" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const item = Item{
        .key = "port",
        .value = "8080",
        .datatype = DataType.number, // 显式指定为 number
    };
    try ini.addItem("port", item);

    const stored = ini.items.get("port").?;
    try std.testing.expectEqual(DataType.number, stored.datatype.?);
    try std.testing.expectEqual(@as(i64, 8080), ini.getNumber("port"));
}

test "addItem - 已有 Item 双方都为 null 时推断" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 创建初始 Item（datatype 为 null）
    const item1 = Item{
        .key = "debug",
        .value = "false",
        .datatype = null,
    };
    try ini.addItem("debug", item1);

    // 更新为数值（新 datatype 也为 null，应该推断）
    const item2 = Item{
        .key = "debug",
        .value = "123",
        .datatype = null,
    };
    try ini.addItem("debug", item2);

    const stored = ini.items.get("debug").?;
    try std.testing.expectEqual(DataType.number, stored.datatype.?);
    try std.testing.expectEqual(@as(i64, 123), ini.getNumber("debug"));
}

test "addItem - 已有 Item 保留新类型" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 创建初始 Item（显式 boolean 类型）
    const item1 = Item{
        .key = "flag",
        .value = "true",
        .datatype = DataType.boolean,
    };
    try ini.addItem("flag", item1);

    // 更新为字符串（新 datatype 为 string）
    const item2 = Item{
        .key = "flag",
        .value = "new_value",
        .datatype = DataType.string,
    };
    try ini.addItem("flag", item2);

    const stored = ini.items.get("flag").?;
    try std.testing.expectEqual(DataType.string, stored.datatype.?);
    try std.testing.expectEqualStrings("new_value", stored.value.?);
}

test "addItem - null 值设为 string 类型" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const item = Item{
        .key = "empty",
        .value = null, // 值为 null
        .datatype = null,
    };
    try ini.addItem("empty", item);

    const stored = ini.items.get("empty").?;
    try std.testing.expectEqual(DataType.string, stored.datatype.?);
}

test "addItem - section 语法自动推断" {
    const allocator = std.testing.allocator;
    var ini = Ini.default(allocator);
    defer ini.deinit();

    const item = Item{
        .key = "database.port",
        .value = "5432",
        .datatype = null,
    };
    try ini.addItem("database.port", item);

    try std.testing.expectEqual(@as(i64, 5432), ini.getNumber("database.port"));
    const stored = ini.sections.get("database").?.items.get("port");
    if (stored) |s| {
        try std.testing.expectEqual(DataType.number, s.datatype.?);
    }
}

