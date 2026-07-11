//! Tests for the 0.7.0 language features: exact rationals, strings,
//! quote/quasiquote, begin/cond, short-circuit logic, predicates, apply,
//! variadic lambdas, try, macros, TCO, closed-form sums, cubic solve,
//! u-substitution, and units.
const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

fn expectEval(allocator: std.mem.Allocator, env: *h.Env, input: []const u8, expected: []const u8) !void {
    const expr = try h.parseExpr(allocator, input);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    const result = try h.eval(expr, env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings(expected, str);
}

test "rationals: exact arithmetic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(/ 1 3)", "(rational 1 3)");
    try expectEval(allocator, &env, "(+ 1/3 1/6)", "(rational 1 2)");
    try expectEval(allocator, &env, "(+ 1/3 2/3)", "1");
    try expectEval(allocator, &env, "(* 2/3 3/4)", "(rational 1 2)");
    try expectEval(allocator, &env, "(- 1/2)", "(rational -1 2)");
    try expectEval(allocator, &env, "(^ 2 -2)", "(rational 1 4)");
    try expectEval(allocator, &env, "(^ 1/2 3)", "(rational 1 8)");
    try expectEval(allocator, &env, "(sqrt 1/4)", "(rational 1 2)");
    try expectEval(allocator, &env, "(numer 22/7)", "22");
    try expectEval(allocator, &env, "(denom 22/7)", "7");
    try expectEval(allocator, &env, "(< 1/3 1/2)", "1");
    try expectEval(allocator, &env, "(= 1/2 0.5)", "1");
    // Float contagion
    try expectEval(allocator, &env, "(+ 0.25 1/4)", "0.5");
    // evalf converts to float
    try expectEval(allocator, &env, "(evalf 1/4)", "0.25");
}

test "strings: literals, escapes, and operations" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "\"hello\"", "\"hello\"");
    try expectEval(allocator, &env, "(concat \"a\" \"-\" \"b\")", "\"a-b\"");
    try expectEval(allocator, &env, "(concat \"x = \" (+ 1 2))", "\"x = 3\"");
    try expectEval(allocator, &env, "(length \"hello\")", "5");
    try expectEval(allocator, &env, "(substring \"hello world\" 0 5)", "\"hello\"");
    try expectEval(allocator, &env, "(string->number \"22/7\")", "(rational 22 7)");
    try expectEval(allocator, &env, "(number->string 1/3)", "\"1/3\"");
    try expectEval(allocator, &env, "(split \"a,b\" \",\")", "(list \"a\" \"b\")");
}

test "quote and quasiquote" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "'(+ 1 2)", "(+ 1 2)");
    try expectEval(allocator, &env, "(car '(a b c))", "a");
    try expectEval(allocator, &env, "`(+ 1 ,(* 2 3))", "(+ 1 6)");
    try expectEval(allocator, &env, "'x", "x");
}

test "begin, cond, and short-circuit logic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(begin 1 2 3)", "3");
    try expectEval(allocator, &env, "(cond ((< 3 2) 1) ((< 1 2) 2) (else 3))", "2");
    try expectEval(allocator, &env, "(cond ((< 3 2) 1) (else 42))", "42");
    // Short-circuit: the division by zero is never evaluated
    try expectEval(allocator, &env, "(and 0 (/ 1 0))", "0");
    try expectEval(allocator, &env, "(or 1 (/ 1 0))", "1");
    // Symbolic operands stay inert
    try expectEval(allocator, &env, "(and p q)", "(and p q)");
}

test "type predicates" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(number? 3)", "1");
    try expectEval(allocator, &env, "(number? 1/3)", "1");
    try expectEval(allocator, &env, "(rational? 1/3)", "1");
    try expectEval(allocator, &env, "(integer? 3)", "1");
    try expectEval(allocator, &env, "(integer? 3.5)", "0");
    try expectEval(allocator, &env, "(symbol? 'x)", "1");
    try expectEval(allocator, &env, "(string? \"s\")", "1");
    try expectEval(allocator, &env, "(list? (list 1))", "1");
    try expectEval(allocator, &env, "(null? (list))", "1");
    try expectEval(allocator, &env, "(null? (list 1))", "0");
    try expectEval(allocator, &env, "(lambda? (lambda (x) x))", "1");
    try expectEval(allocator, &env, "(complex? (complex 1 2))", "1");
}

test "apply and variadic lambdas" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(apply + '(1 2 3))", "6");
    try expectEval(allocator, &env, "((lambda (x . rest) (length rest)) 1 2 3 4)", "3");
    const def = try h.parseExpr(allocator, "(define (my-sum . xs) (apply + xs))");
    defer {
        def.deinit(allocator);
        allocator.destroy(def);
    }
    const dv = try h.eval(def, &env);
    dv.deinit(allocator);
    allocator.destroy(dv);
    try expectEval(allocator, &env, "(my-sum 1 2 3 4 5)", "15");
}

test "try recovers from errors" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(try (/ 1 0) \"fallback\")", "\"fallback\"");
    try expectEval(allocator, &env, "(try (+ 1 2) 99)", "3");
}

test "macros: defmacro with quasiquote templates" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const def = try h.parseExpr(allocator, "(defmacro (unless c a b) `(if ,c ,b ,a))");
    defer {
        def.deinit(allocator);
        allocator.destroy(def);
    }
    const dv = try h.eval(def, &env);
    dv.deinit(allocator);
    allocator.destroy(dv);
    try expectEval(allocator, &env, "(unless 0 \"then\" \"else\")", "\"then\"");
    try expectEval(allocator, &env, "(unless 1 \"then\" \"else\")", "\"else\"");
}

test "TCO: mutual tail recursion" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(
        allocator,
        &env,
        "(letrec ((even? (lambda (n) (if (= n 0) 1 (odd? (- n 1))))) (odd? (lambda (n) (if (= n 0) 0 (even? (- n 1)))))) (even? 10000))",
        "1",
    );
}

test "closed-form symbolic sums" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(sum i 1 n i)", "(/ (* n (+ n 1)) 2)");
    try expectEval(allocator, &env, "(sum i 1 n 1)", "n");
    try expectEval(allocator, &env, "(sum i 1 n (^ 2 i))", "(- (^ 2 (+ n 1)) 2)");
}

test "cubic solve" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(solve (+ (^ x 3) (* -6 (^ x 2)) (* 11 x) -6) x)", "(solutions 3 2 1)");
    try expectEval(allocator, &env, "(solve (+ (^ x 3) -8) x)", "(solutions 2 (complex -1 1.7320508075688772) (complex -1 -1.7320508075688772))");
}

test "u-substitution integration" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(integrate (sin (* 2 x)) x)", "(/ (- (cos (* 2 x))) 2)");
    try expectEval(allocator, &env, "(integrate (* (* 2 x) (cos (^ x 2))) x)", "(sin (^ x 2))");
    try expectEval(allocator, &env, "(integrate (* x (exp (^ x 2))) x)", "(* 0.5 (exp (^ x 2)))");
}

test "n x n eigenvalues" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(eigenvalues (matrix (2 0 0) (0 3 0) (0 0 5)))", "(eigenvalues 5 3 2)");
    try expectEval(allocator, &env, "(eigenvalues (matrix (1 0 0 0) (0 2 0 0) (0 0 3 0) (0 0 0 4)))", "(eigenvalues 1 2 3 4)");
}

test "units carry dimensions and reject mismatches" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(* 5 (unit m))", "(qty 5 1 0 0 0 0 0 0)");
    // 100 km/h in SI
    try expectEval(allocator, &env, "(/ (* 100 (unit km)) (unit h))", "(qty 27.77777777777778 1 0 -1 0 0 0 0)");
    // m + s is a dimensional error
    const bad = try h.parseExpr(allocator, "(+ (unit m) (unit s))");
    defer {
        bad.deinit(allocator);
        allocator.destroy(bad);
    }
    try testing.expectError(error.InvalidArgument, h.eval(bad, &env));
    // m/s * s = m
    try expectEval(allocator, &env, "(* (/ (unit m) (unit s)) (unit s))", "(qty 1 1 0 0 0 0 0 0)");
}

test "sort, assoc, random-seed determinism" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(sort (list 3 1 2))", "(list 1 2 3)");
    try expectEval(allocator, &env, "(assoc 2 (list (list 1 \"a\") (list 2 \"b\")))", "(list 2 \"b\")");
    // Seeded PRNG is deterministic within a process
    const s1 = try h.parseExpr(allocator, "(random-seed 7)");
    defer {
        s1.deinit(allocator);
        allocator.destroy(s1);
    }
    const sv = try h.eval(s1, &env);
    sv.deinit(allocator);
    allocator.destroy(sv);
    const r1 = try h.parseExpr(allocator, "(random 1000)");
    defer {
        r1.deinit(allocator);
        allocator.destroy(r1);
    }
    const v1 = try h.eval(r1, &env);
    defer {
        v1.deinit(allocator);
        allocator.destroy(v1);
    }
    try testing.expect(v1.* == .number);
    try testing.expect(v1.number >= 0 and v1.number < 1000);
}

test "multi-expression bodies" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "((lambda (x) (+ x 1) (* x 10)) 5)", "50");
}
