#!/usr/bin/env python3
"""Compile every Luau source, run actual module tests, and build the Studio place."""

import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
BIN = Path(os.environ.get("WESLEY_TOOLS_DIR", REPO.parent / ".tools")) / "bin"


def run(args, **kwargs):
    subprocess.run([str(arg) for arg in args], cwd=REPO, check=True, **kwargs)


def main():
    for tool in ("luau-compile", "luau", "rojo", "lune"):
        if not (BIN / tool).is_file():
            sys.exit(f"Missing {tool}. Run bash tools/bootstrap.sh first.")
    sources = sorted((REPO / "src").rglob("*.luau")) + sorted((REPO / "tests").rglob("*.luau")) + sorted((REPO / "tools").rglob("*.luau"))
    if not sources:
        sys.exit("No Luau sources found; refusing a zero-source validation.")
    for source in sources:
        run([BIN / "luau-compile", "--binary", source], stdout=subprocess.DEVNULL)
    print(f"PASS: {len(sources)} Luau files compiled", flush=True)
    tests = REPO / "tests/run.luau"
    if not tests.is_file():
        sys.exit("Missing tests/run.luau; no functional module tests ran.")
    run([BIN / "luau", tests])
    run([BIN / "lune", "run", REPO / "tests/server.luau"])
    for name in ("combat.luau", "services.luau", "client.luau", "bootstrap.luau"):
        suite = REPO / "tests" / name
        if suite.is_file():
            run([BIN / "lune", "run", suite])
    build = REPO / "build"
    build.mkdir(exist_ok=True)
    output = build / "EternalForge.rbxlx"
    run([BIN / "rojo", "build", "default.project.json", "--output", output])
    document = ET.parse(output)
    scripts = document.findall(".//Item[@class='Script']")
    clients = document.findall(".//Item[@class='LocalScript']")
    modules = document.findall(".//Item[@class='ModuleScript']")
    if not scripts or not clients or not modules:
        sys.exit("Place is missing server, client, or shared scripts.")
    print(f"PASS: Studio place built ({len(scripts)} server, {len(clients)} client, {len(modules)} modules)", flush=True)
    world_test = REPO / "tests/world.luau"
    if world_test.is_file():
        run([BIN / "lune", "run", world_test])
    run([BIN / "lune", "run", REPO / "tools/build-place.luau"])
    print("Cloud validation passed. Roblox Studio playtesting remains required for live engine behavior.", flush=True)


if __name__ == "__main__":
    main()
