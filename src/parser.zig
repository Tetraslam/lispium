const std = @import("std");

pub const Error = error{
    UnexpectedEOF,
    UnexpectedToken,
    RecursionLimit,
    /// A string literal without a closing quote
    UnterminatedString,
    /// Invalid escape sequence inside a string literal
    InvalidEscape,
};

/// Maximum nesting depth for parsed expressions (prevents stack overflow
/// on pathologically nested input).
pub const MAX_PARSE_DEPTH = 256;

pub const Expr = union(enum) {
    number: f64,
    /// Arbitrary-precision integer (values outside the f64-exact range;
    /// smaller results demote back to .number)
    big: Big,
    symbol: []const u8,
    /// Owned symbol: a symbol whose memory should be freed on deinit
    owned_symbol: []const u8,
    /// String literal (owned, freed on deinit)
    string: []const u8,
    /// Dictionary: string keys (owned) to owned values. Immutable in the
    /// language: dict-set returns a new dict. Symbol/number keys are
    /// stringified on the way in.
    dict: Dict,
    list: std.ArrayList(*Expr),
    /// Lambda: stores parameter names and body expression
    /// Format: lambda{ .params = ["x", "y"], .body = <expr> }
    lambda: Lambda,

    pub const Big = struct {
        /// Owned limb storage in std.math.big.int.Const form (normalized)
        limbs: []std.math.big.Limb,
        positive: bool,

        pub fn toConst(self: Big) std.math.big.int.Const {
            return .{ .limbs = self.limbs, .positive = self.positive };
        }
    };

    pub const Dict = struct {
        /// Keys are owned strings; values are owned expressions
        map: std.StringArrayHashMapUnmanaged(*Expr),

        pub const empty: Dict = .{ .map = .empty };

        pub fn deinitAll(self: *Dict, allocator: std.mem.Allocator) void {
            var it = self.map.iterator();
            while (it.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                entry.value_ptr.*.deinit(allocator);
                allocator.destroy(entry.value_ptr.*);
            }
            self.map.deinit(allocator);
        }
    };

    pub const Lambda = struct {
        params: std.ArrayList([]const u8),
        body: *Expr,
        /// The define-time name (for stack traces and display); anonymous
        /// lambdas have null
        name: ?[]const u8 = null,
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
            .string => |s| {
                allocator.free(s);
            },
            .big => |b| {
                allocator.free(b.limbs);
            },
            .dict => |*d| {
                d.deinitAll(allocator);
            },
            else => {},
        }
    }
};

/// Maps parse-tree nodes to the source token that starts them ('(' for
/// lists). Tokens are slices into the tokenized source, so byte offsets
/// (and from them line/column) can be recovered with `tokenLineCol`.
pub const PosMap = std.AutoHashMap(*const Expr, []const u8);

pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: std.ArrayList([]const u8),
    position: usize = 0,
    /// When set, every created node is recorded here (best effort)
    positions: ?*PosMap = null,
    /// The innermost token at which parsing failed (null for plain EOF)
    error_token: ?[]const u8 = null,

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
        const result = self.parseTokenDepth(token, depth) catch |err| {
            // Remember the innermost failing token (first setter wins)
            if (self.error_token == null) self.error_token = token;
            return err;
        };
        if (self.positions) |map| {
            map.put(result, token) catch {};
        }
        return result;
    }

    fn parseTokenDepth(self: *Parser, token: []const u8, depth: usize) (Error || std.mem.Allocator.Error)!*Expr {
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
        } else if (token.len > 0 and token[0] == '"') {
            // String literal (token includes the surrounding quotes)
            if (token.len < 2 or token[token.len - 1] != '"') {
                return Error.UnterminatedString;
            }
            const inner = token[1 .. token.len - 1];
            var buf: std.ArrayList(u8) = .empty;
            errdefer buf.deinit(self.allocator);
            var i: usize = 0;
            while (i < inner.len) : (i += 1) {
                if (inner[i] == '\\' and i + 1 < inner.len) {
                    i += 1;
                    const esc: u8 = switch (inner[i]) {
                        'n' => '\n',
                        't' => '\t',
                        'r' => '\r',
                        '\\' => '\\',
                        '"' => '"',
                        else => return Error.InvalidEscape,
                    };
                    try buf.append(self.allocator, esc);
                } else {
                    try buf.append(self.allocator, inner[i]);
                }
            }
            const result = try self.allocator.create(Expr);
            errdefer self.allocator.destroy(result);
            result.* = .{ .string = try buf.toOwnedSlice(self.allocator) };
            return result;
        } else if (std.mem.eql(u8, token, "'") or std.mem.eql(u8, token, "`") or std.mem.eql(u8, token, ",")) {
            // Reader sugar: 'x => (quote x), `x => (quasiquote x), ,x => (unquote x)
            const form = if (std.mem.eql(u8, token, "'"))
                "quote"
            else if (std.mem.eql(u8, token, "`"))
                "quasiquote"
            else
                "unquote";
            const inner = try self.parseExprDepth(depth + 1);
            errdefer {
                inner.deinit(self.allocator);
                self.allocator.destroy(inner);
            }
            var list: std.ArrayList(*Expr) = .empty;
            errdefer list.deinit(self.allocator);
            const head = try self.allocator.create(Expr);
            head.* = .{ .symbol = form };
            try list.append(self.allocator, head);
            try list.append(self.allocator, inner);
            const result = try self.allocator.create(Expr);
            result.* = .{ .list = list };
            return result;
        } else {
            // Exact rational literal: p/q with integer p and q
            if (parseRationalLiteral(token)) |pq| {
                var list: std.ArrayList(*Expr) = .empty;
                errdefer {
                    for (list.items) |item| {
                        item.deinit(self.allocator);
                        self.allocator.destroy(item);
                    }
                    list.deinit(self.allocator);
                }
                const head = try self.allocator.create(Expr);
                head.* = .{ .symbol = "rational" };
                try list.append(self.allocator, head);
                const p = try self.allocator.create(Expr);
                p.* = .{ .number = @floatFromInt(pq.p) };
                try list.append(self.allocator, p);
                const q = try self.allocator.create(Expr);
                q.* = .{ .number = @floatFromInt(pq.q) };
                try list.append(self.allocator, q);
                const result = try self.allocator.create(Expr);
                result.* = .{ .list = list };
                return result;
            }
            // Big integer literal: an all-digit token whose value exceeds
            // the exactly-representable f64 integer range
            if (parseBigLiteral(self.allocator, token)) |big| {
                const result = self.allocator.create(Expr) catch |err| {
                    self.allocator.free(big.limbs);
                    return err;
                };
                result.* = .{ .big = big };
                return result;
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

pub const LineCol = struct { line: usize, col: usize };

/// 1-based line/column of `token` within `source`. Only works when the
/// token is a slice into `source` (as produced by the tokenizer); returns
/// null otherwise.
pub fn tokenLineCol(source: []const u8, token: []const u8) ?LineCol {
    const src_start = @intFromPtr(source.ptr);
    const tok_start = @intFromPtr(token.ptr);
    if (tok_start < src_start or tok_start + token.len > src_start + source.len) return null;
    const offset = tok_start - src_start;
    var line: usize = 1;
    var col: usize = 1;
    for (source[0..offset]) |c| {
        if (c == '\n') {
            line += 1;
            col = 1;
        } else {
            col += 1;
        }
    }
    return .{ .line = line, .col = col };
}

/// Heuristic: does the token stream look like infix math (e.g. "1 + 2",
/// "2+3", or "sin(x)") rather than prefix S-expressions? Used by the CLI
/// and REPL to print a helpful hint for new users.
pub fn looksLikeInfix(tokens: []const []const u8) bool {
    if (tokens.len == 0) return false;
    if (std.mem.eql(u8, tokens[0], "(")) return false;
    // Reader sugar prefixes are valid prefix syntax
    if (std.mem.eql(u8, tokens[0], "'") or std.mem.eql(u8, tokens[0], "`") or std.mem.eql(u8, tokens[0], ",")) return false;

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
        // Rational literals like 1/3 or -22/7 are valid syntax, not infix
        if (parseRationalLiteral(tok) != null) return false;
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

/// Parses "p/q" (integers, optional leading minus on p) as a rational
/// literal, e.g. "1/3" or "-22/7". Returns null for anything else, so
/// symbols like "gf/" or paths are unaffected.
fn parseRationalLiteral(token: []const u8) ?struct { p: i64, q: i64 } {
    const slash = std.mem.indexOfScalar(u8, token, '/') orelse return null;
    if (slash == 0 or slash + 1 >= token.len) return null;
    const p = std.fmt.parseInt(i64, token[0..slash], 10) catch return null;
    const q = std.fmt.parseInt(i64, token[slash + 1 ..], 10) catch return null;
    if (q == 0) return null;
    return .{ .p = p, .q = q };
}

/// Parses an integer literal too large for exact f64 representation into
/// an arbitrary-precision integer. Returns null for anything else.
fn parseBigLiteral(allocator: std.mem.Allocator, token: []const u8) ?Expr.Big {
    var digits = token;
    var negative = false;
    if (digits.len > 0 and (digits[0] == '-' or digits[0] == '+')) {
        negative = digits[0] == '-';
        digits = digits[1..];
    }
    if (digits.len == 0) return null;
    for (digits) |c| {
        if (c < '0' or c > '9') return null;
    }
    // Small integers stay as plain (exact) numbers
    if (digits.len <= 15) return null;

    var m = std.math.big.int.Managed.initSet(allocator, 0) catch return null;
    defer m.deinit();
    m.setString(10, digits) catch return null;
    if (m.fitsInTwosComp(.signed, 54)) return null; // exact in f64

    if (negative) m.negate();
    const c = m.toConst();
    const limbs = allocator.dupe(std.math.big.Limb, c.limbs) catch return null;
    return .{ .limbs = limbs, .positive = c.positive };
}
