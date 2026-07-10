//! LSP documentation adapter over the shared docs table (src/docs.zig).
//! Markdown for every entry is generated at compile time.

const std = @import("std");
const shared = @import("../docs.zig");

/// Markdown hover documentation for a builtin or special form.
pub fn getDocumentation(name: []const u8) ?[]const u8 {
    inline for (shared.docs) |doc| {
        const md = comptime blk: {
            var text: []const u8 = "## `" ++ doc.signature ++ "`\n\n" ++ doc.summary ++ ".";
            if (doc.example) |ex| {
                text = text ++ "\n\n**Example:**\n```lispium\n" ++ ex ++ "\n```";
            }
            break :blk text;
        };
        if (std.mem.eql(u8, doc.name, name)) return md;
    }
    return null;
}

/// One-line signature (used as the completion `detail`).
pub fn getSignature(name: []const u8) ?[]const u8 {
    if (shared.find(name)) |doc| return doc.signature;
    return null;
}
