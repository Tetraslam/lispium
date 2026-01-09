# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
zig build run -- repl          # Run interactive REPL
zig build test --summary all   # Run all 319 tests with names
zig build -Doptimize=ReleaseSafe  # Build release binary
```

## Architecture

Lispium is a symbolic computer algebra system (CAS) in pure Zig with zero dependencies.

### Data Flow Pipeline

```
Input → Tokenizer → Parser → Evaluator + Environment → Builtins → Symbolic CAS → Output
```

### Core Expression Type (parser.zig)

The `Expr` tagged union is the fundamental data structure:
- `number`: f64 values
- `symbol`: variable names or function symbols (not owned)
- `owned_symbol`: dynamically allocated symbol strings (freed on deinit)
- `list`: S-expressions like `(+ 1 2 3)`
- `lambda`: user-defined functions

### Module Responsibilities

- **tokenizer.zig** - Splits input into tokens
- **parser.zig** - Recursive descent parser producing Expr trees
- **evaluator.zig** - Evaluates expressions in an environment context
- **environment.zig** - Symbol table with variables and builtin function pointers
- **builtins.zig** - 80+ operations: arithmetic, transcendental, calculus, algebra, complex numbers, matrices, vectors, combinatorics, number theory, statistics, quaternions, finite fields, LaTeX export
- **symbolic.zig** - Core CAS: simplify, diff, integrate, expand, solve, taylor, substitute
- **tests.zig** - Imports test modules from src/tests/
- **src/tests/*.zig** - 319 tests organized by feature: helpers.zig, basic.zig, simplify.zig, calculus.zig, etc.

## Memory Management Patterns

- Use `copyExpr()` from symbolic.zig to clone expression trees
- Builtins receive evaluated args but must copy any expressions they want to keep
- Input expressions are NOT consumed - callers can reuse after function returns
- Always use `errdefer` for cleanup on error paths
- MAX_RECURSION_DEPTH = 100 prevents stack overflow in simplify()
- Use `owned_symbol` variant for dynamically allocated strings that need freeing

## Adding New Features

1. **New builtin function**: Add to `builtins.zig` following the `BuiltinFn` signature, then register in `src/tests/helpers.zig` setupEnv()
2. **New symbolic rule**: Add cases in `symbolic.zig` simplify/diff/integrate functions
3. **Tests**: Create new test file in `src/tests/` and import it in `tests.zig`
4. **Handle owned_symbol**: When adding switch statements on Expr, include both `.symbol` and `.owned_symbol` cases

## Test Helpers

```zig
const expr = try parseExpr(allocator, "(+ x 1)");
defer freeExpr(allocator, expr);

var env = try setupEnv(allocator);
defer env.deinit();

var result = try evaluate(allocator, expr, &env);
defer result.deinit();

const str = try exprToString(allocator, result.value);
defer allocator.free(str);
```
