# Lispium Style

The canonical formatting style, as produced by `lispium fmt` (and
`textDocument/formatting` in the LSP). Line width is 80 columns,
indentation is 2 spaces, and the file ends with exactly one newline.

## Rules

**One line when it fits.** Any expression whose flat form fits within 80
columns stays on one line:

```lisp
(define (square x) (* x x))
```

**Special forms break header-first.** When `define`, `lambda`, `let`,
`letrec`, `if`, `rule`, `sum`, or `product` must break, the header stays on
the first line and the body indents two spaces:

```lisp
(define (magnitude-squared a b)
  (+ (* a a) (* b b)))

(letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1)))))))
  (fact 5))
```

Header sizes: `define`/`lambda`/`let`/`letrec`/`if`/`rule` keep one argument
inline (the signature, params, bindings, condition, or pattern);
`sum`/`product` keep three (variable and bounds).

**Bindings break one per line**, aligned with the first binding:

```lisp
(let ((a 1)
      (b 2)
      (c 3))
  (+ a b c))
```

**Function calls align under the first argument** when the head is short
(≤ 12 characters); longer heads indent every argument two spaces:

```lisp
(+ (* arg-one arg-one)
   (* arg-two arg-two))

(some-long-function-name
  first-argument
  (nested call))
```

**Atom-only argument lists fill.** When every argument is a plain atom,
arguments pack as many per line as fit instead of one per line:

```lisp
(coeffs 1 -3 2 5 -7 11 -13 17 -19 23
        29 -31 37)
```

**Comments.** Standalone comments keep their own line at the current
indentation and are normalized to `; text`. Trailing comments stay attached
to their expression with two spaces before the `;`:

```lisp
; compute the derivative
(diff (^ x 3) x)  ; => 3x^2
```

**Blank lines.** At most one blank line between top-level forms; none at
the start or end of the file.

## Tooling

```bash
lispium fmt file.lspm          # print formatted source to stdout
lispium fmt -w file.lspm ...   # rewrite files in place
lispium fmt --check file.lspm  # exit 1 if anything is unformatted (CI)
lispium fmt -w .               # directories recurse into their .lspm files
```

Editors get the same formatter through the LSP: `:format` in Helix,
Format Document (and format-on-save) in VS Code. The formatter is
idempotent and refuses to run on unbalanced input rather than guessing.
