//! zini 高级使用示例
//!
//! 展示 INI 库的完整功能和使用模式

const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== zini 高级示例 ===\n\n", .{});

    // 示例 1: 创建复杂配置
    {
        std.debug.print("示例 1: 创建复杂配置\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 应用信息
        try config.set("app.name", "MyApp");
        try config.set("app.version", "1.0.0");
        try config.set("app.debug", "true");

        // 服务器配置
        try config.setSection("server", "host", "0.0.0.0");
        try config.setSection("server", "port", "8080");
        try config.setSection("server", "workers", "4");

        // 数据库配置
        try config.setSection("database", "driver", "postgresql");
        try config.setSection("database", "host", "localhost");
        try config.setSection("database", "port", "5432");
        try config.setSection("database", "database", "mydb");
        try config.setSection("database", "username", "user");
        try config.setSection("database", "password", "pass");

        // 日志配置
        try config.setSection("logging", "level", "info");
        try config.setSection("logging", "file", "/var/log/app.log");

        const content = try config.saveToString(allocator);
        defer allocator.free(content);

        std.debug.print("{s}\n", .{content});
    }

    // 示例 2: 解析现有配置
    {
        std.debug.print("\n示例 2: 解析现有配置\n", .{});
        const ini_content =
            \\# 应用配置
            \\app.name = MyApp
            \\app.version = 1.0.0
            \\
            \\[server]
            \\host = localhost
            \\port = 8080
            \\ssl = true
            \\
            \\[database]
            \\host = db.example.com
            \\port = 5432
            \\name = production
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(ini_content);

        // 读取配置值
        const app_name = config.get("app.name").?;
        const server_port = config.getSection("server", "port").?;
        const db_host = config.getSection("database", "host").?;

        std.debug.print("应用名称: {s}\n", .{app_name});
        std.debug.print("服务器端口: {s}\n", .{server_port});
        std.debug.print("数据库主机: {s}\n", .{db_host});
    }

    // 示例 3: 动态修改配置
    {
        std.debug.print("\n示例 3: 动态修改配置\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 加载初始配置
        try config.setSection("app", "name", "OldName");
        try config.setSection("app", "version", "1.0.0");

        std.debug.print("修改前:\n", .{});
        std.debug.print("  名称: {s}\n", .{config.getSection("app", "name").?});

        // 修改配置
        try config.setSection("app", "name", "NewName");
        try config.setSection("app", "version", "2.0.0");

        std.debug.print("修改后:\n", .{});
        std.debug.print("  名称: {s}\n", .{config.getSection("app", "name").?});
        std.debug.print("  版本: {s}\n", .{config.getSection("app", "version").?});
    }

    // 示例 4: 检查和操作 Sections
    {
        std.debug.print("\n示例 4: 检查和操作 Sections\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        try config.setSection("section1", "key1", "value1");
        try config.setSection("section2", "key2", "value2");

        // 检查 section 是否存在
        std.debug.print("section1 存在: {}\n", .{config.hasSection("section1")});
        std.debug.print("section3 存在: {}\n", .{config.hasSection("section3")});

        // 删除 section
        _ = config.removeSection("section1");
        std.debug.print("删除后 section1 存在: {}\n", .{config.hasSection("section1")});
    }

    // 示例 5: 保存和加载文件
    {
        std.debug.print("\n示例 5: 文件操作\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        try config.set("temp", "value");
        try config.setSection("temp_section", "key", "value");

        // 保存到文件
        try config.save("temp_config.ini");
        defer {
            // 清理临时文件
            std.fs.cwd().deleteFile("temp_config.ini") catch {};
        }

        // 从文件加载
        var config2 = Ini.init(allocator);
        defer config2.deinit();

        try config2.load("temp_config.ini");

        std.debug.print("从文件加载的值: {s}\n", .{config2.get("temp").?});
    }

    // 示例 6: 错误处理
    {
        std.debug.print("\n示例 6: 错误处理\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 尝试读取不存在的键
        if (config.get("nonexistent")) |value| {
            std.debug.print("值: {s}\n", .{value});
        } else {
            std.debug.print("键不存在，使用默认值\n", .{});
        }

        // 尝试从不存在的 section 读取
        if (config.getSection("nonexistent", "key")) |value| {
            std.debug.print("值: {s}\n", .{value});
        } else {
            std.debug.print("Section 或键不存在\n", .{});
        }
    }

    std.debug.print("\n=== 所有示例完成 ===\n", .{});
}
