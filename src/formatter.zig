//! Canonical Lispium source formatter (see STYLE.md).
//!
//! Works on a lossless concrete syntax tree (not the evaluator's Expr AST)
//! so numeric literals, comments, and blank lines survive formatting.
//!
//! Style summary:
//! - Expressions that fit within the line width stay on one line
//! - Broken special forms (define/lambda/let/letrec/if/sum/product/rule)
//!   keep their header on the first line and indent the body two spaces
//! - Broken function calls align arguments under the first argument
//! - let/letrec bindings and matrix rows break one per line
//! - One space between elements; no space inside parens
//! - Comments: standalone comments keep their own line; trailing comments
//!   stay attached with two spaces before the ';'
//! - At most one blank line between top-level forms; none at start/end

const std = @import("std");

pub const LINE_WIDTH = 80;
pub const INDENT = 2;

pub const Error = error{
    OutOfMemory,
    UnbalancedParens,
    UnsupportedString,
};

// ============================================================================
// Concrete syntax tree
// ============================================================================

const Node = struct {
    kind: Kind,
    /// Atom text or comment text (comment text excludes the ';' prefix)
    text: []const u8 = "",
    children: std.ArrayList(*Node) = .empty,
    /// Trailing comment attached to this node (same line), without ';'
    trailing: ?[]const u8 = null,

    const Kind = enum {
        atom,
        list,
        /// Standalone comment occupying its own line
        comment,
        /// Blank line separator (top level only)
        blank,
    };

    fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        for (self.children.items) |child| {
            child.deinit(allocator);
            allocator.destroy(child);
        }
        self.children.deinit(allocator);
    }
};

// ============================================================================
// Lexer (comment- and blank-line-preserving)
// ============================================================================

const Token = union(enum) {
    lparen,
    rparen,
    atom: []const u8,
    /// Comment text without the leading ';' run; own_line is true when the
    /// comment starts its line
    comment: struct { text: []const u8, own_line: bool },
    /// One or more blank lines in the source
    blank,
};

fn lex(allocator: std.mem.Allocator, source: []const u8) Error!std.ArrayList(Token) {
    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);

    var i: usize = 0;
    var at_line_start = true;
    var pending_newlines: usize = 0;

    while (i < source.len) {
        const c = source[i];
        if (c == '\n') {
            pending_newlines += 1;
            at_line_start = true;
            i += 1;
            continue;
        }
        if (c == ' ' or c == '\t' or c == '\r') {
            i += 1;
            continue;
        }

        // Two or more newlines between tokens = a blank-line separator
        if (pending_newlines >= 2 and tokens.items.len > 0) {
            try tokens.append(allocator, .blank);
        }
        const after_newline = pending_newlines > 0;
        pending_newlines = 0;

        if (c == ';') {
            var j = i;
            while (j < source.len and source[j] == ';') j += 1;
            const start = j;
            while (j < source.len and source[j] != '\n') j += 1;
            const text = std.mem.trim(u8, source[start..j], " \t\r");
            try tokens.append(allocator, .{ .comment = .{
                .text = text,
                .own_line = at_line_start or after_newline or tokens.items.len == 0,
            } });
            i = j;
            continue;
        }
        at_line_start = false;
        if (c == '(') {
            try tokens.append(allocator, .lparen);
            i += 1;
            continue;
        }
        if (c == ')') {
            try tokens.append(allocator, .rparen);
            i += 1;
            continue;
        }
        if (c == '"') return Error.UnsupportedString;

        const start = i;
        while (i < source.len and source[i] != ' ' and source[i] != '\t' and
            source[i] != '\r' and source[i] != '\n' and source[i] != '(' and
            source[i] != ')' and source[i] != ';') i += 1;
        try tokens.append(allocator, .{ .atom = source[start..i] });
    }

    return tokens;
}

// ============================================================================
// Parser (tokens -> CST)
// ============================================================================

const ParseState = struct {
    allocator: std.mem.Allocator,
    tokens: []const Token,
    pos: usize = 0,

    fn makeNode(self: *ParseState, kind: Node.Kind) Error!*Node {
        const node = self.allocator.create(Node) catch return Error.OutOfMemory;
        node.* = .{ .kind = kind };
        return node;
    }

    /// Parses a sequence of nodes until rparen (inside = true) or EOF.
    fn parseSeq(self: *ParseState, list: *std.ArrayList(*Node), inside: bool) Error!void {
        while (self.pos < self.tokens.len) {
            const tok = self.tokens[self.pos];
            switch (tok) {
                .rparen => {
                    if (!inside) return Error.UnbalancedParens;
                    self.pos += 1;
                    return;
                },
                .lparen => {
                    self.pos += 1;
                    const node = try self.makeNode(.list);
                    errdefer {
                        node.deinit(self.allocator);
                        self.allocator.destroy(node);
                    }
                    try self.parseSeq(&node.children, true);
                    self.attachTrailing(node);
                    try list.append(self.allocator, node);
                },
                .atom => |text| {
                    self.pos += 1;
                    const node = try self.makeNode(.atom);
                    node.text = text;
                    self.attachTrailing(node);
                    try list.append(self.allocator, node);
                },
                .comment => |c| {
                    self.pos += 1;
                    const node = try self.makeNode(.comment);
                    node.text = c.text;
                    try list.append(self.allocator, node);
                },
                .blank => {
                    self.pos += 1;
                    // Preserve blank separators at top level only
                    if (!inside) {
                        const node = try self.makeNode(.blank);
                        try list.append(self.allocator, node);
                    }
                },
            }
        }
        if (inside) return Error.UnbalancedParens;
    }

    /// If the next token is a same-line trailing comment, attach it.
    fn attachTrailing(self: *ParseState, node: *Node) void {
        if (self.pos < self.tokens.len) {
            switch (self.tokens[self.pos]) {
                .comment => |c| {
                    if (!c.own_line) {
                        node.trailing = c.text;
                        self.pos += 1;
                    }
                },
                else => {},
            }
        }
    }
};

// ============================================================================
// Renderer
// ============================================================================

/// Number of header arguments that stay on the first line when a special
/// form breaks; everything after is the body, indented by INDENT.
fn specialFormHeaderArgs(name: []const u8) ?usize {
    const forms = .{
        .{ "define", 1 },
        .{ "lambda", 1 },
        .{ "let", 1 },
        .{ "letrec", 1 },
        .{ "if", 1 },
        .{ "sum", 3 },
        .{ "product", 3 },
        .{ "rule", 1 },
        .{ "matrix", 0 },
    };
    inline for (forms) |f| {
        if (std.mem.eql(u8, name, f[0])) return f[1];
    }
    return null;
}

/// True for forms whose header argument is a list-of-lists that should
/// break one element per line (let/letrec bindings).
fn isBindingForm(name: []const u8) bool {
    return std.mem.eql(u8, name, "let") or std.mem.eql(u8, name, "letrec");
}

/// Width of a node when rendered on a single line, or null if it cannot be
/// flattened (contains standalone comments).
fn flatWidth(node: *const Node) ?usize {
    switch (node.kind) {
        .atom => return node.text.len + trailingWidth(node),
        .comment, .blank => return null,
        .list => {
            var width: usize = 2; // parens
            for (node.children.items, 0..) |child, i| {
                if (child.kind == .comment) return null;
                if (child.trailing != null and i + 1 != node.children.items.len) return null;
                const w = flatWidth(child) orelse return null;
                width += w;
                if (i > 0) width += 1; // separating space
            }
            return width + trailingWidth(node);
        },
    }
}

fn trailingWidth(node: *const Node) usize {
    if (node.trailing) |t| return t.len + 4; // "  ; " + text
    return 0;
}

const Renderer = struct {
    out: *std.Io.Writer,
    col: usize = 0,

    fn write(self: *Renderer, text: []const u8) Error!void {
        self.out.writeAll(text) catch return Error.OutOfMemory;
        self.col += text.len;
    }

    fn newline(self: *Renderer, indent: usize) Error!void {
        self.out.writeAll("\n") catch return Error.OutOfMemory;
        self.out.splatByteAll(' ', indent) catch return Error.OutOfMemory;
        self.col = indent;
    }

    fn writeTrailing(self: *Renderer, node: *const Node) Error!void {
        if (node.trailing) |t| {
            try self.write("  ; ");
            try self.write(t);
        }
    }

    fn renderFlat(self: *Renderer, node: *const Node) Error!void {
        switch (node.kind) {
            .atom => try self.write(node.text),
            .list => {
                try self.write("(");
                for (node.children.items, 0..) |child, i| {
                    if (i > 0) try self.write(" ");
                    try self.renderFlat(child);
                }
                try self.write(")");
            },
            .comment, .blank => unreachable,
        }
        try self.writeTrailing(node);
    }

    /// Renders a node starting at the current column; `indent` is the
    /// current logical indentation for continuation lines.
    fn render(self: *Renderer, node: *const Node, indent: usize) Error!void {
        switch (node.kind) {
            .atom => {
                try self.write(node.text);
                try self.writeTrailing(node);
            },
            .comment => {
                try self.write("; ");
                try self.write(node.text);
            },
            .blank => {},
            .list => {
                if (flatWidth(node)) |w| {
                    if (self.col + w <= LINE_WIDTH) {
                        try self.renderFlat(node);
                        return;
                    }
                }
                try self.renderBroken(node, indent);
            },
        }
    }

    fn renderBroken(self: *Renderer, node: *const Node, indent: usize) Error!void {
        const items = node.children.items;
        if (items.len == 0) {
            try self.write("()");
            try self.writeTrailing(node);
            return;
        }

        try self.write("(");
        const head = items[0];
        const head_is_atom = head.kind == .atom;

        // Special form: header args inline, body indented two spaces
        if (head_is_atom) {
            if (specialFormHeaderArgs(head.text)) |header_args| {
                try self.render(head, indent + 1);
                var i: usize = 1;
                const header_end = @min(1 + header_args, items.len);
                while (i < header_end) : (i += 1) {
                    try self.write(" ");
                    if (isBindingForm(head.text) and items[i].kind == .list) {
                        try self.renderBindings(items[i], self.col);
                    } else {
                        try self.render(items[i], self.col);
                    }
                }
                const body_indent = indent + INDENT;
                while (i < items.len) : (i += 1) {
                    try self.newline(body_indent);
                    try self.render(items[i], body_indent);
                }
                try self.write(")");
                try self.writeTrailing(node);
                return;
            }
        }

        // Regular call. Short heads keep the first argument inline and align
        // the rest beneath it; long or compound heads break every argument
        // onto its own line at a two-space indent.
        try self.render(head, indent + 1);
        const short_head = head_is_atom and head.text.len <= 12;
        const arg_indent = if (short_head)
            indent + 2 + head.text.len
        else
            indent + INDENT;

        // Fill style when every argument is a plain atom: pack as many per
        // line as fit instead of one per line
        var all_atoms = true;
        for (items[1..]) |child| {
            if (child.kind != .atom or child.trailing != null) {
                all_atoms = false;
                break;
            }
        }

        if (all_atoms) {
            var first_arg = true;
            for (items[1..]) |child| {
                if (first_arg) {
                    if (short_head) {
                        try self.write(" ");
                    } else {
                        try self.newline(arg_indent);
                    }
                    first_arg = false;
                } else if (self.col + 1 + child.text.len + 1 <= LINE_WIDTH) {
                    try self.write(" ");
                } else {
                    try self.newline(arg_indent);
                }
                try self.render(child, arg_indent);
            }
            try self.write(")");
            try self.writeTrailing(node);
            return;
        }

        var first_arg = true;
        for (items[1..]) |child| {
            if (first_arg and short_head and child.kind != .comment) {
                try self.write(" ");
                try self.render(child, arg_indent);
                first_arg = false;
            } else {
                try self.newline(arg_indent);
                try self.render(child, arg_indent);
                first_arg = false;
            }
        }
        try self.write(")");
        try self.writeTrailing(node);
    }

    /// let/letrec binding block: ((a 1) (b 2)) with one binding per line
    /// when the block doesn't fit flat.
    fn renderBindings(self: *Renderer, node: *const Node, indent: usize) Error!void {
        if (flatWidth(node)) |w| {
            if (self.col + w <= LINE_WIDTH) {
                try self.renderFlat(node);
                return;
            }
        }
        try self.write("(");
        for (node.children.items, 0..) |child, i| {
            if (i > 0) try self.newline(indent + 1);
            try self.render(child, indent + 1);
        }
        try self.write(")");
        try self.writeTrailing(node);
    }
};

// ============================================================================
// Public API
// ============================================================================

/// Formats Lispium source, returning newly allocated canonical text.
/// The result always ends with exactly one newline (unless empty).
pub fn format(allocator: std.mem.Allocator, source: []const u8) Error![]u8 {
    var tokens = try lex(allocator, source);
    defer tokens.deinit(allocator);

    var state = ParseState{ .allocator = allocator, .tokens = tokens.items };
    var top: std.ArrayList(*Node) = .empty;
    defer {
        for (top.items) |node| {
            node.deinit(allocator);
            allocator.destroy(node);
        }
        top.deinit(allocator);
    }
    try state.parseSeq(&top, false);

    var buf: std.Io.Writer.Allocating = .init(allocator);
    errdefer buf.deinit();
    var renderer = Renderer{ .out = &buf.writer };

    // Drop leading/trailing blank separators
    var start: usize = 0;
    var end: usize = top.items.len;
    while (start < end and top.items[start].kind == .blank) start += 1;
    while (end > start and top.items[end - 1].kind == .blank) end -= 1;

    for (top.items[start..end]) |node| {
        if (node.kind == .blank) {
            // Collapse any run of blank lines to a single one
            buf.writer.writeAll("\n") catch return Error.OutOfMemory;
            continue;
        }
        renderer.col = 0;
        try renderer.render(node, 0);
        buf.writer.writeAll("\n") catch return Error.OutOfMemory;
    }

    return buf.toOwnedSlice() catch return Error.OutOfMemory;
}
