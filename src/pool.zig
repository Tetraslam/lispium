const std = @import("std");
const builtin = @import("builtin");

/// Poison recycled blocks only in Debug builds; the double memset is the
/// single most expensive line in the interpreter under ReleaseSafe.
const poison = builtin.mode == .Debug;

/// A single-threaded free-list allocator for the interpreter's hot path.
///
/// The evaluator allocates and frees millions of tiny fixed-size blocks
/// (every `Expr` node is 56 bytes) per second. Routing those through a
/// thread-safe general-purpose allocator costs more in locking and
/// safety memsets than the actual evaluation. This wrapper recycles all
/// small blocks (<= 64 bytes, align <= 8) through per-size-class free
/// lists and delegates everything else to the backing allocator.
///
/// NOT thread-safe by design: the CLI evaluates on a single thread.
/// Ownership: blocks handed to the backing allocator are always
/// class-sized, so `deinit` can return every cached block exactly.
pub const InterpreterAllocator = struct {
    backing: std.mem.Allocator,
    free_lists: [num_classes]?*Node = @splat(null),

    const Node = struct { next: ?*Node };

    const class_step = 8;
    const max_small = 512;
    const num_classes = max_small / class_step; // 8, 16, ..., 64
    const max_align: std.mem.Alignment = .@"8";

    pub fn init(backing: std.mem.Allocator) InterpreterAllocator {
        return .{ .backing = backing };
    }

    /// Returns every cached block to the backing allocator.
    pub fn deinit(self: *InterpreterAllocator) void {
        for (&self.free_lists, 0..) |*head, i| {
            const size = (i + 1) * class_step;
            var node = head.*;
            while (node) |n| {
                node = n.next;
                const block: [*]u8 = @ptrCast(n);
                self.backing.rawFree(block[0..size], max_align, @returnAddress());
            }
            head.* = null;
        }
    }

    pub fn allocator(self: *InterpreterAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    /// Small allocations (including zero-length ones, which round up to
    /// the first class) qualify for pooling when they don't need more
    /// than 8-byte alignment.
    inline fn classIndex(len: usize, alignment: std.mem.Alignment) ?usize {
        if (len > max_small) return null;
        if (@intFromEnum(alignment) > @intFromEnum(max_align)) return null;
        if (len == 0) return 0;
        return (len - 1) / class_step;
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *InterpreterAllocator = @ptrCast(@alignCast(ctx));
        const ci = classIndex(len, alignment) orelse
            return self.backing.rawAlloc(len, alignment, ret_addr);
        if (self.free_lists[ci]) |node| {
            self.free_lists[ci] = node.next;
            const block: [*]u8 = @ptrCast(node);
            if (poison) @memset(block[0..len], undefined);
            return block;
        }
        // Allocate the full class size so free/deinit are uniform
        return self.backing.rawAlloc((ci + 1) * class_step, max_align, ret_addr);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *InterpreterAllocator = @ptrCast(@alignCast(ctx));
        if (classIndex(memory.len, alignment)) |ci| {
            // A pooled block can grow/shrink within its class
            return classIndex(new_len, alignment) == ci;
        }
        if (classIndex(new_len, alignment) != null) return false; // would change ownership
        return self.backing.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *InterpreterAllocator = @ptrCast(@alignCast(ctx));
        if (classIndex(memory.len, alignment)) |ci| {
            if (classIndex(new_len, alignment) == ci) return memory.ptr;
            return null; // force alloc+copy through the caller
        }
        if (classIndex(new_len, alignment) != null) return null;
        return self.backing.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *InterpreterAllocator = @ptrCast(@alignCast(ctx));
        const ci = classIndex(memory.len, alignment) orelse
            return self.backing.rawFree(memory, alignment, ret_addr);
        if (poison) @memset(memory, undefined);
        const node: *Node = @ptrCast(@alignCast(memory.ptr));
        node.next = self.free_lists[ci];
        self.free_lists[ci] = node;
    }
};

test "pool: recycles small blocks" {
    var pool = InterpreterAllocator.init(std.testing.allocator);
    defer pool.deinit();
    const a = pool.allocator();

    const p1 = try a.create(u64);
    const addr1 = @intFromPtr(p1);
    a.destroy(p1);
    const p2 = try a.create(u64);
    defer a.destroy(p2);
    try std.testing.expectEqual(addr1, @intFromPtr(p2));
}

test "pool: mixed sizes round-trip" {
    var pool = InterpreterAllocator.init(std.testing.allocator);
    defer pool.deinit();
    const a = pool.allocator();

    // Small (pooled), large (delegated), and growing slices
    var list: std.ArrayList(u64) = .empty;
    defer list.deinit(a);
    for (0..1000) |i| {
        try list.append(a, i);
    }
    for (list.items, 0..) |v, i| {
        try std.testing.expectEqual(@as(u64, i), v);
    }

    const big = try a.alloc(u8, 4096);
    defer a.free(big);
    const small = try a.alloc(u8, 3);
    defer a.free(small);
    const exact = try a.alloc(u8, 64);
    defer a.free(exact);
}
