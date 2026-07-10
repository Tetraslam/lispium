const std = @import("std");
const build_options = @import("build_options");
const repl = @import("repl.zig");
const lsp = @import("lsp.zig");
const bench = @import("bench.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;
const evaluator = @import("evaluator.zig");
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");
const registry = @import("registry.zig");
const formatter = @import("formatter.zig");

pub const version = build_options.version;

pub fn main(init: std.process.Init) !void {
    // Run on a thread with a large stack so the evaluator's recursion-depth
    // guard (MAX_EVAL_DEPTH) triggers a clean error before any native stack
    // overflow can occur.
    const thread = try std.Thread.spawn(
        .{ .stack_size = 256 * 1024 * 1024 },
        mainImpl,
        .{init},
    );
    thread.join();
}

fn mainImpl(init: std.process.Init) !void {
    // The CLI uses the fast thread-safe allocator; leak detection is
    // covered by the test suite (which runs on std.testing.allocator).
    const allocator = std.heap.smp_allocator;
    const io = init.io;

    var args_it = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args_it.deinit();
    _ = args_it.skip(); // skip executable name

    var stdout_writer: std.Io.File.Writer = .init(.stdout(), io, &.{});
    const stdout = &stdout_writer.interface;
    var stderr_writer: std.Io.File.Writer = .init(.stderr(), io, &.{});
    const stderr = &stderr_writer.interface;

    if (args_it.next()) |cmd| {
        if (std.mem.eql(u8, cmd, "repl")) {
            try repl.run(allocator, io);
            return;
        } else if (std.mem.eql(u8, cmd, "eval")) {
            // Evaluate a single expression: lispium eval "(+ 1 2)"
            const expr_str = args_it.next() orelse {
                try stderr.print("Usage: lispium eval \"<expression>\"\n", .{});
                return;
            };
            const ok = try evalExpression(allocator, expr_str, stdout, stderr);
            if (!ok) std.process.exit(1);
            return;
        } else if (std.mem.eql(u8, cmd, "run")) {
            // Run a file: lispium run file.lisp
            const file_path = args_it.next() orelse {
                try stderr.print("Usage: lispium run <file.lisp>\n", .{});
                return;
            };
            const ok = try runFile(allocator, io, file_path, stdout, stderr);
            if (!ok) std.process.exit(1);
            return;
        } else if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
            try printUsage(stdout);
            return;
        } else if (std.mem.eql(u8, cmd, "version") or std.mem.eql(u8, cmd, "--version") or std.mem.eql(u8, cmd, "-v")) {
            try stdout.print("lispium {s}\n", .{version});
            return;
        } else if (std.mem.eql(u8, cmd, "lsp")) {
            try lsp.run(allocator, io);
            return;
        } else if (std.mem.eql(u8, cmd, "fmt")) {
            // Format source files in place (like zig fmt).
            // --check reports unformatted files; --stdout prints instead.
            var check_only = false;
            var to_stdout = false;
            var files: std.ArrayList([]const u8) = .empty;
            defer files.deinit(allocator);
            while (args_it.next()) |arg| {
                if (std.mem.eql(u8, arg, "--check")) {
                    check_only = true;
                } else if (std.mem.eql(u8, arg, "--stdout")) {
                    to_stdout = true;
                } else if (std.mem.eql(u8, arg, "-w") or std.mem.eql(u8, arg, "--write")) {
                    // Writing is the default; accepted for compatibility
                } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                    try stdout.print(
                        \\Usage: lispium fmt [flags] [paths...]
                        \\
                        \\Formats Lispium source to the canonical style (see STYLE.md).
                        \\Files are rewritten in place. Directories are searched
                        \\recursively for .lspm files. With no paths, formats the
                        \\current directory.
                        \\
                        \\Flags:
                        \\  --check    Report unformatted files and exit 1 (CI mode)
                        \\  --stdout   Print formatted source instead of writing
                        \\
                    , .{});
                    return;
                } else {
                    try files.append(allocator, arg);
                }
            }
            if (files.items.len == 0) {
                // Default: format the current directory
                try files.append(allocator, ".");
            }

            // Expand directory arguments into their .lspm files (recursive)
            var expanded: std.ArrayList([]const u8) = .empty;
            var owned_paths: std.ArrayList([]u8) = .empty;
            defer {
                for (owned_paths.items) |p| allocator.free(p);
                owned_paths.deinit(allocator);
                expanded.deinit(allocator);
            }
            for (files.items) |path| {
                if (try collectLspmFiles(allocator, io, path, &owned_paths, &expanded, stderr)) continue;
                try expanded.append(allocator, path);
            }
            if (expanded.items.len == 0) {
                try stderr.print("No .lspm files found\n", .{});
                std.process.exit(1);
            }

            const ok = try formatFiles(allocator, io, expanded.items, check_only, to_stdout, stdout, stderr);
            if (!ok) std.process.exit(1);
            return;
        } else if (std.mem.eql(u8, cmd, "bench")) {
            // Parse bench options
            var mode: bench.OutputMode = .pretty;
            var quick = false;

            while (args_it.next()) |arg| {
                if (std.mem.eql(u8, arg, "--plain")) {
                    mode = .plain;
                } else if (std.mem.eql(u8, arg, "--json")) {
                    mode = .json;
                } else if (std.mem.eql(u8, arg, "--quick") or std.mem.eql(u8, arg, "-q")) {
                    quick = true;
                } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                    try stdout.print(
                        \\Usage: lispium bench [options]
                        \\
                        \\Options:
                        \\  --plain    Output in plain CSV format
                        \\  --json     Output in JSON format
                        \\  --quick    Run fewer iterations (faster)
                        \\  --help     Show this help
                        \\
                    , .{});
                    return;
                }
            }

            try bench.run(allocator, io, mode, quick);
            return;
        }
    }

    try printUsage(stdout);
}

/// If `path` is a directory, recursively collects the .lspm files inside it
/// (skipping hidden directories and build output) and returns true.
/// Returns false when `path` is not a directory.
fn collectLspmFiles(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir_path: []const u8,
    owned_paths: *std.ArrayList([]u8),
    out: *std.ArrayList([]const u8),
    stderr: anytype,
) !bool {
    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| switch (err) {
        error.NotDir => return false,
        else => {
            try stderr.print("Error opening '{s}': {}\n", .{ dir_path, err });
            return true; // handled (as an error); don't treat as a file
        },
    };
    defer dir.close(io);

    var walker = dir.walkSelectively(allocator) catch return error.OutOfMemory;
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory) {
            // Skip hidden directories and build artifacts
            const skip = std.mem.startsWith(u8, entry.basename, ".") or
                std.mem.eql(u8, entry.basename, "zig-out") or
                std.mem.eql(u8, entry.basename, "node_modules");
            if (!skip) try walker.enter(io, entry);
            continue;
        }
        if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, ".lspm")) {
            const full = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
            try owned_paths.append(allocator, full);
            try out.append(allocator, full);
        }
    }
    return true;
}

/// Formats each file in place (the default). --check reports unformatted
/// files and fails; --stdout prints the formatted source instead of writing.
fn formatFiles(
    allocator: std.mem.Allocator,
    io: std.Io,
    files: []const []const u8,
    check_only: bool,
    to_stdout: bool,
    stdout: anytype,
    stderr: anytype,
) !bool {
    var all_ok = true;
    for (files) |path| {
        const source = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024 * 10)) catch |err| {
            try stderr.print("Error reading '{s}': {}\n", .{ path, err });
            all_ok = false;
            continue;
        };
        defer allocator.free(source);

        const formatted = formatter.format(allocator, source) catch |err| {
            const msg = switch (err) {
                error.UnbalancedParens => "unbalanced parentheses",
                error.UnsupportedString => "strings are not supported",
                error.OutOfMemory => "out of memory",
            };
            try stderr.print("{s}: format error: {s}\n", .{ path, msg });
            all_ok = false;
            continue;
        };
        defer allocator.free(formatted);

        if (check_only) {
            if (!std.mem.eql(u8, source, formatted)) {
                try stderr.print("{s}: not formatted\n", .{path});
                all_ok = false;
            }
        } else if (to_stdout) {
            try stdout.print("{s}", .{formatted});
        } else {
            if (!std.mem.eql(u8, source, formatted)) {
                std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = formatted }) catch |err| {
                    try stderr.print("Error writing '{s}': {}\n", .{ path, err });
                    all_ok = false;
                    continue;
                };
                try stdout.print("formatted {s}\n", .{path});
            }
        }
    }
    return all_ok;
}

fn printUsage(writer: anytype) !void {
    try writer.print(
        \\Lispium {s} - A Symbolic Computer Algebra System
        \\
        \\Usage:
        \\  lispium repl              Start interactive REPL
        \\  lispium eval "<expr>"     Evaluate a single expression
        \\  lispium run <file.lspm>   Run a Lispium source file
        \\  lispium fmt [paths...]    Format source in place (--check for CI, --stdout to print)
        \\  lispium bench [options]   Run benchmark suite
        \\  lispium lsp               Start language server (for editors)
        \\  lispium help              Show this help message
        \\  lispium version           Show version information
        \\
        \\Benchmark options:
        \\  --plain    CSV output
        \\  --json     JSON output
        \\  --quick    Fewer iterations
        \\
        \\Examples:
        \\  lispium repl
        \\  lispium eval "(+ 1 2 3)"
        \\  lispium eval "(diff (^ x 3) x)"
        \\  lispium run cookbook/calculus.lspm
        \\  lispium bench --quick
        \\
    , .{version});
}

fn evalExpression(allocator: std.mem.Allocator, input: []const u8, stdout: anytype, stderr: anytype) !bool {
    var env = Env.init(allocator);
    defer env.deinit();
    try registry.installBuiltins(&env);

    // Tokenize
    var tokenizer = Tokenizer.init(input);
    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);

    while (true) {
        const tok = tokenizer.next();
        if (tok == null) break;
        try tokens.append(allocator, tok.?);
    }

    if (tokens.items.len == 0) {
        try stderr.print("Error: empty expression\n", .{});
        return false;
    }

    // New-user hint: Lispium is prefix-only
    if (@import("parser.zig").looksLikeInfix(tokens.items)) {
        try stderr.print("hint: Lispium uses prefix notation, e.g. (+ 1 2) or (sin x)\n", .{});
    }

    // Parse and evaluate every expression in the input (not just the first)
    var parser = Parser.init(allocator, tokens);
    while (parser.position < tokens.items.len) {
        const expr = parser.parseExpr() catch |err| {
            const err_msg = switch (err) {
                error.UnexpectedToken => "unexpected token in expression",
                error.UnexpectedEOF => "unexpected end of input (missing closing paren?)",
                error.RecursionLimit => "expression too deeply nested",
                error.UnsupportedString => "strings are not supported (use numbers and symbols)",
                error.OutOfMemory => "out of memory",
            };
            try stderr.print("Parse error: {s}\n", .{err_msg});
            return false;
        };
        defer {
            expr.deinit(allocator);
            allocator.destroy(expr);
        }

        // Evaluate
        const result = evaluator.eval(expr, &env) catch |err| {
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
            const ctx = evaluator.takeErrorContext();
            if (ctx.len > 0) {
                try stderr.print("Eval error: {s} (in '{s}')\n", .{ err_msg, ctx });
            } else {
                try stderr.print("Eval error: {s}\n", .{err_msg});
            }
            return false;
        };
        defer {
            result.deinit(allocator);
            allocator.destroy(result);
        }

        // Print result
        try printExprSimple(result, stdout);
        try stdout.print("\n", .{});
    }
    return true;
}

fn runFile(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8, stdout: anytype, stderr: anytype) !bool {
    // Read file
    const content = std.Io.Dir.cwd().readFileAlloc(io, file_path, allocator, .limited(1024 * 1024 * 10)) catch |err| {
        try stderr.print("Error reading file '{s}': {}\n", .{ file_path, err });
        return false;
    };
    defer allocator.free(content);

    // Every evaluated statement's text is kept alive for the whole run:
    // parsed symbols are slices into these buffers, and anything stored in
    // the environment (defines, rules, lambdas) must remain valid.
    var session_inputs: std.ArrayList([]u8) = .empty;
    defer {
        for (session_inputs.items) |input| allocator.free(input);
        session_inputs.deinit(allocator);
    }

    var env = Env.init(allocator);
    defer env.deinit();
    try registry.installBuiltins(&env);

    // Process expressions, handling multi-line expressions
    var line_num: usize = 0;
    var start_line: usize = 0;
    var had_error = false;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var expr_buf: std.ArrayList(u8) = .empty;
    defer expr_buf.deinit(allocator);
    var paren_depth: i32 = 0;

    while (lines.next()) |raw_line| {
        line_num += 1;

        // Trim whitespace
        const line = std.mem.trim(u8, raw_line, " \t\r");

        // Skip empty lines and comments (only when not in a multi-line expr)
        if (paren_depth == 0) {
            if (line.len == 0) continue;
            if (line[0] == ';') continue;
            start_line = line_num;
        }

        // Strip trailing comment from non-comment lines
        var code_end: usize = line.len;
        var in_string = false;
        for (line, 0..) |c, i| {
            if (c == '"') in_string = !in_string;
            if (c == ';' and !in_string) {
                code_end = i;
                break;
            }
        }
        const code = std.mem.trim(u8, line[0..code_end], " \t");

        if (code.len == 0 and paren_depth == 0) continue;

        // Append to expression buffer
        if (expr_buf.items.len > 0) {
            try expr_buf.append(allocator, ' ');
        }
        try expr_buf.appendSlice(allocator, code);

        // Count parentheses
        for (code) |c| {
            if (c == '(') paren_depth += 1;
            if (c == ')') paren_depth -= 1;
        }

        // If balanced (or negative = error), evaluate
        if (paren_depth <= 0) {
            if (expr_buf.items.len == 0) {
                paren_depth = 0;
                continue;
            }

            // Copy the statement into session-lived storage before tokenizing
            // (symbols are slices into this buffer and may be stored in env)
            const stable_input = try allocator.dupe(u8, expr_buf.items);
            try session_inputs.append(allocator, stable_input);

            // Tokenize
            var tokenizer = Tokenizer.init(stable_input);
            var tokens: std.ArrayList([]const u8) = .empty;
            defer tokens.deinit(allocator);

            while (true) {
                const tok = tokenizer.next();
                if (tok == null) break;
                try tokens.append(allocator, tok.?);
            }

            if (tokens.items.len == 0) {
                expr_buf.clearRetainingCapacity();
                paren_depth = 0;
                continue;
            }

            // Parse
            var parser = Parser.init(allocator, tokens);
            const expr = parser.parseExpr() catch |err| {
                const err_msg = switch (err) {
                    error.UnexpectedToken => "unexpected token",
                    error.UnexpectedEOF => "unexpected end of input",
                    error.RecursionLimit => "expression too deeply nested",
                error.UnsupportedString => "strings are not supported (use numbers and symbols)",
                    error.OutOfMemory => "out of memory",
                };
                try stderr.print("{s}:{}: Parse error: {s}\n", .{ file_path, start_line, err_msg });
                had_error = true;
                expr_buf.clearRetainingCapacity();
                paren_depth = 0;
                continue;
            };
            defer {
                expr.deinit(allocator);
                allocator.destroy(expr);
            }

            // Evaluate
            const result = evaluator.eval(expr, &env) catch |err| {
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
                const ctx = evaluator.takeErrorContext();
                if (ctx.len > 0) {
                    try stderr.print("{s}:{}: Eval error: {s} (in '{s}')\n", .{ file_path, start_line, err_msg, ctx });
                } else {
                    try stderr.print("{s}:{}: Eval error: {s}\n", .{ file_path, start_line, err_msg });
                }
                had_error = true;
                expr_buf.clearRetainingCapacity();
                paren_depth = 0;
                continue;
            };
            defer {
                result.deinit(allocator);
                allocator.destroy(result);
            }

            // Print a condensed version of the expression and result
            const display_expr = if (expr_buf.items.len > 60)
                expr_buf.items[0..57]
            else
                expr_buf.items;
            const ellipsis: []const u8 = if (expr_buf.items.len > 60) "..." else "";
            try stdout.print("; {s}{s}\n", .{ display_expr, ellipsis });
            try printExprSimple(result, stdout);
            try stdout.print("\n\n", .{});

            expr_buf.clearRetainingCapacity();
            paren_depth = 0;
        }
    }
    return !had_error;
}

fn printExprSimple(expr: *const Expr, writer: anytype) !void {
    switch (expr.*) {
        .number => |n| {
            if (@abs(n - @round(n)) < 1e-10 and @abs(n) < 1e15) {
                try writer.print("{d}", .{@as(i64, @intFromFloat(@round(n)))});
            } else if (@abs(n) >= 1e15) {
                // Scientific notation for very large magnitudes
                try writer.print("{e}", .{n});
            } else {
                try writer.print("{d}", .{n});
            }
        },
        .symbol => |s| try writer.print("{s}", .{s}),
        .owned_symbol => |s| try writer.print("{s}", .{s}),
        .list => |lst| {
            if (lst.items.len == 0) {
                try writer.print("()", .{});
                return;
            }
            // Raw text results (plots, SVG, step-by-step output)
            if (lst.items.len == 2 and lst.items[0].* == .symbol and
                (std.mem.eql(u8, lst.items[0].symbol, "plot") or
                    std.mem.eql(u8, lst.items[0].symbol, "svg") or
                    std.mem.eql(u8, lst.items[0].symbol, "steps")))
            {
                switch (lst.items[1].*) {
                    .symbol, .owned_symbol => |text| {
                        try writer.print("{s}", .{text});
                        return;
                    },
                    else => {},
                }
            }
            try writer.print("(", .{});
            for (lst.items, 0..) |item, i| {
                if (i > 0) try writer.print(" ", .{});
                try printExprSimple(item, writer);
            }
            try writer.print(")", .{});
        },
        .lambda => try writer.print("<lambda>", .{}),
    }
}
