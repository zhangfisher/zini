//! 位数据合并功能演示

const std = @import("std");
const Ini = @import("zini").Ini;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== zini 位数据合并功能演示 ===\n\n", .{});

    // 示例 1: 基本位合并（默认 u8）
    {
        std.debug.print("示例 1: 基本位合并（默认 u8）\n", .{});
        std.debug.print("-----------------------------------\n", .{});

        const config_content =
            \\# 位标志配置（8位）
            \\flags.a=0b00000001
            \\flags.b=0b00000010
            \\flags.c=0b00000100
            \\flags.d=4
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        // 直接使用 getU8 获取合并后的值
        const merged_value = try config.getU8("flags");
        std.debug.print("flags.a = 0b00000001 (1)\n", .{});
        std.debug.print("flags.b = 0b00000010 (2)\n", .{});
        std.debug.print("flags.c = 0b00000100 (4)\n", .{});
        std.debug.print("flags.d = 4\n", .{});
        std.debug.print("合并后的 flags = 0b{b:0>8} ({})\n", .{ merged_value, merged_value });

        std.debug.print("  ✓ 基本位合并成功\n\n", .{});
    }

    // 示例 2: 显式类型标识 (u16)
    {
        std.debug.print("示例 2: 显式类型标识 (u16)\n", .{});
        std.debug.print("--------------------------------\n", .{});

        const config_content =
            \\# 16位位标志配置
            \\permissions.read:u16=0b0000000000000001
            \\permissions.write:u16=0b0000000000000010
            \\permissions.execute:u16=0b0000000000000100
            \\permissions.delete:u16=0b0000000000001000
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const merged_value = try config.getU16("permissions");
        std.debug.print("permissions.read    = 0b{b:0>16} (1)\n", .{@as(u16, 1)});
        std.debug.print("permissions.write   = 0b{b:0>16} (2)\n", .{@as(u16, 2)});
        std.debug.print("permissions.execute = 0b{b:0>16} (4)\n", .{@as(u16, 4)});
        std.debug.print("permissions.delete  = 0b{b:0>16} (8)\n", .{@as(u16, 8)});
        std.debug.print("合并后的 permissions = 0b{b:0>16} ({})\n", .{ merged_value, merged_value });

        std.debug.print("  ✓ u16 位合并成功\n\n", .{});
    }

    // 示例 3: Section 中的位合并
    {
        std.debug.print("示例 3: Section 中的位合并\n", .{});
        std.debug.print("----------------------------\n", .{});

        const config_content =
            \\[user_perms]
            \\user.read=1
            \\user.write=2
            \\user.execute=4
            \\
            \\[group_perms]
            \\group.read:u16=1
            \\group.write:u16=2
            \\group.admin:u16=128
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        std.debug.print("user_perms.user 合并值: {} (0b{b:0>8})\n", .{
            try config.getSectionU8("user_perms", "user"),
            try config.getSectionU8("user_perms", "user")
        });

        std.debug.print("group_perms.group 合并值: {} (0b{b:0>16})\n", .{
            try config.getSectionU16("group_perms", "group"),
            try config.getSectionU16("group_perms", "group")
        });

        std.debug.print("  ✓ Section 位合并成功\n\n", .{});
    }

    // 示例 4: 实际应用场景 - 文件权限
    {
        std.debug.print("示例 4: 实际应用 - 文件权限\n", .{});
        std.debug.print("-------------------------------\n", .{});

        const config_content =
            \\# 文件权限配置
            \\file.owner.read=0b100000000
            \\file.owner.write=0b010000000
            \\file.owner.execute=0b001000000
            \\file.group.read=0b000100000
            \\file.group.write=0b000010000
            \\file.others.read=0b000001000
            \\file.others.write=0b000000100
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        std.debug.print("文件权限掩码:\n", .{});
        std.debug.print("  owner: 0b{b:0>9}\n", .{try config.getU32("file.owner")});
        std.debug.print("  group: 0b{b:0>9}\n", .{try config.getU32("file.group")});
        std.debug.print("  others: 0b{b:0>9}\n", .{try config.getU32("file.others")});

        std.debug.print("  ✓ 文件权限配置成功\n\n", .{});
    }

    // 示例 5: 实际应用场景 - 硬件寄存器配置
    {
        std.debug.print("示例 5: 实际应用 - 硬件寄存器\n", .{});
        std.debug.print("--------------------------------\n", .{});

        const config_content =
            \\[registers]
            \\# GPIO 配置寄存器
            \\gpio.direction.0:u16=1
            \\gpio.direction.1:u16=2
            \\gpio.direction.2:u16=4
            \\gpio.direction.3:u16=8
            \\
            \\# 中断使能寄存器
            \\int.enable.uart:u8=0x01
            \\int.enable.timer:u8=0x02
            \\int.enable.gpio:u8=0x04
            \\int.enable.i2c:u8=0x08
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        std.debug.print("寄存器配置:\n", .{});
        std.debug.print("  GPIO 方向寄存器: 0x{X:0>4} (0b{b:0>16})\n", .{
            try config.getSectionU16("registers", "gpio.direction"),
            try config.getSectionU16("registers", "gpio.direction")
        });
        std.debug.print("  中断使能寄存器: 0x{X:0>2} (0b{b:0>8})\n", .{
            try config.getSectionU8("registers", "int.enable"),
            try config.getSectionU8("registers", "int.enable")
        });

        std.debug.print("  ✓ 硬件寄存器配置成功\n\n", .{});
    }

    // 示例 6: 不同进制混合的位合并
    {
        std.debug.print("示例 6: 不同进制混合\n", .{});
        std.debug.print("------------------------\n", .{});

        const config_content =
            \\# 不同进制表示的位标志
            \\status.bit1=0b00000001
            \\status.bit2=0x02
            \\status.bit3=4
            \\status.bit4=0b00001000
            \\status.bit5=0x10
        ;

        var config = Ini.init(allocator);
        defer config.deinit();

        try config.loadFromString(config_content);

        const merged = try config.getU8("status");
        std.debug.print("status 合并值: {} (0x{X:0>2}, 0b{b:0>8})\n", .{ merged, merged, merged });

        std.debug.print("  ✓ 不同进制混合成功\n\n", .{});
    }

    std.debug.print("=== 所有演示完成 ===\n", .{});
}
