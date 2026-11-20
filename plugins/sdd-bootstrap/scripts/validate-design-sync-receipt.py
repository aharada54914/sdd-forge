#!/usr/bin/env python3
"""Validate external design-sync round-trip receipts (design-sync-receipt/v1).

Enforces strict provider attribution and acceptance boundaries (#729):
  - manual / skip / unavailable provider never counts as design integration success.
  - alternative providers must declare explicit capability_gaps vs Claude Design
    and can never report claude_design_connected=true.
  - full and full+SQLite round trips must record pulled tokens/components,
    mockup sync & provider review, REQ/AC mapping, UI code diff, before/after
    visual captures, design version, and post-change UI + persistence verification.
"""
import argparse
import json
from pathlib import Path
import sys

REQUIRED_STRINGS = (
    "feature",
    "track",
    "provider",
    "project_id",
    "design_version",
    "tokens_pull_receipt",
    "mockup_review_receipt",
    "ui_diff_ref",
    "before_screenshot",
    "after_screenshot",
)
VALID_TRACKS = ("full", "full+sqlite", "lite")
VALID_MODES = ("native-sync", "alternative-adapter")


def validate_receipt(doc):
    errors = []
    if not isinstance(doc, dict):
        return ["receipt must be a JSON object"]
    if doc.get("schema") != "design-sync-receipt/v1":
        errors.append("schema must be design-sync-receipt/v1")
    if doc.get("provider_available") is not True:
        errors.append("provider_available must be true (unavailable/manual/skip is not integration success)")
    mode = doc.get("round_trip_mode")
    if mode not in VALID_MODES:
        errors.append("round_trip_mode must be native-sync or alternative-adapter (manual/skip rejected)")
    track = doc.get("track")
    if track not in VALID_TRACKS:
        errors.append(f"track must be one of {VALID_TRACKS}")
    for key in REQUIRED_STRINGS:
        val = doc.get(key)
        if not isinstance(val, str) or not val.strip():
            errors.append(f"{key} must be a nonempty string")
    provider = doc.get("provider")
    claude_connected = doc.get("claude_design_connected")
    if type(claude_connected) is not bool:
        errors.append("claude_design_connected must be boolean")
    if provider == "claude-design":
        if mode != "native-sync" or claude_connected is not True:
            errors.append("claude-design receipt requires round_trip_mode=native-sync and claude_design_connected=true")
    else:
        if claude_connected is True:
            errors.append("alternative provider must never claim claude_design_connected=true")
        if mode != "alternative-adapter":
            errors.append("alternative provider must declare round_trip_mode=alternative-adapter")
        gaps = doc.get("capability_gaps")
        if not isinstance(gaps, list) or not all(isinstance(g, str) and g.strip() for g in gaps):
            errors.append("alternative provider must declare capability_gaps as a list of strings")
    req_ac = doc.get("req_ac_mappings")
    if not isinstance(req_ac, list) or not req_ac or not all(isinstance(x, str) and x.strip() for x in req_ac):
        errors.append("req_ac_mappings must be a nonempty list of REQ/AC identifiers")
    if doc.get("egress_scan") not in ("clean", "overridden"):
        errors.append("egress_scan must be clean or overridden")
    if doc.get("ui_tests_passed") is not True:
        errors.append("ui_tests_passed must be true")
    if track == "full+sqlite" and doc.get("sqlite_restart_persistence_passed") is not True:
        errors.append("full+sqlite track requires sqlite_restart_persistence_passed=true")
    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path, help="Path to design-sync-receipt/v1 JSON file")
    args = parser.parse_args(argv)
    try:
        doc = json.loads(args.receipt.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(json.dumps({"ok": False, "errors": [f"cannot read receipt: {exc}"]}), file=sys.stderr)
        return 2
    errors = validate_receipt(doc)
    if errors:
        print(json.dumps({"ok": False, "errors": errors}, ensure_ascii=False), file=sys.stderr)
        return 1
    print(json.dumps({
        "ok": True,
        "provider": doc["provider"],
        "claude_design_connected": doc["claude_design_connected"],
        "round_trip_mode": doc["round_trip_mode"],
        "track": doc["track"],
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
