# CLAUDE.md

This file provides comprehensive guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Table of Contents

1. [Build Commands](#build-commands)
2. [Architecture Overview](#architecture-overview)
3. [Module Reference](#module-reference)
4. [Expression Types](#expression-types)
5. [Memory Management](#memory-management)
6. [Builtin Functions Reference](#builtin-functions-reference)
7. [Symbolic CAS Operations](#symbolic-cas-operations)
8. [Evaluator Special Forms](#evaluator-special-forms)
9. [Environment and Assumptions](#environment-and-assumptions)
10. [Test Organization](#test-organization)
11. [Adding New Features](#adding-new-features)
12. [Common Patterns](#common-patterns)
13. [Error Handling](#error-handling)
14. [REPL Features](#repl-features)

---

## Build Commands

```bash
zig build run -- repl          # Run interactive REPL
zig build test                 # Run all 453 tests
zig build test --summary all   # Run tests with verbose output showing names
zig build -Doptimize=ReleaseSafe  # Build optimized release binary
```

---

## Architecture Overview

Lispium is a symbolic computer algebra system (CAS) implemented in pure Zig with **zero external dependencies**. The codebase totals ~16,800 lines across all modules.

### Data Flow Pipeline

```
┌─────────┐    ┌───────────┐    ┌────────┐    ┌───────────┐    ┌──────────┐    ┌──────────┐
│  Input  │───>│ Tokenizer │───>│ Parser │───>│ Evaluator │───>│ Builtins │───>│  Output  │
│ (text)  │    │           │    │        │    │    +Env   │    │    or    │    │          │
└─────────┘    └───────────┘    └────────┘    └───────────┘    │ Symbolic │    └──────────┘
                                                               └──────────┘
```

### File Size Reference

| File | Lines | Description |
|------|-------|-------------|
| `builtins.zig` | 4,378 | 80+ builtin functions |
| `symbolic.zig` | 2,982 | Core CAS engine |
| `evaluator.zig` | 784 | Expression evaluator |
| `repl.zig` | 487 | Interactive shell |
| `environment.zig` | 123 | Symbol table & assumptions |
| `parser.zig` | 110 | Recursive descent parser |
| `tokenizer.zig` | 31 | Lexical scanner |
| `src/tests/*.zig` | ~10,000 | 453 tests organized by feature |

---

## Module Reference

### tokenizer.zig (31 lines)

Simple lexical scanner that splits input into tokens.

```zig
pub const Tokenizer = struct {
    input: []const u8,
    position: usize = 0,

    pub fn init(input: []const u8) Tokenizer;
    pub fn next(self: *Tokenizer) ?[]const u8;  // Returns next token or null
};
```

**Token rules:**
- `(` and `)` are individual tokens
- Everything else (separated by whitespace or parens) is a single token
- Numbers like `3.14`, `-2.5`, `1e10` are parsed later by the parser

### parser.zig (110 lines)

Recursive descent parser producing `Expr` AST nodes.

```zig
pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: std.ArrayList([]const u8),
    position: usize = 0,

    pub fn init(allocator: std.mem.Allocator, tokens: std.ArrayList([]const u8)) Parser;
    pub fn parseExpr(self: *Parser) !*Expr;  // Parse one expression
};

pub const Error = error{
    UnexpectedEOF,    // Missing closing paren or incomplete expression
    UnexpectedToken,  // Unexpected ')' without matching '('
};
```

**Parsing rules:**
- `(...)` becomes `Expr.list`
- Numbers (parsed via `std.fmt.parseFloat`) become `Expr.number`
- Everything else becomes `Expr.symbol`

### environment.zig (123 lines)

Symbol table storing variables, builtin functions, rewrite rules, and assumptions.

```zig
pub const Env = struct {
    allocator: std.mem.Allocator,
    variables: std.StringHashMap(*Expr),      // User-defined variables
    builtins: std.StringHashMap(BuiltinFn),   // Builtin function pointers
    rules: std.ArrayList(Rule),                // Pattern rewrite rules
    assumptions: std.StringHashMap(Assumption), // Symbol assumptions

    pub fn init(allocator: std.mem.Allocator) Env;
    pub fn deinit(self: *Env) void;
    pub fn get(self: *Env, key: []const u8) !*Expr;
    pub fn put(self: *Env, key: []const u8, val: *Expr) !void;
    pub fn getBuiltin(self: *Env, key: []const u8) !BuiltinFn;
    pub fn putBuiltin(self: *Env, key: []const u8, fn_ptr: BuiltinFn) !void;
    pub fn assume(self: *Env, symbol: []const u8, assumption: Assumption) !void;
    pub fn getAssumption(self: *Env, symbol: []const u8) ?Assumption;
    pub fn isPositive(self: *Env, symbol: []const u8) bool;
    pub fn isInteger(self: *Env, symbol: []const u8) bool;
    pub fn isNonzero(self: *Env, symbol: []const u8) bool;
};

pub const Rule = struct {
    pattern: *Expr,      // Pattern with ?variables
    replacement: *Expr,  // Replacement template
};

pub const Assumption = packed struct {
    positive: bool = false,
    negative: bool = false,
    nonzero: bool = false,
    integer: bool = false,
    real: bool = false,
    even: bool = false,
    odd: bool = false,
    _padding: u1 = 0,
};
```

### evaluator.zig (784 lines)

Expression evaluator with special form handling.

```zig
pub const Error = error{
    UnsupportedOperator,
    OutOfMemory,
    InvalidLambda,
    InvalidDefine,
    WrongNumberOfArguments,
} || BuiltinError || EnvError || symbolic.SimplifyError;

pub fn eval(expr: *Expr, env: *Env) Error!*Expr;
```

**Evaluation order:**
1. Numbers → copy and return
2. Symbols → lookup in env or return as symbolic
3. `owned_symbol` → same as symbol
4. Lambdas → copy and return
5. Lists → check special forms first, then evaluate operator and call

### builtins.zig (4,378 lines)

All builtin function implementations. See [Builtin Functions Reference](#builtin-functions-reference).

```zig
pub const BuiltinError = error{
    InvalidArgument,
    OutOfMemory,
};

pub const BuiltinFn = *const fn (args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr;
```

### symbolic.zig (2,982 lines)

Core computer algebra system. See [Symbolic CAS Operations](#symbolic-cas-operations).

```zig
pub const SimplifyError = error{
    OutOfMemory,
    RecursionLimit,
};

const MAX_RECURSION_DEPTH = 100;
```

### repl.zig (487 lines)

Interactive read-eval-print loop with pretty printing.

**REPL Commands:**
- `help` or `?` - Show help text
- `quit` or `exit` - Exit REPL
- Ctrl+D - Exit REPL

**Pretty printing features:**
- Greek letters: `pi` → π, `inf` → ∞
- Superscripts: `x^2` → x², `x^3` → x³
- Vectors: `(vector 1 2 3)` → ⟨1, 2, 3⟩
- Matrices: Row-based display with `[a b; c d]` notation
- Complex: `(complex 3 4)` → `3 + 4i`
- Solutions: `(solutions 2 -2)` → `{2, -2}`
- Infix operators with `·` for multiplication

---

## Expression Types

The `Expr` tagged union is the fundamental data structure:

```zig
pub const Expr = union(enum) {
    number: f64,                        // Numeric literals
    symbol: []const u8,                 // Variable/function names (NOT owned)
    owned_symbol: []const u8,           // Dynamically allocated strings (owned, freed on deinit)
    list: std.ArrayList(*Expr),         // S-expressions: (op arg1 arg2 ...)
    lambda: Lambda,                     // User-defined functions

    pub const Lambda = struct {
        params: std.ArrayList([]const u8),  // Parameter names
        body: *Expr,                         // Function body
    };

    pub fn deinit(self: *Expr, allocator: std.mem.Allocator) void;
};
```

### When to use each type

| Type | Use Case | Memory |
|------|----------|--------|
| `number` | Numeric values | No cleanup needed |
| `symbol` | References to input tokens or static strings | NOT freed on deinit |
| `owned_symbol` | Dynamically created strings (e.g., LaTeX output) | Freed on deinit |
| `list` | All compound expressions | Recursively frees children |
| `lambda` | User-defined functions from `lambda` or `define` | Frees params list and body |

### Expression patterns by operation

| Pattern | Meaning | Example |
|---------|---------|---------|
| `(+ a b c ...)` | Addition | `(+ 1 2 3)` → 6 |
| `(- a b)` | Subtraction | `(- 5 3)` → 2 |
| `(* a b c ...)` | Multiplication | `(* 2 3 4)` → 24 |
| `(/ a b)` | Division | `(/ 10 2)` → 5 |
| `(^ base exp)` | Power | `(^ 2 10)` → 1024 |
| `(sin x)` | Trig function | Symbolic or numeric |
| `(complex re im)` | Complex number | `(complex 3 4)` |
| `(vector x y z)` | Vector | `(vector 1 2 3)` |
| `(matrix (r1) (r2))` | Matrix | `(matrix (1 2) (3 4))` |
| `(solutions v1 v2 ...)` | Solution set | Result of `solve` |
| `(quat w x y z)` | Quaternion | `(quat 1 2 3 4)` |
| `(gf value prime)` | Finite field element | `(gf 3 7)` |
| `(factors (p e) ...)` | Prime factorization | `(factors (2 2) (3 1))` |

---

## Memory Management

### Core Principles

1. **Allocator threading**: All functions receive or have access to an allocator
2. **Ownership**: Callers own expressions they create; builtins must copy what they keep
3. **No consumption**: Input expressions are never consumed; they can be reused
4. **Deep copying**: Use `symbolic.copyExpr()` for full tree clones
5. **Error cleanup**: Always use `errdefer` for allocations that might need cleanup

### Key Functions

```zig
// Deep copy an expression tree
pub fn copyExpr(expr: *const Expr, allocator: std.mem.Allocator) SimplifyError!*Expr;

// Create binary operation expression
pub fn makeBinOp(allocator: std.mem.Allocator, op: []const u8, left: *Expr, right: *Expr) SimplifyError!*Expr;
```

### Memory patterns in builtins

```zig
pub fn builtin_example(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    // Args are owned by evaluator - DO NOT free them
    // But you must COPY any args you want to keep in your result

    // Create new expression
    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    errdefer env.allocator.destroy(result);

    // If building a list, copy args
    var list: std.ArrayList(*Expr) = .empty;
    errdefer {
        for (list.items) |item| {
            item.deinit(env.allocator);
            env.allocator.destroy(item);
        }
        list.deinit(env.allocator);
    }

    // Copy expression from args
    const arg_copy = symbolic.copyExpr(args.items[0], env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, arg_copy) catch return BuiltinError.OutOfMemory;

    result.* = .{ .list = list };
    return result;
}
```

### owned_symbol usage

Use `owned_symbol` when creating dynamically allocated strings:

```zig
// In builtin_latex:
const latex_str = buf.toOwnedSlice(env.allocator) catch return BuiltinError.OutOfMemory;
const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
result.* = .{ .owned_symbol = latex_str };  // Will be freed on deinit
return result;
```

### Common memory mistakes to avoid

1. **Don't free args**: Evaluator owns them, will free after builtin returns
2. **Don't return references to args**: Always copy
3. **Don't forget errdefer**: Every allocation needs cleanup on error path
4. **Don't mix symbol/owned_symbol**: Use `symbol` for static strings, `owned_symbol` for dynamic

---

## Builtin Functions Reference

### Arithmetic (5 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `+` | `(+ a b c ...)` | Addition (variadic) |
| `-` | `(- a b ...)` | Subtraction |
| `*` | `(* a b c ...)` | Multiplication (variadic) |
| `/` | `(/ a b)` | Division |
| `^` / `pow` | `(^ base exp)` | Exponentiation |

### Comparison (3 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `=` | `(= a b)` | Equality (returns 1 or 0) |
| `<` | `(< a b)` | Less than |
| `>` | `(> a b)` | Greater than |

### Boolean Logic (5 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `and` | `(and a b ...)` | Logical AND (variadic) |
| `or` | `(or a b ...)` | Logical OR (variadic) |
| `not` | `(not a)` | Logical NOT |
| `xor` | `(xor a b)` | Exclusive OR |
| `implies` | `(implies a b)` | Logical implication |

### Modular Arithmetic (4 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `mod` | `(mod a b)` | Modulo |
| `gcd` | `(gcd a b)` | Greatest common divisor |
| `lcm` | `(lcm a b)` | Least common multiple |
| `modpow` | `(modpow base exp mod)` | Modular exponentiation |

### Transcendental Functions (7 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `sin` | `(sin x)` | Sine |
| `cos` | `(cos x)` | Cosine |
| `tan` | `(tan x)` | Tangent |
| `exp` | `(exp x)` | Exponential (e^x) |
| `ln` | `(ln x)` | Natural logarithm |
| `log` | `(log x)` or `(log x base)` | Logarithm (default base e) |
| `sqrt` | `(sqrt x)` | Square root (returns `(^ x 0.5)`) |

### Inverse Trigonometric Functions (4 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `asin` | `(asin x)` | Arc sine |
| `acos` | `(acos x)` | Arc cosine |
| `atan` | `(atan x)` | Arc tangent |
| `atan2` | `(atan2 y x)` | Two-argument arc tangent |

### Hyperbolic Functions (6 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `sinh` | `(sinh x)` | Hyperbolic sine |
| `cosh` | `(cosh x)` | Hyperbolic cosine |
| `tanh` | `(tanh x)` | Hyperbolic tangent |
| `asinh` | `(asinh x)` | Inverse hyperbolic sine |
| `acosh` | `(acosh x)` | Inverse hyperbolic cosine |
| `atanh` | `(atanh x)` | Inverse hyperbolic tangent |

### Special Functions (6 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `gamma` | `(gamma x)` | Gamma function Γ(x) |
| `beta` | `(beta a b)` | Beta function B(a,b) |
| `besselj` | `(besselj n x)` | Bessel function of first kind J_n(x) |
| `bessely` | `(bessely n x)` | Bessel function of second kind Y_n(x) |
| `erf` | `(erf x)` | Error function |
| `erfc` | `(erfc x)` | Complementary error function |
| `digamma` | `(digamma x)` | Digamma function ψ(x) |

### Calculus (5 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `diff` | `(diff expr var)` or `(diff expr var n)` | Differentiation (nth derivative) |
| `integrate` | `(integrate expr var)` or `(integrate expr var a b)` | Integration (indefinite or definite) |
| `taylor` | `(taylor expr var point order)` | Taylor series expansion |
| `limit` | `(limit expr var point)` | Limit with L'Hôpital's rule |
| `substitute` | `(substitute expr var value)` | Variable substitution |

### Algebra (6 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `simplify` | `(simplify expr)` | Algebraic simplification |
| `expand` | `(expand expr)` | Expand products |
| `solve` | `(solve expr var)` | Solve equation (linear/quadratic) |
| `factor` | `(factor expr var)` | Factor polynomial |
| `partial-fractions` | `(partial-fractions expr var)` | Partial fraction decomposition |
| `collect` | `(collect expr var)` | Collect like terms |

### Complex Numbers (6 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `complex` | `(complex re im)` | Create complex number |
| `real` | `(real z)` | Real part |
| `imag` | `(imag z)` | Imaginary part |
| `conj` | `(conj z)` | Complex conjugate |
| `magnitude` | `(magnitude z)` | Absolute value |
| `arg` | `(arg z)` | Argument (angle) |

### Matrices (11 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `matrix` | `(matrix (r1) (r2) ...)` | Create matrix |
| `det` | `(det M)` | Determinant |
| `transpose` | `(transpose M)` | Transpose |
| `trace` | `(trace M)` | Trace (sum of diagonal) |
| `matmul` | `(matmul A B)` | Matrix multiplication |
| `inv` | `(inv M)` | Matrix inverse |
| `eigenvalues` | `(eigenvalues M)` | Eigenvalues (2x2 only) |
| `eigenvectors` | `(eigenvectors M)` | Eigenvectors (2x2 only) |
| `lu` | `(lu M)` | LU decomposition |
| `charpoly` | `(charpoly M var)` | Characteristic polynomial |
| `linsolve` | `(linsolve A b)` | Solve linear system Ax=b |

### Vectors (4 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `vector` | `(vector x y z ...)` | Create vector |
| `dot` | `(dot v1 v2)` | Dot product |
| `cross` | `(cross v1 v2)` | Cross product (3D only) |
| `norm` | `(norm v)` | Euclidean norm |

### Vector Calculus (4 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `gradient` / `grad` | `(gradient f vars)` | Gradient of scalar field |
| `divergence` | `(divergence F vars)` | Divergence of vector field |
| `curl` | `(curl F vars)` | Curl of vector field (3D) |
| `laplacian` | `(laplacian f vars)` | Laplacian of scalar field |

### Combinatorics (4 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `factorial` / `!` | `(factorial n)` or `(! n)` | Factorial |
| `binomial` / `choose` | `(binomial n k)` | Binomial coefficient |
| `permutations` | `(permutations n r)` | P(n,r) |
| `combinations` | `(combinations n r)` | C(n,r) |

### Number Theory (5 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `prime?` | `(prime? n)` | Primality test |
| `factorize` | `(factorize n)` | Prime factorization |
| `extgcd` | `(extgcd a b)` | Extended GCD (Bezout coefficients) |
| `totient` | `(totient n)` | Euler's totient function |
| `crt` | `(crt (r1 m1) (r2 m2) ...)` | Chinese Remainder Theorem |

### Statistics (6 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `mean` | `(mean x1 x2 ...)` | Arithmetic mean |
| `variance` | `(variance x1 x2 ...)` | Population variance |
| `stddev` | `(stddev x1 x2 ...)` | Standard deviation |
| `median` | `(median x1 x2 ...)` | Median |
| `min` | `(min x1 x2 ...)` | Minimum |
| `max` | `(max x1 x2 ...)` | Maximum |

### Polynomial Operations (6 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `coeffs` | `(coeffs a b c ...)` | Create coefficient list |
| `polydiv` | `(polydiv p1 p2 var)` | Polynomial division |
| `polygcd` | `(polygcd p1 p2)` | Polynomial GCD |
| `polylcm` | `(polylcm p1 p2)` | Polynomial LCM |
| `roots` | `(roots expr var)` | Find polynomial roots |
| `discriminant` | `(discriminant expr var)` | Discriminant |

### Quaternions (8 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `quat` | `(quat w x y z)` | Create quaternion w + xi + yj + zk |
| `quat+` | `(quat+ q1 q2)` | Quaternion addition |
| `quat*` | `(quat* q1 q2)` | Hamilton product |
| `quat-conj` | `(quat-conj q)` | Conjugate |
| `quat-norm` | `(quat-norm q)` | Norm (magnitude) |
| `quat-inv` | `(quat-inv q)` | Multiplicative inverse |
| `quat-scalar` | `(quat-scalar q)` | Scalar part (w) |
| `quat-vector` | `(quat-vector q)` | Vector part (x, y, z) |

### Finite Fields GF(p) (8 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `gf` | `(gf value prime)` | Create element in GF(p) |
| `gf+` | `(gf+ a b)` | Addition in GF(p) |
| `gf-` | `(gf- a b)` | Subtraction in GF(p) |
| `gf*` | `(gf* a b)` | Multiplication in GF(p) |
| `gf/` | `(gf/ a b)` | Division in GF(p) |
| `gf^` | `(gf^ a n)` | Exponentiation in GF(p) |
| `gf-inv` | `(gf-inv a)` | Multiplicative inverse |
| `gf-neg` | `(gf-neg a)` | Negation |

### Pattern Rewriting (2 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `rule` | `(rule pattern replacement)` | Define rewrite rule |
| `rewrite` | `(rewrite expr)` | Apply all defined rules |

**Pattern variables** start with `?` (e.g., `?x`, `?y`):
```lisp
(rule (double ?x) (* 2 ?x))
(rewrite (double 5))  ; => (* 2 5)
```

### Assumptions (2 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `assume` | `(assume var property)` | Set assumption |
| `is?` | `(is? var property)` | Check assumption |

**Properties**: `positive`, `negative`, `nonzero`, `integer`, `real`, `even`, `odd`

### Export (1 function)

| Function | Signature | Description |
|----------|-----------|-------------|
| `latex` | `(latex expr)` | Convert to LaTeX string |

### Differential Equations (1 function)

| Function | Signature | Description |
|----------|-----------|-------------|
| `dsolve` | `(dsolve eqn y x)` | Solve first-order ODE |

### Fourier & Laplace Transforms (3 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `fourier` | `(fourier expr x n)` | Fourier series expansion |
| `laplace` | `(laplace expr t s)` | Laplace transform |
| `inv-laplace` | `(inv-laplace expr s t)` | Inverse Laplace transform |

### Tensor Operations (4 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `tensor` | `(tensor data)` | Create tensor |
| `tensor-rank` | `(tensor-rank T)` | Get tensor rank |
| `tensor-contract` | `(tensor-contract T i j)` | Contract indices |
| `tensor-product` | `(tensor-product T1 T2)` | Outer product |

### Polynomial Interpolation (2 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `lagrange` | `(lagrange points var)` | Lagrange interpolation |
| `newton-interp` | `(newton-interp points var)` | Newton interpolation |

### Numerical Root Finding (2 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `newton-raphson` | `(newton-raphson expr var x0 tol)` | Newton-Raphson method |
| `bisection` | `(bisection expr var a b tol)` | Bisection method |

### Continued Fractions (4 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `to-cf` | `(to-cf x)` | Convert to continued fraction |
| `from-cf` | `(from-cf cf)` | Convert from continued fraction |
| `cf-rational` | `(cf-rational p q)` | CF from rational p/q |
| `cf-convergent` | `(cf-convergent cf n)` | Get nth convergent |

### List Operations (12 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `car` | `(car lst)` | First element |
| `cdr` | `(cdr lst)` | Rest of list |
| `cons` | `(cons x lst)` | Prepend element |
| `list` | `(list a b c ...)` | Create list |
| `length` | `(length lst)` | List length |
| `nth` | `(nth lst n)` | Get nth element |
| `map` | `(map fn lst)` | Map function over list |
| `filter` | `(filter fn lst)` | Filter list by predicate |
| `reduce` | `(reduce fn init lst)` | Reduce list |
| `append` | `(append lst1 lst2)` | Concatenate lists |
| `reverse` | `(reverse lst)` | Reverse list |
| `range` | `(range n)` or `(range start end)` or `(range start end step)` | Generate range |

### Memoization (3 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `memoize` | `(memoize expr)` | Cache expression result |
| `memo-clear` | `(memo-clear)` | Clear memoization cache |
| `memo-stats` | `(memo-stats)` | Get cache size |

### Plotting (3 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `plot-ascii` | `(plot-ascii expr xmin xmax)` or `(plot-ascii expr xmin xmax height width)` | ASCII plot |
| `plot-svg` | `(plot-svg expr xmin xmax)` or `(plot-svg expr xmin xmax height width)` | SVG plot |
| `plot-points` | `(plot-points points)` | Plot discrete points |

### Step-by-Step Solutions (4 functions)

| Function | Signature | Description |
|----------|-----------|-------------|
| `diff-steps` | `(diff-steps expr var)` | Differentiation with steps |
| `integrate-steps` | `(integrate-steps expr var)` | Integration with steps |
| `simplify-steps` | `(simplify-steps expr)` | Simplification with steps |
| `solve-steps` | `(solve-steps expr var)` | Equation solving with steps |

---

## Symbolic CAS Operations

Located in `symbolic.zig` (2,982 lines).

### Core Functions

```zig
// Compare expressions for structural equality
pub fn exprEqual(a: *const Expr, b: *const Expr) bool;

// Deep copy an expression tree
pub fn copyExpr(expr: *const Expr, allocator: std.mem.Allocator) SimplifyError!*Expr;

// Create binary operation
pub fn makeBinOp(allocator: std.mem.Allocator, op: []const u8, left: *Expr, right: *Expr) SimplifyError!*Expr;
```

### Simplification Engine

```zig
pub fn simplify(expr: *const Expr, allocator: std.mem.Allocator) SimplifyError!*Expr;
```

**Simplification rules applied:**
- Constant folding: `(+ 1 2)` → `3`
- Identity elimination: `(+ x 0)` → `x`, `(* x 1)` → `x`
- Zero multiplication: `(* x 0)` → `0`
- Power rules: `(^ x 0)` → `1`, `(^ x 1)` → `x`
- Trig identities: `(sin 0)` → `0`, `(cos 0)` → `1`
- Log/exp identities: `(exp 0)` → `1`, `(ln 1)` → `0`, `(ln (exp x))` → `x`
- Double negation: `(- (- x))` → `x`
- Like term collection: `(+ x x)` → `(* 2 x)`
- Nested operations flattening

### Differentiation

```zig
pub fn diff(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr;
```

**Supported differentiation rules:**
- Constants: `d/dx(c)` = 0
- Variables: `d/dx(x)` = 1, `d/dx(y)` = 0
- Sum rule: `d/dx(a + b)` = `da/dx + db/dx`
- Product rule: `d/dx(a * b)` = `a * db/dx + da/dx * b`
- Quotient rule: `d/dx(a / b)` = `(b * da/dx - a * db/dx) / b²`
- Power rule: `d/dx(x^n)` = `n * x^(n-1)`
- Chain rule for: `sin`, `cos`, `tan`, `exp`, `ln`, `sqrt`

### Integration

```zig
pub fn integrate(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr;
```

**Supported integrals:**
- Constants: `∫c dx` = `cx`
- Variables: `∫x dx` = `x²/2`
- Powers: `∫x^n dx` = `x^(n+1)/(n+1)` (n ≠ -1)
- Reciprocal: `∫1/x dx` = `ln(x)`
- Exponentials: `∫e^x dx` = `e^x`
- Trig: `∫sin(x) dx` = `-cos(x)`, `∫cos(x) dx` = `sin(x)`
- Sum rule: `∫(a + b) dx` = `∫a dx + ∫b dx`
- Constant multiple: `∫c*f dx` = `c*∫f dx`

### Taylor Series

```zig
pub fn taylor(expr: *const Expr, var_name: []const u8, point: f64, order: usize, allocator: std.mem.Allocator) SimplifyError!*Expr;
```

Computes Taylor series: `f(a) + f'(a)(x-a) + f''(a)(x-a)²/2! + ...`

### Equation Solving

```zig
pub fn solve(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr;
```

**Supported equations:**
- Linear: `ax + b = 0` → `x = -b/a`
- Quadratic: `ax² + bx + c = 0` → quadratic formula (includes complex roots)

### Polynomial Operations

```zig
pub fn factor(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr;
pub fn collect(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr;
pub fn partialFractions(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError!*Expr;
pub fn getCoefficients(expr: *const Expr, var_name: []const u8, allocator: std.mem.Allocator) SimplifyError![]*Expr;
```

### Complex Number Operations

```zig
pub fn makeComplex(allocator: std.mem.Allocator, real: f64, imag: f64) SimplifyError!*Expr;
pub fn isComplex(expr: *const Expr) bool;
pub fn getReal(expr: *const Expr) ?f64;
pub fn getImag(expr: *const Expr) ?f64;
pub fn complexAdd(a_real: f64, a_imag: f64, b_real: f64, b_imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr;
pub fn complexSub(a_real: f64, a_imag: f64, b_real: f64, b_imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr;
pub fn complexMul(a_real: f64, a_imag: f64, b_real: f64, b_imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr;
pub fn complexDiv(a_real: f64, a_imag: f64, b_real: f64, b_imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr;
pub fn complexSqrt(real: f64, imag: f64, allocator: std.mem.Allocator) SimplifyError!*Expr;
```

### Pattern Matching

```zig
pub fn isPatternVar(s: []const u8) bool;  // Checks if starts with '?'
pub fn matchPattern(pattern: *const Expr, expr: *const Expr, allocator: std.mem.Allocator) SimplifyError!?std.StringHashMap(*Expr);
pub fn applyBindings(replacement: *const Expr, bindings: *std.StringHashMap(*Expr), allocator: std.mem.Allocator) SimplifyError!*Expr;
pub fn applyRules(expr: *const Expr, rules: []const Rule, allocator: std.mem.Allocator) SimplifyError!?*Expr;
```

---

## Evaluator Special Forms

These are handled specially by the evaluator (not as builtins):

### lambda

```lisp
(lambda (params...) body)
```

Creates a function closure. Parameters are not evaluated.

```lisp
((lambda (x) (* x x)) 5)  ; => 25
```

### define

```lisp
(define name value)              ; Simple binding
(define (name params...) body)   ; Function definition
```

Binds a value or function to a name in the environment.

```lisp
(define pi 3.14159)
(define (square x) (* x x))
(square 7)  ; => 49
```

### if

```lisp
(if condition then-expr)
(if condition then-expr else-expr)
```

Conditional evaluation. Truthy: non-zero numbers, symbols, non-empty lists, lambdas.

```lisp
(if (> x 0) x (- x))  ; absolute value
```

### let

```lisp
(let ((var1 val1) (var2 val2) ...) body)
```

Local bindings with lexical scope.

```lisp
(let ((a 3) (b 4)) (+ a b))  ; => 7
```

### letrec

```lisp
(letrec ((var1 val1) ...) body)
```

Recursive bindings - allows functions to call themselves.

```lisp
(letrec ((fact (lambda (n)
  (if (= n 0) 1 (* n (fact (- n 1)))))))
  (fact 5))  ; => 120
```

### matrix

```lisp
(matrix (row1...) (row2...) ...)
```

Special form that doesn't evaluate row contents, allowing symbolic matrices.

```lisp
(matrix (a b) (c d))  ; Symbolic 2x2 matrix
```

### sum

```lisp
(sum var start end body)
```

Summation notation. Evaluates `body` for each integer value of `var` from `start` to `end`.

```lisp
(sum i 1 5 i)        ; => 15 (1+2+3+4+5)
(sum i 1 5 (* i i))  ; => 55 (sum of squares)
(sum i 1 n i)        ; Symbolic if bounds not numeric
```

### product

```lisp
(product var start end body)
```

Product notation.

```lisp
(product i 1 5 i)  ; => 120 (5!)
```

---

## Environment and Assumptions

### Setting Assumptions

```lisp
(assume x positive)
(assume n integer)
(assume y nonzero)
```

### Checking Assumptions

```lisp
(is? x positive)  ; => 1 if true, 0 if false
```

### How Assumptions Affect Simplification

Assumptions can enable additional simplifications:
- `positive` variables: allows `sqrt(x²) = x`
- `integer` variables: may affect certain reductions
- `nonzero` variables: allows division simplifications

---

## Test Organization

Tests are organized in `src/tests/` with 453 tests across 37 files:

| File | Tests | Coverage |
|------|-------|----------|
| `parser.zig` | Parsing S-expressions |
| `arithmetic.zig` | +, -, *, /, ^ operations |
| `simplify.zig` | Simplification rules |
| `calculus.zig` | diff, integrate, taylor, limit |
| `algebra.zig` | solve, expand, substitute |
| `complex.zig` | Complex number operations |
| `lambda.zig` | Lambda, define, let, letrec |
| `rewrite.zig` | Pattern matching rules |
| `identities.zig` | Trig/log identities |
| `matrix.zig` | Matrix operations |
| `series.zig` | Sum, product notation |
| `vector.zig` | Vector operations |
| `factor.zig` | Polynomial factoring |
| `partial_fractions.zig` | Partial fraction decomposition |
| `collect.zig` | Term collection |
| `modular.zig` | Modular arithmetic |
| `boolean.zig` | Boolean logic |
| `polynomial.zig` | Polynomial tools |
| `assumptions.zig` | Assumption system |
| `combinatorics.zig` | Factorial, binomial, etc. |
| `vector_calculus.zig` | Gradient, divergence, curl |
| `statistics.zig` | Mean, variance, etc. |
| `quaternion.zig` | Quaternion operations |
| `finite_field.zig` | GF(p) arithmetic |
| `latex.zig` | LaTeX export |
| `trig_hyperbolic.zig` | Inverse trig & hyperbolic functions |
| `special_functions.zig` | Gamma, beta, Bessel, erf |
| `dsolve.zig` | Differential equation solver |
| `fourier_laplace.zig` | Fourier series & Laplace transforms |
| `tensor.zig` | Tensor operations |
| `interpolation.zig` | Lagrange & Newton interpolation |
| `rootfinding.zig` | Newton-Raphson & bisection |
| `continued_fractions.zig` | Continued fraction operations |
| `list_ops.zig` | List operations (car, cdr, map, etc.) |
| `memoization.zig` | Memoization functions |
| `plotting.zig` | ASCII & SVG plotting |
| `steps.zig` | Step-by-step solution display |

### Test Helpers (helpers.zig)

```zig
const h = @import("helpers.zig");

// Parse expression from string
pub fn parseExpr(allocator: std.mem.Allocator, input: []const u8) !*Expr;

// Convert expression to string
pub fn exprToString(allocator: std.mem.Allocator, expr: *const Expr) ![]u8;

// Print expression (for debugging)
pub fn writeExpr(expr: *const Expr, writer: anytype) !void;

// Set up environment with all builtins
pub fn setupEnv(allocator: std.mem.Allocator) !Env;

// Re-exports
pub const Expr = @import("../parser.zig").Expr;
pub const eval = @import("../evaluator.zig").eval;
pub const Env = @import("../environment.zig").Env;
pub const builtins = @import("../builtins.zig");
pub const symbolic = @import("../symbolic.zig");
```

### Standard Test Pattern

```zig
test "feature: description" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(+ 1 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    // For numeric results
    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, 3), result.number);

    // For string comparison
    const str = try h.exprToString(allocator, result);
    defer allocator.free(str);
    try testing.expectEqualStrings("expected", str);

    // For owned_symbol results (e.g., latex)
    try testing.expect(result.* == .owned_symbol);
    try testing.expectEqualStrings("expected", result.owned_symbol);
}
```

---

## Adding New Features

### 1. Adding a New Builtin Function

**Step 1**: Add to `builtins.zig`:

```zig
pub fn builtin_myfunction(args: std.ArrayList(*Expr), env: *Env) BuiltinError!*Expr {
    if (args.items.len != 2) return BuiltinError.InvalidArgument;

    // Handle numeric case
    if (args.items[0].* == .number and args.items[1].* == .number) {
        const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
        result.* = .{ .number = compute(args.items[0].number, args.items[1].number) };
        return result;
    }

    // Handle symbolic case - copy args
    var list: std.ArrayList(*Expr) = .empty;
    const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    op.* = .{ .symbol = "myfunction" };
    list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;

    for (args.items) |arg| {
        const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
        list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
    }

    const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
    result.* = .{ .list = list };
    return result;
}
```

**Step 2**: Register in `src/tests/helpers.zig` setupEnv():

```zig
try env.putBuiltin("myfunction", builtins.builtin_myfunction);
```

**Step 3**: Register in `src/repl.zig` run():

```zig
try env.putBuiltin("myfunction", builtins.builtin_myfunction);
```

### 2. Adding Symbolic Rules

Add cases in `symbolic.zig`:

**For simplification** (in `simplifyInternal`):
```zig
if (std.mem.eql(u8, op, "myfunction")) {
    // Apply simplification rules
}
```

**For differentiation** (in `diffInternal`):
```zig
if (std.mem.eql(u8, op, "myfunction")) {
    // Return derivative
}
```

**For integration** (in `integrateInternal`):
```zig
if (std.mem.eql(u8, op, "myfunction")) {
    // Return integral
}
```

### 3. Adding Tests

**Step 1**: Create `src/tests/myfeature.zig`:

```zig
const std = @import("std");
const testing = std.testing;
const h = @import("helpers.zig");

test "myfeature: basic test" {
    const allocator = testing.allocator;
    var env = try h.setupEnv(allocator);
    defer env.deinit();

    const expr = try h.parseExpr(allocator, "(myfunction 1 2)");
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    const result = try h.eval(expr, &env);
    defer {
        result.deinit(allocator);
        allocator.destroy(result);
    }

    try testing.expect(result.* == .number);
    try testing.expectEqual(@as(f64, expected), result.number);
}
```

**Step 2**: Import in `src/tests.zig`:

```zig
comptime {
    // ... existing imports ...
    _ = @import("tests/myfeature.zig");
}
```

### 4. Handling owned_symbol

When adding switch statements on `Expr`, always handle both symbol types:

```zig
switch (expr.*) {
    .number => |n| { ... },
    .symbol, .owned_symbol => |s| { ... },  // Handle both!
    .list => |lst| { ... },
    .lambda => |lam| { ... },
}
```

---

## Common Patterns

### Creating a numeric result

```zig
const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
result.* = .{ .number = value };
return result;
```

### Creating a symbolic expression

```zig
var list: std.ArrayList(*Expr) = .empty;
errdefer { /* cleanup */ }

const op = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
op.* = .{ .symbol = "myop" };
list.append(env.allocator, op) catch return BuiltinError.OutOfMemory;

// Add arguments (must copy!)
for (args.items) |arg| {
    const copy = symbolic.copyExpr(arg, env.allocator) catch return BuiltinError.OutOfMemory;
    list.append(env.allocator, copy) catch return BuiltinError.OutOfMemory;
}

const result = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;
result.* = .{ .list = list };
return result;
```

### Checking expression type in a list

```zig
if (expr.* == .list and expr.list.items.len > 0) {
    if (expr.list.items[0].* == .symbol) {
        const op = expr.list.items[0].symbol;
        if (std.mem.eql(u8, op, "myop")) {
            // Handle this case
        }
    }
}
```

### Extracting a symbol name

```zig
const name = switch (expr.*) {
    .symbol => |s| s,
    .owned_symbol => |s| s,
    else => return error.InvalidArgument,
};
```

### Recursive expression processing

```zig
fn processExpr(expr: *const Expr, allocator: std.mem.Allocator) !*Expr {
    switch (expr.*) {
        .number, .symbol, .owned_symbol => return try symbolic.copyExpr(expr, allocator),
        .lambda => return try symbolic.copyExpr(expr, allocator),
        .list => |lst| {
            var new_list: std.ArrayList(*Expr) = .empty;
            errdefer { /* cleanup */ }

            for (lst.items) |item| {
                const processed = try processExpr(item, allocator);
                try new_list.append(allocator, processed);
            }

            const result = try allocator.create(Expr);
            result.* = .{ .list = new_list };
            return result;
        },
    }
}
```

---

## Error Handling

### Error Types

```zig
// Parser errors
pub const Error = error{
    UnexpectedEOF,
    UnexpectedToken,
};

// Builtin errors
pub const BuiltinError = error{
    InvalidArgument,
    OutOfMemory,
    EvaluationError,
};

// Symbolic CAS errors
pub const SimplifyError = error{
    OutOfMemory,
    RecursionLimit,
};

// Evaluator errors (union of above plus)
pub const Error = error{
    UnsupportedOperator,
    InvalidLambda,
    InvalidDefine,
    WrongNumberOfArguments,
} || BuiltinError || EnvError || SimplifyError;

// Environment errors
pub const Error = error{
    KeyNotFound,
};
```

### Error handling pattern

```zig
// In builtins - convert allocation errors
const expr = env.allocator.create(Expr) catch return BuiltinError.OutOfMemory;

// In symbolic - propagate with try
const result = try allocator.create(Expr);

// In evaluator - full error union
const result = try eval(expr, env);
```

---

## REPL Features

### Pretty Printing

The REPL uses Unicode for cleaner output:
- Greek: π, ∞
- Superscripts: ², ³
- Vectors: ⟨x, y, z⟩
- Multiplication: · (middle dot)
- Complex: a + bi notation
- Solutions: {x₁, x₂} set notation

### Validation

Before printing, expressions are validated to detect:
- Invalid pointers
- Cyclic references
- Excessive recursion depth (MAX_VALIDATION_DEPTH = 1000)

---

## Cookbook Examples

The `cookbook/` directory contains example programs:

| File | Topics |
|------|--------|
| `README.lspm` | Quick start examples and reference |
| `algebra.lspm` | Solve, expand, factor |
| `assumptions.lspm` | Working with assumptions |
| `boolean.lspm` | Boolean logic operations |
| `calculus.lspm` | Differentiation, integration |
| `complex.lspm` | Complex number arithmetic |
| `lambda.lspm` | Functions, recursion |
| `linear_algebra.lspm` | Matrices, determinants |
| `number_theory.lspm` | Primes, factorization |
| `polynomials.lspm` | Polynomial operations |
| `advanced.lspm` | Special functions, transforms, interpolation, tensors |
| `plotting.lspm` | ASCII/SVG plotting, step-by-step solutions |

---

## TODOs / Roadmap

### High Priority

#### File Extension
- [x] Rename `.lisp` files to `.lspm` (Lispium-specific extension)

#### REPL Improvements
- [x] Tab completion for builtin function names (`complete <partial>` command)
- [x] Multiline editing (continue expression on next line if parens unbalanced)
- [x] `?function` syntax for inline help/documentation

#### Package Distribution (First-Class Support)
Target platforms: **Windows**, **Linux**, **macOS**

| Platform | Method | Priority |
|----------|--------|----------|
| All | GitHub Releases (direct binaries) | High |
| All | PyPI / uv (`pip install lispium`) | High |
| macOS | Homebrew tap | High |
| Windows | winget | High |
| Linux | AUR (Arch User Repository) | High |
| Linux | nixpkgs | Medium |

**PyPI approach**: Publish pre-built binaries in a Python package with a thin wrapper. Users get `pip install lispium` → `lispium repl`. Works with `uv` automatically.

#### Web Playground
- [ ] Compile to WASM (Zig has native WASM support)
- [ ] Simple web UI for trying Lispium without installation
- [ ] Shareable links for expressions

### Medium Priority

#### Editor Support
- [ ] VS Code extension with syntax highlighting (TextMate grammar for `.lspm`)
- [ ] LSP server (keep in same repo under `tools/lsp/` or `editor/`)
  - Hover documentation for builtins
  - Completion for function names
  - Parse error diagnostics
  - Signature help

#### Documentation
- [ ] Static documentation site
- [ ] Function reference with examples
- [ ] "Try it" buttons (once WASM playground exists)

### Lower Priority

#### Jupyter Kernel
- [ ] Lispium kernel for Jupyter notebooks
- [ ] Good for educational/math learning use cases

#### Additional Distribution
- [ ] `.deb` package for Debian/Ubuntu
- [ ] Scoop bucket for Windows (alternative to winget)
