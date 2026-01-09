const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Assumptions System Tests
// ============================================================================

test "assumptions: assume positive" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Assume x is positive
    const expr = try h.parseExpr(allocator, "(assume x positive)");
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
    try testing.expectEqualStrings("x", str);
}

test "assumptions: is positive" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Assume x is positive, then check
    const assume_expr = try h.parseExpr(allocator, "(assume x positive)");
    defer {
        assume_expr.deinit(allocator);
        allocator.destroy(assume_expr);
    }

    const assume_result = try h.eval(assume_expr, &env);
    defer {
        assume_result.deinit(allocator);
        allocator.destroy(assume_result);
    }

    const is_expr = try h.parseExpr(allocator, "(is? x positive)");
    defer {
        is_expr.deinit(allocator);
        allocator.destroy(is_expr);
    }

    const is_result = try h.eval(is_expr, &env);
    defer {
        is_result.deinit(allocator);
        allocator.destroy(is_result);
    }

    try testing.expect(is_result.* == .number);
    try testing.expectEqual(@as(f64, 1), is_result.number);
}

test "assumptions: is real after positive" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Assume x is positive - should also be real
    const assume_expr = try h.parseExpr(allocator, "(assume x positive)");
    defer {
        assume_expr.deinit(allocator);
        allocator.destroy(assume_expr);
    }

    const assume_result = try h.eval(assume_expr, &env);
    defer {
        assume_result.deinit(allocator);
        allocator.destroy(assume_result);
    }

    const is_expr = try h.parseExpr(allocator, "(is? x real)");
    defer {
        is_expr.deinit(allocator);
        allocator.destroy(is_expr);
    }

    const is_result = try h.eval(is_expr, &env);
    defer {
        is_result.deinit(allocator);
        allocator.destroy(is_result);
    }

    try testing.expect(is_result.* == .number);
    try testing.expectEqual(@as(f64, 1), is_result.number);
}

test "assumptions: is negative false for unknown" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const is_expr = try h.parseExpr(allocator, "(is? y negative)");
    defer {
        is_expr.deinit(allocator);
        allocator.destroy(is_expr);
    }

    const is_result = try h.eval(is_expr, &env);
    defer {
        is_result.deinit(allocator);
        allocator.destroy(is_result);
    }

    try testing.expect(is_result.* == .number);
    try testing.expectEqual(@as(f64, 0), is_result.number);
}

test "assumptions: integer implies real" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const assume_expr = try h.parseExpr(allocator, "(assume n integer)");
    defer {
        assume_expr.deinit(allocator);
        allocator.destroy(assume_expr);
    }

    const assume_result = try h.eval(assume_expr, &env);
    defer {
        assume_result.deinit(allocator);
        allocator.destroy(assume_result);
    }

    // Check integer
    const is_int_expr = try h.parseExpr(allocator, "(is? n integer)");
    defer {
        is_int_expr.deinit(allocator);
        allocator.destroy(is_int_expr);
    }

    const is_int_result = try h.eval(is_int_expr, &env);
    defer {
        is_int_result.deinit(allocator);
        allocator.destroy(is_int_result);
    }

    try testing.expect(is_int_result.* == .number);
    try testing.expectEqual(@as(f64, 1), is_int_result.number);

    // Check real (should also be true)
    const is_real_expr = try h.parseExpr(allocator, "(is? n real)");
    defer {
        is_real_expr.deinit(allocator);
        allocator.destroy(is_real_expr);
    }

    const is_real_result = try h.eval(is_real_expr, &env);
    defer {
        is_real_result.deinit(allocator);
        allocator.destroy(is_real_result);
    }

    try testing.expect(is_real_result.* == .number);
    try testing.expectEqual(@as(f64, 1), is_real_result.number);
}

test "assumptions: nonzero from positive" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const assume_expr = try h.parseExpr(allocator, "(assume x positive)");
    defer {
        assume_expr.deinit(allocator);
        allocator.destroy(assume_expr);
    }

    const assume_result = try h.eval(assume_expr, &env);
    defer {
        assume_result.deinit(allocator);
        allocator.destroy(assume_result);
    }

    // Check nonzero (should be true since positive)
    const is_expr = try h.parseExpr(allocator, "(is? x nonzero)");
    defer {
        is_expr.deinit(allocator);
        allocator.destroy(is_expr);
    }

    const is_result = try h.eval(is_expr, &env);
    defer {
        is_result.deinit(allocator);
        allocator.destroy(is_result);
    }

    try testing.expect(is_result.* == .number);
    try testing.expectEqual(@as(f64, 1), is_result.number);
}

test "assumptions: even implies integer" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const assume_expr = try h.parseExpr(allocator, "(assume n even)");
    defer {
        assume_expr.deinit(allocator);
        allocator.destroy(assume_expr);
    }

    const assume_result = try h.eval(assume_expr, &env);
    defer {
        assume_result.deinit(allocator);
        allocator.destroy(assume_result);
    }

    // Check even
    const is_even_expr = try h.parseExpr(allocator, "(is? n even)");
    defer {
        is_even_expr.deinit(allocator);
        allocator.destroy(is_even_expr);
    }

    const is_even_result = try h.eval(is_even_expr, &env);
    defer {
        is_even_result.deinit(allocator);
        allocator.destroy(is_even_result);
    }

    try testing.expect(is_even_result.* == .number);
    try testing.expectEqual(@as(f64, 1), is_even_result.number);

    // Check integer (should also be true)
    const is_int_expr = try h.parseExpr(allocator, "(is? n integer)");
    defer {
        is_int_expr.deinit(allocator);
        allocator.destroy(is_int_expr);
    }

    const is_int_result = try h.eval(is_int_expr, &env);
    defer {
        is_int_result.deinit(allocator);
        allocator.destroy(is_int_result);
    }

    try testing.expect(is_int_result.* == .number);
    try testing.expectEqual(@as(f64, 1), is_int_result.number);
}
