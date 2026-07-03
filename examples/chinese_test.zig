//! 中文支持测试

const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== 中文支持测试 ===\n\n", .{});

    const config_content =
        \\# 测试中文支持
        \\应用名称=配置管理器
        \\版本=1.0.0
        \\开发者=张三
        \\描述=这是一个INI解析库  // 支持中文注释
        \\路径=C:/用户/文档/配置文件.txt
        \\
        \\[数据库]
        \\主机=localhost
        \\名称=测试数据库 # 中文值
        \\编码=utf8mb4
        \\
        \\[用户界面]
        \\标题=欢迎使用本系统
        \\提示=请输入您的用户名  # 中文字符串
        \\按钮确定=确定
        \\按钮取消=取消
    ;

    var config = Ini.init(allocator);
    defer config.deinit();

    try config.loadFromString(config_content);

    std.debug.print("全局配置:\n", .{});
    std.debug.print("  应用名称: {s}\n", .{config.get("应用名称").?});
    std.debug.print("  版本: {s}\n", .{config.get("版本").?});
    std.debug.print("  开发者: {s}\n", .{config.get("开发者").?});
    std.debug.print("  描述: {s}\n", .{config.get("描述").?});
    std.debug.print("  路径: {s}\n", .{config.get("路径").?});

    std.debug.print("\n数据库配置:\n", .{});
    std.debug.print("  主机: {s}\n", .{config.get("数据库.主机").?});
    std.debug.print("  名称: {s}\n", .{config.get("数据库.名称").?});
    std.debug.print("  编码: {s}\n", .{config.get("数据库.编码").?});

    std.debug.print("\n用户界面配置:\n", .{});
    std.debug.print("  标题: {s}\n", .{config.get("用户界面.标题").?});
    std.debug.print("  提示: {s}\n", .{config.get("用户界面.提示").?});
    std.debug.print("  按钮确定: {s}\n", .{config.get("用户界面.按钮确定").?});
    std.debug.print("  按钮取消: {s}\n", .{config.get("用户界面.按钮取消").?});

    std.debug.print("\n✓ 中文支持正常！\n", .{});
}
