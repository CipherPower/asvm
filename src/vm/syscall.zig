const std = @import("std");
const errors = @import("error.zig");
const vm = @import("vm.zig");

const VirtualError = errors.VirtualError;
const VirtualMachine = vm.VirtualMachine;

pub const SYSCALL_COUNT: comptime_int = 2;
pub const SyscallHandler = *const fn (self: *VirtualMachine) VirtualError!void;

/// A dispatch table that allows deciding the function to be called at run time.
pub const syscall_table: [SYSCALL_COUNT]SyscallHandler = build_table: {
    var table: [SYSCALL_COUNT]SyscallHandler = undefined;

    table[0] = &sys_write;
    table[1] = &sys_read;

    break :build_table table;
};

/// A utility function for writing a string to an address.
fn write_string(self: *VirtualMachine, addr: u16, string: []const u8) VirtualError!void {
    if (string.len == 0) return error.InvalidSyscallArguments;
    if (addr >= self.memory.len or addr + string.len >= self.memory.len) return error.MemoryOutOfBounds;

    @memcpy(self.memory[addr .. addr + string.len], string[0..]);
    self.memory[addr + string.len] = 0;
}

/// Syscall that facilitates writing from the virtual machine to an operating system file.
/// I.e Stdout or Stderr.
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

/// Syscall that facilitates reading from an operating system file, to an address in
/// the virtual machine.
fn sys_read(self: *VirtualMachine) VirtualError!void {
    const dest: u16 = vm.truncateDword(u16, self.registers[1]);
    const size: u32 = @bitCast(self.registers[2]);
    const read_options: i32 = self.registers[3];

    switch (read_options) {
        0 => {
            // read SIZE bytes
            const bytes: []const u8 = self.stdin.take(@intCast(size)) catch return error.ReadError;
            try write_string(self, dest, bytes);
        },

        1 => {
            // read line
            var line: []u8 = self.stdin.takeDelimiterExclusive('\n') catch return error.ReadError;

            if (line.len > 0 and line[line.len - 1] == '\r') {
                line = line[0 .. line.len - 1];
            }

            try write_string(self, dest, line);
        },

        else => return error.InvalidSyscallArguments,
    }
}
