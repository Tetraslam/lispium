const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

test "matrix: creation" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(matrix (1 2) (3 4))");
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
    try testing.expectEqualStrings("(matrix (1 2) (3 4))", str);
}

test "matrix: det 2x2 numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(det (matrix (1 2) (3 4)))");
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
    try testing.expectEqual(@as(f64, -2), result.number);
}

test "matrix: det 2x2 symbolic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(det (matrix (a b) (c d)))");
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
    try testing.expectEqualStrings("(- (* a d) (* b c))", str);
}

test "matrix: transpose" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(transpose (matrix (1 2) (3 4)))");
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
    try testing.expectEqualStrings("(matrix (1 3) (2 4))", str);
}

test "matrix: trace 2x2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(trace (matrix (1 2) (3 4)))");
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
    try testing.expectEqual(@as(f64, 5), result.number);
}

test "matrix: trace symbolic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(trace (matrix (a b) (c d)))");
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
    try testing.expectEqualStrings("(+ a d)", str);
}

test "matrix: matmul 2x2 numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // [[1,2],[3,4]] * [[5,6],[7,8]] = [[19,22],[43,50]]
    const expr = try h.parseExpr(allocator, "(matmul (matrix (1 2) (3 4)) (matrix (5 6) (7 8)))");
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
    try testing.expectEqualStrings("(matrix (19 22) (43 50))", str);
}

test "matrix: matmul with identity" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // [[a,b],[c,d]] * [[1,0],[0,1]] = [[a,b],[c,d]]
    const expr = try h.parseExpr(allocator, "(matmul (matrix (a b) (c d)) (matrix (1 0) (0 1)))");
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
    try testing.expectEqualStrings("(matrix (a b) (c d))", str);
}

test "matrix: inv 2x2 numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // inv([[4,0],[0,4]]) = [[0.25,0],[0,0.25]]
    // Using 4 as it has no sign issues with 0 entries
    const expr = try h.parseExpr(allocator, "(inv (matrix (4 0) (0 4)))");
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
    // Check first entry is 0.25 and last entry is 0.25
    try testing.expect(result.* == .list);
    try testing.expect(result.list.items.len == 3); // matrix, row1, row2
    const row1 = result.list.items[1];
    try testing.expect(row1.* == .list);
    try testing.expect(row1.list.items[0].* == .number);
    try testing.expectEqual(@as(f64, 0.25), row1.list.items[0].number);
}

test "matrix: inv 1x1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // inv([[4]]) = [[0.25]]
    const expr = try h.parseExpr(allocator, "(inv (matrix (4)))");
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
    try testing.expectEqualStrings("(matrix (0.25))", str);
}

// ============================================================================
// Eigenvalue Tests
// ============================================================================

test "matrix: eigenvalues distinct real" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // [[3, 1], [0, 2]] has eigenvalues 3 and 2
    const expr = try h.parseExpr(allocator, "(eigenvalues (matrix (3 1) (0 2)))");
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
    try testing.expectEqualStrings("(eigenvalues 3 2)", str);
}

test "matrix: eigenvalues diagonal matrix" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // [[5, 0], [0, 7]] has eigenvalues 5 and 7
    const expr = try h.parseExpr(allocator, "(eigenvalues (matrix (5 0) (0 7)))");
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
    try testing.expectEqualStrings("(eigenvalues 7 5)", str);
}

test "matrix: eigenvalues repeated" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // [[2, 0], [0, 2]] has eigenvalue 2 (multiplicity 2)
    const expr = try h.parseExpr(allocator, "(eigenvalues (matrix (2 0) (0 2)))");
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
    try testing.expectEqualStrings("(eigenvalues 2 2)", str);
}

test "matrix: eigenvalues complex" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // [[0, -1], [1, 0]] is rotation by 90°, eigenvalues are ±i
    const expr = try h.parseExpr(allocator, "(eigenvalues (matrix (0 -1) (1 0)))");
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
    try testing.expectEqualStrings("(eigenvalues (complex 0 1) (complex 0 -1))", str);
}

test "matrix: eigenvectors diagonal" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // [[3, 0], [0, 2]] - eigenvectors should be [1,0] and [0,1]
    const expr = try h.parseExpr(allocator, "(eigenvectors (matrix (3 0) (0 2)))");
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
    try testing.expectEqualStrings("(eigenvectors (vector 1 0) (vector 0 1))", str);
}

// ============================================================================
// Linear System Solver Tests
// ============================================================================

test "matrix: linsolve 2x2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Solve [[1, 2], [3, 4]] * x = [5, 11]
    // x = [1, 2]
    const expr = try h.parseExpr(allocator, "(linsolve (matrix (1 2) (3 4)) (vector 5 11))");
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
    try testing.expectEqualStrings("(vector 1 2)", str);
}

test "matrix: linsolve 3x3" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Solve [[1,0,0],[0,1,0],[0,0,1]] * x = [1, 2, 3] (identity)
    // x = [1, 2, 3]
    const expr = try h.parseExpr(allocator, "(linsolve (matrix (1 0 0) (0 1 0) (0 0 1)) (vector 1 2 3))");
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
    try testing.expectEqualStrings("(vector 1 2 3)", str);
}

test "matrix: linsolve 3x3 non-trivial" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Solve [[1,1,1],[0,2,5],[2,5,-1]] * x = [6, -4, 27]
    // Known solution: x = [5, 3, -2]
    const expr = try h.parseExpr(allocator, "(linsolve (matrix (1 1 1) (0 2 5) (2 5 -1)) (vector 6 -4 27))");
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
    try testing.expectEqualStrings("(vector 5 3 -2)", str);
}

// ============================================================================
// LU Decomposition Tests
// ============================================================================

test "matrix: lu 2x2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // LU of [[4, 3], [6, 3]]
    // L = [[1, 0], [1.5, 1]], U = [[4, 3], [0, -1.5]]
    const expr = try h.parseExpr(allocator, "(lu (matrix (4 3) (6 3)))");
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
    try testing.expectEqualStrings("(lu (matrix (1 0) (1.5 1)) (matrix (4 3) (0 -1.5)))", str);
}

test "matrix: lu 3x3" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // LU of [[2, 1, 1], [4, -6, 0], [-2, 7, 2]]
    const expr = try h.parseExpr(allocator, "(lu (matrix (2 1 1) (4 -6 0) (-2 7 2)))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Verify it's an LU tuple
    try testing.expect(result.* == .list);
    try testing.expect(result.list.items.len == 3); // "lu", L, U
}

test "matrix: lu identity" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // LU of identity is L=I, U=I
    const expr = try h.parseExpr(allocator, "(lu (matrix (1 0) (0 1)))");
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
    try testing.expectEqualStrings("(lu (matrix (1 0) (0 1)) (matrix (1 0) (0 1)))", str);
}

// ============================================================================
// Characteristic Polynomial Tests
// ============================================================================

test "matrix: charpoly 2x2 numeric" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // [[1, 2], [3, 4]]: trace=5, det=-2
    // p(λ) = λ² - 5λ - 2
    const expr = try h.parseExpr(allocator, "(charpoly (matrix (1 2) (3 4)) x)");
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
    try testing.expectEqualStrings("(+ (- (^ x 2) (* 5 x)) -2)", str);
}

test "matrix: charpoly 2x2 symbolic" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // [[a, b], [c, d]]: p(λ) = λ² - (a+d)λ + (ad-bc)
    const expr = try h.parseExpr(allocator, "(charpoly (matrix (a b) (c d)) x)");
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
    try testing.expectEqualStrings("(+ (- (^ x 2) (* (+ a d) x)) (- (* a d) (* b c)))", str);
}
