# Changelog

## [Unreleased]

### Changed
- Migrated to Zig 0.16.0 (new std.Io interface: readers/writers, file
  system access, clocks). No user-facing behavior changes; all 504 tests
  pass and all release targets cross-compile.
- Benchmarks now use the shared builtin registry (bench previously carried
  its own registration list).

## [0.5.0] - 2026-07-09

Correctness and robustness overhaul. Highlights:

### Fixed
- REPL/file-runner memory corruption: stored definitions, rules, and lambdas
  referenced a reused input buffer, silently breaking lookups (e.g.
  `(define (square x) ...)` then `(square 5)`) and crashing on cookbook files.
  Inputs are now session-lived and environment keys are owned.
- Unary minus: `(- 5)` now returns `-5` (was `5`); `(/ x)` is the reciprocal.
- `(diff (^ a x) x)`, `(diff (^ x x) x)`, and `(diff (abs x) x)` returned the
  input expression as its own derivative; all now differentiate correctly and
  unknown functions return an inert `(diff ...)` form.
- `(log x base)` argument order now matches the documentation.
- `(limit (^ (+ 1 (/ 1 x)) x) x inf)` returned 1; now returns e (indeterminate
  power forms use exp/log transform with a numeric-probe fallback).
- Taylor series included one term too few and emitted division-by-zero garbage
  at singularities (now a clean "undefined" error).
- Definite integrals with symbolic bounds fold numerically:
  `(integrate (sin x) x 0 pi)` => 2.
- Singular matrix inversion, bisection without a sign change, `permutations`
  with k > n, non-prime `gf` moduli, and negative `nth` indices now error
  instead of returning garbage (the last one crashed the process).
- Recursion depth and sum/product iteration are capped with clean errors
  instead of stack-overflow segfaults and infinite hangs.
- `memoize` no longer leaks; dsolve internals no longer leak.
- `cf-rational` handles negative denominators.

### Added
- Closures: lambdas capture their defining environment by value
  (`make-adder`/`compose` now work).
- `dsolve` is a special form, so `(dsolve (= (diff y x) y) y x)` works as
  documented.
- Complex arithmetic wired into `+ - * / ^ sqrt exp abs`; `(sqrt -4)` => 2i,
  `(evalf (exp (complex 0 pi)))` => -1; negative base with fractional exponent
  returns the principal complex value instead of NaN.
- Vector/matrix arithmetic: elementwise `+`/`-`, scalar `*` and `/`.
- New builtins: `abs`, `floor`, `ceil`, `round`, `sign`.
- Symbolic 2x2 eigenvalues; symbolic comparisons stay inert and `if` defers on
  undecidable conditions.
- Simplifier: power laws (x^a*x^b, (x^a)^b, x^a/x^b), sin^2+cos^2=1, sin/cos/
  tan of pi, commutative like-term merging, `(* -1 x)` => `(- x)`,
  assumption-aware `sqrt(x^2)=x`.
- `integrate` handles `(^ e x)` and `(^ a x)`.
- Single shared builtin registry (the REPL previously exposed only 120 of 163
  builtins); `eval` evaluates every expression in its input; infix-notation
  hint for new users; REPL comment handling.
- Pretty printer: sqrt/quaternion/GF/factors/continued-fraction rendering, raw
  text output for plots/steps/SVG, scientific notation for huge numbers.
- LaTeX: `\sqrt{}`, lambda bodies, inert integrals.
- 41 regression tests; dsolve tests assert real solutions.

### Changed
- CLI uses the fast SMP allocator: naive fib(20) dropped from ~15.7s to ~0.6s
  in debug builds.
- `factorize` returns `(factors (p e) ...)`; `solve` reports `no-solution` for
  contradictions; `assume` returns a confirmation.

## [0.1.0 - 0.4.0 development notes]

### Added
- Basic symbolic manipulation capabilities
  - Added simplification rules for basic arithmetic
  - Support for x + 0 = x simplification
  - Support for x * 1 = x simplification
  - Support for x * 0 = 0 simplification
  - Support for x - 0 = x simplification
  - Support for 0 - x = -x simplification
  - Support for x / 1 = x simplification
  - Support for 0 / x = 0 simplification
  - Support for x - x = 0 simplification
  - Support for x / x = 1 simplification
  - Support for combining like terms (e.g., x + x = 2*x)
  - Support for direct numeric operations (e.g., 2/4 = 0.5)
  - Support for coefficient reordering (e.g., x * (2 * x) = 2 * (x * x))
  - Support for distributive division (e.g., (a - b)/c = a/c - b/c)
  - Support for distributive multiplication (e.g., a * (b + c) = a*b + a*c)
  - Support for fraction subtraction (e.g., a/b - 1 = (a-b)/b)
  - Added recursion depth limit to prevent stack overflow
  - Added cycle detection in distribution rules
  - Added proper cleanup of intermediate expressions
  - Added error cleanup with errdefer
  - Added memory leak prevention in simplification rules
  - Added deep copying of expressions during simplification
  - Added safe memory management for recursive operations
  - Added single-copy strategy for expression manipulation
  - Added proper cleanup of copied expressions
  - Added expression copying utility function
  - Added safe expression printing with error handling
  - Added defensive checks in expression printing
  - Added pointer validation in expression printing
  - Added custom error types for printing failures
  - Added const correctness for expression printing
  - Added comprehensive expression tree validation
  - Added pre-print validation of entire expressions
  - Added separate validation and printing phases
  - Added cycle detection in expression validation
  - Added recursion depth limit in validation
  - Added pointer tracking to detect cycles
  - Added validation error types for cycles and limits
  - Recursive simplification of expressions
  - Memory-safe implementation with proper cleanup
- Symbolic arithmetic operations
  - Support for arithmetic with variables
  - Automatic conversion between numeric and symbolic expressions
  - Mixed numeric and symbolic computations
  - Proper handling of symbolic expressions in all arithmetic operations
- Symbolic variable evaluation
  - Variables can now be used without being defined
  - Undefined variables are treated as symbolic variables
  - Proper integration with simplification rules
- Differentiation support
  - Basic differentiation rules (d/dx(x) = 1, d/dx(c) = 0)
  - Product rule implementation (d/dx(u*v) = u*d/dx(v) + v*d/dx(u))
  - Sum rule implementation (d/dx(u+v) = d/dx(u) + d/dx(v))
  - Quotient rule implementation (d/dx(u/v) = (v*d/dx(u) - u*d/dx(v))/(v*v))
  - Automatic simplification of derivative results
  - Added diff builtin function to REPL environment
  - Proper error handling for invalid differentiation inputs
- Added OutOfMemory error handling in expression validation
- Improved expression validation
  - Added ArenaAllocator for validation memory management
  - Added comprehensive null pointer checks
  - Added proper cleanup with errdefer
  - Enhanced pointer validation throughout the process
  - Updated pointer validation to be Zig 0.13.0 compliant
  - Removed direct null checks in favor of proper pointer validation
  - Enhanced pointer validation using @intFromPtr

### Changed
- Updated build.zig to be compatible with Zig 0.13.0 build system API
  - Replaced deprecated std.build.Builder with new std.Build
  - Updated executable configuration to use the new struct-based API
  - Added proper target and optimization options
  - Added support for passing arguments to the run command
  - Fixed root_source_file specification to use cwd_relative path
- Updated main.zig to be compatible with Zig 0.13.0
  - Fixed GPA allocator API usage
  - Updated argument parsing to use argsWithAllocator with correct value type
  - Added proper resource cleanup with defer statements
  - Fixed allocator to be passed by pointer to match repl.run signature
- Updated repl.zig to be compatible with Zig 0.13.0
  - Replaced readUntilDelimiterAlloc with readUntilDelimiterArrayList
  - Added buffer reuse for better memory efficiency
  - Updated number formatting to use {d} instead of {f}
  - Added proper cleanup with defer statements
  - Fixed builtin function initialization
  - Added error handling with user-friendly messages
  - Added cleanup of evaluation results
  - Updated error types to use std.fs.File.WriteError
- Updated environment.zig to be compatible with Zig 0.13.0
  - Replaced AutoHashMap with StringHashMap for string keys
  - Fixed allocator initialization for HashMaps
  - Improved builtins initialization with proper error handling
  - Added deinit function for proper cleanup
  - Added recursive cleanup of stored expressions
  - Removed duplicate builtin initialization
- Updated parser.zig to be compatible with Zig 0.13.0
  - Fixed allocator usage in ArrayList initialization
  - Updated struct creation syntax
  - Improved float parsing with std.fmt.parseFloat
- Updated tokenizer.zig to be compatible with Zig 0.13.0
  - Replaced isSpace with isWhitespace
  - Fixed slice syntax
- Updated builtins.zig to be compatible with Zig 0.13.0
  - Fixed struct creation syntax
  - Improved array iteration
  - Added proper error handling for allocations
  - Updated function pointer type to use *const fn
  - Added OutOfMemory to BuiltinError set
  - Fixed error handling syntax in create calls
- Updated evaluator.zig to be compatible with Zig 0.13.0
  - Added proper error set handling
  - Fixed function pointer usage
  - Improved error propagation
  - Added environment errors to error set
  - Fixed operator lookup to use getBuiltin directly
  - Optimized evaluation by avoiding redundant symbol lookup 