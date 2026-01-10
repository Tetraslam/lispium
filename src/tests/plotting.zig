const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

// ============================================================================
// plot-ascii Tests
// ============================================================================

test "plot-ascii: basic function" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Plot x^2 from -2 to 2
    const expr = try h.parseExpr(allocator, "(plot-ascii (* x x) -2 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return (plot "...")
    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items.len == 2);
    try testing.expect(lst.items[0].* == .symbol);
    try testing.expectEqualStrings("plot", lst.items[0].symbol);
    try testing.expect(lst.items[1].* == .owned_symbol);

    // Check that the plot string contains some asterisks
    const plot_str = lst.items[1].owned_symbol;
    try testing.expect(std.mem.indexOf(u8, plot_str, "*") != null);
}

test "plot-ascii: linear function" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Plot x from 0 to 10
    const expr = try h.parseExpr(allocator, "(plot-ascii x 0 10)");
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
    try testing.expect(result.list.items.len == 2);
    try testing.expectEqualStrings("plot", result.list.items[0].symbol);
}

test "plot-ascii: custom dimensions" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Plot sin(x) with custom height and width
    const expr = try h.parseExpr(allocator, "(plot-ascii (sin x) 0 6.28 10 40)");
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
    try testing.expectEqualStrings("plot", result.list.items[0].symbol);
}

// ============================================================================
// plot-svg Tests
// ============================================================================

test "plot-svg: basic function" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    // Plot x^2 from -2 to 2
    const expr = try h.parseExpr(allocator, "(plot-svg (* x x) -2 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // Should return (svg "...")
    try testing.expect(result.* == .list);
    const lst = result.list;
    try testing.expect(lst.items.len == 2);
    try testing.expect(lst.items[0].* == .symbol);
    try testing.expectEqualStrings("svg", lst.items[0].symbol);
    try testing.expect(lst.items[1].* == .owned_symbol);

    // Check SVG structure
    const svg_str = lst.items[1].owned_symbol;
    try testing.expect(std.mem.indexOf(u8, svg_str, "<svg") != null);
    try testing.expect(std.mem.indexOf(u8, svg_str, "</svg>") != null);
    try testing.expect(std.mem.indexOf(u8, svg_str, "<path") != null);
}

test "plot-svg: custom dimensions" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(plot-svg (cos x) 0 6.28 300 500)");
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
    try testing.expectEqualStrings("svg", result.list.items[0].symbol);

    // Check width/height in SVG
    const svg_str = result.list.items[1].owned_symbol;
    try testing.expect(std.mem.indexOf(u8, svg_str, "width=\"500\"") != null);
    try testing.expect(std.mem.indexOf(u8, svg_str, "height=\"300\"") != null);
}

// ============================================================================
// plot-points Tests
// ============================================================================

test "plot-points: basic points" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(plot-points (list (vector 0 0) (vector 1 1) (vector 2 4) (vector 3 9)))");
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
    try testing.expectEqualStrings("plot", result.list.items[0].symbol);
    try testing.expect(result.list.items[1].* == .owned_symbol);

    // Check that plot contains asterisks (points)
    const plot_str = result.list.items[1].owned_symbol;
    try testing.expect(std.mem.indexOf(u8, plot_str, "*") != null);
}

test "plot-points: negative coordinates" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(plot-points (list (vector -2 4) (vector -1 1) (vector 0 0) (vector 1 1) (vector 2 4)))");
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
    try testing.expectEqualStrings("plot", result.list.items[0].symbol);
}
