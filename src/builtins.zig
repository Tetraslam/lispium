const std = @import("std");
const Expr = @import("parser.zig").Expr;
const Env = @import("environment.zig").Env;
const symbolic = @import("symbolic.zig");

pub const BuiltinError = error{
    InvalidArgument,
    OutOfMemory,
};

pub const BuiltinFn = *const fn (args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr;

pub fn builtin_add(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // If all arguments are numbers, compute the sum
    var all_numbers = true;
    var sum: f64 = 0;
    for (args.items) |arg| {
        if (arg.* == .number) {
            sum += arg.number;
        } else {
            all_numbers = false;
            break;
        }
    }
    if (all_numbers) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = sum };
        return result;
    }

    // Otherwise, create a symbolic expression
    var list = std.ArrayList(*Expr).init(env.allocator.*);
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "+" };
    try list.append(op);
    for (args.items) |arg| {
        try list.append(arg);
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_subtract(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    // If all arguments are numbers, compute the result
    var all_numbers = true;
    var result: f64 = if (args.items[0].* == .number) args.items[0].number else blk: {
        all_numbers = false;
        break :blk 0;
    };
    for (args.items[1..]) |arg| {
        if (arg.* == .number and all_numbers) {
            result -= arg.number;
        } else {
            all_numbers = false;
        }
    }
    if (all_numbers) {
        const expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        expr.* = .{ .number = result };
        return expr;
    }

    // Otherwise, create a symbolic expression
    var list = std.ArrayList(*Expr).init(env.allocator.*);
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "-" };
    try list.append(op);
    for (args.items) |arg| {
        try list.append(arg);
    }
    const expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    expr.* = .{ .list = list };
    return expr;
}

pub fn builtin_multiply(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // If all arguments are numbers, compute the product
    var all_numbers = true;
    var product: f64 = 1;
    for (args.items) |arg| {
        if (arg.* == .number) {
            product *= arg.number;
        } else {
            all_numbers = false;
            break;
        }
    }
    if (all_numbers) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = product };
        return result;
    }

    // Otherwise, create a symbolic expression
    var list = std.ArrayList(*Expr).init(env.allocator.*);
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "*" };
    try list.append(op);
    for (args.items) |arg| {
        try list.append(arg);
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_divide(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    // If all arguments are numbers, compute the result
    var all_numbers = true;
    var result: f64 = if (args.items[0].* == .number) args.items[0].number else blk: {
        all_numbers = false;
        break :blk 0;
    };
    for (args.items[1..]) |arg| {
        if (arg.* == .number and all_numbers) {
            if (arg.number == 0) return BuiltinError.InvalidArgument;
            result /= arg.number;
        } else {
            all_numbers = false;
        }
    }
    if (all_numbers) {
        const expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        expr.* = .{ .number = result };
        return expr;
    }

    // Otherwise, create a symbolic expression
    var list = std.ArrayList(*Expr).init(env.allocator.*);
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "/" };
    try list.append(op);
    for (args.items) |arg| {
        try list.append(arg);
    }
    const expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    expr.* = .{ .list = list };
    return expr;
}

pub fn builtin_simplify(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;
    return symbolic.simplify(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_diff(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    return symbolic.diff(args.items[0], args.items[1].symbol, env.allocator) catch return BuiltinError.OutOfMemory;
}
