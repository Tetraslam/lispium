const std = @import("std");
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const Parser = @import("../parser.zig").Parser;
pub const Expr = @import("../parser.zig").Expr;
pub const eval = @import("../evaluator.zig").eval;
pub const Env = @import("../environment.zig").Env;
pub const builtins = @import("../builtins.zig");
pub const symbolic = @import("../symbolic.zig");

pub fn parseExpr(allocator: std.mem.Allocator, input: []const u8) !*Expr {
    var tokenizer = Tokenizer.init(input);
    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);

    while (tokenizer.next()) |tok| {
        try tokens.append(allocator, tok);
    }

    var parser = Parser.init(allocator, tokens);
    return parser.parseExpr();
}

pub fn exprToString(allocator: std.mem.Allocator, expr: *const Expr) ![]u8 {
    var result: std.Io.Writer.Allocating = .init(allocator);
    errdefer result.deinit();
    try writeExpr(expr, &result.writer);
    return result.toOwnedSlice();
}

pub fn writeExpr(expr: *const Expr, writer: anytype) !void {
    switch (expr.*) {
        .big => |b| try builtins.writeBig(b, writer),
        .dict => |d| {
            try writer.print("(dict", .{});
            var dict_it = d.map.iterator();
            while (dict_it.next()) |entry| {
                try writer.print(" \"{s}\" ", .{entry.key_ptr.*});
                try writeExpr(entry.value_ptr.*, writer);
            }
            try writer.print(")", .{});
        },
        .string => |s| try writer.print("\"{s}\"", .{s}),
        .number => |n| {
            if (n == @floor(n) and @abs(n) < 1e15) {
                try writer.print("{d:.0}", .{n});
            } else {
                try writer.print("{d}", .{n});
            }
        },
        .symbol => |s| try writer.print("{s}", .{s}),
        .owned_symbol => |s| try writer.print("{s}", .{s}),
        .lambda => |lam| {
            try writer.print("(lambda (", .{});
            for (lam.params.items, 0..) |param, i| {
                if (i > 0) try writer.print(" ", .{});
                try writer.print("{s}", .{param});
            }
            try writer.print(") ", .{});
            try writeExpr(lam.body, writer);
            try writer.print(")", .{});
        },
        .list => |lst| {
            if (lst.items.len > 0) {
                try writer.print("(", .{});
                try writeExpr(lst.items[0], writer);
                for (lst.items[1..]) |item| {
                    try writer.print(" ", .{});
                    try writeExpr(item, writer);
                }
                try writer.print(")", .{});
            } else {
                try writer.print("()", .{});
            }
        },
    }
}

pub fn setupEnv(allocator: std.mem.Allocator) !Env {
    var env = Env.init(allocator);
    try @import("../registry.zig").installBuiltins(&env);
    return env;
}
