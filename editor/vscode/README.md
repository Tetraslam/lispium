# Lispium VS Code Extension

Language support for [Lispium](https://github.com/Tetraslam/lispium) - A Symbolic Computer Algebra System.

## Features

- **Syntax Highlighting**: Full TextMate grammar for `.lspm` files
- **Hover Documentation**: View documentation for builtin functions on hover
- **Autocompletion**: Get suggestions for all Lispium builtins
- **Diagnostics**: Real-time error detection for unbalanced parentheses

## Requirements

- VS Code 1.85.0 or higher
- Lispium installed and available in your PATH (or configure the path in settings)

## Installation

### From VSIX

1. Download the `.vsix` file from the [releases page](https://github.com/Tetraslam/lispium/releases)
2. In VS Code, press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
3. Type "Install from VSIX" and select the command
4. Select the downloaded `.vsix` file

### Install Lispium

```bash
# macOS (Homebrew)
brew install Tetraslam/lispium/lispium

# Or download from releases
# https://github.com/Tetraslam/lispium/releases
```

## Extension Settings

| Setting | Description | Default |
|---------|-------------|---------|
| `lispium.server.path` | Path to the lispium executable | `""` (searches PATH) |
| `lispium.trace.server` | Trace LSP communication | `"off"` |

## Development

```bash
# Install dependencies
npm install

# Compile
npm run compile

# Package
npm run package
```

## License

MIT
