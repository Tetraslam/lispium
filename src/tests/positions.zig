const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const parser_mod = @import("../parser.zig");
const Parser = parser_mod.Parser;
const evaluator = @import("../evaluator.zig");

/// Tokenizes `input` and parses one expression with position recording.
/// Caller owns the returned expression; `positions` and `tokens` are
/// caller-provided so their lifetimes outlive the parse.
fn parseWithPositions(
    allocator: std.mem.Allocator,
    input: []const u8,
    tokens: *std.ArrayList([]const u8),
    positions: *parser_mod.PosMap,
) !*h.Expr {
    var tokenizer = Tokenizer.init(input);
    while (tokenizer.next()) |tok| {
        try tokens.append(allocator, tok);
    }
    var parser = Parser.init(allocator, tokens.*);
    parser.positions = positions;
    return parser.parseExpr();
}

test "positions: tokenLineCol maps offsets across newlines" {
    const source = "(+ 1\n   (mod 3 0)\n   4)";
    // Token "mod" starts at byte 9: line 2, col 5
    const tok = source[9..12];
    try testing.expectEqualStrings("mod", tok);
    const lc = parser_mod.tokenLineCol(source, tok).?;
    try testing.expectEqual(@as(usize, 2), lc.line);
    try testing.expectEqual(@as(usize, 5), lc.col);

    // First byte is line 1, col 1
    const first = parser_mod.tokenLineCol(source, source[0..1]).?;
    try testing.expectEqual(@as(usize, 1), first.line);
    try testing.expectEqual(@as(usize, 1), first.col);

    // A token that isn't a slice into the source has no position
    try testing.expect(parser_mod.tokenLineCol(source, "elsewhere") == null);
}

test "positions: parser records tokens for atoms and lists" {
    const allocator = testing.allocator;
    const input = "(+ 1 (mod 3 0))";

    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);
    var positions = parser_mod.PosMap.init(allocator);
    defer positions.deinit();

    const expr = try parseWithPositions(allocator, input, &tokens, &positions);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    // The outer list is anchored at the opening paren (offset 0)
    const outer_tok = positions.get(expr).?;
    try testing.expectEqual(@as(usize, 1), parser_mod.tokenLineCol(input, outer_tok).?.col);

    // The nested (mod 3 0) list is anchored at its own paren (offset 5)
    const inner = expr.list.items[2];
    const inner_tok = positions.get(inner).?;
    try testing.expectEqual(@as(usize, 6), parser_mod.tokenLineCol(input, inner_tok).?.col);

    // Atoms are recorded too
    const one = expr.list.items[1];
    try testing.expectEqual(@as(usize, 4), parser_mod.tokenLineCol(input, positions.get(one).?).?.col);
}

test "positions: parse error reports the failing token" {
    const allocator = testing.allocator;
    const input = "(+ 1 2))";

    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);

    var tokenizer = Tokenizer.init(input);
    while (tokenizer.next()) |tok| {
        try tokens.append(allocator, tok);
    }
    var parser = Parser.init(allocator, tokens);

    // First expression parses fine
    const expr = try parser.parseExpr();
    expr.deinit(allocator);
    allocator.destroy(expr);

    // The stray ')' fails, and error_token points at it (col 8)
    try testing.expectError(error.UnexpectedToken, parser.parseExpr());
    const lc = parser_mod.tokenLineCol(input, parser.error_token.?).?;
    try testing.expectEqual(@as(usize, 8), lc.col);
}

test "positions: eval error points at the innermost failing subexpression" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const input = "(+ 1\n   (mod 3 0)\n   4)";

    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);
    var positions = parser_mod.PosMap.init(allocator);
    defer positions.deinit();
    defer evaluator.setPositionMap(null);

    const expr = try parseWithPositions(allocator, input, &tokens, &positions);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    evaluator.setPositionMap(&positions);
    try testing.expectError(error.InvalidArgument, h.eval(expr, &env));

    const tok = evaluator.takeErrorPosition().?;
    const lc = parser_mod.tokenLineCol(input, tok).?;
    try testing.expectEqual(@as(usize, 2), lc.line);
    try testing.expectEqual(@as(usize, 4), lc.col); // the '(' of (mod 3 0)
    _ = evaluator.takeErrorContext();
    _ = evaluator.takeCallStack();
}

test "positions: success leaves no stale position" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const input = "(+ 1 2)";

    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);
    var positions = parser_mod.PosMap.init(allocator);
    defer positions.deinit();
    defer evaluator.setPositionMap(null);

    const expr = try parseWithPositions(allocator, input, &tokens, &positions);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    evaluator.setPositionMap(&positions);
    const result = try h.eval(expr, &env);
    result.deinit(allocator);
    allocator.destroy(result);

    try testing.expect(evaluator.takeErrorPosition() == null);
}

test "positions: try recovery discards the failed branch's positions" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const input = "(try (mod 1 0) 42)";

    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);
    var positions = parser_mod.PosMap.init(allocator);
    defer positions.deinit();
    defer evaluator.setPositionMap(null);

    const expr = try parseWithPositions(allocator, input, &tokens, &positions);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    evaluator.setPositionMap(&positions);
    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }
    try testing.expectEqual(@as(f64, 42), result.number);
    try testing.expect(evaluator.takeErrorPosition() == null);
}
