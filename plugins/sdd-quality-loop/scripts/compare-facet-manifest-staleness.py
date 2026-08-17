#!/usr/bin/env python3
"""REQ-004/REQ-005/REQ-006: Facet Manifest staleness comparator.

Usage:
    compare-facet-manifest-staleness.py \\
      --old-manifest <path> --new-manifest <path> \\
      --projection-weakening {weakened|not-weakened|indeterminate} \\
      --registry-weakening {weakened|not-weakened|indeterminate} \\
      --ownership-weakening {weakened|not-weakened|indeterminate} \\
      --resolver-version-bump {none|patch|minor|minor-rule-set|major}

All six flags are REQUIRED on every invocation -- design.md's
`compare-facet-manifest-staleness` contract fixes the three `--*-weakening`
flags and `--resolver-version-bump` as mandatory, explicit, never expressed
by flag omission (a verification-round finding extending "B2"'s fail-closed
correction, requirements.md REQ-004 Goals). A caller with no detector for an
axis must pass `--<axis>-weakening indeterminate` explicitly; a caller for an
axis whose digest did not change passes `--<axis>-weakening not-weakened` by
convention -- never `indeterminate`/`weakened` for an unchanged axis.

Two output channels, fully separated:

- **Verdict channel** (stdout, exit 0/1/2): exactly one line,
  `facet-manifest-staleness: <status>:<reason>` -- never a bare `<status>`.
  `<status>` in {fresh, stale, blocked} maps 1:1 to exit {0, 1, 2}.
- **Diagnostic channel** (stderr, exit 3): one or more lines,
  `facet-manifest-staleness: <check-id>: <detail>`, for anything that is not
  a verdict at all -- a malformed/missing CLI argument, a schema-invalid
  input manifest, a `--resolver-version-bump` tier inconsistent with the two
  manifests actually supplied, or a canonicalizer/subprocess failure reading
  either YAML file. Exit-3 invocations never write a
  `facet-manifest-staleness: <status>:<reason>` line to stdout.

Branch order (highest precedence first, design.md `compare-facet-manifest-
staleness` contract):

  0. Argument validation: all six flags present and in-enum, both manifests
     loadable and schema-valid, `--resolver-version-bump` consistent with
     the two manifests' own `resolver.version`/`rule_set_revision` -- any
     failure -> exit 3, no further branch evaluated.
  1. Policy-Weakening / fail-closed short-circuit: for each axis (fixed
     order projection, registry, ownership) whose `context_binding` digest
     differs between old and new, a `weakened` or `indeterminate` verdict on
     that axis -> `blocked`, before any other branch (including branch 2's
     major-tier force).
  2. `--resolver-version-bump major` -> `stale` (`major-version-forced`),
     unconditionally.
  3. `--resolver-version-bump` in {none, patch} AND no axis's digest
     differs at all -> `fresh` (`unchanged`), no semantic-output
     recomputation attempted. Scoped to none/patch only -- a `minor`/
     `minor-rule-set` bump with an otherwise-unchanged `context_binding`
     always reaches branch 4 (REQ-005's minor tier requires the impact
     assessment unconditionally).
  4. Otherwise: recompute and structurally compare REQ-004's semantic
     output (every REQ-001 field except `context_binding`/`resolver`)
     between old and new -> `fresh` (`metadata-only-refresh`) if unchanged,
     `stale` (`semantic-output-changed`) if changed.

This script runs `validate-facet-manifest.py`'s own schema-conformance check
(`validate_against_schema`, not the full semantic-check suite) against both
`--old-manifest`/`--new-manifest` inputs before evaluating any branch
(design.md branch 0; Discovery contract: "compare-facet-manifest-staleness
uses the identical discovery contract to locate facet-manifest.schema.json
for its own input-shape validation before comparing") -- reused via a
same-directory sibling-module import (`importlib.util.spec_from_file_
location`), matching `check-component-coverage.py`'s own established
same-directory-import precedent for this repository, rather than a
subprocess re-invocation or a second, independent schema engine.

The sibling import is LAZY (deferred to `_load_vfm()`, called from `main()`
after argument parsing), not a module-level side effect. A module-level
import means any failure to load the sibling (missing file, syntax error,
a broken install) raises before `main()` -- and therefore before
`argparse` -- even runs, which (1) breaks `--help` (it would crash with a
traceback instead of printing usage and exiting 0) and (2) is fatal to the
Python process with an *unhandled* traceback and Python's own default exit
code 1 -- which this contract reserves exclusively for the `stale` verdict
(design.md Exit codes: "a caller can branch on exit code alone... 0 =
fresh, 1 = stale, 2 = blocked"). An installation defect must never be
indistinguishable from a legitimate `stale` verdict to a caller that only
inspects the exit code; `_load_vfm()`'s own caller in `main()` catches any
failure and reports it on the same exit-3/stderr-only diagnostic channel
every other "this is not a verdict" condition already uses (T-004
quality-gate finding, seq0761 Major-3).
"""
import argparse
import importlib.util as _il_util
import os
import sys

_SCRIPT_DIR = os.path.dirname(os.path.realpath(os.path.abspath(__file__)))

_VFM_MODULE = None


def _load_vfm():
    """Lazily import validate-facet-manifest.py (same-directory sibling).
    Cached after the first successful call. Raises on any failure -- the
    caller (main()) is responsible for turning that into the exit-3/stderr
    diagnostic channel; this function itself never touches stdout/stderr."""
    global _VFM_MODULE
    if _VFM_MODULE is not None:
        return _VFM_MODULE
    spec = _il_util.spec_from_file_location(
        "_sdd_validate_facet_manifest",
        os.path.join(_SCRIPT_DIR, "validate-facet-manifest.py"),
    )
    module = _il_util.module_from_spec(spec)
    spec.loader.exec_module(module)
    _VFM_MODULE = module
    return module


CHECK_ID = "facet-manifest-staleness"

WEAKENING_CHOICES = ("weakened", "not-weakened", "indeterminate")
BUMP_CHOICES = ("none", "patch", "minor", "minor-rule-set", "major")

# Fixed axis order (design.md: "policy-weakening-blocked:<axis>" (<axis> in
# projection/registry/ownership)) -- also the order branch 1 evaluates
# changed axes in, so a fixture with more than one changed+weakened/
# indeterminate axis has a deterministic "first-encountered" winner.
AXES = (
    ("projection", "projection_sha256"),
    ("registry", "registry_digest"),
    ("ownership", "ownership_digest"),
)

# REQ-004's semantic output: every REQ-001 top-level field except
# `context_binding` and `resolver` (ADR-0021 item 2's own boundary, applied
# literally -- requirements.md REQ-004, reversing an earlier revision's
# narrower `schema`/`feature`/`evidence` exclusion, "B1").
SEMANTIC_FIELDS = (
    "schema",
    "feature",
    "affected_components",
    "required_facets",
    "conditional_facets",
    "resolved_gates",
    "capability_minimum_enforcement",
    "capabilities",
    "lite_eligibility",
)

STATUS_EXIT = {"fresh": 0, "stale": 1, "blocked": 2}


class _ArgumentError(Exception):
    """Raised in place of argparse's default sys.exit(2) so this script can
    map every argument-shape failure to exit 3 (never argparse's own exit 2,
    which this contract reserves for the `blocked` verdict)."""


class _StalenessArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise _ArgumentError(message)


def build_parser():
    parser = _StalenessArgumentParser(prog="compare-facet-manifest-staleness")
    parser.add_argument("--old-manifest", required=True)
    parser.add_argument("--new-manifest", required=True)
    parser.add_argument("--projection-weakening", required=True, choices=WEAKENING_CHOICES)
    parser.add_argument("--registry-weakening", required=True, choices=WEAKENING_CHOICES)
    parser.add_argument("--ownership-weakening", required=True, choices=WEAKENING_CHOICES)
    parser.add_argument("--resolver-version-bump", required=True, choices=BUMP_CHOICES)
    return parser


# --------------------------------------------------------------------------
# Semver / resolver-version-bump consistency check (REQ-005).
# --------------------------------------------------------------------------

def _parse_semver(version_str):
    # Already schema-valid at this point (branch 0's schema-conformance
    # check ran first, and `resolver.version` is pattern-constrained to
    # `^[0-9]+\.[0-9]+\.[0-9]+$`) -- a plain split/int conversion is safe.
    major, minor, patch = version_str.split(".")
    return int(major), int(minor), int(patch)


def actual_bump_tier(old_doc, new_doc):
    """The semver-component tier the two manifests' own `resolver` block
    actually exhibits: the highest-order changed component wins (major over
    minor over patch); `minor-rule-set` is a same-version `rule_set_
    revision`-only edit; `none` is no change at all."""
    old_resolver = old_doc["resolver"]
    new_resolver = new_doc["resolver"]
    old_version = _parse_semver(old_resolver["version"])
    new_version = _parse_semver(new_resolver["version"])
    if old_version[0] != new_version[0]:
        return "major"
    if old_version[1] != new_version[1]:
        return "minor"
    if old_version[2] != new_version[2]:
        return "patch"
    if old_resolver["rule_set_revision"] != new_resolver["rule_set_revision"]:
        return "minor-rule-set"
    return "none"


# --------------------------------------------------------------------------
# REQ-004 branch table.
# --------------------------------------------------------------------------

def _changed_axes(old_doc, new_doc):
    old_binding = old_doc.get("context_binding", {})
    new_binding = new_doc.get("context_binding", {})
    return [
        (name, field)
        for name, field in AXES
        if old_binding.get(field) != new_binding.get(field)
    ]


def _semantic_output(doc):
    return {field: doc.get(field) for field in SEMANTIC_FIELDS}


def classify(old_doc, new_doc, weakening, resolver_version_bump):
    """Return (status, reason) per design.md's 5-branch precedence table
    (branch 0, argument/schema validation, is the caller's own
    responsibility -- this function assumes both documents are already
    schema-valid and the bump tier already cross-checked)."""
    changed = _changed_axes(old_doc, new_doc)
    changed_names = {name for name, _field in changed}

    # Branch 1: Policy-Weakening short-circuit, fixed axis order, runs
    # across ALL changed axes before any other branch.
    for name, _field in AXES:
        if name not in changed_names:
            continue
        verdict = weakening[name]
        if verdict == "weakened":
            return "blocked", f"policy-weakening-blocked:{name}"
        if verdict == "indeterminate":
            return "blocked", f"weakening-verdict-indeterminate:{name}"

    # Branch 2: major-tier forced-regardless.
    if resolver_version_bump == "major":
        return "stale", "major-version-forced"

    # Branch 3: digest-unchanged short-circuit, scoped to none/patch only
    # (a verification-round fix -- a `minor`/`minor-rule-set` bump with no
    # digest change must still reach branch 4, REQ-005).
    if resolver_version_bump in ("none", "patch") and not changed:
        return "fresh", "unchanged"

    # Branch 4: ordinary semantic-output comparison.
    if _semantic_output(old_doc) == _semantic_output(new_doc):
        return "fresh", "metadata-only-refresh"
    return "stale", "semantic-output-changed"


# --------------------------------------------------------------------------
# Diagnostic channel (stderr only, exit 3).
# --------------------------------------------------------------------------

def _emit_error(check_id, detail):
    sys.stderr.write(f"{CHECK_ID}: {check_id}: {detail}\n")
    return 3


def _emit_schema_diagnostics(old_diags, new_diags):
    lines = []
    for tag, diags in (("old-manifest", old_diags), ("new-manifest", new_diags)):
        for diag in diags:
            lines.append((f"/{tag}{diag.pointer}", diag.message))
    for pointer, message in sorted(lines):
        sys.stderr.write(f"{CHECK_ID}: schema-invalid: {pointer}: {message}\n")
    return 3


def main(argv=None):
    # Diagnostic determinism contract: LF-only output on every runtime, on
    # BOTH channels (stdout for the verdict, stderr for exit-3 diagnostics).
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(newline="\n")
        except AttributeError:
            pass  # Python < 3.7: streams are already LF on the platforms this ships to.

    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except _ArgumentError as exc:
        return _emit_error("argument-error", str(exc))

    # Lazy sibling import, deferred until after argument parsing (see module
    # docstring): a missing/broken validate-facet-manifest.py must fail
    # closed on the exit-3/stderr diagnostic channel, never as an unhandled
    # traceback that Python itself would exit with code 1 -- indistinguishable
    # from a legitimate `stale` verdict to a caller that branches on exit
    # code alone (seq0761 Major-3). Exception type is intentionally broad
    # (ImportError, SyntaxError inside the sibling file, FileNotFoundError,
    # etc. are all possible failure shapes for a corrupted/missing sibling)
    # -- anything that prevents the module from loading must be reported,
    # not selectively caught. `Exception` alone does NOT cover `SystemExit`
    # (it subclasses BaseException directly, not Exception) -- a sibling
    # module that calls sys.exit(N) at import time (e.g. a corrupted install
    # whose own top-level code aborts) previously escaped this guard
    # entirely and propagated as exit N with no diagnostic on either
    # channel, silently colliding with this contract's own fixed exit-code
    # enum (0/1/2/3) -- e.g. sys.exit(2) from the sibling would be
    # indistinguishable from this script's own `blocked` verdict (T-005
    # quality-gate lesson, RT-20260817-005 item 1; not a design.md/tasks.md
    # instruction).
    try:
        vfm = _load_vfm()
    except (Exception, SystemExit) as exc:  # noqa: BLE001 -- see comment above
        return _emit_error("validator-import-failed", str(exc))

    try:
        old_doc = vfm.load_manifest(args.old_manifest)
    except vfm.CanonicalizerError as exc:
        return _emit_error("canonicalizer-invocation-failed", f"old-manifest: {exc}")
    # ValueError covers json.JSONDecodeError AND UnicodeDecodeError (both
    # ValueError subclasses) -- a non-UTF-8 or malformed-JSON --old-manifest/
    # --new-manifest must surface this diagnostic, never an unhandled
    # Python traceback (T-001..T-003 quality-gate lesson, not a design.md/
    # tasks.md instruction).
    except (OSError, ValueError) as exc:
        return _emit_error("manifest-unreadable", f"old-manifest: {exc}")

    try:
        new_doc = vfm.load_manifest(args.new_manifest)
    except vfm.CanonicalizerError as exc:
        return _emit_error("canonicalizer-invocation-failed", f"new-manifest: {exc}")
    except (OSError, ValueError) as exc:
        return _emit_error("manifest-unreadable", f"new-manifest: {exc}")

    try:
        schema = vfm.load_schema()
    except FileNotFoundError as exc:
        return _emit_error("schema-discovery-failed", str(exc))

    old_diags = vfm.validate_against_schema(old_doc, schema)
    new_diags = vfm.validate_against_schema(new_doc, schema)
    if old_diags or new_diags:
        return _emit_schema_diagnostics(old_diags, new_diags)

    declared_bump = args.resolver_version_bump
    actual_tier = actual_bump_tier(old_doc, new_doc)
    if declared_bump != actual_tier:
        old_resolver = old_doc["resolver"]
        new_resolver = new_doc["resolver"]
        return _emit_error(
            "resolver-version-bump-inconsistent",
            f"declared '{declared_bump}' but the two manifests' own resolver "
            f"block actually differs at tier '{actual_tier}' "
            f"(old: version={old_resolver['version']!r} "
            f"rule_set_revision={old_resolver['rule_set_revision']!r}; "
            f"new: version={new_resolver['version']!r} "
            f"rule_set_revision={new_resolver['rule_set_revision']!r})",
        )

    weakening = {
        "projection": args.projection_weakening,
        "registry": args.registry_weakening,
        "ownership": args.ownership_weakening,
    }
    status, reason = classify(old_doc, new_doc, weakening, declared_bump)
    sys.stdout.write(f"{CHECK_ID}: {status}:{reason}\n")
    return STATUS_EXIT[status]


if __name__ == "__main__":
    sys.exit(main())
