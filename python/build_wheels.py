#!/usr/bin/env python3
"""
Build platform-specific wheel packages for Lispium.

This script downloads pre-built binaries from GitHub releases and creates
wheel packages for each supported platform.
"""

import os
import sys
import shutil
import tarfile
import tempfile
import urllib.request
from pathlib import Path

VERSION = "0.1.0"
GITHUB_RELEASE_URL = f"https://github.com/Tetraslam/lispium/releases/download/v{VERSION}"

PLATFORMS = [
    ("linux", "x86_64", "lispium-linux-x86_64.tar.gz"),
    ("darwin", "x86_64", "lispium-macos-x86_64.tar.gz"),
    ("darwin", "aarch64", "lispium-macos-aarch64.tar.gz"),
    ("windows", "x86_64", "lispium-windows-x86_64.zip"),
]


def download_binary(platform_name: str, arch: str, archive_name: str, dest_dir: Path):
    """Download and extract binary for a specific platform."""
    url = f"{GITHUB_RELEASE_URL}/{archive_name}"
    print(f"Downloading {url}...")

    with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
        try:
            urllib.request.urlretrieve(url, tmp.name)
        except Exception as e:
            print(f"Failed to download {url}: {e}")
            return False

        # Determine output binary name
        if platform_name == "windows":
            binary_name = f"lispium-{platform_name}-{arch}.exe"
        else:
            binary_name = f"lispium-{platform_name}-{arch}"

        # Extract the binary
        try:
            if archive_name.endswith(".zip"):
                import zipfile
                with zipfile.ZipFile(tmp.name, "r") as zf:
                    for info in zf.infolist():
                        if info.filename.endswith("lispium") or info.filename.endswith("lispium.exe"):
                            with zf.open(info) as src:
                                dest_path = dest_dir / binary_name
                                with open(dest_path, "wb") as dst:
                                    dst.write(src.read())
                                os.chmod(dest_path, 0o755)
                                print(f"  Extracted to {dest_path}")
                                return True
            else:
                with tarfile.open(tmp.name, "r:gz") as tf:
                    for member in tf.getmembers():
                        if member.name.endswith("lispium"):
                            member.name = binary_name
                            tf.extract(member, dest_dir)
                            dest_path = dest_dir / binary_name
                            os.chmod(dest_path, 0o755)
                            print(f"  Extracted to {dest_path}")
                            return True
        except Exception as e:
            print(f"Failed to extract {archive_name}: {e}")
            return False
        finally:
            os.unlink(tmp.name)

    return False


def main():
    """Download all binaries and build wheel packages."""
    script_dir = Path(__file__).parent
    bin_dir = script_dir / "src" / "lispium" / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)

    print("Downloading Lispium binaries...")
    for platform_name, arch, archive_name in PLATFORMS:
        if not download_binary(platform_name, arch, archive_name, bin_dir):
            print(f"Warning: Could not download binary for {platform_name}-{arch}")

    print("\nBuilding wheel package...")
    os.chdir(script_dir)
    os.system(f"{sys.executable} -m build")

    print("\nDone! Wheel packages are in the 'dist' directory.")


if __name__ == "__main__":
    main()
