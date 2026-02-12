const std = @import("std");

fn strcmp(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn StaticMap(comptime V: type) type {
    return std.StaticStringMapWithEql(V, strcmp);
}
