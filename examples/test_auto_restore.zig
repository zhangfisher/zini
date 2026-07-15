//! 测试自动注释保留功能

const std = @import("std");
const Ini = @import("../src/ini.zig").Ini;
const IniOptions = @import("../src/ini.zig").IniOptions;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("\n=== 测试自动注释保留 ===\n\n", .{});

    // 1. 使用默认API从文件加载
    std.debug.print("步骤1：使用默认API从文件加载 real_config.ini\n", .{});
    var ini = Ini.default(allocator);
    defer ini.deinit();
    try ini.load("examples/real_config.ini");

    const schema1 = ini.getSchema("db_host").?;
    std.debug.print("  db_host.title: {s}\n", .{schema1.title orelse "null"});
    std.debug.print("  db_host.description: {s}\n\n", .{schema1.description orelse "null"});

    // 2. 更新值
    try ini.set("db_host", "test.example.com");
    std.debug.print("步骤2：更新 db_host 为 test.example.com\n\n", .{});

    // 3. 保存到新文件
    std.debug.print("步骤3：保存到 test_output.ini\n", .{});
    try ini.save("examples/test_output.ini");

    // 4. 使用完整功能加载保存的文件
    std.debug.print("步骤4：使用完整功能加载保存的文件\n", .{});
    var ini2 = Ini.initWithOptions(allocator, IniOptions.withDescription());
    defer ini2.deinit();
    try ini2.load("examples/test_output.ini");

    const schema2 = ini2.getSchema("db_host").?;
    std.debug.print("  value: {s}\n", .{schema2.value});
    std.debug.print("  title: {s}\n", .{schema2.title orelse "null"});
    std.debug.print("  description: {s}\n\n", .{schema2.description orelse "null"});

    if (schema2.description != null) {
        std.debug.print("✓ 自动注释保留成功！description 已被恢复：{s}\n", .{schema2.description.?});
    } else {
        std.debug.print("✗ 自动注释保留失败！\n", .{});
    }

    std.debug.print("\n生成的文件：examples/test_output.ini\n", .{});
}
