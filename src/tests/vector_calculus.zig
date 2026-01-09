const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Gradient Tests
// ============================================================================

test "gradient of x^2 + y^2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // gradient of x^2 + y^2 = (2x, 2y)
    const expr = try h.parseExpr(allocator, "(gradient (+ (^ x 2) (^ y 2)) (vector x y))");
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
    try testing.expectEqualStrings("(vector (* 2 x) (* 2 y))", str);
}

test "gradient of x^2*y" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // gradient of x^2*y = (2xy, x^2)
    const expr = try h.parseExpr(allocator, "(grad (* (^ x 2) y) (vector x y))");
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
    // d/dx(x^2*y) = y*(2x), d/dy(x^2*y) = x^2
    try testing.expectEqualStrings("(vector (* y (* 2 x)) (^ x 2))", str);
}

// ============================================================================
// Divergence Tests
// ============================================================================

test "divergence of (x, y)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // div(x, y) = dx/dx + dy/dy = 1 + 1 = 2
    const expr = try h.parseExpr(allocator, "(divergence (vector x y) (vector x y))");
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

test "divergence of (x^2, y^2, z^2)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // divergence(x^2, y^2, z^2) = 2x + 2y + 2z
    const expr = try h.parseExpr(allocator, "(divergence (vector (^ x 2) (^ y 2) (^ z 2)) (vector x y z))");
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
    try testing.expectEqualStrings("(+ (* 2 x) (* 2 y) (* 2 z))", str);
}

// ============================================================================
// Curl Tests
// ============================================================================

test "curl of (y, -x, 0)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // curl(y, -x, 0) = (0 - 0, 0 - 0, -1 - 1) = (0, 0, -2)
    const expr = try h.parseExpr(allocator, "(curl (vector y (* -1 x) 0) (vector x y z))");
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
    try testing.expectEqualStrings("(vector 0 0 -2)", str);
}

test "curl of (x, y, z)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // curl of position vector is zero
    const expr = try h.parseExpr(allocator, "(curl (vector x y z) (vector x y z))");
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
    try testing.expectEqualStrings("(vector 0 0 0)", str);
}

// ============================================================================
// Laplacian Tests
// ============================================================================

test "laplacian of x^2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // laplacian of x^2 in 1D = d²(x²)/dx² = 2
    const expr = try h.parseExpr(allocator, "(laplacian (^ x 2) (vector x))");
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

test "laplacian of sin(x)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // laplacian of sin(x) = -sin(x)
    const expr = try h.parseExpr(allocator, "(laplacian (sin x) (vector x))");
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
    try testing.expectEqualStrings("(* -1 (sin x))", str);
}
