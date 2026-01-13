const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;
const evaluator = @import("evaluator.zig");
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");

pub const OutputMode = enum {
    pretty,
    plain,
    json,
};

pub const BenchmarkResult = struct {
    name: []const u8,
    category: []const u8,
    iterations: usize,
    total_ns: u64,
    mean_ns: u64,
    min_ns: u64,
    max_ns: u64,
};

const Benchmark = struct {
    name: []const u8,
    category: []const u8,
    expr: []const u8,
    iterations: usize,
};

// Benchmark definitions
const benchmarks = [_]Benchmark{
    // Parsing
    .{ .name = "parse-simple", .category = "Parsing", .expr = "(+ 1 2 3)", .iterations = 10000 },
    .{ .name = "parse-nested", .category = "Parsing", .expr = "(+ (* 2 (- 3 1)) (/ 8 (^ 2 2)))", .iterations = 10000 },
    .{ .name = "parse-deep", .category = "Parsing", .expr = "(+ (+ (+ (+ (+ (+ (+ (+ 1 2) 3) 4) 5) 6) 7) 8) 9)", .iterations = 5000 },

    // Arithmetic
    .{ .name = "add-numbers", .category = "Arithmetic", .expr = "(+ 1 2 3 4 5 6 7 8 9 10)", .iterations = 10000 },
    .{ .name = "multiply-chain", .category = "Arithmetic", .expr = "(* 2 3 5 7 11 13)", .iterations = 10000 },
    .{ .name = "power-int", .category = "Arithmetic", .expr = "(^ 2 20)", .iterations = 10000 },

    // Simplification
    .{ .name = "simplify-sum", .category = "Simplify", .expr = "(simplify (+ x x x x x))", .iterations = 5000 },
    .{ .name = "simplify-product", .category = "Simplify", .expr = "(simplify (* 2 x 3 y 4))", .iterations = 5000 },
    .{ .name = "simplify-nested", .category = "Simplify", .expr = "(simplify (+ (* 2 x) (* 3 x) (- x)))", .iterations = 3000 },

    // Calculus
    .{ .name = "diff-poly", .category = "Calculus", .expr = "(diff (^ x 5) x)", .iterations = 5000 },
    .{ .name = "diff-trig", .category = "Calculus", .expr = "(diff (sin (* 2 x)) x)", .iterations = 5000 },
    .{ .name = "diff-product", .category = "Calculus", .expr = "(diff (* x (sin x)) x)", .iterations = 3000 },
    .{ .name = "integrate-poly", .category = "Calculus", .expr = "(integrate (^ x 4) x)", .iterations = 5000 },
    .{ .name = "integrate-trig", .category = "Calculus", .expr = "(integrate (cos x) x)", .iterations = 5000 },
    .{ .name = "taylor-exp", .category = "Calculus", .expr = "(taylor (exp x) x 0 5)", .iterations = 1000 },

    // Algebra
    .{ .name = "solve-linear", .category = "Algebra", .expr = "(solve (- (* 2 x) 6) x)", .iterations = 5000 },
    .{ .name = "solve-quadratic", .category = "Algebra", .expr = "(solve (+ (^ x 2) (* -5 x) 6) x)", .iterations = 3000 },
    .{ .name = "expand-binomial", .category = "Algebra", .expr = "(expand (* (+ x 1) (+ x 2)))", .iterations = 3000 },
    .{ .name = "factor-diff-sq", .category = "Algebra", .expr = "(factor (- (^ x 2) 9) x)", .iterations = 3000 },

    // Linear Algebra
    .{ .name = "det-2x2", .category = "Linear Algebra", .expr = "(det (matrix (1 2) (3 4)))", .iterations = 5000 },
    .{ .name = "det-3x3", .category = "Linear Algebra", .expr = "(det (matrix (1 2 3) (4 5 6) (7 8 9)))", .iterations = 3000 },
    .{ .name = "transpose-3x3", .category = "Linear Algebra", .expr = "(transpose (matrix (1 2 3) (4 5 6) (7 8 9)))", .iterations = 5000 },
    .{ .name = "matmul-2x2", .category = "Linear Algebra", .expr = "(matmul (matrix (1 2) (3 4)) (matrix (5 6) (7 8)))", .iterations = 3000 },

    // Vectors
    .{ .name = "dot-product", .category = "Vectors", .expr = "(dot (vector 1 2 3) (vector 4 5 6))", .iterations = 10000 },
    .{ .name = "cross-product", .category = "Vectors", .expr = "(cross (vector 1 2 3) (vector 4 5 6))", .iterations = 5000 },
    .{ .name = "norm", .category = "Vectors", .expr = "(norm (vector 3 4 5 6 7))", .iterations = 10000 },

    // Number Theory
    .{ .name = "factorial-10", .category = "Number Theory", .expr = "(factorial 10)", .iterations = 10000 },
    .{ .name = "gcd", .category = "Number Theory", .expr = "(gcd 48 18)", .iterations = 10000 },
    .{ .name = "prime-check", .category = "Number Theory", .expr = "(prime? 997)", .iterations = 5000 },
    .{ .name = "factorize", .category = "Number Theory", .expr = "(factorize 360)", .iterations = 3000 },

    // Special Functions
    .{ .name = "gamma", .category = "Special", .expr = "(gamma 5.5)", .iterations = 5000 },
    .{ .name = "erf", .category = "Special", .expr = "(erf 1.0)", .iterations = 5000 },
    .{ .name = "bessel-j0", .category = "Special", .expr = "(besselj 0 2.5)", .iterations = 3000 },
};

pub fn run(allocator: std.mem.Allocator, mode: OutputMode, quick: bool) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    var results: std.ArrayList(BenchmarkResult) = .empty;
    defer results.deinit(allocator);

    var env = Env.init(allocator);
    defer env.deinit();
    try initBuiltins(&env);

    const start_total = std.time.nanoTimestamp();

    // Print header for pretty mode
    if (mode == .pretty) {
        try printHeader(stdout);
    }

    var current_category: ?[]const u8 = null;

    for (benchmarks) |bench| {
        const iterations = if (quick) @max(bench.iterations / 10, 100) else bench.iterations;

        // Category header in pretty mode
        if (mode == .pretty) {
            if (current_category == null or !std.mem.eql(u8, current_category.?, bench.category)) {
                if (current_category != null) {
                    try stdout.print("\n", .{});
                }
                try printCategoryHeader(stdout, bench.category);
                current_category = bench.category;
            }
        }

        const result = try runBenchmark(allocator, &env, bench.name, bench.category, bench.expr, iterations);
        try results.append(allocator, result);

        switch (mode) {
            .pretty => try printResultPretty(stdout, result, getMaxTime(results.items)),
            .plain => try printResultPlain(stdout, result),
            .json => {},
        }
    }

    const end_total = std.time.nanoTimestamp();
    const total_ns: u64 = @intCast(end_total - start_total);

    // Print footer/summary
    switch (mode) {
        .pretty => try printFooter(stdout, results.items, total_ns),
        .plain => {},
        .json => try printJson(allocator, stdout, results.items, total_ns),
    }
}

fn runBenchmark(
    allocator: std.mem.Allocator,
    env: *Env,
    name: []const u8,
    category: []const u8,
    expr_str: []const u8,
    iterations: usize,
) !BenchmarkResult {
    var times = try allocator.alloc(u64, iterations);
    defer allocator.free(times);

    // Warmup (10% of iterations, min 10)
    const warmup = @max(iterations / 10, 10);
    for (0..warmup) |_| {
        const expr = try parseExpr(allocator, expr_str);
        defer {
            expr.deinit(allocator);
            allocator.destroy(expr);
        }
        const result = evaluator.eval(expr, env) catch continue;
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Actual benchmark
    for (0..iterations) |i| {
        const start = std.time.nanoTimestamp();

        const expr = try parseExpr(allocator, expr_str);
        defer {
            expr.deinit(allocator);
            allocator.destroy(expr);
        }

        const result = evaluator.eval(expr, env) catch {
            times[i] = 0;
            continue;
        };
        result.deinit(allocator);
        allocator.destroy(result);

        const end = std.time.nanoTimestamp();
        times[i] = @intCast(end - start);
    }

    // Calculate statistics
    var total: u64 = 0;
    var min: u64 = std.math.maxInt(u64);
    var max: u64 = 0;

    for (times) |t| {
        total += t;
        if (t < min) min = t;
        if (t > max) max = t;
    }

    return BenchmarkResult{
        .name = name,
        .category = category,
        .iterations = iterations,
        .total_ns = total,
        .mean_ns = total / iterations,
        .min_ns = min,
        .max_ns = max,
    };
}

fn parseExpr(allocator: std.mem.Allocator, input: []const u8) !*Expr {
    var tokenizer = Tokenizer.init(input);
    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);

    while (tokenizer.next()) |tok| {
        try tokens.append(allocator, tok);
    }

    var parser = Parser.init(allocator, tokens);
    return try parser.parseExpr();
}

fn getMaxTime(results: []const BenchmarkResult) u64 {
    var max: u64 = 1; // Avoid division by zero
    for (results) |r| {
        if (r.mean_ns > max) max = r.mean_ns;
    }
    return max;
}

// ============================================================================
// Pretty Output
// ============================================================================

fn printHeader(writer: anytype) !void {
    try writer.print("\n", .{});
    try writer.print("╭──────────────────────────────────────────────────────────────╮\n", .{});
    try writer.print("│               \x1b[1;36mLispium Benchmark Suite\x1b[0m                       │\n", .{});
    try writer.print("╰──────────────────────────────────────────────────────────────╯\n", .{});
    try writer.print("\n", .{});
}

fn printCategoryHeader(writer: anytype, category: []const u8) !void {
    try writer.print(" \x1b[1;33m{s}\x1b[0m ", .{category});
    // Fill with dashes
    const padding = 60 - category.len;
    for (0..padding) |_| {
        try writer.print("─", .{});
    }
    try writer.print("\n", .{});
}

fn printResultPretty(writer: anytype, result: BenchmarkResult, max_time: u64) !void {
    // Format time
    var time_buf: [32]u8 = undefined;
    const time_str = formatTime(&time_buf, result.mean_ns);

    // Calculate bar width (max 20 chars)
    const bar_width: usize = 20;
    const filled = @min(bar_width, (result.mean_ns * bar_width) / max_time);
    const empty = bar_width - filled;

    // Print: name (padded), time, bar, iterations
    try writer.print("   {s: <22} \x1b[1;32m{s: >8}\x1b[0m  ", .{ result.name, time_str });

    // Bar
    try writer.print("\x1b[36m", .{});
    for (0..filled) |_| {
        try writer.print("█", .{});
    }
    try writer.print("\x1b[2m", .{});
    for (0..empty) |_| {
        try writer.print("░", .{});
    }
    try writer.print("\x1b[0m", .{});

    try writer.print("  {d}×\n", .{result.iterations});
}

fn printFooter(writer: anytype, results: []const BenchmarkResult, total_ns: u64) !void {
    // Find fastest
    var fastest_idx: usize = 0;
    var fastest_time: u64 = std.math.maxInt(u64);
    for (results, 0..) |r, i| {
        if (r.mean_ns < fastest_time) {
            fastest_time = r.mean_ns;
            fastest_idx = i;
        }
    }

    var time_buf: [32]u8 = undefined;
    var total_buf: [32]u8 = undefined;

    const total_str = formatTime(&total_buf, total_ns);
    const fastest_str = formatTime(&time_buf, fastest_time);
    const fastest_name = results[fastest_idx].name;

    try writer.print("\n", .{});
    try writer.print("╭──────────────────────────────────────────────────────────────╮\n", .{});

    // Build the content line
    var content_buf: [200]u8 = undefined;
    const content = std.fmt.bufPrint(&content_buf, "  {d} benchmarks | {s} total | fastest: {s} ({s})  ", .{
        results.len,
        total_str,
        fastest_name,
        fastest_str,
    }) catch "  benchmark results  ";

    // Center the content in the box (62 chars inner width)
    const inner_width: usize = 62;
    const padding_total = if (inner_width > content.len) inner_width - content.len else 0;
    const pad_left = padding_total / 2;
    const pad_right = padding_total - pad_left;

    try writer.print("│", .{});
    for (0..pad_left) |_| try writer.print(" ", .{});
    try writer.print("{s}", .{content});
    for (0..pad_right) |_| try writer.print(" ", .{});
    try writer.print("│\n", .{});

    try writer.print("╰──────────────────────────────────────────────────────────────╯\n", .{});
    try writer.print("\n", .{});
}

// ============================================================================
// Plain Output
// ============================================================================

fn printResultPlain(writer: anytype, result: BenchmarkResult) !void {
    const mean_us = @as(f64, @floatFromInt(result.mean_ns)) / 1000.0;
    try writer.print("{s},{s},{d:.3},us,{d}\n", .{ result.category, result.name, mean_us, result.iterations });
}

// ============================================================================
// JSON Output
// ============================================================================

fn printJson(allocator: std.mem.Allocator, writer: anytype, results: []const BenchmarkResult, total_ns: u64) !void {
    _ = allocator;
    try writer.print("{{\n", .{});
    try writer.print("  \"total_ms\": {d:.2},\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    try writer.print("  \"benchmarks\": [\n", .{});

    for (results, 0..) |r, i| {
        try writer.print("    {{\n", .{});
        try writer.print("      \"name\": \"{s}\",\n", .{r.name});
        try writer.print("      \"category\": \"{s}\",\n", .{r.category});
        try writer.print("      \"iterations\": {d},\n", .{r.iterations});
        try writer.print("      \"mean_us\": {d:.3},\n", .{@as(f64, @floatFromInt(r.mean_ns)) / 1000.0});
        try writer.print("      \"min_us\": {d:.3},\n", .{@as(f64, @floatFromInt(r.min_ns)) / 1000.0});
        try writer.print("      \"max_us\": {d:.3}\n", .{@as(f64, @floatFromInt(r.max_ns)) / 1000.0});
        if (i < results.len - 1) {
            try writer.print("    }},\n", .{});
        } else {
            try writer.print("    }}\n", .{});
        }
    }

    try writer.print("  ]\n", .{});
    try writer.print("}}\n", .{});
}

// ============================================================================
// Utilities
// ============================================================================

fn formatTime(buf: []u8, ns: u64) []const u8 {
    if (ns < 1000) {
        return std.fmt.bufPrint(buf, "{d}ns", .{ns}) catch "?";
    } else if (ns < 1_000_000) {
        const us = @as(f64, @floatFromInt(ns)) / 1000.0;
        return std.fmt.bufPrint(buf, "{d:.2}us", .{us}) catch "?";
    } else if (ns < 1_000_000_000) {
        const ms = @as(f64, @floatFromInt(ns)) / 1_000_000.0;
        return std.fmt.bufPrint(buf, "{d:.2}ms", .{ms}) catch "?";
    } else {
        const s = @as(f64, @floatFromInt(ns)) / 1_000_000_000.0;
        return std.fmt.bufPrint(buf, "{d:.2}s", .{s}) catch "?";
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

    // Trigonometric
    try env.putBuiltin("sin", builtins.builtin_sin);
    try env.putBuiltin("cos", builtins.builtin_cos);
    try env.putBuiltin("tan", builtins.builtin_tan);

    // Transcendental
    try env.putBuiltin("exp", builtins.builtin_exp);
    try env.putBuiltin("ln", builtins.builtin_ln);
    try env.putBuiltin("sqrt", builtins.builtin_sqrt);

    // Matrix operations
    try env.putBuiltin("matrix", builtins.builtin_matrix);
    try env.putBuiltin("det", builtins.builtin_det);
    try env.putBuiltin("transpose", builtins.builtin_transpose);
    try env.putBuiltin("matmul", builtins.builtin_matmul);

    // Vector operations
    try env.putBuiltin("vector", builtins.builtin_vector);
    try env.putBuiltin("dot", builtins.builtin_dot);
    try env.putBuiltin("cross", builtins.builtin_cross);
    try env.putBuiltin("norm", builtins.builtin_norm);

    // Number theory
    try env.putBuiltin("factorial", builtins.builtin_factorial);
    try env.putBuiltin("gcd", builtins.builtin_gcd);
    try env.putBuiltin("prime?", builtins.builtin_prime);
    try env.putBuiltin("factorize", builtins.builtin_factorize);

    // Special functions
    try env.putBuiltin("gamma", builtins.builtin_gamma);
    try env.putBuiltin("erf", builtins.builtin_erf);
    try env.putBuiltin("besselj", builtins.builtin_besselj);
}
