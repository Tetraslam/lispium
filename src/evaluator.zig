const std = @import("std");
const Expr = @import("parser.zig").Expr;
const Env = @import("environment.zig").Env;
const BuiltinError = @import("builtins.zig").BuiltinError;
const EnvError = @import("environment.zig").Error;
const symbolic = @import("symbolic.zig");

pub const Error = error{
    UnsupportedOperator,
    OutOfMemory,
} || BuiltinError || EnvError || symbolic.SimplifyError;

pub fn eval(expr: *Expr, env: *Env) Error!*Expr {
    switch (expr.*) {
        .number => {
            // Return a copy to ensure the result has independent ownership
            return try symbolic.copyExpr(expr, env.allocator);
        },
        .symbol => {
            // Try to get a value from the environment, but if not found,
            // treat it as a symbolic variable
            if (env.get(expr.symbol)) |val| {
                return try symbolic.copyExpr(val, env.allocator);
            } else |_| {
                return try symbolic.copyExpr(expr, env.allocator);
            }
        },
        .list => {
            if (expr.list.items.len == 0) {
                return try symbolic.copyExpr(expr, env.allocator);
            }
            // Evaluate operator.
            const op_expr = expr.list.items[0];
            if (op_expr.* != .symbol) {
                return Error.UnsupportedOperator;
            }
            const func = try env.getBuiltin(op_expr.symbol);
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
