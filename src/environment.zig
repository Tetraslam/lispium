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
    /// Output sink for (print ...); null makes print a no-op (tests)
    out: ?*std.Io.Writer = null,
    /// Input source for (read); null makes read return the symbol eof
    in: ?*std.Io.Reader = null,
    /// Buffers owned by the environment (e.g. lines consumed by (read));
    /// parsed symbols may reference these bytes, freed on deinit
    owned_buffers: std.ArrayList([]u8) = .empty,
    /// The Io instance for file access ((load ...)); null disables it
    io: ?std.Io = null,
    /// Command-line arguments after the script path, for (args)
    script_args: []const []const u8 = &.{},
    /// User-defined macros: name -> lambda whose body is a template
    macros: ?std.StringHashMap(*Expr) = null,
    /// Function names being traced by (trace name)
    traced: ?std.StringHashMap(void) = null,

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
        // The memoization cache allocates from this environment's allocator
        @import("builtins.zig").deinitMemoCache();
        for (self.owned_buffers.items) |buf| self.allocator.free(buf);
        self.owned_buffers.deinit(self.allocator);
        if (self.traced) |*traced| {
            var tit = traced.iterator();
            while (tit.next()) |entry| self.allocator.free(entry.key_ptr.*);
            traced.deinit();
        }
        if (self.macros) |*macros| {
            var mit = macros.iterator();
            while (mit.next()) |entry| {
                entry.value_ptr.*.deinit(self.allocator);
                self.allocator.destroy(entry.value_ptr.*);
                self.allocator.free(entry.key_ptr.*);
            }
            macros.deinit();
        }
        var it = self.variables.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
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
        // Free owned assumption keys
        var assumptions_it = self.assumptions.iterator();
        while (assumptions_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.assumptions.deinit();
    }

    /// Toggles tracing for a function name; returns the new state.
    pub fn toggleTrace(self: *Env, name: []const u8) !bool {
        if (self.traced == null) {
            self.traced = std.StringHashMap(void).init(self.allocator);
        }
        if (self.traced.?.fetchRemove(name)) |kv| {
            self.allocator.free(kv.key);
            return false;
        }
        const owned = try self.allocator.dupe(u8, name);
        try self.traced.?.put(owned, {});
        return true;
    }

    pub fn isTraced(self: *Env, name: []const u8) bool {
        if (self.traced) |traced| return traced.contains(name);
        return false;
    }

    /// Registers a macro (takes ownership of the lambda expression).
    pub fn putMacro(self: *Env, name: []const u8, lambda: *Expr) !void {
        if (self.macros == null) {
            self.macros = std.StringHashMap(*Expr).init(self.allocator);
        }
        if (self.macros.?.getEntry(name)) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
            entry.value_ptr.* = lambda;
        } else {
            const owned_key = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(owned_key);
            try self.macros.?.put(owned_key, lambda);
        }
    }

    /// Looks up a macro by name.
    pub fn getMacro(self: *Env, name: []const u8) ?*Expr {
        if (self.macros) |macros| return macros.get(name);
        return null;
    }

    /// Takes ownership of a buffer, freeing it when the environment dies.
    pub fn keepBuffer(self: *Env, buf: []u8) !void {
        try self.owned_buffers.append(self.allocator, buf);
    }

    pub fn assume(self: *Env, symbol: []const u8, assumption: Assumption) !void {
        if (self.assumptions.get(symbol)) |existing| {
            // Merge assumptions - key already owned
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
            // Duplicate the key so we own it
            const owned_key = try self.allocator.dupe(u8, symbol);
            try self.assumptions.put(owned_key, assumption);
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

    /// Stores a variable binding. The key is duplicated so the environment
    /// owns its own copy (callers may pass slices into transient buffers).
    pub fn put(self: *Env, key: []const u8, val: *Expr) !void {
        if (self.variables.getEntry(key)) |entry| {
            // Key already owned by the map; just swap the value.
            entry.value_ptr.* = val;
        } else {
            const owned_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(owned_key);
            try self.variables.put(owned_key, val);
        }
    }

    /// Removes a variable binding, freeing the owned key.
    /// Does NOT free the value (callers manage value lifetime).
    pub fn remove(self: *Env, key: []const u8) bool {
        if (self.variables.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }

    pub fn getBuiltin(self: *Env, key: []const u8) !BuiltinFn {
        return self.builtins.get(key) orelse return Error.KeyNotFound;
    }

    pub fn putBuiltin(self: *Env, key: []const u8, fn_ptr: BuiltinFn) !void {
        try self.builtins.put(key, fn_ptr);
    }
};
