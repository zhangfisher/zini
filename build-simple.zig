//! 简化的 zini 构建脚本
//! 只测试当前平台，避免跨平台执行错误

const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
    const target = b.standardTargetOptions.{});

    // 创建测试步骤
    const test_step = b.step("test", "运行所有测试");

    // 测试 ini.zig（仅当前平台）
    const ini_test = b.addTest(.{
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 运行测试
    const run_ini_test = b.addRunArtifact(ini_test);
    test_step.dependOn(&run_ini_test.step);

    // 构建库（可选）
    const ini_module = b.createModule(.{
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 静态库
    const static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zini",
        .root_module = ini_module,
    });
    b.installArtifact(static_lib);

    // 动态库
    const dynamic_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "zini",
        .root_module = ini_module,
    });
    b.installArtifact(dynamic_lib);
}
