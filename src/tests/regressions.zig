//! Regression tests for bugs found during the 2026-07 audit.
//! Each test names the original defect it guards against.
const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

fn evalToString(allocator: std.mem.Allocator, env: *h.Env, input: []const u8) ![]u8 {
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
    return h.exprToString(allocator, result);
}

fn expectEval(allocator: std.mem.Allocator, env: *h.Env, input: []const u8, expected: []const u8) !void {
    const str = try evalToString(allocator, env, input);
    defer allocator.free(str);
    try testing.expectEqualStrings(expected, str);
}

test "regression: unary minus negates numbers" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(- 5)", "-5");
    try expectEval(allocator, &env, "(- -3)", "3");
}

test "regression: (/ x) is the reciprocal" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(/ 4)", "(rational 1 4)");
}

test "regression: define then call across statements (dangling-symbol bug)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    // "square" was the canonical victim of the reused-buffer corruption
    const def = try evalToString(allocator, &env, "(define (square x) (* x x))");
    allocator.free(def);
    try expectEval(allocator, &env, "(square 7)", "49");
}

test "regression: closures capture their environment" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(((lambda (n) (lambda (x) (+ x n))) 5) 10)", "15");
    // compose
    const d1 = try evalToString(allocator, &env, "(define (compose f g) (lambda (x) (f (g x))))");
    allocator.free(d1);
    const d2 = try evalToString(allocator, &env, "(define (inc x) (+ x 1))");
    allocator.free(d2);
    const d3 = try evalToString(allocator, &env, "(define (dbl x) (* 2 x))");
    allocator.free(d3);
    try expectEval(allocator, &env, "((compose inc dbl) 5)", "11");
}

test "regression: letrec recursion still works with capture" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(
        allocator,
        &env,
        "(letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))) (fact 5))",
        "120",
    );
}

test "regression: diff of a^x and x^x are not identity" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(diff (^ 2 x) x)", "(* (^ 2 x) (ln 2))");
    try expectEval(allocator, &env, "(diff (^ x x) x)", "(* (^ x x) (+ (ln x) 1))");
}

test "regression: diff of abs uses sign" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(diff (abs x) x)", "(sign x)");
}

test "regression: diff of unknown function returns inert form, not the input" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(diff (gamma x) x)", "(diff (gamma x) x)");
}

test "regression: log argument order is (log value base)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(log 8 2)", "3");
}

test "regression: limit (1 + 1/x)^x as x -> inf is e" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const str = try evalToString(allocator, &env, "(limit (^ (+ 1 (/ 1 x)) x) x inf)");
    defer allocator.free(str);
    const val = try std.fmt.parseFloat(f64, str);
    try testing.expect(@abs(val - std.math.e) < 1e-6);
}

test "regression: taylor order includes the nth-degree term" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(
        allocator,
        &env,
        "(taylor (sin x) x 0 5)",
        "(+ x (* -0.16666666666666666 (^ x 3)) (* 0.008333333333333333 (^ x 5)))",
    );
}

test "regression: taylor at a singularity errors instead of emitting garbage" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const expr = try h.parseExpr(allocator, "(taylor (ln x) x 0 3)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    try testing.expectError(error.Undefined, h.eval(expr, &env));
}

test "regression: singular matrix inverse errors" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const expr = try h.parseExpr(allocator, "(inv (matrix (1 2) (2 4)))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    try testing.expectError(error.InvalidArgument, h.eval(expr, &env));
}

test "regression: complex arithmetic through + - * / ^" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(+ (complex 1 2) (complex 3 4))", "(complex 4 6)");
    try expectEval(allocator, &env, "(* (complex 0 1) (complex 0 1))", "-1");
    try expectEval(allocator, &env, "(/ (complex 1 0) (complex 0 1))", "(complex 0 -1)");
    try expectEval(allocator, &env, "(^ (complex 0 1) 2)", "-1");
    try expectEval(allocator, &env, "(- (complex 1 2))", "(complex -1 -2)");
}

test "regression: sqrt of negatives and complex numbers" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(sqrt -4)", "(complex 0 2)");
    try expectEval(allocator, &env, "(sqrt (complex -1 0))", "(complex 0 1)");
}

test "regression: exp of a pure imaginary (Euler)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(evalf (exp (complex 0 pi)))", "-1");
}

test "regression: negative base with fractional exponent is complex, not NaN" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const str = try evalToString(allocator, &env, "(^ -8 (/ 1 3))");
    defer allocator.free(str);
    // Principal cube root of -8 = 1 + sqrt(3) i
    try testing.expect(std.mem.startsWith(u8, str, "(complex 1"));
}

test "regression: vector and matrix arithmetic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(+ (vector 1 2) (vector 3 4))", "(vector 4 6)");
    try expectEval(allocator, &env, "(- (vector 3 4) (vector 1 1))", "(vector 2 3)");
    try expectEval(allocator, &env, "(* 2 (vector 1 2))", "(vector 2 4)");
    try expectEval(allocator, &env, "(/ (vector 2 4) 2)", "(vector 1 2)");
    try expectEval(allocator, &env, "(+ (matrix (1 2) (3 4)) (matrix (1 1) (1 1)))", "(matrix (2 3) (4 5))");
    try expectEval(allocator, &env, "(* 2 (matrix (1 2) (3 4)))", "(matrix (2 4) (6 8))");
}

test "regression: abs floor ceil round sign" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(abs -3)", "3");
    try expectEval(allocator, &env, "(floor 2.7)", "2");
    try expectEval(allocator, &env, "(ceil 2.1)", "3");
    try expectEval(allocator, &env, "(round 2.5)", "3");
    try expectEval(allocator, &env, "(sign -3)", "-1");
    try expectEval(allocator, &env, "(abs (complex 3 4))", "5");
}

test "regression: symbolic comparisons stay inert and if defers" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(< x 1)", "(< x 1)");
    try expectEval(allocator, &env, "(> 2 1 0)", "1");
    try expectEval(allocator, &env, "(= 1 1 1)", "1");
    try expectEval(allocator, &env, "(if (> x 0) x (- x))", "(if (> x 0) x (- x))");
}

test "regression: nth rejects negative and out-of-range indices" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const bad = try h.parseExpr(allocator, "(nth (list 1 2 3) -1)");
    defer {
        bad.deinit(allocator);
        allocator.destroy(bad);
    }
    try testing.expectError(error.InvalidArgument, h.eval(bad, &env));
}

test "regression: sum/product bounds are validated and capped" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const huge = try h.parseExpr(allocator, "(sum i 1 1e18 i)");
    defer {
        huge.deinit(allocator);
        allocator.destroy(huge);
    }
    try testing.expectError(error.InvalidArgument, h.eval(huge, &env));
    const frac = try h.parseExpr(allocator, "(sum i 1.5 3 i)");
    defer {
        frac.deinit(allocator);
        allocator.destroy(frac);
    }
    try testing.expectError(error.InvalidArgument, h.eval(frac, &env));
}

test "regression: tail recursion runs in constant stack space (TCO)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    // Previously segfaulted around depth 1000; with proper tail calls this
    // loops fine
    try expectEval(
        allocator,
        &env,
        "(letrec ((loop (lambda (n) (if (= n 0) 0 (loop (- n 1)))))) (loop 100000))",
        "0",
    );
}

test "regression: non-tail deep recursion still errors instead of crashing" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    // (+ 1 (loop ...)) is not a tail call, so the depth guard applies
    const expr = try h.parseExpr(allocator, "(letrec ((loop (lambda (n) (if (= n 0) 0 (+ 1 (loop (- n 1))))))) (loop 100000))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    try testing.expectError(error.RecursionLimit, h.eval(expr, &env));
}

test "regression: gf requires a prime modulus and integer operands" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const composite = try h.parseExpr(allocator, "(gf 3 6)");
    defer {
        composite.deinit(allocator);
        allocator.destroy(composite);
    }
    try testing.expectError(error.InvalidArgument, h.eval(composite, &env));
    const frac = try h.parseExpr(allocator, "(gf 2.5 7)");
    defer {
        frac.deinit(allocator);
        allocator.destroy(frac);
    }
    try testing.expectError(error.InvalidArgument, h.eval(frac, &env));
}

test "regression: cf-rational handles negative denominators" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    // 1/-2 = -0.5 = [-1; 2]
    try expectEval(allocator, &env, "(cf-rational 1 -2)", "(cf -1 2)");
}

test "regression: permutations with k > n is an error" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const expr = try h.parseExpr(allocator, "(permutations 3 5)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    try testing.expectError(error.InvalidArgument, h.eval(expr, &env));
}

test "regression: definite integrals with symbolic bounds fold" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(integrate (sin x) x 0 pi)", "2");
}

test "regression: integrate a^x and e^x power forms" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(integrate (^ e x) x)", "(^ e x)");
    try expectEval(allocator, &env, "(integrate (^ 2 x) x)", "(/ (^ 2 x) (ln 2))");
}

test "regression: simplifier power laws and identities" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(simplify (+ (^ (sin x) 2) (^ (cos x) 2)))", "1");
    try expectEval(allocator, &env, "(simplify (* x (/ 1 x)))", "1");
    try expectEval(allocator, &env, "(simplify (/ (^ x 2) x))", "x");
    try expectEval(allocator, &env, "(simplify (* (^ x 2) (^ x 3)))", "(^ x 5)");
    try expectEval(allocator, &env, "(simplify (^ (^ x 2) 3))", "(^ x 6)");
    try expectEval(allocator, &env, "(simplify (sin pi))", "0");
    try expectEval(allocator, &env, "(simplify (* -1 x))", "(- x)");
}

test "regression: sqrt(x^2) = x under a positive assumption" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const a = try evalToString(allocator, &env, "(assume x positive)");
    allocator.free(a);
    try expectEval(allocator, &env, "(simplify (sqrt (^ x 2)))", "x");
}

test "regression: expand merges commutative like terms" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(expand (^ (+ x y) 2))", "(+ (^ x 2) (* 2 (* x y)) (^ y 2))");
}

test "regression: factor displays negative roots as (+ x n)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(factor (+ (^ x 2) (* 3 x) 2) x)", "(* (+ x 1) (+ x 2))");
}

test "regression: dsolve solves through the special form" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(dsolve (= (diff y x) y) y x)", "(= y (* C (exp x)))");
    // The residual form from the cookbook works too
    try expectEval(allocator, &env, "(dsolve (- (diff y x) y) y x)", "(= y (* C (exp x)))");
}

test "regression: solve reports contradictions" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(solve (+ (* 0 x) 5) x)", "no-solution");
}

test "regression: symbolic eigenvalues of a 2x2 matrix" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const str = try evalToString(allocator, &env, "(eigenvalues (matrix (a b) (c d)))");
    defer allocator.free(str);
    try testing.expect(std.mem.startsWith(u8, str, "(eigenvalues "));
    // Must actually contain the quadratic-formula structure, not an error
    try testing.expect(std.mem.indexOf(u8, str, "0.5") != null);
}

test "regression: factorize result carries the factors head" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(factorize 60)", "(factors (2 2) (3 1) (5 1))");
}

test "regression: laplace results are simplified" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(laplace (sin (* 2 t)) t s)", "(/ 2 (+ (^ s 2) 4))");
    try expectEval(allocator, &env, "(laplace (exp (* -1 t)) t s)", "(/ 1 (+ s 1))");
}

test "regression: memoize does not leak (cache freed on env deinit)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(memoize (+ 1 2))", "3");
    try expectEval(allocator, &env, "(memoize (+ 1 2))", "3");
    // testing.allocator fails the test on leak, which is the assertion here
}

test "regression: assume confirms and rejects unknown properties helpfully" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(assume n integer)", "(assumed n integer)");
    const str = try evalToString(allocator, &env, "(assume n banana)");
    defer allocator.free(str);
    try testing.expect(std.mem.indexOf(u8, str, "unknown property") != null);
}

test "regression: bisection without a sign change errors" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const expr = try h.parseExpr(allocator, "(bisection (- (^ x 2) 2) x 5 10 0.0001)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    try testing.expectError(error.InvalidArgument, h.eval(expr, &env));
}

test "regression: interpolation results are simplified" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(
        allocator,
        &env,
        "(newton-interp (list (vector 0 0) (vector 1 1) (vector 2 4)) x)",
        "(+ x (* x (- x 1)))",
    );
}

test "regression: integration by parts and inverse-trig patterns" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(integrate (* x (sin x)) x)", "(- (sin x) (* x (cos x)))");
    try expectEval(allocator, &env, "(integrate (* x (cos x)) x)", "(+ (cos x) (* x (sin x)))");
    try expectEval(allocator, &env, "(integrate (* x (exp x)) x)", "(* (- x 1) (exp x))");
    try expectEval(allocator, &env, "(integrate (tan x) x)", "(- (ln (cos x)))");
    try expectEval(allocator, &env, "(integrate (/ 1 (+ 1 (^ x 2))) x)", "(atan x)");
}

test "regression: NaN arithmetic reports Undefined instead of printing -nan" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const inf_val = try h.parseExpr(allocator, "(- (evalf inf) (evalf inf))");
    defer {
        inf_val.deinit(allocator);
        allocator.destroy(inf_val);
    }
    try testing.expectError(error.Undefined, h.eval(inf_val, &env));
}

test "regression: latex of huge floats does not crash" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    const str = try evalToString(allocator, &env, "(latex 1e300)");
    defer allocator.free(str);
    try testing.expect(std.mem.indexOf(u8, str, "e300") != null);
}
