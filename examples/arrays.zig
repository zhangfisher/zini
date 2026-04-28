//! 数组功能演示

const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== zini 数组功能演示 ===\n\n", .{});

    // 示例 1: 基本数组
    {
        std.debug.print("示例 1: 基本数组\n", .{});
        std.debug.print("-----------------\n", .{});

        const config_content =
            \\# 数组配置
            \\numbers=[1, 2, 3, 4, 5]
            \\names=["Alice", "Bob", "Charlie"]
            \\ports=[8080, 8081, 8082]
            \\enabled=[true, false, true]
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        if (config.getArray("numbers")) |arr| {
            std.debug.print("numbers: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        if (config.getArray("names")) |arr| {
            std.debug.print("names: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        if (config.getArray("ports")) |arr| {
            std.debug.print("ports: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        if (config.getArray("enabled")) |arr| {
            std.debug.print("enabled: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("  ✓ 基本数组解析成功\n\n", .{});
    }

    // 示例 2: 带空格和注释的数组
    {
        std.debug.print("示例 2: 带空格和注释的数组\n", .{});
        std.debug.print("---------------------------\n", .{});

        const config_content =
            \\# 数组可以有空格
            \\numbers = [ 10 , 20 , 30 ]  // 数值数组
            \\files = ["file1.txt", "file2.csv", "file3.log"]  # 文件列表
            \\flags = [ true , false ]  // 布尔数组
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        if (config.getArray("numbers")) |arr| {
            std.debug.print("numbers: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("(长度: {})\n", .{arr.len});
        }

        if (config.getArray("files")) |arr| {
            std.debug.print("files: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("(长度: {})\n", .{arr.len});
        }

        std.debug.print("  ✓ 带格式的数组解析成功\n\n", .{});
    }

    // 示例 3: Section 中的数组
    {
        std.debug.print("示例 3: Section 中的数组\n", .{});
        std.debug.print("------------------------\n", .{});

        const config_content =
            \\[servers]
            \\hosts=["server1.com", "server2.com", "server3.com"]
            \\ports=[80, 443, 8080]
            \\ssl=[true, true, false]
            \\
            \\[database]
            \\shards=["shard1", "shard2", "shard3", "shard4"]
            \\replicas=[1, 2, 3]
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        if (config.getSectionArray("servers", "hosts")) |arr| {
            std.debug.print("servers.hosts: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        if (config.getSectionArray("servers", "ports")) |arr| {
            std.debug.print("servers.ports: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        if (config.getSectionArray("database", "shards")) |arr| {
            std.debug.print("database.shards: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("  ✓ Section 数组解析成功\n\n", .{});
    }

    // 示例 4: 不同进制数组
    {
        std.debug.print("示例 4: 不同进制数组\n", .{});
        std.debug.print("---------------------\n", .{});

        const config_content =
            \\# 二进制数组
            \\flags=[0b101, 0b110, 0b111]
            \\# 十六进制数组
            \\colors=[0xFF0000, 0x00FF00, 0x0000FF]
            \\# 混合十进制
            \\values=[10, 20, 30]
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        if (config.getArray("flags")) |arr| {
            std.debug.print("flags: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        if (config.getArray("colors")) |arr| {
            std.debug.print("colors: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("  ✓ 不同进制数组解析成功\n\n", .{});
    }

    // 示例 5: 实际应用场景
    {
        std.debug.print("示例 5: 实际应用场景\n", .{});
        std.debug.print("--------------------\n", .{});

        const config_content =
            \\# 应用配置
            \\app_name=MyApp
            \\version=1.0.0
            \\
            \\[server]
            \\listen_ports=[80, 443, 8080]
            \\allowed_hosts=["localhost", "127.0.0.1", "*.example.com"]
            \\
            \\[logging]
            \\log_levels=["debug", "info", "warn", "error"]
            \\log_files=["app.log", "error.log", "access.log"]
            \\
            \\[features]
            \\enabled_modules=["auth", "database", "cache", "api"]
            \\disabled_modules=["legacy", "beta"]
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        std.debug.print("应用: {s} v{s}\n\n", .{
            config.get("app_name").?,
            config.get("version").?
        });

        std.debug.print("服务器配置:\n", .{});
        if (config.getSectionArray("server", "listen_ports")) |arr| {
            std.debug.print("  监听端口: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }
        if (config.getSectionArray("server", "allowed_hosts")) |arr| {
            std.debug.print("  允许的主机: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("\n日志配置:\n", .{});
        if (config.getSectionArray("logging", "log_levels")) |arr| {
            std.debug.print("  日志级别: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("\n功能模块:\n", .{});
        if (config.getSectionArray("features", "enabled_modules")) |arr| {
            std.debug.print("  启用: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }
        if (config.getSectionArray("features", "disabled_modules")) |arr| {
            std.debug.print("  禁用: ", .{});
            for (arr) |item| {
                std.debug.print("{s} ", .{item});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("  ✓ 实际应用配置解析成功\n\n", .{});
    }

    // 示例 6: 空数组和单元素数组
    {
        std.debug.print("示例 6: 特殊数组情况\n", .{});
        std.debug.print("--------------------\n", .{});

        const config_content =
            \\# 空数组
            \\empty_list=[]
            \\# 单元素数组
            \\single_item=[42]
            \\# 带引号的字符串数组
            \\quotes=["hello world", "foo bar"]
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        if (config.getArray("empty_list")) |arr| {
            std.debug.print("empty_list: 长度 = {}\n", .{arr.len});
        } else {
            std.debug.print("empty_list: 未找到或为空\n", .{});
        }

        if (config.getArray("single_item")) |arr| {
            std.debug.print("single_item: {s} (长度: {})\n", .{arr[0], arr.len});
        }

        if (config.getArray("quotes")) |arr| {
            std.debug.print("quotes: ", .{});
            for (arr) |item| {
                std.debug.print("\"{s}\" ", .{item});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("  ✓ 特殊数组情况处理成功\n\n", .{});
    }

    std.debug.print("=== 所有演示完成 ===\n", .{});
}
