const std = @import("std");

const Scanner = @import("scanner").Scanner;
const Parser = @import("parser").Parser;
const Compiler = @import("compiler").Compiler;

/// Wrapper struct that facilitates conversion from a string into bytes.
pub const Assembler = struct {
    scanner: Scanner,
    parser: Parser,
    compiler: Compiler,

    allocator: std.mem.Allocator,

    stderr: *std.Io.Writer,

    const Self = @This();

    /// Instantiates a new assembler instance.
    pub fn init(alloc: std.mem.Allocator, stderr: *std.Io.Writer) Self {
        return .{
            .scanner = .init(alloc),
            .parser = .init(alloc),
            .compiler = .init(alloc),

            .allocator = alloc,

            .stderr = stderr,
        };
    }

    /// Deallocates all components of the assembler.
    pub fn deinit(self: *Self) void {
        self.scanner.deinit();
        self.parser.deinit();
        self.compiler.deinit();
    }

    /// Wrapper function over the individual methods that facilitate conversion,
    /// Returning an out of memory error, or null if there was any errors.
    pub fn assemble(self: *Self, source_code: []const u8) !?[]u8 {
        try self.scanner.scan(source_code);
        if (self.scanner.hasErrors()) {
            try self.scanner.handleErrors(self.stderr);
            return null;
        }

        try self.parser.parse(self.scanner.tokens.items);
        if (self.parser.hasErrors()) {
            try self.parser.handleErrors(self.stderr);
            return null;
        }

        try self.compiler.compile(self.parser.statements.items);
        if (self.compiler.hasErrors()) {
            try self.compiler.handleErrors(self.stderr);
            return null;
        }

        return self.compiler.output.items;
    }
};
