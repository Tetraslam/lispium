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

    // Otherwise, create a symbolic expression (copy args since evaluator owns them)
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "+" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_subtract(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    // If all arguments are numbers, compute the result
    var all_numbers = true;
    var result_val: f64 = if (args.items[0].* == .number) args.items[0].number else blk: {
        all_numbers = false;
        break :blk 0;
    };
    for (args.items[1..]) |arg| {
        if (arg.* == .number and all_numbers) {
            result_val -= arg.number;
        } else {
            all_numbers = false;
        }
    }
    if (all_numbers) {
        const expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        expr.* = .{ .number = result_val };
        return expr;
    }

    // Otherwise, create a symbolic expression (copy args since evaluator owns them)
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "-" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
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

    // Otherwise, create a symbolic expression (copy args since evaluator owns them)
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "*" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_divide(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    // If all arguments are numbers, compute the result
    var all_numbers = true;
    var result_val: f64 = if (args.items[0].* == .number) args.items[0].number else blk: {
        all_numbers = false;
        break :blk 0;
    };
    for (args.items[1..]) |arg| {
        if (arg.* == .number and all_numbers) {
            if (arg.number == 0) return BuiltinError.InvalidArgument;
            result_val /= arg.number;
        } else {
            all_numbers = false;
        }
    }
    if (all_numbers) {
        const expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        expr.* = .{ .number = result_val };
        return expr;
    }

    // Otherwise, create a symbolic expression (copy args since evaluator owns them)
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "/" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    expr.* = .{ .list = list };
    return expr;
}

pub fn builtin_power(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    // If both arguments are numbers, compute the power
    if (args.items[0].* == .number and args.items[1].* == .number) {
        const base = args.items[0].number;
        const exp = args.items[1].number;
        const result_val = std.math.pow(f64, base, exp);
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = result_val };
        return result;
    }

    // Otherwise, create a symbolic expression (copy args since evaluator owns them)
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "^" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
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

pub fn builtin_integrate(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    return symbolic.integrate(args.items[0], args.items[1].symbol, env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_expand(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;
    return symbolic.expand(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
}

// ============================================================================
// Trigonometric Functions
// ============================================================================

pub fn builtin_sin(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    // If argument is a number, compute sin
    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = @sin(args.items[0].number) };
        return result;
    }

    // Otherwise, create a symbolic expression
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "sin" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_cos(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    // If argument is a number, compute cos
    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = @cos(args.items[0].number) };
        return result;
    }

    // Otherwise, create a symbolic expression
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "cos" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_tan(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    // If argument is a number, compute tan
    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = @tan(args.items[0].number) };
        return result;
    }

    // Otherwise, create a symbolic expression
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "tan" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

// ============================================================================
// Logarithm and Exponential Functions
// ============================================================================

pub fn builtin_exp(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    // If argument is a number, compute exp
    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = @exp(args.items[0].number) };
        return result;
    }

    // Otherwise, create a symbolic expression
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "exp" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_ln(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    // If argument is a number, compute natural log
    if (args.items[0].* == .number) {
        const val = args.items[0].number;
        if (val <= 0) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = @log(val) };
        return result;
    }

    // Otherwise, create a symbolic expression
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "ln" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_log(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // log with one argument is log base 10
    // log with two arguments is log_base(value)
    if (args.items.len == 1) {
        if (args.items[0].* == .number) {
            const val = args.items[0].number;
            if (val <= 0) return BuiltinError.InvalidArgument;
            const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = @log10(val) };
            return result;
        }

        // Otherwise, create a symbolic expression for log10
        var list: std.ArrayList(*Expr) = .empty;
        const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        op.* = .{ .symbol = "log" };
        list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
        const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .list = list };
        return result;
    } else if (args.items.len == 2) {
        // log(base, value)
        if (args.items[0].* == .number and args.items[1].* == .number) {
            const base = args.items[0].number;
            const val = args.items[1].number;
            if (val <= 0 or base <= 0 or base == 1) return BuiltinError.InvalidArgument;
            const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = @log(val) / @log(base) };
            return result;
        }

        // Otherwise, create a symbolic expression
        var list: std.ArrayList(*Expr) = .empty;
        const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        op.* = .{ .symbol = "log" };
        list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
        for (args.items) |arg| {
            const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
            list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
        }
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .list = list };
        return result;
    }

    return BuiltinError.InvalidArgument;
}

pub fn builtin_sqrt(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    // If argument is a number, compute sqrt
    if (args.items[0].* == .number) {
        const val = args.items[0].number;
        if (val < 0) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = @sqrt(val) };
        return result;
    }

    // Otherwise, create (^ x 0.5) for symbolic sqrt
    const base_copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    const half = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    half.* = .{ .number = 0.5 };
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "^" };

    var list: std.ArrayList(*Expr) = .empty;
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, base_copy) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, half) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

// ============================================================================
// Substitution and Taylor Series
// ============================================================================

pub fn builtin_substitute(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (substitute expr var value) - replaces var with value in expr
    if (args.items.len != 3) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    return symbolic.substitute(args.items[0], args.items[1].symbol, args.items[2], env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_taylor(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (taylor expr var point order) - computes Taylor series of expr around point
    if (args.items.len != 4) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;
    if (args.items[2].* != .number) return BuiltinError.InvalidArgument;
    if (args.items[3].* != .number) return BuiltinError.InvalidArgument;

    const order_f = args.items[3].number;
    if (order_f < 0 or order_f != @floor(order_f) or order_f > 20) {
        return BuiltinError.InvalidArgument;
    }
    const order: usize = @intFromFloat(order_f);

    return symbolic.taylor(args.items[0], args.items[1].symbol, args.items[2].number, order, env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_solve(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (solve expr var) - solves expr = 0 for var
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    return symbolic.solve(args.items[0], args.items[1].symbol, env.allocator) catch return BuiltinError.OutOfMemory;
}

// ============================================================================
// Complex Number Functions
// ============================================================================

pub fn builtin_complex(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (complex real imag) - creates a complex number
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .number) return BuiltinError.InvalidArgument;

    return symbolic.makeComplex(env.allocator, args.items[0].number, args.items[1].number) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_real(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (real z) - gets the real part of z
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (symbolic.getReal(args.items[0])) |r| {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = r };
        return result;
    }
    return BuiltinError.InvalidArgument;
}

pub fn builtin_imag(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (imag z) - gets the imaginary part of z
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (symbolic.getImag(args.items[0])) |i| {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = i };
        return result;
    }
    return BuiltinError.InvalidArgument;
}

pub fn builtin_conj(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (conj z) - complex conjugate
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const real = symbolic.getReal(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const imag = symbolic.getImag(args.items[0]) orelse return BuiltinError.InvalidArgument;

    return symbolic.makeComplex(env.allocator, real, -imag) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_abs_complex(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (magnitude z) - complex magnitude |z|
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const real = symbolic.getReal(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const imag = symbolic.getImag(args.items[0]) orelse return BuiltinError.InvalidArgument;

    const magnitude = @sqrt(real * real + imag * imag);
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = magnitude };
    return result;
}

pub fn builtin_arg(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (arg z) - complex argument (angle)
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const real = symbolic.getReal(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const imag = symbolic.getImag(args.items[0]) orelse return BuiltinError.InvalidArgument;

    const angle = std.math.atan2(imag, real);
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = angle };
    return result;
}
