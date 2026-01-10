/// Documentation for all builtin functions
/// Used by the LSP server for hover and completion

pub const all_builtins = [_][]const u8{
    // Arithmetic
    "+", "-", "*", "/", "^", "pow",
    // Algebra
    "simplify", "expand", "solve", "factor", "partial-fractions", "collect", "substitute", "rewrite", "rule",
    // Calculus
    "diff", "integrate", "taylor", "limit", "dsolve",
    // Trig
    "sin", "cos", "tan", "asin", "acos", "atan", "atan2",
    // Hyperbolic
    "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
    // Transcendental
    "exp", "ln", "log", "sqrt",
    // Complex
    "complex", "real", "imag", "conj", "magnitude", "arg",
    // Matrix
    "matrix", "det", "transpose", "trace", "matmul", "inv", "eigenvalues", "eigenvectors", "linsolve", "lu", "charpoly",
    // Vector
    "vector", "dot", "cross", "norm",
    // Vector calculus
    "gradient", "grad", "divergence", "curl", "laplacian",
    // Boolean
    "and", "or", "not", "xor", "implies",
    // Modular
    "mod", "gcd", "lcm", "modpow",
    // Number theory
    "prime?", "factorize", "totient", "extgcd", "crt",
    // Combinatorics
    "factorial", "!", "binomial", "choose", "permutations", "combinations",
    // Statistics
    "mean", "variance", "stddev", "median", "min", "max",
    // Special functions
    "gamma", "beta", "erf", "erfc", "besselj", "bessely", "digamma",
    // Polynomial
    "coeffs", "polydiv", "polygcd", "polylcm", "roots", "discriminant",
    // Assumptions
    "assume", "is?",
    // Comparisons
    "=", "<", ">",
    // Transforms
    "fourier", "laplace", "inv-laplace",
    // Tensor
    "tensor", "tensor-rank", "tensor-contract", "tensor-product",
    // Interpolation
    "lagrange", "newton-interp",
    // Root finding
    "newton-raphson", "bisection",
    // Continued fractions
    "to-cf", "from-cf", "cf-convergent", "cf-rational",
    // List
    "car", "cdr", "cons", "list", "length", "nth", "map", "filter", "reduce", "append", "reverse", "range",
    // Memoization
    "memoize", "memo-clear", "memo-stats",
    // Plotting
    "plot-ascii", "plot-svg", "plot-points",
    // Step-by-step
    "diff-steps", "integrate-steps", "simplify-steps", "solve-steps",
    // Quaternions
    "quat", "quat+", "quat*", "quat-conj", "quat-norm", "quat-inv", "quat-scalar", "quat-vector",
    // Finite fields
    "gf", "gf+", "gf-", "gf*", "gf/", "gf^", "gf-inv", "gf-neg",
    // Export
    "latex",
    // Special forms
    "define", "lambda", "let", "letrec", "if", "sum", "product",
};

pub fn getDocumentation(name: []const u8) ?[]const u8 {
    const std = @import("std");

    // Arithmetic
    if (std.mem.eql(u8, name, "+")) return "## `(+ a b ...)`\n\nAddition. Adds all arguments together.\n\n**Example:**\n```lispium\n(+ 1 2 3) ; => 6\n(+ x y)   ; => (x + y)\n```";
    if (std.mem.eql(u8, name, "-")) return "## `(- a b ...)`\n\nSubtraction. Subtracts subsequent arguments from the first.\n\n**Example:**\n```lispium\n(- 10 3 2) ; => 5\n(- x y)    ; => (x - y)\n```";
    if (std.mem.eql(u8, name, "*")) return "## `(* a b ...)`\n\nMultiplication. Multiplies all arguments.\n\n**Example:**\n```lispium\n(* 2 3 4) ; => 24\n(* 2 x)   ; => (2 * x)\n```";
    if (std.mem.eql(u8, name, "/")) return "## `(/ a b)`\n\nDivision. Divides a by b.\n\n**Example:**\n```lispium\n(/ 10 2) ; => 5\n(/ x 2)  ; => (x / 2)\n```";
    if (std.mem.eql(u8, name, "^") or std.mem.eql(u8, name, "pow")) return "## `(^ base exp)`\n\nExponentiation. Raises base to the power of exp.\n\n**Example:**\n```lispium\n(^ 2 10) ; => 1024\n(^ x 2)  ; => x^2\n```";

    // Calculus
    if (std.mem.eql(u8, name, "diff")) return "## `(diff expr var [n])`\n\nDifferentiate expression with respect to variable.\nOptionally compute the nth derivative.\n\n**Example:**\n```lispium\n(diff (^ x 3) x)   ; => (* 3 (^ x 2))\n(diff (^ x 3) x 2) ; => (* 6 x)\n```";
    if (std.mem.eql(u8, name, "integrate")) return "## `(integrate expr var [a b])`\n\nIntegrate expression with respect to variable.\nWith bounds a and b, computes definite integral.\n\n**Example:**\n```lispium\n(integrate (^ x 2) x)     ; => (/ (^ x 3) 3)\n(integrate (^ x 2) x 0 1) ; => 0.333...\n```";
    if (std.mem.eql(u8, name, "taylor")) return "## `(taylor expr var point order)`\n\nCompute Taylor series expansion around a point.\n\n**Example:**\n```lispium\n(taylor (exp x) x 0 4) ; => 1 + x + x^2/2 + ...\n```";
    if (std.mem.eql(u8, name, "limit")) return "## `(limit expr var point)`\n\nCompute limit using L'Hopital's rule.\n\n**Example:**\n```lispium\n(limit (/ (sin x) x) x 0) ; => 1\n```";

    // Algebra
    if (std.mem.eql(u8, name, "simplify")) return "## `(simplify expr)`\n\nAlgebraic simplification.\n\n**Example:**\n```lispium\n(simplify (+ x x))     ; => (* 2 x)\n(simplify (* x 0))     ; => 0\n(simplify (^ x 1))     ; => x\n```";
    if (std.mem.eql(u8, name, "expand")) return "## `(expand expr)`\n\nExpand products and powers.\n\n**Example:**\n```lispium\n(expand (^ (+ x 1) 2)) ; => (+ (^ x 2) (* 2 x) 1)\n```";
    if (std.mem.eql(u8, name, "solve")) return "## `(solve expr var)`\n\nSolve equation expr=0 for variable.\nHandles linear and quadratic equations.\n\n**Example:**\n```lispium\n(solve (- (^ x 2) 4) x) ; => {2, -2}\n(solve (+ (* 2 x) 6) x) ; => -3\n```";
    if (std.mem.eql(u8, name, "factor")) return "## `(factor expr var)`\n\nFactor polynomial expression.\n\n**Example:**\n```lispium\n(factor (- (^ x 2) 1) x) ; => (* (- x 1) (+ x 1))\n```";
    if (std.mem.eql(u8, name, "substitute")) return "## `(substitute expr var value)`\n\nSubstitute value for variable in expression.\n\n**Example:**\n```lispium\n(substitute (+ x y) x 3) ; => (+ 3 y)\n```";

    // Trig
    if (std.mem.eql(u8, name, "sin")) return "## `(sin x)`\n\nSine function.\n\n**Example:**\n```lispium\n(sin 0)       ; => 0\n(sin (/ pi 2)) ; => 1\n```";
    if (std.mem.eql(u8, name, "cos")) return "## `(cos x)`\n\nCosine function.\n\n**Example:**\n```lispium\n(cos 0)  ; => 1\n(cos pi) ; => -1\n```";
    if (std.mem.eql(u8, name, "tan")) return "## `(tan x)`\n\nTangent function.\n\n**Example:**\n```lispium\n(tan 0)       ; => 0\n(tan (/ pi 4)) ; => 1\n```";

    // Complex
    if (std.mem.eql(u8, name, "complex")) return "## `(complex re im)`\n\nCreate complex number re + im*i.\n\n**Example:**\n```lispium\n(complex 3 4) ; => 3 + 4i\n```";
    if (std.mem.eql(u8, name, "real")) return "## `(real z)`\n\nReal part of complex number.\n\n**Example:**\n```lispium\n(real (complex 3 4)) ; => 3\n```";
    if (std.mem.eql(u8, name, "imag")) return "## `(imag z)`\n\nImaginary part of complex number.\n\n**Example:**\n```lispium\n(imag (complex 3 4)) ; => 4\n```";
    if (std.mem.eql(u8, name, "magnitude")) return "## `(magnitude z)`\n\nAbsolute value |z| of complex number.\n\n**Example:**\n```lispium\n(magnitude (complex 3 4)) ; => 5\n```";

    // Matrix
    if (std.mem.eql(u8, name, "matrix")) return "## `(matrix (row1) (row2) ...)`\n\nCreate matrix from row vectors.\n\n**Example:**\n```lispium\n(matrix (1 2) (3 4)) ; 2x2 matrix\n```";
    if (std.mem.eql(u8, name, "det")) return "## `(det M)`\n\nDeterminant of matrix.\n\n**Example:**\n```lispium\n(det (matrix (1 2) (3 4))) ; => -2\n```";
    if (std.mem.eql(u8, name, "inv")) return "## `(inv M)`\n\nInverse of matrix.\n\n**Example:**\n```lispium\n(inv (matrix (1 2) (3 4)))\n```";
    if (std.mem.eql(u8, name, "matmul")) return "## `(matmul A B)`\n\nMatrix multiplication A * B.\n\n**Example:**\n```lispium\n(matmul (matrix (1 2) (3 4)) (matrix (5 6) (7 8)))\n```";
    if (std.mem.eql(u8, name, "eigenvalues")) return "## `(eigenvalues M)`\n\nEigenvalues of 2x2 matrix.\n\n**Example:**\n```lispium\n(eigenvalues (matrix (1 2) (2 1)))\n```";

    // Vector
    if (std.mem.eql(u8, name, "vector")) return "## `(vector x y z ...)`\n\nCreate vector.\n\n**Example:**\n```lispium\n(vector 1 2 3) ; => <1, 2, 3>\n```";
    if (std.mem.eql(u8, name, "dot")) return "## `(dot v1 v2)`\n\nDot product of vectors.\n\n**Example:**\n```lispium\n(dot (vector 1 2 3) (vector 4 5 6)) ; => 32\n```";
    if (std.mem.eql(u8, name, "cross")) return "## `(cross v1 v2)`\n\nCross product of 3D vectors.\n\n**Example:**\n```lispium\n(cross (vector 1 0 0) (vector 0 1 0)) ; => <0, 0, 1>\n```";
    if (std.mem.eql(u8, name, "norm")) return "## `(norm v)`\n\nEuclidean norm (length) of vector.\n\n**Example:**\n```lispium\n(norm (vector 3 4)) ; => 5\n```";

    // Vector calculus
    if (std.mem.eql(u8, name, "gradient") or std.mem.eql(u8, name, "grad")) return "## `(gradient f vars)`\n\nGradient of scalar field f.\n\n**Example:**\n```lispium\n(gradient (+ (^ x 2) (^ y 2)) (vector x y))\n```";
    if (std.mem.eql(u8, name, "divergence")) return "## `(divergence F vars)`\n\nDivergence of vector field F.";
    if (std.mem.eql(u8, name, "curl")) return "## `(curl F vars)`\n\nCurl of 3D vector field F.";
    if (std.mem.eql(u8, name, "laplacian")) return "## `(laplacian f vars)`\n\nLaplacian of scalar field f.";

    // List operations
    if (std.mem.eql(u8, name, "list")) return "## `(list a b c ...)`\n\nCreate a list.\n\n**Example:**\n```lispium\n(list 1 2 3) ; => (1 2 3)\n```";
    if (std.mem.eql(u8, name, "car")) return "## `(car lst)`\n\nFirst element of list.\n\n**Example:**\n```lispium\n(car (list 1 2 3)) ; => 1\n```";
    if (std.mem.eql(u8, name, "cdr")) return "## `(cdr lst)`\n\nRest of list (all but first).\n\n**Example:**\n```lispium\n(cdr (list 1 2 3)) ; => (2 3)\n```";
    if (std.mem.eql(u8, name, "map")) return "## `(map fn lst)`\n\nApply function to each element.\n\n**Example:**\n```lispium\n(map (lambda (x) (* x 2)) (list 1 2 3)) ; => (2 4 6)\n```";
    if (std.mem.eql(u8, name, "filter")) return "## `(filter fn lst)`\n\nKeep elements where function returns true.\n\n**Example:**\n```lispium\n(filter (lambda (x) (> x 2)) (list 1 2 3 4)) ; => (3 4)\n```";
    if (std.mem.eql(u8, name, "reduce")) return "## `(reduce fn init lst)`\n\nFold list with function.\n\n**Example:**\n```lispium\n(reduce + 0 (list 1 2 3 4)) ; => 10\n```";
    if (std.mem.eql(u8, name, "range")) return "## `(range n)` or `(range start end [step])`\n\nGenerate number list.\n\n**Example:**\n```lispium\n(range 5)     ; => (0 1 2 3 4)\n(range 1 5)   ; => (1 2 3 4)\n(range 0 10 2) ; => (0 2 4 6 8)\n```";

    // Special forms
    if (std.mem.eql(u8, name, "define")) return "## `(define name value)` or `(define (name args) body)`\n\nDefine a variable or function.\n\n**Example:**\n```lispium\n(define pi 3.14159)\n(define (square x) (* x x))\n```";
    if (std.mem.eql(u8, name, "lambda")) return "## `(lambda (args) body)`\n\nCreate anonymous function.\n\n**Example:**\n```lispium\n((lambda (x) (* x x)) 5) ; => 25\n```";
    if (std.mem.eql(u8, name, "let")) return "## `(let ((var val) ...) body)`\n\nLocal bindings.\n\n**Example:**\n```lispium\n(let ((a 3) (b 4)) (+ a b)) ; => 7\n```";
    if (std.mem.eql(u8, name, "letrec")) return "## `(letrec ((var val) ...) body)`\n\nRecursive bindings - allows functions to call themselves.\n\n**Example:**\n```lispium\n(letrec ((fact (lambda (n)\n  (if (= n 0) 1 (* n (fact (- n 1)))))))\n  (fact 5)) ; => 120\n```";
    if (std.mem.eql(u8, name, "if")) return "## `(if cond then [else])`\n\nConditional expression.\n\n**Example:**\n```lispium\n(if (> x 0) x (- x)) ; absolute value\n```";
    if (std.mem.eql(u8, name, "sum")) return "## `(sum var start end body)`\n\nSummation notation.\n\n**Example:**\n```lispium\n(sum i 1 5 i)       ; => 15\n(sum i 1 5 (* i i)) ; => 55\n```";
    if (std.mem.eql(u8, name, "product")) return "## `(product var start end body)`\n\nProduct notation.\n\n**Example:**\n```lispium\n(product i 1 5 i) ; => 120 (5!)\n```";

    // Assumptions
    if (std.mem.eql(u8, name, "assume")) return "## `(assume var property)`\n\nSet assumption on variable.\n\n**Properties:** positive, negative, nonzero, integer, real, even, odd\n\n**Example:**\n```lispium\n(assume x positive)\n```";
    if (std.mem.eql(u8, name, "is?")) return "## `(is? var property)`\n\nCheck if assumption holds.\n\n**Example:**\n```lispium\n(assume x positive)\n(is? x positive) ; => 1\n```";

    // Plotting
    if (std.mem.eql(u8, name, "plot-ascii")) return "## `(plot-ascii expr xmin xmax [height width])`\n\nASCII plot of expression.\n\n**Example:**\n```lispium\n(plot-ascii (sin x) -3.14 3.14)\n```";
    if (std.mem.eql(u8, name, "plot-svg")) return "## `(plot-svg expr xmin xmax [height width])`\n\nSVG plot of expression.";

    // LaTeX
    if (std.mem.eql(u8, name, "latex")) return "## `(latex expr)`\n\nConvert expression to LaTeX string.\n\n**Example:**\n```lispium\n(latex (/ (^ x 2) 2)) ; => \"\\\\frac{x^{2}}{2}\"\n```";

    // Rewrite
    if (std.mem.eql(u8, name, "rule")) return "## `(rule pattern replacement)`\n\nDefine rewrite rule with pattern variables (?x, ?y, etc).\n\n**Example:**\n```lispium\n(rule (double ?x) (* 2 ?x))\n```";
    if (std.mem.eql(u8, name, "rewrite")) return "## `(rewrite expr)`\n\nApply all defined rules to expression.\n\n**Example:**\n```lispium\n(rule (double ?x) (* 2 ?x))\n(rewrite (double 5)) ; => (* 2 5)\n```";

    return null;
}
