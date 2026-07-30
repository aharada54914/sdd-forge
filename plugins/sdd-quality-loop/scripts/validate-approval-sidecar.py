#!/usr/bin/env python3
"""validate-approval-sidecar (REQ-005, epic-189-a1-project-context T-006).

Independently re-verifies a `sdd/project-context.approval.json` /
`sdd/provider-bindings.approval.json` sidecar against its accompanying
content file (`sdd/project-context.yaml` / `sdd/provider-bindings.yaml`),
in the order requirements.md REQ-005 defines, short-circuiting on the FIRST
failure with that failure's own named, stable diagnostic:

  (0) content-schema conformance -- the content file must canonicalize
      (REQ-003; every canonicalizer rejection category applies), validate
      against `contracts/project-context.schema.json` or
      `contracts/provider-bindings.schema.json` (chosen by the sidecar's own
      `schema` field), and pass the duplicate-`id` semantic check
      (`DUPLICATE_COMPONENT_ID`/`DUPLICATE_BINDING_ID` -- JSON Schema
      draft-07 cannot express array-item-key uniqueness natively, M18).
      `sdd/approver-registry.yaml` is validated the same way here too
      (schema conformance + `DUPLICATE_APPROVER_REGISTRY_ID`, AC-045) --
      before hash comparison, since a corrupted registry can never yield a
      trustworthy approver-identity gate later.
  (1) hash match -- `context_sha256` equals REQ-003's canonical hash of the
      live content file, byte-for-byte.
  (2) HMAC verification -- recompute the REQ-004 preimage (the sidecar
      object with `hmac` excluded, canonicalized in JSON input mode) and
      `hmac.compare_digest` against the stored `hmac`, keyed by the
      resolved `SDD_CONTEXT_KEY`; no resolvable key is a hard failure.
  (3) approver-identity check -- `primary_approval.approver` (and
      `second_approval.approver` when present) must each be a registered
      `id` in `sdd/approver-registry.yaml`; when `second_approval` is
      present, its `approver` must differ from `primary_approval.approver`
      (`DUPLICATE_APPROVER_IDENTITY`, re-checked independently here even
      though `generate-approval-sidecar.py` already refuses this at
      signing time -- a hand-edited-after-signing sidecar must not pass
      merely because its HMAC happens to still verify).
  (4) `effective_at` gate -- non-null and in the future (validator's
      current time < `effective_at`) is a hard, distinct failure.
  (5) weakening-provenance consistency -- IF `weakening_verdict.
      policy_weakening` is `true` AND `weakening_verdict.
      two_person_required` is `true`, THEN `second_approval` must be
      present with an `approver` distinct from `primary_approval.approver`
      (`WEAKENING_PROVENANCE_UNDERAPPROVED`). design.md's own text
      describes this cross-check as part of `--verify-provenance`
      (below); this validator ALSO applies it to the standard
      content+sidecar validation path, closing a gap recorded at T-005's
      quality-gate (seq0353): `generate-approval-sidecar.py` (T-003) does
      not itself refuse to sign a solo-approved sidecar whose verdict
      requires two-person review, so THIS gate -- run at every validation,
      not merely `--verify-provenance` -- is this design's actual,
      canonical enforcement point (`reports/notes/
      epic-189-a1-carryover-items.md`).

`--verify-provenance <sidecar>` mode (REQ-005, NEW): given a LIVE sidecar
alone (no `--content`, no predecessor anchor required -- the whole point is
this check still works after the predecessor anchor's own bytes are gone),
recomputes the sidecar's own HMAC (proving `predecessor_context_sha256`/
`weakening_verdict`/`approval_epoch` were not edited after signing) and
re-applies gate (5) above. The bootstrap case (`weakening_verdict: null`)
is exempt structurally -- gate (5) only fires when a verdict is present.

Reader-side generation-consistency check (design.md "Human-copy publisher
transactional bundle contract"): before trusting ANY path this tool is
about to read (`--content`, `--sidecar`), a live `sdd/.staging/*/
TRANSACTION.json` journal naming either path fails the read closed
(`HUMAN_COPY_PUBLISH_IN_PROGRESS`) -- the identical check
`detect-policy-weakening.py` (T-005) performs, independently reimplemented
here (this script imports nothing from `generate-approval-sidecar.py` or
`detect-policy-weakening.py` -- every check is RECOMPUTED independently,
so a bug unique to the generator's or detector's own implementation is not
silently mirrored by the validator that is supposed to catch it; T-002's
canonicalizer is the one piece of logic this script dispatches to as a
subprocess rather than reimplementing, per every sibling script's own
established convention).

Out of scope (tasks.md T-006): the staging-only signer's own behavior
(T-003); the weakening detector's own category/verdict COMPUTATION (T-005)
-- this validator only reads an ALREADY-COMPUTED `weakening_verdict` field
back out of the sidecar, never recomputes one; wiring this validator into
any Capability Mode gate beyond REQ-009's own call sites (T-011/T-012);
re-deriving `predecessor_context_sha256`/`weakening_verdict`/
`approval_epoch` against a still-live, about-to-be-superseded anchor for a
STAGED (pre-publish) candidate (design.md's REQ-004 text describes this as
a FUTURE capability of "validate-approval-sidecar.py" the publisher would
invoke; T-006's own frozen Done When names no TEST id for it -- see the
implementation report's discharge notes).
"""
import argparse
import glob
import hashlib
import hmac
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

EXIT_USAGE_ERROR = 2

CATEGORY_EXIT_CODES = {
    # Shared numbers, matching the equivalent diagnostic in
    # generate-approval-sidecar.py (T-003) / detect-policy-weakening.py
    # (T-005) where the SAME category name applies -- a soft convention
    # for cross-script readability; each script's exit-code space is
    # otherwise independent (requirements.md: "each rejection category
    # keeps its own diagnostic and exit code", stable WITHIN a script).
    "DUPLICATE_APPROVER_IDENTITY": 10,
    "NO_CONTEXT_KEY": 11,
    "HUMAN_COPY_PUBLISH_IN_PROGRESS": 21,
    "APPROVER_REGISTRY_UNREADABLE": 23,
    # This script's own categories.
    "CONTENT_CANONICALIZATION_FAILED": 31,
    "CONTENT_SCHEMA_VIOLATION": 32,
    "DUPLICATE_COMPONENT_ID": 33,
    "DUPLICATE_BINDING_ID": 34,
    "APPROVER_REGISTRY_SCHEMA_VIOLATION": 35,
    "DUPLICATE_APPROVER_REGISTRY_ID": 36,
    "SIDECAR_UNREADABLE": 37,
    "SIDECAR_MALFORMED": 38,
    "HASH_MISMATCH": 39,
    "HMAC_MISMATCH": 40,
    "UNREGISTERED_APPROVER": 41,
    "EFFECTIVE_AT_NOT_YET_REACHED": 42,
    "WEAKENING_PROVENANCE_UNDERAPPROVED": 43,
    "PREIMAGE_CANONICALIZATION_FAILED": 44,
    "SCHEMA_FILE_UNREADABLE": 45,
    "WEAKENING_VERDICT_MISSING": 46,
    # Last-resort classification: never a raw, uncaught traceback.
    "INTERNAL_ERROR": 90,
}

# sidecar `schema` id -> the content schema this sidecar accompanies, per
# design.md's Data Plan / API Contract Plan.
CONTENT_SCHEMA_INFO = {
    "sdd-project-context-approval/v1": {
        "schema_filename": "project-context.schema.json",
        "array_field": "components",
        "dup_category": "DUPLICATE_COMPONENT_ID",
    },
    "sdd-provider-bindings-approval/v1": {
        "schema_filename": "provider-bindings.schema.json",
        "array_field": "bindings",
        "dup_category": "DUPLICATE_BINDING_ID",
    },
}

SIDECAR_REQUIRED_KEYS = {
    "schema", "context_sha256", "primary_approval", "second_approval",
    "effective_at", "predecessor_context_sha256", "weakening_verdict",
    "approval_epoch", "hmac",
}


class ValidateApprovalSidecarError(Exception):
    """A documented, category-specific refusal -- never an uncaught
    traceback (T-002/T-003/T-005 quality-gate lessons)."""

    def __init__(self, category, message):
        super().__init__(message)
        self.category = category
        self.message = message


# ---------------------------------------------------------------------------
# SDD_CONTEXT_KEY resolution -- independently reimplemented (never imported
# from generate-approval-sidecar.py), byte-parity with `_resolve_sudo_key`
# (sdd-hook-guard.py) / `resolve_context_key` (generate-approval-sidecar.py)
# proven executably by this suite's own key-parity test (AC-013-style
# 4-case matrix; T-006 carry-forward obligation 1). Reimplementing
# independently, rather than importing T-003's copy, preserves this
# validator's INDEPENDENT-verification value for the HMAC gate: a
# generator-side key-resolution bug would not be silently mirrored by an
# imported, shared implementation.
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


def _resolve_key_or_raise():
    key_bytes = resolve_context_key()
    if key_bytes is None:
        raise ValidateApprovalSidecarError(
            "NO_CONTEXT_KEY",
            "no SDD_CONTEXT_KEY resolvable (env SDD_CONTEXT_KEY / env "
            "SDD_CONTEXT_KEY_FILE / <HOME>/.sdd/context-key all absent or "
            "empty); cannot verify HMAC -- a missing key is a hard failure, "
            "never a skip",
        )
    return key_bytes


# ---------------------------------------------------------------------------
# Canonicalizer dispatch (REQ-003) -- never reimplemented; every parse of
# the content file, the approver registry, or the sidecar's own preimage
# goes through this one subprocess boundary.
# ---------------------------------------------------------------------------


def _canonicalizer_path():
    return Path(__file__).resolve().parent / "canonicalize-sdd-yaml.py"


def _canonicalize_file_to_json(path, failure_category):
    """Dispatches `path` (YAML input mode) to canonicalize-sdd-yaml.py and
    returns the parsed canonical JSON object. Any non-zero exit (missing
    file, hostile/out-of-subset YAML, a document that canonicalizes to a
    non-object) is wrapped as `ValidateApprovalSidecarError`."""
    canon_path = _canonicalizer_path()
    try:
        proc = subprocess.run(
            [sys.executable, str(canon_path), str(path), "--input-format", "yaml"],
            capture_output=True,
        )
    except OSError as exc:
        raise ValidateApprovalSidecarError(
            failure_category, f"could not invoke canonicalize-sdd-yaml.py: {exc}",
        ) from exc
    if proc.returncode != 0:
        stderr_text = proc.stderr.decode("utf-8", errors="replace").strip()
        raise ValidateApprovalSidecarError(
            failure_category,
            f"canonicalize-sdd-yaml rejected {str(path)!r} (exit {proc.returncode}): {stderr_text}",
        )
    try:
        obj = json.loads(proc.stdout.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValidateApprovalSidecarError(
            failure_category, f"canonicalizer output for {str(path)!r} is not valid JSON: {exc}",
        ) from exc
    if not isinstance(obj, dict):
        raise ValidateApprovalSidecarError(
            failure_category,
            f"{str(path)!r} must be a YAML mapping/object at the top level",
        )
    return obj


def _hash_file_via_canonicalizer(path, failure_category):
    """context_sha256 recomputation: `--hash-only` dispatch, returning the
    full `sha256:<hex>` string REQ-003 emits."""
    canon_path = _canonicalizer_path()
    try:
        proc = subprocess.run(
            [sys.executable, str(canon_path), str(path), "--input-format", "yaml", "--hash-only"],
            capture_output=True,
        )
    except OSError as exc:
        raise ValidateApprovalSidecarError(
            failure_category, f"could not invoke canonicalize-sdd-yaml.py: {exc}",
        ) from exc
    if proc.returncode != 0:
        stderr_text = proc.stderr.decode("utf-8", errors="replace").strip()
        raise ValidateApprovalSidecarError(
            failure_category,
            f"canonicalize-sdd-yaml rejected {str(path)!r} (exit {proc.returncode}): {stderr_text}",
        )
    return proc.stdout.decode("ascii").strip()


def _canonicalize_json_preimage(obj):
    """Preimage bytes for HMAC (re)computation: `obj` (the `hmac` key
    already excluded by the caller) canonicalized in JSON input mode --
    independently recomputed here, not imported from
    generate-approval-sidecar.py (design.md: "validate-approval-sidecar
    RECOMPUTES the identical preimage")."""
    try:
        text = json.dumps(obj)
        data_bytes = text.encode("utf-8")
    except UnicodeEncodeError as exc:
        raise ValidateApprovalSidecarError(
            "PREIMAGE_CANONICALIZATION_FAILED",
            f"a sidecar field could not be encoded as UTF-8: {exc}",
        ) from exc
    canon_path = _canonicalizer_path()
    tmp_fd, tmp_path = tempfile.mkstemp(prefix="validate-approval-sidecar-")
    try:
        with os.fdopen(tmp_fd, "wb") as f:
            f.write(data_bytes)
        try:
            proc = subprocess.run(
                [sys.executable, str(canon_path), tmp_path, "--input-format", "json"],
                capture_output=True,
            )
        except OSError as exc:
            raise ValidateApprovalSidecarError(
                "PREIMAGE_CANONICALIZATION_FAILED",
                f"could not invoke canonicalize-sdd-yaml.py: {exc}",
            ) from exc
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
    if proc.returncode != 0:
        stderr_text = proc.stderr.decode("utf-8", errors="replace").strip()
        raise ValidateApprovalSidecarError(
            "PREIMAGE_CANONICALIZATION_FAILED",
            f"canonicalize-sdd-yaml rejected the sidecar preimage (exit {proc.returncode}): {stderr_text}",
        )
    return proc.stdout


# ---------------------------------------------------------------------------
# Reader-side generation-consistency check (design.md "Human-copy publisher
# transactional bundle contract"), independently reimplemented from
# detect-policy-weakening.py's own `_check_no_publish_in_progress`.
# ---------------------------------------------------------------------------


def _staging_transaction_journals():
    return sorted(glob.glob(os.path.join("sdd", ".staging", "*", "TRANSACTION.json")))


def _check_no_publish_in_progress(*paths_being_read):
    normalized_targets = {os.path.normpath(p) for p in paths_being_read if p}
    for journal_path in _staging_transaction_journals():
        try:
            with open(journal_path, "r", encoding="utf-8") as f:
                journal = json.load(f)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ValidateApprovalSidecarError(
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
                raise ValidateApprovalSidecarError(
                    "HUMAN_COPY_PUBLISH_IN_PROGRESS",
                    f"a live human-copy transaction journal at {journal_path!r} "
                    f"names {live_path!r}, which this invocation is about to read; "
                    "refusing to proceed on possibly torn cross-file state",
                )


# ---------------------------------------------------------------------------
# Minimal draft-07 JSON Schema subset validator -- the SAME logic already
# proven (byte-identical) in tests/project-context-schema.tests.sh (T-001)
# and tests/approver-registry-schema.tests.sh (T-004) as a test-only
# reference harness; promoted here to PRODUCTION code, since
# validate-approval-sidecar.py is the first script that must actually
# perform this check at runtime (no jsonschema library is available,
# stdlib only). Supports exactly the keywords
# contracts/project-context.schema.json, contracts/provider-bindings.schema.json,
# and contracts/approver-registry.schema.json use: type, required,
# additionalProperties, properties, items, enum, const, minLength, oneOf.
# ---------------------------------------------------------------------------


def _schema_validate(schema, instance, path="/"):
    errors = []
    if "const" in schema and instance != schema["const"]:
        errors.append("%s: expected const %r, got %r" % (path, schema["const"], instance))
    if "enum" in schema and instance not in schema["enum"]:
        errors.append("%s: %r not in enum %r" % (path, instance, schema["enum"]))
    t = schema.get("type")
    if t == "object" and not isinstance(instance, dict):
        errors.append("%s: expected object" % path)
    elif t == "array" and not isinstance(instance, list):
        errors.append("%s: expected array" % path)
    elif t == "string" and not isinstance(instance, str):
        errors.append("%s: expected string" % path)
    elif t == "boolean" and not isinstance(instance, bool):
        errors.append("%s: expected boolean" % path)

    if isinstance(instance, dict):
        for req in schema.get("required", []):
            if req not in instance:
                errors.append("%s: missing required field %r" % (path, req))
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for k in instance:
                if k not in props:
                    errors.append("%s: additional property %r not allowed" % (path, k))
        for k, v in instance.items():
            if k in props:
                errors.extend(_schema_validate(props[k], v, path.rstrip("/") + "/" + k))
    elif isinstance(instance, list) and "items" in schema:
        for idx, item in enumerate(instance):
            errors.extend(_schema_validate(schema["items"], item, path.rstrip("/") + "/%d" % idx))
    elif isinstance(instance, str) and "minLength" in schema and len(instance) < schema["minLength"]:
        errors.append("%s: shorter than minLength %d" % (path, schema["minLength"]))

    if "oneOf" in schema:
        matches = 0
        for sub in schema["oneOf"]:
            if not _schema_validate(sub, instance, path):
                matches += 1
        if matches != 1:
            errors.append("%s: oneOf matched %d branches (need exactly 1)" % (path, matches))

    return errors


def _find_duplicate_id(array):
    if not isinstance(array, list):
        return None
    seen = set()
    for item in array:
        iid = item.get("id") if isinstance(item, dict) else None
        if iid is None:
            continue
        if iid in seen:
            return iid
        seen.add(iid)
    return None


def _repo_root():
    # plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py -> repo root.
    return Path(__file__).resolve().parents[3]


def _load_json_schema_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValidateApprovalSidecarError(
            "SCHEMA_FILE_UNREADABLE", f"cannot read schema file {str(path)!r}: {exc}",
        ) from exc


# ---------------------------------------------------------------------------
# Gate (0): content-schema conformance (content file + approver registry).
# ---------------------------------------------------------------------------


def _resolve_content_schema_info(sidecar_obj):
    schema_id = sidecar_obj.get("schema") if isinstance(sidecar_obj, dict) else None
    info = CONTENT_SCHEMA_INFO.get(schema_id)
    if info is None:
        raise ValidateApprovalSidecarError(
            "SIDECAR_MALFORMED",
            f"sidecar 'schema' field {schema_id!r} is not a recognized approval "
            f"schema id (expected one of {sorted(CONTENT_SCHEMA_INFO)})",
        )
    return info


def _validate_content(content_path, info):
    content_obj = _canonicalize_file_to_json(content_path, "CONTENT_CANONICALIZATION_FAILED")
    schema = _load_json_schema_file(_repo_root() / "contracts" / info["schema_filename"])
    errors = _schema_validate(schema, content_obj)
    if errors:
        raise ValidateApprovalSidecarError("CONTENT_SCHEMA_VIOLATION", "; ".join(errors))
    array_field = info["array_field"]
    dup_id = _find_duplicate_id(content_obj.get(array_field))
    if dup_id is not None:
        raise ValidateApprovalSidecarError(
            info["dup_category"], f"duplicate {array_field}[].id {dup_id!r} in {str(content_path)!r}",
        )


def _validate_registry(registry_path):
    """Returns the set of DISTINCT registered approver ids. A missing
    registry file is treated identically to a present-but-empty
    (`approvers: []`) registry -- the documented zero-identity boundary
    (AC-046) -- never an error. Schema violations and duplicate `id`
    entries are hard failures (AC-045's PRODUCTION discharge -- T-004's
    own suite proved only the test-side concept via an inline harness,
    never calling this script)."""
    if not os.path.isfile(registry_path):
        return set()
    registry_obj = _canonicalize_file_to_json(registry_path, "APPROVER_REGISTRY_UNREADABLE")
    schema = _load_json_schema_file(_repo_root() / "contracts" / "approver-registry.schema.json")
    errors = _schema_validate(schema, registry_obj)
    if errors:
        raise ValidateApprovalSidecarError("APPROVER_REGISTRY_SCHEMA_VIOLATION", "; ".join(errors))
    approvers = registry_obj.get("approvers") or []
    seen = set()
    for entry in approvers:
        iid = entry.get("id") if isinstance(entry, dict) else None
        if iid is None:
            continue
        if iid in seen:
            raise ValidateApprovalSidecarError(
                "DUPLICATE_APPROVER_REGISTRY_ID",
                f"duplicate approvers[].id {iid!r} in {str(registry_path)!r}",
            )
        seen.add(iid)
    return seen


# ---------------------------------------------------------------------------
# Sidecar loading + gates (1)-(5).
# ---------------------------------------------------------------------------


def _load_sidecar(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
    except OSError as exc:
        raise ValidateApprovalSidecarError(
            "SIDECAR_UNREADABLE", f"cannot read --sidecar {str(path)!r}: {exc}",
        ) from exc
    try:
        obj = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValidateApprovalSidecarError(
            "SIDECAR_UNREADABLE", f"--sidecar {str(path)!r} is not valid JSON: {exc}",
        ) from exc
    if not isinstance(obj, dict):
        raise ValidateApprovalSidecarError(
            "SIDECAR_MALFORMED", f"--sidecar {str(path)!r} must be a JSON object",
        )
    missing = SIDECAR_REQUIRED_KEYS - set(obj.keys())
    if missing:
        raise ValidateApprovalSidecarError(
            "SIDECAR_MALFORMED",
            f"--sidecar {str(path)!r} missing required field(s): {sorted(missing)}",
        )
    return obj


def _check_hash_match(content_path, sidecar_obj):
    recomputed = _hash_file_via_canonicalizer(content_path, "CONTENT_CANONICALIZATION_FAILED")
    stored = sidecar_obj.get("context_sha256")
    if not isinstance(stored, str) or recomputed != stored:
        raise ValidateApprovalSidecarError(
            "HASH_MISMATCH",
            f"context_sha256 {stored!r} does not match the live content file's "
            f"independently-recomputed hash {recomputed!r}",
        )


def _check_hmac(sidecar_obj, key_bytes):
    obj_copy = dict(sidecar_obj)
    stored_hmac = obj_copy.pop("hmac", None)
    if not isinstance(stored_hmac, str):
        raise ValidateApprovalSidecarError("SIDECAR_MALFORMED", "hmac field missing or not a string")
    preimage_bytes = _canonicalize_json_preimage(obj_copy)
    recomputed = hmac.new(key_bytes, preimage_bytes, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(recomputed, stored_hmac.lower()):
        raise ValidateApprovalSidecarError(
            "HMAC_MISMATCH",
            "recomputed HMAC does not match the sidecar's stored hmac field -- "
            "hash match alone is never sufficient",
        )


def _check_approver_identity(sidecar_obj, registry_ids):
    primary = sidecar_obj.get("primary_approval")
    if not isinstance(primary, dict) or not isinstance(primary.get("approver"), str):
        raise ValidateApprovalSidecarError("SIDECAR_MALFORMED", "primary_approval.approver missing or not a string")
    primary_id = primary["approver"]
    if primary_id not in registry_ids:
        raise ValidateApprovalSidecarError(
            "UNREGISTERED_APPROVER",
            f"primary_approval.approver {primary_id!r} is not a registered "
            "approver-registry id",
        )
    second = sidecar_obj.get("second_approval")
    if second is not None:
        if not isinstance(second, dict) or not isinstance(second.get("approver"), str):
            raise ValidateApprovalSidecarError("SIDECAR_MALFORMED", "second_approval.approver missing or not a string")
        second_id = second["approver"]
        if second_id not in registry_ids:
            raise ValidateApprovalSidecarError(
                "UNREGISTERED_APPROVER",
                f"second_approval.approver {second_id!r} is not a registered "
                "approver-registry id",
            )
        if second_id == primary_id:
            raise ValidateApprovalSidecarError(
                "DUPLICATE_APPROVER_IDENTITY",
                "primary_approval.approver and second_approval.approver are "
                "the same registry id; a two-person claim requires two "
                "DISTINCT registered identities",
            )


def _check_effective_at(sidecar_obj):
    effective_at = sidecar_obj.get("effective_at")
    if effective_at is None:
        return
    if not isinstance(effective_at, str):
        raise ValidateApprovalSidecarError("SIDECAR_MALFORMED", "effective_at must be null or a string")
    try:
        dt = datetime.strptime(effective_at, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError as exc:
        raise ValidateApprovalSidecarError(
            "SIDECAR_MALFORMED",
            f"effective_at {effective_at!r} is not a valid ISO 8601 timestamp: {exc}",
        ) from exc
    now = datetime.now(timezone.utc)
    if now < dt:
        raise ValidateApprovalSidecarError(
            "EFFECTIVE_AT_NOT_YET_REACHED",
            f"effective_at {effective_at!r} is in the future (current time "
            f"{now.strftime('%Y-%m-%dT%H:%M:%SZ')})",
        )


def _check_bootstrap_invariant(sidecar_obj):
    """T-006 carry-forward obligation 2 (T-003 QG round-2 Minor (3)):
    requirements.md:310-312's invariant permits a null `weakening_verdict`
    ONLY alongside a null `predecessor_context_sha256` (the first-ever-
    publish bootstrap case). A non-bootstrap sidecar
    (`predecessor_context_sha256` present) carrying `weakening_verdict:
    null` is a structural invariant violation this validator rejects --
    backstopping T-005's own generator-side refusal
    (`WEAKENING_VERDICT_MALFORMED`, which only fires when
    `generate-approval-sidecar.py`'s own seam is actually invoked; this
    check independently catches ANY sidecar violating the invariant,
    however it was produced, since the validator never trusts that every
    sidecar it is asked to check necessarily came through that seam)."""
    predecessor = sidecar_obj.get("predecessor_context_sha256")
    verdict = sidecar_obj.get("weakening_verdict")
    if predecessor is not None and verdict is None:
        raise ValidateApprovalSidecarError(
            "WEAKENING_VERDICT_MISSING",
            "predecessor_context_sha256 is present (a non-bootstrap "
            "transition) but weakening_verdict is null -- "
            "requirements.md's invariant permits a null weakening_verdict "
            "ONLY alongside a null predecessor_context_sha256 (the "
            "first-ever-publish bootstrap case)",
        )


def _check_weakening_provenance_consistency(sidecar_obj):
    """Gate (5), requirements.md:466-480 / T-006 carry-forward obligation
    4b: applied at BOTH the standard validation path and
    `--verify-provenance` -- a verdict requiring two-person review implies
    a PRESENT, DISTINCT `second_approval`, or this sidecar is rejected
    regardless of an otherwise-valid hash/HMAC/approver-identity chain."""
    verdict = sidecar_obj.get("weakening_verdict")
    if verdict is None:
        return
    if not isinstance(verdict, dict):
        raise ValidateApprovalSidecarError("SIDECAR_MALFORMED", "weakening_verdict must be null or an object")
    if verdict.get("policy_weakening") is True and verdict.get("two_person_required") is True:
        primary = sidecar_obj.get("primary_approval")
        second = sidecar_obj.get("second_approval")
        primary_id = primary.get("approver") if isinstance(primary, dict) else None
        second_id = second.get("approver") if isinstance(second, dict) else None
        if second is None or second_id is None or second_id == primary_id:
            raise ValidateApprovalSidecarError(
                "WEAKENING_PROVENANCE_UNDERAPPROVED",
                "weakening_verdict records a two-person-required policy-"
                "weakening transition but second_approval is absent or "
                "duplicates primary_approval.approver",
            )


# ---------------------------------------------------------------------------
# Top-level validation flows.
# ---------------------------------------------------------------------------


def _default_registry_path():
    return os.path.join("sdd", "approver-registry.yaml")


def run_standard_validation(content_path, sidecar_path, registry_path):
    _check_no_publish_in_progress(content_path, sidecar_path)
    sidecar_obj = _load_sidecar(sidecar_path)
    _check_bootstrap_invariant(sidecar_obj)
    content_info = _resolve_content_schema_info(sidecar_obj)
    _validate_content(content_path, content_info)
    registry_ids = _validate_registry(registry_path)
    _check_hash_match(content_path, sidecar_obj)
    key_bytes = _resolve_key_or_raise()
    _check_hmac(sidecar_obj, key_bytes)
    _check_approver_identity(sidecar_obj, registry_ids)
    _check_effective_at(sidecar_obj)
    _check_weakening_provenance_consistency(sidecar_obj)


def run_verify_provenance(sidecar_path):
    _check_no_publish_in_progress(sidecar_path)
    sidecar_obj = _load_sidecar(sidecar_path)
    _check_bootstrap_invariant(sidecar_obj)
    key_bytes = _resolve_key_or_raise()
    _check_hmac(sidecar_obj, key_bytes)
    _check_weakening_provenance_consistency(sidecar_obj)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

_EXIT_CODE_HELP = "\n".join(
    f"  {code:>3}  {name}" for name, code in sorted(CATEGORY_EXIT_CODES.items(), key=lambda kv: kv[1])
)


def build_arg_parser():
    parser = argparse.ArgumentParser(
        prog="validate-approval-sidecar.py",
        description=(
            "Independently re-verify an approval sidecar (REQ-005) against "
            "its content file: content-schema conformance, hash match, HMAC "
            "verification, approver identity/duplicate-identity, effective_at, "
            "and weakening-provenance consistency. --verify-provenance checks "
            "a LIVE sidecar's internal consistency alone, indefinitely, after "
            "its predecessor anchor is gone."
        ),
        epilog="Exit codes (stable, one per rejection category):\n"
        f"    0  success (VALID)\n"
        f"  {EXIT_USAGE_ERROR:>3}  usage error (bad arguments)\n"
        f"{_EXIT_CODE_HELP}\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--content", default=None, help="path to the live project-context.yaml/provider-bindings.yaml content file")
    parser.add_argument("--sidecar", required=True, help="path to the approval sidecar JSON file")
    parser.add_argument(
        "--approver-registry", default=None,
        help="path to sdd/approver-registry.yaml (default: sdd/approver-registry.yaml, CWD-relative)",
    )
    parser.add_argument(
        "--verify-provenance", action="store_true",
        help="historical re-check mode: given --sidecar alone, verify its own "
        "HMAC and weakening-provenance internal consistency",
    )
    return parser


def main(argv=None):
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    try:
        if args.verify_provenance:
            if args.content is not None or args.approver_registry is not None:
                raise ValidateApprovalSidecarError(
                    "USAGE_ERROR",
                    "--content/--approver-registry must not be combined with "
                    "--verify-provenance (it checks the sidecar's own internal "
                    "consistency alone)",
                )
            run_verify_provenance(args.sidecar)
        else:
            if args.content is None:
                raise ValidateApprovalSidecarError(
                    "USAGE_ERROR", "--content is required unless --verify-provenance is given",
                )
            registry_path = args.approver_registry or _default_registry_path()
            run_standard_validation(args.content, args.sidecar, registry_path)
        print("VALID")
        return 0
    except ValidateApprovalSidecarError as exc:
        print(f"validate-approval-sidecar: {exc.category}: {exc.message}", file=sys.stderr)
        if exc.category == "USAGE_ERROR":
            return EXIT_USAGE_ERROR
        return CATEGORY_EXIT_CODES.get(exc.category, 1)
    except Exception as exc:  # noqa: BLE001 - last-resort classification, never a raw traceback
        print(f"validate-approval-sidecar: INTERNAL_ERROR: unexpected error: {exc!r}", file=sys.stderr)
        return CATEGORY_EXIT_CODES["INTERNAL_ERROR"]


if __name__ == "__main__":
    sys.exit(main())
