#!/usr/bin/env python3
"""Delegate to real jq; change fixture DATA after the reviewer read boundary."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

args = sys.argv[1:]
real_jq = Path(os.environ["ADR_REAL_JQ"]).resolve(strict=True)
if real_jq == Path(__file__).resolve():
    sys.exit("fixture jq delegation loops")
result = subprocess.run([str(real_jq), *args], check=False)
stage_is_impl = any(args[i:i + 3] == ["--arg", "stage", "impl"]
                    for i in range(len(args) - 2))
boundary = stage_is_impl and any("manifest_superset_ok" in arg for arg in args)
if result.returncode == 0 and boundary:
    root = Path(os.environ["ADR_MUTATION_ROOT"]).resolve(strict=True)
    contract = root / "reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
    receipt = root / "mutation-receipt.json"
    replacement = root / "replacement-contract.json"
    for path in (contract, replacement):
        if path.is_symlink() or not path.resolve(strict=True).is_relative_to(root):
            sys.exit("fixture mutation path is unsafe")
    before = contract.read_bytes()
    mode = os.environ["ADR_MUTATION_MODE"]
    if mode not in ("late-contract-control", "late-contract-rescue"):
        sys.exit("unknown fixture mutation mode")
    if receipt.exists():
        sys.exit("fixture reviewer boundary was reached more than once")
    if mode == "late-contract-rescue":
        # Only a private data-fixture contract is replaced, never executable code.
        os.replace(replacement, contract)
    after = contract.read_bytes()
    with receipt.open("x", encoding="utf-8") as stream:
        json.dump({"mode": mode, "jq_exit": result.returncode,
                   "before": hashlib.sha256(before).hexdigest(),
                   "after": hashlib.sha256(after).hexdigest(),
                   "changed": before != after}, stream)
sys.exit(result.returncode if result.returncode >= 0 else 128 - result.returncode)
