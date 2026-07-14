//! Tests for the canonical source formatter (see STYLE.md).
const std = @import("std");
const testing = std.testing;
const formatter = @import("../formatter.zig");

fn expectFormat(input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    const out = try formatter.format(allocator, input);
    defer allocator.free(out);
    try testing.expectEqualStrings(expected, out);
}

test "formatter: collapses whitespace within a fitting expression" {
    try expectFormat("(+ 1\n2      3)\n", "(+ 1 2 3)\n");
}

test "formatter: short define stays on one line" {
    try expectFormat("(define (square x)     (* x x))", "(define (square x) (* x x))\n");
}

test "formatter: long define breaks with two-space body indent" {
    try expectFormat(
        "(define (f a b) (+ (* a a a a a a) (* b b b b b b) (* 2 a b a b) (* 3 a a b) (* 4 a b b)))",
        \\(define (f a b)
        \\  (+ (* a a a a a a) (* b b b b b b) (* 2 a b a b) (* 3 a a b) (* 4 a b b)))
        \\
        ,
    );
}

test "formatter: let bindings break one per line" {
    try expectFormat(
        "(let ((alpha 1) (beta 2) (gamma 3) (delta 4) (epsilon 5) (zeta 600000) (eta 77777777)) (+ alpha beta gamma delta epsilon zeta eta))",
        \\(let ((alpha 1)
        \\      (beta 2)
        \\      (gamma 3)
        \\      (delta 4)
        \\      (epsilon 5)
        \\      (zeta 600000)
        \\      (eta 77777777))
        \\  (+ alpha beta gamma delta epsilon zeta eta))
        \\
        ,
    );
}

test "formatter: call arguments align under the first argument" {
    try expectFormat(
        "(+ (* first-term first-term first-term) (* second-term second-term second-term) (* third-term third-term))",
        \\(+ (* first-term first-term first-term)
        \\   (* second-term second-term second-term)
        \\   (* third-term third-term))
        \\
        ,
    );
}

test "formatter: standalone and trailing comments preserved" {
    try expectFormat(
        ";; header comment\n(diff (^ x 3) x)   ;result\n",
        "; header comment\n(diff (^ x 3) x)  ; result\n",
    );
}

test "formatter: blank lines collapse to one, none at edges" {
    try expectFormat(
        "\n\n(+ 1 2)\n\n\n\n(+ 3 4)\n\n\n",
        "(+ 1 2)\n\n(+ 3 4)\n",
    );
}

test "formatter: numeric literals survive verbatim" {
    try expectFormat("(+ 1e10   0.5000 -3.14)", "(+ 1e10 0.5000 -3.14)\n");
}

test "formatter: unbalanced input is rejected" {
    const allocator = testing.allocator;
    try testing.expectError(error.UnbalancedParens, formatter.format(allocator, "(+ 1 2"));
    try testing.expectError(error.UnbalancedParens, formatter.format(allocator, "(+ 1 2))"));
}

test "formatter: idempotent on a representative kitchen sink" {
    const allocator = testing.allocator;
    const input =
        \\; kitchen sink
        \\(define (long-function-name arg-one arg-two) (+ (* arg-one arg-one) (* arg-two arg-two) (* 2 arg-one arg-two) (* 3 arg-one)))
        \\(letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))) (fact 5)) ; trailing
        \\(matrix (1 2 3) (4 5 6))
        \\(sum i 1 100 (* i i))
        \\
    ;
    const once = try formatter.format(allocator, input);
    defer allocator.free(once);
    const twice = try formatter.format(allocator, once);
    defer allocator.free(twice);
    try testing.expectEqualStrings(once, twice);
}

test "formatter: formatting preserves structure (parse equivalence)" {
    const allocator = testing.allocator;
    const h = @import("helpers.zig");

    const input = "(define (f x)     (+ (* 2 x)\n 1))";
    const out = try formatter.format(allocator, input);
    defer allocator.free(out);

    const before = try h.parseExpr(allocator, input);
    defer {
        before.deinit(allocator);
        allocator.destroy(before);
    }
    const after = try h.parseExpr(allocator, out);
    defer {
        after.deinit(allocator);
        allocator.destroy(after);
    }

    try testing.expect(h.symbolic.exprEqual(before, after));
}

test "formatter: shebang lines pass through verbatim" {
    const allocator = testing.allocator;
    const src = "#!/usr/bin/env -S lispium run\n(+ 1   2)\n";
    const out = try formatter.format(allocator, src);
    defer allocator.free(out);
    try testing.expect(std.mem.startsWith(u8, out, "#!/usr/bin/env -S lispium run\n"));
    try testing.expect(std.mem.indexOf(u8, out, "(+ 1 2)") != null);
}
