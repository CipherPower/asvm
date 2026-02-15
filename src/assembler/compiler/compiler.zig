const std = @import("std");
const errors = @import("error.zig");
const statement = @import("statement");
const instruction_set = @import("instruction");

const InstructionSet = instruction_set.InstructionSet;
const AddressingMode = instruction_set.AddressingMode;
const InstructionHeader = instruction_set.InstructionHeader;

const CompilerError = errors.CompilerError;
pub const CompilerErrorKind = errors.CompilerErrorKind;

const Statement = statement.Statement;
const StatementKind = statement.StatementKind;
const Operand = statement.Operand;
const Directive = statement.Directive;
const DirectiveTag = statement.DirectiveTag;

fn resolveAddressingMode(operands: [2]Operand) CompilerErrorKind!AddressingMode {
    return switch (operands[0]) {
        .register => switch (operands[1]) {
            .register => .register,
            .integer => .immediate,
            .label => .memory,
            .none => .register,
        },

        .label => switch (operands[1]) {
            .none => .memory,
            else => error.InvalidOperand,
        },

        .none => .register,

        else => error.InvalidOperand,
    };
}

fn calculateInstructionSize(operands: [2]Operand) u16 {
    var size: u16 = 1; // 1 byte for instruction header

    for (operands) |op| {
        switch (op) {
            .register => size += @sizeOf(u8),
            .integer => size += @sizeOf(i32),
            .label => size += @sizeOf(u16),
            .none => {},
        }
    }

    return size;
}

const Segment = enum {
    none,
    data,
    text,
};

pub const Compiler = struct {
    output: std.ArrayList(u8),
    symbol_table: std.StringHashMap(u16),
    errors: std.ArrayList(CompilerError),
    entry_point_label: ?[]const u8,
    entry_point_address: ?u16,
    current_segment: Segment,
    seen_text: bool,
    seen_data: bool,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .output = .empty,
            .symbol_table = .init(allocator),
            .errors = .empty,
            .entry_point_label = null,
            .entry_point_address = null,
            .current_segment = .none,
            .seen_text = false,
            .seen_data = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit(self.allocator);
        self.errors.deinit(self.allocator);
        self.symbol_table.deinit();
    }

    pub fn hasErrors(self: *const Self) bool {
        return self.errors.items.len > 0;
    }

    pub fn compile(self: *Self, statements: []const Statement) error{OutOfMemory}!void {
        self.clear();

        try self.passOne(statements);

        if (self.hasErrors()) return;

        try self.passTwo(statements);
    }

    fn passOne(self: *Self, statements: []const Statement) error{OutOfMemory}!void {
        var current_offset: u16 = 2;

        for (statements) |stmt| {
            switch (stmt.kind) {
                .label => |label_name| {
                    if (self.symbol_table.contains(label_name)) {
                        try self.addError(error.RedefinedLabel, label_name, stmt.line);
                    } else {
                        try self.symbol_table.put(label_name, current_offset);
                    }
                },

                .instruction => |instr| {
                    if (self.current_segment != .text) {
                        try self.addError(error.InstructionOutsideTextSegment, @tagName(instr.instruction), stmt.line);
                    }

                    if (resolveAddressingMode(instr.operands)) |_| {
                        current_offset += calculateInstructionSize(instr.operands);
                    } else |err| {
                        try self.addError(err, @tagName(instr.instruction), stmt.line);
                    }
                },

                .directive => |dir| {
                    switch (dir) {
                        .entry => |label_name| {
                            if (self.entry_point_label != null) {
                                try self.addError(error.DuplicateEntryDirective, label_name, stmt.line);
                            } else {
                                self.entry_point_label = label_name;
                            }
                        },

                        .string => |str| {
                            if (self.current_segment != .data) {
                                try self.addError(error.DirectiveOutsideDataSegment, ".string", stmt.line);
                            } else {
                                current_offset += @as(u16, @truncate(str.len)) + 1; // for null term
                            }
                        },

                        .segment => |segment| {
                            if (std.mem.eql(u8, segment, "data")) {
                                if (self.seen_data) {
                                    try self.addError(error.DuplicateSegment, ".data", stmt.line);
                                } else {
                                    self.seen_data = true;
                                    self.current_segment = .data;
                                }
                            } else if (std.mem.eql(u8, segment, "text")) {
                                if (self.seen_text) {
                                    try self.addError(error.DuplicateSegment, ".text", stmt.line);
                                } else {
                                    self.seen_text = true;
                                    self.current_segment = .text;
                                }
                            } else {
                                try self.addError(error.InvalidSegment, segment, stmt.line);
                            }
                        },
                    }
                },
            }
        }

        if (!self.seen_text) {
            try self.addError(error.MissingTextSegment, ".text", 1);
        }

        if (self.entry_point_label == null) {
            try self.addError(error.MissingEntryDirective, ".entry", 1);
        }
    }

    fn passTwo(self: *Self, statements: []const Statement) error{OutOfMemory}!void {
        try self.emitBytes(&[_]u8{ 0, 0 });

        if (self.entry_point_label) |label| {
            if (self.symbol_table.get(label)) |offset| {
                self.entry_point_address = offset;
            } else {
                try self.addError(error.UndefinedLabel, label, 1);
                return;
            }
        }

        for (statements) |stmt| {
            switch (stmt.kind) {
                .instruction => try self.emitInstruction(stmt),

                .directive => |dir| {
                    switch (dir) {
                        .string => |str| {
                            try self.emitBytes(str);
                            try self.emitByte(0); // null terminator
                        },

                        else => {},
                    }
                },

                else => {},
            }
        }

        if (self.hasErrors()) return;

        if (self.entry_point_address) |offset| {
            const bytes: [@sizeOf(u16)]u8 = std.mem.toBytes(offset);
            @memcpy(self.output.items[0..2], bytes[0..2]);
        }
    }

    fn emitInstruction(self: *Self, stmt: Statement) error{OutOfMemory}!void {
        const instr = stmt.kind.instruction;
        const mode: AddressingMode = resolveAddressingMode(instr.operands) catch |err| {
            try self.addError(err, @tagName(instr.instruction), stmt.line);
            return;
        };

        const instr_header: InstructionHeader = .init(instr.instruction, mode);
        try self.emitByte(instr_header.value);

        for (instr.operands) |op| {
            switch (op) {
                .register => |reg_value| try self.emitByte(reg_value),

                .integer => |int_value| {
                    const bytes: [@sizeOf(i32)]u8 = std.mem.toBytes(int_value);
                    try self.emitBytes(&bytes);
                },

                .label => |label_name| {
                    if (self.symbol_table.get(label_name)) |offset| {
                        const bytes: [@sizeOf(u16)]u8 = std.mem.toBytes(offset);
                        try self.emitBytes(&bytes);
                    } else {
                        try self.addError(error.UndefinedLabel, label_name, stmt.line);
                        return;
                    }
                },

                .none => {},
            }
        }
    }

    pub fn handleErrors(self: *const Self, writer: *std.Io.Writer) !void {
        for (self.errors.items) |err| {
            try writer.print("{f}\n", .{err});
        }

        try writer.flush();
    }

    fn addError(self: *Self, kind: CompilerErrorKind, literal: []const u8, line: usize) error{OutOfMemory}!void {
        const err: CompilerError = .init(kind, literal, line);
        try self.errors.append(self.allocator, err);
    }

    fn emitByte(self: *Self, byte: u8) error{OutOfMemory}!void {
        try self.output.append(self.allocator, byte);
    }

    fn emitBytes(self: *Self, bytes: []const u8) error{OutOfMemory}!void {
        try self.output.appendSlice(self.allocator, bytes);
    }

    fn clear(self: *Self) void {
        self.output.clearRetainingCapacity();
        self.errors.clearRetainingCapacity();
        self.symbol_table.clearRetainingCapacity();
        self.entry_point_label = null;
        self.entry_point_address = null;
        self.current_segment = .none;
        self.seen_text = false;
        self.seen_data = false;
    }
};
