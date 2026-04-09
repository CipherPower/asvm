const std = @import("std");
const errors = @import("error.zig");
const token = @import("token");

const ScannerErrorKind = errors.ScannerErrorKind;
const ScannerError = errors.ScannerError;

const Token = token.Token;
const TokenKind = token.TokenKind;

const VM_MAX_REGISTERS: comptime_int = @import("vm").MAX_REGISTERS;

/// Utility for checking if a character is alphanumeric or is an underscore
fn isAlphanumeric(char: u8) bool {
    return std.ascii.isAlphanumeric(char) or char == '_';
}

/// Utility for checking if a character is a valid octal character.
fn isOctal(char: u8) bool {
    return char >= '0' and char <= '7';
}

/// Utility for checking if a character is a valid binary character.
fn isBinary(char: u8) bool {
    return char == '0' or char == '1';
}

/// Data structure for converting a text input ([]u8) into a series of tokens.
pub const Scanner = struct {
    input: []const u8,
    start: usize,
    current: usize,
    line: usize,
    tokens: std.ArrayList(Token),
    errors: std.ArrayList(ScannerError),
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Instantiates a new Scanner instance.
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

    /// Frees all memory allocated during scanning.
    pub fn deinit(self: *Self) void {
        self.tokens.deinit(self.allocator);
        self.errors.deinit(self.allocator);
    }

    /// Commences scanning of the byte slice into tokens.
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

    /// Converts a series of bytes into a single token.
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

    /// Wrapper for checking if the Scanner encountered any errors
    /// during scanning.
    pub fn hasErrors(self: *const Self) bool {
        return self.errors.items.len > 0;
    }

    /// Wrapper for outputting all errors encountered during scanning
    /// to a given writer.
    pub fn handleErrors(self: *const Self, writer: *std.Io.Writer) !void {
        for (self.errors.items) |err| {
            try writer.print("{f}\n", .{err});
        }

        try writer.flush();
    }

    /// Function that parses a number of base 16, 10, 8, 2 into an Integer token.
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

    /// A dispatcher function that decides which base the number is.
    fn integer(self: *Self) ScannerErrorKind!void {
        const first_digit: u8 = self.previous();

        if (first_digit == '0') {
            switch (self.peek()) {
                ' ', '\t', '\r', '\n' => return try self.number(10),
                else => {},
            }
        }

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

    /// Scans an identifier.
    fn identifier(self: *Self) ScannerErrorKind!void {
        while (isAlphanumeric(self.peek()) and !self.isAtEnd()) {
            _ = self.next();
        }

        const ident: []const u8 = self.getLiteral();

        try self.addToken(.{
            .identifier = ident,
        });
    }

    /// Scans an integer and takes it as a register value.
    /// Also does some checking to ensure the register is valid.
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

    /// Scans a string, checking for encapsulating quotes, making sure that the string
    /// is not split across multiple lines.
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

    /// Synchronises the seeking of the scanner to ensure that
    /// there are no cascading errors after encountering an error.
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

    /// Seeks ahead to skip the slice referring to a comment.
    fn skipComment(self: *Self) void {
        while (self.peek() != '\n' and !self.isAtEnd()) {
            _ = self.next();
        }
    }

    /// Helper function to get the slice between the start and current offset.
    fn getLiteral(self: *const Self) []const u8 {
        return self.input[self.start..self.current];
    }

    /// Utility function for peeking at the previous byte.
    fn previous(self: *const Self) u8 {
        if (self.isAtEnd() or self.current - 1 < 0) return 0;
        return self.input[self.current - 1];
    }

    /// Utility function for peeking at the current byte.
    fn peek(self: *const Self) u8 {
        if (self.isAtEnd()) return 0;
        return self.input[self.current];
    }

    /// Utility function for creating and appending an error to the error list.
    fn addError(self: *Self, kind: ScannerErrorKind, literal: []const u8) ScannerErrorKind!void {
        const err: ScannerError = .{
            .kind = kind,
            .literal = literal,
            .line = self.line,
        };

        try self.errors.append(self.allocator, err);
    }

    /// Utility function for creating and appending a token to the output.
    fn addToken(self: *Self, kind: TokenKind) ScannerErrorKind!void {
        const tok: Token = .init(kind, self.line);

        try self.tokens.append(self.allocator, tok);
    }

    /// Used to advance the scanner to the next byte.
    fn next(self: *Self) u8 {
        const char: u8 = self.input[self.current];
        self.current += 1;
        return char;
    }

    /// Utility function used to check if the scanner has reached the end
    /// of the input string.
    fn isAtEnd(self: *const Self) bool {
        return self.current >= self.input.len;
    }

    /// Resets the scanner for reuse.
    fn clear(self: *Self) void {
        self.input = undefined;
        self.start = 0;
        self.current = 0;
        self.line = 1;
        self.tokens.clearRetainingCapacity();
        self.errors.clearRetainingCapacity();
    }
};
