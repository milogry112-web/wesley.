#!/usr/bin/env python3
"""Install pinned official CLI releases, checking SHA-256 before extraction.

Archives are obtained over verified HTTPS. This manifest pins the bytes obtained
from the official upstream release URLs; it does not claim publisher signatures.
WESLEY_TOOLS_DIR overrides the default sibling .tools directory.
"""

import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import zipfile

REPO = Path(__file__).resolve().parent.parent
ROOT = Path(os.environ.get("WESLEY_TOOLS_DIR", REPO.parent / ".tools")).resolve()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if platform.system() != "Linux" or platform.machine() not in ("x86_64", "amd64"):
        sys.exit("This cloud bootstrap requires Linux x86_64. Install Rojo 7.5.1 for your desktop separately.")
    manifest = json.loads((REPO / "tools/toolchain.json").read_text())
    downloads = ROOT / "downloads"
    binaries = ROOT / "bin"
    downloads.mkdir(parents=True, exist_ok=True)
    binaries.mkdir(parents=True, exist_ok=True)
    for tool in manifest["tools"]:
        archive = downloads / f'{tool["name"]}-{tool["version"]}.zip'
        if not archive.exists() or digest(archive) != tool["sha256"]:
            temporary = archive.with_suffix(".download")
            subprocess.run([
                "curl", "--fail", "--location", "--silent", "--show-error",
                "--proto", "=https", "--proto-redir", "=https", "--tlsv1.2",
                "--connect-timeout", "20", "--max-time", "180", "--retry", "2",
                tool["url"], "--output", str(temporary),
            ], check=True)
            if digest(temporary) != tool["sha256"]:
                temporary.unlink()
                sys.exit(f'Checksum mismatch for {tool["name"]}; refusing to install.')
            temporary.replace(archive)
        with zipfile.ZipFile(archive) as source:
            # Only exact manifest members are extracted; never follow archive paths.
            for name in tool["executables"]:
                target = binaries / name
                temporary = binaries / f".{name}.install"
                temporary.write_bytes(source.read(name))
                temporary.chmod(0o755)
                temporary.replace(target)
        print(f'Installed {tool["name"]} {tool["version"]} (SHA-256 verified)', flush=True)
    print(f"Tool directory: {binaries}")


if __name__ == "__main__":
    main()
