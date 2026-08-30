#!/usr/bin/env python3
"""Validate and aggregate the five live-host hook-activation proof cells."""

import argparse
import base64
import binascii
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import tempfile


CELLS = {
    "Claude-active": ("claude", "not_applicable"),
    "Codex-enabled-active": ("codex", "enabled"),
    "Codex-disabled-expected-unavailable": ("codex", "disabled"),
    "Copilot-primary-active": ("copilot", "not_applicable"),
    "Copilot-subagent-expected-unavailable": ("copilot", "not_applicable"),
}
FILENAMES = {cell: cell.lower() + ".json" for cell in CELLS}
RECORD_KEYS = {
    "schema", "matrix_cell", "runtime", "check", "invocation_mode",
    "nonce", "host_session_id", "host_event_id", "raw_tool_request_ref",
    "raw_tool_request_sha256", "raw_tool_result_ref", "raw_tool_result_sha256",
    "installed_hook_config_ref", "installed_hook_config_digest",
    "installed_feature_config_ref", "installed_feature_config_digest",
    "session_date", "session_start", "session_end", "operator",
    "operator_key_id", "reviewer", "reviewer_key_id", "cli_name",
    "cli_version", "host_os", "plugin_hooks_flag", "tool_call_evidence",
    "verdict", "skip_reason", "operator_signature", "reviewer_signature",
    "notes",
}
REQUIRED_RECORD_KEYS = RECORD_KEYS - {"notes"}
SKIP_NONNULL = {
    "schema", "matrix_cell", "runtime", "check", "invocation_mode",
    "operator", "operator_key_id", "reviewer", "reviewer_key_id",
    "verdict", "skip_reason", "operator_signature", "reviewer_signature",
    "plugin_hooks_flag",
}
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
NONCE_RE = re.compile(r"^[A-Za-z0-9_-]{16,}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
KEY_ID_RE = re.compile(r"^[A-Za-z0-9._-]+$")
HANDSHAKE_PATHS = {
    f"plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.{suffix}"
    for suffix in ("py", "sh", "ps1")
}
CONSUMER_PATHS = {
    "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md",
    "plugins/sdd-lite/skills/lite-gate/SKILL.md",
    "plugins/sdd-lite/skills/lite-spec/SKILL.md",
    "plugins/sdd-ship/skills/ship/SKILL.md",
}

Q = 2**255 - 19
L = 2**252 + 27742317777372353535851937790883648493
D = (-121665 * pow(121666, Q - 2, Q)) % Q
I = pow(2, (Q - 1) // 4, Q)
IDENTITY = (0, 1, 1, 0)


class ValidationError(Exception):
    def __init__(self, code, message, cell=None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.cell = cell


def fail(code, message, cell=None):
    raise ValidationError(code, message, cell)


def load_canonicalizer():
    path = Path(__file__).with_name("canonicalize-sdd-yaml.py")
    spec = importlib.util.spec_from_file_location("sdd_canonicalizer", path)
    if spec is None or spec.loader is None:
        fail("ERR_SCHEMA_INVALID", "RFC 8785 canonicalizer could not be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CANON = load_canonicalizer()


def load_json(path, label):
    try:
        data = Path(path).read_bytes()
        value = CANON.parse_json_bytes(data)
        return CANON.normalize_and_validate(value)
    except (OSError, ValueError, CANON.CanonicalizeError) as exc:
        fail("ERR_SCHEMA_INVALID", f"{label} is not strict JSON: {exc}")


def jcs(value):
    try:
        return CANON.jcs_serialize(CANON.normalize_and_validate(value))
    except (ValueError, CANON.CanonicalizeError) as exc:
        fail("ERR_SCHEMA_INVALID", f"value is not RFC 8785 canonicalizable: {exc}")


def require_exact_keys(value, required, optional, label, cell=None):
    if not isinstance(value, dict):
        fail("ERR_SCHEMA_INVALID", f"{label} must be an object", cell)
    keys = set(value)
    missing = required - keys
    unknown = keys - required - optional
    if missing or unknown:
        fail("ERR_SCHEMA_INVALID", f"{label} key mismatch; missing={sorted(missing)}, unknown={sorted(unknown)}", cell)


def nonempty_string(value):
    return isinstance(value, str) and bool(re.search(r"\S", value))


def parse_utc(value, label, cell=None):
    if not isinstance(value, str) or not value.endswith("Z"):
        fail("ERR_SCHEMA_INVALID", f"{label} must be an ISO 8601 UTC timestamp", cell)
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        fail("ERR_SCHEMA_INVALID", f"{label} must be an ISO 8601 UTC timestamp", cell)
    if parsed.utcoffset() != dt.timedelta(0):
        fail("ERR_SCHEMA_INVALID", f"{label} must use UTC", cell)
    return parsed


def strict_b64(value, expected_length, code, label, cell=None):
    if not isinstance(value, str) or not value:
        fail(code, f"{label} must be non-empty canonical base64", cell)
    try:
        decoded = base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError):
        fail(code, f"{label} is not strict base64", cell)
    if len(decoded) != expected_length or base64.b64encode(decoded).decode("ascii") != value:
        fail(code, f"{label} must encode exactly {expected_length} bytes", cell)
    return decoded


def point_add(p, q):
    x1, y1, z1, t1 = p
    x2, y2, z2, t2 = q
    a = (y1 - x1) * (y2 - x2) % Q
    b = (y1 + x1) * (y2 + x2) % Q
    c = 2 * D * t1 * t2 % Q
    d = 2 * z1 * z2 % Q
    e = (b - a) % Q
    f = (d - c) % Q
    g = (d + c) % Q
    h = (b + a) % Q
    return (e * f % Q, g * h % Q, f * g % Q, e * h % Q)


def scalar_mult(point, scalar):
    result = IDENTITY
    addend = point
    while scalar:
        if scalar & 1:
            result = point_add(result, addend)
        addend = point_add(addend, addend)
        scalar >>= 1
    return result


def point_equal(p, q):
    return p[0] * q[2] % Q == q[0] * p[2] % Q and p[1] * q[2] % Q == q[1] * p[2] % Q


def decode_point(encoded):
    if len(encoded) != 32:
        return None
    value = int.from_bytes(encoded, "little")
    sign_bit = value >> 255
    y = value & ((1 << 255) - 1)
    if y >= Q:
        return None
    yy = y * y % Q
    xx = (yy - 1) * pow(D * yy + 1, Q - 2, Q) % Q
    x = pow(xx, (Q + 3) // 8, Q)
    if (x * x - xx) % Q:
        x = x * I % Q
    if (x * x - xx) % Q:
        return None
    if x == 0 and sign_bit:
        return None
    if (x & 1) != sign_bit:
        x = Q - x
    point = (x, y, 1, x * y % Q)
    if point_equal(scalar_mult(point, 8), IDENTITY):
        return None
    # Ed25519 keys and R encodings produced by conforming signers are in the
    # prime-order subgroup. Reject mixed-order points as well as the small-
    # order points above so torsion components cannot enter verification.
    if not point_equal(scalar_mult(point, L), IDENTITY):
        return None
    return point


BY = 4 * pow(5, Q - 2, Q) % Q
_BXX = (BY * BY - 1) * pow(D * BY * BY + 1, Q - 2, Q) % Q
BX = pow(_BXX, (Q + 3) // 8, Q)
if (BX * BX - _BXX) % Q:
    BX = BX * I % Q
if BX & 1:
    BX = Q - BX
B = (BX, BY, 1, BX * BY % Q)


def verify_ed25519(public_key, signature, message):
    if len(public_key) != 32 or len(signature) != 64:
        return False
    encoded_r = signature[:32]
    scalar_s = int.from_bytes(signature[32:], "little")
    if scalar_s >= L:
        return False
    point_a = decode_point(public_key)
    point_r = decode_point(encoded_r)
    if point_a is None or point_r is None:
        return False
    challenge = int.from_bytes(hashlib.sha512(encoded_r + public_key + message).digest(), "little") % L
    return point_equal(scalar_mult(B, scalar_s), point_add(point_r, scalar_mult(point_a, challenge)))


def validate_registry(value):
    require_exact_keys(value, {"schema", "signers"}, set(), "trusted-signer registry")
    if value["schema"] != "a8-trusted-signers/v1" or not isinstance(value["signers"], dict):
        fail("ERR_SCHEMA_INVALID", "trusted-signer registry schema is invalid")
    for key_id, signer in value["signers"].items():
        if not isinstance(key_id, str) or not KEY_ID_RE.fullmatch(key_id):
            fail("ERR_SCHEMA_INVALID", "trusted-signer key IDs must be canonical strings")
        require_exact_keys(signer, {"identity", "public_key", "role", "added_at"}, set(), f"signer {key_id}")
        if not nonempty_string(signer["identity"]) or signer["role"] not in {"operator", "reviewer", "issuer"}:
            fail("ERR_SCHEMA_INVALID", f"signer {key_id} identity or role is invalid")
        parse_utc(signer["added_at"], f"signer {key_id} added_at")
        public_key = strict_b64(
            signer["public_key"], 32, "ERR_SCHEMA_INVALID", f"signer {key_id} public key"
        )
        if decode_point(public_key) is None:
            fail("ERR_SCHEMA_INVALID", f"signer {key_id} public key is not a strict Ed25519 point")


def signer_for(registry, key_id, role, cell=None):
    signer = registry["signers"].get(key_id) if isinstance(key_id, str) else None
    if signer is None or signer.get("role") != role:
        fail("ERR_SIGNER_UNTRUSTED", f"{role} key is absent or has the wrong registry role", cell)
    public_key = strict_b64(signer["public_key"], 32, "ERR_SIGNATURE_INVALID", f"{role} public key", cell)
    if decode_point(public_key) is None:
        fail("ERR_SIGNATURE_INVALID", f"{role} public key is not a strict Ed25519 point", cell)
    return signer, public_key


def validate_manifest(value):
    require_exact_keys(value, set(CELLS), set(), "expected-digest manifest")
    for cell, entry in value.items():
        require_exact_keys(entry, {"config_path", "expected_sha256"}, set(), f"manifest cell {cell}")
        if not canonical_relative(entry["config_path"], None) or not isinstance(entry["expected_sha256"], str) or not SHA256_RE.fullmatch(entry["expected_sha256"]):
            fail("ERR_SCHEMA_INVALID", f"manifest cell {cell} is invalid")


def validate_allowlist(value):
    require_exact_keys(value, {"schema", "entries"}, set(), "SKIP allowlist")
    if value["schema"] != "a8-skip-allowlist/v1" or not isinstance(value["entries"], list):
        fail("ERR_SCHEMA_INVALID", "SKIP allowlist schema is invalid")
    result = {}
    for entry in value["entries"]:
        require_exact_keys(entry, {"case_id", "reason", "upstream_epic_a1_commit", "upstream_epic_a1_path_blob_ids"}, set(), "SKIP allowlist entry")
        case_id = entry["case_id"]
        if case_id not in {"AC-006", "AC-015", "AC-016"} or case_id in result:
            fail("ERR_SCHEMA_INVALID", "SKIP allowlist case IDs must be unique and recognized")
        if not nonempty_string(entry["reason"]) or not re.fullmatch(r"[0-9a-f]{40}", entry["upstream_epic_a1_commit"]):
            fail("ERR_SCHEMA_INVALID", f"SKIP allowlist entry {case_id} metadata is invalid")
        blobs = entry["upstream_epic_a1_path_blob_ids"]
        if not isinstance(blobs, dict) or not blobs:
            fail("ERR_SCHEMA_INVALID", f"SKIP allowlist entry {case_id} needs activation paths")
        for path, blob_id in blobs.items():
            if not canonical_relative(path, None) or not re.fullmatch(r"[0-9a-f]{40}", blob_id):
                fail("ERR_SCHEMA_INVALID", f"SKIP allowlist entry {case_id} path/blob is invalid")
        result[case_id] = entry
    return result


def canonical_relative(value, prefix):
    if not isinstance(value, str) or "\\" in value or value.startswith("/"):
        return False
    path = PurePosixPath(value)
    if str(path) != value or any(part in {"", ".", ".."} for part in path.parts):
        return False
    return prefix is None or value.startswith(prefix + "/")


def safe_repo_file(root, ref, cell=None):
    if not canonical_relative(ref, "tests/hook-activation-live-proof/raw"):
        fail("ERR_SCHEMA_INVALID", f"evidence ref is not a canonical raw-capture path: {ref!r}", cell)
    current = root
    for part in PurePosixPath(ref).parts:
        current = current / part
        try:
            mode = current.lstat().st_mode
        except OSError as exc:
            fail("ERR_HASH_MISMATCH", f"evidence ref cannot be read: {ref}: {exc}", cell)
        if stat.S_ISLNK(mode):
            fail("ERR_SCHEMA_INVALID", f"evidence ref traverses a symlink: {ref}", cell)
    if not current.is_file():
        fail("ERR_HASH_MISMATCH", f"evidence ref is not a regular file: {ref}", cell)
    return current


def file_digest(path):
    try:
        return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError as exc:
        fail("ERR_HASH_MISMATCH", f"cannot hash {path}: {exc}")


def validate_ledger(value, registry):
    require_exact_keys(value, {"schema", "entries"}, set(), "nonce ledger")
    if value["schema"] != "live-host-nonce-ledger/v1" or not isinstance(value["entries"], list):
        fail("ERR_SCHEMA_INVALID", "nonce ledger schema is invalid")
    by_nonce = {}
    for entry in value["entries"]:
        require_exact_keys(entry, {"nonce", "matrix_cell", "issued_at", "issuer", "issuer_key_id", "issuer_signature", "consumed_by_record"}, set(), "nonce ledger entry")
        nonce = entry["nonce"]
        if not isinstance(nonce, str) or not NONCE_RE.fullmatch(nonce):
            fail("ERR_SCHEMA_INVALID", "ledger nonce format is invalid")
        if nonce in by_nonce:
            fail("ERR_NONCE_DUPLICATE_LEDGER_ENTRY", f"duplicate nonce {nonce}")
        if entry["matrix_cell"] not in CELLS or entry["issuer"] != "check-hook-activation-handshake":
            fail("ERR_SCHEMA_INVALID", f"ledger entry {nonce} discriminator is invalid")
        parse_utc(entry["issued_at"], f"ledger entry {nonce} issued_at")
        consumed = entry["consumed_by_record"]
        if consumed is not None and not canonical_relative(consumed, "tests/hook-activation-live-proof"):
            fail("ERR_SCHEMA_INVALID", f"ledger entry {nonce} consumed path is invalid")
        _, public_key = signer_for(registry, entry["issuer_key_id"], "issuer")
        signature = strict_b64(entry["issuer_signature"], 64, "ERR_ISSUER_SIGNATURE_INVALID", "issuer signature")
        unsigned = {k: v for k, v in entry.items() if k not in {"issuer_signature", "consumed_by_record"}}
        target = hashlib.sha256(jcs(unsigned) + b":nonce-issuer").digest()
        if not verify_ed25519(public_key, signature, target):
            fail("ERR_ISSUER_SIGNATURE_INVALID", f"ledger entry {nonce} issuer signature is invalid")
        by_nonce[nonce] = entry
    return by_nonce


def validate_record_schema(record, expected_cell):
    require_exact_keys(record, REQUIRED_RECORD_KEYS, {"notes"}, "live-host record", expected_cell)
    if record["schema"] != "live-host-verification-record/v1" or record["matrix_cell"] != expected_cell:
        fail("ERR_SCHEMA_INVALID", "record schema or matrix-cell filename binding is invalid", expected_cell)
    verdict = record["verdict"]
    if verdict not in {"PASS", "FAIL", "SKIP"}:
        fail("ERR_SCHEMA_INVALID", "verdict is invalid", expected_cell)
    if record.get("notes") is not None and not isinstance(record.get("notes"), str):
        fail("ERR_SCHEMA_INVALID", "notes must be a string or null", expected_cell)
    if verdict == "SKIP":
        if any(record[key] is None for key in SKIP_NONNULL):
            fail("ERR_SCHEMA_INVALID", "SKIP required field is null", expected_cell)
        if any(record[key] is not None for key in RECORD_KEYS - SKIP_NONNULL - {"notes"}):
            fail("ERR_SCHEMA_INVALID", "SKIP carries forbidden session evidence", expected_cell)
        if record["invocation_mode"] != "manual" or record["plugin_hooks_flag"] != "not_applicable":
            fail("ERR_SCHEMA_INVALID", "SKIP must be manual with not_applicable plugin_hooks_flag", expected_cell)
    else:
        nullable = {"notes", "skip_reason"}
        if record["runtime"] != "codex":
            nullable |= {"installed_feature_config_ref", "installed_feature_config_digest"}
        for key in RECORD_KEYS - nullable:
            if record[key] is None:
                fail("ERR_SCHEMA_INVALID", f"{key} is null for {verdict}", expected_cell)
        for key in nullable - {"notes", "skip_reason"}:
            if record[key] is not None:
                fail("ERR_SCHEMA_INVALID", f"{key} must be null outside Codex", expected_cell)
        if record["skip_reason"] is not None:
            fail("ERR_SCHEMA_INVALID", "skip_reason must be null for PASS/FAIL", expected_cell)
    for key in ("check", "operator", "operator_key_id", "reviewer", "reviewer_key_id", "operator_signature", "reviewer_signature"):
        if not nonempty_string(record[key]):
            fail("ERR_SCHEMA_INVALID", f"{key} must be a non-empty string", expected_cell)
    if record["runtime"] not in {"claude", "codex", "copilot"} or record["invocation_mode"] not in {"automated", "manual"}:
        fail("ERR_SCHEMA_INVALID", "runtime or invocation_mode enum is invalid", expected_cell)
    if record["plugin_hooks_flag"] not in {"enabled", "disabled", "not_applicable"}:
        fail("ERR_SCHEMA_INVALID", "plugin_hooks_flag enum is invalid", expected_cell)
    expected_runtime, expected_flag = CELLS[expected_cell]
    if record["runtime"] != expected_runtime or (verdict != "SKIP" and record["plugin_hooks_flag"] != expected_flag):
        fail("ERR_CELL_RUNTIME_MISMATCH", "matrix cell runtime/flag discriminator mismatch", expected_cell)
    if record["operator"] == record["reviewer"] or record["operator_key_id"] == record["reviewer_key_id"]:
        fail("ERR_SIGNER_KEY_COLLISION", "operator and reviewer must be distinct", expected_cell)
    if verdict == "SKIP":
        return
    if not NONCE_RE.fullmatch(record["nonce"]):
        fail("ERR_SCHEMA_INVALID", "nonce format is invalid", expected_cell)
    for key in ("host_session_id", "host_event_id", "cli_name", "cli_version", "host_os", "tool_call_evidence"):
        if not nonempty_string(record[key]):
            fail("ERR_SCHEMA_INVALID", f"{key} must be a non-empty string", expected_cell)
    for key in ("raw_tool_request_ref", "raw_tool_result_ref", "installed_hook_config_ref"):
        if not canonical_relative(record[key], "tests/hook-activation-live-proof/raw"):
            fail("ERR_SCHEMA_INVALID", f"{key} is not a canonical evidence path", expected_cell)
    if record["runtime"] == "codex" and not canonical_relative(record["installed_feature_config_ref"], "tests/hook-activation-live-proof/raw"):
        fail("ERR_SCHEMA_INVALID", "installed_feature_config_ref is invalid", expected_cell)
    for key in ("raw_tool_request_sha256", "raw_tool_result_sha256", "installed_hook_config_digest"):
        if not isinstance(record[key], str) or not SHA256_RE.fullmatch(record[key]):
            fail("ERR_SCHEMA_INVALID", f"{key} format is invalid", expected_cell)
    if record["runtime"] == "codex" and (not isinstance(record["installed_feature_config_digest"], str) or not SHA256_RE.fullmatch(record["installed_feature_config_digest"])):
        fail("ERR_SCHEMA_INVALID", "installed_feature_config_digest format is invalid", expected_cell)
    if not isinstance(record["session_date"], str) or not DATE_RE.fullmatch(record["session_date"]):
        fail("ERR_SCHEMA_INVALID", "session_date format is invalid", expected_cell)
    start = parse_utc(record["session_start"], "session_start", expected_cell)
    end = parse_utc(record["session_end"], "session_end", expected_cell)
    if end <= start or record["session_date"] != start.date().isoformat():
        fail("ERR_SCHEMA_INVALID", "session date/order is invalid", expected_cell)


def validate_signatures(record, registry, cell):
    operator, operator_key = signer_for(registry, record["operator_key_id"], "operator", cell)
    reviewer, reviewer_key = signer_for(registry, record["reviewer_key_id"], "reviewer", cell)
    if record["operator"] != operator["identity"] or record["reviewer"] != reviewer["identity"]:
        fail("ERR_SIGNER_IDENTITY_MISMATCH", "record identity does not match registry", cell)
    if operator_key == reviewer_key:
        fail("ERR_SIGNER_KEY_COLLISION", "operator and reviewer public keys collide", cell)
    unsigned = {k: v for k, v in record.items() if k not in {"operator_signature", "reviewer_signature"}}
    canonical = jcs(unsigned)
    for role, key in (("operator", operator_key), ("reviewer", reviewer_key)):
        signature = strict_b64(record[role + "_signature"], 64, "ERR_SIGNATURE_INVALID", role + " signature", cell)
        target = hashlib.sha256(canonical + b":" + role.encode("ascii")).digest()
        if not verify_ed25519(key, signature, target):
            fail("ERR_SIGNATURE_INVALID", f"{role} signature is invalid", cell)


def parse_feature_flag(path, cell):
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        fail("ERR_FEATURE_CONFIG_MISMATCH", f"feature config cannot be parsed: {exc}", cell)
    matches = re.findall(r"(?m)^\s*plugin_hooks\s*=\s*(true|false)\s*(?:#.*)?$", text)
    if len(matches) != 1:
        fail("ERR_FEATURE_CONFIG_MISMATCH", "feature config needs exactly one boolean plugin_hooks assignment", cell)
    return "enabled" if matches[0] == "true" else "disabled"


def detect_synthetic(path, cell):
    candidate = path.read_bytes()
    fixture_dir = Path(__file__).resolve().parents[3] / "tests/fixtures/live-host-proof"
    for known in fixture_dir.glob("known-synthetic-*"):
        if known.is_file() and candidate == known.read_bytes():
            fail("ERR_SYNTHETIC_SUBSTITUTION", "raw capture is byte-identical to a committed synthetic fixture", cell)


def validate_skip(record, allowlist, root, cell):
    matches = [
        case_id
        for case_id in allowlist
        if re.search(r"(?<![A-Za-z0-9-])" + re.escape(case_id) + r"(?![A-Za-z0-9-])", record["skip_reason"])
    ]
    if len(matches) != 1:
        fail("ERR_STALE_SKIP", "SKIP reason does not cite exactly one allowlisted case", cell)
    case_id = matches[0]
    entry = allowlist[case_id]
    required = HANDSHAKE_PATHS if case_id in {"AC-006", "AC-015"} else CONSUMER_PATHS
    configured = set(entry["upstream_epic_a1_path_blob_ids"])
    if not required.issubset(configured):
        fail("ERR_SCHEMA_INVALID", f"{case_id} allowlist entry omits required activation paths", cell)
    if case_id == "AC-006" and not t005_has_started(root, cell):
        return
    activation_paths = [root / PurePosixPath(path) for path in sorted(required)]
    if all(path.is_file() for path in activation_paths):
        drifted = []
        for relative in sorted(required):
            expected_blob = entry["upstream_epic_a1_path_blob_ids"][relative]
            data = (root / PurePosixPath(relative)).read_bytes()
            actual = hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()
            if actual != expected_blob:
                drifted.append(relative)
        suffix = f"; blob drift={drifted}" if drifted else ""
        fail("ERR_STALE_SKIP", "SKIP activation artifacts now exist" + suffix, cell)


def t005_has_started(root, cell):
    tasks_path = root / "specs/epic-196-a8-integration/tasks.md"
    try:
        text = tasks_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        fail("ERR_SCHEMA_INVALID", f"T-005 lifecycle state cannot be read: {exc}", cell)
    match = re.search(r"(?ms)^## T-005\b.*?(?=^## T-\d+\b|\Z)", text)
    if match is None:
        fail("ERR_SCHEMA_INVALID", "T-005 section is missing from tasks.md", cell)
    statuses = re.findall(r"(?m)^Status: ([^\r\n]+)$", match.group(0))
    if len(statuses) != 1 or statuses[0] not in {
        "Planned", "In Progress", "Blocked", "Implementation Complete", "Done"
    }:
        fail("ERR_SCHEMA_INVALID", "T-005 has an invalid lifecycle status", cell)
    return statuses[0] in {"In Progress", "Implementation Complete", "Done"}


def validate_pass_record(record, root, manifest, ledger_by_nonce, cell):
    if record["verdict"] == "FAIL":
        fail("ERR_SCHEMA_INVALID", "FAIL verdict is aggregate-ineligible", cell)
    if record["invocation_mode"] != "manual":
        fail("ERR_SYNTHETIC_SUBSTITUTION", "live-host handshake remains manual-required", cell)
    request = safe_repo_file(root, record["raw_tool_request_ref"], cell)
    result = safe_repo_file(root, record["raw_tool_result_ref"], cell)
    hook_config = safe_repo_file(root, record["installed_hook_config_ref"], cell)
    pairs = (
        (request, record["raw_tool_request_sha256"]),
        (result, record["raw_tool_result_sha256"]),
        (hook_config, record["installed_hook_config_digest"]),
    )
    feature_path = None
    if record["runtime"] == "codex":
        feature_path = safe_repo_file(root, record["installed_feature_config_ref"], cell)
        pairs += ((feature_path, record["installed_feature_config_digest"]),)
    for path, declared in pairs:
        if file_digest(path) != declared:
            fail("ERR_HASH_MISMATCH", f"declared digest does not match {path.name}", cell)
    if manifest[cell]["expected_sha256"] != record["installed_hook_config_digest"]:
        fail("ERR_DIGEST_MISMATCH", "installed hook config differs from expected manifest", cell)
    if feature_path is not None and parse_feature_flag(feature_path, cell) != record["plugin_hooks_flag"]:
        fail("ERR_FEATURE_CONFIG_MISMATCH", "Codex feature snapshot disagrees with the semantic cell", cell)
    detect_synthetic(request, cell)
    entry = ledger_by_nonce.get(record["nonce"])
    if entry is None:
        fail("ERR_NONCE_UNKNOWN", "record nonce is absent from ledger", cell)
    record_ref = f"tests/hook-activation-live-proof/{FILENAMES[cell]}"
    if entry["consumed_by_record"] not in {None, record_ref}:
        fail("ERR_NONCE_REUSED", "record nonce was consumed by another record", cell)
    if entry["matrix_cell"] != cell:
        fail("ERR_NONCE_CELL_MISMATCH", "nonce was issued for another matrix cell", cell)
    issued = parse_utc(entry["issued_at"], "issued_at", cell)
    started = parse_utc(record["session_start"], "session_start", cell)
    if issued >= started:
        fail("ERR_NONCE_ISSUED_AFTER_SESSION", "nonce was not issued strictly before session", cell)
    if started - issued > dt.timedelta(hours=24):
        fail("ERR_NONCE_EXPIRED", "nonce exceeded its 24-hour TTL", cell)
    return entry, record_ref


def publish_consumption(ledger_path, ledger, proposals, original_bytes):
    changes = [(entry, record_ref) for entry, record_ref in proposals if entry["consumed_by_record"] is None]
    if not changes:
        return
    lock = Path(str(ledger_path) + ".lock")
    try:
        lock.mkdir()
    except FileExistsError:
        fail("ERR_SCHEMA_INVALID", "nonce ledger lock is already held")
    temp_name = None
    cleanup_error = None
    try:
        try:
            current = ledger_path.read_bytes()
        except OSError as exc:
            fail("ERR_SCHEMA_INVALID", f"nonce ledger cannot be re-read under lock: {exc}")
        if hashlib.sha256(current).digest() != hashlib.sha256(original_bytes).digest():
            fail("ERR_SCHEMA_INVALID", "nonce ledger changed before publication")
        for entry, record_ref in changes:
            entry["consumed_by_record"] = record_ref
        payload = (json.dumps(ledger, indent=2, sort_keys=True) + "\n").encode("utf-8")
        original_mode = stat.S_IMODE(ledger_path.stat().st_mode)
        fd, temp_name = tempfile.mkstemp(prefix=ledger_path.name + ".", dir=ledger_path.parent)
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_name, original_mode)
        os.replace(temp_name, ledger_path)
        temp_name = None
        try:
            directory_fd = os.open(ledger_path.parent, os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        except OSError:
            pass
    finally:
        if temp_name is not None:
            try:
                os.unlink(temp_name)
            except OSError as exc:
                cleanup_error = f"temporary nonce ledger cleanup failed: {exc}"
        try:
            lock.rmdir()
        except OSError as exc:
            cleanup_error = f"nonce ledger lock release failed: {exc}"
        if cleanup_error is not None:
            fail("ERR_SCHEMA_INVALID", cleanup_error)


def parser():
    repo = Path(__file__).resolve().parents[3]
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--records-dir", default=repo / "tests/hook-activation-live-proof", type=Path)
    result.add_argument("--nonce-ledger", default=repo / "tests/hook-activation-live-proof/nonce-ledger.json", type=Path)
    result.add_argument("--expected-digest-manifest", default=repo / "plugins/sdd-review-loop/references/a8-expected-hook-config-digests.json", type=Path)
    result.add_argument("--trusted-signers", default=repo / "plugins/sdd-review-loop/references/a8-trusted-signers.json", type=Path)
    result.add_argument("--skip-allowlist", default=repo / "plugins/sdd-review-loop/references/a8-skip-allowlist.json", type=Path)
    return result


def run(args):
    records_dir = args.records_dir.resolve()
    root = records_dir.parent.parent
    registry = load_json(args.trusted_signers, "trusted-signer registry")
    validate_registry(registry)
    manifest = load_json(args.expected_digest_manifest, "expected-digest manifest")
    validate_manifest(manifest)
    allowlist = validate_allowlist(load_json(args.skip_allowlist, "SKIP allowlist"))
    try:
        original_ledger = args.nonce_ledger.read_bytes()
    except OSError as exc:
        fail("ERR_SCHEMA_INVALID", f"nonce ledger cannot be read: {exc}")
    ledger = load_json(args.nonce_ledger, "nonce ledger")
    ledger_by_nonce = validate_ledger(ledger, registry)
    proposals = []
    pending = False
    for cell in CELLS:
        record_path = records_dir / FILENAMES[cell]
        if not record_path.is_file():
            fail("ERR_MISSING_CELL", f"record is missing: {record_path}", cell)
        record = load_json(record_path, f"record {cell}")
        validate_record_schema(record, cell)
        validate_signatures(record, registry, cell)
        if record["verdict"] == "SKIP":
            validate_skip(record, allowlist, root, cell)
            pending = True
        else:
            proposals.append(validate_pass_record(record, root, manifest, ledger_by_nonce, cell))
    publish_consumption(args.nonce_ledger, ledger, proposals, original_ledger)
    print("pending" if pending else "discharged")
    return 0


def main(argv=None):
    try:
        return run(parser().parse_args(argv))
    except ValidationError as exc:
        prefix = f"{exc.cell}: " if exc.cell else ""
        print(f"{prefix}{exc.code}: {exc.message}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
