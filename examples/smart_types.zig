//! 智能类型推断和选择性写入演示

const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== 智能类型推断演示 ===\n\n", .{});

    // 示例 1: 自动类型推断
    {
        std.debug.print("示例 1: 自动类型推断\n", .{});
        std.debug.print("----------------------\n", .{});

        var config = Ini.init(allocator);
        defer config.deinit();

        // 设置不同类型的值，系统自动推断
        try config.set("u8_value", "255");         // → 自动推断为 u8
        try config.set("u16_value", "65535");      // → 自动推断为 u16（省略标注）
        try config.set("u32_value", "4294967295");   // → 自动推断为 u32
        try config.set("i8_value", "-128");         // → 自动推断为 i8
        try config.set("i16_value", "-32768");      // → 自动推断为 i16
        try config.set("enabled", "true");          // → 自动推断为 bool（省略标注）
        try config.set("rate", "3.14");             // → 自动推断为 float
        try config.set("name", "MyApp");            // → 自动推断为 string（省略标注）

        const content = try config.saveToString(allocator);
        defer allocator.free(content);

        std.debug.print("生成的配置文件：\n{s}\n", .{content});
        std.debug.print("  注意：u16, bool, string 省略了类型标注\n\n", .{});
    }

    // 示例 2: 显式类型标注
    {
        std.debug.print("示例 2: 显式类型标注\n", .{});
        std.debug.print("------------------\n", .{});

        var config = Ini.init(allocator);
        defer config.deinit();

        // 使用类型标注，精确控制类型
        try config.set("port:u16", "8080");        // 显式指定 u16
        try config.set("count:u8", "100");        // 显式指定 u8
        try config.set("timeout:i32", "30");      // 显式指定 i32

        const content = try config.saveToString(allocator);
        defer allocator.free(content);

        std.debug.print("生成的配置文件：\n{s}\n", .{content});
        std.debug.print("  注意：u16 仍然省略了标注，u8/i32 保留了标注\n\n", .{});
    }

    // 示例 3: 混合使用自动推断和显式标注
    {
        std.debug.print("示例 3: 混合使用自动推断和显式标注\n", .{});
        std.debug.print("-----------------------------------\n", .{});

        var config = Ini.init(allocator);
        defer config.deinit();

        // 自动推断的值
        try config.set("auto_port", "9000");      // 自动推断为 u16
        try config.set("auto_bool", "false");      // 自动推断为 bool

        // 显式指定的值
        try config.set("manual_u8:u8", "255");   // 显式指定 u8

        const content = try config.saveToString(allocator);
        defer allocator.free(content);

        std.debug.print("生成的配置文件：\n{s}\n", .{content});
        std.debug.print("  auto_port 自动推断为 u16，省略标注\n", .{});
        std.debug.print("  auto_bool 自动推断为 bool，省略标注\n", .{});
        std.debug.print("  manual_u8 显式指定 u8，保留标注\n\n", .{});
    }

    // 示例 4: 路径语法 + 智能推断
    {
        std.debug.print("示例 4: 路径语法 + 智能推断\n", .{});
        std.debug.print("-----------------------\n", .{});

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.set("server.port", "8080");        // 自动推断为 u16
        try config.set("server.enabled", "true");    // 自动推断为 bool
        try config.set("server.timeout:i32", "60");  // 显式指定 i32

        const content = try config.saveToString(allocator);
        defer allocator.free(content);

        std.debug.print("生成的配置文件：\n{s}\n", .{content});
        std.debug.print("  路径语法与智能推断完美配合\n\n", .{});
    }

    std.debug.print("=== 演示完成 ===\n\n", .{});

    std.debug.print("✨ 智能类型推断特性：\n", .{});
    std.debug.print("  1. 自动识别数值范围：\n", .{});
    std.debug.print("     - 0-255 → u8\n", .{});
    std.debug.print("     - 0-65535 → u16\n", .{});
    std.debug.print("     - 负数 → i8/i16/i32/i64\n", .{});
    std.debug.print("  2. 自动识别布尔值：true/false\n", .{});
    std.debug.print("  3. 自动识别浮点数（包含小数点）\n", .{});
    std.debug.print("  4. 其他 → string\n", .{});
    std.debug.print("\n📝 选择性写入规则：\n", .{});
    std.debug.print("  省略标注：u16, bool, string（最常见的类型）\n", .{});
    std.debug.print("  保留标注：u8, u32, u64, i8, i16, i32, i64, f32, f64\n", .{});
    std.debug.print("\n💡 使用建议：\n", .{});
    std.debug.print("  • 让系统自动推断常见类型（u16, bool, string）\n", .{});
    std.debug.print("  • 对需要精确控制的类型使用显式标注\n", .{});
    std.debug.print("  • 配置文件更简洁，只标注必要的类型\n", .{});
}
