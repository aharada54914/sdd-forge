#!/usr/bin/env python3
"""Generate a canonical digest for a selected Capability Registry fragment.

Fragment selection and stable array ordering live here. Unicode NFC
normalization, RFC 8785 canonical JSON serialization, and hashing are delegated
to Epic A1's canonicalize-sdd-yaml.py JSON interface.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import registry_discovery


class DigestError(Exception):
    pass


def _canonicalizer_path() -> Path:
    return Path(__file__).resolve().parent / "canonicalize-sdd-yaml.py"


def canonical_digest(value: object) -> str:
    fd, temporary = tempfile.mkstemp(prefix="registry-digest-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, separators=(",", ":"))
        canonicalizer = _canonicalizer_path()
        if not canonicalizer.is_file():
            raise DigestError(f"canonicalizer-unavailable: {canonicalizer}")
        try:
            proc = subprocess.run(
                [
                    sys.executable,
                    str(canonicalizer),
                    temporary,
                    "--input-format",
                    "json",
                    "--hash-only",
                ],
                capture_output=True,
            )
        except OSError as exc:
            raise DigestError(f"canonicalizer-unavailable: {exc}") from exc
    finally:
        try:
            os.unlink(temporary)
        except OSError:
            pass
    if proc.returncode != 0:
        detail = proc.stderr.decode("utf-8", errors="replace").strip()
        raise DigestError(f"canonicalizer-failed: {detail}")
    try:
        text = proc.stdout.decode("ascii", errors="strict").strip()
    except UnicodeDecodeError as exc:
        raise DigestError("canonicalizer-invalid-output: non-ASCII stdout") from exc
    match = re.fullmatch(r"sha256:([0-9a-f]{64})", text)
    if match is None:
        raise DigestError("canonicalizer-invalid-output")
    return match.group(1)


def _csv(value: str | None) -> set[str]:
    return set() if value is None else {item.strip() for item in value.split(",") if item.strip()}


def _index_entries(registry: dict, field: str) -> dict[str, dict]:
    entries = registry.get(field)
    if not isinstance(entries, list):
        raise DigestError(f"invalid-registry: {field} must be an array")
    result: dict[str, dict] = {}
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), str) or not entry["id"]:
            raise DigestError(f"invalid-registry: every {field} entry must have a non-empty string id")
        entry_id = entry["id"]
        if entry_id in result:
            raise DigestError(f"invalid-registry: duplicate {field} id {entry_id!r}")
        result[entry_id] = entry
    return result


def build_fragment(registry: dict, capability_ids: set[str], gate_ids: set[str]) -> dict:
    """Select, close over capability gate references, dedupe, and stable-sort."""
    capability_index = _index_entries(registry, "capabilities")
    gate_index = _index_entries(registry, "gates")
    unknown = [f"capability:{item}" for item in sorted(capability_ids - capability_index.keys())]
    unknown += [f"gate:{item}" for item in sorted(gate_ids - gate_index.keys())]
    if unknown:
        raise DigestError("unknown-fragment-id: " + ",".join(unknown))

    selected_gate_ids = set(gate_ids)
    for capability_id in capability_ids:
        references = capability_index[capability_id].get("gate_ids")
        if not isinstance(references, list) or not all(isinstance(item, str) for item in references):
            raise DigestError(
                f"invalid-registry: capability {capability_id!r} gate_ids must be a string array"
            )
        missing_references = sorted(set(references) - gate_index.keys())
        if missing_references:
            raise DigestError(
                f"invalid-registry: capability {capability_id!r} references unknown gates: "
                + ",".join(missing_references)
            )
        selected_gate_ids.update(references)

    return {
        "capabilities": [capability_index[item] for item in sorted(capability_ids)],
        "gates": [gate_index[item] for item in sorted(selected_gate_ids)],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="generate-registry-digest.py")
    parser.add_argument("--capability-ids")
    parser.add_argument("--gate-ids")
    parser.add_argument("--whole", action="store_true")
    args = parser.parse_args(argv)
    capability_ids = _csv(args.capability_ids)
    gate_ids = _csv(args.gate_ids)
    if args.whole and (args.capability_ids is not None or args.gate_ids is not None):
        print("generate-registry-digest: fragment-selector-conflict", file=sys.stderr)
        return 1
    if not args.whole and not capability_ids and not gate_ids:
        print("generate-registry-digest: fragment-selector-required", file=sys.stderr)
        return 1
    try:
        path = registry_discovery.discover_artifact("capability-registry.json")
        with path.open("r", encoding="utf-8") as handle:
            registry = json.load(handle)
        if not isinstance(registry, dict):
            raise DigestError("invalid-registry: top level must be an object")
        selected = registry if args.whole else build_fragment(registry, capability_ids, gate_ids)
        print(canonical_digest(selected))
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        registry_discovery.DiscoveryError,
        DigestError,
    ) as exc:
        print(f"generate-registry-digest: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
