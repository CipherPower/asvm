const std = @import("std");

pub const ScannerErrorKind = error{
    /// Occurs when the byte is unexpected.
    UnexpectedCharacter,

    /// Occurs when the string literal does not have a closing quotation mark.
    UnterminatedStringLiteral,

    /// Occurs when the Integer literal is invalid.
    InvalidIntegerLiteral,

    /// Occurs when the register literal is invalid.
    InvalidRegisterLiteral,

    /// Occurs when the OS throws an out-of-memory exception.
    OutOfMemory,
};

/// Wrapper struct for storing data about a ScannerError, such as the line it occured on.
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
