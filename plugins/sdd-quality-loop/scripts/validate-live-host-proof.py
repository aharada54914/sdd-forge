#!/usr/bin/env python3
"""Validate current native five-cell/five-consumer hook proof.

Contract: specs/epic-196-a8-integration/verification/current-product/live-host-proof-v2.md
"""

import argparse
import ast
import base64
import binascii
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import stat
import sys
import tempfile


CELLS = {
    "Claude-active": ("claude", "not_applicable"),
    "Codex-enabled-active": ("codex", "enabled"),
    "Codex-disabled-expected-unavailable": ("codex", "disabled"),
    "Copilot-primary-active": ("copilot", "not_applicable"),
    "Copilot-subagent-observed": ("copilot", "not_applicable"),
}
FILENAMES = {cell: cell.lower() + ".json" for cell in CELLS}
RECORD_KEYS = {
    "schema", "matrix_cell", "runtime", "check", "invocation_mode",
    "nonce", "host_session_id", "host_event_id", "raw_tool_request_ref",
    "raw_tool_request_sha256", "raw_tool_result_ref", "raw_tool_result_sha256",
    "installed_hook_config_ref", "installed_hook_config_digest",
    "hook_control_ref", "hook_control_sha256",
    "session_date", "session_start", "session_end", "operator",
    "operator_key_id", "reviewer", "reviewer_key_id", "cli_name",
    "cli_version", "host_os", "hooks_state", "tool_call_evidence",
    "verdict", "skip_reason", "operator_signature", "reviewer_signature",
    "observed_status", "consumer_executions", "notes",
}
REQUIRED_RECORD_KEYS = RECORD_KEYS - {"notes"}
SKIP_NONNULL = {
    "schema", "matrix_cell", "runtime", "check", "invocation_mode",
    "operator", "operator_key_id", "reviewer", "reviewer_key_id",
    "verdict", "skip_reason", "operator_signature", "reviewer_signature",
    "hooks_state",
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


def safe_repo_file(root, ref, cell=None, prefix="tests/hook-activation-live-proof/raw"):
    if not canonical_relative(ref, prefix):
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
    if record["schema"] != "live-host-verification-record/v2" or record["matrix_cell"] != expected_cell:
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
        if record["invocation_mode"] != "manual" or record["hooks_state"] != "not_applicable":
            fail("ERR_SCHEMA_INVALID", "SKIP must be manual with not_applicable hooks_state", expected_cell)
    else:
        nullable = {"notes", "skip_reason"}
        if record["runtime"] != "codex":
            nullable |= {"hook_control_ref", "hook_control_sha256"}
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
    if record["hooks_state"] not in {"enabled", "disabled", "not_applicable"}:
        fail("ERR_SCHEMA_INVALID", "hooks_state enum is invalid", expected_cell)
    expected_runtime, expected_flag = CELLS[expected_cell]
    if record["runtime"] != expected_runtime or (verdict != "SKIP" and record["hooks_state"] != expected_flag):
        fail("ERR_CELL_RUNTIME_MISMATCH", "matrix cell runtime/flag discriminator mismatch", expected_cell)
    if record["operator"] == record["reviewer"] or record["operator_key_id"] == record["reviewer_key_id"]:
        fail("ERR_SIGNER_KEY_COLLISION", "operator and reviewer must be distinct", expected_cell)
    if verdict == "SKIP":
        return
    expected_status = (
        "CAPABILITY_RUNTIME_UNAVAILABLE" if expected_cell == "Codex-disabled-expected-unavailable" else "HOOK_ACTIVE"
    )
    allowed_status = (
        {"HOOK_ACTIVE", "CAPABILITY_RUNTIME_UNAVAILABLE"}
        if expected_cell == "Copilot-subagent-observed"
        else {expected_status}
    )
    if record["observed_status"] not in allowed_status:
        fail(
            "ERR_CELL_RUNTIME_MISMATCH",
            "observed hook outcome does not match this cell",
            expected_cell,
        )
    if not NONCE_RE.fullmatch(record["nonce"]):
        fail("ERR_SCHEMA_INVALID", "nonce format is invalid", expected_cell)
    for key in ("host_session_id", "host_event_id", "cli_name", "cli_version", "host_os", "tool_call_evidence"):
        if not nonempty_string(record[key]):
            fail("ERR_SCHEMA_INVALID", f"{key} must be a non-empty string", expected_cell)
    for key in ("raw_tool_request_ref", "raw_tool_result_ref", "installed_hook_config_ref"):
        if not canonical_relative(record[key], "tests/hook-activation-live-proof/raw"):
            fail("ERR_SCHEMA_INVALID", f"{key} is not a canonical evidence path", expected_cell)
    if record["runtime"] == "codex" and not canonical_relative(record["hook_control_ref"], "tests/hook-activation-live-proof/raw"):
        fail("ERR_SCHEMA_INVALID", "hook_control_ref is invalid", expected_cell)
    for key in ("raw_tool_request_sha256", "raw_tool_result_sha256", "installed_hook_config_digest"):
        if not isinstance(record[key], str) or not SHA256_RE.fullmatch(record[key]):
            fail("ERR_SCHEMA_INVALID", f"{key} format is invalid", expected_cell)
    if record["runtime"] == "codex" and (not isinstance(record["hook_control_sha256"], str) or not SHA256_RE.fullmatch(record["hook_control_sha256"])):
        fail("ERR_SCHEMA_INVALID", "hook_control_sha256 format is invalid", expected_cell)
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


def parse_hook_control(path, cell, events=None):
    """Bind current Codex hooks control to the original launch metadata."""
    control = load_json(path, "Codex launch metadata")
    argv = control.get("command") if isinstance(control, dict) else None
    if (
        not isinstance(argv, list)
        or not argv
        or not all(isinstance(arg, str) for arg in argv)
        or argv[0].replace("\\", "/").split("/")[-1] not in {"codex", "codex.exe"}
    ):
        fail("ERR_FEATURE_CONFIG_MISMATCH", "Codex native launch argv is missing", cell)
    states = [argv[i] for i in range(len(argv) - 1) if argv[i] in {"--enable", "--disable"} and argv[i + 1] == "hooks"]
    if len(states) != 1 or any(re.search(r"(?:features\.)?hooks\s*=", arg) for arg in argv):
        fail(
            "ERR_FEATURE_CONFIG_MISMATCH",
            "launch needs exactly one current hooks selector",
            cell,
        )
    if events is not None:
        metadata = [event.get("payload", {}) for event in events if event.get("type") == "session_meta"]
        started = control.get("started")
        if (
            len(metadata) != 1
            or not nonempty_string(control.get("root"))
            or metadata[0].get("cwd") != control["root"]
            or type(started) not in {int, float}
        ):
            fail(
                "ERR_FEATURE_CONFIG_MISMATCH",
                "launch metadata is not bound to native session cwd/start",
                cell,
            )
        times = [parse_utc(event["timestamp"], "native timestamp", cell) for event in events if "timestamp" in event]
        if not times:
            fail("ERR_FEATURE_CONFIG_MISMATCH", "native launch timestamps missing", cell)
        first = min(times)
        if not 0 <= first.timestamp() - started <= 300:
            fail(
                "ERR_FEATURE_CONFIG_MISMATCH",
                "launch metadata start differs from native session",
                cell,
            )
    return "enabled" if states[0] == "--enable" else "disabled"


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
        "Draft", "Planned", "In Progress", "Blocked", "Implementation Complete", "Done"
    }:
        fail("ERR_SCHEMA_INVALID", "T-005 has an invalid lifecycle status", cell)
    return statuses[0] in {"In Progress", "Implementation Complete", "Done"}


def validate_pass_record(record, root, manifest, ledger_by_nonce, cell):
    if record["verdict"] == "FAIL":
        fail("ERR_SCHEMA_INVALID", "FAIL verdict is aggregate-ineligible", cell)
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
        feature_path = safe_repo_file(root, record["hook_control_ref"], cell)
        pairs += ((feature_path, record["hook_control_sha256"]),)
    for path, declared in pairs:
        if file_digest(path) != declared:
            fail("ERR_HASH_MISMATCH", f"declared digest does not match {path.name}", cell)
    if manifest[cell]["expected_sha256"] != record["installed_hook_config_digest"]:
        fail("ERR_DIGEST_MISMATCH", "installed hook config differs from expected manifest", cell)
    if feature_path is not None and parse_hook_control(feature_path, cell) != record["hooks_state"]:
        fail("ERR_FEATURE_CONFIG_MISMATCH", "Codex feature snapshot disagrees with the semantic cell", cell)
    detect_synthetic(request, cell)
    return validate_nonce_binding(record, ledger_by_nonce, cell)


def validate_nonce_binding(record, ledger_by_nonce, cell):
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
    ended = parse_utc(record["session_end"], "session_end", cell)
    if issued >= ended:
        fail(
            "ERR_NONCE_ISSUED_AFTER_SESSION",
            "nonce was not issued before session completion",
            cell,
        )
    if started - issued > dt.timedelta(hours=24):
        fail("ERR_NONCE_EXPIRED", "nonce exceeded its 24-hour TTL", cell)
    return entry, record_ref


CONSUMERS = {
    "sdd-ship": "plugins/sdd-ship/skills/ship/SKILL.md",
    "sdd-bootstrap": "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md",
    "sdd-bootstrap-interviewer": "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md",
    "lite-spec": "plugins/sdd-lite/skills/lite-spec/SKILL.md",
    "lite-gate": "plugins/sdd-lite/skills/lite-gate/SKILL.md",
}
EXECUTION_KEYS = {
    "consumer",
    "source_ref",
    "source_sha256",
    "nonce",
    "host_session_id",
    "host_event_id",
    "session_start",
    "session_end",
    "observed_status",
    "raw_tool_request_ref",
    "raw_tool_request_sha256",
    "raw_tool_result_ref",
    "raw_tool_result_sha256",
    "consumer_invocation_ref",
    "consumer_invocation_sha256",
}


def native_calls(events, runtime, cell):
    """Read native event identities; assistant prose never becomes a tool result."""
    sessions, calls, results = set(), [], {}
    for position, event in enumerate(events):
        if not isinstance(event, dict):
            fail("ERR_SCHEMA_INVALID", "native transcript event is not an object", cell)
        kind = event.get("type")
        payload = event.get("payload", {})
        if runtime == "copilot":
            data = event.get("data", {})
            if kind == "session.start":
                sessions.add(data.get("sessionId"))
            if kind == "result" and event.get("exitCode") == 0:
                sessions.add(event.get("sessionId"))
            if kind == "tool.execution_start":
                calls.append(
                    (
                        position,
                        event.get("id"),
                        data.get("toolCallId"),
                        data.get("toolName"),
                        data.get("arguments"),
                        event,
                        event,
                    )
                )
            if kind == "tool.execution_complete":
                key = data.get("toolCallId")
                if key in results:
                    fail("ERR_SCHEMA_INVALID", "duplicate native completion", cell)
                results[key] = (position, event, event)
        elif runtime == "claude":
            if kind == "system" and event.get("subtype") == "init":
                sessions.add(event.get("session_id"))
            message = event.get("message", {})
            for block in message.get("content", []) if isinstance(message, dict) else []:
                if not isinstance(block, dict):
                    continue
                if kind == "assistant" and block.get("type") == "tool_use":
                    calls.append(
                        (
                            position,
                            block.get("id"),
                            block.get("id"),
                            block.get("name"),
                            block.get("input"),
                            block,
                            event,
                        )
                    )
                if kind == "user" and block.get("type") == "tool_result":
                    key = block.get("tool_use_id")
                    if key in results:
                        fail("ERR_SCHEMA_INVALID", "duplicate native completion", cell)
                    results[key] = (position, block, event)
        elif runtime == "codex":
            if kind == "session_meta" and isinstance(payload, dict):
                sessions.add(payload.get("id"))
            if kind == "response_item" and isinstance(payload, dict):
                if payload.get("type") in {"function_call", "custom_tool_call"}:
                    calls.append(
                        (
                            position,
                            payload.get("id") or payload.get("call_id"),
                            payload.get("call_id"),
                            payload.get("name"),
                            payload.get("arguments", payload.get("input")),
                            payload,
                            event,
                        )
                    )
                if payload.get("type") in {
                    "function_call_output",
                    "custom_tool_call_output",
                }:
                    key = payload.get("call_id")
                    if key in results:
                        fail("ERR_SCHEMA_INVALID", "duplicate native completion", cell)
                    results[key] = (position, payload, event)
    if not sessions or any(not nonempty_string(s) for s in sessions):
        fail("ERR_SCHEMA_INVALID", "native session-start provenance is missing", cell)
    identities = [call[1] for call in calls]
    if any(not nonempty_string(x) for x in identities) or len(set(identities)) != len(identities):
        fail(
            "ERR_SCHEMA_INVALID",
            "native request event identity is absent or duplicated",
            cell,
        )
    return sessions, calls, results


def verified_status(value, nonce, runtime, schema="sdd-hook-verify-result/v1"):
    """Recognize the shipped helper's JSON inside native tool output only."""
    if isinstance(value, dict):
        if (
            value.get("schema") == schema
            and value.get("nonce") == nonce
            and (
                schema == "sdd-hook-challenge/v1"
                or value.get("runtime")
                == {
                    "claude": "claude-code",
                    "codex": "codex-cli",
                    "copilot": "copilot-cli",
                }[runtime]
            )
        ):
            return {value.get("status") if schema == "sdd-hook-verify-result/v1" else "challenge"}
        return set().union(*(verified_status(v, nonce, runtime, schema) for v in value.values()))
    if isinstance(value, list):
        return set().union(*(verified_status(v, nonce, runtime, schema) for v in value))
    found = set()
    if isinstance(value, str):
        try:
            nested = json.loads(value)
        except ValueError:
            nested = None
        if isinstance(nested, (dict, list)):
            found.update(verified_status(nested, nonce, runtime, schema))
        decoder = json.JSONDecoder()
        for match in re.finditer(r"\{", value):
            try:
                obj, _ = decoder.raw_decode(value[match.start() :])
            except ValueError:
                continue
            if isinstance(obj, dict):
                found.update(verified_status(obj, nonce, runtime, schema))
    return found


def native_text(value):
    if isinstance(value, str):
        try:
            nested = json.loads(value)
        except ValueError:
            nested = None
        return native_text(nested) if isinstance(nested, (dict, list)) else value
    if isinstance(value, dict):
        return "\n".join(native_text(v) for v in value.values())
    if isinstance(value, list):
        return "\n".join(native_text(v) for v in value)
    return ""


def native_commands(call):
    """Extract commands from supported native execution tools, never prose."""
    name, arguments = call[3], call[4]
    if isinstance(arguments, str):
        try:
            parsed = json.loads(arguments)
        except ValueError:
            parsed = None
        if isinstance(parsed, dict):
            arguments = parsed
    if name in {
        "bash",
        "Bash",
        "exec_command",
        "shell_command",
        "shell",
    } and isinstance(arguments, dict):
        command = arguments.get("command", arguments.get("cmd"))
        return [command] if isinstance(command, str) else []
    if name == "exec" and isinstance(arguments, str):
        # Match the entire observed wrapper. A function call mentioned inside
        # a comment, string, or conditional is data, not an executed tool.
        match = re.fullmatch(
            r"\s*(?:const|let)\s+([A-Za-z_][A-Za-z_0-9]*)\s*=\s*await\s+tools\.exec_command\((\{.*\})\)\s*;\s*(.*?)\s*",
            arguments, re.S,
        )
        if match is None:
            return []
        variable, literal, output = match.groups()
        output = re.sub(r"\s+", "", output).rstrip(';')
        outputs = {
            f'text({variable}.output)', f'text(JSON.stringify({variable}))',
            f'text({variable}.output);text(`EXIT:${{{variable}.exit_code}}`)',
            f'text(JSON.stringify({{exit_code:{variable}.exit_code,output:{variable}.output}}))',
            f'text(JSON.stringify({{wrapper_exit_code:{variable}.exit_code,output:{variable}.output}}))',
        }
        if output not in outputs:
            return []
        # Only literal scalar exec options are supported; no JS evaluation.
        remaining, options = literal[1:-1].strip(), {}
        decoder = json.JSONDecoder()
        while remaining:
            key = re.match(r'(?:("(?:[^"\\]|\\.)*")|([A-Za-z_][A-Za-z_0-9]*))\s*:\s*', remaining)
            if key is None:
                return []
            try:
                name = json.loads(key.group(1)) if key.group(1) else key.group(2)
                value, end = decoder.raw_decode(remaining[key.end():])
            except ValueError:
                return []
            if name in options or name not in {'cmd', 'workdir', 'yield_time_ms', 'max_output_tokens'}:
                return []
            options[name] = value
            remaining = remaining[key.end() + end:].strip()
            if remaining:
                if not remaining.startswith(','):
                    return []
                remaining = remaining[1:].strip()
        command = options.get('cmd')
        return [command] if isinstance(command, str) else []
    return []


def shell_commands(command):
    """Tokenize only straight-line observed shell programs; never execute them."""
    if any(marker in command for marker in ('<<', '`', '$(')):
        return []
    quote, escaped, comment, normalized = None, False, False, []
    for char in command:
        if comment:
            if char == '\n':
                comment = False
                if not ''.join(normalized).rstrip().endswith(';'):
                    normalized.append(';')
            continue
        if char == '#' and quote is None and (not normalized or normalized[-1].isspace() or normalized[-1] == ';'):
            comment = True
            continue
        if escaped:
            normalized.append(char)
            escaped = False
        elif char == "\\" and quote != "'":
            normalized.append(char)
            escaped = True
        elif char in {"'", '"'}:
            quote = None if quote == char else char if quote is None else quote
            normalized.append(char)
        elif char == '\n':
            if quote:
                return []
            if not ''.join(normalized).rstrip().endswith(';'):
                normalized.append(';')
        else:
            normalized.append(char)
    if quote or escaped:
        return []
    lexer = shlex.shlex(''.join(normalized), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    lexer.commenters = ''
    try:
        tokens = list(lexer)
    except ValueError:
        return []
    commands, words = [], []
    for token in tokens:
        if token in {';', '&&'}:
            if words:
                commands.append(words)
                words = []
        elif token in {'||', '|', '&', '(', ')', '{', '}'}:
            return []
        else:
            words.append(token)
    if words:
        commands.append(words)
    return commands


def command_redirects(words):
    """Return argv and literal stdout/stderr redirects for supported calls."""
    first = next((i for i, word in enumerate(words) if word in {'>', '>>', '<', '2>'}), len(words))
    if first < len(words) and first and words[first - 1] == '2':
        first -= 1
    argv, rest, paths = words[:first], words[first:], []
    while rest:
        if rest[0] == '2':
            rest = rest[1:]
        if len(rest) < 2 or rest[0] != '>' or not re.fullmatch(r'[A-Za-z0-9_./-]+', rest[1]):
            return [], []
        paths.append(rest[1])
        rest = rest[2:]
    return argv, paths


def safe_capture_tail(commands, paths):
    """Allow original output reads and numeric exit bookkeeping, not substitutes."""
    exit_variables = set()
    paths = set(paths)
    for position, words in enumerate(commands):
        argv, redirected = command_redirects(words)
        if not argv:
            return False
        if len(argv) == 1 and re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*=\$\?', argv[0]):
            exit_variables.add('$' + argv[0].split('=')[0])
        elif argv[0] == 'printf' and len(argv) == 3 and argv[1] in {'%s\\n', 'exit=%s\\n'}:
            if argv[2] not in exit_variables | {'stdout:', 'stderr:', 'sentinel:'} | {path + ':' for path in paths}:
                return False
            if redirected and (argv[2] not in exit_variables or set(redirected) & paths):
                return False
            paths.update(redirected)
        elif argv[0] == 'exit' and len(argv) == 2 and argv[1] in exit_variables | {'0'} and not redirected:
            if position != len(commands) - 1:
                return False
            continue
        elif argv[0] == 'cat' and len(argv) >= 2 and set(argv[1:]) <= paths and not redirected:
            continue
        elif (argv[:2] == ['sed', '-n'] and len(argv) >= 4 and re.fullmatch(r'\d+,\d+p', argv[2])
              and set(argv[3:]) - {'--'} <= paths and not redirected):
            continue
        elif (len(argv) == 4 and re.fullmatch(r'python(?:3)?', argv[0]) and argv[1:3] == ['-m', 'json.tool']
              and argv[3] in paths and not redirected):
            continue
        else:
            return False
    return True


def safe_python_reader(argv, paths):
    if len(argv) != 3 or argv[:2] not in (['python3', '-c'], ['python', '-c']):
        return False
    try:
        tree = ast.parse(argv[2])
    except SyntaxError:
        return False
    calls = sorted((node for node in ast.walk(tree) if isinstance(node, ast.Call)
                    and isinstance(node.func, ast.Name) and node.func.id in {'open', 'Path'}),
                   key=lambda node: (node.lineno, node.col_offset))
    if any(len(node.args) != 1 or not isinstance(node.args[0], ast.Constant)
           or node.args[0].value not in paths for node in calls):
        return False
    files = [node.args[0].value for node in calls]
    candidates = []
    if len(files) == 1:
        for options in ('indent=2', 'separators=(",", ":")'):
            candidates.append(f'import json; d=json.load(open({files[0]!r})); print(json.dumps(d, {options}))')
    if len(files) == 3:
        candidates.append('from pathlib import Path; ' + '; '.join(
            f'print({label!r}+Path({path!r}).read_text().rstrip())'
            for label, path in zip(('EXIT=', 'STDOUT=', 'STDERR='), files)))
    return any(ast.dump(tree) == ast.dump(ast.parse(candidate)) for candidate in candidates)


def safe_output_reader(command, paths):
    commands = shell_commands(command)
    if not commands:
        return False
    if safe_capture_tail(commands, paths):
        return True
    if len(commands) == 1:
        argv = commands[0]
        if safe_python_reader(argv, paths):
            return True
        if argv[:2] == ['jq', '-n'] and len(argv) == 12:
            return (argv[2:5] == ['--rawfile', 'verification', 'verification.json']
                    and argv[5:8] == ['--rawfile', 'stderr', 'verification.stderr']
                    and argv[8:11] == ['--rawfile', 'exit', 'verification.exit']
                    and argv[11] == '{stdout:$verification,stderr:$stderr,exit:$exit}'
                    and {'verification.json', 'verification.stderr', 'verification.exit'} <= set(paths))
    if len(commands) == 4 and commands[0][:1] == ['for']:
        first, printing, reading, end = commands
        if len(first) < 4 or first[2] != 'in':
            return False
        variable = first[1]
        return (set(first[3:]) <= set(paths) | {'challenge.json', 'recorded-result.json'}
                and printing == ['do', 'printf', '%s\\n', '[$' + variable + ']']
                and reading[:2] == ['sed', '-n'] and len(reading) == 4
                and re.fullmatch(r'\d+,\d+p', reading[2]) is not None
                and reading[3] == '$' + variable and end == ['done'])
    return False


def reader_paths(command):
    paths = set()
    for argv in shell_commands(command):
        paths.update(argv)
        if len(argv) == 3 and argv[:2] in (['python3', '-c'], ['python', '-c']):
            try:
                tree = ast.parse(argv[2])
            except SyntaxError:
                continue
            paths.update(node.value for node in ast.walk(tree) if isinstance(node, ast.Constant) and isinstance(node.value, str))
    return paths


def invokes_helper(call, flag):
    for command in native_commands(call):
        commands = shell_commands(command)
        for index, words in enumerate(commands):
            argv, paths = command_redirects(words)
            if len(argv) > 1 and argv[1] == '-I':
                argv.pop(1)
            if (len(argv) >= 3 and re.fullmatch(r'(?:[^ ]*/)?python(?:3(?:\.\d+)?)?(?:\.exe)?', argv[0])
                    and argv[1].replace('\\', '/').split('/')[-1] == 'check-hook-activation-handshake.py'
                    and flag in argv[2:] and len({'--emit-challenge', '--verify-response'} & set(argv[2:])) == 1):
                if safe_capture_tail(commands[index + 1:], paths):
                    return True
                break
            # Preparing the recorded-result input cannot inject helper stdout.
            if argv == ['set', '+e']:
                continue
            if argv and argv[0] in {'jq', 'printf'} and paths == ['recorded-result.json']:
                continue
            break
    return False


def read_source_in_order(outputs, source):
    # Native readers may number lines or split a file across several calls.
    # Preserve their order; membership of a shuffled set of lines is not a read.
    text = "\n".join(outputs)
    text = re.sub(r"(?m)^\s*\d+(?:[→|:]|\t) ?", "", text)
    cursor = 0
    for line in source.splitlines():
        if not line.strip():
            continue
        position = text.find(line.strip(), cursor)
        if position < 0:
            return False
        cursor = position + len(line.strip())
    return True


def native_helper_outputs(call, calls, results, before):
    output = results.get(call[2])
    if output is None or not call[0] < output[0] < before:
        return []
    values = [output[1]]
    # A native caller may redirect helper stdout and inspect that exact file in
    # a later tool call. Assistant text and unrelated tool output are excluded.
    destinations, captured_paths = [], set()
    for command in native_commands(call):
        started = False
        for words in shell_commands(command):
            argv, redirected = command_redirects(words)
            if any(word.endswith('check-hook-activation-handshake.py') for word in argv):
                started = True
                destinations.extend(path for path in redirected if path.endswith('.json'))
                captured_paths.update(redirected)
            elif started and argv[:1] == ['printf']:
                captured_paths.update(redirected)
    for reader in calls:
        completed = results.get(reader[2])
        commands = native_commands(reader)
        command = "\n".join(commands)
        allowed = set(captured_paths)
        allowed.add('sdd/.hook-canary-sentinel')
        if (
            completed
            and output[0] < reader[0] < completed[0] < before
            and any(set(destinations) & reader_paths(value) for value in commands)
            and commands
            and all(safe_output_reader(value, allowed) for value in commands)
            and not re.search(r"(?<![<>])[>]|write_text|write_bytes", command)
        ):
            # Any intervening touch of the redirected output makes this read
            # ambiguous. Do not silently accept a replacement generated later.
            if any(
                output[0] < other[0] < reader[0]
                and any(
                    re.search(
                        r"(?<![A-Za-z0-9_./-])" + re.escape(path) + r"(?![A-Za-z0-9_./-])",
                        native_text(other[4]),
                    )
                    for path in captured_paths
                )
                for other in calls
            ):
                continue
            if any(shell_commands(value)[0][0] == 'for' for value in commands):
                # The observed loop also prints the recorded-result input.
                # Only the exact helper-output section is verifier evidence.
                text = native_text(completed[1])
                for path in destinations:
                    section = re.search(r'(?ms)^\[' + re.escape(path) + r'\]\n(.*?)(?=^\[|\Z)', text)
                    if section:
                        values.append(section.group(1))
            else:
                values.append(completed[1])
    return values


def native_strings(value):
    if isinstance(value, str):
        yield value
        try:
            parsed = json.loads(value)
        except ValueError:
            parsed = None
        if isinstance(parsed, (dict, list)):
            yield from native_strings(parsed)
    elif isinstance(value, dict):
        for item in value.values():
            yield from native_strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from native_strings(item)


def validate_native_outcome(call, completion, events, runtime, nonce, status, cell):
    # Reuse the shipped denial semantics instead of treating helper stdout as
    # permission to contradict the original native tool completion.
    spec = importlib.util.spec_from_file_location('sdd_native_handshake', Path(__file__).with_name('check-hook-activation-handshake.py'))
    if spec is None or spec.loader is None:
        fail('ERR_SCHEMA_INVALID', 'native handshake verifier unavailable', cell)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    native_runtime = {'claude':'claude-code', 'codex':'codex-cli', 'copilot':'copilot-cli'}[runtime]
    envelope = {'runtime':native_runtime, 'nonce':nonce, 'executed':False}
    active = False
    try:
        if runtime == 'codex':
            for text in native_strings(completion[1]):
                try:
                    helper._verify_codex_host_denial(dict(envelope, schema=helper.HOST_DENIAL_SCHEMA, raw_result=text), nonce, native_runtime)
                    active = True
                except helper.HookHandshakeError:
                    continue
        elif runtime == 'copilot':
            helper._verify_copilot_host_denial(dict(envelope, schema=helper.COPILOT_HOST_DENIAL_SCHEMA, raw_events=[call[5], completion[1]]), nonce, native_runtime)
            active = True
        else:
            request = json.loads(json.dumps(call[5]))
            target = request.get('input', {}).get('file_path')
            if target != helper.CANARY_TARGET:
                roots = [event.get('cwd') for event in events if event.get('type') == 'system' and event.get('subtype') == 'init']
                if len(roots) != 1 or not isinstance(roots[0], str) or target != str(Path(roots[0]) / helper.CANARY_TARGET):
                    fail('ERR_SCHEMA_INVALID', 'Claude canary is outside its native session root', cell)
                # The original bytes were matched above. Normalize only this
                # validation copy for replay from a different checkout.
                request['input']['file_path'] = helper.CANARY_TARGET
            helper._verify_claude_host_denial(dict(envelope, schema=helper.CLAUDE_HOST_DENIAL_SCHEMA, raw_request=request, raw_result=completion[1]), nonce, native_runtime)
            active = True
    except helper.HookHandshakeError:
        active = False
    if active != (status == 'HOOK_ACTIVE'):
        fail('ERR_CELL_RUNTIME_MISMATCH', 'native canary outcome contradicts verifier status', cell)


def validate_native_execution(entry, request, result, transcript_path, source, runtime, cell):
    nonce, session, event_id = (
        entry["nonce"],
        entry["host_session_id"],
        entry["host_event_id"],
    )
    try:
        events = [
            CANON.parse_json_bytes(line.encode("utf-8"))
            for line in transcript_path.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
    except (ValueError, OSError, UnicodeError, CANON.CanonicalizeError) as exc:
        fail("ERR_SCHEMA_INVALID", f"native transcript is invalid: {exc}", cell)
    sessions, calls, results = native_calls(events, runtime, cell)
    if sessions != {session}:
        fail(
            "ERR_CELL_RUNTIME_MISMATCH",
            "consumer native session differs from signed inventory",
            cell,
        )
    matches = [call for call in calls if call[1] == event_id]
    if len(matches) != 1:
        fail(
            "ERR_SCHEMA_INVALID",
            "canary request is absent from native invocation",
            cell,
        )
    call = matches[0]
    completion = results.get(call[2])
    if (
        jcs(request) not in (jcs(call[5]), jcs(call[6]))
        or completion is None
        or jcs(result) not in (jcs(completion[1]), jcs(completion[2]))
        or completion[0] <= call[0]
    ):
        fail(
            "ERR_SCHEMA_INVALID",
            "native request/result substitution or missing completion",
            cell,
        )
    validate_native_outcome(call, completion, events, runtime, nonce, entry['observed_status'], cell)
    scope_calls = calls
    if runtime == "copilot":
        agent = call[5].get("agentId")
        parent = call[5].get("data", {}).get("parentToolCallId")
        if agent != completion[1].get("agentId") or parent != completion[1].get("data", {}).get("parentToolCallId"):
            fail(
                "ERR_CELL_RUNTIME_MISMATCH",
                "native child request/completion ownership differs",
                cell,
            )
        if cell == "Copilot-subagent-observed":
            if not nonempty_string(agent) or not nonempty_string(parent):
                fail(
                    "ERR_CELL_RUNTIME_MISMATCH",
                    "child cell lacks a native child dispatch",
                    cell,
                )
            task_calls = [c for c in calls if c[2] == parent and c[3] == "task" and c[0] < call[0]]
            started = [
                i
                for i, event in enumerate(events)
                if event.get("type") == "subagent.started"
                and event.get("agentId") == agent
                and event.get("data", {}).get("toolCallId") == parent
            ]
            ended = [
                i
                for i, event in enumerate(events)
                if event.get("type") == "subagent.completed"
                and event.get("agentId") == agent
                and event.get("data", {}).get("toolCallId") == parent
            ]
            if (
                len(task_calls) != 1
                or len(started) != 1
                or len(ended) != 1
                or not task_calls[0][0] < started[0] < call[0] < completion[0] < ended[0]
            ):
                fail(
                    "ERR_CELL_RUNTIME_MISMATCH",
                    "child lifecycle is not bound to the native parent task",
                    cell,
                )
        elif cell == "Copilot-primary-active" and (agent is not None or parent is not None):
            fail(
                "ERR_CELL_RUNTIME_MISMATCH",
                "primary cell contains a child canary",
                cell,
            )
        scope_calls = [
            c for c in calls if c[5].get("agentId") == agent and c[5].get("data", {}).get("parentToolCallId") == parent
        ]
    arguments = json.dumps(call[4], ensure_ascii=False)
    if ".hook-canary-sentinel" not in arguments or nonce not in arguments:
        fail("ERR_SCHEMA_INVALID", "native request is not the nonce-bound canary", cell)
    text_calls = [(c, json.dumps(c[4], ensure_ascii=False).replace("\\\\", "/")) for c in scope_calls]
    emits = [
        c[0]
        for c, text in text_calls
        if invokes_helper(c, "--emit-challenge")
        and c[0] < call[0]
        and c[2] in results
        and c[0] < results[c[2]][0] < call[0]
        and any(
            verified_status(value, nonce, runtime, "sdd-hook-challenge/v1") == {"challenge"}
            for value in native_helper_outputs(c, scope_calls, results, call[0])
        )
    ]
    # Installed caches may add a version segment or copy the canonical skill.
    # Bind the complete read content to the signed source hash, not that path.
    read_outputs = [
        native_text(results[c[2]][1])
        for c, text in text_calls
        if "SKILL.md" in text and c[2] in results and emits and c[0] < results[c[2]][0] < min(emits)
    ]
    verifies = [c for c, text in text_calls if invokes_helper(c, "--verify-response") and c[0] > completion[0]]
    if (
        not read_outputs
        or not emits
        or not verifies
        or not read_source_in_order(read_outputs, source.read_text(encoding="utf-8"))
    ):
        fail(
            "ERR_SCHEMA_INVALID",
            "consumer must fully read its entry point then emit, dispatch, and verify inside the native session",
            cell,
        )
    statuses = set()
    for verify in verifies:
        for value in native_helper_outputs(verify, scope_calls, results, len(events)):
            statuses.update(verified_status(value, nonce, runtime))
    if statuses != {entry["observed_status"]}:
        fail(
            "ERR_SCHEMA_INVALID",
            "native verifier output does not establish the consumer outcome",
            cell,
        )
    timestamps = [
        parse_utc(event["timestamp"], "native event timestamp", cell) for event in events if "timestamp" in event
    ]
    if not timestamps or timestamps != sorted(timestamps):
        fail("ERR_SCHEMA_INVALID", "native timestamps are missing or unordered", cell)
    emitted = events[min(emits)].get("timestamp")
    dispatched = events[call[0]].get("timestamp")
    starts = [
        parse_utc(event["payload"]["timestamp"], "native session start", cell)
        for event in events
        if runtime == "codex" and event.get("type") == "session_meta" and "timestamp" in event.get("payload", {})
    ]
    return (
        starts[0] if len(starts) == 1 else min(timestamps),
        max(timestamps),
        parse_utc(emitted, "native emit timestamp", cell),
        parse_utc(dispatched, "native dispatch timestamp", cell),
    )


def validate_consumer_executions(record, root, ledger_by_nonce, cell):
    entries = record["consumer_executions"]
    if not isinstance(entries, list) or len(entries) != len(CONSUMERS):
        fail("ERR_SCHEMA_INVALID", "all five executed consumers are required", cell)
    primary = [entry for entry in entries if isinstance(entry, dict) and entry.get("nonce") == record["nonce"]]
    if len(primary) != 1 or any(
        primary[0].get(key) != record[key]
        for key in (
            "host_session_id",
            "host_event_id",
            "raw_tool_request_ref",
            "raw_tool_request_sha256",
            "raw_tool_result_ref",
            "raw_tool_result_sha256",
        )
    ):
        fail(
            "ERR_NONCE_REUSED",
            "cell evidence must name one exact consumer dispatch",
            cell,
        )
    seen_consumers, seen_nonces, seen_events, proposals = set(), set(), set(), []
    for entry in entries:
        require_exact_keys(
            entry,
            EXECUTION_KEYS | ({"hook_control_ref", "hook_control_sha256"} if record["runtime"] == "codex" else set()),
            set(),
            "consumer execution",
            cell,
        )
        consumer = entry["consumer"]
        if not isinstance(consumer, str) or consumer not in CONSUMERS or consumer in seen_consumers:
            fail("ERR_SCHEMA_INVALID", "unknown or duplicate consumer execution", cell)
        seen_consumers.add(consumer)
        if entry["source_ref"] != CONSUMERS[consumer]:
            fail("ERR_SCHEMA_INVALID", "consumer source path mismatch", cell)
        source = safe_repo_file(root, entry["source_ref"], cell, prefix=None)
        if file_digest(source) != entry["source_sha256"]:
            fail("ERR_HASH_MISMATCH", "consumer source fingerprint mismatch", cell)
        if entry["observed_status"] != record["observed_status"]:
            fail(
                "ERR_CELL_RUNTIME_MISMATCH",
                "consumer outcome differs from its cell",
                cell,
            )
        nonce, session, event_id = (
            entry["nonce"],
            entry["host_session_id"],
            entry["host_event_id"],
        )
        if not isinstance(nonce, str) or not NONCE_RE.fullmatch(nonce) or nonce in seen_nonces:
            fail("ERR_NONCE_REUSED", "consumer nonce is invalid or reused", cell)
        seen_nonces.add(nonce)
        if not nonempty_string(session) or not nonempty_string(event_id) or (session, event_id) in seen_events:
            fail(
                "ERR_SCHEMA_INVALID",
                "consumer native event identity is invalid or reused",
                cell,
            )
        seen_events.add((session, event_id))
        if nonce == record["nonce"] and (session != record["host_session_id"] or event_id != record["host_event_id"]):
            fail(
                "ERR_NONCE_REUSED",
                "parent nonce belongs to another native dispatch",
                cell,
            )
        start = parse_utc(entry["session_start"], "consumer session_start", cell)
        end = parse_utc(entry["session_end"], "consumer session_end", cell)
        if end <= start:
            fail("ERR_SCHEMA_INVALID", "consumer session timestamps are unordered", cell)
        artifacts = {}
        for label in ("raw_tool_request", "raw_tool_result", "consumer_invocation"):
            relative = entry[label + "_ref"]
            if not canonical_relative(relative, "tests/hook-activation-live-proof/raw"):
                fail(
                    "ERR_SCHEMA_INVALID",
                    "consumer evidence path is not canonical",
                    cell,
                )
            path = safe_repo_file(root, relative, cell)
            if file_digest(path) != entry[label + "_sha256"]:
                fail("ERR_HASH_MISMATCH", "consumer capture hash mismatch", cell)
            detect_synthetic(path, cell)
            artifacts[label] = path
        if record["runtime"] == "codex":
            control = safe_repo_file(root, entry["hook_control_ref"], cell)
            if file_digest(control) != entry["hook_control_sha256"]:
                fail("ERR_HASH_MISMATCH", "consumer launch metadata hash mismatch", cell)
            events = [
                CANON.parse_json_bytes(line)
                for line in artifacts["consumer_invocation"].read_bytes().splitlines()
                if line.strip()
            ]
            if parse_hook_control(control, cell, events) != record["hooks_state"]:
                fail(
                    "ERR_FEATURE_CONFIG_MISMATCH",
                    "consumer launch selector differs from cell",
                    cell,
                )
        request = load_json(artifacts["raw_tool_request"], "native consumer request")
        result = load_json(artifacts["raw_tool_result"], "native consumer result")
        proposal = validate_nonce_binding(entry, ledger_by_nonce, cell)
        native_start, native_end, emitted, dispatched = validate_native_execution(
            entry,
            request,
            result,
            artifacts["consumer_invocation"],
            source,
            record["runtime"],
            cell,
        )
        if start != native_start or end != native_end:
            fail(
                "ERR_SCHEMA_INVALID",
                "signed session window differs from native timestamps",
                cell,
            )
        issued = parse_utc(proposal[0]["issued_at"], "issued_at", cell)
        if not emitted <= issued < dispatched:
            fail(
                "ERR_NONCE_ISSUED_AFTER_SESSION",
                "consumer nonce issuance is outside its native emit/dispatch window",
                cell,
            )
        if dispatched - issued > dt.timedelta(hours=24):
            fail('ERR_NONCE_EXPIRED', 'consumer nonce expired before native dispatch', cell)
        proposals.append(proposal)
    return proposals


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
            proposals.extend(validate_consumer_executions(record, root, ledger_by_nonce, cell))
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
