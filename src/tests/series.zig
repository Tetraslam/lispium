const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Sum (Summation) Tests
// ============================================================================

test "sum: numeric bounds - sum of integers" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // sum i=1 to 5 of i = 1+2+3+4+5 = 15
    const expr = try h.parseExpr(allocator, "(sum i 1 5 i)");
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
    try testing.expectEqual(@as(f64, 15), result.number);
}

test "sum: numeric bounds - sum of squares" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // sum i=1 to 5 of i^2 = 1+4+9+16+25 = 55
    const expr = try h.parseExpr(allocator, "(sum i 1 5 (* i i))");
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
    try testing.expectEqual(@as(f64, 55), result.number);
}

test "sum: empty sum (start > end)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // sum i=5 to 1 of i = 0 (empty)
    const expr = try h.parseExpr(allocator, "(sum i 5 1 i)");
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

test "sum: symbolic upper bound" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // sum i=1 to n of i stays symbolic
    const expr = try h.parseExpr(allocator, "(sum i 1 n i)");
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
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(sum i 1 n i)", str);
}

test "sum: with power function" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // sum i=1 to 3 of i^3 = 1+8+27 = 36
    const expr = try h.parseExpr(allocator, "(sum i 1 3 (^ i 3))");
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
    try testing.expectEqual(@as(f64, 36), result.number);
}

// ============================================================================
// Product (Product Notation) Tests
// ============================================================================

test "product: factorial - product of 1 to 5" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // product i=1 to 5 of i = 1*2*3*4*5 = 120
    const expr = try h.parseExpr(allocator, "(product i 1 5 i)");
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
    try testing.expectEqual(@as(f64, 120), result.number);
}

test "product: empty product (start > end)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // product i=5 to 1 of i = 1 (empty product)
    const expr = try h.parseExpr(allocator, "(product i 5 1 i)");
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

test "product: powers of 2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // product i=1 to 4 of 2 = 2*2*2*2 = 16
    const expr = try h.parseExpr(allocator, "(product i 1 4 2)");
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
    try testing.expectEqual(@as(f64, 16), result.number);
}

test "product: symbolic upper bound" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // product i=1 to n of i stays symbolic
    const expr = try h.parseExpr(allocator, "(product i 1 n i)");
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
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(product i 1 n i)", str);
}

test "product: with expression body" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // product i=1 to 3 of (i+1) = 2*3*4 = 24
    const expr = try h.parseExpr(allocator, "(product i 1 3 (+ i 1))");
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
    try testing.expectEqual(@as(f64, 24), result.number);
}
