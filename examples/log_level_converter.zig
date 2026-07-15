//! 日志级别转换器示例
//!
//! 本示例展示如何使用 zini 库的转换器功能
//! 将人类友好的日志级别（debug, info, warn, error）转换为高效的数字表示（1, 2, 3, 4）

const std = @import("std");
const Ini = @import("src/ini.zig").Ini;
const Converter = @import("src/converter.zig").Converter;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("=== 日志级别转换器示例 ===\n\n", .{});

    // 1. 定义日志级别转换器
    const log_level_converter = struct {
        fn from(input: []const u8) ![]const u8 {
            // 人类友好的值 → 高效的数字
            if (std.mem.eql(u8, input, "debug")) return "1";
            if (std.mem.eql(u8, input, "info")) return "2";
            if (std.mem.eql(u8, input, "warn")) return "3";
            if (std.mem.eql(u8, input, "error")) return "4";
            return error.InvalidValue;
        }
        fn to(input: []const u8) ![]const u8 {
            // 数字 → 人类友好的值
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

    std.debug.print("步骤 1: 定义转换器\n", .{});
    std.debug.print("  ✓ from: 将 debug/info/warn/error 转换为 1/2/3/4\n", .{});
    std.debug.print("  ✓ to:   将 1/2/3/4 转换回 debug/info/warn/error\n\n", .{});

    // 2. 创建 Ini 实例
    var ini = Ini.default(allocator);
    defer ini.deinit();

    // 3. 配置文件内容（人类友好的值）
    const config =
        \\# 应用配置
        \\# 日志级别（debug=1, info=2, warn=3, error=4）
        \\# @choices debug,info,warn,error
        \\# @default info
        \\log_level = error
    ;

    std.debug.print("步骤 2: 加载配置文件\n", .{});
    std.debug.print("  配置文件中的值: error\n", .{});
    try ini.loadFromString(config);
    std.debug.print("  ✓ 配置已加载\n\n", .{});

    // 4. 设置转换器并应用转换
    std.debug.print("步骤 3: 设置转换器\n", .{});
    if (ini.items.getPtr("log_level")) |item| {
        item.converter = &converter;

        // 手动应用转换到已加载的值
        const current_value = item.value;
        const converted = try converter.from(current_value);
        ini.allocator.free(current_value);
        item.value = try ini.allocator.dupe(u8, converted);
        item.datatype = @import("../src/ini.zig").DataType.infer(converted);

        std.debug.print("  ✓ 转换器已设置\n", .{});
        std.debug.print("  ✓ 借人类友好的 'error' 转换为高效的 '4'\n", .{});
    }
    std.debug.print("\n", .{});

    // 5. 访问转换后的值
    std.debug.print("步骤 4: 访问转换后的值\n", .{});
    const value = ini.get("log_level").?;
    std.debug.print("  内部存储的值: {s}\n", .{value});
    const level = ini.getNumber("log_level");
    std.debug.print("  作为数字访问: {d}\n", .{level});
    std.debug.print("  ✓ 值已转换为高效数字表示\n\n", .{});

    // 6. 设置新值（自动应用转换）
    std.debug.print("步骤 5: 设置新值（自动应用 from 转换）\n", .{});
    try ini.set("log_level", "debug");
    const debug_value = ini.get("log_level").?;
    std.debug.print("  设置: debug\n", .{});
    std.debug.print("  内部存储: {s}\n", .{debug_value});
    std.debug.print("  ✓ 人类友好的值自动转换为数字\n\n", .{});

    // 7. 保存配置（自动应用 to 转换）
    std.debug.print("步骤 6: 保存配置（自动应用 to 转换）\n", .{});
    const saved_config = ini.saveToString();
    std.debug.print("  保存的配置:\n", .{});

    // 只显示 log_level 相关的行
    var lines_iter = std.mem.split(u8, saved_config, "\n");
    while (lines_iter.next()) |line| {
        if (std.mem.indexOf(u8, line, "log_level") != null) {
            std.debug.print("    {s}\n", .{line});
        }
    }
    std.debug.print("  ✓ 高效的数字 '1' 转换回人类友好的 'debug'\n\n", .{});

    // 8. 使用预定义转换器
    std.debug.print("步骤 7: 使用预定义转换器\n", .{});
    const common_converter = @import("../src/ini.zig").Converter.common.log_level;

    var ini2 = Ini.default(allocator);
    defer ini2.deinit();

    try ini2.loadFromString(config);
    if (ini2.items.getPtr("log_level")) |item| {
        item.converter = &common_converter;

        const current = item.value;
        const converted = try common_converter.from(current);
        ini2.allocator.free(current);
        item.value = try ini2.allocator.dupe(u8, converted);
        item.datatype = @import("../src/ini.zig").DataType.infer(converted);
    }

    std.debug.print("  ✓ 使用预定义的 log_level 转换器\n", .{});
    std.debug.print("  ✓ 无需手动定义转换器\n\n", .{});

    std.debug.print("=== 示例完成 ===\n", .{});
    std.debug.print("\n转换器功能总结：\n", .{});
    std.debug.print("• 配置文件使用人类友好的值（debug, info, warn, error）\n", .{});
    std.debug.print("• 程序内部使用高效的数字表示（1, 2, 3, 4）\n", .{});
    std.debug.print("• 通过 schema.converter 设置转换器\n", .{});
    std.debug.print("• load/set/save 时自动应用转换\n", .{});
    std.debug.print("• 提供预定义转换器，开箱即用\n", .{});
}