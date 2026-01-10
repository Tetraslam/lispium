; Lispium Cookbook: Number Theory Examples
; ========================================

; Modular Arithmetic
; ------------------
; Basic modulo operation
(mod 17 5)                   ; => 2
(mod -7 3)                   ; => 2 (always non-negative)
(mod 100 7)                  ; => 2

; Greatest Common Divisor
; -----------------------
(gcd 48 18)                  ; => 6
(gcd 17 13)                  ; => 1 (coprime)
(gcd 100 25)                 ; => 25
(gcd 0 5)                    ; => 5

; Least Common Multiple
; ---------------------
(lcm 4 6)                    ; => 12
(lcm 3 5)                    ; => 15
(lcm 12 18)                  ; => 36

; Relationship: gcd(a,b) * lcm(a,b) = a * b
; (gcd 12 18) = 6, (lcm 12 18) = 36, 6 * 36 = 216 = 12 * 18

; Modular Exponentiation
; ----------------------
; Compute a^b mod m efficiently (using square-and-multiply)
(modpow 2 10 1000)           ; => 24  (2^10 = 1024, 1024 mod 1000 = 24)
(modpow 3 100 7)             ; => 4
(modpow 7 256 13)            ; => 9

; Useful for cryptographic applications like RSA
; Example: Fermat's Little Theorem - a^(p-1) ≡ 1 (mod p) for prime p
(modpow 2 6 7)               ; => 1  (2^6 mod 7 = 64 mod 7 = 1)
(modpow 3 10 11)             ; => 1  (3^10 mod 11 = 1)

; Coprimality Check
; -----------------
; Two numbers are coprime if gcd(a,b) = 1
(gcd 15 28)                  ; => 1 (coprime)
(gcd 15 25)                  ; => 5 (not coprime)

; Divisibility
; ------------
; a divides b if (mod b a) = 0
(mod 24 6)                   ; => 0, so 6 divides 24
(mod 25 6)                   ; => 1, so 6 does not divide 25

