const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Memoization Tests
// ============================================================================

test "memoize: basic caching" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // First evaluation
    const expr1 = try h.parseExpr(allocator, "(memoize (+ 1 2))");
    defer {
        expr1.deinit(allocator);
        allocator.destroy(expr1);
    }

    const result1 = try h.eval(expr1, &env);
    defer {
        result1.deinit(allocator);
        allocator.destroy(result1);
    }

    try testing.expect(result1.* == .number);
    try testing.expectApproxEqAbs(@as(f64, 3), result1.number, 1e-10);

    // Second evaluation should use cache
    const expr2 = try h.parseExpr(allocator, "(memoize (+ 1 2))");
    defer {
        expr2.deinit(allocator);
        allocator.destroy(expr2);
    }

    const result2 = try h.eval(expr2, &env);
    defer {
        result2.deinit(allocator);
        allocator.destroy(result2);
    }

    try testing.expect(result2.* == .number);
    try testing.expectApproxEqAbs(@as(f64, 3), result2.number, 1e-10);

    // Clear the cache for other tests
    const clear_expr = try h.parseExpr(allocator, "(memo-clear)");
    defer {
        clear_expr.deinit(allocator);
        allocator.destroy(clear_expr);
    }
    const clear_result = try h.eval(clear_expr, &env);
    defer {
        clear_result.deinit(allocator);
        allocator.destroy(clear_result);
    }
}

test "memo-stats: count cached items" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Start fresh
    const clear_expr = try h.parseExpr(allocator, "(memo-clear)");
    defer {
        clear_expr.deinit(allocator);
        allocator.destroy(clear_expr);
    }
    const clear_result = try h.eval(clear_expr, &env);
    defer {
        clear_result.deinit(allocator);
        allocator.destroy(clear_result);
    }

    // Check initial count
    const stats1 = try h.parseExpr(allocator, "(memo-stats)");
    defer {
        stats1.deinit(allocator);
        allocator.destroy(stats1);
    }
    const result1 = try h.eval(stats1, &env);
    defer {
        result1.deinit(allocator);
        allocator.destroy(result1);
    }

    try testing.expect(result1.* == .number);
    try testing.expectApproxEqAbs(@as(f64, 0), result1.number, 1e-10);

    // Add an item
    const memo1 = try h.parseExpr(allocator, "(memoize (* 2 3))");
    defer {
        memo1.deinit(allocator);
        allocator.destroy(memo1);
    }
    const memo_result = try h.eval(memo1, &env);
    defer {
        memo_result.deinit(allocator);
        allocator.destroy(memo_result);
    }

    // Check count again
    const stats2 = try h.parseExpr(allocator, "(memo-stats)");
    defer {
        stats2.deinit(allocator);
        allocator.destroy(stats2);
    }
    const result2 = try h.eval(stats2, &env);
    defer {
        result2.deinit(allocator);
        allocator.destroy(result2);
    }

    try testing.expect(result2.* == .number);
    try testing.expectApproxEqAbs(@as(f64, 1), result2.number, 1e-10);

    // Clean up
    const final_clear = try h.parseExpr(allocator, "(memo-clear)");
    defer {
        final_clear.deinit(allocator);
        allocator.destroy(final_clear);
    }
    const final_result = try h.eval(final_clear, &env);
    defer {
        final_result.deinit(allocator);
        allocator.destroy(final_result);
    }
}

test "memo-clear: clears cache" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Add something to cache
    const memo_expr = try h.parseExpr(allocator, "(memoize (- 10 5))");
    defer {
        memo_expr.deinit(allocator);
        allocator.destroy(memo_expr);
    }
    const memo_result = try h.eval(memo_expr, &env);
    defer {
        memo_result.deinit(allocator);
        allocator.destroy(memo_result);
    }

    // Clear
    const clear_expr = try h.parseExpr(allocator, "(memo-clear)");
    defer {
        clear_expr.deinit(allocator);
        allocator.destroy(clear_expr);
    }
    const clear_result = try h.eval(clear_expr, &env);
    defer {
        clear_result.deinit(allocator);
        allocator.destroy(clear_result);
    }

    // Should return nil
    try testing.expect(clear_result.* == .list);

    // Stats should be 0
    const stats_expr = try h.parseExpr(allocator, "(memo-stats)");
    defer {
        stats_expr.deinit(allocator);
        allocator.destroy(stats_expr);
    }
    const stats_result = try h.eval(stats_expr, &env);
    defer {
        stats_result.deinit(allocator);
        allocator.destroy(stats_result);
    }

    try testing.expect(stats_result.* == .number);
    try testing.expectApproxEqAbs(@as(f64, 0), stats_result.number, 1e-10);
}
