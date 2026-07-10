const std = @import("std");

pub const Error = error{
    UnexpectedEOF,
    UnexpectedToken,
    RecursionLimit,
    /// String literals are not part of the language (numbers and symbols only)
    UnsupportedString,
};

/// Maximum nesting depth for parsed expressions (prevents stack overflow
/// on pathologically nested input).
pub const MAX_PARSE_DEPTH = 256;

pub const Expr = union(enum) {
    number: f64,
    symbol: []const u8,
    /// Owned symbol: a symbol whose memory should be freed on deinit
    owned_symbol: []const u8,
    list: std.ArrayList(*Expr),
    /// Lambda: stores parameter names and body expression
    /// Format: lambda{ .params = ["x", "y"], .body = <expr> }
    lambda: Lambda,

    pub const Lambda = struct {
        params: std.ArrayList([]const u8),
        body: *Expr,
    };

    pub fn deinit(self: *Expr, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .list => |*lst| {
                for (lst.items) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                lst.deinit(allocator);
            },
            .lambda => |*lam| {
                lam.body.deinit(allocator);
                allocator.destroy(lam.body);
                lam.params.deinit(allocator);
            },
            .owned_symbol => |s| {
                allocator.free(s);
            },
            else => {},
        }
    }
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: std.ArrayList([]const u8),
    position: usize = 0,

    pub fn init(allocator: std.mem.Allocator, tokens: std.ArrayList([]const u8)) Parser {
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
        return self.parseExprDepth(0);
    }

    fn parseExprDepth(self: *Parser, depth: usize) (Error || std.mem.Allocator.Error)!*Expr {
        if (depth > MAX_PARSE_DEPTH) return Error.RecursionLimit;
        const token = self.next() orelse return Error.UnexpectedEOF;
        if (std.mem.eql(u8, token, "(")) {
            var list: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (list.items) |item| {
                    item.deinit(self.allocator);
                    self.allocator.destroy(item);
                }
                list.deinit(self.allocator);
            }
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
                const expr = try self.parseExprDepth(depth + 1);
                try list.append(self.allocator, expr);
            }
            const result = try self.allocator.create(Expr);
            result.* = .{ .list = list };
            return result;
        } else if (std.mem.eql(u8, token, ")")) {
            return Error.UnexpectedToken;
        } else {
            // Reject string literals explicitly (better than a silent symbol)
            if (std.mem.indexOfScalar(u8, token, '"') != null) {
                return Error.UnsupportedString;
            }
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

/// Heuristic: does the token stream look like infix math (e.g. "1 + 2",
/// "2+3", or "sin(x)") rather than prefix S-expressions? Used by the CLI
/// and REPL to print a helpful hint for new users.
pub fn looksLikeInfix(tokens: []const []const u8) bool {
    if (tokens.len == 0) return false;
    if (std.mem.eql(u8, tokens[0], "(")) return false;

    // "sin(x)": a symbol immediately followed by an open paren
    if (tokens.len >= 2 and std.mem.eql(u8, tokens[1], "(")) return true;

    const ops = [_][]const u8{ "+", "-", "*", "/", "^", "=" };

    // "1 + 2": a bare operator token after the first atom
    if (tokens.len >= 3) {
        for (tokens[1..]) |tok| {
            for (ops) |op| {
                if (std.mem.eql(u8, tok, op)) return true;
            }
        }
    }

    // "2+3": a single token mixing digits and operator characters
    if (tokens.len == 1) {
        const tok = tokens[0];
        var has_digit = false;
        var has_op = false;
        for (tok, 0..) |c, i| {
            if (c >= '0' and c <= '9') has_digit = true;
            // A leading '-' or '.' is just a negative/decimal number
            if (i > 0 and (c == '+' or c == '*' or c == '/' or c == '^' or c == '-')) {
                // Exponent notation like 1e-5 is fine
                const prev = tok[i - 1];
                if (prev != 'e' and prev != 'E') has_op = true;
            }
        }
        return has_digit and has_op;
    }

    return false;
}
