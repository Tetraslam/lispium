# Helix support for Lispium

Hover docs, completion, and parse diagnostics via `lispium lsp`, with
s-expression highlighting borrowed from the bundled tree-sitter scheme
grammar.

## Install

1. Make sure `lispium` is on your PATH (`uv tool install lispium`).
2. Merge `languages.toml` into `~/.config/helix/languages.toml`.
3. Copy the query files:

```bash
mkdir -p ~/.config/helix/runtime/queries/lispium
cp queries/lispium/*.scm ~/.config/helix/runtime/queries/lispium/
```

4. Verify: `hx --health lispium` (all queries should be green).

Open any `.lspm` file; `Space + k` shows hover docs, completion triggers on `(`.
Textobjects: `maf`/`mif` select around/inside `define`/`lambda` forms,
`]f`/`[f` jump between them, `]c`/`[c` between comments.
