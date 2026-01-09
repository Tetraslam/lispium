; Lispium Cookbook: Polynomial Examples
; =====================================

; Polynomial Representation
; -------------------------
; Polynomials can be represented in two ways:
; 1. Symbolic: (+ (^ x 2) (* 2 x) 1) for x² + 2x + 1
; 2. Coefficient list: (coeffs 1 2 1) for 1 + 2x + x²
;    Coefficients are listed from constant term to highest degree

; Extract Coefficients
; --------------------
; Get coefficient list from a polynomial expression
(coeffs (+ (^ x 2) (* 3 x) 2) x)  ; => (coeffs 2 3 1) for 2 + 3x + x²

; Polynomial Division
; -------------------
; Divide polynomials, returns (quotient remainder)
; Example: (x² + 3x + 2) ÷ (x + 1)
(polydiv (coeffs 2 3 1) (coeffs 1 1))
; => ((coeffs 2 1) (coeffs 0))
; Quotient: x + 2, Remainder: 0

; Example: (x³ + 2x² + 3x + 4) ÷ (x + 1)
(polydiv (coeffs 4 3 2 1) (coeffs 1 1))
; => ((coeffs 2 1 1) (coeffs 2))
; Quotient: x² + x + 2, Remainder: 2

; Polynomial GCD
; --------------
; Find the greatest common divisor of two polynomials
; GCD of (x² - 1) and (x² + 2x + 1)
; = GCD of (x-1)(x+1) and (x+1)² = (x+1)
(polygcd (coeffs -1 0 1) (coeffs 1 2 1))
; => (coeffs 1 1) representing (x + 1)

; Polynomial LCM
; --------------
; Find the least common multiple of two polynomials
(polylcm (coeffs -1 0 1) (coeffs 1 2 1))
; => LCM of (x² - 1) and (x² + 2x + 1)

; Partial Fractions
; -----------------
; Decompose rational functions into partial fractions
; Example: 1/(x² - 1) = 1/((x-1)(x+1)) = A/(x-1) + B/(x+1)
(partial-fractions (/ 1 (+ (^ x 2) (* -1 1))) x)

; Working with Symbolic Polynomials
; ---------------------------------
; Expand polynomial products
(expand (* (+ x 1) (+ x 2)))  ; => x² + 3x + 2

; Factor polynomials
(factor (+ (^ x 2) (* -1 1)) x)  ; => (x - 1)(x + 1)

; Collect like terms
(collect (+ (* a x) (* b x) c) x)  ; => (a + b)x + c

