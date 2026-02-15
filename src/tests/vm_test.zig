const std = @import("std");
const instruction_set = @import("instruction");
const testing = std.testing;

const assert = testing.expect;
const assertEqual = testing.expectEqualDeep;

const VirtualMachine = @import("vm").VirtualMachine;

const InstructionSet = instruction_set.InstructionSet;
const InstructionHeader = instruction_set.InstructionHeader;
const AddressingMode = instruction_set.AddressingMode;

fn printPass(test_name: []const u8) void {
    std.debug.print("test: \"{s}\" passed!\n", .{test_name});
}

fn instr(in: InstructionSet, mode: AddressingMode) u8 {
    return InstructionHeader.init(in, mode).value;
}

fn label(addr: u16) [@sizeOf(u16)]u8 {
    return std.mem.toBytes(addr);
}

fn int(val: i32) [@sizeOf(i32)]u8 {
    return std.mem.toBytes(val);
}

test "empty vm" {
    const program: []const u8 = &.{};

    var vm: VirtualMachine = try .init(testing.allocator);
    defer vm.deinit();

    try vm.loadProgram(program);

    printPass("empty vm");
}

test "running mov immediate and add register" {
    var program: std.ArrayList(u8) = .empty;
    defer program.deinit(testing.allocator);
    try program.appendSlice(testing.allocator, &label(2));
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 0);
    try program.appendSlice(testing.allocator, &int(10));
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 1);
    try program.appendSlice(testing.allocator, &int(20));
    try program.append(testing.allocator, instr(.add, .register));
    try program.append(testing.allocator, 0);
    try program.append(testing.allocator, 1);
    try program.append(testing.allocator, instr(.hlt, .immediate));

    var vm: VirtualMachine = try .init(testing.allocator);
    defer vm.deinit();

    try vm.loadProgram(program.items);
    try vm.run();

    try assert(vm.registers[0] == 30);

    printPass("running mov immediate and add register");
}

test "math operations (sub, mul, div)" {
    var program: std.ArrayList(u8) = .empty;
    defer program.deinit(testing.allocator);
    try program.appendSlice(testing.allocator, &label(2));
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 0);
    try program.appendSlice(testing.allocator, &int(50));
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 1);
    try program.appendSlice(testing.allocator, &int(10));
    try program.append(testing.allocator, instr(.sub, .register));
    try program.append(testing.allocator, 0);
    try program.append(testing.allocator, 1);
    try program.append(testing.allocator, instr(.mul, .register));
    try program.append(testing.allocator, 0);
    try program.append(testing.allocator, 1);
    try program.append(testing.allocator, instr(.div, .register));
    try program.append(testing.allocator, 0);
    try program.append(testing.allocator, 1);
    try program.append(testing.allocator, instr(.hlt, .immediate));

    var vm: VirtualMachine = try .init(testing.allocator);
    defer vm.deinit();

    try vm.loadProgram(program.items);
    try vm.run();

    try assert(vm.registers[0] == 40);
    try assert(vm.registers[1] == 10);

    printPass("math operations (sub, mul, div)");
}

test "bitwise logic and left shift" {
    var program: std.ArrayList(u8) = .empty;
    defer program.deinit(testing.allocator);
    try program.appendSlice(testing.allocator, &label(2));
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 0);
    try program.appendSlice(testing.allocator, &int(10));
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 1);
    try program.appendSlice(testing.allocator, &int(12));
    try program.append(testing.allocator, instr(.land, .register));
    try program.append(testing.allocator, 0);
    try program.append(testing.allocator, 1);
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 2);
    try program.appendSlice(testing.allocator, &int(2));
    try program.append(testing.allocator, instr(.lsl, .register));
    try program.append(testing.allocator, 0);
    try program.append(testing.allocator, 2);
    try program.append(testing.allocator, instr(.hlt, .immediate));

    var vm: VirtualMachine = try .init(testing.allocator);
    defer vm.deinit();

    try vm.loadProgram(program.items);
    try vm.run();

    try assert(vm.registers[0] == 32);

    printPass("bitwise logic and left shift");
}

test "stack push and pop (downward growth verification)" {
    var program: std.ArrayList(u8) = .empty;
    defer program.deinit(testing.allocator);
    try program.appendSlice(testing.allocator, &label(2));
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 0);
    try program.appendSlice(testing.allocator, &int(84));
    try program.append(testing.allocator, instr(.push, .register));
    try program.append(testing.allocator, 0);
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 0);
    try program.appendSlice(testing.allocator, &int(0));
    try program.append(testing.allocator, instr(.pop, .register));
    try program.append(testing.allocator, 1);
    try program.append(testing.allocator, instr(.hlt, .immediate));

    var vm: VirtualMachine = try .init(testing.allocator);
    defer vm.deinit();

    try vm.loadProgram(program.items);
    try vm.run();

    try assert(vm.registers[1] == 84);
    try assert(vm.sp == 0);

    printPass("stack push and pop (downward growth verification)");
}

test "control flow (call, ret, cmp, jeq)" {
    var program: std.ArrayList(u8) = .empty;
    defer program.deinit(testing.allocator);
    try program.appendSlice(testing.allocator, &label(2));
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 0);
    try program.appendSlice(testing.allocator, &int(5));
    try program.append(testing.allocator, instr(.call, .memory));
    try program.appendSlice(testing.allocator, &label(12));
    try program.append(testing.allocator, instr(.hlt, .immediate));
    try program.append(testing.allocator, instr(.cmp, .immediate));
    try program.append(testing.allocator, 0);
    try program.appendSlice(testing.allocator, &int(5));
    try program.append(testing.allocator, instr(.jz, .memory));
    try program.appendSlice(testing.allocator, &label(28));
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 1);
    try program.appendSlice(testing.allocator, &int(99));
    try program.append(testing.allocator, instr(.ret, .immediate)); // Mode ignored
    try program.append(testing.allocator, instr(.mov, .immediate));
    try program.append(testing.allocator, 1);
    try program.appendSlice(testing.allocator, &int(42));
    try program.append(testing.allocator, instr(.ret, .immediate));

    var vm: VirtualMachine = try .init(testing.allocator);
    defer vm.deinit();

    try vm.loadProgram(program.items);
    try vm.run();

    try assert(vm.registers[1] == 42);

    try assert(vm.sp == 0);

    printPass("control flow (call, ret, cmp, jeq)");
}
