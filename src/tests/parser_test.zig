const std = @import("std");
const testing = std.testing;

const Parser = @import("parser").Parser;
const ParserErrorKind = @import("parser").ParserErrorKind;
const Statement = @import("statement").Statement;
const Token = @import("token").Token;

const assert = testing.expect;
const assertEqual = testing.expectEqualDeep;

fn printPass(test_name: []const u8) void {
    std.debug.print("test: \"{s}\" passed!\n", .{test_name});
}

test "empty parser" {
    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    printPass("empty parser");
}

test "parsing entry directive" {
    const input: []const Token = &.{
        .init(.dot, 1),
        .init(.{ .identifier = "entry" }, 1),
        .init(.{ .identifier = "_start" }, 1),
        .init(.eof, 2),
    };

    const expected: []const Statement = &.{
        .init(.{ .directive = .{ .entry = "_start" } }, 1),
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(input);

    try assert(!parser.hasErrors());
    try assertEqual(expected, parser.statements.items);

    printPass("parsing entry directive");
}

test "parsing labels" {
    const input: []const Token = &.{
        .init(.{ .identifier = "loop" }, 1),
        .init(.colon, 1),
        .init(.{ .identifier = "end" }, 2),
        .init(.colon, 2),
        .init(.eof, 3),
    };

    const expected: []const Statement = &.{
        .init(.{ .label = "loop" }, 1),
        .init(.{ .label = "end" }, 2),
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(input);

    try assert(!parser.hasErrors());
    try assertEqual(expected, parser.statements.items);

    printPass("parsing labels");
}

test "parsing instructions" {
    const input: []const Token = &.{
        .init(.{ .identifier = "mov" }, 1),
        .init(.{ .register = 0 }, 1),
        .init(.comma, 1),
        .init(.hashtag, 1),
        .init(.{ .integer = 10 }, 1),

        .init(.{ .identifier = "add" }, 2),
        .init(.{ .register = 1 }, 2),
        .init(.comma, 2),
        .init(.{ .register = 2 }, 2),

        .init(.{ .identifier = "jmp" }, 3),
        .init(.{ .identifier = "my_label" }, 3),

        .init(.eof, 4),
    };

    const expected: []const Statement = &.{
        .instr(.mov, 1, .{ .register = 0 }, .{ .integer = 10 }),
        .instr(.add, 2, .{ .register = 1 }, .{ .register = 2 }),
        .instr(.jmp, 3, .{ .label = "my_label" }, .none),
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(input);

    try assert(!parser.hasErrors());
    try assertEqual(expected, parser.statements.items);

    printPass("parsing instructions");
}

test "parsing program structure" {
    // .entry _start
    // _start:
    //      mov r0, #10
    //      jmp end

    const input: []const Token = &.{
        .init(.dot, 1),
        .init(.{ .identifier = "entry" }, 1),
        .init(.{ .identifier = "_start" }, 1),
        .init(.{ .identifier = "_start" }, 2),
        .init(.colon, 2),
        .init(.{ .identifier = "mov" }, 3),
        .init(.{ .register = 0 }, 3),
        .init(.comma, 3),
        .init(.hashtag, 3),
        .init(.{ .integer = 10 }, 3),
        .init(.{ .identifier = "jmp" }, 4),
        .init(.{ .identifier = "end" }, 4),
        .init(.eof, 5),
    };

    const expected: []const Statement = &.{
        .init(.{ .directive = .{ .entry = "_start" } }, 1),
        .init(.{ .label = "_start" }, 2),
        .instr(.mov, 3, .{ .register = 0 }, .{ .integer = 10 }),
        .instr(.jmp, 4, .{ .label = "end" }, .none),
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(input);

    try assert(!parser.hasErrors());
    try assertEqual(expected, parser.statements.items);

    printPass("parsing program structure");
}

test "parsing unknown instructions" {
    const input: []const Token = &.{
        .init(.{ .identifier = "nonsense" }, 1),
        .init(.{ .register = 0 }, 1),
        .init(.eof, 2),
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(input);

    try assert(parser.hasErrors());
    try assert(parser.errors.items[0].kind == ParserErrorKind.UnrecognisedInstruction);

    printPass("parsing unknown instructions");
}

test "parsing unexpected token" {
    // .entry #10
    // ^ nonsense code

    const input: []const Token = &.{
        .init(.dot, 1),
        .init(.{ .identifier = "entry" }, 1),
        .init(.hashtag, 1),
        .init(.{ .integer = 10 }, 1),
        .init(.eof, 2),
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(input);

    try assert(parser.hasErrors());
    try assert(parser.errors.items[0].kind == ParserErrorKind.UnexpectedToken);

    printPass("parsing unexpected token");
}

test "parsing zero operand instructions" {
    const input: []const Token = &.{
        .init(.{ .identifier = "syscall" }, 1),
        .init(.{ .identifier = "ret" }, 2),
        .init(.eof, 3),
    };

    const expected: []const Statement = &.{
        .instr(.syscall, 1, .none, .none),
        .instr(.ret, 2, .none, .none),
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(input);

    try assert(!parser.hasErrors());
    try assertEqual(expected, parser.statements.items);

    printPass("parsing zero operand instructions");
}

test "parser trailing comma error" {
    const input: []const Token = &.{
        .init(.{ .identifier = "mov" }, 1),
        .init(.{ .register = 0 }, 1),
        .init(.comma, 1),
        .init(.eof, 1), // unexpected eof
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(input);

    try assert(parser.hasErrors());
    try assert(parser.errors.items[0].kind == ParserErrorKind.UnexpectedOperand);

    printPass("parser trailing comma error");
}

test "parser error recovery multiple" {
    const input: []const Token = &.{
        .init(.{ .identifier = "nonsense" }, 1),

        .init(.{ .identifier = "mov" }, 2),
        .init(.{ .register = 0 }, 2),
        .init(.comma, 2),
        .init(.hashtag, 2),
        .init(.{ .integer = 1 }, 2),

        .init(.{ .identifier = "trash" }, 3),
        .init(.eof, 4),
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(input);

    try assert(parser.hasErrors());
    try assert(parser.errors.items.len == 2);
    try assert(parser.errors.items[0].kind == ParserErrorKind.UnrecognisedInstruction);
    try assert(parser.errors.items[1].kind == ParserErrorKind.UnrecognisedInstruction);

    printPass("parser error recovery multiple");
}
