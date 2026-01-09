// Main test file - imports all modular test files
// This allows `zig build test` to run all tests from the organized test modules

const std = @import("std");

// Import all test modules to include their tests
comptime {
    _ = @import("tests/parser.zig");
    _ = @import("tests/arithmetic.zig");
    _ = @import("tests/simplify.zig");
    _ = @import("tests/calculus.zig");
    _ = @import("tests/algebra.zig");
    _ = @import("tests/complex.zig");
    _ = @import("tests/lambda.zig");
    _ = @import("tests/rewrite.zig");
    _ = @import("tests/identities.zig");
    _ = @import("tests/matrix.zig");
    _ = @import("tests/series.zig");
    _ = @import("tests/vector.zig");
    _ = @import("tests/factor.zig");
    _ = @import("tests/partial_fractions.zig");
    _ = @import("tests/collect.zig");
    _ = @import("tests/modular.zig");
    _ = @import("tests/boolean.zig");
    _ = @import("tests/polynomial.zig");
    _ = @import("tests/assumptions.zig");
    _ = @import("tests/combinatorics.zig");
    _ = @import("tests/vector_calculus.zig");
    _ = @import("tests/statistics.zig");
    _ = @import("tests/quaternion.zig");
    _ = @import("tests/finite_field.zig");
    _ = @import("tests/latex.zig");
}

// Re-export helpers for any external use
pub const helpers = @import("tests/helpers.zig");
