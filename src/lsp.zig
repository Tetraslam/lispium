const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;

/// LSP Server for Lispium
/// Implements Language Server Protocol over stdin/stdout using JSON-RPC 2.0

const builtin_docs = @import("lsp/builtin_docs.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    var server = Server.init(allocator);
    defer server.deinit();
    try server.run();
}

const Server = struct {
    allocator: std.mem.Allocator,
    documents: std.StringHashMap(Document),
    initialized: bool = false,
    shutdown_requested: bool = false,

    const Document = struct {
        uri: []const u8,
        content: []const u8,
        version: i64,
    };

    fn init(allocator: std.mem.Allocator) Server {
        return .{
            .allocator = allocator,
            .documents = std.StringHashMap(Document).init(allocator),
        };
    }

    fn deinit(self: *Server) void {
        var it = self.documents.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.content);
            self.allocator.free(entry.value_ptr.uri);
        }
        self.documents.deinit();
    }

    fn run(self: *Server) !void {
        const stdin_file = std.fs.File.stdin();
        const stdout_file = std.fs.File.stdout();
        const stdin = stdin_file.deprecatedReader();
        const stdout = stdout_file.deprecatedWriter();

        var line_buf = std.array_list.Managed(u8).init(self.allocator);
        defer line_buf.deinit();

        while (!self.shutdown_requested) {
            // Read headers
            var content_length: ?usize = null;
            while (true) {
                line_buf.clearRetainingCapacity();
                stdin.readUntilDelimiterArrayList(&line_buf, '\n', 1024 * 1024) catch |err| {
                    if (err == error.EndOfStream) return;
                    return err;
                };
                const trimmed = std.mem.trim(u8, line_buf.items, "\r\n");
                if (trimmed.len == 0) break;

                if (std.mem.startsWith(u8, trimmed, "Content-Length: ")) {
                    content_length = std.fmt.parseInt(usize, trimmed[16..], 10) catch null;
                }
            }

            const len = content_length orelse continue;

            // Read content
            const content = try self.allocator.alloc(u8, len);
            defer self.allocator.free(content);
            const bytes_read = stdin_file.readAll(content) catch |err| {
                if (err == error.EndOfStream) return;
                return err;
            };
            if (bytes_read != len) continue;

            // Parse JSON-RPC message
            const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, content, .{}) catch continue;
            defer parsed.deinit();

            // Handle the message
            const response = try self.handleMessage(parsed.value);
            if (response) |resp| {
                defer self.allocator.free(resp);
                try stdout.print("Content-Length: {d}\r\n\r\n{s}", .{ resp.len, resp });
            }
        }
    }

    fn handleMessage(self: *Server, msg: std.json.Value) !?[]const u8 {
        const obj = msg.object;

        const method = obj.get("method") orelse return null;
        const method_str = method.string;

        const id = obj.get("id");
        const params = obj.get("params");

        // Handle different methods
        if (std.mem.eql(u8, method_str, "initialize")) {
            return try self.handleInitialize(id);
        } else if (std.mem.eql(u8, method_str, "initialized")) {
            self.initialized = true;
            return null;
        } else if (std.mem.eql(u8, method_str, "shutdown")) {
            self.shutdown_requested = true;
            return try self.makeResponse(id, "null");
        } else if (std.mem.eql(u8, method_str, "exit")) {
            return null;
        } else if (std.mem.eql(u8, method_str, "textDocument/didOpen")) {
            try self.handleDidOpen(params);
            return null;
        } else if (std.mem.eql(u8, method_str, "textDocument/didChange")) {
            try self.handleDidChange(params);
            return null;
        } else if (std.mem.eql(u8, method_str, "textDocument/didClose")) {
            try self.handleDidClose(params);
            return null;
        } else if (std.mem.eql(u8, method_str, "textDocument/hover")) {
            return try self.handleHover(id, params);
        } else if (std.mem.eql(u8, method_str, "textDocument/completion")) {
            return try self.handleCompletion(id, params);
        }

        return null;
    }

    fn handleInitialize(self: *Server, id: ?std.json.Value) ![]const u8 {
        const capabilities =
            \\{
            \\  "capabilities": {
            \\    "textDocumentSync": 1,
            \\    "hoverProvider": true,
            \\    "completionProvider": {
            \\      "triggerCharacters": ["(", " "]
            \\    }
            \\  },
            \\  "serverInfo": {
            \\    "name": "lispium-lsp",
            \\    "version": "0.1.0"
            \\  }
            \\}
        ;
        return try self.makeResponse(id, capabilities);
    }

    fn handleDidOpen(self: *Server, params: ?std.json.Value) !void {
        const p = params orelse return;
        const text_doc = p.object.get("textDocument") orelse return;
        const uri = text_doc.object.get("uri") orelse return;
        const text = text_doc.object.get("text") orelse return;
        const version = text_doc.object.get("version") orelse return;

        const uri_copy = try self.allocator.dupe(u8, uri.string);
        const text_copy = try self.allocator.dupe(u8, text.string);

        try self.documents.put(uri_copy, .{
            .uri = uri_copy,
            .content = text_copy,
            .version = version.integer,
        });

        // Publish diagnostics
        try self.publishDiagnostics(uri.string, text.string);
    }

    fn handleDidChange(self: *Server, params: ?std.json.Value) !void {
        const p = params orelse return;
        const text_doc = p.object.get("textDocument") orelse return;
        const uri = text_doc.object.get("uri") orelse return;
        const changes = p.object.get("contentChanges") orelse return;

        if (changes.array.items.len == 0) return;
        const new_text = changes.array.items[0].object.get("text") orelse return;

        if (self.documents.getPtr(uri.string)) |doc| {
            self.allocator.free(doc.content);
            doc.content = try self.allocator.dupe(u8, new_text.string);
        }

        try self.publishDiagnostics(uri.string, new_text.string);
    }

    fn handleDidClose(self: *Server, params: ?std.json.Value) !void {
        const p = params orelse return;
        const text_doc = p.object.get("textDocument") orelse return;
        const uri = text_doc.object.get("uri") orelse return;

        if (self.documents.fetchRemove(uri.string)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value.content);
            self.allocator.free(kv.value.uri);
        }
    }

    fn handleHover(self: *Server, id: ?std.json.Value, params: ?std.json.Value) ![]const u8 {
        const p = params orelse return try self.makeResponse(id, "null");
        const text_doc = p.object.get("textDocument") orelse return try self.makeResponse(id, "null");
        const uri = text_doc.object.get("uri") orelse return try self.makeResponse(id, "null");
        const position = p.object.get("position") orelse return try self.makeResponse(id, "null");

        const doc = self.documents.get(uri.string) orelse return try self.makeResponse(id, "null");
        const line_num: usize = @intCast(position.object.get("line").?.integer);
        const char_num: usize = @intCast(position.object.get("character").?.integer);

        // Find the word at position
        const word = self.getWordAtPosition(doc.content, line_num, char_num);
        if (word.len == 0) return try self.makeResponse(id, "null");

        // Look up documentation
        if (builtin_docs.getDocumentation(word)) |doc_text| {
            var buf: [4096]u8 = undefined;
            const escaped = escapeJson(doc_text, &buf);
            var result_buf: [8192]u8 = undefined;
            const result = std.fmt.bufPrint(&result_buf,
                \\{{"contents": {{"kind": "markdown", "value": "{s}"}}}}
            , .{escaped}) catch return try self.makeResponse(id, "null");
            return try self.makeResponse(id, result);
        }

        return try self.makeResponse(id, "null");
    }

    fn handleCompletion(self: *Server, id: ?std.json.Value, params: ?std.json.Value) ![]const u8 {
        _ = params;

        // Return all builtin completions
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(self.allocator);

        try buf.appendSlice(self.allocator, "[");
        var first = true;
        for (builtin_docs.all_builtins) |name| {
            if (!first) try buf.appendSlice(self.allocator, ",");
            first = false;

            const doc = builtin_docs.getDocumentation(name) orelse "";
            var doc_buf: [2048]u8 = undefined;
            const escaped_doc = escapeJson(doc, &doc_buf);

            var item_buf: [4096]u8 = undefined;
            const item = std.fmt.bufPrint(&item_buf,
                \\{{"label": "{s}", "kind": 3, "documentation": {{"kind": "markdown", "value": "{s}"}}}}
            , .{ name, escaped_doc }) catch continue;
            try buf.appendSlice(self.allocator, item);
        }
        try buf.appendSlice(self.allocator, "]");

        return try self.makeResponse(id, buf.items);
    }

    fn publishDiagnostics(self: *Server, uri: []const u8, content: []const u8) !void {
        var diagnostics: std.ArrayList(u8) = .empty;
        defer diagnostics.deinit(self.allocator);

        try diagnostics.appendSlice(self.allocator, "[");

        // Check for unbalanced parentheses
        var depth: i32 = 0;
        var line: usize = 0;
        var col: usize = 0;
        var error_line: usize = 0;
        var error_col: usize = 0;
        var has_error = false;

        for (content) |c| {
            if (c == '(') {
                depth += 1;
            } else if (c == ')') {
                depth -= 1;
                if (depth < 0 and !has_error) {
                    has_error = true;
                    error_line = line;
                    error_col = col;
                }
            } else if (c == '\n') {
                line += 1;
                col = 0;
                continue;
            }
            col += 1;
        }

        if (has_error) {
            var buf: [512]u8 = undefined;
            const diag = std.fmt.bufPrint(&buf,
                \\{{"range": {{"start": {{"line": {d}, "character": {d}}}, "end": {{"line": {d}, "character": {d}}}}}, "severity": 1, "message": "Unmatched closing parenthesis"}}
            , .{ error_line, error_col, error_line, error_col + 1 }) catch "";
            try diagnostics.appendSlice(self.allocator, diag);
        } else if (depth > 0) {
            var buf: [512]u8 = undefined;
            const diag = std.fmt.bufPrint(&buf,
                \\{{"range": {{"start": {{"line": {d}, "character": 0}}, "end": {{"line": {d}, "character": 0}}}}, "severity": 1, "message": "Missing {d} closing parenthesis(es)"}}
            , .{ line, line, depth }) catch "";
            try diagnostics.appendSlice(self.allocator, diag);
        }

        try diagnostics.appendSlice(self.allocator, "]");

        // Send notification
        var uri_buf: [2048]u8 = undefined;
        const escaped_uri = escapeJson(uri, &uri_buf);

        var notif_buf: [4096]u8 = undefined;
        const notification = std.fmt.bufPrint(&notif_buf,
            \\{{"jsonrpc": "2.0", "method": "textDocument/publishDiagnostics", "params": {{"uri": "{s}", "diagnostics": {s}}}}}
        , .{ escaped_uri, diagnostics.items }) catch return;

        // Write notification
        const stdout_file = std.fs.File.stdout();
        const stdout = stdout_file.deprecatedWriter();
        try stdout.print("Content-Length: {d}\r\n\r\n{s}", .{ notification.len, notification });
    }

    fn getWordAtPosition(self: *Server, content: []const u8, line_num: usize, char_num: usize) []const u8 {
        _ = self;

        // Find the line
        var lines = std.mem.splitScalar(u8, content, '\n');
        var current_line: usize = 0;
        while (lines.next()) |line| {
            if (current_line == line_num) {
                if (char_num >= line.len) return "";

                // Find word boundaries
                var start = char_num;
                while (start > 0 and isWordChar(line[start - 1])) {
                    start -= 1;
                }
                var end = char_num;
                while (end < line.len and isWordChar(line[end])) {
                    end += 1;
                }

                if (start == end) return "";
                return line[start..end];
            }
            current_line += 1;
        }
        return "";
    }

    fn makeResponse(self: *Server, id: ?std.json.Value, result: []const u8) ![]const u8 {
        var buf: std.ArrayList(u8) = .empty;

        if (id) |i| {
            switch (i) {
                .integer => |n| try std.fmt.format(buf.writer(self.allocator), "{{\"jsonrpc\": \"2.0\", \"id\": {d}, \"result\": {s}}}", .{ n, result }),
                .string => |s| try std.fmt.format(buf.writer(self.allocator), "{{\"jsonrpc\": \"2.0\", \"id\": \"{s}\", \"result\": {s}}}", .{ s, result }),
                else => try std.fmt.format(buf.writer(self.allocator), "{{\"jsonrpc\": \"2.0\", \"id\": null, \"result\": {s}}}", .{result}),
            }
        } else {
            try std.fmt.format(buf.writer(self.allocator), "{{\"jsonrpc\": \"2.0\", \"id\": null, \"result\": {s}}}", .{result});
        }

        return try buf.toOwnedSlice(self.allocator);
    }
};

fn isWordChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '-' or c == '?' or c == '!' or c == '+' or c == '*' or c == '/' or c == '^' or c == '<' or c == '>' or c == '=';
}

fn escapeJson(input: []const u8, buf: []u8) []const u8 {
    var i: usize = 0;
    for (input) |c| {
        if (i + 2 >= buf.len) break;
        switch (c) {
            '"' => {
                buf[i] = '\\';
                buf[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                buf[i] = '\\';
                buf[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                buf[i] = '\\';
                buf[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                buf[i] = '\\';
                buf[i + 1] = 'r';
                i += 2;
            },
            '\t' => {
                buf[i] = '\\';
                buf[i + 1] = 't';
                i += 2;
            },
            else => {
                buf[i] = c;
                i += 1;
            },
        }
    }
    return buf[0..i];
}
