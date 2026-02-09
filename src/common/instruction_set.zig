const std = @import("std");

pub const InstructionSet = enum(u8) {
    mov,
    push,
    pop,
    jmp,
    cmp,
    jg,
    jl,
    jeq,
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
    jneq,

    const Self = @This();

    pub fn toByte(self: Self) u8 {
        return @intFromEnum(self) << 2;
    } 
};

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

const InstructionHeader = struct {
    value: u8,

    const Self = @This();

    pub fn init(instr: InstructionSet, mode: AddressingMode) Self {
        return Self{ .value = instr.toByte() | mode.toByte() };
    }
};