const std = @import("std");

pub const TokenKindTag = enum {
    identifier,
    integer,
    register,
    string_literal,
    dot,
    colon,
    comma,
    left_bracket,
    right_bracket,
    left_paren,
    right_paren,
    hashtag,
    plus,
    minus,
    eof,
};

pub const TokenKind = union(TokenKindTag) {
    identifier: []const u8,
    integer: i32,
    register: u8,
    string_literal: []const u8,
    dot,
    colon,
    comma,
    left_bracket,
    right_bracket,
    left_paren,
    right_paren,
    hashtag,
    plus,
    minus,
    eof,

    const Self = @This();

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        switch (self) {
            .identifier => |ident| try writer.print("identifier(\"{s}\")", .{ident}),
            .integer => |int| try writer.print("integer({d})", .{int}),
            .register => |reg| try writer.print("register(r{d})", .{reg}),
            .string_literal => |lit| try writer.print("string(\"{s}\")", .{lit}),
            .dot => try writer.writeAll("'.'"),
            .colon => try writer.writeAll("':'"),
            .comma => try writer.writeAll("','"),
            .left_bracket => try writer.writeAll("'['"),
            .right_bracket => try writer.writeAll("']'"),
            .left_paren => try writer.writeAll("'('"),
            .right_paren => try writer.writeAll("')'"),
            .hashtag => try writer.writeAll("'#'"),
            .plus => try writer.writeAll("'+'"),
            .minus => try writer.writeAll("'-'"),
            .eof => try writer.writeAll("<EOF>"),
        }
    }
};

pub const Token = struct {
    kind: TokenKind,
    line: usize,

    const Self = @This();

    pub fn init(kind: TokenKind, line: usize) Self {
        return Self{
            .kind = kind,
            .line = line,
        };
    }

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        try writer.print("Token{{ kind: {f}, line: {d} }}", .{ self.kind, self.line });
    }

    pub fn tag(self: Self) TokenKindTag {
        return @as(TokenKindTag, self);
    }
};
