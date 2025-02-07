const std = @import("std");

pub const Error = error{
    UnexpectedEOF,
    UnexpectedToken,
};

pub const Expr = union(enum) {
    number: f64,
    symbol: []const u8,
    list: std.ArrayList(*Expr),

    pub fn deinit(self: *Expr, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .list => |lst| {
                for (lst.items) |item| {
                    item.deinit(allocator);
                }
                lst.deinit();
            },
            else => {},
        }
    }
};

pub const Parser = struct {
    allocator: *std.mem.Allocator,
    tokens: std.ArrayList([]const u8),
    position: usize = 0,

    pub fn init(allocator: *std.mem.Allocator, tokens: std.ArrayList([]const u8)) Parser {
        return Parser{
            .allocator = allocator,
            .tokens = tokens,
            .position = 0,
        };
    }

    fn next(self: *Parser) ?[]const u8 {
        if (self.position >= self.tokens.items.len) return null;
        const token = self.tokens.items[self.position];
        self.position += 1;
        return token;
    }

    fn peek(self: *Parser) ?[]const u8 {
        if (self.position >= self.tokens.items.len) return null;
        return self.tokens.items[self.position];
    }

    pub fn parseExpr(self: *Parser) !*Expr {
        const token = self.next() orelse return Error.UnexpectedEOF;
        if (std.mem.eql(u8, token, "(")) {
            var list = std.ArrayList(*Expr).init(self.allocator.*);
            while (true) {
                const peek_token = self.peek();
                if (peek_token) |p| {
                    if (std.mem.eql(u8, p, ")")) {
                        _ = self.next(); // consume ")"
                        break;
                    }
                } else {
                    return Error.UnexpectedEOF;
                }
                const expr = try self.parseExpr();
                try list.append(expr);
            }
            const result = try self.allocator.create(Expr);
            result.* = .{ .list = list };
            return result;
        } else if (std.mem.eql(u8, token, ")")) {
            return Error.UnexpectedToken;
        } else {
            // Try parsing as a number.
            const result = try self.allocator.create(Expr);
            if (std.fmt.parseFloat(f64, token)) |n| {
                result.* = .{ .number = n };
            } else |_| {
                result.* = .{ .symbol = token };
            }
            return result;
        }
    }
};
