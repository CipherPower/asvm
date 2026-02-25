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

        var vm: VirtualMachine = VirtualMachine.init(allocator, stdout, stderr) catch {
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
        \\
    );
}
