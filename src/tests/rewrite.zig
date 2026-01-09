const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

test "rule: simple pattern match" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const rule_expr = try h.parseExpr(allocator, "(rule (double ?x) (* 2 ?x))");
    defer {
        rule_expr.deinit(allocator);
        allocator.destroy(rule_expr);
    }
    const rule_result = try h.eval(rule_expr, &env);
    defer {
        rule_result.deinit(allocator);
        allocator.destroy(rule_result);
    }

    const expr = try h.parseExpr(allocator, "(rewrite (double 5))");
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
    try testing.expectEqualStrings("(* 2 5)", str);
}

test "rule: multiple pattern variables" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const rule_expr = try h.parseExpr(allocator, "(rule (swap ?a ?b) (pair ?b ?a))");
    defer {
        rule_expr.deinit(allocator);
        allocator.destroy(rule_expr);
    }
    const rule_result = try h.eval(rule_expr, &env);
    defer {
        rule_result.deinit(allocator);
        allocator.destroy(rule_result);
    }

    const expr = try h.parseExpr(allocator, "(rewrite (swap 1 2))");
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
    try testing.expectEqualStrings("(pair 2 1)", str);
}

test "rule: nested rewrite" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const rule_expr = try h.parseExpr(allocator, "(rule (sq ?x) (* ?x ?x))");
    defer {
        rule_expr.deinit(allocator);
        allocator.destroy(rule_expr);
    }
    const rule_result = try h.eval(rule_expr, &env);
    defer {
        rule_result.deinit(allocator);
        allocator.destroy(rule_result);
    }

    const expr = try h.parseExpr(allocator, "(rewrite (+ (sq 3) (sq 4)))");
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
    try testing.expectEqualStrings("(+ (* 3 3) (* 4 4))", str);
}

test "rule: same variable must match same value" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const rule_expr = try h.parseExpr(allocator, "(rule (same ?x ?x) matched)");
    defer {
        rule_expr.deinit(allocator);
        allocator.destroy(rule_expr);
    }
    const rule_result = try h.eval(rule_expr, &env);
    defer {
        rule_result.deinit(allocator);
        allocator.destroy(rule_result);
    }

    // This should match
    const expr1 = try h.parseExpr(allocator, "(rewrite (same 5 5))");
    defer {
        expr1.deinit(allocator);
        allocator.destroy(expr1);
    }
    const result1 = try h.eval(expr1, &env);
    defer {
        result1.deinit(allocator);
        allocator.destroy(result1);
    }
    try testing.expect(result1.* == .symbol);
    try testing.expectEqualStrings("matched", result1.symbol);

    // This should NOT match (5 != 6)
    const expr2 = try h.parseExpr(allocator, "(rewrite (same 5 6))");
    defer {
        expr2.deinit(allocator);
        allocator.destroy(expr2);
    }
    const result2 = try h.eval(expr2, &env);
    defer {
        result2.deinit(allocator);
        allocator.destroy(result2);
    }
    const str = try h.exprToString(allocator, result2);
    defer allocator.free(str);
    try testing.expectEqualStrings("(same 5 6)", str);
}
