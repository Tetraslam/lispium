const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// to-cf Tests - Convert number to continued fraction
// ============================================================================

test "to-cf: integer" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(to-cf 5)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // (cf 5)
    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items.len >= 2);
    try testing.expect(lst.items[0].* == .symbol);
    try testing.expectEqualStrings("cf", lst.items[0].symbol);
    try testing.expectApproxEqAbs(@as(f64, 5), lst.items[1].number, 1e-10);
}

test "to-cf: rational 22/7 (approx pi)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 22/7 = 3.142857... = [3; 7]
    const expr = try h.parseExpr(allocator, "(to-cf 3.142857142857143)");
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
    const lst = result.list;
    try testing.expect(lst.items.len >= 2);
    try testing.expectApproxEqAbs(@as(f64, 3), lst.items[1].number, 1e-10);
}

test "to-cf: golden ratio phi" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // phi = (1 + sqrt(5))/2 = [1; 1, 1, 1, ...]
    const phi = (1.0 + @sqrt(5.0)) / 2.0;
    var buf: [64]u8 = undefined;
    const phi_str = std.fmt.bufPrint(&buf, "(to-cf {d})", .{phi}) catch unreachable;

    const expr = try h.parseExpr(allocator, phi_str);
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
    const lst = result.list;
    // Golden ratio has all 1s in CF
    try testing.expect(lst.items.len > 3);
    try testing.expectApproxEqAbs(@as(f64, 1), lst.items[1].number, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 1), lst.items[2].number, 1e-10);
}

// ============================================================================
// from-cf Tests - Evaluate continued fraction
// ============================================================================

test "from-cf: evaluate simple cf" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Parse the cf first
    const cf_expr = try h.parseExpr(allocator, "(to-cf 3.5)");
    defer {
        cf_expr.deinit(allocator);
        allocator.destroy(cf_expr);
    }

    const cf = try h.eval(cf_expr, &env);

    // Now evaluate the from-cf
    const from_cf_expr = try h.parseExpr(allocator, "(from-cf (to-cf 3.5))");
    defer {
        from_cf_expr.deinit(allocator);
        allocator.destroy(from_cf_expr);
    }

    // Clean up cf
    cf.deinit(allocator);
    allocator.destroy(cf);

    const result = try h.eval(from_cf_expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectApproxEqAbs(@as(f64, 3.5), result.number, 1e-10);
}

// ============================================================================
// cf-rational Tests - CF from numerator/denominator
// ============================================================================

test "cf-rational: 22/7" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(cf-rational 22 7)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // 22/7 = [3; 7]
    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items.len == 3); // cf, 3, 7
    try testing.expectApproxEqAbs(@as(f64, 3), lst.items[1].number, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 7), lst.items[2].number, 1e-10);
}

test "cf-rational: 355/113 (better pi approx)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(cf-rational 355 113)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // 355/113 = [3; 7, 16]
    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items.len == 4); // cf, 3, 7, 16
    try testing.expectApproxEqAbs(@as(f64, 3), lst.items[1].number, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 7), lst.items[2].number, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 16), lst.items[3].number, 1e-10);
}

// ============================================================================
// cf-convergent Tests - Get nth convergent
// ============================================================================

test "cf-convergent: convergents of 22/7" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // 0th convergent of [3; 7] should be 3/1
    const expr0 = try h.parseExpr(allocator, "(cf-convergent (cf-rational 22 7) 0)");
    defer {
        expr0.deinit(allocator);
        allocator.destroy(expr0);
    }

    const result0 = try h.eval(expr0, &env);
    defer {
        result0.deinit(allocator);
        allocator.destroy(result0);
    }

    try testing.expect(result0.* == .list);
    try testing.expect(result0.list.items.len == 3);
    try testing.expectApproxEqAbs(@as(f64, 3), result0.list.items[1].number, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 1), result0.list.items[2].number, 1e-10);

    // 1st convergent should be 22/7
    const expr1 = try h.parseExpr(allocator, "(cf-convergent (cf-rational 22 7) 1)");
    defer {
        expr1.deinit(allocator);
        allocator.destroy(expr1);
    }

    const result1 = try h.eval(expr1, &env);
    defer {
        result1.deinit(allocator);
        allocator.destroy(result1);
    }

    try testing.expect(result1.* == .list);
    try testing.expect(result1.list.items.len == 3);
    try testing.expectApproxEqAbs(@as(f64, 22), result1.list.items[1].number, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 7), result1.list.items[2].number, 1e-10);
}
