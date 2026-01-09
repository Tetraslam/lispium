const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Polynomial Coefficient List Tests
// ============================================================================

test "polynomial: coeffs creation" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (coeffs 1 -3 2) represents x² - 3x + 2
    const expr = try h.parseExpr(allocator, "(coeffs 1 -3 2)");
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
    try testing.expectEqualStrings("(coeffs 1 -3 2)", str);
}

// ============================================================================
// Polynomial Long Division Tests
// ============================================================================

test "polynomial: polydiv exact division" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (x² - 3x + 2) / (x - 2) = (x - 1) with remainder 0
    // coeffs: (1, -3, 2) / (1, -2)
    const expr = try h.parseExpr(allocator, "(polydiv (coeffs 1 -3 2) (coeffs 1 -2) x)");
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
    // quotient: (1, -1) meaning x - 1, remainder: 0
    try testing.expectEqualStrings("((coeffs 1 -1) (coeffs 0))", str);
}

test "polynomial: polydiv with remainder" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (x² + 1) / (x - 1) = x + 1 with remainder 2
    // coeffs: (1, 0, 1) / (1, -1)
    const expr = try h.parseExpr(allocator, "(polydiv (coeffs 1 0 1) (coeffs 1 -1) x)");
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
    // quotient: (1, 1) meaning x + 1, remainder: 2
    try testing.expectEqualStrings("((coeffs 1 1) (coeffs 2))", str);
}

test "polynomial: polydiv higher degree" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (x³ - 6x² + 11x - 6) / (x - 1) = (x² - 5x + 6)
    // This is (x-1)(x-2)(x-3) / (x-1) = (x-2)(x-3) = x² - 5x + 6
    const expr = try h.parseExpr(allocator, "(polydiv (coeffs 1 -6 11 -6) (coeffs 1 -1) x)");
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
    try testing.expectEqualStrings("((coeffs 1 -5 6) (coeffs 0))", str);
}

test "polynomial: polydiv by quadratic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (x³ - 6x² + 11x - 6) / (x² - 3x + 2) = (x - 3) remainder 0
    // (x-1)(x-2)(x-3) / (x-1)(x-2) = (x-3)
    const expr = try h.parseExpr(allocator, "(polydiv (coeffs 1 -6 11 -6) (coeffs 1 -3 2) x)");
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
    try testing.expectEqualStrings("((coeffs 1 -3) (coeffs 0))", str);
}

test "polynomial: polydiv constant divisor" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (2x² + 4x + 6) / 2 = x² + 2x + 3
    const expr = try h.parseExpr(allocator, "(polydiv (coeffs 2 4 6) (coeffs 2) x)");
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
    try testing.expectEqualStrings("((coeffs 1 2 3) (coeffs 0))", str);
}

test "polynomial: polydiv smaller dividend" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x / (x² + 1) = 0 with remainder x
    // coeffs: (1, 0) / (1, 0, 1)
    const expr = try h.parseExpr(allocator, "(polydiv (coeffs 1 0) (coeffs 1 0 1) x)");
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
    // quotient: 0, remainder: (1, 0) meaning x
    try testing.expectEqualStrings("((coeffs 0) (coeffs 1 0))", str);
}

// ============================================================================
// Polynomial GCD Tests
// ============================================================================

test "polynomial: polygcd common factor" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // gcd((x-1)(x-2), (x-1)(x-3)) = (x-1) (monic)
    // (x² - 3x + 2) and (x² - 4x + 3)
    const expr = try h.parseExpr(allocator, "(polygcd (coeffs 1 -3 2) (coeffs 1 -4 3))");
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
    // GCD is (x-1) = (1, -1)
    try testing.expectEqualStrings("(coeffs 1 -1)", str);
}

test "polynomial: polygcd coprime" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // gcd((x-1), (x-2)) = 1 (coprime)
    const expr = try h.parseExpr(allocator, "(polygcd (coeffs 1 -1) (coeffs 1 -2))");
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
    // GCD is 1
    try testing.expectEqualStrings("(coeffs 1)", str);
}

test "polynomial: polygcd one divides other" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // gcd((x-1)(x-2), (x-1)) = (x-1)
    const expr = try h.parseExpr(allocator, "(polygcd (coeffs 1 -3 2) (coeffs 1 -1))");
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
    try testing.expectEqualStrings("(coeffs 1 -1)", str);
}

// ============================================================================
// Polynomial LCM Tests
// ============================================================================

test "polynomial: polylcm common factor" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // lcm((x-1)(x-2), (x-1)(x-3)) = (x-1)(x-2)(x-3)
    // = x³ - 6x² + 11x - 6
    const expr = try h.parseExpr(allocator, "(polylcm (coeffs 1 -3 2) (coeffs 1 -4 3))");
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
    try testing.expectEqualStrings("(coeffs 1 -6 11 -6)", str);
}

test "polynomial: polylcm coprime" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // lcm((x-1), (x-2)) = (x-1)(x-2) = x² - 3x + 2
    const expr = try h.parseExpr(allocator, "(polylcm (coeffs 1 -1) (coeffs 1 -2))");
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
    try testing.expectEqualStrings("(coeffs 1 -3 2)", str);
}

// ============================================================================
// Polynomial Roots Tests
// ============================================================================

test "polynomial: roots linear" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 2x + 6 = 0 => x = -3
    const expr = try h.parseExpr(allocator, "(roots (+ (* 2 x) 6) x)");
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
    try testing.expectEqualStrings("(roots -3)", str);
}

test "polynomial: roots quadratic real" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x² - 5x + 6 = 0 => x = 3, 2
    const expr = try h.parseExpr(allocator, "(roots (+ (- (^ x 2) (* 5 x)) 6) x)");
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
    try testing.expectEqualStrings("(roots 3 2)", str);
}

test "polynomial: roots quadratic complex" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x² + 1 = 0 => x = i, -i
    const expr = try h.parseExpr(allocator, "(roots (+ (^ x 2) 1) x)");
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
    try testing.expectEqualStrings("(roots (complex 0 1) (complex 0 -1))", str);
}

// ============================================================================
// Discriminant Tests
// ============================================================================

test "polynomial: discriminant positive" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x² - 5x + 6: disc = 25 - 24 = 1 (positive, two real roots)
    const expr = try h.parseExpr(allocator, "(discriminant (+ (- (^ x 2) (* 5 x)) 6) x)");
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

test "polynomial: discriminant zero" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x² - 2x + 1: disc = 4 - 4 = 0 (double root)
    const expr = try h.parseExpr(allocator, "(discriminant (+ (- (^ x 2) (* 2 x)) 1) x)");
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

test "polynomial: discriminant negative" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x² + 1: disc = 0 - 4 = -4 (complex roots)
    const expr = try h.parseExpr(allocator, "(discriminant (+ (^ x 2) 1) x)");
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
    try testing.expectEqual(@as(f64, -4), result.number);
}
