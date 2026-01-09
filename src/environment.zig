const std = @import("std");
const Expr = @import("parser.zig").Expr;
const BuiltinFn = @import("builtins.zig").BuiltinFn;

pub const Error = error{
    KeyNotFound,
};

/// A rewrite rule: pattern -> replacement
/// Pattern variables are symbols starting with '?'
pub const Rule = struct {
    pattern: *Expr,
    replacement: *Expr,
};

/// Assumptions about symbols (e.g., positive, integer, real)
pub const Assumption = packed struct {
    positive: bool = false,
    negative: bool = false,
    nonzero: bool = false,
    integer: bool = false,
    real: bool = false,
    even: bool = false,
    odd: bool = false,
    _padding: u1 = 0,
};

pub const Env = struct {
    allocator: std.mem.Allocator,
    variables: std.StringHashMap(*Expr),
    builtins: std.StringHashMap(BuiltinFn),
    rules: std.ArrayList(Rule),
    assumptions: std.StringHashMap(Assumption),

    pub fn init(allocator: std.mem.Allocator) Env {
        return Env{
            .allocator = allocator,
            .variables = std.StringHashMap(*Expr).init(allocator),
            .builtins = std.StringHashMap(BuiltinFn).init(allocator),
            .rules = .empty,
            .assumptions = std.StringHashMap(Assumption).init(allocator),
        };
    }

    pub fn deinit(self: *Env) void {
        var it = self.variables.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.variables.deinit();
        self.builtins.deinit();
        // Free rules
        for (self.rules.items) |rule| {
            var pat = rule.pattern;
            pat.deinit(self.allocator);
            self.allocator.destroy(pat);
            var rep = rule.replacement;
            rep.deinit(self.allocator);
            self.allocator.destroy(rep);
        }
        self.rules.deinit(self.allocator);
        self.assumptions.deinit();
    }

    pub fn assume(self: *Env, symbol: []const u8, assumption: Assumption) !void {
        if (self.assumptions.get(symbol)) |existing| {
            // Merge assumptions
            var merged = existing;
            if (assumption.positive) merged.positive = true;
            if (assumption.negative) merged.negative = true;
            if (assumption.nonzero) merged.nonzero = true;
            if (assumption.integer) merged.integer = true;
            if (assumption.real) merged.real = true;
            if (assumption.even) merged.even = true;
            if (assumption.odd) merged.odd = true;
            try self.assumptions.put(symbol, merged);
        } else {
            try self.assumptions.put(symbol, assumption);
        }
    }

    pub fn getAssumption(self: *Env, symbol: []const u8) ?Assumption {
        return self.assumptions.get(symbol);
    }

    pub fn isPositive(self: *Env, symbol: []const u8) bool {
        if (self.assumptions.get(symbol)) |a| {
            return a.positive;
        }
        return false;
    }

    pub fn isInteger(self: *Env, symbol: []const u8) bool {
        if (self.assumptions.get(symbol)) |a| {
            return a.integer;
        }
        return false;
    }

    pub fn isNonzero(self: *Env, symbol: []const u8) bool {
        if (self.assumptions.get(symbol)) |a| {
            return a.nonzero or a.positive or a.negative;
        }
        return false;
    }

    pub fn get(self: *Env, key: []const u8) !*Expr {
        return self.variables.get(key) orelse return Error.KeyNotFound;
    }

    pub fn put(self: *Env, key: []const u8, val: *Expr) !void {
        try self.variables.put(key, val);
    }

    pub fn getBuiltin(self: *Env, key: []const u8) !BuiltinFn {
        return self.builtins.get(key) orelse return Error.KeyNotFound;
    }

    pub fn putBuiltin(self: *Env, key: []const u8, fn_ptr: BuiltinFn) !void {
        try self.builtins.put(key, fn_ptr);
    }
};
