const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;
const eval = @import("evaluator.zig").eval;
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");

const help_text =
    \\Lispium - A Symbolic Computer Algebra System
    \\
    \\Arithmetic:     (+ a b ...)  (- a b ...)  (* a b ...)  (/ a b)  (^ a b)
    \\Functions:      (sin x)  (cos x)  (tan x)  (exp x)  (ln x)  (log x)  (sqrt x)
    \\Calculus:       (diff expr var)        - differentiate expr w.r.t. var
    \\                (integrate expr var)   - integrate expr w.r.t. var
    \\                (taylor expr var pt n) - Taylor series of order n around pt
    \\Algebra:        (simplify expr)        - simplify expression
    \\                (expand expr)          - expand products/powers
    \\                (solve expr var)       - solve expr = 0 for var
    \\                (substitute expr v e)  - replace v with e in expr
    \\Complex:        (complex re im)        - create complex number
    \\                (real z) (imag z)      - get real/imaginary part
    \\                (conj z) (magnitude z) - conjugate and magnitude
    \\
    \\Examples:
    \\  (+ 1 2 3)                 => 6
    \\  (diff (^ x 3) x)          => (* 3 (^ x 2))
    \\  (solve (- (^ x 2) 4) x)   => (solutions 2 -2)
    \\  (taylor (sin x) x 0 4)    => (+ x (* -0.166... (^ x 3)))
    \\
    \\Type 'help' for this message, 'quit' or Ctrl+D to exit.
;

pub fn run(allocator: std.mem.Allocator) !void {
    var env = Env.init(allocator);
    defer env.deinit();

    // Initialize builtins
    try env.putBuiltin("+", builtins.builtin_add);
    try env.putBuiltin("-", builtins.builtin_subtract);
    try env.putBuiltin("*", builtins.builtin_multiply);
    try env.putBuiltin("/", builtins.builtin_divide);
    try env.putBuiltin("^", builtins.builtin_power);
    try env.putBuiltin("pow", builtins.builtin_power);
    try env.putBuiltin("simplify", builtins.builtin_simplify);
    try env.putBuiltin("diff", builtins.builtin_diff);
    try env.putBuiltin("integrate", builtins.builtin_integrate);
    try env.putBuiltin("expand", builtins.builtin_expand);
    try env.putBuiltin("sin", builtins.builtin_sin);
    try env.putBuiltin("cos", builtins.builtin_cos);
    try env.putBuiltin("tan", builtins.builtin_tan);
    try env.putBuiltin("exp", builtins.builtin_exp);
    try env.putBuiltin("ln", builtins.builtin_ln);
    try env.putBuiltin("log", builtins.builtin_log);
    try env.putBuiltin("sqrt", builtins.builtin_sqrt);
    try env.putBuiltin("substitute", builtins.builtin_substitute);
    try env.putBuiltin("taylor", builtins.builtin_taylor);
    try env.putBuiltin("solve", builtins.builtin_solve);
    try env.putBuiltin("complex", builtins.builtin_complex);
    try env.putBuiltin("real", builtins.builtin_real);
    try env.putBuiltin("imag", builtins.builtin_imag);
    try env.putBuiltin("conj", builtins.builtin_conj);
    try env.putBuiltin("magnitude", builtins.builtin_abs_complex);
    try env.putBuiltin("arg", builtins.builtin_arg);

    const stdout_file = std.fs.File.stdout();
    const stdin_file = std.fs.File.stdin();
    const stdout = stdout_file.deprecatedWriter();
    const stdin = stdin_file.deprecatedReader();
    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    // Print welcome message
    try stdout.print("Lispium v0.1 - Symbolic Computer Algebra System\n", .{});
    try stdout.print("Type 'help' for available commands, 'quit' to exit.\n\n", .{});

    while (true) {
        try stdout.print("lispium> ", .{});
        stdin.readUntilDelimiterArrayList(&buf, '\n', 1024 * 1024) catch |err| {
            if (err == error.EndOfStream) {
                try stdout.print("\nGoodbye!\n", .{});
                break;
            }
            return err;
        };

        // Trim whitespace
        const input = std.mem.trim(u8, buf.items, " \t\r\n");
        if (input.len == 0) {
            buf.clearRetainingCapacity();
            continue;
        }

        // Handle special commands
        if (std.mem.eql(u8, input, "help") or std.mem.eql(u8, input, "?")) {
            try stdout.print("{s}\n", .{help_text});
            buf.clearRetainingCapacity();
            continue;
        }
        if (std.mem.eql(u8, input, "quit") or std.mem.eql(u8, input, "exit")) {
            try stdout.print("Goodbye!\n", .{});
            break;
        }

        var tokenizer = Tokenizer.init(input);
        var tokens: std.ArrayList([]const u8) = .empty;
        defer tokens.deinit(allocator);

        while (true) {
            const tok = tokenizer.next();
            if (tok == null) break;
            try tokens.append(allocator, tok.?);
        }

        if (tokens.items.len == 0) {
            buf.clearRetainingCapacity();
            continue;
        }

        var parser = Parser.init(allocator, tokens);
        const expr = parser.parseExpr() catch |err| {
            const err_msg = switch (err) {
                error.UnexpectedToken => "unexpected token in expression",
                error.UnexpectedEOF => "unexpected end of input (missing closing paren?)",
                error.OutOfMemory => "out of memory",
            };
            try stdout.print("Error: {s}\n", .{err_msg});
            buf.clearRetainingCapacity();
            continue;
        };
        defer {
            expr.deinit(allocator);
            allocator.destroy(expr);
        }

        const result = eval(expr, &env) catch |err| {
            const err_msg = switch (err) {
                error.UnsupportedOperator => "unsupported operator",
                error.InvalidArgument => "invalid argument(s)",
                error.KeyNotFound => "unknown function or variable",
                error.OutOfMemory => "out of memory",
                error.RecursionLimit => "recursion limit exceeded",
            };
            try stdout.print("Error: {s}\n", .{err_msg});
            buf.clearRetainingCapacity();
            continue;
        };
        defer {
            result.deinit(allocator);
            allocator.destroy(result);
        }

        // Validate and print the result
        validateExpr(result) catch |err| {
            try stdout.print("Internal error: {}\n", .{err});
            buf.clearRetainingCapacity();
            continue;
        };

        printExpr(result, stdout) catch |err| {
            try stdout.print("Display error: {}\n", .{err});
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
        .number => |n| {
            // Print integers without decimal points
            if (n == @floor(n) and @abs(n) < 1e15) {
                try writer.print("{d:.0}", .{n});
            } else {
                try writer.print("{d}", .{n});
            }
        },
        .symbol => |s| try writer.print("{s}", .{s}),
        .list => |lst| {
            if (lst.items.len > 0) {
                // Check for complex number - pretty print it
                if (lst.items.len == 3 and lst.items[0].* == .symbol and
                    std.mem.eql(u8, lst.items[0].symbol, "complex") and
                    lst.items[1].* == .number and lst.items[2].* == .number)
                {
                    const real = lst.items[1].number;
                    const imag = lst.items[2].number;

                    if (real == 0 and imag == 0) {
                        try writer.print("0", .{});
                    } else if (real == 0) {
                        // Pure imaginary
                        if (imag == 1) {
                            try writer.print("i", .{});
                        } else if (imag == -1) {
                            try writer.print("-i", .{});
                        } else if (imag == @floor(imag) and @abs(imag) < 1e15) {
                            try writer.print("{d:.0}i", .{imag});
                        } else {
                            try writer.print("{d}i", .{imag});
                        }
                    } else if (imag == 0) {
                        // Pure real
                        if (real == @floor(real) and @abs(real) < 1e15) {
                            try writer.print("{d:.0}", .{real});
                        } else {
                            try writer.print("{d}", .{real});
                        }
                    } else {
                        // Both parts
                        if (real == @floor(real) and @abs(real) < 1e15) {
                            try writer.print("{d:.0}", .{real});
                        } else {
                            try writer.print("{d}", .{real});
                        }
                        if (imag > 0) {
                            if (imag == 1) {
                                try writer.print("+i", .{});
                            } else if (imag == @floor(imag) and @abs(imag) < 1e15) {
                                try writer.print("+{d:.0}i", .{imag});
                            } else {
                                try writer.print("+{d}i", .{imag});
                            }
                        } else {
                            if (imag == -1) {
                                try writer.print("-i", .{});
                            } else if (imag == @floor(imag) and @abs(imag) < 1e15) {
                                try writer.print("{d:.0}i", .{imag});
                            } else {
                                try writer.print("{d}i", .{imag});
                            }
                        }
                    }
                    return;
                }

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
