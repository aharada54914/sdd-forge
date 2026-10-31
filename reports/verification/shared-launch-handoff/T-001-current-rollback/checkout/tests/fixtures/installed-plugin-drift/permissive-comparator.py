#!/usr/bin/env python3
"""Deliberately wrong comparator used only to prove the TDD RED oracle."""

import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--install-root", required=True)
parser.add_argument("--mode", choices=("preflight", "verify"), default="preflight")
args = parser.parse_args()
print(json.dumps({
    "schema": "installed-plugin-drift-report/v1",
    "mode": args.mode,
    "install_root": str(Path(args.install_root).resolve()),
    "state": "installed_synced",
    "diverged": [],
}, sort_keys=True))
