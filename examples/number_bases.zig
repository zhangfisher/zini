//! 二进制和十六进制数字支持演示

const std = @import("std");
const Ini = @import("../src/ini.zig").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== zini 二进制/十六进制支持演示 ===\n\n", .{});

    // 示例 1: 基本二进制和十六进制
    {
        std.debug.print("示例 1: 基本二进制和十六进制\n", .{});
        std.debug.print("------------------------------\n", .{});

        const config_content =
            \\# 不同进制表示
            \\binary_value=0b1010
            \\hex_value=0xFF
            \\decimal_value=255
            \\decimal_negative=-42
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const binary = try config.getInt("binary_value");
        const hex = try config.getInt("hex_value");
        const decimal = try config.getInt("decimal_value");
        const neg_decimal = try config.getInt("decimal_negative");

        std.debug.print("0b1010 = {}\n", .{binary});
        std.debug.print("0xFF = {}\n", .{hex});
        std.debug.print("255 = {}\n", .{decimal});
        std.debug.print("-42 = {}\n", .{neg_decimal});

        std.debug.print("  ✓ 基本进制转换成功\n\n", .{});
    }

    // 示例 2: 类型标识 + 不同进制
    {
        std.debug.print("示例 2: 类型标识 + 不同进制\n", .{});
        std.debug.print("----------------------------\n", .{});

        const config_content =
            \\flags:u8=0b10101010      // 二进制位掩码
            \\color:u32=0xFF5733       # 十六进制颜色值
            \\address:u16=0x8000       // 内存地址
            \\mask:u8=0b11110000       # 位掩码
            \\max_value:u64=0xFFFFFFFFFFFFFFFF  // 64位最大值
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const flags = try config.getU8("flags");
        const color = try config.getU32("color");
        const address = try config.getU16("address");
        const mask = try config.getU8("mask");
        const max_val = try config.getU64("max_value");

        std.debug.print("flags (0b10101010): 0b{b:0>8}\n", .{flags});
        std.debug.print("color (0xFF5733): 0x{X:0>8}\n", .{color});
        std.debug.print("address (0x8000): 0x{X:0>4}\n", .{address});
        std.debug.print("mask (0b11110000): 0b{b:0>8}\n", .{mask});
        std.debug.print("max_value (u64): 0x{X:0>16}\n", .{max_val});

        std.debug.print("  ✓ 类型化进制转换成功\n\n", .{});
    }

    // 示例 3: 实际应用场景 - 权限和配置
    {
        std.debug.print("示例 3: 实际应用 - 权限和配置\n", .{});
        std.debug.print("--------------------------------\n", .{});

        const config_content =
            \\# 文件权限 (二进制)
            \\owner_read:u8=0b100
            \\owner_write:u8=0b010
            \\owner_exec:u8=0b001
            \\all_permissions:u8=0b11111111  // rwxrwxrwx
            \\
            \\# 网络配置 (十六进制)
            \\mac_address:u64=0x001122334455  # MAC 地址
            \\subnet_mask:u32=0xFFFFFF00     // 子网掩码
            \\broadcast:u32=0xFFFFFFFF       # 广播地址
            \\
            \\# 颜色配置
            \\primary_color:u32=0x3498db     # 蓝色
            \\accent_color:u32=0xe74c3c      // 红色
            \\success_color:u32=0x2ecc71     # 绿色
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        std.debug.print("文件权限:\n", .{});
        std.debug.print("  owner_read: 0b{b:0>8} ({s}进制 = {})\n", .{
            try config.getU8("owner_read"),
            if (try config.getU8("owner_read") == 4) "二" else "十",
            try config.getU8("owner_read")
        });
        std.debug.print("  all_permissions: 0b{b:0>8} = {}\n", .{
            try config.getU8("all_permissions"),
            try config.getU8("all_permissions")
        });

        std.debug.print("网络配置:\n", .{});
        std.debug.print("  MAC: 0x{X:0>12}\n", .{try config.getU64("mac_address")});
        std.debug.print("  子网掩码: 0x{X:0>8}\n", .{try config.getU32("subnet_mask")});
        std.debug.print("  广播地址: 0x{X:0>8}\n", .{try config.getU32("broadcast")});

        std.debug.print("颜色配置:\n", .{});
        std.debug.print("  主色: #{X:0>6}\n", .{try config.getU32("primary_color")});
        std.debug.print("  强调色: #{X:0>6}\n", .{try config.getU32("accent_color")});
        std.debug.print("  成功色: #{X:0>6}\n", .{try config.getU32("success_color")});

        std.debug.print("  ✓ 实际应用场景演示成功\n\n", .{});
    }

    // 示例 4: Section 中的进制混合
    {
        std.debug.print("示例 4: Section 中的进制混合\n", .{});
        std.debug.print("------------------------------\n", .{});

        const config_content =
            \\[registers]
            \\port_a:u8=0b11110000   # 端口A初值
            \\port_b:u8=0xAA        // 端口B初值
            \\control:u16=0x1234    # 控制寄存器
            \\status:u8=0b00001111  // 状态寄存器
            \\
            \\[memory]
            \\stack_start:u16=0x0100   # 栈起始地址
            \\heap_start:u16=0x8000    // 堆起始地址
            \\vector_table:u16=0x0000  # 中断向量表
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        std.debug.print("寄存器配置:\n", .{});
        std.debug.print("  port_a: 0b{b:0>8}\n", .{try config.getU8("registers.port_a")});
        std.debug.print("  port_b: 0x{X:0>2}\n", .{try config.getU8("registers.port_b")});
        std.debug.print("  control: 0x{X:0>4}\n", .{try config.getU16("registers.control")});
        std.debug.print("  status: 0b{b:0>8}\n", .{try config.getU8("registers.status")});

        std.debug.print("内存配置:\n", .{});
        std.debug.print("  stack_start: 0x{X:0>4}\n", .{try config.getU16("memory.stack_start")});
        std.debug.print("  heap_start: 0x{X:0>4}\n", .{try config.getU16("memory.heap_start")});
        std.debug.print("  vector_table: 0x{X:0>4}\n", .{try config.getU16("memory.vector_table")});

        std.debug.print("  ✓ Section 进制混合成功\n\n", .{});
    }

    // 示例 5: 行尾注释与进制混合
    {
        std.debug.print("示例 5: 行尾注释与进制混合\n", .{});
        std.debug.print("----------------------------\n", .{});

        const config_content =
            \\# 常用数值定义
            \\byte_max:u8=0xFF    // 字节最大值
            \\word_max:u16=0xFFFF # 字最大值
            \\dword_max:u32=0xFFFFFFFF  // 双字最大值
            \\bit_mask:u8=0b00000001    # 最低位掩码
            \\
            \\[display]
            \\width:u16=0x7FF0    // 屏幕宽度
            \\height:u16=0x7FF   # 屏幕高度
            \\format:u8=0b011     # RGB565格式
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        std.debug.print("常用数值:\n", .{});
        std.debug.print("  byte_max: 0x{X:0>2} = {}\n", .{
            try config.getU8("byte_max"),
            try config.getU8("byte_max")
        });
        std.debug.print("  word_max: 0x{X:0>4} = {}\n", .{
            try config.getU16("word_max"),
            try config.getU16("word_max")
        });
        std.debug.print("  bit_mask: 0b{b:0>8}\n", .{try config.getU8("bit_mask")});

        std.debug.print("显示配置:\n", .{});
        std.debug.print("  width: {} (0x{X})\n", .{
            try config.getU16("display.width"),
            try config.getU16("display.width")
        });
        std.debug.print("  height: {} (0x{X})\n", .{
            try config.getU16("display.height"),
            try config.getU16("display.height")
        });
        std.debug.print("  format: 0b{b:0>8}\n", .{try config.getU8("display.format")});

        std.debug.print("  ✓ 行尾注释与进制混合成功\n\n", .{});
    }

    // 示例 6: 边界值测试
    {
        std.debug.print("示例 6: 边界值测试\n", .{});
        std.debug.print("-------------------\n", .{});

        const config_content =
            \\# u8 边界
            \\u8_min:u8=0x00
            \\u8_max:u8=0xFF
            \\u8_binary:u8=0b11111111
            \\
            \\# i8 边界
            \\i8_min:i8=-128
            \\i8_max:i8=0x7F
            \\
            \\# u16 边界
            \\u16_max:u16=0xFFFF
            \\
            \\# u32 边界
            \\u32_max:u32=0xFFFFFFFF
            \\
            \\# u64 边界
            \\u64_max:u64=0xFFFFFFFFFFFFFFFF
        ;

        var config = Ini.default(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        std.debug.print("u8 范围: {} - {}\n", .{
            try config.getU8("u8_min"),
            try config.getU8("u8_max")
        });
        std.debug.print("i8 范围: {} - {}\n", .{
            try config.getI8("i8_min"),
            try config.getI8("i8_max")
        });
        std.debug.print("u16 最大: {}\n", .{try config.getU16("u16_max")});
        std.debug.print("u32 最大: {}\n", .{try config.getU32("u32_max")});
        std.debug.print("u64 最大: {}\n", .{try config.getU64("u64_max")});

        std.debug.print("  ✓ 边界值测试通过\n\n", .{});
    }

    std.debug.print("=== 所有演示完成 ===\n", .{});
}
