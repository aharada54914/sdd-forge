#!/usr/bin/env python3
"""REQ-003/REQ-006: Context Projection schema validator.

Usage:
    validate-context-projection.py --projection <path>

`<path>` is loaded directly via stdlib `json.load` -- this script's target,
`plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json`
(Epic A1's already-reserved path, INV-007), is already JSON, never YAML.
Unlike `validate-facet-manifest.py`/`validate-capability-summary.py`, there
is no YAML parse contract here and no `canonicalize-sdd-yaml` subprocess
invocation at all (design.md `validate-context-projection` contract: "needs
no such step"; Planned Files, "no YAML/canonicalizer subprocess").

Schema validation uses the packaged shared Draft 7 adapter. CLI arguments,
diagnostic IDs and semantic checks remain local to this entry point.
"""
import argparse
import json
import os
import subprocess
import sys
from collections import namedtuple

# importlib callers need the same packaged-module lookup as direct CLI execution.
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from sdd_schema import _validate

Diagnostic = namedtuple("Diagnostic", ["check_id", "pointer", "message"])

SCHEMA_FILENAME = "context-projection.schema.json"


# --------------------------------------------------------------------------
# Discovery contract (REQ-006, all four scripts; identical to Epic A2's own
# REQ-005 discovery contract, design.md "Discovery contract").
# --------------------------------------------------------------------------

def discover_schema_path():
    """Resolve contracts/context-projection.schema.json.

    (1) packaged copy at the script-relative offset ../contracts/<filename>;
    (2) else via the git root's contracts/<filename>;
    (3) fail closed naming both attempted paths.
    """
    script_real = os.path.realpath(os.path.abspath(__file__))
    script_dir = os.path.dirname(script_real)
    packaged = os.path.normpath(
        os.path.join(script_dir, "..", "contracts", SCHEMA_FILENAME)
    )
    if os.path.isfile(packaged):
        return packaged

    git_root = _find_git_root(script_dir)
    git_root_path = None
    if git_root is not None:
        git_root_path = os.path.join(git_root, "contracts", SCHEMA_FILENAME)
        if os.path.isfile(git_root_path):
            return git_root_path

    attempted = [packaged, git_root_path or "<git root unresolved>/contracts/" + SCHEMA_FILENAME]
    raise FileNotFoundError(
        "context-projection: schema-discovery-failed: tried " + ", ".join(attempted)
    )


def _find_git_root(start_dir):
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=start_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=30,
        )
        if result.returncode == 0:
            return result.stdout.decode("utf-8").strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    # Fall back to a manual .git-directory walk.
    current = start_dir
    while True:
        if os.path.isdir(os.path.join(current, ".git")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            return None
        current = parent


def load_schema():
    path = discover_schema_path()
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


# --------------------------------------------------------------------------
# Projection load (REQ-003/REQ-006). No YAML parse contract: this script's
# target is always already-canonical JSON (Epic A1's reserved
# project-context.resolved.json path, or an equivalently-shaped fixture).
# --------------------------------------------------------------------------

def load_projection(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


# --------------------------------------------------------------------------
# Shared Draft 7 schema adapter.
# --------------------------------------------------------------------------

def validate_against_schema(document, schema):
    raw = []
    try:
        _validate(document, schema, schema, "", raw)
    except ValueError as exc:
        raw.append(("", f"invalid schema: {exc}"))
    return [Diagnostic("schema-invalid", pointer, message) for pointer, message in raw]


def validate_document(document, schema=None):
    """Run schema conformance; return a Diagnostic list.

    Pure function over an already-parsed structure -- no I/O. This is the
    function both the CLI (after `load_projection`) and the regression suite
    (against JSON fixtures) call. No semantic check beyond schema
    conformance exists for this artifact (design.md `validate-context-
    projection` contract: "Checks: schema conformance only")."""
    if schema is None:
        schema = load_schema()
    return list(validate_against_schema(document, schema))


# --------------------------------------------------------------------------
# Diagnostic determinism contract (REQ-006, all four scripts).
# --------------------------------------------------------------------------

def format_diagnostics(diags):
    ordered = sorted(diags, key=lambda d: (d.check_id, d.pointer))
    return [f"context-projection: {d.check_id}: {d.pointer}: {d.message}" for d in ordered]


def main(argv=None):
    # Diagnostic determinism contract: LF-only output on every runtime.
    # Python's text-mode stdout translates "\n" to os.linesep on some
    # platforms unless reconfigured; force LF explicitly.
    try:
        sys.stdout.reconfigure(newline="\n")
    except AttributeError:
        pass  # Python < 3.7: stdout is already LF on the platforms this ships to.

    parser = argparse.ArgumentParser(prog="validate-context-projection")
    parser.add_argument("--projection", required=True)
    args = parser.parse_args(argv)

    try:
        document = load_projection(args.projection)
    # ValueError covers json.JSONDecodeError (a ValueError subclass) AND
    # UnicodeDecodeError (raised by the implicit UTF-8 text decode inside
    # `open(..., encoding="utf-8")` when the input bytes are not valid
    # UTF-8) -- catching only json.JSONDecodeError let a non-UTF-8 input
    # leak an unhandled traceback instead of this diagnostic, violating the
    # diagnostic determinism contract (a caller/CI parser expects a single
    # `context-projection: <check-id>: <detail>` line, never a traceback).
    except (OSError, ValueError) as exc:
        sys.stdout.write(f"context-projection: projection-unreadable: {exc}\n")
        return 1

    try:
        schema = load_schema()
    except FileNotFoundError as exc:
        sys.stdout.write(f"{exc}\n")
        return 1

    diags = validate_document(document, schema)
    if not diags:
        return 0

    out = sys.stdout
    for line in format_diagnostics(diags):
        out.write(line + "\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
