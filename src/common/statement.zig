const std = @import("std");
const InstructionSet = @import("instruction.zig").InstructionSet;

pub const Operand = union(enum) {
    register: u8,
    integer: i32,
    label: []const u8,
    none,

    const Self = @This();

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        switch (self) {
            .register => |reg| try writer.print("operand(register = {d})", .{reg}),
            .integer => |int| try writer.print("operand(integer = {d})", .{int}),
            .label => |label| try writer.print("operand(label = {s})", .{label}),
            .none => try writer.print("operand(none)"),
        }
    }
};

pub const Directive = union(enum) {
    entry: Operand, // label

    const Self = @This();

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        switch (self) {
            .entry => |op_label| try writer.print("directive(op = {f})", .{op_label}),
        }
    }
};

pub const StatementKind = union(enum) {
    label: Operand, // label
    instruction: struct {
        instruction: InstructionSet,
        operands: [2]Operand,
    },
    directive: Directive,

    const Self = @This();

    pub fn isKind(self: Self, other: Self) bool {
        return std.meta.activeTag(self) == std.meta.activeTag(other);
    }

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        switch (self) {
            .label => |op_label| try writer.print("statementkind(op = {f})", .{op_label}),
            .instruction => |instr_struct| {
                try writer.print("statementkind(instr = {s}, operands = [{f}, {f}])", .{
                    @tagName(instr_struct.instruction),
                    instr_struct.operands[0],
                    instr_struct.operands[1],
                });
            },
            .directive => |dir| try writer.print("statementkind(dir = {f})", .{dir}),
        }
    }
};

pub const Statement = struct {
    kind: StatementKind,
    line: usize,

    const Self = @This();

    pub fn init(kind: StatementKind, line: usize) Self {
        return Self{
            .kind = kind,
            .line = line,
        };
    }

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        try writer.print("statement(kind = {f}, line = {d})", .{ self.kind, self.line });
    }
};