const std = @import("std");

pub const CompilerErrorKind = error{
    /// Occurs when there is more than one ".entry" directives in the input file.
    DuplicateEntryDirective,

    /// Occurs when there is no ".entry" directive in the input file.
    MissingEntryDirective,

    /// Occurs when a label that has been used has not been declared/defined.
    UndefinedLabel,

    /// Occurs when a label is declared/defined two or more times.
    RedefinedLabel,

    /// Occurs when the addressing mode for the instruction is invalid.
    InvalidAddressingMode,

    /// Occurs when the operands for a given instruction are invalid.
    InvalidOperand,

    /// Occurs when there are duplicate ".segment" directives.
    DuplicateSegment,

    /// Occurs when there is no .segment .text directive
    MissingTextSegment,

    /// Occurs when a directive that is exclusive to a certain segment is used
    /// outside of that segment.
    DirectiveOutsideDataSegment,

    /// Occurs when an instruction is used outside of a ".text" segment.
    InstructionOutsideTextSegment,

    /// Occurs when a segment is not valid.
    InvalidSegment,

    /// Occurs when the OS raises an out-of-memory exception.
    OutOfMemory,
};

/// Wrapper struct for storing a Compiler error.
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
            error.DuplicateSegment => "Duplicate segment",
            error.MissingTextSegment => "Missing text segment",
            error.DirectiveOutsideDataSegment => "Directive cannot be used outside data segment",
            error.InstructionOutsideTextSegment => "Instruction outside text segment",
            error.InvalidSegment => "Invalid segment",
            error.OutOfMemory => "Out of memory, cannot continue compilation",
        };

        try writer.print("[line {d}] {s}: {s}", .{ self.line, message_kind, self.literal });
    }
};
