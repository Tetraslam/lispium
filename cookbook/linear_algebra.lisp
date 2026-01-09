; Lispium Cookbook: Linear Algebra Examples
; ==========================================

; Vectors
; -------
; Create vectors with the vector function
(vector 1 2 3)              ; => ⟨1, 2, 3⟩

; Dot product
(dot (vector 1 2 3) (vector 4 5 6))  ; => 32  (1*4 + 2*5 + 3*6)

; Cross product (3D vectors only)
(cross (vector 1 0 0) (vector 0 1 0))  ; => ⟨0, 0, 1⟩

; Vector norm (magnitude)
(norm (vector 3 4))         ; => 5
(norm (vector 1 2 2))       ; => 3

; Matrices
; --------
; Create matrices row by row
(matrix (1 2) (3 4))        ; 2x2 matrix

; Determinant
(det (matrix (1 2) (3 4)))  ; => -2  (1*4 - 2*3)
(det (matrix (1 2 3) (4 5 6) (7 8 9)))  ; => 0 (singular)

; Transpose
(transpose (matrix (1 2) (3 4)))  ; => [[1, 3], [2, 4]]

; Trace (sum of diagonal elements)
(trace (matrix (1 2) (3 4)))  ; => 5  (1 + 4)

; Matrix multiplication
(matmul (matrix (1 2) (3 4)) (matrix (5 6) (7 8)))
; => [[19, 22], [43, 50]]

; Matrix inverse
(inv (matrix (1 2) (3 4)))  ; => [[-2, 1], [1.5, -0.5]]

; Eigenvalues (2x2 matrices)
; -------------------------
; For a 2x2 matrix, eigenvalues are roots of det(A - λI) = 0
(eigenvalues (matrix (4 1) (2 3)))  ; => (5 2)

; Eigenvectors (2x2 matrices)
(eigenvectors (matrix (4 1) (2 3)))  ; eigenvectors for each eigenvalue

; Linear Systems
; --------------
; Solve Ax = b using Gaussian elimination
; Solve: x + 2y = 5, 3x + 4y = 11
(linsolve (matrix (1 2) (3 4)) (vector 5 11))  ; => ⟨1, 2⟩

; Solve 3x3 system:
; x + y + z = 6
; 2x + y - z = 1
; x - y + 2z = 5
(linsolve (matrix (1 1 1) (2 1 -1) (1 -1 2)) (vector 6 1 5))
; => ⟨1, 2, 3⟩  (x=1, y=2, z=3)

