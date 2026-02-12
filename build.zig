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

    var instructions_mod = b.addModule("instructions", .{
        .root_source_file = b.path("src/common/instruction_set.zig"),
        .target = target,
        .optimize = optimize,
    });
    instructions_mod.addImport("util", util_mod);

    const token_mod = b.addModule("token", .{
        .root_source_file = b.path("src/common/token.zig"),
        .target = target,
        .optimize = optimize,
    });

    var statement_mod = b.addModule("statement", .{
        .root_source_file = b.path("src/common/statement.zig"),
        .target = target,
        .optimize = optimize,
    });
    statement_mod.addImport("util", util_mod);

    var scanner_mod = b.addModule("scanner", .{
        .root_source_file = b.path("src/assembler/scanner/scanner.zig"),
        .target = target,
        .optimize = optimize,
    });
    scanner_mod.addImport("token", token_mod);

    var parser_mod = b.addModule("parser", .{
        .root_source_file = b.path("src/assembler/parser/parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    parser_mod.addImport("token", token_mod);
    parser_mod.addImport("statement", statement_mod);
    parser_mod.addImport("instruction", instructions_mod);

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

    var scanner_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests/scanner_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    scanner_tests.root_module.addImport("scanner", scanner_mod);
    scanner_tests.root_module.addImport("token", token_mod);
    const run_scanner_tests = b.addRunArtifact(scanner_tests);

    // TEST STEP:

    const tests_step = b.step("test", "Run all tests");
    // tests_step.dependOn(&run_exe_tests.step);
    tests_step.dependOn(&run_scanner_tests.step);
}
