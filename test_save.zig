const std = @import("std");
const Ini = @import("src/root.zig").Ini;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var ini = Ini.init(allocator);
    defer ini.deinit();

    const content =
        \# @type u16
        \port = 9000
    ;

    try ini.loadFromString(content);
    const saved = try ini.saveToString(allocator);
    defer allocator.free(saved);
    
    std.debug.print("{s}", .{saved});
}
