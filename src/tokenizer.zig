const std = @import("std");

pub const Tokenizer = struct {
    input: []const u8,
    position: usize = 0,

    pub fn init(input: []const u8) Tokenizer {
        return Tokenizer{
            .input = input,
            .position = 0,
        };
    }

    pub fn next(self: *Tokenizer) ?[]const u8 {
        // Skip whitespace
        while (self.position < self.input.len and std.ascii.isWhitespace(self.input[self.position])) : (self.position += 1) {}
        if (self.position >= self.input.len) return null;
        const start = self.position;
        const c = self.input[start];
        if (c == '(' or c == ')') {
            self.position += 1;
            return self.input[start..self.position];
        }
        // Reader sugar: ' (quote), ` (quasiquote), , (unquote) are their
        // own tokens so the parser can expand them
        if (c == '\'' or c == '`' or c == ',') {
            self.position += 1;
            return self.input[start..self.position];
        }
        // String literal: consume through the closing quote, honoring
        // backslash escapes; the token includes both quotes
        if (c == '"') {
            self.position += 1;
            while (self.position < self.input.len) {
                const ch = self.input[self.position];
                if (ch == '\\' and self.position + 1 < self.input.len) {
                    self.position += 2;
                    continue;
                }
                self.position += 1;
                if (ch == '"') break;
            }
            return self.input[start..self.position];
        }
        while (self.position < self.input.len and
            !std.ascii.isWhitespace(self.input[self.position]) and
            self.input[self.position] != '(' and
            self.input[self.position] != ')' and
            self.input[self.position] != '"') : (self.position += 1)
        {}
        return self.input[start..self.position];
    }
};
