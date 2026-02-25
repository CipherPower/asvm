const std = @import("std");
const errors = @import("error.zig");
const vm = @import("vm.zig");

const VirtualError = errors.VirtualError;
const VirtualMachine = vm.VirtualMachine;

pub const SYSCALL_COUNT: comptime_int = 1;
pub const SyscallHandler = *const fn (self: *VirtualMachine) VirtualError!void;

pub const syscall_table: [SYSCALL_COUNT]SyscallHandler = build_table: {
    var table: [SYSCALL_COUNT]SyscallHandler = undefined;

    table[0] = &sys_write;

    break :build_table table;
};

fn sys_write(self: *VirtualMachine) VirtualError!void {
    const fd: u8 = vm.truncateDword(u8, self.registers[1]);
    const value: i32 = self.registers[2];
    const fmt_options: u8 = vm.truncateDword(u8, self.registers[3]);

    const writer: *std.Io.Writer = switch (fd) {
        0 => self.stdout,
        1 => self.stderr,

        else => return error.InvalidSyscallArguments,
    };

    switch (fmt_options) {
        0 => {
            var ptr: u16 = vm.truncateDword(u16, value);
            while (ptr < self.memory.len) : (ptr +%= 1) {
                const char: u8 = vm.truncateDword(u8, self.memory[ptr]);
                if (char == 0) break;
                writer.writeByte(char) catch return error.WriteError;
            }
            writer.flush() catch return error.WriteError;
        },

        1 => {
            writer.print("{d}", .{value}) catch return error.WriteError;
            writer.flush() catch return error.WriteError;
        },

        2 => {
            writer.writeByte('\n') catch return error.WriteError;
            writer.flush() catch return error.WriteError;
        },

        else => return error.InvalidSyscallArguments,
    }
}
