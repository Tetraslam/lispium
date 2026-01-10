const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// diff-steps Tests
// ============================================================================

test "diff-steps: power rule" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(diff-steps (^ x 2) x)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return (steps "...")
    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items.len == 2);
    try testing.expect(lst.items[0].* == .symbol);
    try testing.expectEqualStrings("steps", lst.items[0].symbol);
    try testing.expect(lst.items[1].* == .owned_symbol);

    // Check that steps contain expected content
    const steps_str = lst.items[1].owned_symbol;
    try testing.expect(std.mem.indexOf(u8, steps_str, "Step 1") != null);
    try testing.expect(std.mem.indexOf(u8, steps_str, "Step 2") != null);
    try testing.expect(std.mem.indexOf(u8, steps_str, "Power rule") != null);
}

test "diff-steps: sum rule" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(diff-steps (+ x 1) x)");
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
    const steps_str = result.list.items[1].owned_symbol;
    try testing.expect(std.mem.indexOf(u8, steps_str, "Sum/Difference rule") != null);
}

// ============================================================================
// integrate-steps Tests
// ============================================================================

test "integrate-steps: basic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(integrate-steps x x)");
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
    try testing.expectEqualStrings("steps", lst.items[0].symbol);

    const steps_str = lst.items[1].owned_symbol;
    try testing.expect(std.mem.indexOf(u8, steps_str, "Step 1") != null);
    try testing.expect(std.mem.indexOf(u8, steps_str, "integral") != null);
    try testing.expect(std.mem.indexOf(u8, steps_str, "+ C") != null);
}

// ============================================================================
// simplify-steps Tests
// ============================================================================

test "simplify-steps: basic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(simplify-steps (+ x 0))");
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
    try testing.expectEqualStrings("steps", lst.items[0].symbol);

    const steps_str = lst.items[1].owned_symbol;
    try testing.expect(std.mem.indexOf(u8, steps_str, "Applicable simplification rules") != null);
    try testing.expect(std.mem.indexOf(u8, steps_str, "Simplified result") != null);
}

// ============================================================================
// solve-steps Tests
// ============================================================================

test "solve-steps: linear equation" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Solve x - 5 = 0, so x = 5
    const expr = try h.parseExpr(allocator, "(solve-steps (- x 5) x)");
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
    try testing.expectEqualStrings("steps", lst.items[0].symbol);

    const steps_str = lst.items[1].owned_symbol;
    try testing.expect(std.mem.indexOf(u8, steps_str, "Solve for x") != null);
    try testing.expect(std.mem.indexOf(u8, steps_str, "Solution") != null);
}
