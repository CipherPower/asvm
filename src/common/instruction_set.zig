const std = @import("std");

const StaticMap = @import("util").StaticMap;

/// Wrapper function for converting a byte slice to an instruction set,
/// returning null if the byte slice was invalid.
pub fn resolveInstruction(str: []const u8) ?InstructionSet {
    return InstructionSet.table.get(str);
}

/// Enum containing all possible instructions.
pub const InstructionSet = enum(u8) {
    mov,
    push,
    pop,
    jmp,
    cmp,
    jg,
    jl,
    jz,
    add,
    sub,
    mul,
    div,
    land, // logical and
    not,
    xor,
    neg,
    lor, // logical or
    syscall,
    ret,
    call,
    inc,
    dec,
    lsl,
    lsr,
    str,
    jnz,
    hlt,
    lea,

    const Self = @This();

    const table: StaticMap(Self) = .initComptime(.{
        .{ "mov", Self.mov },
        .{ "push", Self.push },
        .{ "pop", Self.pop },
        .{ "jmp", Self.jmp },
        .{ "cmp", Self.cmp },
        .{ "jg", Self.jg },
        .{ "jl", Self.jl },
        .{ "jz", Self.jz },
        .{ "add", Self.add },
        .{ "sub", Self.sub },
        .{ "mul", Self.mul },
        .{ "div", Self.div },
        .{ "and", Self.land },
        .{ "not", Self.not },
        .{ "xor", Self.xor },
        .{ "neg", Self.neg },
        .{ "or", Self.lor },
        .{ "syscall", Self.syscall },
        .{ "ret", Self.ret },
        .{ "call", Self.call },
        .{ "inc", Self.inc },
        .{ "dec", Self.dec },
        .{ "lsl", Self.lsl },
        .{ "lsr", Self.lsr },
        .{ "str", Self.str },
        .{ "jnz", Self.jnz },
        .{ "hlt", Self.hlt },
        .{ "lea", Self.lea },
    });

    pub fn toByte(self: Self) u8 {
        return @intFromEnum(self) << 2;
    }
};

/// An enum that represents the different addressing modes an instruction could take.
pub const AddressingMode = enum(u8) {
    immediate,
    memory,
    register,
    indirect,

    const Self = @This();

    pub fn toByte(self: Self) u8 {
        return @intFromEnum(self);
    }
};

/// Wrapper that facilitates conversion from an InstructionSet + AddressingMode
/// into a byte.
pub const InstructionHeader = struct {
    value: u8,

    const Self = @This();

    pub fn init(instr: InstructionSet, mode: AddressingMode) Self {
        return Self{ .value = instr.toByte() | mode.toByte() };
    }
};
