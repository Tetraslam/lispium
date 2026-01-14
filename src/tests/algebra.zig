const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Expression Equality Tests
// ============================================================================

test "exprEqual: numbers" {
    const allocator = testing.allocator;

    const a = try h.parseExpr(allocator, "42");
    defer {
        a.deinit(allocator);
        allocator.destroy(a);
    }
    const b = try h.parseExpr(allocator, "42");
    defer {
        b.deinit(allocator);
        allocator.destroy(b);
    }
    const c = try h.parseExpr(allocator, "43");
    defer {
        c.deinit(allocator);
        allocator.destroy(c);
    }

    try testing.expect(h.symbolic.exprEqual(a, b));
    try testing.expect(!h.symbolic.exprEqual(a, c));
}

test "exprEqual: symbols" {
    const allocator = testing.allocator;

    const a = try h.parseExpr(allocator, "x");
    defer {
        a.deinit(allocator);
        allocator.destroy(a);
    }
    const b = try h.parseExpr(allocator, "x");
    defer {
        b.deinit(allocator);
        allocator.destroy(b);
    }
    const c = try h.parseExpr(allocator, "y");
    defer {
        c.deinit(allocator);
        allocator.destroy(c);
    }

    try testing.expect(h.symbolic.exprEqual(a, b));
    try testing.expect(!h.symbolic.exprEqual(a, c));
}

test "exprEqual: lists" {
    const allocator = testing.allocator;

    const a = try h.parseExpr(allocator, "(+ x 1)");
    defer {
        a.deinit(allocator);
        allocator.destroy(a);
    }
    const b = try h.parseExpr(allocator, "(+ x 1)");
    defer {
        b.deinit(allocator);
        allocator.destroy(b);
    }
    const c = try h.parseExpr(allocator, "(+ x 2)");
    defer {
        c.deinit(allocator);
        allocator.destroy(c);
    }

    try testing.expect(h.symbolic.exprEqual(a, b));
    try testing.expect(!h.symbolic.exprEqual(a, c));
}

// ============================================================================
// Trig Function Tests
// ============================================================================

test "trig: sin numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(sin 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "trig: cos numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(cos 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "trig: symbolic sin" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(sin x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(sin x)", str);
}

// ============================================================================
// Exp/Log Function Tests
// ============================================================================

test "exp: numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(exp 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "ln: numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(ln 1)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "log: base 10" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(log 100)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 2), result.number);
}

test "log: custom base" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(log 2 8)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 3), result.number);
}

test "sqrt: numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(sqrt 16)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 4), result.number);
}

// ============================================================================
// Expansion Tests
// ============================================================================

test "expand: simple distribution" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(expand (* (+ a b) c))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ (* a c) (* b c))", str);
}

test "expand: FOIL" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(expand (* (+ a b) (+ c d)))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ (* a c) (* a d) (* b c) (* b d))", str);
}

test "expand: (x+1)^2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(expand (^ (+ x 1) 2))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ (* x x) (* 2 x) 1)", str);
}

// ============================================================================
// Substitution Tests
// ============================================================================

test "substitute: simple variable" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(substitute (+ x 1) x 5)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(+ 5 1)", str);
}

test "substitute: nested expression" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(substitute (* x (+ x 3)) x 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 2 (+ 2 3))", str);
}

test "substitute: with simplify" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (substitute (+ x 1) x 5))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 6), result.number);
}

// ============================================================================
// Equation Solving Tests
// ============================================================================

test "solve: linear equation" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(solve (+ (* 2 x) 4) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, -2), result.number);
}

test "solve: linear equation simple x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(solve (- x 5) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 5), result.number);
}

test "solve: quadratic with one solution" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(solve (^ x 2) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "solve: quadratic x^2 - 4" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(solve (- (^ x 2) 4) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(solutions 2 -2)", str);
}

test "solve: quadratic x^2 + 1 (complex solutions)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(solve (+ (^ x 2) 1) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(solutions (complex 0 1) (complex 0 -1))", str);
}

test "solve: equation syntax (= left right)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (solve (= x 5) x) should give x = 5
    const expr = try h.parseExpr(allocator, "(solve (= x 5) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 5), result.number);
}

test "solve: equation syntax x^2 = 4" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(solve (= (* x x) 4) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(solutions 2 -2)", str);
}
