//! Capability ports: http-get and exec. Both are host-gated (Env.allow_net
//! / Env.allow_exec): the CLI turns them on, WASM/tests/LSP leave them off
//! and the builtins fail with a readable (error-message). Per the design
//! rule, these fetch and produce VALUES — no servers, no long-lived
//! processes, no sockets exposed to the language.
const std = @import("std");
const builtin = @import("builtin");
const Expr = @import("parser.zig").Expr;
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");
const BuiltinError = builtins.BuiltinError;

/// Builds a dict expression from (name, value-expr) pairs, taking
/// ownership of the values.
fn makeDict(allocator: std.mem.Allocator, entries: []const struct { []const u8, *Expr }) BuiltinError!*Expr {
    var d: Expr.Dict = .empty;
    errdefer d.deinitAll(allocator);
    for (entries) |entry| {
        const key = allocator.dupe(u8, entry[0]) catch {
            entry[1].deinit(allocator);
            allocator.destroy(entry[1]);
            return BuiltinError.OutOfMemory;
        };
        d.map.put(allocator, key, entry[1]) catch {
            allocator.free(key);
            entry[1].deinit(allocator);
            allocator.destroy(entry[1]);
            return BuiltinError.OutOfMemory;
        };
    }
    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .dict = d };
    return result;
}

fn makeNumberExpr(allocator: std.mem.Allocator, n: f64) BuiltinError!*Expr {
    const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = n };
    return result;
}

fn makeStringExprDupe(allocator: std.mem.Allocator, text: []const u8) BuiltinError!*Expr {
    const owned = allocator.dupe(u8, text) catch return BuiltinError.OutOfMemory;
    const result = allocator.create(Expr) catch {
        allocator.free(owned);
        return BuiltinError.OutOfMemory;
    };
    result.* = .{ .string = owned };
    return result;
}

pub fn builtin_http_get(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (http-get url) - fetches a URL, returning {status body}
    if (comptime builtin.os.tag == .freestanding) {
        builtins.setErrorMessage("http-get: no network in the browser playground");
        return BuiltinError.EvaluationError;
    }
    if (args.items.len != 1 or args.items[0].* != .string) return BuiltinError.InvalidArgument;
    if (!env.allow_net) {
        builtins.setErrorMessage("http-get: network access is not enabled in this environment");
        return BuiltinError.EvaluationError;
    }
    const io = env.io orelse {
        builtins.setErrorMessage("http-get: no io available");
        return BuiltinError.EvaluationError;
    };

    var client: std.http.Client = .{ .allocator = env.allocator, .io = io };
    defer client.deinit();

    var body: std.Io.Writer.Allocating = .init(env.allocator);
    defer body.deinit();

    const fetch_result = client.fetch(.{
        .location = .{ .url = args.items[0].string },
        .response_writer = &body.writer,
    }) catch |err| {
        var msg_buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "http-get failed: {t}", .{err}) catch "http-get failed";
        builtins.setErrorMessage(msg);
        return BuiltinError.EvaluationError;
    };

    const status_expr = try makeNumberExpr(env.allocator, @floatFromInt(@intFromEnum(fetch_result.status)));
    const body_expr = makeStringExprDupe(env.allocator, body.written()) catch |err| {
        status_expr.deinit(env.allocator);
        env.allocator.destroy(status_expr);
        return err;
    };
    return makeDict(env.allocator, &.{
        .{ "status", status_expr },
        .{ "body", body_expr },
    });
}

pub fn builtin_exec(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (exec cmd) - runs a shell command, returning {status stdout stderr}.
    // The escape hatch to everything the language deliberately doesn't do.
    if (comptime builtin.os.tag == .freestanding) {
        builtins.setErrorMessage("exec: no processes in the browser playground");
        return BuiltinError.EvaluationError;
    }
    if (args.items.len != 1 or args.items[0].* != .string) return BuiltinError.InvalidArgument;
    if (!env.allow_exec) {
        builtins.setErrorMessage("exec: subprocess access is not enabled in this environment");
        return BuiltinError.EvaluationError;
    }
    const io = env.io orelse {
        builtins.setErrorMessage("exec: no io available");
        return BuiltinError.EvaluationError;
    };

    const argv: []const []const u8 = if (comptime builtin.os.tag == .windows)
        &.{ "cmd", "/C", args.items[0].string }
    else
        &.{ "/bin/sh", "-c", args.items[0].string };

    const run_result = std.process.run(env.allocator, io, .{
        .argv = argv,
        .stdout_limit = .limited(10 * 1024 * 1024),
        .stderr_limit = .limited(10 * 1024 * 1024),
    }) catch |err| {
        var msg_buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "exec failed: {t}", .{err}) catch "exec failed";
        builtins.setErrorMessage(msg);
        return BuiltinError.EvaluationError;
    };
    defer env.allocator.free(run_result.stdout);
    defer env.allocator.free(run_result.stderr);

    const status: f64 = switch (run_result.term) {
        .exited => |code| @floatFromInt(code),
        else => -1,
    };

    const status_expr = try makeNumberExpr(env.allocator, status);
    const stdout_expr = makeStringExprDupe(env.allocator, run_result.stdout) catch |err| {
        status_expr.deinit(env.allocator);
        env.allocator.destroy(status_expr);
        return err;
    };
    const stderr_expr = makeStringExprDupe(env.allocator, run_result.stderr) catch |err| {
        status_expr.deinit(env.allocator);
        env.allocator.destroy(status_expr);
        stdout_expr.deinit(env.allocator);
        env.allocator.destroy(stdout_expr);
        return err;
    };
    return makeDict(env.allocator, &.{
        .{ "status", status_expr },
        .{ "stdout", stdout_expr },
        .{ "stderr", stderr_expr },
    });
}
