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

test "bigint: literal parses as big" {
    const allocator = testing.allocator;
    const expr = try h.parseExpr(allocator, "99999999999999999999");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    try testing.expect(expr.* == .big);
}

test "bigint: small literal stays a plain number" {
    const allocator = testing.allocator;
    const expr = try h.parseExpr(allocator, "9007199254740991");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    try testing.expect(expr.* == .number);
}

test "bigint: literal round-trips through printing" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "99999999999999999999", "99999999999999999999");
    try expectEval(allocator, &env, "-99999999999999999999", "-99999999999999999999");
}

test "bigint: addition and carry" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(+ 99999999999999999999 1)", "100000000000000000000");
}

test "bigint: subtraction demotes back to a plain number" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(- 100000000000000000001 100000000000000000000)");
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
    try testing.expectEqual(@as(f64, 1), result.number);
}

test "bigint: multiplication" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(* 99999999999999999999 99999999999999999999)", "9999999999999999999800000000000000000001");
}

test "bigint: unary negation" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(- 99999999999999999999)", "-99999999999999999999");
}

test "bigint: power promotes past f64 exactness" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(^ 2 100)", "1267650600228229401496703205376");
}

test "bigint: small powers unchanged" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(^ 2 10)", "1024");
}

test "bigint: factorial is exact past 20" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(factorial 25)", "15511210043330985984000000");
    try expectEval(allocator, &env, "(factorial 20)", "2432902008176640000");
}

test "bigint: exact division" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(/ (factorial 25) (factorial 24))", "25");
    try expectEval(allocator, &env, "(/ (^ 2 100) (^ 2 50))", "1125899906842624");
}

test "bigint: inexact division falls back to float" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(/ (^ 2 100) 3)");
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
    try testing.expectApproxEqRel(@as(f64, 4.2255020007607644e29), result.number, 1e-12);
}

test "bigint: exact comparisons" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    // A float comparison would tie on these
    try expectEval(allocator, &env, "(< (^ 2 100) (+ (^ 2 100) 1))", "1");
    try expectEval(allocator, &env, "(> (^ 2 100) (+ (^ 2 100) 1))", "0");
    try expectEval(allocator, &env, "(= (^ 2 100) (^ 2 100))", "1");
    try expectEval(allocator, &env, "(= (^ 2 100) (+ (^ 2 100) 1))", "0");
}

test "bigint: mod and gcd" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(mod (^ 2 100) 7)", "2");
    try expectEval(allocator, &env, "(gcd (factorial 30) (factorial 28))", "304888344611713860501504000000");
}

test "bigint: abs and sign" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(abs (- (^ 2 100)))", "1267650600228229401496703205376");
    try expectEval(allocator, &env, "(sign (- (^ 2 100)))", "-1");
    try expectEval(allocator, &env, "(sign (^ 2 100))", "1");
}

test "bigint: predicates" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();
    try expectEval(allocator, &env, "(integer? (^ 2 100))", "1");
    try expectEval(allocator, &env, "(number? (^ 2 100))", "1");
    try expectEval(allocator, &env, "(rational? (^ 2 100))", "1");
}

test "bigint: float contagion" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(+ (^ 2 100) 0.5)");
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
}

test "bigint: evalf converts to float" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(evalf (^ 2 100))");
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
    try testing.expectApproxEqRel(@as(f64, 1.2676506002282294e30), result.number, 1e-12);
}

test "bigint: works in variables and lambdas" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    {
        const expr = try h.parseExpr(allocator, "(define big 99999999999999999999)");
        defer {
            expr.deinit(allocator);
            allocator.destroy(expr);
        }
        const result = try h.eval(expr, &env);
        result.deinit(allocator);
        allocator.destroy(result);
    }
    try expectEval(allocator, &env, "(+ big big)", "199999999999999999998");
    try expectEval(allocator, &env, "((lambda (x) (* x 2)) big)", "199999999999999999998");
}

test "bigint: latex export" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(latex (^ 2 100))");
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
    try testing.expectEqualStrings("1267650600228229401496703205376", result.owned_symbol);
}
