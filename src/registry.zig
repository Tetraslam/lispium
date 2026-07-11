//! Single source of truth for builtin function registration.
//! Used by the CLI evaluator, file runner, REPL, LSP, and tests.
const std = @import("std");
const Env = @import("environment.zig").Env;
const builtins = @import("builtins.zig");

pub fn installBuiltins(env: *Env) !void {
    // Arithmetic
    try env.putBuiltin("+", builtins.builtin_add);
    try env.putBuiltin("-", builtins.builtin_subtract);
    try env.putBuiltin("*", builtins.builtin_multiply);
    try env.putBuiltin("/", builtins.builtin_divide);
    try env.putBuiltin("^", builtins.builtin_power);
    try env.putBuiltin("pow", builtins.builtin_power);
    try env.putBuiltin("abs", builtins.builtin_abs);
    try env.putBuiltin("floor", builtins.builtin_floor);
    try env.putBuiltin("ceil", builtins.builtin_ceil);
    try env.putBuiltin("round", builtins.builtin_round);
    try env.putBuiltin("sign", builtins.builtin_sign);
    try env.putBuiltin("numer", builtins.builtin_numer);
    try env.putBuiltin("denom", builtins.builtin_denom);

    // Strings
    try env.putBuiltin("concat", builtins.builtin_concat);
    try env.putBuiltin("substring", builtins.builtin_substring);
    try env.putBuiltin("string->number", builtins.builtin_string_to_number);
    try env.putBuiltin("number->string", builtins.builtin_number_to_string);
    try env.putBuiltin("split", builtins.builtin_split);

    // I/O
    try env.putBuiltin("print", builtins.builtin_print);
    try env.putBuiltin("read", builtins.builtin_read);

    // Type predicates and program structure
    try env.putBuiltin("number?", builtins.builtin_is_number);
    try env.putBuiltin("integer?", builtins.builtin_is_integer);
    try env.putBuiltin("rational?", builtins.builtin_is_rational);
    try env.putBuiltin("symbol?", builtins.builtin_is_symbol);
    try env.putBuiltin("string?", builtins.builtin_is_string);
    try env.putBuiltin("list?", builtins.builtin_is_list);
    try env.putBuiltin("lambda?", builtins.builtin_is_lambda);
    try env.putBuiltin("null?", builtins.builtin_is_null);
    try env.putBuiltin("complex?", builtins.builtin_is_complex);
    try env.putBuiltin("apply", builtins.builtin_apply);
    try env.putBuiltin("error", builtins.builtin_error);
    try env.putBuiltin("assert", builtins.builtin_assert);
    try env.putBuiltin("load", builtins.builtin_load);
    try env.putBuiltin("args", builtins.builtin_args);
    try env.putBuiltin("exit", builtins.builtin_exit);
    try env.putBuiltin("random", builtins.builtin_random);
    try env.putBuiltin("random-seed", builtins.builtin_random_seed);
    try env.putBuiltin("sort", builtins.builtin_sort);
    try env.putBuiltin("assoc", builtins.builtin_assoc);
    try env.putBuiltin("unit", builtins.builtin_unit);

    // Algebra
    try env.putBuiltin("simplify", builtins.builtin_simplify);
    try env.putBuiltin("evalf", builtins.builtin_evalf);
    try env.putBuiltin("N", builtins.builtin_evalf);
    try env.putBuiltin("diff", builtins.builtin_diff);
    try env.putBuiltin("integrate", builtins.builtin_integrate);
    try env.putBuiltin("expand", builtins.builtin_expand);
    try env.putBuiltin("substitute", builtins.builtin_substitute);
    try env.putBuiltin("taylor", builtins.builtin_taylor);
    try env.putBuiltin("solve", builtins.builtin_solve);
    try env.putBuiltin("factor", builtins.builtin_factor);
    try env.putBuiltin("partial-fractions", builtins.builtin_partial_fractions);
    try env.putBuiltin("collect", builtins.builtin_collect);
    try env.putBuiltin("limit", builtins.builtin_limit);

    // Trigonometric
    try env.putBuiltin("sin", builtins.builtin_sin);
    try env.putBuiltin("cos", builtins.builtin_cos);
    try env.putBuiltin("tan", builtins.builtin_tan);
    try env.putBuiltin("asin", builtins.builtin_asin);
    try env.putBuiltin("acos", builtins.builtin_acos);
    try env.putBuiltin("atan", builtins.builtin_atan);
    try env.putBuiltin("atan2", builtins.builtin_atan2);

    // Hyperbolic
    try env.putBuiltin("sinh", builtins.builtin_sinh);
    try env.putBuiltin("cosh", builtins.builtin_cosh);
    try env.putBuiltin("tanh", builtins.builtin_tanh);
    try env.putBuiltin("asinh", builtins.builtin_asinh);
    try env.putBuiltin("acosh", builtins.builtin_acosh);
    try env.putBuiltin("atanh", builtins.builtin_atanh);

    // Transcendental
    try env.putBuiltin("exp", builtins.builtin_exp);
    try env.putBuiltin("ln", builtins.builtin_ln);
    try env.putBuiltin("log", builtins.builtin_log);
    try env.putBuiltin("sqrt", builtins.builtin_sqrt);

    // Complex numbers
    try env.putBuiltin("complex", builtins.builtin_complex);
    try env.putBuiltin("real", builtins.builtin_real);
    try env.putBuiltin("imag", builtins.builtin_imag);
    try env.putBuiltin("conj", builtins.builtin_conj);
    try env.putBuiltin("magnitude", builtins.builtin_abs_complex);
    try env.putBuiltin("arg", builtins.builtin_arg);

    // Pattern rewriting
    try env.putBuiltin("rule", builtins.builtin_rule);
    try env.putBuiltin("rewrite", builtins.builtin_rewrite);

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
    try env.putBuiltin("lu", builtins.builtin_lu);
    try env.putBuiltin("charpoly", builtins.builtin_charpoly);

    // Vector operations
    try env.putBuiltin("vector", builtins.builtin_vector);
    try env.putBuiltin("dot", builtins.builtin_dot);
    try env.putBuiltin("cross", builtins.builtin_cross);
    try env.putBuiltin("norm", builtins.builtin_norm);

    // Vector calculus
    try env.putBuiltin("gradient", builtins.builtin_gradient);
    try env.putBuiltin("grad", builtins.builtin_gradient);
    try env.putBuiltin("divergence", builtins.builtin_divergence);
    try env.putBuiltin("curl", builtins.builtin_curl);
    try env.putBuiltin("laplacian", builtins.builtin_laplacian);

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

    // Number theory
    try env.putBuiltin("prime?", builtins.builtin_prime);
    try env.putBuiltin("factorize", builtins.builtin_factorize);
    try env.putBuiltin("totient", builtins.builtin_totient);
    try env.putBuiltin("extgcd", builtins.builtin_extgcd);
    try env.putBuiltin("crt", builtins.builtin_crt);

    // Combinatorics
    try env.putBuiltin("factorial", builtins.builtin_factorial);
    try env.putBuiltin("!", builtins.builtin_factorial);
    try env.putBuiltin("binomial", builtins.builtin_binomial);
    try env.putBuiltin("choose", builtins.builtin_binomial);
    try env.putBuiltin("permutations", builtins.builtin_permutations);
    try env.putBuiltin("combinations", builtins.builtin_combinations);

    // Statistics
    try env.putBuiltin("mean", builtins.builtin_mean);
    try env.putBuiltin("variance", builtins.builtin_variance);
    try env.putBuiltin("stddev", builtins.builtin_stddev);
    try env.putBuiltin("median", builtins.builtin_median);
    try env.putBuiltin("min", builtins.builtin_min);
    try env.putBuiltin("max", builtins.builtin_max);

    // Polynomial operations
    try env.putBuiltin("coeffs", builtins.builtin_coeffs);
    try env.putBuiltin("polydiv", builtins.builtin_polydiv);
    try env.putBuiltin("polygcd", builtins.builtin_polygcd);
    try env.putBuiltin("polylcm", builtins.builtin_polylcm);
    try env.putBuiltin("roots", builtins.builtin_roots);
    try env.putBuiltin("discriminant", builtins.builtin_discriminant);

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

    // Quaternions
    try env.putBuiltin("quat", builtins.builtin_quat);
    try env.putBuiltin("quat+", builtins.builtin_quat_add);
    try env.putBuiltin("quat*", builtins.builtin_quat_mul);
    try env.putBuiltin("quat-conj", builtins.builtin_quat_conj);
    try env.putBuiltin("quat-norm", builtins.builtin_quat_norm);
    try env.putBuiltin("quat-inv", builtins.builtin_quat_inv);
    try env.putBuiltin("quat-scalar", builtins.builtin_quat_scalar);
    try env.putBuiltin("quat-vector", builtins.builtin_quat_vector);

    // Finite fields
    try env.putBuiltin("gf", builtins.builtin_gf);
    try env.putBuiltin("gf+", builtins.builtin_gf_add);
    try env.putBuiltin("gf-", builtins.builtin_gf_sub);
    try env.putBuiltin("gf*", builtins.builtin_gf_mul);
    try env.putBuiltin("gf/", builtins.builtin_gf_div);
    try env.putBuiltin("gf^", builtins.builtin_gf_pow);
    try env.putBuiltin("gf-inv", builtins.builtin_gf_inv);
    try env.putBuiltin("gf-neg", builtins.builtin_gf_neg);

    // LaTeX export
    try env.putBuiltin("latex", builtins.builtin_latex);
}
