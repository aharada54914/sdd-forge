#!/usr/bin/env python3
"""Perform fresh deterministic original and quote verification."""

import runpy
import sys
from pathlib import Path

sys.dont_write_bytecode = True
if __name__ == "__main__":
    sys.argv.insert(1, "check")
    runpy.run_path(
        str(Path(__file__).with_name("research-evidence-tools.py")), run_name="__main__"
    )
