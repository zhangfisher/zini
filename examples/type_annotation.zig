//! 类型标识功能演示
//!
//! 展示 INI 库的类型标识功能：key:类型=值

const std = @import("std");
const Ini = @import("../src/ini.zig").Ini;
const DataType = @import("../src/ini.zig").DataType;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== zini 类型标识功能演示 ===\n\n", .{});

    // 示例 1: 基本类型标识
    {
        std.debug.print("示例 1: 基本类型标识\n", .{});
        std.debug.print("----------------------\n", .{});

        const config_content =
            \\# 使用类型标识
            \\count:u8=255
            \\port:u16=8080
            \\timeout:u32=1000
            \\id:u64=18446744073709551615
            \\temperature:i8=-30
            \\value:i16=-1000
            \\score:i32=100000
            \\amount:i64=9223372036854775807
            \\rate:f32=0.5
            \\pi:f64=3.1415926535
            \\enabled:bool=true
            \\message:string=Hello World
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        // 使用特定类型访问
        const count = try config.getU8("count");
        const port = try config.getU16("port");
        const timeout = try config.getU32("timeout");
        const id = try config.getU64("id");

        const temp = try config.getI8("temperature");
        const value = try config.getI16("value");
        const score = try config.getI32("score");
        const amount = try config.getI64("amount");

        const rate = try config.getF32("rate");
        const pi = try config.getF64("pi");

        const enabled = try config.getBool("enabled");
        const message = config.get("message").?;

        std.debug.print("u8 count: {}\n", .{count});
        std.debug.print("u16 port: {}\n", .{port});
        std.debug.print("u32 timeout: {}\n", .{timeout});
        std.debug.print("u64 id: {}\n", .{id});
        std.debug.print("i8 temperature: {}\n", .{temp});
        std.debug.print("i16 value: {}\n", .{value});
        std.debug.print("i32 score: {}\n", .{score});
        std.debug.print("i64 amount: {}\n", .{amount});
        std.debug.print("f32 rate: {d:.2}\n", .{rate});
        std.debug.print("f64 pi: {d:.10}\n", .{pi});
        std.debug.print("bool enabled: {}\n", .{enabled});
        std.debug.print("string message: {s}\n", .{message});

        std.debug.print("  ✓ 类型标识解析成功\n\n", .{});
    }

    // 示例 2: Section 中的类型标识
    {
        std.debug.print("示例 2: Section 中的类型标识\n", .{});
        std.debug.print("----------------------------\n", .{});

        const config_content =
            \\[database]
            \\host: string=localhost
            \\port: u16=5432
            \\ssl: bool=true
            \\timeout: u32=30
            \\max_connections: u8=10
            \\retry_count: i8=3
            \\pool_size: u32=100
            \\connection_timeout: f32=5.5
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const host = config.get("database.host").?;
        const port = try config.getU16("database.port");
        const ssl = try config.getBool("database.ssl");
        const timeout = try config.getU32("database.timeout");
        const max_conn = try config.getU8("database.max_connections");
        const retry = try config.getI8("database.retry_count");
        const pool_size = try config.getU32("database.pool_size");
        const conn_timeout = try config.getF32("database.connection_timeout");

        std.debug.print("数据库配置:\n", .{});
        std.debug.print("  主机: {s}\n", .{host});
        std.debug.print("  端口: {}\n", .{port});
        std.debug.print("  SSL: {}\n", .{ssl});
        std.debug.print("  超时: {}s\n", .{timeout});
        std.debug.print("  最大连接: {}\n", .{max_conn});
        std.debug.print("  重试次数: {}\n", .{retry});
        std.debug.print("  连接池大小: {}\n", .{pool_size});
        std.debug.print("  连接超时: {d:.1}s\n", .{conn_timeout});

        std.debug.print("  ✓ Section 类型标识解析成功\n\n", .{});
    }

    // 示例 3: 混合使用类型标识和自动推断
    {
        std.debug.print("示例 3: 混合使用类型标识和自动推断\n", .{});
        std.debug.print("----------------------------------\n", .{});

        const config_content =
            \\# 类型标识和自动推断混合
            \\app_name=MyApp
            \\version: f32=2.0
            \\debug: bool=true
            \\max_users: u32=1000
            \\timeout=30
            \\rate: f64=0.15
            \\
            \\[database]
            \\host=localhost
            \\port: u16=5432
            \\enabled: bool=true
            \\connections: u8=10
            \\timeout=30.5
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        // 自动推断的值
        const app_name = config.get("app_name").?;
        const timeout_auto = try config.getInt("timeout");
        const rate = try config.getFloat("rate");

        // 显式类型的值
        const version = try config.getF32("version");
        const debug = try config.getBool("debug");
        const max_users = try config.getU32("max_users");

        // Section 中的混合使用
        const host = config.get("database.host").?;
        const port = try config.getU16("database.port");
        const enabled = try config.getBool("database.enabled");
        const connections = try config.getU8("database.connections");
        const db_timeout = try config.getFloat("database.timeout");

        std.debug.print("全局配置:\n", .{});
        std.debug.print("  app_name (string): {s}\n", .{app_name});
        std.debug.print("  version (f32): {d:.1}\n", .{version});
        std.debug.print("  debug (bool): {}\n", .{debug});
        std.debug.print("  max_users (u32): {}\n", .{max_users});
        std.debug.print("  timeout (推断i64): {}\n", .{timeout_auto});
        std.debug.print("  rate (推断f64): {d:.2}\n", .{rate});

        std.debug.print("数据库配置:\n", .{});
        std.debug.print("  host (推断string): {s}\n", .{host});
        std.debug.print("  port (u16): {}\n", .{port});
        std.debug.print("  enabled (bool): {}\n", .{enabled});
        std.debug.print("  connections (u8): {}\n", .{connections});
        std.debug.print("  timeout (推断f64): {d:.1}s\n", .{db_timeout});

        std.debug.print("  ✓ 混合模式解析成功\n\n", .{});
    }

    // 示例 4: 实际应用场景
    {
        std.debug.print("示例 4: 实际应用场景 - 游戏配置\n", .{});
        std.debug.print("----------------------------------\n", .{});

        const game_config =
            \\# 游戏配置文件
            \\window_width: u16=1920
            \\window_height: u16=1080
            \\fullscreen: bool=true
            \\vsync: bool=false
            \\target_fps: u8=60
            \\max_particles: u32=10000
            \\volume: f32=0.8
            \\sensitivity: f32=1.5
            \\difficulty: u8=3
            \\auto_save: bool=true
            \\save_interval: u32=300
            \\
            \\[player]
            \\name: string=Hero
            \\level: u32=1
            \\experience: u64=0
            \\health: f32=100.0
            \\max_health: f32=100.0
            \\mana: f32=50.0
            \\max_mana: f32=100.0
            \\speed: f32=5.0
            \\strength: u16=10
            \\agility: u16=8
            \\intelligence: u16=12
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(game_config);

        const width = try config.getU16("window_width");
        const height = try config.getU16("window_height");
        const fullscreen = try config.getBool("fullscreen");
        const target_fps = try config.getU8("target_fps");
        const max_particles = try config.getU32("max_particles");
        const volume = try config.getF32("volume");
        const sensitivity = try config.getF32("sensitivity");
        const difficulty = try config.getU8("difficulty");
        const auto_save = try config.getBool("auto_save");
        const save_interval = try config.getU32("save_interval");

        std.debug.print("显示设置:\n", .{});
        std.debug.print("  分辨率: {}x{}\n", .{width, height});
        std.debug.print("  全屏: {}\n", .{fullscreen});
        std.debug.print("  目标帧率: {} FPS\n", .{target_fps});

        std.debug.print("游戏设置:\n", .{});
        std.debug.print("  最大粒子数: {}\n", .{max_particles});
        std.debug.print("  音量: {d:.1}\n", .{volume});
        std.debug.print("  鼠标灵敏度: {d:.1}\n", .{sensitivity});
        std.debug.print("  难度: {}\n", .{difficulty});
        std.debug.print("  自动保存: {}\n", .{auto_save});
        std.debug.print("  保存间隔: {}s\n", .{save_interval});

        // 玩家属性
        const player_name = config.get("player.name").?;
        const player_level = try config.getU32("player.level");
        const player_health = try config.getF32("player.health");
        const player_mana = try config.getF32("player.mana");
        const player_speed = try config.getF32("player.speed");
        const player_strength = try config.getU16("player.strength");

        std.debug.print("玩家属性:\n", .{});
        std.debug.print("  名称: {s}\n", .{player_name});
        std.debug.print("  等级: {}\n", .{player_level});
        std.debug.print("  生命值: {d:.1}/{d:.1}\n", .{player_health, try config.getF32("player.max_health")});
        std.debug.print("  魔法值: {d:.1}/{d:.1}\n", .{player_mana, try config.getF32("player.max_mana")});
        std.debug.print("  移动速度: {d:.1}\n", .{player_speed});
        std.debug.print("  力量: {}\n", .{player_strength});

        std.debug.print("  ✓ 游戏配置解析成功\n\n", .{});
    }

    // 示例 5: 类型安全和错误处理
    {
        std.debug.print("示例 5: 类型安全和错误处理\n", .{});
        std.debug.print("-------------------------\n", .{});

        const config_content =
            \\count:u8=255
            \\value:i32=1000
            \\rate: f64=3.14159
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        // 正确的类型访问
        const count = try config.getU8("count");
        std.debug.print("u8 访问成功: {}\n", .{count});

        // 类型不匹配（会溢出的值）
        const overflow_content = "count:u8=300";
        var config2 = Ini.default(allocator);
        defer config2.deinit();
        try config2.loadFromString(overflow_content);

        const overflow_result = config2.getU8("count");
        if (overflow_result) |v| {
            std.debug.print("意外成功: {}\n", .{v});
        } else |err| {
            std.debug.print("✓ 正确检测到 u8 溢出: {}\n", .{err});
        }

        // 尝试用不同类型访问相同值
        // 注意：当前实现只转换字符串值，不检查原始类型
        const i32_result = config.getI32("count");
        if (i32_result) |v| {
            std.debug.print("i32 访问成功: {}\n", .{v});
            std.debug.print("注意: u8 和 i32 之间允许自动转换\n", .{});
        } else |err| {
            std.debug.print("✓ u8 值不能直接用 i32 访问: {}\n", .{err});
        }

        std.debug.print("  ✓ 类型安全检查正常\n\n", .{});
    }

    std.debug.print("=== 所有演示完成 ===\n", .{});
}
