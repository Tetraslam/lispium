//! WebAssembly entry point for the browser playground.
//!
//! Exports a tiny C ABI:
//!   lispium_alloc(len)        -> pointer for the host to write input into
//!   lispium_eval(ptr, len)    -> pointer to a NUL-terminated result string
//!   lispium_reset()           -> fresh environment (clears definitions)
//!
//! The environment persists between calls so (define ...) works like a REPL
//! session. (print ...) output is captured into the result string.

const std = @import("std");
const Env = @import("environment.zig").Env;
const registry = @import("registry.zig");
const evaluator = @import("evaluator.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const builtins = @import("builtins.zig");

const allocator = std.heap.wasm_allocator;

var env: ?Env = null;
var result_buf: ?[]u8 = null;

fn getEnv() !*Env {
    if (env == null) {
        env = Env.init(allocator);
        try registry.installBuiltins(&env.?);
    }
    return &env.?;
}

export fn lispium_alloc(len: usize) ?[*]u8 {
    const buf = allocator.alloc(u8, len) catch return null;
    return buf.ptr;
}

export fn lispium_reset() void {
    if (env) |*e| {
        e.deinit();
        env = null;
    }
}

/// Evaluates the given source (one or more expressions) and returns a
/// NUL-terminated string with printed output and results, one per line.
export fn lispium_eval(ptr: [*]const u8, len: usize) [*:0]const u8 {
    // Free the previous result
    if (result_buf) |old| {
        allocator.free(old);
        result_buf = null;
    }
    const output = evalToString(ptr[0..len]) catch "error: out of memory";
    // evalToString returns an owned NUL-terminated slice (or a literal on OOM)
    return @ptrCast(output.ptr);
}

fn evalToString(source: []const u8) ![:0]const u8 {
    const e = try getEnv();

    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();

    // Capture (print ...) output into the response
    e.out = &out.writer;
    defer e.out = null;

    // The environment stores symbols that reference the source text, so it
    // must live as long as the session
    const stable = try allocator.dupe(u8, source);
    e.keepBuffer(stable) catch {
        allocator.free(stable);
        return error.OutOfMemory;
    };

    // Strip comments line-by-line (same policy as the file runner)
    var cleaned: std.Io.Writer.Allocating = .init(allocator);
    defer cleaned.deinit();
    var lines = std.mem.splitScalar(u8, stable, '\n');
    while (lines.next()) |line| {
        var in_str = false;
        var end: usize = line.len;
        for (line, 0..) |c, i| {
            if (c == '"') in_str = !in_str;
            if (c == ';' and !in_str) {
                end = i;
                break;
            }
        }
        try cleaned.writer.writeAll(line[0..end]);
        try cleaned.writer.writeAll("\n");
    }
    const clean_src = try cleaned.toOwnedSlice();
    e.keepBuffer(clean_src) catch {
        allocator.free(clean_src);
        return error.OutOfMemory;
    };

    var tokenizer = Tokenizer.init(clean_src);
    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(allocator);
    while (tokenizer.next()) |tok| {
        try tokens.append(allocator, tok);
    }

    if (tokens.items.len == 0) {
        try out.writer.writeAll("");
    } else {
        var parser = Parser.init(allocator, tokens);
        while (parser.position < tokens.items.len) {
            const expr = parser.parseExpr() catch |err| {
                const msg = switch (err) {
                    error.UnexpectedToken => "parse error: unexpected token",
                    error.UnexpectedEOF => "parse error: missing closing paren",
                    error.RecursionLimit => "parse error: too deeply nested",
                    error.UnterminatedString => "parse error: unterminated string",
                    error.InvalidEscape => "parse error: invalid string escape",
                    error.OutOfMemory => "out of memory",
                };
                try out.writer.print("{s}\n", .{msg});
                break;
            };
            defer {
                expr.deinit(allocator);
                allocator.destroy(expr);
            }

            const result = evaluator.eval(expr, e) catch |err| {
                const msg = switch (err) {
                    error.UnsupportedOperator => "error: unsupported operator",
                    error.InvalidArgument => "error: invalid argument(s)",
                    error.KeyNotFound => "error: unknown function or variable",
                    error.OutOfMemory => "error: out of memory",
                    error.RecursionLimit => "error: recursion or iteration limit exceeded",
                    error.InvalidLambda => "error: invalid lambda expression",
                    error.InvalidDefine => "error: invalid define expression",
                    error.InvalidSyntax => "error: malformed special form",
                    error.WrongNumberOfArguments => "error: wrong number of arguments",
                    error.EvaluationError => "error: evaluation error",
                    error.Undefined => "error: mathematically undefined",
                };
                const ctx = evaluator.takeErrorContext();
                if (ctx.len > 0) {
                    try out.writer.print("{s} (in '{s}')\n", .{ msg, ctx });
                } else {
                    try out.writer.print("{s}\n", .{msg});
                }
                continue;
            };
            defer {
                result.deinit(allocator);
                allocator.destroy(result);
            }

            // Skip echoing results of print/begin statements (they printed)
            const is_print_stmt = expr.* == .list and expr.list.items.len > 0 and
                expr.list.items[0].* == .symbol and
                (std.mem.eql(u8, expr.list.items[0].symbol, "print") or
                    std.mem.eql(u8, expr.list.items[0].symbol, "begin"));
            if (!is_print_stmt) {
                builtins.writeExprPlain(result, &out.writer);
                try out.writer.writeAll("\n");
            }
        }
    }

    const text = try out.toOwnedSliceSentinel(0);
    result_buf = text;
    return text;
}
