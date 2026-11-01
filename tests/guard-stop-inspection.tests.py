#!/usr/bin/env python3
"""Run the Node runtime-boundary regressions through the shared catalog."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

if __name__ == "__main__":
    subprocess.run(
        ["node", "--test", str(ROOT / "tests/guard-stop-inspection.tests.mjs"),
         str(ROOT / "tests/mcp-json-boundaries.tests.mjs")],
        check=True,
        timeout=60,
    )
