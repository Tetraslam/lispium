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
    InvalidSyntax,
    WrongNumberOfArguments,
} || BuiltinError || EnvError || symbolic.SimplifyError;

/// Maximum evaluator recursion depth. Prevents native stack overflow from
/// deeply recursive user code or deeply nested expressions; exceeding it
/// returns error.RecursionLimit instead of crashing.
pub const MAX_EVAL_DEPTH = 2000;

/// Maximum number of iterations for (sum ...) and (product ...) loops.
pub const MAX_LOOP_ITERATIONS: i64 = 10_000_000;

threadlocal var eval_depth: usize = 0;

/// Name of the builtin that most recently reported an error, so the REPL
/// and CLI can say *which* function rejected its arguments.
threadlocal var error_context_buf: [64]u8 = undefined;
threadlocal var error_context_len: usize = 0;

fn setErrorContext(name: []const u8) void {
    const n = @min(name.len, error_context_buf.len);
    @memcpy(error_context_buf[0..n], name[0..n]);
    error_context_len = n;
}

/// Returns the name of the most recently failing builtin (empty if none),
/// clearing it in the process.
pub fn takeErrorContext() []const u8 {
    const n = error_context_len;
    error_context_len = 0;
    return error_context_buf[0..n];
}

pub fn eval(expr: *Expr, env: *Env) Error!*Expr {
    eval_depth += 1;
    defer eval_depth -= 1;
    if (eval_depth > MAX_EVAL_DEPTH) return Error.RecursionLimit;
    return evalInner(expr, env);
}

fn evalInner(expr: *Expr, env: *Env) Error!*Expr {
    switch (expr.*) {
        .number => {
            // Return a copy to ensure the result has independent ownership
            return try symbolic.copyExpr(expr, env.allocator);
        },
        .string => {
            // Strings are self-evaluating
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
                // (dsolve equation y x) - special form: the ODE must NOT be
                // pre-evaluated (otherwise (diff y x) collapses to 0)
                if (std.mem.eql(u8, op_expr.symbol, "dsolve")) {
                    return try evalDsolve(expr, env);
                }
                // (begin e1 e2 ...) - evaluate in order, return the last
                if (std.mem.eql(u8, op_expr.symbol, "begin")) {
                    return try evalBegin(expr, env);
                }
                // (cond (test result) ... (else result)) - multi-branch
                if (std.mem.eql(u8, op_expr.symbol, "cond")) {
                    return try evalCond(expr, env);
                }
                // (and ...) / (or ...) - short-circuit special forms
                if (std.mem.eql(u8, op_expr.symbol, "and")) {
                    return try evalAndOr(expr, env, true);
                }
                if (std.mem.eql(u8, op_expr.symbol, "or")) {
                    return try evalAndOr(expr, env, false);
                }
                // (try expr fallback) - evaluate expr; on error, evaluate
                // fallback instead (recoverable error handling)
                if (std.mem.eql(u8, op_expr.symbol, "try")) {
                    if (expr.list.items.len != 3) return Error.InvalidSyntax;
                    const attempted = eval(expr.list.items[1], env) catch |err| switch (err) {
                        error.OutOfMemory => return err,
                        else => return try eval(expr.list.items[2], env),
                    };
                    return attempted;
                }
                // (time expr) - evaluate and report wall time
                if (std.mem.eql(u8, op_expr.symbol, "time")) {
                    if (expr.list.items.len != 2) return Error.InvalidSyntax;
                    const io = env.io orelse return try eval(expr.list.items[1], env);
                    const start = std.Io.Timestamp.now(io, .awake).nanoseconds;
                    const result = try eval(expr.list.items[1], env);
                    const elapsed = std.Io.Timestamp.now(io, .awake).nanoseconds - start;
                    if (env.out) |out| {
                        const us: u64 = @intCast(@max(0, @divTrunc(elapsed, 1000)));
                        if (us < 1000) {
                            out.print("time: {d}us\n", .{us}) catch {};
                        } else if (us < 1_000_000) {
                            out.print("time: {d}.{d:0>3}ms\n", .{ us / 1000, us % 1000 }) catch {};
                        } else {
                            out.print("time: {d}.{d:0>3}s\n", .{ us / 1_000_000, (us % 1_000_000) / 1000 }) catch {};
                        }
                        out.flush() catch {};
                    }
                    return result;
                }
                // (trace name) - toggle call tracing for a user function.
                // Only intercepts when the argument names a lambda (the
                // matrix trace builtin keeps working for everything else).
                if (std.mem.eql(u8, op_expr.symbol, "trace") and
                    expr.list.items.len == 2 and expr.list.items[1].* == .symbol)
                {
                    const name = expr.list.items[1].symbol;
                    const is_fn = if (env.get(name)) |v| v.* == .lambda else |_| false;
                    if (is_fn or env.isTraced(name)) {
                        const enabled = env.toggleTrace(name) catch return Error.OutOfMemory;
                        const result = try env.allocator.create(Expr);
                        result.* = .{ .symbol = if (enabled) "tracing" else "untraced" };
                        return result;
                    }
                }
                // (defmacro (name params...) template) - define a macro
                if (std.mem.eql(u8, op_expr.symbol, "defmacro")) {
                    return try evalDefmacro(expr, env);
                }
                // (quote expr) - return expr unevaluated
                if (std.mem.eql(u8, op_expr.symbol, "quote")) {
                    if (expr.list.items.len != 2) return Error.InvalidSyntax;
                    return try symbolic.copyExpr(expr.list.items[1], env.allocator);
                }
                // (quasiquote expr) - like quote, but (unquote x) evaluates
                if (std.mem.eql(u8, op_expr.symbol, "quasiquote")) {
                    if (expr.list.items.len != 2) return Error.InvalidSyntax;
                    return try evalQuasiquote(expr.list.items[1], env);
                }
                // (unquote expr) outside quasiquote is an error
                if (std.mem.eql(u8, op_expr.symbol, "unquote")) {
                    return Error.InvalidSyntax;
                }
            }

            // Macro expansion: bind unevaluated arguments into the
            // template, then evaluate the expansion
            if (op_expr.* == .symbol) {
                if (env.getMacro(op_expr.symbol)) |macro| {
                    return try expandAndEvalMacro(macro, expr.list.items[1..], env);
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
                if (op_expr.* == .symbol and env.isTraced(op_expr.symbol)) {
                    return try callLambdaTraced(op_expr.symbol, evaled_op, expr.list.items[1..], env);
                }
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
                        if (env.isTraced(op_expr.symbol)) {
                            return try callLambdaTraced(op_expr.symbol, val, expr.list.items[1..], env);
                        }
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
            const result = func(args, env) catch |err| {
                // Remember the failing operator for better error messages
                setErrorContext(op_expr.symbol);
                return err;
            };
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

/// Evaluates (lambda (params...) body) into a Lambda expression.
/// Free variables in the body that are currently bound in the environment
/// are captured by value at creation time (closure semantics).
fn evalLambda(expr: *Expr, env: *Env) Error!*Expr {
    // (lambda (x y) body...) - multiple body expressions form an implicit begin
    if (expr.list.items.len < 3) return Error.InvalidLambda;

    const params_expr = expr.list.items[1];
    var body_storage: ?*Expr = null;
    defer if (body_storage) |b| {
        b.deinit(env.allocator);
        env.allocator.destroy(b);
    };
    const body_expr = if (expr.list.items.len == 3)
        expr.list.items[2]
    else blk: {
        const wrapped = try makeImplicitBegin(expr.list.items[2..], env);
        body_storage = wrapped;
        break :blk wrapped;
    };

    // params should be a list of symbols
    if (params_expr.* != .list) return Error.InvalidLambda;

    var params: std.ArrayList([]const u8) = .empty;
    errdefer params.deinit(env.allocator);

    // "." before the final parameter marks a rest (variadic) parameter;
    // it is stored with a "." prefix marker in the params list
    var i: usize = 0;
    const plist = params_expr.list.items;
    while (i < plist.len) : (i += 1) {
        const p = plist[i];
        if (p.* != .symbol) return Error.InvalidLambda;
        if (std.mem.eql(u8, p.symbol, ".")) {
            if (i + 2 != plist.len) return Error.InvalidLambda;
            if (plist[i + 1].* != .symbol) return Error.InvalidLambda;
            try params.append(env.allocator, ".");
            try params.append(env.allocator, plist[i + 1].symbol);
            break;
        }
        try params.append(env.allocator, p.symbol);
    }

    // Capture free variables by value (don't evaluate the body itself).
    // Names (define)d inside the body are mutable globals: never capture.
    var shadowed: std.ArrayList([]const u8) = .empty;
    defer shadowed.deinit(env.allocator);
    try shadowed.appendSlice(env.allocator, params.items);
    try collectDefinedNames(body_expr, &shadowed, env.allocator);
    const body_copy = try captureFreeVars(body_expr, &shadowed, env);

    const result = try env.allocator.create(Expr);
    result.* = .{ .lambda = .{ .params = params, .body = body_copy } };
    return result;
}

/// Collects names bound by (define name ...) anywhere inside an expression.
/// Such names are treated as mutable globals and are never captured.
fn collectDefinedNames(expr: *const Expr, names: *std.ArrayList([]const u8), allocator: std.mem.Allocator) !void {
    if (expr.* != .list) return;
    const items = expr.list.items;
    if (items.len >= 2 and items[0].* == .symbol and std.mem.eql(u8, items[0].symbol, "define")) {
        if (items[1].* == .symbol) {
            try names.append(allocator, items[1].symbol);
        } else if (items[1].* == .list and items[1].list.items.len > 0 and items[1].list.items[0].* == .symbol) {
            try names.append(allocator, items[1].list.items[0].symbol);
        }
    }
    for (items) |item| {
        try collectDefinedNames(item, names, allocator);
    }
}

fn isShadowed(shadowed: *std.ArrayList([]const u8), name: []const u8) bool {
    for (shadowed.items) |s| {
        if (std.mem.eql(u8, s, name)) return true;
    }
    return false;
}

/// Copies an expression, substituting free variables with their current
/// environment values (capture-by-value closures). Names bound by nested
/// lambda/let/letrec/sum/product/define forms are respected (shadowed).
fn captureFreeVars(expr: *const Expr, shadowed: *std.ArrayList([]const u8), env: *Env) Error!*Expr {
    switch (expr.*) {
        .number, .string, .lambda => return try symbolic.copyExpr(expr, env.allocator),
        .symbol, .owned_symbol => {
            const name = switch (expr.*) {
                .symbol => |s| s,
                .owned_symbol => |s| s,
                else => unreachable,
            };
            if (!isShadowed(shadowed, name)) {
                if (env.variables.get(name)) |val| {
                    // Skip self-referential placeholders (used by letrec)
                    const is_self = switch (val.*) {
                        .symbol => |vs| std.mem.eql(u8, vs, name),
                        .owned_symbol => |vs| std.mem.eql(u8, vs, name),
                        else => false,
                    };
                    if (!is_self) return try symbolic.copyExpr(val, env.allocator);
                }
            }
            return try symbolic.copyExpr(expr, env.allocator);
        },
        .list => |lst| {
            if (lst.items.len == 0) return try symbolic.copyExpr(expr, env.allocator);

            const head = lst.items[0];
            const head_name: ?[]const u8 = if (head.* == .symbol) head.symbol else null;

            var new_list: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (new_list.items) |item| {
                    item.deinit(env.allocator);
                    env.allocator.destroy(item);
                }
                new_list.deinit(env.allocator);
            }

            if (head_name) |hn| {
                // matrix rows and quoted data are never evaluated; leave
                // them untouched (quasiquote is conservative: skip capture)
                if (std.mem.eql(u8, hn, "matrix") or std.mem.eql(u8, hn, "quote") or
                    std.mem.eql(u8, hn, "quasiquote"))
                {
                    return try symbolic.copyExpr(expr, env.allocator);
                }
                // (define name value): the name position stays verbatim
                if (std.mem.eql(u8, hn, "define") and lst.items.len >= 3) {
                    try new_list.append(env.allocator, try symbolic.copyExpr(head, env.allocator));
                    try new_list.append(env.allocator, try symbolic.copyExpr(lst.items[1], env.allocator));
                    for (lst.items[2..]) |item| {
                        try new_list.append(env.allocator, try captureFreeVars(item, shadowed, env));
                    }
                    const result = try env.allocator.create(Expr);
                    result.* = .{ .list = new_list };
                    return result;
                }
                // (lambda (p...) body): params shadow the body
                if (std.mem.eql(u8, hn, "lambda") and lst.items.len == 3 and lst.items[1].* == .list) {
                    try new_list.append(env.allocator, try symbolic.copyExpr(head, env.allocator));
                    try new_list.append(env.allocator, try symbolic.copyExpr(lst.items[1], env.allocator));
                    const shadow_base = shadowed.items.len;
                    for (lst.items[1].list.items) |p| {
                        if (p.* == .symbol) try shadowed.append(env.allocator, p.symbol);
                    }
                    const body = try captureFreeVars(lst.items[2], shadowed, env);
                    shadowed.shrinkRetainingCapacity(shadow_base);
                    try new_list.append(env.allocator, body);
                    const result = try env.allocator.create(Expr);
                    result.* = .{ .list = new_list };
                    return result;
                }
                // (let/letrec ((n v)...) body): names shadow the body
                if ((std.mem.eql(u8, hn, "let") or std.mem.eql(u8, hn, "letrec")) and
                    lst.items.len == 3 and lst.items[1].* == .list)
                {
                    const is_letrec = std.mem.eql(u8, hn, "letrec");
                    try new_list.append(env.allocator, try symbolic.copyExpr(head, env.allocator));
                    const shadow_base = shadowed.items.len;
                    if (is_letrec) {
                        for (lst.items[1].list.items) |b| {
                            if (b.* == .list and b.list.items.len == 2 and b.list.items[0].* == .symbol) {
                                try shadowed.append(env.allocator, b.list.items[0].symbol);
                            }
                        }
                    }
                    var bindings: std.ArrayList(*Expr) = .empty;
                    errdefer {
                        for (bindings.items) |item| {
                            item.deinit(env.allocator);
                            env.allocator.destroy(item);
                        }
                        bindings.deinit(env.allocator);
                    }
                    for (lst.items[1].list.items) |b| {
                        if (b.* == .list and b.list.items.len == 2 and b.list.items[0].* == .symbol) {
                            var pair: std.ArrayList(*Expr) = .empty;
                            try pair.append(env.allocator, try symbolic.copyExpr(b.list.items[0], env.allocator));
                            try pair.append(env.allocator, try captureFreeVars(b.list.items[1], shadowed, env));
                            const pair_expr = try env.allocator.create(Expr);
                            pair_expr.* = .{ .list = pair };
                            try bindings.append(env.allocator, pair_expr);
                            if (!is_letrec) try shadowed.append(env.allocator, b.list.items[0].symbol);
                        } else {
                            try bindings.append(env.allocator, try symbolic.copyExpr(b, env.allocator));
                        }
                    }
                    const bindings_expr = try env.allocator.create(Expr);
                    bindings_expr.* = .{ .list = bindings };
                    try new_list.append(env.allocator, bindings_expr);
                    const body = try captureFreeVars(lst.items[2], shadowed, env);
                    shadowed.shrinkRetainingCapacity(shadow_base);
                    try new_list.append(env.allocator, body);
                    const result = try env.allocator.create(Expr);
                    result.* = .{ .list = new_list };
                    return result;
                }
                // (sum/product var start end body): loop var shadows the body
                if ((std.mem.eql(u8, hn, "sum") or std.mem.eql(u8, hn, "product")) and
                    lst.items.len == 5 and lst.items[1].* == .symbol)
                {
                    try new_list.append(env.allocator, try symbolic.copyExpr(head, env.allocator));
                    try new_list.append(env.allocator, try symbolic.copyExpr(lst.items[1], env.allocator));
                    try new_list.append(env.allocator, try captureFreeVars(lst.items[2], shadowed, env));
                    try new_list.append(env.allocator, try captureFreeVars(lst.items[3], shadowed, env));
                    const shadow_base = shadowed.items.len;
                    try shadowed.append(env.allocator, lst.items[1].symbol);
                    const body = try captureFreeVars(lst.items[4], shadowed, env);
                    shadowed.shrinkRetainingCapacity(shadow_base);
                    try new_list.append(env.allocator, body);
                    const result = try env.allocator.create(Expr);
                    result.* = .{ .list = new_list };
                    return result;
                }
            }

            // Default: recurse into every item
            for (lst.items) |item| {
                try new_list.append(env.allocator, try captureFreeVars(item, shadowed, env));
            }
            const result = try env.allocator.create(Expr);
            result.* = .{ .list = new_list };
            return result;
        },
    }
}

/// Evaluates (defmacro (name params...) template): stores a lambda whose
/// body is the unexpanded template.
fn evalDefmacro(expr: *Expr, env: *Env) Error!*Expr {
    if (expr.list.items.len < 3) return Error.InvalidSyntax;
    const sig = expr.list.items[1];
    if (sig.* != .list or sig.list.items.len == 0) return Error.InvalidSyntax;
    if (sig.list.items[0].* != .symbol) return Error.InvalidSyntax;
    const name = sig.list.items[0].symbol;

    var params: std.ArrayList([]const u8) = .empty;
    errdefer params.deinit(env.allocator);
    for (sig.list.items[1..]) |p| {
        if (p.* != .symbol) return Error.InvalidSyntax;
        try params.append(env.allocator, p.symbol);
    }

    var body_storage: ?*Expr = null;
    defer if (body_storage) |b| {
        b.deinit(env.allocator);
        env.allocator.destroy(b);
    };
    const body_src = if (expr.list.items.len == 3)
        expr.list.items[2]
    else blk: {
        const wrapped = try makeImplicitBegin(expr.list.items[2..], env);
        body_storage = wrapped;
        break :blk wrapped;
    };
    const body_copy = try symbolic.copyExpr(body_src, env.allocator);

    const lambda_expr = try env.allocator.create(Expr);
    lambda_expr.* = .{ .lambda = .{ .params = params, .body = body_copy } };
    try env.putMacro(name, lambda_expr);

    const result = try env.allocator.create(Expr);
    result.* = .{ .symbol = "macro-defined" };
    return result;
}

/// Expands a macro call: parameters bind to the UNEVALUATED argument
/// expressions, the template body evaluates to produce the expansion, and
/// the expansion is then evaluated.
fn expandAndEvalMacro(macro: *const Expr, arg_exprs: []*Expr, env: *Env) Error!*Expr {
    const lam = macro.lambda;
    if (arg_exprs.len != lam.params.items.len) return Error.WrongNumberOfArguments;

    var old_values: std.ArrayList(SavedBinding) = .empty;
    defer old_values.deinit(env.allocator);
    errdefer restoreBindings(&old_values, env);

    // Bind parameters to the raw (unevaluated) argument expressions
    for (lam.params.items, arg_exprs) |param, arg| {
        try bindParam(&old_values, env, param, try symbolic.copyExpr(arg, env.allocator));
    }

    // Evaluate the template to build the expansion
    const expansion = try eval(lam.body, env);
    restoreBindings(&old_values, env);
    old_values.clearRetainingCapacity();
    defer {
        expansion.deinit(env.allocator);
        env.allocator.destroy(expansion);
    }

    // Evaluate the expansion in the caller's environment
    return try eval(expansion, env);
}

/// Wraps several body expressions into a synthesized (begin ...) node.
fn makeImplicitBegin(body: []*Expr, env: *Env) Error!*Expr {
    var list: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (list.items) |item| {
            item.deinit(env.allocator);
            env.allocator.destroy(item);
        }
        list.deinit(env.allocator);
    }
    const head = try env.allocator.create(Expr);
    head.* = .{ .symbol = "begin" };
    try list.append(env.allocator, head);
    for (body) |e| {
        try list.append(env.allocator, try symbolic.copyExpr(e, env.allocator));
    }
    const result = try env.allocator.create(Expr);
    result.* = .{ .list = list };
    return result;
}

/// Evaluates (begin e1 e2 ... en): each expression in order, returning en.
fn evalBegin(expr: *Expr, env: *Env) Error!*Expr {
    if (expr.list.items.len < 2) return Error.InvalidSyntax;
    const body = expr.list.items[1..];
    for (body[0 .. body.len - 1]) |e| {
        const v = try eval(e, env);
        v.deinit(env.allocator);
        env.allocator.destroy(v);
    }
    return try eval(body[body.len - 1], env);
}

/// Truthiness shared by if/cond/and/or.
fn isTruthy(v: *const Expr) bool {
    return switch (v.*) {
        .number => |n| n != 0,
        .symbol, .owned_symbol => true,
        .string => |s| s.len > 0,
        .list => |lst| lst.items.len > 0,
        .lambda => true,
    };
}

/// Evaluates (cond (test result...) ... (else result...)).
/// Returns 0 when no clause matches (like if without an else branch).
fn evalCond(expr: *Expr, env: *Env) Error!*Expr {
    if (expr.list.items.len < 2) return Error.InvalidSyntax;
    for (expr.list.items[1..]) |clause| {
        if (clause.* != .list or clause.list.items.len < 2) return Error.InvalidSyntax;
        const test_expr = clause.list.items[0];

        // (else ...) always matches
        const is_else = test_expr.* == .symbol and std.mem.eql(u8, test_expr.symbol, "else");
        if (!is_else) {
            const cond_val = try eval(test_expr, env);
            const truthy = isTruthy(cond_val);
            cond_val.deinit(env.allocator);
            env.allocator.destroy(cond_val);
            if (!truthy) continue;
        }

        // Matched: evaluate the clause body as an implicit begin
        const body = clause.list.items[1..];
        for (body[0 .. body.len - 1]) |e| {
            const v = try eval(e, env);
            v.deinit(env.allocator);
            env.allocator.destroy(v);
        }
        return try eval(body[body.len - 1], env);
    }
    const result = try env.allocator.create(Expr);
    result.* = .{ .number = 0 };
    return result;
}

/// Short-circuit (and ...) / (or ...): arguments evaluate left to right and
/// evaluation stops at the deciding value. Symbolic arguments keep the whole
/// form inert (CAS behavior), so (and p q) stays (and p q).
fn evalAndOr(expr: *Expr, env: *Env, comptime is_and: bool) Error!*Expr {
    for (expr.list.items[1..]) |arg| {
        const v = try eval(arg, env);
        defer {
            v.deinit(env.allocator);
            env.allocator.destroy(v);
        }

        // Undecidable symbolic value: return the form unevaluated
        const symbolic_value = switch (v.*) {
            .symbol, .owned_symbol => true,
            .list => |lst| lst.items.len > 0 and lst.items[0].* == .symbol and
                (std.mem.eql(u8, lst.items[0].symbol, "<") or
                    std.mem.eql(u8, lst.items[0].symbol, ">") or
                    std.mem.eql(u8, lst.items[0].symbol, "and") or
                    std.mem.eql(u8, lst.items[0].symbol, "or") or
                    std.mem.eql(u8, lst.items[0].symbol, "not")),
            else => false,
        };
        if (symbolic_value) {
            return try symbolic.copyExpr(expr, env.allocator);
        }

        const truthy = isTruthy(v);
        if (is_and and !truthy) {
            const result = try env.allocator.create(Expr);
            result.* = .{ .number = 0 };
            return result;
        }
        if (!is_and and truthy) {
            const result = try env.allocator.create(Expr);
            result.* = .{ .number = 1 };
            return result;
        }
    }
    const result = try env.allocator.create(Expr);
    result.* = .{ .number = if (is_and) 1 else 0 };
    return result;
}

/// Walks a quasiquoted template, copying everything verbatim except
/// (unquote x) forms, which evaluate in the current environment.
fn evalQuasiquote(expr: *Expr, env: *Env) Error!*Expr {
    if (expr.* == .list and expr.list.items.len == 2 and
        expr.list.items[0].* == .symbol and
        std.mem.eql(u8, expr.list.items[0].symbol, "unquote"))
    {
        return try eval(expr.list.items[1], env);
    }
    if (expr.* == .list) {
        var new_list: std.ArrayList(*Expr) = .empty;
        errdefer {
            for (new_list.items) |item| {
                item.deinit(env.allocator);
                env.allocator.destroy(item);
            }
            new_list.deinit(env.allocator);
        }
        for (expr.list.items) |item| {
            try new_list.append(env.allocator, try evalQuasiquote(item, env));
        }
        const result = try env.allocator.create(Expr);
        result.* = .{ .list = new_list };
        return result;
    }
    return try symbolic.copyExpr(expr, env.allocator);
}

/// Evaluates (dsolve equation y x). Special form: the equation is passed
/// through unevaluated so (diff y x) is preserved structurally.
fn evalDsolve(expr: *Expr, env: *Env) Error!*Expr {
    if (expr.list.items.len != 4) return Error.InvalidSyntax;

    const func = env.getBuiltin("dsolve") catch {
        return try symbolic.copyExpr(expr, env.allocator);
    };

    var args: std.ArrayList(*Expr) = .empty;
    defer {
        for (args.items) |arg| {
            arg.deinit(env.allocator);
            env.allocator.destroy(arg);
        }
        args.deinit(env.allocator);
    }
    for (expr.list.items[1..]) |arg| {
        try args.append(env.allocator, try symbolic.copyExpr(arg, env.allocator));
    }
    return try func(args, env);
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

        // Body is the rest of the define (several expressions form an
        // implicit begin); capture free variables by value (params and the
        // function's own name stay symbolic for recursion)
        var shadowed: std.ArrayList([]const u8) = .empty;
        defer shadowed.deinit(env.allocator);
        try shadowed.appendSlice(env.allocator, params.items);
        try shadowed.append(env.allocator, func_name);
        try collectDefinedNames(expr.list.items[2], &shadowed, env.allocator);
        if (expr.list.items.len > 3) {
            for (expr.list.items[3..]) |e| {
                try collectDefinedNames(e, &shadowed, env.allocator);
            }
        }

        var body_storage: ?*Expr = null;
        defer if (body_storage) |b| {
            b.deinit(env.allocator);
            env.allocator.destroy(b);
        };
        const body_src = if (expr.list.items.len == 3)
            expr.list.items[2]
        else blk: {
            const wrapped = try makeImplicitBegin(expr.list.items[2..], env);
            body_storage = wrapped;
            break :blk wrapped;
        };
        const body_copy = try captureFreeVars(body_src, &shadowed, env);

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
        return Error.InvalidSyntax;
    }

    const cond = try eval(expr.list.items[1], env);
    defer {
        cond.deinit(env.allocator);
        env.allocator.destroy(cond);
    }

    // A condition that stayed a symbolic comparison (e.g. (> x 0) with
    // symbolic x) can't be decided: return the whole if-expression inert
    if (cond.* == .list and cond.list.items.len > 0 and cond.list.items[0].* == .symbol) {
        const op = cond.list.items[0].symbol;
        if (std.mem.eql(u8, op, "<") or std.mem.eql(u8, op, ">") or std.mem.eql(u8, op, "=")) {
            var result_list: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (result_list.items) |item| {
                    item.deinit(env.allocator);
                    env.allocator.destroy(item);
                }
                result_list.deinit(env.allocator);
            }
            const if_sym = try env.allocator.create(Expr);
            if_sym.* = .{ .symbol = "if" };
            try result_list.append(env.allocator, if_sym);
            try result_list.append(env.allocator, try symbolic.copyExpr(cond, env.allocator));
            for (expr.list.items[2..]) |branch| {
                try result_list.append(env.allocator, try symbolic.copyExpr(branch, env.allocator));
            }
            const result = try env.allocator.create(Expr);
            result.* = .{ .list = result_list };
            return result;
        }
    }

    // Truthy: anything that's not 0 or empty list
    const is_truthy = switch (cond.*) {
        .number => |n| n != 0,
        .symbol, .owned_symbol => true,
        .string => |s| s.len > 0,
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
    if (expr.list.items.len != 3) return Error.InvalidSyntax;

    const bindings = expr.list.items[1];
    const body = expr.list.items[2];

    if (bindings.* != .list) return Error.InvalidSyntax;

    // Save old values and set new ones
    var old_values: std.ArrayList(SavedBinding) = .empty;
    defer old_values.deinit(env.allocator);

    // Evaluate and bind all variables
    for (bindings.list.items) |binding| {
        if (binding.* != .list or binding.list.items.len != 2) return Error.InvalidSyntax;
        if (binding.list.items[0].* != .symbol) return Error.InvalidSyntax;

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
                _ = env.remove(item.name);
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
            _ = env.remove(item.name);
        }
    }

    return result;
}

/// Evaluates (letrec ((var val) ...) body) - allows recursive bindings
fn evalLetrec(expr: *Expr, env: *Env) Error!*Expr {
    // (letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))) (fact 5))
    if (expr.list.items.len != 3) return Error.InvalidSyntax;

    const bindings = expr.list.items[1];
    const body = expr.list.items[2];

    if (bindings.* != .list) return Error.InvalidSyntax;

    // Save old values
    var old_values: std.ArrayList(SavedBinding) = .empty;
    defer old_values.deinit(env.allocator);

    // First pass: bind all names to placeholders (allows mutual recursion)
    for (bindings.list.items) |binding| {
        if (binding.* != .list or binding.list.items.len != 2) return Error.InvalidSyntax;
        if (binding.list.items[0].* != .symbol) return Error.InvalidSyntax;

        const var_name = binding.list.items[0].symbol;

        // Save old value if it exists
        const old_val = env.get(var_name) catch null;
        try old_values.append(env.allocator, .{ .name = var_name, .value = old_val });

        // Create a self-referential placeholder (the symbol itself) so that
        // closure capture leaves recursive references symbolic
        const placeholder = try env.allocator.create(Expr);
        placeholder.* = .{ .symbol = var_name };
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
                _ = env.remove(item.name);
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
            _ = env.remove(item.name);
        }
    }

    return result;
}

/// Calls a lambda with given arguments
fn callLambda(lambda: *const Expr, arg_exprs: []*Expr, env: *Env) Error!*Expr {
    // Evaluate the initial arguments
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

    // Trampoline state: tail calls to lambdas swap `current` and loop
    // instead of recursing, so tail recursion runs in constant stack space.
    var lambda_storage: ?*Expr = null;
    defer if (lambda_storage) |l| {
        l.deinit(env.allocator);
        env.allocator.destroy(l);
    };
    var current: *const Expr = lambda;

    // Bindings saved across all iterations; first save per name wins
    var old_values: std.ArrayList(SavedBinding) = .empty;
    defer old_values.deinit(env.allocator);
    errdefer restoreBindings(&old_values, env);

    const result = trampoline: while (true) {
        const lam = current.lambda;

        const is_variadic = lam.params.items.len >= 2 and
            std.mem.eql(u8, lam.params.items[lam.params.items.len - 2], ".");
        const fixed_count = if (is_variadic) lam.params.items.len - 2 else lam.params.items.len;

        if (is_variadic) {
            if (args.items.len < fixed_count) return Error.WrongNumberOfArguments;
        } else if (args.items.len != fixed_count) {
            return Error.WrongNumberOfArguments;
        }

        // Bind fixed parameters
        for (lam.params.items[0..fixed_count], args.items[0..fixed_count]) |param, arg| {
            try bindParam(&old_values, env, param, try symbolic.copyExpr(arg, env.allocator));
        }

        // Bind the rest parameter to a (list ...) of the remaining arguments
        if (is_variadic) {
            const rest_name = lam.params.items[lam.params.items.len - 1];
            var rest_list: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (rest_list.items) |item| {
                    item.deinit(env.allocator);
                    env.allocator.destroy(item);
                }
                rest_list.deinit(env.allocator);
            }
            const list_sym = try env.allocator.create(Expr);
            list_sym.* = .{ .symbol = "list" };
            try rest_list.append(env.allocator, list_sym);
            for (args.items[fixed_count..]) |arg| {
                try rest_list.append(env.allocator, try symbolic.copyExpr(arg, env.allocator));
            }
            const rest_expr = try env.allocator.create(Expr);
            rest_expr.* = .{ .list = rest_list };
            try bindParam(&old_values, env, rest_name, rest_expr);
        }

        // Descend to the tail expression through if/begin/cond
        var body: *Expr = lam.body;
        descend: while (body.* == .list and body.list.items.len > 0 and body.list.items[0].* == .symbol) {
            const op = body.list.items[0].symbol;
            if (std.mem.eql(u8, op, "if") and (body.list.items.len == 3 or body.list.items.len == 4)) {
                const cond = try eval(body.list.items[1], env);
                defer {
                    cond.deinit(env.allocator);
                    env.allocator.destroy(cond);
                }
                // Undecidable symbolic conditions fall back to plain eval
                if (cond.* == .list and cond.list.items.len > 0 and cond.list.items[0].* == .symbol) {
                    const cop = cond.list.items[0].symbol;
                    if (std.mem.eql(u8, cop, "<") or std.mem.eql(u8, cop, ">") or std.mem.eql(u8, cop, "=")) {
                        break :descend;
                    }
                }
                if (isTruthy(cond)) {
                    body = body.list.items[2];
                } else if (body.list.items.len == 4) {
                    body = body.list.items[3];
                } else {
                    const zero = try env.allocator.create(Expr);
                    zero.* = .{ .number = 0 };
                    break :trampoline zero;
                }
                continue :descend;
            }
            if (std.mem.eql(u8, op, "begin") and body.list.items.len >= 2) {
                const inner = body.list.items[1..];
                for (inner[0 .. inner.len - 1]) |e| {
                    const v = try eval(e, env);
                    v.deinit(env.allocator);
                    env.allocator.destroy(v);
                }
                body = inner[inner.len - 1];
                continue :descend;
            }
            if (std.mem.eql(u8, op, "cond") and body.list.items.len >= 2) {
                var matched: ?*Expr = null;
                for (body.list.items[1..]) |clause| {
                    if (clause.* != .list or clause.list.items.len < 2) return Error.InvalidSyntax;
                    const test_expr = clause.list.items[0];
                    const is_else = test_expr.* == .symbol and std.mem.eql(u8, test_expr.symbol, "else");
                    if (!is_else) {
                        const cv = try eval(test_expr, env);
                        const truthy = isTruthy(cv);
                        cv.deinit(env.allocator);
                        env.allocator.destroy(cv);
                        if (!truthy) continue;
                    }
                    const cbody = clause.list.items[1..];
                    for (cbody[0 .. cbody.len - 1]) |e| {
                        const v = try eval(e, env);
                        v.deinit(env.allocator);
                        env.allocator.destroy(v);
                    }
                    matched = cbody[cbody.len - 1];
                    break;
                }
                if (matched) |m| {
                    body = m;
                    continue :descend;
                }
                const zero = try env.allocator.create(Expr);
                zero.* = .{ .number = 0 };
                break :trampoline zero;
            }
            break :descend;
        }

        // Is the tail expression a call to a lambda? Then loop instead of
        // recursing (proper tail calls).
        if (body.* == .list and body.list.items.len > 0 and !isSpecialFormHead(body.list.items[0])) {
            const evaled_op = try eval(body.list.items[0], env);
            if (evaled_op.* == .lambda) {
                // Evaluate the new arguments with the current bindings
                var new_args: std.ArrayList(*Expr) = .empty;
                errdefer {
                    for (new_args.items) |arg| {
                        arg.deinit(env.allocator);
                        env.allocator.destroy(arg);
                    }
                    new_args.deinit(env.allocator);
                    evaled_op.deinit(env.allocator);
                    env.allocator.destroy(evaled_op);
                }
                for (body.list.items[1..]) |arg_expr| {
                    try new_args.append(env.allocator, try eval(arg_expr, env));
                }

                // Swap in the new frame
                for (args.items) |arg| {
                    arg.deinit(env.allocator);
                    env.allocator.destroy(arg);
                }
                args.deinit(env.allocator);
                args = new_args;

                if (lambda_storage) |l| {
                    l.deinit(env.allocator);
                    env.allocator.destroy(l);
                }
                lambda_storage = evaled_op;
                current = evaled_op;
                continue :trampoline;
            }
            evaled_op.deinit(env.allocator);
            env.allocator.destroy(evaled_op);
        }

        // Not a tail call: evaluate normally and finish
        break :trampoline try eval(body, env);
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

/// Binds a parameter, saving the outer value the first time a name is
/// bound in this call frame and freeing our own previous value after that.
fn bindParam(old_values: *std.ArrayList(SavedBinding), env: *Env, name: []const u8, value: *Expr) Error!void {
    var already_saved = false;
    for (old_values.items) |item| {
        if (std.mem.eql(u8, item.name, name)) {
            already_saved = true;
            break;
        }
    }
    if (already_saved) {
        // The current binding is ours from a previous trampoline iteration
        if (env.get(name)) |cur| {
            cur.deinit(env.allocator);
            env.allocator.destroy(cur);
        } else |_| {}
    } else {
        const old_val = env.get(name) catch null;
        try old_values.append(env.allocator, .{ .name = name, .value = old_val });
    }
    try env.put(name, value);
}

/// True when the head symbol names a special form (which is never a
/// tail-callable function).
fn isSpecialFormHead(head: *const Expr) bool {
    if (head.* != .symbol) return false;
    const names = [_][]const u8{
        "lambda", "define", "defmacro", "if", "let", "letrec", "matrix", "sum",
        "product", "solve",     "dsolve", "quote", "quasiquote", "unquote",
        "begin",  "cond",       "and",   "or",    "try",
    };
    for (names) |n| {
        if (std.mem.eql(u8, head.symbol, n)) return true;
    }
    return false;
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
        if (row.* != .list) return Error.InvalidSyntax; // Rows must be lists

        // Check rectangular
        if (cols == null) {
            cols = row.list.items.len;
        } else if (row.list.items.len != cols.?) {
            return Error.InvalidSyntax; // Non-rectangular
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
    if (expr.list.items.len != 5) return Error.InvalidSyntax;

    const var_expr = expr.list.items[1];
    const start_expr = expr.list.items[2];
    const end_expr = expr.list.items[3];
    const body_expr = expr.list.items[4];

    if (var_expr.* != .symbol) return Error.InvalidSyntax;
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
        const start_int = boundToInt(start_val.number) orelse return Error.InvalidArgument;
        const end_int = boundToInt(end_val.number) orelse return Error.InvalidArgument;
        if (end_int - start_int >= MAX_LOOP_ITERATIONS) return Error.RecursionLimit;

        if (start_int > end_int) {
            // Empty sum
            const result = try env.allocator.create(Expr);
            result.* = .{ .number = 0 };
            return result;
        }

        // Save old binding
        const old_val = env.get(var_name) catch null;

        // Compute sum: numeric terms fold into an accumulator so large
        // ranges don't build a deep expression tree (which is slow and can
        // exhaust the stack on teardown); only symbolic terms are chained.
        var numeric_acc: f64 = 0;
        var has_numeric = false;
        var sum_result: ?*Expr = null;
        errdefer if (sum_result) |acc| {
            acc.deinit(env.allocator);
            env.allocator.destroy(acc);
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

            if (term.* == .number) {
                numeric_acc += term.number;
                has_numeric = true;
                term.deinit(env.allocator);
                env.allocator.destroy(term);
            } else if (sum_result) |acc| {
                const new_acc = try symbolic.makeBinOp(env.allocator, "+", acc, term);
                sum_result = new_acc;
            } else {
                sum_result = term;
            }
        }

        // Fold the numeric accumulator into the result
        if (has_numeric) {
            const acc_expr = try env.allocator.create(Expr);
            acc_expr.* = .{ .number = numeric_acc };
            if (sum_result) |acc| {
                sum_result = try symbolic.makeBinOp(env.allocator, "+", acc, acc_expr);
            } else {
                sum_result = acc_expr;
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
            _ = env.remove(var_name);
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

    // Symbolic bounds: try a closed form (Faulhaber / geometric) first
    if (try closedFormSum(var_name, start_val, end_val, body_expr, env)) |closed| {
        return closed;
    }

    // Otherwise return as symbolic sum expression
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
    if (expr.list.items.len != 5) return Error.InvalidSyntax;

    const var_expr = expr.list.items[1];
    const start_expr = expr.list.items[2];
    const end_expr = expr.list.items[3];
    const body_expr = expr.list.items[4];

    if (var_expr.* != .symbol) return Error.InvalidSyntax;
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
        const start_int = boundToInt(start_val.number) orelse return Error.InvalidArgument;
        const end_int = boundToInt(end_val.number) orelse return Error.InvalidArgument;
        if (end_int - start_int >= MAX_LOOP_ITERATIONS) return Error.RecursionLimit;

        if (start_int > end_int) {
            // Empty product
            const result = try env.allocator.create(Expr);
            result.* = .{ .number = 1 };
            return result;
        }

        // Save old binding
        const old_val = env.get(var_name) catch null;

        // Compute product: numeric terms fold into an accumulator so large
        // ranges don't build a deep expression tree (which is slow and can
        // exhaust the stack on teardown); only symbolic terms are chained.
        var numeric_acc: f64 = 1;
        var has_numeric = false;
        var product_result: ?*Expr = null;
        errdefer if (product_result) |acc| {
            acc.deinit(env.allocator);
            env.allocator.destroy(acc);
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

            if (term.* == .number) {
                numeric_acc *= term.number;
                has_numeric = true;
                term.deinit(env.allocator);
                env.allocator.destroy(term);
            } else if (product_result) |acc| {
                const new_acc = try symbolic.makeBinOp(env.allocator, "*", acc, term);
                product_result = new_acc;
            } else {
                product_result = term;
            }
        }

        // Fold the numeric accumulator into the result
        if (has_numeric) {
            const acc_expr = try env.allocator.create(Expr);
            acc_expr.* = .{ .number = numeric_acc };
            if (product_result) |acc| {
                product_result = try symbolic.makeBinOp(env.allocator, "*", acc, acc_expr);
            } else {
                product_result = acc_expr;
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
            _ = env.remove(var_name);
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
    if (expr.list.items.len != 3) return Error.InvalidSyntax;

    const eq_expr = expr.list.items[1];
    const var_expr = expr.list.items[2];

    if (var_expr.* != .symbol) return Error.InvalidSyntax;
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

/// Converts a numeric loop bound to an integer, rejecting non-integers
/// and values outside the exactly-representable f64 integer range.
fn boundToInt(n: f64) ?i64 {
    if (n != @floor(n)) return null;
    if (n > 9.0e15 or n < -9.0e15) return null;
    return @intFromFloat(n);
}

/// Closed forms for symbolic-bound sums: polynomial bodies up to degree 3
/// (Faulhaber) and geometric bodies r^i with constant r. Currently requires
/// the lower bound to be the literal 1 (the common case, e.g. (sum i 1 n ...)).
fn closedFormSum(var_name: []const u8, start_val: *Expr, end_val: *Expr, body: *Expr, env: *Env) Error!?*Expr {
    // Lower bound must be exactly 1
    if (start_val.* != .number or start_val.number != 1) return null;

    const a = env.allocator;

    // Helper: builds an expression from a template string via substitution
    // is overkill; construct directly instead.
    const n_expr = end_val; // upper bound expression (copied when used)

    // Polynomial body: collect numeric coefficients c0 + c1 i + c2 i^2 + c3 i^3
    if (symbolic.getPolyCoeffsFor(body, var_name, env.allocator)) |coeffs_opt| {
        if (coeffs_opt) |coeffs| {
            defer env.allocator.free(coeffs);
            if (coeffs.len <= 4) {
                // Faulhaber:
                //   sum 1        = n
                //   sum i        = n(n+1)/2
                //   sum i^2      = n(n+1)(2n+1)/6
                //   sum i^3      = n^2 (n+1)^2 / 4
                var total: ?*Expr = null;
                errdefer if (total) |t| {
                    t.deinit(a);
                    a.destroy(t);
                };
                for (coeffs, 0..) |c, k| {
                    if (c == 0) continue;
                    const n1 = try symbolic.copyExpr(n_expr, a);
                    var term: *Expr = undefined;
                    switch (k) {
                        0 => term = n1,
                        1 => {
                            // n(n+1)/2
                            const n2 = try symbolic.copyExpr(n_expr, a);
                            const one = try a.create(Expr);
                            one.* = .{ .number = 1 };
                            const np1 = try symbolic.makeBinOp(a, "+", n2, one);
                            const prod = try symbolic.makeBinOp(a, "*", n1, np1);
                            const two = try a.create(Expr);
                            two.* = .{ .number = 2 };
                            term = try symbolic.makeBinOp(a, "/", prod, two);
                        },
                        2 => {
                            // n(n+1)(2n+1)/6
                            const n2 = try symbolic.copyExpr(n_expr, a);
                            const one = try a.create(Expr);
                            one.* = .{ .number = 1 };
                            const np1 = try symbolic.makeBinOp(a, "+", n2, one);
                            const n3 = try symbolic.copyExpr(n_expr, a);
                            const two = try a.create(Expr);
                            two.* = .{ .number = 2 };
                            const twon = try symbolic.makeBinOp(a, "*", two, n3);
                            const one2 = try a.create(Expr);
                            one2.* = .{ .number = 1 };
                            const twonp1 = try symbolic.makeBinOp(a, "+", twon, one2);
                            const p1 = try symbolic.makeBinOp(a, "*", n1, np1);
                            const p2 = try symbolic.makeBinOp(a, "*", p1, twonp1);
                            const six = try a.create(Expr);
                            six.* = .{ .number = 6 };
                            term = try symbolic.makeBinOp(a, "/", p2, six);
                        },
                        3 => {
                            // n^2 (n+1)^2 / 4
                            const two = try a.create(Expr);
                            two.* = .{ .number = 2 };
                            const nsq = try symbolic.makeBinOp(a, "^", n1, two);
                            const n2 = try symbolic.copyExpr(n_expr, a);
                            const one = try a.create(Expr);
                            one.* = .{ .number = 1 };
                            const np1 = try symbolic.makeBinOp(a, "+", n2, one);
                            const two2 = try a.create(Expr);
                            two2.* = .{ .number = 2 };
                            const np1sq = try symbolic.makeBinOp(a, "^", np1, two2);
                            const prod = try symbolic.makeBinOp(a, "*", nsq, np1sq);
                            const four = try a.create(Expr);
                            four.* = .{ .number = 4 };
                            term = try symbolic.makeBinOp(a, "/", prod, four);
                        },
                        else => {
                            n1.deinit(a);
                            a.destroy(n1);
                            return null;
                        },
                    }
                    if (c != 1) {
                        const c_expr = try a.create(Expr);
                        c_expr.* = .{ .number = c };
                        term = try symbolic.makeBinOp(a, "*", c_expr, term);
                    }
                    if (total) |t| {
                        total = try symbolic.makeBinOp(a, "+", t, term);
                    } else {
                        total = term;
                    }
                }
                if (total) |t| {
                    const simplified = try symbolic.simplify(t, a);
                    t.deinit(a);
                    a.destroy(t);
                    return simplified;
                }
                // All-zero polynomial
                const zero = try a.create(Expr);
                zero.* = .{ .number = 0 };
                return zero;
            }
        }
    } else |_| {}

    // Geometric body: r^i with constant r => (r^(n+1) - r) / (r - 1)
    if (body.* == .list and body.list.items.len == 3 and
        body.list.items[0].* == .symbol and std.mem.eql(u8, body.list.items[0].symbol, "^"))
    {
        const base = body.list.items[1];
        const expo = body.list.items[2];
        const expo_is_var = expo.* == .symbol and std.mem.eql(u8, expo.symbol, var_name);
        if (expo_is_var and !symbolic.containsVariable(base, var_name) and base.* == .number and base.number != 1) {
            const r1 = try symbolic.copyExpr(base, a);
            const n1 = try symbolic.copyExpr(n_expr, a);
            const one = try a.create(Expr);
            one.* = .{ .number = 1 };
            const np1 = try symbolic.makeBinOp(a, "+", n1, one);
            const r_pow = try symbolic.makeBinOp(a, "^", r1, np1);
            const r2 = try symbolic.copyExpr(base, a);
            const numer = try symbolic.makeBinOp(a, "-", r_pow, r2);
            const r3 = try symbolic.copyExpr(base, a);
            const one2 = try a.create(Expr);
            one2.* = .{ .number = 1 };
            const denom = try symbolic.makeBinOp(a, "-", r3, one2);
            const quotient = try symbolic.makeBinOp(a, "/", numer, denom);
            const simplified = try symbolic.simplify(quotient, a);
            quotient.deinit(a);
            a.destroy(quotient);
            return simplified;
        }
    }

    return null;
}

threadlocal var trace_depth: usize = 0;

/// Wraps callLambda with call/return tracing output for (trace name).
fn callLambdaTraced(name: []const u8, lambda: *const Expr, arg_exprs: []*Expr, env: *Env) Error!*Expr {
    if (env.out) |out| {
        var d: usize = 0;
        while (d < trace_depth) : (d += 1) out.writeAll("  ") catch {};
        out.print("({s}", .{name}) catch {};
        // Show the argument expressions as written (evaluating them here
        // would run side effects twice)
        for (arg_exprs) |arg| {
            out.writeAll(" ") catch {};
            @import("builtins.zig").writeExprPlain(arg, out);
        }
        out.writeAll(")\n") catch {};
        out.flush() catch {};
    }
    trace_depth += 1;
    const result = callLambda(lambda, arg_exprs, env) catch |err| {
        trace_depth -= 1;
        return err;
    };
    trace_depth -= 1;
    if (env.out) |out| {
        var d: usize = 0;
        while (d < trace_depth) : (d += 1) out.writeAll("  ") catch {};
        out.print("{s} => ", .{name}) catch {};
        @import("builtins.zig").writeExprPlain(result, out);
        out.writeAll("\n") catch {};
        out.flush() catch {};
    }
    return result;
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
            _ = env.remove(item.name);
        }
    }
}
