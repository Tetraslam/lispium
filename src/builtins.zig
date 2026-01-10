const std = @import("std");
const Expr = @import("parser.zig").Expr;
const environment = @import("environment.zig");
const Env = environment.Env;
const Assumption = environment.Assumption;
const symbolic = @import("symbolic.zig");
const eval = @import("evaluator.zig").eval;

pub const BuiltinError = error{
    InvalidArgument,
    OutOfMemory,
    EvaluationError,
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

pub fn builtin_eq(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (= a b) - returns 1 if equal, 0 if not
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const equal = symbolic.exprEqual(args.items[0], args.items[1]);

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = if (equal) 1 else 0 };
    return result;
}

pub fn builtin_lt(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (< a b) - returns 1 if a < b, 0 otherwise (only for numbers)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number or args.items[1].* != .number) return BuiltinError.InvalidArgument;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = if (args.items[0].number < args.items[1].number) 1 else 0 };
    return result;
}

pub fn builtin_gt(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (> a b) - returns 1 if a > b, 0 otherwise (only for numbers)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number or args.items[1].* != .number) return BuiltinError.InvalidArgument;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = if (args.items[0].number > args.items[1].number) 1 else 0 };
    return result;
}

// ============================================================================
// Boolean Algebra Functions
// ============================================================================

pub fn builtin_and(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (and a b ...) - logical AND. 0 is false, non-zero is true
    if (args.items.len < 2) return BuiltinError.InvalidArgument;

    var all_numbers = true;
    for (args.items) |arg| {
        if (arg.* != .number) {
            all_numbers = false;
            break;
        }
    }

    if (all_numbers) {
        // Evaluate: false if any is 0, true (1) otherwise
        for (args.items) |arg| {
            if (arg.number == 0) {
                const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                result.* = .{ .number = 0 };
                return result;
            }
        }
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 1 };
        return result;
    }

    // Symbolic: return (and ...) expression
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "and" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_or(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (or a b ...) - logical OR
    if (args.items.len < 2) return BuiltinError.InvalidArgument;

    var all_numbers = true;
    for (args.items) |arg| {
        if (arg.* != .number) {
            all_numbers = false;
            break;
        }
    }

    if (all_numbers) {
        // Evaluate: true if any is non-zero
        for (args.items) |arg| {
            if (arg.number != 0) {
                const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                result.* = .{ .number = 1 };
                return result;
            }
        }
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 0 };
        return result;
    }

    // Symbolic: return (or ...) expression
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "or" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_not(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (not a) - logical NOT
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = if (args.items[0].number == 0) 1 else 0 };
        return result;
    }

    // Symbolic: return (not ...) expression
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "not" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_xor(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (xor a b) - logical XOR
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number and args.items[1].* == .number) {
        const a = args.items[0].number != 0;
        const b = args.items[1].number != 0;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = if (a != b) 1 else 0 };
        return result;
    }

    // Symbolic
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "xor" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_implies(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (implies a b) - logical implication: a → b ≡ ¬a ∨ b
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number and args.items[1].* == .number) {
        const a = args.items[0].number != 0;
        const b = args.items[1].number != 0;
        // a → b is true when a is false OR b is true
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = if (!a or b) 1 else 0 };
        return result;
    }

    // Symbolic
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "implies" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

// ============================================================================
// Modular Arithmetic Functions
// ============================================================================

pub fn builtin_mod(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (mod a b) - returns a mod b
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number or args.items[1].* != .number) return BuiltinError.InvalidArgument;

    const a = args.items[0].number;
    const b = args.items[1].number;
    if (b == 0) return BuiltinError.InvalidArgument;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = @mod(a, b) };
    return result;
}

pub fn builtin_gcd(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gcd a b) - returns greatest common divisor
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number or args.items[1].* != .number) return BuiltinError.InvalidArgument;

    var a = @abs(args.items[0].number);
    var b = @abs(args.items[1].number);

    // Only works for integers
    if (a != @floor(a) or b != @floor(b)) return BuiltinError.InvalidArgument;

    // Euclidean algorithm
    while (b > 0.5) {
        const temp = b;
        b = @mod(a, b);
        a = temp;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = a };
    return result;
}

pub fn builtin_lcm(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (lcm a b) - returns least common multiple
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number or args.items[1].* != .number) return BuiltinError.InvalidArgument;

    const a = @abs(args.items[0].number);
    const b = @abs(args.items[1].number);

    // Only works for integers
    if (a != @floor(a) or b != @floor(b)) return BuiltinError.InvalidArgument;

    if (a == 0 or b == 0) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 0 };
        return result;
    }

    // Compute GCD first
    var x = a;
    var y = b;
    while (y > 0.5) {
        const temp = y;
        y = @mod(x, y);
        x = temp;
    }
    const gcd_val = x;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = (a / gcd_val) * b };
    return result;
}

pub fn builtin_modpow(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (modpow base exp mod) - returns (base^exp) mod m efficiently
    if (args.items.len != 3) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number or args.items[1].* != .number or args.items[2].* != .number) {
        return BuiltinError.InvalidArgument;
    }

    const base_f = args.items[0].number;
    const exp_f = args.items[1].number;
    const mod_f = args.items[2].number;

    // Must be non-negative integers
    if (base_f < 0 or exp_f < 0 or mod_f <= 0) return BuiltinError.InvalidArgument;
    if (base_f != @floor(base_f) or exp_f != @floor(exp_f) or mod_f != @floor(mod_f)) {
        return BuiltinError.InvalidArgument;
    }

    var base: u64 = @intFromFloat(base_f);
    var exp: u64 = @intFromFloat(exp_f);
    const mod: u64 = @intFromFloat(mod_f);

    // Fast modular exponentiation
    var result_val: u64 = 1;
    base = base % mod;
    while (exp > 0) {
        if (exp % 2 == 1) {
            result_val = (result_val * base) % mod;
        }
        exp = exp / 2;
        base = (base * base) % mod;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = @floatFromInt(result_val) };
    return result;
}

// ============================================================================
// Combinatorics Functions
// ============================================================================

pub fn builtin_factorial(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (factorial n) or (! n) - returns n!
    if (args.items.len != 1) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number) return BuiltinError.InvalidArgument;

    const n_f = args.items[0].number;
    if (n_f < 0 or n_f != @floor(n_f)) return BuiltinError.InvalidArgument;
    if (n_f > 170) return BuiltinError.InvalidArgument; // Overflow protection

    const n: u64 = @intFromFloat(n_f);
    var result_val: f64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        result_val *= @floatFromInt(i);
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = result_val };
    return result;
}

pub fn builtin_binomial(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (binomial n k) or (choose n k) - returns n choose k = n! / (k! * (n-k)!)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number or args.items[1].* != .number) return BuiltinError.InvalidArgument;

    const n_f = args.items[0].number;
    const k_f = args.items[1].number;

    if (n_f < 0 or k_f < 0 or n_f != @floor(n_f) or k_f != @floor(k_f)) {
        return BuiltinError.InvalidArgument;
    }
    if (k_f > n_f) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 0 };
        return result;
    }

    const n: u64 = @intFromFloat(n_f);
    var k: u64 = @intFromFloat(k_f);

    // Use symmetry: C(n,k) = C(n,n-k) to minimize iterations
    if (k > n - k) {
        k = n - k;
    }

    // Compute using multiplicative formula: C(n,k) = n*(n-1)*...*(n-k+1) / k!
    var result_val: f64 = 1;
    var i: u64 = 0;
    while (i < k) : (i += 1) {
        result_val = result_val * @as(f64, @floatFromInt(n - i)) / @as(f64, @floatFromInt(i + 1));
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = @round(result_val) }; // Round to handle floating point errors
    return result;
}

pub fn builtin_permutations(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (permutations n k) - returns P(n,k) = n! / (n-k)! = n * (n-1) * ... * (n-k+1)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number or args.items[1].* != .number) return BuiltinError.InvalidArgument;

    const n_f = args.items[0].number;
    const k_f = args.items[1].number;

    if (n_f < 0 or k_f < 0 or n_f != @floor(n_f) or k_f != @floor(k_f)) {
        return BuiltinError.InvalidArgument;
    }
    if (k_f > n_f) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 0 };
        return result;
    }

    const n: u64 = @intFromFloat(n_f);
    const k: u64 = @intFromFloat(k_f);

    var result_val: f64 = 1;
    var i: u64 = 0;
    while (i < k) : (i += 1) {
        result_val *= @floatFromInt(n - i);
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = result_val };
    return result;
}

pub fn builtin_combinations(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (combinations n k) - alias for binomial
    return builtin_binomial(args, env);
}

// ============================================================================
// Number Theory Functions
// ============================================================================

pub fn builtin_prime(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (prime? n) - returns 1 if n is prime, 0 otherwise
    if (args.items.len != 1) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number) return BuiltinError.InvalidArgument;

    const n_f = args.items[0].number;
    if (n_f < 0 or n_f != @floor(n_f)) return BuiltinError.InvalidArgument;

    const n: u64 = @intFromFloat(n_f);
    const is_prime = isPrime(n);

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = if (is_prime) 1 else 0 };
    return result;
}

fn isPrime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    if (n == 3) return true;
    if (n % 3 == 0) return false;

    // Check 6k ± 1 up to sqrt(n)
    var i: u64 = 5;
    while (i * i <= n) {
        if (n % i == 0 or n % (i + 2) == 0) return false;
        i += 6;
    }
    return true;
}

pub fn builtin_factorize(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (factorize n) - returns prime factorization as list of (prime exponent) pairs
    if (args.items.len != 1) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number) return BuiltinError.InvalidArgument;

    const n_f = args.items[0].number;
    if (n_f < 2 or n_f != @floor(n_f)) return BuiltinError.InvalidArgument;

    var n: u64 = @intFromFloat(n_f);
    var result_list: std.ArrayList(*Expr) = .empty;

    // Factor out 2s
    var count: u64 = 0;
    while (n % 2 == 0) {
        count += 1;
        n /= 2;
    }
    if (count > 0) {
        var pair: std.ArrayList(*Expr) = .empty;
        const two = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        two.* = .{ .number = 2 };
        pair.append(env.allocator, two) catch return BuiltinError.OutOfMemory;
        const exp = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        exp.* = .{ .number = @floatFromInt(count) };
        pair.append(env.allocator, exp) catch return BuiltinError.OutOfMemory;
        const pair_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        pair_expr.* = .{ .list = pair };
        result_list.append(env.allocator, pair_expr) catch return BuiltinError.OutOfMemory;
    }

    // Factor odd numbers
    var i: u64 = 3;
    while (i * i <= n) {
        count = 0;
        while (n % i == 0) {
            count += 1;
            n /= i;
        }
        if (count > 0) {
            var pair: std.ArrayList(*Expr) = .empty;
            const prime = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            prime.* = .{ .number = @floatFromInt(i) };
            pair.append(env.allocator, prime) catch return BuiltinError.OutOfMemory;
            const exp = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            exp.* = .{ .number = @floatFromInt(count) };
            pair.append(env.allocator, exp) catch return BuiltinError.OutOfMemory;
            const pair_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            pair_expr.* = .{ .list = pair };
            result_list.append(env.allocator, pair_expr) catch return BuiltinError.OutOfMemory;
        }
        i += 2;
    }

    // If n > 1, then it's a prime factor
    if (n > 1) {
        var pair: std.ArrayList(*Expr) = .empty;
        const prime = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        prime.* = .{ .number = @floatFromInt(n) };
        pair.append(env.allocator, prime) catch return BuiltinError.OutOfMemory;
        const one = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        one.* = .{ .number = 1 };
        pair.append(env.allocator, one) catch return BuiltinError.OutOfMemory;
        const pair_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        pair_expr.* = .{ .list = pair };
        result_list.append(env.allocator, pair_expr) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_extgcd(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (extgcd a b) - returns (gcd x y) where ax + by = gcd(a,b)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number or args.items[1].* != .number) return BuiltinError.InvalidArgument;

    const a_f = args.items[0].number;
    const b_f = args.items[1].number;

    if (a_f != @floor(a_f) or b_f != @floor(b_f)) return BuiltinError.InvalidArgument;

    const a: i64 = @intFromFloat(a_f);
    const b: i64 = @intFromFloat(b_f);

    // Extended Euclidean algorithm
    var old_r: i64 = a;
    var r: i64 = b;
    var old_s: i64 = 1;
    var s: i64 = 0;
    var old_t: i64 = 0;
    var t: i64 = 1;

    while (r != 0) {
        const quotient = @divTrunc(old_r, r);
        const temp_r = r;
        r = old_r - quotient * r;
        old_r = temp_r;

        const temp_s = s;
        s = old_s - quotient * s;
        old_s = temp_s;

        const temp_t = t;
        t = old_t - quotient * t;
        old_t = temp_t;
    }

    // Result: gcd = old_r, x = old_s, y = old_t
    // Verify: a * old_s + b * old_t = old_r (gcd)
    var result_list: std.ArrayList(*Expr) = .empty;

    const gcd_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    gcd_expr.* = .{ .number = @floatFromInt(@as(i64, @intCast(@abs(old_r)))) };
    result_list.append(env.allocator, gcd_expr) catch return BuiltinError.OutOfMemory;

    const x_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    x_expr.* = .{ .number = @floatFromInt(old_s) };
    result_list.append(env.allocator, x_expr) catch return BuiltinError.OutOfMemory;

    const y_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    y_expr.* = .{ .number = @floatFromInt(old_t) };
    result_list.append(env.allocator, y_expr) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_totient(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (totient n) - Euler's totient function phi(n)
    // Returns count of integers 1..n coprime to n
    if (args.items.len != 1) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number) return BuiltinError.InvalidArgument;

    const n_f = args.items[0].number;
    if (n_f < 1 or n_f != @floor(n_f)) return BuiltinError.InvalidArgument;

    var n: u64 = @intFromFloat(n_f);
    var result_val: u64 = n;

    // phi(n) = n * product(1 - 1/p) for each prime p dividing n
    var p: u64 = 2;
    while (p * p <= n) {
        if (n % p == 0) {
            // Remove all factors of p
            while (n % p == 0) {
                n /= p;
            }
            // Multiply result by (1 - 1/p) = (p-1)/p
            result_val -= result_val / p;
        }
        p += 1;
    }
    // If n > 1, then it's a prime factor
    if (n > 1) {
        result_val -= result_val / n;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = @floatFromInt(result_val) };
    return result;
}

pub fn builtin_crt(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (crt remainders moduli) - Chinese Remainder Theorem
    // Given remainders (vector r1 r2 ...) and moduli (vector m1 m2 ...), find x such that
    // x ≡ r1 (mod m1), x ≡ r2 (mod m2), ...
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const remainders = args.items[0];
    const moduli = args.items[1];

    if (remainders.* != .list or moduli.* != .list) return BuiltinError.InvalidArgument;

    // Get the actual numeric items (skip "vector" symbol if present)
    const r_list = remainders.list.items;
    const m_list = moduli.list.items;

    // Check if first element is "vector" symbol and skip it
    var r_start: usize = 0;
    var m_start: usize = 0;
    if (r_list.len > 0 and r_list[0].* == .symbol and std.mem.eql(u8, r_list[0].symbol, "vector")) {
        r_start = 1;
    }
    if (m_list.len > 0 and m_list[0].* == .symbol and std.mem.eql(u8, m_list[0].symbol, "vector")) {
        m_start = 1;
    }

    const r_items = r_list[r_start..];
    const m_items = m_list[m_start..];

    if (r_items.len != m_items.len or r_items.len == 0) return BuiltinError.InvalidArgument;

    // Extract values
    var rs: std.ArrayListAligned(i64, null) = .empty;
    defer rs.deinit(env.allocator);
    var ms: std.ArrayListAligned(i64, null) = .empty;
    defer ms.deinit(env.allocator);

    for (r_items) |r| {
        if (r.* != .number or r.number != @floor(r.number)) return BuiltinError.InvalidArgument;
        rs.append(env.allocator, @intFromFloat(r.number)) catch return BuiltinError.OutOfMemory;
    }
    for (m_items) |m| {
        if (m.* != .number or m.number != @floor(m.number) or m.number <= 0) return BuiltinError.InvalidArgument;
        ms.append(env.allocator, @intFromFloat(m.number)) catch return BuiltinError.OutOfMemory;
    }

    // CRT algorithm
    var x: i64 = rs.items[0];
    var m_prod: i64 = ms.items[0];

    var i: usize = 1;
    while (i < rs.items.len) : (i += 1) {
        const r = rs.items[i];
        const m = ms.items[i];

        // Solve: x + m_prod * t ≡ r (mod m)
        // => m_prod * t ≡ r - x (mod m)
        // Use extended Euclidean algorithm to find inverse of m_prod mod m

        const g = extGcdI64(m_prod, m);
        const gcd_val = g.gcd;
        const inv = g.x; // m_prod * inv ≡ gcd (mod m)

        const diff = @mod(r - x, m);
        if (@mod(diff, gcd_val) != 0) {
            // No solution exists
            return BuiltinError.InvalidArgument;
        }

        const t = @mod(@divTrunc(diff, gcd_val) * inv, @divTrunc(m, gcd_val));
        x = x + m_prod * t;
        m_prod = @divTrunc(m_prod * m, gcd_val);
        x = @mod(x, m_prod);
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = @floatFromInt(x) };
    return result;
}

const ExtGcdResult = struct {
    gcd: i64,
    x: i64,
    y: i64,
};

fn extGcdI64(a: i64, b: i64) ExtGcdResult {
    var old_r: i64 = a;
    var r: i64 = b;
    var old_s: i64 = 1;
    var s: i64 = 0;
    var old_t: i64 = 0;
    var t: i64 = 1;

    while (r != 0) {
        const quotient = @divTrunc(old_r, r);
        const temp_r = r;
        r = old_r - quotient * r;
        old_r = temp_r;

        const temp_s = s;
        s = old_s - quotient * s;
        old_s = temp_s;

        const temp_t = t;
        t = old_t - quotient * t;
        old_t = temp_t;
    }

    return .{
        .gcd = if (old_r < 0) -old_r else old_r,
        .x = old_s,
        .y = old_t,
    };
}

// ============================================================================
// Polynomial Division
// ============================================================================

pub fn builtin_polydiv(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (polydiv dividend divisor var) - polynomial long division
    // Returns (quotient remainder) as a list
    // Polynomials are coefficient lists from highest to lowest degree
    // e.g., (polydiv (coeffs 1 -3 2) (coeffs 1 -2) x) for (x²-3x+2)/(x-2)
    if (args.items.len != 3) return BuiltinError.InvalidArgument;

    const dividend = args.items[0];
    const divisor = args.items[1];
    // args.items[2] is the variable (for output formatting), but we work with coefficients

    // Both must be coefficient lists: (coeffs c_n c_{n-1} ... c_0)
    if (!isCoeffList(dividend) or !isCoeffList(divisor)) return BuiltinError.InvalidArgument;

    const div_coeffs = getCoeffs(dividend) orelse return BuiltinError.InvalidArgument;
    const divis_coeffs = getCoeffs(divisor) orelse return BuiltinError.InvalidArgument;

    if (divis_coeffs.len == 0) return BuiltinError.InvalidArgument;

    // Check leading coefficient of divisor is non-zero
    if (divis_coeffs[0].* != .number or divis_coeffs[0].number == 0) {
        return BuiltinError.InvalidArgument;
    }

    // Allocate working array (copy of dividend coefficients)
    var remainder: std.ArrayListAligned(f64, null) = .empty;
    defer remainder.deinit(env.allocator);
    for (div_coeffs) |c| {
        if (c.* != .number) return BuiltinError.InvalidArgument;
        remainder.append(env.allocator, c.number) catch return BuiltinError.OutOfMemory;
    }

    // Get divisor as f64 array
    var divisor_arr: std.ArrayListAligned(f64, null) = .empty;
    defer divisor_arr.deinit(env.allocator);
    for (divis_coeffs) |c| {
        if (c.* != .number) return BuiltinError.InvalidArgument;
        divisor_arr.append(env.allocator, c.number) catch return BuiltinError.OutOfMemory;
    }

    const div_len = divisor_arr.items.len;

    // Quotient coefficients
    var quotient: std.ArrayListAligned(f64, null) = .empty;
    defer quotient.deinit(env.allocator);

    // Polynomial long division algorithm
    while (remainder.items.len >= div_len) {
        const lead_coeff = remainder.items[0] / divisor_arr.items[0];
        quotient.append(env.allocator, lead_coeff) catch return BuiltinError.OutOfMemory;

        // Subtract lead_coeff * divisor from remainder
        for (divisor_arr.items, 0..) |d, i| {
            remainder.items[i] -= lead_coeff * d;
        }

        // Remove leading zero
        _ = remainder.orderedRemove(0);
    }

    // Strip leading zeros from remainder (except keep at least one element)
    while (remainder.items.len > 1 and remainder.items[0] == 0) {
        _ = remainder.orderedRemove(0);
    }

    // Build result: (list (coeffs q...) (coeffs r...))
    var result_list: std.ArrayList(*Expr) = .empty;

    // Build quotient (coeffs ...)
    var q_list: std.ArrayList(*Expr) = .empty;
    const q_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    q_sym.* = .{ .symbol = "coeffs" };
    q_list.append(env.allocator, q_sym) catch return BuiltinError.OutOfMemory;
    if (quotient.items.len == 0) {
        const zero = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        zero.* = .{ .number = 0 };
        q_list.append(env.allocator, zero) catch return BuiltinError.OutOfMemory;
    } else {
        for (quotient.items) |q| {
            const qe = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            qe.* = .{ .number = q };
            q_list.append(env.allocator, qe) catch return BuiltinError.OutOfMemory;
        }
    }
    const q_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    q_expr.* = .{ .list = q_list };
    result_list.append(env.allocator, q_expr) catch return BuiltinError.OutOfMemory;

    // Build remainder (coeffs ...)
    var r_list: std.ArrayList(*Expr) = .empty;
    const r_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    r_sym.* = .{ .symbol = "coeffs" };
    r_list.append(env.allocator, r_sym) catch return BuiltinError.OutOfMemory;
    if (remainder.items.len == 0) {
        const zero = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        zero.* = .{ .number = 0 };
        r_list.append(env.allocator, zero) catch return BuiltinError.OutOfMemory;
    } else {
        for (remainder.items) |r| {
            const re = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            re.* = .{ .number = r };
            r_list.append(env.allocator, re) catch return BuiltinError.OutOfMemory;
        }
    }
    const r_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    r_expr.* = .{ .list = r_list };
    result_list.append(env.allocator, r_expr) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

fn isCoeffList(expr: *const Expr) bool {
    if (expr.* != .list) return false;
    if (expr.list.items.len < 2) return false;
    if (expr.list.items[0].* != .symbol) return false;
    return std.mem.eql(u8, expr.list.items[0].symbol, "coeffs");
}

fn getCoeffs(expr: *const Expr) ?[]*Expr {
    if (!isCoeffList(expr)) return null;
    return expr.list.items[1..];
}

pub fn builtin_coeffs(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (coeffs c_n c_{n-1} ... c_0) - creates a coefficient list
    var result_list: std.ArrayList(*Expr) = .empty;
    const coeffs_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    coeffs_sym.* = .{ .symbol = "coeffs" };
    result_list.append(env.allocator, coeffs_sym) catch return BuiltinError.OutOfMemory;

    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_polygcd(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (polygcd p1 p2) - polynomial GCD using Euclidean algorithm
    // Both p1 and p2 are coefficient lists (coeffs c_n ... c_0)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (!isCoeffList(args.items[0]) or !isCoeffList(args.items[1])) {
        return BuiltinError.InvalidArgument;
    }

    const coeffs1 = getCoeffs(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const coeffs2 = getCoeffs(args.items[1]) orelse return BuiltinError.InvalidArgument;

    // Convert to f64 arrays
    var a: std.ArrayListAligned(f64, null) = .empty;
    defer a.deinit(env.allocator);
    for (coeffs1) |c| {
        if (c.* != .number) return BuiltinError.InvalidArgument;
        a.append(env.allocator, c.number) catch return BuiltinError.OutOfMemory;
    }

    var b: std.ArrayListAligned(f64, null) = .empty;
    defer b.deinit(env.allocator);
    for (coeffs2) |c| {
        if (c.* != .number) return BuiltinError.InvalidArgument;
        b.append(env.allocator, c.number) catch return BuiltinError.OutOfMemory;
    }

    // Strip leading zeros
    while (a.items.len > 1 and a.items[0] == 0) {
        _ = a.orderedRemove(0);
    }
    while (b.items.len > 1 and b.items[0] == 0) {
        _ = b.orderedRemove(0);
    }

    // Euclidean algorithm for polynomials
    while (b.items.len > 0 and !(b.items.len == 1 and b.items[0] == 0)) {
        // Compute a mod b (remainder of a / b)
        var r: std.ArrayListAligned(f64, null) = .empty;
        defer r.deinit(env.allocator);

        // Copy a to remainder
        for (a.items) |coeff| {
            r.append(env.allocator, coeff) catch return BuiltinError.OutOfMemory;
        }

        // Perform division to get remainder
        while (r.items.len >= b.items.len) {
            const lead_coeff = r.items[0] / b.items[0];
            for (b.items, 0..) |d, i| {
                r.items[i] -= lead_coeff * d;
            }
            _ = r.orderedRemove(0);
        }

        // Strip leading zeros from r
        while (r.items.len > 1 and r.items[0] == 0) {
            _ = r.orderedRemove(0);
        }

        // a = b, b = r
        a.clearRetainingCapacity();
        for (b.items) |coeff| {
            a.append(env.allocator, coeff) catch return BuiltinError.OutOfMemory;
        }

        b.clearRetainingCapacity();
        for (r.items) |coeff| {
            b.append(env.allocator, coeff) catch return BuiltinError.OutOfMemory;
        }
    }

    // Normalize GCD to be monic (leading coefficient = 1)
    if (a.items.len > 0 and a.items[0] != 0) {
        const lead = a.items[0];
        for (a.items) |*coeff| {
            coeff.* /= lead;
        }
    }

    // Build result (coeffs ...)
    var result_list: std.ArrayList(*Expr) = .empty;
    const coeffs_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    coeffs_sym.* = .{ .symbol = "coeffs" };
    result_list.append(env.allocator, coeffs_sym) catch return BuiltinError.OutOfMemory;

    if (a.items.len == 0) {
        const zero = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        zero.* = .{ .number = 0 };
        result_list.append(env.allocator, zero) catch return BuiltinError.OutOfMemory;
    } else {
        for (a.items) |coeff| {
            const ce = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            ce.* = .{ .number = coeff };
            result_list.append(env.allocator, ce) catch return BuiltinError.OutOfMemory;
        }
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_polylcm(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (polylcm p1 p2) - polynomial LCM = (p1 * p2) / gcd(p1, p2)
    // For simplicity, we'll just return the product for now (TODO: implement properly)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (!isCoeffList(args.items[0]) or !isCoeffList(args.items[1])) {
        return BuiltinError.InvalidArgument;
    }

    const coeffs1 = getCoeffs(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const coeffs2 = getCoeffs(args.items[1]) orelse return BuiltinError.InvalidArgument;

    // Convert to f64 arrays
    var a: std.ArrayListAligned(f64, null) = .empty;
    defer a.deinit(env.allocator);
    for (coeffs1) |c| {
        if (c.* != .number) return BuiltinError.InvalidArgument;
        a.append(env.allocator, c.number) catch return BuiltinError.OutOfMemory;
    }

    var b: std.ArrayListAligned(f64, null) = .empty;
    defer b.deinit(env.allocator);
    for (coeffs2) |c| {
        if (c.* != .number) return BuiltinError.InvalidArgument;
        b.append(env.allocator, c.number) catch return BuiltinError.OutOfMemory;
    }

    // Multiply polynomials: result has degree deg(a) + deg(b)
    const result_len = a.items.len + b.items.len - 1;
    var product: std.ArrayListAligned(f64, null) = .empty;
    defer product.deinit(env.allocator);

    // Initialize with zeros
    var i: usize = 0;
    while (i < result_len) : (i += 1) {
        product.append(env.allocator, 0) catch return BuiltinError.OutOfMemory;
    }

    // Convolve
    for (a.items, 0..) |ai, ia| {
        for (b.items, 0..) |bj, jb| {
            product.items[ia + jb] += ai * bj;
        }
    }

    // Now we need to divide by GCD
    // First compute GCD
    var gcd_a: std.ArrayListAligned(f64, null) = .empty;
    defer gcd_a.deinit(env.allocator);
    for (coeffs1) |c| {
        gcd_a.append(env.allocator, c.number) catch return BuiltinError.OutOfMemory;
    }

    var gcd_b: std.ArrayListAligned(f64, null) = .empty;
    defer gcd_b.deinit(env.allocator);
    for (coeffs2) |c| {
        gcd_b.append(env.allocator, c.number) catch return BuiltinError.OutOfMemory;
    }

    // Euclidean algorithm
    while (gcd_b.items.len > 0 and !(gcd_b.items.len == 1 and gcd_b.items[0] == 0)) {
        var r: std.ArrayListAligned(f64, null) = .empty;
        defer r.deinit(env.allocator);
        for (gcd_a.items) |coeff| {
            r.append(env.allocator, coeff) catch return BuiltinError.OutOfMemory;
        }
        while (r.items.len >= gcd_b.items.len) {
            const lead_coeff = r.items[0] / gcd_b.items[0];
            for (gcd_b.items, 0..) |d, idx| {
                r.items[idx] -= lead_coeff * d;
            }
            _ = r.orderedRemove(0);
        }
        while (r.items.len > 1 and r.items[0] == 0) {
            _ = r.orderedRemove(0);
        }
        gcd_a.clearRetainingCapacity();
        for (gcd_b.items) |coeff| {
            gcd_a.append(env.allocator, coeff) catch return BuiltinError.OutOfMemory;
        }
        gcd_b.clearRetainingCapacity();
        for (r.items) |coeff| {
            gcd_b.append(env.allocator, coeff) catch return BuiltinError.OutOfMemory;
        }
    }

    // Divide product by gcd_a
    var lcm_result: std.ArrayListAligned(f64, null) = .empty;
    defer lcm_result.deinit(env.allocator);
    for (product.items) |coeff| {
        lcm_result.append(env.allocator, coeff) catch return BuiltinError.OutOfMemory;
    }

    var quotient: std.ArrayListAligned(f64, null) = .empty;
    defer quotient.deinit(env.allocator);

    while (lcm_result.items.len >= gcd_a.items.len) {
        const lead_coeff = lcm_result.items[0] / gcd_a.items[0];
        quotient.append(env.allocator, lead_coeff) catch return BuiltinError.OutOfMemory;
        for (gcd_a.items, 0..) |d, idx| {
            lcm_result.items[idx] -= lead_coeff * d;
        }
        _ = lcm_result.orderedRemove(0);
    }

    // Build result
    var result_list: std.ArrayList(*Expr) = .empty;
    const coeffs_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    coeffs_sym.* = .{ .symbol = "coeffs" };
    result_list.append(env.allocator, coeffs_sym) catch return BuiltinError.OutOfMemory;

    if (quotient.items.len == 0) {
        const zero = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        zero.* = .{ .number = 0 };
        result_list.append(env.allocator, zero) catch return BuiltinError.OutOfMemory;
    } else {
        for (quotient.items) |coeff| {
            const ce = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            ce.* = .{ .number = coeff };
            result_list.append(env.allocator, ce) catch return BuiltinError.OutOfMemory;
        }
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

// ============================================================================
// Linear System Solver
// ============================================================================

pub fn builtin_linsolve(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (linsolve A b) - solve Ax = b using Gaussian elimination
    // A is a matrix, b is a vector
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const a_expr = args.items[0];
    const b_expr = args.items[1];

    if (!isMatrix(a_expr) or !isVector(b_expr)) return BuiltinError.InvalidArgument;

    const dims = getMatrixDims(a_expr) orelse return BuiltinError.InvalidArgument;
    if (dims.rows != dims.cols) return BuiltinError.InvalidArgument; // Must be square

    const b_elems = getVectorElems(b_expr) orelse return BuiltinError.InvalidArgument;
    if (b_elems.len != dims.rows) return BuiltinError.InvalidArgument;

    const n = dims.rows;
    const rows = getMatrixRows(a_expr) orelse return BuiltinError.InvalidArgument;

    // Build augmented matrix [A|b] as f64 array
    var aug: std.ArrayListAligned(f64, null) = .empty;
    defer aug.deinit(env.allocator);

    for (rows, 0..) |row, i| {
        for (row.list.items) |elem| {
            if (elem.* != .number) return BuiltinError.InvalidArgument;
            aug.append(env.allocator, elem.number) catch return BuiltinError.OutOfMemory;
        }
        // Append b[i]
        if (b_elems[i].* != .number) return BuiltinError.InvalidArgument;
        aug.append(env.allocator, b_elems[i].number) catch return BuiltinError.OutOfMemory;
    }

    const cols = n + 1;

    // Gaussian elimination with partial pivoting
    var pivot_row: usize = 0;
    while (pivot_row < n) : (pivot_row += 1) {
        // Find max pivot
        var max_row = pivot_row;
        var max_val = @abs(aug.items[pivot_row * cols + pivot_row]);
        var row_i = pivot_row + 1;
        while (row_i < n) : (row_i += 1) {
            const val = @abs(aug.items[row_i * cols + pivot_row]);
            if (val > max_val) {
                max_val = val;
                max_row = row_i;
            }
        }

        // Swap rows if needed
        if (max_row != pivot_row) {
            var col: usize = 0;
            while (col < cols) : (col += 1) {
                const temp = aug.items[pivot_row * cols + col];
                aug.items[pivot_row * cols + col] = aug.items[max_row * cols + col];
                aug.items[max_row * cols + col] = temp;
            }
        }

        // Check for singular matrix
        if (@abs(aug.items[pivot_row * cols + pivot_row]) < 1e-10) {
            return BuiltinError.InvalidArgument; // Singular or near-singular
        }

        // Eliminate below
        var elim_row = pivot_row + 1;
        while (elim_row < n) : (elim_row += 1) {
            const factor = aug.items[elim_row * cols + pivot_row] / aug.items[pivot_row * cols + pivot_row];
            var col: usize = pivot_row;
            while (col < cols) : (col += 1) {
                aug.items[elim_row * cols + col] -= factor * aug.items[pivot_row * cols + col];
            }
        }
    }

    // Back substitution
    var solution: std.ArrayListAligned(f64, null) = .empty;
    defer solution.deinit(env.allocator);
    var idx: usize = 0;
    while (idx < n) : (idx += 1) {
        solution.append(env.allocator, 0) catch return BuiltinError.OutOfMemory;
    }

    var i_signed: isize = @intCast(n);
    i_signed -= 1;
    while (i_signed >= 0) : (i_signed -= 1) {
        const i: usize = @intCast(i_signed);
        var sum: f64 = aug.items[i * cols + n]; // b value
        var j = i + 1;
        while (j < n) : (j += 1) {
            sum -= aug.items[i * cols + j] * solution.items[j];
        }
        solution.items[i] = sum / aug.items[i * cols + i];
    }

    // Build result vector
    var result_list: std.ArrayList(*Expr) = .empty;
    const vec_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    vec_sym.* = .{ .symbol = "vector" };
    result_list.append(env.allocator, vec_sym) catch return BuiltinError.OutOfMemory;

    for (solution.items) |val| {
        const ve = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        ve.* = .{ .number = val };
        result_list.append(env.allocator, ve) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

// ============================================================================
// Assumptions System
// ============================================================================

pub fn builtin_assume(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (assume x positive) or (assume x integer) etc.
    // Returns the symbol that was assumed
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (args.items[0].* != .symbol) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    const sym_name = args.items[0].symbol;
    const prop_name = args.items[1].symbol;

    var assumption = Assumption{};

    if (std.mem.eql(u8, prop_name, "positive")) {
        assumption.positive = true;
        assumption.real = true;
    } else if (std.mem.eql(u8, prop_name, "negative")) {
        assumption.negative = true;
        assumption.real = true;
    } else if (std.mem.eql(u8, prop_name, "nonzero")) {
        assumption.nonzero = true;
    } else if (std.mem.eql(u8, prop_name, "integer")) {
        assumption.integer = true;
        assumption.real = true;
    } else if (std.mem.eql(u8, prop_name, "real")) {
        assumption.real = true;
    } else if (std.mem.eql(u8, prop_name, "even")) {
        assumption.even = true;
        assumption.integer = true;
        assumption.real = true;
    } else if (std.mem.eql(u8, prop_name, "odd")) {
        assumption.odd = true;
        assumption.integer = true;
        assumption.real = true;
    } else {
        return BuiltinError.InvalidArgument;
    }

    env.assume(sym_name, assumption) catch return BuiltinError.OutOfMemory;

    // Return the symbol
    return symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_is(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (is? x positive) - returns 1 if x is assumed positive, 0 otherwise
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (args.items[0].* != .symbol) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    const sym_name = args.items[0].symbol;
    const prop_name = args.items[1].symbol;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;

    if (env.getAssumption(sym_name)) |a| {
        var matches = false;
        if (std.mem.eql(u8, prop_name, "positive")) {
            matches = a.positive;
        } else if (std.mem.eql(u8, prop_name, "negative")) {
            matches = a.negative;
        } else if (std.mem.eql(u8, prop_name, "nonzero")) {
            matches = a.nonzero or a.positive or a.negative;
        } else if (std.mem.eql(u8, prop_name, "integer")) {
            matches = a.integer;
        } else if (std.mem.eql(u8, prop_name, "real")) {
            matches = a.real;
        } else if (std.mem.eql(u8, prop_name, "even")) {
            matches = a.even;
        } else if (std.mem.eql(u8, prop_name, "odd")) {
            matches = a.odd;
        }
        result.* = .{ .number = if (matches) 1 else 0 };
    } else {
        result.* = .{ .number = 0 };
    }

    return result;
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
    // (diff expr var) - first derivative
    // (diff expr var n) - nth derivative
    if (args.items.len != 2 and args.items.len != 3) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    var order: usize = 1;
    if (args.items.len == 3) {
        if (args.items[2].* != .number) return BuiltinError.InvalidArgument;
        const n = args.items[2].number;
        if (n < 0 or n != @floor(n) or n > 10) return BuiltinError.InvalidArgument;
        order = @intFromFloat(n);
    }

    if (order == 0) {
        return symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    }

    // Apply diff repeatedly
    var current = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    for (0..order) |_| {
        const next = symbolic.diff(current, args.items[1].symbol, env.allocator) catch {
            current.deinit(env.allocator);
            env.allocator.destroy(current);
            return BuiltinError.OutOfMemory;
        };
        current.deinit(env.allocator);
        env.allocator.destroy(current);
        current = next;
    }
    return current;
}

pub fn builtin_integrate(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (integrate expr var) - indefinite integral
    // (integrate expr var a b) - definite integral from a to b
    if (args.items.len != 2 and args.items.len != 4) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    const var_name = args.items[1].symbol;

    // Compute indefinite integral (antiderivative)
    const antiderivative = symbolic.integrate(args.items[0], var_name, env.allocator) catch return BuiltinError.OutOfMemory;

    if (args.items.len == 2) {
        // Indefinite integral - return antiderivative
        return antiderivative;
    }

    // Definite integral: substitute upper and lower bounds, then subtract
    // F(b) - F(a)
    const a = args.items[2];
    const b = args.items[3];

    // F(b) - substitute var with b
    const f_b = symbolic.substitute(antiderivative, var_name, b, env.allocator) catch {
        antiderivative.deinit(env.allocator);
        env.allocator.destroy(antiderivative);
        return BuiltinError.OutOfMemory;
    };
    const f_b_simplified = symbolic.simplify(f_b, env.allocator) catch {
        f_b.deinit(env.allocator);
        env.allocator.destroy(f_b);
        antiderivative.deinit(env.allocator);
        env.allocator.destroy(antiderivative);
        return BuiltinError.OutOfMemory;
    };
    f_b.deinit(env.allocator);
    env.allocator.destroy(f_b);

    // F(a) - substitute var with a
    const f_a = symbolic.substitute(antiderivative, var_name, a, env.allocator) catch {
        f_b_simplified.deinit(env.allocator);
        env.allocator.destroy(f_b_simplified);
        antiderivative.deinit(env.allocator);
        env.allocator.destroy(antiderivative);
        return BuiltinError.OutOfMemory;
    };
    const f_a_simplified = symbolic.simplify(f_a, env.allocator) catch {
        f_a.deinit(env.allocator);
        env.allocator.destroy(f_a);
        f_b_simplified.deinit(env.allocator);
        env.allocator.destroy(f_b_simplified);
        antiderivative.deinit(env.allocator);
        env.allocator.destroy(antiderivative);
        return BuiltinError.OutOfMemory;
    };
    f_a.deinit(env.allocator);
    env.allocator.destroy(f_a);

    // Free antiderivative
    antiderivative.deinit(env.allocator);
    env.allocator.destroy(antiderivative);

    // F(b) - F(a)
    const diff = symbolic.makeBinOp(env.allocator, "-", f_b_simplified, f_a_simplified) catch return BuiltinError.OutOfMemory;
    const result = symbolic.simplify(diff, env.allocator) catch {
        diff.deinit(env.allocator);
        env.allocator.destroy(diff);
        return BuiltinError.OutOfMemory;
    };
    diff.deinit(env.allocator);
    env.allocator.destroy(diff);

    return result;
}

// ============================================================================
// Vector Calculus Functions
// ============================================================================

pub fn builtin_gradient(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gradient f (vector x y z)) - computes gradient of scalar function f
    // Returns (vector df/dx df/dy df/dz)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const f = args.items[0];
    const vars_arg = args.items[1];

    if (vars_arg.* != .list) return BuiltinError.InvalidArgument;

    const vars_list = vars_arg.list.items;
    var var_start: usize = 0;
    if (vars_list.len > 0 and vars_list[0].* == .symbol and std.mem.eql(u8, vars_list[0].symbol, "vector")) {
        var_start = 1;
    }
    const vars = vars_list[var_start..];

    if (vars.len == 0) return BuiltinError.InvalidArgument;

    // Build result vector
    var result_list: std.ArrayList(*Expr) = .empty;
    const vec_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    vec_sym.* = .{ .symbol = "vector" };
    result_list.append(env.allocator, vec_sym) catch return BuiltinError.OutOfMemory;

    for (vars) |v| {
        if (v.* != .symbol) return BuiltinError.InvalidArgument;
        const partial = symbolic.diff(f, v.symbol, env.allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(env.allocator, partial) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_divergence(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (divergence F (vector x y z)) - computes divergence of vector field F = (Fx, Fy, Fz)
    // Returns dFx/dx + dFy/dy + dFz/dz
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const F_arg = args.items[0];
    const vars_arg = args.items[1];

    if (F_arg.* != .list or vars_arg.* != .list) return BuiltinError.InvalidArgument;

    const F_list = F_arg.list.items;
    const vars_list = vars_arg.list.items;

    // Skip "vector" symbol if present
    var F_start: usize = 0;
    var var_start: usize = 0;
    if (F_list.len > 0 and F_list[0].* == .symbol and std.mem.eql(u8, F_list[0].symbol, "vector")) {
        F_start = 1;
    }
    if (vars_list.len > 0 and vars_list[0].* == .symbol and std.mem.eql(u8, vars_list[0].symbol, "vector")) {
        var_start = 1;
    }

    const F = F_list[F_start..];
    const vars = vars_list[var_start..];

    if (F.len != vars.len or F.len == 0) return BuiltinError.InvalidArgument;

    // Compute sum of partial derivatives: dF_i/dx_i
    var terms: std.ArrayList(*Expr) = .empty;
    defer {
        for (terms.items) |item| {
            item.deinit(env.allocator);
            env.allocator.destroy(item);
        }
        terms.deinit(env.allocator);
    }

    for (F, vars) |Fi, vi| {
        if (vi.* != .symbol) return BuiltinError.InvalidArgument;
        const partial = symbolic.diff(Fi, vi.symbol, env.allocator) catch return BuiltinError.OutOfMemory;
        terms.append(env.allocator, partial) catch return BuiltinError.OutOfMemory;
    }

    // Build sum expression
    if (terms.items.len == 1) {
        const result = symbolic.copyExpr(terms.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
        return result;
    }

    var sum_list: std.ArrayList(*Expr) = .empty;
    const plus_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plus_sym.* = .{ .symbol = "+" };
    sum_list.append(env.allocator, plus_sym) catch return BuiltinError.OutOfMemory;

    for (terms.items) |term| {
        const copy = symbolic.copyExpr(term, env.allocator) catch return BuiltinError.OutOfMemory;
        sum_list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }

    const sum_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    sum_expr.* = .{ .list = sum_list };

    const result = symbolic.simplify(sum_expr, env.allocator) catch {
        sum_expr.deinit(env.allocator);
        env.allocator.destroy(sum_expr);
        return BuiltinError.OutOfMemory;
    };
    sum_expr.deinit(env.allocator);
    env.allocator.destroy(sum_expr);

    return result;
}

pub fn builtin_curl(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (curl F (vector x y z)) - computes curl of 3D vector field F = (Fx, Fy, Fz)
    // Returns (dFz/dy - dFy/dz, dFx/dz - dFz/dx, dFy/dx - dFx/dy)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const F_arg = args.items[0];
    const vars_arg = args.items[1];

    if (F_arg.* != .list or vars_arg.* != .list) return BuiltinError.InvalidArgument;

    const F_list = F_arg.list.items;
    const vars_list = vars_arg.list.items;

    // Skip "vector" symbol if present
    var F_start: usize = 0;
    var var_start: usize = 0;
    if (F_list.len > 0 and F_list[0].* == .symbol and std.mem.eql(u8, F_list[0].symbol, "vector")) {
        F_start = 1;
    }
    if (vars_list.len > 0 and vars_list[0].* == .symbol and std.mem.eql(u8, vars_list[0].symbol, "vector")) {
        var_start = 1;
    }

    const F = F_list[F_start..];
    const vars = vars_list[var_start..];

    // Curl requires exactly 3 components
    if (F.len != 3 or vars.len != 3) return BuiltinError.InvalidArgument;

    for (vars) |v| {
        if (v.* != .symbol) return BuiltinError.InvalidArgument;
    }

    const Fx = F[0];
    const Fy = F[1];
    const Fz = F[2];
    const x = vars[0].symbol;
    const y = vars[1].symbol;
    const z = vars[2].symbol;

    // curl_x = dFz/dy - dFy/dz
    const dFz_dy = symbolic.diff(Fz, y, env.allocator) catch return BuiltinError.OutOfMemory;
    const dFy_dz = symbolic.diff(Fy, z, env.allocator) catch return BuiltinError.OutOfMemory;
    const curl_x = symbolic.makeBinOp(env.allocator, "-", dFz_dy, dFy_dz) catch return BuiltinError.OutOfMemory;
    const curl_x_simp = symbolic.simplify(curl_x, env.allocator) catch return BuiltinError.OutOfMemory;
    curl_x.deinit(env.allocator);
    env.allocator.destroy(curl_x);

    // curl_y = dFx/dz - dFz/dx
    const dFx_dz = symbolic.diff(Fx, z, env.allocator) catch return BuiltinError.OutOfMemory;
    const dFz_dx = symbolic.diff(Fz, x, env.allocator) catch return BuiltinError.OutOfMemory;
    const curl_y = symbolic.makeBinOp(env.allocator, "-", dFx_dz, dFz_dx) catch return BuiltinError.OutOfMemory;
    const curl_y_simp = symbolic.simplify(curl_y, env.allocator) catch return BuiltinError.OutOfMemory;
    curl_y.deinit(env.allocator);
    env.allocator.destroy(curl_y);

    // curl_z = dFy/dx - dFx/dy
    const dFy_dx = symbolic.diff(Fy, x, env.allocator) catch return BuiltinError.OutOfMemory;
    const dFx_dy = symbolic.diff(Fx, y, env.allocator) catch return BuiltinError.OutOfMemory;
    const curl_z = symbolic.makeBinOp(env.allocator, "-", dFy_dx, dFx_dy) catch return BuiltinError.OutOfMemory;
    const curl_z_simp = symbolic.simplify(curl_z, env.allocator) catch return BuiltinError.OutOfMemory;
    curl_z.deinit(env.allocator);
    env.allocator.destroy(curl_z);

    // Build result vector
    var result_list: std.ArrayList(*Expr) = .empty;
    const vec_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    vec_sym.* = .{ .symbol = "vector" };
    result_list.append(env.allocator, vec_sym) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, curl_x_simp) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, curl_y_simp) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, curl_z_simp) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_laplacian(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (laplacian f (vector x y z)) - computes Laplacian of scalar function f
    // Returns d²f/dx² + d²f/dy² + d²f/dz²
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const f = args.items[0];
    const vars_arg = args.items[1];

    if (vars_arg.* != .list) return BuiltinError.InvalidArgument;

    const vars_list = vars_arg.list.items;
    var var_start: usize = 0;
    if (vars_list.len > 0 and vars_list[0].* == .symbol and std.mem.eql(u8, vars_list[0].symbol, "vector")) {
        var_start = 1;
    }
    const vars = vars_list[var_start..];

    if (vars.len == 0) return BuiltinError.InvalidArgument;

    // Compute sum of second partial derivatives: d²f/dx_i²
    var terms: std.ArrayList(*Expr) = .empty;
    defer {
        for (terms.items) |item| {
            item.deinit(env.allocator);
            env.allocator.destroy(item);
        }
        terms.deinit(env.allocator);
    }

    for (vars) |v| {
        if (v.* != .symbol) return BuiltinError.InvalidArgument;
        // First derivative
        const first = symbolic.diff(f, v.symbol, env.allocator) catch return BuiltinError.OutOfMemory;
        defer {
            first.deinit(env.allocator);
            env.allocator.destroy(first);
        }
        // Second derivative
        const second = symbolic.diff(first, v.symbol, env.allocator) catch return BuiltinError.OutOfMemory;
        terms.append(env.allocator, second) catch return BuiltinError.OutOfMemory;
    }

    // Build sum expression
    if (terms.items.len == 1) {
        const result = symbolic.copyExpr(terms.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
        return result;
    }

    var sum_list: std.ArrayList(*Expr) = .empty;
    const plus_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plus_sym.* = .{ .symbol = "+" };
    sum_list.append(env.allocator, plus_sym) catch return BuiltinError.OutOfMemory;

    for (terms.items) |term| {
        const copy = symbolic.copyExpr(term, env.allocator) catch return BuiltinError.OutOfMemory;
        sum_list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }

    const sum_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    sum_expr.* = .{ .list = sum_list };

    const result = symbolic.simplify(sum_expr, env.allocator) catch {
        sum_expr.deinit(env.allocator);
        env.allocator.destroy(sum_expr);
        return BuiltinError.OutOfMemory;
    };
    sum_expr.deinit(env.allocator);
    env.allocator.destroy(sum_expr);

    return result;
}

pub fn builtin_expand(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;
    return symbolic.expand(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
}

// ============================================================================
// Statistics Functions
// ============================================================================

pub fn builtin_mean(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (mean a b c ...) or (mean (vector a b c)) - arithmetic mean
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    var values: std.ArrayListAligned(f64, null) = .empty;
    defer values.deinit(env.allocator);

    // Check if single argument is a vector
    if (args.items.len == 1 and args.items[0].* == .list) {
        const lst = args.items[0].list.items;
        var start: usize = 0;
        if (lst.len > 0 and lst[0].* == .symbol and std.mem.eql(u8, lst[0].symbol, "vector")) {
            start = 1;
        }
        for (lst[start..]) |item| {
            if (item.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, item.number) catch return BuiltinError.OutOfMemory;
        }
    } else {
        for (args.items) |arg| {
            if (arg.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, arg.number) catch return BuiltinError.OutOfMemory;
        }
    }

    if (values.items.len == 0) return BuiltinError.InvalidArgument;

    var sum: f64 = 0;
    for (values.items) |v| {
        sum += v;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = sum / @as(f64, @floatFromInt(values.items.len)) };
    return result;
}

pub fn builtin_variance(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (variance a b c ...) or (variance (vector a b c)) - population variance
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    var values: std.ArrayListAligned(f64, null) = .empty;
    defer values.deinit(env.allocator);

    // Check if single argument is a vector
    if (args.items.len == 1 and args.items[0].* == .list) {
        const lst = args.items[0].list.items;
        var start: usize = 0;
        if (lst.len > 0 and lst[0].* == .symbol and std.mem.eql(u8, lst[0].symbol, "vector")) {
            start = 1;
        }
        for (lst[start..]) |item| {
            if (item.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, item.number) catch return BuiltinError.OutOfMemory;
        }
    } else {
        for (args.items) |arg| {
            if (arg.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, arg.number) catch return BuiltinError.OutOfMemory;
        }
    }

    if (values.items.len == 0) return BuiltinError.InvalidArgument;

    // Compute mean
    var sum: f64 = 0;
    for (values.items) |v| {
        sum += v;
    }
    const mean = sum / @as(f64, @floatFromInt(values.items.len));

    // Compute variance: sum((x - mean)^2) / n
    var variance_sum: f64 = 0;
    for (values.items) |v| {
        const diff = v - mean;
        variance_sum += diff * diff;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = variance_sum / @as(f64, @floatFromInt(values.items.len)) };
    return result;
}

pub fn builtin_stddev(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (stddev a b c ...) - population standard deviation (sqrt of variance)
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    var values: std.ArrayListAligned(f64, null) = .empty;
    defer values.deinit(env.allocator);

    // Check if single argument is a vector
    if (args.items.len == 1 and args.items[0].* == .list) {
        const lst = args.items[0].list.items;
        var start: usize = 0;
        if (lst.len > 0 and lst[0].* == .symbol and std.mem.eql(u8, lst[0].symbol, "vector")) {
            start = 1;
        }
        for (lst[start..]) |item| {
            if (item.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, item.number) catch return BuiltinError.OutOfMemory;
        }
    } else {
        for (args.items) |arg| {
            if (arg.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, arg.number) catch return BuiltinError.OutOfMemory;
        }
    }

    if (values.items.len == 0) return BuiltinError.InvalidArgument;

    // Compute mean
    var sum: f64 = 0;
    for (values.items) |v| {
        sum += v;
    }
    const mean = sum / @as(f64, @floatFromInt(values.items.len));

    // Compute variance
    var variance_sum: f64 = 0;
    for (values.items) |v| {
        const diff = v - mean;
        variance_sum += diff * diff;
    }
    const variance = variance_sum / @as(f64, @floatFromInt(values.items.len));

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = @sqrt(variance) };
    return result;
}

pub fn builtin_median(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (median a b c ...) - median value
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    var values: std.ArrayListAligned(f64, null) = .empty;
    defer values.deinit(env.allocator);

    // Check if single argument is a vector
    if (args.items.len == 1 and args.items[0].* == .list) {
        const lst = args.items[0].list.items;
        var start: usize = 0;
        if (lst.len > 0 and lst[0].* == .symbol and std.mem.eql(u8, lst[0].symbol, "vector")) {
            start = 1;
        }
        for (lst[start..]) |item| {
            if (item.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, item.number) catch return BuiltinError.OutOfMemory;
        }
    } else {
        for (args.items) |arg| {
            if (arg.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, arg.number) catch return BuiltinError.OutOfMemory;
        }
    }

    if (values.items.len == 0) return BuiltinError.InvalidArgument;

    // Sort values
    std.mem.sort(f64, values.items, {}, std.sort.asc(f64));

    const n = values.items.len;
    const median = if (n % 2 == 1)
        values.items[n / 2]
    else
        (values.items[n / 2 - 1] + values.items[n / 2]) / 2.0;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = median };
    return result;
}

pub fn builtin_min(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (min a b c ...) - minimum value
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    var values: std.ArrayListAligned(f64, null) = .empty;
    defer values.deinit(env.allocator);

    // Check if single argument is a vector
    if (args.items.len == 1 and args.items[0].* == .list) {
        const lst = args.items[0].list.items;
        var start: usize = 0;
        if (lst.len > 0 and lst[0].* == .symbol and std.mem.eql(u8, lst[0].symbol, "vector")) {
            start = 1;
        }
        for (lst[start..]) |item| {
            if (item.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, item.number) catch return BuiltinError.OutOfMemory;
        }
    } else {
        for (args.items) |arg| {
            if (arg.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, arg.number) catch return BuiltinError.OutOfMemory;
        }
    }

    if (values.items.len == 0) return BuiltinError.InvalidArgument;

    var min_val = values.items[0];
    for (values.items[1..]) |v| {
        if (v < min_val) min_val = v;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = min_val };
    return result;
}

pub fn builtin_max(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (max a b c ...) - maximum value
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    var values: std.ArrayListAligned(f64, null) = .empty;
    defer values.deinit(env.allocator);

    // Check if single argument is a vector
    if (args.items.len == 1 and args.items[0].* == .list) {
        const lst = args.items[0].list.items;
        var start: usize = 0;
        if (lst.len > 0 and lst[0].* == .symbol and std.mem.eql(u8, lst[0].symbol, "vector")) {
            start = 1;
        }
        for (lst[start..]) |item| {
            if (item.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, item.number) catch return BuiltinError.OutOfMemory;
        }
    } else {
        for (args.items) |arg| {
            if (arg.* != .number) return BuiltinError.InvalidArgument;
            values.append(env.allocator, arg.number) catch return BuiltinError.OutOfMemory;
        }
    }

    if (values.items.len == 0) return BuiltinError.InvalidArgument;

    var max_val = values.items[0];
    for (values.items[1..]) |v| {
        if (v > max_val) max_val = v;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = max_val };
    return result;
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
// Inverse Trigonometric Functions
// ============================================================================

pub fn builtin_asin(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const val = args.items[0].number;
        if (val < -1 or val > 1) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.asin(val) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "asin" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_acos(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const val = args.items[0].number;
        if (val < -1 or val > 1) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.acos(val) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "acos" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_atan(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.atan(args.items[0].number) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "atan" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_atan2(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number and args.items[1].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.atan2(args.items[0].number, args.items[1].number) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "atan2" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

// ============================================================================
// Hyperbolic Functions
// ============================================================================

pub fn builtin_sinh(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.sinh(args.items[0].number) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "sinh" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_cosh(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.cosh(args.items[0].number) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "cosh" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_tanh(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.tanh(args.items[0].number) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "tanh" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_asinh(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.asinh(args.items[0].number) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "asinh" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_acosh(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const val = args.items[0].number;
        if (val < 1) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.acosh(val) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "acosh" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_atanh(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const val = args.items[0].number;
        if (val <= -1 or val >= 1) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = std.math.atanh(val) };
        return result;
    }

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "atanh" };
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

pub fn builtin_factor(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (factor expr var) - factors a polynomial expression
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    return symbolic.factor(args.items[0], args.items[1].symbol, env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_partial_fractions(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (partial-fractions expr var) - decomposes a rational function into partial fractions
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    return symbolic.partialFractions(args.items[0], args.items[1].symbol, env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_collect(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (collect expr var) - collects like terms with respect to a variable
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    return symbolic.collect(args.items[0], args.items[1].symbol, env.allocator) catch return BuiltinError.OutOfMemory;
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

pub fn builtin_limit(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (limit expr var point) - computes limit of expr as var -> point
    if (args.items.len != 3) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;
    if (args.items[2].* != .number) return BuiltinError.InvalidArgument;

    return symbolic.limit(args.items[0], args.items[1].symbol, args.items[2].number, env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_rule(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (rule pattern replacement) - defines a rewrite rule
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    // Copy the pattern and replacement
    const pattern = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    errdefer {
        pattern.deinit(env.allocator);
        env.allocator.destroy(pattern);
    }
    const replacement = symbolic.copyExpr(args.items[1], env.allocator) catch return BuiltinError.OutOfMemory;
    errdefer {
        replacement.deinit(env.allocator);
        env.allocator.destroy(replacement);
    }

    const Rule = @import("environment.zig").Rule;
    env.rules.append(env.allocator, Rule{ .pattern = pattern, .replacement = replacement }) catch return BuiltinError.OutOfMemory;

    // Return a confirmation symbol
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .symbol = "rule-added" };
    return result;
}

pub fn builtin_rewrite(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (rewrite expr) - applies all rewrite rules to expr until no rules match
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    var current = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;

    // Apply rules until fixpoint (with limit to prevent infinite loops)
    var iterations: usize = 0;
    const max_iterations: usize = 100;

    while (iterations < max_iterations) : (iterations += 1) {
        const rewritten = rewriteOnce(current, env) catch return BuiltinError.OutOfMemory;
        if (rewritten) |new_expr| {
            current.deinit(env.allocator);
            env.allocator.destroy(current);
            current = new_expr;
        } else {
            // No rule matched, we're done
            break;
        }
    }

    return current;
}

fn rewriteOnce(expr: *Expr, env: *Env) !?*Expr {
    // First try to match at the top level
    if (try symbolic.applyRules(expr, env.rules.items, env.allocator)) |result| {
        return result;
    }

    // Then recursively try subexpressions
    if (expr.* == .list) {
        for (expr.list.items, 0..) |item, i| {
            if (try rewriteOnce(item, env)) |new_item| {
                // Replace the item and return a copy of the whole expression
                var new_list: std.ArrayList(*Expr) = .empty;
                errdefer {
                    for (new_list.items) |it| {
                        it.deinit(env.allocator);
                        env.allocator.destroy(it);
                    }
                    new_list.deinit(env.allocator);
                }

                for (expr.list.items, 0..) |it, j| {
                    if (j == i) {
                        new_list.append(env.allocator, new_item) catch return error.OutOfMemory;
                    } else {
                        const copy = symbolic.copyExpr(it, env.allocator) catch return error.OutOfMemory;
                        new_list.append(env.allocator, copy) catch return error.OutOfMemory;
                    }
                }

                const result = env.allocator.create(Expr) catch return error.OutOfMemory;
                result.* = .{ .list = new_list };
                return result;
            }
        }
    }

    return null;
}

// ============================================================================
// Matrix Operations
// ============================================================================

/// Helper: check if an expression is a matrix (list of lists)
fn isMatrix(expr: *const Expr) bool {
    if (expr.* != .list) return false;
    if (expr.list.items.len == 0) return false;
    // First item should be the "matrix" symbol
    if (expr.list.items[0].* != .symbol) return false;
    if (!std.mem.eql(u8, expr.list.items[0].symbol, "matrix")) return false;
    if (expr.list.items.len < 2) return false;
    // Rest should be the rows
    for (expr.list.items[1..]) |row| {
        if (row.* != .list) return false;
    }
    return true;
}

/// Get matrix rows from a (matrix ...) expression
fn getMatrixRows(expr: *const Expr) ?[]*Expr {
    if (!isMatrix(expr)) return null;
    return expr.list.items[1..];
}

/// Get matrix dimensions (rows, cols)
fn getMatrixDims(expr: *const Expr) ?struct { rows: usize, cols: usize } {
    const rows_expr = getMatrixRows(expr) orelse return null;
    if (rows_expr.len == 0) return null;
    const first_row = rows_expr[0];
    if (first_row.* != .list) return null;
    return .{ .rows = rows_expr.len, .cols = first_row.list.items.len };
}

pub fn builtin_matrix(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (matrix row1 row2 ...) where each row is a list
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    // Verify all args are lists (rows)
    var cols: ?usize = null;
    for (args.items) |arg| {
        if (arg.* != .list) return BuiltinError.InvalidArgument;
        if (cols == null) {
            cols = arg.list.items.len;
        } else if (arg.list.items.len != cols.?) {
            return BuiltinError.InvalidArgument; // Non-rectangular matrix
        }
    }

    // Build (matrix row1 row2 ...)
    var result_list: std.ArrayList(*Expr) = .empty;
    const matrix_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    matrix_sym.* = .{ .symbol = "matrix" };
    result_list.append(env.allocator, matrix_sym) catch return BuiltinError.OutOfMemory;

    for (args.items) |arg| {
        const row_copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(env.allocator, row_copy) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_det(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (det M) - determinant of matrix M
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const m = args.items[0];
    if (!isMatrix(m)) return BuiltinError.InvalidArgument;

    const dims = getMatrixDims(m) orelse return BuiltinError.InvalidArgument;
    if (dims.rows != dims.cols) return BuiltinError.InvalidArgument; // Must be square

    const rows = getMatrixRows(m) orelse return BuiltinError.InvalidArgument;

    if (dims.rows == 1) {
        // 1x1: det = single element
        return symbolic.copyExpr(rows[0].list.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    } else if (dims.rows == 2) {
        // 2x2: det = ad - bc
        const a = rows[0].list.items[0];
        const b = rows[0].list.items[1];
        const c = rows[1].list.items[0];
        const d = rows[1].list.items[1];

        // ad
        const ad = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(a, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(d, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;

        // bc
        const bc = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(b, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(c, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;

        // ad - bc
        const det_expr = symbolic.makeBinOp(env.allocator, "-", ad, bc) catch return BuiltinError.OutOfMemory;

        // Simplify and free the temporary expression
        const result = symbolic.simplify(det_expr, env.allocator) catch return BuiltinError.OutOfMemory;
        det_expr.deinit(env.allocator);
        env.allocator.destroy(det_expr);
        return result;
    } else if (dims.rows == 3) {
        // 3x3: Sarrus rule or cofactor expansion
        // Use first row cofactor expansion
        const a = rows[0].list.items[0];
        const b = rows[0].list.items[1];
        const c = rows[0].list.items[2];
        const d = rows[1].list.items[0];
        const e = rows[1].list.items[1];
        const f = rows[1].list.items[2];
        const g = rows[2].list.items[0];
        const h = rows[2].list.items[1];
        const i = rows[2].list.items[2];

        // det = a(ei-fh) - b(di-fg) + c(dh-eg)
        // ei - fh
        const ei = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(e, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(i, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const fh = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(f, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(h, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const minor1 = symbolic.makeBinOp(env.allocator, "-", ei, fh) catch return BuiltinError.OutOfMemory;

        // di - fg
        const di = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(d, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(i, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const fg = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(f, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(g, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const minor2 = symbolic.makeBinOp(env.allocator, "-", di, fg) catch return BuiltinError.OutOfMemory;

        // dh - eg
        const dh = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(d, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(h, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const eg = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(e, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(g, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const minor3 = symbolic.makeBinOp(env.allocator, "-", dh, eg) catch return BuiltinError.OutOfMemory;

        // a*minor1
        const term1 = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(a, env.allocator) catch return BuiltinError.OutOfMemory, minor1) catch return BuiltinError.OutOfMemory;
        // b*minor2
        const term2 = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(b, env.allocator) catch return BuiltinError.OutOfMemory, minor2) catch return BuiltinError.OutOfMemory;
        // c*minor3
        const term3 = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(c, env.allocator) catch return BuiltinError.OutOfMemory, minor3) catch return BuiltinError.OutOfMemory;

        // term1 - term2 + term3
        const sub1 = symbolic.makeBinOp(env.allocator, "-", term1, term2) catch return BuiltinError.OutOfMemory;
        const det_expr = symbolic.makeBinOp(env.allocator, "+", sub1, term3) catch return BuiltinError.OutOfMemory;

        // Simplify and free temporary expression
        const result = symbolic.simplify(det_expr, env.allocator) catch return BuiltinError.OutOfMemory;
        det_expr.deinit(env.allocator);
        env.allocator.destroy(det_expr);
        return result;
    }

    // For larger matrices, return symbolic det
    return symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_transpose(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (transpose M) - transpose of matrix M
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const m = args.items[0];
    if (!isMatrix(m)) return BuiltinError.InvalidArgument;

    const dims = getMatrixDims(m) orelse return BuiltinError.InvalidArgument;
    const rows = getMatrixRows(m) orelse return BuiltinError.InvalidArgument;

    // Build transposed matrix
    var result_list: std.ArrayList(*Expr) = .empty;
    const matrix_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    matrix_sym.* = .{ .symbol = "matrix" };
    result_list.append(env.allocator, matrix_sym) catch return BuiltinError.OutOfMemory;

    var col: usize = 0;
    while (col < dims.cols) : (col += 1) {
        var new_row: std.ArrayList(*Expr) = .empty;
        for (rows) |row| {
            const elem_copy = symbolic.copyExpr(row.list.items[col], env.allocator) catch return BuiltinError.OutOfMemory;
            new_row.append(env.allocator, elem_copy) catch return BuiltinError.OutOfMemory;
        }
        const new_row_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        new_row_expr.* = .{ .list = new_row };
        result_list.append(env.allocator, new_row_expr) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_trace(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (trace M) - trace of matrix M (sum of diagonal)
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const m = args.items[0];
    if (!isMatrix(m)) return BuiltinError.InvalidArgument;

    const dims = getMatrixDims(m) orelse return BuiltinError.InvalidArgument;
    if (dims.rows != dims.cols) return BuiltinError.InvalidArgument; // Must be square

    const rows = getMatrixRows(m) orelse return BuiltinError.InvalidArgument;

    // Build sum of diagonal elements
    var sum: *Expr = symbolic.copyExpr(rows[0].list.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    var i: usize = 1;
    while (i < dims.rows) : (i += 1) {
        const diag_elem = symbolic.copyExpr(rows[i].list.items[i], env.allocator) catch return BuiltinError.OutOfMemory;
        const new_sum = symbolic.makeBinOp(env.allocator, "+", sum, diag_elem) catch return BuiltinError.OutOfMemory;
        // Note: sum ownership transferred to new_sum, no need to free separately
        sum = new_sum;
    }

    // Simplify and free temporary expression
    const result = symbolic.simplify(sum, env.allocator) catch return BuiltinError.OutOfMemory;
    sum.deinit(env.allocator);
    env.allocator.destroy(sum);
    return result;
}

pub fn builtin_eigenvalues(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (eigenvalues M) - eigenvalues of 2x2 matrix M
    // For [[a,b],[c,d]], eigenvalues are roots of λ² - (a+d)λ + (ad-bc) = 0
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const m = args.items[0];
    if (!isMatrix(m)) return BuiltinError.InvalidArgument;

    const dims = getMatrixDims(m) orelse return BuiltinError.InvalidArgument;
    if (dims.rows != 2 or dims.cols != 2) return BuiltinError.InvalidArgument;

    const rows = getMatrixRows(m) orelse return BuiltinError.InvalidArgument;
    const a = rows[0].list.items[0];
    const b = rows[0].list.items[1];
    const c = rows[1].list.items[0];
    const d = rows[1].list.items[1];

    // Check if all are numbers
    if (a.* != .number or b.* != .number or c.* != .number or d.* != .number) {
        return BuiltinError.InvalidArgument;
    }

    const av = a.number;
    const bv = b.number;
    const cv = c.number;
    const dv = d.number;

    // trace = a + d
    const trace = av + dv;
    // det = ad - bc
    const det = av * dv - bv * cv;

    // Eigenvalues from quadratic: λ² - trace*λ + det = 0
    // λ = (trace ± sqrt(trace² - 4*det)) / 2
    const disc = trace * trace - 4 * det;

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "eigenvalues" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;

    if (disc >= 0) {
        const sqrt_disc = @sqrt(disc);
        const lambda1 = (trace + sqrt_disc) / 2;
        const lambda2 = (trace - sqrt_disc) / 2;

        const e1 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        e1.* = .{ .number = lambda1 };
        list.append(env.allocator, e1) catch return BuiltinError.OutOfMemory;

        const e2 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        e2.* = .{ .number = lambda2 };
        list.append(env.allocator, e2) catch return BuiltinError.OutOfMemory;
    } else {
        // Complex eigenvalues
        const sqrt_neg_disc = @sqrt(-disc);
        const real_part = trace / 2;
        const imag_part = sqrt_neg_disc / 2;

        // (complex real imag) for first eigenvalue
        var c1_list: std.ArrayList(*Expr) = .empty;
        const c1_op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        c1_op.* = .{ .symbol = "complex" };
        c1_list.append(env.allocator, c1_op) catch return BuiltinError.OutOfMemory;
        const c1_real = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        c1_real.* = .{ .number = real_part };
        c1_list.append(env.allocator, c1_real) catch return BuiltinError.OutOfMemory;
        const c1_imag = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        c1_imag.* = .{ .number = imag_part };
        c1_list.append(env.allocator, c1_imag) catch return BuiltinError.OutOfMemory;
        const e1 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        e1.* = .{ .list = c1_list };
        list.append(env.allocator, e1) catch return BuiltinError.OutOfMemory;

        // (complex real -imag) for second eigenvalue
        var c2_list: std.ArrayList(*Expr) = .empty;
        const c2_op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        c2_op.* = .{ .symbol = "complex" };
        c2_list.append(env.allocator, c2_op) catch return BuiltinError.OutOfMemory;
        const c2_real = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        c2_real.* = .{ .number = real_part };
        c2_list.append(env.allocator, c2_real) catch return BuiltinError.OutOfMemory;
        const c2_imag = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        c2_imag.* = .{ .number = -imag_part };
        c2_list.append(env.allocator, c2_imag) catch return BuiltinError.OutOfMemory;
        const e2 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        e2.* = .{ .list = c2_list };
        list.append(env.allocator, e2) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_eigenvectors(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (eigenvectors M) - eigenvectors of 2x2 matrix M
    // For eigenvalue λ, eigenvector satisfies (A - λI)v = 0
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const m = args.items[0];
    if (!isMatrix(m)) return BuiltinError.InvalidArgument;

    const dims = getMatrixDims(m) orelse return BuiltinError.InvalidArgument;
    if (dims.rows != 2 or dims.cols != 2) return BuiltinError.InvalidArgument;

    const rows = getMatrixRows(m) orelse return BuiltinError.InvalidArgument;
    const a = rows[0].list.items[0];
    const b = rows[0].list.items[1];
    const c = rows[1].list.items[0];
    const d = rows[1].list.items[1];

    // Check if all are numbers
    if (a.* != .number or b.* != .number or c.* != .number or d.* != .number) {
        return BuiltinError.InvalidArgument;
    }

    const av = a.number;
    const bv = b.number;
    const cv = c.number;
    const dv = d.number;

    const trace = av + dv;
    const det = av * dv - bv * cv;
    const disc = trace * trace - 4 * det;

    if (disc < 0) {
        // Complex eigenvalues - return symbolic result
        return BuiltinError.InvalidArgument;
    }

    const sqrt_disc = @sqrt(disc);
    const lambda1 = (trace + sqrt_disc) / 2;
    const lambda2 = (trace - sqrt_disc) / 2;

    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "eigenvectors" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;

    // For each eigenvalue, find eigenvector from (A - λI)v = 0
    // Row 1: (a-λ)x + by = 0 => v = [b, λ-a] or [λ-d, c] (if b=0)

    // Eigenvector for lambda1
    const v1 = computeEigenvector(av, bv, cv, dv, lambda1, env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, v1) catch return BuiltinError.OutOfMemory;

    // Eigenvector for lambda2
    const v2 = computeEigenvector(av, bv, cv, dv, lambda2, env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, v2) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

fn computeEigenvector(a: f64, b: f64, c: f64, d: f64, lambda: f64, allocator: std.mem.Allocator) !*Expr {
    // (A - λI) = [[a-λ, b], [c, d-λ]]
    // Solve (a-λ)x + by = 0
    // If b != 0: v = [b, λ-a] (unnormalized)
    // If b = 0: use second row: cx + (d-λ)y = 0 => v = [d-λ, -c] or [1, 0] if c=0

    var x_comp: f64 = undefined;
    var y_comp: f64 = undefined;

    if (@abs(b) > 1e-10) {
        x_comp = b;
        y_comp = lambda - a;
    } else if (@abs(c) > 1e-10) {
        x_comp = d - lambda;
        y_comp = -c;
    } else {
        // Diagonal matrix - eigenvector is [1, 0] or [0, 1]
        if (@abs(a - lambda) < 1e-10) {
            x_comp = 1;
            y_comp = 0;
        } else {
            x_comp = 0;
            y_comp = 1;
        }
    }

    // Normalize
    const mag = @sqrt(x_comp * x_comp + y_comp * y_comp);
    if (mag > 1e-10) {
        x_comp /= mag;
        y_comp /= mag;
    }

    // Build (vector x y)
    var vec_list: std.ArrayList(*Expr) = .empty;
    const vec_op = allocator.create(Expr) catch return error.OutOfMemory;
    vec_op.* = .{ .symbol = "vector" };
    vec_list.append(allocator, vec_op) catch return error.OutOfMemory;

    const x_expr = allocator.create(Expr) catch return error.OutOfMemory;
    x_expr.* = .{ .number = x_comp };
    vec_list.append(allocator, x_expr) catch return error.OutOfMemory;

    const y_expr = allocator.create(Expr) catch return error.OutOfMemory;
    y_expr.* = .{ .number = y_comp };
    vec_list.append(allocator, y_expr) catch return error.OutOfMemory;

    const result = allocator.create(Expr) catch return error.OutOfMemory;
    result.* = .{ .list = vec_list };
    return result;
}

pub fn builtin_product(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (product var start end body) - product notation, handled specially by evaluator
    // args are: [start_val, end_val, body_evaluated_results...]
    // When called with numeric bounds, evaluator passes all evaluated body values
    // This multiplies them together
    if (args.items.len == 0) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 1 }; // Empty product is 1
        return result;
    }

    // Multiply all evaluated terms
    var all_numbers = true;
    var product_val: f64 = 1;
    for (args.items) |arg| {
        if (arg.* == .number) {
            product_val *= arg.number;
        } else {
            all_numbers = false;
            break;
        }
    }

    if (all_numbers) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = product_val };
        return result;
    }

    // Build symbolic product
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
    return symbolic.simplify(result, env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_matmul(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (matmul A B) - matrix multiplication
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const a = args.items[0];
    const b = args.items[1];

    if (!isMatrix(a) or !isMatrix(b)) return BuiltinError.InvalidArgument;

    const dims_a = getMatrixDims(a) orelse return BuiltinError.InvalidArgument;
    const dims_b = getMatrixDims(b) orelse return BuiltinError.InvalidArgument;

    // A: m x n, B: n x p => C: m x p
    if (dims_a.cols != dims_b.rows) return BuiltinError.InvalidArgument;

    const rows_a = getMatrixRows(a) orelse return BuiltinError.InvalidArgument;
    const rows_b = getMatrixRows(b) orelse return BuiltinError.InvalidArgument;

    // Build result matrix
    var result_list: std.ArrayList(*Expr) = .empty;
    const matrix_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    matrix_sym.* = .{ .symbol = "matrix" };
    result_list.append(env.allocator, matrix_sym) catch return BuiltinError.OutOfMemory;

    var i: usize = 0;
    while (i < dims_a.rows) : (i += 1) {
        var row_list: std.ArrayList(*Expr) = .empty;
        var j: usize = 0;
        while (j < dims_b.cols) : (j += 1) {
            // C[i,j] = sum(k: A[i,k] * B[k,j])
            var sum_expr: ?*Expr = null;
            var k: usize = 0;
            while (k < dims_a.cols) : (k += 1) {
                const a_ik = symbolic.copyExpr(rows_a[i].list.items[k], env.allocator) catch return BuiltinError.OutOfMemory;
                const b_kj = symbolic.copyExpr(rows_b[k].list.items[j], env.allocator) catch return BuiltinError.OutOfMemory;
                const product = symbolic.makeBinOp(env.allocator, "*", a_ik, b_kj) catch return BuiltinError.OutOfMemory;

                if (sum_expr) |s| {
                    sum_expr = symbolic.makeBinOp(env.allocator, "+", s, product) catch return BuiltinError.OutOfMemory;
                } else {
                    sum_expr = product;
                }
            }
            // Simplify and add to row
            if (sum_expr) |s| {
                const simplified = symbolic.simplify(s, env.allocator) catch return BuiltinError.OutOfMemory;
                s.deinit(env.allocator);
                env.allocator.destroy(s);
                row_list.append(env.allocator, simplified) catch return BuiltinError.OutOfMemory;
            }
        }
        const row_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        row_expr.* = .{ .list = row_list };
        result_list.append(env.allocator, row_expr) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_inv(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (inv M) - matrix inverse (2x2 only for now)
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const m = args.items[0];
    if (!isMatrix(m)) return BuiltinError.InvalidArgument;

    const dims = getMatrixDims(m) orelse return BuiltinError.InvalidArgument;
    if (dims.rows != dims.cols) return BuiltinError.InvalidArgument; // Must be square

    const rows = getMatrixRows(m) orelse return BuiltinError.InvalidArgument;

    if (dims.rows == 1) {
        // 1x1: inverse = 1/element
        const elem = rows[0].list.items[0];
        const one = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        one.* = .{ .number = 1 };
        const inv_elem = symbolic.makeBinOp(env.allocator, "/", one, symbolic.copyExpr(elem, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const simplified = symbolic.simplify(inv_elem, env.allocator) catch return BuiltinError.OutOfMemory;
        inv_elem.deinit(env.allocator);
        env.allocator.destroy(inv_elem);

        // Build 1x1 matrix
        var row_list: std.ArrayList(*Expr) = .empty;
        row_list.append(env.allocator, simplified) catch return BuiltinError.OutOfMemory;
        const row_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        row_expr.* = .{ .list = row_list };

        var result_list: std.ArrayList(*Expr) = .empty;
        const matrix_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        matrix_sym.* = .{ .symbol = "matrix" };
        result_list.append(env.allocator, matrix_sym) catch return BuiltinError.OutOfMemory;
        result_list.append(env.allocator, row_expr) catch return BuiltinError.OutOfMemory;

        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .list = result_list };
        return result;
    } else if (dims.rows == 2) {
        // 2x2: inverse = (1/det) * adjugate
        // For [[a,b],[c,d]], inverse = (1/(ad-bc)) * [[d,-b],[-c,a]]
        const a = rows[0].list.items[0];
        const b = rows[0].list.items[1];
        const c = rows[1].list.items[0];
        const d = rows[1].list.items[1];

        // Compute determinant: ad - bc
        const ad = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(a, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(d, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const bc = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(b, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(c, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const det_expr = symbolic.makeBinOp(env.allocator, "-", ad, bc) catch return BuiltinError.OutOfMemory;
        const det = symbolic.simplify(det_expr, env.allocator) catch return BuiltinError.OutOfMemory;
        det_expr.deinit(env.allocator);
        env.allocator.destroy(det_expr);

        // Build adjugate: [[d, -b], [-c, a]]
        // Entry (1,1): d/det
        const neg_one = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        neg_one.* = .{ .number = -1 };

        const entry11_num = symbolic.copyExpr(d, env.allocator) catch return BuiltinError.OutOfMemory;
        const entry11 = symbolic.makeBinOp(env.allocator, "/", entry11_num, symbolic.copyExpr(det, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const entry11_s = symbolic.simplify(entry11, env.allocator) catch return BuiltinError.OutOfMemory;
        entry11.deinit(env.allocator);
        env.allocator.destroy(entry11);

        // Entry (1,2): -b/det
        const neg_b = symbolic.makeBinOp(env.allocator, "*", neg_one, symbolic.copyExpr(b, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const entry12 = symbolic.makeBinOp(env.allocator, "/", neg_b, symbolic.copyExpr(det, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const entry12_s = symbolic.simplify(entry12, env.allocator) catch return BuiltinError.OutOfMemory;
        entry12.deinit(env.allocator);
        env.allocator.destroy(entry12);

        // Entry (2,1): -c/det
        const neg_one2 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        neg_one2.* = .{ .number = -1 };
        const neg_c = symbolic.makeBinOp(env.allocator, "*", neg_one2, symbolic.copyExpr(c, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const entry21 = symbolic.makeBinOp(env.allocator, "/", neg_c, symbolic.copyExpr(det, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const entry21_s = symbolic.simplify(entry21, env.allocator) catch return BuiltinError.OutOfMemory;
        entry21.deinit(env.allocator);
        env.allocator.destroy(entry21);

        // Entry (2,2): a/det
        const entry22_num = symbolic.copyExpr(a, env.allocator) catch return BuiltinError.OutOfMemory;
        const entry22 = symbolic.makeBinOp(env.allocator, "/", entry22_num, symbolic.copyExpr(det, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
        const entry22_s = symbolic.simplify(entry22, env.allocator) catch return BuiltinError.OutOfMemory;
        entry22.deinit(env.allocator);
        env.allocator.destroy(entry22);

        // Free det
        det.deinit(env.allocator);
        env.allocator.destroy(det);

        // Build row 1: [entry11, entry12]
        var row1_list: std.ArrayList(*Expr) = .empty;
        row1_list.append(env.allocator, entry11_s) catch return BuiltinError.OutOfMemory;
        row1_list.append(env.allocator, entry12_s) catch return BuiltinError.OutOfMemory;
        const row1_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        row1_expr.* = .{ .list = row1_list };

        // Build row 2: [entry21, entry22]
        var row2_list: std.ArrayList(*Expr) = .empty;
        row2_list.append(env.allocator, entry21_s) catch return BuiltinError.OutOfMemory;
        row2_list.append(env.allocator, entry22_s) catch return BuiltinError.OutOfMemory;
        const row2_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        row2_expr.* = .{ .list = row2_list };

        // Build matrix
        var result_list: std.ArrayList(*Expr) = .empty;
        const matrix_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        matrix_sym.* = .{ .symbol = "matrix" };
        result_list.append(env.allocator, matrix_sym) catch return BuiltinError.OutOfMemory;
        result_list.append(env.allocator, row1_expr) catch return BuiltinError.OutOfMemory;
        result_list.append(env.allocator, row2_expr) catch return BuiltinError.OutOfMemory;

        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .list = result_list };
        return result;
    }

    // For larger matrices, return symbolic inverse
    var result_list: std.ArrayList(*Expr) = .empty;
    const inv_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    inv_sym.* = .{ .symbol = "inv" };
    result_list.append(env.allocator, inv_sym) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, symbolic.copyExpr(m, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

// ============================================================================
// Vector Operations
// ============================================================================

fn isVector(expr: *const Expr) bool {
    // A vector is (vector e1 e2 ...)
    if (expr.* != .list) return false;
    if (expr.list.items.len < 2) return false;
    if (expr.list.items[0].* != .symbol) return false;
    return std.mem.eql(u8, expr.list.items[0].symbol, "vector");
}

fn getVectorElems(expr: *const Expr) ?[]*Expr {
    if (!isVector(expr)) return null;
    return expr.list.items[1..];
}

pub fn builtin_vector(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (vector e1 e2 ...) - creates a vector
    var result_list: std.ArrayList(*Expr) = .empty;
    const vec_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    vec_sym.* = .{ .symbol = "vector" };
    result_list.append(env.allocator, vec_sym) catch return BuiltinError.OutOfMemory;

    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_dot(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (dot v1 v2) - dot product
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const v1 = args.items[0];
    const v2 = args.items[1];

    if (!isVector(v1) or !isVector(v2)) return BuiltinError.InvalidArgument;

    const elems1 = getVectorElems(v1) orelse return BuiltinError.InvalidArgument;
    const elems2 = getVectorElems(v2) orelse return BuiltinError.InvalidArgument;

    if (elems1.len != elems2.len) return BuiltinError.InvalidArgument;

    // dot = sum of element-wise products
    var sum_expr: ?*Expr = null;
    for (elems1, elems2) |e1, e2| {
        const e1_copy = symbolic.copyExpr(e1, env.allocator) catch return BuiltinError.OutOfMemory;
        const e2_copy = symbolic.copyExpr(e2, env.allocator) catch return BuiltinError.OutOfMemory;
        const product = symbolic.makeBinOp(env.allocator, "*", e1_copy, e2_copy) catch return BuiltinError.OutOfMemory;

        if (sum_expr) |s| {
            sum_expr = symbolic.makeBinOp(env.allocator, "+", s, product) catch return BuiltinError.OutOfMemory;
        } else {
            sum_expr = product;
        }
    }

    if (sum_expr) |s| {
        const result = symbolic.simplify(s, env.allocator) catch return BuiltinError.OutOfMemory;
        s.deinit(env.allocator);
        env.allocator.destroy(s);
        return result;
    } else {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 0 };
        return result;
    }
}

pub fn builtin_cross(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (cross v1 v2) - cross product (3D vectors only)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const v1 = args.items[0];
    const v2 = args.items[1];

    if (!isVector(v1) or !isVector(v2)) return BuiltinError.InvalidArgument;

    const elems1 = getVectorElems(v1) orelse return BuiltinError.InvalidArgument;
    const elems2 = getVectorElems(v2) orelse return BuiltinError.InvalidArgument;

    if (elems1.len != 3 or elems2.len != 3) return BuiltinError.InvalidArgument;

    // cross product: (a1, a2, a3) x (b1, b2, b3) = (a2*b3 - a3*b2, a3*b1 - a1*b3, a1*b2 - a2*b1)
    const a1 = elems1[0];
    const a2 = elems1[1];
    const a3 = elems1[2];
    const b1 = elems2[0];
    const b2 = elems2[1];
    const b3 = elems2[2];

    // Component 1: a2*b3 - a3*b2
    const a2b3 = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(a2, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(b3, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
    const a3b2 = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(a3, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(b2, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
    const c1 = symbolic.makeBinOp(env.allocator, "-", a2b3, a3b2) catch return BuiltinError.OutOfMemory;
    const c1_s = symbolic.simplify(c1, env.allocator) catch return BuiltinError.OutOfMemory;
    c1.deinit(env.allocator);
    env.allocator.destroy(c1);

    // Component 2: a3*b1 - a1*b3
    const a3b1 = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(a3, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(b1, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
    const a1b3 = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(a1, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(b3, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
    const c2 = symbolic.makeBinOp(env.allocator, "-", a3b1, a1b3) catch return BuiltinError.OutOfMemory;
    const c2_s = symbolic.simplify(c2, env.allocator) catch return BuiltinError.OutOfMemory;
    c2.deinit(env.allocator);
    env.allocator.destroy(c2);

    // Component 3: a1*b2 - a2*b1
    const a1b2 = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(a1, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(b2, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
    const a2b1 = symbolic.makeBinOp(env.allocator, "*", symbolic.copyExpr(a2, env.allocator) catch return BuiltinError.OutOfMemory, symbolic.copyExpr(b1, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
    const c3 = symbolic.makeBinOp(env.allocator, "-", a1b2, a2b1) catch return BuiltinError.OutOfMemory;
    const c3_s = symbolic.simplify(c3, env.allocator) catch return BuiltinError.OutOfMemory;
    c3.deinit(env.allocator);
    env.allocator.destroy(c3);

    // Build result vector
    var result_list: std.ArrayList(*Expr) = .empty;
    const vec_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    vec_sym.* = .{ .symbol = "vector" };
    result_list.append(env.allocator, vec_sym) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, c1_s) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, c2_s) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, c3_s) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_norm(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (norm v) - Euclidean norm (magnitude) of vector
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const v = args.items[0];
    if (!isVector(v)) return BuiltinError.InvalidArgument;

    const elems = getVectorElems(v) orelse return BuiltinError.InvalidArgument;

    // norm = sqrt(sum of squares)
    var sum_expr: ?*Expr = null;
    for (elems) |e| {
        const e_copy = symbolic.copyExpr(e, env.allocator) catch return BuiltinError.OutOfMemory;
        const e_copy2 = symbolic.copyExpr(e, env.allocator) catch return BuiltinError.OutOfMemory;
        const sq = symbolic.makeBinOp(env.allocator, "*", e_copy, e_copy2) catch return BuiltinError.OutOfMemory;

        if (sum_expr) |s| {
            sum_expr = symbolic.makeBinOp(env.allocator, "+", s, sq) catch return BuiltinError.OutOfMemory;
        } else {
            sum_expr = sq;
        }
    }

    if (sum_expr) |s| {
        const s_simplified = symbolic.simplify(s, env.allocator) catch return BuiltinError.OutOfMemory;
        s.deinit(env.allocator);
        env.allocator.destroy(s);

        // If all numeric, compute sqrt directly
        if (s_simplified.* == .number) {
            const val = s_simplified.number;
            s_simplified.deinit(env.allocator);
            env.allocator.destroy(s_simplified);
            const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = @sqrt(val) };
            return result;
        }

        // Otherwise build sqrt(sum) expression
        var sqrt_list: std.ArrayList(*Expr) = .empty;
        const sqrt_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        sqrt_sym.* = .{ .symbol = "sqrt" };
        sqrt_list.append(env.allocator, sqrt_sym) catch return BuiltinError.OutOfMemory;
        sqrt_list.append(env.allocator, s_simplified) catch return BuiltinError.OutOfMemory;

        const sqrt_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        sqrt_expr.* = .{ .list = sqrt_list };
        return sqrt_expr;
    } else {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 0 };
        return result;
    }
}

// ============================================================================
// LU Decomposition
// ============================================================================

pub fn builtin_lu(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (lu M) - LU decomposition of matrix M using Doolittle's algorithm
    // Returns (lu L U) where A = L*U, L is lower triangular with 1s on diagonal
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const m = args.items[0];
    if (!isMatrix(m)) return BuiltinError.InvalidArgument;

    const dims = getMatrixDims(m) orelse return BuiltinError.InvalidArgument;
    if (dims.rows != dims.cols) return BuiltinError.InvalidArgument; // Must be square

    const n = dims.rows;
    const rows = getMatrixRows(m) orelse return BuiltinError.InvalidArgument;

    // Extract numeric values from matrix
    var values: [16][16]f64 = undefined;
    if (n > 16) return BuiltinError.InvalidArgument; // Limit matrix size

    for (0..n) |i| {
        for (0..n) |j| {
            const elem = rows[i].list.items[j];
            if (elem.* != .number) return BuiltinError.InvalidArgument;
            values[i][j] = elem.number;
        }
    }

    // Doolittle's LU decomposition: A = LU
    // L[i][j] for i > j, L[i][i] = 1
    // U[i][j] for i <= j
    var l_vals: [16][16]f64 = undefined;
    var u_vals: [16][16]f64 = undefined;

    // Initialize
    for (0..n) |i| {
        for (0..n) |j| {
            l_vals[i][j] = if (i == j) 1.0 else 0.0;
            u_vals[i][j] = 0.0;
        }
    }

    // Compute L and U
    for (0..n) |i| {
        // Upper triangular matrix U
        for (i..n) |j| {
            var sum: f64 = 0.0;
            for (0..i) |k| {
                sum += l_vals[i][k] * u_vals[k][j];
            }
            u_vals[i][j] = values[i][j] - sum;
        }

        // Lower triangular matrix L
        for ((i + 1)..n) |j| {
            var sum: f64 = 0.0;
            for (0..i) |k| {
                sum += l_vals[j][k] * u_vals[k][i];
            }
            if (@abs(u_vals[i][i]) < 1e-15) {
                // Pivot is zero - matrix is singular
                return BuiltinError.InvalidArgument;
            }
            l_vals[j][i] = (values[j][i] - sum) / u_vals[i][i];
        }
    }

    // Build L matrix
    var l_result: std.ArrayList(*Expr) = .empty;
    const l_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    l_sym.* = .{ .symbol = "matrix" };
    l_result.append(env.allocator, l_sym) catch return BuiltinError.OutOfMemory;

    for (0..n) |i| {
        var l_row: std.ArrayList(*Expr) = .empty;
        for (0..n) |j| {
            const val = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            val.* = .{ .number = l_vals[i][j] };
            l_row.append(env.allocator, val) catch return BuiltinError.OutOfMemory;
        }
        const l_row_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        l_row_expr.* = .{ .list = l_row };
        l_result.append(env.allocator, l_row_expr) catch return BuiltinError.OutOfMemory;
    }

    const l_matrix = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    l_matrix.* = .{ .list = l_result };

    // Build U matrix
    var u_result: std.ArrayList(*Expr) = .empty;
    const u_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    u_sym.* = .{ .symbol = "matrix" };
    u_result.append(env.allocator, u_sym) catch return BuiltinError.OutOfMemory;

    for (0..n) |i| {
        var u_row: std.ArrayList(*Expr) = .empty;
        for (0..n) |j| {
            const val = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            val.* = .{ .number = u_vals[i][j] };
            u_row.append(env.allocator, val) catch return BuiltinError.OutOfMemory;
        }
        const u_row_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        u_row_expr.* = .{ .list = u_row };
        u_result.append(env.allocator, u_row_expr) catch return BuiltinError.OutOfMemory;
    }

    const u_matrix = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    u_matrix.* = .{ .list = u_result };

    // Return (lu L U)
    var result_list: std.ArrayList(*Expr) = .empty;
    const lu_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    lu_sym.* = .{ .symbol = "lu" };
    result_list.append(env.allocator, lu_sym) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, l_matrix) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, u_matrix) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

// ============================================================================
// Characteristic Polynomial
// ============================================================================

pub fn builtin_charpoly(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (charpoly M lambda) - characteristic polynomial det(M - lambda*I)
    // For 2x2: λ² - trace*λ + det
    // For 3x3: -λ³ + trace*λ² - (sum of 2x2 principal minors)*λ + det
    if (args.items.len < 1 or args.items.len > 2) return BuiltinError.InvalidArgument;

    const m = args.items[0];
    if (!isMatrix(m)) return BuiltinError.InvalidArgument;

    const dims = getMatrixDims(m) orelse return BuiltinError.InvalidArgument;
    if (dims.rows != dims.cols) return BuiltinError.InvalidArgument; // Must be square

    // Get the variable (default to λ)
    const lambda_var: []const u8 = if (args.items.len == 2)
        (if (args.items[1].* == .symbol) args.items[1].symbol else return BuiltinError.InvalidArgument)
    else
        "λ";

    const rows = getMatrixRows(m) orelse return BuiltinError.InvalidArgument;

    if (dims.rows == 2) {
        // 2x2: p(λ) = λ² - (a+d)λ + (ad-bc)
        const a = rows[0].list.items[0];
        const b = rows[0].list.items[1];
        const c = rows[1].list.items[0];
        const d = rows[1].list.items[1];

        // Build λ²
        const lambda_sym1 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        lambda_sym1.* = .{ .symbol = lambda_var };
        const two1 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        two1.* = .{ .number = 2 };
        const lambda_sq = symbolic.makeBinOp(env.allocator, "^", lambda_sym1, two1) catch return BuiltinError.OutOfMemory;

        // Build trace = a + d
        const a_copy = symbolic.copyExpr(a, env.allocator) catch return BuiltinError.OutOfMemory;
        const d_copy = symbolic.copyExpr(d, env.allocator) catch return BuiltinError.OutOfMemory;
        const trace = symbolic.makeBinOp(env.allocator, "+", a_copy, d_copy) catch return BuiltinError.OutOfMemory;

        // Build trace * λ
        const trace_simp = symbolic.simplify(trace, env.allocator) catch return BuiltinError.OutOfMemory;
        trace.deinit(env.allocator);
        env.allocator.destroy(trace);
        const lambda_sym2 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        lambda_sym2.* = .{ .symbol = lambda_var };
        const trace_lambda = symbolic.makeBinOp(env.allocator, "*", trace_simp, lambda_sym2) catch return BuiltinError.OutOfMemory;

        // Build det = ad - bc
        const a_copy2 = symbolic.copyExpr(a, env.allocator) catch return BuiltinError.OutOfMemory;
        const d_copy2 = symbolic.copyExpr(d, env.allocator) catch return BuiltinError.OutOfMemory;
        const ad = symbolic.makeBinOp(env.allocator, "*", a_copy2, d_copy2) catch return BuiltinError.OutOfMemory;
        const b_copy = symbolic.copyExpr(b, env.allocator) catch return BuiltinError.OutOfMemory;
        const c_copy = symbolic.copyExpr(c, env.allocator) catch return BuiltinError.OutOfMemory;
        const bc = symbolic.makeBinOp(env.allocator, "*", b_copy, c_copy) catch return BuiltinError.OutOfMemory;
        const det = symbolic.makeBinOp(env.allocator, "-", ad, bc) catch return BuiltinError.OutOfMemory;
        const det_simp = symbolic.simplify(det, env.allocator) catch return BuiltinError.OutOfMemory;
        det.deinit(env.allocator);
        env.allocator.destroy(det);

        // Build λ² - trace*λ + det
        const sub1 = symbolic.makeBinOp(env.allocator, "-", lambda_sq, trace_lambda) catch return BuiltinError.OutOfMemory;
        const poly_expr = symbolic.makeBinOp(env.allocator, "+", sub1, det_simp) catch return BuiltinError.OutOfMemory;

        const result = symbolic.simplify(poly_expr, env.allocator) catch return BuiltinError.OutOfMemory;
        poly_expr.deinit(env.allocator);
        env.allocator.destroy(poly_expr);
        return result;
    }

    // For larger matrices, return symbolic charpoly expression
    var result_list: std.ArrayList(*Expr) = .empty;
    const charpoly_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    charpoly_sym.* = .{ .symbol = "charpoly" };
    result_list.append(env.allocator, charpoly_sym) catch return BuiltinError.OutOfMemory;
    const m_copy = symbolic.copyExpr(m, env.allocator) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, m_copy) catch return BuiltinError.OutOfMemory;
    const lambda_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    lambda_sym.* = .{ .symbol = lambda_var };
    result_list.append(env.allocator, lambda_sym) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

// ============================================================================
// Polynomial Root Finding
// ============================================================================

pub fn builtin_roots(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (roots poly var) - finds roots of polynomial in var
    // Supports linear and quadratic polynomials with complex roots
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    const poly = args.items[0];
    const var_name = args.items[1].symbol;

    // Get polynomial coefficients
    const coeffs = symbolic.getCoefficients(poly, var_name, env.allocator) catch return BuiltinError.OutOfMemory;
    defer {
        for (coeffs) |c| {
            c.deinit(env.allocator);
            env.allocator.destroy(c);
        }
        env.allocator.free(coeffs);
    }

    if (coeffs.len == 0) return BuiltinError.InvalidArgument;

    var result_list: std.ArrayList(*Expr) = .empty;
    const roots_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    roots_sym.* = .{ .symbol = "roots" };
    result_list.append(env.allocator, roots_sym) catch return BuiltinError.OutOfMemory;

    const degree = coeffs.len - 1;

    if (degree == 1) {
        // Linear: ax + b = 0, x = -b/a
        const a = coeffs[1];
        const b = coeffs[0];
        if (a.* == .number and b.* == .number) {
            const root_val = -b.number / a.number;
            const root = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            root.* = .{ .number = root_val };
            result_list.append(env.allocator, root) catch return BuiltinError.OutOfMemory;
        } else {
            // Symbolic: -b/a
            const neg_b = symbolic.makeBinOp(env.allocator, "*", blk: {
                const neg1 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                neg1.* = .{ .number = -1 };
                break :blk neg1;
            }, symbolic.copyExpr(b, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
            const root_expr = symbolic.makeBinOp(env.allocator, "/", neg_b, symbolic.copyExpr(a, env.allocator) catch return BuiltinError.OutOfMemory) catch return BuiltinError.OutOfMemory;
            const root_simp = symbolic.simplify(root_expr, env.allocator) catch return BuiltinError.OutOfMemory;
            root_expr.deinit(env.allocator);
            env.allocator.destroy(root_expr);
            result_list.append(env.allocator, root_simp) catch return BuiltinError.OutOfMemory;
        }
    } else if (degree == 2) {
        // Quadratic: ax² + bx + c = 0
        // x = (-b ± sqrt(b² - 4ac)) / 2a
        const a = coeffs[2];
        const b = coeffs[1];
        const c = coeffs[0];

        if (a.* == .number and b.* == .number and c.* == .number) {
            const av = a.number;
            const bv = b.number;
            const cv = c.number;

            const disc = bv * bv - 4 * av * cv;

            if (disc >= 0) {
                const sqrt_disc = @sqrt(disc);
                const r1 = (-bv + sqrt_disc) / (2 * av);
                const r2 = (-bv - sqrt_disc) / (2 * av);

                const root1 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                root1.* = .{ .number = r1 };
                result_list.append(env.allocator, root1) catch return BuiltinError.OutOfMemory;

                const root2 = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                root2.* = .{ .number = r2 };
                result_list.append(env.allocator, root2) catch return BuiltinError.OutOfMemory;
            } else {
                // Complex roots
                const sqrt_neg_disc = @sqrt(-disc);
                const real_part = -bv / (2 * av);
                const imag_part = sqrt_neg_disc / (2 * av);

                const c1 = symbolic.makeComplex(env.allocator, real_part, imag_part) catch return BuiltinError.OutOfMemory;
                result_list.append(env.allocator, c1) catch return BuiltinError.OutOfMemory;

                const c2 = symbolic.makeComplex(env.allocator, real_part, -imag_part) catch return BuiltinError.OutOfMemory;
                result_list.append(env.allocator, c2) catch return BuiltinError.OutOfMemory;
            }
        } else {
            // Symbolic - return roots expression with the polynomial
            const poly_copy = symbolic.copyExpr(poly, env.allocator) catch return BuiltinError.OutOfMemory;
            result_list.append(env.allocator, poly_copy) catch return BuiltinError.OutOfMemory;
        }
    } else {
        // Higher degree - return symbolic
        const poly_copy = symbolic.copyExpr(poly, env.allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(env.allocator, poly_copy) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

// ============================================================================
// Discriminant
// ============================================================================

pub fn builtin_discriminant(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (discriminant poly var) - discriminant of polynomial
    // For quadratic ax² + bx + c: disc = b² - 4ac
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .symbol) return BuiltinError.InvalidArgument;

    const poly = args.items[0];
    const var_name = args.items[1].symbol;

    // Get polynomial coefficients
    const coeffs = symbolic.getCoefficients(poly, var_name, env.allocator) catch return BuiltinError.OutOfMemory;
    defer {
        for (coeffs) |c| {
            c.deinit(env.allocator);
            env.allocator.destroy(c);
        }
        env.allocator.free(coeffs);
    }

    if (coeffs.len < 2) return BuiltinError.InvalidArgument;

    const degree = coeffs.len - 1;

    if (degree == 2) {
        // Quadratic: disc = b² - 4ac
        const a = coeffs[2];
        const b = coeffs[1];
        const c = coeffs[0];

        if (a.* == .number and b.* == .number and c.* == .number) {
            const disc = b.number * b.number - 4 * a.number * c.number;
            const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = disc };
            return result;
        } else {
            // Symbolic: b² - 4ac
            const b_copy = symbolic.copyExpr(b, env.allocator) catch return BuiltinError.OutOfMemory;
            const b_copy2 = symbolic.copyExpr(b, env.allocator) catch return BuiltinError.OutOfMemory;
            const b_sq = symbolic.makeBinOp(env.allocator, "*", b_copy, b_copy2) catch return BuiltinError.OutOfMemory;

            const four = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            four.* = .{ .number = 4 };
            const a_copy = symbolic.copyExpr(a, env.allocator) catch return BuiltinError.OutOfMemory;
            const c_copy = symbolic.copyExpr(c, env.allocator) catch return BuiltinError.OutOfMemory;
            const four_a = symbolic.makeBinOp(env.allocator, "*", four, a_copy) catch return BuiltinError.OutOfMemory;
            const four_ac = symbolic.makeBinOp(env.allocator, "*", four_a, c_copy) catch return BuiltinError.OutOfMemory;

            const disc_expr = symbolic.makeBinOp(env.allocator, "-", b_sq, four_ac) catch return BuiltinError.OutOfMemory;
            const result = symbolic.simplify(disc_expr, env.allocator) catch return BuiltinError.OutOfMemory;
            disc_expr.deinit(env.allocator);
            env.allocator.destroy(disc_expr);
            return result;
        }
    } else if (degree == 3) {
        // Cubic: disc = 18abcd - 4b³d + b²c² - 4ac³ - 27a²d²
        // For simplicity, return symbolic for now
        var result_list: std.ArrayList(*Expr) = .empty;
        const disc_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        disc_sym.* = .{ .symbol = "discriminant" };
        result_list.append(env.allocator, disc_sym) catch return BuiltinError.OutOfMemory;
        const poly_copy = symbolic.copyExpr(poly, env.allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(env.allocator, poly_copy) catch return BuiltinError.OutOfMemory;
        const var_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        var_sym.* = .{ .symbol = var_name };
        result_list.append(env.allocator, var_sym) catch return BuiltinError.OutOfMemory;

        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .list = result_list };
        return result;
    }

    // Other degrees - return symbolic
    var result_list: std.ArrayList(*Expr) = .empty;
    const disc_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    disc_sym.* = .{ .symbol = "discriminant" };
    result_list.append(env.allocator, disc_sym) catch return BuiltinError.OutOfMemory;
    const poly_copy = symbolic.copyExpr(poly, env.allocator) catch return BuiltinError.OutOfMemory;
    result_list.append(env.allocator, poly_copy) catch return BuiltinError.OutOfMemory;
    const var_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    var_sym.* = .{ .symbol = var_name };
    result_list.append(env.allocator, var_sym) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

// ============================================================================
// Quaternion Functions
// ============================================================================

/// Helper to check if expression is a quaternion (quat a b c d)
fn isQuaternion(expr: *const Expr) bool {
    if (expr.* != .list) return false;
    if (expr.list.items.len != 5) return false;
    if (expr.list.items[0].* != .symbol) return false;
    return std.mem.eql(u8, expr.list.items[0].symbol, "quat");
}

/// Helper to get quaternion components [a, b, c, d] where q = a + bi + cj + dk
fn getQuatComponents(expr: *const Expr) ?[4]f64 {
    if (!isQuaternion(expr)) return null;
    var components: [4]f64 = undefined;
    for (0..4) |i| {
        if (expr.list.items[i + 1].* != .number) return null;
        components[i] = expr.list.items[i + 1].number;
    }
    return components;
}

/// Helper to create a quaternion expression
fn makeQuaternion(allocator: std.mem.Allocator, a: f64, b: f64, c: f64, d: f64) BuiltinError!*Expr {
    var list: std.ArrayList(*Expr) = .empty;
    const quat_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    quat_sym.* = .{ .symbol = "quat" };
    list.append(allocator, quat_sym) catch return BuiltinError.OutOfMemory;

    const a_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    a_expr.* = .{ .number = a };
    list.append(allocator, a_expr) catch return BuiltinError.OutOfMemory;

    const b_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    b_expr.* = .{ .number = b };
    list.append(allocator, b_expr) catch return BuiltinError.OutOfMemory;

    const c_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    c_expr.* = .{ .number = c };
    list.append(allocator, c_expr) catch return BuiltinError.OutOfMemory;

    const d_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    d_expr.* = .{ .number = d };
    list.append(allocator, d_expr) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_quat(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (quat a b c d) - creates quaternion a + bi + cj + dk
    if (args.items.len != 4) return BuiltinError.InvalidArgument;
    for (args.items) |arg| {
        if (arg.* != .number) return BuiltinError.InvalidArgument;
    }

    return makeQuaternion(env.allocator, args.items[0].number, args.items[1].number, args.items[2].number, args.items[3].number);
}

pub fn builtin_quat_add(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (quat+ q1 q2) - quaternion addition
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const q1 = getQuatComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const q2 = getQuatComponents(args.items[1]) orelse return BuiltinError.InvalidArgument;

    return makeQuaternion(env.allocator, q1[0] + q2[0], q1[1] + q2[1], q1[2] + q2[2], q1[3] + q2[3]);
}

pub fn builtin_quat_mul(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (quat* q1 q2) - quaternion multiplication (Hamilton product)
    // (a1 + b1i + c1j + d1k)(a2 + b2i + c2j + d2k)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const q1 = getQuatComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const q2 = getQuatComponents(args.items[1]) orelse return BuiltinError.InvalidArgument;

    const a1 = q1[0];
    const b1 = q1[1];
    const c1 = q1[2];
    const d1 = q1[3];
    const a2 = q2[0];
    const b2 = q2[1];
    const c2 = q2[2];
    const d2 = q2[3];

    // Hamilton product formula
    const a = a1 * a2 - b1 * b2 - c1 * c2 - d1 * d2;
    const b = a1 * b2 + b1 * a2 + c1 * d2 - d1 * c2;
    const c = a1 * c2 - b1 * d2 + c1 * a2 + d1 * b2;
    const d = a1 * d2 + b1 * c2 - c1 * b2 + d1 * a2;

    return makeQuaternion(env.allocator, a, b, c, d);
}

pub fn builtin_quat_conj(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (quat-conj q) - quaternion conjugate: a - bi - cj - dk
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const q = getQuatComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;

    return makeQuaternion(env.allocator, q[0], -q[1], -q[2], -q[3]);
}

pub fn builtin_quat_norm(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (quat-norm q) - quaternion norm: sqrt(a² + b² + c² + d²)
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const q = getQuatComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;

    const norm = @sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = norm };
    return result;
}

pub fn builtin_quat_inv(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (quat-inv q) - quaternion inverse: conj(q) / |q|²
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const q = getQuatComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;

    const norm_sq = q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3];
    if (norm_sq == 0) return BuiltinError.InvalidArgument;

    return makeQuaternion(env.allocator, q[0] / norm_sq, -q[1] / norm_sq, -q[2] / norm_sq, -q[3] / norm_sq);
}

pub fn builtin_quat_scalar(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (quat-scalar q) - gets scalar (real) part
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const q = getQuatComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = q[0] };
    return result;
}

pub fn builtin_quat_vector(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (quat-vector q) - gets vector (imaginary) part as (vector b c d)
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const q = getQuatComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;

    var list: std.ArrayList(*Expr) = .empty;
    const vec_sym = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    vec_sym.* = .{ .symbol = "vector" };
    list.append(env.allocator, vec_sym) catch return BuiltinError.OutOfMemory;

    const b_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    b_expr.* = .{ .number = q[1] };
    list.append(env.allocator, b_expr) catch return BuiltinError.OutOfMemory;

    const c_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    c_expr.* = .{ .number = q[2] };
    list.append(env.allocator, c_expr) catch return BuiltinError.OutOfMemory;

    const d_expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    d_expr.* = .{ .number = q[3] };
    list.append(env.allocator, d_expr) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

// ============================================================================
// Finite Field GF(p) Functions
// ============================================================================

/// Helper to check if expression is a GF element (gf value p)
fn isGfElement(expr: *const Expr) bool {
    if (expr.* != .list) return false;
    if (expr.list.items.len != 3) return false;
    if (expr.list.items[0].* != .symbol) return false;
    return std.mem.eql(u8, expr.list.items[0].symbol, "gf");
}

/// Helper to get GF element value and modulus
fn getGfComponents(expr: *const Expr) ?struct { value: i64, p: i64 } {
    if (!isGfElement(expr)) return null;
    if (expr.list.items[1].* != .number) return null;
    if (expr.list.items[2].* != .number) return null;
    return .{
        .value = @intFromFloat(expr.list.items[1].number),
        .p = @intFromFloat(expr.list.items[2].number),
    };
}

/// Helper to create a GF element
fn makeGfElement(allocator: std.mem.Allocator, value: i64, p: i64) BuiltinError!*Expr {
    var list: std.ArrayList(*Expr) = .empty;
    const gf_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    gf_sym.* = .{ .symbol = "gf" };
    list.append(allocator, gf_sym) catch return BuiltinError.OutOfMemory;

    // Normalize value to [0, p-1]
    var normalized = @mod(value, p);
    if (normalized < 0) normalized += p;

    const val_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    val_expr.* = .{ .number = @floatFromInt(normalized) };
    list.append(allocator, val_expr) catch return BuiltinError.OutOfMemory;

    const p_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    p_expr.* = .{ .number = @floatFromInt(p) };
    list.append(allocator, p_expr) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_gf(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gf value p) - creates element in GF(p)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;
    if (args.items[0].* != .number) return BuiltinError.InvalidArgument;
    if (args.items[1].* != .number) return BuiltinError.InvalidArgument;

    const value: i64 = @intFromFloat(args.items[0].number);
    const p: i64 = @intFromFloat(args.items[1].number);

    if (p <= 1) return BuiltinError.InvalidArgument; // p must be > 1

    return makeGfElement(env.allocator, value, p);
}

pub fn builtin_gf_add(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gf+ a b) - addition in GF(p)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const a = getGfComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const b = getGfComponents(args.items[1]) orelse return BuiltinError.InvalidArgument;

    if (a.p != b.p) return BuiltinError.InvalidArgument; // Must be same field

    return makeGfElement(env.allocator, a.value + b.value, a.p);
}

pub fn builtin_gf_sub(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gf- a b) - subtraction in GF(p)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const a = getGfComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const b = getGfComponents(args.items[1]) orelse return BuiltinError.InvalidArgument;

    if (a.p != b.p) return BuiltinError.InvalidArgument;

    return makeGfElement(env.allocator, a.value - b.value, a.p);
}

pub fn builtin_gf_mul(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gf* a b) - multiplication in GF(p)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const a = getGfComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const b = getGfComponents(args.items[1]) orelse return BuiltinError.InvalidArgument;

    if (a.p != b.p) return BuiltinError.InvalidArgument;

    return makeGfElement(env.allocator, a.value * b.value, a.p);
}

pub fn builtin_gf_div(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gf/ a b) - division in GF(p): a * b^(-1)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const a = getGfComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;
    const b = getGfComponents(args.items[1]) orelse return BuiltinError.InvalidArgument;

    if (a.p != b.p) return BuiltinError.InvalidArgument;
    if (b.value == 0) return BuiltinError.InvalidArgument; // Division by zero

    // Find multiplicative inverse of b using extended Euclidean algorithm
    const inv = modInverse(b.value, b.p) orelse return BuiltinError.InvalidArgument;

    return makeGfElement(env.allocator, a.value * inv, a.p);
}

/// Compute modular inverse using extended Euclidean algorithm
fn modInverse(a: i64, m: i64) ?i64 {
    var old_r: i64 = a;
    var r: i64 = m;
    var old_s: i64 = 1;
    var s: i64 = 0;

    while (r != 0) {
        const quotient = @divTrunc(old_r, r);
        const temp_r = r;
        r = old_r - quotient * r;
        old_r = temp_r;

        const temp_s = s;
        s = old_s - quotient * s;
        old_s = temp_s;
    }

    if (old_r != 1) return null; // No inverse exists (not coprime)

    if (old_s < 0) old_s += m;
    return old_s;
}

pub fn builtin_gf_pow(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gf^ a n) - exponentiation in GF(p): a^n mod p
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const a = getGfComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;
    if (args.items[1].* != .number) return BuiltinError.InvalidArgument;

    var n: i64 = @intFromFloat(args.items[1].number);
    const p = a.p;

    if (n < 0) {
        // Negative exponent: a^(-n) = (a^(-1))^n
        const inv = modInverse(a.value, p) orelse return BuiltinError.InvalidArgument;
        n = -n;
        const result = modPow(inv, @intCast(n), p);
        return makeGfElement(env.allocator, result, p);
    }

    const result = modPow(a.value, @intCast(n), p);
    return makeGfElement(env.allocator, result, p);
}

/// Modular exponentiation using binary method
fn modPow(base: i64, exp: u64, m: i64) i64 {
    if (m == 1) return 0;

    var result: i64 = 1;
    var b = @mod(base, m);
    var e = exp;

    while (e > 0) {
        if (e & 1 == 1) {
            result = @mod(result * b, m);
        }
        e >>= 1;
        b = @mod(b * b, m);
    }

    return result;
}

pub fn builtin_gf_inv(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gf-inv a) - multiplicative inverse in GF(p)
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const a = getGfComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;

    if (a.value == 0) return BuiltinError.InvalidArgument; // 0 has no inverse

    const inv = modInverse(a.value, a.p) orelse return BuiltinError.InvalidArgument;

    return makeGfElement(env.allocator, inv, a.p);
}

pub fn builtin_gf_neg(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (gf-neg a) - additive inverse in GF(p)
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const a = getGfComponents(args.items[0]) orelse return BuiltinError.InvalidArgument;

    return makeGfElement(env.allocator, -a.value, a.p);
}

// ============================================================================
// Special Functions (Gamma, Beta, Error Function, Bessel)
// ============================================================================

/// Lanczos approximation coefficients for gamma function
const lanczos_g = 7;
const lanczos_coefficients = [_]f64{
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
};

/// Compute gamma function using Lanczos approximation
fn gammaLanczos(z: f64) f64 {
    if (z < 0.5) {
        // Use reflection formula: Gamma(1-z) * Gamma(z) = pi / sin(pi*z)
        return std.math.pi / (@sin(std.math.pi * z) * gammaLanczos(1.0 - z));
    }

    const z_adj = z - 1.0;
    var x = lanczos_coefficients[0];
    for (1..lanczos_coefficients.len) |i| {
        x += lanczos_coefficients[i] / (z_adj + @as(f64, @floatFromInt(i)));
    }

    const t = z_adj + @as(f64, lanczos_g) + 0.5;
    return @sqrt(2.0 * std.math.pi) * std.math.pow(f64, t, z_adj + 0.5) * @exp(-t) * x;
}

pub fn builtin_gamma(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const z = args.items[0].number;
        // Check for poles (non-positive integers)
        if (z <= 0 and @floor(z) == z) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = gammaLanczos(z) };
        return result;
    }

    // Symbolic case
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "gamma" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_beta(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // Beta(a, b) = Gamma(a) * Gamma(b) / Gamma(a + b)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number and args.items[1].* == .number) {
        const a = args.items[0].number;
        const b = args.items[1].number;
        if (a <= 0 or b <= 0) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = gammaLanczos(a) * gammaLanczos(b) / gammaLanczos(a + b) };
        return result;
    }

    // Symbolic case
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "beta" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

/// Error function approximation using Horner's method
fn erfApprox(x: f64) f64 {
    // Abramowitz and Stegun approximation 7.1.26
    const a1: f64 = 0.254829592;
    const a2: f64 = -0.284496736;
    const a3: f64 = 1.421413741;
    const a4: f64 = -1.453152027;
    const a5: f64 = 1.061405429;
    const p: f64 = 0.3275911;

    const sign: f64 = if (x < 0) -1.0 else 1.0;
    const abs_x = @abs(x);

    const t = 1.0 / (1.0 + p * abs_x);
    const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * @exp(-abs_x * abs_x);

    return sign * y;
}

pub fn builtin_erf(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = erfApprox(args.items[0].number) };
        return result;
    }

    // Symbolic case
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "erf" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_erfc(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // erfc(x) = 1 - erf(x)
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 1.0 - erfApprox(args.items[0].number) };
        return result;
    }

    // Symbolic case
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "erfc" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

/// Bessel function J_n(x) of the first kind using series expansion
fn besselJ(n: i32, x: f64) f64 {
    if (x == 0) {
        return if (n == 0) 1.0 else 0.0;
    }

    const n_f: f64 = @floatFromInt(n);

    // Series expansion: J_n(x) = (x/2)^n * sum_{k=0}^inf (-1)^k * (x/2)^{2k} / (k! * (n+k)!)
    var sum: f64 = 0.0;
    var term: f64 = 1.0 / gammaLanczos(n_f + 1.0);
    const half_x = x / 2.0;
    const half_x_sq = half_x * half_x;

    var k: i32 = 0;
    while (k < 100) : (k += 1) {
        sum += term;
        const k_f: f64 = @floatFromInt(k);
        term *= -half_x_sq / ((k_f + 1.0) * (n_f + k_f + 1.0));
        if (@abs(term) < 1e-15 * @abs(sum)) break;
    }

    return std.math.pow(f64, half_x, n_f) * sum;
}

/// Bessel function Y_n(x) of the second kind
fn besselY(n: i32, x: f64) f64 {
    if (x <= 0) return std.math.nan(f64);

    // For integer order: Y_n(x) = (J_n(x)*cos(n*pi) - J_{-n}(x)) / sin(n*pi)
    // This limit gives the correct result
    // Using Neumann's formula for integer n
    const euler_gamma = 0.5772156649015329;

    if (n == 0) {
        // Y_0(x) approximation
        return (2.0 / std.math.pi) * ((@log(x / 2.0) + euler_gamma) * besselJ(0, x) - besselY0Series(x));
    }

    // General formula using recurrence
    var y_prev = besselY0Approx(x);
    var y_curr = besselY1Approx(x);

    if (n == 0) return y_prev;
    if (n == 1) return y_curr;

    var i: i32 = 1;
    while (i < n) : (i += 1) {
        const i_f: f64 = @floatFromInt(i);
        const y_next = (2.0 * i_f / x) * y_curr - y_prev;
        y_prev = y_curr;
        y_curr = y_next;
    }

    return y_curr;
}

fn besselY0Series(x: f64) f64 {
    // Series for the non-logarithmic part of Y_0
    var sum: f64 = 0.0;
    var term: f64 = 1.0;
    const half_x_sq = (x / 2.0) * (x / 2.0);
    var harmonic: f64 = 0.0;

    var k: i32 = 1;
    while (k < 50) : (k += 1) {
        const k_f: f64 = @floatFromInt(k);
        harmonic += 1.0 / k_f;
        term *= -half_x_sq / (k_f * k_f);
        sum += term * harmonic;
    }

    return sum;
}

fn besselY0Approx(x: f64) f64 {
    const euler_gamma = 0.5772156649015329;
    return (2.0 / std.math.pi) * ((@log(x / 2.0) + euler_gamma) * besselJ(0, x)) - (2.0 / std.math.pi) * besselY0Series(x);
}

fn besselY1Approx(x: f64) f64 {
    // Use recurrence from Y_0
    // Y_1(x) can be computed from derivative relationship
    const h = 1e-6;
    return (besselY0Approx(x + h) - besselY0Approx(x - h)) / (2.0 * h) + besselJ(0, x) / x;
}

pub fn builtin_besselj(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (besselj n x) - Bessel function of first kind
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number and args.items[1].* == .number) {
        const n = args.items[0].number;
        const x = args.items[1].number;
        const n_int: i32 = @intFromFloat(n);
        if (@as(f64, @floatFromInt(n_int)) != n) return BuiltinError.InvalidArgument; // n must be integer
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = besselJ(n_int, x) };
        return result;
    }

    // Symbolic case
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "besselj" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_bessely(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (bessely n x) - Bessel function of second kind
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number and args.items[1].* == .number) {
        const n = args.items[0].number;
        const x = args.items[1].number;
        const n_int: i32 = @intFromFloat(n);
        if (@as(f64, @floatFromInt(n_int)) != n) return BuiltinError.InvalidArgument;
        if (x <= 0) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = besselY(n_int, x) };
        return result;
    }

    // Symbolic case
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "bessely" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

/// Digamma function (psi) - derivative of ln(Gamma)
fn digamma(x: f64) f64 {
    if (x <= 0 and @floor(x) == x) return std.math.nan(f64);

    // For small x, use recurrence: psi(x+1) = psi(x) + 1/x
    var result: f64 = 0.0;
    var z = x;

    while (z < 6) {
        result -= 1.0 / z;
        z += 1.0;
    }

    // Asymptotic expansion for large z
    const z2 = z * z;
    result += @log(z) - 1.0 / (2.0 * z) - 1.0 / (12.0 * z2) + 1.0 / (120.0 * z2 * z2);

    return result;
}

pub fn builtin_digamma(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    if (args.items[0].* == .number) {
        const x = args.items[0].number;
        if (x <= 0 and @floor(x) == x) return BuiltinError.InvalidArgument;
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = digamma(x) };
        return result;
    }

    // Symbolic case
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "digamma" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;
    const copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

// ============================================================================
// LaTeX Output Export
// ============================================================================

pub fn builtin_latex(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (latex expr) - converts expression to LaTeX string
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(env.allocator);

    exprToLatex(args.items[0], &buf, env.allocator) catch return BuiltinError.OutOfMemory;

    // Create owned_symbol expression with the LaTeX string
    // Using owned_symbol ensures the string is freed on deinit
    const latex_str = buf.toOwnedSlice(env.allocator) catch return BuiltinError.OutOfMemory;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .owned_symbol = latex_str };
    return result;
}

const LatexError = error{OutOfMemory};

fn exprToLatex(expr: *const Expr, buf: *std.ArrayList(u8), allocator: std.mem.Allocator) LatexError!void {
    switch (expr.*) {
        .number => |n| {
            // Format number, removing trailing zeros for integers
            var num_buf: [64]u8 = undefined;
            const n_int: i64 = @intFromFloat(n);
            if (@as(f64, @floatFromInt(n_int)) == n) {
                const formatted = std.fmt.bufPrint(&num_buf, "{d}", .{n_int}) catch return error.OutOfMemory;
                buf.appendSlice(allocator, formatted) catch return error.OutOfMemory;
            } else {
                const formatted = std.fmt.bufPrint(&num_buf, "{d}", .{n}) catch return error.OutOfMemory;
                buf.appendSlice(allocator, formatted) catch return error.OutOfMemory;
            }
        },
        .symbol, .owned_symbol => |s| {
            // Handle special symbols
            if (std.mem.eql(u8, s, "pi")) {
                buf.appendSlice(allocator, "\\pi") catch return error.OutOfMemory;
            } else if (std.mem.eql(u8, s, "e")) {
                buf.appendSlice(allocator, "e") catch return error.OutOfMemory;
            } else if (std.mem.eql(u8, s, "inf")) {
                buf.appendSlice(allocator, "\\infty") catch return error.OutOfMemory;
            } else if (s.len == 1) {
                // Single letter variables stay as-is
                buf.appendSlice(allocator, s) catch return error.OutOfMemory;
            } else {
                // Multi-letter symbols use \text{}
                buf.appendSlice(allocator, "\\text{") catch return error.OutOfMemory;
                buf.appendSlice(allocator, s) catch return error.OutOfMemory;
                buf.appendSlice(allocator, "}") catch return error.OutOfMemory;
            }
        },
        .lambda => {
            buf.appendSlice(allocator, "\\lambda") catch return error.OutOfMemory;
        },
        .list => |lst| {
            if (lst.items.len == 0) {
                buf.appendSlice(allocator, "()") catch return error.OutOfMemory;
                return;
            }

            const op = lst.items[0];
            if (op.* == .symbol) {
                const op_name = op.symbol;

                // Binary operators
                if (std.mem.eql(u8, op_name, "+")) {
                    if (lst.items.len > 1) {
                        try exprToLatex(lst.items[1], buf, allocator);
                        for (lst.items[2..]) |arg| {
                            buf.appendSlice(allocator, " + ") catch return error.OutOfMemory;
                            try exprToLatex(arg, buf, allocator);
                        }
                    }
                } else if (std.mem.eql(u8, op_name, "-")) {
                    if (lst.items.len == 2) {
                        buf.appendSlice(allocator, "-") catch return error.OutOfMemory;
                        try exprToLatex(lst.items[1], buf, allocator);
                    } else if (lst.items.len > 2) {
                        try exprToLatex(lst.items[1], buf, allocator);
                        for (lst.items[2..]) |arg| {
                            buf.appendSlice(allocator, " - ") catch return error.OutOfMemory;
                            try exprToLatex(arg, buf, allocator);
                        }
                    }
                } else if (std.mem.eql(u8, op_name, "*")) {
                    if (lst.items.len > 1) {
                        try wrapIfNeeded(lst.items[1], buf, allocator);
                        for (lst.items[2..]) |arg| {
                            buf.appendSlice(allocator, " \\cdot ") catch return error.OutOfMemory;
                            try wrapIfNeeded(arg, buf, allocator);
                        }
                    }
                } else if (std.mem.eql(u8, op_name, "/")) {
                    if (lst.items.len == 3) {
                        buf.appendSlice(allocator, "\\frac{") catch return error.OutOfMemory;
                        try exprToLatex(lst.items[1], buf, allocator);
                        buf.appendSlice(allocator, "}{") catch return error.OutOfMemory;
                        try exprToLatex(lst.items[2], buf, allocator);
                        buf.appendSlice(allocator, "}") catch return error.OutOfMemory;
                    }
                } else if (std.mem.eql(u8, op_name, "^")) {
                    if (lst.items.len == 3) {
                        try wrapIfNeeded(lst.items[1], buf, allocator);
                        buf.appendSlice(allocator, "^{") catch return error.OutOfMemory;
                        try exprToLatex(lst.items[2], buf, allocator);
                        buf.appendSlice(allocator, "}") catch return error.OutOfMemory;
                    }
                }
                // Functions
                else if (std.mem.eql(u8, op_name, "sqrt")) {
                    buf.appendSlice(allocator, "\\sqrt{") catch return error.OutOfMemory;
                    if (lst.items.len > 1) try exprToLatex(lst.items[1], buf, allocator);
                    buf.appendSlice(allocator, "}") catch return error.OutOfMemory;
                } else if (std.mem.eql(u8, op_name, "sin") or std.mem.eql(u8, op_name, "cos") or
                    std.mem.eql(u8, op_name, "tan") or std.mem.eql(u8, op_name, "ln") or
                    std.mem.eql(u8, op_name, "exp") or std.mem.eql(u8, op_name, "log"))
                {
                    buf.appendSlice(allocator, "\\") catch return error.OutOfMemory;
                    buf.appendSlice(allocator, op_name) catch return error.OutOfMemory;
                    buf.appendSlice(allocator, "{") catch return error.OutOfMemory;
                    if (lst.items.len > 1) try exprToLatex(lst.items[1], buf, allocator);
                    buf.appendSlice(allocator, "}") catch return error.OutOfMemory;
                }
                // Matrix
                else if (std.mem.eql(u8, op_name, "matrix")) {
                    buf.appendSlice(allocator, "\\begin{pmatrix}") catch return error.OutOfMemory;
                    for (lst.items[1..], 0..) |row, i| {
                        if (i > 0) buf.appendSlice(allocator, " \\\\ ") catch return error.OutOfMemory;
                        if (row.* == .list) {
                            for (row.list.items, 0..) |elem, j| {
                                if (j > 0) buf.appendSlice(allocator, " & ") catch return error.OutOfMemory;
                                try exprToLatex(elem, buf, allocator);
                            }
                        }
                    }
                    buf.appendSlice(allocator, "\\end{pmatrix}") catch return error.OutOfMemory;
                }
                // Vector
                else if (std.mem.eql(u8, op_name, "vector")) {
                    buf.appendSlice(allocator, "\\begin{pmatrix}") catch return error.OutOfMemory;
                    for (lst.items[1..], 0..) |elem, i| {
                        if (i > 0) buf.appendSlice(allocator, " \\\\ ") catch return error.OutOfMemory;
                        try exprToLatex(elem, buf, allocator);
                    }
                    buf.appendSlice(allocator, "\\end{pmatrix}") catch return error.OutOfMemory;
                }
                // Complex number
                else if (std.mem.eql(u8, op_name, "complex")) {
                    if (lst.items.len == 3) {
                        try exprToLatex(lst.items[1], buf, allocator);
                        if (lst.items[2].* == .number and lst.items[2].number >= 0) {
                            buf.appendSlice(allocator, " + ") catch return error.OutOfMemory;
                        }
                        try exprToLatex(lst.items[2], buf, allocator);
                        buf.appendSlice(allocator, "i") catch return error.OutOfMemory;
                    }
                }
                // Integral
                else if (std.mem.eql(u8, op_name, "integrate")) {
                    buf.appendSlice(allocator, "\\int ") catch return error.OutOfMemory;
                    if (lst.items.len > 1) try exprToLatex(lst.items[1], buf, allocator);
                    buf.appendSlice(allocator, " \\, d") catch return error.OutOfMemory;
                    if (lst.items.len > 2 and lst.items[2].* == .symbol) {
                        buf.appendSlice(allocator, lst.items[2].symbol) catch return error.OutOfMemory;
                    } else {
                        buf.appendSlice(allocator, "x") catch return error.OutOfMemory;
                    }
                }
                // Derivative
                else if (std.mem.eql(u8, op_name, "diff")) {
                    buf.appendSlice(allocator, "\\frac{d}{d") catch return error.OutOfMemory;
                    if (lst.items.len > 2 and lst.items[2].* == .symbol) {
                        buf.appendSlice(allocator, lst.items[2].symbol) catch return error.OutOfMemory;
                    } else {
                        buf.appendSlice(allocator, "x") catch return error.OutOfMemory;
                    }
                    buf.appendSlice(allocator, "}\\left(") catch return error.OutOfMemory;
                    if (lst.items.len > 1) try exprToLatex(lst.items[1], buf, allocator);
                    buf.appendSlice(allocator, "\\right)") catch return error.OutOfMemory;
                }
                // Sum
                else if (std.mem.eql(u8, op_name, "sum")) {
                    buf.appendSlice(allocator, "\\sum ") catch return error.OutOfMemory;
                    if (lst.items.len > 1) try exprToLatex(lst.items[1], buf, allocator);
                }
                // Default: function notation
                else {
                    buf.appendSlice(allocator, "\\text{") catch return error.OutOfMemory;
                    buf.appendSlice(allocator, op_name) catch return error.OutOfMemory;
                    buf.appendSlice(allocator, "}(") catch return error.OutOfMemory;
                    for (lst.items[1..], 0..) |arg, i| {
                        if (i > 0) buf.appendSlice(allocator, ", ") catch return error.OutOfMemory;
                        try exprToLatex(arg, buf, allocator);
                    }
                    buf.appendSlice(allocator, ")") catch return error.OutOfMemory;
                }
            } else {
                // Non-symbol first element
                buf.appendSlice(allocator, "(") catch return error.OutOfMemory;
                for (lst.items, 0..) |item, i| {
                    if (i > 0) buf.appendSlice(allocator, " ") catch return error.OutOfMemory;
                    try exprToLatex(item, buf, allocator);
                }
                buf.appendSlice(allocator, ")") catch return error.OutOfMemory;
            }
        },
    }
}

fn wrapIfNeeded(expr: *const Expr, buf: *std.ArrayList(u8), allocator: std.mem.Allocator) LatexError!void {
    // Wrap in parentheses if it's an addition/subtraction
    const needs_wrap = expr.* == .list and expr.list.items.len > 0 and
        expr.list.items[0].* == .symbol and
        (std.mem.eql(u8, expr.list.items[0].symbol, "+") or std.mem.eql(u8, expr.list.items[0].symbol, "-"));

    if (needs_wrap) buf.appendSlice(allocator, "\\left(") catch return error.OutOfMemory;
    try exprToLatex(expr, buf, allocator);
    if (needs_wrap) buf.appendSlice(allocator, "\\right)") catch return error.OutOfMemory;
}

// ============================================================================
// Differential Equation Solver (dsolve)
// ============================================================================

pub fn builtin_dsolve(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (dsolve ode y x) - solve ODE for y(x)
    // ODE format: (= (diff y x) rhs) where rhs is dy/dx
    // Or: (= (+ (diff y x) (* P y)) Q) for first-order linear
    if (args.items.len < 3) return BuiltinError.InvalidArgument;

    const ode = args.items[0];
    const y_var = args.items[1];
    const x_var = args.items[2];

    if (y_var.* != .symbol and y_var.* != .owned_symbol) return BuiltinError.InvalidArgument;
    if (x_var.* != .symbol and x_var.* != .owned_symbol) return BuiltinError.InvalidArgument;

    const y_name = if (y_var.* == .symbol) y_var.symbol else y_var.owned_symbol;
    const x_name = if (x_var.* == .symbol) x_var.symbol else x_var.owned_symbol;

    // Check if it's an equation (= lhs rhs)
    if (ode.* == .list and ode.list.items.len == 3) {
        const op = ode.list.items[0];
        if (op.* == .symbol and std.mem.eql(u8, op.symbol, "=")) {
            const lhs = ode.list.items[1];
            const rhs = ode.list.items[2];

            // Check if lhs is (diff y x) - i.e., y' = f(x,y)
            if (isDiffExpr(lhs, y_name, x_name)) {
                // dy/dx = rhs
                return solveDifferentialEquation(rhs, y_name, x_name, env);
            }
        }
    }

    // If not recognized, return symbolic form
    return createSymbolicDsolve(ode, y_var, x_var, env);
}

fn isDiffExpr(expr: *const Expr, y_name: []const u8, x_name: []const u8) bool {
    if (expr.* != .list) return false;
    const lst = expr.list;
    if (lst.items.len != 3) return false;
    const op = lst.items[0];
    if (op.* != .symbol) return false;
    if (!std.mem.eql(u8, op.symbol, "diff")) return false;

    // Check it's diff of y with respect to x
    const arg1 = lst.items[1];
    const arg2 = lst.items[2];
    if (arg1.* != .symbol) return false;
    if (arg2.* != .symbol) return false;
    return std.mem.eql(u8, arg1.symbol, y_name) and std.mem.eql(u8, arg2.symbol, x_name);
}

fn solveDifferentialEquation(rhs: *const Expr, y_name: []const u8, x_name: []const u8, env: *Env) BuiltinError!*Expr {
    // Check if RHS contains y (dependent variable)
    const contains_y = symbolic.containsVariable(rhs, y_name);

    if (!contains_y) {
        // dy/dx = f(x) - simple integration
        // Solution: y = integral(f(x), x) + C
        return solveByDirectIntegration(rhs, y_name, x_name, env);
    }

    // Try separable: dy/dx = f(x) * g(y)
    if (trySeparable(rhs, y_name, x_name, env)) |solution| {
        return solution;
    }

    // Try first-order linear: dy/dx = P(x)*y + Q(x) => dy/dx - P*y = Q
    if (tryLinearFirstOrder(rhs, y_name, x_name, env)) |solution| {
        return solution;
    }

    // Can't solve, return symbolic
    return createSymbolicResult(rhs, y_name, x_name, env);
}

fn solveByDirectIntegration(rhs: *const Expr, y_name: []const u8, x_name: []const u8, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    // y = integral(rhs, x) + C
    const integrated = symbolic.integrate(rhs, x_name, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        integrated.deinit(allocator);
        allocator.destroy(integrated);
    }

    // Create: (+ integral C)
    var result_list: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (result_list.items) |item| {
            item.deinit(allocator);
            allocator.destroy(item);
        }
        result_list.deinit(allocator);
    }

    const plus_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plus_op.* = .{ .symbol = "+" };
    result_list.append(allocator, plus_op) catch return BuiltinError.OutOfMemory;

    const integrated_copy = symbolic.copyExpr(integrated, allocator) catch return BuiltinError.OutOfMemory;
    result_list.append(allocator, integrated_copy) catch return BuiltinError.OutOfMemory;

    const c_const = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    c_const.* = .{ .symbol = "C" };
    result_list.append(allocator, c_const) catch return BuiltinError.OutOfMemory;

    const solution_rhs = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    solution_rhs.* = .{ .list = result_list };

    // Simplify the result
    const simplified = symbolic.simplify(solution_rhs, allocator) catch return BuiltinError.OutOfMemory;
    solution_rhs.deinit(allocator);
    allocator.destroy(solution_rhs);

    // Create equation: (= y solution)
    return createEquation(y_name, simplified, env);
}

fn trySeparable(rhs: *const Expr, y_name: []const u8, x_name: []const u8, env: *Env) ?*Expr {
    // Check if rhs is f(x) * g(y) or f(x) / h(y)
    if (rhs.* != .list) return null;
    const lst = rhs.list;
    if (lst.items.len != 3) return null;

    const op = lst.items[0];
    if (op.* != .symbol) return null;

    if (std.mem.eql(u8, op.symbol, "*")) {
        // dy/dx = f(x) * g(y)
        const arg1 = lst.items[1];
        const arg2 = lst.items[2];

        const arg1_has_y = symbolic.containsVariable(arg1, y_name);
        const arg1_has_x = symbolic.containsVariable(arg1, x_name);
        const arg2_has_y = symbolic.containsVariable(arg2, y_name);
        const arg2_has_x = symbolic.containsVariable(arg2, x_name);

        if (!arg1_has_y and arg1_has_x and arg2_has_y and !arg2_has_x) {
            // f(x) = arg1, g(y) = arg2
            // Solution: integral(1/g(y), y) = integral(f(x), x) + C
            return solveSeparable(arg1, arg2, y_name, x_name, env) catch return null;
        } else if (arg1_has_y and !arg1_has_x and !arg2_has_y and arg2_has_x) {
            // f(x) = arg2, g(y) = arg1
            return solveSeparable(arg2, arg1, y_name, x_name, env) catch return null;
        }
    } else if (std.mem.eql(u8, op.symbol, "/")) {
        // dy/dx = f(x) / h(y) => h(y) dy = f(x) dx
        const arg1 = lst.items[1];
        const arg2 = lst.items[2];

        const arg1_has_y = symbolic.containsVariable(arg1, y_name);
        const arg2_has_y = symbolic.containsVariable(arg2, y_name);
        const arg1_has_x = symbolic.containsVariable(arg1, x_name);
        const arg2_has_x = symbolic.containsVariable(arg2, x_name);

        if (!arg1_has_y and arg1_has_x and arg2_has_y and !arg2_has_x) {
            // f(x) = arg1, h(y) = arg2
            // integral(h(y), y) = integral(f(x), x) + C
            return solveSeparableDiv(arg1, arg2, y_name, x_name, env) catch return null;
        }
    }

    return null;
}

fn solveSeparable(fx: *const Expr, gy: *const Expr, y_name: []const u8, x_name: []const u8, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    // Solution: integral(1/g(y), y) = integral(f(x), x) + C
    // Create 1/g(y)
    var one_over_gy_list: std.ArrayList(*Expr) = .empty;
    const div_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    div_op.* = .{ .symbol = "/" };
    one_over_gy_list.append(allocator, div_op) catch return BuiltinError.OutOfMemory;

    const one = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    one.* = .{ .number = 1 };
    one_over_gy_list.append(allocator, one) catch return BuiltinError.OutOfMemory;

    const gy_copy = symbolic.copyExpr(gy, allocator) catch return BuiltinError.OutOfMemory;
    one_over_gy_list.append(allocator, gy_copy) catch return BuiltinError.OutOfMemory;

    const one_over_gy = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    one_over_gy.* = .{ .list = one_over_gy_list };
    defer {
        one_over_gy.deinit(allocator);
        allocator.destroy(one_over_gy);
    }

    // Integrate both sides
    const lhs_int = symbolic.integrate(one_over_gy, y_name, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        lhs_int.deinit(allocator);
        allocator.destroy(lhs_int);
    }

    const rhs_int = symbolic.integrate(fx, x_name, allocator) catch return BuiltinError.OutOfMemory;

    // Build equation: lhs_int = rhs_int + C
    var rhs_plus_c: std.ArrayList(*Expr) = .empty;
    const plus_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plus_op.* = .{ .symbol = "+" };
    rhs_plus_c.append(allocator, plus_op) catch return BuiltinError.OutOfMemory;
    rhs_plus_c.append(allocator, rhs_int) catch return BuiltinError.OutOfMemory;

    const c_const = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    c_const.* = .{ .symbol = "C" };
    rhs_plus_c.append(allocator, c_const) catch return BuiltinError.OutOfMemory;

    const rhs_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    rhs_expr.* = .{ .list = rhs_plus_c };

    // Simplify both sides
    const lhs_simp = symbolic.simplify(symbolic.copyExpr(lhs_int, allocator) catch return BuiltinError.OutOfMemory, allocator) catch return BuiltinError.OutOfMemory;
    const rhs_simp = symbolic.simplify(rhs_expr, allocator) catch return BuiltinError.OutOfMemory;

    // Build final equation
    var eq_list: std.ArrayList(*Expr) = .empty;
    const eq_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    eq_op.* = .{ .symbol = "=" };
    eq_list.append(allocator, eq_op) catch return BuiltinError.OutOfMemory;
    eq_list.append(allocator, lhs_simp) catch return BuiltinError.OutOfMemory;
    eq_list.append(allocator, rhs_simp) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = eq_list };
    return result;
}

fn solveSeparableDiv(fx: *const Expr, hy: *const Expr, y_name: []const u8, x_name: []const u8, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    // dy/dx = f(x)/h(y) => h(y) dy = f(x) dx
    // integral(h(y), y) = integral(f(x), x) + C

    const lhs_int = symbolic.integrate(hy, y_name, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        lhs_int.deinit(allocator);
        allocator.destroy(lhs_int);
    }

    const rhs_int = symbolic.integrate(fx, x_name, allocator) catch return BuiltinError.OutOfMemory;

    // Build equation: lhs_int = rhs_int + C
    var rhs_plus_c: std.ArrayList(*Expr) = .empty;
    const plus_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plus_op.* = .{ .symbol = "+" };
    rhs_plus_c.append(allocator, plus_op) catch return BuiltinError.OutOfMemory;
    rhs_plus_c.append(allocator, rhs_int) catch return BuiltinError.OutOfMemory;

    const c_const = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    c_const.* = .{ .symbol = "C" };
    rhs_plus_c.append(allocator, c_const) catch return BuiltinError.OutOfMemory;

    const rhs_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    rhs_expr.* = .{ .list = rhs_plus_c };

    // Simplify
    const lhs_simp = symbolic.simplify(symbolic.copyExpr(lhs_int, allocator) catch return BuiltinError.OutOfMemory, allocator) catch return BuiltinError.OutOfMemory;
    const rhs_simp = symbolic.simplify(rhs_expr, allocator) catch return BuiltinError.OutOfMemory;

    var eq_list: std.ArrayList(*Expr) = .empty;
    const eq_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    eq_op.* = .{ .symbol = "=" };
    eq_list.append(allocator, eq_op) catch return BuiltinError.OutOfMemory;
    eq_list.append(allocator, lhs_simp) catch return BuiltinError.OutOfMemory;
    eq_list.append(allocator, rhs_simp) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = eq_list };
    return result;
}

fn tryLinearFirstOrder(rhs: *const Expr, y_name: []const u8, x_name: []const u8, env: *Env) ?*Expr {
    // dy/dx = a*y + f(x) where a may be a function of x
    // Try to extract linear term
    if (rhs.* != .list) {
        // Check if it's just a*y
        if (rhs.* == .symbol and std.mem.eql(u8, rhs.symbol, y_name)) {
            // dy/dx = y => y = C*e^x
            return solveLinearHomogeneous(null, y_name, x_name, env) catch return null;
        }
        return null;
    }

    const lst = rhs.list;
    if (lst.items.len < 2) return null;

    const op = lst.items[0];
    if (op.* != .symbol) return null;

    if (std.mem.eql(u8, op.symbol, "*") and lst.items.len == 3) {
        // dy/dx = a * y (where a might be constant or function of x)
        const arg1 = lst.items[1];
        const arg2 = lst.items[2];

        const arg1_is_y = (arg1.* == .symbol and std.mem.eql(u8, arg1.symbol, y_name));
        const arg2_is_y = (arg2.* == .symbol and std.mem.eql(u8, arg2.symbol, y_name));

        if (arg2_is_y and !symbolic.containsVariable(arg1, y_name)) {
            // dy/dx = a(x) * y
            return solveLinearHomogeneous(arg1, y_name, x_name, env) catch return null;
        } else if (arg1_is_y and !symbolic.containsVariable(arg2, y_name)) {
            // dy/dx = y * a(x)
            return solveLinearHomogeneous(arg2, y_name, x_name, env) catch return null;
        }
    } else if (std.mem.eql(u8, op.symbol, "+") and lst.items.len == 3) {
        // dy/dx = a*y + f(x)
        const arg1 = lst.items[1];
        const arg2 = lst.items[2];

        // Check which term contains y
        const coeff1 = extractLinearCoeff(arg1, y_name);
        const coeff2 = extractLinearCoeff(arg2, y_name);

        if (coeff1 != null and !symbolic.containsVariable(arg2, y_name)) {
            // dy/dx = coeff1*y + arg2
            return solveLinearNonhomogeneous(coeff1.?, arg2, y_name, x_name, env) catch return null;
        } else if (coeff2 != null and !symbolic.containsVariable(arg1, y_name)) {
            // dy/dx = arg1 + coeff2*y
            return solveLinearNonhomogeneous(coeff2.?, arg1, y_name, x_name, env) catch return null;
        }
    }

    return null;
}

fn extractLinearCoeff(expr: *const Expr, y_name: []const u8) ?*const Expr {
    // Extract a from a*y
    if (expr.* == .symbol and std.mem.eql(u8, expr.symbol, y_name)) {
        return null; // coefficient is 1, but we'd need to create it
    }

    if (expr.* != .list) return null;
    const lst = expr.list;
    if (lst.items.len != 3) return null;

    const op = lst.items[0];
    if (op.* != .symbol or !std.mem.eql(u8, op.symbol, "*")) return null;

    const arg1 = lst.items[1];
    const arg2 = lst.items[2];

    const arg1_is_y = (arg1.* == .symbol and std.mem.eql(u8, arg1.symbol, y_name));
    const arg2_is_y = (arg2.* == .symbol and std.mem.eql(u8, arg2.symbol, y_name));

    if (arg2_is_y and !symbolic.containsVariable(arg1, y_name)) {
        return arg1;
    } else if (arg1_is_y and !symbolic.containsVariable(arg2, y_name)) {
        return arg2;
    }

    return null;
}

fn solveLinearHomogeneous(a_coeff: ?*const Expr, y_name: []const u8, x_name: []const u8, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    // dy/dx = a(x)*y => y = C * e^(integral(a, x))
    var integral_a: *Expr = undefined;

    if (a_coeff) |a| {
        integral_a = symbolic.integrate(a, x_name, allocator) catch return BuiltinError.OutOfMemory;
    } else {
        // a = 1, integral = x
        integral_a = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        integral_a.* = .{ .symbol = x_name };
    }
    defer {
        integral_a.deinit(allocator);
        allocator.destroy(integral_a);
    }

    // Build: C * e^(integral_a)
    var exp_list: std.ArrayList(*Expr) = .empty;
    const exp_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    exp_op.* = .{ .symbol = "exp" };
    exp_list.append(allocator, exp_op) catch return BuiltinError.OutOfMemory;

    const integral_copy = symbolic.copyExpr(integral_a, allocator) catch return BuiltinError.OutOfMemory;
    exp_list.append(allocator, integral_copy) catch return BuiltinError.OutOfMemory;

    const exp_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    exp_expr.* = .{ .list = exp_list };

    var mult_list: std.ArrayList(*Expr) = .empty;
    const mult_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    mult_op.* = .{ .symbol = "*" };
    mult_list.append(allocator, mult_op) catch return BuiltinError.OutOfMemory;

    const c_const = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    c_const.* = .{ .symbol = "C" };
    mult_list.append(allocator, c_const) catch return BuiltinError.OutOfMemory;
    mult_list.append(allocator, exp_expr) catch return BuiltinError.OutOfMemory;

    const solution = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    solution.* = .{ .list = mult_list };

    // Simplify
    const simplified = symbolic.simplify(solution, allocator) catch return BuiltinError.OutOfMemory;

    return createEquation(y_name, simplified, env);
}

fn solveLinearNonhomogeneous(a_coeff: *const Expr, fx: *const Expr, y_name: []const u8, x_name: []const u8, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    // dy/dx = a*y + f(x)
    // Solution: y = e^(A) * (C + integral(f(x)*e^(-A), x)) where A = integral(a, x)

    // Compute A = integral(a, x)
    const A = symbolic.integrate(a_coeff, x_name, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        A.deinit(allocator);
        allocator.destroy(A);
    }

    // Build e^A and e^(-A)
    var exp_A_list: std.ArrayList(*Expr) = .empty;
    const exp_op1 = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    exp_op1.* = .{ .symbol = "exp" };
    exp_A_list.append(allocator, exp_op1) catch return BuiltinError.OutOfMemory;
    const A_copy = symbolic.copyExpr(A, allocator) catch return BuiltinError.OutOfMemory;
    exp_A_list.append(allocator, A_copy) catch return BuiltinError.OutOfMemory;

    const exp_A = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    exp_A.* = .{ .list = exp_A_list };

    // Build -A
    var neg_A_list: std.ArrayList(*Expr) = .empty;
    const neg_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    neg_op.* = .{ .symbol = "-" };
    neg_A_list.append(allocator, neg_op) catch return BuiltinError.OutOfMemory;
    const zero_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    zero_expr.* = .{ .number = 0 };
    neg_A_list.append(allocator, zero_expr) catch return BuiltinError.OutOfMemory;
    const A_copy2 = symbolic.copyExpr(A, allocator) catch return BuiltinError.OutOfMemory;
    neg_A_list.append(allocator, A_copy2) catch return BuiltinError.OutOfMemory;

    const neg_A = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    neg_A.* = .{ .list = neg_A_list };

    // Build e^(-A)
    var exp_neg_A_list: std.ArrayList(*Expr) = .empty;
    const exp_op2 = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    exp_op2.* = .{ .symbol = "exp" };
    exp_neg_A_list.append(allocator, exp_op2) catch return BuiltinError.OutOfMemory;
    exp_neg_A_list.append(allocator, neg_A) catch return BuiltinError.OutOfMemory;

    const exp_neg_A = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    exp_neg_A.* = .{ .list = exp_neg_A_list };

    // Build f(x) * e^(-A)
    var fx_exp_list: std.ArrayList(*Expr) = .empty;
    const mult_op1 = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    mult_op1.* = .{ .symbol = "*" };
    fx_exp_list.append(allocator, mult_op1) catch return BuiltinError.OutOfMemory;
    const fx_copy = symbolic.copyExpr(fx, allocator) catch return BuiltinError.OutOfMemory;
    fx_exp_list.append(allocator, fx_copy) catch return BuiltinError.OutOfMemory;
    fx_exp_list.append(allocator, exp_neg_A) catch return BuiltinError.OutOfMemory;

    const fx_exp = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    fx_exp.* = .{ .list = fx_exp_list };
    defer {
        fx_exp.deinit(allocator);
        allocator.destroy(fx_exp);
    }

    // Integrate f(x)*e^(-A)
    const integral_fx = symbolic.integrate(fx_exp, x_name, allocator) catch return BuiltinError.OutOfMemory;

    // Build C + integral
    var c_plus_int_list: std.ArrayList(*Expr) = .empty;
    const plus_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plus_op.* = .{ .symbol = "+" };
    c_plus_int_list.append(allocator, plus_op) catch return BuiltinError.OutOfMemory;
    const c_const = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    c_const.* = .{ .symbol = "C" };
    c_plus_int_list.append(allocator, c_const) catch return BuiltinError.OutOfMemory;
    c_plus_int_list.append(allocator, integral_fx) catch return BuiltinError.OutOfMemory;

    const c_plus_int = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    c_plus_int.* = .{ .list = c_plus_int_list };

    // Build e^A * (C + integral)
    var final_list: std.ArrayList(*Expr) = .empty;
    const mult_op2 = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    mult_op2.* = .{ .symbol = "*" };
    final_list.append(allocator, mult_op2) catch return BuiltinError.OutOfMemory;
    final_list.append(allocator, exp_A) catch return BuiltinError.OutOfMemory;
    final_list.append(allocator, c_plus_int) catch return BuiltinError.OutOfMemory;

    const solution = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    solution.* = .{ .list = final_list };

    // Simplify
    const simplified = symbolic.simplify(solution, allocator) catch return BuiltinError.OutOfMemory;

    return createEquation(y_name, simplified, env);
}

fn createEquation(y_name: []const u8, rhs: *Expr, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    var eq_list: std.ArrayList(*Expr) = .empty;
    const eq_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    eq_op.* = .{ .symbol = "=" };
    eq_list.append(allocator, eq_op) catch return BuiltinError.OutOfMemory;

    const y_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    y_sym.* = .{ .symbol = y_name };
    eq_list.append(allocator, y_sym) catch return BuiltinError.OutOfMemory;
    eq_list.append(allocator, rhs) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = eq_list };
    return result;
}

fn createSymbolicDsolve(ode: *const Expr, y_var: *const Expr, x_var: *const Expr, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "dsolve" };
    list.append(allocator, op) catch return BuiltinError.OutOfMemory;

    const ode_copy = symbolic.copyExpr(ode, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, ode_copy) catch return BuiltinError.OutOfMemory;

    const y_copy = symbolic.copyExpr(y_var, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, y_copy) catch return BuiltinError.OutOfMemory;

    const x_copy = symbolic.copyExpr(x_var, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, x_copy) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

fn createSymbolicResult(rhs: *const Expr, y_name: []const u8, x_name: []const u8, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;
    _ = y_name;
    _ = x_name;

    // Can't solve - return symbolic (dsolve (= (diff y x) rhs) y x)
    var diff_list: std.ArrayList(*Expr) = .empty;
    const diff_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    diff_op.* = .{ .symbol = "dsolve" };
    diff_list.append(allocator, diff_op) catch return BuiltinError.OutOfMemory;

    const rhs_copy = symbolic.copyExpr(rhs, allocator) catch return BuiltinError.OutOfMemory;
    diff_list.append(allocator, rhs_copy) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = diff_list };
    return result;
}

// ============================================================================
// Fourier Series
// ============================================================================

pub fn builtin_fourier(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (fourier expr var n) - compute n-term Fourier series of expr on [-pi, pi]
    // (fourier expr var n L) - compute on [-L, L]
    // Returns: (fourier-series a0 ((a1 b1) (a2 b2) ... (an bn)))
    if (args.items.len < 3) return BuiltinError.InvalidArgument;

    const expr_arg = args.items[0];
    const var_arg = args.items[1];
    const n_arg = args.items[2];

    if (var_arg.* != .symbol and var_arg.* != .owned_symbol) return BuiltinError.InvalidArgument;
    if (n_arg.* != .number) return BuiltinError.InvalidArgument;

    const var_name = if (var_arg.* == .symbol) var_arg.symbol else var_arg.owned_symbol;
    const n: usize = @intFromFloat(n_arg.number);
    if (n == 0) return BuiltinError.InvalidArgument;

    // Get period (default to pi for [-pi, pi])
    const L: f64 = if (args.items.len > 3 and args.items[3].* == .number) args.items[3].number else std.math.pi;

    const allocator = env.allocator;

    // Compute a0 = (1/L) * integral(f(x), -L, L) / 2
    // For now, return symbolic Fourier series structure
    // In a full implementation, we would compute integrals symbolically

    // Create symbolic structure: (fourier-series a0 ((a1 b1) (a2 b2) ...))
    var result_list: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (result_list.items) |item| {
            item.deinit(allocator);
            allocator.destroy(item);
        }
        result_list.deinit(allocator);
    }

    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "fourier-series" };
    result_list.append(allocator, op) catch return BuiltinError.OutOfMemory;

    // Compute a0 coefficient (numeric approximation for now)
    // a0 = (1/L) * integral from -L to L of f(x) dx
    const a0_val = computeFourierA0(expr_arg, var_name, L, allocator, env) catch {
        // Fall back to symbolic
        return createSymbolicFourier(expr_arg, var_arg, n, L, env);
    };
    const a0_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    a0_expr.* = .{ .number = a0_val };
    result_list.append(allocator, a0_expr) catch return BuiltinError.OutOfMemory;

    // Compute coefficients list
    var coeffs_list: std.ArrayList(*Expr) = .empty;
    var i: usize = 1;
    while (i <= n) : (i += 1) {
        var pair: std.ArrayList(*Expr) = .empty;

        // Compute a_n = (1/L) * integral from -L to L of f(x)*cos(n*pi*x/L) dx
        const an_val = computeFourierAn(expr_arg, var_name, @intCast(i), L, allocator, env) catch 0;
        const an_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        an_expr.* = .{ .number = an_val };
        pair.append(allocator, an_expr) catch return BuiltinError.OutOfMemory;

        // Compute b_n = (1/L) * integral from -L to L of f(x)*sin(n*pi*x/L) dx
        const bn_val = computeFourierBn(expr_arg, var_name, @intCast(i), L, allocator, env) catch 0;
        const bn_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        bn_expr.* = .{ .number = bn_val };
        pair.append(allocator, bn_expr) catch return BuiltinError.OutOfMemory;

        const pair_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        pair_expr.* = .{ .list = pair };
        coeffs_list.append(allocator, pair_expr) catch return BuiltinError.OutOfMemory;
    }

    const coeffs_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    coeffs_expr.* = .{ .list = coeffs_list };
    result_list.append(allocator, coeffs_expr) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

fn computeFourierA0(expr: *const Expr, var_name: []const u8, L: f64, allocator: std.mem.Allocator, env: *Env) !f64 {
    // Numerical integration using Simpson's rule
    const num_points: usize = 100;
    const dx = 2.0 * L / @as(f64, @floatFromInt(num_points));
    var sum: f64 = 0;

    var i: usize = 0;
    while (i <= num_points) : (i += 1) {
        const x = -L + @as(f64, @floatFromInt(i)) * dx;
        const fx = evaluateAt(expr, var_name, x, allocator, env) catch return error.OutOfMemory;

        const weight: f64 = if (i == 0 or i == num_points) 1 else if (i % 2 == 0) 2 else 4;
        sum += weight * fx;
    }

    return (sum * dx / 3.0) / (2.0 * L);
}

fn computeFourierAn(expr: *const Expr, var_name: []const u8, n: i32, L: f64, allocator: std.mem.Allocator, env: *Env) !f64 {
    // a_n = (1/L) * integral from -L to L of f(x)*cos(n*pi*x/L) dx
    const num_points: usize = 100;
    const dx = 2.0 * L / @as(f64, @floatFromInt(num_points));
    var sum: f64 = 0;

    const n_f: f64 = @floatFromInt(n);

    var i: usize = 0;
    while (i <= num_points) : (i += 1) {
        const x = -L + @as(f64, @floatFromInt(i)) * dx;
        const fx = evaluateAt(expr, var_name, x, allocator, env) catch return error.OutOfMemory;
        const cos_term = @cos(n_f * std.math.pi * x / L);

        const weight: f64 = if (i == 0 or i == num_points) 1 else if (i % 2 == 0) 2 else 4;
        sum += weight * fx * cos_term;
    }

    return (sum * dx / 3.0) / L;
}

fn computeFourierBn(expr: *const Expr, var_name: []const u8, n: i32, L: f64, allocator: std.mem.Allocator, env: *Env) !f64 {
    // b_n = (1/L) * integral from -L to L of f(x)*sin(n*pi*x/L) dx
    const num_points: usize = 100;
    const dx = 2.0 * L / @as(f64, @floatFromInt(num_points));
    var sum: f64 = 0;

    const n_f: f64 = @floatFromInt(n);

    var i: usize = 0;
    while (i <= num_points) : (i += 1) {
        const x = -L + @as(f64, @floatFromInt(i)) * dx;
        const fx = evaluateAt(expr, var_name, x, allocator, env) catch return error.OutOfMemory;
        const sin_term = @sin(n_f * std.math.pi * x / L);

        const weight: f64 = if (i == 0 or i == num_points) 1 else if (i % 2 == 0) 2 else 4;
        sum += weight * fx * sin_term;
    }

    return (sum * dx / 3.0) / L;
}

fn evaluateAt(expr: *const Expr, var_name: []const u8, x_val: f64, allocator: std.mem.Allocator, _: *Env) !f64 {
    // Substitute x_val for var_name and evaluate
    const x_expr = allocator.create(Expr) catch return error.OutOfMemory;
    x_expr.* = .{ .number = x_val };
    defer allocator.destroy(x_expr);

    const substituted = symbolic.substitute(expr, var_name, x_expr, allocator) catch return error.OutOfMemory;
    defer {
        substituted.deinit(allocator);
        allocator.destroy(substituted);
    }

    const simplified = symbolic.simplify(substituted, allocator) catch return error.OutOfMemory;
    defer {
        simplified.deinit(allocator);
        allocator.destroy(simplified);
    }

    if (simplified.* == .number) {
        return simplified.number;
    }
    return error.OutOfMemory; // Can't evaluate to number
}

fn createSymbolicFourier(expr: *const Expr, var_arg: *const Expr, n: usize, L: f64, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "fourier" };
    list.append(allocator, op) catch return BuiltinError.OutOfMemory;

    const expr_copy = symbolic.copyExpr(expr, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, expr_copy) catch return BuiltinError.OutOfMemory;

    const var_copy = symbolic.copyExpr(var_arg, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, var_copy) catch return BuiltinError.OutOfMemory;

    const n_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    n_expr.* = .{ .number = @floatFromInt(n) };
    list.append(allocator, n_expr) catch return BuiltinError.OutOfMemory;

    const L_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    L_expr.* = .{ .number = L };
    list.append(allocator, L_expr) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

// ============================================================================
// Laplace Transform
// ============================================================================

pub fn builtin_laplace(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (laplace expr t s) - compute Laplace transform of expr from t-domain to s-domain
    // L{f(t)} = integral from 0 to inf of f(t)*e^(-st) dt
    if (args.items.len < 3) return BuiltinError.InvalidArgument;

    const expr_arg = args.items[0];
    const t_arg = args.items[1];
    const s_arg = args.items[2];

    if (t_arg.* != .symbol and t_arg.* != .owned_symbol) return BuiltinError.InvalidArgument;
    if (s_arg.* != .symbol and s_arg.* != .owned_symbol) return BuiltinError.InvalidArgument;

    const t_name = if (t_arg.* == .symbol) t_arg.symbol else t_arg.owned_symbol;
    const s_name = if (s_arg.* == .symbol) s_arg.symbol else s_arg.owned_symbol;

    const allocator = env.allocator;

    // Handle common Laplace transforms symbolically
    // L{1} = 1/s
    if (expr_arg.* == .number and expr_arg.number == 1) {
        return createDivision(makeNumber(1, allocator), makeSymbol(s_name, allocator), allocator);
    }

    // L{t} = 1/s^2
    if (expr_arg.* == .symbol and std.mem.eql(u8, expr_arg.symbol, t_name)) {
        return createDivision(makeNumber(1, allocator), createPower(makeSymbol(s_name, allocator), makeNumber(2, allocator), allocator), allocator);
    }

    // L{t^n} = n!/s^(n+1)
    if (expr_arg.* == .list and expr_arg.list.items.len == 3) {
        const op = expr_arg.list.items[0];
        if (op.* == .symbol and std.mem.eql(u8, op.symbol, "^")) {
            const base = expr_arg.list.items[1];
            const exp_arg = expr_arg.list.items[2];
            if (base.* == .symbol and std.mem.eql(u8, base.symbol, t_name) and exp_arg.* == .number) {
                const n = exp_arg.number;
                if (n == @floor(n) and n >= 0) {
                    const n_int: u64 = @intFromFloat(n);
                    const factorial = computeFactorial(n_int);
                    return createDivision(makeNumber(@floatFromInt(factorial), allocator), createPower(makeSymbol(s_name, allocator), makeNumber(n + 1, allocator), allocator), allocator);
                }
            }
        }
    }

    // L{e^(at)} = 1/(s-a)
    if (expr_arg.* == .list and expr_arg.list.items.len == 2) {
        const op = expr_arg.list.items[0];
        if (op.* == .symbol and std.mem.eql(u8, op.symbol, "exp")) {
            const inner = expr_arg.list.items[1];
            // Check if inner is a*t
            if (inner.* == .list and inner.list.items.len == 3) {
                const inner_op = inner.list.items[0];
                if (inner_op.* == .symbol and std.mem.eql(u8, inner_op.symbol, "*")) {
                    const mult1 = inner.list.items[1];
                    const mult2 = inner.list.items[2];
                    if (mult2.* == .symbol and std.mem.eql(u8, mult2.symbol, t_name) and !symbolic.containsVariable(mult1, t_name)) {
                        // e^(a*t) -> 1/(s-a)
                        return createDivision(makeNumber(1, allocator), createSubtraction(makeSymbol(s_name, allocator), symbolic.copyExpr(mult1, allocator) catch return BuiltinError.OutOfMemory, allocator), allocator);
                    } else if (mult1.* == .symbol and std.mem.eql(u8, mult1.symbol, t_name) and !symbolic.containsVariable(mult2, t_name)) {
                        // e^(t*a) -> 1/(s-a)
                        return createDivision(makeNumber(1, allocator), createSubtraction(makeSymbol(s_name, allocator), symbolic.copyExpr(mult2, allocator) catch return BuiltinError.OutOfMemory, allocator), allocator);
                    }
                }
            } else if (inner.* == .symbol and std.mem.eql(u8, inner.symbol, t_name)) {
                // e^t -> 1/(s-1)
                return createDivision(makeNumber(1, allocator), createSubtraction(makeSymbol(s_name, allocator), makeNumber(1, allocator), allocator), allocator);
            }
        }
    }

    // L{sin(at)} = a/(s^2 + a^2)
    // L{cos(at)} = s/(s^2 + a^2)
    if (expr_arg.* == .list and expr_arg.list.items.len == 2) {
        const op = expr_arg.list.items[0];
        const inner = expr_arg.list.items[1];

        if (op.* == .symbol) {
            if (std.mem.eql(u8, op.symbol, "sin")) {
                const coeff = extractCoefficient(inner, t_name);
                if (coeff) |a| {
                    // sin(a*t) -> a/(s^2 + a^2)
                    const a_copy = symbolic.copyExpr(a, allocator) catch return BuiltinError.OutOfMemory;
                    const a_squared = createPower(symbolic.copyExpr(a, allocator) catch return BuiltinError.OutOfMemory, makeNumber(2, allocator), allocator);
                    const s_squared = createPower(makeSymbol(s_name, allocator), makeNumber(2, allocator), allocator);
                    const denom = createAddition(s_squared, a_squared, allocator);
                    return createDivision(a_copy, denom, allocator);
                }
            } else if (std.mem.eql(u8, op.symbol, "cos")) {
                const coeff = extractCoefficient(inner, t_name);
                if (coeff) |a| {
                    // cos(a*t) -> s/(s^2 + a^2)
                    const a_squared = createPower(symbolic.copyExpr(a, allocator) catch return BuiltinError.OutOfMemory, makeNumber(2, allocator), allocator);
                    const s_squared = createPower(makeSymbol(s_name, allocator), makeNumber(2, allocator), allocator);
                    const denom = createAddition(s_squared, a_squared, allocator);
                    return createDivision(makeSymbol(s_name, allocator), denom, allocator);
                }
            }
        }
    }

    // Can't transform symbolically, return symbolic form
    return createSymbolicLaplace(expr_arg, t_arg, s_arg, env);
}

fn extractCoefficient(expr: *const Expr, var_name: []const u8) ?*const Expr {
    // Extract 'a' from a*x or x (where a=1)
    if (expr.* == .symbol and std.mem.eql(u8, expr.symbol, var_name)) {
        return null; // Would need to return 1, but we'll handle this case specially
    }

    if (expr.* == .list and expr.list.items.len == 3) {
        const op = expr.list.items[0];
        if (op.* == .symbol and std.mem.eql(u8, op.symbol, "*")) {
            const arg1 = expr.list.items[1];
            const arg2 = expr.list.items[2];

            if (arg2.* == .symbol and std.mem.eql(u8, arg2.symbol, var_name) and !symbolic.containsVariable(arg1, var_name)) {
                return arg1;
            } else if (arg1.* == .symbol and std.mem.eql(u8, arg1.symbol, var_name) and !symbolic.containsVariable(arg2, var_name)) {
                return arg2;
            }
        }
    }

    return null;
}

fn makeNumber(n: f64, allocator: std.mem.Allocator) *Expr {
    const result = allocator.create(Expr) catch unreachable;
    result.* = .{ .number = n };
    return result;
}

fn makeSymbol(s: []const u8, allocator: std.mem.Allocator) *Expr {
    const result = allocator.create(Expr) catch unreachable;
    result.* = .{ .symbol = s };
    return result;
}

fn createDivision(num: *Expr, denom: *Expr, allocator: std.mem.Allocator) BuiltinError!*Expr {
    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "/" };
    list.append(allocator, op) catch return BuiltinError.OutOfMemory;
    list.append(allocator, num) catch return BuiltinError.OutOfMemory;
    list.append(allocator, denom) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

fn createPower(base: *Expr, exp: *Expr, allocator: std.mem.Allocator) *Expr {
    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch unreachable;
    op.* = .{ .symbol = "^" };
    list.append(allocator, op) catch unreachable;
    list.append(allocator, base) catch unreachable;
    list.append(allocator, exp) catch unreachable;

    const result = allocator.create(Expr) catch unreachable;
    result.* = .{ .list = list };
    return result;
}

fn createSubtraction(a: *Expr, b: *Expr, allocator: std.mem.Allocator) *Expr {
    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch unreachable;
    op.* = .{ .symbol = "-" };
    list.append(allocator, op) catch unreachable;
    list.append(allocator, a) catch unreachable;
    list.append(allocator, b) catch unreachable;

    const result = allocator.create(Expr) catch unreachable;
    result.* = .{ .list = list };
    return result;
}

fn createAddition(a: *Expr, b: *Expr, allocator: std.mem.Allocator) *Expr {
    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch unreachable;
    op.* = .{ .symbol = "+" };
    list.append(allocator, op) catch unreachable;
    list.append(allocator, a) catch unreachable;
    list.append(allocator, b) catch unreachable;

    const result = allocator.create(Expr) catch unreachable;
    result.* = .{ .list = list };
    return result;
}

fn computeFactorial(n: u64) u64 {
    if (n <= 1) return 1;
    var result: u64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

fn createSymbolicLaplace(expr: *const Expr, t_arg: *const Expr, s_arg: *const Expr, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "laplace" };
    list.append(allocator, op) catch return BuiltinError.OutOfMemory;

    const expr_copy = symbolic.copyExpr(expr, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, expr_copy) catch return BuiltinError.OutOfMemory;

    const t_copy = symbolic.copyExpr(t_arg, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, t_copy) catch return BuiltinError.OutOfMemory;

    const s_copy = symbolic.copyExpr(s_arg, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, s_copy) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_inv_laplace(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (inv-laplace expr s t) - compute inverse Laplace transform from s-domain to t-domain
    if (args.items.len < 3) return BuiltinError.InvalidArgument;

    const expr_arg = args.items[0];
    const s_arg = args.items[1];
    const t_arg = args.items[2];

    if (s_arg.* != .symbol and s_arg.* != .owned_symbol) return BuiltinError.InvalidArgument;
    if (t_arg.* != .symbol and t_arg.* != .owned_symbol) return BuiltinError.InvalidArgument;

    const s_name = if (s_arg.* == .symbol) s_arg.symbol else s_arg.owned_symbol;
    const t_name = if (t_arg.* == .symbol) t_arg.symbol else t_arg.owned_symbol;

    const allocator = env.allocator;

    // Handle common inverse Laplace transforms
    // L^{-1}{1/s} = 1
    if (expr_arg.* == .list and expr_arg.list.items.len == 3) {
        const op = expr_arg.list.items[0];
        if (op.* == .symbol and std.mem.eql(u8, op.symbol, "/")) {
            const num = expr_arg.list.items[1];
            const denom = expr_arg.list.items[2];

            // 1/s -> 1
            if (num.* == .number and num.number == 1 and denom.* == .symbol and std.mem.eql(u8, denom.symbol, s_name)) {
                const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                result.* = .{ .number = 1 };
                return result;
            }

            // 1/s^2 -> t
            if (num.* == .number and num.number == 1 and denom.* == .list and denom.list.items.len == 3) {
                const denom_op = denom.list.items[0];
                if (denom_op.* == .symbol and std.mem.eql(u8, denom_op.symbol, "^")) {
                    const base = denom.list.items[1];
                    const exp = denom.list.items[2];
                    if (base.* == .symbol and std.mem.eql(u8, base.symbol, s_name) and exp.* == .number and exp.number == 2) {
                        const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                        result.* = .{ .symbol = t_name };
                        return result;
                    }
                }
            }

            // 1/(s-a) -> e^(a*t)
            if (num.* == .number and num.number == 1 and denom.* == .list and denom.list.items.len == 3) {
                const denom_op = denom.list.items[0];
                if (denom_op.* == .symbol and std.mem.eql(u8, denom_op.symbol, "-")) {
                    const denom_arg1 = denom.list.items[1];
                    const denom_arg2 = denom.list.items[2];
                    if (denom_arg1.* == .symbol and std.mem.eql(u8, denom_arg1.symbol, s_name)) {
                        // 1/(s-a) -> e^(a*t)
                        const a_copy = symbolic.copyExpr(denom_arg2, allocator) catch return BuiltinError.OutOfMemory;

                        var mult_list: std.ArrayList(*Expr) = .empty;
                        const mult_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                        mult_op.* = .{ .symbol = "*" };
                        mult_list.append(allocator, mult_op) catch return BuiltinError.OutOfMemory;
                        mult_list.append(allocator, a_copy) catch return BuiltinError.OutOfMemory;
                        const t_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                        t_sym.* = .{ .symbol = t_name };
                        mult_list.append(allocator, t_sym) catch return BuiltinError.OutOfMemory;

                        const mult_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                        mult_expr.* = .{ .list = mult_list };

                        var exp_list: std.ArrayList(*Expr) = .empty;
                        const exp_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                        exp_op.* = .{ .symbol = "exp" };
                        exp_list.append(allocator, exp_op) catch return BuiltinError.OutOfMemory;
                        exp_list.append(allocator, mult_expr) catch return BuiltinError.OutOfMemory;

                        const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                        result.* = .{ .list = exp_list };
                        return result;
                    }
                }
            }
        }
    }

    // Can't transform symbolically, return symbolic form
    return createSymbolicInvLaplace(expr_arg, s_arg, t_arg, env);
}

fn createSymbolicInvLaplace(expr: *const Expr, s_arg: *const Expr, t_arg: *const Expr, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "inv-laplace" };
    list.append(allocator, op) catch return BuiltinError.OutOfMemory;

    const expr_copy = symbolic.copyExpr(expr, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, expr_copy) catch return BuiltinError.OutOfMemory;

    const s_copy = symbolic.copyExpr(s_arg, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, s_copy) catch return BuiltinError.OutOfMemory;

    const t_copy = symbolic.copyExpr(t_arg, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, t_copy) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

// ============================================================================
// Tensor Operations
// ============================================================================

pub fn builtin_tensor(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (tensor rank dims components...) - create tensor with given rank, dimensions, and components
    // (tensor 2 (2 2) a b c d) - 2x2 matrix as rank-2 tensor
    // Or: (tensor ((a b) (c d))) - infer from nested structure
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;

    // Build tensor expression: (tensor components...)
    var result_list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "tensor" };
    result_list.append(allocator, op) catch return BuiltinError.OutOfMemory;

    for (args.items) |arg| {
        const arg_copy = symbolic.copyExpr(arg, allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(allocator, arg_copy) catch return BuiltinError.OutOfMemory;
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_tensor_rank(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (tensor-rank t) - get rank of tensor
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const tensor = args.items[0];
    const allocator = env.allocator;

    // Count nesting depth
    var rank: f64 = 0;
    var current = tensor;
    while (current.* == .list and current.list.items.len > 0) {
        const first = current.list.items[0];
        if (first.* == .symbol) {
            if (std.mem.eql(u8, first.symbol, "tensor")) {
                // Skip tensor tag, continue to inner content
                if (current.list.items.len > 1) {
                    current = current.list.items[1];
                    // Don't increment rank here - tensor is just a wrapper
                    continue;
                } else break;
            } else if (std.mem.eql(u8, first.symbol, "vector")) {
                // Vector is rank-1 (flat list of elements)
                rank += 1;
                break;
            } else if (std.mem.eql(u8, first.symbol, "matrix")) {
                // Matrix is rank-2
                rank += 2;
                break;
            } else {
                // Other structure
                rank += 1;
                break;
            }
        } else if (first.* == .list) {
            current = first;
            rank += 1;
        } else {
            rank += 1;
            break;
        }
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = rank };
    return result;
}

pub fn builtin_tensor_contract(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (tensor-contract t i j) - contract tensor on indices i and j
    // For rank-2 tensor (matrix), this is the trace when i=0, j=1
    if (args.items.len < 3) return BuiltinError.InvalidArgument;

    const tensor = args.items[0];
    const idx_i = args.items[1];
    const idx_j = args.items[2];

    if (idx_i.* != .number or idx_j.* != .number) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;

    // For matrix (rank-2), contraction with i=0, j=1 gives trace
    // Check if it's a matrix-like structure
    if (tensor.* == .list and tensor.list.items.len > 0) {
        const first = tensor.list.items[0];
        if (first.* == .symbol and (std.mem.eql(u8, first.symbol, "matrix") or std.mem.eql(u8, first.symbol, "tensor"))) {
            // Get dimensions
            var size: usize = 0;
            if (tensor.list.items.len > 1 and tensor.list.items[1].* == .list) {
                size = tensor.list.items[1].list.items.len;
            }

            // Compute trace (sum of diagonal elements)
            if (size > 0) {
                var trace: f64 = 0;
                var i: usize = 0;
                while (i < size) : (i += 1) {
                    if (i + 1 < tensor.list.items.len) {
                        const row = tensor.list.items[i + 1];
                        if (row.* == .list and i < row.list.items.len) {
                            if (row.list.items[i].* == .number) {
                                trace += row.list.items[i].number;
                            }
                        }
                    }
                }
                const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                result.* = .{ .number = trace };
                return result;
            }
        }
    }

    // Return symbolic form
    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "tensor-contract" };
    list.append(allocator, op) catch return BuiltinError.OutOfMemory;

    const tensor_copy = symbolic.copyExpr(tensor, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, tensor_copy) catch return BuiltinError.OutOfMemory;

    const idx_i_copy = symbolic.copyExpr(idx_i, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, idx_i_copy) catch return BuiltinError.OutOfMemory;

    const idx_j_copy = symbolic.copyExpr(idx_j, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, idx_j_copy) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_tensor_product(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (tensor-product t1 t2) - outer/tensor product of two tensors
    // For vectors: creates a matrix
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const t1 = args.items[0];
    const t2 = args.items[1];
    const allocator = env.allocator;

    // Check if both are vectors
    const t1_is_vec = t1.* == .list and t1.list.items.len > 0 and
        t1.list.items[0].* == .symbol and std.mem.eql(u8, t1.list.items[0].symbol, "vector");
    const t2_is_vec = t2.* == .list and t2.list.items.len > 0 and
        t2.list.items[0].* == .symbol and std.mem.eql(u8, t2.list.items[0].symbol, "vector");

    if (t1_is_vec and t2_is_vec) {
        // Outer product: v1 ⊗ v2 = matrix where m[i][j] = v1[i] * v2[j]
        const v1_len = t1.list.items.len - 1;
        const v2_len = t2.list.items.len - 1;

        var result_list: std.ArrayList(*Expr) = .empty;
        const matrix_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        matrix_op.* = .{ .symbol = "matrix" };
        result_list.append(allocator, matrix_op) catch return BuiltinError.OutOfMemory;

        var i: usize = 0;
        while (i < v1_len) : (i += 1) {
            var row: std.ArrayList(*Expr) = .empty;
            var j: usize = 0;
            while (j < v2_len) : (j += 1) {
                const v1_elem = t1.list.items[i + 1];
                const v2_elem = t2.list.items[j + 1];

                if (v1_elem.* == .number and v2_elem.* == .number) {
                    const product = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                    product.* = .{ .number = v1_elem.number * v2_elem.number };
                    row.append(allocator, product) catch return BuiltinError.OutOfMemory;
                } else {
                    // Symbolic product
                    var mult_list: std.ArrayList(*Expr) = .empty;
                    const mult_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                    mult_op.* = .{ .symbol = "*" };
                    mult_list.append(allocator, mult_op) catch return BuiltinError.OutOfMemory;
                    const v1_copy = symbolic.copyExpr(v1_elem, allocator) catch return BuiltinError.OutOfMemory;
                    mult_list.append(allocator, v1_copy) catch return BuiltinError.OutOfMemory;
                    const v2_copy = symbolic.copyExpr(v2_elem, allocator) catch return BuiltinError.OutOfMemory;
                    mult_list.append(allocator, v2_copy) catch return BuiltinError.OutOfMemory;
                    const mult_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                    mult_expr.* = .{ .list = mult_list };
                    row.append(allocator, mult_expr) catch return BuiltinError.OutOfMemory;
                }
            }

            const row_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            row_expr.* = .{ .list = row };
            result_list.append(allocator, row_expr) catch return BuiltinError.OutOfMemory;
        }

        const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .list = result_list };
        return result;
    }

    // Return symbolic form
    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "tensor-product" };
    list.append(allocator, op) catch return BuiltinError.OutOfMemory;

    const t1_copy = symbolic.copyExpr(t1, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, t1_copy) catch return BuiltinError.OutOfMemory;

    const t2_copy = symbolic.copyExpr(t2, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, t2_copy) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

// ============================================================================
// Polynomial Interpolation
// ============================================================================

pub fn builtin_lagrange(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (lagrange ((x0 y0) (x1 y1) ...) var) - Lagrange interpolation polynomial
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const points = args.items[0];
    const var_arg = args.items[1];

    if (points.* != .list) return BuiltinError.InvalidArgument;
    if (var_arg.* != .symbol and var_arg.* != .owned_symbol) return BuiltinError.InvalidArgument;

    const var_name = if (var_arg.* == .symbol) var_arg.symbol else var_arg.owned_symbol;
    const allocator = env.allocator;

    // Extract points
    var xs: std.ArrayList(f64) = .empty;
    defer xs.deinit(allocator);
    var ys: std.ArrayList(f64) = .empty;
    defer ys.deinit(allocator);

    // points is either a raw list of pairs, or a (list ...) or (vector ...) structure
    const points_data = if (points.list.items.len > 0 and points.list.items[0].* == .symbol) blk: {
        const sym = points.list.items[0].symbol;
        if (std.mem.eql(u8, sym, "list") or std.mem.eql(u8, sym, "vector")) {
            break :blk points.list.items[1..];
        }
        break :blk points.list.items;
    } else points.list.items;

    for (points_data) |pt| {
        // Each point is either a raw list or a (vector x y) structure
        const pt_data = if (pt.* == .list and pt.list.items.len > 0 and pt.list.items[0].* == .symbol and
            std.mem.eql(u8, pt.list.items[0].symbol, "vector"))
            pt.list.items[1..]
        else if (pt.* == .list)
            pt.list.items
        else
            return BuiltinError.InvalidArgument;

        if (pt_data.len != 2) return BuiltinError.InvalidArgument;
        if (pt_data[0].* != .number or pt_data[1].* != .number) return BuiltinError.InvalidArgument;
        xs.append(allocator, pt_data[0].number) catch return BuiltinError.OutOfMemory;
        ys.append(allocator, pt_data[1].number) catch return BuiltinError.OutOfMemory;
    }

    const n = xs.items.len;
    if (n == 0) return BuiltinError.InvalidArgument;

    // Build Lagrange polynomial: sum of y_i * L_i(x)
    // L_i(x) = product of (x - x_j) / (x_i - x_j) for j != i
    var terms: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (terms.items) |item| {
            item.deinit(allocator);
            allocator.destroy(item);
        }
        terms.deinit(allocator);
    }

    const plus_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plus_op.* = .{ .symbol = "+" };
    terms.append(allocator, plus_op) catch return BuiltinError.OutOfMemory;

    var i: usize = 0;
    while (i < n) : (i += 1) {
        // Build L_i(x) * y_i
        var Li_terms: std.ArrayList(*Expr) = .empty;
        const mult_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        mult_op.* = .{ .symbol = "*" };
        Li_terms.append(allocator, mult_op) catch return BuiltinError.OutOfMemory;

        // y_i coefficient
        const yi = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        yi.* = .{ .number = ys.items[i] };
        Li_terms.append(allocator, yi) catch return BuiltinError.OutOfMemory;

        // Product of (x - x_j) / (x_i - x_j) for j != i
        var j: usize = 0;
        while (j < n) : (j += 1) {
            if (i == j) continue;

            // (x - x_j)
            var num_list: std.ArrayList(*Expr) = .empty;
            const sub_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            sub_op.* = .{ .symbol = "-" };
            num_list.append(allocator, sub_op) catch return BuiltinError.OutOfMemory;
            const var_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            var_expr.* = .{ .symbol = var_name };
            num_list.append(allocator, var_expr) catch return BuiltinError.OutOfMemory;
            const xj = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            xj.* = .{ .number = xs.items[j] };
            num_list.append(allocator, xj) catch return BuiltinError.OutOfMemory;
            const num_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            num_expr.* = .{ .list = num_list };

            // / (x_i - x_j)
            const denom_val = xs.items[i] - xs.items[j];
            const denom = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            denom.* = .{ .number = denom_val };

            var div_list: std.ArrayList(*Expr) = .empty;
            const div_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            div_op.* = .{ .symbol = "/" };
            div_list.append(allocator, div_op) catch return BuiltinError.OutOfMemory;
            div_list.append(allocator, num_expr) catch return BuiltinError.OutOfMemory;
            div_list.append(allocator, denom) catch return BuiltinError.OutOfMemory;
            const div_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            div_expr.* = .{ .list = div_list };

            Li_terms.append(allocator, div_expr) catch return BuiltinError.OutOfMemory;
        }

        const Li_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        Li_expr.* = .{ .list = Li_terms };
        terms.append(allocator, Li_expr) catch return BuiltinError.OutOfMemory;
    }

    const poly = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    poly.* = .{ .list = terms };

    // Simplify the result
    const simplified = symbolic.simplify(poly, allocator) catch {
        poly.deinit(allocator);
        allocator.destroy(poly);
        return BuiltinError.OutOfMemory;
    };

    // Free the original poly since simplify creates a new expression
    poly.deinit(allocator);
    allocator.destroy(poly);

    return simplified;
}

pub fn builtin_newton_interp(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (newton-interp ((x0 y0) (x1 y1) ...) var) - Newton's divided differences interpolation
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const points = args.items[0];
    const var_arg = args.items[1];

    if (points.* != .list) return BuiltinError.InvalidArgument;
    if (var_arg.* != .symbol and var_arg.* != .owned_symbol) return BuiltinError.InvalidArgument;

    const var_name = if (var_arg.* == .symbol) var_arg.symbol else var_arg.owned_symbol;
    const allocator = env.allocator;

    // Extract points
    var xs: std.ArrayList(f64) = .empty;
    defer xs.deinit(allocator);
    var ys: std.ArrayList(f64) = .empty;
    defer ys.deinit(allocator);

    // points is either a raw list of pairs, or a (list ...) or (vector ...) structure
    const points_data = if (points.list.items.len > 0 and points.list.items[0].* == .symbol) blk: {
        const sym = points.list.items[0].symbol;
        if (std.mem.eql(u8, sym, "list") or std.mem.eql(u8, sym, "vector")) {
            break :blk points.list.items[1..];
        }
        break :blk points.list.items;
    } else points.list.items;

    for (points_data) |pt| {
        // Each point is either a raw list or a (vector x y) structure
        const pt_data = if (pt.* == .list and pt.list.items.len > 0 and pt.list.items[0].* == .symbol and
            std.mem.eql(u8, pt.list.items[0].symbol, "vector"))
            pt.list.items[1..]
        else if (pt.* == .list)
            pt.list.items
        else
            return BuiltinError.InvalidArgument;

        if (pt_data.len != 2) return BuiltinError.InvalidArgument;
        if (pt_data[0].* != .number or pt_data[1].* != .number) return BuiltinError.InvalidArgument;
        xs.append(allocator, pt_data[0].number) catch return BuiltinError.OutOfMemory;
        ys.append(allocator, pt_data[1].number) catch return BuiltinError.OutOfMemory;
    }

    const n = xs.items.len;
    if (n == 0) return BuiltinError.InvalidArgument;

    // Compute divided differences table
    var dd: std.ArrayList(std.ArrayList(f64)) = .empty;
    defer {
        for (dd.items) |*row| {
            row.deinit(allocator);
        }
        dd.deinit(allocator);
    }

    // First column is y values
    var first_col: std.ArrayList(f64) = .empty;
    for (ys.items) |y| {
        first_col.append(allocator, y) catch return BuiltinError.OutOfMemory;
    }
    dd.append(allocator, first_col) catch return BuiltinError.OutOfMemory;

    // Compute higher order differences
    var k: usize = 1;
    while (k < n) : (k += 1) {
        var col: std.ArrayList(f64) = .empty;
        var i: usize = 0;
        while (i < n - k) : (i += 1) {
            const diff = (dd.items[k - 1].items[i + 1] - dd.items[k - 1].items[i]) / (xs.items[i + k] - xs.items[i]);
            col.append(allocator, diff) catch return BuiltinError.OutOfMemory;
        }
        dd.append(allocator, col) catch return BuiltinError.OutOfMemory;
    }

    // Build Newton form: f[x0] + f[x0,x1](x-x0) + f[x0,x1,x2](x-x0)(x-x1) + ...
    var terms: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (terms.items) |item| {
            item.deinit(allocator);
            allocator.destroy(item);
        }
        terms.deinit(allocator);
    }

    const plus_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plus_op.* = .{ .symbol = "+" };
    terms.append(allocator, plus_op) catch return BuiltinError.OutOfMemory;

    k = 0;
    while (k < n) : (k += 1) {
        const coeff = dd.items[k].items[0];
        if (@abs(coeff) < 1e-15) continue; // Skip near-zero terms

        if (k == 0) {
            const term = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            term.* = .{ .number = coeff };
            terms.append(allocator, term) catch return BuiltinError.OutOfMemory;
        } else {
            var mult_terms: std.ArrayList(*Expr) = .empty;
            const mult_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            mult_op.* = .{ .symbol = "*" };
            mult_terms.append(allocator, mult_op) catch return BuiltinError.OutOfMemory;

            const coeff_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            coeff_expr.* = .{ .number = coeff };
            mult_terms.append(allocator, coeff_expr) catch return BuiltinError.OutOfMemory;

            // Product of (x - x_j) for j = 0 to k-1
            var j: usize = 0;
            while (j < k) : (j += 1) {
                var sub_list: std.ArrayList(*Expr) = .empty;
                const sub_op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                sub_op.* = .{ .symbol = "-" };
                sub_list.append(allocator, sub_op) catch return BuiltinError.OutOfMemory;
                const var_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                var_expr.* = .{ .symbol = var_name };
                sub_list.append(allocator, var_expr) catch return BuiltinError.OutOfMemory;
                const xj = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                xj.* = .{ .number = xs.items[j] };
                sub_list.append(allocator, xj) catch return BuiltinError.OutOfMemory;
                const sub_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
                sub_expr.* = .{ .list = sub_list };
                mult_terms.append(allocator, sub_expr) catch return BuiltinError.OutOfMemory;
            }

            const term = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            term.* = .{ .list = mult_terms };
            terms.append(allocator, term) catch return BuiltinError.OutOfMemory;
        }
    }

    const poly = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    poly.* = .{ .list = terms };

    return poly;
}

// ============================================================================
// Numerical Root Finding
// ============================================================================

pub fn builtin_newton_raphson(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (newton-raphson expr var x0) - find root using Newton-Raphson method
    // (newton-raphson expr var x0 tol) - with custom tolerance
    // (newton-raphson expr var x0 tol max-iter) - with custom max iterations
    if (args.items.len < 3) return BuiltinError.InvalidArgument;

    const expr_arg = args.items[0];
    const var_arg = args.items[1];
    const x0_arg = args.items[2];

    if (var_arg.* != .symbol and var_arg.* != .owned_symbol) return BuiltinError.InvalidArgument;
    if (x0_arg.* != .number) return BuiltinError.InvalidArgument;

    const var_name = if (var_arg.* == .symbol) var_arg.symbol else var_arg.owned_symbol;
    var x = x0_arg.number;

    const tol: f64 = if (args.items.len > 3 and args.items[3].* == .number) args.items[3].number else 1e-10;
    const max_iter: usize = if (args.items.len > 4 and args.items[4].* == .number) @intFromFloat(args.items[4].number) else 100;

    const allocator = env.allocator;

    // Compute derivative
    const deriv = symbolic.diff(expr_arg, var_name, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        deriv.deinit(allocator);
        allocator.destroy(deriv);
    }

    // Newton-Raphson iteration: x_{n+1} = x_n - f(x_n) / f'(x_n)
    var iter: usize = 0;
    while (iter < max_iter) : (iter += 1) {
        const fx = evaluateAt(expr_arg, var_name, x, allocator, env) catch {
            // Can't evaluate, return symbolic result
            return createSymbolicNewtonRaphson(expr_arg, var_arg, x0_arg, tol, max_iter, env);
        };
        const dfx = evaluateAt(deriv, var_name, x, allocator, env) catch {
            return createSymbolicNewtonRaphson(expr_arg, var_arg, x0_arg, tol, max_iter, env);
        };

        if (@abs(dfx) < 1e-15) {
            // Derivative too small, can't continue
            break;
        }

        const x_new = x - fx / dfx;

        if (@abs(x_new - x) < tol) {
            const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = x_new };
            return result;
        }

        x = x_new;
    }

    // Return final approximation
    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = x };
    return result;
}

fn createSymbolicNewtonRaphson(expr: *const Expr, var_arg: *const Expr, x0: *const Expr, tol: f64, max_iter: usize, env: *Env) BuiltinError!*Expr {
    const allocator = env.allocator;

    var list: std.ArrayList(*Expr) = .empty;
    const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "newton-raphson" };
    list.append(allocator, op) catch return BuiltinError.OutOfMemory;

    const expr_copy = symbolic.copyExpr(expr, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, expr_copy) catch return BuiltinError.OutOfMemory;

    const var_copy = symbolic.copyExpr(var_arg, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, var_copy) catch return BuiltinError.OutOfMemory;

    const x0_copy = symbolic.copyExpr(x0, allocator) catch return BuiltinError.OutOfMemory;
    list.append(allocator, x0_copy) catch return BuiltinError.OutOfMemory;

    const tol_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    tol_expr.* = .{ .number = tol };
    list.append(allocator, tol_expr) catch return BuiltinError.OutOfMemory;

    const iter_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    iter_expr.* = .{ .number = @floatFromInt(max_iter) };
    list.append(allocator, iter_expr) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn builtin_bisection(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (bisection expr var a b) - find root using bisection method in [a,b]
    // (bisection expr var a b tol) - with custom tolerance
    if (args.items.len < 4) return BuiltinError.InvalidArgument;

    const expr_arg = args.items[0];
    const var_arg = args.items[1];
    const a_arg = args.items[2];
    const b_arg = args.items[3];

    if (var_arg.* != .symbol and var_arg.* != .owned_symbol) return BuiltinError.InvalidArgument;
    if (a_arg.* != .number or b_arg.* != .number) return BuiltinError.InvalidArgument;

    const var_name = if (var_arg.* == .symbol) var_arg.symbol else var_arg.owned_symbol;
    var a = a_arg.number;
    var b = b_arg.number;

    const tol: f64 = if (args.items.len > 4 and args.items[4].* == .number) args.items[4].number else 1e-10;

    const allocator = env.allocator;

    // Evaluate at endpoints
    var fa = evaluateAt(expr_arg, var_name, a, allocator, env) catch return BuiltinError.InvalidArgument;
    const fb = evaluateAt(expr_arg, var_name, b, allocator, env) catch return BuiltinError.InvalidArgument;

    // Check for sign change
    if (fa * fb > 0) {
        // No sign change, return symbolic
        var list: std.ArrayList(*Expr) = .empty;
        const op = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        op.* = .{ .symbol = "bisection" };
        list.append(allocator, op) catch return BuiltinError.OutOfMemory;
        const expr_copy = symbolic.copyExpr(expr_arg, allocator) catch return BuiltinError.OutOfMemory;
        list.append(allocator, expr_copy) catch return BuiltinError.OutOfMemory;
        const var_copy = symbolic.copyExpr(var_arg, allocator) catch return BuiltinError.OutOfMemory;
        list.append(allocator, var_copy) catch return BuiltinError.OutOfMemory;
        const a_copy = symbolic.copyExpr(a_arg, allocator) catch return BuiltinError.OutOfMemory;
        list.append(allocator, a_copy) catch return BuiltinError.OutOfMemory;
        const b_copy = symbolic.copyExpr(b_arg, allocator) catch return BuiltinError.OutOfMemory;
        list.append(allocator, b_copy) catch return BuiltinError.OutOfMemory;
        const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .list = list };
        return result;
    }

    // Bisection iteration
    var iter: usize = 0;
    while (iter < 100 and (b - a) > tol) : (iter += 1) {
        const mid = (a + b) / 2.0;
        const fmid = evaluateAt(expr_arg, var_name, mid, allocator, env) catch break;

        if (@abs(fmid) < tol) {
            const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = mid };
            return result;
        }

        if (fa * fmid < 0) {
            b = mid;
        } else {
            a = mid;
            fa = fmid;
        }
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = (a + b) / 2.0 };
    return result;
}

// ============================================================================
// Continued Fractions
// ============================================================================

pub fn builtin_to_cf(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (to-cf x) - convert number to continued fraction representation
    // (to-cf x n) - with maximum n terms
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    const x_arg = args.items[0];
    if (x_arg.* != .number) return BuiltinError.InvalidArgument;

    var x = x_arg.number;
    const max_terms: usize = if (args.items.len > 1 and args.items[1].* == .number)
        @intFromFloat(@max(1, args.items[1].number))
    else
        20;

    const allocator = env.allocator;

    // Build continued fraction [a0; a1, a2, ...]
    var terms: std.ArrayList(*Expr) = .empty;

    const cf_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    cf_sym.* = .{ .symbol = "cf" };
    terms.append(allocator, cf_sym) catch return BuiltinError.OutOfMemory;

    var i: usize = 0;
    while (i < max_terms) : (i += 1) {
        const a = @floor(x);
        const a_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        a_expr.* = .{ .number = a };
        terms.append(allocator, a_expr) catch return BuiltinError.OutOfMemory;

        const frac = x - a;
        if (@abs(frac) < 1e-12) break;

        x = 1.0 / frac;
        if (!std.math.isFinite(x)) break;
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = terms };
    return result;
}

pub fn builtin_from_cf(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (from-cf (cf a0 a1 a2 ...)) - evaluate continued fraction to rational/float
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    const cf = args.items[0];
    if (cf.* != .list) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const lst = cf.list;

    // Check for cf tag
    var terms_start: usize = 0;
    if (lst.items.len > 0 and lst.items[0].* == .symbol and
        std.mem.eql(u8, lst.items[0].symbol, "cf"))
    {
        terms_start = 1;
    }

    if (lst.items.len <= terms_start) {
        const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = 0 };
        return result;
    }

    // Evaluate from the end: [a0; a1, ..., an] = a0 + 1/(a1 + 1/(... + 1/an))
    var value: f64 = 0;

    var i: usize = lst.items.len;
    while (i > terms_start) {
        i -= 1;
        const a = lst.items[i];
        if (a.* != .number) return BuiltinError.InvalidArgument;

        if (i == lst.items.len - 1) {
            value = a.number;
        } else {
            value = a.number + 1.0 / value;
        }
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = value };
    return result;
}

pub fn builtin_cf_convergent(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (cf-convergent (cf a0 a1 ...) n) - get nth convergent as (rational p q)
    if (args.items.len < 2) return BuiltinError.InvalidArgument;

    const cf = args.items[0];
    const n_arg = args.items[1];

    if (cf.* != .list or n_arg.* != .number) return BuiltinError.InvalidArgument;

    const n: usize = @intFromFloat(@max(0, n_arg.number));
    const allocator = env.allocator;
    const lst = cf.list;

    // Check for cf tag
    var terms_start: usize = 0;
    if (lst.items.len > 0 and lst.items[0].* == .symbol and
        std.mem.eql(u8, lst.items[0].symbol, "cf"))
    {
        terms_start = 1;
    }

    // Compute convergent p_n/q_n using recurrence:
    // p_{-2} = 0, p_{-1} = 1
    // q_{-2} = 1, q_{-1} = 0
    // p_k = a_k * p_{k-1} + p_{k-2}
    // q_k = a_k * q_{k-1} + q_{k-2}
    // So p_0 = a_0 * 1 + 0 = a_0, q_0 = a_0 * 0 + 1 = 1

    var p_prev: f64 = 0; // p_{-2}
    var q_prev: f64 = 1; // q_{-2}
    var p_curr: f64 = 1; // p_{-1}
    var q_curr: f64 = 0; // q_{-1}

    var k: usize = 0;
    while (k <= n and terms_start + k < lst.items.len) : (k += 1) {
        const a = lst.items[terms_start + k];
        if (a.* != .number) return BuiltinError.InvalidArgument;

        const a_val = a.number;
        const p_new = a_val * p_curr + p_prev;
        const q_new = a_val * q_curr + q_prev;

        p_prev = p_curr;
        q_prev = q_curr;
        p_curr = p_new;
        q_curr = q_new;
    }

    // Return as (rational p q)
    var result_list: std.ArrayList(*Expr) = .empty;
    const rat_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    rat_sym.* = .{ .symbol = "rational" };
    result_list.append(allocator, rat_sym) catch return BuiltinError.OutOfMemory;

    const p_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    p_expr.* = .{ .number = p_curr };
    result_list.append(allocator, p_expr) catch return BuiltinError.OutOfMemory;

    const q_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    q_expr.* = .{ .number = q_curr };
    result_list.append(allocator, q_expr) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_cf_rational(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (cf-rational p q) - continued fraction of rational p/q
    if (args.items.len < 2) return BuiltinError.InvalidArgument;

    const p_arg = args.items[0];
    const q_arg = args.items[1];

    if (p_arg.* != .number or q_arg.* != .number) return BuiltinError.InvalidArgument;

    var p: i64 = @intFromFloat(p_arg.number);
    var q: i64 = @intFromFloat(q_arg.number);

    if (q == 0) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;

    var terms: std.ArrayList(*Expr) = .empty;
    const cf_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    cf_sym.* = .{ .symbol = "cf" };
    terms.append(allocator, cf_sym) catch return BuiltinError.OutOfMemory;

    // Euclidean algorithm to get continued fraction coefficients
    while (q != 0) {
        const a = @divTrunc(p, q);
        const a_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        a_expr.* = .{ .number = @floatFromInt(a) };
        terms.append(allocator, a_expr) catch return BuiltinError.OutOfMemory;

        const r = @mod(p, q);
        p = q;
        q = r;
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = terms };
    return result;
}

// ============================================================================
// List Operations
// ============================================================================

pub fn builtin_car(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (car list) - get first element
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const lst = args.items[0];
    if (lst.* != .list) return BuiltinError.InvalidArgument;

    const items = lst.list.items;
    if (items.len == 0) return BuiltinError.InvalidArgument;

    // If the list is tagged (vector, matrix, etc.), skip the tag
    const start_idx: usize = if (items.len > 0 and items[0].* == .symbol)
        (if (std.mem.eql(u8, items[0].symbol, "vector") or
            std.mem.eql(u8, items[0].symbol, "list") or
            std.mem.eql(u8, items[0].symbol, "cf")) @as(usize, 1) else 0)
    else
        0;

    if (start_idx >= items.len) return BuiltinError.InvalidArgument;

    return symbolic.copyExpr(items[start_idx], env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_cdr(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (cdr list) - get rest of list (everything but first)
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const lst = args.items[0];
    if (lst.* != .list) return BuiltinError.InvalidArgument;

    const items = lst.list.items;
    const allocator = env.allocator;

    // If the list is tagged, preserve the tag
    var tag: ?[]const u8 = null;
    var start_idx: usize = 0;

    if (items.len > 0 and items[0].* == .symbol) {
        if (std.mem.eql(u8, items[0].symbol, "vector") or
            std.mem.eql(u8, items[0].symbol, "list") or
            std.mem.eql(u8, items[0].symbol, "cf"))
        {
            tag = items[0].symbol;
            start_idx = 1;
        }
    }

    if (start_idx + 1 > items.len) {
        // Return empty list
        var result_list: std.ArrayList(*Expr) = .empty;
        if (tag) |t| {
            const tag_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            tag_sym.* = .{ .symbol = t };
            result_list.append(allocator, tag_sym) catch return BuiltinError.OutOfMemory;
        }
        const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .list = result_list };
        return result;
    }

    var result_list: std.ArrayList(*Expr) = .empty;
    if (tag) |t| {
        const tag_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        tag_sym.* = .{ .symbol = t };
        result_list.append(allocator, tag_sym) catch return BuiltinError.OutOfMemory;
    }

    // Add all elements after the first data element
    for (items[start_idx + 1 ..]) |item| {
        const copy = symbolic.copyExpr(item, allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(allocator, copy) catch return BuiltinError.OutOfMemory;
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_cons(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (cons elem list) - prepend element to list
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const elem = args.items[0];
    const lst = args.items[1];

    const allocator = env.allocator;
    var result_list: std.ArrayList(*Expr) = .empty;

    // Copy the element first
    const elem_copy = symbolic.copyExpr(elem, allocator) catch return BuiltinError.OutOfMemory;

    if (lst.* == .list) {
        const items = lst.list.items;
        // Check for tag
        if (items.len > 0 and items[0].* == .symbol and
            (std.mem.eql(u8, items[0].symbol, "vector") or
            std.mem.eql(u8, items[0].symbol, "list") or
            std.mem.eql(u8, items[0].symbol, "cf")))
        {
            // Preserve tag
            const tag_copy = symbolic.copyExpr(items[0], allocator) catch return BuiltinError.OutOfMemory;
            result_list.append(allocator, tag_copy) catch return BuiltinError.OutOfMemory;
            result_list.append(allocator, elem_copy) catch return BuiltinError.OutOfMemory;
            // Copy rest
            for (items[1..]) |item| {
                const copy = symbolic.copyExpr(item, allocator) catch return BuiltinError.OutOfMemory;
                result_list.append(allocator, copy) catch return BuiltinError.OutOfMemory;
            }
        } else {
            // No tag, just prepend
            result_list.append(allocator, elem_copy) catch return BuiltinError.OutOfMemory;
            for (items) |item| {
                const copy = symbolic.copyExpr(item, allocator) catch return BuiltinError.OutOfMemory;
                result_list.append(allocator, copy) catch return BuiltinError.OutOfMemory;
            }
        }
    } else {
        // Second arg not a list, create pair
        result_list.append(allocator, elem_copy) catch return BuiltinError.OutOfMemory;
        const lst_copy = symbolic.copyExpr(lst, allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(allocator, lst_copy) catch return BuiltinError.OutOfMemory;
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_list_fn(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (list e1 e2 ...) - create a list
    const allocator = env.allocator;

    var result_list: std.ArrayList(*Expr) = .empty;
    const list_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    list_sym.* = .{ .symbol = "list" };
    result_list.append(allocator, list_sym) catch return BuiltinError.OutOfMemory;

    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(allocator, copy) catch return BuiltinError.OutOfMemory;
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_length(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (length list) - get length of list
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const lst = args.items[0];
    if (lst.* != .list) return BuiltinError.InvalidArgument;

    const items = lst.list.items;

    // Account for tagged lists
    const len: usize = if (items.len > 0 and items[0].* == .symbol and
        (std.mem.eql(u8, items[0].symbol, "vector") or
        std.mem.eql(u8, items[0].symbol, "list") or
        std.mem.eql(u8, items[0].symbol, "cf") or
        std.mem.eql(u8, items[0].symbol, "matrix")))
        items.len - 1
    else
        items.len;

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = @floatFromInt(len) };
    return result;
}

pub fn builtin_nth(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (nth list n) - get nth element (0-indexed)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const lst = args.items[0];
    const n_arg = args.items[1];

    if (lst.* != .list or n_arg.* != .number) return BuiltinError.InvalidArgument;

    const items = lst.list.items;
    const n: usize = @intFromFloat(n_arg.number);

    // Account for tagged lists
    const start_idx: usize = if (items.len > 0 and items[0].* == .symbol and
        (std.mem.eql(u8, items[0].symbol, "vector") or
        std.mem.eql(u8, items[0].symbol, "list") or
        std.mem.eql(u8, items[0].symbol, "cf")))
        1
    else
        0;

    if (start_idx + n >= items.len) return BuiltinError.InvalidArgument;

    return symbolic.copyExpr(items[start_idx + n], env.allocator) catch return BuiltinError.OutOfMemory;
}

pub fn builtin_map(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (map fn list) - apply fn to each element
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const func = args.items[0];
    const lst = args.items[1];

    if (lst.* != .list) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const items = lst.list.items;

    var result_list: std.ArrayList(*Expr) = .empty;

    // Preserve tag if present
    var start_idx: usize = 0;
    if (items.len > 0 and items[0].* == .symbol and
        (std.mem.eql(u8, items[0].symbol, "vector") or
        std.mem.eql(u8, items[0].symbol, "list")))
    {
        const tag_copy = symbolic.copyExpr(items[0], allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(allocator, tag_copy) catch return BuiltinError.OutOfMemory;
        start_idx = 1;
    }

    // Apply function to each element
    for (items[start_idx..]) |item| {
        // Build (func item)
        var call_list: std.ArrayList(*Expr) = .empty;
        const func_copy = symbolic.copyExpr(func, allocator) catch return BuiltinError.OutOfMemory;
        call_list.append(allocator, func_copy) catch return BuiltinError.OutOfMemory;
        const item_copy = symbolic.copyExpr(item, allocator) catch return BuiltinError.OutOfMemory;
        call_list.append(allocator, item_copy) catch return BuiltinError.OutOfMemory;

        const call_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        call_expr.* = .{ .list = call_list };

        // Evaluate the call
        const eval_result = eval(call_expr, env) catch {
            call_expr.deinit(allocator);
            allocator.destroy(call_expr);
            return BuiltinError.InvalidArgument;
        };

        // Clean up call expr and its contents (func_copy and item_copy)
        call_expr.deinit(allocator);
        allocator.destroy(call_expr);

        result_list.append(allocator, eval_result) catch return BuiltinError.OutOfMemory;
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_filter(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (filter pred list) - keep elements where pred is true (non-zero)
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    const pred = args.items[0];
    const lst = args.items[1];

    if (lst.* != .list) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const items = lst.list.items;

    var result_list: std.ArrayList(*Expr) = .empty;

    // Preserve tag if present
    var start_idx: usize = 0;
    if (items.len > 0 and items[0].* == .symbol and
        (std.mem.eql(u8, items[0].symbol, "vector") or
        std.mem.eql(u8, items[0].symbol, "list")))
    {
        const tag_copy = symbolic.copyExpr(items[0], allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(allocator, tag_copy) catch return BuiltinError.OutOfMemory;
        start_idx = 1;
    }

    for (items[start_idx..]) |item| {
        // Build (pred item)
        var call_list: std.ArrayList(*Expr) = .empty;
        const pred_copy = symbolic.copyExpr(pred, allocator) catch return BuiltinError.OutOfMemory;
        call_list.append(allocator, pred_copy) catch return BuiltinError.OutOfMemory;
        const item_copy = symbolic.copyExpr(item, allocator) catch return BuiltinError.OutOfMemory;
        call_list.append(allocator, item_copy) catch return BuiltinError.OutOfMemory;

        const call_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        call_expr.* = .{ .list = call_list };

        const eval_result = eval(call_expr, env) catch {
            call_expr.deinit(allocator);
            allocator.destroy(call_expr);
            continue; // Skip on error
        };

        // Clean up call expr (deinit frees the list items)
        call_expr.deinit(allocator);
        allocator.destroy(call_expr);

        // Check if result is truthy (non-zero number)
        const keep = if (eval_result.* == .number) eval_result.number != 0 else true;

        eval_result.deinit(allocator);
        allocator.destroy(eval_result);

        if (keep) {
            const copy = symbolic.copyExpr(item, allocator) catch return BuiltinError.OutOfMemory;
            result_list.append(allocator, copy) catch return BuiltinError.OutOfMemory;
        }
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_reduce(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (reduce fn init list) - fold list with fn
    if (args.items.len != 3) return BuiltinError.InvalidArgument;

    const func = args.items[0];
    const init = args.items[1];
    const lst = args.items[2];

    if (lst.* != .list) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const items = lst.list.items;

    var acc = symbolic.copyExpr(init, allocator) catch return BuiltinError.OutOfMemory;

    // Skip tag if present
    var start_idx: usize = 0;
    if (items.len > 0 and items[0].* == .symbol and
        (std.mem.eql(u8, items[0].symbol, "vector") or
        std.mem.eql(u8, items[0].symbol, "list")))
    {
        start_idx = 1;
    }

    for (items[start_idx..]) |item| {
        // Build (fn acc item)
        var call_list: std.ArrayList(*Expr) = .empty;
        const func_copy = symbolic.copyExpr(func, allocator) catch return BuiltinError.OutOfMemory;
        call_list.append(allocator, func_copy) catch return BuiltinError.OutOfMemory;
        call_list.append(allocator, acc) catch return BuiltinError.OutOfMemory;
        const item_copy = symbolic.copyExpr(item, allocator) catch return BuiltinError.OutOfMemory;
        call_list.append(allocator, item_copy) catch return BuiltinError.OutOfMemory;

        const call_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        call_expr.* = .{ .list = call_list };

        const new_acc = eval(call_expr, env) catch {
            call_expr.deinit(allocator);
            allocator.destroy(call_expr);
            return BuiltinError.InvalidArgument;
        };

        // Clean up call expr and its contents (func_copy, old acc, item_copy)
        call_expr.deinit(allocator);
        allocator.destroy(call_expr);

        acc = new_acc;
    }

    return acc;
}

pub fn builtin_append(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (append list1 list2 ...) - concatenate lists
    const allocator = env.allocator;

    var result_list: std.ArrayList(*Expr) = .empty;
    var has_tag = false;

    for (args.items) |arg| {
        if (arg.* != .list) continue;

        const items = arg.list.items;
        var start_idx: usize = 0;

        // Check for tag
        if (items.len > 0 and items[0].* == .symbol) {
            if (std.mem.eql(u8, items[0].symbol, "vector") or
                std.mem.eql(u8, items[0].symbol, "list"))
            {
                if (!has_tag) {
                    has_tag = true;
                    const tag_copy = symbolic.copyExpr(items[0], allocator) catch return BuiltinError.OutOfMemory;
                    result_list.append(allocator, tag_copy) catch return BuiltinError.OutOfMemory;
                }
                start_idx = 1;
            }
        }

        for (items[start_idx..]) |item| {
            const copy = symbolic.copyExpr(item, allocator) catch return BuiltinError.OutOfMemory;
            result_list.append(allocator, copy) catch return BuiltinError.OutOfMemory;
        }
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_reverse(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (reverse list) - reverse a list
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const lst = args.items[0];
    if (lst.* != .list) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const items = lst.list.items;

    var result_list: std.ArrayList(*Expr) = .empty;

    // Check for tag
    var start_idx: usize = 0;
    if (items.len > 0 and items[0].* == .symbol and
        (std.mem.eql(u8, items[0].symbol, "vector") or
        std.mem.eql(u8, items[0].symbol, "list")))
    {
        const tag_copy = symbolic.copyExpr(items[0], allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(allocator, tag_copy) catch return BuiltinError.OutOfMemory;
        start_idx = 1;
    }

    // Add elements in reverse order
    var i: usize = items.len;
    while (i > start_idx) {
        i -= 1;
        const copy = symbolic.copyExpr(items[i], allocator) catch return BuiltinError.OutOfMemory;
        result_list.append(allocator, copy) catch return BuiltinError.OutOfMemory;
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_range(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (range end) - [0, 1, ..., end-1]
    // (range start end) - [start, start+1, ..., end-1]
    // (range start end step) - [start, start+step, ...]
    if (args.items.len == 0) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;

    var start: f64 = 0;
    var end: f64 = 0;
    var step: f64 = 1;

    if (args.items.len == 1) {
        if (args.items[0].* != .number) return BuiltinError.InvalidArgument;
        end = args.items[0].number;
    } else if (args.items.len == 2) {
        if (args.items[0].* != .number or args.items[1].* != .number) return BuiltinError.InvalidArgument;
        start = args.items[0].number;
        end = args.items[1].number;
    } else {
        if (args.items[0].* != .number or args.items[1].* != .number or args.items[2].* != .number)
            return BuiltinError.InvalidArgument;
        start = args.items[0].number;
        end = args.items[1].number;
        step = args.items[2].number;
    }

    if (step == 0) return BuiltinError.InvalidArgument;

    var result_list: std.ArrayList(*Expr) = .empty;
    const list_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    list_sym.* = .{ .symbol = "list" };
    result_list.append(allocator, list_sym) catch return BuiltinError.OutOfMemory;

    var val = start;
    var count: usize = 0;
    const max_count: usize = 10000; // Safety limit

    while (count < max_count) : (count += 1) {
        if ((step > 0 and val >= end) or (step < 0 and val <= end)) break;

        const num_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        num_expr.* = .{ .number = val };
        result_list.append(allocator, num_expr) catch return BuiltinError.OutOfMemory;

        val += step;
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

// ============================================================================
// Memoization Functions
// ============================================================================

/// Global memo cache using string keys for expression results
var memo_cache: ?std.StringHashMap(*Expr) = null;

/// Convert expression to string for caching key
fn memoExprToString(expr: *const Expr, allocator: std.mem.Allocator) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try memoWriteExpr(expr, result.writer(allocator));
    return result.toOwnedSlice(allocator);
}

fn memoWriteExpr(expr: *const Expr, writer: anytype) !void {
    switch (expr.*) {
        .number => |n| {
            if (n == @floor(n) and @abs(n) < 1e15) {
                try writer.print("{d:.0}", .{n});
            } else {
                try writer.print("{d}", .{n});
            }
        },
        .symbol => |s| try writer.print("{s}", .{s}),
        .owned_symbol => |s| try writer.print("{s}", .{s}),
        .lambda => |lam| {
            try writer.print("(lambda (", .{});
            for (lam.params.items, 0..) |param, i| {
                if (i > 0) try writer.print(" ", .{});
                try writer.print("{s}", .{param});
            }
            try writer.print(") ", .{});
            try memoWriteExpr(lam.body, writer);
            try writer.print(")", .{});
        },
        .list => |lst| {
            if (lst.items.len > 0) {
                try writer.print("(", .{});
                try memoWriteExpr(lst.items[0], writer);
                for (lst.items[1..]) |item| {
                    try writer.print(" ", .{});
                    try memoWriteExpr(item, writer);
                }
                try writer.print(")", .{});
            } else {
                try writer.print("()", .{});
            }
        },
    }
}

pub fn builtin_memoize(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (memoize expr) - Evaluate and cache the expression
    // Returns cached result if same expression was seen before
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;

    // Initialize cache if needed
    if (memo_cache == null) {
        memo_cache = std.StringHashMap(*Expr).init(allocator);
    }

    // Convert expression to string as key
    const key = memoExprToString(args.items[0], allocator) catch return BuiltinError.OutOfMemory;

    // Check cache
    if (memo_cache.?.get(key)) |cached| {
        allocator.free(key);
        return symbolic.copyExpr(cached, allocator) catch return BuiltinError.OutOfMemory;
    }

    // Evaluate and cache
    const evaluated = eval(args.items[0], env) catch return BuiltinError.EvaluationError;
    const copy = symbolic.copyExpr(evaluated, allocator) catch return BuiltinError.OutOfMemory;
    memo_cache.?.put(key, copy) catch return BuiltinError.OutOfMemory;

    return evaluated;
}

pub fn builtin_memo_clear(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (memo-clear) - Clear the memoization cache
    _ = args;
    const allocator = env.allocator;

    if (memo_cache) |*cache| {
        var iter = cache.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit(allocator);
            allocator.destroy(entry.value_ptr.*);
        }
        cache.deinit();
        memo_cache = null;
    }

    // Return nil/empty list
    var nil_list: std.ArrayList(*Expr) = .empty;
    const nil_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    nil_sym.* = .{ .symbol = "nil" };
    nil_list.append(allocator, nil_sym) catch return BuiltinError.OutOfMemory;
    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = nil_list };
    return result;
}

pub fn builtin_memo_stats(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (memo-stats) - Return statistics about the memo cache
    _ = args;
    const allocator = env.allocator;

    var count: f64 = 0;
    if (memo_cache) |cache| {
        count = @floatFromInt(cache.count());
    }

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = count };
    return result;
}

// ============================================================================
// Plotting Functions
// ============================================================================

pub fn builtin_plot_ascii(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (plot-ascii func x-min x-max) - Plot function as ASCII art
    // (plot-ascii func x-min x-max height width) - With custom dimensions
    if (args.items.len < 3) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const func = args.items[0];
    if (args.items[1].* != .number or args.items[2].* != .number)
        return BuiltinError.InvalidArgument;

    const x_min = args.items[1].number;
    const x_max = args.items[2].number;
    const height: usize = if (args.items.len > 3 and args.items[3].* == .number)
        @intFromFloat(@max(5, @min(50, args.items[3].number)))
    else
        20;
    const width: usize = if (args.items.len > 4 and args.items[4].* == .number)
        @intFromFloat(@max(20, @min(200, args.items[4].number)))
    else
        60;

    // Sample function at points
    var y_values: std.ArrayList(f64) = .empty;
    defer y_values.deinit(allocator);

    var y_min: f64 = std.math.inf(f64);
    var y_max: f64 = -std.math.inf(f64);

    const step = (x_max - x_min) / @as(f64, @floatFromInt(width - 1));
    var x = x_min;
    for (0..width) |_| {
        // Substitute x value and evaluate
        const x_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        x_expr.* = .{ .number = x };
        defer {
            x_expr.deinit(allocator);
            allocator.destroy(x_expr);
        }

        const subst = symbolic.substitute(func, "x", x_expr, allocator) catch return BuiltinError.OutOfMemory;
        defer {
            subst.deinit(allocator);
            allocator.destroy(subst);
        }

        const evaled = eval(subst, env) catch {
            y_values.append(allocator, std.math.nan(f64)) catch return BuiltinError.OutOfMemory;
            x += step;
            continue;
        };
        defer {
            evaled.deinit(allocator);
            allocator.destroy(evaled);
        }

        const y = if (evaled.* == .number) evaled.number else std.math.nan(f64);
        y_values.append(allocator, y) catch return BuiltinError.OutOfMemory;

        if (!std.math.isNan(y) and !std.math.isInf(y)) {
            y_min = @min(y_min, y);
            y_max = @max(y_max, y);
        }
        x += step;
    }

    // Handle edge cases
    if (std.math.isInf(y_min) or std.math.isInf(y_max)) {
        y_min = -1;
        y_max = 1;
    }
    if (y_min == y_max) {
        y_min -= 1;
        y_max += 1;
    }

    // Build ASCII plot
    var plot: std.ArrayList(u8) = .empty;
    errdefer plot.deinit(allocator);

    const writer = plot.writer(allocator);
    const y_range = y_max - y_min;

    for (0..height) |row| {
        const y_at_row = y_max - (@as(f64, @floatFromInt(row)) / @as(f64, @floatFromInt(height - 1))) * y_range;

        // Y-axis label
        writer.print("{d:8.2} |", .{y_at_row}) catch return BuiltinError.OutOfMemory;

        for (y_values.items) |y| {
            if (std.math.isNan(y) or std.math.isInf(y)) {
                writer.print(" ", .{}) catch return BuiltinError.OutOfMemory;
            } else {
                const y_pos = (y_max - y) / y_range * @as(f64, @floatFromInt(height - 1));
                const char_row: usize = @intFromFloat(@max(0, @min(@as(f64, @floatFromInt(height - 1)), y_pos)));
                if (char_row == row) {
                    writer.print("*", .{}) catch return BuiltinError.OutOfMemory;
                } else {
                    writer.print(" ", .{}) catch return BuiltinError.OutOfMemory;
                }
            }
        }
        writer.print("\n", .{}) catch return BuiltinError.OutOfMemory;
    }

    // X-axis
    writer.print("         +", .{}) catch return BuiltinError.OutOfMemory;
    for (0..width) |_| {
        writer.print("-", .{}) catch return BuiltinError.OutOfMemory;
    }
    writer.print("\n", .{}) catch return BuiltinError.OutOfMemory;

    // X-axis labels
    writer.print("         {d:.2}", .{x_min}) catch return BuiltinError.OutOfMemory;
    const label_space = width - 20;
    for (0..label_space) |_| {
        writer.print(" ", .{}) catch return BuiltinError.OutOfMemory;
    }
    writer.print("{d:.2}\n", .{x_max}) catch return BuiltinError.OutOfMemory;

    const plot_str = plot.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory;

    var result_list: std.ArrayList(*Expr) = .empty;
    const plot_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plot_sym.* = .{ .symbol = "plot" };
    result_list.append(allocator, plot_sym) catch return BuiltinError.OutOfMemory;

    const plot_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plot_expr.* = .{ .owned_symbol = plot_str };
    result_list.append(allocator, plot_expr) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_plot_svg(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (plot-svg func x-min x-max) - Plot function as SVG
    // (plot-svg func x-min x-max height width) - With custom dimensions
    if (args.items.len < 3) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const func = args.items[0];
    if (args.items[1].* != .number or args.items[2].* != .number)
        return BuiltinError.InvalidArgument;

    const x_min = args.items[1].number;
    const x_max = args.items[2].number;
    const svg_height: f64 = if (args.items.len > 3 and args.items[3].* == .number)
        @max(100, @min(1000, args.items[3].number))
    else
        400;
    const svg_width: f64 = if (args.items.len > 4 and args.items[4].* == .number)
        @max(100, @min(2000, args.items[4].number))
    else
        600;

    const margin: f64 = 50;
    const plot_width = svg_width - 2 * margin;
    const plot_height = svg_height - 2 * margin;
    const num_points: usize = 200;

    // Sample function at points
    var points: std.ArrayList(struct { x: f64, y: f64 }) = .empty;
    defer points.deinit(allocator);

    var y_min: f64 = std.math.inf(f64);
    var y_max: f64 = -std.math.inf(f64);

    const step = (x_max - x_min) / @as(f64, @floatFromInt(num_points - 1));
    var x = x_min;
    for (0..num_points) |_| {
        const x_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        x_expr.* = .{ .number = x };
        defer {
            x_expr.deinit(allocator);
            allocator.destroy(x_expr);
        }

        const subst = symbolic.substitute(func, "x", x_expr, allocator) catch return BuiltinError.OutOfMemory;
        defer {
            subst.deinit(allocator);
            allocator.destroy(subst);
        }

        const evaled = eval(subst, env) catch {
            x += step;
            continue;
        };

        if (evaled.* == .number) {
            const y = evaled.number;
            if (!std.math.isNan(y) and !std.math.isInf(y)) {
                points.append(allocator, .{ .x = x, .y = y }) catch return BuiltinError.OutOfMemory;
                y_min = @min(y_min, y);
                y_max = @max(y_max, y);
            }
        }
        evaled.deinit(allocator);
        allocator.destroy(evaled);
        x += step;
    }

    if (std.math.isInf(y_min) or std.math.isInf(y_max)) {
        y_min = -1;
        y_max = 1;
    }
    if (y_min == y_max) {
        y_min -= 1;
        y_max += 1;
    }

    // Build SVG
    var svg: std.ArrayList(u8) = .empty;
    errdefer svg.deinit(allocator);
    const writer = svg.writer(allocator);

    // SVG header
    writer.print("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{d:.0}\" height=\"{d:.0}\">\n", .{ svg_width, svg_height }) catch return BuiltinError.OutOfMemory;
    writer.print("  <rect width=\"100%\" height=\"100%\" fill=\"white\"/>\n", .{}) catch return BuiltinError.OutOfMemory;

    // Grid
    writer.print("  <g stroke=\"#eee\" stroke-width=\"1\">\n", .{}) catch return BuiltinError.OutOfMemory;
    var i: usize = 0;
    while (i <= 10) : (i += 1) {
        const gx = margin + @as(f64, @floatFromInt(i)) * plot_width / 10;
        const gy = margin + @as(f64, @floatFromInt(i)) * plot_height / 10;
        writer.print("    <line x1=\"{d:.1}\" y1=\"{d:.1}\" x2=\"{d:.1}\" y2=\"{d:.1}\"/>\n", .{ gx, margin, gx, svg_height - margin }) catch return BuiltinError.OutOfMemory;
        writer.print("    <line x1=\"{d:.1}\" y1=\"{d:.1}\" x2=\"{d:.1}\" y2=\"{d:.1}\"/>\n", .{ margin, gy, svg_width - margin, gy }) catch return BuiltinError.OutOfMemory;
    }
    writer.print("  </g>\n", .{}) catch return BuiltinError.OutOfMemory;

    // Axes
    writer.print("  <g stroke=\"black\" stroke-width=\"2\">\n", .{}) catch return BuiltinError.OutOfMemory;
    writer.print("    <line x1=\"{d:.1}\" y1=\"{d:.1}\" x2=\"{d:.1}\" y2=\"{d:.1}\"/>\n", .{ margin, svg_height - margin, svg_width - margin, svg_height - margin }) catch return BuiltinError.OutOfMemory;
    writer.print("    <line x1=\"{d:.1}\" y1=\"{d:.1}\" x2=\"{d:.1}\" y2=\"{d:.1}\"/>\n", .{ margin, margin, margin, svg_height - margin }) catch return BuiltinError.OutOfMemory;
    writer.print("  </g>\n", .{}) catch return BuiltinError.OutOfMemory;

    // Plot line
    if (points.items.len > 0) {
        writer.print("  <path d=\"M", .{}) catch return BuiltinError.OutOfMemory;
        for (points.items, 0..) |pt, idx| {
            const px = margin + (pt.x - x_min) / (x_max - x_min) * plot_width;
            const py = svg_height - margin - (pt.y - y_min) / (y_max - y_min) * plot_height;
            if (idx == 0) {
                writer.print("{d:.1} {d:.1}", .{ px, py }) catch return BuiltinError.OutOfMemory;
            } else {
                writer.print(" L{d:.1} {d:.1}", .{ px, py }) catch return BuiltinError.OutOfMemory;
            }
        }
        writer.print("\" fill=\"none\" stroke=\"blue\" stroke-width=\"2\"/>\n", .{}) catch return BuiltinError.OutOfMemory;
    }

    // Labels
    writer.print("  <text x=\"{d:.1}\" y=\"{d:.1}\" font-size=\"12\">{d:.2}</text>\n", .{ margin, svg_height - margin + 20, x_min }) catch return BuiltinError.OutOfMemory;
    writer.print("  <text x=\"{d:.1}\" y=\"{d:.1}\" font-size=\"12\">{d:.2}</text>\n", .{ svg_width - margin - 20, svg_height - margin + 20, x_max }) catch return BuiltinError.OutOfMemory;
    writer.print("  <text x=\"{d:.1}\" y=\"{d:.1}\" font-size=\"12\">{d:.2}</text>\n", .{ 5, svg_height - margin, y_min }) catch return BuiltinError.OutOfMemory;
    writer.print("  <text x=\"{d:.1}\" y=\"{d:.1}\" font-size=\"12\">{d:.2}</text>\n", .{ 5, margin + 10, y_max }) catch return BuiltinError.OutOfMemory;

    writer.print("</svg>\n", .{}) catch return BuiltinError.OutOfMemory;

    const svg_str = svg.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory;

    var result_list: std.ArrayList(*Expr) = .empty;
    const svg_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    svg_sym.* = .{ .symbol = "svg" };
    result_list.append(allocator, svg_sym) catch return BuiltinError.OutOfMemory;

    const svg_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    svg_expr.* = .{ .owned_symbol = svg_str };
    result_list.append(allocator, svg_expr) catch return BuiltinError.OutOfMemory;

    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = result_list };
    return result;
}

pub fn builtin_plot_points(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (plot-points points) - Plot list of (x y) points as ASCII
    if (args.items.len < 1) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const points_list = args.items[0];
    if (points_list.* != .list) return BuiltinError.InvalidArgument;

    var xs: std.ArrayList(f64) = .empty;
    defer xs.deinit(allocator);
    var ys: std.ArrayList(f64) = .empty;
    defer ys.deinit(allocator);

    const items = points_list.list.items;
    const start_idx: usize = if (items.len > 0 and items[0].* == .symbol)
        (if (std.mem.eql(u8, items[0].symbol, "list") or std.mem.eql(u8, items[0].symbol, "vector")) 1 else 0)
    else
        0;

    for (items[start_idx..]) |item| {
        if (item.* == .list) {
            const pt = item.list.items;
            const pt_start: usize = if (pt.len > 0 and pt[0].* == .symbol)
                (if (std.mem.eql(u8, pt[0].symbol, "vector") or std.mem.eql(u8, pt[0].symbol, "list")) 1 else 0)
            else
                0;
            if (pt.len >= pt_start + 2 and pt[pt_start].* == .number and pt[pt_start + 1].* == .number) {
                xs.append(allocator, pt[pt_start].number) catch return BuiltinError.OutOfMemory;
                ys.append(allocator, pt[pt_start + 1].number) catch return BuiltinError.OutOfMemory;
            }
        }
    }

    if (xs.items.len == 0) return BuiltinError.InvalidArgument;

    var x_min: f64 = xs.items[0];
    var x_max: f64 = xs.items[0];
    var y_min: f64 = ys.items[0];
    var y_max: f64 = ys.items[0];

    for (xs.items) |x| {
        x_min = @min(x_min, x);
        x_max = @max(x_max, x);
    }
    for (ys.items) |y| {
        y_min = @min(y_min, y);
        y_max = @max(y_max, y);
    }

    if (x_min == x_max) {
        x_min -= 1;
        x_max += 1;
    }
    if (y_min == y_max) {
        y_min -= 1;
        y_max += 1;
    }

    const width: usize = 60;
    const height: usize = 20;

    // Create grid
    var grid: [20][60]u8 = undefined;
    for (&grid) |*row| {
        @memset(row, ' ');
    }

    // Place points
    for (xs.items, 0..) |x, idx| {
        const y = ys.items[idx];
        const col: usize = @intFromFloat(@max(0, @min(@as(f64, @floatFromInt(width - 1)), (x - x_min) / (x_max - x_min) * @as(f64, @floatFromInt(width - 1)))));
        const row: usize = @intFromFloat(@max(0, @min(@as(f64, @floatFromInt(height - 1)), (y_max - y) / (y_max - y_min) * @as(f64, @floatFromInt(height - 1)))));
        grid[row][col] = '*';
    }

    // Build output
    var plot: std.ArrayList(u8) = .empty;
    errdefer plot.deinit(allocator);
    const writer = plot.writer(allocator);

    for (0..height) |row| {
        const y_at_row = y_max - (@as(f64, @floatFromInt(row)) / @as(f64, @floatFromInt(height - 1))) * (y_max - y_min);
        writer.print("{d:8.2} |", .{y_at_row}) catch return BuiltinError.OutOfMemory;
        for (0..width) |col| {
            writer.print("{c}", .{grid[row][col]}) catch return BuiltinError.OutOfMemory;
        }
        writer.print("\n", .{}) catch return BuiltinError.OutOfMemory;
    }

    writer.print("         +", .{}) catch return BuiltinError.OutOfMemory;
    for (0..width) |_| {
        writer.print("-", .{}) catch return BuiltinError.OutOfMemory;
    }
    writer.print("\n", .{}) catch return BuiltinError.OutOfMemory;
    writer.print("         {d:.2}", .{x_min}) catch return BuiltinError.OutOfMemory;
    for (0..40) |_| {
        writer.print(" ", .{}) catch return BuiltinError.OutOfMemory;
    }
    writer.print("{d:.2}\n", .{x_max}) catch return BuiltinError.OutOfMemory;

    const plot_str = plot.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory;

    var result_list: std.ArrayList(*Expr) = .empty;
    const plot_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plot_sym.* = .{ .symbol = "plot" };
    result_list.append(allocator, plot_sym) catch return BuiltinError.OutOfMemory;

    const plot_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    plot_expr.* = .{ .owned_symbol = plot_str };
    result_list.append(allocator, plot_expr) catch return BuiltinError.OutOfMemory;

    const points_result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    points_result.* = .{ .list = result_list };
    return points_result;
}

// ============================================================================
// Step-by-Step Solution Functions
// ============================================================================

fn stepWriteExpr(expr: *const Expr, writer: anytype) !void {
    switch (expr.*) {
        .number => |n| {
            if (n == @floor(n) and @abs(n) < 1e15) {
                try writer.print("{d:.0}", .{n});
            } else {
                try writer.print("{d}", .{n});
            }
        },
        .symbol => |s| try writer.print("{s}", .{s}),
        .owned_symbol => |s| try writer.print("{s}", .{s}),
        .lambda => |lam| {
            try writer.print("(lambda (", .{});
            for (lam.params.items, 0..) |param, i| {
                if (i > 0) try writer.print(" ", .{});
                try writer.print("{s}", .{param});
            }
            try writer.print(") ", .{});
            try stepWriteExpr(lam.body, writer);
            try writer.print(")", .{});
        },
        .list => |lst| {
            if (lst.items.len > 0) {
                try writer.print("(", .{});
                try stepWriteExpr(lst.items[0], writer);
                for (lst.items[1..]) |item| {
                    try writer.print(" ", .{});
                    try stepWriteExpr(item, writer);
                }
                try writer.print(")", .{});
            } else {
                try writer.print("()", .{});
            }
        },
    }
}

fn stepExprToString(expr: *const Expr, allocator: std.mem.Allocator) ![]u8 {
    var step_result: std.ArrayList(u8) = .empty;
    errdefer step_result.deinit(allocator);
    try stepWriteExpr(expr, step_result.writer(allocator));
    return step_result.toOwnedSlice(allocator);
}

pub fn builtin_diff_steps(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (diff-steps expr var) - Show step-by-step differentiation
    if (args.items.len < 2) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const expr = args.items[0];
    const var_expr = args.items[1];

    if (var_expr.* != .symbol) return BuiltinError.InvalidArgument;
    const var_name = var_expr.symbol;

    var steps: std.ArrayList(u8) = .empty;
    errdefer steps.deinit(allocator);
    const writer = steps.writer(allocator);

    // Step 1: Show original expression
    writer.print("Step 1: Find d/d{s} of ", .{var_name}) catch return BuiltinError.OutOfMemory;
    const orig_str = stepExprToString(expr, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(orig_str);
    writer.print("{s}\n\n", .{orig_str}) catch return BuiltinError.OutOfMemory;

    // Perform differentiation
    const diff_result = symbolic.diff(expr, var_name, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        diff_result.deinit(allocator);
        allocator.destroy(diff_result);
    }

    // Step 2: Apply differentiation rules
    writer.print("Step 2: Apply differentiation rules:\n", .{}) catch return BuiltinError.OutOfMemory;

    if (expr.* == .list and expr.list.items.len > 0) {
        const op = expr.list.items[0];
        if (op.* == .symbol) {
            const op_name = op.symbol;
            if (std.mem.eql(u8, op_name, "+") or std.mem.eql(u8, op_name, "-")) {
                writer.print("  - Sum/Difference rule: d/dx(f + g) = df/dx + dg/dx\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "*")) {
                writer.print("  - Product rule: d/dx(fg) = f'g + fg'\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "/")) {
                writer.print("  - Quotient rule: d/dx(f/g) = (f'g - fg')/g^2\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "^") or std.mem.eql(u8, op_name, "pow")) {
                writer.print("  - Power rule: d/dx(x^n) = n*x^(n-1)\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "sin")) {
                writer.print("  - d/dx(sin(u)) = cos(u) * du/dx\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "cos")) {
                writer.print("  - d/dx(cos(u)) = -sin(u) * du/dx\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "tan")) {
                writer.print("  - d/dx(tan(u)) = sec^2(u) * du/dx\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "ln") or std.mem.eql(u8, op_name, "log")) {
                writer.print("  - d/dx(ln(u)) = (1/u) * du/dx\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "exp")) {
                writer.print("  - d/dx(e^u) = e^u * du/dx\n", .{}) catch return BuiltinError.OutOfMemory;
            }
        }
    } else if (expr.* == .symbol) {
        if (std.mem.eql(u8, expr.symbol, var_name)) {
            writer.print("  - d/dx(x) = 1\n", .{}) catch return BuiltinError.OutOfMemory;
        } else {
            writer.print("  - d/dx(constant) = 0\n", .{}) catch return BuiltinError.OutOfMemory;
        }
    } else if (expr.* == .number) {
        writer.print("  - d/dx(constant) = 0\n", .{}) catch return BuiltinError.OutOfMemory;
    }

    // Step 3: Show result before simplification
    const diff_str = stepExprToString(diff_result, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(diff_str);
    writer.print("\nStep 3: Raw derivative: {s}\n", .{diff_str}) catch return BuiltinError.OutOfMemory;

    // Step 4: Simplify
    const simplified = symbolic.simplify(diff_result, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        simplified.deinit(allocator);
        allocator.destroy(simplified);
    }

    const simp_str = stepExprToString(simplified, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(simp_str);
    writer.print("\nStep 4: Simplified result: {s}\n", .{simp_str}) catch return BuiltinError.OutOfMemory;

    const steps_str = steps.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory;

    var step_result_list: std.ArrayList(*Expr) = .empty;
    const steps_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    steps_sym.* = .{ .symbol = "steps" };
    step_result_list.append(allocator, steps_sym) catch return BuiltinError.OutOfMemory;

    const steps_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    steps_expr.* = .{ .owned_symbol = steps_str };
    step_result_list.append(allocator, steps_expr) catch return BuiltinError.OutOfMemory;

    const final_result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    final_result.* = .{ .list = step_result_list };
    return final_result;
}

pub fn builtin_integrate_steps(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (integrate-steps expr var) - Show step-by-step integration
    if (args.items.len < 2) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const expr = args.items[0];
    const var_expr = args.items[1];

    if (var_expr.* != .symbol) return BuiltinError.InvalidArgument;
    const var_name = var_expr.symbol;

    var steps: std.ArrayList(u8) = .empty;
    errdefer steps.deinit(allocator);
    const writer = steps.writer(allocator);

    // Step 1: Show original expression
    writer.print("Step 1: Find integral of ", .{}) catch return BuiltinError.OutOfMemory;
    const orig_str = stepExprToString(expr, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(orig_str);
    writer.print("{s} d{s}\n\n", .{ orig_str, var_name }) catch return BuiltinError.OutOfMemory;

    // Step 2: Identify integration technique
    writer.print("Step 2: Identify integration technique:\n", .{}) catch return BuiltinError.OutOfMemory;

    if (expr.* == .number or (expr.* == .symbol and !std.mem.eql(u8, expr.symbol, var_name))) {
        writer.print("  - Constant rule: integral(c) = c*x\n", .{}) catch return BuiltinError.OutOfMemory;
    } else if (expr.* == .symbol and std.mem.eql(u8, expr.symbol, var_name)) {
        writer.print("  - Power rule: integral(x) = x^2/2\n", .{}) catch return BuiltinError.OutOfMemory;
    } else if (expr.* == .list and expr.list.items.len > 0) {
        const op = expr.list.items[0];
        if (op.* == .symbol) {
            const op_name = op.symbol;
            if (std.mem.eql(u8, op_name, "+") or std.mem.eql(u8, op_name, "-")) {
                writer.print("  - Sum/Difference rule: integral(f + g) = integral(f) + integral(g)\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "*")) {
                writer.print("  - Check for constant multiple or substitution\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "^") or std.mem.eql(u8, op_name, "pow")) {
                writer.print("  - Power rule: integral(x^n) = x^(n+1)/(n+1) for n != -1\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "sin")) {
                writer.print("  - integral(sin(x)) = -cos(x)\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "cos")) {
                writer.print("  - integral(cos(x)) = sin(x)\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "exp")) {
                writer.print("  - integral(e^x) = e^x\n", .{}) catch return BuiltinError.OutOfMemory;
            }
        }
    }

    // Perform integration
    const int_result = symbolic.integrate(expr, var_name, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        int_result.deinit(allocator);
        allocator.destroy(int_result);
    }

    // Step 3: Show result before simplification
    const int_str = stepExprToString(int_result, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(int_str);
    writer.print("\nStep 3: Raw antiderivative: {s}\n", .{int_str}) catch return BuiltinError.OutOfMemory;

    // Step 4: Simplify
    const simplified = symbolic.simplify(int_result, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        simplified.deinit(allocator);
        allocator.destroy(simplified);
    }

    const simp_str = stepExprToString(simplified, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(simp_str);
    writer.print("\nStep 4: Simplified result: {s} + C\n", .{simp_str}) catch return BuiltinError.OutOfMemory;

    const steps_str = steps.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory;

    var step_result_list: std.ArrayList(*Expr) = .empty;
    const steps_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    steps_sym.* = .{ .symbol = "steps" };
    step_result_list.append(allocator, steps_sym) catch return BuiltinError.OutOfMemory;

    const steps_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    steps_expr.* = .{ .owned_symbol = steps_str };
    step_result_list.append(allocator, steps_expr) catch return BuiltinError.OutOfMemory;

    const final_result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    final_result.* = .{ .list = step_result_list };
    return final_result;
}

pub fn builtin_simplify_steps(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (simplify-steps expr) - Show step-by-step simplification
    if (args.items.len < 1) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const expr = args.items[0];

    var steps: std.ArrayList(u8) = .empty;
    errdefer steps.deinit(allocator);
    const writer = steps.writer(allocator);

    // Step 1: Show original expression
    writer.print("Step 1: Original expression: ", .{}) catch return BuiltinError.OutOfMemory;
    const orig_str = stepExprToString(expr, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(orig_str);
    writer.print("{s}\n\n", .{orig_str}) catch return BuiltinError.OutOfMemory;

    // Step 2: List simplification rules that may apply
    writer.print("Step 2: Applicable simplification rules:\n", .{}) catch return BuiltinError.OutOfMemory;
    writer.print("  - Combine like terms\n", .{}) catch return BuiltinError.OutOfMemory;
    writer.print("  - Evaluate constant expressions\n", .{}) catch return BuiltinError.OutOfMemory;
    writer.print("  - Apply algebraic identities (x*0=0, x+0=x, x*1=x, etc.)\n", .{}) catch return BuiltinError.OutOfMemory;
    writer.print("  - Cancel common factors\n", .{}) catch return BuiltinError.OutOfMemory;

    // Perform simplification
    const simp_result = symbolic.simplify(expr, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        simp_result.deinit(allocator);
        allocator.destroy(simp_result);
    }

    // Step 3: Show result
    const simp_str = stepExprToString(simp_result, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(simp_str);
    writer.print("\nStep 3: Simplified result: {s}\n", .{simp_str}) catch return BuiltinError.OutOfMemory;

    const steps_str = steps.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory;

    var step_result_list: std.ArrayList(*Expr) = .empty;
    const steps_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    steps_sym.* = .{ .symbol = "steps" };
    step_result_list.append(allocator, steps_sym) catch return BuiltinError.OutOfMemory;

    const steps_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    steps_expr.* = .{ .owned_symbol = steps_str };
    step_result_list.append(allocator, steps_expr) catch return BuiltinError.OutOfMemory;

    const final_result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    final_result.* = .{ .list = step_result_list };
    return final_result;
}

pub fn builtin_solve_steps(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (solve-steps equation var) - Show step-by-step equation solving
    if (args.items.len < 2) return BuiltinError.InvalidArgument;

    const allocator = env.allocator;
    const eq_expr = args.items[0];
    const var_expr = args.items[1];

    if (var_expr.* != .symbol) return BuiltinError.InvalidArgument;
    const var_name = var_expr.symbol;

    var steps: std.ArrayList(u8) = .empty;
    errdefer steps.deinit(allocator);
    const writer = steps.writer(allocator);

    // Step 1: Show equation
    writer.print("Step 1: Solve for {s} in: ", .{var_name}) catch return BuiltinError.OutOfMemory;
    const orig_str = stepExprToString(eq_expr, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(orig_str);
    writer.print("{s} = 0\n\n", .{orig_str}) catch return BuiltinError.OutOfMemory;

    // Step 2: Identify equation type
    writer.print("Step 2: Identify equation type and method:\n", .{}) catch return BuiltinError.OutOfMemory;

    // Check if it's a polynomial
    if (eq_expr.* == .list and eq_expr.list.items.len > 0) {
        const op = eq_expr.list.items[0];
        if (op.* == .symbol) {
            const op_name = op.symbol;
            if (std.mem.eql(u8, op_name, "+") or std.mem.eql(u8, op_name, "-")) {
                writer.print("  - This appears to be a polynomial equation\n", .{}) catch return BuiltinError.OutOfMemory;
                writer.print("  - Method: Algebraic manipulation and factoring\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "*")) {
                writer.print("  - This is a product of terms\n", .{}) catch return BuiltinError.OutOfMemory;
                writer.print("  - Method: Set each factor to zero\n", .{}) catch return BuiltinError.OutOfMemory;
            } else if (std.mem.eql(u8, op_name, "^") or std.mem.eql(u8, op_name, "pow")) {
                writer.print("  - This involves powers\n", .{}) catch return BuiltinError.OutOfMemory;
                writer.print("  - Method: Take roots or use logarithms\n", .{}) catch return BuiltinError.OutOfMemory;
            }
        }
    }

    // Perform solve
    const solve_result = symbolic.solve(eq_expr, var_name, allocator) catch return BuiltinError.OutOfMemory;
    defer {
        solve_result.deinit(allocator);
        allocator.destroy(solve_result);
    }

    // Step 3: Show solution
    const sol_str = stepExprToString(solve_result, allocator) catch return BuiltinError.OutOfMemory;
    defer allocator.free(sol_str);
    writer.print("\nStep 3: Solution(s): {s} = {s}\n", .{ var_name, sol_str }) catch return BuiltinError.OutOfMemory;

    const steps_str = steps.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory;

    var step_result_list: std.ArrayList(*Expr) = .empty;
    const steps_sym = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    steps_sym.* = .{ .symbol = "steps" };
    step_result_list.append(allocator, steps_sym) catch return BuiltinError.OutOfMemory;

    const steps_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    steps_expr.* = .{ .owned_symbol = steps_str };
    step_result_list.append(allocator, steps_expr) catch return BuiltinError.OutOfMemory;

    const final_result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    final_result.* = .{ .list = step_result_list };
    return final_result;
}
