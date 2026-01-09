const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Quaternion Creation Tests
// ============================================================================

test "quaternion: create" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(quat 1 2 3 4)");
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
    try testing.expectEqualStrings("(quat 1 2 3 4)", str);
}

// ============================================================================
// Quaternion Addition Tests
// ============================================================================

test "quaternion: addition" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (1 + 2i + 3j + 4k) + (5 + 6i + 7j + 8k) = (6 + 8i + 10j + 12k)
    const expr = try h.parseExpr(allocator, "(quat+ (quat 1 2 3 4) (quat 5 6 7 8))");
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
    try testing.expectEqualStrings("(quat 6 8 10 12)", str);
}

// ============================================================================
// Quaternion Multiplication Tests
// ============================================================================

test "quaternion: i*j = k" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // i * j = k, so (0,1,0,0) * (0,0,1,0) = (0,0,0,1)
    const expr = try h.parseExpr(allocator, "(quat* (quat 0 1 0 0) (quat 0 0 1 0))");
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
    try testing.expectEqualStrings("(quat 0 0 0 1)", str);
}

test "quaternion: j*i = -k" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // j * i = -k (non-commutative)
    const expr = try h.parseExpr(allocator, "(quat* (quat 0 0 1 0) (quat 0 1 0 0))");
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
    try testing.expectEqualStrings("(quat 0 0 0 -1)", str);
}

test "quaternion: i^2 = -1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // i * i = -1
    const expr = try h.parseExpr(allocator, "(quat* (quat 0 1 0 0) (quat 0 1 0 0))");
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
    try testing.expectEqualStrings("(quat -1 0 0 0)", str);
}

// ============================================================================
// Quaternion Conjugate Tests
// ============================================================================

test "quaternion: conjugate" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // conj(1 + 2i + 3j + 4k) = 1 - 2i - 3j - 4k
    const expr = try h.parseExpr(allocator, "(quat-conj (quat 1 2 3 4))");
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
    try testing.expectEqualStrings("(quat 1 -2 -3 -4)", str);
}

// ============================================================================
// Quaternion Norm Tests
// ============================================================================

test "quaternion: norm" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // |1 + 0i + 0j + 0k| = 1
    const expr = try h.parseExpr(allocator, "(quat-norm (quat 1 0 0 0))");
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

test "quaternion: norm unit quaternion" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // |0 + 1i + 0j + 0k| = 1
    const expr = try h.parseExpr(allocator, "(quat-norm (quat 0 1 0 0))");
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

// ============================================================================
// Quaternion Inverse Tests
// ============================================================================

test "quaternion: inverse identity" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // inv(1) = 1
    const expr = try h.parseExpr(allocator, "(quat-inv (quat 1 0 0 0))");
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
    // The conjugate formula produces -0 for imaginary parts when negating 0
    try testing.expectEqualStrings("(quat 1 -0 -0 -0)", str);
}

// ============================================================================
// Quaternion Part Extraction Tests
// ============================================================================

test "quaternion: scalar part" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(quat-scalar (quat 5 2 3 4))");
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

test "quaternion: vector part" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(quat-vector (quat 1 2 3 4))");
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
    try testing.expectEqualStrings("(vector 2 3 4)", str);
}
