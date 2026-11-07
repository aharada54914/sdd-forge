#!/usr/bin/env python3
"""REQ-002/REQ-006: Capability Summary (Lite track) schema validator.

Usage:
    validate-capability-summary.py --summary <path>

<path> ending in .yaml/.yml is loaded through the YAML parse contract: a
`canonicalize-sdd-yaml` subprocess invocation (canonical-JSON stdout) is the
sole path from YAML bytes to a Python structure -- never a hand-rolled YAML
parser and never a silent fallback. A non-zero canonicalizer exit surfaces as
this validator's own `canonicalizer-invocation-failed` diagnostic.

<path> ending in .json is loaded directly via stdlib `json.load` -- this is
NOT a YAML parsing path of any kind; it exists so the regression suite can
exercise `validate_document` (the shared schema adapter) against
already-canonical JSON fixtures, independent of whichever tool eventually
turns a `capability-summary.yaml` into that structure (design.md YAML parse
contract, shared verbatim with `validate-facet-manifest`).

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

SCHEMA_FILENAME = "capability-summary.schema.json"


class CanonicalizerError(Exception):
    """Raised when the YAML parse contract's subprocess step fails."""


# --------------------------------------------------------------------------
# Discovery contract (REQ-006, all four scripts; identical to Epic A2's own
# REQ-005 discovery contract, design.md "Discovery contract").
# --------------------------------------------------------------------------

def discover_schema_path():
    """Resolve contracts/capability-summary.schema.json.

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
        "capability-summary: schema-discovery-failed: tried " + ", ".join(attempted)
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
# YAML parse contract (REQ-006, shared verbatim with validate-facet-manifest).
# --------------------------------------------------------------------------

def load_summary_yaml(path):
    """Sole path from YAML bytes to a Python structure: canonicalize-sdd-yaml
    subprocess + json.loads. Never a hand-rolled parser, never a silent
    fallback."""
    script_real = os.path.realpath(os.path.abspath(__file__))
    script_dir = os.path.dirname(script_real)
    candidates = [
        os.path.normpath(os.path.join(script_dir, "canonicalize-sdd-yaml.py")),
        os.path.normpath(os.path.join(script_dir, "canonicalize-sdd-yaml")),
    ]
    canonicalizer = next((c for c in candidates if os.path.isfile(c)), None)
    if canonicalizer is None:
        canonicalizer = "canonicalize-sdd-yaml"  # rely on PATH as a last resort

    try:
        if canonicalizer.endswith(".py"):
            argv = [sys.executable, canonicalizer, "--input-format", "yaml", path]
        else:
            argv = [canonicalizer, "--input-format", "yaml", path]
        result = subprocess.run(
            argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False
        )
    except OSError as exc:
        raise CanonicalizerError(str(exc))

    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise CanonicalizerError(detail or f"exit {result.returncode}")

    try:
        return json.loads(result.stdout.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise CanonicalizerError(f"non-JSON canonicalizer stdout: {exc}")


def load_summary_json(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def load_summary(path):
    if path.endswith(".yaml") or path.endswith(".yml"):
        return load_summary_yaml(path)
    return load_summary_json(path)


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

    Pure function over an already-parsed structure -- no I/O, no YAML
    handling. This is the function both the CLI (after the YAML parse
    contract) and the regression suite (against JSON fixtures) call. Unlike
    `validate-facet-manifest.py`, no semantic check beyond schema
    conformance exists for this artifact (design.md `validate-capability-
    summary` contract)."""
    if schema is None:
        schema = load_schema()
    return list(validate_against_schema(document, schema))


# --------------------------------------------------------------------------
# Diagnostic determinism contract (REQ-006, all four scripts).
# --------------------------------------------------------------------------

def format_diagnostics(diags):
    ordered = sorted(diags, key=lambda d: (d.check_id, d.pointer))
    return [f"capability-summary: {d.check_id}: {d.pointer}: {d.message}" for d in ordered]


def main(argv=None):
    # Diagnostic determinism contract: LF-only output on every runtime.
    # Python's text-mode stdout translates "\n" to os.linesep on some
    # platforms unless reconfigured; force LF explicitly.
    try:
        sys.stdout.reconfigure(newline="\n")
    except AttributeError:
        pass  # Python < 3.7: stdout is already LF on the platforms this ships to.

    parser = argparse.ArgumentParser(prog="validate-capability-summary")
    parser.add_argument("--summary", required=True)
    args = parser.parse_args(argv)

    try:
        document = load_summary(args.summary)
    except CanonicalizerError as exc:
        sys.stdout.write(f"capability-summary: canonicalizer-invocation-failed: {exc}\n")
        return 1
    # ValueError covers json.JSONDecodeError AND UnicodeDecodeError (both
    # ValueError subclasses) -- a non-UTF-8 --summary input must surface
    # this diagnostic, never an unhandled Python traceback (T-001..T-004
    # quality-gate lesson -- RT-20260817-004; not a design.md/tasks.md
    # instruction; validate-context-projection.py/compare-facet-manifest-
    # staleness.py already carried this fix, this was the one remaining gap).
    except (OSError, ValueError) as exc:
        sys.stdout.write(f"capability-summary: summary-unreadable: {exc}\n")
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
