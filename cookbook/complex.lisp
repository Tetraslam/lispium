; Lispium Cookbook: Complex Number Examples
; =========================================

; Creating Complex Numbers
; ------------------------
(complex 3 4)                ; => 3 + 4i
(complex 1 0)                ; => 1 (real number)
(complex 0 1)                ; => i (imaginary unit)
(complex -2 5)               ; => -2 + 5i

; Extracting Parts
; ----------------
(real (complex 3 4))         ; => 3
(imag (complex 3 4))         ; => 4
(real (complex 5 -2))        ; => 5
(imag (complex 5 -2))        ; => -2

; Complex Conjugate
; -----------------
; Conjugate of a + bi is a - bi
(conj (complex 3 4))         ; => 3 - 4i
(conj (complex -2 5))        ; => -2 - 5i

; Magnitude (Absolute Value)
; --------------------------
; |a + bi| = sqrt(a² + b²)
(magnitude (complex 3 4))    ; => 5  (sqrt(9 + 16) = sqrt(25) = 5)
(magnitude (complex 5 12))   ; => 13 (sqrt(25 + 144) = sqrt(169) = 13)

; Argument (Phase Angle)
; ----------------------
; arg(a + bi) = atan2(b, a) in radians
(arg (complex 1 1))          ; => π/4 (≈ 0.785)
(arg (complex 0 1))          ; => π/2 (≈ 1.571)
(arg (complex -1 0))         ; => π   (≈ 3.142)

; Arithmetic Operations
; ---------------------
; Addition: (a + bi) + (c + di) = (a+c) + (b+d)i
(+ (complex 1 2) (complex 3 4))  ; => 4 + 6i

; Subtraction
(- (complex 5 3) (complex 2 1))  ; => 3 + 2i

; Multiplication: (a + bi)(c + di) = (ac - bd) + (ad + bc)i
(* (complex 1 2) (complex 3 4))  ; => -5 + 10i

; Division
(/ (complex 1 0) (complex 0 1))  ; => -i  (1/i = -i)

; Polar Form
; ----------
; Complex number in polar form: r·e^(iθ) = r(cos θ + i sin θ)
; where r = magnitude, θ = argument

; Convert from polar: r·e^(iθ)
; magnitude = 5, angle = π/3
; => 5·(cos(π/3) + i·sin(π/3)) = 5·(0.5 + i·0.866) = 2.5 + 4.33i

; Euler's Identity
; ----------------
; e^(iπ) + 1 = 0, the famous Euler's identity
; (exp (complex 0 pi)) => approximately -1 + 0i

; De Moivre's Theorem
; -------------------
; (cos θ + i sin θ)^n = cos(nθ) + i sin(nθ)

; Roots of Unity
; --------------
; The n-th roots of unity are: e^(2πik/n) for k = 0, 1, ..., n-1
; Square roots of 1: ±1
; Cube roots of 1: 1, e^(2πi/3), e^(4πi/3)
; Fourth roots of 1: 1, i, -1, -i

