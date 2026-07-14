const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

/// Evaluates `input` and compares the printed result against `expected`.
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

fn run(allocator: std.mem.Allocator, env: *h.Env, input: []const u8) !void {
    const expr = try h.parseExpr(allocator, input);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    const result = try h.eval(expr, env);
    result.deinit(allocator);
    allocator.destroy(result);
}

test "dispatch: shadowing a builtin with a lambda invalidates cached calls" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Prime the operator cache with the builtin
    try expectEval(allocator, &env, "(+ 1 2)", "3");
    // Shadow + with a lambda; the next call must see it
    try run(allocator, &env, "(define + (lambda (a b) 42))");
    try expectEval(allocator, &env, "(+ 1 2)", "42");
}

test "dispatch: a new macro shadows a cached builtin" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(mod 5 3)", "2");
    try run(allocator, &env, "(defmacro (mod a b) `(+ ,a ,b))");
    try expectEval(allocator, &env, "(mod 5 3)", "8");
}

test "dispatch: redefining a function invalidates cached lambda calls" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try run(allocator, &env, "(define (f x) (* x 2))");
    try expectEval(allocator, &env, "(f 10)", "20");
    try run(allocator, &env, "(define (f x) (* x 3))");
    try expectEval(allocator, &env, "(f 10)", "30");
}

test "dispatch: a function redefining itself mid-call survives" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // The old body finishes executing after displacing itself
    try run(allocator, &env, "(define (f n) (begin (define (f n) 99) n))");
    try expectEval(allocator, &env, "(f 1)", "1");
    try expectEval(allocator, &env, "(f 1)", "99");
}

test "dispatch: tail call through a parameter that rebinds its own name" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Each tail iteration rebinds `f` (the very binding being executed);
    // the displaced lambda must survive until the call finishes
    try run(allocator, &env, "(define (self f n) (if (= n 0) \"done\" (f f (- n 1))))");
    try expectEval(allocator, &env, "(self self 5)", "\"done\"");
}

test "dispatch: number rebinds keep the cache hot but stay correct" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Rebinding numbers (loop counters) must not confuse dispatch
    try run(allocator, &env, "(define (count i acc) (if (= i 0) acc (count (- i 1) (+ acc 1))))");
    try expectEval(allocator, &env, "(count 1000 0)", "1000");
    try expectEval(allocator, &env, "(count 1000 0)", "1000");
}

test "dispatch: higher-order builtins call lambdas directly" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(reduce + 0 (map (lambda (x) (* x x)) (filter (lambda (x) (= (mod x 2) 0)) (range 10))))", "120");
    // Named functions and builtin names still work as function arguments
    try run(allocator, &env, "(define (sq x) (* x x))");
    try expectEval(allocator, &env, "(nth (map sq (list 1 2 3)) 2)", "9");
    try expectEval(allocator, &env, "(reduce + 0 (list 1 2 3))", "6");
}

test "dispatch: closures returned from functions are callable" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try run(allocator, &env, "(define (make-adder n) (lambda (x) (+ x n)))");
    try run(allocator, &env, "(define add5 (make-adder 5))");
    try expectEval(allocator, &env, "(add5 10)", "15");
    // Replacing the closure invalidates the cached call
    try run(allocator, &env, "(define add5 (make-adder 7))");
    try expectEval(allocator, &env, "(add5 10)", "17");
}

test "dispatch: builtins are first-class through variables and parameters" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // (define f +) makes f act as +
    try run(allocator, &env, "(define plus +)");
    try expectEval(allocator, &env, "(plus 3 4)", "7");

    // ... including through function parameters (captured as (quote +))
    try run(allocator, &env, "(define (g f a b) (f a b))");
    try expectEval(allocator, &env, "(g + 2 3)", "5");
    try expectEval(allocator, &env, "(g max 2 3)", "3");

    // Rebinding the alias changes dispatch
    try run(allocator, &env, "(define plus -)");
    try expectEval(allocator, &env, "(plus 3 4)", "-1");
}

test "dispatch: not uses general truthiness" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(not 0)", "1");
    try expectEval(allocator, &env, "(not 5)", "0");
    try expectEval(allocator, &env, "(not '())", "1");
    try expectEval(allocator, &env, "(not '(a b))", "0");
    try expectEval(allocator, &env, "(not \"s\")", "0");
    try expectEval(allocator, &env, "(not (list))", "1");
    try expectEval(allocator, &env, "(not (assoc 'z '((a 1))))", "1");
    // Bare symbols stay symbolic
    try expectEval(allocator, &env, "(not x)", "(not x)");
}
