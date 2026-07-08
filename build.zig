//! zini 构建脚本
//! 适配 Zig 0.16.0

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 模块定义
    const zini_module = b.addModule("zini", .{
        .root_source_file = b.path("src/ini.zig"),
    });

    // 主库配置
    const lib = b.addStaticLibrary(.{
        .name = "zini",
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // 测试配置
    const tests = b.addTest(.{
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "运行库测试");
    test_step.dependOn(&run_tests.step);

    // 示例程序
    const simple_types_exe = b.addExecutable(.{
        .name = "simple_types",
        .root_source_file = b.path("examples/simple_types.zig"),
        .target = target,
        .optimize = optimize,
    });
    simple_types_exe.root_module.addImport("zini", zini_module);
    b.installArtifact(simple_types_exe);

    const run_simple_types = b.addRunArtifact(simple_types_exe);
    const run_step = b.step("run", "运行示例程序");
    run_step.dependOn(&run_simple_types.step);
}
