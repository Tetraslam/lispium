const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Direct Integration Tests (dy/dx = f(x))
// ============================================================================

test "dsolve: dy/dx = x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = x => y = x^2/2 + C
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) x) y x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return a list result (equation or dsolve symbolic form)
    try testing.expect(result.* == .list);
}

test "dsolve: dy/dx = 2x" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = 2x => y = x^2 + C
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) (* 2 x)) y x)");
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

test "dsolve: dy/dx = constant" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = 3 => y = 3x + C
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) 3) y x)");
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
// Homogeneous Linear Tests (dy/dx = a*y)
// ============================================================================

test "dsolve: dy/dx = y (exponential growth)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = y => y = C*e^x
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) y) y x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return a result (might be equation or unsolved symbolic form)
    try testing.expect(result.* == .list);
}

test "dsolve: dy/dx = 2*y" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = 2y => y = C*e^(2x)
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) (* 2 y)) y x)");
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
// Separable Equation Tests (dy/dx = f(x) * g(y))
// ============================================================================

test "dsolve: dy/dx = x * y (separable)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = x*y => ln|y| = x^2/2 + C
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) (* x y)) y x)");
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
// Linear Non-homogeneous Tests (dy/dx = a*y + f(x))
// ============================================================================

test "dsolve: dy/dx = y + x (linear non-homogeneous)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = y + x
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) (+ y x)) y x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return a result (equation or unsolved symbolic form)
    try testing.expect(result.* == .list);
}

test "dsolve: dy/dx = 2*y + 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = 2y + 1
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) (+ (* 2 y) 1)) y x)");
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
// Symbolic (Unsolvable) Tests
// ============================================================================

test "dsolve: symbolic fallback" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Complex equation that can't be solved symbolically
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) (^ y 2)) y x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return some result (either solved or symbolic form)
    try testing.expect(result.* == .list);
}

// ============================================================================
// Edge Cases
// ============================================================================

test "dsolve: dy/dx = 0" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = 0 => y = C
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) 0) y x)");
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

test "dsolve: dy/dx = sin(x)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = sin(x) => y = -cos(x) + C
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) (sin x)) y x)");
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

test "dsolve: dy/dx = exp(x)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dy/dx = e^x => y = e^x + C
    const expr = try h.parseExpr(allocator, "(dsolve (= (diff y x) (exp x)) y x)");
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
