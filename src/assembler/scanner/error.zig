const std = @import("std");

pub const ScannerErrorKind = error{
    UnexpectedCharacter,
    UnterminatedStringLiteral,
    InvalidIntegerLiteral,
    InvalidRegisterLiteral,
    OutOfMemory,
};

pub const ScannerError = struct {
    kind: ScannerErrorKind,
    literal: []const u8,
    line: usize,

    const Self = @This();

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        const message_kind: []const u8 = switch (self.kind) {
            error.InvalidIntegerLiteral => "Invalid integer literal",
            error.InvalidRegisterLiteral => "Invalid register literal",
            error.UnexpectedCharacter => "Unexpected Character",
            error.UnterminatedStringLiteral => "Unterminated string literal, expected delimiter \" after literal",
            error.OutOfMemory => "Out of memory, cannot continue scanning",
        };

        try writer.print("[line {d}] {s}: \"{s}\"", .{ self.line, message_kind, self.literal });
    }
};
