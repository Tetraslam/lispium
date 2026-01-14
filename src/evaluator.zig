const std = @import("std");
const Expr = @import("parser.zig").Expr;
const Env = @import("environment.zig").Env;
const BuiltinError = @import("builtins.zig").BuiltinError;
const EnvError = @import("environment.zig").Error;
const symbolic = @import("symbolic.zig");

const SavedBinding = struct { name: []const u8, value: ?*Expr };

pub const Error = error{
    UnsupportedOperator,
    OutOfMemory,
    InvalidLambda,
    InvalidDefine,
    WrongNumberOfArguments,
} || BuiltinError || EnvError || symbolic.SimplifyError;

pub fn eval(expr: *Expr, env: *Env) Error!*Expr {
    switch (expr.*) {
        .number => {
            // Return a copy to ensure the result has independent ownership
            return try symbolic.copyExpr(expr, env.allocator);
        },
        .symbol => |sym| {
            // Try to get a value from the environment, but if not found,
            // treat it as a symbolic variable
            if (env.get(sym)) |val| {
                return try symbolic.copyExpr(val, env.allocator);
            } else |_| {
                return try symbolic.copyExpr(expr, env.allocator);
            }
        },
        .owned_symbol => |sym| {
            // Treat owned_symbol like symbol for evaluation purposes
            if (env.get(sym)) |val| {
                return try symbolic.copyExpr(val, env.allocator);
            } else |_| {
                return try symbolic.copyExpr(expr, env.allocator);
            }
        },
        .lambda => {
            // Lambda evaluates to itself (a copy)
            return try symbolic.copyExpr(expr, env.allocator);
        },
        .list => {
            if (expr.list.items.len == 0) {
                return try symbolic.copyExpr(expr, env.allocator);
            }
            // Get the operator
            const op_expr = expr.list.items[0];

            // Handle special forms first (before evaluating anything)
            if (op_expr.* == .symbol) {
                // (lambda (params...) body)
                if (std.mem.eql(u8, op_expr.symbol, "lambda")) {
                    return try evalLambda(expr, env);
                }
                // (define name value) or (define (name params...) body)
                if (std.mem.eql(u8, op_expr.symbol, "define")) {
                    return try evalDefine(expr, env);
                }
                // (if condition then-expr else-expr)
                if (std.mem.eql(u8, op_expr.symbol, "if")) {
                    return try evalIf(expr, env);
                }
                // (let ((var val) ...) body)
                if (std.mem.eql(u8, op_expr.symbol, "let")) {
                    return try evalLet(expr, env);
                }
                // (matrix (row1...) (row2...) ...) - special form, don't evaluate rows
                if (std.mem.eql(u8, op_expr.symbol, "matrix")) {
                    return try evalMatrix(expr, env);
                }
                // (sum var start end body) - summation notation
                if (std.mem.eql(u8, op_expr.symbol, "sum")) {
                    return try evalSum(expr, env);
                }
                // (letrec ((var val) ...) body) - recursive let
                if (std.mem.eql(u8, op_expr.symbol, "letrec")) {
                    return try evalLetrec(expr, env);
                }
                // (product var start end body) - product notation
                if (std.mem.eql(u8, op_expr.symbol, "product")) {
                    return try evalProduct(expr, env);
                }
                // (solve equation var) - special form to handle (= left right) syntax
                if (std.mem.eql(u8, op_expr.symbol, "solve")) {
                    return try evalSolve(expr, env);
                }
            }

            // Evaluate the operator (could be a lambda expression or a symbol)
            const evaled_op = try eval(op_expr, env);
            defer {
                evaled_op.deinit(env.allocator);
                env.allocator.destroy(evaled_op);
            }

            // If the operator evaluated to a lambda, call it
            if (evaled_op.* == .lambda) {
                return try callLambda(evaled_op, expr.list.items[1..], env);
            }

            // Otherwise, try builtin lookup (operator must be a symbol)
            if (op_expr.* != .symbol) {
                return Error.UnsupportedOperator;
            }

            const func = env.getBuiltin(op_expr.symbol) catch {
                // Not a builtin - check if it's a user-defined function in variables
                if (env.get(op_expr.symbol)) |val| {
                    if (val.* == .lambda) {
                        return try callLambda(val, expr.list.items[1..], env);
                    }
                } else |_| {}
                // Return as symbolic expression
                return try symbolic.copyExpr(expr, env.allocator);
            };

            // Evaluate arguments - evaluator owns these, will free after builtin returns
            var args: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (args.items) |arg| {
                    arg.deinit(env.allocator);
                    env.allocator.destroy(arg);
                }
                args.deinit(env.allocator);
            }
            for (expr.list.items[1..]) |arg| {
                try args.append(env.allocator, try eval(arg, env));
            }
            const result = try func(args, env);
            // Free the args - builtin should have copied anything it needs
            for (args.items) |arg| {
                arg.deinit(env.allocator);
                env.allocator.destroy(arg);
            }
            args.deinit(env.allocator);
            return result;
        },
    }
}

/// Evaluates (lambda (params...) body) into a Lambda expression
fn evalLambda(expr: *Expr, env: *Env) Error!*Expr {
    // (lambda (x y) body) - list has 3 elements: lambda, params, body
    if (expr.list.items.len != 3) return Error.InvalidLambda;

    const params_expr = expr.list.items[1];
    const body_expr = expr.list.items[2];

    // params should be a list of symbols
    if (params_expr.* != .list) return Error.InvalidLambda;

    var params: std.ArrayList([]const u8) = .empty;
    errdefer params.deinit(env.allocator);

    for (params_expr.list.items) |p| {
        if (p.* != .symbol) return Error.InvalidLambda;
        try params.append(env.allocator, p.symbol);
    }

    // Copy the body (don't evaluate it yet)
    const body_copy = try symbolic.copyExpr(body_expr, env.allocator);

    const result = try env.allocator.create(Expr);
    result.* = .{ .lambda = .{ .params = params, .body = body_copy } };
    return result;
}

/// Evaluates (define name value) or (define (name params...) body)
fn evalDefine(expr: *Expr, env: *Env) Error!*Expr {
    if (expr.list.items.len < 3) return Error.InvalidDefine;

    const name_or_sig = expr.list.items[1];

    if (name_or_sig.* == .symbol) {
        // Simple form: (define name value)
        if (expr.list.items.len != 3) return Error.InvalidDefine;

        const value = try eval(expr.list.items[2], env);
        errdefer {
            value.deinit(env.allocator);
            env.allocator.destroy(value);
        }

        // If there's an old value, free it
        if (env.get(name_or_sig.symbol)) |old| {
            old.deinit(env.allocator);
            env.allocator.destroy(old);
        } else |_| {}

        try env.put(name_or_sig.symbol, value);

        // Return the value (as a copy since we stored the original)
        return try symbolic.copyExpr(value, env.allocator);
    } else if (name_or_sig.* == .list) {
        // Function form: (define (name params...) body)
        // Equivalent to (define name (lambda (params...) body))
        if (name_or_sig.list.items.len == 0) return Error.InvalidDefine;
        if (name_or_sig.list.items[0].* != .symbol) return Error.InvalidDefine;

        const func_name = name_or_sig.list.items[0].symbol;

        // Build params list
        var params: std.ArrayList([]const u8) = .empty;
        errdefer params.deinit(env.allocator);

        for (name_or_sig.list.items[1..]) |p| {
            if (p.* != .symbol) return Error.InvalidDefine;
            try params.append(env.allocator, p.symbol);
        }

        // Body is the rest of the define (could be multiple expressions, take last for now)
        const body_copy = try symbolic.copyExpr(expr.list.items[2], env.allocator);

        const lambda_expr = try env.allocator.create(Expr);
        lambda_expr.* = .{ .lambda = .{ .params = params, .body = body_copy } };

        // If there's an old value, free it
        if (env.get(func_name)) |old| {
            old.deinit(env.allocator);
            env.allocator.destroy(old);
        } else |_| {}

        try env.put(func_name, lambda_expr);

        // Return the lambda
        return try symbolic.copyExpr(lambda_expr, env.allocator);
    }

    return Error.InvalidDefine;
}

/// Evaluates (if condition then-expr else-expr)
fn evalIf(expr: *Expr, env: *Env) Error!*Expr {
    // (if cond then else) - 4 elements, or (if cond then) - 3 elements
    if (expr.list.items.len < 3 or expr.list.items.len > 4) {
        return Error.InvalidDefine; // Reuse error for now
    }

    const cond = try eval(expr.list.items[1], env);
    defer {
        cond.deinit(env.allocator);
        env.allocator.destroy(cond);
    }

    // Truthy: anything that's not 0 or empty list
    const is_truthy = switch (cond.*) {
        .number => |n| n != 0,
        .symbol, .owned_symbol => true,
        .list => |lst| lst.items.len > 0,
        .lambda => true,
    };

    if (is_truthy) {
        return try eval(expr.list.items[2], env);
    } else if (expr.list.items.len == 4) {
        return try eval(expr.list.items[3], env);
    } else {
        // No else branch, return 0
        const result = try env.allocator.create(Expr);
        result.* = .{ .number = 0 };
        return result;
    }
}

/// Evaluates (let ((var val) ...) body)
fn evalLet(expr: *Expr, env: *Env) Error!*Expr {
    // (let ((x 1) (y 2)) body) - 3 elements
    if (expr.list.items.len != 3) return Error.InvalidDefine;

    const bindings = expr.list.items[1];
    const body = expr.list.items[2];

    if (bindings.* != .list) return Error.InvalidDefine;

    // Save old values and set new ones
    var old_values: std.ArrayList(SavedBinding) = .empty;
    defer old_values.deinit(env.allocator);

    // Evaluate and bind all variables
    for (bindings.list.items) |binding| {
        if (binding.* != .list or binding.list.items.len != 2) return Error.InvalidDefine;
        if (binding.list.items[0].* != .symbol) return Error.InvalidDefine;

        const var_name = binding.list.items[0].symbol;
        const var_val = try eval(binding.list.items[1], env);

        // Save old value if it exists
        const old_val = env.get(var_name) catch null;
        try old_values.append(env.allocator, .{ .name = var_name, .value = old_val });

        try env.put(var_name, var_val);
    }

    // Evaluate body
    const result = eval(body, env) catch |err| {
        // Restore old values on error
        for (old_values.items) |item| {
            if (item.value) |old| {
                const current = env.get(item.name) catch null;
                if (current) |c| {
                    c.deinit(env.allocator);
                    env.allocator.destroy(c);
                }
                env.put(item.name, old) catch {};
            } else {
                // Remove the binding
                if (env.get(item.name)) |current| {
                    current.deinit(env.allocator);
                    env.allocator.destroy(current);
                } else |_| {}
                _ = env.variables.remove(item.name);
            }
        }
        return err;
    };

    // Restore old values (let has lexical scope)
    for (old_values.items) |item| {
        if (item.value) |old| {
            const current = env.get(item.name) catch null;
            if (current) |c| {
                c.deinit(env.allocator);
                env.allocator.destroy(c);
            }
            try env.put(item.name, old);
        } else {
            // Remove the binding
            if (env.get(item.name)) |current| {
                current.deinit(env.allocator);
                env.allocator.destroy(current);
            } else |_| {}
            _ = env.variables.remove(item.name);
        }
    }

    return result;
}

/// Evaluates (letrec ((var val) ...) body) - allows recursive bindings
fn evalLetrec(expr: *Expr, env: *Env) Error!*Expr {
    // (letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))) (fact 5))
    if (expr.list.items.len != 3) return Error.InvalidDefine;

    const bindings = expr.list.items[1];
    const body = expr.list.items[2];

    if (bindings.* != .list) return Error.InvalidDefine;

    // Save old values
    var old_values: std.ArrayList(SavedBinding) = .empty;
    defer old_values.deinit(env.allocator);

    // First pass: bind all names to placeholders (allows mutual recursion)
    for (bindings.list.items) |binding| {
        if (binding.* != .list or binding.list.items.len != 2) return Error.InvalidDefine;
        if (binding.list.items[0].* != .symbol) return Error.InvalidDefine;

        const var_name = binding.list.items[0].symbol;

        // Save old value if it exists
        const old_val = env.get(var_name) catch null;
        try old_values.append(env.allocator, .{ .name = var_name, .value = old_val });

        // Create a placeholder (we'll replace it after all bindings are visible)
        const placeholder = try env.allocator.create(Expr);
        placeholder.* = .{ .number = 0 };
        try env.put(var_name, placeholder);
    }

    // Second pass: evaluate values now that all names are bound
    for (bindings.list.items) |binding| {
        const var_name = binding.list.items[0].symbol;
        const var_val = try eval(binding.list.items[1], env);

        // Replace placeholder with actual value
        if (env.get(var_name)) |current| {
            current.deinit(env.allocator);
            env.allocator.destroy(current);
        } else |_| {}

        try env.put(var_name, var_val);
    }

    // Evaluate body
    const result = eval(body, env) catch |err| {
        // Restore old values on error
        for (old_values.items) |item| {
            if (item.value) |old| {
                const current = env.get(item.name) catch null;
                if (current) |c| {
                    c.deinit(env.allocator);
                    env.allocator.destroy(c);
                }
                env.put(item.name, old) catch {};
            } else {
                // Remove the binding
                if (env.get(item.name)) |current| {
                    current.deinit(env.allocator);
                    env.allocator.destroy(current);
                } else |_| {}
                _ = env.variables.remove(item.name);
            }
        }
        return err;
    };

    // Restore old values (letrec has lexical scope)
    for (old_values.items) |item| {
        if (item.value) |old| {
            const current = env.get(item.name) catch null;
            if (current) |c| {
                c.deinit(env.allocator);
                env.allocator.destroy(c);
            }
            try env.put(item.name, old);
        } else {
            // Remove the binding
            if (env.get(item.name)) |current| {
                current.deinit(env.allocator);
                env.allocator.destroy(current);
            } else |_| {}
            _ = env.variables.remove(item.name);
        }
    }

    return result;
}

/// Calls a lambda with given arguments
fn callLambda(lambda: *const Expr, arg_exprs: []*Expr, env: *Env) Error!*Expr {
    const lam = lambda.lambda;

    if (arg_exprs.len != lam.params.items.len) {
        return Error.WrongNumberOfArguments;
    }

    // Evaluate arguments
    var args: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (args.items) |arg| {
            arg.deinit(env.allocator);
            env.allocator.destroy(arg);
        }
        args.deinit(env.allocator);
    }

    for (arg_exprs) |arg_expr| {
        try args.append(env.allocator, try eval(arg_expr, env));
    }

    // Save old bindings
    var old_values: std.ArrayList(SavedBinding) = .empty;
    defer old_values.deinit(env.allocator);

    // Bind parameters to arguments
    for (lam.params.items, args.items) |param, arg| {
        const old_val = env.get(param) catch null;
        try old_values.append(env.allocator, .{ .name = param, .value = old_val });

        // Copy the arg since we'll free it after
        const arg_copy = try symbolic.copyExpr(arg, env.allocator);
        try env.put(param, arg_copy);
    }

    // Evaluate body
    const result = eval(lam.body, env) catch |err| {
        // Restore old values on error
        restoreBindings(&old_values, env);
        return err;
    };

    // Restore old values
    restoreBindings(&old_values, env);

    // Free the evaluated args
    for (args.items) |arg| {
        arg.deinit(env.allocator);
        env.allocator.destroy(arg);
    }
    args.deinit(env.allocator);

    return result;
}

/// Evaluates (matrix (row1...) (row2...) ...) without evaluating row contents
fn evalMatrix(expr: *Expr, env: *Env) Error!*Expr {
    // (matrix (a b) (c d) ...) - rows are not evaluated, just passed through
    // This allows symbolic matrices with unevaluated row lists

    // Build result: (matrix row1 row2 ...)
    var result_list: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (result_list.items) |item| {
            item.deinit(env.allocator);
            env.allocator.destroy(item);
        }
        result_list.deinit(env.allocator);
    }

    // Copy the "matrix" symbol
    const matrix_sym = try env.allocator.create(Expr);
    matrix_sym.* = .{ .symbol = "matrix" };
    try result_list.append(env.allocator, matrix_sym);

    // Validate and copy rows (don't evaluate them)
    var cols: ?usize = null;
    for (expr.list.items[1..]) |row| {
        if (row.* != .list) return Error.InvalidDefine; // Rows must be lists

        // Check rectangular
        if (cols == null) {
            cols = row.list.items.len;
        } else if (row.list.items.len != cols.?) {
            return Error.InvalidDefine; // Non-rectangular
        }

        // Copy row without evaluating
        const row_copy = try symbolic.copyExpr(row, env.allocator);
        try result_list.append(env.allocator, row_copy);
    }

    const result = try env.allocator.create(Expr);
    result.* = .{ .list = result_list };
    return result;
}

/// Evaluates (sum var start end body) - summation notation
fn evalSum(expr: *Expr, env: *Env) Error!*Expr {
    // (sum i 1 5 (* i i)) computes sum of i^2 from i=1 to i=5
    if (expr.list.items.len != 5) return Error.InvalidDefine;

    const var_expr = expr.list.items[1];
    const start_expr = expr.list.items[2];
    const end_expr = expr.list.items[3];
    const body_expr = expr.list.items[4];

    if (var_expr.* != .symbol) return Error.InvalidDefine;
    const var_name = var_expr.symbol;

    // Evaluate start and end
    const start_val = try eval(start_expr, env);
    defer {
        start_val.deinit(env.allocator);
        env.allocator.destroy(start_val);
    }
    const end_val = try eval(end_expr, env);
    defer {
        end_val.deinit(env.allocator);
        env.allocator.destroy(end_val);
    }

    // If both bounds are numeric integers, compute the sum
    if (start_val.* == .number and end_val.* == .number) {
        const start_int: i64 = @intFromFloat(start_val.number);
        const end_int: i64 = @intFromFloat(end_val.number);

        if (start_int > end_int) {
            // Empty sum
            const result = try env.allocator.create(Expr);
            result.* = .{ .number = 0 };
            return result;
        }

        // Save old binding
        const old_val = env.get(var_name) catch null;

        // Compute sum
        var sum_result: ?*Expr = null;
        errdefer if (sum_result) |s| {
            s.deinit(env.allocator);
            env.allocator.destroy(s);
        };

        var i: i64 = start_int;
        while (i <= end_int) : (i += 1) {
            // Free previous index binding if any (from previous iteration)
            if (env.get(var_name)) |prev| {
                prev.deinit(env.allocator);
                env.allocator.destroy(prev);
            } else |_| {}

            // Bind variable
            const idx_expr = try env.allocator.create(Expr);
            idx_expr.* = .{ .number = @floatFromInt(i) };
            try env.put(var_name, idx_expr);

            // Evaluate body
            const term = try eval(body_expr, env);

            if (sum_result) |s| {
                // Add to running sum
                const new_sum = try symbolic.makeBinOp(env.allocator, "+", s, term);
                sum_result = new_sum;
            } else {
                sum_result = term;
            }
        }

        // Restore old binding
        if (env.get(var_name)) |current| {
            current.deinit(env.allocator);
            env.allocator.destroy(current);
        } else |_| {}

        if (old_val) |old| {
            try env.put(var_name, old);
        } else {
            _ = env.variables.remove(var_name);
        }

        // Simplify result
        if (sum_result) |s| {
            const simplified = try symbolic.simplify(s, env.allocator);
            s.deinit(env.allocator);
            env.allocator.destroy(s);
            return simplified;
        } else {
            const result = try env.allocator.create(Expr);
            result.* = .{ .number = 0 };
            return result;
        }
    }

    // Symbolic bounds - return as symbolic sum expression
    var result_list: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (result_list.items) |item| {
            item.deinit(env.allocator);
            env.allocator.destroy(item);
        }
        result_list.deinit(env.allocator);
    }

    const sum_sym = try env.allocator.create(Expr);
    sum_sym.* = .{ .symbol = "sum" };
    try result_list.append(env.allocator, sum_sym);
    try result_list.append(env.allocator, try symbolic.copyExpr(var_expr, env.allocator));
    try result_list.append(env.allocator, try symbolic.copyExpr(start_val, env.allocator));
    try result_list.append(env.allocator, try symbolic.copyExpr(end_val, env.allocator));
    try result_list.append(env.allocator, try symbolic.copyExpr(body_expr, env.allocator));

    const result = try env.allocator.create(Expr);
    result.* = .{ .list = result_list };
    return result;
}

/// Evaluates (product var start end body) - product notation
fn evalProduct(expr: *Expr, env: *Env) Error!*Expr {
    // (product i 1 5 i) computes 1*2*3*4*5 = 120 (factorial)
    if (expr.list.items.len != 5) return Error.InvalidDefine;

    const var_expr = expr.list.items[1];
    const start_expr = expr.list.items[2];
    const end_expr = expr.list.items[3];
    const body_expr = expr.list.items[4];

    if (var_expr.* != .symbol) return Error.InvalidDefine;
    const var_name = var_expr.symbol;

    // Evaluate start and end
    const start_val = try eval(start_expr, env);
    defer {
        start_val.deinit(env.allocator);
        env.allocator.destroy(start_val);
    }
    const end_val = try eval(end_expr, env);
    defer {
        end_val.deinit(env.allocator);
        env.allocator.destroy(end_val);
    }

    // If both bounds are numeric integers, compute the product
    if (start_val.* == .number and end_val.* == .number) {
        const start_int: i64 = @intFromFloat(start_val.number);
        const end_int: i64 = @intFromFloat(end_val.number);

        if (start_int > end_int) {
            // Empty product
            const result = try env.allocator.create(Expr);
            result.* = .{ .number = 1 };
            return result;
        }

        // Save old binding
        const old_val = env.get(var_name) catch null;

        // Compute product
        var product_result: ?*Expr = null;
        errdefer if (product_result) |p| {
            p.deinit(env.allocator);
            env.allocator.destroy(p);
        };

        var i: i64 = start_int;
        while (i <= end_int) : (i += 1) {
            // Free previous index binding if any (from previous iteration)
            if (env.get(var_name)) |prev| {
                prev.deinit(env.allocator);
                env.allocator.destroy(prev);
            } else |_| {}

            // Bind variable
            const idx_expr = try env.allocator.create(Expr);
            idx_expr.* = .{ .number = @floatFromInt(i) };
            try env.put(var_name, idx_expr);

            // Evaluate body
            const term = try eval(body_expr, env);

            if (product_result) |p| {
                // Multiply with running product
                const new_product = try symbolic.makeBinOp(env.allocator, "*", p, term);
                product_result = new_product;
            } else {
                product_result = term;
            }
        }

        // Restore old binding
        if (env.get(var_name)) |current| {
            current.deinit(env.allocator);
            env.allocator.destroy(current);
        } else |_| {}

        if (old_val) |old| {
            try env.put(var_name, old);
        } else {
            _ = env.variables.remove(var_name);
        }

        // Simplify result
        if (product_result) |p| {
            const simplified = try symbolic.simplify(p, env.allocator);
            p.deinit(env.allocator);
            env.allocator.destroy(p);
            return simplified;
        } else {
            const result = try env.allocator.create(Expr);
            result.* = .{ .number = 1 };
            return result;
        }
    }

    // Symbolic bounds - return as symbolic product expression
    var result_list: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (result_list.items) |item| {
            item.deinit(env.allocator);
            env.allocator.destroy(item);
        }
        result_list.deinit(env.allocator);
    }

    const prod_sym = try env.allocator.create(Expr);
    prod_sym.* = .{ .symbol = "product" };
    try result_list.append(env.allocator, prod_sym);
    try result_list.append(env.allocator, try symbolic.copyExpr(var_expr, env.allocator));
    try result_list.append(env.allocator, try symbolic.copyExpr(start_val, env.allocator));
    try result_list.append(env.allocator, try symbolic.copyExpr(end_val, env.allocator));
    try result_list.append(env.allocator, try symbolic.copyExpr(body_expr, env.allocator));

    const result = try env.allocator.create(Expr);
    result.* = .{ .list = result_list };
    return result;
}

/// Evaluates (solve equation var) where equation can be:
/// - (= left right) which gets converted to (- left right) = 0
/// - Any expression assumed equal to 0
fn evalSolve(expr: *Expr, env: *Env) Error!*Expr {
    if (expr.list.items.len != 3) return Error.InvalidDefine;

    const eq_expr = expr.list.items[1];
    const var_expr = expr.list.items[2];

    if (var_expr.* != .symbol) return Error.InvalidDefine;
    const var_name = var_expr.symbol;

    // Check if equation is in (= left right) form
    var equation_to_solve: *Expr = undefined;
    var owns_equation = false;

    if (eq_expr.* == .list and eq_expr.list.items.len == 3) {
        if (eq_expr.list.items[0].* == .symbol and
            std.mem.eql(u8, eq_expr.list.items[0].symbol, "="))
        {
            // Convert (= left right) to (- left right)
            const left = try eval(eq_expr.list.items[1], env);
            errdefer {
                left.deinit(env.allocator);
                env.allocator.destroy(left);
            }
            const right = try eval(eq_expr.list.items[2], env);
            errdefer {
                right.deinit(env.allocator);
                env.allocator.destroy(right);
            }

            equation_to_solve = try symbolic.makeBinOp(env.allocator, "-", left, right);
            owns_equation = true;
        }
    }

    if (!owns_equation) {
        // Normal form: evaluate the expression (assumed = 0)
        equation_to_solve = try eval(eq_expr, env);
        owns_equation = true;
    }

    defer if (owns_equation) {
        equation_to_solve.deinit(env.allocator);
        env.allocator.destroy(equation_to_solve);
    };

    return symbolic.solve(equation_to_solve, var_name, env.allocator) catch return Error.OutOfMemory;
}

fn restoreBindings(old_values: *std.ArrayList(SavedBinding), env: *Env) void {
    for (old_values.items) |item| {
        if (item.value) |old| {
            const current = env.get(item.name) catch null;
            if (current) |c| {
                c.deinit(env.allocator);
                env.allocator.destroy(c);
            }
            env.put(item.name, old) catch {};
        } else {
            // Remove the binding
            if (env.get(item.name)) |current| {
                current.deinit(env.allocator);
                env.allocator.destroy(current);
            } else |_| {}
            _ = env.variables.remove(item.name);
        }
    }
}
