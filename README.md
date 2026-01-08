# Lispium

## A Rare Metal of Algebraic Power

Lispium is a language designed to be a high-performance lisp for symbolic algebraic computation.

## Features

- [x] Symbolic algebraic computation
- [x] Differentiation and integration
- [x] Taylor series expansion
- [x] Equation solving (linear & quadratic)
- [x] Complex number arithmetic
- [x] Expression simplification & expansion
- [x] REPL with S-expressions
- [x] Zero dependencies, pure Zig

## Build & Run

```bash
zig build run -- repl
```

## Operations

### Arithmetic

```lisp
(+ 1 2 3)           ; => 6
(- 10 3 2)          ; => 5
(* 2 3 4)           ; => 24
(/ 10 2)            ; => 5
(^ 2 10)            ; => 1024
```

### Functions

```lisp
(sin x)  (cos x)  (tan x)
(exp x)  (ln x)   (log x)
(sqrt x)
```

### Calculus

```lisp
(diff (^ x 3) x)              ; => (* 3 (^ x 2))
(integrate (* 2 x) x)         ; => (^ x 2)
(taylor (exp x) x 0 4)        ; => (+ 1 x (* 0.5 (^ x 2)) ...)
```

### Algebra

```lisp
(simplify (+ x x x))          ; => (* 3 x)
(expand (* (+ x 1) (+ x 1)))  ; => (+ (^ x 2) (* 2 x) 1)
(solve (- (^ x 2) 4) x)       ; => (solutions 2 -2)
(substitute (+ x y) x 5)      ; => (+ 5 y)
```

### Complex Numbers

```lisp
(complex 3 4)                 ; => 3+4i
(magnitude (complex 3 4))     ; => 5
(conj (complex 3 4))          ; => 3-4i
(solve (+ (^ x 2) 1) x)       ; => (solutions i -i)
```

## Tests

```bash
zig build test
```

For verbose output showing all test names:

```bash
zig build test --summary all
```

78 tests, 0 memory leaks.
