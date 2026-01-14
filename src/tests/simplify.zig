const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

test "simplify: x + 0 = x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (+ x 0))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "simplify: 0 + x = x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (+ 0 x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "simplify: x * 1 = x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (* x 1))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "simplify: x * 0 = 0" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (* x 0))");
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

test "simplify: x - x = 0" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (- x x))");
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

test "simplify: x / x = 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (/ x x))");
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

test "simplify: x + x = 2*x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (+ x x))");
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
    try testing.expectEqualStrings("(* 2 x)", str);
}

test "simplify: numeric computation" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (+ 2 3))");
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

test "simplify: x^0 = 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (^ x 0))");
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

test "simplify: x^1 = x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (^ x 1))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .symbol);
    try testing.expectEqualStrings("x", result.symbol);
}

test "simplify: 2x + 3x = 5x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify (+ (* 2 x) (* 3 x)))");
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
