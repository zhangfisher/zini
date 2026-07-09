//! Web 后端应用配置文件演示
//! 这是一个简化版本，可以独立运行

const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("=== Web 后端应用配置文件管理演示 ===\n\n", .{});

    // 示例 1: 基本 INI 配置内容
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
        \\[database]
        \\# 数据库配置
        \\# @title 数据库主机
        \\# @default localhost
        \\host = db.example.com
        \\
        \\# @title 数据库端口
        \\# @default 5432
        \\port = 5432
        \\
        \\[security]
        \\# 安全配置
        \\# @title JWT密钥
        \\jwt_secret = production_secret_key_2024
        \\
        \\# @title HTTPS启用
        \\# @default false
        \\https_enabled = true
    ;

    std.debug.print("步骤 1: 示例配置内容\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("{s}\n", .{config_content});

    std.debug.print("\n步骤 2: 配置文件结构说明\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("✓ 全局配置项: host, port\n", .{});
    std.debug.print("✓ Section [database]: 数据库配置\n", .{});
    std.debug.print("✓ Section [security]: 安全配置\n", .{});

    std.debug.print("\n步骤 3: 元数据支持说明\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("✓ @title: 配置项标题\n", .{});
    std.debug.print("✓ @default: 默认值\n", .{});
    std.debug.print("✓ @choices: 可选值列表\n", .{});
    std.debug.print("✓ 普通注释: 描述信息\n", .{});

    std.debug.print("\n步骤 4: 类型推断演示\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("✓ 0.0.0.0 → string (IP地址)\n", .{});
    std.debug.print("✓ 9000 → number (端口号)\n", .{});
    std.debug.print("✓ true → boolean (布尔值)\n", .{});
    std.debug.print("✓ db.example.com → string (域名)\n", .{});

    std.debug.print("\n步骤 5: zini 库功能概述\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("✓ loadFromString/load: 加载配置\n", .{});
    std.debug.print("✓ get/set: 读写配置值\n", .{});
    std.debug.print("✓ getNumber/getBoolean/getFloat: 类型转换\n", .{});
    std.debug.print("✓ getSection: 操作特定 section\n", .{});
    std.debug.print("✓ reset: 重置为默认值\n", .{});
    std.debug.print("✓ has/remove: 配置管理\n", .{});
    std.debug.print("✓ saveToString/save: 保存配置\n", .{});

    std.debug.print("\n步骤 6: 实际应用场景\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("✓ Web 服务器配置\n", .{});
    std.debug.print("✓ 数据库连接设置\n", .{});
    std.debug.print("✓ Redis 缓存配置\n", .{});
    std.debug.print("✓ 日志系统配置\n", .{});
    std.debug.print("✓ 安全和认证配置\n", .{});
    std.debug.print("✓ 监控和性能配置\n", .{});
    std.debug.print("✓ 功能开关配置\n", .{});

    std.debug.print("\n步骤 7: 完整功能列表\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("📁 文件操作:\n", .{});
    std.debug.print("  • load/loadFromString: 加载配置\n", .{});
    std.debug.print("  • save/saveToString: 保存配置\n", .{});
    std.debug.print("  • getSection: 获取特定 section\n", .{});

    std.debug.print("\n🔍 配置访问:\n", .{});
    std.debug.print("  • get: 获取原始值\n", .{});
    std.debug.print("  • getNumber: 获取数值\n", .{});
    std.debug.print("  • getBoolean: 获取布尔值\n", .{});
    std.debug.print("  • getFloat: 获取浮点数\n", .{});
    std.debug.print("  • getString: 获取字符串\n", .{});
    std.debug.print("  • getSchema: 获取完整元数据\n", .{});

    std.debug.print("\n🔧 配置管理:\n", .{});
    std.debug.print("  • set: 设置配置值\n", .{});
    std.debug.print("  • has: 检查键存在\n", .{});
    std.debug.print("  • remove: 删除配置项\n", .{});
    std.debug.print("  • add: 添加新配置项\n", .{});

    std.debug.print("\n🔄 高级功能:\n", .{});
    std.debug.print("  • reset: 重置为默认值\n", .{});
    std.debug.print("  • forEach: 遍历配置项\n", .{});
    std.debug.print("  • getValidators: 配置校验\n", .{});

    std.debug.print("\n📊 元数据支持:\n", .{});
    std.debug.print("  • @title: 配置项标题\n", .{});
    std.debug.print("  • @default: 默认值\n", .{});
    std.debug.print("  • @choices: 可选值列表\n", .{});
    std.debug.print("  • @enum: 枚举值列表\n", .{});
    std.debug.print("  • 普通注释: 描述信息\n", .{});

    std.debug.print("\n步骤 8: 使用示例代码\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("请查看完整示例: examples/web_backend_config.zig\n", .{});
    std.debug.print("\n基本用法:\n", .{});
    std.debug.print("  const Ini = @import(\"zini\").Ini;\n", .{});
    std.debug.print("  var ini = Ini.init(allocator);\n", .{});
    std.debug.print("  try ini.loadFromString(content);\n", .{});
    std.debug.print("  const value = ini.get(\"key\").?;\n", .{});

    std.debug.print("\n步骤 9: 典型 Web 应用配置结构\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("📦 建议的配置结构:\n", .{});
    std.debug.print("  [server]     - 服务器配置\n", .{});
    std.debug.print("  [database]   - 数据库配置\n", .{});
    std.debug.print("  [redis]      - 缓存配置\n", .{});
    std.debug.print("  [logging]    - 日志配置\n", .{});
    std.debug.print("  [security]   - 安全配置\n", .{});
    std.debug.print("  [monitoring] - 监控配置\n", .{});
    std.debug.print("  [features]   - 功能开关\n", .{});
    std.debug.print("  [performance] - 性能配置\n", .{});

    std.debug.print("\n步骤 10: 配置管理最佳实践\n", .{});
    std.debug.print("────────────────────────────\n", .{});
    std.debug.print("✓ 使用描述性注释说明配置用途\n", .{});
    std.debug.print("✓ 为关键配置提供默认值\n", .{});
    std.debug.print("✓ 限制可选择的值范围\n", .{});
    std.debug.print("✓ 按功能分组配置项\n", .{});
    std.debug.print("✓ 使用环境特定的配置文件\n", .{});
    std.debug.print("✓ 实施配置校验\n", .{});
    std.debug.print("✓ 定期备份配置文件\n", .{});

    _ = allocator; // 标记为已使用

    std.debug.print("\n=== 演示完成 ===\n", .{});
    std.debug.print("\n📚 完整示例: examples/web_backend_config.zig\n", .{});
    std.debug.print("📖 文档: README.md\n", .{});
    std.debug.print("🔧 构建: zig build run-web\n", .{});
}
