#!/usr/bin/env python3
"""REQ-005: Projection generator for `gate-capabilities.json`.

Reads the canonical Registry (`contracts/capability-registry.json`) via a
fixed, script-relative offset -- mirroring `generate-guard-invariants.py`'s
own canonical-source resolution exactly (INV-009). Deliberately does NOT
use `registry_discovery.py`'s packaged-copy-first contract: this script is
that packaged/vendored copy's own producer and must never read its own
output as its input (design.md "Projection generator contract", REQ-005).

Writes `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`:
a top-level `_generated` metadata object (`source`, `schema_version`,
`sha256`, `notice`) followed by `gates` (stage: implementation entries
only, stable-sorted by id) and `capability_gate_map` (every capability id
-> its implementation-stage gate ids, sorted; a gate id referencing a
non-implementation-stage gate is omitted here so this file stays
internally consistent with its own `gates` array -- no dangling
reference to a gate this projection does not itself carry).

`--check`: recomputes the same content in memory, compares byte-for-byte
against the committed file, exits non-zero on any difference. No write,
no filesystem mutation of any kind -- mirrors
`generate-guard-invariants.py --check` exactly.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
EXPECTED_REGISTRY_SCHEMA = "capability-registry/v1"
CANONICAL_SOURCE_REL = "contracts/capability-registry.json"


def load_registry(canonical_path: Path) -> tuple[dict[str, Any], str]:
    """Read and minimally validate the canonical Registry. Returns (data, sha256-of-raw-bytes)."""
    raw = canonical_path.read_bytes()
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"canonical Registry JSON is invalid: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError("canonical Registry JSON must be an object")
    if data.get("schema") != EXPECTED_REGISTRY_SCHEMA:
        raise ValueError(
            f"canonical Registry schema must be {EXPECTED_REGISTRY_SCHEMA!r}, "
            f"got {data.get('schema')!r}"
        )
    return data, hashlib.sha256(raw).hexdigest()


def build_projection(data: dict[str, Any], digest: str) -> dict[str, Any]:
    all_gates = data.get("gates", [])
    if not isinstance(all_gates, list):
        raise ValueError("Registry 'gates' must be an array")
    impl_gates = sorted(
        (g for g in all_gates if isinstance(g, dict) and g.get("stage") == "implementation"),
        key=lambda g: str(g.get("id", "")),
    )
    impl_gate_ids = {g.get("id") for g in impl_gates}

    capabilities = data.get("capabilities", [])
    if not isinstance(capabilities, list):
        raise ValueError("Registry 'capabilities' must be an array")
    capability_gate_map: dict[str, list[str]] = {}
    for cap in sorted(
        (c for c in capabilities if isinstance(c, dict) and c.get("id")),
        key=lambda c: str(c.get("id", "")),
    ):
        cap_id = cap["id"]
        gate_ids = cap.get("gate_ids", [])
        if not isinstance(gate_ids, list):
            gate_ids = []
        capability_gate_map[cap_id] = sorted(gid for gid in gate_ids if gid in impl_gate_ids)

    return {
        "_generated": {
            "source": CANONICAL_SOURCE_REL,
            "schema_version": SCHEMA_VERSION,
            "sha256": digest,
            "notice": "This file is generated. Do not edit.",
        },
        "gates": impl_gates,
        "capability_gate_map": capability_gate_map,
    }


def render(projection: dict[str, Any]) -> bytes:
    return (json.dumps(projection, indent=2, ensure_ascii=True) + "\n").encode("utf-8")


def write_atomic(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(content)
    os.replace(temporary, path)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify committed output without writing")
    parser.add_argument(
        "--repo-root",
        default=None,
        help=(
            "override the repo root used to locate contracts/capability-registry.json "
            "(defaults to this script's fixed monorepo-relative offset); test isolation only"
        ),
    )
    args = parser.parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    repo_root = Path(args.repo_root).resolve() if args.repo_root else script_dir.parent.parent.parent
    canonical = repo_root / "contracts" / "capability-registry.json"
    # Derived from repo_root (not script_dir) even in production, where the
    # two coincide by construction -- this keeps --repo-root test isolation
    # from ever touching this repository's own real generated output.
    output_path = repo_root / "plugins" / "sdd-quality-loop" / "scripts" / "generated" / "gate-capabilities.json"

    try:
        if not canonical.is_file():
            print(f"generate-gate-capabilities: canonical Registry not found: {canonical}", file=sys.stderr)
            return 1
        data, digest = load_registry(canonical)
        projection = build_projection(data, digest)
        content = render(projection)
    except (OSError, ValueError) as exc:
        print(f"generate-gate-capabilities: {exc}", file=sys.stderr)
        return 1

    if args.check:
        if not output_path.is_file() or output_path.read_bytes() != content:
            print(f"generate-gate-capabilities: gate-capabilities.json is stale: {output_path}", file=sys.stderr)
            return 1
        return 0

    write_atomic(output_path, content)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
