const std = @import("std");
const testing = std.testing;

const Parser = @import("parser").Parser;
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

    try parser.parse(@constCast(input));

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

    try parser.parse(@constCast(input));

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
        .init(.{ .instruction = .{ .instruction = .mov, .operands = .{ .{ .register = 0 }, .{ .integer = 10 } } } }, 1),
        .init(.{ .instruction = .{ .instruction = .add, .operands = .{ .{ .register = 1 }, .{ .register = 2 } } } }, 2),
        .init(.{ .instruction = .{ .instruction = .jmp, .operands = .{ .{ .label = "my_label" }, .none } } }, 3),
    };

    var parser: Parser = .init(testing.allocator);
    defer parser.deinit();

    try parser.parse(@constCast(input));

    try assert(!parser.hasErrors());
    try assertEqual(expected, parser.statements.items);

    printPass("parsing instructions");
}
