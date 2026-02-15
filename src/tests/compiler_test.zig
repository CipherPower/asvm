const std = @import("std");
const testing = std.testing;

const instruction = @import("instruction");

const Compiler = @import("compiler").Compiler;
const CompilerErrorKind = @import("compiler").CompilerErrorKind;

const Statement = @import("statement").Statement;

const InstructionSet = instruction.InstructionSet;
const InstructionHeader = instruction.InstructionHeader;
const AddressingMode = instruction.AddressingMode;

const assert = testing.expect;
const assertEqual = testing.expectEqualDeep;

fn printPass(test_name: []const u8) void {
    std.debug.print("test: \"{s}\" passed!\n", .{test_name});
}

fn instr(in: InstructionSet, mode: AddressingMode) u8 {
    return InstructionHeader.init(in, mode).value;
}

fn label(addr: u16) [@sizeOf(u16)]u8 {
    return std.mem.toBytes(addr);
}

fn int(val: i32) [@sizeOf(i32)]u8 {
    return std.mem.toBytes(val);
}

test "empty compiler" {
    var compiler: Compiler = .init(testing.allocator);
    defer compiler.deinit();

    printPass("empty compiler");
}

test "compiling minimal program" {
    const statements: []const Statement = &.{
        .init(.{ .directive = .{ .entry = "_start" } }, 1),
        .init(.{ .label = "_start" }, 2),
        .instr(.syscall, 3, .none, .none),
    };

    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(testing.allocator);
    try expected.appendSlice(testing.allocator, &label(2));
    try expected.append(testing.allocator, instr(.syscall, .register));

    var compiler: Compiler = .init(testing.allocator);
    defer compiler.deinit();

    try compiler.compile(statements);

    try assert(!compiler.hasErrors());
    try assertEqual(expected.items, compiler.output.items);

    printPass("compiling minimal program");
}

test "compiling program with registers and operands" {
    const statements: []const Statement = &.{
        .init(.{ .directive = .{ .entry = "_start" } }, 1),
        .init(.{ .label = "_start" }, 2),
        .instr(.mov, 3, .{ .register = 0 }, .{ .integer = 10 }),
    };

    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(testing.allocator);
    try expected.appendSlice(testing.allocator, &label(2));
    try expected.append(testing.allocator, instr(.mov, .immediate));
    try expected.append(testing.allocator, 0);
    try expected.appendSlice(testing.allocator, &int(10));

    var compiler: Compiler = .init(testing.allocator);
    defer compiler.deinit();

    try compiler.compile(statements);

    try assert(!compiler.hasErrors());
    try assertEqual(expected.items, compiler.output.items);

    printPass("compiling program with registers and operands");
}

test "compiling program with forward label resolution" {
    const statements: []const Statement = &.{
        .init(.{ .directive = .{ .entry = "_start" } }, 1),
        .init(.{ .label = "_start" }, 2),
        .instr(.jmp, 3, .{ .label = "end" }, .none),
        .init(.{ .label = "end" }, 4),
        .instr(.ret, 5, .none, .none),
    };

    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(testing.allocator);
    try expected.appendSlice(testing.allocator, &label(2));
    try expected.append(testing.allocator, instr(.jmp, .memory));
    try expected.appendSlice(testing.allocator, &label(5));
    try expected.append(testing.allocator, instr(.ret, .register));

    var compiler: Compiler = .init(testing.allocator);
    defer compiler.deinit();

    try compiler.compile(statements);

    try assert(!compiler.hasErrors());
    try assertEqual(expected.items, compiler.output.items);

    printPass("compiling program with forward label resolution");
}

test "compiler error missing entry directive" {
    // ret

    const statements: []const Statement = &.{
        .instr(.ret, 1, .none, .none),
    };

    var compiler: Compiler = .init(testing.allocator);
    defer compiler.deinit();

    try compiler.compile(statements);

    try assert(compiler.hasErrors());
    try assert(compiler.errors.items[0].kind == CompilerErrorKind.MissingEntryDirective);

    printPass("compiler error missing entry directive");
}

test "compiler error undefined label" {
    //.entry _start
    //_start:
    //  jmp missing_label

    const statements: []const Statement = &.{
        .init(.{ .directive = .{ .entry = "_start" } }, 1),
        .init(.{ .label = "_start" }, 2),
        .instr(.jmp, 3, .{ .label = "missing_label" }, .none),
    };

    var compiler: Compiler = .init(testing.allocator);
    defer compiler.deinit();

    try compiler.compile(statements);

    try assert(compiler.hasErrors());
    try assert(compiler.errors.items[0].kind == CompilerErrorKind.UndefinedLabel);

    printPass("compiler error undefined label");
}
