"""Remove specific bindings only in a disposable, hash-pinned source snapshot."""
from __future__ import annotations

import argparse
import ast
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any

BASE = Path("specs/cloud-orchestration/verification/T-013/preflight-repair")
EXECUTION = "plugins/sdd-aws-cloud/scripts/aws_execution.py"
NATIVE = "plugins/sdd-aws-cloud/scripts/aws_native.py"
CONTRACT = "plugins/sdd-quality-loop/scripts/cloud_contracts.py"
AUTH = "plugins/sdd-quality-loop/scripts/cloud_authorization.py"
CONTROL = "plugins/sdd-aws-cloud/scripts/aws_control.py"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def mutate(source: str, spec: dict) -> str:
    if "old" in spec:
        assert source.count(spec["old"]) == spec.get("count", 1), "mutation anchor count"
        return source.replace(spec["old"], spec["new"])
    lines = source.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    replacements = []
    for node in ast.walk(ast.parse(source)):
        if not isinstance(node, ast.Call) or len(node.args) < 2:
            continue
        if not isinstance(node.args[1], ast.Constant) or node.args[1].value != spec["guard"]:
            continue
        name = node.func.attr if isinstance(node.func, ast.Attribute) else getattr(node.func, "id", "")
        if name not in ("require", "_require"):
            continue
        condition = node.args[0]
        segment = ast.get_source_segment(source, condition)
        if "contains" in spec and spec["contains"] not in (segment or ""):
            continue
        assert condition.end_lineno is not None and condition.end_col_offset is not None
        replacements.append((offsets[condition.lineno - 1] + condition.col_offset,
                             offsets[condition.end_lineno - 1] + condition.end_col_offset))
    assert len(replacements) == spec.get("count", 1), (spec, replacements)
    for start, end in sorted(replacements, reverse=True):
        source = source[:start] + "True" + source[end:]
    return source


def specs() -> list[dict]:
    result = []
    def guard(name: str, path: str, code: str, case: str, marker: str = "MISMATCH_NOT_REJECTED", **kw: Any) -> None:
        result.append(dict(name=name, path=path, guard=code, case=case, marker=marker, **kw))
    def expression(name: str, path: str, old: str, new: str, case: str, marker: str) -> None:
        result.append(dict(name=name, path=path, old=old, new=new, case=case, marker=marker))

    guard("preview-binding", CONTRACT, "BINDING_MISMATCH", "R1.preview-run_id", contains="preview[key]")
    guard("file-digest", CONTRACT, "DIGEST_MISMATCH", "R1.bytes-config")
    guard("native-binding", EXECUTION, "CHANGE_SET_BINDING_MISMATCH", "R2.wire-ChangeSetName")
    guard("arn-scope", EXECUTION, "NATIVE_ID_MISMATCH", "R2.arn-direct-account")
    guard("template", EXECUTION, "TEMPLATE_SUBSTITUTION", "R2.template")
    guard("semantic-drift", EXECUTION, "PREVIEW_DRIFT", "R2.semantic-change", "SEMANTIC_DRIFT_ACCEPTED", contains="self.readback", count=2)
    guard("asset-readback", NATIVE, "S3_SUBSTITUTION", "R3.header-ETag")
    guard("asset-encryption", NATIVE, "S3_OBJECT_DENIED", "R3.header-x-amz-server-side-encryption")
    guard("asset-key", EXECUTION, "CREATE_REQUEST_MISMATCH", "R3.asset-key")
    guard("role-input", EXECUTION, "CREATE_REQUEST_MISMATCH", "R4.create-RoleARN")
    guard("failure-policy", NATIVE, "AWS_FAILURE_POLICY", "R4.DisableRollback")
    guard("stack-role", EXECUTION, "STACK_AUTHORITY_MISMATCH", "R4.stack-role")
    expression("event-token", EXECUTION, 'and e.get("ClientRequestToken") == self.token', 'and True',
               "R4.event-token", "WRONG_TOKEN_COMPLETION_ACCEPTED")
    guard("approval", AUTH, "APPROVAL_REQUIRED", "R5.approval")
    guard("lease", AUTH, "CREDENTIAL_EXPIRED", "R5.lease", contains="end > now")
    guard("principal", AUTH, "PROVIDER_PRINCIPAL_MISMATCH", "R5.principal", count=2)
    guard("receipt-stage", CONTRACT, "BINDING_MISMATCH", "R5.receipt-operation", contains="receipt['operation']")
    guard("receipt-expiry", CONTRACT, "EXPIRED_RECEIPT", "R5.receipt-expires_at")
    for name, old in [("Status", 'value["Status"] == "FAILED"'),
                      ("ExecutionStatus", 'value["ExecutionStatus"] == "UNAVAILABLE"'),
                      ("StatusReason", 'value.get("StatusReason") == NO_CHANGES'),
                      ("Changes", 'value.get("Changes", []) == []')]:
        expression("no-op-" + name, EXECUTION, old, "True", "R6.no-op-" + name, "MISMATCH_NOT_REJECTED")
    expression("no-op-native-id", CONTRACT,
               "_require(result != 'NO_CHANGE' or 'native_operation_id' not in value)",
               "_require(True)", "R6.fabricated-deployment", "MISMATCH_NOT_REJECTED")
    guard("journal-binding", EXECUTION, "RECOVERY_BINDING_MISMATCH", "R7.journal-status", "JOURNAL_MISMATCH_ACCEPTED")
    guard("journal-hash", EXECUTION, "INTENT_BYTES_MISMATCH", "R7.journal-body_sha256", "JOURNAL_MISMATCH_ACCEPTED")
    guard("journal-body", EXECUTION, "EXECUTE_INTENT_MISMATCH", "R7.journal-body.ClientRequestToken", "JOURNAL_MISMATCH_ACCEPTED")
    expression("journal-time", EXECUTION, 'epoch(op["created_at"])', 'None', "R7.journal-created_at", "JOURNAL_MISMATCH_ACCEPTED")
    guard("recovery-trusted-scope", EXECUTION, "TRUSTED_POLICY_BINDING_MISMATCH", "R8.trusted-deployment_scope", "TRUSTED_PIN_ACCEPTED")
    guard("recovery-trusted-unit", CONTROL, "UNIT_AUTHORITY_MISMATCH", "R8.trusted-unit_id", "UNTRUSTED_RECOVERY_READ")
    expression("response-digest", NATIVE, 'response_sha256=digest(response.body)', 'response_sha256=digest(b"")',
               "R9.observed-bindings", "TRACE_BINDING_MISMATCH:response_sha256")
    expression("health-flag", EXECUTION, 'health_verified=False', 'health_verified=True',
               "R9.observed-bindings", "HEALTH_FLAG_MISMATCH")
    expression("state", EXECUTION, '"PASS": "PREVIEW_READY" if phase == "prepare" else "OBSERVED"',
               '"PASS": "PREVIEW_READY" if phase == "prepare" else "VERIFIED"', "R9.observed-bindings", "STATE_MISMATCH")
    expression("exit", CONTRACT, "'UNKNOWN': 3}", "'UNKNOWN': 0}", "R9.result-mapping", "EXIT_MISMATCH:UNKNOWN")
    expression("receipt-principal-emission", AUTH, 'principal=principal,', 'principal="other-principal",',
               "R9.observed-bindings", "RECEIPT_PRINCIPAL_MISMATCH")
    expression("journal-hash-emission", EXECUTION, 'body_sha256=self.wire_hash(mutation, body)', 'body_sha256="0" * 64',
               "R9.observed-bindings", "JOURNAL_HASH_MISMATCH")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scratch", type=Path, required=True)
    parser.add_argument("--only")
    args = parser.parse_args()
    root = Path.cwd()
    manifest = json.loads((BASE / "task-input-manifest.json").read_text())
    snapshot = args.scratch / "snapshot"
    for ref in manifest["allowed_inputs"]:
        assert sha((snapshot / ref["path"]).read_bytes()) == ref["sha256"]
    tree = args.scratch / "mutation-tree"
    if tree.exists():
        shutil.rmtree(tree)
    shutil.copytree(snapshot, tree)
    evidence = BASE / "evidence/mutations-final"
    evidence.mkdir(exist_ok=True)
    records = []
    for spec in specs():
        if args.only and spec["name"] != args.only:
            continue
        path = tree / spec["path"]
        original = path.read_bytes()
        updated = mutate(original.decode(), spec).encode()
        patch_text = "".join(difflib.unified_diff(original.decode().splitlines(True), updated.decode().splitlines(True),
                                               fromfile=spec["path"], tofile=spec["path"]))
        patch_path = evidence / (spec["name"] + ".patch")
        patch_path.write_text(patch_text)
        prefix = evidence / spec["name"]
        command = [sys.executable, "-B", str(root / BASE / "probes.py"), "--root", str(tree),
                   "--case", spec["case"], "--output", str(root / (str(prefix) + ".json"))]
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        path.write_bytes(updated)
        try:
            run = subprocess.run(command, capture_output=True, text=True, check=False)
            Path(str(prefix) + ".log").write_text(run.stdout + run.stderr)
        finally:
            path.write_bytes(original)
        record = dict(name=spec["name"], timestamp=timestamp, path=spec["path"],
                      before_sha256=sha(original), mutant_sha256=sha(updated), restored_sha256=sha(path.read_bytes()),
                      patch=str(patch_path), patch_sha256=sha(patch_path.read_bytes()),
                      command=command, exit_code=run.returncode, expected_assertion=spec["marker"])
        probe_file = Path(str(prefix) + ".json")
        probes = json.loads(probe_file.read_text())["records"] if probe_file.exists() else []
        record["sensitive"] = bool(run.returncode == 1 and len(probes) == 1 and probes[0]["setup_complete"]
                                   and probes[0]["body_entered"] and probes[0].get("error_type") == "AssertionError"
                                   and spec["marker"] in probes[0].get("error", "")
                                   and record["restored_sha256"] == record["before_sha256"])
        records.append(record)
        print(spec["name"], "SENSITIVE" if record["sensitive"] else "NOT_ESTABLISHED", flush=True)
    summary = evidence / ("summary-" + args.only + ".json" if args.only else "summary.json")
    summary.write_text(json.dumps(records, indent=2) + "\n")
    return int(not all(r["sensitive"] for r in records))


if __name__ == "__main__":
    raise SystemExit(main())
