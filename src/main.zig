const std = @import("std");
const repl = @import("repl.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();
    var args_it = try std.process.argsWithAllocator(allocator);
    defer args_it.deinit();
    _ = args_it.skip(); // skip executable name

    if (args_it.next()) |arg| {
        if (std.mem.eql(u8, arg, "repl")) {
            try repl.run(&allocator);
            return;
        }
    }
    std.debug.print("Run with the argument \"repl\" for interactive mode.\n", .{});
}
