const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;
const eval = @import("evaluator.zig").eval;
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");

pub fn run(allocator: *std.mem.Allocator) !void {
    var env = Env.init(allocator);
    defer env.deinit();

    // Initialize builtins
    try env.putBuiltin("+", builtins.builtin_add);
    try env.putBuiltin("-", builtins.builtin_subtract);
    try env.putBuiltin("*", builtins.builtin_multiply);
    try env.putBuiltin("/", builtins.builtin_divide);
    try env.putBuiltin("simplify", builtins.builtin_simplify);
    try env.putBuiltin("diff", builtins.builtin_diff);

    var stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var buf = std.ArrayList(u8).init(allocator.*);
    defer buf.deinit();

    while (true) {
        try stdout.print("lispium> ", .{});
        try stdin.readUntilDelimiterArrayList(&buf, '\n', 1024 * 1024);
        if (buf.items.len == 0) continue;

        var tokenizer = Tokenizer.init(allocator, buf.items);
        var tokens = std.ArrayList([]const u8).init(allocator.*);
        defer tokens.deinit();

        while (true) {
            const tok = tokenizer.next();
            if (tok == null) break;
            try tokens.append(tok.?);
        }

        var parser = Parser.init(allocator, tokens);
        const expr = parser.parseExpr() catch |err| {
            try stdout.print("Parse error: {}\n", .{err});
            buf.clearRetainingCapacity();
            continue;
        };
        defer expr.deinit(allocator.*);

        const result = eval(expr, &env) catch |err| {
            try stdout.print("Eval error: {}\n", .{err});
            buf.clearRetainingCapacity();
            continue;
        };
        defer result.deinit(allocator.*);

        // Validate and print the result
        validateExpr(result) catch |err| {
            try stdout.print("Validation error: {}\n", .{err});
            buf.clearRetainingCapacity();
            continue;
        };

        printExpr(result, stdout) catch |err| {
            try stdout.print("Print error: {}\n", .{err});
            buf.clearRetainingCapacity();
            continue;
        };
        try stdout.print("\n", .{});
        buf.clearRetainingCapacity();
    }
}

const PrintError = error{
    InvalidPointer,
    InvalidExpression,
    RecursionLimit,
    CyclicExpression,
    OutOfMemory,
} || std.fs.File.WriteError;

const MAX_VALIDATION_DEPTH = 1000;

fn validateExprInner(expr: *const Expr, visited: *std.AutoHashMap(usize, void), depth: usize) PrintError!void {
    if (depth > MAX_VALIDATION_DEPTH) {
        return PrintError.RecursionLimit;
    }

    const ptr_val = @intFromPtr(expr);
    if (ptr_val == 0 or ptr_val == std.math.maxInt(usize)) {
        return PrintError.InvalidPointer;
    }

    // Check for cycles
    if (visited.contains(ptr_val)) {
        return PrintError.CyclicExpression;
    }
    visited.put(ptr_val, {}) catch return PrintError.OutOfMemory;

    switch (expr.*) {
        .number => {},
        .symbol => {},
        .list => |lst| {
            if (lst.items.len > 0) {
                for (lst.items) |item| {
                    const item_ptr = @intFromPtr(item);
                    if (item_ptr == 0 or item_ptr == std.math.maxInt(usize)) {
                        return PrintError.InvalidPointer;
                    }
                    try validateExprInner(item, visited, depth + 1);
                }
            }
        },
    }
}

fn validateExpr(expr: *const Expr) PrintError!void {
    const ptr_val = @intFromPtr(expr);
    if (ptr_val == 0 or ptr_val == std.math.maxInt(usize)) {
        return PrintError.InvalidPointer;
    }
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var visited = std.AutoHashMap(usize, void).init(arena.allocator());
    errdefer visited.deinit();
    try validateExprInner(expr, &visited, 0);
}

fn printExpr(expr: *const Expr, writer: anytype) PrintError!void {
    // Validate entire expression tree first
    try validateExpr(expr);

    switch (expr.*) {
        .number => |n| try writer.print("{d}", .{n}),
        .symbol => |s| try writer.print("{s}", .{s}),
        .list => |lst| {
            if (lst.items.len > 0) {
                try writer.print("(", .{});
                // Print operator
                if (lst.items[0].* == .symbol) {
                    try writer.print("{s}", .{lst.items[0].symbol});
                } else {
                    try printExpr(lst.items[0], writer);
                }

                // Print arguments
                for (lst.items[1..]) |item| {
                    try writer.print(" ", .{});
                    try printExpr(item, writer);
                }
                try writer.print(")", .{});
            } else {
                try writer.print("()", .{});
            }
        },
    }
}
