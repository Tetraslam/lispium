const std = @import("std");
const Expr = @import("parser.zig").Expr;

pub const SimplifyError = error{
    OutOfMemory,
    RecursionLimit,
};

const MAX_RECURSION_DEPTH = 100;

fn exprEqual(a: *Expr, b: *Expr) bool {
    switch (a.*) {
        .number => |n| {
            if (b.* == .number) {
                return n == b.number;
            }
            return false;
        },
        .symbol => |s| {
            if (b.* == .symbol) {
                return std.mem.eql(u8, s, b.symbol);
            }
            return false;
        },
        .list => |lst| {
            if (b.* != .list) return false;
            if (lst.items.len != b.list.items.len) return false;
            for (lst.items, b.list.items) |item_a, item_b| {
                if (!exprEqual(item_a, item_b)) return false;
            }
            return true;
        },
    }
}

fn copyExpr(expr: *Expr, allocator: *std.mem.Allocator) !*Expr {
    const result = try allocator.create(Expr);
    errdefer allocator.destroy(result);

    result.* = switch (expr.*) {
        .number => |n| .{ .number = n },
        .symbol => |s| .{ .symbol = s },
        .list => |l| blk: {
            var new_list = std.ArrayList(*Expr).init(allocator.*);
            errdefer {
                for (new_list.items) |item| {
                    item.deinit(allocator.*);
                    allocator.destroy(item);
                }
                new_list.deinit();
            }
            for (l.items) |item| {
                const copied = try copyExpr(item, allocator);
                try new_list.append(copied);
            }
            break :blk .{ .list = new_list };
        },
    };
    return result;
}

fn simplifyWithDepth(expr: *Expr, allocator: *std.mem.Allocator, depth: usize) SimplifyError!*Expr {
    if (depth > MAX_RECURSION_DEPTH) {
        return SimplifyError.RecursionLimit;
    }

    switch (expr.*) {
        .number, .symbol => return expr,
        .list => |lst| {
            if (lst.items.len == 0) return expr;

            const op = lst.items[0];
            if (op.* != .symbol) return expr;

            // First simplify all arguments
            var simplified_args = std.ArrayList(*Expr).init(allocator.*);
            errdefer {
                for (simplified_args.items) |arg| {
                    arg.deinit(allocator.*);
                    allocator.destroy(arg);
                }
                simplified_args.deinit();
            }

            // Simplify arguments without copying first
            for (lst.items[1..]) |arg| {
                const simp_arg = try simplifyWithDepth(arg, allocator, depth + 1);
                try simplified_args.append(simp_arg);
            }

            // Try to evaluate numeric operations first
            if (simplified_args.items.len == 2) {
                if (simplified_args.items[0].* == .number and simplified_args.items[1].* == .number) {
                    const a = simplified_args.items[0].number;
                    const b = simplified_args.items[1].number;
                    const result = try allocator.create(Expr);
                    errdefer allocator.destroy(result);

                    if (std.mem.eql(u8, op.symbol, "+")) {
                        result.* = .{ .number = a + b };
                        return result;
                    } else if (std.mem.eql(u8, op.symbol, "-")) {
                        result.* = .{ .number = a - b };
                        return result;
                    } else if (std.mem.eql(u8, op.symbol, "*")) {
                        result.* = .{ .number = a * b };
                        return result;
                    } else if (std.mem.eql(u8, op.symbol, "/")) {
                        if (b != 0) {
                            result.* = .{ .number = a / b };
                            return result;
                        }
                    }
                }
            }

            // Apply simplification rules
            if (std.mem.eql(u8, op.symbol, "+")) {
                // Combine like terms
                if (simplified_args.items.len >= 2) {
                    var i: usize = 0;
                    while (i < simplified_args.items.len) : (i += 1) {
                        var j: usize = i + 1;
                        while (j < simplified_args.items.len) {
                            if (exprEqual(simplified_args.items[i], simplified_args.items[j])) {
                                // Create 2 * x
                                var mul_list = std.ArrayList(*Expr).init(allocator.*);
                                const mul_op = try allocator.create(Expr);
                                mul_op.* = .{ .symbol = "*" };
                                const two = try allocator.create(Expr);
                                two.* = .{ .number = 2 };
                                try mul_list.append(mul_op);
                                try mul_list.append(two);
                                try mul_list.append(simplified_args.items[i]);

                                const mul_expr = try allocator.create(Expr);
                                mul_expr.* = .{ .list = mul_list };

                                // Replace the first term with 2*x and remove the second
                                simplified_args.items[i] = mul_expr;
                                _ = simplified_args.orderedRemove(j);
                                continue;
                            }
                            j += 1;
                        }
                    }
                }

                // x + 0 = x
                if (simplified_args.items.len == 2) {
                    if (simplified_args.items[1].* == .number and simplified_args.items[1].number == 0) {
                        return simplified_args.items[0];
                    }
                    if (simplified_args.items[0].* == .number and simplified_args.items[0].number == 0) {
                        return simplified_args.items[1];
                    }
                }
            } else if (std.mem.eql(u8, op.symbol, "*")) {
                // x * 1 = x
                // x * 0 = 0
                if (simplified_args.items.len == 2) {
                    if (simplified_args.items[1].* == .number) {
                        if (simplified_args.items[1].number == 1) {
                            return simplified_args.items[0];
                        }
                        if (simplified_args.items[1].number == 0) {
                            const result = try allocator.create(Expr);
                            errdefer allocator.destroy(result);
                            result.* = .{ .number = 0 };
                            return result;
                        }
                    }
                    if (simplified_args.items[0].* == .number) {
                        if (simplified_args.items[0].number == 1) {
                            return simplified_args.items[1];
                        }
                        if (simplified_args.items[0].number == 0) {
                            const result = try allocator.create(Expr);
                            errdefer allocator.destroy(result);
                            result.* = .{ .number = 0 };
                            return result;
                        }
                    }
                }

                // Handle nested multiplication with coefficients
                // (* x (* 2 x)) = (* 2 (* x x))
                if (simplified_args.items.len == 2) {
                    if (simplified_args.items[1].* == .list) {
                        const inner = simplified_args.items[1].list;
                        if (inner.items.len == 3 and
                            std.mem.eql(u8, inner.items[0].symbol, "*") and
                            inner.items[1].* == .number)
                        {
                            // Reorder to put coefficient first
                            var new_list = std.ArrayList(*Expr).init(allocator.*);
                            try new_list.append(op);
                            try new_list.append(inner.items[1]); // coefficient

                            // Create x * x
                            var prod_list = std.ArrayList(*Expr).init(allocator.*);
                            const mul_op = try allocator.create(Expr);
                            mul_op.* = .{ .symbol = "*" };
                            try prod_list.append(mul_op);
                            try prod_list.append(simplified_args.items[0]);
                            try prod_list.append(inner.items[2]);

                            const prod_expr = try allocator.create(Expr);
                            prod_expr.* = .{ .list = prod_list };
                            try new_list.append(prod_expr);

                            const result = try allocator.create(Expr);
                            result.* = .{ .list = new_list };
                            return try simplifyWithDepth(result, allocator, depth + 1);
                        }
                    }
                }

                // Handle distribution over addition: (* a (+ b c)) = (+ (* a b) (* a c))
                if (simplified_args.items.len == 2) {
                    const a = simplified_args.items[0];
                    const b = simplified_args.items[1];
                    if (b.* == .list and b.list.items.len == 3 and
                        std.mem.eql(u8, b.list.items[0].symbol, "+"))
                    {
                        // Create (* a b)
                        var term1 = std.ArrayList(*Expr).init(allocator.*);
                        const mul_op1 = try allocator.create(Expr);
                        mul_op1.* = .{ .symbol = "*" };
                        try term1.append(mul_op1);
                        try term1.append(a);
                        try term1.append(b.list.items[1]);

                        // Create (* a c)
                        var term2 = std.ArrayList(*Expr).init(allocator.*);
                        const mul_op2 = try allocator.create(Expr);
                        mul_op2.* = .{ .symbol = "*" };
                        try term2.append(mul_op2);
                        try term2.append(a);
                        try term2.append(b.list.items[2]);

                        // Create final (+ term1 term2)
                        var sum_list = std.ArrayList(*Expr).init(allocator.*);
                        const add_op = try allocator.create(Expr);
                        add_op.* = .{ .symbol = "+" };
                        const term1_expr = try allocator.create(Expr);
                        term1_expr.* = .{ .list = term1 };
                        const term2_expr = try allocator.create(Expr);
                        term2_expr.* = .{ .list = term2 };

                        try sum_list.append(add_op);
                        try sum_list.append(term1_expr);
                        try sum_list.append(term2_expr);

                        const result = try allocator.create(Expr);
                        result.* = .{ .list = sum_list };
                        return try simplifyWithDepth(result, allocator, depth + 1);
                    }
                }
            } else if (std.mem.eql(u8, op.symbol, "-")) {
                // x - x = 0
                if (simplified_args.items.len == 2 and exprEqual(simplified_args.items[0], simplified_args.items[1])) {
                    const result = try allocator.create(Expr);
                    errdefer allocator.destroy(result);
                    result.* = .{ .number = 0 };
                    return result;
                }
                // x - 0 = x
                if (simplified_args.items.len == 2 and
                    simplified_args.items[1].* == .number and
                    simplified_args.items[1].number == 0)
                {
                    return simplified_args.items[0];
                }
                // 0 - x = -x
                if (simplified_args.items.len == 2 and
                    simplified_args.items[0].* == .number and
                    simplified_args.items[0].number == 0)
                {
                    var neg_list = std.ArrayList(*Expr).init(allocator.*);
                    const mul_op = try allocator.create(Expr);
                    mul_op.* = .{ .symbol = "*" };
                    const neg_one = try allocator.create(Expr);
                    neg_one.* = .{ .number = -1 };
                    try neg_list.append(mul_op);
                    try neg_list.append(neg_one);
                    try neg_list.append(simplified_args.items[1]);

                    const result = try allocator.create(Expr);
                    result.* = .{ .list = neg_list };
                    return result;
                }

                // Handle (- (/ a b) 1) = (/ (- a b) b)
                if (simplified_args.items.len == 2 and
                    simplified_args.items[0].* == .list and
                    simplified_args.items[0].list.items.len == 3 and
                    std.mem.eql(u8, simplified_args.items[0].list.items[0].symbol, "/") and
                    simplified_args.items[1].* == .number and
                    simplified_args.items[1].number == 1)
                {
                    const div = simplified_args.items[0].list;
                    const num = div.items[1];
                    const denom = div.items[2];

                    // Create (- num denom)
                    var sub_list = std.ArrayList(*Expr).init(allocator.*);
                    const sub_op = try allocator.create(Expr);
                    sub_op.* = .{ .symbol = "-" };
                    try sub_list.append(sub_op);
                    try sub_list.append(num);
                    try sub_list.append(denom);

                    // Create final (/ (- num denom) denom)
                    var div_list = std.ArrayList(*Expr).init(allocator.*);
                    const div_op = try allocator.create(Expr);
                    div_op.* = .{ .symbol = "/" };
                    const sub_expr = try allocator.create(Expr);
                    sub_expr.* = .{ .list = sub_list };

                    try div_list.append(div_op);
                    try div_list.append(sub_expr);
                    try div_list.append(denom);

                    const result = try allocator.create(Expr);
                    result.* = .{ .list = div_list };
                    return try simplifyWithDepth(result, allocator, depth + 1);
                }
            } else if (std.mem.eql(u8, op.symbol, "/")) {
                // x/x = 1 (assuming x ≠ 0)
                if (simplified_args.items.len == 2 and exprEqual(simplified_args.items[0], simplified_args.items[1])) {
                    const result = try allocator.create(Expr);
                    errdefer allocator.destroy(result);
                    result.* = .{ .number = 1 };
                    return result;
                }
                // x / 1 = x
                if (simplified_args.items.len == 2 and
                    simplified_args.items[1].* == .number and
                    simplified_args.items[1].number == 1)
                {
                    return simplified_args.items[0];
                }
                // 0 / x = 0 (assuming x ≠ 0)
                if (simplified_args.items.len == 2 and
                    simplified_args.items[0].* == .number and
                    simplified_args.items[0].number == 0)
                {
                    const result = try allocator.create(Expr);
                    errdefer allocator.destroy(result);
                    result.* = .{ .number = 0 };
                    return result;
                }

                // Handle division of subtraction: (/ (- a b) c) = (- (/ a c) (/ b c))
                if (simplified_args.items.len == 2 and
                    simplified_args.items[0].* == .list and
                    simplified_args.items[0].list.items.len == 3 and
                    std.mem.eql(u8, simplified_args.items[0].list.items[0].symbol, "-"))
                {
                    const num = simplified_args.items[0].list;
                    const denom = simplified_args.items[1];

                    // Create (/ a c)
                    var div1 = std.ArrayList(*Expr).init(allocator.*);
                    const div_op1 = try allocator.create(Expr);
                    div_op1.* = .{ .symbol = "/" };
                    try div1.append(div_op1);
                    try div1.append(num.items[1]);
                    try div1.append(denom);

                    // Create (/ b c)
                    var div2 = std.ArrayList(*Expr).init(allocator.*);
                    const div_op2 = try allocator.create(Expr);
                    div_op2.* = .{ .symbol = "/" };
                    try div2.append(div_op2);
                    try div2.append(num.items[2]);
                    try div2.append(denom);

                    // Create final (- div1 div2)
                    var result_list = std.ArrayList(*Expr).init(allocator.*);
                    const sub_op = try allocator.create(Expr);
                    sub_op.* = .{ .symbol = "-" };
                    const div1_expr = try allocator.create(Expr);
                    div1_expr.* = .{ .list = div1 };
                    const div2_expr = try allocator.create(Expr);
                    div2_expr.* = .{ .list = div2 };

                    try result_list.append(sub_op);
                    try result_list.append(div1_expr);
                    try result_list.append(div2_expr);

                    const result = try allocator.create(Expr);
                    result.* = .{ .list = result_list };
                    return try simplifyWithDepth(result, allocator, depth + 1);
                }
            }

            // If no simplification rule applies, return a new list with simplified arguments
            var new_list = std.ArrayList(*Expr).init(allocator.*);
            errdefer {
                for (new_list.items) |item| {
                    item.deinit(allocator.*);
                    allocator.destroy(item);
                }
                new_list.deinit();
            }

            try new_list.append(op);
            for (simplified_args.items) |arg| {
                try new_list.append(arg);
            }
            const result = try allocator.create(Expr);
            errdefer allocator.destroy(result);
            result.* = .{ .list = new_list };
            return result;
        },
    }
}

pub fn simplify(expr: *Expr, allocator: *std.mem.Allocator) SimplifyError!*Expr {
    // Make a copy of the input expression to avoid modifying it
    const copied = try copyExpr(expr, allocator);
    errdefer {
        copied.deinit(allocator.*);
        allocator.destroy(copied);
    }
    return simplifyWithDepth(copied, allocator, 0);
}

pub fn diff(expr: *Expr, var_name: []const u8, allocator: *std.mem.Allocator) SimplifyError!*Expr {
    // Make a copy of the input expression to avoid modifying it
    const copied = try copyExpr(expr, allocator);
    errdefer {
        copied.deinit(allocator.*);
        allocator.destroy(copied);
    }

    const result = switch (copied.*) {
        .number => blk: {
            const result = try allocator.create(Expr);
            result.* = .{ .number = 0 };
            break :blk result;
        },
        .symbol => |s| blk: {
            const result = try allocator.create(Expr);
            result.* = .{ .number = if (std.mem.eql(u8, s, var_name)) 1 else 0 };
            break :blk result;
        },
        .list => |lst| blk: {
            if (lst.items.len == 0) break :blk copied;
            const op = lst.items[0];
            if (op.* != .symbol) break :blk copied;

            if (std.mem.eql(u8, op.symbol, "+")) {
                // d/dx(u + v) = d/dx(u) + d/dx(v)
                var new_list = std.ArrayList(*Expr).init(allocator.*);
                const new_op = try allocator.create(Expr);
                new_op.* = .{ .symbol = "+" };
                try new_list.append(new_op);

                for (lst.items[1..]) |arg| {
                    const d = try diff(arg, var_name, allocator);
                    try new_list.append(d);
                }

                const result = try allocator.create(Expr);
                result.* = .{ .list = new_list };
                break :blk result;
            } else if (std.mem.eql(u8, op.symbol, "*")) {
                // d/dx(u * v) = u * d/dx(v) + v * d/dx(u)
                if (lst.items.len == 3) {
                    const u = lst.items[1];
                    const v = lst.items[2];
                    const du = try diff(u, var_name, allocator);
                    const dv = try diff(v, var_name, allocator);

                    // Create u * dv
                    var term1 = std.ArrayList(*Expr).init(allocator.*);
                    const mul_op1 = try allocator.create(Expr);
                    mul_op1.* = .{ .symbol = "*" };
                    try term1.append(mul_op1);
                    try term1.append(u);
                    try term1.append(dv);

                    // Create v * du
                    var term2 = std.ArrayList(*Expr).init(allocator.*);
                    const mul_op2 = try allocator.create(Expr);
                    mul_op2.* = .{ .symbol = "*" };
                    try term2.append(mul_op2);
                    try term2.append(v);
                    try term2.append(du);

                    // Create final sum
                    var sum_list = std.ArrayList(*Expr).init(allocator.*);
                    const add_op = try allocator.create(Expr);
                    add_op.* = .{ .symbol = "+" };
                    const term1_expr = try allocator.create(Expr);
                    term1_expr.* = .{ .list = term1 };
                    const term2_expr = try allocator.create(Expr);
                    term2_expr.* = .{ .list = term2 };

                    try sum_list.append(add_op);
                    try sum_list.append(term1_expr);
                    try sum_list.append(term2_expr);

                    const result = try allocator.create(Expr);
                    result.* = .{ .list = sum_list };
                    break :blk result;
                }
            } else if (std.mem.eql(u8, op.symbol, "/")) {
                // d/dx(u/v) = (v * d/dx(u) - u * d/dx(v)) / (v * v)
                if (lst.items.len == 3) {
                    const u = lst.items[1];
                    const v = lst.items[2];
                    const du = try diff(u, var_name, allocator);
                    const dv = try diff(v, var_name, allocator);

                    // Create v * du
                    var term1 = std.ArrayList(*Expr).init(allocator.*);
                    const mul_op1 = try allocator.create(Expr);
                    mul_op1.* = .{ .symbol = "*" };
                    try term1.append(mul_op1);
                    try term1.append(v);
                    try term1.append(du);

                    // Create u * dv
                    var term2 = std.ArrayList(*Expr).init(allocator.*);
                    const mul_op2 = try allocator.create(Expr);
                    mul_op2.* = .{ .symbol = "*" };
                    try term2.append(mul_op2);
                    try term2.append(u);
                    try term2.append(dv);

                    // Create v * v (denominator)
                    var denom = std.ArrayList(*Expr).init(allocator.*);
                    const mul_op3 = try allocator.create(Expr);
                    mul_op3.* = .{ .symbol = "*" };
                    try denom.append(mul_op3);
                    try denom.append(v);
                    try denom.append(v);

                    // Create numerator (term1 - term2)
                    var num = std.ArrayList(*Expr).init(allocator.*);
                    const sub_op = try allocator.create(Expr);
                    sub_op.* = .{ .symbol = "-" };
                    const term1_expr = try allocator.create(Expr);
                    term1_expr.* = .{ .list = term1 };
                    const term2_expr = try allocator.create(Expr);
                    term2_expr.* = .{ .list = term2 };
                    try num.append(sub_op);
                    try num.append(term1_expr);
                    try num.append(term2_expr);

                    // Create final division
                    var div_list = std.ArrayList(*Expr).init(allocator.*);
                    const div_op = try allocator.create(Expr);
                    div_op.* = .{ .symbol = "/" };
                    const num_expr = try allocator.create(Expr);
                    num_expr.* = .{ .list = num };
                    const denom_expr = try allocator.create(Expr);
                    denom_expr.* = .{ .list = denom };

                    try div_list.append(div_op);
                    try div_list.append(num_expr);
                    try div_list.append(denom_expr);

                    const result = try allocator.create(Expr);
                    result.* = .{ .list = div_list };
                    break :blk result;
                }
            }

            // For unsupported operations, return 0
            const result = try allocator.create(Expr);
            result.* = .{ .number = 0 };
            break :blk result;
        },
    };

    // Clean up the copy if we created a new expression
    if (result != copied) {
        copied.deinit(allocator.*);
        allocator.destroy(copied);
    }

    return result;
}
