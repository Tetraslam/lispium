const std = @import("std");
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const Parser = @import("../parser.zig").Parser;
pub const Expr = @import("../parser.zig").Expr;
pub const eval = @import("../evaluator.zig").eval;
pub const Env = @import("../environment.zig").Env;
pub const builtins = @import("../builtins.zig");
pub const symbolic = @import("../symbolic.zig");

pub fn parseExpr(allocator: std.mem.Allocator, input: []const u8) !*Expr {
    var tokenizer = Tokenizer.init(input);
    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);

    while (tokenizer.next()) |tok| {
        try tokens.append(allocator, tok);
    }

    var parser = Parser.init(allocator, tokens);
    return parser.parseExpr();
}

pub fn exprToString(allocator: std.mem.Allocator, expr: *const Expr) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try writeExpr(expr, result.writer(allocator));
    return result.toOwnedSlice(allocator);
}

pub fn writeExpr(expr: *const Expr, writer: anytype) !void {
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
            try writeExpr(lam.body, writer);
            try writer.print(")", .{});
        },
        .list => |lst| {
            if (lst.items.len > 0) {
                try writer.print("(", .{});
                try writeExpr(lst.items[0], writer);
                for (lst.items[1..]) |item| {
                    try writer.print(" ", .{});
                    try writeExpr(item, writer);
                }
                try writer.print(")", .{});
            } else {
                try writer.print("()", .{});
            }
        },
    }
}

pub fn setupEnv(allocator: std.mem.Allocator) !Env {
    var env = Env.init(allocator);
    try env.putBuiltin("+", builtins.builtin_add);
    try env.putBuiltin("-", builtins.builtin_subtract);
    try env.putBuiltin("*", builtins.builtin_multiply);
    try env.putBuiltin("/", builtins.builtin_divide);
    try env.putBuiltin("^", builtins.builtin_power);
    try env.putBuiltin("pow", builtins.builtin_power);
    try env.putBuiltin("=", builtins.builtin_eq);
    try env.putBuiltin("<", builtins.builtin_lt);
    try env.putBuiltin(">", builtins.builtin_gt);
    try env.putBuiltin("mod", builtins.builtin_mod);
    try env.putBuiltin("gcd", builtins.builtin_gcd);
    try env.putBuiltin("lcm", builtins.builtin_lcm);
    try env.putBuiltin("modpow", builtins.builtin_modpow);
    try env.putBuiltin("simplify", builtins.builtin_simplify);
    try env.putBuiltin("diff", builtins.builtin_diff);
    try env.putBuiltin("integrate", builtins.builtin_integrate);
    try env.putBuiltin("expand", builtins.builtin_expand);
    try env.putBuiltin("sin", builtins.builtin_sin);
    try env.putBuiltin("cos", builtins.builtin_cos);
    try env.putBuiltin("tan", builtins.builtin_tan);
    try env.putBuiltin("exp", builtins.builtin_exp);
    try env.putBuiltin("ln", builtins.builtin_ln);
    try env.putBuiltin("log", builtins.builtin_log);
    try env.putBuiltin("sqrt", builtins.builtin_sqrt);
    try env.putBuiltin("substitute", builtins.builtin_substitute);
    try env.putBuiltin("taylor", builtins.builtin_taylor);
    try env.putBuiltin("solve", builtins.builtin_solve);
    try env.putBuiltin("factor", builtins.builtin_factor);
    try env.putBuiltin("partial-fractions", builtins.builtin_partial_fractions);
    try env.putBuiltin("collect", builtins.builtin_collect);
    try env.putBuiltin("complex", builtins.builtin_complex);
    try env.putBuiltin("real", builtins.builtin_real);
    try env.putBuiltin("imag", builtins.builtin_imag);
    try env.putBuiltin("conj", builtins.builtin_conj);
    try env.putBuiltin("magnitude", builtins.builtin_abs_complex);
    try env.putBuiltin("arg", builtins.builtin_arg);
    try env.putBuiltin("limit", builtins.builtin_limit);
    try env.putBuiltin("rule", builtins.builtin_rule);
    try env.putBuiltin("rewrite", builtins.builtin_rewrite);
    try env.putBuiltin("matrix", builtins.builtin_matrix);
    try env.putBuiltin("det", builtins.builtin_det);
    try env.putBuiltin("transpose", builtins.builtin_transpose);
    try env.putBuiltin("trace", builtins.builtin_trace);
    try env.putBuiltin("matmul", builtins.builtin_matmul);
    try env.putBuiltin("inv", builtins.builtin_inv);
    try env.putBuiltin("eigenvalues", builtins.builtin_eigenvalues);
    try env.putBuiltin("eigenvectors", builtins.builtin_eigenvectors);
    try env.putBuiltin("vector", builtins.builtin_vector);
    try env.putBuiltin("dot", builtins.builtin_dot);
    try env.putBuiltin("cross", builtins.builtin_cross);
    try env.putBuiltin("norm", builtins.builtin_norm);
    try env.putBuiltin("and", builtins.builtin_and);
    try env.putBuiltin("or", builtins.builtin_or);
    try env.putBuiltin("not", builtins.builtin_not);
    try env.putBuiltin("xor", builtins.builtin_xor);
    try env.putBuiltin("implies", builtins.builtin_implies);
    try env.putBuiltin("coeffs", builtins.builtin_coeffs);
    try env.putBuiltin("polydiv", builtins.builtin_polydiv);
    try env.putBuiltin("polygcd", builtins.builtin_polygcd);
    try env.putBuiltin("polylcm", builtins.builtin_polylcm);
    try env.putBuiltin("linsolve", builtins.builtin_linsolve);
    try env.putBuiltin("assume", builtins.builtin_assume);
    try env.putBuiltin("is?", builtins.builtin_is);
    // Combinatorics
    try env.putBuiltin("factorial", builtins.builtin_factorial);
    try env.putBuiltin("!", builtins.builtin_factorial);
    try env.putBuiltin("binomial", builtins.builtin_binomial);
    try env.putBuiltin("choose", builtins.builtin_binomial);
    try env.putBuiltin("permutations", builtins.builtin_permutations);
    try env.putBuiltin("combinations", builtins.builtin_combinations);
    // Number theory
    try env.putBuiltin("prime?", builtins.builtin_prime);
    try env.putBuiltin("factorize", builtins.builtin_factorize);
    try env.putBuiltin("extgcd", builtins.builtin_extgcd);
    try env.putBuiltin("totient", builtins.builtin_totient);
    try env.putBuiltin("crt", builtins.builtin_crt);
    // Vector calculus
    try env.putBuiltin("gradient", builtins.builtin_gradient);
    try env.putBuiltin("grad", builtins.builtin_gradient);
    try env.putBuiltin("divergence", builtins.builtin_divergence);
    try env.putBuiltin("curl", builtins.builtin_curl);
    try env.putBuiltin("laplacian", builtins.builtin_laplacian);
    // Statistics
    try env.putBuiltin("mean", builtins.builtin_mean);
    try env.putBuiltin("variance", builtins.builtin_variance);
    try env.putBuiltin("stddev", builtins.builtin_stddev);
    try env.putBuiltin("median", builtins.builtin_median);
    try env.putBuiltin("min", builtins.builtin_min);
    try env.putBuiltin("max", builtins.builtin_max);
    // Linear algebra advanced
    try env.putBuiltin("lu", builtins.builtin_lu);
    try env.putBuiltin("charpoly", builtins.builtin_charpoly);
    // Polynomial tools
    try env.putBuiltin("roots", builtins.builtin_roots);
    try env.putBuiltin("discriminant", builtins.builtin_discriminant);
    // Quaternions
    try env.putBuiltin("quat", builtins.builtin_quat);
    try env.putBuiltin("quat+", builtins.builtin_quat_add);
    try env.putBuiltin("quat*", builtins.builtin_quat_mul);
    try env.putBuiltin("quat-conj", builtins.builtin_quat_conj);
    try env.putBuiltin("quat-norm", builtins.builtin_quat_norm);
    try env.putBuiltin("quat-inv", builtins.builtin_quat_inv);
    try env.putBuiltin("quat-scalar", builtins.builtin_quat_scalar);
    try env.putBuiltin("quat-vector", builtins.builtin_quat_vector);
    // Finite fields GF(p)
    try env.putBuiltin("gf", builtins.builtin_gf);
    try env.putBuiltin("gf+", builtins.builtin_gf_add);
    try env.putBuiltin("gf-", builtins.builtin_gf_sub);
    try env.putBuiltin("gf*", builtins.builtin_gf_mul);
    try env.putBuiltin("gf/", builtins.builtin_gf_div);
    try env.putBuiltin("gf^", builtins.builtin_gf_pow);
    try env.putBuiltin("gf-inv", builtins.builtin_gf_inv);
    try env.putBuiltin("gf-neg", builtins.builtin_gf_neg);
    // Output export
    try env.putBuiltin("latex", builtins.builtin_latex);
    return env;
}
