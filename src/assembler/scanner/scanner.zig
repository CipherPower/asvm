const std = @import("std");
const errors = @import("error.zig");
const token = @import("token");

const ScannerErrorKind = errors.ScannerErrorKind;
const ScannerError = errors.ScannerError;

const Token = token.Token;
const TokenKind = token.TokenKind;

const VM_MAX_REGISTERS: comptime_int = @import("vm").MAX_REGISTERS;

fn isAlphanumeric(char: u8) bool {
    return std.ascii.isAlphanumeric(char) or char == '_';
}

fn isOctal(char: u8) bool {
    return char >= '0' and char <= '7';
}

fn isBinary(char: u8) bool {
    return char == '0' or char == '1';
}

pub const Scanner = struct {
    input: []const u8,
    start: usize,
    current: usize,
    line: usize,
    tokens: std.ArrayList(Token),
    errors: std.ArrayList(ScannerError),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .input = undefined,
            .start = 0,
            .current = 0,
            .line = 1,
            .tokens = .empty,
            .errors = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit(self.allocator);
        self.errors.deinit(self.allocator);
    }

    pub fn scan(self: *Self, input: []const u8) error{OutOfMemory}!void {
        self.clear();
        self.input = input;

        while (!self.isAtEnd()) {
            self.start = self.current;

            self.scanToken() catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => self.sync(),
            };
        }

        self.addToken(.eof) catch {
            return error.OutOfMemory;
        };
    }

    fn scanToken(self: *Self) ScannerErrorKind!void {
        const char: u8 = self.next();

        switch (char) {
            '(' => try self.addToken(.left_paren),
            ')' => try self.addToken(.right_paren),
            '[' => try self.addToken(.left_bracket),
            ']' => try self.addToken(.right_bracket),
            ',' => try self.addToken(.comma),
            '.' => try self.addToken(.dot),
            '-' => try self.addToken(.minus),
            '+' => try self.addToken(.plus),
            ':' => try self.addToken(.colon),
            '#' => try self.addToken(.hashtag),

            ' ', '\r', '\t' => {},
            '\n' => self.line += 1,

            ';' => self.skipComment(),

            '"' => try self.string(),

            'a'...'z', 'A'...'Z', '_' => {
                if (char == 'r' and std.ascii.isDigit(self.peek())) {
                    try self.register();
                } else {
                    try self.identifier();
                }
            },

            '0'...'9' => try self.integer(),

            else => {
                const literal = self.getLiteral();
                try self.addError(error.UnexpectedCharacter, literal);
                return error.UnexpectedCharacter;
            },
        }
    }

    pub fn hasErrors(self: *const Self) bool {
        return self.errors.items.len > 0;
    }

    pub fn handleErrors(self: *const Self, writer: *std.Io.Writer) !void {
        for (self.errors.items) |err| {
            try writer.print("{f}\n", .{err});
        }

        try writer.flush();
    }

    fn number(self: *Self, base: u8) ScannerErrorKind!void {
        while (!self.isAtEnd()) {
            const char: u8 = self.peek();
            const valid: bool = switch (base) {
                16 => std.ascii.isHex(char),
                10 => std.ascii.isDigit(char),
                8 => isOctal(char),
                2 => isBinary(char),
                else => unreachable,
            };

            if (!valid) break;
            _ = self.next();
        }

        const full_literal: []const u8 = self.getLiteral();

        const parse_slice: []const u8 = if (base == 10) full_literal else full_literal[2..];

        if (parse_slice.len == 0) {
            try self.addError(error.InvalidIntegerLiteral, full_literal);
            return error.InvalidIntegerLiteral;
        }

        const number_value: i32 = std.fmt.parseInt(i32, parse_slice, base) catch {
            try self.addError(error.InvalidIntegerLiteral, full_literal);
            return error.InvalidIntegerLiteral;
        };

        try self.addToken(.{
            .integer = number_value,
        });
    }

    fn integer(self: *Self) ScannerErrorKind!void {
        const first_digit: u8 = self.previous();

        if (first_digit == '0' and !self.isAtEnd()) {
            switch (self.peek()) {
                'x' => {
                    _ = self.next();
                    return try self.number(16);
                },

                'b' => {
                    _ = self.next();
                    return try self.number(2);
                },

                'o' => {
                    _ = self.next();
                    return try self.number(8);
                },

                '0'...'9' => {},

                else => {
                    try self.addError(error.InvalidIntegerLiteral, self.getLiteral());
                    return error.InvalidIntegerLiteral;
                },
            }
        }

        return try self.number(10);
    }

    fn identifier(self: *Self) ScannerErrorKind!void {
        while (isAlphanumeric(self.peek()) and !self.isAtEnd()) {
            _ = self.next();
        }

        const ident: []const u8 = self.getLiteral();

        try self.addToken(.{
            .identifier = ident,
        });
    }

    fn register(self: *Self) ScannerErrorKind!void {
        self.start = self.current;

        while (std.ascii.isDigit(self.peek()) and !self.isAtEnd()) {
            _ = self.next();
        }

        const number_literal: []const u8 = self.getLiteral();
        if (number_literal.len == 0) {
            try self.addError(error.InvalidRegisterLiteral, "r");
            return error.InvalidRegisterLiteral;
        }

        const register_value: u8 = std.fmt.parseInt(u8, number_literal, 10) catch {
            try self.addError(error.InvalidRegisterLiteral, number_literal);
            return error.InvalidRegisterLiteral;
        };

        if (register_value >= VM_MAX_REGISTERS) {
            try self.addError(error.InvalidRegisterLiteral, self.input[self.start - 1 .. self.current]);
            return error.InvalidRegisterLiteral;
        }

        try self.addToken(.{
            .register = register_value,
        });
    }

    fn string(self: *Self) ScannerErrorKind!void {
        self.start = self.current;

        while (self.peek() != '"' and self.peek() != '\n' and !self.isAtEnd()) {
            _ = self.next();
        }

        if (self.peek() == '\n' or self.isAtEnd()) {
            try self.addError(error.UnterminatedStringLiteral, self.getLiteral());
            return error.UnterminatedStringLiteral;
        }

        const string_literal: []const u8 = self.getLiteral();
        try self.addToken(.{
            .string_literal = string_literal,
        });

        _ = self.next();
    }

    fn sync(self: *Self) void {
        while (!self.isAtEnd()) {
            if (self.previous() == '\n') return;

            switch (self.peek()) {
                '\n' => return,
                '.' => return,
                '#' => return,
                'a'...'z', 'A'...'Z', '_' => return,
                '"' => return,

                else => _ = self.next(),
            }
        }
    }

    fn skipComment(self: *Self) void {
        while (self.peek() != '\n' and !self.isAtEnd()) {
            _ = self.next();
        }
    }

    fn getLiteral(self: *const Self) []const u8 {
        return self.input[self.start..self.current];
    }

    fn previous(self: *const Self) u8 {
        if (self.isAtEnd()) return 0;
        return self.input[self.current - 1];
    }

    fn peek(self: *const Self) u8 {
        if (self.isAtEnd()) return 0;
        return self.input[self.current];
    }

    fn addError(self: *Self, kind: ScannerErrorKind, literal: []const u8) ScannerErrorKind!void {
        const err: ScannerError = .{
            .kind = kind,
            .literal = literal,
            .line = self.line,
        };

        try self.errors.append(self.allocator, err);
    }

    fn addToken(self: *Self, kind: TokenKind) ScannerErrorKind!void {
        const tok: Token = .init(kind, self.line);

        try self.tokens.append(self.allocator, tok);
    }

    fn next(self: *Self) u8 {
        const char: u8 = self.input[self.current];
        self.current += 1;
        return char;
    }

    fn isAtEnd(self: *const Self) bool {
        return self.current >= self.input.len;
    }

    fn clear(self: *Self) void {
        self.input = undefined;
        self.start = 0;
        self.current = 0;
        self.line = 1;
        self.tokens.clearRetainingCapacity();
        self.errors.clearRetainingCapacity();
    }
};
