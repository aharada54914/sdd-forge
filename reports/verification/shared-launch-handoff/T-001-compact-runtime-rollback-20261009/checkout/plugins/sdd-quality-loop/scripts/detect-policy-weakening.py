#!/usr/bin/env python3
"""detect-policy-weakening (REQ-006, epic-189-a1-project-context T-005).

Compares a candidate `project-context.yaml`/`provider-bindings.yaml`
against the currently-APPROVED anchor (never git HEAD, never a
caller-supplied path on the production call path) and classifies the diff
against the nine canonical weakening categories decision doc Section 9
names (design.md "Policy-weakening categories"): exactly THREE are
implemented against A1's schema (`capability_enforcement` weakened,
component path narrowed via the glob-coverage-narrowing algorithm,
`spec_profile` `full`->`lite`); the other SIX are reported `n/a` in every
run, explicitly, never a silent omission and never an invented proxy
classification.

Trust anchor (design.md "Weakening-detector approved-context anchor CLI
contract"): resolved INTERNALLY by reading the protected snapshot
`sdd/.approved-context/<schema-basename>.approved.yaml` (relative to the
current working directory, matching this epic's other scripts'
`sdd/.staging/...`-relative convention -- these tools are invoked from the
project root). `--approved-context` exists ONLY for this script's own
fixture-driven tests (REQ-011); `generate-approval-sidecar.py` and
`validate-approval-sidecar.py` MUST invoke `compute_verdict()` below
WITHOUT overriding it -- there is no way to reach a caller-supplied anchor
on the production call path. No anchor snapshot yet (first-ever publish
for this schema, `NO_APPROVED_CONTEXT_ANCHOR`) is a documented, non-error
bootstrap condition: every category reports `not_weakened`/`n/a`, since
nothing previously approved exists to narrow.

Diffs run over REQ-003's canonicalizer output (`canonicalize-sdd-yaml.py`,
dispatched as a subprocess -- never reimplemented; every parse of the
candidate, the approved-context anchor, or `sdd/approver-registry.yaml`
goes through it).

Two-person/cooldown verdict: for a change classified as policy-weakening
(any ONE of the three implemented categories), this module additionally
reads `sdd/approver-registry.yaml` (relative to the current working
directory, no override flag -- REQ-007-protected once T-007/T-009 land)
and counts its DISTINCT `id` entries: `two_person_required: true` when
there are 2 or more; else `two_person_required: false` with
`cooldown_hours: 24`. A registry file that does not exist yet is treated
identically to a present-but-empty (`approvers: []`) registry -- both are
the same documented zero-identity boundary (AC-046) -- but an OSError on
an EXISTING file (or genuinely malformed content) fails closed
(`APPROVER_REGISTRY_UNREADABLE`), never silently treated as zero.

`compute_verdict(candidate_path, approved_context_path=None)` is the
SINGLE in-process seam `generate-approval-sidecar.py` (T-003) and
`validate-approval-sidecar.py` (T-006) call directly -- it returns EXACTLY
the 4-key `weakening_verdict` shape `contracts/approval-sidecar.schema.json`
defines (`policy_weakening`, `categories`, `two_person_required`,
`cooldown_hours`), since callers embed this return value verbatim as the
sidecar's own `weakening_verdict` field; it never accepts or trusts a
caller-supplied verdict, and never passes `approved_context_path` from a
production call site. `generate-approval-sidecar.py`/`.py` never accept a
pre-computed verdict as an input -- this module is the ONLY place one may
come from (requirements.md REQ-006).
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
from pathlib import Path

EXIT_USAGE_ERROR = 2

CATEGORY_EXIT_CODES = {
    "CANDIDATE_NOT_SCHEMA_VALID": 20,
    "HUMAN_COPY_PUBLISH_IN_PROGRESS": 21,
    "APPROVED_CONTEXT_ANCHOR_UNREADABLE": 22,
    "APPROVER_REGISTRY_UNREADABLE": 23,
}

# schema id (candidate's own `schema` field) -> the basename the approved-
# context anchor snapshot shares (`sdd/.approved-context/<basename>.approved.yaml`),
# per design.md's Data Plan / CLI contract. Deliberately the candidate's OWN
# content schema id, not the *-approval/v1 sidecar schema id T-003/T-004 use.
SCHEMA_BASENAMES = {
    "sdd-project-context/v1": "project-context",
    "sdd-provider-bindings/v1": "provider-bindings",
}

IMPLEMENTED_CATEGORIES = (
    "capability_enforcement_weakened",
    "component_path_narrowed",
    "spec_profile_full_to_lite",
)

NA_CATEGORIES = (
    "capability_removed",
    "public_distribution_descoped",
    "criticality_lowered",
    "provider_allowlist_widened",
    "production_write_path_changed",
    "required_gate_removed",
)

COOLDOWN_HOURS = 24


class DetectPolicyWeakeningError(Exception):
    """A documented, category-specific refusal -- never an uncaught
    traceback (Lessons learned from T-002/T-003's quality-gate rounds)."""

    def __init__(self, category, message):
        super().__init__(message)
        self.category = category
        self.message = message


# ---------------------------------------------------------------------------
# Canonicalizer dispatch (REQ-003) -- never reimplemented. Every parse of a
# candidate, an approved-context anchor, or the approver registry goes
# through this one function.
# ---------------------------------------------------------------------------


def _canonicalizer_path():
    return Path(__file__).resolve().parent / "canonicalize-sdd-yaml.py"


def _load_schema_document(path, failure_category):
    """Dispatches `path` to canonicalize-sdd-yaml.py (YAML input mode) and
    returns the parsed canonical JSON object. Any non-zero exit (missing
    file, a document that canonicalizes to a non-object such as an empty
    file, or hostile/out-of-subset YAML) is wrapped as
    `DetectPolicyWeakeningError(failure_category, ...)` -- never an
    uncaught traceback."""
    canon_path = _canonicalizer_path()
    try:
        proc = subprocess.run(
            [sys.executable, str(canon_path), str(path), "--input-format", "yaml"],
            capture_output=True,
        )
    except OSError as exc:
        raise DetectPolicyWeakeningError(
            failure_category, f"could not invoke canonicalize-sdd-yaml.py: {exc}",
        ) from exc
    if proc.returncode != 0:
        stderr_text = proc.stderr.decode("utf-8", errors="replace").strip()
        raise DetectPolicyWeakeningError(
            failure_category,
            f"canonicalize-sdd-yaml rejected {str(path)!r} (exit {proc.returncode}): {stderr_text}",
        )
    try:
        obj = json.loads(proc.stdout.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise DetectPolicyWeakeningError(
            failure_category, f"canonicalizer output for {str(path)!r} is not valid JSON: {exc}",
        ) from exc
    if not isinstance(obj, dict):
        raise DetectPolicyWeakeningError(
            failure_category,
            f"{str(path)!r} must be a YAML mapping/object at the top level (a "
            "project-context/provider-bindings document is expected)",
        )
    return obj


# ---------------------------------------------------------------------------
# Approved-context anchor resolution (design.md "Weakening-detector
# approved-context anchor CLI contract").
# ---------------------------------------------------------------------------


def _default_anchor_path(basename):
    return os.path.join("sdd", ".approved-context", f"{basename}.approved.yaml")


def _default_registry_path():
    return os.path.join("sdd", "approver-registry.yaml")


def _staging_transaction_journals():
    return sorted(glob.glob(os.path.join("sdd", ".staging", "*", "TRANSACTION.json")))


def _check_no_publish_in_progress(*paths_being_read):
    """Reader-side generation-consistency check (design.md, closes the
    read-during-publish race): discards the read (raises
    `HUMAN_COPY_PUBLISH_IN_PROGRESS`) if a live
    `sdd/.staging/*/TRANSACTION.json` journal names any of
    `paths_being_read` among its listed targets' `live_path` entries. A
    journal that exists but cannot be parsed is ITSELF treated as an
    in-progress signal (fail-closed -- a torn/unreadable journal is never
    silently ignored just because it could not be parsed)."""
    normalized_targets = {os.path.normpath(p) for p in paths_being_read}
    for journal_path in _staging_transaction_journals():
        try:
            with open(journal_path, "r", encoding="utf-8") as f:
                journal = json.load(f)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise DetectPolicyWeakeningError(
                "HUMAN_COPY_PUBLISH_IN_PROGRESS",
                f"a human-copy transaction journal exists at {journal_path!r} but "
                f"could not be read/parsed ({exc}); treated as a possibly-torn "
                "in-progress publish rather than proceeding on unverifiable state",
            ) from exc
        targets = journal.get("targets") if isinstance(journal, dict) else None
        if not isinstance(targets, list):
            continue
        for target in targets:
            live_path = target.get("live_path") if isinstance(target, dict) else None
            if isinstance(live_path, str) and os.path.normpath(live_path) in normalized_targets:
                raise DetectPolicyWeakeningError(
                    "HUMAN_COPY_PUBLISH_IN_PROGRESS",
                    f"a live human-copy transaction journal at {journal_path!r} "
                    f"names {live_path!r}, which this invocation is about to read; "
                    "refusing to proceed on possibly torn cross-file state",
                )


def _count_distinct_registry_identities():
    """Reads `sdd/approver-registry.yaml` (already REQ-004-schema-validated
    at write time, T-004's Out of Scope here) and returns the count of
    DISTINCT `id` entries. A registry file that does not exist yet is
    treated identically to a present-but-empty (`approvers: []`) registry
    -- both are the documented zero-identity boundary (AC-046), never an
    error. A genuine read/parse failure on an EXISTING file fails closed
    instead (`APPROVER_REGISTRY_UNREADABLE`), never silently treated as
    zero."""
    path = _default_registry_path()
    if not os.path.isfile(path):
        return 0
    registry_obj = _load_schema_document(path, "APPROVER_REGISTRY_UNREADABLE")
    approvers = registry_obj.get("approvers")
    if not isinstance(approvers, list):
        raise DetectPolicyWeakeningError(
            "APPROVER_REGISTRY_UNREADABLE",
            f"{path!r} has no valid 'approvers' array",
        )
    distinct_ids = set()
    for entry in approvers:
        if isinstance(entry, dict) and isinstance(entry.get("id"), str):
            distinct_ids.add(entry["id"])
    return len(distinct_ids)


# ---------------------------------------------------------------------------
# Glob-coverage narrowing algorithm (design.md "Policy-weakening
# categories", closes M13).
# ---------------------------------------------------------------------------

_GLOB_META_RE = re.compile(r"[*?\[]")


def _scope_prefix(pattern):
    """The substring before `pattern`'s first glob metacharacter (`*`, `?`,
    `[`), normalized to use `/` -- a literal path with no metacharacter is
    its own scope prefix."""
    normalized = pattern.replace("\\", "/")
    m = _GLOB_META_RE.search(normalized)
    return normalized[: m.start()] if m else normalized


def _scope_prefix_set(patterns):
    return {_scope_prefix(p) for p in patterns if isinstance(p, str)}


def _include_narrows(baseline_prefixes, candidate_prefixes):
    """Some `p` in the baseline has NO `q` in the candidate such that `q`
    is a prefix of (or equal to) `p` -- candidate no longer includes
    anything at or under a path the baseline used to include. Covers both
    outright removal (fewer patterns) and replacement of a broad pattern
    with a more specific one at an unchanged pattern count."""
    for p in baseline_prefixes:
        if not any(p.startswith(q) for q in candidate_prefixes):
            return True
    return False


def _exclude_widens(baseline_prefixes, candidate_prefixes):
    """Some `q` in the candidate has NO `p` in the baseline such that `p`
    is a prefix of (or equal to) `q` -- candidate excludes something (or a
    broader region) the baseline did not."""
    for q in candidate_prefixes:
        if not any(q.startswith(p) for p in baseline_prefixes):
            return True
    return False


def _component_path_narrows(baseline_components, candidate_components):
    baseline_by_id = {
        c["id"]: c for c in baseline_components
        if isinstance(c, dict) and isinstance(c.get("id"), str)
    }
    candidate_by_id = {
        c["id"]: c for c in candidate_components
        if isinstance(c, dict) and isinstance(c.get("id"), str)
    }
    for comp_id, baseline_comp in baseline_by_id.items():
        candidate_comp = candidate_by_id.get(comp_id)
        if candidate_comp is None:
            # The component itself was removed entirely: the ultimate
            # narrowing of whatever effective path ownership it had.
            return True
        b_paths = baseline_comp.get("paths") or {}
        c_paths = candidate_comp.get("paths") or {}
        b_inc = _scope_prefix_set(b_paths.get("include") or [])
        c_inc = _scope_prefix_set(c_paths.get("include") or [])
        b_exc = _scope_prefix_set(b_paths.get("exclude") or [])
        c_exc = _scope_prefix_set(c_paths.get("exclude") or [])
        if _include_narrows(b_inc, c_inc) or _exclude_widens(b_exc, c_exc):
            return True
    return False


# ---------------------------------------------------------------------------
# Category classification (design.md "Policy-weakening categories").
# ---------------------------------------------------------------------------


def _workflow_field(obj, name):
    return ((obj or {}).get("workflow") or {}).get(name)


def _capability_enforcement_weakened(baseline_obj, candidate_obj):
    return (
        _workflow_field(baseline_obj, "capability_enforcement") == "required"
        and _workflow_field(candidate_obj, "capability_enforcement") == "advisory"
    )


def _spec_profile_full_to_lite(baseline_obj, candidate_obj):
    return (
        _workflow_field(baseline_obj, "spec_profile") == "full"
        and _workflow_field(candidate_obj, "spec_profile") == "lite"
    )


def _classify_categories(baseline_obj, candidate_obj):
    categories = {name: "n/a" for name in NA_CATEGORIES}
    categories["capability_enforcement_weakened"] = (
        "weakened" if _capability_enforcement_weakened(baseline_obj, candidate_obj) else "not_weakened"
    )
    categories["component_path_narrowed"] = (
        "weakened"
        if _component_path_narrows(
            (baseline_obj or {}).get("components") or [],
            (candidate_obj or {}).get("components") or [],
        )
        else "not_weakened"
    )
    categories["spec_profile_full_to_lite"] = (
        "weakened" if _spec_profile_full_to_lite(baseline_obj, candidate_obj) else "not_weakened"
    )
    return categories


# ---------------------------------------------------------------------------
# Verdict computation (public in-process seam + CLI).
# ---------------------------------------------------------------------------


def _compute_verdict_and_anchor_status(candidate_path, approved_context_path=None):
    candidate_obj = _load_schema_document(candidate_path, "CANDIDATE_NOT_SCHEMA_VALID")
    schema_id = candidate_obj.get("schema")
    if schema_id not in SCHEMA_BASENAMES:
        raise DetectPolicyWeakeningError(
            "CANDIDATE_NOT_SCHEMA_VALID",
            f"candidate {str(candidate_path)!r} has no recognized 'schema' field "
            f"(got {schema_id!r}; expected one of {sorted(SCHEMA_BASENAMES)})",
        )
    basename = SCHEMA_BASENAMES[schema_id]

    anchor_path = (
        approved_context_path if approved_context_path is not None
        else _default_anchor_path(basename)
    )

    _check_no_publish_in_progress(anchor_path)

    anchor_present = os.path.isfile(anchor_path)
    baseline_obj = (
        _load_schema_document(anchor_path, "APPROVED_CONTEXT_ANCHOR_UNREADABLE")
        if anchor_present else None
    )

    categories = _classify_categories(baseline_obj, candidate_obj)
    policy_weakening = any(categories[name] == "weakened" for name in IMPLEMENTED_CATEGORIES)

    if not policy_weakening:
        verdict = {
            "policy_weakening": False,
            "categories": categories,
            "two_person_required": False,
            "cooldown_hours": None,
        }
    else:
        distinct_count = _count_distinct_registry_identities()
        two_person_required = distinct_count >= 2
        verdict = {
            "policy_weakening": True,
            "categories": categories,
            "two_person_required": two_person_required,
            "cooldown_hours": None if two_person_required else COOLDOWN_HOURS,
        }
    return verdict, anchor_present


def compute_verdict(candidate_path, approved_context_path=None):
    """Public in-process seam. `generate-approval-sidecar.py` (T-003) and
    `validate-approval-sidecar.py` (T-006) call this DIRECTLY, WITHOUT
    `approved_context_path` -- production callers never override the
    anchor (requirements.md REQ-006's "generator/validator never trust an
    externally-supplied verdict, and never re-derive from a
    caller-suppliable anchor"). Returns EXACTLY the 4-key
    `weakening_verdict` shape `contracts/approval-sidecar.schema.json`
    defines -- no extra key, since this return value is embedded verbatim
    as the sidecar's own `weakening_verdict` field."""
    verdict, _anchor_present = _compute_verdict_and_anchor_status(candidate_path, approved_context_path)
    return verdict


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

_EXIT_CODE_HELP = "\n".join(
    f"  {code:>3}  {name}" for name, code in sorted(CATEGORY_EXIT_CODES.items(), key=lambda kv: kv[1])
)


def build_arg_parser():
    parser = argparse.ArgumentParser(
        prog="detect-policy-weakening.py",
        description=(
            "Classify a candidate project-context.yaml/provider-bindings.yaml "
            "against the currently-approved anchor over the nine canonical "
            "weakening categories (three implemented, six documented N/A), and "
            "emit a machine-readable weakening_verdict JSON object on stdout."
        ),
        epilog="Exit codes (stable, one per rejection category):\n"
        f"    0  success (a verdict was emitted; NO_APPROVED_CONTEXT_ANCHOR is a\n"
        f"       documented, non-error condition noted on stderr, not a rejection)\n"
        f"  {EXIT_USAGE_ERROR:>3}  usage error (bad arguments)\n"
        f"{_EXIT_CODE_HELP}\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--candidate", required=True, help="path to the working-tree/staged content file being evaluated")
    parser.add_argument(
        "--approved-context", default=None,
        help="TEST-ONLY override of the trust anchor path (REQ-011 fixtures only; "
        "never used by generate-approval-sidecar.py/validate-approval-sidecar.py)",
    )
    return parser


def main(argv=None):
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    try:
        verdict, anchor_present = _compute_verdict_and_anchor_status(
            args.candidate, args.approved_context,
        )
    except DetectPolicyWeakeningError as exc:
        print(f"detect-policy-weakening: {exc.category}: {exc.message}", file=sys.stderr)
        return CATEGORY_EXIT_CODES.get(exc.category, 1)

    if not anchor_present:
        print(
            "detect-policy-weakening: NO_APPROVED_CONTEXT_ANCHOR: no approved-context "
            "anchor snapshot exists yet for this schema (first-ever publish); every "
            "category is treated as a new addition, not a weakening of anything "
            "previously approved",
            file=sys.stderr,
        )

    print(json.dumps(verdict, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
