#!/usr/bin/env python3
"""check-component-coverage — the Reverse Coverage Gate (REQ-004, T-004).

epic-191-a3-path-ownership. Always runs to completion and always emits an
`check-component-coverage-verdict/v1` evidence record carrying a
`producer.sha256` binding, deriving one of three states from
`workflow.capability_enforcement`/`disabled-legacy` (ADR-0016):

  - `disabled-legacy` (project-context.yaml absent, or the field itself
    absent/invalid — the capability pipeline is outside its own domain,
    ADR-0016 point 4): zero ownership Fail-condition evaluation, a real
    N/A evidence record, exit 0. `--facet-manifest` is accepted but never
    consulted for existence in this state.
  - `advisory`: `--facet-manifest` is structurally required; a missing or
    unreadable manifest is a hard error (distinct exit code). When
    present and readable, all six Fail conditions are evaluated and
    recorded, but exit is ALWAYS 0 regardless of any trigger.
  - `required`: identical evaluation to `advisory`, but exit is non-zero
    IFF at least one Fail condition triggers.

Applicability is derived from `workflow.capability_enforcement`, never from
Facet-Manifest file presence (ADR-0016, NEW-001) — `advisory` is never
silently promoted to `required`'s blocking strength.

This script imports `resolve-component-paths.py`'s public functions
directly (same-directory sibling module) rather than reimplementing
classification or the git-diff collector.

This module must NOT import from outside the standard library, mirroring
`resolve-component-paths.py`'s own no-third-party-dependency constraint.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from typing import Dict, List, Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util as _il_util

_rcp_spec = _il_util.spec_from_file_location(
    "resolve_component_paths", os.path.join(os.path.dirname(os.path.abspath(__file__)), "resolve-component-paths.py")
)
rcp = _il_util.module_from_spec(_rcp_spec)
_rcp_spec.loader.exec_module(rcp)

SCHEMA = "check-component-coverage-verdict/v1"
CHECK_ID = "check-component-coverage"

# Exit codes (distinct per REQ-004's own wording):
EXIT_OK = 0
EXIT_FAIL_TRIGGERED = 1  # `required` state, at least one Fail condition triggered
EXIT_HARD_ERROR = 2  # manifest missing/unreadable in advisory/required; config error


def _producer_sha256() -> str:
    with open(os.path.abspath(__file__), "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def derive_state(config_path: Optional[str]) -> str:
    """Returns 'disabled-legacy' | 'advisory' | 'required'.

    Per ADR-0016 point 4: disabled-legacy is a derived internal state, not
    an enum value of capability_enforcement, entered whenever
    project-context.yaml is absent OR the capability_enforcement field
    itself is absent/invalid in it — a conservative, fail-toward-inactive
    default (this feature never infers `required` from ambiguous data).
    """
    if not config_path or not os.path.isfile(config_path):
        return "disabled-legacy"
    try:
        with open(config_path, "r", encoding="utf-8") as fh:
            text = fh.read()
        data = rcp.parse_minimal_yaml(text)
    except (rcp.ConfigError, OSError):
        return "disabled-legacy"
    workflow = data.get("workflow")
    if not isinstance(workflow, dict):
        return "disabled-legacy"
    value = workflow.get("capability_enforcement")
    if value == "advisory":
        return "advisory"
    if value == "required":
        return "required"
    return "disabled-legacy"


def load_facet_manifest(path: str):
    """Returns (affected_components: List[str], error: Optional[str])."""
    if not os.path.isfile(path):
        return None, f"Facet Manifest not found: {path}"
    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        return None, f"Facet Manifest unreadable: {path} ({exc})"
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        try:
            data = rcp.parse_minimal_yaml(text)
        except rcp.ConfigError as exc:
            return None, f"Facet Manifest could not be parsed as JSON or YAML: {path} ({exc})"
    if not isinstance(data, dict) or "affected_components" not in data:
        return None, f"Facet Manifest at {path} has no top-level 'affected_components' key"
    affected = data.get("affected_components")
    if not isinstance(affected, list) or not all(isinstance(x, str) for x in affected):
        return None, f"Facet Manifest at {path} 'affected_components' must be a list of strings"
    return affected, None


def load_provider_bindings(path: str):
    """Returns a list of binding dicts, or None if the file does not exist.
    Fail-6 is conditional on this file's existence (design.md Design
    Decisions "Fail-6 scope"). Never reads a `credentials` block
    (security-spec.md Secrets Management)."""
    if not os.path.isfile(path):
        return None
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        data = rcp.parse_minimal_yaml(text)
    bindings = data.get("bindings") if isinstance(data, dict) else None
    if not isinstance(bindings, list):
        return []
    out = []
    for b in bindings:
        if not isinstance(b, dict):
            continue
        # Deliberately never read a "credentials" key (security-spec.md).
        out.append(
            {
                "provider_binding_ids": b.get("provider_binding_ids") or [],
                "adapter_paths": b.get("adapter_paths"),
            }
        )
    return out


def evaluate_fail_conditions(records: List[dict], affected_components: List[str], bindings: Optional[List[dict]]):
    """Evaluates all six Fail conditions (REQ-004) against the resolver's
    own classification records. Returns a list of
    {id, triggered, detail} dicts, one per Fail-1..Fail-6, plus a list of
    warning strings."""
    affected_set = set(affected_components)
    warnings: List[str] = []

    fail1_paths = [r["raw_path"] for r in records if r["classification"] == "UNOWNED"]
    fail1 = {"id": "Fail-1", "triggered": len(fail1_paths) > 0, "detail": {"unowned_paths": fail1_paths}}

    fail2_components: List[str] = []
    for r in records:
        if r["classification"] == "EXCLUSIVE":
            for comp in r["owning_components"]:
                if comp not in affected_set and comp not in fail2_components:
                    fail2_components.append(comp)
    fail2 = {
        "id": "Fail-2",
        "triggered": len(fail2_components) > 0,
        "detail": {"missing_exclusive_owners": fail2_components},
    }

    fail3_paths = [r["raw_path"] for r in records if r["classification"] == "OVERLAP"]
    fail3 = {"id": "Fail-3", "triggered": len(fail3_paths) > 0, "detail": {"overlap_paths": fail3_paths}}

    fail4_components: List[str] = []
    for r in records:
        if r["classification"] == "SHARED_BOUNDED":
            for comp in r["owning_components"]:
                if comp not in affected_set and comp not in fail4_components:
                    fail4_components.append(comp)
    fail4 = {
        "id": "Fail-4",
        "triggered": len(fail4_components) > 0,
        "detail": {"missing_bounded_shared_owners": fail4_components},
    }

    fail5_paths = [
        r["raw_path"]
        for r in records
        if r["classification"] == "UNOWNED" and r.get("evidence", {}).get("excluded_match")
    ]
    fail5 = {"id": "Fail-5", "triggered": len(fail5_paths) > 0, "detail": {"excluded_match_paths": fail5_paths}}

    if bindings is None:
        fail6 = {"id": "Fail-6", "triggered": False, "detail": {"status": "not-applicable (provider-bindings absent)"}}
        warnings.append("Fail-6: sdd/provider-bindings.yaml absent; recorded N/A")
    else:
        exclusive_by_component: Dict[str, List[str]] = {}
        for r in records:
            if r["classification"] == "EXCLUSIVE":
                for comp in r["owning_components"]:
                    exclusive_by_component.setdefault(comp, []).append(r["raw_path"])
        fail6_matches = []
        any_binding_missing_adapter_paths = False
        for binding in bindings:
            adapter_paths = binding.get("adapter_paths")
            joined_components = binding.get("provider_binding_ids") or []
            if adapter_paths is None:
                any_binding_missing_adapter_paths = True
                continue
            for comp in joined_components:
                for path in exclusive_by_component.get(comp, []):
                    nfc_path = rcp.normalize_nfc(path)
                    for pattern in adapter_paths:
                        try:
                            normalized_pattern = rcp.validate_and_normalize_pattern(pattern)
                        except rcp.ConfigError:
                            continue
                        if rcp.pattern_matches(normalized_pattern, nfc_path):
                            fail6_matches.append({"component": comp, "path": path, "pattern": pattern})
        if any_binding_missing_adapter_paths:
            warnings.append("Fail-6: a provider binding declares no adapter_paths; evaluation not possible for it")
        fail6 = {"id": "Fail-6", "triggered": len(fail6_matches) > 0, "detail": {"matches": fail6_matches}}

    return [fail1, fail2, fail3, fail4, fail5, fail6], warnings


def run(
    config_path: Optional[str],
    facet_manifest_path: Optional[str],
    provider_bindings_path: str,
    records: Optional[List[dict]],
) -> dict:
    """Pure evaluation core (no argv/exit handling), so it can be called
    directly by tests and by main()."""
    state = derive_state(config_path)
    producer = {"script": "plugins/sdd-quality-loop/scripts/check-component-coverage.py", "sha256": _producer_sha256()}

    if state == "disabled-legacy":
        return {
            "schema": SCHEMA,
            "check_id": CHECK_ID,
            "producer": producer,
            "state": "not-applicable (disabled-legacy)",
            "manifest_status": "not-consulted",
            "fail_conditions": [],
            "warnings": [],
        }

    if not facet_manifest_path:
        return {
            "schema": SCHEMA,
            "check_id": CHECK_ID,
            "producer": producer,
            "state": state,
            "manifest_status": "missing",
            "error": "--facet-manifest is required in advisory/required state",
        }

    affected_components, err = load_facet_manifest(facet_manifest_path)
    if err is not None:
        manifest_status = "missing" if not os.path.isfile(facet_manifest_path) else "unreadable"
        return {
            "schema": SCHEMA,
            "check_id": CHECK_ID,
            "producer": producer,
            "state": state,
            "manifest_status": manifest_status,
            "error": err,
        }

    bindings = load_provider_bindings(provider_bindings_path)
    fail_conditions, warnings = evaluate_fail_conditions(records or [], affected_components, bindings)

    return {
        "schema": SCHEMA,
        "check_id": CHECK_ID,
        "producer": producer,
        "state": state,
        "manifest_status": "present",
        "fail_conditions": fail_conditions,
        "warnings": warnings,
    }


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="check-component-coverage.py")
    parser.add_argument("--config", help="path to project-context.yaml")
    parser.add_argument("--facet-manifest", help="path to the Facet Manifest (required in advisory/required state)")
    parser.add_argument(
        "--provider-bindings",
        default="sdd/provider-bindings.yaml",
        help="path to the Provider Bindings file (Fail-6; default: sdd/provider-bindings.yaml)",
    )
    parser.add_argument("--changed-paths-file", help="interim input surface (see resolve-component-paths.py)")
    parser.add_argument("--source-rev", default="HEAD")
    parser.add_argument("--target-rev")
    parser.add_argument("--include-untracked", action="store_true", default=True)
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args(argv)

    state = derive_state(args.config)

    records: List[dict] = []
    if state != "disabled-legacy":
        try:
            config = rcp.load_config_file(args.config) if args.config else None
        except (rcp.ConfigError, OSError) as exc:
            print(f"check-component-coverage: config error: {exc}", file=sys.stderr)
            return EXIT_HARD_ERROR
        if config is not None:
            try:
                if args.target_rev:
                    diff_basis = rcp.collect_changed_paths(args.repo_root, args.source_rev, args.target_rev, args.include_untracked)
                    raw_paths = diff_basis["changed_paths"]
                else:
                    raw_paths = rcp._read_paths_file(args.changed_paths_file)
                classify_result = rcp.classify_paths(config, raw_paths)
                records = classify_result["records"]
            except (rcp.ConfigError, rcp.CollisionError, rcp.GitDiffError, OSError) as exc:
                print(f"check-component-coverage: {exc}", file=sys.stderr)
                return EXIT_HARD_ERROR

    result = run(args.config, args.facet_manifest, args.provider_bindings, records)
    print(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True))

    if result["state"] == "not-applicable (disabled-legacy)":
        return EXIT_OK
    if "error" in result:
        return EXIT_HARD_ERROR
    if result["state"] == "advisory":
        return EXIT_OK
    # required
    if any(fc["triggered"] for fc in result["fail_conditions"]):
        return EXIT_FAIL_TRIGGERED
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
