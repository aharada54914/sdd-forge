#!/usr/bin/env python3
"""Report reviewed adapter gaps; no job admission or execution is performed."""

import ast
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
REQUIRED = (
    "work_order_admission",
    "restart_lease",
    "duplicate_reconciliation",
    "late_result_fencing",
    "file_port_database_reservation",
    "cancel_child_tree",
    "budget_observation",
)
CANDIDATES = (
    (
        "managed-native-invocation",
        "plugins/sdd-implementation/scripts/managed-model-entry.py",
        "_run_cli",
        "Internal bounded subprocess exchange; no public factory work-order ownership API.",
    ),
    (
        "lite-gate",
        "plugins/sdd-lite/lib/run-lite-gate.py",
        "_run_one",
        "Required-check execution owner; not a discretionary work-order executor.",
    ),
    (
        "verification-catalog",
        "tests/verification.py",
        "main",
        "Catalog suite execution owner; no public factory lease/reconciliation contract.",
    ),
)


def inspect(root=ROOT):
    results = []
    for name, relative, symbol, boundary in CANDIDATES:
        path = root / relative
        available, digest = False, None
        try:
            raw = path.read_bytes()
            tree = ast.parse(raw)
            available = any(
                isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
                and node.name == symbol
                for node in tree.body
            )
            digest = hashlib.sha256(raw).hexdigest()
        except (OSError, SyntaxError):
            pass
        results.append(
            {
                "adapter": name,
                "source": relative,
                "sha256": digest,
                "reviewed_symbol_present": available,
                "boundary": boundary,
                "required_capabilities": {key: "not-demonstrated" for key in REQUIRED},
            }
        )
    return {
        "schema": "factory-adapter-readiness/v1",
        "admissible": False,
        "reason": "no-verified-adapter",
        "candidates": results,
        "next": "Verify one existing executor public API and real cancel/resume/isolation/budget behavior before admission policy implementation.",
        "authority": "none",
        "scope": "source inventory only; no claim about all external hosts",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    print(json.dumps(inspect(args.root.resolve()), indent=2))
