"""Command-line interface wrapper for Lispium."""

import os
import sys
import platform
import subprocess
from pathlib import Path


def get_binary_path() -> Path:
    """Get the path to the Lispium binary for the current platform."""
    system = platform.system().lower()
    machine = platform.machine().lower()

    # Normalize architecture names
    if machine in ("x86_64", "amd64"):
        arch = "x86_64"
    elif machine in ("arm64", "aarch64"):
        arch = "aarch64"
    else:
        arch = machine

    # Determine binary name based on OS
    if system == "windows":
        binary_name = f"lispium-{system}-{arch}.exe"
    else:
        binary_name = f"lispium-{system}-{arch}"

    # Look for binary in package directory
    package_dir = Path(__file__).parent
    binary_path = package_dir / "bin" / binary_name

    if binary_path.exists():
        return binary_path

    # Fallback: try to find 'lispium' in PATH
    import shutil
    system_binary = shutil.which("lispium")
    if system_binary:
        return Path(system_binary)

    # If no platform-specific binary, try generic name
    generic_path = package_dir / "bin" / "lispium"
    if generic_path.exists():
        return generic_path

    raise FileNotFoundError(
        f"Lispium binary not found for platform {system}-{arch}. "
        f"Please install Lispium separately or ensure it's in your PATH. "
        f"Visit https://github.com/Tetraslam/lispium/releases for downloads."
    )


def main():
    """Run Lispium with the provided arguments."""
    try:
        binary_path = get_binary_path()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    # Make sure binary is executable on Unix
    if platform.system() != "Windows":
        os.chmod(binary_path, 0o755)

    # Run the binary with all provided arguments
    args = [str(binary_path)] + sys.argv[1:]

    try:
        result = subprocess.run(args)
        sys.exit(result.returncode)
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as e:
        print(f"Error running Lispium: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
