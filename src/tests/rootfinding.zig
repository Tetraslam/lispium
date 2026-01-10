const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Newton-Raphson Tests
// ============================================================================

test "newton-raphson: find root of x^2 - 4 near 3" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 4 = 0, root at x = 2
    const expr = try h.parseExpr(allocator, "(newton-raphson (- (^ x 2) 4) x 3)");
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
    try testing.expectApproxEqAbs(@as(f64, 2), result.number, 1e-6);
}

test "newton-raphson: find root of x^3 - 8 near 3" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^3 - 8 = 0, root at x = 2
    const expr = try h.parseExpr(allocator, "(newton-raphson (- (^ x 3) 8) x 3)");
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
    try testing.expectApproxEqAbs(@as(f64, 2), result.number, 1e-6);
}

test "newton-raphson: find sqrt(2) via x^2 - 2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(newton-raphson (- (^ x 2) 2) x 1.5)");
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
    try testing.expectApproxEqAbs(@sqrt(@as(f64, 2)), result.number, 1e-6);
}

test "newton-raphson: find root of x^4 - 16 near 2.5" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^4 - 16 = 0, root at x = 2
    const expr = try h.parseExpr(allocator, "(newton-raphson (- (^ x 4) 16) x 2.5)");
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
    try testing.expectApproxEqAbs(@as(f64, 2), result.number, 1e-6);
}

// ============================================================================
// Bisection Method Tests
// ============================================================================

test "bisection: find root of x^2 - 4 in [0, 3]" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 4 = 0, root at x = 2
    const expr = try h.parseExpr(allocator, "(bisection (- (^ x 2) 4) x 0 3)");
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
    try testing.expectApproxEqAbs(@as(f64, 2), result.number, 1e-6);
}

test "bisection: find root of x^3 - 27 in [2, 4]" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^3 - 27 = 0, root at x = 3
    const expr = try h.parseExpr(allocator, "(bisection (- (^ x 3) 27) x 2 4)");
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
    try testing.expectApproxEqAbs(@as(f64, 3), result.number, 1e-6);
}

test "bisection: find sqrt(3) via x^2 - 3" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(bisection (- (^ x 2) 3) x 1 2)");
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
    try testing.expectApproxEqAbs(@sqrt(@as(f64, 3)), result.number, 1e-6);
}

test "bisection: find root of x^5 - 32 in [1, 3]" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^5 - 32 = 0, root at x = 2
    const expr = try h.parseExpr(allocator, "(bisection (- (^ x 5) 32) x 1 3)");
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
    try testing.expectApproxEqAbs(@as(f64, 2), result.number, 1e-6);
}

test "bisection: negative root in [-3, 0]" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // x^2 - 4 = 0, root at x = -2
    const expr = try h.parseExpr(allocator, "(bisection (- (^ x 2) 4) x -3 0)");
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
    try testing.expectApproxEqAbs(@as(f64, -2), result.number, 1e-6);
}
