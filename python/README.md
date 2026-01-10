# Lispium

A Symbolic Computer Algebra System written in Zig.

## Installation

```bash
pip install lispium
```

Or with uv:

```bash
uv pip install lispium
```

## Usage

After installation, the `lispium` command is available:

```bash
# Start the REPL
lispium repl

# Run a file
lispium run script.lspm

# Show version
lispium --version

# Show help
lispium --help
```

## Features

- **Symbolic Computation**: Work with symbolic expressions and variables
- **Calculus**: Differentiation, integration, Taylor series, limits
- **Linear Algebra**: Matrices, determinants, eigenvalues, linear systems
- **Algebra**: Polynomial operations, equation solving, factoring
- **Number Theory**: Prime testing, factorization, modular arithmetic
- **And much more**: Complex numbers, vectors, statistics, plotting

## Example

```lisp
; Differentiate x^3
(diff (^ x 3) x)  ; => (* 3 (^ x 2))

; Solve quadratic equation
(solve (- (^ x 2) 4) x)  ; => {2, -2}

; Matrix determinant
(det (matrix (1 2) (3 4)))  ; => -2
```

## Documentation

See the [GitHub repository](https://github.com/Tetraslam/lispium) for full documentation.

## License

MIT
