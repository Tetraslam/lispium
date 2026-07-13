# Lispium

**A Rare Metal of Algebraic Power**

[![CI](https://github.com/Tetraslam/lispium/actions/workflows/ci.yml/badge.svg)](https://github.com/Tetraslam/lispium/actions/workflows/ci.yml)
[![PyPI](https://img.shields.io/pypi/v/lispium)](https://pypi.org/project/lispium/)

A symbolic computer algebra system in pure Zig. Zero dependencies.

**[Try it in the playground](https://tetraslam.github.io/lispium/playground/)** · **[Function reference](https://tetraslam.github.io/lispium/)** · [Cookbook](cookbook/)

## Install

```bash
pip install lispium
```

Or grab a binary from [releases](https://github.com/Tetraslam/lispium/releases) (Linux, macOS, Windows). Also on winget and the AUR (`lispium-bin`).

## Quick start

```bash
lispium repl
```

```lisp
> (diff (^ x 3) x)
3x²

> (solve (- (^ x 2) 4) x)
{2, -2}

> (+ 1/3 1/6)
1/2

> (factorial 25)
15511210043330985984000000

> (det (matrix (a b) (c d)))
ad - bc
```

## Highlights

- **Calculus** — derivatives, integrals, Taylor series, limits, ODEs, Laplace transforms
- **Algebra** — equation solving through quartics, factoring, partial fractions, rewrite rules
- **Linear algebra** — symbolic matrices, determinants, eigenvalues, LU decomposition
- **Exact arithmetic** — rationals (`1/3`), arbitrary-precision integers, complex numbers, units with dimensional analysis
- **A real Lisp** — closures, macros, tail calls, strings, quote/quasiquote, error handling
- **And more** — number theory, quaternions, finite fields, tensors, plotting, LaTeX export, step-by-step solutions

The [cookbook](cookbook/) has runnable examples for every area, and errors point at the failing subexpression (`file:line:col`, caret in the REPL, call stacks).

## Tooling

- `lispium run file.lspm` (`--watch`, `--time`, `--profile`), `lispium test`, `lispium fmt`
- REPL with line editing, persistent history, `?func` inline docs
- LSP (`lispium lsp`): hover, completion, diagnostics, rename — powers the [VS Code extension](https://marketplace.visualstudio.com/items?itemName=tetraslam.lispium)
- Jupyter kernel: `pip install lispium[jupyter]`, then `python -m lispium.kernel install`

## Development

```bash
zig build run -- repl   # build and run
zig build test          # 558 tests, 0 leaks
```

[CLAUDE.md](CLAUDE.md) documents every builtin and the architecture.
