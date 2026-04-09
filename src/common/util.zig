const std = @import("std");

/// utility function that abstracts comparation of two strings.
fn strcmp(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// A generic type that allows static HashMaps to be built.
pub fn StaticMap(comptime V: type) type {
    return std.StaticStringMapWithEql(V, strcmp);
}
