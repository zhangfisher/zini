const std = @import("std");

/// 获取指定名称的环境变量值
/// 参数: name - 环境变量名称
/// 返回: 环境变量的值，如果不存在则返回null
pub fn getEnv(name: []const u8) ?[:0]const u8 {
    const builtin = @import("builtin");

    switch (builtin.os.tag) {
        .windows => {
            // Windows: 使用std.process.Environ.getWindows，然后转换为UTF-8
            var name_w = std.heap.page_allocator.alloc(u16, name.len + 1) catch return null;
            defer std.heap.page_allocator.free(name_w);

            // 转换为UTF-16LE
            for (name, 0..) |c, i| {
                name_w[i] = c;
            }
            name_w[name.len] = 0;

            const environ = std.process.Environ{ .block = .{ .use_global = true } };
            const name_w_ptr: [*:0]const u16 = @ptrCast(name_w.ptr);
            const result_w = std.process.Environ.getWindows(environ, name_w_ptr) orelse return null;

            // 转换UTF-16LE到UTF-8
            // UTF-16LE字符串以0结尾，需要先找到长度
            var result_w_len: usize = 0;
            while (result_w[result_w_len] != 0) : (result_w_len += 1) {}

            // 计算UTF-8所需的最大空间（每个UTF-16字符最多4字节，加上null终止符）
            const max_utf8_len = result_w_len * 4 + 1;
            const result_utf8 = std.heap.page_allocator.alloc(u8, max_utf8_len) catch return null;
            const written = std.unicode.utf16LeToUtf8(result_utf8[0 .. max_utf8_len - 1], result_w[0..result_w_len]) catch return null;
            result_utf8[written] = 0; // 添加null终止符

            // 创建以0结尾的切片
            return result_utf8[0..written :0];
        },
        else => {
            // POSIX: 使用std.process.Environ.getPosix
            const environ = std.process.Environ{ .block = .{ .use_global = true } };
            const result = std.process.Environ.getPosix(environ, name);
            return result;
        },
    }
}

/// 获取所有以指定前缀开头的环境变量名称列表
/// 参数: prefix - 环境变量名称前缀
/// 返回: 匹配的环境变量名称切片列表，如果没有匹配则返回空切片
pub fn getEnvs(prefix: []const u8) [][]const u8 {
    const builtin = @import("builtin");

    switch (builtin.os.tag) {
        .windows => {
            return getEnvsWindows(prefix);
        },
        else => {
            return getEnvsPosix(prefix);
        },
    }
}

/// Windows平台的getEnvs实现
fn getEnvsWindows(prefix: []const u8) [][]const u8 {
    const allocator = std.heap.page_allocator;
    var name_list = std.ArrayList([]const u8).initCapacity(allocator, 16) catch return &[_][]const u8{};
    defer name_list.deinit(allocator);

    // 获取PEB中的环境变量块
    const peb = std.os.windows.peb();
    const env_ptr = peb.ProcessParameters.Environment;

    // 遍历所有环境变量
    var i: usize = 0;
    while (env_ptr[i] != 0) {
        const env_value = env_ptr[i..];
        // 计算UTF-16字符串长度（以0结尾）
        var len: usize = 0;
        while (env_value[len] != 0) : (len += 1) {}

        // 查找'='分隔符
        var eq_idx: usize = 0;
        while (eq_idx < len and env_value[eq_idx] != '=') : (eq_idx += 1) {}

        if (eq_idx > 0 and eq_idx < len) {
            // 提取环境变量名称（UTF-16LE）
            const name_w = env_value[0..eq_idx];

            // 转换为UTF-8进行比较
            const max_utf8_len = eq_idx * 4;
            const name_utf8 = allocator.alloc(u8, max_utf8_len) catch break;
            const written = std.unicode.utf16LeToUtf8(name_utf8, name_w) catch {
                allocator.free(name_utf8);
                i += len + 1;
                continue;
            };

            const name_str = name_utf8[0..written];

            // 检查是否以prefix开头
            if (std.mem.startsWith(u8, name_str, prefix)) {
                // 分配持久内存存储名称
                const persistent_name = allocator.alloc(u8, written) catch {
                    allocator.free(name_utf8);
                    i += len + 1;
                    continue;
                };
                @memcpy(persistent_name, name_utf8[0..written]);
                name_list.append(allocator, persistent_name) catch {
                    allocator.free(persistent_name);
                    allocator.free(name_utf8);
                    i += len + 1;
                    continue;
                };
            }

            allocator.free(name_utf8);
        }

        // 跳过到下一个环境变量（包括null终止符）
        i += len + 1;
    }

    // 将ArrayList转换为切片
    const result = allocator.alloc([]const u8, name_list.items.len) catch {
        // 清理已分配的内存
        for (name_list.items) |item| {
            allocator.free(item);
        }
        return &[_][]const u8{};
    };

    @memcpy(result, name_list.items);
    return result;
}

/// POSIX平台的getEnvs实现
fn getEnvsPosix(prefix: []const u8) [][]const u8 {
    const allocator = std.heap.page_allocator;
    var name_list = std.ArrayList([]const u8).initCapacity(allocator, 16) catch return &[_][]const u8{};
    defer name_list.deinit(allocator);

    const c_env = std.c.environ;
    var i: usize = 0;

    while (c_env[i] != null) : (i += 1) {
        const entry = c_env[i].?;
        const entry_str = std.mem.sliceTo(entry, 0);

        // 查找'='分隔符
        if (std.mem.indexOf(u8, entry_str, "=")) |eq_idx| {
            const name = entry_str[0..eq_idx];

            // 检查是否以prefix开头
            if (std.mem.startsWith(u8, name, prefix)) {
                // 分配持久内存存储名称
                const persistent_name = allocator.alloc(u8, name.len) catch continue;
                @memcpy(persistent_name, name);
                name_list.append(allocator, persistent_name) catch {
                    allocator.free(persistent_name);
                    continue;
                };
            }
        }
    }

    // 将ArrayList转换为切片
    const result = allocator.alloc([]const u8, name_list.items.len) catch {
        // 清理已分配的内存
        for (name_list.items) |item| {
            allocator.free(item);
        }
        return &[_][]const u8{};
    };

    @memcpy(result, name_list.items);
    return result;
}

pub fn main() !void {
    // 测试getEnv函数
    std.debug.print("=== 测试 getEnv ===\n", .{});

    if (getEnv("PATH")) |path| {
        std.debug.print("PATH: {s}\n", .{path});
    } else {
        std.debug.print("PATH not found\n", .{});
    }

    if (getEnv("NONEXISTENT_VAR")) |val| {
        std.debug.print("NONEXISTENT_VAR: {s}\n", .{val});
    } else {
        std.debug.print("NONEXISTENT_VAR not found\n", .{});
    }

    // 测试getEnvs函数
    std.debug.print("\n=== 测试 getEnvs ===\n", .{});

    // 查找所有以"PATH"开头的环境变量
    const path_vars = getEnvs("PATH");
    defer {
        // 释放内存
        for (path_vars) |item| {
            std.heap.page_allocator.free(item);
        }
        std.heap.page_allocator.free(path_vars);
    }

    std.debug.print("以'PATH'开头的环境变量:\n", .{});
    for (path_vars, 0..) |var_name, index| {
        std.debug.print("  {d}: {s}\n", .{index, var_name});
    }

    // 查找所有以"PUB"开头的环境变量（如果有）
    const pub_vars = getEnvs("PUB");
    defer {
        for (pub_vars) |item| {
            std.heap.page_allocator.free(item);
        }
        std.heap.page_allocator.free(pub_vars);
    }

    std.debug.print("\n以'PUB'开头的环境变量:\n", .{});
    if (pub_vars.len == 0) {
        std.debug.print("  (无)\n", .{});
    } else {
        for (pub_vars, 0..) |var_name, index| {
            std.debug.print("  {d}: {s}\n", .{index, var_name});
        }
    }

    // 查找所有以"USER"开头的环境变量
    const user_vars = getEnvs("USER");
    defer {
        for (user_vars) |item| {
            std.heap.page_allocator.free(item);
        }
        std.heap.page_allocator.free(user_vars);
    }

    std.debug.print("\n以'USER'开头的环境变量:\n", .{});
    for (user_vars, 0..) |var_name, index| {
        std.debug.print("  {d}: {s}\n", .{index, var_name});
    }
}
