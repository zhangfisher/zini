const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 创建主模块
    const mod = b.addModule("zini", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // 类型演示可执行文件
    const simple_types_exe = b.addExecutable(.{
        .name = "simple_types",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/simple_types.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    const simple_types_step = b.step("simple_types", "Run simple types demo");
    const simple_types_cmd = b.addRunArtifact(simple_types_exe);
    simple_types_step.dependOn(&simple_types_cmd.step);

    // 类型标识演示可执行文件
    const type_annot_exe = b.addExecutable(.{
        .name = "type_annotation",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/type_annotation.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    const type_annot_step = b.step("type_annot", "Run type annotation demo");
    const type_annot_cmd = b.addRunArtifact(type_annot_exe);
    type_annot_step.dependOn(&type_annot_cmd.step);

    // 行尾注释演示可执行文件
    const line_comments_exe = b.addExecutable(.{
        .name = "line_comments",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/line_comments.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    const line_comments_step = b.step("comments", "Run line comments demo");
    const line_comments_cmd = b.addRunArtifact(line_comments_exe);
    line_comments_step.dependOn(&line_comments_cmd.step);

    // 中文支持测试可执行文件
    const chinese_exe = b.addExecutable(.{
        .name = "chinese_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/chinese_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    const chinese_step = b.step("chinese", "Run chinese support test");
    const chinese_cmd = b.addRunArtifact(chinese_exe);
    chinese_step.dependOn(&chinese_cmd.step);

    // 二进制/十六进制演示可执行文件
    const number_bases_exe = b.addExecutable(.{
        .name = "number_bases",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/number_bases.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    const number_bases_step = b.step("bases", "Run number bases demo");
    const number_bases_cmd = b.addRunArtifact(number_bases_exe);
    number_bases_step.dependOn(&number_bases_cmd.step);

    const types_exe = b.addExecutable(.{
        .name = "types_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/types_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    const types_demo_step = b.step("types", "Run types demo");
    const types_demo_cmd = b.addRunArtifact(types_exe);
    types_demo_step.dependOn(&types_demo_cmd.step);

    // 保存时不指定路径演示可执行文件
    const save_without_path_exe = b.addExecutable(.{
        .name = "save_without_path",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/save_without_path.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
            .link_libc = true,
        }),
    });

    const save_without_path_step = b.step("save_demo", "Run save without path demo");
    const save_without_path_cmd = b.addRunArtifact(save_without_path_exe);
    save_without_path_step.dependOn(&save_without_path_cmd.step);

    // 路径语法演示可执行文件
    const path_syntax_exe = b.addExecutable(.{
        .name = "path_syntax",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/path_syntax.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
            .link_libc = true,
        }),
    });

    const path_syntax_step = b.step("path_syntax", "Run path syntax demo");
    const path_syntax_cmd = b.addRunArtifact(path_syntax_exe);
    path_syntax_step.dependOn(&path_syntax_cmd.step);

    // 智能类型演示可执行文件
    const smart_types_exe = b.addExecutable(.{
        .name = "smart_types",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/smart_types.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
            .link_libc = true,
        }),
    });

    const smart_types_step = b.step("smart_types", "Run smart types demo");
    const smart_types_cmd = b.addRunArtifact(smart_types_exe);
    smart_types_step.dependOn(&smart_types_cmd.step);

    // getSchema 演示可执行文件
    const getschema_demo_exe = b.addExecutable(.{
        .name = "getSchema_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/getSchema_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
            .link_libc = true,
        }),
    });

    const getschema_demo_step = b.step("getSchema_demo", "Run getSchema demo");
    const getschema_demo_cmd = b.addRunArtifact(getschema_demo_exe);
    getschema_demo_step.dependOn(&getschema_demo_cmd.step);

    // 测试
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    // 文档注释测试
    const doc_tests_mod = b.createModule(.{
        .root_source_file = b.path("tests/documentation.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    const doc_tests = b.addTest(.{
        .root_module = doc_tests_mod,
    });

    const run_doc_tests = b.addRunArtifact(doc_tests);

    // Schema iteration tests
    const schema_iteration_mod = b.createModule(.{
        .root_source_file = b.path("tests/schema_iteration.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    const schema_iteration_tests = b.addTest(.{
        .root_module = schema_iteration_mod,
    });

    const run_schema_iteration_tests = b.addRunArtifact(schema_iteration_tests);

    // getSchema section syntax tests
    const getschema_section_mod = b.createModule(.{
        .root_source_file = b.path("tests/getSchema_section_syntax.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    const getschema_section_tests = b.addTest(.{
        .root_module = getschema_section_mod,
    });

    const run_getschema_section_tests = b.addRunArtifact(getschema_section_tests);

    // 多行字符串测试
    const multiline_strings_mod = b.createModule(.{
        .root_source_file = b.path("tests/multiline_strings.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    const multiline_strings_tests = b.addTest(.{
        .root_module = multiline_strings_mod,
    });

    const run_multiline_strings_tests = b.addRunArtifact(multiline_strings_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_doc_tests.step);
    test_step.dependOn(&run_schema_iteration_tests.step);
    test_step.dependOn(&run_getschema_section_tests.step);
    test_step.dependOn(&run_multiline_strings_tests.step);
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_doc_tests.step);
    test_step.dependOn(&run_schema_iteration_tests.step);
    test_step.dependOn(&run_getschema_section_tests.step);
    test_step.dependOn(&run_multiline_strings_tests.step);

    // Zig 0.16 特性：基准测试
    const bench_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/benchmarks.zig"),
            .target = target,
            .optimize = .ReleaseFast, // 基准测试使用最快优化
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    const bench_step = b.step("bench", "Run benchmarks");
    const bench_cmd = b.addRunArtifact(bench_exe);
    bench_step.dependOn(&bench_cmd.step);

    // 添加文档生成步骤
    const docs_step = b.step("docs", "Generate documentation");
    const docs_obj = b.addObject(.{
        .name = "zini_docs",
        .root_module = mod,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    docs_step.dependOn(&install_docs.step);

    // ========== C 库构建 ==========

    // 创建 C API 模块
    const capi_mod = b.createModule(.{
        .root_source_file = b.path("src/capi.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    // 静态库
    const static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zini",
        .root_module = capi_mod,
    });

    b.installArtifact(static_lib);

    // 动态库
    const shared_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "zini_shared",
        .root_module = capi_mod,
    });

    b.installArtifact(shared_lib);

    // 头文件生成和安装
    const header_step = b.step("header", "Generate C header file");
    const header_install = b.addInstallFile(
        b.path("include/zini.h"),
        "include/zini.h"
    );
    header_step.dependOn(&header_install.step);

    // ReleaseFast 静态库
    const fast_static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zini_fast",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/capi.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    // ReleaseFast 动态库
    const fast_shared_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "zini_fast_shared",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/capi.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    // 安装 fast 版本库
    b.installArtifact(fast_static_lib);
    b.installArtifact(fast_shared_lib);

    // 库构建步骤
    const lib_step = b.step("lib", "Build C library (static and shared)");
    lib_step.dependOn(b.getInstallStep());

    // Fast 版本库构建步骤
    const lib_fast_step = b.step("lib-fast", "Build C library (ReleaseFast)");
    lib_fast_step.dependOn(&fast_static_lib.step);
    lib_fast_step.dependOn(&fast_shared_lib.step);

    // ReleaseSmall 静态库
    const small_static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zini_small",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/capi.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
            .link_libc = true,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    // ReleaseSmall 动态库
    const small_shared_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "zini_small_shared",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/capi.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
            .link_libc = true,
            .imports = &.{
                .{ .name = "zini", .module = mod },
            },
        }),
    });

    // 安装 small 版本库
    b.installArtifact(small_static_lib);
    b.installArtifact(small_shared_lib);

    // Small 版本库构建步骤
    const lib_small_step = b.step("lib-small", "Build C library (ReleaseSmall)");
    lib_small_step.dependOn(&small_static_lib.step);
    lib_small_step.dependOn(&small_shared_lib.step);

    // ========== ARM32 gnueabihf 库构建 ==========

    // ARM32 gnueabihf 目标
    const arm32_target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .linux,
        .abi = .gnueabihf,
    });

    // 创建 ARM32 C API 模块
    const arm32_capi_mod = b.createModule(.{
        .root_source_file = b.path("src/capi.zig"),
        .target = arm32_target,
        .optimize = .ReleaseSmall,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    // ARM32 静态库
    const arm32_static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zini",
        .root_module = arm32_capi_mod,
    });

    // ARM32 动态库
    const arm32_shared_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "zini",
        .root_module = arm32_capi_mod,
    });

    // 安装 ARM32 库（带架构后缀）
    const arm32_static_install = b.addInstallArtifact(arm32_static_lib, .{
        .dest_dir = .{ .override = .{ .custom = "lib/arm32-gnueabihf" } },
    });

    const arm32_shared_install = b.addInstallArtifact(arm32_shared_lib, .{
        .dest_dir = .{ .override = .{ .custom = "lib/arm32-gnueabihf" } },
    });

    // 创建 ARM32 构建步骤
    const arm32_step = b.step("arm32", "Build ARM32 gnueabihf C library (ReleaseSmall)");
    arm32_step.dependOn(&arm32_static_install.step);
    arm32_step.dependOn(&arm32_shared_install.step);

    // ========== 多平台 c_zini C API 库构建 ==========

    // 定义目标平台
    const x86_64_linux_gnu_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .gnu,
    });

    const x86_64_windows_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .msvc,
    });

    const arm32_linux_gnu_target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .linux,
        .abi = .gnueabihf,
    });

    const arm32_linux_musl_target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .linux,
        .abi = .musleabihf,
    });

    // ========== x86_64 Linux GNU ==========

    const x86_64_linux_gnu_capi_mod = b.createModule(.{
        .root_source_file = b.path("src/capi.zig"),
        .target = x86_64_linux_gnu_target,
        .optimize = .ReleaseSmall,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    const x86_64_linux_gnu_static = b.addLibrary(.{
        .linkage = .static,
        .name = "c_zini_x86_64_linux_gnu",
        .root_module = x86_64_linux_gnu_capi_mod,
    });

    const x86_64_linux_gnu_shared = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "c_zini_x86_64_linux_gnu",
        .root_module = x86_64_linux_gnu_capi_mod,
    });

    b.installArtifact(x86_64_linux_gnu_static);
    b.installArtifact(x86_64_linux_gnu_shared);

    // ========== x86_64 Windows ==========

    const x86_64_windows_capi_mod = b.createModule(.{
        .root_source_file = b.path("src/capi.zig"),
        .target = x86_64_windows_target,
        .optimize = .ReleaseSmall,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    const x86_64_windows_static = b.addLibrary(.{
        .linkage = .static,
        .name = "c_zini_x86_64_windows",
        .root_module = x86_64_windows_capi_mod,
    });

    const x86_64_windows_shared = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "c_zini_x86_64_windows",
        .root_module = x86_64_windows_capi_mod,
    });

    b.installArtifact(x86_64_windows_static);
    b.installArtifact(x86_64_windows_shared);

    // ========== ARM32 Linux GNU ==========

    const arm32_linux_gnu_capi_mod = b.createModule(.{
        .root_source_file = b.path("src/capi.zig"),
        .target = arm32_linux_gnu_target,
        .optimize = .ReleaseSmall,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    const arm32_linux_gnu_static = b.addLibrary(.{
        .linkage = .static,
        .name = "c_zini_arm_linux_gnueabihf",
        .root_module = arm32_linux_gnu_capi_mod,
    });

    const arm32_linux_gnu_shared = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "c_zini_arm_linux_gnueabihf",
        .root_module = arm32_linux_gnu_capi_mod,
    });

    b.installArtifact(arm32_linux_gnu_static);
    b.installArtifact(arm32_linux_gnu_shared);

    // ========== ARM32 Linux MUSL ==========

    const arm32_linux_musl_capi_mod = b.createModule(.{
        .root_source_file = b.path("src/capi.zig"),
        .target = arm32_linux_musl_target,
        .optimize = .ReleaseSmall,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zini", .module = mod },
        },
    });

    const arm32_linux_musl_static = b.addLibrary(.{
        .linkage = .static,
        .name = "c_zini_arm_linux_musleabihf",
        .root_module = arm32_linux_musl_capi_mod,
    });

    const arm32_linux_musl_shared = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "c_zini_arm_linux_musleabihf",
        .root_module = arm32_linux_musl_capi_mod,
    });

    b.installArtifact(arm32_linux_musl_static);
    b.installArtifact(arm32_linux_musl_shared);

    // ========== 统一构建步骤 ==========

    const c_zini_step = b.step("c-zini", "Build c_zini C library for all platforms (ReleaseSmall)");
    c_zini_step.dependOn(&x86_64_linux_gnu_static.step);
    c_zini_step.dependOn(&x86_64_linux_gnu_shared.step);
    c_zini_step.dependOn(&x86_64_windows_static.step);
    c_zini_step.dependOn(&x86_64_windows_shared.step);
    c_zini_step.dependOn(&arm32_linux_gnu_static.step);
    c_zini_step.dependOn(&arm32_linux_gnu_shared.step);
    c_zini_step.dependOn(&arm32_linux_musl_static.step);
    c_zini_step.dependOn(&arm32_linux_musl_shared.step);
}
