//! Tests for the batteries pass: strings, dicts, JSON/CSV, dates,
//! inspectable errors, the prelude, and capability-port gating.
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

test "batteries: chained >= <= and !=" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(>= 3 2 2)", "1");
    try expectEval(allocator, &env, "(>= 2 3)", "0");
    try expectEval(allocator, &env, "(<= 1 1 5)", "1");
    try expectEval(allocator, &env, "(!= 1 2)", "1");
    try expectEval(allocator, &env, "(!= 2 2)", "0");
    // Symbolic operands stay inert
    try expectEval(allocator, &env, "(>= x 2)", "(>= x 2)");
}

test "batteries: string builtins" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(index-of \"hello\" \"ll\")", "2");
    try expectEval(allocator, &env, "(index-of \"hello\" \"zz\")", "-1");
    try expectEval(allocator, &env, "(contains? \"hello\" \"ell\")", "1");
    try expectEval(allocator, &env, "(replace \"a-b-c\" \"-\" \"+\")", "\"a+b+c\"");
    try expectEval(allocator, &env, "(upcase \"abc\")", "\"ABC\"");
    try expectEval(allocator, &env, "(downcase \"ABC\")", "\"abc\"");
    try expectEval(allocator, &env, "(trim \"  hi  \")", "\"hi\"");
    try expectEval(allocator, &env, "(char->code \"A\")", "65");
    try expectEval(allocator, &env, "(code->char 97)", "\"a\"");
    try expectEval(allocator, &env, "(string->symbol \"go\")", "go");
    try expectEval(allocator, &env, "(symbol->string 'east)", "\"east\"");
}

test "batteries: dict basics" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(dict-get (dict 'a 1 'b 2) 'b)", "2");
    try expectEval(allocator, &env, "(dict-get (dict \"a\" 1) 'a)", "1");
    try expectEval(allocator, &env, "(dict-get (dict) 'missing)", "0");
    try expectEval(allocator, &env, "(dict-get (dict) 'missing 'fallback)", "fallback");
    try expectEval(allocator, &env, "(dict-has? (dict 'a 1) 'a)", "1");
    try expectEval(allocator, &env, "(dict-size (dict 'a 1 'b 2))", "2");
    try expectEval(allocator, &env, "(dict-keys (dict 'a 1 'b 2))", "(list \"a\" \"b\")");
    try expectEval(allocator, &env, "(dict-values (dict 'a 1 'b 2))", "(list 1 2)");
    try expectEval(allocator, &env, "(dict? (dict))", "1");
    try expectEval(allocator, &env, "(dict? 5)", "0");
}

test "batteries: dict immutability and equality" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // dict-set returns a new dict; the original is untouched
    const setup = try h.parseExpr(allocator, "(define d (dict 'a 1))");
    defer {
        setup.deinit(allocator);
        allocator.destroy(setup);
    }
    const r = try h.eval(setup, &env);
    r.deinit(allocator);
    allocator.destroy(r);

    try expectEval(allocator, &env, "(dict-size (dict-set d 'b 2))", "2");
    try expectEval(allocator, &env, "(dict-size d)", "1");
    try expectEval(allocator, &env, "(dict-size (dict-remove d 'a))", "0");
    try expectEval(allocator, &env, "(dict-size d)", "1");

    // Order-insensitive equality
    try expectEval(allocator, &env, "(= (dict 'a 1 'b 2) (dict 'b 2 'a 1))", "1");
    try expectEval(allocator, &env, "(= (dict 'a 1) (dict 'a 2))", "0");

    // Merge: right side wins
    try expectEval(allocator, &env, "(dict-get (dict-merge (dict 'a 1) (dict 'a 9)) 'a)", "9");

    // Empty dict is falsy, non-empty truthy
    try expectEval(allocator, &env, "(if (dict) 'y 'n)", "n");
    try expectEval(allocator, &env, "(if (dict 'a 1) 'y 'n)", "y");
}

test "batteries: json round-trip" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(json-parse \"{\\\"a\\\": [1, 2.5], \\\"b\\\": true, \\\"c\\\": null}\")", "(dict \"a\" (list 1 2.5) \"b\" 1 \"c\" null)");
    // (the test writer prints strings raw, without re-escaping quotes)
    try expectEval(allocator, &env, "(json-emit (dict \"x\" (list 1 2) \"s\" \"hi\"))", "\"{\"x\":[1,2],\"s\":\"hi\"}\"");
    try expectEval(allocator, &env, "(dict-get (json-parse (json-emit (dict \"n\" (dict \"deep\" 42)))) \"n\")", "(dict \"deep\" 42)");
    // Parse errors are catchable with a readable message
    try expectEval(allocator, &env, "(try (json-parse \"{bad\") (error-message))", "\"json-parse: invalid JSON\"");
}

test "batteries: csv round-trip" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(csv-parse \"name,score\\nada,92.5\\n\\\"smith, j\\\",88\\n\")", "(list (list \"name\" \"score\") (list \"ada\" 92.5) (list \"smith, j\" 88))");
    try expectEval(allocator, &env, "(csv-emit (list (list \"a\" 1) (list \"with,comma\" 2)))", "\"a,1\n\"with,comma\",2\n\"");
}

test "batteries: dates" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(date-format 0)", "\"1970-01-01 00:00:00\"");
    try expectEval(allocator, &env, "(date-format 86461)", "\"1970-01-02 00:01:01\"");
    try expectEval(allocator, &env, "(dict-get (date-parts 0) 'weekday)", "4"); // Thursday
    try expectEval(allocator, &env, "(dict-get (date-parts 1786690000) 'year)", "2026");
    // (now) needs a clock; the test env has none, so it errors politely
    try testing.expectError(error.EvaluationError, evalRaw(allocator, &env, "(now)"));
}

test "batteries: inspectable errors" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(try (error \"boom\" 42) (concat \"got: \" (error-message)))", "\"got: boom 42\"");
    try expectEval(allocator, &env, "(try (assert 0 \"must hold\") (error-message))", "\"assertion failed: must hold\"");
}

test "batteries: prelude is loaded and shadowable" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(zip '(1 2) '(a b))", "((list 1 a) (list 2 b))");
    try expectEval(allocator, &env, "(take '(1 2 3 4) 2)", "(1 2)");
    try expectEval(allocator, &env, "(drop '(1 2 3 4) 2)", "(3 4)");
    try expectEval(allocator, &env, "(last '(1 2 3))", "3");
    try expectEval(allocator, &env, "(member? '(a b) 'b)", "1");
    try expectEval(allocator, &env, "(join \"-\" (list \"x\" \"y\"))", "\"x-y\"");
    try expectEval(allocator, &env, "(sum-list '(1 2 3))", "6");
    try expectEval(allocator, &env, "((compose inc inc) 1)", "3");
    try expectEval(allocator, &env, "(flatten '(1 (2 (3))))", "(1 2 3)");
    try expectEval(allocator, &env, "(all? (lambda (x) (> x 0)) '(1 2))", "1");
    try expectEval(allocator, &env, "(max-by (lambda (p) (second p)) '((a 1) (b 5)))", "(b 5)");

    // Shadowing a prelude name works like any other define
    try run(allocator, &env, "(define (zip a b) 'mine)");
    try expectEval(allocator, &env, "(zip '(1) '(2))", "mine");
}

test "batteries: capability ports are gated off in tests" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    try expectEval(allocator, &env, "(try (http-get \"https://example.com\") (error-message))", "\"http-get: network access is not enabled in this environment\"");
    try expectEval(allocator, &env, "(try (exec \"echo hi\") (error-message))", "\"exec: subprocess access is not enabled in this environment\"");
}

fn evalRaw(allocator: std.mem.Allocator, env: *h.Env, input: []const u8) !*h.Expr {
    const expr = try h.parseExpr(allocator, input);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }
    return h.eval(expr, env);
}

fn run(allocator: std.mem.Allocator, env: *h.Env, input: []const u8) !void {
    const result = try evalRaw(allocator, env, input);
    result.deinit(allocator);
    allocator.destroy(result);
}
