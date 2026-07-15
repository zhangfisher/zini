//! 行尾注释功能演示

const std = @import("std");
const Ini = @import("../src/ini.zig").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== zini 行尾注释功能演示 ===\n\n", .{});

    // 示例 1: 基本行尾注释
    {
        std.debug.print("示例 1: 基本行尾注释\n", .{});
        std.debug.print("-----------------------\n", .{});

        const config_content =
            \\# 这是整行注释
            \\app_name=MyApp // 这是应用名称
            \\version=1.0.0 # 版本号
            \\debug=true    // 启用调试模式
            \\port=8080     # 服务端口
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const app_name = config.get("app_name").?;
        const version = config.get("version").?;
        const debug = try config.getBool("debug");
        const port = try config.getInt("port");

        std.debug.print("app_name: {s}\n", .{app_name});
        std.debug.print("version: {s}\n", .{version});
        std.debug.print("debug: {}\n", .{debug});
        std.debug.print("port: {}\n", .{port});

        std.debug.print("  ✓ 行尾注释被正确忽略\n\n", .{});
    }

    // 示例 2: 引号字符串内的注释符号
    {
        std.debug.print("示例 2: 引号字符串内的注释符号\n", .{});
        std.debug.print("------------------------------\n", .{});

        const config_content =
            \\message="Hello // not a comment"  // 这是真正的注释
            \\path='C:/Users/App # config'     # 路径包含井号
            \\url="https://example.com#anchor" // URL 包含井号
            \\code="if (x > 0) // check"        # 代码片段
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const message = config.get("message").?;
        const path = config.get("path").?;
        const url = config.get("url").?;
        const code = config.get("code").?;

        std.debug.print("message: {s}\n", .{message});
        std.debug.print("path: {s}\n", .{path});
        std.debug.print("url: {s}\n", .{url});
        std.debug.print("code: {s}\n", .{code});

        std.debug.print("  ✓ 引号内的注释符号被保留\n\n", .{});
    }

    // 示例 3: 类型标识 + 行尾注释
    {
        std.debug.print("示例 3: 类型标识 + 行尾注释\n", .{});
        std.debug.print("----------------------------\n", .{});

        const config_content =
            \\count:u8=10        // 计数器
            \\rate:f64=0.5       # 比率
            \\enabled:bool=true  // 启用标志
            \\name:string=Test   # 名称
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const count = try config.getU8("count");
        const rate = try config.getF64("rate");
        const enabled = try config.getBool("enabled");
        const name = config.get("name").?;

        std.debug.print("count (u8): {}\n", .{count});
        std.debug.print("rate (f64): {d:.1}\n", .{rate});
        std.debug.print("enabled (bool): {}\n", .{enabled});
        std.debug.print("name (string): {s}\n", .{name});

        std.debug.print("  ✓ 类型标识与行尾注释兼容\n\n", .{});
    }

    // 示例 4: Section 中的行尾注释
    {
        std.debug.print("示例 4: Section 中的行尾注释\n", .{});
        std.debug.print("---------------------------\n", .{});

        const config_content =
            \\[database]
            \\host=localhost      # 数据库主机
            \\port:u16=5432       // 端口号
            \\ssl:bool=true       # 启用 SSL
            \\timeout:u32=30      // 超时时间（秒）
            \\
            \\[server]
            \\workers:u8=4        # 工作线程数
            \\queue_size:u32=1000 // 队列大小
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const db_host = config.get("database.host").?;
        const db_port = try config.getU16("database.port");
        const db_ssl = try config.getBool("database.ssl");
        const db_timeout = try config.getU32("database.timeout");

        std.debug.print("数据库配置:\n", .{});
        std.debug.print("  host: {s}\n", .{db_host});
        std.debug.print("  port: {}\n", .{db_port});
        std.debug.print("  ssl: {}\n", .{db_ssl});
        std.debug.print("  timeout: {}s\n", .{db_timeout});

        const workers = try config.getU8("server.workers");
        const queue_size = try config.getU32("server.queue_size");

        std.debug.print("服务器配置:\n", .{});
        std.debug.print("  workers: {}\n", .{workers});
        std.debug.print("  queue_size: {}\n", .{queue_size});

        std.debug.print("  ✓ Section 行尾注释正常工作\n\n", .{});
    }

    // 示例 5: 实际配置文件场景
    {
        std.debug.print("示例 5: 实际配置文件场景\n", .{});
        std.debug.print("------------------------\n", .{});

        const real_config =
            \\# 应用配置文件
            \\# 更新日期: 2024-01-15
            \\
            \\[app]
            \\name: string=MyApplication    // 应用名称
            \\version: f32=2.5              # 版本号
            \\debug: bool=false             // 调试模式（生产环境关闭）
            \\max_connections: u32=1000     # 最大连接数
            \\timeout: u32=30               // 请求超时（秒）
            \\
            \\[database]
            \\host=localhost                # 数据库主机
            \\port: u16=5432                // PostgreSQL 端口
            \\name: string=myapp_db         # 数据库名称
            \\ssl: bool=true                // 启用 SSL 连接
            \\pool_size: u8=10              // 连接池大小
            \\
            \\[logging]
            \\level: string=INFO            // 日志级别
            \\file: string=app.log          # 日志文件路径
            \\max_size: u64=10485760        # 最大文件大小（10MB）
            \\rotate: bool=true             // 启用日志轮转
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(real_config);

        std.debug.print("应用配置:\n", .{});
        std.debug.print("  名称: {s}\n", .{config.get("app.name").?});
        std.debug.print("  版本: {d:.1}\n", .{try config.getF32("app.version")});
        std.debug.print("  调试模式: {}\n", .{try config.getBool("app.debug")});
        std.debug.print("  最大连接: {}\n", .{try config.getU32("app.max_connections")});

        std.debug.print("数据库配置:\n", .{});
        std.debug.print("  主机: {s}\n", .{config.get("database.host").?});
        std.debug.print("  端口: {}\n", .{try config.getU16("database.port")});
        std.debug.print("  连接池: {}\n", .{try config.getU8("database.pool_size")});

        std.debug.print("日志配置:\n", .{});
        std.debug.print("  级别: {s}\n", .{config.get("logging.level").?});
        std.debug.print("  文件: {s}\n", .{config.get("logging.file").?});
        std.debug.print("  最大大小: {} bytes\n", .{try config.getU64("logging.max_size")});

        std.debug.print("  ✓ 实际配置文件解析成功\n\n", .{});
    }

    std.debug.print("=== 所有演示完成 ===\n", .{});
}
