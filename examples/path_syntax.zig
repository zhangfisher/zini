//! 路径语法演示 - 统一的 API 访问配置

const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== zini 路径语法演示 ===\n\n", .{});

    // 示例 1: 基本路径语法
    {
        std.debug.print("示例 1: 基本路径语法\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 设置配置项 - 使用路径语法
        try config.set("app.name", "MyApp");
        try config.set("app.version", "1.0.0");
        try config.set("server.host", "0.0.0.0");
        try config.set("server.port", "8080");
        try config.set("database.host", "localhost");
        try config.set("database.port", "5432");
        try config.set("database.name", "mydb");

        // 获取配置项 - 使用相同的路径语法
        const app_name = config.get("app.name").?;
        const app_version = config.get("app.version").?;
        const server_host = config.get("server.host").?;
        const server_port = try config.getU16("server.port");
        const db_port = try config.getU16("database.port");

        std.debug.print("  应用: {s} v{s}\n", .{ app_name, app_version });
        std.debug.print("  服务器: {s}:{}\n", .{ server_host, server_port });
        std.debug.print("  数据库端口: {}\n", .{db_port });

        std.debug.print("  ✓ 路径语法让配置访问更简洁\n\n", .{});
    }

    // 示例 2: 类型安全的路径访问
    {
        std.debug.print("示例 2: 类型安全的路径访问\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 设置不同类型的值
        try config.set("server.debug", "true");
        try config.set("server.timeout", "30");
        try config.set("server.rate_limit", "100.5");
        try config.set("server.buffer_size", "8192");

        // 使用类型化方法获取
        const debug = try config.getBool("server.debug");
        const timeout = try config.getInt("server.timeout");
        const rate_limit = try config.getFloat("server.rate_limit");
        const buffer_size = try config.getInt("server.buffer_size");

        std.debug.print("  debug: {}\n", .{debug});
        std.debug.print("  timeout: {}s\n", .{timeout});
        std.debug.print("  rate_limit: {d:.1}\n", .{rate_limit});
        std.debug.print("  buffer_size: {} bytes\n", .{buffer_size});

        std.debug.print("  ✓ 类型安全的路径访问\n\n", .{});
    }

    // 示例 3: 从文件加载并使用路径语法
    {
        std.debug.print("示例 3: 从文件加载并使用路径语法\n", .{});
        const config_content =
            \\# 应用配置
            \\app_name = DemoApp
            \\app_version = 2.0.0
            \\
            \\[server]
            \\host = localhost
            \\port = 9000
            \\ssl = true
            \\
            \\[database]
            \\host = db.example.com
            \\port = 5432
            \\name = production
            \\pool_size = 20
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        // 使用路径语法访问所有配置
        const app_name = config.get("app_name").?;
        const app_version = config.get("app_version").?;
        const server_port = try config.getU16("server.port");
        const server_ssl = try config.getBool("server.ssl");
        const db_host = config.get("database.host").?;
        const db_pool = try config.getInt("database.pool_size");

        std.debug.print("  应用: {s} v{s}\n", .{ app_name, app_version });
        std.debug.print("  服务器端口: {}, SSL: {}\n", .{ server_port, server_ssl });
        std.debug.print("  数据库: {s}, 连接池: {}\n", .{ db_host, db_pool });

        std.debug.print("  ✓ 路径语法与文件加载完美配合\n\n", .{});
    }

    // 示例 4: 多级路径支持
    {
        std.debug.print("示例 4: 多级路径支持\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 设置深层嵌套的配置
        try config.set("server.config.timeout", "60");
        try config.set("server.config.retry.count", "3");
        try config.set("server.config.retry.delay", "1000");

        // 获取深层嵌套的配置
        const timeout = config.get("server.config.timeout");
        const retry_count = config.get("server.config.retry.count");
        const retry_delay = config.get("server.config.retry.delay");

        std.debug.print("  超时: {s}s\n", .{timeout.?});
        std.debug.print("  重试次数: {s}\n", .{retry_count.?});
        std.debug.print("  重试延迟: {s}ms\n", .{retry_delay.?});

        std.debug.print("  ✓ 多级路径支持深层嵌套配置\n\n", .{});
    }

    // 示例 5: 动态配置路径
    {
        std.debug.print("示例 5: 动态配置路径\n", .{});
        var config = Ini.init(allocator);
        defer config.deinit();

        // 模拟动态构建配置路径
        const sections = [_][]const u8{ "server", "database", "cache" };
        const keys = [_][]const u8{ "host", "port", "timeout" };

        for (sections) |section| {
            for (keys) |key| {
                const path = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ section, key });
                defer allocator.free(path);

                const value = try std.fmt.allocPrint(allocator, "{s}_value", .{path});
                try config.set(path, value);
            }
        }

        // 验证动态路径
        const server_host = config.get("server.host").?;
        const db_port = config.get("database.port").?;
        const cache_timeout = config.get("cache.timeout").?;

        std.debug.print("  动态 server.host: {s}\n", .{server_host});
        std.debug.print("  动态 database.port: {s}\n", .{db_port});
        std.debug.print("  动态 cache.timeout: {s}\n", .{cache_timeout});

        std.debug.print("  ✓ 动态构建配置路径\n\n", .{});
    }

    // 示例 6: 配置更新和保存
    {
        std.debug.print("示例 6: 配置更新和保存\n", .{});
        const test_file = "path_syntax_test.ini";

        var config = Ini.init(allocator);
        defer config.deinit();

        // 创建初始配置
        try config.set("app.version", "1.0.0");
        try config.set("server.port", "8080");

        // 保存到文件
        try config.saveAndRemember(test_file);
        std.debug.print("  ✓ 初始配置已保存\n", .{});

        // 重新加载并更新
        var config2 = Ini.init(allocator);
        defer config2.deinit();

        try config2.load(test_file);

        // 使用路径语法更新配置
        try config2.set("app.version", "2.0.0");
        try config2.set("server.port", "9000");

        // 保存更新后的配置
        try config2.save();

        // 验证更新
        var config3 = Ini.init(allocator);
        defer config3.deinit();

        try config3.load(test_file);
        const new_version = config3.get("app.version").?;
        const new_port = try config3.getU16("server.port");

        std.debug.print("  更新后版本: {s}\n", .{new_version});
        std.debug.print("  更新后端口: {}\n", .{new_port});

        std.debug.print("  ✓ 配置更新和保存成功\n\n", .{});
    }

    std.debug.print("=== 所有演示完成 ===\n", .{});

    std.debug.print("\n✨ 路径语法优势：\n", .{});
    std.debug.print("  • 统一的 API：get() 和 set() 方法处理所有场景\n", .{});
    std.debug.print("  • 更简洁：无需分别记忆全局和 section 的方法\n", .{});
    std.debug.print("  • 更直观：点号分隔符符合直觉\n", .{});
    std.debug.print("  • 类型安全：支持所有类型化方法\n", .{});
    std.debug.print("  • 灵活性：支持多级路径嵌套\n", .{});
}
