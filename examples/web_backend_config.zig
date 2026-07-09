//! Web 后端应用配置文件完整示例
//!
//! 本示例展示如何使用 zini 库管理一个典型的 Web 后端应用配置文件
//! 涵盖了库的所有核心功能和高级特性

const std = @import("std");
const Ini = @import("zini").Ini;
const IniOptions = @import("zini").IniOptions;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("=== Web 后端应用配置文件管理示例 ===\n\n", .{});

    // 步骤 1: 创建配置文件内容（模拟典型 Web 应用配置）
    // ========================================

    const config_content =
        \\# Web 服务器配置
        \\# @title 服务器配置
        \\# @default localhost
        \\# @choices localhost,0.0.0.0,127.0.0.1
        \\host = 0.0.0.0
        \\
        \\# 服务器监听端口
        \\# @title 监听端口
        \\# @default 8080
        \\# @choices 8080,8000,3000
        \\port = 9000
        \\
        \\# 启用 HTTPS
        \\# @title HTTPS启用
        \\# @default false
        \\https_enabled = true
        \\
        \\# 工作进程数
        \\# @title 工作进程
        \\# @default 4
        \\# @choices 1,2,4,8,16
        \\worker_processes = 8
        \\
        \\[database]
        \\# 数据库连接配置
        \\# 数据库类型
        \\# @title 数据库类型
        \\# @default postgresql
        \\# @choices postgresql,mysql,sqlite,mongodb
        \\driver = postgresql
        \\
        \\# 数据库主机地址
        \\# @title 数据库主机
        \\# @default localhost
        \\# @choices localhost,127.0.0.1,db.example.com
        \\host = db.example.com
        \\
        \\# 数据库端口
        \\# @title 数据库端口
        \\# @default 5432
        \\# @choices 5432,3306,27017
        \\port = 5432
        \\
        \\# 数据库名称
        \\# @title 数据库名称
        \\# @default myapp
        \\database = myapp_production
        \\
        \\# 连接超时时间（秒）
        \\# @title 连接超时
        \\# @default 30
        \\# @choices 10,20,30,60,120
        \\timeout = 60
        \\
        \\# 连接池大小
        \\# @title 连接池大小
        \\# @default 10
        \\# @choices 5,10,20,50,100
        \\pool_size = 20
        \\
        \\[redis]
        \\# Redis 缓存配置
        \\# Redis 主机地址
        \\# @title Redis主机
        \\# @default localhost
        \\host = redis.example.com
        \\
        \\# Redis 端口
        \\# @title Redis端口
        \\# @default 6379
        \\port = 6379
        \\
        \\# 使用密码认证
        \\# @title 密码认证
        \\# @default false
        \\auth_enabled = true
        \\
        \\# 默认数据库索引
        \\# @title 数据库索引
        \\# @default 0
        \\# @choices 0,1,2,3,4,5,6,7,8,9
        \\db_index = 1
        \\
        \\[logging]
        \\# 日志配置
        \\# 日志级别
        \\# @title 日志级别
        \\# @default info
        \\# @choices debug,info,warn,error,fatal
        \\level = warn
        \\
        \\# 日志文件路径
        \\# @title 日志文件
        \\# @default /var/log/app.log
        \\file = /var/log/myapp/production.log
        \\
        \\# 日志文件大小限制（MB）
        \\# @title 文件大小限制
        \\# @default 100
        \\# @choices 10,50,100,500,1000
        \\max_size = 500
        \\
        \\# 保留日志文件数量
        \\# @title 保留文件数
        \\# @default 7
        \\# @choices 1,3,7,14,30
        \\max_files = 14
        \\
        \\[security]
        \\# 安全配置
        \\# JWT 密钥
        \\# @title JWT密钥
        \\# @default changeme
        \\jwt_secret = production_secret_key_2024
        \\
        \\# JWT 过期时间（小时）
        \\# @title JWT过期时间
        \\# @default 24
        \\# @choices 1,6,12,24,48,72
        \\jwt_expiration = 48
        \\
        \\# 启用 CORS
        \\# @title CORS启用
        \\# @default true
        \\cors_enabled = true
        \\
        \\# 允许的源地址
        \\# @title 允许源地址
        \\# @default *
        \\allowed_origins = https://example.com,https://www.example.com
        \\
        \\# 启用速率限制
        \\# @title 速率限制
        \\# @default true
        \\rate_limit_enabled = true
        \\
        \\# 每分钟请求限制
        \\# @title 请求限制
        \\# @default 100
        \\# @choices 50,100,200,500,1000
        \\rate_limit_requests = 200
        \\
        \\[monitoring]
        \\# 监控和健康检查配置
        \\# 启用健康检查端点
        \\# @title 健康检查
        \\# @default true
        \\health_check_enabled = true
        \\
        \\# 健康检查路径
        \\# @title 健康检查路径
        \\# @default /health
        \\health_check_path = /healthz
        \\
        \\# 启用 Prometheus 指标
        \\# @title Prometheus指标
        \\# @default false
        \\prometheus_enabled = true
        \\
        \\# Prometheus 端口
        \\# @title Prometheus端口
        \\# @default 9090
        \\# @choices 9090,9091,9100
        \\prometheus_port = 9091
        \\
        \\[feature_flags]
        \\# 功能开关配置
        \\# 启用新用户界面
        \\# @title 新UI
        \\# @default false
        \\new_ui_enabled = true
        \\
        \\# 启用 API v2
        \\# @title API v2
        \\# @default false
        \\api_v2_enabled = true
        \\
        \\# 启用 Beta 功能
        \\# @title Beta功能
        \\# @default false
        \\beta_features_enabled = false
        \\
        \\[performance]
        \\# 性能优化配置
        \\# 启用 Gzip 压缩
        \\# @title Gzip压缩
        \\# @default true
        \\gzip_enabled = true
        \\
        \\# 压缩级别（1-9）
        \\# @title 压缩级别
        \\# @default 6
        \\# @choices 1,2,3,4,5,6,7,8,9
        \\gzip_level = 9
        \\
        \\# 启用响应缓存
        \\# @title 响应缓存
        \\# @default true
        \\cache_enabled = true
        \\
        \\# 缓存过期时间（秒）
        \\# @title 缓存过期时间
        \\# @default 3600
        \\# @choices 60,300,600,1800,3600,7200
        \\cache_ttl = 1800
        \\
        \\# 最大并发连接数
        \\# @title 最大并发连接
        \\# @default 1000
        \\# @choices 500,1000,2000,5000,10000
        \\max_connections = 5000
    ;

    std.debug.print("步骤 1: 加载配置文件\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 创建 Ini 解析器，启用描述加载以获取完整元数据
    var ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini.deinit();

    // 从字符串加载配置
    try ini.loadFromString(config_content);
    std.debug.print("✓ 配置文件加载成功\n\n", .{});

    // 步骤 2: 演示基本配置访问
    // ========================================

    std.debug.print("步骤 2: 基本配置访问\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 获取全局配置项
    const host = ini.get("host").?;
    const port = ini.getNumber("port").?;
    const https_enabled = ini.getBoolean("https_enabled").?;
    const worker_processes = ini.getNumber("worker_processes").?;

    std.debug.print("服务器配置:\n", .{});
    std.debug.print("  主机地址: {s}\n", .{host});
    std.debug.print("  监听端口: {}\n", .{port});
    std.debug.print("  HTTPS启用: {}\n", .{https_enabled});
    std.debug.print("  工作进程: {}\n", .{worker_processes});
    std.debug.print("\n", .{});

    // 步骤 3: 演示 Section 配置访问
    // ========================================

    std.debug.print("步骤 3: Section 配置访问\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 获取数据库配置
    const db_driver = ini.get("database.driver").?;
    const db_host = ini.get("database.host").?;
    const db_port = ini.getNumber("database.port").?;
    const db_database = ini.get("database.database").?;
    const db_timeout = ini.getNumber("database.timeout").?;
    const db_pool_size = ini.getNumber("database.pool_size").?;

    std.debug.print("数据库配置:\n", .{});
    std.debug.print("  驱动类型: {s}\n", .{db_driver});
    std.debug.print("  主机地址: {s}\n", .{db_host});
    std.debug.print("  端口号: {}\n", .{db_port});
    std.debug.print("  数据库名: {s}\n", .{db_database});
    std.debug.print("  超时时间: {} 秒\n", .{db_timeout});
    std.debug.print("  连接池: {}\n", .{db_pool_size});
    std.debug.print("\n", .{});

    // 步骤 4: 演示 Schema 元数据访问
    // ========================================

    std.debug.print("步骤 4: Schema 元数据访问\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 获取完整的 Schema 信息
    if (ini.getSchema("port")) |port_schema| {
        std.debug.print("端口配置详细信息:\n", .{});
        std.debug.print("  键名: {s}\n", .{port_schema.key});
        std.debug.print("  当前值: {s}\n", .{port_schema.value});
        std.debug.print("  数据类型: {}\n", .{port_schema.datatype});

        if (port_schema.title) |title| {
            std.debug.print("  标题: {s}\n", .{title});
        }

        if (port_schema.description) |desc| {
            std.debug.print("  描述: {s}\n", .{desc});
        }

        if (port_schema.default) |default_value| {
            std.debug.print("  默认值: {s}\n", .{default_value});
        }

        if (port_schema.choices) |choices| {
            std.debug.print("  可选值: ", .{});
            for (choices, 0..) |choice, i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{s}", .{choice});
            }
            std.debug.print("\n", .{});
        }
    }
    std.debug.print("\n", .{});

    // 步骤 5: 演示类型推断和转换
    // ========================================

    std.debug.print("步骤 5: 类型推断和转换\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 字符串类型
    const level = ini.getString("logging.level").?;
    std.debug.print("日志级别 (字符串): {s}\n", .{level});

    // 整数类型
    const max_size = ini.getNumber("logging.max_size").?;
    std.debug.print("日志大小限制 (整数): {} MB\n", .{max_size});

    // 布尔类型
    const cors_enabled = ini.getBoolean("security.cors_enabled").?;
    std.debug.print("CORS启用 (布尔): {}\n", .{cors_enabled});

    // 浮点数类型（通过字符串转换）
    const cache_ttl_str = ini.get("performance.cache_ttl").?;
    const cache_ttl = try std.fmt.parseFloat(f64, cache_ttl_str);
    std.debug.print("缓存过期时间 (浮点): {:.0} 秒\n", .{cache_ttl});
    std.debug.print("\n", .{});

    // 步骤 6: 演示配置修改和保存
    // ========================================

    std.debug.print("步骤 6: 配置修改和保存\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 修改配置值
    try ini.set("host", "192.168.1.100");
    try ini.set("port", "8888");
    try ini.set("database.host", "newdb.example.com");
    try ini.set("database.port", "3306");

    std.debug.print("✓ 配置修改成功\n", .{});
    std.debug.print("  修改后主机: {s}\n", .{ini.get("host").?});
    std.debug.print("  修改后端口: {s}\n", .{ini.get("port").?});
    std.debug.print("  修改后数据库主机: {s}\n", .{ini.get("database.host").?});
    std.debug.print("  修改后数据库端口: {s}\n", .{ini.get("database.port").?});
    std.debug.print("\n", .{});

    // 保存修改后的配置
    const saved_config = try ini.saveToString(allocator);
    defer allocator.free(saved_config);

    std.debug.print("✓ 配置保存成功\n", .{});
    std.debug.print("保存的配置预览 (前500字符):\n", .{});
    const preview_len = @min(saved_config.len, 500);
    std.debug.print("{s}\n", .{saved_config[0..preview_len]});
    std.debug.print("\n", .{});

    // 步骤 7: 演示 reset() 方法
    // ========================================

    std.debug.print("步骤 7: 配置重置功能\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 重置所有配置为默认值
    try ini.reset();

    std.debug.print("✓ 配置重置成功\n", .{});
    std.debug.print("重置后的值:\n", .{});
    std.debug.print("  主机: {s} (默认: localhost)\n", .{ini.get("host").?});
    std.debug.print("  端口: {s} (默认: 8080)\n", .{ini.get("port").?});
    std.debug.print("  HTTPS启用: {s} (默认: false)\n", .{ini.get("https_enabled").?});
    std.debug.print("  数据库类型: {s} (默认: postgresql)\n", .{ini.get("database.driver").?});
    std.debug.print("\n", .{});

    // 步骤 8: 演示 getSection() 方法
    // ========================================

    std.debug.print("步骤 8: Section 操作功能\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 重新加载配置以演示 getSection 功能
    try ini.loadFromString(config_content);

    // 获取 database section 并进行操作
    if (ini.getSection("database")) |*db_section| {
        std.debug.print("✓ 获取 database section 成功\n", .{});

        // 在 section 中添加新配置项
        try db_section.set("maintenance_mode", "false");
        try db_section.set("readonly_mode", "false");

        std.debug.print("  添加配置项: maintenance_mode = false\n", .{});
        std.debug.print("  添加配置项: readonly_mode = false\n", .{});

        // 获取 section 中的配置
        const db_host_new = db_section.get("host").?;
        std.debug.print("  数据库主机: {s}\n", .{db_host_new});

        // 重置该 section 的所有配置
        try db_section.reset();
        std.debug.print("✓ database section 配置已重置\n", .{});
    }
    std.debug.print("\n", .{});

    // 步骤 9: 演示配置校验器
    // ========================================

    std.debug.print("步骤 9: 配置校验器功能\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 重新加载配置以演示校验器
    try ini.loadFromString(config_content);

    // 添加配置校验器
    const validators = ini.getValidators();

    // 为 database.port 添加端口号范围校验
    try validators.add("database.port", "database_port_validator", struct {
        fn validate(alloc: std.mem.Allocator, value: []const u8) !void {
            _ = alloc;
            const port_num = try std.fmt.parseInt(u16, value, 10);
            if (port_num < 1024 or port_num > 65535) {
                return error.PortOutOfRange;
            }
        }
    }.validate);

    std.debug.print("✓ 添加端口号校验器 (1024-65535)\n", .{});

    // 测试有效端口
    try ini.set("database.port", "5432");
    std.debug.print("  设置有效端口 5432: ✓\n", .{});

    // 测试无效端口（会报错）
    std.debug.print("  设置无效端口 100: ", .{});
    ini.set("database.port", "100") catch |err| {
        std.debug.print("✓ (校验失败: {})\n", .{err});
    };
    std.debug.print("\n", .{});

    // 步骤 10: 演示 has() 和 remove() 方法
    // ========================================

    std.debug.print("步骤 10: 配置检查和删除\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 检查配置项是否存在
    std.debug.print("配置项检查:\n", .{});
    std.debug.print("  host 存在: {}\n", .{ini.hasItem("host")});
    std.debug.print("  port 存在: {}\n", .{ini.hasItem("port")});
    std.debug.print("  database.host 存在: {}\n", .{ini.hasItem("database.host")});
    std.debug.print("  nonexistent.key 存在: {}\n", .{ini.hasItem("nonexistent.key")});

    // 删除配置项
    std.debug.print("\n删除配置项:\n", .{});
    const removed = ini.removeItem("security.allowed_origins");
    std.debug.print("  删除 security.allowed_origins: {}\n", .{removed});
    std.debug.print("  再次检查 security.allowed_origins: {}\n", .{ini.hasItem("security.allowed_origins")});
    std.debug.print("\n", .{});

    // 步骤 11: 演示遍历所有配置项
    // ========================================

    std.debug.print("步骤 11: 遍历所有配置项\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 遍历全局配置项
    std.debug.print("全局配置项:\n", .{});
    var global_iter = ini.items.iterator();
    while (global_iter.next()) |entry| {
        const key = entry.key_ptr.*;
        const item = entry.value_ptr.*;
        std.debug.print("  {s} = {s} (类型: {})\n", .{ key, item.value, item.datatype });
    }
    std.debug.print("\n", .{});

    // 遍历所有 sections
    std.debug.print("Section 列表:\n", .{});
    if (ini.sections) |sections| {
        var section_iter = sections.iterator();
        while (section_iter.next()) |entry| {
            const section_name = entry.key_ptr.*;
            std.debug.print("  [{s}]\n", .{section_name});
        }
    }
    std.debug.print("\n", .{});

    // 步骤 12: 演示高级功能 - 条件配置加载
    // ========================================

    std.debug.print("步骤 12: 高级功能演示\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 创建环境特定的配置
    const production_config =
        \\# 生产环境配置
        \\# @title 环境
        \\# @default development
        \\# @choices development,staging,production
        \\environment = production
        \\
        \\# 调试模式
        \\# @title 调试模式
        \\# @default true
        \\debug = false
        \\
        \\# 日志级别
        \\# @title 日志级别
        \\# @default info
        \\# @choices debug,info,warn,error
        \\log_level = error
        \\
        \\[monitoring]
        \\# 启用监控
        \\# @title 监控启用
        \\# @default false
        \\enabled = true
        \\
        \\# 采样率
        \\# @title 采样率
        \\# @default 1.0
        \\sample_rate = 0.1
    ;

    var prod_ini = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer prod_ini.deinit();

    try prod_ini.loadFromString(production_config);

    std.debug.print("生产环境配置:\n", .{});
    std.debug.print("  环境: {s}\n", .{prod_ini.get("environment").?});
    std.debug.print("  调试模式: {s}\n", .{prod_ini.get("debug").?});
    std.debug.print("  日志级别: {s}\n", .{prod_ini.get("log_level").?});
    std.debug.print("  监控启用: {s}\n", .{prod_ini.get("monitoring.enabled").?});

    // 获取浮点数值
    const sample_rate_str = prod_ini.get("monitoring.sample_rate").?;
    const sample_rate = try std.fmt.parseFloat(f64, sample_rate_str);
    std.debug.print("  采样率: {d:.1}\n", .{sample_rate});
    std.debug.print("\n", .{});

    // 步骤 13: 演示错误处理
    // ========================================

    std.debug.print("步骤 13: 错误处理演示\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    // 类型转换错误处理
    std.debug.print("类型转换错误:\n", .{});
    _ = ini.getNumber("logging.level") catch |err| {
        std.debug.print("  将 'warn' 转换为数字: ✗ (错误: {})\n", .{err});
    };

    // 键不存在错误处理
    std.debug.print("键不存在错误:\n", .{});
    if (ini.get("nonexistent.key")) |value| {
        std.debug.print("  获取不存在的键: {s}\n", .{value});
    } else {
        std.debug.print("  获取不存在的键: ✓ (返回 null)\n", .{});
    }

    // Section 不存在错误处理
    std.debug.print("Section不存在错误:\n", .{});
    if (ini.getSection("nonexistent")) |*section| {
        _ = section;
        std.debug.print("  获取不存在的section: ✓\n", .{});
    } else {
        std.debug.print("  获取不存在的section: ✓ (返回 null)\n", .{});
    }
    std.debug.print("\n", .{});

    // 步骤 14: 最终统计
    // ========================================

    std.debug.print("步骤 14: 配置统计信息\n", .{});
    std.debug.print("────────────────────────────\n", .{});

    var global_count: usize = 0;
    var global_iter_final = ini.items.iterator();
    while (global_iter_final.next()) |_| : (global_count += 1) {}

    var section_count: usize = 0;
    var total_section_items: usize = 0;

    if (ini.sections) |sections| {
        var section_iter = sections.iterator();
        while (section_iter.next()) |entry| {
            section_count += 1;
            const section_ini = entry.value_ptr.*;
            var item_iter = section_ini.items.iterator();
            while (item_iter.next()) |_| : (total_section_items += 1) {}
        }
    }

    std.debug.print("配置统计:\n", .{});
    std.debug.print("  全局配置项: {}\n", .{global_count});
    std.debug.print("  Section数量: {}\n", .{section_count});
    std.debug.print("  Section配置项总数: {}\n", .{total_section_items});
    std.debug.print("  配置项总数: {}\n", .{global_count + total_section_items});
    std.debug.print("\n", .{});

    std.debug.print("=== 示例演示完成 ===\n", .{});
    std.debug.print("\n本示例展示了 zini 库的以下功能:\n", .{});
    std.debug.print("✓ 基本 INI 文件解析和保存\n", .{});
    std.debug.print("✓ Sections 和全局配置支持\n", .{});
    std.debug.print("✓ 完整元数据支持 (title, description, default, choices)\n", .{});
    std.debug.print("✓ 类型推断和转换 (string, number, boolean, float)\n", .{});
    std.debug.print("✓ 配置修改和保存\n", .{});
    std.debug.print("✓ reset() 方法 - 配置重置\n", .{});
    std.debug.print("✓ getSection() 方法 - Section 操作\n", .{});
    std.debug.print("✓ 配置校验器 - 自定义验证\n", .{});
    std.debug.print("✓ has() 和 remove() 方法\n", .{});
    std.debug.print("✓ 配置项遍历\n", .{});
    std.debug.print("✓ 错误处理\n", .{});
    std.debug.print("✓ 内存安全管理\n", .{});
}
