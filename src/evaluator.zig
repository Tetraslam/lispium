const std = @import("std");
const Expr = @import("parser.zig").Expr;
const Env = @import("environment.zig").Env;
const BuiltinError = @import("builtins.zig").BuiltinError;
const EnvError = @import("environment.zig").Error;

pub const Error = error{
    UnsupportedOperator,
    OutOfMemory,
} || BuiltinError || EnvError;

pub fn eval(expr: *Expr, env: *Env) Error!*Expr {
    switch (expr.*) {
        .number => return expr,
        .symbol => {
            // Try to get a value from the environment, but if not found,
            // treat it as a symbolic variable
            if (env.get(expr.symbol)) |val| {
                return val;
            } else |_| {
                return expr;
            }
        },
        .list => {
            if (expr.list.items.len == 0) {
                return expr; // empty list returns itself
            }
            // Evaluate operator.
            const op_expr = expr.list.items[0];
            if (op_expr.* != .symbol) {
                return Error.UnsupportedOperator;
            }
            const func = try env.getBuiltin(op_expr.symbol);
            // Evaluate arguments.
            var args = std.ArrayList(*Expr).init(env.allocator.*);
            defer args.deinit();
            for (expr.list.items[1..]) |arg| {
                try args.append(try eval(arg, env));
            }
            return try func(args, env);
        },
    }
}
