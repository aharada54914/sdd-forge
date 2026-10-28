#!/usr/bin/env python3
"""Validate passive research metadata; no network, original access or approval."""

import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from research_evidence import main  # noqa: E402 - sibling runtime path is explicit.

if __name__ == "__main__":
    raise SystemExit(main())
