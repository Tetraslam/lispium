# Lispium

## A Rare Metal of Algebraic Power

Lispium is a language designed to be a high-performance lisp for symbolic algebraic computation.

## Features

- [x] Symbolic algebraic computation
- [x] Differentiation and integration (indefinite & definite)
- [x] Taylor series expansion
- [x] Equation solving (linear & quadratic)
- [x] Polynomial factoring
- [x] Partial fractions decomposition
- [x] Complex number arithmetic
- [x] Expression simplification & expansion
- [x] Lambda functions & user-defined procedures
- [x] Recursive functions (letrec)
- [x] Symbolic limits with L'Hôpital's rule
- [x] Pattern-matching rewrite rules
- [x] Symbolic matrix operations (det, inv, transpose, LU decomposition)
- [x] Vector operations (dot, cross, norm)
- [x] Vector calculus (gradient, divergence, curl, laplacian)
- [x] Summation & product notation
- [x] Combinatorics (factorial, binomial, permutations, combinations)
- [x] Number theory (primality, factorization, totient, CRT)
- [x] Statistics (mean, variance, stddev, median)
- [x] Quaternions
- [x] Finite fields GF(p)
- [x] LaTeX export
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
(integrate x x 0 2)           ; => 2 (definite integral)
(taylor (exp x) x 0 4)        ; => (+ 1 x (* 0.5 (^ x 2)) ...)
```

### Limits

```lisp
(limit (^ x 2) x 2)           ; => 4
(limit (/ (sin x) x) x 0)     ; => 1   (L'Hôpital)
(limit (/ (tan x) x) x 0)     ; => 1
```

### Algebra

```lisp
(simplify (+ x x x))          ; => (* 3 x)
(expand (* (+ x 1) (+ x 1)))  ; => (+ (^ x 2) (* 2 x) 1)
(solve (- (^ x 2) 4) x)       ; => (solutions 2 -2)
(substitute (+ x y) x 5)      ; => (+ 5 y)
```

### Factoring

```lisp
(factor (- (^ x 2) 4) x)      ; => (* (- x 2) (+ x 2))
(factor (+ (^ x 2) (* 2 x) 1) x) ; => (^ (+ x 1) 2)
(factor (+ (^ x 2) (* 3 x) 2) x) ; => (* (- x -1) (- x -2))
```

### Partial Fractions

```lisp
(partial-fractions (/ 1 (- (^ x 2) 1)) x)
; => (+ (/ 0.5 (- x 1)) (/ -0.5 (- x -1)))

(partial-fractions (/ 1 (+ (^ x 2) (* 3 x) 2)) x)
; => (+ (/ 1 (- x -1)) (/ -1 (- x -2)))
```

### Lambda & Define

```lisp
((lambda (x) (* x x)) 5)      ; => 25
(define (square x) (* x x))
(square 7)                    ; => 49
(let ((a 3) (b 4)) (+ a b))   ; => 7
(if 1 42 99)                  ; => 42
(= 3 3)                       ; => 1 (true)
(< 2 5)                       ; => 1 (true)
```

### Recursive Functions

```lisp
; factorial using letrec
(letrec ((fact (lambda (n)
  (if (= n 0) 1 (* n (fact (- n 1)))))))
  (fact 5))                   ; => 120

; fibonacci
(letrec ((fib (lambda (n)
  (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))))
  (fib 10))                   ; => 55
```

### Rewrite Rules

```lisp
(rule (double ?x) (* 2 ?x))   ; define pattern rule
(rewrite (double 5))          ; => (* 2 5)
(rule (sq ?x) (* ?x ?x))
(rewrite (+ (sq 3) (sq 4)))   ; => (+ (* 3 3) (* 4 4))
```

### Complex Numbers

```lisp
(complex 3 4)                 ; => 3+4i
(magnitude (complex 3 4))     ; => 5
(conj (complex 3 4))          ; => 3-4i
(solve (+ (^ x 2) 1) x)       ; => (solutions i -i)
```

### Matrices

```lisp
(matrix (1 2) (3 4))          ; 2x2 matrix
(det (matrix (a b) (c d)))    ; => (- (* a d) (* b c))
(transpose (matrix (1 2) (3 4)))  ; => ((1 3) (2 4))
(trace (matrix (1 2) (3 4)))  ; => 5
(matmul A B)                  ; matrix multiplication
(inv (matrix (4 0) (0 4)))    ; => ((0.25 0) (0 0.25))
```

### Series & Products

```lisp
(sum i 1 5 i)                 ; => 15 (1+2+3+4+5)
(sum i 1 5 (* i i))           ; => 55 (sum of squares)
(product i 1 5 i)             ; => 120 (5!)
(sum i 1 n i)                 ; symbolic: stays as (sum i 1 n i)
```

### Vectors

```lisp
(vector 1 2 3)                ; 3D vector
(dot (vector 1 2 3) (vector 4 5 6))  ; => 32
(cross (vector 1 0 0) (vector 0 1 0)) ; => (vector 0 0 1)
(norm (vector 3 4))           ; => 5
```

### Vector Calculus

```lisp
(gradient (+ (^ x 2) (^ y 2)) (vector x y))   ; => (vector (* 2 x) (* 2 y))
(divergence (vector x y) (vector x y))         ; => 2
(curl (vector y (* -1 x) 0) (vector x y z))   ; => (vector 0 0 -2)
(laplacian (^ x 2) (vector x))                 ; => 2
```

### Combinatorics

```lisp
(factorial 5)                 ; => 120
(! 5)                         ; => 120 (alias)
(binomial 5 2)                ; => 10
(choose 5 2)                  ; => 10 (alias)
(permutations 5 3)            ; => 60
(combinations 5 3)            ; => 10
```

### Number Theory

```lisp
(prime? 17)                   ; => 1 (true)
(prime? 15)                   ; => 0 (false)
(factorize 60)                ; => (factors (2 2) (3 1) (5 1))
(extgcd 35 15)                ; => (extgcd 5 1 -2) (gcd and Bezout coefficients)
(totient 12)                  ; => 4 (Euler's totient)
(crt (2 3) (3 5))             ; => 8 (Chinese Remainder Theorem)
```

### Statistics

```lisp
(mean 1 2 3 4 5)              ; => 3
(variance 1 2 3 4 5)          ; => 2
(stddev 1 2 3 4 5)            ; => 1.414...
(median 1 2 3 4 5)            ; => 3
(min 3 1 4 1 5)               ; => 1
(max 3 1 4 1 5)               ; => 5
```

### Linear Algebra (Advanced)

```lisp
(lu (matrix (4 3) (6 3)))     ; => (lu L U) - LU decomposition
(charpoly (matrix (1 2) (3 4)) lambda) ; characteristic polynomial
(eigenvalues (matrix (1 2) (2 1)))     ; => (eigenvalues 3 -1)
```

### Polynomial Tools

```lisp
(coeffs 1 -3 2)               ; polynomial x² - 3x + 2 as coefficients
(polydiv (coeffs 1 -3 2) (coeffs 1 -2) x)  ; polynomial division
(polygcd (coeffs 1 -3 2) (coeffs 1 -4 3))  ; polynomial GCD
(roots (+ (- (^ x 2) (* 5 x)) 6) x)        ; => (roots 3 2)
(discriminant (+ (^ x 2) 1) x)             ; => -4
```

### Quaternions

```lisp
(quat 1 2 3 4)                ; quaternion 1 + 2i + 3j + 4k
(quat+ q1 q2)                 ; quaternion addition
(quat* q1 q2)                 ; quaternion multiplication (Hamilton product)
(quat-conj (quat 1 2 3 4))    ; => (quat 1 -2 -3 -4)
(quat-norm (quat 1 2 3 4))    ; => magnitude
(quat-inv q)                  ; multiplicative inverse
```

### Finite Fields GF(p)

```lisp
(gf 3 7)                      ; element 3 in GF(7)
(gf+ (gf 3 7) (gf 5 7))       ; => (gf 1 7) (3+5=8≡1 mod 7)
(gf* (gf 3 7) (gf 4 7))       ; => (gf 5 7) (3*4=12≡5 mod 7)
(gf-inv (gf 3 7))             ; => (gf 5 7) (multiplicative inverse)
(gf^ (gf 2 7) 3)              ; => (gf 1 7) (2³=8≡1 mod 7)
```

### LaTeX Export

```lisp
(latex (+ x 1))               ; => "x + 1"
(latex (/ 1 x))               ; => "\frac{1}{x}"
(latex (^ x 2))               ; => "x^{2}"
(latex (sin x))               ; => "\sin{x}"
(latex (matrix (1 2) (3 4)))  ; => "\begin{pmatrix}1 & 2 \\ 3 & 4\end{pmatrix}"
```

## Trig/Log Identities

Simplify automatically applies:

- `sin(0) = 0`, `cos(0) = 1`, `tan(0) = 0`
- `exp(0) = 1`, `ln(1) = 0`, `ln(e) = 1`
- `exp(ln(x)) = x`, `ln(exp(x)) = x`
- `ln(x^n) = n*ln(x)`

## Tests

```bash
zig build test
```

For verbose output showing all test names:

```bash
zig build test --summary all
```

319 tests, 0 memory leaks.
