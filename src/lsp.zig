const std = @import("std");
const build_options = @import("build_options");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;

/// LSP Server for Lispium
/// Implements Language Server Protocol over stdin/stdout using JSON-RPC 2.0

const builtin_docs = @import("lsp/builtin_docs.zig");
const formatter = @import("formatter.zig");
const server_version = build_options.version;

pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    var server = Server.init(allocator);
    defer server.deinit();
    try server.run(io);
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

    fn run(self: *Server, io: std.Io) !void {
        const stdin_buffer = try self.allocator.alloc(u8, 1024 * 1024);
        defer self.allocator.free(stdin_buffer);
        var stdin_reader: std.Io.File.Reader = .init(.stdin(), io, stdin_buffer);
        const stdin = &stdin_reader.interface;

        var stdout_writer: std.Io.File.Writer = .init(.stdout(), io, &.{});
        const stdout = &stdout_writer.interface;

        while (!self.shutdown_requested) {
            // Read headers
            var content_length: ?usize = null;
            while (true) {
                const raw_line = (stdin.takeDelimiter('\n') catch |err| return err) orelse return;
                const trimmed = std.mem.trim(u8, raw_line, "\r\n");
                if (trimmed.len == 0) break;

                if (std.mem.startsWith(u8, trimmed, "Content-Length: ")) {
                    content_length = std.fmt.parseInt(usize, trimmed[16..], 10) catch null;
                }
            }

            const len = content_length orelse continue;

            // Read content
            const content = try self.allocator.alloc(u8, len);
            defer self.allocator.free(content);
            stdin.readSliceAll(content) catch |err| {
                if (err == error.EndOfStream) return;
                return err;
            };

            // Parse JSON-RPC message
            const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, content, .{}) catch continue;
            defer parsed.deinit();

            // Handle the message
            const response = try self.handleMessage(parsed.value, stdout);
            if (response) |resp| {
                defer self.allocator.free(resp);
                self.writeMessage(stdout, resp);
            }
        }
    }

    fn writeMessage(_: *Server, stdout: *std.Io.Writer, content: []const u8) void {
        stdout.print("Content-Length: {d}\r\n\r\n{s}", .{ content.len, content }) catch return;
    }

    fn handleMessage(self: *Server, msg: std.json.Value, stdout: *std.Io.Writer) !?[]const u8 {
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
            try self.handleDidOpen(params, stdout);
            return null;
        } else if (std.mem.eql(u8, method_str, "textDocument/didChange")) {
            try self.handleDidChange(params, stdout);
            return null;
        } else if (std.mem.eql(u8, method_str, "textDocument/didClose")) {
            try self.handleDidClose(params);
            return null;
        } else if (std.mem.eql(u8, method_str, "textDocument/hover")) {
            return try self.handleHover(id, params);
        } else if (std.mem.eql(u8, method_str, "textDocument/completion")) {
            return try self.handleCompletion(id, params);
        } else if (std.mem.eql(u8, method_str, "textDocument/formatting")) {
            return try self.handleFormatting(id, params);
        } else if (std.mem.eql(u8, method_str, "textDocument/definition")) {
            return try self.handleDefinition(id, params);
        } else if (std.mem.eql(u8, method_str, "textDocument/documentSymbol")) {
            return try self.handleDocumentSymbol(id, params);
        } else if (std.mem.eql(u8, method_str, "textDocument/rename")) {
            return try self.handleRename(id, params);
        } else if (std.mem.eql(u8, method_str, "textDocument/signatureHelp")) {
            return try self.handleSignatureHelp(id, params);
        }

        return null;
    }

    fn handleInitialize(self: *Server, id: ?std.json.Value) ![]const u8 {
        var buf: [512]u8 = undefined;
        const capabilities = std.fmt.bufPrint(&buf,
            \\{{
            \\  "capabilities": {{
            \\    "textDocumentSync": 1,
            \\    "hoverProvider": true,
            \\    "documentFormattingProvider": true,
            \\    "definitionProvider": true,
            \\    "documentSymbolProvider": true,
            \\    "renameProvider": true,
            \\    "signatureHelpProvider": {{
            \\      "triggerCharacters": [" "]
            \\    }},
            \\    "completionProvider": {{
            \\      "triggerCharacters": ["("]
            \\    }}
            \\  }},
            \\  "serverInfo": {{
            \\    "name": "lispium-lsp",
            \\    "version": "{s}"
            \\  }}
            \\}}
        , .{server_version}) catch return error.OutOfMemory;
        return try self.makeResponse(id, capabilities);
    }

    fn handleDidOpen(self: *Server, params: ?std.json.Value, stdout: *std.Io.Writer) !void {
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
        try self.publishDiagnostics(uri.string, text.string, stdout);
    }

    fn handleDidChange(self: *Server, params: ?std.json.Value, stdout: *std.Io.Writer) !void {
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

        try self.publishDiagnostics(uri.string, new_text.string, stdout);
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

    const Definition = struct { line: usize, character: usize, name_len: usize };
    const NamedDef = struct { name: []const u8, def: Definition };

    /// Scans document text for (define name ...), (define (name ...) ...),
    /// and (defmacro (name ...) ...) top-level definitions.
    fn findDefinitions(content: []const u8, allocator: std.mem.Allocator) !std.ArrayList(NamedDef) {
        var defs: std.ArrayList(NamedDef) = .empty;
        errdefer defs.deinit(allocator);

        var line_num: usize = 0;
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| : (line_num += 1) {
            for ([_][]const u8{ "(define ", "(defmacro " }) |kw| {
                var search_from: usize = 0;
                while (std.mem.indexOfPos(u8, line, search_from, kw)) |kw_start| {
                    search_from = kw_start + kw.len;
                    var i = kw_start + kw.len;
                    while (i < line.len and line[i] == ' ') i += 1;
                    // Function form: (define (name ...) ...)
                    if (i < line.len and line[i] == '(') i += 1;
                    const name_start = i;
                    while (i < line.len and isWordChar(line[i])) i += 1;
                    if (i > name_start) {
                        try defs.append(allocator, .{
                            .name = line[name_start..i],
                            .def = .{ .line = line_num, .character = name_start, .name_len = i - name_start },
                        });
                    }
                }
            }
        }
        return defs;
    }

    /// textDocument/definition: jump to the (define ...) of the word under
    /// the cursor.
    fn handleDefinition(self: *Server, id: ?std.json.Value, params: ?std.json.Value) ![]const u8 {
        const p = params orelse return try self.makeResponse(id, "null");
        const text_doc = p.object.get("textDocument") orelse return try self.makeResponse(id, "null");
        const uri = text_doc.object.get("uri") orelse return try self.makeResponse(id, "null");
        const position = p.object.get("position") orelse return try self.makeResponse(id, "null");
        const doc = self.documents.get(uri.string) orelse return try self.makeResponse(id, "null");

        const line_num: usize = @intCast(position.object.get("line").?.integer);
        const char_num: usize = @intCast(position.object.get("character").?.integer);
        const word = self.getWordAtPosition(doc.content, line_num, char_num);
        if (word.len == 0) return try self.makeResponse(id, "null");

        var defs = try findDefinitions(doc.content, self.allocator);
        defer defs.deinit(self.allocator);
        for (defs.items) |entry| {
            if (std.mem.eql(u8, entry.name, word)) {
                var buf: [512]u8 = undefined;
                const loc = std.fmt.bufPrint(&buf,
                    \\{{"uri": "{s}", "range": {{"start": {{"line": {d}, "character": {d}}}, "end": {{"line": {d}, "character": {d}}}}}}}
                , .{ uri.string, entry.def.line, entry.def.character, entry.def.line, entry.def.character + entry.def.name_len }) catch return try self.makeResponse(id, "null");
                return try self.makeResponse(id, loc);
            }
        }
        return try self.makeResponse(id, "null");
    }

    /// textDocument/documentSymbol: outline of top-level definitions.
    fn handleDocumentSymbol(self: *Server, id: ?std.json.Value, params: ?std.json.Value) ![]const u8 {
        const p = params orelse return try self.makeResponse(id, "null");
        const text_doc = p.object.get("textDocument") orelse return try self.makeResponse(id, "null");
        const uri = text_doc.object.get("uri") orelse return try self.makeResponse(id, "null");
        const doc = self.documents.get(uri.string) orelse return try self.makeResponse(id, "null");

        var defs = try findDefinitions(doc.content, self.allocator);
        defer defs.deinit(self.allocator);

        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "[");
        for (defs.items, 0..) |entry, i| {
            if (i > 0) try buf.appendSlice(self.allocator, ",");
            var item_buf: [512]u8 = undefined;
            // kind 12 = Function
            const item = std.fmt.bufPrint(&item_buf,
                \\{{"name": "{s}", "kind": 12, "location": {{"uri": "{s}", "range": {{"start": {{"line": {d}, "character": {d}}}, "end": {{"line": {d}, "character": {d}}}}}}}}}
            , .{ entry.name, uri.string, entry.def.line, entry.def.character, entry.def.line, entry.def.character + entry.def.name_len }) catch continue;
            try buf.appendSlice(self.allocator, item);
        }
        try buf.appendSlice(self.allocator, "]");
        return try self.makeResponse(id, buf.items);
    }

    /// textDocument/rename: renames every whole-word occurrence of the
    /// symbol under the cursor within this document.
    fn handleRename(self: *Server, id: ?std.json.Value, params: ?std.json.Value) ![]const u8 {
        const p = params orelse return try self.makeResponse(id, "null");
        const text_doc = p.object.get("textDocument") orelse return try self.makeResponse(id, "null");
        const uri = text_doc.object.get("uri") orelse return try self.makeResponse(id, "null");
        const position = p.object.get("position") orelse return try self.makeResponse(id, "null");
        const new_name_val = p.object.get("newName") orelse return try self.makeResponse(id, "null");
        const new_name = new_name_val.string;
        const doc = self.documents.get(uri.string) orelse return try self.makeResponse(id, "null");

        const line_num: usize = @intCast(position.object.get("line").?.integer);
        const char_num: usize = @intCast(position.object.get("character").?.integer);
        const word = self.getWordAtPosition(doc.content, line_num, char_num);
        if (word.len == 0) return try self.makeResponse(id, "null");

        var edits: std.ArrayList(u8) = .empty;
        defer edits.deinit(self.allocator);
        try edits.appendSlice(self.allocator, "[");
        var first = true;

        var ln: usize = 0;
        var lines_it = std.mem.splitScalar(u8, doc.content, '\n');
        while (lines_it.next()) |line| : (ln += 1) {
            var search: usize = 0;
            while (std.mem.indexOfPos(u8, line, search, word)) |at| {
                search = at + word.len;
                // Whole-word match only
                const before_ok = at == 0 or !isWordChar(line[at - 1]);
                const after_ok = at + word.len >= line.len or !isWordChar(line[at + word.len]);
                if (!before_ok or !after_ok) continue;
                if (!first) try edits.appendSlice(self.allocator, ",");
                first = false;
                var buf: [512]u8 = undefined;
                var esc_buf: [256]u8 = undefined;
                const escaped_new = escapeJson(new_name, &esc_buf);
                const item = std.fmt.bufPrint(&buf,
                    \\{{"range": {{"start": {{"line": {d}, "character": {d}}}, "end": {{"line": {d}, "character": {d}}}}}, "newText": "{s}"}}
                , .{ ln, at, ln, at + word.len, escaped_new }) catch continue;
                try edits.appendSlice(self.allocator, item);
            }
        }
        try edits.appendSlice(self.allocator, "]");

        var result: std.ArrayList(u8) = .empty;
        defer result.deinit(self.allocator);
        var uri_buf: [512]u8 = undefined;
        const escaped_uri = escapeJson(uri.string, &uri_buf);
        try result.appendSlice(self.allocator, "{\"changes\": {\"");
        try result.appendSlice(self.allocator, escaped_uri);
        try result.appendSlice(self.allocator, "\": ");
        try result.appendSlice(self.allocator, edits.items);
        try result.appendSlice(self.allocator, "}}");
        return try self.makeResponse(id, result.items);
    }

    /// textDocument/signatureHelp: shows the signature of the innermost
    /// enclosing call while typing arguments.
    fn handleSignatureHelp(self: *Server, id: ?std.json.Value, params: ?std.json.Value) ![]const u8 {
        const p = params orelse return try self.makeResponse(id, "null");
        const text_doc = p.object.get("textDocument") orelse return try self.makeResponse(id, "null");
        const uri = text_doc.object.get("uri") orelse return try self.makeResponse(id, "null");
        const position = p.object.get("position") orelse return try self.makeResponse(id, "null");
        const doc = self.documents.get(uri.string) orelse return try self.makeResponse(id, "null");

        const line_num: usize = @intCast(position.object.get("line").?.integer);
        const char_num: usize = @intCast(position.object.get("character").?.integer);

        // Find the byte offset of the cursor
        var offset: usize = 0;
        var ln: usize = 0;
        var lines_it = std.mem.splitScalar(u8, doc.content, '\n');
        while (lines_it.next()) |line| : (ln += 1) {
            if (ln == line_num) {
                offset += @min(char_num, line.len);
                break;
            }
            offset += line.len + 1;
        }

        // Scan backwards for the innermost unclosed '(' and take the head word
        var depth: i32 = 0;
        var i = offset;
        var head: []const u8 = "";
        while (i > 0) {
            i -= 1;
            const c = doc.content[i];
            if (c == ')') depth += 1;
            if (c == '(') {
                if (depth == 0) {
                    var j = i + 1;
                    const start = j;
                    while (j < doc.content.len and isWordChar(doc.content[j])) j += 1;
                    head = doc.content[start..j];
                    break;
                }
                depth -= 1;
            }
        }
        if (head.len == 0) return try self.makeResponse(id, "null");

        const sig = builtin_docs.getSignature(head) orelse return try self.makeResponse(id, "null");
        const doc_md = builtin_docs.getDocumentation(head) orelse "";
        var sig_buf: [256]u8 = undefined;
        var doc_buf: [2048]u8 = undefined;
        const escaped_sig = escapeJson(sig, &sig_buf);
        const escaped_doc = escapeJson(doc_md, &doc_buf);
        var buf: [4096]u8 = undefined;
        const result = std.fmt.bufPrint(&buf,
            \\{{"signatures": [{{"label": "{s}", "documentation": {{"kind": "markdown", "value": "{s}"}}}}], "activeSignature": 0, "activeParameter": 0}}
        , .{ escaped_sig, escaped_doc }) catch return try self.makeResponse(id, "null");
        return try self.makeResponse(id, result);
    }

    /// Whole-document formatting via the canonical Lispium formatter.
    fn handleFormatting(self: *Server, id: ?std.json.Value, params: ?std.json.Value) ![]const u8 {
        const p = params orelse return try self.makeResponse(id, "null");
        const text_doc = p.object.get("textDocument") orelse return try self.makeResponse(id, "null");
        const uri = text_doc.object.get("uri") orelse return try self.makeResponse(id, "null");

        const doc = self.documents.get(uri.string) orelse return try self.makeResponse(id, "null");

        const formatted = formatter.format(self.allocator, doc.content) catch {
            // Unbalanced input etc: decline to format rather than erroring
            return try self.makeResponse(id, "null");
        };
        defer self.allocator.free(formatted);

        if (std.mem.eql(u8, formatted, doc.content)) {
            return try self.makeResponse(id, "[]");
        }

        // Replace the entire document (end position: one past the last line)
        const line_count = std.mem.count(u8, doc.content, "\n") + 1;

        var buf: std.Io.Writer.Allocating = .init(self.allocator);
        errdefer buf.deinit();
        try buf.writer.print(
            "[{{\"range\": {{\"start\": {{\"line\": 0, \"character\": 0}}, \"end\": {{\"line\": {d}, \"character\": 0}}}}, \"newText\": ",
            .{line_count},
        );
        try writeJsonString(&buf.writer, formatted);
        try buf.writer.writeAll("}]");

        const edits = try buf.toOwnedSlice();
        defer self.allocator.free(edits);
        return try self.makeResponse(id, edits);
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
        for (@import("docs.zig").docs) |entry| {
            if (!first) try buf.appendSlice(self.allocator, ",");
            first = false;

            const doc = builtin_docs.getDocumentation(entry.name) orelse "";
            var doc_buf: [2048]u8 = undefined;
            const escaped_doc = escapeJson(doc, &doc_buf);
            var sig_buf: [512]u8 = undefined;
            const escaped_sig = escapeJson(entry.signature, &sig_buf);

            var item_buf: [4096]u8 = undefined;
            const item = std.fmt.bufPrint(&item_buf,
                \\{{"label": "{s}", "kind": 3, "detail": "{s}", "documentation": {{"kind": "markdown", "value": "{s}"}}}}
            , .{ entry.name, escaped_sig, escaped_doc }) catch continue;
            try buf.appendSlice(self.allocator, item);
        }
        try buf.appendSlice(self.allocator, "]");

        return try self.makeResponse(id, buf.items);
    }

    fn publishDiagnostics(self: *Server, uri: []const u8, content: []const u8, stdout: *std.Io.Writer) !void {
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
        self.writeMessage(stdout, notification);
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
        if (id) |i| {
            switch (i) {
                .integer => |n| return try std.fmt.allocPrint(self.allocator, "{{\"jsonrpc\": \"2.0\", \"id\": {d}, \"result\": {s}}}", .{ n, result }),
                .string => |s| return try std.fmt.allocPrint(self.allocator, "{{\"jsonrpc\": \"2.0\", \"id\": \"{s}\", \"result\": {s}}}", .{ s, result }),
                else => {},
            }
        }
        return try std.fmt.allocPrint(self.allocator, "{{\"jsonrpc\": \"2.0\", \"id\": null, \"result\": {s}}}", .{result});
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

/// Writes a JSON-escaped string literal (with surrounding quotes).
fn writeJsonString(writer: *std.Io.Writer, text: []const u8) !void {
    try writer.writeAll("\"");
    for (text) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    try writer.print("\\u{x:0>4}", .{c});
                } else {
                    try writer.writeAll(&[_]u8{c});
                }
            },
        }
    }
    try writer.writeAll("\"");
}
