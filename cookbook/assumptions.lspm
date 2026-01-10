; Lispium Cookbook: Assumptions System Examples
; =============================================

; Setting Assumptions
; -------------------
; Use (assume var property) to declare properties of variables

; Positivity assumptions
(assume x positive)          ; x > 0
(assume y negative)          ; y < 0
(assume z nonzero)           ; z ≠ 0

; Number type assumptions
(assume n integer)           ; n is an integer
(assume m real)              ; m is a real number
(assume k even)              ; k is an even integer
(assume j odd)               ; j is an odd integer

; Multiple assumptions on same variable
(assume t positive)
(assume t integer)           ; t is a positive integer

; Querying Assumptions
; --------------------
; Use (is? var property) to check if an assumption holds

(assume x positive)
(is? x positive)             ; => true
(is? x negative)             ; => false
(is? x nonzero)              ; => true (positive implies nonzero)

(assume n integer)
(is? n integer)              ; => true
(is? n real)                 ; => true (integers are real)

; Assumptions in Simplification
; -----------------------------
; Assumptions can guide simplification rules

; With (assume x positive):
; sqrt(x^2) simplifies to x (not |x|)

; With (assume n integer):
; sin(n * pi) simplifies to 0
; cos(n * pi) simplifies to (-1)^n

; With (assume x nonzero):
; x / x simplifies to 1

; Practical Examples
; ------------------

; Physics: positive time
(assume t positive)
; Now sqrt(t^2) = t, not |t|

; Counting: integer quantities
(assume n integer)
(assume n positive)
; n is a positive integer (natural number)

; Complex analysis: real/imaginary parts
(assume x real)
(assume y real)
; (complex x y) has real parts

; Parity reasoning
(assume k even)
(assume j odd)
; k + j is odd
; k * j is even

; Clearing Assumptions
; --------------------
; Currently assumptions persist for the session
; Restart REPL to clear all assumptions

