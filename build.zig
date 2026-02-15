const std = @import("std");

pub fn build(b: *std.Build) void {
    // BUILD OPTIONS:

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // MODULES:

    const util_mod = b.addModule("util", .{
        .root_source_file = b.path("src/common/util.zig"),
        .target = target,
        .optimize = optimize,
    });

    const instructions_mod = b.addModule("instructions", .{
        .root_source_file = b.path("src/common/instruction_set.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "util", .module = util_mod },
        },
    });

    const token_mod = b.addModule("token", .{
        .root_source_file = b.path("src/common/token.zig"),
        .target = target,
        .optimize = optimize,
    });

    const statement_mod = b.addModule("statement", .{
        .root_source_file = b.path("src/common/statement.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "util", .module = util_mod },
            .{ .name = "instruction", .module = instructions_mod },
        },
    });

    const scanner_mod = b.addModule("scanner", .{
        .root_source_file = b.path("src/assembler/scanner/scanner.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "token", .module = token_mod },
        },
    });

    const parser_mod = b.addModule("parser", .{
        .root_source_file = b.path("src/assembler/parser/parser.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "token", .module = token_mod },
            .{ .name = "statement", .module = statement_mod },
            .{ .name = "instruction", .module = instructions_mod },
        },
    });

    const compiler_mod = b.addModule("compiler", .{
        .root_source_file = b.path("src/assembler/compiler/compiler.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "statement", .module = statement_mod },
            .{ .name = "instruction", .module = instructions_mod },
        },
    });

    const assembler_mod = b.addModule("assember", .{
        .root_source_file = b.path("src/assembler/assembler.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "scanner", .module = scanner_mod },
            .{ .name = "parser", .module = parser_mod },
            .{ .name = "compiler", .module = compiler_mod },
        },
    });

    _ = assembler_mod;

    const vm_mod = b.addModule("vm", .{
        .root_source_file = b.path("src/vm/vm.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "instruction", .module = instructions_mod },
        },
    });

    // EXECUTABLE:

    const exe = b.addExecutable(.{
        .name = "asvm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    b.installArtifact(exe);

    // RUN STEP:

    const run_step = b.step("run", "Run the executable");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // TEST MODULES:

    // const exe_tests = b.addTest(.{
    //     .root_module = exe.root_module,
    // });
    // const run_exe_tests = b.addRunArtifact(exe_tests);

    const scanner_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests/scanner_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "scanner", .module = scanner_mod },
                .{ .name = "token", .module = token_mod },
            },
        }),
    });
    const run_scanner_tests = b.addRunArtifact(scanner_tests);

    const parser_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests/parser_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "parser", .module = parser_mod },
                .{ .name = "token", .module = token_mod },
                .{ .name = "util", .module = util_mod },
                .{ .name = "instruction", .module = instructions_mod },
                .{ .name = "statement", .module = statement_mod },
            },
        }),
    });
    const run_parser_tests = b.addRunArtifact(parser_tests);

    const compiler_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests/compiler_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "compiler", .module = compiler_mod },
                .{ .name = "instruction", .module = instructions_mod },
                .{ .name = "statement", .module = statement_mod },
            },
        }),
    });
    const run_compiler_tests = b.addRunArtifact(compiler_tests);

    const vm_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests/vm_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vm", .module = vm_mod },
                .{ .name = "instruction", .module = instructions_mod },
            },
        }),
    });
    const run_vm_tests = b.addRunArtifact(vm_tests);

    // TEST STEP:

    const tests_step = b.step("test", "Run all tests");
    // tests_step.dependOn(&run_exe_tests.step);
    tests_step.dependOn(&run_scanner_tests.step);
    tests_step.dependOn(&run_parser_tests.step);
    tests_step.dependOn(&run_compiler_tests.step);
    tests_step.dependOn(&run_vm_tests.step);
}
