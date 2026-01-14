const std = @import("std");
const Expr = @import("parser.zig").Expr;

pub const SimplifyError = error{
    OutOfMemory,
    RecursionLimit,
};

const MAX_RECURSION_DEPTH = 100;

pub fn exprEqual(a: *const Expr, b: *const Expr) bool {
    switch (a.*) {
        .number => |n| {
            if (b.* == .number) {
                return n == b.number;
            }
            return false;
        },
        .symbol, .owned_symbol => |s| {
            const b_sym = switch (b.*) {
                .symbol => |bs| bs,
                .owned_symbol => |bs| bs,
                else => return false,
            };
            return std.mem.eql(u8, s, b_sym);
        },
        .list => |lst| {
            if (b.* != .list) return false;
            if (lst.items.len != b.list.items.len) return false;
            for (lst.items, b.list.items) |item_a, item_b| {
                if (!exprEqual(item_a, item_b)) return false;
            }
            return true;
        },
        .lambda => |lam_a| {
            if (b.* != .lambda) return false;
            const lam_b = b.lambda;
            if (lam_a.params.items.len != lam_b.params.items.len) return false;
            for (lam_a.params.items, lam_b.params.items) |p_a, p_b| {
                if (!std.mem.eql(u8, p_a, p_b)) return false;
            }
            return exprEqual(lam_a.body, lam_b.body);
        },
    }
}

/// Creates a deep copy of an expression.
/// The caller owns the returned expression.
pub fn copyExpr(expr: *const Expr, allocator: std.mem.Allocator) SimplifyError!*Expr {
    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    errdefer allocator.destroy(result);

    result.* = switch (expr.*) {
        .number => |n| .{ .number = n },
        .symbol => |s| .{ .symbol = s },
        .owned_symbol => |s| blk: {
            // Copy the owned string to a new allocation
            const new_str = allocator.dupe(u8, s) catch return SimplifyError.OutOfMemory;
            break :blk .{ .owned_symbol = new_str };
        },
        .list => |l| blk: {
            var new_list: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (new_list.items) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                new_list.deinit(allocator);
            }
            for (l.items) |item| {
                const copied = try copyExpr(item, allocator);
                new_list.append(allocator, copied) catch return SimplifyError.OutOfMemory;
            }
            break :blk .{ .list = new_list };
        },
        .lambda => |lam| blk: {
            var new_params: std.ArrayList([]const u8) = .empty;
            errdefer new_params.deinit(allocator);
            for (lam.params.items) |param| {
                new_params.append(allocator, param) catch return SimplifyError.OutOfMemory;
            }
            const new_body = try copyExpr(lam.body, allocator);
            break :blk .{ .lambda = .{ .params = new_params, .body = new_body } };
        },
    };
    return result;
}

fn makeNumber(allocator: std.mem.Allocator, n: f64) SimplifyError!*Expr {
    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    result.* = .{ .number = n };
    return result;
}

fn makeSymbol(allocator: std.mem.Allocator, s: []const u8) SimplifyError!*Expr {
    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    result.* = .{ .symbol = s };
    return result;
}

/// Checks if an expression contains a given variable
pub fn containsVariable(expr: *const Expr, var_name: []const u8) bool {
    switch (expr.*) {
        .number => return false,
        .symbol => |s| return std.mem.eql(u8, s, var_name),
        .owned_symbol => |s| return std.mem.eql(u8, s, var_name),
        .list => |lst| {
            for (lst.items) |item| {
                if (containsVariable(item, var_name)) return true;
            }
            return false;
        },
        .lambda => |lam| {
            // Check if var_name is bound by the lambda
            for (lam.params.items) |param| {
                if (std.mem.eql(u8, param, var_name)) return false;
            }
            return containsVariable(lam.body, var_name);
        },
    }
}

fn makeList(allocator: std.mem.Allocator, items: []const *Expr) SimplifyError!*Expr {
    var list: std.ArrayList(*Expr) = .empty;
    errdefer list.deinit(allocator);
    for (items) |item| {
        list.append(allocator, item) catch return SimplifyError.OutOfMemory;
    }
    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

pub fn makeBinOp(allocator: std.mem.Allocator, op: []const u8, left: *Expr, right: *Expr) SimplifyError!*Expr {
    const op_expr = try makeSymbol(allocator, op);
    return makeList(allocator, &[_]*Expr{ op_expr, left, right });
}

/// Simplifies an expression.
/// The input is NOT consumed - it can be used after this call.
/// Returns a NEW expression that the caller owns.
pub fn simplify(expr: *const Expr, allocator: std.mem.Allocator) SimplifyError!*Expr {
    return simplifyInternal(expr, allocator, 0);
}

fn simplifyInternal(expr: *const Expr, allocator: std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    if (depth > MAX_RECURSION_DEPTH) {
        return SimplifyError.RecursionLimit;
    }

    switch (expr.*) {
        .number => return try copyExpr(expr, allocator),
        .symbol, .owned_symbol => return try copyExpr(expr, allocator),
        .lambda => return try copyExpr(expr, allocator),
        .list => |lst| {
            if (lst.items.len == 0) return try copyExpr(expr, allocator);

            const op = lst.items[0];
            if (op.* != .symbol) return try copyExpr(expr, allocator);

            // First simplify all arguments
            var simplified_args: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (simplified_args.items) |arg| {
                    arg.deinit(allocator);
                    allocator.destroy(arg);
                }
                simplified_args.deinit(allocator);
            }

            for (lst.items[1..]) |arg| {
                const simp_arg = try simplifyInternal(arg, allocator, depth + 1);
                simplified_args.append(allocator, simp_arg) catch return SimplifyError.OutOfMemory;
            }

            // Try to evaluate numeric operations
            if (simplified_args.items.len == 2) {
                if (simplified_args.items[0].* == .number and simplified_args.items[1].* == .number) {
                    const a = simplified_args.items[0].number;
                    const b = simplified_args.items[1].number;
                    var result_val: ?f64 = null;

                    if (std.mem.eql(u8, op.symbol, "+")) {
                        result_val = a + b;
                    } else if (std.mem.eql(u8, op.symbol, "-")) {
                        result_val = a - b;
                    } else if (std.mem.eql(u8, op.symbol, "*")) {
                        result_val = a * b;
                    } else if (std.mem.eql(u8, op.symbol, "/")) {
                        if (b != 0) {
                            result_val = a / b;
                        }
                    }

                    if (result_val) |val| {
                        // Free simplified args since we're returning a number
                        for (simplified_args.items) |arg| {
                            arg.deinit(allocator);
                            allocator.destroy(arg);
                        }
                        simplified_args.deinit(allocator);
                        return try makeNumber(allocator, val);
                    }
                }
            }

            // Apply simplification rules
            if (std.mem.eql(u8, op.symbol, "+")) {
                return try simplifyAddition(&simplified_args, allocator);
            } else if (std.mem.eql(u8, op.symbol, "*")) {
                return try simplifyMultiplication(&simplified_args, allocator);
            } else if (std.mem.eql(u8, op.symbol, "-")) {
                return try simplifySubtraction(&simplified_args, allocator);
            } else if (std.mem.eql(u8, op.symbol, "/")) {
                return try simplifyDivision(&simplified_args, allocator);
            } else if (std.mem.eql(u8, op.symbol, "^")) {
                return try simplifyPower(&simplified_args, allocator);
            } else if (std.mem.eql(u8, op.symbol, "sin")) {
                return try simplifySin(&simplified_args, allocator, depth);
            } else if (std.mem.eql(u8, op.symbol, "cos")) {
                return try simplifyCos(&simplified_args, allocator, depth);
            } else if (std.mem.eql(u8, op.symbol, "tan")) {
                return try simplifyTan(&simplified_args, allocator, depth);
            } else if (std.mem.eql(u8, op.symbol, "exp")) {
                return try simplifyExp(&simplified_args, allocator, depth);
            } else if (std.mem.eql(u8, op.symbol, "ln") or std.mem.eql(u8, op.symbol, "log")) {
                return try simplifyLn(&simplified_args, allocator, depth);
            }

            // No simplification rule - return a new list with the operator and simplified args
            return try buildResultList(op.symbol, &simplified_args, allocator);
        },
    }
}

/// Builds result list and takes ownership of simplified_args
fn buildResultList(op_name: []const u8, args: *std.ArrayList(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr {
    var new_list: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (new_list.items) |item| {
            item.deinit(allocator);
            allocator.destroy(item);
        }
        new_list.deinit(allocator);
    }

    const new_op = try makeSymbol(allocator, op_name);
    new_list.append(allocator, new_op) catch return SimplifyError.OutOfMemory;
    for (args.items) |arg| {
        new_list.append(allocator, arg) catch return SimplifyError.OutOfMemory;
    }
    // We've transferred ownership of items to new_list, so just free the ArrayList's
    // internal storage without freeing the items themselves. clearAndFree would free
    // the backing array but the items pointer now belongs to new_list.
    // Use clearRetainingCapacity then deinit to properly free only the ArrayList storage.
    args.clearRetainingCapacity();
    args.deinit(allocator);

    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    result.* = .{ .list = new_list };
    return result;
}

/// Extract coefficient and base from a term.
/// For (* coeff base) returns (coeff, base)
/// For a simple expression returns (1, expr)
/// Returns null for coeff if it's implicitly 1.
const CoeffBase = struct {
    coeff: ?f64,
    base: *Expr,
    owns_base: bool, // true if we allocated base, false if it's borrowed
};

fn extractCoeffBase(term: *Expr) CoeffBase {
    // Check for (* coeff base) or (* base coeff) pattern
    if (term.* == .list) {
        const lst = term.list;
        if (lst.items.len == 3) {
            if (lst.items[0].* == .symbol or lst.items[0].* == .owned_symbol) {
                const op = switch (lst.items[0].*) {
                    .symbol => |s| s,
                    .owned_symbol => |s| s,
                    else => unreachable,
                };
                if (std.mem.eql(u8, op, "*")) {
                    // (* num base) pattern
                    if (lst.items[1].* == .number) {
                        return .{ .coeff = lst.items[1].number, .base = lst.items[2], .owns_base = false };
                    }
                    // (* base num) pattern
                    if (lst.items[2].* == .number) {
                        return .{ .coeff = lst.items[2].number, .base = lst.items[1], .owns_base = false };
                    }
                }
            }
        }
    }
    // No coefficient found - implicit coefficient of 1
    return .{ .coeff = null, .base = term, .owns_base = false };
}

/// Takes ownership of args and returns the simplified result.
fn simplifyAddition(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr {
    // Combine like terms with coefficients: 2x + 3x -> 5x
    // Use a fixed-point approach: keep combining until no more changes occur
    if (args.items.len >= 2) {
        var changed = true;
        while (changed) {
            changed = false;
            var i: usize = 0;
            outer: while (i < args.items.len) : (i += 1) {
                const cb_i = extractCoeffBase(args.items[i]);
                const coeff_i = cb_i.coeff orelse 1.0;

                var j: usize = i + 1;
                while (j < args.items.len) {
                    const cb_j = extractCoeffBase(args.items[j]);

                    // Check if bases are equal
                    if (exprEqual(cb_i.base, cb_j.base)) {
                        const coeff_j = cb_j.coeff orelse 1.0;
                        const new_coeff = coeff_i + coeff_j;

                        // Free the second term completely
                        const dup = args.orderedRemove(j);
                        dup.deinit(allocator);
                        allocator.destroy(dup);

                        // Create new_coeff * base
                        // First, copy the base since the original term owns it
                        const base_copy = try copyExpr(cb_i.base, allocator);

                        // Free the original term
                        args.items[i].deinit(allocator);
                        allocator.destroy(args.items[i]);

                        // Build new term
                        if (new_coeff == 0) {
                            base_copy.deinit(allocator);
                            allocator.destroy(base_copy);
                            args.items[i] = try makeNumber(allocator, 0);
                        } else if (new_coeff == 1) {
                            args.items[i] = base_copy;
                        } else {
                            const mul_op = try makeSymbol(allocator, "*");
                            const coeff_expr = try makeNumber(allocator, new_coeff);
                            const mul_expr = try makeList(allocator, &[_]*Expr{ mul_op, coeff_expr, base_copy });
                            args.items[i] = mul_expr;
                        }
                        // Mark changed and restart the outer loop to re-extract fresh coeffbase
                        changed = true;
                        continue :outer;
                    }
                    j += 1;
                }
            }
        }
    }

    // Remove zeros from the sum
    {
        var i: usize = 0;
        while (i < args.items.len) {
            if (args.items[i].* == .number and args.items[i].number == 0) {
                const zero = args.orderedRemove(i);
                zero.deinit(allocator);
                allocator.destroy(zero);
            } else {
                i += 1;
            }
        }
    }

    // Empty sum (all zeros) = 0
    if (args.items.len == 0) {
        args.deinit(allocator);
        return try makeNumber(allocator, 0);
    }

    // Single argument: return it directly
    if (args.items.len == 1) {
        const result = args.items[0];
        args.deinit(allocator);
        return result;
    }

    return try buildResultList("+", args, allocator);
}

/// Takes ownership of args and returns the simplified result.
fn simplifyMultiplication(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr {
    // x * 1 = x, x * 0 = 0
    if (args.items.len == 2) {
        if (args.items[1].* == .number) {
            if (args.items[1].number == 1) {
                const result = args.items[0];
                args.items[1].deinit(allocator);
                allocator.destroy(args.items[1]);
                args.deinit(allocator);
                return result;
            }
            if (args.items[1].number == 0) {
                for (args.items) |arg| {
                    arg.deinit(allocator);
                    allocator.destroy(arg);
                }
                args.deinit(allocator);
                return try makeNumber(allocator, 0);
            }
        }
        if (args.items[0].* == .number) {
            if (args.items[0].number == 1) {
                const result = args.items[1];
                args.items[0].deinit(allocator);
                allocator.destroy(args.items[0]);
                args.deinit(allocator);
                return result;
            }
            if (args.items[0].number == 0) {
                for (args.items) |arg| {
                    arg.deinit(allocator);
                    allocator.destroy(arg);
                }
                args.deinit(allocator);
                return try makeNumber(allocator, 0);
            }
        }
    }

    // Single argument: return it directly
    if (args.items.len == 1) {
        const result = args.items[0];
        args.deinit(allocator);
        return result;
    }

    return try buildResultList("*", args, allocator);
}

/// Takes ownership of args and returns the simplified result.
fn simplifySubtraction(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr {
    if (args.items.len == 2) {
        // x - x = 0
        if (exprEqual(args.items[0], args.items[1])) {
            for (args.items) |arg| {
                arg.deinit(allocator);
                allocator.destroy(arg);
            }
            args.deinit(allocator);
            return try makeNumber(allocator, 0);
        }
        // x - 0 = x
        if (args.items[1].* == .number and args.items[1].number == 0) {
            const result = args.items[0];
            args.items[1].deinit(allocator);
            allocator.destroy(args.items[1]);
            args.deinit(allocator);
            return result;
        }
    }

    return try buildResultList("-", args, allocator);
}

/// Takes ownership of args and returns the simplified result.
fn simplifyDivision(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr {
    if (args.items.len == 2) {
        // x / x = 1 (but NOT 0/0 which is undefined)
        if (exprEqual(args.items[0], args.items[1])) {
            // Don't simplify 0/0 to 1 - it's undefined
            const is_zero = (args.items[0].* == .number and args.items[0].number == 0);
            if (!is_zero) {
                for (args.items) |arg| {
                    arg.deinit(allocator);
                    allocator.destroy(arg);
                }
                args.deinit(allocator);
                return try makeNumber(allocator, 1);
            }
        }
        // x / 1 = x
        if (args.items[1].* == .number and args.items[1].number == 1) {
            const result = args.items[0];
            args.items[1].deinit(allocator);
            allocator.destroy(args.items[1]);
            args.deinit(allocator);
            return result;
        }
    }

    return try buildResultList("/", args, allocator);
}

/// Takes ownership of args and returns the simplified result.
fn simplifyPower(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr {
    if (args.items.len == 2) {
        // x^0 = 1
        if (args.items[1].* == .number and args.items[1].number == 0) {
            for (args.items) |arg| {
                arg.deinit(allocator);
                allocator.destroy(arg);
            }
            args.deinit(allocator);
            return try makeNumber(allocator, 1);
        }
        // x^1 = x
        if (args.items[1].* == .number and args.items[1].number == 1) {
            const result = args.items[0];
            args.items[1].deinit(allocator);
            allocator.destroy(args.items[1]);
            args.deinit(allocator);
            return result;
        }
        // 0^x = 0 (for x > 0, but we'll keep it simple)
        if (args.items[0].* == .number and args.items[0].number == 0) {
            for (args.items) |arg| {
                arg.deinit(allocator);
                allocator.destroy(arg);
            }
            args.deinit(allocator);
            return try makeNumber(allocator, 0);
        }
        // 1^x = 1
        if (args.items[0].* == .number and args.items[0].number == 1) {
            for (args.items) |arg| {
                arg.deinit(allocator);
                allocator.destroy(arg);
            }
            args.deinit(allocator);
            return try makeNumber(allocator, 1);
        }
        // Both numbers: compute the power
        if (args.items[0].* == .number and args.items[1].* == .number) {
            const base = args.items[0].number;
            const exp = args.items[1].number;
            const result_val = std.math.pow(f64, base, exp);
            for (args.items) |arg| {
                arg.deinit(allocator);
                allocator.destroy(arg);
            }
            args.deinit(allocator);
            return try makeNumber(allocator, result_val);
        }
    }

    return try buildResultList("^", args, allocator);
}

// ============================================================================
// Trigonometric and Logarithmic Simplifications
// ============================================================================

fn simplifySin(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    _ = depth;
    if (args.items.len != 1) return try buildResultList("sin", args, allocator);

    const arg = args.items[0];

    // sin(0) = 0
    if (arg.* == .number and arg.number == 0) {
        arg.deinit(allocator);
        allocator.destroy(arg);
        args.deinit(allocator);
        return try makeNumber(allocator, 0);
    }

    // sin(asin(x)) = x (if we had asin...)

    return try buildResultList("sin", args, allocator);
}

fn simplifyCos(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    _ = depth;
    if (args.items.len != 1) return try buildResultList("cos", args, allocator);

    const arg = args.items[0];

    // cos(0) = 1
    if (arg.* == .number and arg.number == 0) {
        arg.deinit(allocator);
        allocator.destroy(arg);
        args.deinit(allocator);
        return try makeNumber(allocator, 1);
    }

    return try buildResultList("cos", args, allocator);
}

fn simplifyTan(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    _ = depth;
    if (args.items.len != 1) return try buildResultList("tan", args, allocator);

    const arg = args.items[0];

    // tan(0) = 0
    if (arg.* == .number and arg.number == 0) {
        arg.deinit(allocator);
        allocator.destroy(arg);
        args.deinit(allocator);
        return try makeNumber(allocator, 0);
    }

    return try buildResultList("tan", args, allocator);
}

fn simplifyExp(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    _ = depth;
    if (args.items.len != 1) return try buildResultList("exp", args, allocator);

    const arg = args.items[0];

    // exp(0) = 1
    if (arg.* == .number and arg.number == 0) {
        arg.deinit(allocator);
        allocator.destroy(arg);
        args.deinit(allocator);
        return try makeNumber(allocator, 1);
    }

    // exp(ln(x)) = x
    if (arg.* == .list) {
        const lst = arg.list;
        if (lst.items.len == 2 and lst.items[0].* == .symbol) {
            const inner_op = lst.items[0].symbol;
            if (std.mem.eql(u8, inner_op, "ln") or std.mem.eql(u8, inner_op, "log")) {
                // exp(ln(x)) = x - return a copy of the inner argument
                const inner_arg = lst.items[1];
                const result = try copyExpr(inner_arg, allocator);
                arg.deinit(allocator);
                allocator.destroy(arg);
                args.deinit(allocator);
                return result;
            }
        }
    }

    return try buildResultList("exp", args, allocator);
}

fn simplifyLn(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    _ = depth;
    if (args.items.len != 1) return try buildResultList("ln", args, allocator);

    const arg = args.items[0];

    // ln(1) = 0
    if (arg.* == .number and arg.number == 1) {
        arg.deinit(allocator);
        allocator.destroy(arg);
        args.deinit(allocator);
        return try makeNumber(allocator, 0);
    }

    // ln(e) = 1 (if arg is the symbol "e")
    if (arg.* == .symbol and std.mem.eql(u8, arg.symbol, "e")) {
        arg.deinit(allocator);
        allocator.destroy(arg);
        args.deinit(allocator);
        return try makeNumber(allocator, 1);
    }

    // ln(exp(x)) = x
    if (arg.* == .list) {
        const lst = arg.list;
        if (lst.items.len == 2 and lst.items[0].* == .symbol) {
            const inner_op = lst.items[0].symbol;
            if (std.mem.eql(u8, inner_op, "exp")) {
                // ln(exp(x)) = x
                const inner_arg = lst.items[1];
                const result = try copyExpr(inner_arg, allocator);
                arg.deinit(allocator);
                allocator.destroy(arg);
                args.deinit(allocator);
                return result;
            }
        }
    }

    // ln(x^n) = n * ln(x)
    if (arg.* == .list) {
        const lst = arg.list;
        if (lst.items.len == 3 and lst.items[0].* == .symbol and std.mem.eql(u8, lst.items[0].symbol, "^")) {
            const base = lst.items[1];
            const exponent = lst.items[2];
            // Create n * ln(base)
            const base_copy = try copyExpr(base, allocator);
            const exp_copy = try copyExpr(exponent, allocator);
            const ln_base = try makeUnaryOp(allocator, "ln", base_copy);
            const result = try makeBinOp(allocator, "*", exp_copy, ln_base);

            arg.deinit(allocator);
            allocator.destroy(arg);
            args.deinit(allocator);
            return result;
        }
    }

    return try buildResultList("ln", args, allocator);
}

fn makeUnaryOp(allocator: std.mem.Allocator, op: []const u8, arg: *Expr) SimplifyError!*Expr {
    const op_expr = try makeSymbol(allocator, op);
    errdefer {
        op_expr.deinit(allocator);
        allocator.destroy(op_expr);
    }
    return makeList(allocator, &[_]*Expr{ op_expr, arg });
}

/// Differentiates an expression with respect to a variable and simplifies the result.
/// Returns a NEW expression that the caller owns.
pub fn diff(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr {
    const raw_result = try diffInternal(expr, var_name, allocator);
    defer {
        raw_result.deinit(allocator);
        allocator.destroy(raw_result);
    }
    return try simplify(raw_result, allocator);
}

fn diffInternal(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr {
    switch (expr.*) {
        .number => {
            return try makeNumber(allocator, 0);
        },
        .symbol, .owned_symbol => |s| {
            return try makeNumber(allocator, if (std.mem.eql(u8, s, var_name)) 1 else 0);
        },
        .lambda => {
            // Lambda is treated as constant for differentiation
            return try makeNumber(allocator, 0);
        },
        .list => |lst| {
            if (lst.items.len == 0) return try copyExpr(expr, allocator);
            const op = lst.items[0];
            if (op.* != .symbol) return try copyExpr(expr, allocator);

            if (std.mem.eql(u8, op.symbol, "+") or std.mem.eql(u8, op.symbol, "-")) {
                // d/dx(u + v) = d/dx(u) + d/dx(v)
                var new_list: std.ArrayList(*Expr) = .empty;
                errdefer {
                    for (new_list.items) |item| {
                        item.deinit(allocator);
                        allocator.destroy(item);
                    }
                    new_list.deinit(allocator);
                }
                const new_op = try makeSymbol(allocator, op.symbol);
                new_list.append(allocator, new_op) catch return SimplifyError.OutOfMemory;

                for (lst.items[1..]) |arg| {
                    const d = try diffInternal(arg, var_name, allocator);
                    new_list.append(allocator, d) catch return SimplifyError.OutOfMemory;
                }

                const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
                result.* = .{ .list = new_list };
                return result;
            } else if (std.mem.eql(u8, op.symbol, "*")) {
                // Product rule: d/dx(u * v) = u * dv + v * du
                if (lst.items.len == 3) {
                    const u = lst.items[1];
                    const v = lst.items[2];
                    const du = try diffInternal(u, var_name, allocator);
                    errdefer {
                        du.deinit(allocator);
                        allocator.destroy(du);
                    }
                    const dv = try diffInternal(v, var_name, allocator);
                    errdefer {
                        dv.deinit(allocator);
                        allocator.destroy(dv);
                    }

                    // u * dv
                    const u_copy = try copyExpr(u, allocator);
                    const term1 = try makeBinOp(allocator, "*", u_copy, dv);

                    // v * du
                    const v_copy = try copyExpr(v, allocator);
                    const term2 = try makeBinOp(allocator, "*", v_copy, du);

                    // term1 + term2
                    return try makeBinOp(allocator, "+", term1, term2);
                }
            } else if (std.mem.eql(u8, op.symbol, "/")) {
                // Quotient rule: d/dx(u/v) = (v*du - u*dv) / v^2
                if (lst.items.len == 3) {
                    const u = lst.items[1];
                    const v = lst.items[2];
                    const du = try diffInternal(u, var_name, allocator);
                    const dv = try diffInternal(v, var_name, allocator);

                    // v * du
                    const v_copy1 = try copyExpr(v, allocator);
                    const term1 = try makeBinOp(allocator, "*", v_copy1, du);

                    // u * dv
                    const u_copy = try copyExpr(u, allocator);
                    const term2 = try makeBinOp(allocator, "*", u_copy, dv);

                    // numerator = term1 - term2
                    const numer = try makeBinOp(allocator, "-", term1, term2);

                    // denominator = v * v
                    const v_copy2 = try copyExpr(v, allocator);
                    const v_copy3 = try copyExpr(v, allocator);
                    const denom = try makeBinOp(allocator, "*", v_copy2, v_copy3);

                    return try makeBinOp(allocator, "/", numer, denom);
                }
            } else if (std.mem.eql(u8, op.symbol, "^")) {
                // Power rule: d/dx(u^n) = n * u^(n-1) * du/dx
                // For simplicity, we handle u^n where n is a constant
                if (lst.items.len == 3) {
                    const base = lst.items[1];
                    const exp = lst.items[2];

                    // For now, only handle constant exponents
                    if (exp.* == .number) {
                        const n = exp.number;
                        const du = try diffInternal(base, var_name, allocator);

                        // n * u^(n-1)
                        const n_expr = try makeNumber(allocator, n);
                        const base_copy = try copyExpr(base, allocator);
                        const n_minus_1 = try makeNumber(allocator, n - 1);
                        const power_term = try makeBinOp(allocator, "^", base_copy, n_minus_1);
                        const coeff_times_power = try makeBinOp(allocator, "*", n_expr, power_term);

                        // n * u^(n-1) * du
                        return try makeBinOp(allocator, "*", coeff_times_power, du);
                    } else {
                        // For general u^v, use d/dx(u^v) = u^v * (v' * ln(u) + v * u'/u)
                        // This requires ln function, so for now we return a copy
                        return try copyExpr(expr, allocator);
                    }
                }
            } else if (std.mem.eql(u8, op.symbol, "sin")) {
                // d/dx(sin(u)) = cos(u) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    // cos(u)
                    const cos_op = try makeSymbol(allocator, "cos");
                    const u_copy = try copyExpr(u, allocator);
                    const cos_u = try makeList(allocator, &[_]*Expr{ cos_op, u_copy });

                    // cos(u) * du
                    return try makeBinOp(allocator, "*", cos_u, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "cos")) {
                // d/dx(cos(u)) = -sin(u) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    // sin(u)
                    const sin_op = try makeSymbol(allocator, "sin");
                    const u_copy = try copyExpr(u, allocator);
                    const sin_u = try makeList(allocator, &[_]*Expr{ sin_op, u_copy });

                    // -1 * sin(u) * du
                    const neg_one = try makeNumber(allocator, -1);
                    const neg_sin_u = try makeBinOp(allocator, "*", neg_one, sin_u);
                    return try makeBinOp(allocator, "*", neg_sin_u, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "tan")) {
                // d/dx(tan(u)) = sec^2(u) * du/dx = (1/cos^2(u)) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    // cos(u)
                    const cos_op = try makeSymbol(allocator, "cos");
                    const u_copy = try copyExpr(u, allocator);
                    const cos_u = try makeList(allocator, &[_]*Expr{ cos_op, u_copy });

                    // cos(u)^2
                    const two = try makeNumber(allocator, 2);
                    const cos_sq = try makeBinOp(allocator, "^", cos_u, two);

                    // 1 / cos(u)^2
                    const one = try makeNumber(allocator, 1);
                    const sec_sq = try makeBinOp(allocator, "/", one, cos_sq);

                    // sec^2(u) * du
                    return try makeBinOp(allocator, "*", sec_sq, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "exp")) {
                // d/dx(exp(u)) = exp(u) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    // exp(u)
                    const exp_op = try makeSymbol(allocator, "exp");
                    const u_copy = try copyExpr(u, allocator);
                    const exp_u = try makeList(allocator, &[_]*Expr{ exp_op, u_copy });

                    // exp(u) * du
                    return try makeBinOp(allocator, "*", exp_u, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "ln")) {
                // d/dx(ln(u)) = (1/u) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    // 1/u
                    const one = try makeNumber(allocator, 1);
                    const u_copy = try copyExpr(u, allocator);
                    const inv_u = try makeBinOp(allocator, "/", one, u_copy);

                    // (1/u) * du
                    return try makeBinOp(allocator, "*", inv_u, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "log")) {
                // d/dx(log(u)) = (1/(u * ln(10))) * du/dx (base 10)
                // d/dx(log(b, u)) = (1/(u * ln(b))) * du/dx (general base)
                if (lst.items.len == 2) {
                    // log base 10
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    // ln(10)
                    const ln_10 = try makeNumber(allocator, @log(10.0));
                    const u_copy = try copyExpr(u, allocator);
                    const u_ln_10 = try makeBinOp(allocator, "*", u_copy, ln_10);
                    const one = try makeNumber(allocator, 1);
                    const inv = try makeBinOp(allocator, "/", one, u_ln_10);

                    return try makeBinOp(allocator, "*", inv, du);
                } else if (lst.items.len == 3) {
                    // log with base
                    const base = lst.items[1];
                    const u = lst.items[2];
                    const du = try diffInternal(u, var_name, allocator);

                    // ln(base)
                    const ln_op = try makeSymbol(allocator, "ln");
                    const base_copy = try copyExpr(base, allocator);
                    const ln_base = try makeList(allocator, &[_]*Expr{ ln_op, base_copy });

                    // u * ln(base)
                    const u_copy = try copyExpr(u, allocator);
                    const u_ln_base = try makeBinOp(allocator, "*", u_copy, ln_base);
                    const one = try makeNumber(allocator, 1);
                    const inv = try makeBinOp(allocator, "/", one, u_ln_base);

                    return try makeBinOp(allocator, "*", inv, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "asin")) {
                // d/dx(asin(u)) = 1/sqrt(1-u^2) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    // 1 - u^2
                    const one = try makeNumber(allocator, 1);
                    const u_copy = try copyExpr(u, allocator);
                    const two = try makeNumber(allocator, 2);
                    const u_sq = try makeBinOp(allocator, "^", u_copy, two);
                    const one_minus_u_sq = try makeBinOp(allocator, "-", one, u_sq);

                    // sqrt(1 - u^2)
                    const half = try makeNumber(allocator, 0.5);
                    const sqrt_term = try makeBinOp(allocator, "^", one_minus_u_sq, half);

                    // 1 / sqrt(1 - u^2)
                    const one2 = try makeNumber(allocator, 1);
                    const inv = try makeBinOp(allocator, "/", one2, sqrt_term);

                    return try makeBinOp(allocator, "*", inv, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "acos")) {
                // d/dx(acos(u)) = -1/sqrt(1-u^2) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    // 1 - u^2
                    const one = try makeNumber(allocator, 1);
                    const u_copy = try copyExpr(u, allocator);
                    const two = try makeNumber(allocator, 2);
                    const u_sq = try makeBinOp(allocator, "^", u_copy, two);
                    const one_minus_u_sq = try makeBinOp(allocator, "-", one, u_sq);

                    // sqrt(1 - u^2)
                    const half = try makeNumber(allocator, 0.5);
                    const sqrt_term = try makeBinOp(allocator, "^", one_minus_u_sq, half);

                    // -1 / sqrt(1 - u^2)
                    const neg_one = try makeNumber(allocator, -1);
                    const inv = try makeBinOp(allocator, "/", neg_one, sqrt_term);

                    return try makeBinOp(allocator, "*", inv, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "atan")) {
                // d/dx(atan(u)) = 1/(1+u^2) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    // 1 + u^2
                    const one = try makeNumber(allocator, 1);
                    const u_copy = try copyExpr(u, allocator);
                    const two = try makeNumber(allocator, 2);
                    const u_sq = try makeBinOp(allocator, "^", u_copy, two);
                    const one_plus_u_sq = try makeBinOp(allocator, "+", one, u_sq);

                    // 1 / (1 + u^2)
                    const one2 = try makeNumber(allocator, 1);
                    const inv = try makeBinOp(allocator, "/", one2, one_plus_u_sq);

                    return try makeBinOp(allocator, "*", inv, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "sinh")) {
                // d/dx(sinh(u)) = cosh(u) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    const cosh_op = try makeSymbol(allocator, "cosh");
                    const u_copy = try copyExpr(u, allocator);
                    const cosh_u = try makeList(allocator, &[_]*Expr{ cosh_op, u_copy });

                    return try makeBinOp(allocator, "*", cosh_u, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "cosh")) {
                // d/dx(cosh(u)) = sinh(u) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    const sinh_op = try makeSymbol(allocator, "sinh");
                    const u_copy = try copyExpr(u, allocator);
                    const sinh_u = try makeList(allocator, &[_]*Expr{ sinh_op, u_copy });

                    return try makeBinOp(allocator, "*", sinh_u, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "tanh")) {
                // d/dx(tanh(u)) = sech^2(u) * du/dx = 1/cosh^2(u) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    const cosh_op = try makeSymbol(allocator, "cosh");
                    const u_copy = try copyExpr(u, allocator);
                    const cosh_u = try makeList(allocator, &[_]*Expr{ cosh_op, u_copy });

                    const two = try makeNumber(allocator, 2);
                    const cosh_sq = try makeBinOp(allocator, "^", cosh_u, two);

                    const one = try makeNumber(allocator, 1);
                    const sech_sq = try makeBinOp(allocator, "/", one, cosh_sq);

                    return try makeBinOp(allocator, "*", sech_sq, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "asinh")) {
                // d/dx(asinh(u)) = 1/sqrt(u^2+1) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    const u_copy = try copyExpr(u, allocator);
                    const two = try makeNumber(allocator, 2);
                    const u_sq = try makeBinOp(allocator, "^", u_copy, two);
                    const one = try makeNumber(allocator, 1);
                    const u_sq_plus_one = try makeBinOp(allocator, "+", u_sq, one);

                    const half = try makeNumber(allocator, 0.5);
                    const sqrt_term = try makeBinOp(allocator, "^", u_sq_plus_one, half);

                    const one2 = try makeNumber(allocator, 1);
                    const inv = try makeBinOp(allocator, "/", one2, sqrt_term);

                    return try makeBinOp(allocator, "*", inv, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "acosh")) {
                // d/dx(acosh(u)) = 1/sqrt(u^2-1) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    const u_copy = try copyExpr(u, allocator);
                    const two = try makeNumber(allocator, 2);
                    const u_sq = try makeBinOp(allocator, "^", u_copy, two);
                    const one = try makeNumber(allocator, 1);
                    const u_sq_minus_one = try makeBinOp(allocator, "-", u_sq, one);

                    const half = try makeNumber(allocator, 0.5);
                    const sqrt_term = try makeBinOp(allocator, "^", u_sq_minus_one, half);

                    const one2 = try makeNumber(allocator, 1);
                    const inv = try makeBinOp(allocator, "/", one2, sqrt_term);

                    return try makeBinOp(allocator, "*", inv, du);
                }
            } else if (std.mem.eql(u8, op.symbol, "atanh")) {
                // d/dx(atanh(u)) = 1/(1-u^2) * du/dx
                if (lst.items.len == 2) {
                    const u = lst.items[1];
                    const du = try diffInternal(u, var_name, allocator);

                    const one = try makeNumber(allocator, 1);
                    const u_copy = try copyExpr(u, allocator);
                    const two = try makeNumber(allocator, 2);
                    const u_sq = try makeBinOp(allocator, "^", u_copy, two);
                    const one_minus_u_sq = try makeBinOp(allocator, "-", one, u_sq);

                    const one2 = try makeNumber(allocator, 1);
                    const inv = try makeBinOp(allocator, "/", one2, one_minus_u_sq);

                    return try makeBinOp(allocator, "*", inv, du);
                }
            }

            // Unknown operation - return copy of input
            return try copyExpr(expr, allocator);
        },
    }
}

/// Integrates an expression with respect to a variable and simplifies the result.
/// Returns a NEW expression that the caller owns.
/// Note: This is symbolic integration for basic patterns only.
pub fn integrate(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr {
    const raw_result = try integrateInternal(expr, var_name, allocator);
    defer {
        raw_result.deinit(allocator);
        allocator.destroy(raw_result);
    }
    return try simplify(raw_result, allocator);
}

fn integrateInternal(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr {
    switch (expr.*) {
        .number => |n| {
            // ∫c dx = c*x
            const c = try makeNumber(allocator, n);
            const x = try makeSymbol(allocator, var_name);
            return try makeBinOp(allocator, "*", c, x);
        },
        .lambda => {
            // Lambda is treated as constant for integration
            const c = try copyExpr(expr, allocator);
            const x = try makeSymbol(allocator, var_name);
            return try makeBinOp(allocator, "*", c, x);
        },
        .symbol, .owned_symbol => |s| {
            if (std.mem.eql(u8, s, var_name)) {
                // ∫x dx = x^2/2
                const x = try makeSymbol(allocator, var_name);
                const two = try makeNumber(allocator, 2);
                const x_sq = try makeBinOp(allocator, "^", x, two);
                const half = try makeNumber(allocator, 0.5);
                return try makeBinOp(allocator, "*", half, x_sq);
            } else {
                // ∫c dx = c*x where c is a constant (different variable)
                const c = try makeSymbol(allocator, s);
                const x = try makeSymbol(allocator, var_name);
                return try makeBinOp(allocator, "*", c, x);
            }
        },
        .list => |lst| {
            if (lst.items.len == 0) return try copyExpr(expr, allocator);
            const op = lst.items[0];
            if (op.* != .symbol) return try copyExpr(expr, allocator);

            if (std.mem.eql(u8, op.symbol, "+") or std.mem.eql(u8, op.symbol, "-")) {
                // ∫(f ± g) dx = ∫f dx ± ∫g dx
                var new_list: std.ArrayList(*Expr) = .empty;
                errdefer {
                    for (new_list.items) |item| {
                        item.deinit(allocator);
                        allocator.destroy(item);
                    }
                    new_list.deinit(allocator);
                }
                const new_op = try makeSymbol(allocator, op.symbol);
                new_list.append(allocator, new_op) catch return SimplifyError.OutOfMemory;

                for (lst.items[1..]) |arg| {
                    const int_arg = try integrateInternal(arg, var_name, allocator);
                    new_list.append(allocator, int_arg) catch return SimplifyError.OutOfMemory;
                }

                const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
                result.* = .{ .list = new_list };
                return result;
            } else if (std.mem.eql(u8, op.symbol, "*")) {
                // For c*f(x), try to pull out constant and integrate
                if (lst.items.len == 3) {
                    const first = lst.items[1];
                    const second = lst.items[2];

                    // Check if first is constant (number or different variable)
                    if (first.* == .number or (first.* == .symbol and !std.mem.eql(u8, first.symbol, var_name))) {
                        // ∫c*f dx = c * ∫f dx
                        const c = try copyExpr(first, allocator);
                        const int_f = try integrateInternal(second, var_name, allocator);
                        return try makeBinOp(allocator, "*", c, int_f);
                    }

                    // Check if second is constant
                    if (second.* == .number or (second.* == .symbol and !std.mem.eql(u8, second.symbol, var_name))) {
                        // ∫f*c dx = c * ∫f dx
                        const c = try copyExpr(second, allocator);
                        const int_f = try integrateInternal(first, var_name, allocator);
                        return try makeBinOp(allocator, "*", c, int_f);
                    }
                }
            } else if (std.mem.eql(u8, op.symbol, "^")) {
                // Power rule: ∫x^n dx = x^(n+1)/(n+1)
                if (lst.items.len == 3) {
                    const base = lst.items[1];
                    const exp = lst.items[2];

                    // Check if base is just the variable and exp is a number
                    if (base.* == .symbol and std.mem.eql(u8, base.symbol, var_name)) {
                        if (exp.* == .number) {
                            const n = exp.number;
                            if (n == -1) {
                                // ∫x^(-1) dx = ln(x)
                                const ln_op = try makeSymbol(allocator, "ln");
                                const x = try makeSymbol(allocator, var_name);
                                return try makeList(allocator, &[_]*Expr{ ln_op, x });
                            } else {
                                // ∫x^n dx = x^(n+1)/(n+1)
                                const x = try makeSymbol(allocator, var_name);
                                const n_plus_1 = try makeNumber(allocator, n + 1);
                                const power = try makeBinOp(allocator, "^", x, n_plus_1);
                                const divisor = try makeNumber(allocator, n + 1);
                                return try makeBinOp(allocator, "/", power, divisor);
                            }
                        }
                    }
                }
            } else if (std.mem.eql(u8, op.symbol, "/")) {
                // Check for 1/x pattern
                if (lst.items.len == 3) {
                    const numer = lst.items[1];
                    const denom = lst.items[2];
                    if (numer.* == .number and numer.number == 1) {
                        if (denom.* == .symbol and std.mem.eql(u8, denom.symbol, var_name)) {
                            // ∫1/x dx = ln(x)
                            const ln_op = try makeSymbol(allocator, "ln");
                            const x = try makeSymbol(allocator, var_name);
                            return try makeList(allocator, &[_]*Expr{ ln_op, x });
                        }
                    }
                }
            } else if (std.mem.eql(u8, op.symbol, "sin")) {
                // ∫sin(x) dx = -cos(x)
                if (lst.items.len == 2) {
                    const arg = lst.items[1];
                    if (arg.* == .symbol and std.mem.eql(u8, arg.symbol, var_name)) {
                        const neg_one = try makeNumber(allocator, -1);
                        const cos_op = try makeSymbol(allocator, "cos");
                        const x = try makeSymbol(allocator, var_name);
                        const cos_x = try makeList(allocator, &[_]*Expr{ cos_op, x });
                        return try makeBinOp(allocator, "*", neg_one, cos_x);
                    }
                }
            } else if (std.mem.eql(u8, op.symbol, "cos")) {
                // ∫cos(x) dx = sin(x)
                if (lst.items.len == 2) {
                    const arg = lst.items[1];
                    if (arg.* == .symbol and std.mem.eql(u8, arg.symbol, var_name)) {
                        const sin_op = try makeSymbol(allocator, "sin");
                        const x = try makeSymbol(allocator, var_name);
                        return try makeList(allocator, &[_]*Expr{ sin_op, x });
                    }
                }
            } else if (std.mem.eql(u8, op.symbol, "exp")) {
                // ∫exp(x) dx = exp(x)
                if (lst.items.len == 2) {
                    const arg = lst.items[1];
                    if (arg.* == .symbol and std.mem.eql(u8, arg.symbol, var_name)) {
                        const exp_op = try makeSymbol(allocator, "exp");
                        const x = try makeSymbol(allocator, var_name);
                        return try makeList(allocator, &[_]*Expr{ exp_op, x });
                    }
                }
            }

            // Cannot integrate - return integral symbol
            var int_list: std.ArrayList(*Expr) = .empty;
            const int_op = try makeSymbol(allocator, "integral");
            int_list.append(allocator, int_op) catch return SimplifyError.OutOfMemory;
            const expr_copy = try copyExpr(expr, allocator);
            int_list.append(allocator, expr_copy) catch return SimplifyError.OutOfMemory;
            const var_sym = try makeSymbol(allocator, var_name);
            int_list.append(allocator, var_sym) catch return SimplifyError.OutOfMemory;
            const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
            result.* = .{ .list = int_list };
            return result;
        },
    }
}

/// Expands an expression (distributes multiplication over addition).
/// Returns a NEW expression that the caller owns.
pub fn expand(expr: *const Expr, allocator: std.mem.Allocator) SimplifyError!*Expr {
    const expanded = try expandInternal(expr, allocator, 0);
    defer {
        expanded.deinit(allocator);
        allocator.destroy(expanded);
    }
    return try simplify(expanded, allocator);
}

fn expandInternal(expr: *const Expr, allocator: std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    if (depth > MAX_RECURSION_DEPTH) {
        return SimplifyError.RecursionLimit;
    }

    switch (expr.*) {
        .number => return try copyExpr(expr, allocator),
        .symbol, .owned_symbol => return try copyExpr(expr, allocator),
        .lambda => return try copyExpr(expr, allocator),
        .list => |lst| {
            if (lst.items.len == 0) return try copyExpr(expr, allocator);
            const op = lst.items[0];
            if (op.* != .symbol) return try copyExpr(expr, allocator);

            if (std.mem.eql(u8, op.symbol, "*")) {
                // First expand all arguments
                var expanded_args: std.ArrayList(*Expr) = .empty;
                defer {
                    for (expanded_args.items) |arg| {
                        arg.deinit(allocator);
                        allocator.destroy(arg);
                    }
                    expanded_args.deinit(allocator);
                }
                for (lst.items[1..]) |arg| {
                    const exp_arg = try expandInternal(arg, allocator, depth + 1);
                    expanded_args.append(allocator, exp_arg) catch return SimplifyError.OutOfMemory;
                }

                // Distribute multiplication over addition
                return try distributeProduct(&expanded_args, allocator);
            } else if (std.mem.eql(u8, op.symbol, "^")) {
                // (a + b)^n expansion for positive integer n
                if (lst.items.len == 3) {
                    const base = lst.items[1];
                    const exp = lst.items[2];

                    if (exp.* == .number) {
                        const n = exp.number;
                        // Only expand for small positive integers
                        if (n > 0 and n == @floor(n) and n <= 10) {
                            const n_int: usize = @intFromFloat(n);
                            const expanded_base = try expandInternal(base, allocator, depth + 1);
                            defer {
                                expanded_base.deinit(allocator);
                                allocator.destroy(expanded_base);
                            }

                            // Create expanded_base * expanded_base * ... n times
                            var result = try copyExpr(expanded_base, allocator);
                            for (1..n_int) |_| {
                                // distributeProduct takes ownership of its args, so we don't free them
                                const result_copy = try copyExpr(result, allocator);
                                const base_copy = try copyExpr(expanded_base, allocator);
                                var args: std.ArrayList(*Expr) = .empty;
                                args.append(allocator, result_copy) catch return SimplifyError.OutOfMemory;
                                args.append(allocator, base_copy) catch return SimplifyError.OutOfMemory;
                                const new_result = try distributeProduct(&args, allocator);
                                // distributeProduct copies the args it needs, so we need to free them
                                for (args.items) |arg| {
                                    arg.deinit(allocator);
                                    allocator.destroy(arg);
                                }
                                args.deinit(allocator);
                                result.deinit(allocator);
                                allocator.destroy(result);
                                result = new_result;
                            }
                            return result;
                        }
                    }
                }
            } else if (std.mem.eql(u8, op.symbol, "+") or std.mem.eql(u8, op.symbol, "-")) {
                // Recursively expand terms
                var new_list: std.ArrayList(*Expr) = .empty;
                errdefer {
                    for (new_list.items) |item| {
                        item.deinit(allocator);
                        allocator.destroy(item);
                    }
                    new_list.deinit(allocator);
                }
                const new_op = try makeSymbol(allocator, op.symbol);
                new_list.append(allocator, new_op) catch return SimplifyError.OutOfMemory;

                for (lst.items[1..]) |arg| {
                    const exp_arg = try expandInternal(arg, allocator, depth + 1);
                    new_list.append(allocator, exp_arg) catch return SimplifyError.OutOfMemory;
                }

                const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
                result.* = .{ .list = new_list };
                return result;
            }

            return try copyExpr(expr, allocator);
        },
    }
}

/// Substitutes a variable with an expression in the given expression.
/// Returns a NEW expression that the caller owns.
pub fn substitute(expr: *const Expr, var_name: []const u8, value: *const Expr, allocator: std.mem.Allocator) SimplifyError!*Expr {
    switch (expr.*) {
        .number => return try copyExpr(expr, allocator),
        .lambda => return try copyExpr(expr, allocator), // Don't substitute inside lambdas (lexical scope)
        .symbol, .owned_symbol => |s| {
            if (std.mem.eql(u8, s, var_name)) {
                return try copyExpr(value, allocator);
            }
            return try copyExpr(expr, allocator);
        },
        .list => |lst| {
            if (lst.items.len == 0) return try copyExpr(expr, allocator);

            var new_list: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (new_list.items) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                new_list.deinit(allocator);
            }

            for (lst.items) |item| {
                const sub_item = try substitute(item, var_name, value, allocator);
                new_list.append(allocator, sub_item) catch return SimplifyError.OutOfMemory;
            }

            const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
            result.* = .{ .list = new_list };
            return result;
        },
    }
}

/// Evaluates an expression with all numeric arguments to a number if possible.
/// This handles cases like (exp 0) -> 1, (sin 0) -> 0, etc.
/// Returns a NEW expression that the caller owns.
fn evalNumeric(expr: *const Expr, allocator: std.mem.Allocator) SimplifyError!*Expr {
    switch (expr.*) {
        .number => return try copyExpr(expr, allocator),
        .symbol, .owned_symbol => return try copyExpr(expr, allocator),
        .lambda => return try copyExpr(expr, allocator),
        .list => |lst| {
            if (lst.items.len == 0) return try copyExpr(expr, allocator);
            const op = lst.items[0];
            if (op.* != .symbol) return try copyExpr(expr, allocator);

            // First recursively evaluate all arguments
            var eval_args: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (eval_args.items) |arg| {
                    arg.deinit(allocator);
                    allocator.destroy(arg);
                }
                eval_args.deinit(allocator);
            }

            for (lst.items[1..]) |arg| {
                const eval_arg = try evalNumeric(arg, allocator);
                eval_args.append(allocator, eval_arg) catch return SimplifyError.OutOfMemory;
            }

            // Check if all args are numbers
            var all_numbers = true;
            for (eval_args.items) |arg| {
                if (arg.* != .number) {
                    all_numbers = false;
                    break;
                }
            }

            if (all_numbers and eval_args.items.len > 0) {
                const arg0 = eval_args.items[0].number;
                var result_val: ?f64 = null;

                if (std.mem.eql(u8, op.symbol, "exp")) {
                    result_val = @exp(arg0);
                } else if (std.mem.eql(u8, op.symbol, "ln")) {
                    if (arg0 > 0) result_val = @log(arg0);
                } else if (std.mem.eql(u8, op.symbol, "log")) {
                    if (eval_args.items.len == 1 and arg0 > 0) {
                        result_val = @log10(arg0);
                    } else if (eval_args.items.len == 2 and arg0 > 0 and arg0 != 1) {
                        const arg1 = eval_args.items[1].number;
                        if (arg1 > 0) result_val = @log(arg1) / @log(arg0);
                    }
                } else if (std.mem.eql(u8, op.symbol, "sin")) {
                    result_val = @sin(arg0);
                } else if (std.mem.eql(u8, op.symbol, "cos")) {
                    result_val = @cos(arg0);
                } else if (std.mem.eql(u8, op.symbol, "tan")) {
                    result_val = @tan(arg0);
                } else if (std.mem.eql(u8, op.symbol, "+")) {
                    var sum: f64 = 0;
                    for (eval_args.items) |arg| sum += arg.number;
                    result_val = sum;
                } else if (std.mem.eql(u8, op.symbol, "-")) {
                    if (eval_args.items.len >= 1) {
                        var res = arg0;
                        for (eval_args.items[1..]) |arg| res -= arg.number;
                        result_val = res;
                    }
                } else if (std.mem.eql(u8, op.symbol, "*")) {
                    var prod: f64 = 1;
                    for (eval_args.items) |arg| prod *= arg.number;
                    result_val = prod;
                } else if (std.mem.eql(u8, op.symbol, "/")) {
                    if (eval_args.items.len == 2 and eval_args.items[1].number != 0) {
                        result_val = arg0 / eval_args.items[1].number;
                    }
                } else if (std.mem.eql(u8, op.symbol, "^")) {
                    if (eval_args.items.len == 2) {
                        result_val = std.math.pow(f64, arg0, eval_args.items[1].number);
                    }
                }

                if (result_val) |val| {
                    for (eval_args.items) |arg| {
                        arg.deinit(allocator);
                        allocator.destroy(arg);
                    }
                    eval_args.deinit(allocator);
                    return try makeNumber(allocator, val);
                }
            }

            // Not all numbers, rebuild the expression with evaluated args
            var new_list: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (new_list.items) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                new_list.deinit(allocator);
            }
            const new_op = try makeSymbol(allocator, op.symbol);
            new_list.append(allocator, new_op) catch return SimplifyError.OutOfMemory;
            for (eval_args.items) |arg| {
                new_list.append(allocator, arg) catch return SimplifyError.OutOfMemory;
            }
            // Transfer ownership to new_list
            eval_args.clearRetainingCapacity();
            eval_args.deinit(allocator);

            const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
            result.* = .{ .list = new_list };
            return result;
        },
    }
}

/// Computes the Taylor series expansion of an expression around a point.
/// taylor(expr, var_name, point, order) gives the first 'order' terms of the Taylor series.
/// Returns a NEW expression that the caller owns.
pub fn taylor(expr: *const Expr, var_name: []const u8, point: f64, order: usize, allocator: std.mem.Allocator) SimplifyError!*Expr {
    if (order == 0) {
        return try makeNumber(allocator, 0);
    }

    // Build (x - point) term for later use
    const point_expr = try makeNumber(allocator, point);
    defer {
        point_expr.deinit(allocator);
        allocator.destroy(point_expr);
    }

    // Start building the sum of Taylor terms
    var terms: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (terms.items) |t| {
            t.deinit(allocator);
            allocator.destroy(t);
        }
        terms.deinit(allocator);
    }

    const sum_op = try makeSymbol(allocator, "+");
    terms.append(allocator, sum_op) catch return SimplifyError.OutOfMemory;

    // Current derivative (starts as the original expression)
    var current_deriv = try copyExpr(expr, allocator);
    defer {
        current_deriv.deinit(allocator);
        allocator.destroy(current_deriv);
    }

    var factorial: f64 = 1;

    for (0..order) |n| {
        // Evaluate current derivative at the point
        const deriv_at_point = try substitute(current_deriv, var_name, point_expr, allocator);
        defer {
            deriv_at_point.deinit(allocator);
            allocator.destroy(deriv_at_point);
        }

        // Evaluate numerically to convert (exp 0) -> 1, etc.
        const numeric_deriv = try evalNumeric(deriv_at_point, allocator);
        defer {
            numeric_deriv.deinit(allocator);
            allocator.destroy(numeric_deriv);
        }

        // Simplify to get the final value
        const simplified_deriv = try simplify(numeric_deriv, allocator);
        defer {
            simplified_deriv.deinit(allocator);
            allocator.destroy(simplified_deriv);
        }

        // Update factorial (n! for this term)
        if (n > 0) {
            factorial *= @as(f64, @floatFromInt(n));
        }

        // Build the term: (f^(n)(a) / n!) * (x - a)^n
        if (n == 0) {
            // First term is just the function value at the point
            const term = try copyExpr(simplified_deriv, allocator);
            terms.append(allocator, term) catch return SimplifyError.OutOfMemory;
        } else {
            // Coefficient: f^(n)(a) / n!
            var coeff: *Expr = undefined;
            if (simplified_deriv.* == .number) {
                const coeff_val = simplified_deriv.number / factorial;
                // Skip terms with zero coefficient
                if (coeff_val == 0) {
                    // Differentiate for the next iteration (unless we're done)
                    if (n < order - 1) {
                        const next_deriv = try diff(current_deriv, var_name, allocator);
                        current_deriv.deinit(allocator);
                        allocator.destroy(current_deriv);
                        current_deriv = next_deriv;
                    }
                    continue;
                }
                coeff = try makeNumber(allocator, coeff_val);
            } else {
                const fact_expr = try makeNumber(allocator, factorial);
                coeff = try makeBinOp(allocator, "/", try copyExpr(simplified_deriv, allocator), fact_expr);
            }

            // (x - a) term - simplify if a == 0
            var power_term: *Expr = undefined;
            if (point == 0) {
                // Just use x directly
                if (n == 1) {
                    power_term = try makeSymbol(allocator, var_name);
                } else {
                    const x_var = try makeSymbol(allocator, var_name);
                    const n_expr = try makeNumber(allocator, @floatFromInt(n));
                    power_term = try makeBinOp(allocator, "^", x_var, n_expr);
                }
            } else {
                const x_var = try makeSymbol(allocator, var_name);
                const a_val = try makeNumber(allocator, point);
                const x_minus_a = try makeBinOp(allocator, "-", x_var, a_val);

                if (n == 1) {
                    power_term = x_minus_a;
                } else {
                    const n_expr = try makeNumber(allocator, @floatFromInt(n));
                    power_term = try makeBinOp(allocator, "^", x_minus_a, n_expr);
                }
            }

            // coeff * (x - a)^n - simplify if coeff == 1
            var term: *Expr = undefined;
            if (coeff.* == .number and coeff.number == 1) {
                coeff.deinit(allocator);
                allocator.destroy(coeff);
                term = power_term;
            } else {
                term = try makeBinOp(allocator, "*", coeff, power_term);
            }
            terms.append(allocator, term) catch return SimplifyError.OutOfMemory;
        }

        // Differentiate for the next iteration (unless we're done)
        if (n < order - 1) {
            const next_deriv = try diff(current_deriv, var_name, allocator);
            current_deriv.deinit(allocator);
            allocator.destroy(current_deriv);
            current_deriv = next_deriv;
        }
    }

    // Build the result expression
    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    result.* = .{ .list = terms };

    // Simplify the final result
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }
    return try simplify(result, allocator);
}

/// Collects polynomial coefficients from an expanded expression.
/// Returns coefficients as [constant, linear, quadratic, ...] or null if not polynomial.
fn collectPolyCoeffs(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!?[]f64 {
    // We'll collect up to degree 4 polynomials
    var coeffs: [5]f64 = .{ 0, 0, 0, 0, 0 };
    var max_degree: usize = 0;

    if (!try collectPolyCoeffsInner(expr, var_name, &coeffs, &max_degree)) {
        return null;
    }

    // Allocate and return the coefficients
    const result = allocator.alloc(f64, max_degree + 1) catch return SimplifyError.OutOfMemory;
    for (0..max_degree + 1) |i| {
        result[i] = coeffs[i];
    }
    return result;
}

fn collectPolyCoeffsInner(expr: *const Expr, var_name: []const u8, coeffs: *[5]f64, max_degree: *usize) SimplifyError!bool {
    switch (expr.*) {
        .number => |n| {
            coeffs[0] += n;
            return true;
        },
        .lambda => {
            // Lambda is not a polynomial
            return false;
        },
        .symbol, .owned_symbol => |s| {
            if (std.mem.eql(u8, s, var_name)) {
                coeffs[1] += 1;
                if (max_degree.* < 1) max_degree.* = 1;
            } else {
                // Other variable - not a polynomial in var_name
                return false;
            }
            return true;
        },
        .list => |lst| {
            if (lst.items.len == 0) return true;
            const op = lst.items[0];
            if (op.* != .symbol) return false;

            if (std.mem.eql(u8, op.symbol, "+")) {
                for (lst.items[1..]) |arg| {
                    if (!try collectPolyCoeffsInner(arg, var_name, coeffs, max_degree)) {
                        return false;
                    }
                }
                return true;
            } else if (std.mem.eql(u8, op.symbol, "-")) {
                if (lst.items.len < 2) return false;
                // First term is positive
                if (!try collectPolyCoeffsInner(lst.items[1], var_name, coeffs, max_degree)) {
                    return false;
                }
                // Remaining terms are negated
                for (lst.items[2..]) |arg| {
                    // Negate the coefficients temporarily
                    var neg_coeffs: [5]f64 = .{ 0, 0, 0, 0, 0 };
                    var neg_max: usize = 0;
                    if (!try collectPolyCoeffsInner(arg, var_name, &neg_coeffs, &neg_max)) {
                        return false;
                    }
                    for (0..5) |i| {
                        coeffs[i] -= neg_coeffs[i];
                    }
                    if (neg_max > max_degree.*) max_degree.* = neg_max;
                }
                return true;
            } else if (std.mem.eql(u8, op.symbol, "*")) {
                if (lst.items.len < 3) return false;

                // Count how many times the variable appears as a factor
                var var_count: usize = 0;
                var num_coeff: f64 = 1;
                var has_other: bool = false;

                for (lst.items[1..]) |arg| {
                    if (arg.* == .number) {
                        num_coeff *= arg.number;
                    } else if (arg.* == .symbol) {
                        if (std.mem.eql(u8, arg.symbol, var_name)) {
                            var_count += 1;
                        } else {
                            has_other = true;
                            break;
                        }
                    } else if (arg.* == .list) {
                        // Check for x^n
                        const inner = arg.list;
                        if (inner.items.len == 3 and inner.items[0].* == .symbol and
                            std.mem.eql(u8, inner.items[0].symbol, "^"))
                        {
                            if (inner.items[1].* == .symbol and
                                std.mem.eql(u8, inner.items[1].symbol, var_name) and
                                inner.items[2].* == .number)
                            {
                                const exp = inner.items[2].number;
                                if (exp >= 0 and exp == @floor(exp) and exp < 5) {
                                    var_count += @intFromFloat(exp);
                                } else {
                                    has_other = true;
                                    break;
                                }
                            } else {
                                has_other = true;
                                break;
                            }
                        } else {
                            has_other = true;
                            break;
                        }
                    } else {
                        has_other = true;
                        break;
                    }
                }

                if (!has_other and var_count < 5) {
                    coeffs[var_count] += num_coeff;
                    if (max_degree.* < var_count) max_degree.* = var_count;
                    return true;
                }
                return false;
            } else if (std.mem.eql(u8, op.symbol, "^")) {
                if (lst.items.len != 3) return false;
                const base = lst.items[1];
                const exp = lst.items[2];

                // x^n case
                if (base.* == .symbol and std.mem.eql(u8, base.symbol, var_name) and exp.* == .number) {
                    const n = exp.number;
                    if (n >= 0 and n == @floor(n) and n < 5) {
                        const idx: usize = @intFromFloat(n);
                        coeffs[idx] += 1;
                        if (max_degree.* < idx) max_degree.* = idx;
                        return true;
                    }
                }
                return false;
            }
            return false;
        },
    }
}

/// Solves an equation expr = 0 for the given variable.
/// Returns a list of solutions, or an empty list if unsolvable.
/// Returns a NEW expression that the caller owns.
pub fn solve(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr {
    // First expand and simplify the expression
    const expanded = try expand(expr, allocator);
    defer {
        expanded.deinit(allocator);
        allocator.destroy(expanded);
    }

    // Try to collect polynomial coefficients
    const coeffs_opt = try collectPolyCoeffs(expanded, var_name, allocator);
    if (coeffs_opt) |coeffs| {
        defer allocator.free(coeffs);

        // Solve based on degree
        if (coeffs.len == 1) {
            // Constant - either always 0 or never 0
            if (coeffs[0] == 0) {
                // Infinite solutions - return "all"
                return try makeSymbol(allocator, "all");
            } else {
                // No solutions - return empty list
                const empty_list: std.ArrayList(*Expr) = .empty;
                const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
                result.* = .{ .list = empty_list };
                return result;
            }
        } else if (coeffs.len == 2) {
            // Linear: a*x + b = 0 => x = -b/a
            const a = coeffs[1];
            const b = coeffs[0];
            if (a == 0) {
                if (b == 0) {
                    return try makeSymbol(allocator, "all");
                } else {
                    const empty_list: std.ArrayList(*Expr) = .empty;
                    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
                    result.* = .{ .list = empty_list };
                    return result;
                }
            }
            // x = -b/a
            const solution = -b / a;
            return try makeNumber(allocator, solution);
        } else if (coeffs.len == 3) {
            // Quadratic: a*x^2 + b*x + c = 0
            const a = coeffs[2];
            const b = coeffs[1];
            const c = coeffs[0];

            if (a == 0) {
                // Actually linear
                if (b == 0) {
                    if (c == 0) {
                        return try makeSymbol(allocator, "all");
                    } else {
                        const empty_list: std.ArrayList(*Expr) = .empty;
                        const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
                        result.* = .{ .list = empty_list };
                        return result;
                    }
                }
                return try makeNumber(allocator, -c / b);
            }

            // Discriminant
            const disc = b * b - 4 * a * c;

            if (disc < 0) {
                // Complex solutions: (-b +/- i*sqrt(-disc)) / (2a)
                const sqrt_neg_disc = @sqrt(-disc);
                const real_part = -b / (2 * a);
                const imag_part = sqrt_neg_disc / (2 * a);

                var solutions: std.ArrayList(*Expr) = .empty;
                errdefer {
                    for (solutions.items) |s| {
                        s.deinit(allocator);
                        allocator.destroy(s);
                    }
                    solutions.deinit(allocator);
                }

                const list_op = try makeSymbol(allocator, "solutions");
                solutions.append(allocator, list_op) catch return SimplifyError.OutOfMemory;
                solutions.append(allocator, try makeComplex(allocator, real_part, imag_part)) catch return SimplifyError.OutOfMemory;
                solutions.append(allocator, try makeComplex(allocator, real_part, -imag_part)) catch return SimplifyError.OutOfMemory;

                const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
                result.* = .{ .list = solutions };
                return result;
            } else if (disc == 0) {
                // One solution
                const solution = -b / (2 * a);
                return try makeNumber(allocator, solution);
            } else {
                // Two solutions
                const sqrt_disc = @sqrt(disc);
                const sol1 = (-b + sqrt_disc) / (2 * a);
                const sol2 = (-b - sqrt_disc) / (2 * a);

                var solutions: std.ArrayList(*Expr) = .empty;
                errdefer {
                    for (solutions.items) |s| {
                        s.deinit(allocator);
                        allocator.destroy(s);
                    }
                    solutions.deinit(allocator);
                }

                const list_op = try makeSymbol(allocator, "solutions");
                solutions.append(allocator, list_op) catch return SimplifyError.OutOfMemory;
                solutions.append(allocator, try makeNumber(allocator, sol1)) catch return SimplifyError.OutOfMemory;
                solutions.append(allocator, try makeNumber(allocator, sol2)) catch return SimplifyError.OutOfMemory;

                const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
                result.* = .{ .list = solutions };
                return result;
            }
        }
    }

    // Cannot solve - return the original expression with a "solve" wrapper
    var solve_list: std.ArrayList(*Expr) = .empty;
    const solve_op = try makeSymbol(allocator, "solve");
    solve_list.append(allocator, solve_op) catch return SimplifyError.OutOfMemory;
    const expr_copy = try copyExpr(expr, allocator);
    solve_list.append(allocator, expr_copy) catch return SimplifyError.OutOfMemory;
    const var_sym = try makeSymbol(allocator, var_name);
    solve_list.append(allocator, var_sym) catch return SimplifyError.OutOfMemory;
    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    result.* = .{ .list = solve_list };
    return result;
}

/// Factors a polynomial expression with respect to a variable.
/// Returns a NEW expression that the caller owns.
/// Handles: GCF, difference of squares, perfect square trinomials, quadratics.
pub fn factor(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr {
    // First expand and simplify the expression
    const expanded = try expand(expr, allocator);
    defer {
        expanded.deinit(allocator);
        allocator.destroy(expanded);
    }

    // Try to collect polynomial coefficients
    const coeffs_opt = try collectPolyCoeffs(expanded, var_name, allocator);
    if (coeffs_opt) |coeffs| {
        defer allocator.free(coeffs);

        // Factor based on degree
        if (coeffs.len == 1) {
            // Constant - just return it
            return try makeNumber(allocator, coeffs[0]);
        } else if (coeffs.len == 2) {
            // Linear: a*x + b
            // Factor out GCF if both coefficients share one
            const a = coeffs[1];
            const b = coeffs[0];

            if (a == 0) {
                return try makeNumber(allocator, b);
            }

            // Check for GCF (for simple integer cases)
            const gcd = gcdF64(a, b);
            if (@abs(gcd) > 1) {
                // Factor out GCF: gcd * (a/gcd * x + b/gcd)
                const inner_a = a / gcd;
                const inner_b = b / gcd;

                const x = try makeSymbol(allocator, var_name);
                const ax = if (inner_a == 1) x else blk: {
                    const coeff = try makeNumber(allocator, inner_a);
                    break :blk try makeBinOp(allocator, "*", coeff, x);
                };

                const inner_expr = if (inner_b == 0) ax else blk: {
                    const const_term = try makeNumber(allocator, inner_b);
                    break :blk try makeBinOp(allocator, "+", ax, const_term);
                };

                const gcd_expr = try makeNumber(allocator, gcd);
                return try makeBinOp(allocator, "*", gcd_expr, inner_expr);
            }

            // No factoring possible for linear - return simplified form
            const x = try makeSymbol(allocator, var_name);
            const ax = if (a == 1) x else blk: {
                const coeff = try makeNumber(allocator, a);
                break :blk try makeBinOp(allocator, "*", coeff, x);
            };
            if (b == 0) return ax;
            const const_term = try makeNumber(allocator, b);
            return try makeBinOp(allocator, "+", ax, const_term);
        } else if (coeffs.len == 3) {
            // Quadratic: a*x^2 + b*x + c
            const a = coeffs[2];
            const b = coeffs[1];
            const c = coeffs[0];

            if (a == 0) {
                // Actually linear, recurse with degree 1
                const linear_coeffs = allocator.alloc(f64, 2) catch return SimplifyError.OutOfMemory;
                defer allocator.free(linear_coeffs);
                linear_coeffs[0] = c;
                linear_coeffs[1] = b;
                return try factorFromCoeffs(linear_coeffs, var_name, allocator);
            }

            // Check for difference of squares: x^2 - a^2 = (x-a)(x+a)
            if (b == 0 and c < 0 and a > 0) {
                const sqrt_a = @sqrt(a);
                const sqrt_c = @sqrt(-c);
                // Check if both are perfect squares
                if (sqrt_a == @floor(sqrt_a) and sqrt_c == @floor(sqrt_c)) {
                    // (sqrt_a * x - sqrt_c)(sqrt_a * x + sqrt_c)
                    const x = try makeSymbol(allocator, var_name);

                    const ax1 = if (sqrt_a == 1) x else blk: {
                        const sa = try makeNumber(allocator, sqrt_a);
                        const x1 = try makeSymbol(allocator, var_name);
                        break :blk try makeBinOp(allocator, "*", sa, x1);
                    };
                    const sc1 = try makeNumber(allocator, sqrt_c);
                    const factor1 = try makeBinOp(allocator, "-", ax1, sc1);

                    const ax2 = if (sqrt_a == 1) blk: {
                        break :blk try makeSymbol(allocator, var_name);
                    } else blk: {
                        const sa2 = try makeNumber(allocator, sqrt_a);
                        const x2 = try makeSymbol(allocator, var_name);
                        break :blk try makeBinOp(allocator, "*", sa2, x2);
                    };
                    const sc2 = try makeNumber(allocator, sqrt_c);
                    const factor2 = try makeBinOp(allocator, "+", ax2, sc2);

                    return try makeBinOp(allocator, "*", factor1, factor2);
                }
            }

            // Check for perfect square trinomial: (rx + s)^2 = r^2*x^2 + 2rs*x + s^2
            // If a = r^2, c = s^2, b = 2rs, then we have (rx + s)^2
            if (a > 0 and c >= 0) {
                const r = @sqrt(a);
                const s = @sqrt(c);
                if (r == @floor(r) and s == @floor(s)) {
                    const expected_b = 2 * r * s;
                    if (b == expected_b or b == -expected_b) {
                        // Perfect square! (rx + s)^2 or (rx - s)^2
                        const x = try makeSymbol(allocator, var_name);
                        const rx = if (r == 1) x else blk: {
                            const r_expr = try makeNumber(allocator, r);
                            break :blk try makeBinOp(allocator, "*", r_expr, x);
                        };
                        const s_expr = try makeNumber(allocator, s);
                        const inner = if (b > 0)
                            try makeBinOp(allocator, "+", rx, s_expr)
                        else
                            try makeBinOp(allocator, "-", rx, s_expr);

                        const two = try makeNumber(allocator, 2);
                        return try makeBinOp(allocator, "^", inner, two);
                    }
                }
            }

            // General quadratic factoring using roots
            const disc = b * b - 4 * a * c;
            if (disc >= 0) {
                const sqrt_disc = @sqrt(disc);
                const r1 = (-b + sqrt_disc) / (2 * a);
                const r2 = (-b - sqrt_disc) / (2 * a);

                // Check if roots are "nice" integers or simple fractions
                if (isNiceNumber(r1) and isNiceNumber(r2)) {
                    // a(x - r1)(x - r2)
                    const x1 = try makeSymbol(allocator, var_name);
                    const r1_expr = try makeNumber(allocator, r1);
                    const factor1 = try makeBinOp(allocator, "-", x1, r1_expr);

                    const x2 = try makeSymbol(allocator, var_name);
                    const r2_expr = try makeNumber(allocator, r2);
                    const factor2 = try makeBinOp(allocator, "-", x2, r2_expr);

                    const prod = try makeBinOp(allocator, "*", factor1, factor2);

                    if (a == 1) return prod;
                    const a_expr = try makeNumber(allocator, a);
                    return try makeBinOp(allocator, "*", a_expr, prod);
                }
            }

            // Cannot factor nicely, return expanded form
            return try copyExpr(expanded, allocator);
        } else if (coeffs.len == 4) {
            // Cubic - try to find rational root and factor
            // For now, just return the expanded form
            return try copyExpr(expanded, allocator);
        }
    }

    // Not a polynomial - return copy of original
    return try copyExpr(expr, allocator);
}

/// Helper to factor from already-collected coefficients
fn factorFromCoeffs(coeffs: []const f64, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr {
    if (coeffs.len == 2) {
        const a = coeffs[1];
        const b = coeffs[0];

        if (a == 0) {
            return try makeNumber(allocator, b);
        }

        const x = try makeSymbol(allocator, var_name);
        const ax = if (a == 1) x else blk: {
            const coeff = try makeNumber(allocator, a);
            break :blk try makeBinOp(allocator, "*", coeff, x);
        };
        if (b == 0) return ax;
        const const_term = try makeNumber(allocator, b);
        return try makeBinOp(allocator, "+", ax, const_term);
    }
    // Fallback
    const x = try makeSymbol(allocator, var_name);
    return x;
}

/// GCD for floating point numbers (for simple integer coefficients)
fn gcdF64(a: f64, b: f64) f64 {
    const a_abs = @abs(a);
    const b_abs = @abs(b);

    // Only works well for integer values
    if (a_abs != @floor(a_abs) or b_abs != @floor(b_abs)) return 1;

    var x = a_abs;
    var y = b_abs;

    while (y > 0.5) {
        const temp = y;
        y = @mod(x, y);
        x = temp;
    }
    return x;
}

/// Check if a number is "nice" (integer or simple fraction like 0.5)
fn isNiceNumber(n: f64) bool {
    // Check if it's an integer
    if (n == @floor(n)) return true;
    // Check common fractions
    if (n * 2 == @floor(n * 2)) return true; // halves
    if (n * 3 == @floor(n * 3)) return true; // thirds
    if (n * 4 == @floor(n * 4)) return true; // quarters
    return false;
}

/// Collects like terms with respect to a variable.
/// E.g., (+ (* a x) (* b x) y) -> (+ (* (+ a b) x) y)
/// Returns a NEW expression that the caller owns.
pub fn collect(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr {
    // First expand the expression
    const expanded = try expand(expr, allocator);
    defer {
        expanded.deinit(allocator);
        allocator.destroy(expanded);
    }

    // Only works on sums
    if (expanded.* != .list) return try copyExpr(expanded, allocator);
    const lst = expanded.list;
    if (lst.items.len == 0) return try copyExpr(expanded, allocator);
    if (lst.items[0].* != .symbol) return try copyExpr(expanded, allocator);
    if (!std.mem.eql(u8, lst.items[0].symbol, "+")) return try copyExpr(expanded, allocator);

    // Collect coefficients for each power of the variable
    // For now, handle x^0, x^1 (constants and linear terms)
    var const_terms: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (const_terms.items) |t| {
            t.deinit(allocator);
            allocator.destroy(t);
        }
        const_terms.deinit(allocator);
    }

    var linear_coeffs: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (linear_coeffs.items) |c| {
            c.deinit(allocator);
            allocator.destroy(c);
        }
        linear_coeffs.deinit(allocator);
    }

    var other_terms: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (other_terms.items) |t| {
            t.deinit(allocator);
            allocator.destroy(t);
        }
        other_terms.deinit(allocator);
    }

    // Analyze each term
    for (lst.items[1..]) |term| {
        const analysis = try analyzeTermForVar(term, var_name, allocator);

        if (analysis.power == 0) {
            // Constant term (doesn't contain var)
            const copy = try copyExpr(term, allocator);
            const_terms.append(allocator, copy) catch return SimplifyError.OutOfMemory;
        } else if (analysis.power == 1) {
            // Linear term: coeff * x
            if (analysis.coeff) |coeff| {
                linear_coeffs.append(allocator, coeff) catch return SimplifyError.OutOfMemory;
            } else {
                // Just x by itself
                const one = try makeNumber(allocator, 1);
                linear_coeffs.append(allocator, one) catch return SimplifyError.OutOfMemory;
            }
        } else {
            // Higher power or complex term - keep as-is
            const copy = try copyExpr(term, allocator);
            other_terms.append(allocator, copy) catch return SimplifyError.OutOfMemory;
        }
    }

    // Build result
    var result_terms: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (result_terms.items) |t| {
            t.deinit(allocator);
            allocator.destroy(t);
        }
        result_terms.deinit(allocator);
    }

    const plus_op = try makeSymbol(allocator, "+");
    result_terms.append(allocator, plus_op) catch return SimplifyError.OutOfMemory;

    // Add collected linear term if any
    if (linear_coeffs.items.len > 0) {
        const combined_coeff = try combineTerms(&linear_coeffs, allocator);
        const x_sym = try makeSymbol(allocator, var_name);
        const linear_term = try makeBinOp(allocator, "*", combined_coeff, x_sym);
        result_terms.append(allocator, linear_term) catch return SimplifyError.OutOfMemory;
    }

    // Add constant terms
    for (const_terms.items) |ct| {
        result_terms.append(allocator, ct) catch return SimplifyError.OutOfMemory;
    }
    const_terms.clearRetainingCapacity();
    const_terms.deinit(allocator);

    // Add other terms
    for (other_terms.items) |ot| {
        result_terms.append(allocator, ot) catch return SimplifyError.OutOfMemory;
    }
    other_terms.clearRetainingCapacity();
    other_terms.deinit(allocator);

    // Clear linear_coeffs (ownership transferred)
    linear_coeffs.clearRetainingCapacity();
    linear_coeffs.deinit(allocator);

    // If only one term after +, return just that term
    if (result_terms.items.len == 2) {
        const result = result_terms.items[1];
        result_terms.items[0].deinit(allocator);
        allocator.destroy(result_terms.items[0]);
        result_terms.deinit(allocator);
        return result;
    }

    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    result.* = .{ .list = result_terms };
    return result;
}

const TermAnalysis = struct {
    power: i32, // -1 for complex terms we can't handle
    coeff: ?*Expr, // coefficient (owned by caller if not null)
};

/// Analyzes a term to extract coefficient and power of variable
fn analyzeTermForVar(term: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!TermAnalysis {
    // Simple variable: x -> power 1, coeff null
    if (term.* == .symbol) {
        if (std.mem.eql(u8, term.symbol, var_name)) {
            return .{ .power = 1, .coeff = null };
        } else {
            return .{ .power = 0, .coeff = null };
        }
    }

    // Number: constant
    if (term.* == .number) {
        return .{ .power = 0, .coeff = null };
    }

    // List expression
    if (term.* == .list) {
        const lst = term.list;
        if (lst.items.len == 0) return .{ .power = 0, .coeff = null };
        if (lst.items[0].* != .symbol) return .{ .power = -1, .coeff = null };

        const op = lst.items[0].symbol;

        // (* coeff x) or (* x coeff)
        if (std.mem.eql(u8, op, "*") and lst.items.len == 3) {
            const arg1 = lst.items[1];
            const arg2 = lst.items[2];

            // Check if arg2 is the variable
            if (arg2.* == .symbol and std.mem.eql(u8, arg2.symbol, var_name)) {
                // arg1 is the coefficient
                const coeff = try copyExpr(arg1, allocator);
                return .{ .power = 1, .coeff = coeff };
            }

            // Check if arg1 is the variable
            if (arg1.* == .symbol and std.mem.eql(u8, arg1.symbol, var_name)) {
                // arg2 is the coefficient
                const coeff = try copyExpr(arg2, allocator);
                return .{ .power = 1, .coeff = coeff };
            }

            // Neither is directly the variable - check for x^n pattern
            // ... for now, treat as "other"
        }

        // Check if expression contains the variable at all
        if (!containsVar(term, var_name)) {
            return .{ .power = 0, .coeff = null };
        }
    }

    return .{ .power = -1, .coeff = null };
}

/// Checks if an expression contains the variable
fn containsVar(expr: *const Expr, var_name: []const u8) bool {
    switch (expr.*) {
        .number => return false,
        .symbol, .owned_symbol => |s| return std.mem.eql(u8, s, var_name),
        .lambda => return false,
        .list => |lst| {
            for (lst.items) |item| {
                if (containsVar(item, var_name)) return true;
            }
            return false;
        },
    }
}

/// Combines a list of terms into a single expression
fn combineTerms(terms: *std.ArrayList(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr {
    if (terms.items.len == 0) {
        return try makeNumber(allocator, 0);
    }
    if (terms.items.len == 1) {
        const result = terms.items[0];
        return result;
    }

    // Build (+ term1 term2 ...)
    var list: std.ArrayList(*Expr) = .empty;
    const plus = try makeSymbol(allocator, "+");
    list.append(allocator, plus) catch return SimplifyError.OutOfMemory;
    for (terms.items) |t| {
        list.append(allocator, t) catch return SimplifyError.OutOfMemory;
    }

    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    result.* = .{ .list = list };

    // Simplify the result
    const simplified = try simplify(result, allocator);
    result.deinit(allocator);
    allocator.destroy(result);

    return simplified;
}

/// Performs partial fraction decomposition on a rational function.
/// Returns a NEW expression that the caller owns.
/// Handles: P(x)/Q(x) where Q(x) factors into distinct linear factors.
pub fn partialFractions(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr {
    // Expression must be a division: P(x) / Q(x)
    if (expr.* != .list) return try copyExpr(expr, allocator);
    const lst = expr.list;
    if (lst.items.len != 3) return try copyExpr(expr, allocator);
    if (lst.items[0].* != .symbol) return try copyExpr(expr, allocator);
    if (!std.mem.eql(u8, lst.items[0].symbol, "/")) return try copyExpr(expr, allocator);

    const numer = lst.items[1];
    const denom = lst.items[2];

    // Expand and get coefficients for denominator
    const denom_expanded = try expand(denom, allocator);
    defer {
        denom_expanded.deinit(allocator);
        allocator.destroy(denom_expanded);
    }

    const denom_coeffs_opt = try collectPolyCoeffs(denom_expanded, var_name, allocator);
    if (denom_coeffs_opt == null) return try copyExpr(expr, allocator);
    const denom_coeffs = denom_coeffs_opt.?;
    defer allocator.free(denom_coeffs);

    // Check numerator - must be a polynomial of lower degree
    const numer_expanded = try expand(numer, allocator);
    defer {
        numer_expanded.deinit(allocator);
        allocator.destroy(numer_expanded);
    }

    const numer_coeffs_opt = try collectPolyCoeffs(numer_expanded, var_name, allocator);
    if (numer_coeffs_opt == null) return try copyExpr(expr, allocator);
    const numer_coeffs = numer_coeffs_opt.?;
    defer allocator.free(numer_coeffs);

    // Numerator degree must be less than denominator degree for proper fraction
    if (numer_coeffs.len >= denom_coeffs.len) {
        // Improper fraction - for now, return as-is
        return try copyExpr(expr, allocator);
    }

    // Handle quadratic denominator with distinct real roots
    if (denom_coeffs.len == 3) {
        const a = denom_coeffs[2];
        const b = denom_coeffs[1];
        const c = denom_coeffs[0];

        const disc = b * b - 4 * a * c;
        if (disc > 0) {
            // Two distinct real roots
            const sqrt_disc = @sqrt(disc);
            const r1 = (-b + sqrt_disc) / (2 * a);
            const r2 = (-b - sqrt_disc) / (2 * a);

            // For P(x) / (a(x-r1)(x-r2)), we have:
            // P(x) / (a(x-r1)(x-r2)) = A/(x-r1) + B/(x-r2)
            // where A = P(r1) / (a(r1-r2)) and B = P(r2) / (a(r2-r1))

            // Evaluate P(r1)
            var p_r1: f64 = 0;
            var power: f64 = 1;
            for (numer_coeffs) |coeff| {
                p_r1 += coeff * power;
                power *= r1;
            }

            // Evaluate P(r2)
            var p_r2: f64 = 0;
            power = 1;
            for (numer_coeffs) |coeff| {
                p_r2 += coeff * power;
                power *= r2;
            }

            // Compute A and B
            const coeff_a = p_r1 / (a * (r1 - r2));
            const coeff_b = p_r2 / (a * (r2 - r1));

            // Check if coefficients are nice numbers
            if (!isNiceNumber(coeff_a) or !isNiceNumber(coeff_b)) {
                return try copyExpr(expr, allocator);
            }

            // Build result: A/(x-r1) + B/(x-r2)
            // First term: A / (x - r1)
            const a_expr = try makeNumber(allocator, coeff_a);
            const x1 = try makeSymbol(allocator, var_name);
            const r1_expr = try makeNumber(allocator, r1);
            const factor1 = try makeBinOp(allocator, "-", x1, r1_expr);
            const term1 = try makeBinOp(allocator, "/", a_expr, factor1);

            // Second term: B / (x - r2)
            const b_expr = try makeNumber(allocator, coeff_b);
            const x2 = try makeSymbol(allocator, var_name);
            const r2_expr = try makeNumber(allocator, r2);
            const factor2 = try makeBinOp(allocator, "-", x2, r2_expr);
            const term2 = try makeBinOp(allocator, "/", b_expr, factor2);

            // Sum them
            return try makeBinOp(allocator, "+", term1, term2);
        } else if (disc == 0) {
            // Repeated root - P(x) / (a(x-r)^2) = A/(x-r) + B/(x-r)^2
            const r = -b / (2 * a);

            // For P(x) = p0 + p1*x (linear or constant)
            // P(x) / (a(x-r)^2)
            // Using partial fractions: A/(x-r) + B/(x-r)^2
            // where B = P(r)/a and A = P'(r)/a

            // P(r)
            var p_r: f64 = 0;
            var p_pow: f64 = 1;
            for (numer_coeffs) |coeff| {
                p_r += coeff * p_pow;
                p_pow *= r;
            }

            // P'(r) - derivative at r
            var p_prime_r: f64 = 0;
            for (numer_coeffs[1..], 1..) |coeff, i| {
                const fi: f64 = @floatFromInt(i);
                p_prime_r += fi * coeff * std.math.pow(f64, r, fi - 1);
            }

            const coeff_b_val = p_r / a;
            const coeff_a_val = p_prime_r / a;

            if (!isNiceNumber(coeff_a_val) or !isNiceNumber(coeff_b_val)) {
                return try copyExpr(expr, allocator);
            }

            // Build: A/(x-r) + B/(x-r)^2
            const x1 = try makeSymbol(allocator, var_name);
            const r_expr1 = try makeNumber(allocator, r);
            const factor_val = try makeBinOp(allocator, "-", x1, r_expr1);

            // Term 1: A / (x - r)
            const a_num = try makeNumber(allocator, coeff_a_val);
            const factor1_copy = try copyExpr(factor_val, allocator);
            const term1 = try makeBinOp(allocator, "/", a_num, factor1_copy);

            // Term 2: B / (x - r)^2
            const b_num = try makeNumber(allocator, coeff_b_val);
            const factor_sq = try makeBinOp(allocator, "^", factor_val, try makeNumber(allocator, 2));
            const term2 = try makeBinOp(allocator, "/", b_num, factor_sq);

            return try makeBinOp(allocator, "+", term1, term2);
        }
    }

    // Handle linear denominator (trivial case)
    if (denom_coeffs.len == 2) {
        // Already in simplest form
        return try copyExpr(expr, allocator);
    }

    // Cannot decompose - return as-is
    return try copyExpr(expr, allocator);
}

/// Computes the limit of an expression as a variable approaches a value.
/// Returns a NEW expression that the caller owns.
/// Handles direct substitution, L'Hôpital's rule, and special limits.
pub fn limit(expr: *const Expr, var_name: []const u8, point: f64, allocator: std.mem.Allocator) SimplifyError!*Expr {
    return limitInternal(expr, var_name, point, allocator, 0);
}

fn limitInternal(expr: *const Expr, var_name: []const u8, point: f64, allocator: std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    if (depth > 10) {
        // Too much recursion (e.g., repeated L'Hôpital's), return symbolic limit
        return makeLimitExpr(expr, var_name, point, allocator);
    }

    // Try direct substitution first
    const point_expr = try makeNumber(allocator, point);
    defer {
        point_expr.deinit(allocator);
        allocator.destroy(point_expr);
    }

    const substituted = try substitute(expr, var_name, point_expr, allocator);
    defer {
        substituted.deinit(allocator);
        allocator.destroy(substituted);
    }

    // Evaluate numerically
    const evaluated = try evalNumeric(substituted, allocator);
    defer {
        evaluated.deinit(allocator);
        allocator.destroy(evaluated);
    }

    // Simplify
    const simplified = try simplify(evaluated, allocator);

    // Check if we got a valid number (not NaN, not infinity)
    if (simplified.* == .number) {
        const n = simplified.number;
        if (!std.math.isNan(n) and !std.math.isInf(n)) {
            return simplified;
        }
    }

    // Direct substitution didn't work - free and try special cases
    simplified.deinit(allocator);
    allocator.destroy(simplified);

    // Check for special limit forms
    if (expr.* == .list) {
        const lst = expr.list;
        if (lst.items.len > 0 and lst.items[0].* == .symbol) {
            const op = lst.items[0].symbol;

            // Handle division (potential L'Hôpital's rule)
            if (std.mem.eql(u8, op, "/") and lst.items.len == 3) {
                return try limitDivision(lst.items[1], lst.items[2], var_name, point, allocator, depth);
            }

            // Check for sin(x)/x as x→0 special case
            if (std.mem.eql(u8, op, "*")) {
                // Might be a product involving sin(x)/x
            }
        }
    }

    // Try to evaluate symbolically without specific point
    // For now, return a limit expression
    return makeLimitExpr(expr, var_name, point, allocator);
}

fn makeLimitExpr(expr: *const Expr, var_name: []const u8, point: f64, allocator: std.mem.Allocator) SimplifyError!*Expr {
    var list: std.ArrayList(*Expr) = .empty;
    const op = try makeSymbol(allocator, "limit");
    list.append(allocator, op) catch return SimplifyError.OutOfMemory;
    const expr_copy = try copyExpr(expr, allocator);
    list.append(allocator, expr_copy) catch return SimplifyError.OutOfMemory;
    const var_sym = try makeSymbol(allocator, var_name);
    list.append(allocator, var_sym) catch return SimplifyError.OutOfMemory;
    const point_expr = try makeNumber(allocator, point);
    list.append(allocator, point_expr) catch return SimplifyError.OutOfMemory;
    const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}

fn limitDivision(numer: *const Expr, denom: *const Expr, var_name: []const u8, point: f64, allocator: std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    // Check for 0/0 form (indeterminate)
    const point_expr = try makeNumber(allocator, point);
    defer {
        point_expr.deinit(allocator);
        allocator.destroy(point_expr);
    }

    // Evaluate numerator at point
    const numer_at_point = try substitute(numer, var_name, point_expr, allocator);
    defer {
        numer_at_point.deinit(allocator);
        allocator.destroy(numer_at_point);
    }
    const numer_eval = try evalNumeric(numer_at_point, allocator);
    defer {
        numer_eval.deinit(allocator);
        allocator.destroy(numer_eval);
    }
    const numer_simp = try simplify(numer_eval, allocator);
    defer {
        numer_simp.deinit(allocator);
        allocator.destroy(numer_simp);
    }

    // Evaluate denominator at point
    const denom_at_point = try substitute(denom, var_name, point_expr, allocator);
    defer {
        denom_at_point.deinit(allocator);
        allocator.destroy(denom_at_point);
    }
    const denom_eval = try evalNumeric(denom_at_point, allocator);
    defer {
        denom_eval.deinit(allocator);
        allocator.destroy(denom_eval);
    }
    const denom_simp = try simplify(denom_eval, allocator);
    defer {
        denom_simp.deinit(allocator);
        allocator.destroy(denom_simp);
    }

    const numer_zero = (numer_simp.* == .number and numer_simp.number == 0);
    const denom_zero = (denom_simp.* == .number and denom_simp.number == 0);

    // Special case: sin(x)/x as x→0
    if (numer_zero and denom_zero and point == 0) {
        if (isSinOfVar(numer, var_name) and isVar(denom, var_name)) {
            return try makeNumber(allocator, 1);
        }
        // Also check for (1-cos(x))/x as x→0 = 0
        if (isOneMinusCosOfVar(numer, var_name) and isVar(denom, var_name)) {
            return try makeNumber(allocator, 0);
        }
        // tan(x)/x as x→0 = 1
        if (isTanOfVar(numer, var_name) and isVar(denom, var_name)) {
            return try makeNumber(allocator, 1);
        }
    }

    // 0/0 form - apply L'Hôpital's rule
    if (numer_zero and denom_zero) {
        const d_numer = try diff(numer, var_name, allocator);
        defer {
            d_numer.deinit(allocator);
            allocator.destroy(d_numer);
        }
        const d_denom = try diff(denom, var_name, allocator);
        defer {
            d_denom.deinit(allocator);
            allocator.destroy(d_denom);
        }

        // Build d_numer / d_denom and take its limit
        const new_quot = try makeBinOp(allocator, "/", try copyExpr(d_numer, allocator), try copyExpr(d_denom, allocator));
        defer {
            new_quot.deinit(allocator);
            allocator.destroy(new_quot);
        }

        return try limitInternal(new_quot, var_name, point, allocator, depth + 1);
    }

    // ∞/∞ form - also L'Hôpital's rule
    const numer_inf = (numer_simp.* == .number and std.math.isInf(numer_simp.number));
    const denom_inf = (denom_simp.* == .number and std.math.isInf(denom_simp.number));
    if (numer_inf and denom_inf) {
        const d_numer = try diff(numer, var_name, allocator);
        defer {
            d_numer.deinit(allocator);
            allocator.destroy(d_numer);
        }
        const d_denom = try diff(denom, var_name, allocator);
        defer {
            d_denom.deinit(allocator);
            allocator.destroy(d_denom);
        }

        const new_quot = try makeBinOp(allocator, "/", try copyExpr(d_numer, allocator), try copyExpr(d_denom, allocator));
        defer {
            new_quot.deinit(allocator);
            allocator.destroy(new_quot);
        }

        return try limitInternal(new_quot, var_name, point, allocator, depth + 1);
    }

    // Not an indeterminate form - return symbolic limit
    const quot = try makeBinOp(allocator, "/", try copyExpr(numer, allocator), try copyExpr(denom, allocator));
    defer {
        quot.deinit(allocator);
        allocator.destroy(quot);
    }
    return makeLimitExpr(quot, var_name, point, allocator);
}

fn isSinOfVar(expr: *const Expr, var_name: []const u8) bool {
    if (expr.* != .list) return false;
    const lst = expr.list;
    if (lst.items.len != 2) return false;
    if (lst.items[0].* != .symbol) return false;
    if (!std.mem.eql(u8, lst.items[0].symbol, "sin")) return false;
    return isVar(lst.items[1], var_name);
}

fn isTanOfVar(expr: *const Expr, var_name: []const u8) bool {
    if (expr.* != .list) return false;
    const lst = expr.list;
    if (lst.items.len != 2) return false;
    if (lst.items[0].* != .symbol) return false;
    if (!std.mem.eql(u8, lst.items[0].symbol, "tan")) return false;
    return isVar(lst.items[1], var_name);
}

fn isOneMinusCosOfVar(expr: *const Expr, var_name: []const u8) bool {
    if (expr.* != .list) return false;
    const lst = expr.list;
    if (lst.items.len != 3) return false;
    if (lst.items[0].* != .symbol) return false;
    if (!std.mem.eql(u8, lst.items[0].symbol, "-")) return false;
    if (lst.items[1].* != .number or lst.items[1].number != 1) return false;
    // Check if second arg is (cos var_name)
    if (lst.items[2].* != .list) return false;
    const inner = lst.items[2].list;
    if (inner.items.len != 2) return false;
    if (inner.items[0].* != .symbol) return false;
    if (!std.mem.eql(u8, inner.items[0].symbol, "cos")) return false;
    return isVar(inner.items[1], var_name);
}

fn isVar(expr: *const Expr, var_name: []const u8) bool {
    return expr.* == .symbol and std.mem.eql(u8, expr.symbol, var_name);
}

// ============================================================================
// Pattern Matching and Rewrite Rules
// ============================================================================

/// Checks if a symbol is a pattern variable (starts with '?')
pub fn isPatternVar(s: []const u8) bool {
    return s.len > 1 and s[0] == '?';
}

/// Pattern matching: tries to match expr against pattern, extracting bindings.
/// Returns bindings hashmap on success, null on failure.
pub fn matchPattern(pattern: *const Expr, expr: *const Expr, allocator: std.mem.Allocator) SimplifyError!?std.StringHashMap(*Expr) {
    var bindings = std.StringHashMap(*Expr).init(allocator);
    errdefer {
        var it = bindings.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(allocator);
            allocator.destroy(entry.value_ptr.*);
        }
        bindings.deinit();
    }

    if (try matchPatternInner(pattern, expr, &bindings, allocator)) {
        return bindings;
    } else {
        // Cleanup on failure
        var it = bindings.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(allocator);
            allocator.destroy(entry.value_ptr.*);
        }
        bindings.deinit();
        return null;
    }
}

fn matchPatternInner(pattern: *const Expr, expr: *const Expr, bindings: *std.StringHashMap(*Expr), allocator: std.mem.Allocator) SimplifyError!bool {
    switch (pattern.*) {
        .number => |n| {
            return expr.* == .number and expr.number == n;
        },
        .symbol, .owned_symbol => |s| {
            // Check if it's a pattern variable
            if (isPatternVar(s)) {
                // Check if already bound
                if (bindings.get(s)) |bound_expr| {
                    // Must match the already bound value
                    return exprEqual(bound_expr, expr);
                } else {
                    // Bind the pattern variable to this expression
                    const expr_copy = try copyExpr(expr, allocator);
                    bindings.put(s, expr_copy) catch return SimplifyError.OutOfMemory;
                    return true;
                }
            } else {
                // Regular symbol - must match exactly
                const expr_sym = switch (expr.*) {
                    .symbol => |es| es,
                    .owned_symbol => |es| es,
                    else => return false,
                };
                return std.mem.eql(u8, expr_sym, s);
            }
        },
        .lambda => {
            // Lambdas must match exactly (no pattern matching inside)
            return exprEqual(pattern, expr);
        },
        .list => |pat_lst| {
            if (expr.* != .list) return false;
            const expr_lst = expr.list;
            if (pat_lst.items.len != expr_lst.items.len) return false;

            // Match each element
            for (pat_lst.items, expr_lst.items) |pat_item, expr_item| {
                if (!try matchPatternInner(pat_item, expr_item, bindings, allocator)) {
                    return false;
                }
            }
            return true;
        },
    }
}

/// Applies bindings to a replacement expression.
/// Returns a new expression with pattern variables substituted.
pub fn applyBindings(replacement: *const Expr, bindings: *std.StringHashMap(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr {
    switch (replacement.*) {
        .number => return try copyExpr(replacement, allocator),
        .symbol, .owned_symbol => |s| {
            if (isPatternVar(s)) {
                if (bindings.get(s)) |bound_expr| {
                    return try copyExpr(bound_expr, allocator);
                } else {
                    // Unbound pattern variable - keep as-is (shouldn't happen in well-formed rules)
                    return try copyExpr(replacement, allocator);
                }
            } else {
                return try copyExpr(replacement, allocator);
            }
        },
        .lambda => return try copyExpr(replacement, allocator),
        .list => |lst| {
            var new_list: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (new_list.items) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                new_list.deinit(allocator);
            }

            for (lst.items) |item| {
                const new_item = try applyBindings(item, bindings, allocator);
                new_list.append(allocator, new_item) catch return SimplifyError.OutOfMemory;
            }

            const result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
            result.* = .{ .list = new_list };
            return result;
        },
    }
}

/// Tries to apply user-defined rewrite rules to an expression.
/// Returns a new expression if a rule matches, or null if no rule matches.
pub fn applyRules(expr: *const Expr, rules: []const @import("environment.zig").Rule, allocator: std.mem.Allocator) SimplifyError!?*Expr {
    for (rules) |rule| {
        if (try matchPattern(rule.pattern, expr, allocator)) |bindings| {
            defer {
                var it = bindings.iterator();
                while (it.next()) |entry| {
                    entry.value_ptr.*.deinit(allocator);
                    allocator.destroy(entry.value_ptr.*);
                }
                var b = bindings;
                b.deinit();
            }
            return try applyBindings(rule.replacement, @constCast(&bindings), allocator);
        }
    }
    return null;
}

/// Creates a complex number expression (complex real imag)
pub fn makeComplex(allocator: std.mem.Allocator, real: f64, imag: f64) SimplifyError!*Expr {
    // Normalize -0 to 0
    const norm_real = if (real == 0) 0 else real;
    const norm_imag = if (imag == 0) 0 else imag;

    if (norm_imag == 0) {
        // Pure real number
        return try makeNumber(allocator, norm_real);
    }

    const complex_op = try makeSymbol(allocator, "complex");
    const real_expr = try makeNumber(allocator, norm_real);
    const imag_expr = try makeNumber(allocator, norm_imag);
    return try makeList(allocator, &[_]*Expr{ complex_op, real_expr, imag_expr });
}

/// Checks if an expression is a complex number
pub fn isComplex(expr: *const Expr) bool {
    if (expr.* == .list) {
        const lst = expr.list;
        if (lst.items.len == 3 and lst.items[0].* == .symbol and
            std.mem.eql(u8, lst.items[0].symbol, "complex"))
        {
            return lst.items[1].* == .number and lst.items[2].* == .number;
        }
    }
    return false;
}

/// Gets the real part of a complex expression
pub fn getReal(expr: *const Expr) ?f64 {
    if (expr.* == .number) return expr.number;
    if (isComplex(expr)) {
        return expr.list.items[1].number;
    }
    return null;
}

/// Gets the imaginary part of a complex expression
pub fn getImag(expr: *const Expr) ?f64 {
    if (expr.* == .number) return 0;
    if (isComplex(expr)) {
        return expr.list.items[2].number;
    }
    return null;
}

/// Adds two complex numbers
pub fn complexAdd(a_real: f64, a_imag: f64, b_real: f64, b_imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr {
    return try makeComplex(allocator, a_real + b_real, a_imag + b_imag);
}

/// Subtracts two complex numbers
pub fn complexSub(a_real: f64, a_imag: f64, b_real: f64, b_imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr {
    return try makeComplex(allocator, a_real - b_real, a_imag - b_imag);
}

/// Multiplies two complex numbers
pub fn complexMul(a_real: f64, a_imag: f64, b_real: f64, b_imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr {
    // (a + bi)(c + di) = (ac - bd) + (ad + bc)i
    const real = a_real * b_real - a_imag * b_imag;
    const imag = a_real * b_imag + a_imag * b_real;
    return try makeComplex(allocator, real, imag);
}

/// Divides two complex numbers
pub fn complexDiv(a_real: f64, a_imag: f64, b_real: f64, b_imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr {
    // (a + bi) / (c + di) = ((ac + bd) + (bc - ad)i) / (c^2 + d^2)
    const denom = b_real * b_real + b_imag * b_imag;
    if (denom == 0) {
        // Division by zero - return symbolic
        return try makeComplex(allocator, std.math.inf(f64), std.math.inf(f64));
    }
    const real = (a_real * b_real + a_imag * b_imag) / denom;
    const imag = (a_imag * b_real - a_real * b_imag) / denom;
    return try makeComplex(allocator, real, imag);
}

/// Computes the complex square root
pub fn complexSqrt(real: f64, imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr {
    const r = @sqrt(real * real + imag * imag);
    const result_real = @sqrt((r + real) / 2);
    var result_imag = @sqrt((r - real) / 2);
    if (imag < 0) result_imag = -result_imag;
    return try makeComplex(allocator, result_real, result_imag);
}

/// Public wrapper for getting polynomial coefficients from an expression.
/// First expands the expression, then extracts numeric coefficients.
/// Returns a slice of Expr pointers (as numbers) [c_0, c_1, c_2, ...] for c_0 + c_1*x + c_2*x² + ...
/// Returns empty slice if not a valid polynomial with numeric coefficients.
pub fn getCoefficients(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError![]*Expr {
    // First expand the expression
    const expanded = try expand(expr, allocator);
    defer {
        expanded.deinit(allocator);
        allocator.destroy(expanded);
    }

    // Get numeric coefficients
    const numeric_coeffs = try collectPolyCoeffs(expanded, var_name, allocator);
    if (numeric_coeffs == null) {
        // Return empty slice
        const empty = allocator.alloc(*Expr, 0) catch return SimplifyError.OutOfMemory;
        return empty;
    }

    const coeffs = numeric_coeffs.?;
    defer allocator.free(coeffs);

    // Convert to Expr pointers
    const result = allocator.alloc(*Expr, coeffs.len) catch return SimplifyError.OutOfMemory;
    for (coeffs, 0..) |c, i| {
        const num_expr = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
        num_expr.* = .{ .number = c };
        result[i] = num_expr;
    }

    return result;
}

fn distributeProduct(args: *std.ArrayList(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr {
    if (args.items.len == 0) {
        return try makeNumber(allocator, 1);
    }
    if (args.items.len == 1) {
        return try copyExpr(args.items[0], allocator);
    }

    // Take first two arguments and distribute
    const first = args.items[0];
    const second = args.items[1];

    // Check if either is a sum
    const first_is_sum = first.* == .list and first.list.items.len > 0 and
        first.list.items[0].* == .symbol and std.mem.eql(u8, first.list.items[0].symbol, "+");
    const second_is_sum = second.* == .list and second.list.items.len > 0 and
        second.list.items[0].* == .symbol and std.mem.eql(u8, second.list.items[0].symbol, "+");

    var result: *Expr = undefined;

    if (first_is_sum and second_is_sum) {
        // (a + b) * (c + d) = ac + ad + bc + bd
        var sum_terms: std.ArrayList(*Expr) = .empty;
        errdefer {
            for (sum_terms.items) |t| {
                t.deinit(allocator);
                allocator.destroy(t);
            }
            sum_terms.deinit(allocator);
        }
        const sum_op = try makeSymbol(allocator, "+");
        sum_terms.append(allocator, sum_op) catch return SimplifyError.OutOfMemory;

        for (first.list.items[1..]) |a| {
            for (second.list.items[1..]) |b| {
                const a_copy = try copyExpr(a, allocator);
                const b_copy = try copyExpr(b, allocator);
                const prod = try makeBinOp(allocator, "*", a_copy, b_copy);
                sum_terms.append(allocator, prod) catch return SimplifyError.OutOfMemory;
            }
        }

        result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
        result.* = .{ .list = sum_terms };
    } else if (first_is_sum) {
        // (a + b) * c = ac + bc
        var sum_terms: std.ArrayList(*Expr) = .empty;
        errdefer {
            for (sum_terms.items) |t| {
                t.deinit(allocator);
                allocator.destroy(t);
            }
            sum_terms.deinit(allocator);
        }
        const sum_op = try makeSymbol(allocator, "+");
        sum_terms.append(allocator, sum_op) catch return SimplifyError.OutOfMemory;

        for (first.list.items[1..]) |a| {
            const a_copy = try copyExpr(a, allocator);
            const second_copy = try copyExpr(second, allocator);
            const prod = try makeBinOp(allocator, "*", a_copy, second_copy);
            sum_terms.append(allocator, prod) catch return SimplifyError.OutOfMemory;
        }

        result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
        result.* = .{ .list = sum_terms };
    } else if (second_is_sum) {
        // a * (b + c) = ab + ac
        var sum_terms: std.ArrayList(*Expr) = .empty;
        errdefer {
            for (sum_terms.items) |t| {
                t.deinit(allocator);
                allocator.destroy(t);
            }
            sum_terms.deinit(allocator);
        }
        const sum_op = try makeSymbol(allocator, "+");
        sum_terms.append(allocator, sum_op) catch return SimplifyError.OutOfMemory;

        for (second.list.items[1..]) |b| {
            const first_copy = try copyExpr(first, allocator);
            const b_copy = try copyExpr(b, allocator);
            const prod = try makeBinOp(allocator, "*", first_copy, b_copy);
            sum_terms.append(allocator, prod) catch return SimplifyError.OutOfMemory;
        }

        result = allocator.create(Expr) catch return SimplifyError.OutOfMemory;
        result.* = .{ .list = sum_terms };
    } else {
        // Neither is a sum, just multiply
        const first_copy = try copyExpr(first, allocator);
        const second_copy = try copyExpr(second, allocator);
        result = try makeBinOp(allocator, "*", first_copy, second_copy);
    }

    // If there are more arguments, continue distributing
    if (args.items.len > 2) {
        var remaining: std.ArrayList(*Expr) = .empty;
        remaining.append(allocator, result) catch return SimplifyError.OutOfMemory;
        for (args.items[2..]) |arg| {
            const arg_copy = try copyExpr(arg, allocator);
            remaining.append(allocator, arg_copy) catch return SimplifyError.OutOfMemory;
        }
        const final_result = try distributeProduct(&remaining, allocator);
        for (remaining.items) |item| {
            item.deinit(allocator);
            allocator.destroy(item);
        }
        remaining.deinit(allocator);
        return final_result;
    }

    return result;
}
