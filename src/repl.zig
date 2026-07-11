const std = @import("std");
const build_options = @import("build_options");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;
const eval = @import("evaluator.zig").eval;
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");
const registry = @import("registry.zig");
const docs_table = @import("docs.zig");

const version = build_options.version;

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
    \\                (factor expr var)      - factor polynomial
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
    \\Tips:
    \\  - Type 'complete <partial>' for function name completions
    \\  - Type ?function for help on a specific function (e.g., ?diff)
    \\  - Multi-line input: expressions continue until parens are balanced
    \\  - An empty line cancels a pending multi-line expression
    \\  - 'history' lists past inputs; '!!' repeats the last, '!n' recalls entry n
    \\
    \\Type 'help' for this message, 'quit' or Ctrl+D to exit.
;

/// List of all builtin function names for completion and help
/// All documented names (builtins and special forms) from the shared table.
fn allNames() []const []const u8 {
    const names = comptime blk: {
        var list: [docs_table.docs.len][]const u8 = undefined;
        for (docs_table.docs, 0..) |doc, i| list[i] = doc.name;
        const frozen = list;
        break :blk frozen;
    };
    return &names;
}

/// Plain-text help for ?func queries, from the shared docs table.
fn getFunctionHelp(name: []const u8) ?[]const u8 {
    inline for (docs_table.docs) |doc| {
        const text = comptime blk: {
            var t: []const u8 = doc.signature ++ "\n  " ++ doc.summary ++ ".";
            if (doc.example) |ex| {
                t = t ++ "\n  Example: " ++ ex;
            }
            break :blk t;
        };
        if (std.mem.eql(u8, doc.name, name)) return text;
    }
    return null;
}

/// Count parentheses to determine if expression is complete
/// Appends one line to the history file, ignoring failures.
fn appendHistory(io: std.Io, path: []const u8, line: []const u8) void {
    const file = std.Io.Dir.cwd().openFile(io, path, .{ .mode = .write_only }) catch |err| switch (err) {
        error.FileNotFound => std.Io.Dir.cwd().createFile(io, path, .{}) catch return,
        else => return,
    };
    defer file.close(io);
    const end = file.length(io) catch return;
    var offset = end;
    _ = file.writePositional(io, &.{line}, offset) catch return;
    offset += line.len;
    _ = file.writePositional(io, &.{"\n"}, offset) catch return;
}

fn countParens(input: []const u8) i32 {
    var depth: i32 = 0;
    var in_string = false;
    var in_comment = false;
    for (input) |c| {
        if (c == '\n') in_comment = false;
        if (in_comment) continue;
        if (c == '"') in_string = !in_string;
        if (!in_string) {
            if (c == ';') {
                in_comment = true;
                continue;
            }
            if (c == '(') depth += 1;
            if (c == ')') depth -= 1;
        }
    }
    return depth;
}

/// Find completions for a partial function name
fn findCompletions(partial: []const u8, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var completions: std.ArrayList([]const u8) = .empty;
    for (allNames()) |name| {
        if (partial.len == 0 or std.mem.startsWith(u8, name, partial)) {
            try completions.append(allocator, name);
        }
    }
    return completions;
}

/// Extract the current word being typed (for completion)
fn getCurrentWord(input: []const u8) []const u8 {
    if (input.len == 0) return "";

    // Find the start of the current word (after '(' or space)
    var start: usize = input.len;
    var i: usize = input.len;
    while (i > 0) {
        i -= 1;
        const c = input[i];
        if (c == '(' or c == ' ' or c == '\t') {
            start = i + 1;
            break;
        }
        if (i == 0) {
            start = 0;
        }
    }

    return input[start..];
}

pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    return runWithFile(allocator, io, null, null);
}

/// Starts the REPL, optionally (load)ing a file into the session first.
/// `home_dir` enables persistent history at ~/.lispium_history.
pub fn runWithFile(allocator: std.mem.Allocator, io: std.Io, preload: ?[]const u8, home_dir: ?[]const u8) !void {
    // Every evaluated input line is kept alive for the whole session:
    // parsed symbols are slices into these buffers, and anything stored in
    // the environment (defines, rules, lambdas) must remain valid.
    var session_inputs: std.ArrayList([]u8) = .empty;
    defer {
        for (session_inputs.items) |input| allocator.free(input);
        session_inputs.deinit(allocator);
    }

    var env = Env.init(allocator);
    defer env.deinit();

    // Initialize builtins (shared registry: single source of truth)
    try registry.installBuiltins(&env);

    // Persistent history: load previous sessions so history/!!/!n work
    // across restarts, and append this session's inputs
    var history_path_buf: [512]u8 = undefined;
    const history_path: ?[]const u8 = blk: {
        const home = home_dir orelse break :blk null;
        break :blk std.fmt.bufPrint(&history_path_buf, "{s}/.lispium_history", .{home}) catch null;
    };
    if (history_path) |hp| {
        if (std.Io.Dir.cwd().readFileAlloc(io, hp, allocator, .limited(1024 * 1024))) |content| {
            defer allocator.free(content);
            var hist_lines = std.mem.splitScalar(u8, content, '\n');
            while (hist_lines.next()) |hline| {
                const trimmed_h = std.mem.trim(u8, hline, " \t\r");
                if (trimmed_h.len == 0) continue;
                const owned = allocator.dupe(u8, trimmed_h) catch continue;
                session_inputs.append(allocator, owned) catch {
                    allocator.free(owned);
                    continue;
                };
            }
        } else |_| {}
    }

    var stdout_writer: std.Io.File.Writer = .init(.stdout(), io, &.{});
    const stdout = &stdout_writer.interface;

    // Line buffer for stdin (1 MiB max line length, matching the old limit)
    const stdin_buffer = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(stdin_buffer);
    var stdin_reader: std.Io.File.Reader = .init(.stdin(), io, stdin_buffer);
    const stdin = &stdin_reader.interface;

    // Wire (print), (read), and (load) to the same stdio the REPL uses
    env.out = stdout;
    env.in = stdin;
    env.io = io;

    // Multi-line expression buffer
    var expr_buf: std.ArrayList(u8) = .empty;
    defer expr_buf.deinit(allocator);

    // Preload a file into the session when requested (lispium repl file.lspm)
    if (preload) |path| {
        const quoted = try std.fmt.allocPrint(allocator, "(load \"{s}\")", .{path});
        defer allocator.free(quoted);
        var tk = Tokenizer.init(quoted);
        var toks: std.ArrayList([]const u8) = .empty;
        defer toks.deinit(allocator);
        while (tk.next()) |t| try toks.append(allocator, t);
        var p = Parser.init(allocator, toks);
        if (p.parseExpr()) |e| {
            defer {
                e.deinit(allocator);
                allocator.destroy(e);
            }
            if (eval(e, &env)) |r| {
                r.deinit(allocator);
                allocator.destroy(r);
                try stdout.print("loaded {s}\n", .{path});
            } else |_| {
                try stdout.print("failed to load {s}\n", .{path});
            }
        } else |_| {}
    }

    // Print welcome message
    try stdout.print("Lispium {s} - Symbolic Computer Algebra System\n", .{version});
    try stdout.print("Type 'help' for commands, '?func' for function help, 'quit' to exit.\n\n", .{});

    while (true) {
        // Show different prompt for continuation lines
        if (expr_buf.items.len == 0) {
            try stdout.print("lispium> ", .{});
        } else {
            try stdout.print("      .. ", .{});
        }

        const maybe_line = stdin.takeDelimiter('\n') catch |err| {
            if (err == error.StreamTooLong) {
                try stdout.print("Error: input line too long\n", .{});
                break;
            }
            return err;
        };
        const raw_line = maybe_line orelse {
            try stdout.print("\nGoodbye!\n", .{});
            break;
        };

        // Trim whitespace from this line
        const line = std.mem.trim(u8, raw_line, " \t\r\n");

        // Handle empty line
        if (line.len == 0) {
            if (expr_buf.items.len == 0) {
                continue;
            }
            // In multiline mode, an empty line cancels the pending input
            // (escape hatch for unbalanced parens)
            try stdout.print("(input cancelled)\n", .{});
            expr_buf.clearRetainingCapacity();
            continue;
        }

        // Handle special commands (only on first line)
        if (expr_buf.items.len == 0) {
            if (std.mem.eql(u8, line, "history")) {
                for (session_inputs.items, 1..) |input_line, num| {
                    try stdout.print("{d: >4}  {s}\n", .{ num, input_line });
                }
                continue;
            }
            if (std.mem.eql(u8, line, "help")) {
                try stdout.print("{s}\n", .{help_text});
                continue;
            }
            if (std.mem.eql(u8, line, "quit") or std.mem.eql(u8, line, "exit")) {
                try stdout.print("Goodbye!\n", .{});
                break;
            }

            // Handle ?function help queries
            if (line.len > 1 and line[0] == '?') {
                const func_name = line[1..];
                if (getFunctionHelp(func_name)) |help| {
                    try stdout.print("{s}\n", .{help});
                } else {
                    // Check if it's a valid function name
                    var found = false;
                    for (allNames()) |name| {
                        if (std.mem.eql(u8, name, func_name)) {
                            found = true;
                            break;
                        }
                    }
                    if (found) {
                        try stdout.print("{s}: builtin function (no detailed help available)\n", .{func_name});
                    } else {
                        try stdout.print("Unknown function: {s}\n", .{func_name});
                        // Suggest similar names
                        const partial = func_name;
                        var suggestions = try findCompletions(partial, allocator);
                        defer suggestions.deinit(allocator);
                        if (suggestions.items.len > 0 and suggestions.items.len <= 10) {
                            try stdout.print("Did you mean: ", .{});
                            for (suggestions.items, 0..) |s, i| {
                                if (i > 0) try stdout.print(", ", .{});
                                try stdout.print("{s}", .{s});
                            }
                            try stdout.print("?\n", .{});
                        }
                    }
                }
                continue;
            }

            // Handle TAB completion request (user types partial name and TAB shows as special char)
            // For now, handle 'complete <partial>' command
            if (std.mem.startsWith(u8, line, "complete ")) {
                const partial = line[9..];
                var completions = try findCompletions(partial, allocator);
                defer completions.deinit(allocator);
                if (completions.items.len == 0) {
                    try stdout.print("No completions for '{s}'\n", .{partial});
                } else if (completions.items.len == 1) {
                    try stdout.print("{s}\n", .{completions.items[0]});
                } else {
                    for (completions.items) |c| {
                        try stdout.print("  {s}\n", .{c});
                    }
                }
                continue;
            }
        }

        // Strip trailing ';' comment (unless inside a string)
        var code_end: usize = line.len;
        var in_str = false;
        for (line, 0..) |c, i| {
            if (c == '"') in_str = !in_str;
            if (c == ';' and !in_str) {
                code_end = i;
                break;
            }
        }
        var code = std.mem.trim(u8, line[0..code_end], " \t");
        if (code.len == 0) continue;

        // History recall: !! repeats the last input, !n recalls entry n
        if (expr_buf.items.len == 0 and code.len >= 2 and code[0] == '!') {
            if (std.mem.eql(u8, code, "!!")) {
                if (session_inputs.items.len == 0) {
                    try stdout.print("history is empty\n", .{});
                    continue;
                }
                code = session_inputs.items[session_inputs.items.len - 1];
                try stdout.print("{s}\n", .{code});
            } else if (std.fmt.parseInt(usize, code[1..], 10)) |num| {
                if (num == 0 or num > session_inputs.items.len) {
                    try stdout.print("no history entry {d}\n", .{num});
                    continue;
                }
                code = session_inputs.items[num - 1];
                try stdout.print("{s}\n", .{code});
            } else |_| {}
        }

        // Append line to expression buffer
        if (expr_buf.items.len > 0) {
            try expr_buf.append(allocator, ' ');
        }
        try expr_buf.appendSlice(allocator, code);

        // Check if expression is complete (balanced parens)
        const paren_depth = countParens(expr_buf.items);
        if (paren_depth > 0) {
            // Need more input
            continue;
        }

        // Expression complete, process it. Copy into session-lived storage
        // first: symbols are slices into this buffer and may be stored in env.
        const trimmed_input = std.mem.trim(u8, expr_buf.items, " \t\r\n");
        const input = try allocator.dupe(u8, trimmed_input);
        try session_inputs.append(allocator, input);

        // Append to the persistent history file (best effort)
        if (history_path) |hp| {
            appendHistory(io, hp, input);
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
            expr_buf.clearRetainingCapacity();
            continue;
        }

        // New-user hint: Lispium is prefix-only
        if (@import("parser.zig").looksLikeInfix(tokens.items)) {
            try stdout.print("hint: Lispium uses prefix notation, e.g. (+ 1 2) or (sin x)\n", .{});
        }

        var parser = Parser.init(allocator, tokens);
        const expr = parser.parseExpr() catch |err| {
            const err_msg = switch (err) {
                error.UnexpectedToken => "unexpected token in expression",
                error.UnexpectedEOF => "unexpected end of input (missing closing paren?)",
                error.RecursionLimit => "expression too deeply nested",
                error.UnterminatedString => "unterminated string literal",
                error.InvalidEscape => "invalid escape sequence in string (use \\n \\t \\r \\\\ \\\")",
                error.OutOfMemory => "out of memory",
            };
            try stdout.print("Error: {s}\n", .{err_msg});
            expr_buf.clearRetainingCapacity();
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
                error.RecursionLimit => "recursion or iteration limit exceeded",
                error.InvalidLambda => "invalid lambda expression",
                error.InvalidDefine => "invalid define expression",
                error.InvalidSyntax => "malformed special form (wrong shape or argument count)",
                error.WrongNumberOfArguments => "wrong number of arguments",
                error.EvaluationError => "evaluation error",
                error.Undefined => "result is mathematically undefined at this point",
            };
            const ctx = @import("evaluator.zig").takeErrorContext();
            if (ctx.len > 0) {
                try stdout.print("Error: {s} (in '{s}')\n", .{ err_msg, ctx });
            } else {
                try stdout.print("Error: {s}\n", .{err_msg});
            }
            const frames = @import("evaluator.zig").takeCallStack();
            if (frames.len > 0) {
                try stdout.print("  call stack:", .{});
                var fi = frames.len;
                while (fi > 0) {
                    fi -= 1;
                    try stdout.print(" {s}", .{frames[fi]});
                    if (fi > 0) try stdout.print(" <-", .{});
                }
                try stdout.print("\n", .{});
            }
            expr_buf.clearRetainingCapacity();
            continue;
        };
        defer {
            result.deinit(allocator);
            allocator.destroy(result);
        }

        // Validate and print the result
        validateExpr(result) catch |err| {
            try stdout.print("Internal error: {}\n", .{err});
            expr_buf.clearRetainingCapacity();
            continue;
        };

        printExpr(result, stdout) catch |err| {
            try stdout.print("Display error: {}\n", .{err});
            expr_buf.clearRetainingCapacity();
            continue;
        };
        try stdout.print("\n", .{});

        // Bind _ to the last result for quick reuse
        if (@import("symbolic.zig").copyExpr(result, allocator)) |last| {
            if (env.get("_")) |old_val| {
                old_val.deinit(allocator);
                allocator.destroy(old_val);
            } else |_| {}
            env.put("_", last) catch {
                last.deinit(allocator);
                allocator.destroy(last);
            };
        } else |_| {}

        expr_buf.clearRetainingCapacity();
    }
}

const PrintError = error{
    InvalidPointer,
    InvalidExpression,
    RecursionLimit,
    CyclicExpression,
    OutOfMemory,
} || std.Io.Writer.Error;

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
        .symbol, .owned_symbol, .string => {},
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
    } else if (@abs(n) >= 1e15) {
        // Very large magnitudes: scientific notation instead of hundreds
        // of decimal digits
        try writer.print("{e}", .{n});
    } else {
        try writer.print("{d}", .{n});
    }
}

fn printExpr(expr: *const Expr, writer: anytype) PrintError!void {
    try printExprPretty(expr, writer, true);
}


/// Writes a string literal with escapes so output is valid Lispium syntax.
fn writeEscapedString(writer: anytype, s: []const u8) !void {
    try writer.print("\"", .{});
    for (s) |c| {
        switch (c) {
            '"' => try writer.print("\\\"", .{}),
            '\\' => try writer.print("\\\\", .{}),
            '\n' => try writer.print("\\n", .{}),
            '\t' => try writer.print("\\t", .{}),
            '\r' => try writer.print("\\r", .{}),
            else => try writer.print("{c}", .{c}),
        }
    }
    try writer.print("\"", .{});
}

fn printExprPretty(expr: *const Expr, writer: anytype, is_top: bool) PrintError!void {
    // Validate entire expression tree first
    if (is_top) {
        try validateExpr(expr);
    }

    switch (expr.*) {
        .number => |n| try printNum(n, writer),
        .string => |s| try writeEscapedString(writer, s),
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
        .lambda => try writer.print("<lambda>", .{}),
        .list => |lst| {
            if (lst.items.len == 0) {
                try writer.print("()", .{});
                return;
            }

            // Get operator if it's a symbol
            const op = if (lst.items[0].* == .symbol) lst.items[0].symbol else null;

            // Raw text results (plots, SVG, step-by-step output): print the
            // text itself without wrapping it in an S-expression
            if (op != null and lst.items.len == 2 and
                (std.mem.eql(u8, op.?, "plot") or std.mem.eql(u8, op.?, "svg") or std.mem.eql(u8, op.?, "steps")))
            {
                switch (lst.items[1].*) {
                    .symbol, .owned_symbol => |text| {
                        try writer.print("{s}", .{text});
                        return;
                    },
                    else => {},
                }
            }

            // Physical quantities print as value followed by units
            if (op != null and std.mem.eql(u8, op.?, "qty") and lst.items.len == 9 and
                lst.items[1].* == .number)
            {
                try printNum(lst.items[1].number, writer);
                const names = [_][]const u8{ "m", "kg", "s", "A", "K", "mol", "cd" };
                // Positive-exponent units first
                var wrote_unit = false;
                for (names, 0..) |name, i| {
                    if (lst.items[i + 2].* != .number) continue;
                    const d = lst.items[i + 2].number;
                    if (d > 0) {
                        try writer.print("{s}{s}", .{ if (wrote_unit) "\xc2\xb7" else " ", name });
                        if (d != 1) try writer.print("^{d}", .{d});
                        wrote_unit = true;
                    }
                }
                var first_div = true;
                for (names, 0..) |name, i| {
                    if (lst.items[i + 2].* != .number) continue;
                    const d = lst.items[i + 2].number;
                    if (d < 0) {
                        if (!wrote_unit and first_div) try writer.print(" 1", .{});
                        try writer.print("{s}{s}", .{ if (first_div) "/" else "\xc2\xb7", name });
                        if (d != -1) try writer.print("^{d}", .{-d});
                        first_div = false;
                    }
                }
                return;
            }

            // Exact rationals print as p/q
            if (op != null and std.mem.eql(u8, op.?, "rational") and lst.items.len == 3 and
                lst.items[1].* == .number and lst.items[2].* == .number)
            {
                try printNum(lst.items[1].number, writer);
                try writer.print("/", .{});
                try printNum(lst.items[2].number, writer);
                return;
            }

            // Prime factorization: (factors (2 2) (3 1)) -> 2^2 · 3
            if (op != null and std.mem.eql(u8, op.?, "factors") and lst.items.len > 1) {
                for (lst.items[1..], 0..) |pair, i| {
                    if (i > 0) try writer.print(" Â· ", .{}); // ·
                    if (pair.* == .list and pair.list.items.len == 2) {
                        try printExprPretty(pair.list.items[0], writer, false);
                        if (pair.list.items[1].* == .number and pair.list.items[1].number != 1) {
                            try writer.print("^", .{});
                            try printExprPretty(pair.list.items[1], writer, false);
                        }
                    } else {
                        try printExprPretty(pair, writer, false);
                    }
                }
                return;
            }

            // Quaternion: (quat w x y z) -> w + xi + yj + zk
            if (op != null and std.mem.eql(u8, op.?, "quat") and lst.items.len == 5 and
                lst.items[1].* == .number and lst.items[2].* == .number and
                lst.items[3].* == .number and lst.items[4].* == .number)
            {
                try printNum(lst.items[1].number, writer);
                const units = [_][]const u8{ "i", "j", "k" };
                for (lst.items[2..5], 0..) |comp, i| {
                    const v = comp.number;
                    if (v >= 0) {
                        try writer.print(" + ", .{});
                        try printNum(v, writer);
                    } else {
                        try writer.print(" - ", .{});
                        try printNum(-v, writer);
                    }
                    try writer.print("{s}", .{units[i]});
                }
                return;
            }

            // Finite field element: (gf 3 7) -> 3 (mod 7)
            if (op != null and std.mem.eql(u8, op.?, "gf") and lst.items.len == 3 and
                lst.items[1].* == .number and lst.items[2].* == .number)
            {
                try printNum(lst.items[1].number, writer);
                try writer.print(" (mod ", .{});
                try printNum(lst.items[2].number, writer);
                try writer.print(")", .{});
                return;
            }

            // Continued fraction: (cf 3 7 15) -> [3; 7, 15]
            if (op != null and std.mem.eql(u8, op.?, "cf") and lst.items.len > 1) {
                try writer.print("[", .{});
                for (lst.items[1..], 0..) |item, i| {
                    if (i == 1) try writer.print("; ", .{});
                    if (i > 1) try writer.print(", ", .{});
                    try printExprPretty(item, writer, false);
                }
                try writer.print("]", .{});
                return;
            }

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

            // Power printing: (^ x 0.5) as âx, superscripts for 2/3,
            // parenthesized bases when the base is compound (avoids xÂ²^0.5)
            if (op != null and std.mem.eql(u8, op.?, "^") and lst.items.len == 3) {
                if (lst.items[2].* == .number and lst.items[2].number == 0.5) {
                    try writer.print("â(", .{}); // â
                    try printExprPretty(lst.items[1], writer, false);
                    try writer.print(")", .{});
                    return;
                }
                const base_is_atom = lst.items[1].* == .number or lst.items[1].* == .symbol or lst.items[1].* == .owned_symbol;
                if (!base_is_atom) try writer.print("(", .{});
                try printExprPretty(lst.items[1], writer, false);
                if (!base_is_atom) try writer.print(")", .{});
                if (lst.items[2].* == .number) {
                    const exp = lst.items[2].number;
                    if (exp == 2) {
                        try writer.print("Â²", .{}); // Â²
                        return;
                    } else if (exp == 3) {
                        try writer.print("Â³", .{}); // Â³
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

            // Infix operators: +, -, *, / (outer parens omitted at top level)
            if (op != null and (std.mem.eql(u8, op.?, "+") or std.mem.eql(u8, op.?, "-") or
                std.mem.eql(u8, op.?, "*") or std.mem.eql(u8, op.?, "/")))
            {
                const op_char = op.?;
                const op_sym = if (std.mem.eql(u8, op_char, "*"))
                    "Â·" // Â·
                else if (std.mem.eql(u8, op_char, "/"))
                    "/"
                else
                    op_char;

                // Unary minus: -x
                if (std.mem.eql(u8, op_char, "-") and lst.items.len == 2) {
                    try writer.print("-", .{});
                    try printExprPretty(lst.items[1], writer, false);
                    return;
                }

                if (!is_top) try writer.print("(", .{});
                for (lst.items[1..], 0..) |item, i| {
                    if (i > 0) {
                        try writer.print(" {s} ", .{op_sym});
                    }
                    try printExprPretty(item, writer, false);
                }
                if (!is_top) try writer.print(")", .{});
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
