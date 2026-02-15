const std = @import("std");

const Scanner = @import("scanner").Scanner;
const Parser = @import("parser").Parser;
const Compiler = @import("compiler").Compiler;

pub const Assembler = struct {
    scanner: Scanner,
    parser: Parser,
    compiler: Compiler,

    allocator: std.mem.Allocator,

    stderr: *std.Io.Writer,
    stdout: *std.Io.Writer,

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, stdout: *std.Io.Writer, stderr: *std.Io.Writer) Self {
        return .{
            .scanner = .init(alloc),
            .parser = .init(alloc),
            .compiler = .init(alloc),

            .allocator = alloc,

            .stderr = stderr,
            .stdout = stdout,
        };
    }

    pub fn deinit(self: *Self) void {
        self.scanner.deinit();
        self.parser.deinit();
        self.compiler.deinit();
    }

    pub fn assemble(file: *std.fs.File, file_name: ?[]const u8) !void {}
};
