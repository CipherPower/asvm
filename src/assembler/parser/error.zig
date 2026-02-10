const std = @import("std");

pub const ParserErrorKind = error{
    UnexpectedToken,
    UnrecognisedIdentifier,
    UnrecognisedInstruction,
    UnexpectedOperand,
    OutOfMemory,
};

pub const ParserError = struct {
    kind: ParserErrorKind,
    literal: []const u8,
    line: usize,

    const Self = @This();

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        const message_kind: []const u8 = switch (self.kind) {
            error.UnexpectedToken => "Unexpected token",
            error.UnexpectedOperand => "Unexpected operand",
            error.UnrecognisedIdentifier => "Unrecognised identifier",
            error.UnrecognisedInstruction => "Unrecognised instruction",
            error.OutOfMemory => "Out of memory, cannot continue parsing"
        };

        try writer.print("[line {d}] {s}: \"{s}\"", .{ self.line, message_kind, self.literal });
    }
};
