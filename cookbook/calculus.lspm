; Lispium Cookbook: Calculus Examples
; =====================================

; Basic Differentiation
; ---------------------
; Power rule: d/dx(x^n) = n*x^(n-1)
(diff (^ x 3) x)          ; => (* 3 (^ x 2))
(diff (^ x 5) x)          ; => (* 5 (^ x 4))

; Higher-order derivatives
(diff (^ x 4) x 2)        ; => (* 4 (* 3 (^ x 2)))  (second derivative)
(diff (sin x) x 2)        ; => (* -1 (sin x))       (sin'' = -sin)

; Chain rule (automatically applied)
(diff (sin (^ x 2)) x)    ; => (* (cos (^ x 2)) (* 2 x))

; Product rule
(diff (* x (sin x)) x)    ; Uses product rule

; Transcendental functions
(diff (exp x) x)          ; => (exp x)
(diff (ln x) x)           ; => (/ 1 x)
(diff (sin x) x)          ; => (cos x)
(diff (cos x) x)          ; => (* -1 (sin x))

; Integration
; -----------
; Power rule: ∫x^n dx = x^(n+1)/(n+1)
(integrate (^ x 2) x)     ; => (/ (^ x 3) 3)
(integrate (^ x 3) x)     ; => (/ (^ x 4) 4)

; Special integrals
(integrate (/ 1 x) x)     ; => (ln x)
(integrate (exp x) x)     ; => (exp x)
(integrate (sin x) x)     ; => (* -1 (cos x))
(integrate (cos x) x)     ; => (sin x)

; Taylor Series
; -------------
; Expand functions around a point
(taylor (sin x) x 0 5)    ; sin(x) ≈ x - x³/6 + x⁵/120
(taylor (exp x) x 0 4)    ; exp(x) ≈ 1 + x + x²/2 + x³/6 + x⁴/24
(taylor (cos x) x 0 4)    ; cos(x) ≈ 1 - x²/2 + x⁴/24

; Limits
; ------
(limit (/ (sin x) x) x 0) ; => 1 (L'Hôpital's rule)
