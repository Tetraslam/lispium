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

pub const Options = struct {
    mode: OutputMode = .pretty,
    quick: bool = false,
    /// Case-sensitive substring match against benchmark name or category
    filter: ?[]const u8 = null,
    /// Write results as JSON to this path (for later --compare)
    save_path: ?[]const u8 = null,
    /// Read a previous --save file and report per-benchmark deltas
    compare_path: ?[]const u8 = null,
};

pub const BenchmarkResult = struct {
    name: []const u8,
    category: []const u8,
    iterations: usize,
    total_ns: u64,
    mean_ns: u64,
    median_ns: u64,
    min_ns: u64,
    max_ns: u64,
    /// Median of the matching baseline benchmark (when comparing)
    baseline_ns: ?u64 = null,
};

const Benchmark = struct {
    name: []const u8,
    category: []const u8,
    /// Statements evaluated once before timing (definitions); benchmark
    /// setups use bench-* names so they can't collide with each other
    setup: ?[]const u8 = null,
    expr: []const u8,
    iterations: usize,
};

// Benchmark definitions. Micro benchmarks time a single builtin or CAS
// operation; the Programs category times interpreter-level workloads
// (function calls, tail recursion, closures, higher-order functions) that
// track what real scripts feel like.
const benchmarks = [_]Benchmark{
    // Parsing
    .{ .name = "parse-simple", .category = "Parsing", .expr = "(+ 1 2 3)", .iterations = 10000 },
    .{ .name = "parse-nested", .category = "Parsing", .expr = "(+ (* 2 (- 3 1)) (/ 8 (^ 2 2)))", .iterations = 10000 },
    .{ .name = "parse-deep", .category = "Parsing", .expr = "(+ (+ (+ (+ (+ (+ (+ (+ 1 2) 3) 4) 5) 6) 7) 8) 9)", .iterations = 5000 },

    // Arithmetic
    .{ .name = "add-numbers", .category = "Arithmetic", .expr = "(+ 1 2 3 4 5 6 7 8 9 10)", .iterations = 10000 },
    .{ .name = "multiply-chain", .category = "Arithmetic", .expr = "(* 2 3 5 7 11 13)", .iterations = 10000 },
    .{ .name = "power-int", .category = "Arithmetic", .expr = "(^ 2 20)", .iterations = 10000 },
    .{ .name = "rational-sum", .category = "Arithmetic", .expr = "(+ 1/3 1/6 1/12 1/24)", .iterations = 10000 },
    .{ .name = "bigint-pow", .category = "Arithmetic", .expr = "(^ 3 500)", .iterations = 2000 },
    .{ .name = "bigint-factorial", .category = "Arithmetic", .expr = "(factorial 100)", .iterations = 2000 },

    // Programs
    .{
        .name = "fib-recursive",
        .category = "Programs",
        .setup = "(define (bench-fib n) (if (< n 2) n (+ (bench-fib (- n 1)) (bench-fib (- n 2)))))",
        .expr = "(bench-fib 15)",
        .iterations = 200,
    },
    .{
        .name = "tail-loop",
        .category = "Programs",
        .setup = "(define (bench-loop i acc) (if (= i 0) acc (bench-loop (- i 1) (+ acc i))))",
        .expr = "(bench-loop 10000 0)",
        .iterations = 100,
    },
    .{
        .name = "mutual-recursion",
        .category = "Programs",
        .setup = "(define (bench-even? n) (if (= n 0) 1 (bench-odd? (- n 1)))) (define (bench-odd? n) (if (= n 0) 0 (bench-even? (- n 1))))",
        .expr = "(bench-even? 10000)",
        .iterations = 100,
    },
    .{
        .name = "map-filter-reduce",
        .category = "Programs",
        .setup = "(define bench-xs (range 1000))",
        .expr = "(reduce + 0 (map (lambda (x) (* x x)) (filter (lambda (x) (= (mod x 2) 0)) bench-xs)))",
        .iterations = 100,
    },
    .{
        .name = "closure-calls",
        .category = "Programs",
        .setup = "(define (bench-adder n) (lambda (x) (+ x n))) (define bench-add5 (bench-adder 5)) (define bench-ys (range 500))",
        .expr = "(reduce + 0 (map bench-add5 bench-ys))",
        .iterations = 100,
    },
    .{
        .name = "string-build",
        .category = "Programs",
        .setup = "(define (bench-str n acc) (if (= n 0) acc (bench-str (- n 1) (concat acc \"x\"))))",
        .expr = "(length (bench-str 200 \"\"))",
        .iterations = 100,
    },
    .{
        .name = "sort-random",
        .category = "Programs",
        .setup = "(random-seed 42) (define bench-rand (map (lambda (i) (random 100000)) (range 1000)))",
        .expr = "(car (sort bench-rand))",
        .iterations = 100,
    },
    .{
        .name = "macro-expansion",
        .category = "Programs",
        .setup = "(defmacro (bench-unless c a b) `(if ,c ,b ,a))",
        .expr = "(bench-unless 0 \"yes\" \"no\")",
        .iterations = 5000,
    },

    // Simplification
    .{ .name = "simplify-sum", .category = "Simplify", .expr = "(simplify (+ x x x x x))", .iterations = 5000 },
    .{ .name = "simplify-product", .category = "Simplify", .expr = "(simplify (* 2 x 3 y 4))", .iterations = 5000 },
    .{ .name = "simplify-nested", .category = "Simplify", .expr = "(simplify (+ (* 2 x) (* 3 x) (- x)))", .iterations = 3000 },

    // Calculus
    .{ .name = "diff-poly", .category = "Calculus", .expr = "(diff (^ x 5) x)", .iterations = 5000 },
    .{ .name = "diff-trig", .category = "Calculus", .expr = "(diff (sin (* 2 x)) x)", .iterations = 5000 },
    .{ .name = "diff-product", .category = "Calculus", .expr = "(diff (* x (sin x)) x)", .iterations = 3000 },
    .{ .name = "diff-pipeline", .category = "Calculus", .expr = "(diff (* (+ (* 3 (^ x 4)) (* 2 (^ x 3)) (^ x 2) x 1) (sin x)) x)", .iterations = 1000 },
    .{ .name = "integrate-poly", .category = "Calculus", .expr = "(integrate (^ x 4) x)", .iterations = 5000 },
    .{ .name = "integrate-trig", .category = "Calculus", .expr = "(integrate (cos x) x)", .iterations = 5000 },
    .{ .name = "taylor-exp", .category = "Calculus", .expr = "(taylor (exp x) x 0 5)", .iterations = 1000 },

    // Algebra
    .{ .name = "solve-linear", .category = "Algebra", .expr = "(solve (- (* 2 x) 6) x)", .iterations = 5000 },
    .{ .name = "solve-quadratic", .category = "Algebra", .expr = "(solve (+ (^ x 2) (* -5 x) 6) x)", .iterations = 3000 },
    .{ .name = "expand-binomial", .category = "Algebra", .expr = "(expand (* (+ x 1) (+ x 2)))", .iterations = 3000 },
    .{ .name = "expand-cubic", .category = "Algebra", .expr = "(simplify (expand (* (+ x 1) (+ x 2) (+ x 3))))", .iterations = 1000 },
    .{ .name = "factor-diff-sq", .category = "Algebra", .expr = "(factor (- (^ x 2) 9) x)", .iterations = 3000 },

    // Linear Algebra
    .{ .name = "det-2x2", .category = "Linear Algebra", .expr = "(det (matrix (1 2) (3 4)))", .iterations = 5000 },
    .{ .name = "det-3x3", .category = "Linear Algebra", .expr = "(det (matrix (1 2 3) (4 5 6) (7 8 9)))", .iterations = 3000 },
    .{ .name = "transpose-3x3", .category = "Linear Algebra", .expr = "(transpose (matrix (1 2 3) (4 5 6) (7 8 9)))", .iterations = 5000 },
    .{ .name = "matmul-2x2", .category = "Linear Algebra", .expr = "(matmul (matrix (1 2) (3 4)) (matrix (5 6) (7 8)))", .iterations = 3000 },
    .{ .name = "eigenvalues-3x3", .category = "Linear Algebra", .expr = "(eigenvalues (matrix (2 0 0) (0 3 4) (0 4 9)))", .iterations = 1000 },

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

/// A saved --save file, for --compare (older files carry mean_us only)
const Baseline = struct {
    benchmarks: []const BaselineEntry,
};
const BaselineEntry = struct {
    name: []const u8 = "",
    median_us: f64 = 0,
    mean_us: f64 = 0,
};

pub fn run(allocator: std.mem.Allocator, io: std.Io, options: Options) !void {
    var stdout_writer: std.Io.File.Writer = .init(.stdout(), io, &.{});
    const stdout = &stdout_writer.interface;

    // Load the comparison baseline first so a bad path fails fast
    var baseline_parsed: ?std.json.Parsed(Baseline) = null;
    defer if (baseline_parsed) |*p| p.deinit();
    if (options.compare_path) |path| {
        const data = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(16 * 1024 * 1024)) catch |err| {
            try stdout.print("error: can't read baseline '{s}': {}\n", .{ path, err });
            try stdout.flush();
            return;
        };
        defer allocator.free(data);
        // alloc_always: the parsed names must outlive `data`
        baseline_parsed = std.json.parseFromSlice(Baseline, allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch |err| {
            try stdout.print("error: can't parse baseline '{s}': {}\n", .{ path, err });
            try stdout.flush();
            return;
        };
    }

    var results: std.ArrayList(BenchmarkResult) = .empty;
    defer results.deinit(allocator);

    var env = Env.init(allocator);
    defer env.deinit();
    try @import("registry.zig").installBuiltins(&env);

    const start_total = std.Io.Timestamp.now(io, .awake).nanoseconds;

    if (options.mode == .pretty) {
        try printHeader(stdout);
    }

    var current_category: ?[]const u8 = null;

    for (benchmarks) |bench| {
        if (options.filter) |f| {
            if (std.mem.indexOf(u8, bench.name, f) == null and
                std.mem.indexOf(u8, bench.category, f) == null) continue;
        }

        const iterations = if (options.quick) @max(bench.iterations / 10, 20) else bench.iterations;

        // Category header in pretty mode
        if (options.mode == .pretty) {
            if (current_category == null or !std.mem.eql(u8, current_category.?, bench.category)) {
                if (current_category != null) {
                    try stdout.print("\n", .{});
                }
                try printCategoryHeader(stdout, bench.category);
                current_category = bench.category;
            }
        }

        var result = try runBenchmark(allocator, io, &env, bench, iterations);
        if (baseline_parsed) |p| {
            result.baseline_ns = baselineMedianNs(p.value, bench.name);
        }
        try results.append(allocator, result);

        switch (options.mode) {
            .pretty => try printResultPretty(stdout, result, getMaxTime(results.items)),
            .plain => try printResultPlain(stdout, result),
            .json => {},
        }
        try stdout.flush();
    }

    const end_total = std.Io.Timestamp.now(io, .awake).nanoseconds;
    const total_ns: u64 = @intCast(end_total - start_total);

    // Print footer/summary
    switch (options.mode) {
        .pretty => try printFooter(stdout, results.items, total_ns),
        .plain => {},
        .json => try printJson(stdout, results.items, total_ns),
    }

    // Save results for future --compare runs
    if (options.save_path) |path| {
        var buf: std.Io.Writer.Allocating = .init(allocator);
        defer buf.deinit();
        try printJson(&buf.writer, results.items, total_ns);
        std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = buf.written() }) catch |err| {
            try stdout.print("error: can't write '{s}': {}\n", .{ path, err });
            try stdout.flush();
            return;
        };
        if (options.mode == .pretty) {
            try stdout.print(" saved baseline to {s}\n\n", .{path});
        }
    }
    try stdout.flush();
}

fn baselineMedianNs(baseline: Baseline, name: []const u8) ?u64 {
    for (baseline.benchmarks) |b| {
        if (std.mem.eql(u8, b.name, name)) {
            const us = if (b.median_us > 0) b.median_us else b.mean_us;
            if (us <= 0) return null;
            return @intFromFloat(us * 1000.0);
        }
    }
    return null;
}

fn runBenchmark(
    allocator: std.mem.Allocator,
    io: std.Io,
    env: *Env,
    bench: Benchmark,
    iterations: usize,
) !BenchmarkResult {
    // One-time setup (definitions persist in the shared environment)
    if (bench.setup) |setup| {
        try evalAll(allocator, setup, env);
    }

    var times = try allocator.alloc(u64, iterations);
    defer allocator.free(times);

    // Warmup (10% of iterations, min 10)
    const warmup = @max(iterations / 10, 10);
    for (0..warmup) |_| {
        const expr = try parseExpr(allocator, bench.expr);
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
        const start = std.Io.Timestamp.now(io, .awake).nanoseconds;

        const expr = try parseExpr(allocator, bench.expr);
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

        const end = std.Io.Timestamp.now(io, .awake).nanoseconds;
        times[i] = @intCast(end - start);
    }

    // Statistics: the median is the headline (robust against scheduler
    // noise and one-off page faults); mean/min/max are reported alongside
    var total: u64 = 0;
    var min: u64 = std.math.maxInt(u64);
    var max: u64 = 0;
    for (times) |t| {
        total += t;
        if (t < min) min = t;
        if (t > max) max = t;
    }
    std.mem.sort(u64, times, {}, std.sort.asc(u64));
    const median = times[times.len / 2];

    return BenchmarkResult{
        .name = bench.name,
        .category = bench.category,
        .iterations = iterations,
        .total_ns = total,
        .mean_ns = total / iterations,
        .median_ns = median,
        .min_ns = min,
        .max_ns = max,
    };
}

/// Evaluates every statement in `source` (setup strings hold several).
fn evalAll(allocator: std.mem.Allocator, source: []const u8, env: *Env) !void {
    var tokenizer = Tokenizer.init(source);
    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);
    while (tokenizer.next()) |tok| {
        try tokens.append(allocator, tok);
    }
    var parser = Parser.init(allocator, tokens);
    while (parser.position < tokens.items.len) {
        const expr = try parser.parseExpr();
        defer {
            expr.deinit(allocator);
            allocator.destroy(expr);
        }
        const result = try evaluator.eval(expr, env);
        result.deinit(allocator);
        allocator.destroy(result);
    }
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
        if (r.median_ns > max) max = r.median_ns;
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
    const time_str = formatTime(&time_buf, result.median_ns);

    // Calculate bar width (max 20 chars)
    const bar_width: usize = 20;
    const filled = @min(bar_width, (result.median_ns * bar_width) / max_time);
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

    try writer.print("  {d}×", .{result.iterations});

    // Delta against the baseline (negative = faster now)
    if (result.baseline_ns) |base| {
        if (base > 0) {
            const now: f64 = @floatFromInt(result.median_ns);
            const then: f64 = @floatFromInt(base);
            const pct = (now - then) / then * 100.0;
            if (pct <= -2.0) {
                try writer.print("  \x1b[1;32m{d:.0}%\x1b[0m", .{pct});
            } else if (pct >= 2.0) {
                try writer.print("  \x1b[1;31m+{d:.0}%\x1b[0m", .{pct});
            } else {
                try writer.print("  \x1b[2m~\x1b[0m", .{});
            }
        }
    }

    try writer.print("\n", .{});
}

fn printFooter(writer: anytype, results: []const BenchmarkResult, total_ns: u64) !void {
    if (results.len == 0) {
        try writer.print("\nno benchmarks matched the filter\n\n", .{});
        return;
    }

    // Find fastest
    var fastest_idx: usize = 0;
    var fastest_time: u64 = std.math.maxInt(u64);
    for (results, 0..) |r, i| {
        if (r.median_ns < fastest_time) {
            fastest_time = r.median_ns;
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

    // Overall comparison: geometric mean of the per-benchmark ratios
    var log_sum: f64 = 0;
    var matched: usize = 0;
    for (results) |r| {
        if (r.baseline_ns) |base| {
            if (base > 0 and r.median_ns > 0) {
                const ratio = @as(f64, @floatFromInt(base)) / @as(f64, @floatFromInt(r.median_ns));
                log_sum += @log(ratio);
                matched += 1;
            }
        }
    }
    if (matched > 0) {
        const geomean = @exp(log_sum / @as(f64, @floatFromInt(matched)));
        if (geomean >= 1.0) {
            try writer.print(" vs baseline: \x1b[1;32m{d:.2}x faster\x1b[0m (geomean of {d} benchmarks)\n", .{ geomean, matched });
        } else {
            try writer.print(" vs baseline: \x1b[1;31m{d:.2}x slower\x1b[0m (geomean of {d} benchmarks)\n", .{ 1.0 / geomean, matched });
        }
    }
    try writer.print("\n", .{});
}

// ============================================================================
// Plain Output
// ============================================================================

fn printResultPlain(writer: anytype, result: BenchmarkResult) !void {
    const median_us = @as(f64, @floatFromInt(result.median_ns)) / 1000.0;
    try writer.print("{s},{s},{d:.3},us,{d}", .{ result.category, result.name, median_us, result.iterations });
    if (result.baseline_ns) |base| {
        if (base > 0) {
            const pct = (@as(f64, @floatFromInt(result.median_ns)) - @as(f64, @floatFromInt(base))) /
                @as(f64, @floatFromInt(base)) * 100.0;
            try writer.print(",{d:.1}%", .{pct});
        }
    }
    try writer.print("\n", .{});
}

// ============================================================================
// JSON Output
// ============================================================================

fn printJson(writer: anytype, results: []const BenchmarkResult, total_ns: u64) !void {
    try writer.print("{{\n", .{});
    try writer.print("  \"total_ms\": {d:.2},\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    try writer.print("  \"benchmarks\": [\n", .{});

    for (results, 0..) |r, i| {
        try writer.print("    {{\n", .{});
        try writer.print("      \"name\": \"{s}\",\n", .{r.name});
        try writer.print("      \"category\": \"{s}\",\n", .{r.category});
        try writer.print("      \"iterations\": {d},\n", .{r.iterations});
        try writer.print("      \"median_us\": {d:.3},\n", .{@as(f64, @floatFromInt(r.median_ns)) / 1000.0});
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
