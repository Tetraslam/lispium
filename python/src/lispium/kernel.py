"""Jupyter kernel for Lispium.

A thin wrapper that keeps one `lispium repl` subprocess alive per kernel
session, so definitions persist between cells. Install with:

    pip install lispium[jupyter]
    python -m lispium.kernel install

Then pick "Lispium" in Jupyter's kernel list.
"""

import subprocess
import sys

try:
    from ipykernel.kernelbase import Kernel
except ImportError:  # pragma: no cover
    Kernel = object

from .cli import get_binary_path

# Boundary marker: evaluating SENTINEL_EXPR makes the REPL echo the full
# sentinel string as a result line. The expression is split in two so the
# input text itself can never match.
SENTINEL = "--lispium-cell-done--"
SENTINEL_EXPR = '(concat "--lispium-" "cell-done--")' 


class LispiumKernel(Kernel):
    implementation = "lispium"
    implementation_version = "0.8.0"
    language = "lispium"
    language_version = "0.8.0"
    language_info = {
        "name": "lispium",
        "mimetype": "text/x-lispium",
        "file_extension": ".lspm",
        "pygments_lexer": "scheme",
        "codemirror_mode": "scheme",
    }
    banner = "Lispium - a symbolic computer algebra system"

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._proc = None

    def _ensure_proc(self):
        if self._proc is None or self._proc.poll() is not None:
            self._proc = subprocess.Popen(
                [str(get_binary_path()), "repl"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
            # Consume the banner up to the first prompt
            self._read_until_sentinel(bootstrap=True)
        return self._proc

    def _read_until_sentinel(self, bootstrap=False):
        """Reads REPL output until the sentinel line, stripping prompts."""
        proc = self._proc
        lines = []
        if bootstrap:
            proc.stdin.write(SENTINEL_EXPR + "\n")
            proc.stdin.flush()
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            # Strip any number of leading prompt markers
            while line.startswith("lispium> ") or line.startswith("      .. "):
                line = line[9:]
            if SENTINEL in line:
                break
            lines.append(line)
        return "".join(lines)

    def do_execute(
        self, code, silent, store_history=True, user_expressions=None, allow_stdin=False
    ):
        proc = self._ensure_proc()
        # Feed the cell line by line (the REPL balances parens itself),
        # then the sentinel
        for line in code.splitlines():
            proc.stdin.write(line + "\n")
        proc.stdin.write(SENTINEL_EXPR + "\n")
        proc.stdin.flush()
        output = self._read_until_sentinel().strip("\n")

        if not silent and output:
            self.send_response(
                self.iopub_socket, "stream", {"name": "stdout", "text": output + "\n"}
            )
        return {
            "status": "ok",
            "execution_count": self.execution_count,
            "payload": [],
            "user_expressions": {},
        }

    def do_shutdown(self, restart):
        if self._proc is not None:
            try:
                self._proc.stdin.write("quit\n")
                self._proc.stdin.flush()
                self._proc.wait(timeout=2)
            except Exception:
                self._proc.kill()
            self._proc = None
        return {"status": "ok", "restart": restart}


KERNEL_SPEC = {
    "argv": [sys.executable, "-m", "lispium.kernel", "-f", "{connection_file}"],
    "display_name": "Lispium",
    "language": "lispium",
}


def install():
    """Registers the kernelspec with Jupyter."""
    import json
    import tempfile
    from pathlib import Path

    from jupyter_client.kernelspec import KernelSpecManager

    with tempfile.TemporaryDirectory() as td:
        spec_dir = Path(td) / "lispium"
        spec_dir.mkdir()
        (spec_dir / "kernel.json").write_text(json.dumps(KERNEL_SPEC, indent=2))
        KernelSpecManager().install_kernel_spec(str(spec_dir), "lispium", user=True)
    print("Installed the Lispium Jupyter kernel (user).")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "install":
        install()
    else:
        from ipykernel.kernelapp import IPKernelApp

        IPKernelApp.launch_instance(kernel_class=LispiumKernel)
