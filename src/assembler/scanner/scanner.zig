const std = @import("std");
const errors = @import("error.zig");
const token = @import("token");

const ScannerErrorKind = errors.ScannerErrorKind;
const ScannerError = errors.ScannerError;

const Token = token.Token;
const TokenKind = token.TokenKind;

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
        return Self{
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
                error.OutOfMemory => return err,
                else => self.sync(),
            };
        }
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

            'a'...'z', 'A'...'Z', '_' => {},

            '0'...'9' => try self.integer(),

            else => {},
        }
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
        try self.errors.append(self.allocator, .{
            .kind = kind,
            .literal = literal,
            .line = self.line,
        });
    }

    fn addToken(self: *Self, kind: TokenKind) ScannerErrorKind!void {
        try self.tokens.append(self.allocator, .{
            .kind = kind,
            .line = self.line,
        });
    }

    fn next(self: Self) u8 {
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
