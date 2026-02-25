const std = @import("std");

const VirtualMachine = @import("vm.zig").VirtualMachine;

pub const VirtualError = error{
    MemoryOutOfBounds,
    InvalidOpcode,
    InvalidAddressingMode,
    InvalidRegister,
    DivideByZero,
    StackOverflow,
    UnknownSyscall,
    StackUndeflow,
    InvalidSyscallArguments,
    WriteError,
};

pub fn handleVmError(vm: *const VirtualMachine, err: VirtualError) !void {
    const error_message: []const u8 = switch (err) {
        error.DivideByZero => "Attempted to divide by zero",
        error.InvalidAddressingMode => "Invalid addressing mode for instruction",
        error.InvalidOpcode => "Unknown instruction",
        error.InvalidRegister => "Invalid register (0 -> 15)",
        error.MemoryOutOfBounds => "Segmentation fault",
        error.StackOverflow => "Stack overflow",
        error.UnknownSyscall => "Unrecognised syscall id",
        error.StackUndeflow => "Stack underflow",
        error.InvalidSyscallArguments => "Invalid syscall arguments",
        error.WriteError => "Write error",
    };

    try vm.stderr.print("0x{x}: {s}.\n", .{ vm.pc, error_message });
}
