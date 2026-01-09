const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Trig Identity Tests
// ============================================================================

test "trig: sin(0) = 0" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(sin 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.symbolic.simplify(expr, allocator);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "trig: cos(0) = 1" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(cos 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.symbolic.simplify(expr, allocator);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "trig: tan(0) = 0" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(tan 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.symbolic.simplify(expr, allocator);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

// ============================================================================
// Log Identity Tests
// ============================================================================

test "log: exp(0) = 1" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(exp 0)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.symbolic.simplify(expr, allocator);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "log: ln(1) = 0" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(ln 1)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.symbolic.simplify(expr, allocator);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 0), result.number);
}

test "log: ln(e) = 1" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(ln e)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.symbolic.simplify(expr, allocator);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "log: exp(ln(x)) = x" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(exp (ln x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.symbolic.simplify(expr, allocator);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "log: ln(exp(x)) = x" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(ln (exp x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.symbolic.simplify(expr, allocator);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "log: ln(x^n) = n*ln(x)" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(ln (^ x 3))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.symbolic.simplify(expr, allocator);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 3 (ln x))", str);
}
