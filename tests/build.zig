//! tests 目录构建脚本
//! 使用 Zig 0.16 正确的 API 和模块路径

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 创建主测试步骤
    const test_step = b.step("test", "运行 tests 目录下的所有测试");

    // 创建 zini 模块（指向父目录）
    const zini_module = b.createModule(.{
        .root_source_file = b.path("../src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 测试文件列表
    const test_files = [_]struct { []const u8, []const u8 }{
        .{ "auto_type_inference.zig", "auto_type_inference" },
        // .{ "benchmarks.zig", "benchmarks" },
        // .{ "complete_verification.zig", "complete_verification" },
        // .{ "datatype_consistency.zig", "datatype_consistency" },
        // .{ "default_value_fallback.zig", "default_value_fallback" },
        // .{ "documentation.zig", "documentation" },
        // .{ "forEach_refactor_test.zig", "forEach_refactor_test" },
        // .{ "forEach_verify.zig", "forEach_verify" },
        // .{ "getItem_test.zig", "getItem_test" },
        // .{ "getSchema_section_syntax.zig", "getSchema_section_syntax" },
        // .{ "ini_options.zig", "ini_options" },
        // .{ "item_iteration.zig", "item_iteration" },
        // .{ "item_iteration_simple.zig", "item_iteration_simple" },
        // .{ "metadata_system.zig", "metadata_system" },
        // .{ "multiline_strings.zig", "multiline_strings" },
        // .{ "path_syntax.zig", "path_syntax" },
        // .{ "reset_functionality.zig", "reset_functionality" },
        // .{ "type_annotation_set.zig", "type_annotation_set" },
        // .{ "types.zig", "types" },
    };

    // 为每个测试文件创建独立的步骤和运行器
    for (test_files) |test_info| {
        const file = test_info[0];
        const name = test_info[1];

        // 创建单个测试步骤
        const single_test_step = b.step(name, b.fmt("运行 {s} 测试", .{name}));

        // 创建测试模块，导入 zini 模块
        const test_module = b.createModule(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = optimize,
            // 链接libc（因为zini使用c_allocator）
        });

        test_module.link_libc = true;

        // 将 zini 模块添加到测试模块的导入中
        test_module.addImport("zini", zini_module);

        // 创建测试
        const test_exe = b.addTest(.{
            .root_module = test_module,
        });

        // 运行测试
        const run_test = b.addRunArtifact(test_exe);
        single_test_step.dependOn(&run_test.step);

        // 同时添加到主测试步骤
        test_step.dependOn(&run_test.step);
    }
}
