# Changelog

## [0.13.0] - 2026-07-13

The dogfood release: four long example programs written in Lispium
(examples/), and every interpreter bug they exposed, fixed.

### Added
- **examples/**: a metacircular evaluator (a Lisp interpreter in Lispium
  with closures, cond, mutual recursion), a neural network learning XOR
  by backpropagation, a regex engine (parser + set-of-positions matcher,
  no exponential backtracking), and a Turing machine simulator (binary
  increment, 3-state busy beaver, palindrome recognizer). All
  self-testing via assert.

### Fixed
- Parens inside string literals no longer confuse the run-mode statement
  splitter or the REPL's multi-line detection (escapes honored).
- Higher-order builtins (map/filter/reduce) bind element VALUES as-is
  instead of re-evaluating them as code, matching `apply`; list-valued
  elements like '((f 1) (g 2)) now flow through safely. Errors raised
  inside map/reduce lambdas propagate instead of masking as "invalid
  argument".
- Closure capture quotes captured list/symbol values, so closures over
  data (alists, quoted trees) no longer re-execute them as applications.
- `lispium fmt` passes shebang lines through instead of mangling them.
- simplify flattens nested sums/products and folds constants across
  levels: (* 4 (* 3 x^2)) -> 12x^2, which also fixes unsimplified nth
  derivatives.
- REPL: eigenvalues/roots print as {a, b} sets, -0 is normalized, and
  persistent history is only written by interactive sessions.
- bench: the summary box sizes itself to its content; the header is
  centered.

### Changed
- README: install with `uv tool install lispium`.

## [0.12.0] - 2026-07-13

The speed release. Programs run 4-6.5x faster (recursive calls 4.6x,
tail loops 6.5x, map/filter/reduce pipelines 4.3x); micro benchmarks
average 1.9x. No language changes.

### Changed
- All CLI allocation goes through a single-threaded free-list pool
  (`pool.zig`), eliminating allocator lock and safety-memset overhead on
  the interpreter's small-block churn.
- Function calls borrow lambdas from the environment instead of deep
  copying them per call (and per tail-call iteration). Values displaced
  while possibly executing are freed at evaluator depth zero.
- Operator dispatch: special forms use a comptime string map; variable/
  builtin/macro resolution goes through a generation-validated inline
  cache, so tight loops skip all hashmap lookups.
- map/filter/reduce call lambdas directly instead of building a synthetic
  call expression (with a full lambda copy) per element.
- `factorial` above 20 got ~2x faster as a side effect of pooling.

### Added
- `lispium bench` overhaul: a Programs category (recursion, tail loops,
  closures, higher-order pipelines, strings, sort, macros, bigints),
  median-based reporting, `--filter`, and `--save FILE` / `--compare
  FILE` with per-benchmark deltas and a geomean summary.

## [0.11.0] - 2026-07-13

The pinpoint release.

### Added
- **Source positions in errors**: run mode reports `file:line:col` of the
  innermost failing subexpression (parse and eval errors), `lispium eval`
  reports `at line:col`, and the REPL echoes the input with a caret under
  the failing token. Inside user functions, errors point at the call site
  and keep the call-stack trace.
- Statement buffers preserve the original file layout, so positions in
  multi-line expressions map back to the real line and column.

### Fixed
- An unclosed statement at end of file is now a parse error instead of
  being silently dropped.
- Several statements on one line (or one `lispium eval` string) all
  evaluate; previously everything after the first was silently ignored.
- A stray `)` after a complete expression is now reported.

### Changed
- Shorter README; repo description and CI badge added.

## [0.10.0] - 2026-07-13

The bignum release.

### Added
- **Arbitrary-precision integers**: integer literals and results outside
  the f64-exact range become exact big integers (backed by
  `std.math.big.int`), demoting back to plain numbers when they fit.
  Exact `+ - * ^ mod gcd abs sign`, exact `= < >` comparisons, and `/`
  when each divisor divides evenly (float otherwise).
- **Exact factorials past 20!**: `(factorial 25)` returns
  15511210043330985984000000 instead of an error above 170 (new cap:
  100000).
- **Exact integer powers**: `(^ 2 100)` returns the full 31-digit value
  (integer base, integer exponent up to 1e6).
- Bigs flow through variables, lambdas, `evalf`, LaTeX export, and all
  printers; mixing with floats produces floats.

## [0.9.0] - 2026-07-11

The polish release.

### Added
- **Native REPL line editor** (POSIX terminals): arrow-key history and
  cursor movement, Home/End, Ctrl+A/E/K/U/W/L, Ctrl+C cancels the line,
  Ctrl+D exits; piped input and Windows fall back to plain reading.
- **Step evaluator**: `(step expr)` prints every reduction with its
  result, indented by depth (capped at 200 steps).
- **Profiling**: `lispium run --profile` prints a per-statement cost
  table (sorted, with percentages and line numbers).
- **LSP**: rename (whole-word, per-document) and signature help while
  typing arguments.
- **VS Code**: CodeLens "eval" above every top-level form, showing the
  result inline.

## [0.8.0] - 2026-07-11

The tooling release.

### Added
- **Documentation site**: `lispium docs [name|--html]` renders the shared
  docs table; the generated site (with search) is served by GitHub Pages
  at https://tetraslam.github.io/lispium/ and CI-checked for freshness.
- **Browser playground**: `zig build wasm` builds a 530 KB WebAssembly
  module (persistent environment, captured print output); the playground
  at /playground/ runs entirely client-side.
- **Stack traces**: evaluation errors print the user-function call chain;
  lambdas carry their define-time names; tail calls rename the reused
  frame; `try` discards frames from the failed branch.
- **Quartic solve**: Ferrari's method via the resolvent cubic, with the
  biquadratic shortcut and full complex roots (`x^4 + 1 = 0` included).
- **LSP**: go-to-definition for `define`/`defmacro` and document symbols.
- **CLI**: `lispium run --watch` (rerun on change) and `--time`;
  `lispium fmt -` formats stdin; `lispium completions bash|zsh|fish`;
  a man page (man/lispium.1).
- **REPL**: persistent history at ~/.lispium_history (history/!!/!n work
  across sessions).
- **Jupyter kernel**: `pip install lispium[jupyter]` then
  `python -m lispium.kernel install` — a persistent-REPL kernel.
- **VS Code**: "Lispium: Run Current File" command with an output panel.

### Fixed
- Latent use-after-free in the tail-call trampoline's frame bookkeeping.

## [0.7.0] - 2026-07-11

The language release: Lispium graduates from expression evaluator to a
small lisp with a serious CAS inside.

### Added
- **Exact rationals**: `1/3` literal syntax; exact `+ - * / ^ sqrt` with
  normalization and float contagion; `numer`/`denom`/`rational?`;
  `(+ 1/3 1/6)` => `1/2`. (i64-backed; overflow falls back to floats.)
- **Strings**: `"..."` literals with escapes; `concat`, `substring`,
  `split`, `string->number`, `number->string`, `length`.
- **quote/quasiquote**: `'x`, `` `x ``, `,x` reader sugar and special forms.
- **Macros**: `(defmacro (name params) template)` — params bind to
  unevaluated args; `unless`/`while` are writable as user macros.
- **Programs**: `begin`, `cond` (with `else`), short-circuit `and`/`or`,
  multi-expression bodies, `apply`, variadic lambdas `(x . rest)`,
  `try`/`error`/`assert`, type predicates (`number?` ... `complex?`),
  `print`/`read` interactive I/O, `load`, `(args)`, `(exit)`, shebang
  support, `random`/`random-seed`, `sort`, `assoc`.
- **Tail-call optimization**: tail recursion (through if/begin/cond,
  including mutual recursion) runs in constant stack space.
- **Units**: `(unit m)` etc. (20 SI/derived units) with full dimensional
  analysis through arithmetic; `100 km/h` => `27.78 m/s`; `m + s` errors.
- **CAS**: closed-form symbolic sums (Faulhaber + geometric), cubic
  equation solving (Cardano), n×n eigenvalues (3×3 exact via cubic, n≥4
  QR iteration), integration by u-substitution and more patterns.
- **Tooling**: `lispium test` runner for `*_test.lspm`; `lispium repl
  file.lspm` preloads a session; `lispium eval -` reads stdin; `(time
  expr)`; `(trace f)` call tracing; `_` holds the last REPL result.
- All 38 new builtins/forms documented in the shared docs table (hover,
  completion, `?func`); formatter understands strings, quote sugar, and
  the new special forms; cookbook/programs.lspm tours everything.

## [0.6.2] - 2026-07-10

### Changed
- `lispium fmt` now formats in place by default (like `zig fmt`); `--stdout`
  prints instead, `--check` unchanged, and no arguments means the current
  directory. `-w` is accepted as a no-op for compatibility.
- Builtin documentation unified into a single table (src/docs.zig) consumed
  by LSP hover, LSP completion (now with signatures), and REPL `?func` help:
  all 168 builtins plus special forms are documented (previously ~50).

### Fixed
- VS Code: `+ - * / ^ = < >` and names like `gf+`/`prime?` are now proper
  words (hover/double-click/completion ranges); grammar highlights
  `abs`/`floor`/`ceil`/`round`/`sign`/`evalf`.

## [0.6.1] - 2026-07-10

### Added
- `lispium fmt` accepts directories and recurses into their `.lspm` files
  (skipping hidden directories, `zig-out`, and `node_modules`), so
  `lispium fmt -w .` formats a whole project.

## [0.6.0] - 2026-07-10

### Added
- Canonical code style (STYLE.md) and `lispium fmt` formatter: 80-column,
  2-space indent, comment- and literal-preserving, idempotent. Flags:
  `-w` (in place), `--check` (CI).
- LSP `textDocument/formatting` so Helix `:format` and VS Code
  format-on-save use the same formatter.
- VS Code extension: format-on-save enabled by default for Lispium files,
  a "Restart Language Server" command, and a visible error when the server
  binary can't be found.
- Helix config ships with `auto-format = true`.
- Cookbook reformatted to canonical style (verified output-identical);
  CI enforces `fmt --check` on the cookbook.

## [0.5.1] - 2026-07-10

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