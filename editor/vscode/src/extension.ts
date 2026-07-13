import * as path from 'path';
import * as fs from 'fs';
import { execFile } from 'child_process';
import { workspace, ExtensionContext, window, commands, languages, CodeLens, Range, Position, TextDocument } from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: ExtensionContext) {
    const outputChannel = window.createOutputChannel('Lispium');
    outputChannel.appendLine('Lispium extension activating...');

    // Get the path to the lispium executable
    const config = workspace.getConfiguration('lispium');
    let serverPath = config.get<string>('server.path') || '';

    if (!serverPath) {
        // Try to find lispium in common locations
        const homeDir = process.env.HOME || process.env.USERPROFILE || '';
        const possiblePaths = [
            // User-local installations (pip install --user, etc.)
            path.join(homeDir, '.local', 'bin', 'lispium'),
            // Common installation locations
            '/usr/local/bin/lispium',
            '/usr/bin/lispium',
            '/opt/homebrew/bin/lispium',
            // Windows
            'C:\\Program Files\\lispium\\lispium.exe',
            path.join(homeDir, 'AppData', 'Local', 'Programs', 'lispium', 'lispium.exe'),
            // Local development
            path.join(context.extensionPath, '..', '..', 'zig-out', 'bin', 'lispium'),
            // Fallback to PATH lookup
            'lispium',
        ];

        for (const p of possiblePaths) {
            if (p === 'lispium') {
                // Just use 'lispium' and let the system find it
                serverPath = p;
                break;
            }
            try {
                if (fs.existsSync(p)) {
                    serverPath = p;
                    break;
                }
            } catch {
                // Ignore errors
            }
        }

        if (!serverPath) {
            serverPath = 'lispium'; // Fallback to PATH lookup
        }
    }

    outputChannel.appendLine(`Using server path: ${serverPath}`);

    // Server options - run lispium lsp
    const serverOptions: ServerOptions = {
        run: {
            command: serverPath,
            args: ['lsp'],
            transport: TransportKind.stdio
        },
        debug: {
            command: serverPath,
            args: ['lsp'],
            transport: TransportKind.stdio
        }
    };

    // Options to control the language client
    const clientOptions: LanguageClientOptions = {
        // Register the server for Lispium documents
        documentSelector: [{ scheme: 'file', language: 'lispium' }],
        synchronize: {
            // Notify the server about file changes to .lspm files
            fileEvents: workspace.createFileSystemWatcher('**/*.lspm')
        },
        outputChannelName: 'Lispium Language Server',
        traceOutputChannel: window.createOutputChannel('Lispium LSP Trace')
    };

    // Create the language client and start it
    client = new LanguageClient(
        'lispium',
        'Lispium Language Server',
        serverOptions,
        clientOptions
    );

    // Start the client. This will also launch the server
    outputChannel.appendLine('Starting language client...');
    client.start().then(() => {
        outputChannel.appendLine('Language client started successfully');
    }).catch((err) => {
        outputChannel.appendLine(`Language client failed to start: ${err}`);
        window.showErrorMessage(
            `Lispium language server failed to start (looked for '${serverPath}'). ` +
            `Install it with 'uv tool install lispium' or set 'lispium.server.path'.`
        );
    });

    // Restart command: handy after upgrading the lispium binary
    context.subscriptions.push(
        commands.registerCommand('lispium.restartServer', async () => {
            outputChannel.appendLine('Restarting language server...');
            await client.restart();
            outputChannel.appendLine('Language server restarted');
        })
    );

    // CodeLens: an "evaluate" action above each top-level form
    context.subscriptions.push(
        languages.registerCodeLensProvider({ language: 'lispium' }, {
            provideCodeLenses(document: TextDocument): CodeLens[] {
                const lenses: CodeLens[] = [];
                const text = document.getText();
                // Find top-level forms: '(' at column 0 through its match
                let depth = 0, start = -1, startLine = 0, line = 0;
                for (let i = 0; i < text.length; i++) {
                    const c = text[i];
                    if (c === '\n') { line++; continue; }
                    if (c === ';') { while (i < text.length && text[i] !== '\n') i++; line++; continue; }
                    if (c === '(') { if (depth === 0) { start = i; startLine = line; } depth++; }
                    if (c === ')') {
                        depth--;
                        if (depth === 0 && start >= 0) {
                            const form = text.slice(start, i + 1);
                            lenses.push(new CodeLens(
                                new Range(new Position(startLine, 0), new Position(startLine, 0)),
                                { title: '$(play) eval', command: 'lispium.evalForm', arguments: [form] }
                            ));
                            start = -1;
                        }
                    }
                }
                return lenses;
            }
        })
    );

    // Evaluate one form and show the result inline
    context.subscriptions.push(
        commands.registerCommand('lispium.evalForm', (form: string) => {
            execFile(serverPath, ['eval', form], { timeout: 15000 }, (err, stdout, stderr) => {
                const result = (stdout || stderr || (err ? err.message : '')).trim();
                const preview = form.length > 40 ? form.slice(0, 37) + '...' : form;
                window.showInformationMessage(`${preview}  =>  ${result.split('\n').pop()}`);
            });
        })
    );

    // Run the current .lspm file and show output
    const runChannel = window.createOutputChannel('Lispium Run');
    context.subscriptions.push(
        commands.registerCommand('lispium.runFile', async () => {
            const editor = window.activeTextEditor;
            if (!editor || !editor.document.fileName.endsWith('.lspm')) {
                window.showWarningMessage('Open a .lspm file to run it.');
                return;
            }
            await editor.document.save();
            const file = editor.document.fileName;
            runChannel.clear();
            runChannel.show(true);
            runChannel.appendLine(`$ lispium run ${file}`);
            execFile(serverPath, ['run', file], { timeout: 30000 }, (err, stdout, stderr) => {
                if (stdout) runChannel.append(stdout);
                if (stderr) runChannel.append(stderr);
                if (err && !stdout && !stderr) runChannel.appendLine(`error: ${err.message}`);
            });
        })
    );

    context.subscriptions.push({
        dispose: () => {
            if (client) {
                client.stop();
            }
        }
    });
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
