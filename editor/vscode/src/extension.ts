import * as path from 'path';
import * as fs from 'fs';
import { workspace, ExtensionContext, window } from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: ExtensionContext) {
    // Get the path to the lispium executable
    const config = workspace.getConfiguration('lispium');
    let serverPath = config.get<string>('server.path') || '';

    if (!serverPath) {
        // Try to find lispium in common locations
        const possiblePaths = [
            // In PATH (will be resolved by spawn)
            'lispium',
            // Common installation locations
            '/usr/local/bin/lispium',
            '/usr/bin/lispium',
            '/opt/homebrew/bin/lispium',
            // Windows
            'C:\\Program Files\\lispium\\lispium.exe',
            // Local development
            path.join(context.extensionPath, '..', '..', 'zig-out', 'bin', 'lispium'),
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
    client.start();

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
