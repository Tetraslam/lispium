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
    try env.putBuiltin("asin", builtins.builtin_asin);
    try env.putBuiltin("acos", builtins.builtin_acos);
    try env.putBuiltin("atan", builtins.builtin_atan);
    try env.putBuiltin("atan2", builtins.builtin_atan2);
    try env.putBuiltin("sinh", builtins.builtin_sinh);
    try env.putBuiltin("cosh", builtins.builtin_cosh);
    try env.putBuiltin("tanh", builtins.builtin_tanh);
    try env.putBuiltin("asinh", builtins.builtin_asinh);
    try env.putBuiltin("acosh", builtins.builtin_acosh);
    try env.putBuiltin("atanh", builtins.builtin_atanh);
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
    // Special functions
    try env.putBuiltin("gamma", builtins.builtin_gamma);
    try env.putBuiltin("beta", builtins.builtin_beta);
    try env.putBuiltin("erf", builtins.builtin_erf);
    try env.putBuiltin("erfc", builtins.builtin_erfc);
    try env.putBuiltin("besselj", builtins.builtin_besselj);
    try env.putBuiltin("bessely", builtins.builtin_bessely);
    try env.putBuiltin("digamma", builtins.builtin_digamma);
    // Differential equations
    try env.putBuiltin("dsolve", builtins.builtin_dsolve);
    // Fourier & Laplace transforms
    try env.putBuiltin("fourier", builtins.builtin_fourier);
    try env.putBuiltin("laplace", builtins.builtin_laplace);
    try env.putBuiltin("inv-laplace", builtins.builtin_inv_laplace);
    // Tensor operations
    try env.putBuiltin("tensor", builtins.builtin_tensor);
    try env.putBuiltin("tensor-rank", builtins.builtin_tensor_rank);
    try env.putBuiltin("tensor-contract", builtins.builtin_tensor_contract);
    try env.putBuiltin("tensor-product", builtins.builtin_tensor_product);
    // Polynomial interpolation
    try env.putBuiltin("lagrange", builtins.builtin_lagrange);
    try env.putBuiltin("newton-interp", builtins.builtin_newton_interp);
    // Numerical root finding
    try env.putBuiltin("newton-raphson", builtins.builtin_newton_raphson);
    try env.putBuiltin("bisection", builtins.builtin_bisection);
    // Continued fractions
    try env.putBuiltin("to-cf", builtins.builtin_to_cf);
    try env.putBuiltin("from-cf", builtins.builtin_from_cf);
    try env.putBuiltin("cf-convergent", builtins.builtin_cf_convergent);
    try env.putBuiltin("cf-rational", builtins.builtin_cf_rational);
    // List operations
    try env.putBuiltin("car", builtins.builtin_car);
    try env.putBuiltin("cdr", builtins.builtin_cdr);
    try env.putBuiltin("cons", builtins.builtin_cons);
    try env.putBuiltin("list", builtins.builtin_list_fn);
    try env.putBuiltin("length", builtins.builtin_length);
    try env.putBuiltin("nth", builtins.builtin_nth);
    try env.putBuiltin("map", builtins.builtin_map);
    try env.putBuiltin("filter", builtins.builtin_filter);
    try env.putBuiltin("reduce", builtins.builtin_reduce);
    try env.putBuiltin("append", builtins.builtin_append);
    try env.putBuiltin("reverse", builtins.builtin_reverse);
    try env.putBuiltin("range", builtins.builtin_range);

    // Memoization
    try env.putBuiltin("memoize", builtins.builtin_memoize);
    try env.putBuiltin("memo-clear", builtins.builtin_memo_clear);
    try env.putBuiltin("memo-stats", builtins.builtin_memo_stats);

    // Plotting
    try env.putBuiltin("plot-ascii", builtins.builtin_plot_ascii);
    try env.putBuiltin("plot-svg", builtins.builtin_plot_svg);
    try env.putBuiltin("plot-points", builtins.builtin_plot_points);

    // Step-by-step solutions
    try env.putBuiltin("diff-steps", builtins.builtin_diff_steps);
    try env.putBuiltin("integrate-steps", builtins.builtin_integrate_steps);
    try env.putBuiltin("simplify-steps", builtins.builtin_simplify_steps);
    try env.putBuiltin("solve-steps", builtins.builtin_solve_steps);
    return env;
}
