const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Gamma Function Tests
// ============================================================================

test "gamma: factorial integers" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // gamma(n) = (n-1)! for positive integers
    // gamma(5) = 4! = 24
    const expr = try h.parseExpr(allocator, "(gamma 5)");
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
    try testing.expectApproxEqAbs(@as(f64, 24), result.number, 1e-10);
}

test "gamma: half integer" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // gamma(0.5) = sqrt(pi)
    const expr = try h.parseExpr(allocator, "(gamma 0.5)");
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
    try testing.expectApproxEqAbs(@sqrt(std.math.pi), result.number, 1e-10);
}

test "gamma: gamma(1) = 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(gamma 1)");
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
    try testing.expectApproxEqAbs(@as(f64, 1), result.number, 1e-10);
}

test "gamma: gamma(2) = 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(gamma 2)");
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
    try testing.expectApproxEqAbs(@as(f64, 1), result.number, 1e-10);
}

test "gamma: symbolic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(gamma x)");
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
    try testing.expectEqualStrings("(gamma x)", str);
}

// ============================================================================
// Beta Function Tests
// ============================================================================

test "beta: B(1,1) = 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(beta 1 1)");
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
    try testing.expectApproxEqAbs(@as(f64, 1), result.number, 1e-10);
}

test "beta: B(2,2) = 1/6" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // B(2,2) = Gamma(2)*Gamma(2)/Gamma(4) = 1*1/6 = 1/6
    const expr = try h.parseExpr(allocator, "(beta 2 2)");
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
    try testing.expectApproxEqAbs(1.0 / 6.0, result.number, 1e-10);
}

test "beta: B(0.5, 0.5) = pi" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // B(0.5, 0.5) = Gamma(0.5)^2/Gamma(1) = pi
    const expr = try h.parseExpr(allocator, "(beta 0.5 0.5)");
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
    try testing.expectApproxEqAbs(std.math.pi, result.number, 1e-10);
}

test "beta: symbolic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(beta a b)");
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
    try testing.expectEqualStrings("(beta a b)", str);
}

// ============================================================================
// Error Function Tests
// ============================================================================

test "erf: erf(0) = 0" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(erf 0)");
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
    try testing.expectApproxEqAbs(@as(f64, 0), result.number, 1e-8);
}

test "erf: large positive" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // erf(3) should be very close to 1
    const expr = try h.parseExpr(allocator, "(erf 3)");
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
    try testing.expect(result.number > 0.999);
}

test "erf: odd function" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // erf(-x) = -erf(x)
    const expr1 = try h.parseExpr(allocator, "(erf 1)");
    defer {
        expr1.deinit(allocator);
        allocator.destroy(expr1);
    }

    const result1 = try h.eval(expr1, &env);
    defer {
        result1.deinit(allocator);
        allocator.destroy(result1);
    }

    const expr2 = try h.parseExpr(allocator, "(erf -1)");
    defer {
        expr2.deinit(allocator);
        allocator.destroy(expr2);
    }

    const result2 = try h.eval(expr2, &env);
    defer {
        result2.deinit(allocator);
        allocator.destroy(result2);
    }

    try testing.expect(result1.* == .number);
    try testing.expect(result2.* == .number);
    try testing.expectApproxEqAbs(-result1.number, result2.number, 1e-10);
}

test "erf: symbolic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(erf x)");
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
    try testing.expectEqualStrings("(erf x)", str);
}

// ============================================================================
// Complementary Error Function Tests
// ============================================================================

test "erfc: erfc(0) = 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(erfc 0)");
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
    try testing.expectApproxEqAbs(@as(f64, 1), result.number, 1e-8);
}

test "erfc: erf + erfc = 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // erf(x) + erfc(x) = 1
    const expr = try h.parseExpr(allocator, "(+ (erf 1.5) (erfc 1.5))");
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
    try testing.expectApproxEqAbs(@as(f64, 1), result.number, 1e-10);
}

// ============================================================================
// Bessel Function of First Kind Tests
// ============================================================================

test "besselj: J_0(0) = 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(besselj 0 0)");
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
    try testing.expectApproxEqAbs(@as(f64, 1), result.number, 1e-10);
}

test "besselj: J_1(0) = 0" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(besselj 1 0)");
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
    try testing.expectApproxEqAbs(@as(f64, 0), result.number, 1e-10);
}

test "besselj: J_0(2.4048) near zero" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // First zero of J_0 is approximately 2.4048
    const expr = try h.parseExpr(allocator, "(besselj 0 2.4048)");
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
    try testing.expect(@abs(result.number) < 0.001);
}

test "besselj: symbolic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(besselj n x)");
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
    try testing.expectEqualStrings("(besselj n x)", str);
}

// ============================================================================
// Bessel Function of Second Kind Tests
// ============================================================================

test "bessely: Y_0 at small value" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Y_0(1) is approximately -0.0882569642
    const expr = try h.parseExpr(allocator, "(bessely 0 1)");
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
    try testing.expectApproxEqAbs(@as(f64, 0.0882569642), result.number, 0.01);
}

test "bessely: symbolic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(bessely n x)");
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
    try testing.expectEqualStrings("(bessely n x)", str);
}

// ============================================================================
// Digamma Function Tests
// ============================================================================

test "digamma: psi(1) = -gamma" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // psi(1) = -gamma (Euler-Mascheroni constant)
    const euler_gamma = 0.5772156649015329;
    const expr = try h.parseExpr(allocator, "(digamma 1)");
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
    try testing.expectApproxEqAbs(-euler_gamma, result.number, 1e-6);
}

test "digamma: recurrence psi(x+1) = psi(x) + 1/x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // psi(3) = psi(2) + 1/2
    const expr1 = try h.parseExpr(allocator, "(digamma 3)");
    defer {
        expr1.deinit(allocator);
        allocator.destroy(expr1);
    }

    const result1 = try h.eval(expr1, &env);
    defer {
        result1.deinit(allocator);
        allocator.destroy(result1);
    }

    const expr2 = try h.parseExpr(allocator, "(+ (digamma 2) 0.5)");
    defer {
        expr2.deinit(allocator);
        allocator.destroy(expr2);
    }

    const result2 = try h.eval(expr2, &env);
    defer {
        result2.deinit(allocator);
        allocator.destroy(result2);
    }

    try testing.expect(result1.* == .number);
    try testing.expect(result2.* == .number);
    try testing.expectApproxEqAbs(result1.number, result2.number, 1e-10);
}

test "digamma: symbolic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(digamma x)");
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
    try testing.expectEqualStrings("(digamma x)", str);
}

// ============================================================================
// Integration Tests - Combinations
// ============================================================================

test "gamma beta relation: B(a,b) = Gamma(a)*Gamma(b)/Gamma(a+b)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Compute B(3,4) directly
    const expr1 = try h.parseExpr(allocator, "(beta 3 4)");
    defer {
        expr1.deinit(allocator);
        allocator.destroy(expr1);
    }

    const result1 = try h.eval(expr1, &env);
    defer {
        result1.deinit(allocator);
        allocator.destroy(result1);
    }

    // Compute via gamma: Gamma(3)*Gamma(4)/Gamma(7) = 2*6/720 = 1/60
    const expr2 = try h.parseExpr(allocator, "(/ (* (gamma 3) (gamma 4)) (gamma 7))");
    defer {
        expr2.deinit(allocator);
        allocator.destroy(expr2);
    }

    const result2 = try h.eval(expr2, &env);
    defer {
        result2.deinit(allocator);
        allocator.destroy(result2);
    }

    try testing.expect(result1.* == .number);
    try testing.expect(result2.* == .number);
    try testing.expectApproxEqAbs(result1.number, result2.number, 1e-10);
}
