; Lispium Cookbook: Boolean Algebra Examples
; ==========================================

; Basic Operations
; ----------------
; AND operation
(and true true)              ; => true
(and true false)             ; => false
(and false true)             ; => false
(and false false)            ; => false

; OR operation
(or true true)               ; => true
(or true false)              ; => true
(or false true)              ; => true
(or false false)             ; => false

; NOT operation
(not true)                   ; => false
(not false)                  ; => true

; XOR (exclusive or)
(xor true true)              ; => false
(xor true false)             ; => true
(xor false true)             ; => true
(xor false false)            ; => false

; Implication
; -----------
; p implies q (p → q) is equivalent to (not p) or q
(implies true true)          ; => true
(implies true false)         ; => false
(implies false true)         ; => true
(implies false false)        ; => true

; Boolean Laws
; ------------
; De Morgan's Laws:
; not(A and B) = (not A) or (not B)
; not(A or B) = (not A) and (not B)

; Identity laws:
(and true x)                 ; => x
(or false x)                 ; => x

; Domination laws:
(and false x)                ; => false
(or true x)                  ; => true

; Complement laws:
(and x (not x))              ; => false
(or x (not x))               ; => true

; Idempotent laws:
(and x x)                    ; => x
(or x x)                     ; => x

; Double negation:
(not (not x))                ; => x

; Compound Expressions
; --------------------
; Build complex boolean expressions
(and (or a b) (not c))       ; (a ∨ b) ∧ ¬c
(implies (and p q) r)        ; (p ∧ q) → r
(or (and a b) (and c d))     ; (a ∧ b) ∨ (c ∧ d)

; Truth Table Example
; -------------------
; For expression: (and (or a b) (not a))
; a=T, b=T: (and (or T T) (not T)) = (and T F) = F
; a=T, b=F: (and (or T F) (not T)) = (and T F) = F
; a=F, b=T: (and (or F T) (not F)) = (and T T) = T
; a=F, b=F: (and (or F F) (not F)) = (and F T) = F

