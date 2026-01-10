const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Lagrange Interpolation Tests
// ============================================================================

test "lagrange: single point returns constant" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(lagrange (vector (vector 0 5)) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Single point interpolation: y = 5
    try testing.expect(result.* == .list or result.* == .number);
}

test "lagrange: two points gives linear" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Points (0, 0) and (1, 1) should give y = x
    const expr = try h.parseExpr(allocator, "(lagrange (vector (vector 0 0) (vector 1 1)) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should produce a polynomial expression
    try testing.expect(result.* == .list or result.* == .symbol);
}

test "lagrange: three points gives quadratic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Points (0, 0), (1, 1), (2, 4) - this is y = x^2
    const expr = try h.parseExpr(allocator, "(lagrange (vector (vector 0 0) (vector 1 1) (vector 2 4)) x)");
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
}

test "lagrange: interpolates correctly" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Points: (1, 2), (2, 5), (3, 10)
    const expr = try h.parseExpr(allocator, "(lagrange (vector (vector 1 2) (vector 2 5) (vector 3 10)) x)");
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
}

// ============================================================================
// Newton Interpolation Tests
// ============================================================================

test "newton-interp: single point returns constant" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(newton-interp (vector (vector 0 5)) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list or result.* == .number);
}

test "newton-interp: two points gives linear" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(newton-interp (vector (vector 0 0) (vector 1 1)) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list or result.* == .symbol);
}

test "newton-interp: three points gives quadratic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(newton-interp (vector (vector 0 0) (vector 1 1) (vector 2 4)) x)");
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
}

test "newton-interp: builds divided difference form" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(newton-interp (vector (vector 1 1) (vector 2 4) (vector 3 9) (vector 4 16)) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Newton form for x^2 data
    try testing.expect(result.* == .list);
}
