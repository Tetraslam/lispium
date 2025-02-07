const std = @import("std");
const Expr = @import("parser.zig").Expr;
const BuiltinFn = @import("builtins.zig").BuiltinFn;

pub const Error = error{
    KeyNotFound,
};

pub const Env = struct {
    allocator: *std.mem.Allocator,
    variables: std.StringHashMap(*Expr),
    builtins: std.StringHashMap(BuiltinFn),

    pub fn init(allocator: *std.mem.Allocator) Env {
        return Env{
            .allocator = allocator,
            .variables = std.StringHashMap(*Expr).init(allocator.*),
            .builtins = std.StringHashMap(BuiltinFn).init(allocator.*),
        };
    }

    pub fn deinit(self: *Env) void {
        var it = self.variables.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator.*);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.variables.deinit();
        self.builtins.deinit();
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
