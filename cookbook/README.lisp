; Lispium Cookbook
; ================
; A collection of examples demonstrating Lispium's capabilities
;
; Files in this cookbook:
; -----------------------
; calculus.lisp      - Differentiation, integration, Taylor series, limits
; linear_algebra.lisp - Vectors, matrices, eigenvalues, linear systems
; algebra.lisp       - Simplification, expansion, factoring, solving
; polynomials.lisp   - Polynomial division, GCD, LCM, partial fractions
; number_theory.lisp - Modular arithmetic, GCD, LCM, modular exponentiation
; boolean.lisp       - Boolean operations: and, or, not, xor, implies
; complex.lisp       - Complex numbers, conjugate, magnitude, argument
; assumptions.lisp   - Setting and querying variable assumptions
; lambda.lisp        - Functions, recursion, higher-order functions
;
; Quick Reference
; ---------------
; Arithmetic:     + - * / ^ mod
; Comparison:     = < >
; Trigonometric:  sin cos tan
; Transcendental: exp ln log sqrt
; Calculus:       diff integrate taylor limit
; Algebra:        simplify expand factor solve collect substitute
; Polynomials:    coeffs polydiv polygcd polylcm partial-fractions
; Linear Algebra: vector dot cross norm matrix det transpose trace
;                 matmul inv eigenvalues eigenvectors linsolve
; Number Theory:  gcd lcm modpow
; Boolean:        and or not xor implies
; Complex:        complex real imag conj magnitude arg
; Functions:      lambda define letrec if
; Assumptions:    assume is?
; Rewriting:      rule rewrite
;
; Getting Started
; ---------------
; Run the REPL: zig build run -- repl
; Try: (+ 1 2)
; Try: (diff (^ x 3) x)
; Try: (simplify (+ x x))
;
; For help in REPL, type: help

