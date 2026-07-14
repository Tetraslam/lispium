//! Data interchange builtins: JSON and CSV parse/emit.
//!
//! Mapping (documented in CLAUDE.md):
//!   JSON object  <->  dict
//!   JSON array   <->  (list ...)
//!   JSON string  <->  string
//!   JSON number  <->  number
//!   true/false   <->  1 / 0
//!   null         <->  the symbol null
const std = @import("std");
const Expr = @import("parser.zig").Expr;
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");
const symbolic = @import("symbolic.zig");
const BuiltinError = builtins.BuiltinError;

// ----------------------------------------------------------------------------
// JSON parse
// ----------------------------------------------------------------------------

pub fn builtin_json_parse(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (json-parse s) - JSON text to Lispium values
    if (args.items.len != 1 or args.items[0].* != .string) return BuiltinError.InvalidArgument;

    const parsed = std.json.parseFromSlice(std.json.Value, env.allocator, args.items[0].string, .{}) catch {
        builtins.setErrorMessage("json-parse: invalid JSON");
        return BuiltinError.EvaluationError;
    };
    defer parsed.deinit();
    return jsonToExpr(parsed.value, env.allocator);
}

fn jsonToExpr(value: std.json.Value, allocator: std.mem.Allocator) BuiltinError!*Expr {
    switch (value) {
        .null => {
            const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .symbol = "null" };
            return result;
        },
        .bool => |b| {
            const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = if (b) 1 else 0 };
            return result;
        },
        .integer => |i| {
            const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = @floatFromInt(i) };
            return result;
        },
        .float => |f| {
            const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = f };
            return result;
        },
        .number_string => |s| {
            const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .number = std.fmt.parseFloat(f64, s) catch 0 };
            return result;
        },
        .string => |s| {
            const owned = allocator.dupe(u8, s) catch return BuiltinError.OutOfMemory;
            const result = allocator.create(Expr) catch {
                allocator.free(owned);
                return BuiltinError.OutOfMemory;
            };
            result.* = .{ .string = owned };
            return result;
        },
        .array => |arr| {
            var list: std.ArrayList(*Expr) = .empty;
            errdefer {
                for (list.items) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                list.deinit(allocator);
            }
            const head = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            head.* = .{ .symbol = "list" };
            list.append(allocator, head) catch return BuiltinError.OutOfMemory;
            for (arr.items) |item| {
                const child = try jsonToExpr(item, allocator);
                list.append(allocator, child) catch {
                    child.deinit(allocator);
                    allocator.destroy(child);
                    return BuiltinError.OutOfMemory;
                };
            }
            const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .list = list };
            return result;
        },
        .object => |obj| {
            var d: Expr.Dict = .empty;
            errdefer d.deinitAll(allocator);
            var it = obj.iterator();
            while (it.next()) |entry| {
                const key = allocator.dupe(u8, entry.key_ptr.*) catch return BuiltinError.OutOfMemory;
                errdefer allocator.free(key);
                const child = try jsonToExpr(entry.value_ptr.*, allocator);
                const gop = d.map.getOrPut(allocator, key) catch {
                    child.deinit(allocator);
                    allocator.destroy(child);
                    return BuiltinError.OutOfMemory;
                };
                if (gop.found_existing) {
                    allocator.free(key);
                    gop.value_ptr.*.deinit(allocator);
                    allocator.destroy(gop.value_ptr.*);
                }
                gop.value_ptr.* = child;
            }
            const result = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
            result.* = .{ .dict = d };
            return result;
        },
    }
}

// ----------------------------------------------------------------------------
// JSON emit
// ----------------------------------------------------------------------------

pub fn builtin_json_emit(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (json-emit value) - Lispium values to JSON text
    if (args.items.len != 1) return BuiltinError.InvalidArgument;

    var buf: std.Io.Writer.Allocating = .init(env.allocator);
    defer buf.deinit();
    exprToJson(args.items[0], &buf.writer) catch {
        builtins.setErrorMessage("json-emit: value has no JSON representation");
        return BuiltinError.EvaluationError;
    };
    const owned = env.allocator.dupe(u8, buf.written()) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch {
        env.allocator.free(owned);
        return BuiltinError.OutOfMemory;
    };
    result.* = .{ .string = owned };
    return result;
}

const JsonEmitError = error{ Unrepresentable, WriteFailed };

fn exprToJson(expr: *const Expr, writer: *std.Io.Writer) JsonEmitError!void {
    switch (expr.*) {
        .number => |n| {
            if (!std.math.isFinite(n)) return error.Unrepresentable;
            if (n == @floor(n) and @abs(n) < 1e15) {
                writer.print("{d}", .{@as(i64, @intFromFloat(n))}) catch return error.WriteFailed;
            } else {
                writer.print("{d}", .{n}) catch return error.WriteFailed;
            }
        },
        .big => |b| {
            builtins.writeBig(b, writer) catch return error.WriteFailed;
        },
        .string => |s| writeJsonString(s, writer) catch return error.WriteFailed,
        .symbol, .owned_symbol => |s| {
            // null round-trips; other symbols become strings
            if (std.mem.eql(u8, s, "null")) {
                writer.writeAll("null") catch return error.WriteFailed;
            } else {
                writeJsonString(s, writer) catch return error.WriteFailed;
            }
        },
        .dict => |d| {
            writer.writeAll("{") catch return error.WriteFailed;
            var it = d.map.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) writer.writeAll(",") catch return error.WriteFailed;
                first = false;
                writeJsonString(entry.key_ptr.*, writer) catch return error.WriteFailed;
                writer.writeAll(":") catch return error.WriteFailed;
                try exprToJson(entry.value_ptr.*, writer);
            }
            writer.writeAll("}") catch return error.WriteFailed;
        },
        .list => |lst| {
            // Rationals become decimal numbers; other lists become arrays
            if (builtins.asRational(expr)) |r| {
                if (r.q != 1) {
                    const v = @as(f64, @floatFromInt(r.p)) / @as(f64, @floatFromInt(r.q));
                    writer.print("{d}", .{v}) catch return error.WriteFailed;
                    return;
                }
            }
            // Skip a leading list/vector tag
            var start: usize = 0;
            if (lst.items.len > 0 and lst.items[0].* == .symbol and
                (std.mem.eql(u8, lst.items[0].symbol, "list") or
                    std.mem.eql(u8, lst.items[0].symbol, "vector")))
            {
                start = 1;
            }
            writer.writeAll("[") catch return error.WriteFailed;
            for (lst.items[start..], 0..) |item, i| {
                if (i > 0) writer.writeAll(",") catch return error.WriteFailed;
                try exprToJson(item, writer);
            }
            writer.writeAll("]") catch return error.WriteFailed;
        },
        .lambda => return error.Unrepresentable,
    }
}

fn writeJsonString(s: []const u8, writer: *std.Io.Writer) !void {
    try writer.writeAll("\"");
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\t' => try writer.writeAll("\\t"),
            '\r' => try writer.writeAll("\\r"),
            else => {
                if (c < 0x20) {
                    try writer.print("\\u{x:0>4}", .{c});
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
    try writer.writeAll("\"");
}

// ----------------------------------------------------------------------------
// CSV
// ----------------------------------------------------------------------------

pub fn builtin_csv_parse(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (csv-parse s) - rows as a list of lists; numeric cells become
    // numbers, everything else stays a string. Handles quoted cells with
    // embedded commas and doubled quotes.
    if (args.items.len != 1 or args.items[0].* != .string) return BuiltinError.InvalidArgument;
    const text = args.items[0].string;

    var rows: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (rows.items) |item| {
            item.deinit(env.allocator);
            env.allocator.destroy(item);
        }
        rows.deinit(env.allocator);
    }
    const rows_head = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    rows_head.* = .{ .symbol = "list" };
    rows.append(env.allocator, rows_head) catch return BuiltinError.OutOfMemory;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        if (line.len == 0) continue;
        const row = try parseCsvLine(line, env.allocator);
        rows.append(env.allocator, row) catch {
            row.deinit(env.allocator);
            env.allocator.destroy(row);
            return BuiltinError.OutOfMemory;
        };
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = rows };
    return result;
}

fn parseCsvLine(line: []const u8, allocator: std.mem.Allocator) BuiltinError!*Expr {
    var cells: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (cells.items) |item| {
            item.deinit(allocator);
            allocator.destroy(item);
        }
        cells.deinit(allocator);
    }
    const head = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    head.* = .{ .symbol = "list" };
    cells.append(allocator, head) catch return BuiltinError.OutOfMemory;

    var cell: std.ArrayList(u8) = .empty;
    defer cell.deinit(allocator);
    var i: usize = 0;
    var in_quotes = false;
    while (i < line.len) : (i += 1) {
        const c = line[i];
        if (in_quotes) {
            if (c == '"') {
                if (i + 1 < line.len and line[i + 1] == '"') {
                    cell.append(allocator, '"') catch return BuiltinError.OutOfMemory;
                    i += 1; // doubled quote
                } else {
                    in_quotes = false;
                }
            } else {
                cell.append(allocator, c) catch return BuiltinError.OutOfMemory;
            }
        } else if (c == '"' and cell.items.len == 0) {
            in_quotes = true;
        } else if (c == ',') {
            try appendCsvCell(&cells, cell.items, allocator);
            cell.clearRetainingCapacity();
        } else {
            cell.append(allocator, c) catch return BuiltinError.OutOfMemory;
        }
    }
    try appendCsvCell(&cells, cell.items, allocator);

    const row = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    row.* = .{ .list = cells };
    return row;
}

fn appendCsvCell(cells: *std.ArrayList(*Expr), text: []const u8, allocator: std.mem.Allocator) BuiltinError!void {
    const trimmed = std.mem.trim(u8, text, " \t");
    const cell_expr = allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    if (trimmed.len > 0) {
        if (std.fmt.parseFloat(f64, trimmed)) |n| {
            cell_expr.* = .{ .number = n };
            cells.append(allocator, cell_expr) catch {
                allocator.destroy(cell_expr);
                return BuiltinError.OutOfMemory;
            };
            return;
        } else |_| {}
    }
    const owned = allocator.dupe(u8, trimmed) catch {
        allocator.destroy(cell_expr);
        return BuiltinError.OutOfMemory;
    };
    cell_expr.* = .{ .string = owned };
    cells.append(allocator, cell_expr) catch {
        cell_expr.deinit(allocator);
        allocator.destroy(cell_expr);
        return BuiltinError.OutOfMemory;
    };
}

pub fn builtin_csv_emit(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (csv-emit rows) - a list of row-lists to CSV text; cells with
    // commas/quotes/newlines are quoted
    if (args.items.len != 1 or args.items[0].* != .list) return BuiltinError.InvalidArgument;

    var buf: std.Io.Writer.Allocating = .init(env.allocator);
    defer buf.deinit();

    const rows = args.items[0].list.items;
    var start: usize = 0;
    if (rows.len > 0 and rows[0].* == .symbol and std.mem.eql(u8, rows[0].symbol, "list")) start = 1;

    for (rows[start..]) |row| {
        if (row.* != .list) return BuiltinError.InvalidArgument;
        const cells = row.list.items;
        var cstart: usize = 0;
        if (cells.len > 0 and cells[0].* == .symbol and std.mem.eql(u8, cells[0].symbol, "list")) cstart = 1;
        for (cells[cstart..], 0..) |cell, i| {
            if (i > 0) buf.writer.writeAll(",") catch return BuiltinError.OutOfMemory;
            writeCsvCell(cell, &buf.writer) catch return BuiltinError.OutOfMemory;
        }
        buf.writer.writeAll("\n") catch return BuiltinError.OutOfMemory;
    }

    const owned = env.allocator.dupe(u8, buf.written()) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch {
        env.allocator.free(owned);
        return BuiltinError.OutOfMemory;
    };
    result.* = .{ .string = owned };
    return result;
}

fn writeCsvCell(cell: *const Expr, writer: *std.Io.Writer) !void {
    switch (cell.*) {
        .string => |s| {
            const needs_quotes = std.mem.indexOfAny(u8, s, ",\"\n") != null;
            if (needs_quotes) {
                try writer.writeAll("\"");
                for (s) |c| {
                    if (c == '"') try writer.writeAll("\"\"") else try writer.writeByte(c);
                }
                try writer.writeAll("\"");
            } else {
                try writer.writeAll(s);
            }
        },
        else => builtins.writeExprPlain(cell, writer),
    }
}

// ----------------------------------------------------------------------------
// Time and dates (UTC only; time as a VALUE, never as a runtime)
// ----------------------------------------------------------------------------

pub fn builtin_now(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (now) - Unix time in seconds (UTC), with sub-second precision
    if (args.items.len != 0) return BuiltinError.InvalidArgument;
    const io = env.io orelse {
        builtins.setErrorMessage("now: no clock available in this environment");
        return BuiltinError.EvaluationError;
    };
    const ns = std.Io.Timestamp.now(io, .real).nanoseconds;
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .number = @as(f64, @floatFromInt(ns)) / 1e9 };
    return result;
}

pub fn builtin_date_parts(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (date-parts ts) - a dict of {year month day hour minute second weekday}
    // for a Unix timestamp, in UTC. Weekday: 0 = Sunday.
    if (args.items.len != 1 or args.items[0].* != .number) return BuiltinError.InvalidArgument;
    const ts = args.items[0].number;
    if (ts < 0 or ts > 4e17) return BuiltinError.InvalidArgument;

    const secs: u64 = @intFromFloat(ts);
    const es = std.time.epoch.EpochSeconds{ .secs = secs };
    const day = es.getEpochDay();
    const year_day = day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_secs = es.getDaySeconds();

    var d: Expr.Dict = .empty;
    errdefer d.deinitAll(env.allocator);
    const fields = [_]struct { name: []const u8, value: f64 }{
        .{ .name = "year", .value = @floatFromInt(year_day.year) },
        .{ .name = "month", .value = @floatFromInt(month_day.month.numeric()) },
        .{ .name = "day", .value = @floatFromInt(@as(u32, month_day.day_index) + 1) },
        .{ .name = "hour", .value = @floatFromInt(day_secs.getHoursIntoDay()) },
        .{ .name = "minute", .value = @floatFromInt(day_secs.getMinutesIntoHour()) },
        .{ .name = "second", .value = @floatFromInt(day_secs.getSecondsIntoMinute()) },
        // Jan 1 1970 was a Thursday (4)
        .{ .name = "weekday", .value = @floatFromInt((day.day + 4) % 7) },
    };
    for (fields) |f| {
        const key = env.allocator.dupe(u8, f.name) catch return BuiltinError.OutOfMemory;
        errdefer env.allocator.free(key);
        const val = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        val.* = .{ .number = f.value };
        d.map.put(env.allocator, key, val) catch {
            val.deinit(env.allocator);
            env.allocator.destroy(val);
            return BuiltinError.OutOfMemory;
        };
    }
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .dict = d };
    return result;
}

pub fn builtin_date_format(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // (date-format ts) - "YYYY-MM-DD HH:MM:SS" in UTC
    if (args.items.len != 1 or args.items[0].* != .number) return BuiltinError.InvalidArgument;
    const ts = args.items[0].number;
    if (ts < 0 or ts > 4e17) return BuiltinError.InvalidArgument;

    const secs: u64 = @intFromFloat(ts);
    const es = std.time.epoch.EpochSeconds{ .secs = secs };
    const year_day = es.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_secs = es.getDaySeconds();

    var buf: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        year_day.year,
        month_day.month.numeric(),
        @as(u32, month_day.day_index) + 1,
        day_secs.getHoursIntoDay(),
        day_secs.getMinutesIntoHour(),
        day_secs.getSecondsIntoMinute(),
    }) catch return BuiltinError.OutOfMemory;

    const owned = env.allocator.dupe(u8, text) catch return BuiltinError.OutOfMemory;
    const result = env.allocator.create(Expr) catch {
        env.allocator.free(owned);
        return BuiltinError.OutOfMemory;
    };
    result.* = .{ .string = owned };
    return result;
}
