const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Distinct Linear Factors Tests
// ============================================================================

test "partial-fractions: 1/(x^2 - 1)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 1/(x^2 - 1) = 1/((x-1)(x+1)) = 0.5/(x-1) - 0.5/(x+1)
    // = 0.5/(x-1) + (-0.5)/(x-(-1))
    const expr = try h.parseExpr(allocator, "(partial-fractions (/ 1 (- (^ x 2) 1)) x)");
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
    // Roots are r1=1 and r2=-1
    // A = 1 / (1*(1-(-1))) = 1/2 = 0.5
    // B = 1 / (1*(-1-1)) = 1/(-2) = -0.5
    try testing.expectEqualStrings("(+ (/ 0.5 (- x 1)) (/ -0.5 (- x -1)))", str);
}

test "partial-fractions: 1/(x^2 - 4)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 1/(x^2 - 4) = 1/((x-2)(x+2))
    // Roots: r1=2, r2=-2
    // A = 1/(1*(2-(-2))) = 1/4 = 0.25
    // B = 1/(1*(-2-2)) = 1/(-4) = -0.25
    const expr = try h.parseExpr(allocator, "(partial-fractions (/ 1 (- (^ x 2) 4)) x)");
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
    try testing.expectEqualStrings("(+ (/ 0.25 (- x 2)) (/ -0.25 (- x -2)))", str);
}

test "partial-fractions: 1/(x^2 + 3x + 2)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 + 3x + 2 = (x+1)(x+2)
    // Roots: r1=-1, r2=-2
    // For 1/((x+1)(x+2)):
    // A = 1/(1*(-1-(-2))) = 1/1 = 1
    // B = 1/(1*(-2-(-1))) = 1/(-1) = -1
    const expr = try h.parseExpr(allocator, "(partial-fractions (/ 1 (+ (^ x 2) (* 3 x) 2)) x)");
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
    try testing.expectEqualStrings("(+ (/ 1 (- x -1)) (/ -1 (- x -2)))", str);
}

test "partial-fractions: x/(x^2 - 1)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x/(x^2 - 1) with numerator = x
    // Roots: r1=1, r2=-1
    // P(1) = 1, P(-1) = -1
    // A = 1/(1*(1-(-1))) = 1/2 = 0.5
    // B = -1/(1*(-1-1)) = -1/(-2) = 0.5
    const expr = try h.parseExpr(allocator, "(partial-fractions (/ x (- (^ x 2) 1)) x)");
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
    try testing.expectEqualStrings("(+ (/ 0.5 (- x 1)) (/ 0.5 (- x -1)))", str);
}

// ============================================================================
// Repeated Root Tests
// ============================================================================

test "partial-fractions: 1/(x^2 - 2x + 1) (repeated root)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 2x + 1 = (x-1)^2
    // 1/(x-1)^2 = A/(x-1) + B/(x-1)^2
    // At r=1: P(1) = 1, P'(1) = 0
    // B = P(r)/a = 1/1 = 1
    // A = P'(r)/a = 0/1 = 0
    const expr = try h.parseExpr(allocator, "(partial-fractions (/ 1 (+ (^ x 2) (* -2 x) 1)) x)");
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
    // A = 0, B = 1: 0/(x-1) + 1/(x-1)^2
    try testing.expectEqualStrings("(+ (/ 0 (- x 1)) (/ 1 (^ (- x 1) 2)))", str);
}

test "partial-fractions: x/(x^2 - 2x + 1) (repeated root with linear numer)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 2x + 1 = (x-1)^2, numerator = x
    // At r=1: P(1) = 1, P'(1) = 1
    // B = P(r)/a = 1/1 = 1
    // A = P'(r)/a = 1/1 = 1
    const expr = try h.parseExpr(allocator, "(partial-fractions (/ x (+ (^ x 2) (* -2 x) 1)) x)");
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
    // A = 1, B = 1: 1/(x-1) + 1/(x-1)^2
    try testing.expectEqualStrings("(+ (/ 1 (- x 1)) (/ 1 (^ (- x 1) 2)))", str);
}

// ============================================================================
// Edge Cases / No Decomposition
// ============================================================================

test "partial-fractions: 1/x (linear denom, no decomposition)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Already in simplest form
    const expr = try h.parseExpr(allocator, "(partial-fractions (/ 1 x) x)");
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
    // Should return as-is
    try testing.expectEqualStrings("(/ 1 x)", str);
}

test "partial-fractions: non-division expression" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Not a division - should return as-is
    const expr = try h.parseExpr(allocator, "(partial-fractions (+ x 1) x)");
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
    try testing.expectEqualStrings("(+ x 1)", str);
}
