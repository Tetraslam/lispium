const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Collect Terms Tests
// ============================================================================

test "collect: simple numeric coefficients" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (+ (* 2 x) (* 3 x)) -> (* 5 x)
    const expr = try h.parseExpr(allocator, "(collect (+ (* 2 x) (* 3 x)) x)");
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
    try testing.expectEqualStrings("(* 5 x)", str);
}

test "collect: with constant term" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (+ (* 2 x) (* 3 x) 5) -> (+ (* 5 x) 5)
    const expr = try h.parseExpr(allocator, "(collect (+ (* 2 x) (* 3 x) 5) x)");
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
    try testing.expectEqualStrings("(+ (* 5 x) 5)", str);
}

test "collect: symbolic coefficients" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (+ (* a x) (* b x)) -> (* (+ a b) x)
    const expr = try h.parseExpr(allocator, "(collect (+ (* a x) (* b x)) x)");
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
    try testing.expectEqualStrings("(* (+ a b) x)", str);
}

test "collect: symbolic with constant" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (+ (* a x) (* b x) y) -> (+ (* (+ a b) x) y)
    const expr = try h.parseExpr(allocator, "(collect (+ (* a x) (* b x) y) x)");
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
    try testing.expectEqualStrings("(+ (* (+ a b) x) y)", str);
}

test "collect: just x terms" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (+ x x x) -> (* 3 x)
    const expr = try h.parseExpr(allocator, "(collect (+ x x x) x)");
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
    try testing.expectEqualStrings("(* 3 x)", str);
}

test "collect: single term returns as-is" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(collect (* 5 x) x)");
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
    try testing.expectEqualStrings("(* 5 x)", str);
}
