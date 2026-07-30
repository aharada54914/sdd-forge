#!/usr/bin/env python3
"""generate-approval-sidecar (REQ-004, epic-189-a1-project-context T-003).

Human/CI-only tool: computes `context_sha256` for a Project Context or
Provider Binding content file (via REQ-003's canonicalizer, dispatched as a
subprocess -- never reimplemented), HMAC-SHA256-signs an approval sidecar
object, and writes ONLY a staged candidate to `sdd/.staging/<schema-id>/
<nonce>/` -- it NEVER opens the live `sdd/*.approval.json` sidecar path, nor
the live `sdd/.approved-context/*.approved.yaml` anchor path, for writing
under any invocation (design.md "HMAC preimage and signing", B7).

Operational constraint (documented, not technically enforced by this script):
an agent may author and test this script, but the actual SIGNING invocation
always requires a human or CI principal holding `SDD_CONTEXT_KEY` -- this
tool never runs with agent-accessible credentials as part of an agent-driven
workflow (Roles and Permissions, requirements.md).

Provenance-field resolution (predecessor_context_sha256 / weakening_verdict /
approval_epoch): reads the CURRENTLY-LIVE sidecar for this schema, if one
exists (`--live-sidecar`). If none exists (bootstrap, first-ever publish),
the three fields are null/null/1. If one exists, `weakening_verdict` is
resolved via an IN-PROCESS invocation seam (`_invoke_weakening_detector_seam`)
that dispatches to T-005's `detect-policy-weakening.py` (`compute_verdict()`,
called WITHOUT an anchor override -- the production call path never
supplies one). This tool never accepts a caller-supplied verdict
(requirements.md REQ-006) -- the seam is the ONLY place one may come from.
If the detector module is missing, fails to load, or exposes no
`compute_verdict()` entry point, every non-bootstrap transition fails
CLOSED with `WEAKENING_DETECTOR_UNAVAILABLE` (tasks.md T-003 Out of Scope,
completed by T-005's wiring). Any exception `compute_verdict()` itself
raises (its own named diagnostic, or an unexpected error) is classified as
a documented `generate-approval-sidecar` failure rather than an uncaught
traceback (`WEAKENING_DETECTOR_ERROR`, or the detector's own category
passed through verbatim); a verdict that is malformed, non-serializable,
or `None` for a non-bootstrap transition is rejected before preimage
construction (`WEAKENING_VERDICT_MALFORMED` -- T-003 QG round-2 seq0352
advance findings, closed by T-005's wiring).

Out of scope (see tasks.md T-003/T-005): full sidecar re-validation
(T-006), and publishing the staged candidate to its live path (T-007's
`apply-human-copy`).
"""
import argparse
import hashlib
import hmac
import importlib.util
import json
import os
import secrets
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

EXIT_USAGE_ERROR = 2

CATEGORY_EXIT_CODES = {
    "DUPLICATE_APPROVER_IDENTITY": 10,
    "NO_CONTEXT_KEY": 11,
    "WEAKENING_DETECTOR_UNAVAILABLE": 12,
    "CONTENT_CANONICALIZATION_FAILED": 13,
    "PREIMAGE_CANONICALIZATION_FAILED": 14,
    "LIVE_SIDECAR_UNREADABLE": 15,
    "STAGING_IO_ERROR": 16,
    # T-005 wiring completion (T-003 QG round-2 seq0352 advance findings):
    # the compute_verdict() call site itself must be inside the classified
    # try-wrap, and its return value validated BEFORE preimage construction.
    "WEAKENING_DETECTOR_ERROR": 17,
    "WEAKENING_VERDICT_MALFORMED": 18,
    # Pass-through categories: detect-policy-weakening.py's own named
    # diagnostics, re-raised verbatim by the seam rather than collapsed into
    # a generic label (category-specific diagnostic discipline, T-002/T-003
    # gate lessons).
    "CANDIDATE_NOT_SCHEMA_VALID": 20,
    "HUMAN_COPY_PUBLISH_IN_PROGRESS": 21,
    "APPROVED_CONTEXT_ANCHOR_UNREADABLE": 22,
    "APPROVER_REGISTRY_UNREADABLE": 23,
    # Test-only hook (AC-034/TEST-034); never produced by a real signing run.
    "SIMULATED_MID_WRITE_FAILURE": 90,
}

# schema id (as declared in contracts/approval-sidecar.schema.json's `schema`
# enum) -> the basename every sibling artifact (live sidecar, approved-context
# anchor, staged candidate/snapshot) shares, per design.md's Data Plan.
SCHEMA_BASENAMES = {
    "sdd-project-context-approval/v1": "project-context",
    "sdd-provider-bindings-approval/v1": "provider-bindings",
}


class GenerateApprovalSidecarError(Exception):
    """A documented, category-specific refusal -- never an uncaught
    traceback (Lessons learned from T-002's quality-gate rounds)."""

    def __init__(self, category, message):
        super().__init__(message)
        self.category = category
        self.message = message


# ---------------------------------------------------------------------------
# SDD_CONTEXT_KEY resolution -- byte-parity with `_resolve_sudo_key`
# (sdd-hook-guard.py:350-380) / `resolve_evidence_key`
# (generate-evidence-bundle.sh:314-338), per AC-013/TEST-013. Identical
# 3-step-plus-none algorithm; only the env var names and home-relative
# filename differ.
# ---------------------------------------------------------------------------


def _strip_key_bytes(raw):
    """Drop a leading UTF-8 BOM and strip trailing whitespace/newlines."""
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    return raw.rstrip(b" \t\r\n")


def resolve_context_key():
    """Resolve SDD_CONTEXT_KEY bytes per the documented 4-case order:
    env SDD_CONTEXT_KEY -> env SDD_CONTEXT_KEY_FILE -> <HOME>/.sdd/context-key
    -> None (fail-closed). Returns key bytes or None."""
    env_key = os.environ.get("SDD_CONTEXT_KEY")
    if env_key:
        return env_key.encode("utf-8")
    env_key_file = os.environ.get("SDD_CONTEXT_KEY_FILE")
    if env_key_file:
        try:
            with open(env_key_file, "rb") as f:
                raw = _strip_key_bytes(f.read())
            if raw:
                return raw
        except OSError:
            pass
        return None
    home = os.environ.get("HOME") or os.environ.get("USERPROFILE", "")
    if home:
        key_path = os.path.join(home, ".sdd", "context-key")
        try:
            with open(key_path, "rb") as f:
                raw = _strip_key_bytes(f.read())
            if raw:
                return raw
        except OSError:
            pass
    return None


# ---------------------------------------------------------------------------
# Canonicalizer dispatch (REQ-003) -- never reimplemented. Every call to
# canonicalize-sdd-yaml.py goes through this one function.
# ---------------------------------------------------------------------------


def _canonicalizer_path():
    return Path(__file__).resolve().parent / "canonicalize-sdd-yaml.py"


def _run_canonicalizer(data_bytes, input_format, hash_only, failure_category):
    """Dispatch `data_bytes` to canonicalize-sdd-yaml.py as a subprocess
    (never reimplemented -- task instruction). Returns stdout bytes on
    success. Any non-zero exit (malformed/hostile input, e.g. an invalid
    UTF-8 lone surrogate the canonicalizer itself rejects) is wrapped as a
    `GenerateApprovalSidecarError(failure_category, ...)` carrying the
    canonicalizer's own diagnostic text -- never an uncaught traceback and
    never silently ignored."""
    canon_path = _canonicalizer_path()
    tmp_fd, tmp_path = tempfile.mkstemp(prefix="generate-approval-sidecar-")
    try:
        with os.fdopen(tmp_fd, "wb") as f:
            f.write(data_bytes)
        argv = [sys.executable, str(canon_path), tmp_path, "--input-format", input_format]
        if hash_only:
            argv.append("--hash-only")
        try:
            proc = subprocess.run(argv, capture_output=True)
        except OSError as exc:
            raise GenerateApprovalSidecarError(
                failure_category,
                f"could not invoke canonicalize-sdd-yaml.py: {exc}",
            ) from exc
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

    if proc.returncode != 0:
        stderr_text = proc.stderr.decode("utf-8", errors="replace").strip()
        raise GenerateApprovalSidecarError(
            failure_category,
            f"canonicalize-sdd-yaml rejected input (exit {proc.returncode}): {stderr_text}",
        )
    return proc.stdout


def _hash_content_file(content_bytes):
    """context_sha256 (REQ-003 against the live content file's bytes)."""
    stdout = _run_canonicalizer(
        content_bytes, input_format="yaml", hash_only=True,
        failure_category="CONTENT_CANONICALIZATION_FAILED",
    )
    return stdout.decode("ascii").strip()


def _canonicalize_json_preimage(obj):
    """Preimage bytes: canonicalize-sdd-yaml applied to `obj` (a plain dict,
    the `hmac` key already excluded by the caller), JSON input mode."""
    try:
        text = json.dumps(obj)
        data_bytes = text.encode("utf-8")
    except UnicodeEncodeError as exc:
        # Defensive: json.dumps (ensure_ascii=True, the default) already
        # escapes any non-ASCII code point -- including an unpaired UTF-16
        # surrogate -- as a literal \uXXXX ASCII sequence, so this branch is
        # not expected to be reachable in practice. Kept as a documented
        # fail-closed backstop rather than an uncaught traceback.
        raise GenerateApprovalSidecarError(
            "PREIMAGE_CANONICALIZATION_FAILED",
            f"a field could not be encoded as UTF-8: {exc}",
        ) from exc
    return _run_canonicalizer(
        data_bytes, input_format="json", hash_only=False,
        failure_category="PREIMAGE_CANONICALIZATION_FAILED",
    )


# ---------------------------------------------------------------------------
# Provenance-field resolution (design.md "HMAC preimage and signing").
# ---------------------------------------------------------------------------


_WEAKENING_VERDICT_REQUIRED_KEYS = {
    "policy_weakening", "categories", "two_person_required", "cooldown_hours",
}
_WEAKENING_VERDICT_ENUM_CATEGORIES = {
    "capability_enforcement_weakened", "component_path_narrowed", "spec_profile_full_to_lite",
}
_WEAKENING_VERDICT_NA_CATEGORIES = {
    "capability_removed", "public_distribution_descoped", "criticality_lowered",
    "provider_allowlist_widened", "production_write_path_changed", "required_gate_removed",
}
_WEAKENING_VERDICT_CATEGORY_KEYS = _WEAKENING_VERDICT_ENUM_CATEGORIES | _WEAKENING_VERDICT_NA_CATEGORIES


def _validate_weakening_verdict_shape(verdict):
    """(T-003 QG round-2 seq0352 advance findings #2/#3, closed by T-005's
    wiring): the detector's return value must be schema-shaped and
    JSON-serializable BEFORE it reaches HMAC preimage construction -- a
    malformed, non-serializable, or (for a non-bootstrap transition) `None`
    verdict is a classified rejection here, never a downstream TypeError
    or a silently-embedded `weakening_verdict: null` in violation of
    requirements.md:310-312's invariant."""
    if verdict is None:
        raise GenerateApprovalSidecarError(
            "WEAKENING_VERDICT_MALFORMED",
            "detect-policy-weakening.py's compute_verdict() returned None for a "
            "non-bootstrap transition; requirements.md's historical "
            "weakening-binding invariant requires a non-null weakening_verdict "
            "whenever a predecessor anchor exists (only the first-ever, "
            "bootstrap publish may embed null)",
        )
    if not isinstance(verdict, dict) or set(verdict.keys()) != _WEAKENING_VERDICT_REQUIRED_KEYS:
        raise GenerateApprovalSidecarError(
            "WEAKENING_VERDICT_MALFORMED",
            "detect-policy-weakening.py's compute_verdict() returned a malformed "
            f"verdict (expected exactly the keys {sorted(_WEAKENING_VERDICT_REQUIRED_KEYS)}): "
            f"{verdict!r}",
        )
    if not isinstance(verdict["policy_weakening"], bool):
        raise GenerateApprovalSidecarError(
            "WEAKENING_VERDICT_MALFORMED", "weakening_verdict.policy_weakening must be a boolean",
        )
    if not isinstance(verdict["two_person_required"], bool):
        raise GenerateApprovalSidecarError(
            "WEAKENING_VERDICT_MALFORMED", "weakening_verdict.two_person_required must be a boolean",
        )
    cooldown = verdict["cooldown_hours"]
    if isinstance(cooldown, bool) or (cooldown is not None and not isinstance(cooldown, (int, float))):
        raise GenerateApprovalSidecarError(
            "WEAKENING_VERDICT_MALFORMED", "weakening_verdict.cooldown_hours must be null or a number",
        )
    categories = verdict["categories"]
    if not isinstance(categories, dict) or set(categories.keys()) != _WEAKENING_VERDICT_CATEGORY_KEYS:
        raise GenerateApprovalSidecarError(
            "WEAKENING_VERDICT_MALFORMED",
            "weakening_verdict.categories must have exactly the keys "
            f"{sorted(_WEAKENING_VERDICT_CATEGORY_KEYS)}",
        )
    for name, value in categories.items():
        if name in _WEAKENING_VERDICT_ENUM_CATEGORIES:
            if value not in ("weakened", "not_weakened"):
                raise GenerateApprovalSidecarError(
                    "WEAKENING_VERDICT_MALFORMED",
                    f"weakening_verdict.categories.{name} must be 'weakened' or 'not_weakened' "
                    f"(got {value!r})",
                )
        elif value != "n/a":
            raise GenerateApprovalSidecarError(
                "WEAKENING_VERDICT_MALFORMED",
                f"weakening_verdict.categories.{name} must be 'n/a' (got {value!r})",
            )
    try:
        json.dumps(verdict)
    except (TypeError, ValueError) as exc:
        raise GenerateApprovalSidecarError(
            "WEAKENING_VERDICT_MALFORMED", f"weakening_verdict is not JSON-serializable: {exc}",
        ) from exc


def _invoke_weakening_detector_seam(candidate_content_path):
    """The single, in-process invocation seam through which T-005's
    `detect-policy-weakening.py` is wired in (tasks.md T-005 Planned
    Files). `generate-approval-sidecar` never accepts a caller-supplied
    weakening verdict (requirements.md REQ-006) -- this is the ONLY place
    a verdict may come from, and it never passes an anchor override (the
    production call path always uses the detector's own internally-
    resolved, protected approved-context anchor). If the detector module
    is absent, fails to load, or exposes no `compute_verdict()` entry
    point, every non-bootstrap transition fails CLOSED here with
    `WEAKENING_DETECTOR_UNAVAILABLE`."""
    detector_path = Path(__file__).resolve().parent / "detect-policy-weakening.py"
    if not detector_path.is_file():
        raise GenerateApprovalSidecarError(
            "WEAKENING_DETECTOR_UNAVAILABLE",
            "detect-policy-weakening.py (T-005) is not present in-process; "
            "cannot resolve a weakening verdict for a non-bootstrap transition",
        )
    spec = importlib.util.spec_from_file_location("_sdd_detect_policy_weakening", detector_path)
    if spec is None or spec.loader is None:
        raise GenerateApprovalSidecarError(
            "WEAKENING_DETECTOR_UNAVAILABLE",
            "detect-policy-weakening.py could not be loaded as a module",
        )
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as exc:  # noqa: BLE001 - any load failure is the same seam-unavailable outcome
        raise GenerateApprovalSidecarError(
            "WEAKENING_DETECTOR_UNAVAILABLE",
            f"detect-policy-weakening.py failed to load: {exc}",
        ) from exc
    if not hasattr(module, "compute_verdict"):
        raise GenerateApprovalSidecarError(
            "WEAKENING_DETECTOR_UNAVAILABLE",
            "detect-policy-weakening.py has no compute_verdict() entry point",
        )

    # (T-003 QG round-2 seq0352 advance finding #1): the compute_verdict()
    # CALL SITE itself -- not merely the module load above -- must sit
    # inside the classified try-wrap: any exception it raises must surface
    # as a documented, classified failure, never a raw traceback.
    detector_error_type = getattr(module, "DetectPolicyWeakeningError", None)
    try:
        verdict = module.compute_verdict(candidate_content_path)
    except Exception as exc:  # noqa: BLE001 - every exception here must be classified
        if detector_error_type is not None and isinstance(exc, detector_error_type):
            # Pass through the detector's OWN named category verbatim (it is
            # already a stable, documented diagnostic) rather than
            # collapsing it into a generic label.
            raise GenerateApprovalSidecarError(exc.category, exc.message) from exc
        raise GenerateApprovalSidecarError(
            "WEAKENING_DETECTOR_ERROR",
            f"detect-policy-weakening.py's compute_verdict() raised an unexpected "
            f"error: {exc!r}",
        ) from exc

    # (finding #2/#3): validate BEFORE returning to the caller, so an
    # invalid verdict never reaches preimage construction.
    _validate_weakening_verdict_shape(verdict)
    return verdict


def _resolve_provenance(live_sidecar_path, content_path):
    """Returns (predecessor_context_sha256, weakening_verdict, approval_epoch).
    Bootstrap (no live sidecar exists yet for this schema): (None, None, 1).
    Non-bootstrap: reads the live sidecar's own context_sha256/approval_epoch,
    then resolves weakening_verdict via the in-process seam (always fails
    closed until T-005 lands)."""
    if not live_sidecar_path or not os.path.isfile(live_sidecar_path):
        return None, None, 1

    try:
        with open(live_sidecar_path, "r", encoding="utf-8") as f:
            live = json.load(f)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise GenerateApprovalSidecarError(
            "LIVE_SIDECAR_UNREADABLE",
            f"cannot parse live sidecar at {live_sidecar_path!r}: {exc}",
        ) from exc

    predecessor_context_sha256 = live.get("context_sha256") if isinstance(live, dict) else None
    approval_epoch_prev = live.get("approval_epoch") if isinstance(live, dict) else None
    if not isinstance(predecessor_context_sha256, str) or not isinstance(approval_epoch_prev, int) or isinstance(approval_epoch_prev, bool):
        raise GenerateApprovalSidecarError(
            "LIVE_SIDECAR_UNREADABLE",
            f"live sidecar at {live_sidecar_path!r} is missing a valid "
            "context_sha256/approval_epoch",
        )

    # Non-bootstrap: the verdict may ONLY come from the in-process seam.
    weakening_verdict = _invoke_weakening_detector_seam(content_path)
    return predecessor_context_sha256, weakening_verdict, approval_epoch_prev + 1


# ---------------------------------------------------------------------------
# Staged output (design.md: staged-candidate-ONLY, never the live path, B7).
# ---------------------------------------------------------------------------


def _default_stage_dir(schema_id, nonce):
    return os.path.join("sdd", ".staging", schema_id, nonce)


def _write_staged_outputs(stage_dir, schema_id, sidecar_obj, content_bytes, nonce, simulate_failure=None):
    """Writes the signed candidate, the byte-exact approved-context snapshot,
    and MANIFEST.sha256 to a TEMPORARY sibling directory, re-hashes every
    file from disk, then commits with ONE atomic directory rename into
    `stage_dir`. A failure at any point before that rename leaves `stage_dir`
    itself absent -- never partially populated (AC-034/TEST-034) -- and the
    temporary directory is removed. A re-run always uses a fresh nonce, so
    it never collides with a prior failed attempt's leftovers.

    Every filesystem operation in this function -- including directory
    creation and the final commit rename -- is covered by the try/except
    below: an OSError from any of them (a colliding `--stage-dir`, an
    unwritable parent, a non-directory occupying part of the default path,
    a permission error, etc.) is wrapped as `GenerateApprovalSidecarError`
    (`STAGING_IO_ERROR`), never left to propagate as a raw, undocumented
    traceback (quality-gate seq0350 Major remedy)."""
    basename = SCHEMA_BASENAMES[schema_id]
    sidecar_bytes = (json.dumps(sidecar_obj, indent=2, sort_keys=True) + "\n").encode("utf-8")

    stage_dir = stage_dir.rstrip("/").rstrip(os.sep)
    parent_dir = os.path.dirname(stage_dir) or "."
    tmp_leaf = os.path.join(parent_dir, ".tmp-" + nonce)

    try:
        os.makedirs(parent_dir, exist_ok=True)

        if os.path.exists(tmp_leaf):
            shutil.rmtree(tmp_leaf)
        os.makedirs(tmp_leaf)

        sidecar_path = os.path.join(tmp_leaf, f"{basename}.approval.json")
        snapshot_path = os.path.join(tmp_leaf, f"{basename}.approved.yaml")
        manifest_path = os.path.join(tmp_leaf, "MANIFEST.sha256")

        with open(sidecar_path, "wb") as f:
            f.write(sidecar_bytes)

        if simulate_failure == "after-sidecar":
            raise GenerateApprovalSidecarError(
                "SIMULATED_MID_WRITE_FAILURE",
                "test-only simulated failure after writing the sidecar candidate",
            )

        with open(snapshot_path, "wb") as f:
            f.write(content_bytes)

        if simulate_failure == "after-snapshot":
            raise GenerateApprovalSidecarError(
                "SIMULATED_MID_WRITE_FAILURE",
                "test-only simulated failure after writing the approved-context snapshot",
            )

        # Re-hash every staged file from disk (not from the in-memory bytes
        # above) before committing, per design.md's "re-hashed" discipline.
        with open(sidecar_path, "rb") as f:
            sidecar_hash = hashlib.sha256(f.read()).hexdigest()
        with open(snapshot_path, "rb") as f:
            snapshot_hash = hashlib.sha256(f.read()).hexdigest()

        manifest_text = (
            f"nonce: {nonce}\n"
            f"{sidecar_hash}  {basename}.approval.json\n"
            f"{snapshot_hash}  {basename}.approved.yaml\n"
        )
        with open(manifest_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(manifest_text)

        os.rename(tmp_leaf, stage_dir)
    except OSError as exc:
        shutil.rmtree(tmp_leaf, ignore_errors=True)
        raise GenerateApprovalSidecarError(
            "STAGING_IO_ERROR",
            f"a filesystem error occurred while staging the candidate at "
            f"{stage_dir!r}: {exc}",
        ) from exc
    except BaseException:
        shutil.rmtree(tmp_leaf, ignore_errors=True)
        raise


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

_EXIT_CODE_HELP = "\n".join(
    f"  {code:>3}  {name}" for name, code in sorted(CATEGORY_EXIT_CODES.items(), key=lambda kv: kv[1])
)


def build_arg_parser():
    parser = argparse.ArgumentParser(
        prog="generate-approval-sidecar.py",
        description=(
            "Human/CI-only tool (REQ-004): compute context_sha256 via the "
            "canonicalizer, HMAC-SHA256-sign an approval sidecar, and write "
            "ONLY a staged candidate + approved-context snapshot + manifest "
            "under sdd/.staging/<schema-id>/<nonce>/ -- never the live "
            "sidecar or anchor path."
        ),
        epilog="Exit codes (stable, one per rejection category):\n"
        f"    0  success\n"
        f"  {EXIT_USAGE_ERROR:>3}  usage error (bad arguments, unreadable file)\n"
        f"{_EXIT_CODE_HELP}\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--schema", choices=sorted(SCHEMA_BASENAMES), help="approval schema id")
    parser.add_argument("--content", help="path to the live project-context.yaml/provider-bindings.yaml content file")
    parser.add_argument("--approver", help="primary approver's approver-registry id")
    parser.add_argument("--status", help='primary/second approval status; must be exactly "Approved"')
    parser.add_argument("--second-approver", default=None, help="second approver's approver-registry id (two-person review)")
    parser.add_argument("--effective-at", default=None, help="ISO 8601 effective_at value (passthrough; null if omitted)")
    parser.add_argument("--live-sidecar", help="path to the currently-live sidecar for this schema (absent => bootstrap)")
    parser.add_argument(
        "--stage-dir", default=None,
        help="override the staging output directory (default: sdd/.staging/<schema-id>/<nonce>/)",
    )
    # Test-only hooks (not production code paths -- AC-012/AC-034).
    parser.add_argument("--dump-preimage", default=None, help=argparse.SUPPRESS)
    parser.add_argument(
        "--simulate-mid-write-failure", choices=("after-sidecar", "after-snapshot"),
        default=None, help=argparse.SUPPRESS,
    )
    return parser


def _now_iso8601():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _run_dump_preimage(path):
    """AC-012 test hook (not a production code path): reads a full approval
    JSON object from `path` (its `hmac` field, if any, is excluded -- this is
    exactly what TEST-012 exercises: two sidecars differing ONLY in `hmac`
    must produce an identical preimage), and writes the canonical preimage
    bytes to stdout. Requires no SDD_CONTEXT_KEY; never signs or stages
    anything."""
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except OSError as exc:
        print(f"generate-approval-sidecar: usage error: cannot read {path!r}: {exc}", file=sys.stderr)
        return EXIT_USAGE_ERROR
    try:
        obj = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        print(f"generate-approval-sidecar: usage error: {path!r} is not valid JSON: {exc}", file=sys.stderr)
        return EXIT_USAGE_ERROR
    if not isinstance(obj, dict):
        print(f"generate-approval-sidecar: usage error: {path!r} must be a JSON object", file=sys.stderr)
        return EXIT_USAGE_ERROR
    obj = dict(obj)
    obj.pop("hmac", None)
    try:
        preimage_bytes = _canonicalize_json_preimage(obj)
    except GenerateApprovalSidecarError as exc:
        print(f"generate-approval-sidecar: {exc.category}: {exc.message}", file=sys.stderr)
        return CATEGORY_EXIT_CODES.get(exc.category, 1)
    sys.stdout.buffer.write(preimage_bytes)
    sys.stdout.buffer.flush()
    return 0


def _require(args, names):
    missing = [f"--{name.replace('_', '-')}" for name in names if getattr(args, name) is None]
    if missing:
        raise GenerateApprovalSidecarError(
            "USAGE_ERROR", f"missing required argument(s): {', '.join(missing)}",
        )


def main(argv=None):
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    if args.dump_preimage is not None:
        return _run_dump_preimage(args.dump_preimage)

    try:
        _require(args, ["schema", "content", "approver", "status", "live_sidecar"])

        if args.status != "Approved":
            raise GenerateApprovalSidecarError(
                "USAGE_ERROR", f'--status must be exactly "Approved" (got {args.status!r})',
            )

        if args.second_approver is not None and args.second_approver == args.approver:
            raise GenerateApprovalSidecarError(
                "DUPLICATE_APPROVER_IDENTITY",
                "primary_approval.approver and second_approval.approver are "
                "the same registry id; a two-person claim requires two "
                "DISTINCT registered identities",
            )

        try:
            with open(args.content, "rb") as f:
                content_bytes = f.read()
        except OSError as exc:
            raise GenerateApprovalSidecarError("USAGE_ERROR", f"cannot read --content {args.content!r}: {exc}") from exc

        context_sha256 = _hash_content_file(content_bytes)

        predecessor_context_sha256, weakening_verdict, approval_epoch = _resolve_provenance(
            args.live_sidecar, args.content,
        )

        key_bytes = resolve_context_key()
        if key_bytes is None:
            raise GenerateApprovalSidecarError(
                "NO_CONTEXT_KEY",
                "no SDD_CONTEXT_KEY resolvable (env SDD_CONTEXT_KEY / env "
                "SDD_CONTEXT_KEY_FILE / <HOME>/.sdd/context-key all absent or "
                "empty); refusing to write an unsigned sidecar",
            )

        now = _now_iso8601()
        primary_approval = {"status": args.status, "approver": args.approver, "approved_at": now}
        second_approval = None
        if args.second_approver is not None:
            second_approval = {"status": args.status, "approver": args.second_approver, "approved_at": now}

        approval_obj = {
            "schema": args.schema,
            "context_sha256": context_sha256,
            "primary_approval": primary_approval,
            "second_approval": second_approval,
            "effective_at": args.effective_at,
            "predecessor_context_sha256": predecessor_context_sha256,
            "weakening_verdict": weakening_verdict,
            "approval_epoch": approval_epoch,
        }

        preimage_bytes = _canonicalize_json_preimage(approval_obj)
        hmac_hex = hmac.new(key_bytes, preimage_bytes, hashlib.sha256).hexdigest()

        sidecar = dict(approval_obj)
        sidecar["hmac"] = hmac_hex

        nonce = secrets.token_hex(32)
        stage_dir = args.stage_dir or _default_stage_dir(args.schema, nonce)

        _write_staged_outputs(
            stage_dir, args.schema, sidecar, content_bytes, nonce,
            simulate_failure=args.simulate_mid_write_failure,
        )

        print(f"staged: {stage_dir}")
        print(f"nonce: {nonce}")
        return 0
    except GenerateApprovalSidecarError as exc:
        print(f"generate-approval-sidecar: {exc.category}: {exc.message}", file=sys.stderr)
        if exc.category == "USAGE_ERROR":
            return EXIT_USAGE_ERROR
        return CATEGORY_EXIT_CODES.get(exc.category, 1)


if __name__ == "__main__":
    sys.exit(main())
