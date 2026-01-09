const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

test "lambda: simple function" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "((lambda (x) (+ x 1)) 5)");
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
    try testing.expectEqual(@as(f64, 6), result.number);
}

test "lambda: two parameters" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "((lambda (x y) (+ x y)) 3 4)");
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
    try testing.expectEqual(@as(f64, 7), result.number);
}

test "lambda: nested operations" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "((lambda (x) (* x x)) 5)");
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
    try testing.expectEqual(@as(f64, 25), result.number);
}

test "define: simple value" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const def_expr = try h.parseExpr(allocator, "(define x 42)");
    defer {
        def_expr.deinit(allocator);
        allocator.destroy(def_expr);
    }

    const def_result = try h.eval(def_expr, &env);
    defer {
        def_result.deinit(allocator);
        allocator.destroy(def_result);
    }

    const use_expr = try h.parseExpr(allocator, "(+ x 8)");
    defer {
        use_expr.deinit(allocator);
        allocator.destroy(use_expr);
    }

    const use_result = try h.eval(use_expr, &env);
    defer {
        use_result.deinit(allocator);
        allocator.destroy(use_result);
    }

    try testing.expect(use_result.* == .number);
    try testing.expectEqual(@as(f64, 50), use_result.number);
}

test "define: function form" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const def_expr = try h.parseExpr(allocator, "(define (square x) (* x x))");
    defer {
        def_expr.deinit(allocator);
        allocator.destroy(def_expr);
    }

    const def_result = try h.eval(def_expr, &env);
    defer {
        def_result.deinit(allocator);
        allocator.destroy(def_result);
    }

    const call_expr = try h.parseExpr(allocator, "(square 7)");
    defer {
        call_expr.deinit(allocator);
        allocator.destroy(call_expr);
    }

    const call_result = try h.eval(call_expr, &env);
    defer {
        call_result.deinit(allocator);
        allocator.destroy(call_result);
    }

    try testing.expect(call_result.* == .number);
    try testing.expectEqual(@as(f64, 49), call_result.number);
}

test "define: function with multiple params" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const def_expr = try h.parseExpr(allocator, "(define (add a b) (+ a b))");
    defer {
        def_expr.deinit(allocator);
        allocator.destroy(def_expr);
    }

    const def_result = try h.eval(def_expr, &env);
    defer {
        def_result.deinit(allocator);
        allocator.destroy(def_result);
    }

    const call_expr = try h.parseExpr(allocator, "(add 10 20)");
    defer {
        call_expr.deinit(allocator);
        allocator.destroy(call_expr);
    }

    const call_result = try h.eval(call_expr, &env);
    defer {
        call_result.deinit(allocator);
        allocator.destroy(call_result);
    }

    try testing.expect(call_result.* == .number);
    try testing.expectEqual(@as(f64, 30), call_result.number);
}

test "if: true branch" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(if 1 42 99)");
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
    try testing.expectEqual(@as(f64, 42), result.number);
}

test "if: false branch" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(if 0 42 99)");
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
    try testing.expectEqual(@as(f64, 99), result.number);
}

test "let: single binding" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(let ((x 5)) (+ x 1))");
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
    try testing.expectEqual(@as(f64, 6), result.number);
}

test "let: multiple bindings" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(let ((x 3) (y 4)) (+ x y))");
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
    try testing.expectEqual(@as(f64, 7), result.number);
}

test "let: lexical scoping" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const def_expr = try h.parseExpr(allocator, "(define x 100)");
    defer {
        def_expr.deinit(allocator);
        allocator.destroy(def_expr);
    }
    const def_result = try h.eval(def_expr, &env);
    defer {
        def_result.deinit(allocator);
        allocator.destroy(def_result);
    }

    const let_expr = try h.parseExpr(allocator, "(let ((x 5)) x)");
    defer {
        let_expr.deinit(allocator);
        allocator.destroy(let_expr);
    }
    const let_result = try h.eval(let_expr, &env);
    defer {
        let_result.deinit(allocator);
        allocator.destroy(let_result);
    }
    try testing.expect(let_result.* == .number);
    try testing.expectEqual(@as(f64, 5), let_result.number);

    const after_expr = try h.parseExpr(allocator, "x");
    defer {
        after_expr.deinit(allocator);
        allocator.destroy(after_expr);
    }
    const after_result = try h.eval(after_expr, &env);
    defer {
        after_result.deinit(allocator);
        allocator.destroy(after_result);
    }
    try testing.expect(after_result.* == .number);
    try testing.expectEqual(@as(f64, 100), after_result.number);
}

test "define: using lambda with CAS" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const def_expr = try h.parseExpr(allocator, "(define (deriv f) (diff f x))");
    defer {
        def_expr.deinit(allocator);
        allocator.destroy(def_expr);
    }
    const def_result = try h.eval(def_expr, &env);
    defer {
        def_result.deinit(allocator);
        allocator.destroy(def_result);
    }

    const call_expr = try h.parseExpr(allocator, "(deriv (^ x 3))");
    defer {
        call_expr.deinit(allocator);
        allocator.destroy(call_expr);
    }

    const call_result = try h.eval(call_expr, &env);
    defer {
        call_result.deinit(allocator);
        allocator.destroy(call_result);
    }

    const str = try h.exprToString(allocator, call_result);
    defer allocator.free(str);
    try testing.expectEqualStrings("(* 3 (^ x 2))", str);
}

// ============================================================================
// Letrec Tests (Recursive Bindings)
// ============================================================================

test "letrec: factorial" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))) (fact 5))
    // 5! = 120
    const expr = try h.parseExpr(allocator, "(letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))) (fact 5))");
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
    try testing.expectEqual(@as(f64, 120), result.number);
}

test "letrec: fibonacci" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (letrec ((fib (lambda (n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2))))))) (fib 10))
    // fib(10) = 55
    const expr = try h.parseExpr(allocator, "(letrec ((fib (lambda (n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2))))))) (fib 10))");
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
    try testing.expectEqual(@as(f64, 55), result.number);
}

test "letrec: simple recursive sum" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // sum from 1 to n: (letrec ((sum (lambda (n) (if (= n 0) 0 (+ n (sum (- n 1))))))) (sum 10))
    // sum(10) = 55
    const expr = try h.parseExpr(allocator, "(letrec ((mysum (lambda (n) (if (= n 0) 0 (+ n (mysum (- n 1))))))) (mysum 10))");
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
    try testing.expectEqual(@as(f64, 55), result.number);
}
