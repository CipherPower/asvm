const std = @import("std");

const Assembler = @import("assember").Assembler;

const VirtualMachine = @import("vm").VirtualMachine;
const handleVmError = @import("vm").handleVmError;

pub fn main() !void {
    var stderr_buffer: [128]u8 = undefined;
    var stderr_writer: std.fs.File.Writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr: *std.Io.Writer = &stderr_writer.interface;

    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout: *std.Io.Writer = &stdout_writer.interface;

    var stdin_buffer: [128]u8 = undefined;
    var stdin_reader: std.fs.File.Reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin: *std.Io.Reader = &stdin_reader.interface;

    const allocator: std.mem.Allocator = std.heap.smp_allocator;

    var args: std.process.ArgIterator = std.process.argsWithAllocator(allocator) catch {
        try stderr.print("ERROR: Could not allocate memory for executable arguments.\n", .{});
        try stderr.flush();
        return;
    };
    defer args.deinit();

    _ = args.skip(); // skip executable name;

    const cmd: []const u8 = args.next() orelse {
        try printUsage(stderr);
        try stderr.flush();
        return;
    };

    if (std.mem.eql(u8, cmd, "run")) {
        const input_path: []const u8 = args.next() orelse {
            try stderr.writeAll("ERROR: Command 'run' requires an input binary file.\n");
            try printUsage(stderr);
            try stderr.flush();
            return;
        };

        var file: std.fs.File = std.fs.cwd().openFile(input_path, .{}) catch |err| {
            try stderr.print("ERROR: Failed to open file '{s}', {s}.\n", .{ input_path, @errorName(err) });
            try stderr.flush();
            return;
        };
        defer file.close();

        var file_reader: std.fs.File.Reader = file.reader(&.{});
        const bytecode: []const u8 = file_reader.interface.allocRemaining(allocator, .unlimited) catch |err| {
            try stderr.print("ERROR: Could not read from file '{s}', {s}.\n", .{ input_path, @errorName(err) });
            try stderr.flush();
            return;
        };

        var vm: VirtualMachine = VirtualMachine.init(allocator, stdout, stderr, stdin) catch {
            try stderr.writeAll("ERROR: Could not allocate enough memory for Virtual address space.\n");
            try stderr.flush();
            return;
        };
        defer vm.deinit();

        vm.loadProgram(bytecode) catch |err| {
            try handleVmError(&vm, err);
            try stderr.flush();
            return;
        };

        vm.run() catch |err| {
            try handleVmError(&vm, err);
            try stderr.flush();
            return;
        };
    } else if (std.mem.eql(u8, cmd, "assemble")) {
        const input_path: []const u8 = args.next() orelse {
            try stderr.writeAll("ERROR: Command 'assemble' requires an input assembly file.\n");
            try printUsage(stderr);
            try stderr.flush();
            return;
        };

        var output_path: []const u8 = "a.bin";

        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "-o")) {
                output_path = args.next() orelse {
                    try stderr.writeAll("ERROR: flag '-o' requires specifying an output file name.\n");
                    try stderr.flush();
                    return;
                };
            } else {
                try stderr.print("ERROR: Unknown argument: '{s}'.\n", .{arg});
            }
        }
        try stderr.flush();

        var file: std.fs.File = std.fs.cwd().openFile(input_path, .{}) catch |err| {
            try stderr.print("ERROR: Failed to open file '{s}', {s}.\n", .{ input_path, @errorName(err) });
            try stderr.flush();
            return;
        };
        defer file.close();

        var assembler: Assembler = .init(allocator, stderr);
        defer assembler.deinit();

        var file_reader: std.fs.File.Reader = file.reader(&.{});
        const source: []const u8 = file_reader.interface.allocRemaining(allocator, .unlimited) catch |err| {
            try stderr.print("ERROR: Could not read from file '{s}', {s}.\n", .{ input_path, @errorName(err) });
            try stderr.flush();
            return;
        };

        const result: ?[]const u8 = assembler.assemble(source) catch |err| {
            try stderr.print("ERROR: Could not assemble '{s}', {s}.\n", .{ input_path, @errorName(err) });
            try stderr.flush();
            return;
        };

        if (result) |bytecode| {
            var out_file: std.fs.File = std.fs.cwd().createFile(output_path, .{}) catch |err| {
                try stderr.print("ERROR: Could not create file '{s}', {s}.\n", .{ output_path, @errorName(err) });
                try stderr.flush();
                return;
            };
            defer out_file.close();

            var file_writer: std.fs.File.Writer = out_file.writer(&.{});
            file_writer.interface.writeAll(bytecode) catch |err| {
                try stderr.print("ERROR: Could not write to file '{s}', {s}.\n", .{ output_path, @errorName(err) });
                try stderr.flush();
                return;
            };
        } else {
            try stderr.writeAll("ERROR: Assembler encountered error, compilation stopped.\n");
            try stderr.flush();
            return;
        }
    } else if (std.mem.eql(u8, cmd, "help")) {
        try printHelp(stderr);
        try stderr.flush();
        return;
    } else if (std.mem.eql(u8, cmd, "instructions")) {
        try printInstructions(stdout);
        try stdout.flush();
        return;
    } else {
        try stderr.print("ERROR: Unknown command '{s}'.\n", .{cmd});
        try printUsage(stderr);
        try stderr.flush();
        return;
    }
}

fn printUsage(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\Usage: asvm <command> [args]
        \\
        \\Commands:
        \\  run <file.bin>                  Run a compiled binary file.
        \\  assemble <file.asm> [-o out]    Assemble to a binary file (default 'a.bin').
        \\  help                            Print the help message.
        \\  instructions                    Print a list of all valid instructions, and what they do.
        \\
    );
}

fn printHelp(writer: *std.Io.Writer) !void {
    try printUsage(writer);
    try writer.writeAll(
        \\
        \\ - asvm is an assembler and virtual machine implementation written in zig 0.15.2.
        \\ - It utilises a CISC architecture to allow variable length instructions, which
        \\ - are dynamically deconstructed during runtime, adding some performance overhead,
        \\ - but allows for more complex instructions whilst optimising the size of instructions used,
        \\ - which is necessary for its somewhat small sized address space.
        \\
        \\ Tip:
        \\ - The list of instructions with a brief explanation can be found by running the 'instructions' command.
        \\
    );
}

fn printInstructions(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\Instructions:
        \\ [0] = First Operand
        \\ [1] = Second Operand
        \\
        \\ - mov [register], [register | integer | address]     Copies [0] to [1].
        \\ - str [register], [address]                          Stores the value in [0] at the address [1].
        \\ - lea [register], [address]                          Stores the address of [1] in [0].
        \\ - push [register]                                    Pushes [0] to the stack, can cause overflow.
        \\ - pop [register]                                     Pops a value from the stack into [0], can cause underflow.
        \\ - jmp [address]                                      Transfers execution to [0].
        \\ - cmp [register], [register | integer]               Compares [0] and [1], sets according flags.
        \\ - jg [address]                                       Jumps to [0] if both zero and sign flags are not set.
        \\ - jl [address]                                       Jumps to [0] if the sign flag is set.
        \\ - jz [address]                                       Jumps to [0] if zero flag is set.
        \\ - jnz [address]                                      Jumps to [0] if zero flag is not set.
        \\ - add [register], [register | integer | address]     Adds [0] and [1], storing in [0].
        \\ - sub [register], [register | integer | address]     Subtracts [1] from [0], storing in [0].
        \\ - mul [register], [register | integer | address]     Multiplies [0] and [1], storing in [0].
        \\ - div [register], [register | integer | address]     Divides [1] from [0], storing in [0]. Could cause divide-by-zero error.
        \\ - inc [register]                                     Increments [0] by one, storing in [0].
        \\ - dec [register]                                     Decrements [0] by one, storing in [0].
        \\ - and [register], [register | integer | address]     Performs bitwise and between [0] and [1], storing in [0].
        \\ - not [register]                                     Performs bitwise not on [0], storing in [0].
        \\ - xor [register], [register | integer | address]     Performs bitwise xor between [0] and [1], storing in [0].
        \\ - neg [register]                                     Finds the two's complement of [0], storing in [0].
        \\ - or [register], [register | integer | address]      Performs bitwise or between [0] and [1], storing in [0].
        \\ - lsl [register], [register | integer | address]     Performs a bitshift left by [1] on [0], storing in [0].
        \\ - lsr [register], [register | integer | address]     Performs a bitshift right by [1] on [0], storing in [0].
        \\ - syscall                                            Interrups execution and transfers execution to a syscall handler.
        \\ - ret                                                Pops an address off the stack, and transfers execution to it.
        \\ - call [address]                                     Pushes IP onto the stack, and transfers execution to the procedure at [0].
        \\
    );
}
