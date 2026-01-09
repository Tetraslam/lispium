const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// LaTeX Basic Tests
// ============================================================================

test "latex: number" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex 42)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("42", result.owned_symbol);
}

test "latex: variable" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("x", result.owned_symbol);
}

test "latex: pi" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex pi)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("\\pi", result.owned_symbol);
}

// ============================================================================
// LaTeX Operator Tests
// ============================================================================

test "latex: addition" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex (+ x 1))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("x + 1", result.owned_symbol);
}

test "latex: multiplication" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex (* 2 x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("2 \\cdot x", result.owned_symbol);
}

test "latex: fraction" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex (/ 1 x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("\\frac{1}{x}", result.owned_symbol);
}

test "latex: power" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex (^ x 2))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("x^{2}", result.owned_symbol);
}

// ============================================================================
// LaTeX Function Tests
// ============================================================================

test "latex: sqrt" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Note: (sqrt x) evaluates to (^ x 0.5) before latex conversion
    // So the LaTeX output is x^{0.5} not \sqrt{x}
    const expr = try h.parseExpr(allocator, "(latex (sqrt x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("x^{0.5}", result.owned_symbol);
}

test "latex: sin" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex (sin x))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("\\sin{x}", result.owned_symbol);
}

// ============================================================================
// LaTeX Matrix Tests
// ============================================================================

test "latex: matrix" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex (matrix (1 2) (3 4)))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("\\begin{pmatrix}1 & 2 \\\\ 3 & 4\\end{pmatrix}", result.owned_symbol);
}

test "latex: vector" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex (vector 1 2 3))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("\\begin{pmatrix}1 \\\\ 2 \\\\ 3\\end{pmatrix}", result.owned_symbol);
}
