const std = @import("std");

pub const VirtualError = error{
    MemoryOutOfBounds,
    InvalidOpcode,
    InvalidAddressingMode,
    InvalidRegister,
    DivideByZero,
    StackOverflow,
    UnknownSyscall,
    StackUndeflow,
};
