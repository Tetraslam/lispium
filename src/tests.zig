const std = @import("std");
const testing = std.testing;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;
const eval = @import("evaluator.zig").eval;
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");
const symbolic = @import("symbolic.zig");

// ============================================================================
// Test Helpers
// ============================================================================

fn parseExpr(allocator: std.mem.Allocator, input: []const u8) !*Expr {
    var tokenizer = Tokenizer.init(input);
    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);

    while (tokenizer.next()) |tok| {
        try tokens.append(allocator, tok);
    }

    var parser = Parser.init(allocator, tokens);
    return parser.parseExpr();
}

fn exprToString(allocator: std.mem.Allocator, expr: *const Expr) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try writeExpr(expr, result.writer(allocator));
    return result.toOwnedSlice(allocator);
}

fn writeExpr(expr: *const Expr, writer: anytype) !void {
    switch (expr.*) {
        .number => |n| {
            if (n == @floor(n) and @abs(n) < 1e15) {
                try writer.print("{d:.0}", .{n});
            } else {
                try writer.print("{d}", .{n});
            }
        },
        .symbol => |s| try writer.print("{s}", .{s}),
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

fn setupEnv(allocator: std.mem.Allocator) !Env {
    var env = Env.init(allocator);
    try env.putBuiltin("+", builtins.builtin_add);
    try env.putBuiltin("-", builtins.builtin_subtract);
    try env.putBuiltin("*", builtins.builtin_multiply);
    try env.putBuiltin("/", builtins.builtin_divide);
    try env.putBuiltin("^", builtins.builtin_power);
    try env.putBuiltin("pow", builtins.builtin_power);
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
    try env.putBuiltin("complex", builtins.builtin_complex);
    try env.putBuiltin("real", builtins.builtin_real);
    try env.putBuiltin("imag", builtins.builtin_imag);
    try env.putBuiltin("conj", builtins.builtin_conj);
    try env.putBuiltin("magnitude", builtins.builtin_abs_complex);
    try env.putBuiltin("arg", builtins.builtin_arg);
    return env;
}

// Helper struct for managing eval result cleanup
const EvalResult = struct {
    result: *Expr,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const EvalResult) void {
        self.result.deinit(self.allocator);
        self.allocator.destroy(self.result);
    }
};

fn evalAndTrack(expr: *Expr, env: *Env, allocator: std.mem.Allocator) !EvalResult {
    const result = try eval(expr, env);
    return EvalResult{ .result = result, .allocator = allocator };
}

// ============================================================================
// Tokenizer Tests
// ============================================================================

test "tokenizer: basic tokens" {
    var tokenizer = Tokenizer.init("(+ 1 2)");
    try testing.expectEqualStrings("(", tokenizer.next().?);
    try testing.expectEqualStrings("+", tokenizer.next().?);
    try testing.expectEqualStrings("1", tokenizer.next().?);
    try testing.expectEqualStrings("2", tokenizer.next().?);
    try testing.expectEqualStrings(")", tokenizer.next().?);
    try testing.expectEqual(@as(?[]const u8, null), tokenizer.next());
}

test "tokenizer: nested expressions" {
    var tokenizer = Tokenizer.init("(+ (* x 2) y)");
    const expected = [_][]const u8{ "(", "+", "(", "*", "x", "2", ")", "y", ")" };
    for (expected) |exp| {
        try testing.expectEqualStrings(exp, tokenizer.next().?);
    }
    try testing.expectEqual(@as(?[]const u8, null), tokenizer.next());
}

test "tokenizer: floating point numbers" {
    var tokenizer = Tokenizer.init("(+ 3.14 2.71)");
    try testing.expectEqualStrings("(", tokenizer.next().?);
    try testing.expectEqualStrings("+", tokenizer.next().?);
    try testing.expectEqualStrings("3.14", tokenizer.next().?);
    try testing.expectEqualStrings("2.71", tokenizer.next().?);
    try testing.expectEqualStrings(")", tokenizer.next().?);
}

// ============================================================================
// Parser Tests
// ============================================================================

test "parser: number" {
    const allocator = testing.allocator;

    const expr = try parseExpr(allocator, "42");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.* == .number);
    try testing.expectEqual(@as(f64, 42), expr.number);
}

test "parser: symbol" {
    const allocator = testing.allocator;

    const expr = try parseExpr(allocator, "x");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.* == .symbol);
    try testing.expectEqualStrings("x", expr.symbol);
}

test "parser: simple list" {
    const allocator = testing.allocator;

    const expr = try parseExpr(allocator, "(+ 1 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.* == .list);
    try testing.expectEqual(@as(usize, 3), expr.list.items.len);
    try testing.expect(expr.list.items[0].* == .symbol);
    try testing.expectEqualStrings("+", expr.list.items[0].symbol);
    try testing.expect(expr.list.items[1].* == .number);
    try testing.expectEqual(@as(f64, 1), expr.list.items[1].number);
}

test "parser: nested list" {
    const allocator = testing.allocator;

    const expr = try parseExpr(allocator, "(+ (* 2 3) 4)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.* == .list);
    try testing.expectEqual(@as(usize, 3), expr.list.items.len);
    // Second element should be (* 2 3)
    try testing.expect(expr.list.items[1].* == .list);
    try testing.expectEqual(@as(usize, 3), expr.list.items[1].list.items.len);
}

// ============================================================================
// Arithmetic Tests
// ============================================================================

test "arithmetic: addition" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(+ 1 2 3)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 6), result.number);
}

test "arithmetic: subtraction" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(- 10 3 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 5), result.number);
}

test "arithmetic: multiplication" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(* 2 3 4)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 24), result.number);
}

test "arithmetic: division" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(/ 24 4 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 3), result.number);
}

test "arithmetic: nested operations" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(+ (* 2 3) (- 10 5))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 11), result.number); // 6 + 5 = 11
}

// ============================================================================
// Symbolic Expression Tests
// ============================================================================

test "symbolic: variable preserved" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(+ x 1)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ x 1)", str);
}

// ============================================================================
// Simplification Tests
// ============================================================================

test "simplify: x + 0 = x" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (+ x 0))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "simplify: 0 + x = x" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (+ 0 x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "simplify: x * 1 = x" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (* x 1))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "simplify: x * 0 = 0" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (* x 0))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "simplify: x - x = 0" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (- x x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "simplify: x / x = 1" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (/ x x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "simplify: x + x = 2*x" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (+ x x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 2 x)", str);
}

test "simplify: numeric computation" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (+ 2 3))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 5), result.number);
}

// ============================================================================
// Differentiation Tests
// ============================================================================

test "diff: constant" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(diff 5 x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "diff: same variable" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(diff x x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "diff: different variable" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(diff y x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "diff: sum rule" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(x + 1) = 1 + 0 = 1 (with auto-simplification)
    const expr = try parseExpr(allocator, "(diff (+ x 1) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "diff: product rule" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(x * x) = 2x (with auto-simplification)
    const expr = try parseExpr(allocator, "(diff (* x x) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 2 x)", str);
}

// ============================================================================
// Expression Equality Tests
// ============================================================================

test "exprEqual: numbers" {
    const allocator = testing.allocator;

    const a = try parseExpr(allocator, "42");
    defer {
        a.deinit(allocator);
        allocator.destroy(a);
    }
    const b = try parseExpr(allocator, "42");
    defer {
        b.deinit(allocator);
        allocator.destroy(b);
    }
    const c = try parseExpr(allocator, "43");
    defer {
        c.deinit(allocator);
        allocator.destroy(c);
    }

    try testing.expect(symbolic.exprEqual(a, b));
    try testing.expect(!symbolic.exprEqual(a, c));
}

test "exprEqual: symbols" {
    const allocator = testing.allocator;

    const a = try parseExpr(allocator, "x");
    defer {
        a.deinit(allocator);
        allocator.destroy(a);
    }
    const b = try parseExpr(allocator, "x");
    defer {
        b.deinit(allocator);
        allocator.destroy(b);
    }
    const c = try parseExpr(allocator, "y");
    defer {
        c.deinit(allocator);
        allocator.destroy(c);
    }

    try testing.expect(symbolic.exprEqual(a, b));
    try testing.expect(!symbolic.exprEqual(a, c));
}

test "exprEqual: lists" {
    const allocator = testing.allocator;

    const a = try parseExpr(allocator, "(+ x 1)");
    defer {
        a.deinit(allocator);
        allocator.destroy(a);
    }
    const b = try parseExpr(allocator, "(+ x 1)");
    defer {
        b.deinit(allocator);
        allocator.destroy(b);
    }
    const c = try parseExpr(allocator, "(+ x 2)");
    defer {
        c.deinit(allocator);
        allocator.destroy(c);
    }

    try testing.expect(symbolic.exprEqual(a, b));
    try testing.expect(!symbolic.exprEqual(a, c));
}

// ============================================================================
// Copy Expression Tests
// ============================================================================

test "copyExpr: deep copy" {
    const allocator = testing.allocator;

    const original = try parseExpr(allocator, "(+ (* x 2) y)");
    defer {
        original.deinit(allocator);
        allocator.destroy(original);
    }

    const copied = try symbolic.copyExpr(original, allocator);
    defer {
        copied.deinit(allocator);
        allocator.destroy(copied);
    }

    try testing.expect(symbolic.exprEqual(original, copied));
    // Verify they're different memory
    try testing.expect(original != copied);
}

// ============================================================================
// Power Operator Tests
// ============================================================================

test "power: numeric computation" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(^ 2 3)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 8), result.number);
}

test "power: pow alias" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(pow 2 10)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1024), result.number);
}

test "simplify: x^0 = 1" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (^ x 0))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "simplify: x^1 = x" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(simplify (^ x 1))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "diff: power rule x^2" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(x^2) = 2*x
    const expr = try parseExpr(allocator, "(diff (^ x 2) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 2 x)", str);
}

test "diff: power rule x^3" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(x^3) = 3*x^2
    const expr = try parseExpr(allocator, "(diff (^ x 3) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 3 (^ x 2))", str);
}

// ============================================================================
// Trigonometric Function Tests
// ============================================================================

test "trig: sin numeric" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(sin 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "trig: cos numeric" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(cos 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "trig: symbolic sin" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(sin x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(sin x)", str);
}

test "diff: sin(x)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(sin(x)) = cos(x)
    const expr = try parseExpr(allocator, "(diff (sin x) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(cos x)", str);
}

test "diff: cos(x)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(cos(x)) = -sin(x)
    const expr = try parseExpr(allocator, "(diff (cos x) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* -1 (sin x))", str);
}

test "diff: chain rule sin(2x)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(sin(2x)) = cos(2x) * 2
    const expr = try parseExpr(allocator, "(diff (sin (* 2 x)) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* (cos (* 2 x)) 2)", str);
}

// ============================================================================
// Logarithm and Exponential Tests
// ============================================================================

test "exp: numeric" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(exp 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "ln: numeric" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(ln 1)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "log: base 10" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(log 100)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 2), result.number);
}

test "log: custom base" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(log 2 8)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 3), result.number);
}

test "sqrt: numeric" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(sqrt 16)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 4), result.number);
}

test "diff: exp(x)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(exp(x)) = exp(x)
    const expr = try parseExpr(allocator, "(diff (exp x) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(exp x)", str);
}

test "diff: ln(x)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(ln(x)) = 1/x
    const expr = try parseExpr(allocator, "(diff (ln x) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(/ 1 x)", str);
}

test "diff: chain rule exp(2x)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // d/dx(exp(2x)) = exp(2x) * 2
    const expr = try parseExpr(allocator, "(diff (exp (* 2 x)) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* (exp (* 2 x)) 2)", str);
}

// ============================================================================
// Integration Tests
// ============================================================================

test "integrate: constant" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // ∫1 dx = x
    const expr = try parseExpr(allocator, "(integrate 1 x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "integrate: x" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // ∫x dx = 0.5*x^2
    const expr = try parseExpr(allocator, "(integrate x x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 0.5 (^ x 2))", str);
}

test "integrate: x^2" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // ∫x^2 dx = x^3/3
    const expr = try parseExpr(allocator, "(integrate (^ x 2) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(/ (^ x 3) 3)", str);
}

test "integrate: 1/x" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // ∫1/x dx = ln(x)
    const expr = try parseExpr(allocator, "(integrate (/ 1 x) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(ln x)", str);
}

test "integrate: sin(x)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // ∫sin(x) dx = -cos(x)
    const expr = try parseExpr(allocator, "(integrate (sin x) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* -1 (cos x))", str);
}

test "integrate: cos(x)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // ∫cos(x) dx = sin(x)
    const expr = try parseExpr(allocator, "(integrate (cos x) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(sin x)", str);
}

test "integrate: exp(x)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // ∫exp(x) dx = exp(x)
    const expr = try parseExpr(allocator, "(integrate (exp x) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(exp x)", str);
}

test "integrate: sum rule" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // ∫(x+1) dx = x^2/2 + x
    const expr = try parseExpr(allocator, "(integrate (+ x 1) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ (* 0.5 (^ x 2)) x)", str);
}

// ============================================================================
// Expansion Tests
// ============================================================================

test "expand: simple distribution" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // (a+b)*c = a*c + b*c
    const expr = try parseExpr(allocator, "(expand (* (+ a b) c))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ (* a c) (* b c))", str);
}

test "expand: FOIL" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // (a+b)*(c+d) = a*c + a*d + b*c + b*d
    const expr = try parseExpr(allocator, "(expand (* (+ a b) (+ c d)))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ (* a c) (* a d) (* b c) (* b d))", str);
}

test "expand: (x+1)^2" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // (x+1)^2 = x^2 + 2x + 1
    const expr = try parseExpr(allocator, "(expand (^ (+ x 1) 2))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ (* x x) (* 2 x) 1)", str);
}

// ============================================================================
// Substitution Tests
// ============================================================================

test "substitute: simple variable" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // substitute x with 5 in (+ x 1)
    const expr = try parseExpr(allocator, "(substitute (+ x 1) x 5)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ 5 1)", str);
}

test "substitute: nested expression" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // substitute x with 2 in (* x (+ x 3))
    const expr = try parseExpr(allocator, "(substitute (* x (+ x 3)) x 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 2 (+ 2 3))", str);
}

test "substitute: with simplify" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // substitute and simplify (+ x 1) with x=5 should give 6
    const expr = try parseExpr(allocator, "(simplify (substitute (+ x 1) x 5))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 6), result.number);
}

// ============================================================================
// Taylor Series Tests
// ============================================================================

test "taylor: constant" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // Taylor series of constant 5 around x=0, order 3 is just 5
    const expr = try parseExpr(allocator, "(taylor 5 x 0 3)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 5), result.number);
}

test "taylor: x around 0" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // Taylor series of x around x=0, order 3 is just x (as (x-0) = x)
    const expr = try parseExpr(allocator, "(taylor x x 0 3)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Result should be (+ 0 (* 1 x) ...) simplified to x
    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "taylor: x^2 around 0" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // Taylor series of x^2 around x=0, order 3
    // f(0) = 0, f'(0) = 0, f''(0) = 2
    // Taylor: 0 + 0*x + (2/2!)*x^2 = x^2
    const expr = try parseExpr(allocator, "(taylor (^ x 2) x 0 3)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(^ x 2)", str);
}

test "taylor: exp(x) around 0 order 4" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // Taylor series of exp(x) around x=0, order 4
    // exp(0) = 1, all derivatives are 1 at x=0
    // 1 + x + x^2/2! + x^3/3!
    const expr = try parseExpr(allocator, "(taylor (exp x) x 0 4)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    // 1 + x + 0.5*x^2 + (1/6)*x^3
    try testing.expectEqualStrings("(+ 1 x (* 0.5 (^ x 2)) (* 0.16666666666666666 (^ x 3)))", str);
}

// ============================================================================
// Equation Solving Tests
// ============================================================================

test "solve: linear equation" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // solve (+ (* 2 x) 4) x = 0  =>  2x + 4 = 0  =>  x = -2
    const expr = try parseExpr(allocator, "(solve (+ (* 2 x) 4) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, -2), result.number);
}

test "solve: linear equation simple x" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // solve (- x 5) x = 0  =>  x - 5 = 0  =>  x = 5
    const expr = try parseExpr(allocator, "(solve (- x 5) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 5), result.number);
}

test "solve: quadratic with one solution" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // solve (^ x 2) x = 0  =>  x^2 = 0  =>  x = 0
    const expr = try parseExpr(allocator, "(solve (^ x 2) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "solve: quadratic x^2 - 4" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // solve (- (^ x 2) 4) x = 0  =>  x^2 - 4 = 0  =>  x = +/- 2
    const expr = try parseExpr(allocator, "(solve (- (^ x 2) 4) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(solutions 2 -2)", str);
}

test "solve: quadratic x^2 + 1 (complex solutions)" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // solve (+ (^ x 2) 1) x = 0  =>  x^2 + 1 = 0  =>  x = +/- i
    const expr = try parseExpr(allocator, "(solve (+ (^ x 2) 1) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(solutions (complex 0 1) (complex 0 -1))", str);
}

// ============================================================================
// Complex Number Tests
// ============================================================================

test "complex: create" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(complex 3 4)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(complex 3 4)", str);
}

test "complex: real part" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(real (complex 3 4))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 3), result.number);
}

test "complex: imag part" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(imag (complex 3 4))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 4), result.number);
}

test "complex: conjugate" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    const expr = try parseExpr(allocator, "(conj (complex 3 4))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(complex 3 -4)", str);
}

test "complex: magnitude" {
    const allocator = testing.allocator;

    var env = try setupEnv(allocator);
    defer env.deinit();

    // |3 + 4i| = 5
    const expr = try parseExpr(allocator, "(magnitude (complex 3 4))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 5), result.number);
}
