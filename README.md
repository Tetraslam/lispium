# Lispium

**A Rare Metal of Algebraic Power**

A symbolic computer algebra system written in pure Zig. Zero dependencies, blazing fast.

## Install

```bash
pip install lispium
```

## Quick Start

```bash
lispium repl
```

```lisp
> (diff (^ x 3) x)
3x²

> (solve (- (^ x 2) 4) x)
{2, -2}

> (integrate (* 2 x) x)
x²

> (det (matrix (a b) (c d)))
ad - bc

> (taylor (exp x) x 0 3)
1 + x + x²/2 + x³/6
```

## Highlights

- **Calculus** - derivatives, integrals, Taylor series, limits
- **Algebra** - equation solving, factoring, partial fractions
- **Linear Algebra** - matrices, determinants, eigenvalues, LU decomposition
- **Number Theory** - primes, factorization, Chinese Remainder Theorem
- **And more** - quaternions, finite fields, Laplace transforms, plotting

[Playground](https://tetraslam.github.io/lispium/playground/) · [Function reference](https://tetraslam.github.io/lispium/) · [Cookbook](cookbook/)

## Features

- [x] Exact rational arithmetic (`1/3`, not `0.333...`)
- [x] Strings, quote/quasiquote, and macros (defmacro)
- [x] Interactive I/O (print, read), scripts with shebang + (args)
- [x] Tail-call optimization (constant-stack loops)
- [x] Error handling (try, error, assert) and a test runner
- [x] Units with dimensional analysis
- [x] Symbolic algebraic computation
- [x] Differentiation and integration (indefinite & definite)
- [x] Taylor series expansion
- [x] Equation solving (linear, quadratic & cubic)
- [x] Polynomial factoring
- [x] Partial fractions decomposition
- [x] Complex number arithmetic
- [x] Expression simplification & expansion
- [x] Lambda functions & user-defined procedures (with closures)
- [x] Recursive functions (letrec)
- [x] Symbolic limits with L'Hôpital's rule
- [x] Pattern-matching rewrite rules
- [x] Symbolic matrix operations (det, inv, transpose, LU decomposition)
- [x] Vector operations (dot, cross, norm, elementwise arithmetic)
- [x] Vector calculus (gradient, divergence, curl, laplacian)
- [x] Summation & product notation
- [x] Combinatorics (factorial, binomial, permutations, combinations)
- [x] Number theory (primality, factorization, totient, CRT)
- [x] Statistics (mean, variance, stddev, median)
- [x] Quaternions
- [x] Finite fields GF(p)
- [x] LaTeX export
- [x] Inverse trig & hyperbolic functions
- [x] Special functions (gamma, beta, bessel, erf)
- [x] Differential equation solver (dsolve)
- [x] Fourier series & Laplace transforms
- [x] Tensor operations (rank, contraction, product)
- [x] Polynomial interpolation (Lagrange, Newton)
- [x] Numerical root finding (Newton-Raphson, bisection)
- [x] Continued fractions
- [x] List operations (car, cdr, cons, map, filter, reduce)
- [x] Memoization
- [x] Plotting (ASCII & SVG)
- [x] Step-by-step solutions
- [x] REPL with S-expressions
- [x] Zero dependencies, pure Zig

## Build & Run

```bash
zig build run -- repl
```

## Tour

Everything is a prefix S-expression: `(+ 1 2 3)` => `6`, `(^ 2 10)` => `1024`.

```lisp
; Calculus
(diff (^ x 3) x)              ; => (* 3 (^ x 2))
(integrate (* x (sin x)) x)   ; => (- (sin x) (* x (cos x)))
(integrate (sin x) x 0 pi)    ; => 2 (definite integral)
(taylor (exp x) x 0 4)        ; => 1 + x + x²/2 + x³/6 + x⁴/24
(limit (/ (sin x) x) x 0)     ; => 1 (L'Hôpital)
(limit (^ (+ 1 (/ 1 x)) x) x inf)  ; => e

; Exact arithmetic & programs
(+ 1/3 1/6)                   ; => 1/2 (exact rationals)
(defmacro (unless c a b) `(if ,c ,b ,a))
(apply + '(1 2 3))            ; => 6
(sum i 1 n i)                 ; => n(n+1)/2 (closed form)
(/ (* 100 (unit km)) (unit h))  ; => 27.78 m/s (dimensional analysis)

; Algebra
(simplify (+ (^ (sin x) 2) (^ (cos x) 2)))  ; => 1
(expand (* (+ x 1) (+ x 1)))  ; => (+ (^ x 2) (* 2 x) 1)
(solve (- (^ x 2) 4) x)       ; => (solutions 2 -2)
(factor (+ (^ x 2) (* 3 x) 2) x)  ; => (* (+ x 1) (+ x 2))
(partial-fractions (/ 1 (- (^ x 2) 1)) x)
(substitute (+ x y) x 5)      ; => (+ 5 y)
(evalf pi)                    ; => 3.141592653589793

; Functions and closures
(define (square x) (* x x))
(square 7)                    ; => 49
(define (make-adder n) (lambda (x) (+ x n)))
((make-adder 5) 10)           ; => 15
(letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1)))))))
  (fact 5))                   ; => 120
(let ((a 3) (b 4)) (+ a b))   ; => 7

; Rewrite rules
(rule (double ?x) (* 2 ?x))
(rewrite (double 5))          ; => (* 2 5)

; Complex numbers
(sqrt -4)                     ; => 2i
(* (complex 0 1) (complex 0 1))  ; => -1
(magnitude (complex 3 4))     ; => 5

; Linear algebra
(det (matrix (a b) (c d)))    ; => (- (* a d) (* b c))
(inv (matrix (4 0) (0 4)))    ; => ((0.25 0) (0 0.25))
(matmul A B)  (eigenvalues M)  (lu M)  (linsolve A b)
(+ (vector 1 2) (vector 3 4)) ; => (vector 4 6)
(cross (vector 1 0 0) (vector 0 1 0))  ; => (vector 0 0 1)

; Series, number theory, statistics
(sum i 1 5 (* i i))           ; => 55
(product i 1 5 i)             ; => 120
(factorize 60)                ; => (factors (2 2) (3 1) (5 1))
(crt (vector 2 3) (vector 3 5))  ; => 8
(mean 1 2 3 4 5)              ; => 3

; Differential equations & transforms
(dsolve (= (diff y x) y) y x) ; => (= y (* C (exp x)))
(laplace (exp (* -1 t)) t s)  ; => (/ 1 (+ s 1))

; Quaternions & finite fields
(quat* (quat 0 1 0 0) (quat 0 0 1 0))  ; => (quat 0 0 0 1)
(gf+ (gf 3 7) (gf 5 7))       ; => (gf 1 7)

; Export & tooling
(latex (/ 1 x))               ; => "\frac{1}{x}"
(plot-ascii (* x x) -2 2)     ; ASCII plot
(diff-steps (^ x 3) x)        ; step-by-step solution
```

The [cookbook](cookbook/) has runnable examples for every area
(`lispium run cookbook/calculus.lspm`), and [CLAUDE.md](CLAUDE.md) documents
every builtin with signatures.

## REPL

- Multi-line input continues until parens balance; an empty line cancels
- `help`, `?function` (inline docs), `complete <partial>` (tab-complete names)
- `history`, `!!` (repeat last), `!n` (recall entry n)
- Pretty printing: π, ⟨1, 2, 3⟩, x², √x, 3 + 4i, {2, -2}

## Formatting

```bash
lispium fmt                  # canonical style, in place (see STYLE.md)
lispium fmt --check .        # CI mode
```

Editors format through the LSP (`:format` in Helix, format-on-save in VS Code).

## Tooling

- `lispium repl [file]` — REPL with a real line editor (arrows, history,
  cursor editing), persistent history, `_`, `?func` docs
- `lispium run --watch --time --profile` — live reload, timing, and
  per-statement profiling
- `lispium test` — assert-based test runner for `*_test.lspm`
- `lispium docs [name|--html]` — reference in the terminal or as a site
- `lispium fmt` / `lispium completions <shell>` / `man man/lispium.1`
- LSP (`lispium lsp`): hover, completion, diagnostics, formatting,
  go-to-definition, outline — used by the VS Code extension and Helix
- Jupyter: `pip install lispium[jupyter]`, then `python -m lispium.kernel install`
- Errors show call stacks: `call stack: inner <- middle <- outer`
- `(step expr)` prints every reduction; `(trace f)` traces one function
- LSP also does rename and signature help

## Tests

```bash
zig build test               # run the suite
zig build test --summary all # verbose, shows test names
```

532 tests, 0 memory leaks.
