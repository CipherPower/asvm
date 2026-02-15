const std = @import("std");
const testing = std.testing;

const Token = @import("token").Token;
const Scanner = @import("scanner").Scanner;

const assert = testing.expect;
const assertEqual = testing.expectEqualDeep;

fn printPass(test_name: []const u8) void {
    std.debug.print("test: \"{s}\" passed!\n", .{test_name});
}

test "empty scanner" {
    var scanner: Scanner = .init(testing.allocator);
    defer scanner.deinit();

    printPass("empty scanner");
}

test "scanning comments and whitespace" {
    const input: []const u8 =
        \\; this is a comment
        \\
        \\    ; this is also a comment
    ;

    const expected: []const Token = &.{
        .init(.eof, 3),
    };

    var scanner: Scanner = .init(testing.allocator);
    defer scanner.deinit();

    try scanner.scan(input);

    try assert(!scanner.hasErrors());
    try assertEqual(expected, scanner.tokens.items);

    printPass("scanning comments and whitespace");
}

test "scanning identifiers" {
    const input: []const u8 = "add, mov, xor";

    const expected: []const Token = &.{
        .init(.{ .identifier = "add" }, 1),
        .init(.comma, 1),
        .init(.{ .identifier = "mov" }, 1),
        .init(.comma, 1),
        .init(.{ .identifier = "xor" }, 1),
        .init(.eof, 1),
    };

    var scanner: Scanner = .init(testing.allocator);
    defer scanner.deinit();

    try scanner.scan(input);

    try assert(!scanner.hasErrors());
    try assertEqual(expected, scanner.tokens.items);

    printPass("scanning identifiers");
}

test "scanning numbers" {
    const input: []const u8 = "0xFF 0b0001 0o7 22";

    const expected: []const Token = &.{
        .init(.{ .integer = 255 }, 1),
        .init(.{ .integer = 1 }, 1),
        .init(.{ .integer = 7 }, 1),
        .init(.{ .integer = 22 }, 1),
        .init(.eof, 1),
    };

    var scanner: Scanner = .init(testing.allocator);
    defer scanner.deinit();

    try scanner.scan(input);

    try assert(!scanner.hasErrors());
    try assertEqual(expected, scanner.tokens.items);

    printPass("scanning numbers");
}

test "scanning registers" {
    const input: []const u8 = "r0 r1 r2 r3 r7";

    const expected: []const Token = &.{
        .init(.{ .register = 0 }, 1),
        .init(.{ .register = 1 }, 1),
        .init(.{ .register = 2 }, 1),
        .init(.{ .register = 3 }, 1),
        .init(.{ .register = 7 }, 1),
        .init(.eof, 1),
    };

    var scanner: Scanner = .init(testing.allocator);
    defer scanner.deinit();

    try scanner.scan(input);

    try assert(!scanner.hasErrors());
    try assertEqual(expected, scanner.tokens.items);

    printPass("scanning registers");
}

test "scanning a mini program" {
    const input: []const u8 =
        \\.entry _start
        \\_start:
        \\  mov r0, #1
        \\  syscall
    ;

    const expected: []const Token = &.{
        .init(.dot, 1),
        .init(.{ .identifier = "entry" }, 1),
        .init(.{ .identifier = "_start" }, 1),
        .init(.{ .identifier = "_start" }, 2),
        .init(.colon, 2),
        .init(.{ .identifier = "mov" }, 3),
        .init(.{ .register = 0 }, 3),
        .init(.comma, 3),
        .init(.hashtag, 3),
        .init(.{ .integer = 1 }, 3),
        .init(.{ .identifier = "syscall" }, 4),
        .init(.eof, 4),
    };

    var scanner: Scanner = .init(testing.allocator);
    defer scanner.deinit();

    try scanner.scan(input);

    try assert(!scanner.hasErrors());
    try assertEqual(expected, scanner.tokens.items);

    printPass("scanning a mini program");
}

test "scanning string literals" {
    const input: []const u8 =
        \\ "this is a string"
        \\ "this is also a string"
        \\ "eof string lit"
    ;

    const expected: []const Token = &.{
        .init(.{ .string_literal = "this is a string" }, 1),
        .init(.{ .string_literal = "this is also a string" }, 2),
        .init(.{ .string_literal = "eof string lit" }, 3),
        .init(.eof, 3),
    };

    var scanner: Scanner = .init(testing.allocator);
    defer scanner.deinit();

    try scanner.scan(input);

    try assert(!scanner.hasErrors());
    try assertEqual(expected, scanner.tokens.items);

    printPass("scanning string literals");
}

test "scanning bad input" {
    const input: []const u8 = "0x r100";

    var scanner: Scanner = .init(testing.allocator);
    defer scanner.deinit();

    try scanner.scan(input);

    try assert(scanner.hasErrors());
    try assert(scanner.errors.items.len == 2);

    printPass("scanning bad input");
}
