#!/usr/bin/env python3
"""Acceptance cases for the five-cell live-host proof validator."""

import base64
import copy
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
VALIDATOR = Path(
    os.environ.get(
        "LIVE_HOST_VALIDATOR",
        ROOT / "plugins/sdd-quality-loop/scripts/validate-live-host-proof.py",
    )
).resolve()

CELLS = {
    "Claude-active": ("claude", "not_applicable", "claude-hooks.json"),
    "Codex-enabled-active": ("codex", "enabled", "hooks.json"),
    "Codex-disabled-expected-unavailable": ("codex", "disabled", "hooks.json"),
    "Copilot-primary-active": ("copilot", "not_applicable", "copilot-hooks.json"),
    "Copilot-subagent-expected-unavailable": ("copilot", "not_applicable", "copilot-hooks.json"),
}
FILENAMES = {
    cell: cell.lower().replace("claude", "claude").replace("codex", "codex").replace("copilot", "copilot") + ".json"
    for cell in CELLS
}
ERRORS = {
    "ERR_MISSING_CELL",
    "ERR_SCHEMA_INVALID",
    "ERR_CELL_RUNTIME_MISMATCH",
    "ERR_FEATURE_CONFIG_MISMATCH",
    "ERR_NONCE_UNKNOWN",
    "ERR_NONCE_REUSED",
    "ERR_NONCE_CELL_MISMATCH",
    "ERR_NONCE_ISSUED_AFTER_SESSION",
    "ERR_NONCE_EXPIRED",
    "ERR_NONCE_DUPLICATE_LEDGER_ENTRY",
    "ERR_ISSUER_SIGNATURE_INVALID",
    "ERR_HASH_MISMATCH",
    "ERR_DIGEST_MISMATCH",
    "ERR_SIGNATURE_INVALID",
    "ERR_SIGNER_UNTRUSTED",
    "ERR_SIGNER_IDENTITY_MISMATCH",
    "ERR_SIGNER_KEY_COLLISION",
    "ERR_SYNTHETIC_SUBSTITUTION",
    "ERR_STALE_SKIP",
}

# RFC 8032 arithmetic. This test-only signer uses deterministic disposable
# seeds; no fixture key is trusted outside a temporary test repository.
Q = 2**255 - 19
L = 2**252 + 27742317777372353535851937790883648493
D = (-121665 * pow(121666, Q - 2, Q)) % Q
I = pow(2, (Q - 1) // 4, Q)


def inv(value):
    return pow(value, Q - 2, Q)


def recover_x(y):
    xx = (y * y - 1) * inv(D * y * y + 1) % Q
    x = pow(xx, (Q + 3) // 8, Q)
    if (x * x - xx) % Q:
        x = x * I % Q
    if x & 1:
        x = Q - x
    return x


BY = 4 * inv(5) % Q
BX = recover_x(BY)
B = (BX, BY, 1, BX * BY % Q)
IDENTITY = (0, 1, 1, 0)


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


def encode_point(point):
    x, y, z, _ = point
    zi = inv(z)
    x = x * zi % Q
    y = y * zi % Q
    return int.to_bytes(y | ((x & 1) << 255), 32, "little")


def keypair(seed_byte):
    seed = bytes([seed_byte]) * 32
    digest = hashlib.sha512(seed).digest()
    scalar = int.from_bytes(digest[:32], "little")
    scalar &= (1 << 254) - 8
    scalar |= 1 << 254
    return seed, encode_point(scalar_mult(B, scalar))


def sign(seed, public_key, message):
    digest = hashlib.sha512(seed).digest()
    scalar = int.from_bytes(digest[:32], "little")
    scalar &= (1 << 254) - 8
    scalar |= 1 << 254
    prefix = digest[32:]
    r = int.from_bytes(hashlib.sha512(prefix + message).digest(), "little") % L
    encoded_r = encode_point(scalar_mult(B, r))
    h = int.from_bytes(hashlib.sha512(encoded_r + public_key + message).digest(), "little") % L
    return encoded_r + int.to_bytes((r + h * scalar) % L, 32, "little")


KEYS = {
    "operator-key": keypair(17),
    "reviewer-key": keypair(23),
    "issuer-key": keypair(31),
    "outsider-key": keypair(47),
}


def jcs(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def record_target(record, role):
    unsigned = {k: v for k, v in record.items() if k not in {"operator_signature", "reviewer_signature"}}
    return hashlib.sha256(jcs(unsigned) + b":" + role.encode("ascii")).digest()


def sign_record(record):
    record["operator_signature"] = ""
    record["reviewer_signature"] = ""
    for role, key_id in (("operator", "operator-key"), ("reviewer", "reviewer-key")):
        seed, public_key = KEYS[key_id]
        record[role + "_signature"] = base64.b64encode(sign(seed, public_key, record_target(record, role))).decode("ascii")


def sign_ledger_entry(entry):
    unsigned = {k: v for k, v in entry.items() if k not in {"issuer_signature", "consumed_by_record"}}
    target = hashlib.sha256(jcs(unsigned) + b":nonce-issuer").digest()
    seed, public_key = KEYS["issuer-key"]
    entry["issuer_signature"] = base64.b64encode(sign(seed, public_key, target)).decode("ascii")


class Fixture:
    def __init__(self, base, verdicts=None):
        self.root = Path(base) / "repo"
        self.records = self.root / "tests/hook-activation-live-proof"
        self.raw = self.records / "raw"
        self.ledger = self.records / "nonce-ledger.json"
        self.manifest = self.root / "fixtures/expected.json"
        self.registry = self.root / "fixtures/trusted.json"
        self.allowlist = self.root / "fixtures/allowlist.json"
        self.records.mkdir(parents=True)
        self.raw.mkdir(parents=True)
        self._build(verdicts or {cell: "PASS" for cell in CELLS})

    def _build(self, verdicts):
        registry = {"schema": "a8-trusted-signers/v1", "signers": {}}
        for key_id, identity, role in (
            ("operator-key", "fixture-operator", "operator"),
            ("reviewer-key", "fixture-reviewer", "reviewer"),
            ("issuer-key", "fixture-issuer", "issuer"),
        ):
            registry["signers"][key_id] = {
                "identity": identity,
                "public_key": base64.b64encode(KEYS[key_id][1]).decode("ascii"),
                "role": role,
                "added_at": "2026-08-01T00:00:00Z",
            }
        write_json(self.registry, registry)
        allowlist = {
            "schema": "a8-skip-allowlist/v1",
            "entries": [{
                "case_id": "AC-015",
                "reason": "Epic A1 tracking issue #189",
                "upstream_epic_a1_commit": "1" * 40,
                "upstream_epic_a1_path_blob_ids": {
                    f"plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.{suffix}": "2" * 40
                    for suffix in ("py", "sh", "ps1")
                },
            }],
        }
        write_json(self.allowlist, allowlist)
        expected = {}
        ledger_entries = []
        for index, (cell, (runtime, flag, config_name)) in enumerate(CELLS.items(), start=1):
            config_bytes = ("fixture config " + config_name + "\n").encode("utf-8")
            config_ref = f"tests/hook-activation-live-proof/raw/{cell}-installed-config.json"
            (self.root / config_ref).write_bytes(config_bytes)
            expected[cell] = {
                "config_path": config_name,
                "expected_sha256": sha256_bytes(config_bytes),
            }
            verdict = verdicts[cell]
            if verdict == "SKIP":
                record = self._skip_record(cell, runtime)
            else:
                request_ref = f"tests/hook-activation-live-proof/raw/{cell}-request.json"
                result_ref = f"tests/hook-activation-live-proof/raw/{cell}-result.json"
                request_bytes = ("real host request " + cell + "\n").encode("utf-8")
                result_bytes = ("real host denial " + cell + "\n").encode("utf-8")
                (self.root / request_ref).write_bytes(request_bytes)
                (self.root / result_ref).write_bytes(result_bytes)
                feature_ref = None
                feature_digest = None
                if runtime == "codex":
                    feature_ref = f"tests/hook-activation-live-proof/raw/{cell}-feature-config.toml"
                    feature_bytes = ("plugin_hooks = " + ("true" if flag == "enabled" else "false") + "\n").encode("utf-8")
                    (self.root / feature_ref).write_bytes(feature_bytes)
                    feature_digest = sha256_bytes(feature_bytes)
                nonce = f"fixture_nonce_{index:02d}_abcdef"
                record = {
                    "schema": "live-host-verification-record/v1",
                    "matrix_cell": cell,
                    "runtime": runtime,
                    "check": "hook-activation-handshake",
                    "invocation_mode": "manual",
                    "nonce": nonce,
                    "host_session_id": f"session-{index}",
                    "host_event_id": f"event-{index}",
                    "raw_tool_request_ref": request_ref,
                    "raw_tool_request_sha256": sha256_bytes(request_bytes),
                    "raw_tool_result_ref": result_ref,
                    "raw_tool_result_sha256": sha256_bytes(result_bytes),
                    "installed_hook_config_ref": config_ref,
                    "installed_hook_config_digest": sha256_bytes(config_bytes),
                    "installed_feature_config_ref": feature_ref,
                    "installed_feature_config_digest": feature_digest,
                    "session_date": "2026-08-01",
                    "session_start": "2026-08-01T12:00:00Z",
                    "session_end": "2026-08-01T12:05:00Z",
                    "operator": "fixture-operator",
                    "operator_key_id": "operator-key",
                    "reviewer": "fixture-reviewer",
                    "reviewer_key_id": "reviewer-key",
                    "cli_name": runtime + "-cli",
                    "cli_version": "1.0.0",
                    "host_os": "fixture-os",
                    "plugin_hooks_flag": flag,
                    "tool_call_evidence": "independently reviewed real host capture",
                    "verdict": verdict,
                    "skip_reason": None,
                    "operator_signature": "",
                    "reviewer_signature": "",
                    "notes": None,
                }
                ledger_entry = {
                    "nonce": nonce,
                    "matrix_cell": cell,
                    "issued_at": "2026-08-01T11:55:00Z",
                    "issuer": "check-hook-activation-handshake",
                    "issuer_key_id": "issuer-key",
                    "issuer_signature": "",
                    "consumed_by_record": None,
                }
                sign_ledger_entry(ledger_entry)
                ledger_entries.append(ledger_entry)
            sign_record(record)
            write_json(self.record_path(cell), record)
        write_json(self.manifest, expected)
        write_json(self.ledger, {"schema": "live-host-nonce-ledger/v1", "entries": ledger_entries})

    def _skip_record(self, cell, runtime):
        return {
            "schema": "live-host-verification-record/v1",
            "matrix_cell": cell,
            "runtime": runtime,
            "check": "hook-activation-handshake",
            "invocation_mode": "manual",
            "nonce": None,
            "host_session_id": None,
            "host_event_id": None,
            "raw_tool_request_ref": None,
            "raw_tool_request_sha256": None,
            "raw_tool_result_ref": None,
            "raw_tool_result_sha256": None,
            "installed_hook_config_ref": None,
            "installed_hook_config_digest": None,
            "installed_feature_config_ref": None,
            "installed_feature_config_digest": None,
            "session_date": None,
            "session_start": None,
            "session_end": None,
            "operator": "fixture-operator",
            "operator_key_id": "operator-key",
            "reviewer": "fixture-reviewer",
            "reviewer_key_id": "reviewer-key",
            "cli_name": None,
            "cli_version": None,
            "host_os": None,
            "plugin_hooks_flag": "not_applicable",
            "tool_call_evidence": None,
            "verdict": "SKIP",
            "skip_reason": "AC-015: Epic A1 tracking issue #189",
            "operator_signature": "",
            "reviewer_signature": "",
            "notes": None,
        }

    def record_path(self, cell):
        return self.records / FILENAMES[cell]

    def load_record(self, cell="Claude-active"):
        return json.loads(self.record_path(cell).read_text(encoding="utf-8"))

    def save_record(self, record, resign=True):
        if resign:
            sign_record(record)
        write_json(self.record_path(record["matrix_cell"]), record)

    def load_ledger(self):
        return json.loads(self.ledger.read_text(encoding="utf-8"))

    def save_ledger(self, ledger, resign=False):
        if resign:
            for entry in ledger["entries"]:
                sign_ledger_entry(entry)
        write_json(self.ledger, ledger)


def validator_command(fixture):
    args = [
        "--records-dir", str(fixture.records),
        "--nonce-ledger", str(fixture.ledger),
        "--expected-digest-manifest", str(fixture.manifest),
        "--trusted-signers", str(fixture.registry),
        "--skip-allowlist", str(fixture.allowlist),
    ]
    if VALIDATOR.suffix == ".ps1":
        return ["pwsh", "-NoProfile", "-File", str(VALIDATOR), *args]
    if VALIDATOR.suffix == ".sh":
        return ["bash", str(VALIDATOR), *args]
    return [sys.executable, str(VALIDATOR), *args]


def invoke(fixture):
    return subprocess.run(validator_command(fixture), text=True, capture_output=True, check=False)


def with_fixture(action, verdicts=None):
    temp = tempfile.mkdtemp(prefix="live-host-proof-")
    try:
        fixture = Fixture(temp, verdicts)
        action(fixture)
        return invoke(fixture)
    finally:
        shutil.rmtree(temp)


def set_ledger_entry(fixture, field, value, resign=True):
    ledger = fixture.load_ledger()
    ledger["entries"][0][field] = value
    fixture.save_ledger(ledger, resign=resign)


def named_cases():
    cases = []

    cases.append(("ERR_MISSING_CELL", lambda f: f.record_path("Claude-active").unlink()))
    cases.append(("ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"unexpected": True}))))
    cases.append(("ERR_CELL_RUNTIME_MISMATCH", lambda f: _mutate_record(f, lambda r: r.update({"runtime": "copilot", "installed_feature_config_ref": None, "installed_feature_config_digest": None}))))
    cases.append(("ERR_FEATURE_CONFIG_MISMATCH", _feature_mismatch))
    cases.append(("ERR_NONCE_UNKNOWN", lambda f: _mutate_record(f, lambda r: r.update({"nonce": "unknown_nonce_abcdef"}))))
    cases.append(("ERR_NONCE_REUSED", lambda f: set_ledger_entry(f, "consumed_by_record", "tests/hook-activation-live-proof/other.json", resign=False)))
    cases.append(("ERR_NONCE_CELL_MISMATCH", lambda f: set_ledger_entry(f, "matrix_cell", "Copilot-primary-active", resign=True)))
    cases.append(("ERR_NONCE_ISSUED_AFTER_SESSION", lambda f: set_ledger_entry(f, "issued_at", "2026-08-01T12:01:00Z", resign=True)))
    cases.append(("ERR_NONCE_EXPIRED", lambda f: set_ledger_entry(f, "issued_at", "2026-07-30T00:00:00Z", resign=True)))
    cases.append(("ERR_NONCE_DUPLICATE_LEDGER_ENTRY", _duplicate_nonce))
    cases.append(("ERR_ISSUER_SIGNATURE_INVALID", lambda f: set_ledger_entry(f, "issuer_signature", base64.b64encode(b"x" * 64).decode("ascii"), resign=False)))
    cases.append(("ERR_HASH_MISMATCH", lambda f: _mutate_record(f, lambda r: r.update({"raw_tool_request_sha256": "sha256:" + "0" * 64}))))
    cases.append(("ERR_DIGEST_MISMATCH", _digest_mismatch))
    cases.append(("ERR_SIGNATURE_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"reviewer_signature": base64.b64encode(b"x" * 64).decode("ascii")}), resign=False)))
    cases.append(("ERR_SIGNER_UNTRUSTED", lambda f: _mutate_record(f, lambda r: r.update({"operator_key_id": "not-registered"}))))
    cases.append(("ERR_SIGNER_IDENTITY_MISMATCH", lambda f: _mutate_record(f, lambda r: r.update({"operator": "impostor"}))))
    cases.append(("ERR_SIGNER_KEY_COLLISION", _key_collision))
    cases.append(("ERR_SYNTHETIC_SUBSTITUTION", _synthetic_capture))
    cases.append(("ERR_STALE_SKIP", _stale_skip))
    return cases


def _mutate_record(fixture, mutate, resign=True):
    record = fixture.load_record()
    original_cell = record["matrix_cell"]
    mutate(record)
    if resign:
        sign_record(record)
    write_json(fixture.record_path(original_cell), record)


def _feature_mismatch(fixture):
    cell = "Codex-enabled-active"
    record = fixture.load_record(cell)
    path = fixture.root / record["installed_feature_config_ref"]
    path.write_text("plugin_hooks = false\n", encoding="utf-8")
    record["installed_feature_config_digest"] = sha256_bytes(path.read_bytes())
    fixture.save_record(record)


def _duplicate_nonce(fixture):
    ledger = fixture.load_ledger()
    ledger["entries"].append(copy.deepcopy(ledger["entries"][0]))
    fixture.save_ledger(ledger)


def _digest_mismatch(fixture):
    manifest = json.loads(fixture.manifest.read_text(encoding="utf-8"))
    manifest["Claude-active"]["expected_sha256"] = "sha256:" + "0" * 64
    write_json(fixture.manifest, manifest)


def _key_collision(fixture):
    registry = json.loads(fixture.registry.read_text(encoding="utf-8"))
    registry["signers"]["reviewer-key"]["public_key"] = registry["signers"]["operator-key"]["public_key"]
    write_json(fixture.registry, registry)


def _synthetic_capture(fixture):
    record = fixture.load_record()
    source = ROOT / "tests/fixtures/live-host-proof/known-synthetic-request.json"
    target = fixture.root / record["raw_tool_request_ref"]
    target.write_bytes(source.read_bytes())
    record["raw_tool_request_sha256"] = sha256_bytes(target.read_bytes())
    fixture.save_record(record)


def _stale_skip(fixture):
    allowlist = json.loads(fixture.allowlist.read_text(encoding="utf-8"))
    for relative in allowlist["entries"][0]["upstream_epic_a1_path_blob_ids"]:
        activation = fixture.root / relative
        activation.parent.mkdir(parents=True, exist_ok=True)
        activation.write_text("# activated fixture\n", encoding="utf-8")


def _configure_ac006(fixture, task_status):
    """Model AC-006's task-state + handshake-files activation predicate."""
    handshake_paths = {
        f"plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.{suffix}": "2" * 40
        for suffix in ("py", "sh", "ps1")
    }
    # A non-handshake A1 consumer is deliberately absent. AC-006 must not wait
    # for AC-016's separate five-consumer activation surface.
    activation_paths = {
        **handshake_paths,
        "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md": "3" * 40,
    }
    allowlist = json.loads(fixture.allowlist.read_text(encoding="utf-8"))
    allowlist["entries"][0].update({
        "case_id": "AC-006",
        "upstream_epic_a1_path_blob_ids": activation_paths,
    })
    write_json(fixture.allowlist, allowlist)
    for cell in CELLS:
        record = fixture.load_record(cell)
        record["skip_reason"] = "AC-006: Epic A1 tracking issue #189"
        fixture.save_record(record)
    for relative in handshake_paths:
        path = fixture.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("# activated handshake fixture\n", encoding="utf-8")
    tasks = fixture.root / "specs/epic-196-a8-integration/tasks.md"
    tasks.parent.mkdir(parents=True, exist_ok=True)
    tasks.write_text(
        "## T-005 Author validator\n\n"
        "Approval: Approved (fixture)\n\n"
        f"Status: {task_status}\n\n"
        "## T-006 Later task\n\nStatus: Planned\n",
        encoding="utf-8",
    )


def special_cases():
    cases = [
        ("missing-reviewer-signature", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.pop("reviewer_signature"), resign=False)),
        ("role-domain-separation", "ERR_SIGNATURE_INVALID", _replay_operator_signature),
        ("malformed-public-key", "ERR_SCHEMA_INVALID", _malformed_public_key),
        ("unused-signer-malformed-public-key", "ERR_SCHEMA_INVALID", _unused_malformed_public_key),
        ("manifest-config-path-traversal", "ERR_SCHEMA_INVALID", _manifest_path_traversal),
        ("malformed-signature", "ERR_SIGNATURE_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"reviewer_signature": "not-base64"}), resign=False)),
        ("automated-claim-for-manual-check", "ERR_SYNTHETIC_SUBSTITUTION", lambda f: _mutate_record(f, lambda r: r.update({"invocation_mode": "automated"}))),
        ("fail-verdict-hard-failure", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"verdict": "FAIL"}))),
        ("skip-allowlist-substring-not-citation", "ERR_STALE_SKIP", _skip_bad_citation),
    ]
    for key in sorted({
        "schema", "matrix_cell", "runtime", "check", "invocation_mode",
        "nonce", "host_session_id", "host_event_id", "raw_tool_request_ref",
        "raw_tool_request_sha256", "raw_tool_result_ref", "raw_tool_result_sha256",
        "installed_hook_config_ref", "installed_hook_config_digest",
        "installed_feature_config_ref", "installed_feature_config_digest",
        "session_date", "session_start", "session_end", "operator",
        "operator_key_id", "reviewer", "reviewer_key_id", "cli_name",
        "cli_version", "host_os", "plugin_hooks_flag", "tool_call_evidence",
        "verdict", "skip_reason", "operator_signature", "reviewer_signature",
    }):
        cases.append((
            "missing-required-field-" + key,
            "ERR_SCHEMA_INVALID",
            lambda f, field=key: _mutate_record(f, lambda r: r.pop(field), resign=False),
        ))
    cases.extend([
        ("schema-const", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"schema": "wrong/v1"}))),
        ("matrix-cell-enum", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"matrix_cell": "Unknown-cell"}))),
        ("runtime-enum", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"runtime": "other"}))),
        ("check-nonempty", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"check": " "}))),
        ("invocation-mode-enum", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"invocation_mode": "interactive"}))),
        ("nonce-format", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"nonce": "short"}))),
        ("host-identifiers-nonempty", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"host_event_id": ""}))),
        ("canonical-evidence-path", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"raw_tool_request_ref": "tests/hook-activation-live-proof/raw/../escape"}))),
        ("digest-format", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"raw_tool_result_sha256": "SHA256:" + "A" * 64}))),
        ("session-date-format", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"session_date": "2026-8-1"}))),
        ("session-order", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"session_end": r["session_start"]}))),
        ("identity-nonempty", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"operator": ""}))),
        ("cli-fields-nonempty", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"cli_version": ""}))),
        ("plugin-hooks-enum", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"plugin_hooks_flag": "Enabled"}))),
        ("verdict-enum", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"verdict": "pass"}))),
        ("skip-reason-null-on-pass", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"skip_reason": "AC-015"}))),
        ("notes-type", "ERR_SCHEMA_INVALID", lambda f: _mutate_record(f, lambda r: r.update({"notes": 7}))),
        ("non-codex-feature-config-null", "ERR_SCHEMA_INVALID", _noncodex_feature_config),
        ("skip-carries-session-evidence", "ERR_SCHEMA_INVALID", _skip_carries_evidence),
        ("skip-needs-reason", "ERR_SCHEMA_INVALID", _skip_missing_reason),
    ])
    return cases


def _noncodex_feature_config(fixture):
    record = fixture.load_record()
    record["installed_feature_config_ref"] = record["raw_tool_request_ref"]
    record["installed_feature_config_digest"] = record["raw_tool_request_sha256"]
    fixture.save_record(record)


def _skip_carries_evidence(fixture):
    record = fixture._skip_record("Claude-active", "claude")
    record["nonce"] = "fixture_nonce_skip_abcdef"
    fixture.save_record(record)


def _skip_missing_reason(fixture):
    record = fixture._skip_record("Claude-active", "claude")
    record["skip_reason"] = None
    fixture.save_record(record)


def _replay_operator_signature(fixture):
    record = fixture.load_record()
    record["reviewer_signature"] = record["operator_signature"]
    fixture.save_record(record, resign=False)


def _malformed_public_key(fixture):
    registry = json.loads(fixture.registry.read_text(encoding="utf-8"))
    registry["signers"]["reviewer-key"]["public_key"] = base64.b64encode(b"short").decode("ascii")
    write_json(fixture.registry, registry)


def _unused_malformed_public_key(fixture):
    registry = json.loads(fixture.registry.read_text(encoding="utf-8"))
    registry["signers"]["unused-key"] = {
        "identity": "unused-fixture-signer",
        "public_key": base64.b64encode(b"short").decode("ascii"),
        "role": "reviewer",
        "added_at": "2026-08-01T00:00:00Z",
    }
    write_json(fixture.registry, registry)


def _manifest_path_traversal(fixture):
    manifest = json.loads(fixture.manifest.read_text(encoding="utf-8"))
    manifest["Claude-active"]["config_path"] = "../claude-hooks.json"
    write_json(fixture.manifest, manifest)


def _skip_bad_citation(fixture):
    record = fixture._skip_record("Claude-active", "claude")
    record["skip_reason"] = "XAC-015X: looks similar but is not an exact case citation"
    fixture.save_record(record)


def crypto_known_answer_case():
    spec = importlib.util.spec_from_file_location(
        "live_host_validator",
        ROOT / "plugins/sdd-quality-loop/scripts/validate-live-host-proof.py",
    )
    if spec is None or spec.loader is None:
        return False, "validator module could not be loaded"
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    public_key = bytes.fromhex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
    signature = bytes.fromhex(
        "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
        "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
    )
    malleable = signature[:32] + L.to_bytes(32, "little")
    small_order_key = b"\x01" + b"\x00" * 31
    order_two = (0, Q - 1, 1, 0)
    mixed_order_key = encode_point(point_add(B, order_two))
    ok = (
        module.verify_ed25519(public_key, signature, b"")
        and not module.verify_ed25519(public_key, malleable, b"")
        and not module.verify_ed25519(small_order_key, signature, b"")
        and module.decode_point(mixed_order_key) is None
    )
    return ok, "RFC 8032 test vector 1 plus S>=L, small-order, and mixed-order negative vectors"


def load_validator_module():
    spec = importlib.util.spec_from_file_location(
        "live_host_validator_transaction",
        ROOT / "plugins/sdd-quality-loop/scripts/validate-live-host-proof.py",
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("validator module could not be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_failure_case(name, expected, mutation, verdicts=None):
    result = with_fixture(lambda fixture: mutation(fixture), verdicts)
    ok = result.returncode != 0 and expected in result.stderr
    detail = f"exit={result.returncode} stderr={result.stderr.strip()!r} stdout={result.stdout.strip()!r}"
    return ok, detail


def run_success_case(name, expected_state, verdicts):
    result = with_fixture(lambda fixture: None, verdicts)
    ok = result.returncode == 0 and result.stdout.strip() == expected_state and not result.stderr.strip()
    detail = f"exit={result.returncode} stderr={result.stderr.strip()!r} stdout={result.stdout.strip()!r}"
    return ok, detail


def transaction_cases():
    results = []
    temp = tempfile.mkdtemp(prefix="live-host-proof-transaction-")
    try:
        fixture = Fixture(temp)
        before = fixture.ledger.read_bytes()
        _digest_mismatch(fixture)
        result = invoke(fixture)
        results.append(("atomic-all-or-none", result.returncode != 0 and fixture.ledger.read_bytes() == before, f"exit={result.returncode}"))
    finally:
        shutil.rmtree(temp)

    temp = tempfile.mkdtemp(prefix="live-host-proof-idempotent-")
    try:
        fixture = Fixture(temp)
        mode_before = fixture.ledger.stat().st_mode & 0o777
        first = invoke(fixture)
        after_first = fixture.ledger.read_bytes()
        mode_after_first = fixture.ledger.stat().st_mode & 0o777
        second = invoke(fixture)
        mode_after_second = fixture.ledger.stat().st_mode & 0o777
        results.append((
            "idempotent-repeat",
            first.returncode == 0
            and second.returncode == 0
            and after_first == fixture.ledger.read_bytes()
            and mode_before == mode_after_first == mode_after_second,
            f"first={first.returncode} second={second.returncode} modes={mode_before:o}/{mode_after_first:o}/{mode_after_second:o}",
        ))
    finally:
        shutil.rmtree(temp)

    temp = tempfile.mkdtemp(prefix="live-host-proof-lock-")
    try:
        fixture = Fixture(temp)
        before = fixture.ledger.read_bytes()
        Path(str(fixture.ledger) + ".lock").mkdir()
        result = invoke(fixture)
        results.append(("lock-contention", result.returncode != 0 and fixture.ledger.read_bytes() == before and "ERR_SCHEMA_INVALID" in result.stderr, f"exit={result.returncode} stderr={result.stderr.strip()!r}"))
    finally:
        shutil.rmtree(temp)

    temp = tempfile.mkdtemp(prefix="live-host-proof-lock-release-")
    try:
        fixture = Fixture(temp)
        module = load_validator_module()
        ledger = fixture.load_ledger()
        original = fixture.ledger.read_bytes()
        proposals = [
            (entry, f"tests/hook-activation-live-proof/{FILENAMES[entry['matrix_cell']]}")
            for entry in ledger["entries"]
        ]
        raised = None
        with mock.patch.object(Path, "rmdir", side_effect=OSError("fixture lock release failure")):
            try:
                module.publish_consumption(fixture.ledger, ledger, proposals, original)
            except module.ValidationError as exc:
                raised = exc
        results.append((
            "lock-release-failure-is-not-silent",
            raised is not None and raised.code == "ERR_SCHEMA_INVALID",
            f"raised={getattr(raised, 'code', None)!r}",
        ))
    finally:
        shutil.rmtree(temp)
    return results


def wrapper_convention_case():
    script_dir = ROOT / "plugins/sdd-quality-loop/scripts"
    shell = (script_dir / "validate-live-host-proof.sh").read_text(encoding="utf-8")
    powershell = (script_dir / "validate-live-host-proof.ps1").read_text(encoding="utf-8")
    ok = (
        "lib/py-dispatch.sh" in shell
        and "sdd_py_dispatch" in shell
        and "lib/py-dispatch.ps1" in powershell
        and "Invoke-SddPyDispatch" in powershell
        and "& $python.Source" not in powershell
    )
    return ok, "thin wrappers must use the repository's byte-preserving shared dispatchers"


def main():
    descriptor = json.loads((ROOT / "tests/fixtures/live-host-proof/cases.json").read_text(encoding="utf-8"))
    if set(descriptor["named_error_cases"]) != ERRORS:
        print("not ok - fixture descriptor does not cover the exact named error set")
        return 1
    fixture_cases = {
        path.stem: json.loads(path.read_text(encoding="utf-8"))["expected_error"]
        for path in (ROOT / "tests/fixtures/live-host-proof/cases").glob("ERR_*.json")
    }
    if set(fixture_cases) != ERRORS or any(name != value for name, value in fixture_cases.items()):
        print("not ok - fixture tree needs exactly one descriptor per named error")
        return 1

    results = []
    for expected, mutation in named_cases():
        ok, detail = run_failure_case(expected, expected, mutation, {cell: "SKIP" for cell in CELLS} if expected == "ERR_STALE_SKIP" else None)
        results.append((expected, ok, detail))
    for name, expected, mutation in special_cases():
        ok, detail = run_failure_case(name, expected, mutation)
        results.append((name, ok, detail))

    all_skip = {cell: "SKIP" for cell in CELLS}
    mixed = {cell: ("SKIP" if index == 0 else "PASS") for index, cell in enumerate(CELLS)}
    for name, state, verdicts in (
        ("all-five-pass-discharged", "discharged", None),
        ("valid-premerge-skip-pending", "pending", all_skip),
        ("mixed-pass-skip-pending", "pending", mixed),
    ):
        ok, detail = run_success_case(name, state, verdicts)
        results.append((name, ok, detail))
    result = with_fixture(lambda fixture: _configure_ac006(fixture, "Planned"), all_skip)
    results.append((
        "ac006-planned-remains-pending",
        result.returncode == 0 and result.stdout.strip() == "pending",
        f"exit={result.returncode} stderr={result.stderr.strip()!r} stdout={result.stdout.strip()!r}",
    ))
    ok, detail = run_failure_case(
        "ac006-started-is-stale",
        "ERR_STALE_SKIP",
        lambda fixture: _configure_ac006(fixture, "In Progress"),
        all_skip,
    )
    results.append(("ac006-started-is-stale", ok, detail))
    results.extend(transaction_cases())
    crypto_ok, crypto_detail = crypto_known_answer_case()
    results.append(("rfc8032-known-answer-and-strict-negatives", crypto_ok, crypto_detail))
    wrapper_ok, wrapper_detail = wrapper_convention_case()
    results.append(("shared-byte-preserving-wrapper-dispatch", wrapper_ok, wrapper_detail))

    passed = 0
    for name, ok, detail in results:
        if ok:
            passed += 1
            print(f"ok - {name}")
        else:
            print(f"not ok - {name}: {detail}")
    failed = len(results) - passed
    print(f"live-host-proof: {passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
