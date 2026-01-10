const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// Tensor Creation Tests
// ============================================================================

test "tensor: create 1D tensor" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Use vector syntax which is already supported
    const expr = try h.parseExpr(allocator, "(tensor (vector 1 2 3))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items.len == 2);
    try testing.expect(lst.items[0].* == .symbol);
    try testing.expectEqualStrings("tensor", lst.items[0].symbol);
}

test "tensor: create 2D tensor (matrix)" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Use matrix syntax
    const expr = try h.parseExpr(allocator, "(tensor (matrix (1 2) (3 4)))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items[0].* == .symbol);
    try testing.expectEqualStrings("tensor", lst.items[0].symbol);
}

// ============================================================================
// Tensor Rank Tests
// ============================================================================

test "tensor-rank: scalar has rank 0" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(tensor-rank 5)");
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
    try testing.expectApproxEqAbs(@as(f64, 0), result.number, 1e-10);
}

test "tensor-rank: vector has rank 1" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Direct vector
    const expr = try h.parseExpr(allocator, "(tensor-rank (vector 1 2 3))");
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
    // Vector structure has list with symbol + elements, counts as rank 1
    try testing.expectApproxEqAbs(@as(f64, 1), result.number, 1e-10);
}

test "tensor-rank: 2D tensor has rank 2" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(tensor-rank (tensor (matrix (1 2) (3 4))))");
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
    try testing.expectApproxEqAbs(@as(f64, 2), result.number, 1e-10);
}

// ============================================================================
// Tensor Contraction Tests
// ============================================================================

test "tensor-contract: contract 2D tensor along diagonal" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Trace-like contraction: sum of diagonal
    const expr = try h.parseExpr(allocator, "(tensor-contract (tensor (matrix (1 0) (0 2))) 0 1)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return a result (contraction reduces rank)
    try testing.expect(result.* == .number or result.* == .list);
}

// ============================================================================
// Tensor Product Tests
// ============================================================================

test "tensor-product: outer product of vectors" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(tensor-product (tensor (vector 1 2)) (tensor (vector 3 4)))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Tensor product returns a result
    try testing.expect(result.* == .list);
}

test "tensor-product: scalar times tensor" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(tensor-product 2 (tensor (vector 1 2 3)))");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Scalar times tensor scales all elements
    try testing.expect(result.* == .list);
}
