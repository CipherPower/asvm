const std = @import("std");

pub const CompilerErrorKind = error{
    DuplicateEntryDirective,
    MissingEntryDirective,
    UndefinedLabel,
    RedefinedLabel,
    InvalidAddressingMode,
    InvalidOperand,
    OutOfMemory,
};

pub const CompilerError = struct {
    kind: CompilerErrorKind,
    literal: []const u8,
    line: usize,

    const Self = @This();

    pub fn init(kind: CompilerErrorKind, literal: []const u8, line: usize) Self {
        return .{
            .kind = kind,
            .literal = literal,
            .line = line,
        };
    }

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        const message_kind: []const u8 = switch (self.kind) {
            error.DuplicateEntryDirective => "Duplicate entry directive",
            error.InvalidAddressingMode => "Invalid addressing mode",
            error.InvalidOperand => "Invalid operand for instruction",
            error.MissingEntryDirective => "Missing entry directive",
            error.UndefinedLabel => "Label not defined",
            error.RedefinedLabel => "Label redefined",
            error.OutOfMemory => "Out of memory, cannot continue compilation",
        };

        try writer.print("[line {d}] {s}: {s}", .{ self.line, message_kind, self.literal });
    }
};
