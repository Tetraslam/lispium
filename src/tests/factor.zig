const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Difference of Squares Tests
// ============================================================================

test "factor: x^2 - 4 (difference of squares)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 4 = (x - 2)(x + 2)
    const expr = try h.parseExpr(allocator, "(factor (- (^ x 2) 4) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* (- x 2) (+ x 2))", str);
}

test "factor: x^2 - 9 (difference of squares)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 9 = (x - 3)(x + 3)
    const expr = try h.parseExpr(allocator, "(factor (- (^ x 2) 9) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* (- x 3) (+ x 3))", str);
}

test "factor: x^2 - 16 (difference of squares)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 16 = (x - 4)(x + 4)
    const expr = try h.parseExpr(allocator, "(factor (- (^ x 2) 16) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* (- x 4) (+ x 4))", str);
}

// ============================================================================
// Perfect Square Trinomial Tests
// ============================================================================

test "factor: x^2 + 2x + 1 (perfect square)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 + 2x + 1 = (x + 1)^2
    const expr = try h.parseExpr(allocator, "(factor (+ (^ x 2) (* 2 x) 1) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(^ (+ x 1) 2)", str);
}

test "factor: x^2 - 2x + 1 (perfect square negative)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 2x + 1 = (x - 1)^2
    const expr = try h.parseExpr(allocator, "(factor (+ (^ x 2) (* -2 x) 1) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(^ (- x 1) 2)", str);
}

test "factor: x^2 + 4x + 4 (perfect square)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 + 4x + 4 = (x + 2)^2
    const expr = try h.parseExpr(allocator, "(factor (+ (^ x 2) (* 4 x) 4) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(^ (+ x 2) 2)", str);
}

// ============================================================================
// General Quadratic Factoring Tests
// ============================================================================

test "factor: x^2 + 3x + 2 (general quadratic)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 + 3x + 2 = (x + 1)(x + 2) = (x - (-1))(x - (-2))
    const expr = try h.parseExpr(allocator, "(factor (+ (^ x 2) (* 3 x) 2) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    // Roots are -1 and -2, so we get (x - (-1))(x - (-2))
    try testing.expectEqualStrings("(* (- x -1) (- x -2))", str);
}

test "factor: x^2 - 5x + 6 (general quadratic)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 5x + 6 = (x - 2)(x - 3)
    const expr = try h.parseExpr(allocator, "(factor (+ (^ x 2) (* -5 x) 6) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    // Roots are 2 and 3
    try testing.expectEqualStrings("(* (- x 3) (- x 2))", str);
}

// ============================================================================
// Linear Tests
// ============================================================================

test "factor: 2x + 4 (linear GCF)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 2x + 4 = 2(x + 2)
    const expr = try h.parseExpr(allocator, "(factor (+ (* 2 x) 4) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 2 (+ x 2))", str);
}

test "factor: 3x + 9 (linear GCF)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 3x + 9 = 3(x + 3)
    const expr = try h.parseExpr(allocator, "(factor (+ (* 3 x) 9) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 3 (+ x 3))", str);
}

// ============================================================================
// Simple/Edge Cases
// ============================================================================

test "factor: x^2 (just x squared)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 = (x - 0)^2 (perfect square with s=0)
    const expr = try h.parseExpr(allocator, "(factor (^ x 2) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    // Recognized as perfect square (x - 0)^2
    try testing.expectEqualStrings("(^ (- x 0) 2)", str);
}

test "factor: constant 5" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(factor 5 x)");
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

test "factor: simple x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(factor x x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}
