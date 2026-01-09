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
    \\Transcendental: (sin x)  (cos x)  (tan x)  (exp x)  (ln x)  (log x)  (sqrt x)
    \\Calculus:       (diff expr var)        - differentiate
    \\                (diff expr var n)      - nth derivative
    \\                (integrate expr var)   - indefinite integral
    \\                (taylor expr var pt n) - Taylor series
    \\Algebra:        (simplify expr)        - simplify
    \\                (expand expr)          - expand products
    \\                (solve expr var)       - solve equation
    \\                (factor expr)          - factor polynomial
    \\                (collect expr var)     - collect like terms
    \\                (substitute expr v e)  - substitute
    \\Linear Alg:     (matrix (a b) (c d))   - create matrix
    \\                (det M) (inv M)        - determinant, inverse
    \\                (matmul A B)           - matrix multiply
    \\                (eigenvalues M)        - eigenvalues
    \\                (linsolve A b)         - solve Ax=b
    \\Vectors:        (vector x y z)         - create vector
    \\                (dot v1 v2)            - dot product
    \\                (cross v1 v2)          - cross product
    \\Complex:        (complex re im)        - complex number
    \\                (real z) (imag z)      - parts
    \\Boolean:        (and a b) (or a b)     - logic
    \\                (not a) (xor a b)
    \\Modular:        (mod a b) (gcd a b)    - modular arithmetic
    \\                (modpow base exp mod)
    \\Polynomials:    (coeffs a b c)         - coefficient list
    \\                (polydiv p1 p2 x)      - division
    \\                (polygcd p1 p2)        - GCD
    \\Assumptions:    (assume x positive)    - set assumption
    \\                (is? x positive)       - check assumption
    \\
    \\Examples:
    \\  (+ 1 2 3)                 => 6
    \\  (diff (^ x 3) x)          => 3x²
    \\  (solve (- (^ x 2) 4) x)   => {2, -2}
    \\  (det (matrix (1 2) (3 4)))=> -2
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
    try env.putBuiltin("limit", builtins.builtin_limit);
    try env.putBuiltin("rule", builtins.builtin_rule);
    try env.putBuiltin("rewrite", builtins.builtin_rewrite);
    try env.putBuiltin("factor", builtins.builtin_factor);
    try env.putBuiltin("partial-fractions", builtins.builtin_partial_fractions);
    try env.putBuiltin("collect", builtins.builtin_collect);
    // Matrix operations
    try env.putBuiltin("matrix", builtins.builtin_matrix);
    try env.putBuiltin("det", builtins.builtin_det);
    try env.putBuiltin("transpose", builtins.builtin_transpose);
    try env.putBuiltin("trace", builtins.builtin_trace);
    try env.putBuiltin("matmul", builtins.builtin_matmul);
    try env.putBuiltin("inv", builtins.builtin_inv);
    try env.putBuiltin("eigenvalues", builtins.builtin_eigenvalues);
    try env.putBuiltin("eigenvectors", builtins.builtin_eigenvectors);
    try env.putBuiltin("linsolve", builtins.builtin_linsolve);
    // Vector operations
    try env.putBuiltin("vector", builtins.builtin_vector);
    try env.putBuiltin("dot", builtins.builtin_dot);
    try env.putBuiltin("cross", builtins.builtin_cross);
    try env.putBuiltin("norm", builtins.builtin_norm);
    // Boolean algebra
    try env.putBuiltin("and", builtins.builtin_and);
    try env.putBuiltin("or", builtins.builtin_or);
    try env.putBuiltin("not", builtins.builtin_not);
    try env.putBuiltin("xor", builtins.builtin_xor);
    try env.putBuiltin("implies", builtins.builtin_implies);
    // Modular arithmetic
    try env.putBuiltin("mod", builtins.builtin_mod);
    try env.putBuiltin("gcd", builtins.builtin_gcd);
    try env.putBuiltin("lcm", builtins.builtin_lcm);
    try env.putBuiltin("modpow", builtins.builtin_modpow);
    // Polynomial operations
    try env.putBuiltin("coeffs", builtins.builtin_coeffs);
    try env.putBuiltin("polydiv", builtins.builtin_polydiv);
    try env.putBuiltin("polygcd", builtins.builtin_polygcd);
    try env.putBuiltin("polylcm", builtins.builtin_polylcm);
    // Assumptions
    try env.putBuiltin("assume", builtins.builtin_assume);
    try env.putBuiltin("is?", builtins.builtin_is);
    // Comparisons
    try env.putBuiltin("=", builtins.builtin_eq);
    try env.putBuiltin("<", builtins.builtin_lt);
    try env.putBuiltin(">", builtins.builtin_gt);

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
                error.InvalidLambda => "invalid lambda expression",
                error.InvalidDefine => "invalid define expression",
                error.WrongNumberOfArguments => "wrong number of arguments",
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
        .symbol, .owned_symbol => {},
        .lambda => |lam| {
            const body_ptr = @intFromPtr(lam.body);
            if (body_ptr == 0 or body_ptr == std.math.maxInt(usize)) {
                return PrintError.InvalidPointer;
            }
            try validateExprInner(lam.body, visited, depth + 1);
        },
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

fn printNum(n: f64, writer: anytype) !void {
    if (n == @floor(n) and @abs(n) < 1e15) {
        try writer.print("{d:.0}", .{n});
    } else {
        try writer.print("{d}", .{n});
    }
}

fn printExpr(expr: *const Expr, writer: anytype) PrintError!void {
    try printExprPretty(expr, writer, true);
}

fn printExprPretty(expr: *const Expr, writer: anytype, is_top: bool) PrintError!void {
    // Validate entire expression tree first
    if (is_top) {
        try validateExpr(expr);
    }

    switch (expr.*) {
        .number => |n| try printNum(n, writer),
        .symbol, .owned_symbol => |s| {
            // Use Greek letters for common symbols
            if (std.mem.eql(u8, s, "pi")) {
                try writer.print("\xcf\x80", .{}); // π
            } else if (std.mem.eql(u8, s, "e")) {
                try writer.print("e", .{});
            } else if (std.mem.eql(u8, s, "inf")) {
                try writer.print("\xe2\x88\x9e", .{}); // ∞
            } else {
                try writer.print("{s}", .{s});
            }
        },
        .lambda => |_| try writer.print("<lambda>", .{}),
        .list => |lst| {
            if (lst.items.len == 0) {
                try writer.print("()", .{});
                return;
            }

            // Get operator if it's a symbol
            const op = if (lst.items[0].* == .symbol) lst.items[0].symbol else null;

            // Complex number pretty printing
            if (op != null and std.mem.eql(u8, op.?, "complex") and lst.items.len == 3 and
                lst.items[1].* == .number and lst.items[2].* == .number)
            {
                try printComplex(lst.items[1].number, lst.items[2].number, writer);
                return;
            }

            // Vector pretty printing
            if (op != null and std.mem.eql(u8, op.?, "vector")) {
                try writer.print("\xe2\x9f\xa8", .{}); // ⟨
                for (lst.items[1..], 0..) |item, i| {
                    if (i > 0) try writer.print(", ", .{});
                    try printExprPretty(item, writer, false);
                }
                try writer.print("\xe2\x9f\xa9", .{}); // ⟩
                return;
            }

            // Matrix pretty printing (simplified - just show as rows)
            if (op != null and std.mem.eql(u8, op.?, "matrix")) {
                try writer.print("[", .{});
                for (lst.items[1..], 0..) |row, i| {
                    if (i > 0) try writer.print("; ", .{});
                    if (row.* == .list) {
                        for (row.list.items, 0..) |elem, j| {
                            if (j > 0) try writer.print(" ", .{});
                            try printExprPretty(elem, writer, false);
                        }
                    } else {
                        try printExprPretty(row, writer, false);
                    }
                }
                try writer.print("]", .{});
                return;
            }

            // Power with superscript for simple exponents
            if (op != null and std.mem.eql(u8, op.?, "^") and lst.items.len == 3) {
                try printExprPretty(lst.items[1], writer, false);
                if (lst.items[2].* == .number) {
                    const exp = lst.items[2].number;
                    if (exp == 2) {
                        try writer.print("\xc2\xb2", .{}); // ²
                        return;
                    } else if (exp == 3) {
                        try writer.print("\xc2\xb3", .{}); // ³
                        return;
                    }
                }
                try writer.print("^", .{});
                try printExprPretty(lst.items[2], writer, false);
                return;
            }

            // Square root
            if (op != null and std.mem.eql(u8, op.?, "sqrt") and lst.items.len == 2) {
                try writer.print("\xe2\x88\x9a(", .{}); // √
                try printExprPretty(lst.items[1], writer, false);
                try writer.print(")", .{});
                return;
            }

            // Infix operators: +, -, *, /
            if (op != null and (std.mem.eql(u8, op.?, "+") or std.mem.eql(u8, op.?, "-") or
                std.mem.eql(u8, op.?, "*") or std.mem.eql(u8, op.?, "/")))
            {
                const op_char = op.?;
                const op_sym = if (std.mem.eql(u8, op_char, "*"))
                    "\xc2\xb7" // ·
                else if (std.mem.eql(u8, op_char, "/"))
                    "/"
                else
                    op_char;

                try writer.print("(", .{});
                for (lst.items[1..], 0..) |item, i| {
                    if (i > 0) {
                        try writer.print(" {s} ", .{op_sym});
                    }
                    try printExprPretty(item, writer, false);
                }
                try writer.print(")", .{});
                return;
            }

            // Solutions list
            if (op != null and std.mem.eql(u8, op.?, "solutions")) {
                try writer.print("{{", .{});
                for (lst.items[1..], 0..) |item, i| {
                    if (i > 0) try writer.print(", ", .{});
                    try printExprPretty(item, writer, false);
                }
                try writer.print("}}", .{});
                return;
            }

            // Default: S-expression format
            try writer.print("(", .{});
            if (lst.items[0].* == .symbol) {
                try writer.print("{s}", .{lst.items[0].symbol});
            } else {
                try printExprPretty(lst.items[0], writer, false);
            }
            for (lst.items[1..]) |item| {
                try writer.print(" ", .{});
                try printExprPretty(item, writer, false);
            }
            try writer.print(")", .{});
        },
    }
}

fn printComplex(real: f64, imag: f64, writer: anytype) !void {
    if (real == 0 and imag == 0) {
        try writer.print("0", .{});
    } else if (real == 0) {
        if (imag == 1) {
            try writer.print("i", .{});
        } else if (imag == -1) {
            try writer.print("-i", .{});
        } else {
            try printNum(imag, writer);
            try writer.print("i", .{});
        }
    } else if (imag == 0) {
        try printNum(real, writer);
    } else {
        try printNum(real, writer);
        if (imag > 0) {
            if (imag == 1) {
                try writer.print(" + i", .{});
            } else {
                try writer.print(" + ", .{});
                try printNum(imag, writer);
                try writer.print("i", .{});
            }
        } else {
            if (imag == -1) {
                try writer.print(" - i", .{});
            } else {
                try writer.print(" - ", .{});
                try printNum(-imag, writer);
                try writer.print("i", .{});
            }
        }
    }
}
