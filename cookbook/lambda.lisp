; Lispium Cookbook: Lambda and Function Examples
; ==============================================

; Anonymous Functions (Lambda)
; ----------------------------
; Create functions with (lambda (params) body)

; Identity function
(lambda (x) x)

; Constant function
(lambda (x) 42)

; Single argument functions
(lambda (x) (+ x 1))         ; increment
(lambda (x) (* x 2))         ; double
(lambda (x) (^ x 2))         ; square

; Multiple argument functions
(lambda (x y) (+ x y))       ; addition
(lambda (x y) (* x y))       ; multiplication
(lambda (a b c) (+ (* a (^ x 2)) (* b x) c))  ; quadratic

; Function Application
; --------------------
; Apply a lambda immediately
((lambda (x) (+ x 1)) 5)     ; => 6
((lambda (x y) (* x y)) 3 4) ; => 12

; Define Named Functions
; ----------------------
; Use define to bind functions to names
(define square (lambda (x) (* x 2)))
(define cube (lambda (x) (^ x 3)))
(define add (lambda (x y) (+ x y)))

; Then use them
(square 5)                   ; => 25
(cube 3)                     ; => 27
(add 10 20)                  ; => 30

; Recursive Functions (letrec)
; ----------------------------
; Use letrec for recursive function definitions
(letrec ((fact (lambda (n)
                 (if (= n 0)
                     1
                     (* n (fact (- n 1)))))))
  (fact 5))                  ; => 120

; Fibonacci with letrec
(letrec ((fib (lambda (n)
                (if (< n 2)
                    n
                    (+ (fib (- n 1)) (fib (- n 2)))))))
  (fib 10))                  ; => 55

; Higher-Order Functions
; ----------------------
; Functions that take or return functions

; Function that returns a function
(define make-adder (lambda (n) (lambda (x) (+ x n))))
(define add5 (make-adder 5))
(add5 10)                    ; => 15

; Composition (f ∘ g)(x) = f(g(x))
(define compose (lambda (f g) (lambda (x) (f (g x)))))
(define inc (lambda (x) (+ x 1)))
(define double (lambda (x) (* x 2)))
(define inc-then-double (compose double inc))
(inc-then-double 5)          ; => 12  ((5+1)*2)

; Closures
; --------
; Lambdas capture their environment
(define make-counter (lambda (start)
  (lambda () (set! start (+ start 1)) start)))

; Mathematical Functions
; ----------------------
; Define common mathematical functions
(define abs (lambda (x) (if (< x 0) (* -1 x) x)))
(define sign (lambda (x) (if (< x 0) -1 (if (> x 0) 1 0))))
(define max (lambda (a b) (if (> a b) a b)))
(define min (lambda (a b) (if (< a b) a b)))

