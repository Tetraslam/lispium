const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// GF(p) Creation Tests
// ============================================================================

test "gf: create element" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(gf 3 7)");
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
    try testing.expectEqualStrings("(gf 3 7)", str);
}

test "gf: normalize to field" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 10 mod 7 = 3
    const expr = try h.parseExpr(allocator, "(gf 10 7)");
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
    try testing.expectEqualStrings("(gf 3 7)", str);
}

// ============================================================================
// GF(p) Addition Tests
// ============================================================================

test "gf: addition" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 3 + 5 = 8 mod 7 = 1
    const expr = try h.parseExpr(allocator, "(gf+ (gf 3 7) (gf 5 7))");
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
    try testing.expectEqualStrings("(gf 1 7)", str);
}

// ============================================================================
// GF(p) Multiplication Tests
// ============================================================================

test "gf: multiplication" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 3 * 4 = 12 mod 7 = 5
    const expr = try h.parseExpr(allocator, "(gf* (gf 3 7) (gf 4 7))");
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
    try testing.expectEqualStrings("(gf 5 7)", str);
}

// ============================================================================
// GF(p) Inverse Tests
// ============================================================================

test "gf: multiplicative inverse" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // inv(3) in GF(7): 3 * x = 1 mod 7, x = 5 (since 3*5=15=1 mod 7)
    const expr = try h.parseExpr(allocator, "(gf-inv (gf 3 7))");
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
    try testing.expectEqualStrings("(gf 5 7)", str);
}

test "gf: inverse times original is 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 3 * inv(3) = 1 in GF(7)
    const expr = try h.parseExpr(allocator, "(gf* (gf 3 7) (gf-inv (gf 3 7)))");
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
    try testing.expectEqualStrings("(gf 1 7)", str);
}

// ============================================================================
// GF(p) Division Tests
// ============================================================================

test "gf: division" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 6 / 2 = 3 in GF(7)
    const expr = try h.parseExpr(allocator, "(gf/ (gf 6 7) (gf 2 7))");
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
    try testing.expectEqualStrings("(gf 3 7)", str);
}

// ============================================================================
// GF(p) Exponentiation Tests
// ============================================================================

test "gf: exponentiation" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 2^3 = 8 mod 7 = 1
    const expr = try h.parseExpr(allocator, "(gf^ (gf 2 7) 3)");
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
    try testing.expectEqualStrings("(gf 1 7)", str);
}

test "gf: Fermat's little theorem" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // a^(p-1) = 1 for a != 0 in GF(p)
    // 3^6 = 1 in GF(7)
    const expr = try h.parseExpr(allocator, "(gf^ (gf 3 7) 6)");
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
    try testing.expectEqualStrings("(gf 1 7)", str);
}

// ============================================================================
// GF(p) Subtraction and Negation Tests
// ============================================================================

test "gf: subtraction" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 2 - 5 = -3 mod 7 = 4
    const expr = try h.parseExpr(allocator, "(gf- (gf 2 7) (gf 5 7))");
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
    try testing.expectEqualStrings("(gf 4 7)", str);
}

test "gf: additive inverse" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // neg(3) = -3 mod 7 = 4
    const expr = try h.parseExpr(allocator, "(gf-neg (gf 3 7))");
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
    try testing.expectEqualStrings("(gf 4 7)", str);
}
