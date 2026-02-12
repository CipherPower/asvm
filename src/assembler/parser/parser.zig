const std = @import("std");
const errors = @import("error.zig");
const statement = @import("statement");
const instructions = @import("instruction");

const Token = @import("token").Token;

const InstructionSet = instructions.InstructionSet;
const resolveInstruction = instructions.resolveInstruction;

const ParserErrorKind = errors.ParserErrorKind;
const ParserError = errors.ParserError;

const Statement = statement.Statement;
const StatementKind = statement.StatementKind;
const Directive = statement.Directive;
const Operand = statement.Operand;
const resolveDirective = statement.resolveDirective;


pub const Parser = struct {
    tokens: []Token,
    statements: std.ArrayList(Statement),
    errors: std.ArrayList(ParserError),
    current: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .tokens = undefined,
            .statements = .empty,
            .errors = .empty,
            .current = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.statements.deinit(self.allocator);
        self.errors.deinit(self.allocator);
    }

    pub fn parse(self: *Self, tokens: []Token) error{OutOfMemory}!void {
        self.clear();
        self.tokens = tokens;

        while (!self.isAtEnd()) {
            self.parseStatement() catch |err| switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                else => self.sync(),
            };
        }
    }

    pub fn parseStatement(self: *Self) ParserErrorKind!void {
        switch (self.peek().tag()) {
            .dot => try self.directive(),

            .identifier => {
                if (self.peekNext().tag() == .colon) {
                    try self.label();
                } else {
                    try self.instruction();
                }
            },

            .eof => {},

            else => {
                try self.addError(error.UnexpectedToken, "Expected label, directive or instruction");
                return error.UnexpectedToken;
            },
        }
    }

    pub fn hasErrors(self: *const Self) bool {
        return self.errors.items.len > 0;
    }

    fn directive(self: *Self) ParserErrorKind!void {
        _ = self.next();

        const identifier: *Token = try self.expectIdentifier();

        if () |directive_tag| {
            switch (directive_tag) {
                .entry => {
                    const label_token: *Token = try self.expectIdentifier();
                    try self.addStatement(.{
                        .directive = .{
                            .entry = .{
                                .label = label_token.kind.identifier,
                            },
                        },
                    });
                },
            }
        } else {
            try self.addError(error.UnexpectedToken, "unknown directive");
            return error.UnexpectedToken;
        }
    }

    fn label(self: *Self) ParserErrorKind!void {
        const ident: *Token = try self.expectIdentifier();
        _ = self.next();

        try self.addStatement(.{
            .label = .{
                .label = ident.kind.identifier,
            },
        });
    }

    fn instruction(self: *Self) ParserErrorKind!void {
        const mnemonic_token: *Token = try self.expectIdentifier();

        if (resolveInstruction(mnemonic_token.kind.identifier)) |instr| {
            var operands: [2]Operand = .{ .none, .none };

            if (!self.isNewStatement(mnemonic_token.line)) {
                operands[0] = try self.operand();

                if (self.matchToken(.comma)) {
                    operands[1] = try self.operand();
                }
            }

        } else {

        }
    }

    fn operand(self: *Self) ParserErrorKind!Operand {
        switch (self.peek().kind) {

        }
    }

    fn isNewStatement(self: *const Self, current_line: usize) bool {
        if (self.peek().line > current_line) return true;

        return switch (self.peek().tag()) {
            .eof => true,
            .dot => true,
            .identifier => self.peekNext().tag() == .colon,
            else => false,
        ;}
    }

    fn expectIdentifier(self: *Self) ParserErrorKind!*Token {
        if (self.peek().tag() == .identifier) {
            return self.next();
        } else {
            // const literal: []const u8 = std.fmt.allocPrint(self.allocator, "{f}", self.peek().*);
            const literal: []const u8 = "temporary";
            try self.addError(error.UnexpectedToken, literal);

            return error.UnexpectedToken;
        }
    }

    fn addStatement(self: *Self, kind: StatementKind) ParserErrorKind!void {
        const stmt: Statement = .init(kind, self.peek().line);
        try self.statements.append(self.allocator, stmt);
    }

    fn addError(self: *Self, kind: ParserErrorKind, literal: []const u8) ParserErrorKind!void {
        const err: ParserError = .{
            .kind = kind,
            .literal = literal,
            .line = self.peek().line,
        };

        try self.errors.append(self.allocator, err);
    }

    fn sync(self: *Self) void {
        _ = self.next();

        while (!self.isAtEnd()) {
            const token: *Token = self.peek();

            switch (token.tag()) {
                .dot => return,
                .identifier => {
                    if (self.peekNext().tag() == .colon) return;
                },

                else => {},
            }

            if (self.peek().line > self.previous().line) return;

            _ = self.next();
        }
    }

    fn peekNext(self: *const Self) *Token {
        if (self.current + 1 >= self.tokens.len) {
            return &self.tokens[self.tokens.len - 1];
        }

        return &self.tokens[self.current + 1];
    }

    fn next(self: *Self) *Token {
        if (!self.isAtEnd()) {
            self.current += 1;
        }

        return self.previous();
    }

    fn peek(self: *const Self) *Token {
        return &self.tokens[self.current];
    }

    fn previous(self: *const Self) *Token {
        return &self.tokens[self.current - 1];
    }

    fn isAtEnd(self: *const Self) bool {
        return self.current >= self.tokens.len;
    }

    fn clear(self: *Self) void {
        self.tokens = undefined;
        self.statements.clearRetainingCapacity();
        self.errors.clearRetainingCapacity();
        self.current = 0;
    }
};
