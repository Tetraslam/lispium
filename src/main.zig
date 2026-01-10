const std = @import("std");
const build_options = @import("build_options");
const repl = @import("repl.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;
const evaluator = @import("evaluator.zig");
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");

pub const version = build_options.version;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var args_it = try std.process.argsWithAllocator(allocator);
    defer args_it.deinit();
    _ = args_it.skip(); // skip executable name

    const stdout = std.fs.File.stdout().deprecatedWriter();
    const stderr = std.fs.File.stderr().deprecatedWriter();

    if (args_it.next()) |cmd| {
        if (std.mem.eql(u8, cmd, "repl")) {
            try repl.run(allocator);
            return;
        } else if (std.mem.eql(u8, cmd, "eval")) {
            // Evaluate a single expression: lispium eval "(+ 1 2)"
            const expr_str = args_it.next() orelse {
                try stderr.print("Usage: lispium eval \"<expression>\"\n", .{});
                return;
            };
            try evalExpression(allocator, expr_str, stdout, stderr);
            return;
        } else if (std.mem.eql(u8, cmd, "run")) {
            // Run a file: lispium run file.lisp
            const file_path = args_it.next() orelse {
                try stderr.print("Usage: lispium run <file.lisp>\n", .{});
                return;
            };
            try runFile(allocator, file_path, stdout, stderr);
            return;
        } else if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
            try printUsage(stdout);
            return;
        } else if (std.mem.eql(u8, cmd, "version") or std.mem.eql(u8, cmd, "--version") or std.mem.eql(u8, cmd, "-v")) {
            try stdout.print("lispium {s}\n", .{version});
            return;
        }
    }

    try printUsage(stdout);
}

fn printUsage(writer: anytype) !void {
    try writer.print(
        \\Lispium {s} - A Symbolic Computer Algebra System
        \\
        \\Usage:
        \\  lispium repl              Start interactive REPL
        \\  lispium eval "<expr>"     Evaluate a single expression
        \\  lispium run <file.lspm>   Run a Lispium source file
        \\  lispium help              Show this help message
        \\  lispium version           Show version information
        \\
        \\Examples:
        \\  lispium repl
        \\  lispium eval "(+ 1 2 3)"
        \\  lispium eval "(diff (^ x 3) x)"
        \\  lispium run cookbook/calculus.lspm
        \\
    , .{version});
}

fn evalExpression(allocator: std.mem.Allocator, input: []const u8, stdout: anytype, stderr: anytype) !void {
    var env = Env.init(allocator);
    defer env.deinit();
    try initBuiltins(&env);

    // Tokenize
    var tokenizer = Tokenizer.init(input);
    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);

    while (true) {
        const tok = tokenizer.next();
        if (tok == null) break;
        try tokens.append(allocator, tok.?);
    }

    if (tokens.items.len == 0) {
        try stderr.print("Error: empty expression\n", .{});
        return;
    }

    // Parse
    var parser = Parser.init(allocator, tokens);
    const expr = parser.parseExpr() catch |err| {
        const err_msg = switch (err) {
            error.UnexpectedToken => "unexpected token in expression",
            error.UnexpectedEOF => "unexpected end of input (missing closing paren?)",
            error.OutOfMemory => "out of memory",
        };
        try stderr.print("Parse error: {s}\n", .{err_msg});
        return;
    };
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    // Evaluate
    const result = evaluator.eval(expr, &env) catch |err| {
        const err_msg = switch (err) {
            error.UnsupportedOperator => "unsupported operator",
            error.InvalidArgument => "invalid argument(s)",
            error.KeyNotFound => "unknown function or variable",
            error.OutOfMemory => "out of memory",
            error.RecursionLimit => "recursion limit exceeded",
            error.InvalidLambda => "invalid lambda expression",
            error.InvalidDefine => "invalid define expression",
            error.WrongNumberOfArguments => "wrong number of arguments",
            error.EvaluationError => "evaluation error",
        };
        try stderr.print("Eval error: {s}\n", .{err_msg});
        return;
    };
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Print result
    try printExprSimple(result, stdout);
    try stdout.print("\n", .{});
}

fn runFile(allocator: std.mem.Allocator, file_path: []const u8, stdout: anytype, stderr: anytype) !void {
    // Read file
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        try stderr.print("Error opening file '{s}': {}\n", .{ file_path, err });
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 1024 * 1024 * 10) catch |err| {
        try stderr.print("Error reading file: {}\n", .{err});
        return;
    };
    defer allocator.free(content);

    var env = Env.init(allocator);
    defer env.deinit();
    try initBuiltins(&env);

    // Process expressions, handling multi-line expressions
    var line_num: usize = 0;
    var start_line: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var expr_buf: std.ArrayList(u8) = .empty;
    defer expr_buf.deinit(allocator);
    var paren_depth: i32 = 0;

    while (lines.next()) |raw_line| {
        line_num += 1;

        // Trim whitespace
        const line = std.mem.trim(u8, raw_line, " \t\r");

        // Skip empty lines and comments (only when not in a multi-line expr)
        if (paren_depth == 0) {
            if (line.len == 0) continue;
            if (line[0] == ';') continue;
            start_line = line_num;
        }

        // Strip trailing comment from non-comment lines
        var code_end: usize = line.len;
        var in_string = false;
        for (line, 0..) |c, i| {
            if (c == '"') in_string = !in_string;
            if (c == ';' and !in_string) {
                code_end = i;
                break;
            }
        }
        const code = std.mem.trim(u8, line[0..code_end], " \t");

        if (code.len == 0 and paren_depth == 0) continue;

        // Append to expression buffer
        if (expr_buf.items.len > 0) {
            try expr_buf.append(allocator, ' ');
        }
        try expr_buf.appendSlice(allocator, code);

        // Count parentheses
        for (code) |c| {
            if (c == '(') paren_depth += 1;
            if (c == ')') paren_depth -= 1;
        }

        // If balanced (or negative = error), evaluate
        if (paren_depth <= 0) {
            if (expr_buf.items.len == 0) {
                paren_depth = 0;
                continue;
            }

            // Tokenize
            var tokenizer = Tokenizer.init(expr_buf.items);
            var tokens: std.ArrayList([]const u8) = .empty;
            defer tokens.deinit(allocator);

            while (true) {
                const tok = tokenizer.next();
                if (tok == null) break;
                try tokens.append(allocator, tok.?);
            }

            if (tokens.items.len == 0) {
                expr_buf.clearRetainingCapacity();
                paren_depth = 0;
                continue;
            }

            // Parse
            var parser = Parser.init(allocator, tokens);
            const expr = parser.parseExpr() catch |err| {
                const err_msg = switch (err) {
                    error.UnexpectedToken => "unexpected token",
                    error.UnexpectedEOF => "unexpected end of input",
                    error.OutOfMemory => "out of memory",
                };
                try stderr.print("{s}:{}: Parse error: {s}\n", .{ file_path, start_line, err_msg });
                expr_buf.clearRetainingCapacity();
                paren_depth = 0;
                continue;
            };
            defer {
                expr.deinit(allocator);
                allocator.destroy(expr);
            }

            // Evaluate
            const result = evaluator.eval(expr, &env) catch |err| {
                const err_msg = switch (err) {
                    error.UnsupportedOperator => "unsupported operator",
                    error.InvalidArgument => "invalid argument(s)",
                    error.KeyNotFound => "unknown function or variable",
                    error.OutOfMemory => "out of memory",
                    error.RecursionLimit => "recursion limit exceeded",
                    error.InvalidLambda => "invalid lambda expression",
                    error.InvalidDefine => "invalid define expression",
                    error.WrongNumberOfArguments => "wrong number of arguments",
                    error.EvaluationError => "evaluation error",
                };
                try stderr.print("{s}:{}: Eval error: {s}\n", .{ file_path, start_line, err_msg });
                expr_buf.clearRetainingCapacity();
                paren_depth = 0;
                continue;
            };
            defer {
                result.deinit(allocator);
                allocator.destroy(result);
            }

            // Print a condensed version of the expression and result
            const display_expr = if (expr_buf.items.len > 60)
                expr_buf.items[0..57]
            else
                expr_buf.items;
            const ellipsis: []const u8 = if (expr_buf.items.len > 60) "..." else "";
            try stdout.print("; {s}{s}\n", .{ display_expr, ellipsis });
            try printExprSimple(result, stdout);
            try stdout.print("\n\n", .{});

            expr_buf.clearRetainingCapacity();
            paren_depth = 0;
        }
    }
}

fn printExprSimple(expr: *const Expr, writer: anytype) !void {
    switch (expr.*) {
        .number => |n| {
            if (@abs(n - @round(n)) < 1e-10 and @abs(n) < 1e15) {
                try writer.print("{d}", .{@as(i64, @intFromFloat(@round(n)))});
            } else {
                try writer.print("{d}", .{n});
            }
        },
        .symbol => |s| try writer.print("{s}", .{s}),
        .owned_symbol => |s| try writer.print("{s}", .{s}),
        .list => |lst| {
            if (lst.items.len == 0) {
                try writer.print("()", .{});
                return;
            }
            try writer.print("(", .{});
            for (lst.items, 0..) |item, i| {
                if (i > 0) try writer.print(" ", .{});
                try printExprSimple(item, writer);
            }
            try writer.print(")", .{});
        },
        .lambda => try writer.print("<lambda>", .{}),
    }
}

fn initBuiltins(env: *Env) !void {
    // Arithmetic
    try env.putBuiltin("+", builtins.builtin_add);
    try env.putBuiltin("-", builtins.builtin_subtract);
    try env.putBuiltin("*", builtins.builtin_multiply);
    try env.putBuiltin("/", builtins.builtin_divide);
    try env.putBuiltin("^", builtins.builtin_power);
    try env.putBuiltin("pow", builtins.builtin_power);

    // Algebra
    try env.putBuiltin("simplify", builtins.builtin_simplify);
    try env.putBuiltin("diff", builtins.builtin_diff);
    try env.putBuiltin("integrate", builtins.builtin_integrate);
    try env.putBuiltin("expand", builtins.builtin_expand);
    try env.putBuiltin("substitute", builtins.builtin_substitute);
    try env.putBuiltin("taylor", builtins.builtin_taylor);
    try env.putBuiltin("solve", builtins.builtin_solve);
    try env.putBuiltin("factor", builtins.builtin_factor);
    try env.putBuiltin("partial-fractions", builtins.builtin_partial_fractions);
    try env.putBuiltin("collect", builtins.builtin_collect);
    try env.putBuiltin("limit", builtins.builtin_limit);

    // Trigonometric
    try env.putBuiltin("sin", builtins.builtin_sin);
    try env.putBuiltin("cos", builtins.builtin_cos);
    try env.putBuiltin("tan", builtins.builtin_tan);
    try env.putBuiltin("asin", builtins.builtin_asin);
    try env.putBuiltin("acos", builtins.builtin_acos);
    try env.putBuiltin("atan", builtins.builtin_atan);
    try env.putBuiltin("atan2", builtins.builtin_atan2);

    // Hyperbolic
    try env.putBuiltin("sinh", builtins.builtin_sinh);
    try env.putBuiltin("cosh", builtins.builtin_cosh);
    try env.putBuiltin("tanh", builtins.builtin_tanh);
    try env.putBuiltin("asinh", builtins.builtin_asinh);
    try env.putBuiltin("acosh", builtins.builtin_acosh);
    try env.putBuiltin("atanh", builtins.builtin_atanh);

    // Transcendental
    try env.putBuiltin("exp", builtins.builtin_exp);
    try env.putBuiltin("ln", builtins.builtin_ln);
    try env.putBuiltin("log", builtins.builtin_log);
    try env.putBuiltin("sqrt", builtins.builtin_sqrt);

    // Complex numbers
    try env.putBuiltin("complex", builtins.builtin_complex);
    try env.putBuiltin("real", builtins.builtin_real);
    try env.putBuiltin("imag", builtins.builtin_imag);
    try env.putBuiltin("conj", builtins.builtin_conj);
    try env.putBuiltin("magnitude", builtins.builtin_abs_complex);
    try env.putBuiltin("arg", builtins.builtin_arg);

    // Pattern rewriting
    try env.putBuiltin("rule", builtins.builtin_rule);
    try env.putBuiltin("rewrite", builtins.builtin_rewrite);

    // Matrix operations
    try env.putBuiltin("matrix", builtins.builtin_matrix);
    try env.putBuiltin("det", builtins.builtin_det);
    try env.putBuiltin("transpose", builtins.builtin_transpose);
    try env.putBuiltin("trace", builtins.builtin_trace);
    try env.putBuiltin("matmul", builtins.builtin_matmul);
    try env.putBuiltin("inv", builtins.builtin_inv);
    try env.putBuiltin("eigenvalues", builtins.builtin_eigenvalues);
    try env.putBuiltin("eigenvectors", builtins.builtin_eigenvectors);
    try env.putBuiltin("linsolve", builtins.builtin_linsolve);
    try env.putBuiltin("lu", builtins.builtin_lu);
    try env.putBuiltin("charpoly", builtins.builtin_charpoly);

    // Vector operations
    try env.putBuiltin("vector", builtins.builtin_vector);
    try env.putBuiltin("dot", builtins.builtin_dot);
    try env.putBuiltin("cross", builtins.builtin_cross);
    try env.putBuiltin("norm", builtins.builtin_norm);

    // Vector calculus
    try env.putBuiltin("gradient", builtins.builtin_gradient);
    try env.putBuiltin("grad", builtins.builtin_gradient);
    try env.putBuiltin("divergence", builtins.builtin_divergence);
    try env.putBuiltin("curl", builtins.builtin_curl);
    try env.putBuiltin("laplacian", builtins.builtin_laplacian);

    // Boolean algebra
    try env.putBuiltin("and", builtins.builtin_and);
    try env.putBuiltin("or", builtins.builtin_or);
    try env.putBuiltin("not", builtins.builtin_not);
    try env.putBuiltin("xor", builtins.builtin_xor);
    try env.putBuiltin("implies", builtins.builtin_implies);

    // Modular arithmetic
    try env.putBuiltin("mod", builtins.builtin_mod);
    try env.putBuiltin("gcd", builtins.builtin_gcd);
    try env.putBuiltin("lcm", builtins.builtin_lcm);
    try env.putBuiltin("modpow", builtins.builtin_modpow);

    // Number theory
    try env.putBuiltin("prime?", builtins.builtin_prime);
    try env.putBuiltin("factorize", builtins.builtin_factorize);
    try env.putBuiltin("totient", builtins.builtin_totient);
    try env.putBuiltin("extgcd", builtins.builtin_extgcd);
    try env.putBuiltin("crt", builtins.builtin_crt);

    // Combinatorics
    try env.putBuiltin("factorial", builtins.builtin_factorial);
    try env.putBuiltin("!", builtins.builtin_factorial);
    try env.putBuiltin("binomial", builtins.builtin_binomial);
    try env.putBuiltin("choose", builtins.builtin_binomial);
    try env.putBuiltin("permutations", builtins.builtin_permutations);
    try env.putBuiltin("combinations", builtins.builtin_combinations);

    // Statistics
    try env.putBuiltin("mean", builtins.builtin_mean);
    try env.putBuiltin("variance", builtins.builtin_variance);
    try env.putBuiltin("stddev", builtins.builtin_stddev);
    try env.putBuiltin("median", builtins.builtin_median);
    try env.putBuiltin("min", builtins.builtin_min);
    try env.putBuiltin("max", builtins.builtin_max);

    // Polynomial operations
    try env.putBuiltin("coeffs", builtins.builtin_coeffs);
    try env.putBuiltin("polydiv", builtins.builtin_polydiv);
    try env.putBuiltin("polygcd", builtins.builtin_polygcd);
    try env.putBuiltin("polylcm", builtins.builtin_polylcm);
    try env.putBuiltin("roots", builtins.builtin_roots);
    try env.putBuiltin("discriminant", builtins.builtin_discriminant);

    // Assumptions
    try env.putBuiltin("assume", builtins.builtin_assume);
    try env.putBuiltin("is?", builtins.builtin_is);

    // Comparisons
    try env.putBuiltin("=", builtins.builtin_eq);
    try env.putBuiltin("<", builtins.builtin_lt);
    try env.putBuiltin(">", builtins.builtin_gt);

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

    // Quaternions
    try env.putBuiltin("quat", builtins.builtin_quat);
    try env.putBuiltin("quat+", builtins.builtin_quat_add);
    try env.putBuiltin("quat*", builtins.builtin_quat_mul);
    try env.putBuiltin("quat-conj", builtins.builtin_quat_conj);
    try env.putBuiltin("quat-norm", builtins.builtin_quat_norm);
    try env.putBuiltin("quat-inv", builtins.builtin_quat_inv);
    try env.putBuiltin("quat-scalar", builtins.builtin_quat_scalar);
    try env.putBuiltin("quat-vector", builtins.builtin_quat_vector);

    // Finite fields
    try env.putBuiltin("gf", builtins.builtin_gf);
    try env.putBuiltin("gf+", builtins.builtin_gf_add);
    try env.putBuiltin("gf-", builtins.builtin_gf_sub);
    try env.putBuiltin("gf*", builtins.builtin_gf_mul);
    try env.putBuiltin("gf/", builtins.builtin_gf_div);
    try env.putBuiltin("gf^", builtins.builtin_gf_pow);
    try env.putBuiltin("gf-inv", builtins.builtin_gf_inv);
    try env.putBuiltin("gf-neg", builtins.builtin_gf_neg);

    // LaTeX export
    try env.putBuiltin("latex", builtins.builtin_latex);
}
