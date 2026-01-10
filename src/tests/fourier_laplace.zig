const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Fourier Series Tests
// ============================================================================

test "fourier: constant function" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Fourier series of constant 1 should have a0 = 1, all other coefficients ~0
    const expr = try h.parseExpr(allocator, "(fourier 1 x 3)");
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
    // Should be (fourier-series a0 ((a1 b1) ...))
    const lst = result.list;
    try testing.expect(lst.items.len >= 2);
    try testing.expect(lst.items[0].* == .symbol);
    try testing.expectEqualStrings("fourier-series", lst.items[0].symbol);
}

test "fourier: x function" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Fourier series of x (odd function) should have a_n = 0, b_n != 0
    const expr = try h.parseExpr(allocator, "(fourier x x 3)");
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

test "fourier: x^2 function" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Fourier series of x^2 (even function)
    const expr = try h.parseExpr(allocator, "(fourier (^ x 2) x 3)");
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
// Laplace Transform Tests
// ============================================================================

test "laplace: L{1} = 1/s" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(laplace 1 t s)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should be (/ 1 s)
    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items.len == 3);
    try testing.expect(lst.items[0].* == .symbol);
    try testing.expectEqualStrings("/", lst.items[0].symbol);
}

test "laplace: L{t} = 1/s^2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(laplace t t s)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should be (/ 1 (^ s 2))
    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items[0].* == .symbol);
    try testing.expectEqualStrings("/", lst.items[0].symbol);
}

test "laplace: L{t^2} = 2/s^3" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(laplace (^ t 2) t s)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should be (/ 2 (^ s 3))
    try testing.expect(result.* == .list);
}

test "laplace: L{e^t} = 1/(s-1)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(laplace (exp t) t s)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should be (/ 1 (- s 1))
    try testing.expect(result.* == .list);
}

test "laplace: L{e^(at)} = 1/(s-a)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(laplace (exp (* 2 t)) t s)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should be (/ 1 (- s 2))
    try testing.expect(result.* == .list);
}

test "laplace: L{sin(at)} = a/(s^2 + a^2)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(laplace (sin (* 2 t)) t s)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should be (/ 2 (+ (^ s 2) (^ 2 2)))
    try testing.expect(result.* == .list);
}

test "laplace: L{cos(at)} = s/(s^2 + a^2)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(laplace (cos (* 3 t)) t s)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should be (/ s (+ (^ s 2) (^ 3 2)))
    try testing.expect(result.* == .list);
}

test "laplace: symbolic fallback" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Complex function that can't be transformed symbolically
    const expr = try h.parseExpr(allocator, "(laplace (^ (sin t) 2) t s)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return symbolic (laplace ...)
    try testing.expect(result.* == .list);
}

// ============================================================================
// Inverse Laplace Transform Tests
// ============================================================================

test "inv-laplace: L^{-1}{1/s} = 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(inv-laplace (/ 1 s) s t)");
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
    try testing.expectApproxEqAbs(@as(f64, 1), result.number, 1e-10);
}

test "inv-laplace: L^{-1}{1/s^2} = t" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(inv-laplace (/ 1 (^ s 2)) s t)");
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
    try testing.expectEqualStrings("t", result.symbol);
}

test "inv-laplace: L^{-1}{1/(s-a)} = e^(a*t)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(inv-laplace (/ 1 (- s 2)) s t)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should be (exp (* 2 t))
    try testing.expect(result.* == .list);
    try testing.expect(result.list.items[0].* == .symbol);
    try testing.expectEqualStrings("exp", result.list.items[0].symbol);
}

test "inv-laplace: symbolic fallback" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(inv-laplace (/ s (+ (^ s 2) 4)) s t)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return symbolic form
    try testing.expect(result.* == .list);
}
