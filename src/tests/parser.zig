const std = @import("std");
const testing = std.testing;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const h = @import("helpers.zig");

// ============================================================================
// Tokenizer Tests
// ============================================================================

test "tokenizer: basic tokens" {
    var tokenizer = Tokenizer.init("(+ 1 2)");
    try testing.expectEqualStrings("(", tokenizer.next().?);
    try testing.expectEqualStrings("+", tokenizer.next().?);
    try testing.expectEqualStrings("1", tokenizer.next().?);
    try testing.expectEqualStrings("2", tokenizer.next().?);
    try testing.expectEqualStrings(")", tokenizer.next().?);
    try testing.expectEqual(@as(?[]const u8, null), tokenizer.next());
}

test "tokenizer: nested expressions" {
    var tokenizer = Tokenizer.init("(+ (* x 2) y)");
    const expected = [_][]const u8{ "(", "+", "(", "*", "x", "2", ")", "y", ")" };
    for (expected) |exp| {
        try testing.expectEqualStrings(exp, tokenizer.next().?);
    }
    try testing.expectEqual(@as(?[]const u8, null), tokenizer.next());
}

test "tokenizer: floating point numbers" {
    var tokenizer = Tokenizer.init("(+ 3.14 2.71)");
    try testing.expectEqualStrings("(", tokenizer.next().?);
    try testing.expectEqualStrings("+", tokenizer.next().?);
    try testing.expectEqualStrings("3.14", tokenizer.next().?);
    try testing.expectEqualStrings("2.71", tokenizer.next().?);
    try testing.expectEqualStrings(")", tokenizer.next().?);
}

// ============================================================================
// Parser Tests
// ============================================================================

test "parser: number" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "42");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.* == .number);
    try testing.expectEqual(@as(f64, 42), expr.number);
}

test "parser: symbol" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "x");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.* == .symbol);
    try testing.expectEqualStrings("x", expr.symbol);
}

test "parser: simple list" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(+ 1 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.* == .list);
    try testing.expectEqual(@as(usize, 3), expr.list.items.len);
    try testing.expect(expr.list.items[0].* == .symbol);
    try testing.expectEqualStrings("+", expr.list.items[0].symbol);
    try testing.expect(expr.list.items[1].* == .number);
    try testing.expectEqual(@as(f64, 1), expr.list.items[1].number);
}

test "parser: nested list" {
    const allocator = testing.allocator;

    const expr = try h.parseExpr(allocator, "(+ (* 2 3) 4)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.* == .list);
    try testing.expectEqual(@as(usize, 3), expr.list.items.len);
    // Second element should be (* 2 3)
    try testing.expect(expr.list.items[1].* == .list);
    try testing.expectEqual(@as(usize, 3), expr.list.items[1].list.items.len);
}

// ============================================================================
// Expression Equality Tests
// ============================================================================

test "exprEqual: numbers" {
    const allocator = testing.allocator;

    const a = try h.parseExpr(allocator, "42");
    defer {
        a.deinit(allocator);
        allocator.destroy(a);
    }
    const b = try h.parseExpr(allocator, "42");
    defer {
        b.deinit(allocator);
        allocator.destroy(b);
    }
    const c = try h.parseExpr(allocator, "43");
    defer {
        c.deinit(allocator);
        allocator.destroy(c);
    }

    try testing.expect(h.symbolic.exprEqual(a, b));
    try testing.expect(!h.symbolic.exprEqual(a, c));
}

test "exprEqual: symbols" {
    const allocator = testing.allocator;

    const a = try h.parseExpr(allocator, "x");
    defer {
        a.deinit(allocator);
        allocator.destroy(a);
    }
    const b = try h.parseExpr(allocator, "x");
    defer {
        b.deinit(allocator);
        allocator.destroy(b);
    }
    const c = try h.parseExpr(allocator, "y");
    defer {
        c.deinit(allocator);
        allocator.destroy(c);
    }

    try testing.expect(h.symbolic.exprEqual(a, b));
    try testing.expect(!h.symbolic.exprEqual(a, c));
}

test "exprEqual: lists" {
    const allocator = testing.allocator;

    const a = try h.parseExpr(allocator, "(+ x 1)");
    defer {
        a.deinit(allocator);
        allocator.destroy(a);
    }
    const b = try h.parseExpr(allocator, "(+ x 1)");
    defer {
        b.deinit(allocator);
        allocator.destroy(b);
    }
    const c = try h.parseExpr(allocator, "(+ x 2)");
    defer {
        c.deinit(allocator);
        allocator.destroy(c);
    }

    try testing.expect(h.symbolic.exprEqual(a, b));
    try testing.expect(!h.symbolic.exprEqual(a, c));
}

// ============================================================================
// Copy Expression Tests
// ============================================================================

test "copyExpr: deep copy" {
    const allocator = testing.allocator;

    const original = try h.parseExpr(allocator, "(+ (* x 2) y)");
    defer {
        original.deinit(allocator);
        allocator.destroy(original);
    }

    const copied = try h.symbolic.copyExpr(original, allocator);
    defer {
        copied.deinit(allocator);
        allocator.destroy(copied);
    }

    try testing.expect(h.symbolic.exprEqual(original, copied));
    // Verify they're different memory
    try testing.expect(original != copied);
}
