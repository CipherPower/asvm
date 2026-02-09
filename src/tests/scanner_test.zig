const std = @import("std");
const testing = std.testing;

const assert = testing.expect;
const assertEq = testing.expectEqualDeep;

const Scanner = @import("scanner").Scanner;

fn printPass(test_name: []const u8) void {
    std.debug.print("test: \"{s}\" passed!\n", .{test_name});
}

test "empty scanner" {
    const scanner: Scanner = .init(testing.allocator);
    _ = scanner;

    printPass("empty scanner");
}
