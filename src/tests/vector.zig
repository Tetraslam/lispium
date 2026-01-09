const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Vector Creation Tests
// ============================================================================

test "vector: creation" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(vector 1 2 3)");
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
    try testing.expectEqualStrings("(vector 1 2 3)", str);
}

// ============================================================================
// Dot Product Tests
// ============================================================================

test "vector: dot product numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (1,2,3) . (4,5,6) = 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
    const expr = try h.parseExpr(allocator, "(dot (vector 1 2 3) (vector 4 5 6))");
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
    try testing.expectEqual(@as(f64, 32), result.number);
}

test "vector: dot product 2D" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (3,4) . (3,4) = 9 + 16 = 25
    const expr = try h.parseExpr(allocator, "(dot (vector 3 4) (vector 3 4))");
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
    try testing.expectEqual(@as(f64, 25), result.number);
}

// ============================================================================
// Cross Product Tests
// ============================================================================

test "vector: cross product" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (1,0,0) x (0,1,0) = (0,0,1)
    const expr = try h.parseExpr(allocator, "(cross (vector 1 0 0) (vector 0 1 0))");
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
    try testing.expectEqualStrings("(vector 0 0 1)", str);
}

test "vector: cross product general" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (1,2,3) x (4,5,6) = (2*6-3*5, 3*4-1*6, 1*5-2*4) = (12-15, 12-6, 5-8) = (-3, 6, -3)
    const expr = try h.parseExpr(allocator, "(cross (vector 1 2 3) (vector 4 5 6))");
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
    try testing.expectEqualStrings("(vector -3 6 -3)", str);
}

// ============================================================================
// Norm Tests
// ============================================================================

test "vector: norm 3-4-5 triangle" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // ||(3,4)|| = sqrt(9+16) = 5
    const expr = try h.parseExpr(allocator, "(norm (vector 3 4))");
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

test "vector: norm unit vector" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // ||(1,0,0)|| = 1
    const expr = try h.parseExpr(allocator, "(norm (vector 1 0 0))");
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
