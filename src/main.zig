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
        mainWrapper,
        .{init},
    );
    thread.join();
}

fn mainWrapper(init: std.process.Init) !void {
    mainImpl(init) catch |err| switch (err) {
        // A closed pipe (e.g. `lispium docs | head`) is not an error
        error.WriteFailed => return,
        else => return err,
    };
}

fn mainImpl(init: std.process.Init) !void {
    // This thread has a 256 MiB stack (see main), so the evaluator can
    // recurse much deeper than the conservative library default
    evaluator.max_eval_depth = evaluator.MAX_EVAL_DEPTH;

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
            // Optional file argument preloads definitions into the session
            const preload = args_it.next();
            const home = init.minimal.environ.getAlloc(allocator, "HOME") catch
                init.minimal.environ.getAlloc(allocator, "USERPROFILE") catch null;
            defer if (home) |h| allocator.free(h);
            try repl.runWithFile(allocator, io, preload, home);
            return;
        } else if (std.mem.eql(u8, cmd, "eval")) {
            // Evaluate an expression: lispium eval "(+ 1 2)"  (or - for stdin)
            const expr_arg = args_it.next() orelse {
                try stderr.print("Usage: lispium eval \"<expression>\" (or - to read stdin)\n", .{});
                return;
            };
            var stdin_text: ?[]u8 = null;
            defer if (stdin_text) |t| allocator.free(t);
            const expr_str = if (std.mem.eql(u8, expr_arg, "-")) blk: {
                var rbuf: [64 * 1024]u8 = undefined;
                var rdr: std.Io.File.Reader = .init(.stdin(), io, &rbuf);
                var collected: std.Io.Writer.Allocating = .init(allocator);
                defer collected.deinit();
                _ = rdr.interface.streamRemaining(&collected.writer) catch {};
                stdin_text = try collected.toOwnedSlice();
                break :blk stdin_text.?;
            } else expr_arg;
            const ok = try evalExpression(allocator, io, expr_str, stdout, stderr);
            if (!ok) std.process.exit(1);
            return;
        } else if (std.mem.eql(u8, cmd, "run")) {
            // Run a file: lispium run file.lisp
            var file_path: ?[]const u8 = null;
            var watch = false;
            var timed = false;
            var profile = false;
            var script_args: std.ArrayList([]const u8) = .empty;
            defer script_args.deinit(allocator);
            while (args_it.next()) |a| {
                if (file_path == null and std.mem.eql(u8, a, "--watch")) {
                    watch = true;
                } else if (file_path == null and std.mem.eql(u8, a, "--time")) {
                    timed = true;
                } else if (file_path == null and std.mem.eql(u8, a, "--profile")) {
                    profile = true;
                } else if (file_path == null) {
                    file_path = a;
                } else {
                    try script_args.append(allocator, a);
                }
            }
            const path = file_path orelse {
                try stderr.print("Usage: lispium run [--watch] [--time] <file.lspm> [args...]\n", .{});
                return;
            };

            if (watch) {
                try watchFile(allocator, io, path, script_args.items, stdout, stderr);
                return;
            }

            const start = if (timed) std.Io.Timestamp.now(io, .awake).nanoseconds else 0;
            const ok = if (profile)
                try runFileProfiled(allocator, io, path, script_args.items, stdout, stderr)
            else
                try runFile(allocator, io, path, script_args.items, stdout, stderr);
            if (timed) {
                const us: u64 = @intCast(@max(0, @divTrunc(std.Io.Timestamp.now(io, .awake).nanoseconds - start, 1000)));
                try stderr.print("total: {d}.{d:0>3}ms\n", .{ us / 1000, us % 1000 });
            }
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
        } else if (std.mem.eql(u8, cmd, "completions")) {
            // Shell completion scripts: lispium completions bash|zsh|fish
            const shell = args_it.next() orelse {
                try stderr.print("Usage: lispium completions bash|zsh|fish\n", .{});
                std.process.exit(1);
            };
            try printCompletions(stdout, shell, stderr);
            return;
        } else if (std.mem.eql(u8, cmd, "docs")) {
            // lispium docs           -> list all documented names
            // lispium docs <name>    -> terminal docs for one function
            // lispium docs --html    -> full static reference site to stdout
            const docs_table = @import("docs.zig");
            if (args_it.next()) |arg| {
                if (std.mem.eql(u8, arg, "--html")) {
                    try @import("docsite.zig").writeHtml(stdout);
                    return;
                }
                if (docs_table.find(arg)) |doc| {
                    try stdout.print("{s}\n  {s}.\n", .{ doc.signature, doc.summary });
                    if (doc.example) |ex| try stdout.print("  Example: {s}\n", .{ex});
                } else {
                    try stderr.print("No documentation for '{s}'\n", .{arg});
                    std.process.exit(1);
                }
                return;
            }
            for (docs_table.docs) |doc| {
                try stdout.print("{s: <18} {s}\n", .{ doc.name, doc.signature });
            }
            return;
        } else if (std.mem.eql(u8, cmd, "test")) {
            // Run *_test.lspm files: lispium test [dir|files...]
            var files: std.ArrayList([]const u8) = .empty;
            defer files.deinit(allocator);
            var owned_paths: std.ArrayList([]u8) = .empty;
            defer {
                for (owned_paths.items) |p| allocator.free(p);
                owned_paths.deinit(allocator);
            }
            var explicit: std.ArrayList([]const u8) = .empty;
            defer explicit.deinit(allocator);
            while (args_it.next()) |a| try explicit.append(allocator, a);
            if (explicit.items.len == 0) try explicit.append(allocator, ".");
            for (explicit.items) |path| {
                if (try collectTestFiles(allocator, io, path, &owned_paths, &files, stderr)) continue;
                try files.append(allocator, path);
            }
            if (files.items.len == 0) {
                try stderr.print("No *_test.lspm files found\n", .{});
                std.process.exit(1);
            }
            var failed: usize = 0;
            for (files.items) |path| {
                const ok = try runFileImpl(allocator, io, path, &.{}, stdout, stderr, true, false);
                if (ok) {
                    try stdout.print("ok   {s}\n", .{path});
                } else {
                    try stdout.print("FAIL {s}\n", .{path});
                    failed += 1;
                }
            }
            try stdout.print("\n{d} file(s), {d} failed\n", .{ files.items.len, failed });
            if (failed > 0) std.process.exit(1);
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

            // '-' formats stdin to stdout (editor integration)
            if (files.items.len == 1 and std.mem.eql(u8, files.items[0], "-")) {
                var rbuf: [64 * 1024]u8 = undefined;
                var rdr: std.Io.File.Reader = .init(.stdin(), io, &rbuf);
                var collected: std.Io.Writer.Allocating = .init(allocator);
                defer collected.deinit();
                _ = rdr.interface.streamRemaining(&collected.writer) catch {};
                const source = try collected.toOwnedSlice();
                defer allocator.free(source);
                const formatted = formatter.format(allocator, source) catch |err| {
                    const msg = switch (err) {
                        error.UnbalancedParens => "unbalanced parentheses",
                        error.OutOfMemory => "out of memory",
                    };
                    try stderr.print("format error: {s}\n", .{msg});
                    std.process.exit(1);
                };
                defer allocator.free(formatted);
                try stdout.print("{s}", .{formatted});
                return;
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

/// Recursively collects *_test.lspm files from a directory. Returns false
/// when `path` is not a directory.
fn collectTestFiles(
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
            return true;
        },
    };
    defer dir.close(io);

    var walker = dir.walkSelectively(allocator) catch return error.OutOfMemory;
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory) {
            const skip = std.mem.startsWith(u8, entry.basename, ".") or
                std.mem.eql(u8, entry.basename, "zig-out") or
                std.mem.eql(u8, entry.basename, "node_modules");
            if (!skip) try walker.enter(io, entry);
            continue;
        }
        if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, "_test.lspm")) {
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
        \\  lispium repl [file.lspm]  Start interactive REPL (optionally preloading a file)
        \\  lispium eval "<expr>"     Evaluate a single expression
        \\  lispium run <file.lspm>   Run a file (--watch, --time, --profile)
        \\  lispium fmt [paths...]    Format source in place (--check for CI, --stdout to print)
        \\  lispium test [dir|files]  Run *_test.lspm files (assert-based tests)
        \\  lispium docs [name|--html] Builtin reference (terminal or static site)
        \\  lispium completions <sh>  Shell completions (bash, zsh, fish)
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

fn evalExpression(allocator: std.mem.Allocator, io: std.Io, input: []const u8, stdout: anytype, stderr: anytype) !bool {
    var env = Env.init(allocator);
    defer env.deinit();
    try registry.installBuiltins(&env);

    // Wire (print), (read), and (load) to the process stdio and io
    env.out = stdout;
    env.io = io;
    var stdin_buffer: [64 * 1024]u8 = undefined;
    var stdin_reader: std.Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    env.in = &stdin_reader.interface;

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
                error.UnterminatedString => "unterminated string literal",
                error.InvalidEscape => "invalid escape sequence in string (use \\n \\t \\r \\\\ \\\")",
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
            try printCallStack(stderr);
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

fn runFile(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8, script_args: []const []const u8, stdout: anytype, stderr: anytype) !bool {
    return runFileImpl(allocator, io, file_path, script_args, stdout, stderr, false, false);
}

/// Like runFile, but prints per-statement wall time sorted by cost.
fn runFileProfiled(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8, script_args: []const []const u8, stdout: anytype, stderr: anytype) !bool {
    return runFileImpl(allocator, io, file_path, script_args, stdout, stderr, false, true);
}

fn runFileImpl(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8, script_args: []const []const u8, stdout: anytype, stderr: anytype, quiet: bool, profile: bool) !bool {
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

    // Wire (print), (read), and (load) to the process stdio and io
    env.out = stdout;
    env.io = io;
    env.script_args = script_args;
    var stdin_buffer: [64 * 1024]u8 = undefined;
    var stdin_reader: std.Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    env.in = &stdin_reader.interface;

    // Process expressions, handling multi-line expressions
    var line_num: usize = 0;
    var start_line: usize = 0;
    const ProfileEntry = struct { line: usize, text: []u8, ns: i96 };
    var profile_entries: std.ArrayList(ProfileEntry) = .empty;
    defer {
        for (profile_entries.items) |e| allocator.free(e.text);
        profile_entries.deinit(allocator);
    }

    var had_error = false;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var expr_buf: std.ArrayList(u8) = .empty;
    defer expr_buf.deinit(allocator);
    var paren_depth: i32 = 0;

    while (lines.next()) |raw_line| {
        line_num += 1;

        // Skip a shebang line so .lspm files can be executable scripts
        if (line_num == 1 and std.mem.startsWith(u8, raw_line, "#!")) continue;

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
                error.UnterminatedString => "unterminated string literal",
                error.InvalidEscape => "invalid escape sequence in string (use \\n \\t \\r \\\\ \\\")",
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
            const eval_start = if (profile) std.Io.Timestamp.now(io, .awake).nanoseconds else 0;
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
                try printCallStack(stderr);
                had_error = true;
                expr_buf.clearRetainingCapacity();
                paren_depth = 0;
                continue;
            };
            defer {
                result.deinit(allocator);
                allocator.destroy(result);
            }

            if (profile) {
                const elapsed = std.Io.Timestamp.now(io, .awake).nanoseconds - eval_start;
                const preview_len = @min(expr_buf.items.len, 48);
                const text = try allocator.dupe(u8, expr_buf.items[0..preview_len]);
                try profile_entries.append(allocator, .{ .line = start_line, .text = text, .ns = elapsed });
            }

            // Statements that print for themselves aren't echoed again;
            // quiet mode (the test runner) suppresses all echoes
            const is_print_stmt = quiet or (expr.* == .list and expr.list.items.len > 0 and
                expr.list.items[0].* == .symbol and
                (std.mem.eql(u8, expr.list.items[0].symbol, "print") or
                    std.mem.eql(u8, expr.list.items[0].symbol, "begin")));
            if (is_print_stmt) {
                expr_buf.clearRetainingCapacity();
                paren_depth = 0;
                continue;
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

    if (profile and profile_entries.items.len > 0) {
        // Sort by descending cost
        const byCost = struct {
            fn f(_: void, a: ProfileEntry, b: ProfileEntry) bool {
                return a.ns > b.ns;
            }
        }.f;
        std.mem.sort(ProfileEntry, profile_entries.items, {}, byCost);
        var total: i96 = 0;
        for (profile_entries.items) |e| total += e.ns;
        try stdout.print("\nprofile ({d} statements, {d}.{d:0>3}ms total):\n", .{
            profile_entries.items.len,
            @as(u64, @intCast(@max(0, @divTrunc(total, 1_000_000)))),
            @as(u64, @intCast(@max(0, @mod(@divTrunc(total, 1000), 1000)))),
        });
        for (profile_entries.items) |e| {
            const us: u64 = @intCast(@max(0, @divTrunc(e.ns, 1000)));
            const pct: u64 = if (total > 0) @intCast(@divTrunc(e.ns * 100, total)) else 0;
            try stdout.print("  {d: >8}us {d: >3}%  L{d: <4} {s}\n", .{ us, pct, e.line, e.text });
        }
    }
    return !had_error;
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

/// Reruns a file whenever its modification time changes (polling).
fn watchFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    script_args: []const []const u8,
    stdout: anytype,
    stderr: anytype,
) !void {
    var last_mtime: i128 = 0;
    try stdout.print("watching {s} (Ctrl+C to stop)\n", .{path});
    while (true) {
        const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch {
            std.Io.sleep(io, .fromNanoseconds(300 * std.time.ns_per_ms), .awake) catch return;
            continue;
        };
        const mtime = stat.mtime.nanoseconds;
        if (mtime != last_mtime) {
            last_mtime = mtime;
            try stdout.print("\x1b[2J\x1b[H", .{}); // clear screen
            try stdout.print("=== {s}\n", .{path});
            _ = runFile(allocator, io, path, script_args, stdout, stderr) catch {};
            stdout.flush() catch {};
        }
        std.Io.sleep(io, .fromNanoseconds(300 * std.time.ns_per_ms), .awake) catch return;
    }
}

/// Emits a shell completion script for the CLI.
fn printCompletions(stdout: anytype, shell: []const u8, stderr: anytype) !void {
    const subcommands = "repl eval run fmt test docs completions bench lsp help version";
    if (std.mem.eql(u8, shell, "bash")) {
        try stdout.print(
            \\_lispium() {{
            \\  local cur="${{COMP_WORDS[COMP_CWORD]}}"
            \\  if [ "$COMP_CWORD" -eq 1 ]; then
            \\    COMPREPLY=($(compgen -W "{s}" -- "$cur"))
            \\  else
            \\    COMPREPLY=($(compgen -f -X '!*.lspm' -- "$cur") $(compgen -d -- "$cur"))
            \\  fi
            \\}}
            \\complete -F _lispium lispium
            \\
        , .{subcommands});
    } else if (std.mem.eql(u8, shell, "zsh")) {
        try stdout.print(
            \\#compdef lispium
            \\_arguments '1:command:({s})' '*:file:_files -g "*.lspm"'
            \\
        , .{subcommands});
    } else if (std.mem.eql(u8, shell, "fish")) {
        var it = std.mem.splitScalar(u8, subcommands, ' ');
        while (it.next()) |sub| {
            try stdout.print("complete -c lispium -n '__fish_use_subcommand' -a {s}\n", .{sub});
        }
        try stdout.print("complete -c lispium -a '(__fish_complete_suffix .lspm)'\n", .{});
    } else {
        try stderr.print("Unknown shell '{s}' (expected bash, zsh, or fish)\n", .{shell});
        std.process.exit(1);
    }
}

/// Prints the user-function call chain recorded for the last error.
fn printCallStack(writer: anytype) !void {
    const frames = evaluator.takeCallStack();
    if (frames.len == 0) return;
    try writer.print("  call stack:", .{});
    var i = frames.len;
    while (i > 0) {
        i -= 1;
        try writer.print(" {s}", .{frames[i]});
        if (i > 0) try writer.print(" <-", .{});
    }
    try writer.print("\n", .{});
}

fn printExprSimple(expr: *const Expr, writer: anytype) !void {
    switch (expr.*) {
        .big => |b| try builtins.writeBig(b, writer),
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
        .string => |s| try writeEscapedString(writer, s),
        .list => |lst| {
            if (lst.items.len == 0) {
                try writer.print("()", .{});
                return;
            }
            // Exact rationals print as p/q (re-parseable literal syntax)
            if (lst.items.len == 3 and lst.items[0].* == .symbol and
                std.mem.eql(u8, lst.items[0].symbol, "rational") and
                lst.items[1].* == .number and lst.items[2].* == .number)
            {
                try writer.print("{d}/{d}", .{
                    @as(i64, @intFromFloat(lst.items[1].number)),
                    @as(i64, @intFromFloat(lst.items[2].number)),
                });
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
