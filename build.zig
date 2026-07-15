//! zini 构建脚本
//! 适配 Zig 0.16.0
//! 固定使用 ReleaseSmall 模式
//! 支持多平台构建：linux-x86-64, linux-x86-64-musl, linux-arm32-musl, windows-x86-64
//! 输出：ini -> zig-out/lib, test -> zig-out/test
//! 每个平台都构建静态库和动态库，文件名包含平台信息

const std = @import("std");

pub fn build(b: *std.Build) void {
    // 固定使用 ReleaseSmall 模式
    const optimize = .ReleaseSmall;

    // 定义要支持的目标平台
    const targets = [_]std.Target.Query{
        // linux-x86-64 (glibc)
        .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
        },
        // linux-x86-64-musl
        .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .musl,
        },
        // linux-arm32-musl
        .{
            .cpu_arch = .arm,
            .os_tag = .linux,
            .abi = .musleabihf,
        },
        // windows-x86-64
        .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
        },
    };

    // 创建测试步骤（只创建一次）
    const test_step = b.step("test", "运行所有测试");

    // 为每个目标平台构建库
    for (targets) |target_query| {
        const target = b.resolveTargetQuery(target_query);

        // 获取平台的三元组名称，用于创建子目录
        const target_triple = target.query.zigTriple(b.allocator) catch "unknown";

        // 构建 ini.zig 库 (输出到 zig-out/lib)
        buildIniLib(b, target, optimize, target_triple);

        // 构建测试 (输出到 zig-out/test)
        buildTests(b, target, optimize, target_triple, test_step);
    }
}

// 构建 ini.zig 的静态库和动态库
fn buildIniLib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, target_triple: []const u8) void {
    // 创建 ini 模块（需要 libc，因为使用了 std.heap.c_allocator）
    const ini_module = b.createModule(.{
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 构建静态库
    const static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zini",
        .root_module = ini_module,
    });

    // 安装静态库到 zig-out/lib/[platform]/
    const install_static = b.addInstallArtifact(static_lib, .{
        .dest_dir = .{ .override = .{ .custom = b.fmt("lib/{s}", .{target_triple}) } },
    });
    b.getInstallStep().dependOn(&install_static.step);

    // 构建动态库
    const dynamic_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "zini",
        .root_module = ini_module,
    });

    // 安装动态库到 zig-out/lib/[platform]/
    const install_dynamic = b.addInstallArtifact(dynamic_lib, .{
        .dest_dir = .{ .override = .{ .custom = b.fmt("lib/{s}", .{target_triple}) } },
    });
    b.getInstallStep().dependOn(&install_dynamic.step);
}

// 构建测试并输出到 zig-out/test
fn buildTests(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, target_triple: []const u8, test_step: *std.Build.Step) void {
    // 创建测试模块
    const test_module = b.createModule(.{
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 在模块中启用libc链接
    test_module.link_libc = true;

    // 创建 ini.zig 的测试
    const ini_test = b.addTest(.{
        .name = "ini_test",
        .root_module = test_module,
    });

    // 安装 ini 测试到 zig-out/test/[platform]/
    const install_ini_test = b.addInstallArtifact(ini_test, .{
        .dest_dir = .{ .override = .{ .custom = b.fmt("test/{s}", .{target_triple}) } },
    });
    b.getInstallStep().dependOn(&install_ini_test.step);

    // 将测试运行器添加到测试步骤
    const ini_test_run = b.addRunArtifact(ini_test);
    test_step.dependOn(&ini_test_run.step);
}
