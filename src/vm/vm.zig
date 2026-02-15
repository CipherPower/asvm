const std = @import("std");
const errors = @import("error.zig");
const instruction_set = @import("instruction");

const VirtualError = errors.VirtualError;

const InstructionSet = instruction_set.InstructionSet;
const AddressingMode = instruction_set.AddressingMode;

pub const MEMORY_SIZE: comptime_int = 65536;
pub const MAX_REGISTERS: comptime_int = 16;

fn deconstructHeader(byte: u8) VirtualError!struct { InstructionSet, AddressingMode } {
    const instruction: u8 = byte >> 2;
    const mode: u8 = byte & 0b0000_0011;

    const opcode: InstructionSet = std.meta.intToEnum(InstructionSet, instruction) catch return error.InvalidOpcode;
    const addressing_mode: AddressingMode = std.meta.intToEnum(AddressingMode, mode) catch return error.InvalidAddressingMode;

    return .{ opcode, addressing_mode };
}

fn checkRegister(register: u8) VirtualError!void {
    if (register >= MAX_REGISTERS) return error.InvalidRegister;
}

fn truncateDword(comptime T: type, dword: i32) T {
    return @truncate(@as(u32, @bitCast(dword)));
}

pub fn handleVmError(vm: *const VirtualMachine, err: VirtualError, writer: *std.Io.Writer) !void {
    const error_message: []const u8 = switch (err) {
        error.DivideByZero => "Attempted to divide by zero",
        error.InvalidAddressingMode => "Invalid addressing mode for instruction",
        error.InvalidOpcode => "Unknown instruction",
        error.InvalidRegister => "Invalid register (0 -> 15)",
        error.MemoryOutOfBounds => "Segmentation fault",
        error.StackOverflow => "Stack overflow",
        error.StackUndeflow => "Stack underflow",
    };

    try writer.print("0x{x}: {s}.\n", .{ vm.pc, error_message });
}

pub const VirtualMachine = struct {
    memory: []u8,
    registers: [MAX_REGISTERS]i32,
    pc: u16,
    sp: u16,
    flags: u8,
    running: bool,
    allocator: std.mem.Allocator,

    const Self = @This();

    const InstructionHandler: type = *const fn (self: *Self, mode: AddressingMode) VirtualError!void;
    const InstructionCount: usize = @typeInfo(InstructionSet).@"enum".fields.len;

    // FLAG MASKS:
    const FLAG_Z: u8 = 1 << 0;
    const FLAG_S: u8 = 1 << 1;

    const dispatch_table: [InstructionCount]InstructionHandler = build_table: {
        var table: [InstructionCount]InstructionHandler = undefined;

        table[@intFromEnum(InstructionSet.mov)] = &handleMov;
        table[@intFromEnum(InstructionSet.push)] = &handlePush;
        table[@intFromEnum(InstructionSet.pop)] = &handlePop;
        table[@intFromEnum(InstructionSet.jmp)] = &handleJmp;
        table[@intFromEnum(InstructionSet.cmp)] = &handleCmp;
        table[@intFromEnum(InstructionSet.jg)] = &handleJg;
        table[@intFromEnum(InstructionSet.jl)] = &handleJl;
        table[@intFromEnum(InstructionSet.jz)] = &handleJz;
        table[@intFromEnum(InstructionSet.add)] = &handleAdd;
        table[@intFromEnum(InstructionSet.sub)] = &handleSub;
        table[@intFromEnum(InstructionSet.mul)] = &handleMul;
        table[@intFromEnum(InstructionSet.div)] = &handleDiv;
        table[@intFromEnum(InstructionSet.land)] = &handleAnd;
        table[@intFromEnum(InstructionSet.not)] = &handleNot;
        table[@intFromEnum(InstructionSet.xor)] = &handleXor;
        table[@intFromEnum(InstructionSet.neg)] = &handleNeg;
        table[@intFromEnum(InstructionSet.lor)] = &handleOr;
        table[@intFromEnum(InstructionSet.syscall)] = &handleSyscall;
        table[@intFromEnum(InstructionSet.ret)] = &handleRet;
        table[@intFromEnum(InstructionSet.call)] = &handleCall;
        table[@intFromEnum(InstructionSet.inc)] = &handleInc;
        table[@intFromEnum(InstructionSet.dec)] = &handleDec;
        table[@intFromEnum(InstructionSet.lsl)] = &handleLsl;
        table[@intFromEnum(InstructionSet.lsr)] = &handleLsr;
        table[@intFromEnum(InstructionSet.str)] = &handleStr;
        table[@intFromEnum(InstructionSet.jnz)] = &handleJnz;
        table[@intFromEnum(InstructionSet.hlt)] = &handleHlt;

        break :build_table table;
    };

    pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!Self {
        const mem: []u8 = try allocator.alloc(u8, MEMORY_SIZE);
        @memset(mem, 0);

        return .{
            .memory = mem,
            .registers = [_]i32{0} ** 16,
            .pc = 0,
            .sp = 0,
            .flags = 0,
            .running = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.memory);
    }

    pub fn loadProgram(self: *Self, bytecode: []const u8) VirtualError!void {
        if (bytecode.len > self.memory.len) return error.MemoryOutOfBounds;

        @memcpy(self.memory[0..bytecode.len], bytecode);

        self.pc = std.mem.readInt(u16, self.memory[0..2], .little);
    }

    pub fn run(self: *Self) VirtualError!void {
        self.running = true;

        while (self.running) {
            try self.step();
        }
    }

    // ========================================================================================
    //                                  FDE OPERATIONS
    // ========================================================================================

    fn step(self: *Self) VirtualError!void {
        const instruction_header: u8 = try self.fetchByte();

        const opcode, const mode = try deconstructHeader(instruction_header);

        try self.execute(opcode, mode);
    }

    fn execute(self: *Self, opcode: InstructionSet, mode: AddressingMode) VirtualError!void {
        const opcode_idx: usize = @intFromEnum(opcode);
        const handler: InstructionHandler = dispatch_table[opcode_idx];

        try handler(self, mode);
    }

    // ========================================================================================
    //                                  FETCH OPERATIONS
    // ========================================================================================

    fn fetchByte(self: *Self) VirtualError!u8 {
        if (self.pc >= self.memory.len) return error.MemoryOutOfBounds;
        const value: u8 = self.memory[self.pc];
        self.pc +%= 1;
        return value;
    }

    fn fetchWord(self: *Self) VirtualError!u16 {
        if (self.pc >= self.memory.len - 1) return error.MemoryOutOfBounds;
        const value: u16 = std.mem.readInt(u16, self.memory[self.pc..][0..2], .little);
        self.pc +%= 2;
        return value;
    }

    fn fetchDword(self: *Self) VirtualError!i32 {
        if (self.pc >= self.memory.len - 3) return error.MemoryOutOfBounds;
        const value: i32 = std.mem.readInt(i32, self.memory[self.pc..][0..4], .little);
        self.pc +%= 4;
        return value;
    }

    fn fetchSrcValue(self: *Self, mode: AddressingMode) VirtualError!i32 {
        switch (mode) {
            .immediate => return try self.fetchDword(),

            .register => {
                const src_reg: u8 = try self.fetchByte();
                try checkRegister(src_reg);
                return self.registers[src_reg];
            },

            .memory => {
                const address: u16 = try self.fetchWord();
                return try self.readDword(address);
            },

            else => return error.InvalidAddressingMode,
        }
    }

    // ========================================================================================
    //                                  MEMORY OPERATIONS
    // ========================================================================================

    fn readDword(self: *Self, address: u16) VirtualError!i32 {
        if (address >= self.memory.len - 3) return error.MemoryOutOfBounds;
        return std.mem.readInt(i32, self.memory[address..][0..4], .little);
    }

    // ========================================================================================
    //                                  STACK OPERATIONS
    // ========================================================================================

    fn stackPushDword(self: *Self, value: i32) VirtualError!void {
        self.sp -%= 4;
        std.mem.writeInt(i32, self.memory[self.sp..][0..4], value, .little);
    }

    fn stackPopDword(self: *Self) VirtualError!i32 {
        const value: i32 = std.mem.readInt(i32, self.memory[self.sp..][0..4], .little);
        self.sp +%= 4;
        return value;
    }

    // ========================================================================================
    //                                  HANDLERS
    // ========================================================================================

    fn handleMov(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        self.registers[dest_register] = try self.fetchSrcValue(mode);
    }

    fn handleStr(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .memory) return error.InvalidAddressingMode;
        const src_register: u8 = try self.fetchByte();
        try checkRegister(src_register);
        const target_address: u16 = try self.fetchWord();
        if (target_address >= self.memory.len - 3) return error.MemoryOutOfBounds;

        std.mem.writeInt(i32, self.memory[target_address..][0..4], self.registers[src_register], .little);
    }

    fn handlePush(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .register) return error.InvalidAddressingMode;

        const register: u8 = try self.fetchByte();
        try checkRegister(register);

        try self.stackPushDword(self.registers[register]);
    }

    fn handlePop(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .register) return error.InvalidAddressingMode;

        const register: u8 = try self.fetchByte();
        try checkRegister(register);

        self.registers[register] = try self.stackPopDword();
    }

    fn handleJmp(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .memory) return error.InvalidAddressingMode;

        const target_address: u16 = try self.fetchWord();
        if (target_address >= self.memory.len) return error.MemoryOutOfBounds;

        self.pc = target_address;
    }

    fn handleAdd(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        self.registers[dest_register] +%= try self.fetchSrcValue(mode);
    }

    fn handleSub(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        self.registers[dest_register] -%= try self.fetchSrcValue(mode);
    }

    fn handleMul(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        self.registers[dest_register] *%= try self.fetchSrcValue(mode);
    }

    fn handleDiv(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        const value: i32 = try self.fetchSrcValue(mode);
        if (value == 0) return error.DivideByZero;

        self.registers[dest_register] = @divExact(self.registers[dest_register], value);
    }

    fn handleInc(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .register) return error.InvalidAddressingMode;

        const register: u8 = try self.fetchByte();
        try checkRegister(register);

        self.registers[register] +%= 1;
    }

    fn handleDec(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .register) return error.InvalidAddressingMode;

        const register: u8 = try self.fetchByte();
        try checkRegister(register);

        self.registers[register] -%= 1;
    }

    fn handleNeg(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .register) return error.InvalidAddressingMode;

        const register: u8 = try self.fetchByte();
        try checkRegister(register);

        self.registers[register] = -self.registers[register];
    }

    fn handleAnd(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        self.registers[dest_register] &= try self.fetchSrcValue(mode);
    }

    fn handleOr(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        self.registers[dest_register] |= try self.fetchSrcValue(mode);
    }

    fn handleXor(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        self.registers[dest_register] ^= try self.fetchSrcValue(mode);
    }

    fn handleNot(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .register) return error.InvalidAddressingMode;

        const register: u8 = try self.fetchByte();
        try checkRegister(register);

        self.registers[register] = ~self.registers[register];
    }

    fn handleLsl(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        const shift_amount: i32 = try self.fetchSrcValue(mode);
        self.registers[dest_register] <<= truncateDword(u5, shift_amount);
    }

    fn handleLsr(self: *Self, mode: AddressingMode) VirtualError!void {
        const dest_register: u8 = try self.fetchByte();
        try checkRegister(dest_register);

        const shift_amount: i32 = try self.fetchSrcValue(mode);
        self.registers[dest_register] >>= truncateDword(u5, shift_amount);
    }

    fn handleCmp(self: *Self, mode: AddressingMode) VirtualError!void {
        const register: u8 = try self.fetchByte();
        try checkRegister(register);

        const value: i32 = try self.fetchSrcValue(mode);
        const result: i32 = self.registers[register] -% value;

        self.flags = 0;
        if (result == 0) self.flags |= FLAG_Z;
        if (result < 0) self.flags |= FLAG_S;
    }

    fn handleJz(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .memory) return error.InvalidAddressingMode;
        const target_address: u16 = try self.fetchWord();
        if ((self.flags & FLAG_Z) != 0) self.pc = target_address;
    }

    fn handleJnz(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .memory) return error.InvalidAddressingMode;
        const target_address: u16 = try self.fetchWord();
        if ((self.flags & FLAG_Z) == 0) self.pc = target_address;
    }

    fn handleJg(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .memory) return error.InvalidAddressingMode;
        const target_address: u16 = try self.fetchWord();

        const is_zero: bool = (self.flags & FLAG_Z) != 0;
        const is_signed: bool = (self.flags & FLAG_S) != 0;

        if (!is_zero and !is_signed) self.pc = target_address;
    }

    fn handleJl(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .memory) return error.InvalidAddressingMode;
        const target_address: u16 = try self.fetchWord();
        if ((self.flags & FLAG_S) != 0) self.pc = target_address;
    }

    fn handleCall(self: *Self, mode: AddressingMode) VirtualError!void {
        if (mode != .memory) return error.InvalidAddressingMode;
        const target_address: u16 = try self.fetchWord();
        try self.stackPushDword(@intCast(self.pc));
        self.pc = target_address;
    }

    fn handleRet(self: *Self, mode: AddressingMode) VirtualError!void {
        _ = mode;
        const return_address: i32 = try self.stackPopDword();
        self.pc = truncateDword(u16, return_address);
    }

    fn handleSyscall(self: *Self, mode: AddressingMode) VirtualError!void {
        _ = mode;
        std.debug.print("SYSCALL [r0: {d}]\n", .{self.registers[0]});
    }

    fn handleHlt(self: *Self, mode: AddressingMode) VirtualError!void {
        _ = mode;
        self.running = false;
    }
};
