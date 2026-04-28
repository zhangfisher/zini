//! zini 类型支持演示
//!
//! 展示 INI 库的自动类型推断和类型安全访问功能

const std = @import("std");
const Ini = @import("zini").Ini;
const DataType = @import("zini").DataType;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== zini 类型支持演示 ===\n\n", .{});

    // 示例 1: 自动类型推断
    {
        std.debug.print("示例 1: 自动类型推断\n", .{});
        std.debug.print("------------------------\n", .{});

        var config = Ini.init(allocator);
        defer config.deinit();

        // 设置各种类型的值
        try config.set("app.debug", "true");           // 布尔值
        try config.set("app.port", "8080");            // 整数
        try config.set("app.version", "2.5");          // 浮点数
        try config.set("app.name", "MyApp");           // 字符串

        // 显示推断的类型
        const debug_entry = config.getEntry("app.debug").?;
        const port_entry = config.getEntry("app.port").?;
        const version_entry = config.getEntry("app.version").?;
        const name_entry = config.getEntry("app.name").?;

        std.debug.print("app.debug = 'true'  -> 类型: {s}\n", .{debug_entry.datatype.typeName()});
        std.debug.print("app.port = '8080'   -> 类型: {s}\n", .{port_entry.datatype.typeName()});
        std.debug.print("app.version = '2.5' -> 类型: {s}\n", .{version_entry.datatype.typeName()});
        std.debug.print("app.name = 'MyApp'  -> 类型: {s}\n", .{name_entry.datatype.typeName()});
    }

    // 示例 2: 类型安全访问
    {
        std.debug.print("\n示例 2: 类型安全访问\n", .{});
        std.debug.print("----------------------\n", .{});

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.set("enabled", "true");
        try config.set("count", "100");
        try config.set("rate", "0.15");
        try config.set("message", "Hello");

        // 使用类型安全的访问方法
        const enabled = try config.getBool("enabled");
        const count = try config.getInt("count");
        const rate = try config.getFloat("rate");
        const message = config.get("message").?;

        std.debug.print("enabled (bool): {}\n", .{enabled});
        std.debug.print("count (int): {}\n", .{count});
        std.debug.print("rate (float): {d:.2}\n", .{rate});
        std.debug.print("message (string): {s}\n", .{message});

        // 使用这些值进行计算
        const total = @as(f64, @floatFromInt(count)) * rate;
        std.debug.print("计算结果: {} * {d:.2} = {d:.2}\n", .{count, rate, total});
    }

    // 示例 3: Section 中的类型支持
    {
        std.debug.print("\n示例 3: Section 中的类型支持\n", .{});
        std.debug.print("-------------------------------\n", .{});

        var config = Ini.init(allocator);
        defer config.deinit();

        // 数据库配置
        try config.setSection("database", "host", "localhost");
        try config.setSection("database", "port", "5432");
        try config.setSection("database", "ssl", "true");
        try config.setSection("database", "timeout", "30.5");

        // 服务器配置
        try config.setSection("server", "workers", "4");
        try config.setSection("server", "enabled", "true");
        try config.setSection("server", "max_memory", "2048");

        // 访问数据库配置
        const db_host = config.getSection("database", "host").?;
        const db_port = try config.getSectionInt("database", "port");
        const db_ssl = try config.getSectionBool("database", "ssl");
        const db_timeout = try config.getSectionFloat("database", "timeout");

        std.debug.print("数据库配置:\n", .{});
        std.debug.print("  主机: {s}\n", .{db_host});
        std.debug.print("  端口: {}\n", .{db_port});
        std.debug.print("  SSL: {}\n", .{db_ssl});
        std.debug.print("  超时: {d:.1}s\n", .{db_timeout});

        // 访问服务器配置
        const server_workers = try config.getSectionInt("server", "workers");
        const server_enabled = try config.getSectionBool("server", "enabled");
        const server_memory = try config.getSectionInt("server", "max_memory");

        std.debug.print("服务器配置:\n", .{});
        std.debug.print("  工作进程: {}\n", .{server_workers});
        std.debug.print("  启用状态: {}\n", .{server_enabled});
        std.debug.print("  最大内存: {} MB\n", .{server_memory});
    }

    // 示例 4: 从配置文件加载
    {
        std.debug.print("\n示例 4: 从配置文件加载\n", .{});
        std.debug.print("----------------------\n", .{});

        const config_content =
            \\# 应用配置文件
            \\app.name = MyApp
            \\app.version = 2.0
            \\app.debug = true
            \\app.port = 8080
            \\app.timeout = 30.5
            \\
            \\[database]
            \\host = localhost
            \\port = 5432
            \\ssl = true
            \\pool_size = 10
            \\connection_timeout = 5.0
            \\
            \\[features]
            \\caching = true
            \\logging = true
            \\max_cache_size = 1024
            \\cache_ttl = 3600.0
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        // 读取应用配置
        const app_name = config.get("app.name").?;
        const app_version = try config.getFloat("app.version");
        const app_debug = try config.getBool("app.debug");
        const app_port = try config.getInt("app.port");
        const app_timeout = try config.getFloat("app.timeout");

        std.debug.print("应用配置:\n", .{});
        std.debug.print("  名称: {s}\n", .{app_name});
        std.debug.print("  版本: {d:.1}\n", .{app_version});
        std.debug.print("  调试模式: {}\n", .{app_debug});
        std.debug.print("  端口: {}\n", .{app_port});
        std.debug.print("  超时: {d:.1}s\n", .{app_timeout});

        // 读取数据库配置
        const db_pool_size = try config.getSectionInt("database", "pool_size");
        const db_conn_timeout = try config.getSectionFloat("database", "connection_timeout");

        std.debug.print("数据库连接池配置:\n", .{});
        std.debug.print("  连接池大小: {}\n", .{db_pool_size});
        std.debug.print("  连接超时: {d:.1}s\n", .{db_conn_timeout});

        // 读取功能配置
        const caching = try config.getSectionBool("features", "caching");
        const max_cache_size = try config.getSectionInt("features", "max_cache_size");
        const cache_ttl = try config.getSectionFloat("features", "cache_ttl");

        std.debug.print("缓存功能配置:\n", .{});
        std.debug.print("  启用缓存: {}\n", .{caching});
        std.debug.print("  最大缓存: {} MB\n", .{max_cache_size});
        std.debug.print("  缓存TTL: {d:.0}s\n", .{cache_ttl});
    }

    // 示例 5: 错误处理和类型检查
    {
        std.debug.print("\n示例 5: 错误处理和类型检查\n", .{});
        std.debug.print("----------------------------\n", .{});

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.set("valid_int", "42");
        try config.set("valid_bool", "true");

        // 尝试错误的类型转换
        std.debug.print("尝试将 '42' 转换为布尔值:\n", .{});
        if (config.getBool("valid_int")) |_| {
            std.debug.print("  转换成功（不应该发生）\n", .{});
        } else |err| {
            std.debug.print("  ✓ 正确返回错误: {}\n", .{err});
        }

        std.debug.print("尝试将 'true' 转换为整数:\n", .{});
        if (config.getInt("valid_bool")) |_| {
            std.debug.print("  转换成功（不应该发生）\n", .{});
        } else |err| {
            std.debug.print("  ✓ 正确返回错误: {}\n", .{err});
        }

        // 检查键是否存在
        std.debug.print("检查不存在的键:\n", .{});
        if (config.get("nonexistent")) |value| {
            std.debug.print("  找到值: {s}\n", .{value});
        } else {
            std.debug.print("  ✓ 键不存在\n", .{});
        }

        // 类型检查
        std.debug.print("类型检查:\n", .{});
        if (config.getEntry("valid_int")) |entry| {
            const is_int = entry.isType(.int);
            const is_bool = entry.isType(.bool);
            std.debug.print("  valid_int 是整数: {}\n", .{is_int});
            std.debug.print("  valid_int 是布尔: {}\n", .{is_bool});
        }
    }

    std.debug.print("\n=== 类型支持演示完成 ===\n", .{});
}
