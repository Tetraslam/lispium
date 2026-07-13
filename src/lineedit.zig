//! Raw-mode line editor for the REPL (POSIX terminals).
//!
//! Features: cursor movement (left/right/home/end), backspace/delete,
//! kill-line (Ctrl+K/U), delete-word (Ctrl+W), history navigation
//! (up/down), Ctrl+C cancels the line, Ctrl+D on an empty line is EOF.
//! Falls back to plain line reading on Windows and non-TTY stdin.

const std = @import("std");
const builtin = @import("builtin");

pub const supported = builtin.os.tag != .windows and builtin.os.tag != .freestanding;

pub const Result = union(enum) {
    /// A completed input line (owned by the caller's allocator)
    line: []u8,
    /// Ctrl+D on an empty line
    eof,
    /// Ctrl+C: cancel current input
    cancelled,
};

/// Reads one line with editing. `history` is ordered oldest-first.
pub fn readLine(
    allocator: std.mem.Allocator,
    io: std.Io,
    out: *std.Io.Writer,
    prompt: []const u8,
    history: []const []const u8,
) !Result {
    if (comptime !supported) return error.Unsupported;

    const stdin_file: std.Io.File = .stdin();
    const fd = stdin_file.handle;

    // Enter raw mode (restore on exit)
    const original = try std.posix.tcgetattr(fd);
    var raw = original;
    raw.lflag.ICANON = false;
    raw.lflag.ECHO = false;
    raw.lflag.ISIG = false;
    raw.cc[@intFromEnum(std.posix.V.MIN)] = 1;
    raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;
    try std.posix.tcsetattr(fd, .FLUSH, raw);
    defer std.posix.tcsetattr(fd, .FLUSH, original) catch {};

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    var cursor: usize = 0;
    var hist_idx: usize = history.len; // one past the end = editing new line
    var saved_line: std.ArrayList(u8) = .empty;
    defer saved_line.deinit(allocator);

    try redraw(out, prompt, buf.items, cursor);

    var byte_buf: [1]u8 = undefined;
    while (true) {
        const n = stdin_file.readStreaming(io, &.{&byte_buf}) catch return .eof;
        if (n == 0) return .eof;
        const c = byte_buf[0];

        switch (c) {
            '\r', '\n' => {
                out.writeAll("\n") catch {};
                out.flush() catch {};
                return .{ .line = try buf.toOwnedSlice(allocator) };
            },
            3 => { // Ctrl+C
                out.writeAll("^C\n") catch {};
                out.flush() catch {};
                return .cancelled;
            },
            4 => { // Ctrl+D
                if (buf.items.len == 0) {
                    out.writeAll("\n") catch {};
                    out.flush() catch {};
                    return .eof;
                }
            },
            127, 8 => { // Backspace
                if (cursor > 0) {
                    _ = buf.orderedRemove(cursor - 1);
                    cursor -= 1;
                }
            },
            1 => cursor = 0, // Ctrl+A
            5 => cursor = buf.items.len, // Ctrl+E
            11 => buf.shrinkRetainingCapacity(cursor), // Ctrl+K
            21 => { // Ctrl+U: kill to start
                const remaining = buf.items.len - cursor;
                std.mem.copyForwards(u8, buf.items[0..remaining], buf.items[cursor..]);
                buf.shrinkRetainingCapacity(remaining);
                cursor = 0;
            },
            23 => { // Ctrl+W: delete previous word
                var start = cursor;
                while (start > 0 and buf.items[start - 1] == ' ') start -= 1;
                while (start > 0 and buf.items[start - 1] != ' ') start -= 1;
                const removed = cursor - start;
                std.mem.copyForwards(u8, buf.items[start..], buf.items[cursor..]);
                buf.shrinkRetainingCapacity(buf.items.len - removed);
                cursor = start;
            },
            12 => { // Ctrl+L: clear screen
                out.writeAll("\x1b[2J\x1b[H") catch {};
            },
            27 => { // Escape sequence
                var seq: [2]u8 = undefined;
                if ((stdin_file.readStreaming(io, &.{seq[0..1]}) catch 0) == 0) continue;
                if (seq[0] != '[' and seq[0] != 'O') continue;
                if ((stdin_file.readStreaming(io, &.{seq[1..2]}) catch 0) == 0) continue;
                switch (seq[1]) {
                    'A' => { // Up: older history
                        if (hist_idx > 0) {
                            if (hist_idx == history.len) {
                                saved_line.clearRetainingCapacity();
                                try saved_line.appendSlice(allocator, buf.items);
                            }
                            hist_idx -= 1;
                            buf.clearRetainingCapacity();
                            try buf.appendSlice(allocator, history[hist_idx]);
                            cursor = buf.items.len;
                        }
                    },
                    'B' => { // Down: newer history
                        if (hist_idx < history.len) {
                            hist_idx += 1;
                            buf.clearRetainingCapacity();
                            if (hist_idx == history.len) {
                                try buf.appendSlice(allocator, saved_line.items);
                            } else {
                                try buf.appendSlice(allocator, history[hist_idx]);
                            }
                            cursor = buf.items.len;
                        }
                    },
                    'C' => { // Right
                        if (cursor < buf.items.len) cursor += 1;
                    },
                    'D' => { // Left
                        if (cursor > 0) cursor -= 1;
                    },
                    'H' => cursor = 0, // Home
                    'F' => cursor = buf.items.len, // End
                    '3' => { // Delete: consume trailing '~'
                        var tilde: [1]u8 = undefined;
                        _ = stdin_file.readStreaming(io, &.{&tilde}) catch 0;
                        if (cursor < buf.items.len) {
                            _ = buf.orderedRemove(cursor);
                        }
                    },
                    else => {},
                }
            },
            else => {
                if (c >= 32 or c >= 128) { // printable (UTF-8 continuation bytes included)
                    try buf.insert(allocator, cursor, c);
                    cursor += 1;
                }
            },
        }
        try redraw(out, prompt, buf.items, cursor);
    }
}

fn redraw(out: *std.Io.Writer, prompt: []const u8, line: []const u8, cursor: usize) !void {
    // Clear the line, print prompt + buffer, put the cursor in place
    out.writeAll("\r\x1b[K") catch {};
    out.writeAll(prompt) catch {};
    out.writeAll(line) catch {};
    const tail = line.len - cursor;
    if (tail > 0) {
        out.print("\x1b[{d}D", .{tail}) catch {};
    }
    out.flush() catch {};
}
