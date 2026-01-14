const std = @import("std");
const build_options = @import("build_options");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Expr = @import("parser.zig").Expr;
const eval = @import("evaluator.zig").eval;
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");

const version = build_options.version;

const help_text =
    \\Lispium - A Symbolic Computer Algebra System
    \\
    \\Arithmetic:     (+ a b ...)  (- a b ...)  (* a b ...)  (/ a b)  (^ a b)
    \\Transcendental: (sin x)  (cos x)  (tan x)  (exp x)  (ln x)  (log x)  (sqrt x)
    \\Calculus:       (diff expr var)        - differentiate
    \\                (diff expr var n)      - nth derivative
    \\                (integrate expr var)   - indefinite integral
    \\                (taylor expr var pt n) - Taylor series
    \\Algebra:        (simplify expr)        - simplify
    \\                (expand expr)          - expand products
    \\                (solve expr var)       - solve equation
    \\                (factor expr)          - factor polynomial
    \\                (collect expr var)     - collect like terms
    \\                (substitute expr v e)  - substitute
    \\Linear Alg:     (matrix (a b) (c d))   - create matrix
    \\                (det M) (inv M)        - determinant, inverse
    \\                (matmul A B)           - matrix multiply
    \\                (eigenvalues M)        - eigenvalues
    \\                (linsolve A b)         - solve Ax=b
    \\Vectors:        (vector x y z)         - create vector
    \\                (dot v1 v2)            - dot product
    \\                (cross v1 v2)          - cross product
    \\Complex:        (complex re im)        - complex number
    \\                (real z) (imag z)      - parts
    \\Boolean:        (and a b) (or a b)     - logic
    \\                (not a) (xor a b)
    \\Modular:        (mod a b) (gcd a b)    - modular arithmetic
    \\                (modpow base exp mod)
    \\Polynomials:    (coeffs a b c)         - coefficient list
    \\                (polydiv p1 p2 x)      - division
    \\                (polygcd p1 p2)        - GCD
    \\Assumptions:    (assume x positive)    - set assumption
    \\                (is? x positive)       - check assumption
    \\
    \\Examples:
    \\  (+ 1 2 3)                 => 6
    \\  (diff (^ x 3) x)          => 3x²
    \\  (solve (- (^ x 2) 4) x)   => {2, -2}
    \\  (det (matrix (1 2) (3 4)))=> -2
    \\
    \\Tips:
    \\  - Type 'complete <partial>' for function name completions
    \\  - Type ?function for help on a specific function (e.g., ?diff)
    \\  - Multi-line input: expressions continue until parens are balanced
    \\
    \\Type 'help' for this message, 'quit' or Ctrl+D to exit.
;

/// List of all builtin function names for completion and help
const builtin_names = [_][]const u8{
    // Arithmetic
    "+", "-", "*", "/", "^", "pow",
    // Algebra
    "simplify", "diff", "integrate", "expand", "substitute", "taylor", "solve", "factor",
    "partial-fractions", "collect", "limit",
    // Trigonometric
    "sin", "cos", "tan", "asin", "acos", "atan", "atan2",
    // Hyperbolic
    "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
    // Transcendental
    "exp", "ln", "log", "sqrt",
    // Complex
    "complex", "real", "imag", "conj", "magnitude", "arg",
    // Rewrite
    "rule", "rewrite",
    // Matrix
    "matrix", "det", "transpose", "trace", "matmul", "inv", "eigenvalues", "eigenvectors",
    "linsolve", "lu", "charpoly",
    // Vector
    "vector", "dot", "cross", "norm",
    // Vector calculus
    "gradient", "grad", "divergence", "curl", "laplacian",
    // Boolean
    "and", "or", "not", "xor", "implies",
    // Modular
    "mod", "gcd", "lcm", "modpow",
    // Polynomial
    "coeffs", "polydiv", "polygcd", "polylcm", "roots", "discriminant",
    // Assumptions
    "assume", "is?",
    // Comparisons
    "=", "<", ">",
    // Special functions
    "gamma", "beta", "erf", "erfc", "besselj", "bessely", "digamma",
    // Differential equations
    "dsolve",
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
    // List operations
    "car", "cdr", "cons", "list", "length", "nth", "map", "filter", "reduce",
    "append", "reverse", "range",
    // Memoization
    "memoize", "memo-clear", "memo-stats",
    // Plotting
    "plot-ascii", "plot-svg", "plot-points",
    // Step-by-step
    "diff-steps", "integrate-steps", "simplify-steps", "solve-steps",
    // Combinatorics
    "factorial", "!", "binomial", "choose", "permutations", "combinations",
    // Number theory
    "prime?", "factorize", "totient", "extgcd", "crt",
    // Statistics
    "mean", "variance", "stddev", "median", "min", "max",
    // Quaternions
    "quat", "quat+", "quat*", "quat-conj", "quat-norm", "quat-inv", "quat-scalar", "quat-vector",
    // Finite fields
    "gf", "gf+", "gf-", "gf*", "gf/", "gf^", "gf-inv", "gf-neg",
    // Export
    "latex",
    // Special forms (not builtins but useful to know)
    "define", "lambda", "let", "letrec", "if", "sum", "product",
};

/// Help text for specific functions
fn getFunctionHelp(name: []const u8) ?[]const u8 {
    // Arithmetic
    if (std.mem.eql(u8, name, "+")) return "(+ a b ...)  Addition - adds all arguments";
    if (std.mem.eql(u8, name, "-")) return "(- a b ...)  Subtraction - subtracts subsequent args from first";
    if (std.mem.eql(u8, name, "*")) return "(* a b ...)  Multiplication - multiplies all arguments";
    if (std.mem.eql(u8, name, "/")) return "(/ a b)      Division - divides a by b";
    if (std.mem.eql(u8, name, "^") or std.mem.eql(u8, name, "pow")) return "(^ base exp) Power - raises base to exponent";

    // Calculus
    if (std.mem.eql(u8, name, "diff")) return "(diff expr var [n])  Differentiate expr with respect to var, optionally n times\n  Example: (diff (^ x 3) x) => (* 3 (^ x 2))";
    if (std.mem.eql(u8, name, "integrate")) return "(integrate expr var [a b])  Integrate expr with respect to var\n  Indefinite: (integrate (^ x 2) x) => (/ (^ x 3) 3)\n  Definite:   (integrate (^ x 2) x 0 1) => 0.333...";
    if (std.mem.eql(u8, name, "taylor")) return "(taylor expr var point order)  Taylor series expansion\n  Example: (taylor (exp x) x 0 4) => (+ 1 x (/ (^ x 2) 2) ...)";
    if (std.mem.eql(u8, name, "limit")) return "(limit expr var point)  Compute limit using L'Hopital's rule\n  Example: (limit (/ (sin x) x) x 0) => 1";

    // Algebra
    if (std.mem.eql(u8, name, "simplify")) return "(simplify expr)  Algebraic simplification\n  Example: (simplify (+ x x)) => (* 2 x)";
    if (std.mem.eql(u8, name, "expand")) return "(expand expr)  Expand products and powers\n  Example: (expand (^ (+ x 1) 2)) => (+ (^ x 2) (* 2 x) 1)";
    if (std.mem.eql(u8, name, "solve")) return "(solve expr var)  Solve equation expr=0 for var\n  Example: (solve (+ (^ x 2) (* -4 1)) x) => (solutions 2 -2)";
    if (std.mem.eql(u8, name, "factor")) return "(factor expr var)  Factor polynomial in var\n  Example: (factor (+ (^ x 2) (* -1 1)) x) => (* (- x 1) (+ x 1))";
    if (std.mem.eql(u8, name, "substitute")) return "(substitute expr var value)  Replace var with value in expr\n  Example: (substitute (+ x y) x 3) => (+ 3 y)";
    if (std.mem.eql(u8, name, "collect")) return "(collect expr var)  Collect like terms in var\n  Example: (collect (+ (* 2 x) (* 3 x) 5) x) => (+ (* 5 x) 5)";

    // Trig
    if (std.mem.eql(u8, name, "sin")) return "(sin x)  Sine function";
    if (std.mem.eql(u8, name, "cos")) return "(cos x)  Cosine function";
    if (std.mem.eql(u8, name, "tan")) return "(tan x)  Tangent function";
    if (std.mem.eql(u8, name, "asin")) return "(asin x)  Arc sine (inverse sine), returns radians";
    if (std.mem.eql(u8, name, "acos")) return "(acos x)  Arc cosine (inverse cosine), returns radians";
    if (std.mem.eql(u8, name, "atan")) return "(atan x)  Arc tangent (inverse tangent), returns radians";
    if (std.mem.eql(u8, name, "atan2")) return "(atan2 y x)  Two-argument arc tangent";

    // Hyperbolic
    if (std.mem.eql(u8, name, "sinh")) return "(sinh x)  Hyperbolic sine";
    if (std.mem.eql(u8, name, "cosh")) return "(cosh x)  Hyperbolic cosine";
    if (std.mem.eql(u8, name, "tanh")) return "(tanh x)  Hyperbolic tangent";

    // Transcendental
    if (std.mem.eql(u8, name, "exp")) return "(exp x)  Exponential function e^x";
    if (std.mem.eql(u8, name, "ln")) return "(ln x)  Natural logarithm (base e)";
    if (std.mem.eql(u8, name, "log")) return "(log x [base])  Logarithm, default base e\n  Example: (log 100 10) => 2";
    if (std.mem.eql(u8, name, "sqrt")) return "(sqrt x)  Square root, equivalent to (^ x 0.5)";

    // Complex
    if (std.mem.eql(u8, name, "complex")) return "(complex re im)  Create complex number re + im*i\n  Example: (complex 3 4) => 3 + 4i";
    if (std.mem.eql(u8, name, "real")) return "(real z)  Real part of complex number";
    if (std.mem.eql(u8, name, "imag")) return "(imag z)  Imaginary part of complex number";
    if (std.mem.eql(u8, name, "conj")) return "(conj z)  Complex conjugate";
    if (std.mem.eql(u8, name, "magnitude")) return "(magnitude z)  Absolute value |z| of complex number";
    if (std.mem.eql(u8, name, "arg")) return "(arg z)  Argument (angle) of complex number in radians";

    // Matrix
    if (std.mem.eql(u8, name, "matrix")) return "(matrix (row1) (row2) ...)  Create matrix from rows\n  Example: (matrix (1 2) (3 4)) => 2x2 matrix";
    if (std.mem.eql(u8, name, "det")) return "(det M)  Determinant of matrix M";
    if (std.mem.eql(u8, name, "inv")) return "(inv M)  Inverse of matrix M";
    if (std.mem.eql(u8, name, "transpose")) return "(transpose M)  Transpose of matrix M";
    if (std.mem.eql(u8, name, "matmul")) return "(matmul A B)  Matrix multiplication A * B";
    if (std.mem.eql(u8, name, "eigenvalues")) return "(eigenvalues M)  Eigenvalues of 2x2 matrix M";
    if (std.mem.eql(u8, name, "linsolve")) return "(linsolve A b)  Solve linear system Ax = b";

    // Vector
    if (std.mem.eql(u8, name, "vector")) return "(vector x y z ...)  Create vector\n  Example: (vector 1 2 3) => ⟨1, 2, 3⟩";
    if (std.mem.eql(u8, name, "dot")) return "(dot v1 v2)  Dot product of vectors";
    if (std.mem.eql(u8, name, "cross")) return "(cross v1 v2)  Cross product of 3D vectors";
    if (std.mem.eql(u8, name, "norm")) return "(norm v)  Euclidean norm (length) of vector";

    // Vector calculus
    if (std.mem.eql(u8, name, "gradient") or std.mem.eql(u8, name, "grad")) return "(gradient f vars)  Gradient of scalar field f\n  Example: (gradient (+ (^ x 2) (^ y 2)) (vector x y))";
    if (std.mem.eql(u8, name, "divergence")) return "(divergence F vars)  Divergence of vector field F";
    if (std.mem.eql(u8, name, "curl")) return "(curl F vars)  Curl of 3D vector field F";
    if (std.mem.eql(u8, name, "laplacian")) return "(laplacian f vars)  Laplacian of scalar field f";

    // Rewrite rules
    if (std.mem.eql(u8, name, "rule")) return "(rule pattern replacement)  Define rewrite rule with ?vars\n  Example: (rule (double ?x) (* 2 ?x))";
    if (std.mem.eql(u8, name, "rewrite")) return "(rewrite expr)  Apply all defined rules to expr";

    // Special forms
    if (std.mem.eql(u8, name, "define")) return "(define name value) or (define (name args) body)\n  Define a variable or function\n  Example: (define (square x) (* x x))";
    if (std.mem.eql(u8, name, "lambda")) return "(lambda (args) body)  Create anonymous function\n  Example: ((lambda (x) (* x x)) 5) => 25";
    if (std.mem.eql(u8, name, "let")) return "(let ((var val) ...) body)  Local bindings\n  Example: (let ((a 3) (b 4)) (+ a b)) => 7";
    if (std.mem.eql(u8, name, "if")) return "(if cond then [else])  Conditional\n  Example: (if (> x 0) x (- x))";
    if (std.mem.eql(u8, name, "sum")) return "(sum var start end body)  Summation\n  Example: (sum i 1 5 i) => 15";
    if (std.mem.eql(u8, name, "product")) return "(product var start end body)  Product notation\n  Example: (product i 1 5 i) => 120";

    // List operations
    if (std.mem.eql(u8, name, "list")) return "(list a b c ...)  Create a list";
    if (std.mem.eql(u8, name, "car")) return "(car lst)  First element of list";
    if (std.mem.eql(u8, name, "cdr")) return "(cdr lst)  Rest of list (all but first)";
    if (std.mem.eql(u8, name, "map")) return "(map fn lst)  Apply fn to each element\n  Example: (map (lambda (x) (* x 2)) (list 1 2 3))";
    if (std.mem.eql(u8, name, "filter")) return "(filter fn lst)  Keep elements where fn returns true";
    if (std.mem.eql(u8, name, "reduce")) return "(reduce fn init lst)  Fold list with fn";
    if (std.mem.eql(u8, name, "range")) return "(range n) or (range start end [step])  Generate number list";

    // Plotting
    if (std.mem.eql(u8, name, "plot-ascii")) return "(plot-ascii expr xmin xmax [height width])  ASCII plot of expr";
    if (std.mem.eql(u8, name, "plot-svg")) return "(plot-svg expr xmin xmax [height width])  SVG plot of expr";

    // Assumptions
    if (std.mem.eql(u8, name, "assume")) return "(assume var property)  Set assumption on variable\n  Properties: positive, negative, nonzero, integer, real, even, odd";
    if (std.mem.eql(u8, name, "is?")) return "(is? var property)  Check if assumption holds";

    // Export
    if (std.mem.eql(u8, name, "latex")) return "(latex expr)  Convert expression to LaTeX string";

    return null;
}

/// Count parentheses to determine if expression is complete
fn countParens(input: []const u8) i32 {
    var depth: i32 = 0;
    var in_string = false;
    for (input) |c| {
        if (c == '"') in_string = !in_string;
        if (!in_string) {
            if (c == '(') depth += 1;
            if (c == ')') depth -= 1;
        }
    }
    return depth;
}

/// Find completions for a partial function name
fn findCompletions(partial: []const u8, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var completions: std.ArrayList([]const u8) = .empty;
    for (builtin_names) |name| {
        if (partial.len == 0 or std.mem.startsWith(u8, name, partial)) {
            try completions.append(allocator, name);
        }
    }
    return completions;
}

/// Extract the current word being typed (for completion)
fn getCurrentWord(input: []const u8) []const u8 {
    if (input.len == 0) return "";

    // Find the start of the current word (after '(' or space)
    var start: usize = input.len;
    var i: usize = input.len;
    while (i > 0) {
        i -= 1;
        const c = input[i];
        if (c == '(' or c == ' ' or c == '\t') {
            start = i + 1;
            break;
        }
        if (i == 0) {
            start = 0;
        }
    }

    return input[start..];
}

pub fn run(allocator: std.mem.Allocator) !void {
    var env = Env.init(allocator);
    defer env.deinit();

    // Initialize builtins
    try env.putBuiltin("+", builtins.builtin_add);
    try env.putBuiltin("-", builtins.builtin_subtract);
    try env.putBuiltin("*", builtins.builtin_multiply);
    try env.putBuiltin("/", builtins.builtin_divide);
    try env.putBuiltin("^", builtins.builtin_power);
    try env.putBuiltin("pow", builtins.builtin_power);
    try env.putBuiltin("simplify", builtins.builtin_simplify);
    try env.putBuiltin("evalf", builtins.builtin_evalf);
    try env.putBuiltin("N", builtins.builtin_evalf);
    try env.putBuiltin("diff", builtins.builtin_diff);
    try env.putBuiltin("integrate", builtins.builtin_integrate);
    try env.putBuiltin("expand", builtins.builtin_expand);
    try env.putBuiltin("sin", builtins.builtin_sin);
    try env.putBuiltin("cos", builtins.builtin_cos);
    try env.putBuiltin("tan", builtins.builtin_tan);
    try env.putBuiltin("asin", builtins.builtin_asin);
    try env.putBuiltin("acos", builtins.builtin_acos);
    try env.putBuiltin("atan", builtins.builtin_atan);
    try env.putBuiltin("atan2", builtins.builtin_atan2);
    try env.putBuiltin("sinh", builtins.builtin_sinh);
    try env.putBuiltin("cosh", builtins.builtin_cosh);
    try env.putBuiltin("tanh", builtins.builtin_tanh);
    try env.putBuiltin("asinh", builtins.builtin_asinh);
    try env.putBuiltin("acosh", builtins.builtin_acosh);
    try env.putBuiltin("atanh", builtins.builtin_atanh);
    try env.putBuiltin("exp", builtins.builtin_exp);
    try env.putBuiltin("ln", builtins.builtin_ln);
    try env.putBuiltin("log", builtins.builtin_log);
    try env.putBuiltin("sqrt", builtins.builtin_sqrt);
    try env.putBuiltin("substitute", builtins.builtin_substitute);
    try env.putBuiltin("taylor", builtins.builtin_taylor);
    try env.putBuiltin("solve", builtins.builtin_solve);
    try env.putBuiltin("complex", builtins.builtin_complex);
    try env.putBuiltin("real", builtins.builtin_real);
    try env.putBuiltin("imag", builtins.builtin_imag);
    try env.putBuiltin("conj", builtins.builtin_conj);
    try env.putBuiltin("magnitude", builtins.builtin_abs_complex);
    try env.putBuiltin("arg", builtins.builtin_arg);
    try env.putBuiltin("limit", builtins.builtin_limit);
    try env.putBuiltin("rule", builtins.builtin_rule);
    try env.putBuiltin("rewrite", builtins.builtin_rewrite);
    try env.putBuiltin("factor", builtins.builtin_factor);
    try env.putBuiltin("partial-fractions", builtins.builtin_partial_fractions);
    try env.putBuiltin("collect", builtins.builtin_collect);
    // Matrix operations
    try env.putBuiltin("matrix", builtins.builtin_matrix);
    try env.putBuiltin("det", builtins.builtin_det);
    try env.putBuiltin("transpose", builtins.builtin_transpose);
    try env.putBuiltin("trace", builtins.builtin_trace);
    try env.putBuiltin("matmul", builtins.builtin_matmul);
    try env.putBuiltin("inv", builtins.builtin_inv);
    try env.putBuiltin("eigenvalues", builtins.builtin_eigenvalues);
    try env.putBuiltin("eigenvectors", builtins.builtin_eigenvectors);
    try env.putBuiltin("linsolve", builtins.builtin_linsolve);
    // Vector operations
    try env.putBuiltin("vector", builtins.builtin_vector);
    try env.putBuiltin("dot", builtins.builtin_dot);
    try env.putBuiltin("cross", builtins.builtin_cross);
    try env.putBuiltin("norm", builtins.builtin_norm);
    // Boolean algebra
    try env.putBuiltin("and", builtins.builtin_and);
    try env.putBuiltin("or", builtins.builtin_or);
    try env.putBuiltin("not", builtins.builtin_not);
    try env.putBuiltin("xor", builtins.builtin_xor);
    try env.putBuiltin("implies", builtins.builtin_implies);
    // Modular arithmetic
    try env.putBuiltin("mod", builtins.builtin_mod);
    try env.putBuiltin("gcd", builtins.builtin_gcd);
    try env.putBuiltin("lcm", builtins.builtin_lcm);
    try env.putBuiltin("modpow", builtins.builtin_modpow);
    // Polynomial operations
    try env.putBuiltin("coeffs", builtins.builtin_coeffs);
    try env.putBuiltin("polydiv", builtins.builtin_polydiv);
    try env.putBuiltin("polygcd", builtins.builtin_polygcd);
    try env.putBuiltin("polylcm", builtins.builtin_polylcm);
    // Assumptions
    try env.putBuiltin("assume", builtins.builtin_assume);
    try env.putBuiltin("is?", builtins.builtin_is);
    // Comparisons
    try env.putBuiltin("=", builtins.builtin_eq);
    try env.putBuiltin("<", builtins.builtin_lt);
    try env.putBuiltin(">", builtins.builtin_gt);
    // Special functions
    try env.putBuiltin("gamma", builtins.builtin_gamma);
    try env.putBuiltin("beta", builtins.builtin_beta);
    try env.putBuiltin("erf", builtins.builtin_erf);
    try env.putBuiltin("erfc", builtins.builtin_erfc);
    try env.putBuiltin("besselj", builtins.builtin_besselj);
    try env.putBuiltin("bessely", builtins.builtin_bessely);
    try env.putBuiltin("digamma", builtins.builtin_digamma);
    // Differential equations
    try env.putBuiltin("dsolve", builtins.builtin_dsolve);
    // Fourier & Laplace transforms
    try env.putBuiltin("fourier", builtins.builtin_fourier);
    try env.putBuiltin("laplace", builtins.builtin_laplace);
    try env.putBuiltin("inv-laplace", builtins.builtin_inv_laplace);
    // Tensor operations
    try env.putBuiltin("tensor", builtins.builtin_tensor);
    try env.putBuiltin("tensor-rank", builtins.builtin_tensor_rank);
    try env.putBuiltin("tensor-contract", builtins.builtin_tensor_contract);
    try env.putBuiltin("tensor-product", builtins.builtin_tensor_product);
    // Polynomial interpolation
    try env.putBuiltin("lagrange", builtins.builtin_lagrange);
    try env.putBuiltin("newton-interp", builtins.builtin_newton_interp);
    // Numerical root finding
    try env.putBuiltin("newton-raphson", builtins.builtin_newton_raphson);
    try env.putBuiltin("bisection", builtins.builtin_bisection);
    // Continued fractions
    try env.putBuiltin("to-cf", builtins.builtin_to_cf);
    try env.putBuiltin("from-cf", builtins.builtin_from_cf);
    try env.putBuiltin("cf-convergent", builtins.builtin_cf_convergent);
    try env.putBuiltin("cf-rational", builtins.builtin_cf_rational);
    // List operations
    try env.putBuiltin("car", builtins.builtin_car);
    try env.putBuiltin("cdr", builtins.builtin_cdr);
    try env.putBuiltin("cons", builtins.builtin_cons);
    try env.putBuiltin("list", builtins.builtin_list_fn);
    try env.putBuiltin("length", builtins.builtin_length);
    try env.putBuiltin("nth", builtins.builtin_nth);
    try env.putBuiltin("map", builtins.builtin_map);
    try env.putBuiltin("filter", builtins.builtin_filter);
    try env.putBuiltin("reduce", builtins.builtin_reduce);
    try env.putBuiltin("append", builtins.builtin_append);
    try env.putBuiltin("reverse", builtins.builtin_reverse);
    try env.putBuiltin("range", builtins.builtin_range);

    // Memoization
    try env.putBuiltin("memoize", builtins.builtin_memoize);
    try env.putBuiltin("memo-clear", builtins.builtin_memo_clear);
    try env.putBuiltin("memo-stats", builtins.builtin_memo_stats);

    // Plotting
    try env.putBuiltin("plot-ascii", builtins.builtin_plot_ascii);
    try env.putBuiltin("plot-svg", builtins.builtin_plot_svg);
    try env.putBuiltin("plot-points", builtins.builtin_plot_points);

    // Step-by-step solutions
    try env.putBuiltin("diff-steps", builtins.builtin_diff_steps);
    try env.putBuiltin("integrate-steps", builtins.builtin_integrate_steps);
    try env.putBuiltin("simplify-steps", builtins.builtin_simplify_steps);
    try env.putBuiltin("solve-steps", builtins.builtin_solve_steps);

    const stdout_file = std.fs.File.stdout();
    const stdin_file = std.fs.File.stdin();
    const stdout = stdout_file.deprecatedWriter();
    const stdin = stdin_file.deprecatedReader();
    var line_buf = std.array_list.Managed(u8).init(allocator);
    defer line_buf.deinit();

    // Multi-line expression buffer
    var expr_buf = std.array_list.Managed(u8).init(allocator);
    defer expr_buf.deinit();

    // Print welcome message
    try stdout.print("Lispium {s} - Symbolic Computer Algebra System\n", .{version});
    try stdout.print("Type 'help' for commands, '?func' for function help, 'quit' to exit.\n\n", .{});

    while (true) {
        // Show different prompt for continuation lines
        if (expr_buf.items.len == 0) {
            try stdout.print("lispium> ", .{});
        } else {
            try stdout.print("      .. ", .{});
        }

        line_buf.clearRetainingCapacity();
        stdin.readUntilDelimiterArrayList(&line_buf, '\n', 1024 * 1024) catch |err| {
            if (err == error.EndOfStream) {
                try stdout.print("\nGoodbye!\n", .{});
                break;
            }
            return err;
        };

        // Trim whitespace from this line
        const line = std.mem.trim(u8, line_buf.items, " \t\r\n");

        // Handle empty line
        if (line.len == 0) {
            if (expr_buf.items.len == 0) {
                continue;
            }
            // In multiline mode, empty line is just continuation
            try expr_buf.append(' ');
            continue;
        }

        // Handle special commands (only on first line)
        if (expr_buf.items.len == 0) {
            if (std.mem.eql(u8, line, "help")) {
                try stdout.print("{s}\n", .{help_text});
                continue;
            }
            if (std.mem.eql(u8, line, "quit") or std.mem.eql(u8, line, "exit")) {
                try stdout.print("Goodbye!\n", .{});
                break;
            }

            // Handle ?function help queries
            if (line.len > 1 and line[0] == '?') {
                const func_name = line[1..];
                if (getFunctionHelp(func_name)) |help| {
                    try stdout.print("{s}\n", .{help});
                } else {
                    // Check if it's a valid function name
                    var found = false;
                    for (builtin_names) |name| {
                        if (std.mem.eql(u8, name, func_name)) {
                            found = true;
                            break;
                        }
                    }
                    if (found) {
                        try stdout.print("{s}: builtin function (no detailed help available)\n", .{func_name});
                    } else {
                        try stdout.print("Unknown function: {s}\n", .{func_name});
                        // Suggest similar names
                        const partial = func_name;
                        var suggestions = try findCompletions(partial, allocator);
                        defer suggestions.deinit(allocator);
                        if (suggestions.items.len > 0 and suggestions.items.len <= 10) {
                            try stdout.print("Did you mean: ", .{});
                            for (suggestions.items, 0..) |s, i| {
                                if (i > 0) try stdout.print(", ", .{});
                                try stdout.print("{s}", .{s});
                            }
                            try stdout.print("?\n", .{});
                        }
                    }
                }
                continue;
            }

            // Handle TAB completion request (user types partial name and TAB shows as special char)
            // For now, handle 'complete <partial>' command
            if (std.mem.startsWith(u8, line, "complete ")) {
                const partial = line[9..];
                var completions = try findCompletions(partial, allocator);
                defer completions.deinit(allocator);
                if (completions.items.len == 0) {
                    try stdout.print("No completions for '{s}'\n", .{partial});
                } else if (completions.items.len == 1) {
                    try stdout.print("{s}\n", .{completions.items[0]});
                } else {
                    for (completions.items) |c| {
                        try stdout.print("  {s}\n", .{c});
                    }
                }
                continue;
            }
        }

        // Append line to expression buffer
        if (expr_buf.items.len > 0) {
            try expr_buf.append(' ');
        }
        try expr_buf.appendSlice(line);

        // Check if expression is complete (balanced parens)
        const paren_depth = countParens(expr_buf.items);
        if (paren_depth > 0) {
            // Need more input
            continue;
        }

        // Expression complete, process it
        const input = std.mem.trim(u8, expr_buf.items, " \t\r\n");

        var tokenizer = Tokenizer.init(input);
        var tokens: std.ArrayList([]const u8) = .empty;
        defer tokens.deinit(allocator);

        while (true) {
            const tok = tokenizer.next();
            if (tok == null) break;
            try tokens.append(allocator, tok.?);
        }

        if (tokens.items.len == 0) {
            expr_buf.clearRetainingCapacity();
            continue;
        }

        var parser = Parser.init(allocator, tokens);
        const expr = parser.parseExpr() catch |err| {
            const err_msg = switch (err) {
                error.UnexpectedToken => "unexpected token in expression",
                error.UnexpectedEOF => "unexpected end of input (missing closing paren?)",
                error.OutOfMemory => "out of memory",
            };
            try stdout.print("Error: {s}\n", .{err_msg});
            expr_buf.clearRetainingCapacity();
            continue;
        };
        defer {
            expr.deinit(allocator);
            allocator.destroy(expr);
        }

        const result = eval(expr, &env) catch |err| {
            const err_msg = switch (err) {
                error.UnsupportedOperator => "unsupported operator",
                error.InvalidArgument => "invalid argument(s)",
                error.KeyNotFound => "unknown function or variable",
                error.OutOfMemory => "out of memory",
                error.RecursionLimit => "recursion limit exceeded",
                error.InvalidLambda => "invalid lambda expression",
                error.InvalidDefine => "invalid define expression",
                error.WrongNumberOfArguments => "wrong number of arguments",
                error.EvaluationError => "evaluation error",
            };
            try stdout.print("Error: {s}\n", .{err_msg});
            expr_buf.clearRetainingCapacity();
            continue;
        };
        defer {
            result.deinit(allocator);
            allocator.destroy(result);
        }

        // Validate and print the result
        validateExpr(result) catch |err| {
            try stdout.print("Internal error: {}\n", .{err});
            expr_buf.clearRetainingCapacity();
            continue;
        };

        printExpr(result, stdout) catch |err| {
            try stdout.print("Display error: {}\n", .{err});
            expr_buf.clearRetainingCapacity();
            continue;
        };
        try stdout.print("\n", .{});
        expr_buf.clearRetainingCapacity();
    }
}

const PrintError = error{
    InvalidPointer,
    InvalidExpression,
    RecursionLimit,
    CyclicExpression,
    OutOfMemory,
} || std.fs.File.WriteError;

const MAX_VALIDATION_DEPTH = 1000;

fn validateExprInner(expr: *const Expr, visited: *std.AutoHashMap(usize, void), depth: usize) PrintError!void {
    if (depth > MAX_VALIDATION_DEPTH) {
        return PrintError.RecursionLimit;
    }

    const ptr_val = @intFromPtr(expr);
    if (ptr_val == 0 or ptr_val == std.math.maxInt(usize)) {
        return PrintError.InvalidPointer;
    }

    // Check for cycles
    if (visited.contains(ptr_val)) {
        return PrintError.CyclicExpression;
    }
    visited.put(ptr_val, {}) catch return PrintError.OutOfMemory;

    switch (expr.*) {
        .number => {},
        .symbol, .owned_symbol => {},
        .lambda => |lam| {
            const body_ptr = @intFromPtr(lam.body);
            if (body_ptr == 0 or body_ptr == std.math.maxInt(usize)) {
                return PrintError.InvalidPointer;
            }
            try validateExprInner(lam.body, visited, depth + 1);
        },
        .list => |lst| {
            if (lst.items.len > 0) {
                for (lst.items) |item| {
                    const item_ptr = @intFromPtr(item);
                    if (item_ptr == 0 or item_ptr == std.math.maxInt(usize)) {
                        return PrintError.InvalidPointer;
                    }
                    try validateExprInner(item, visited, depth + 1);
                }
            }
        },
    }
}

fn validateExpr(expr: *const Expr) PrintError!void {
    const ptr_val = @intFromPtr(expr);
    if (ptr_val == 0 or ptr_val == std.math.maxInt(usize)) {
        return PrintError.InvalidPointer;
    }
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var visited = std.AutoHashMap(usize, void).init(arena.allocator());
    errdefer visited.deinit();
    try validateExprInner(expr, &visited, 0);
}

fn printNum(n: f64, writer: anytype) !void {
    if (n == @floor(n) and @abs(n) < 1e15) {
        try writer.print("{d:.0}", .{n});
    } else {
        try writer.print("{d}", .{n});
    }
}

fn printExpr(expr: *const Expr, writer: anytype) PrintError!void {
    try printExprPretty(expr, writer, true);
}

fn printExprPretty(expr: *const Expr, writer: anytype, is_top: bool) PrintError!void {
    // Validate entire expression tree first
    if (is_top) {
        try validateExpr(expr);
    }

    switch (expr.*) {
        .number => |n| try printNum(n, writer),
        .symbol, .owned_symbol => |s| {
            // Use Greek letters for common symbols
            if (std.mem.eql(u8, s, "pi")) {
                try writer.print("\xcf\x80", .{}); // π
            } else if (std.mem.eql(u8, s, "e")) {
                try writer.print("e", .{});
            } else if (std.mem.eql(u8, s, "inf")) {
                try writer.print("\xe2\x88\x9e", .{}); // ∞
            } else {
                try writer.print("{s}", .{s});
            }
        },
        .lambda => |_| try writer.print("<lambda>", .{}),
        .list => |lst| {
            if (lst.items.len == 0) {
                try writer.print("()", .{});
                return;
            }

            // Get operator if it's a symbol
            const op = if (lst.items[0].* == .symbol) lst.items[0].symbol else null;

            // Complex number pretty printing
            if (op != null and std.mem.eql(u8, op.?, "complex") and lst.items.len == 3 and
                lst.items[1].* == .number and lst.items[2].* == .number)
            {
                try printComplex(lst.items[1].number, lst.items[2].number, writer);
                return;
            }

            // Vector pretty printing
            if (op != null and std.mem.eql(u8, op.?, "vector")) {
                try writer.print("\xe2\x9f\xa8", .{}); // ⟨
                for (lst.items[1..], 0..) |item, i| {
                    if (i > 0) try writer.print(", ", .{});
                    try printExprPretty(item, writer, false);
                }
                try writer.print("\xe2\x9f\xa9", .{}); // ⟩
                return;
            }

            // Matrix pretty printing (simplified - just show as rows)
            if (op != null and std.mem.eql(u8, op.?, "matrix")) {
                try writer.print("[", .{});
                for (lst.items[1..], 0..) |row, i| {
                    if (i > 0) try writer.print("; ", .{});
                    if (row.* == .list) {
                        for (row.list.items, 0..) |elem, j| {
                            if (j > 0) try writer.print(" ", .{});
                            try printExprPretty(elem, writer, false);
                        }
                    } else {
                        try printExprPretty(row, writer, false);
                    }
                }
                try writer.print("]", .{});
                return;
            }

            // Power with superscript for simple exponents
            if (op != null and std.mem.eql(u8, op.?, "^") and lst.items.len == 3) {
                try printExprPretty(lst.items[1], writer, false);
                if (lst.items[2].* == .number) {
                    const exp = lst.items[2].number;
                    if (exp == 2) {
                        try writer.print("\xc2\xb2", .{}); // ²
                        return;
                    } else if (exp == 3) {
                        try writer.print("\xc2\xb3", .{}); // ³
                        return;
                    }
                }
                try writer.print("^", .{});
                try printExprPretty(lst.items[2], writer, false);
                return;
            }

            // Square root
            if (op != null and std.mem.eql(u8, op.?, "sqrt") and lst.items.len == 2) {
                try writer.print("\xe2\x88\x9a(", .{}); // √
                try printExprPretty(lst.items[1], writer, false);
                try writer.print(")", .{});
                return;
            }

            // Infix operators: +, -, *, /
            if (op != null and (std.mem.eql(u8, op.?, "+") or std.mem.eql(u8, op.?, "-") or
                std.mem.eql(u8, op.?, "*") or std.mem.eql(u8, op.?, "/")))
            {
                const op_char = op.?;
                const op_sym = if (std.mem.eql(u8, op_char, "*"))
                    "\xc2\xb7" // ·
                else if (std.mem.eql(u8, op_char, "/"))
                    "/"
                else
                    op_char;

                try writer.print("(", .{});
                for (lst.items[1..], 0..) |item, i| {
                    if (i > 0) {
                        try writer.print(" {s} ", .{op_sym});
                    }
                    try printExprPretty(item, writer, false);
                }
                try writer.print(")", .{});
                return;
            }

            // Solutions list
            if (op != null and std.mem.eql(u8, op.?, "solutions")) {
                try writer.print("{{", .{});
                for (lst.items[1..], 0..) |item, i| {
                    if (i > 0) try writer.print(", ", .{});
                    try printExprPretty(item, writer, false);
                }
                try writer.print("}}", .{});
                return;
            }

            // Default: S-expression format
            try writer.print("(", .{});
            if (lst.items[0].* == .symbol) {
                try writer.print("{s}", .{lst.items[0].symbol});
            } else {
                try printExprPretty(lst.items[0], writer, false);
            }
            for (lst.items[1..]) |item| {
                try writer.print(" ", .{});
                try printExprPretty(item, writer, false);
            }
            try writer.print(")", .{});
        },
    }
}

fn printComplex(real: f64, imag: f64, writer: anytype) !void {
    if (real == 0 and imag == 0) {
        try writer.print("0", .{});
    } else if (real == 0) {
        if (imag == 1) {
            try writer.print("i", .{});
        } else if (imag == -1) {
            try writer.print("-i", .{});
        } else {
            try printNum(imag, writer);
            try writer.print("i", .{});
        }
    } else if (imag == 0) {
        try printNum(real, writer);
    } else {
        try printNum(real, writer);
        if (imag > 0) {
            if (imag == 1) {
                try writer.print(" + i", .{});
            } else {
                try writer.print(" + ", .{});
                try printNum(imag, writer);
                try writer.print("i", .{});
            }
        } else {
            if (imag == -1) {
                try writer.print(" - i", .{});
            } else {
                try writer.print(" - ", .{});
                try printNum(-imag, writer);
                try writer.print("i", .{});
            }
        }
    }
}
