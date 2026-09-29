"""One synthetic closed-record fixture; all generated files stay in a caller temp root."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

FEATURE = "epic-197-a9-dogfood"
SOURCE = f"reports/spec-review/{FEATURE}/attempt-3/round-3"
PREVIOUS = f"reports/spec-review/{FEATURE}/attempt-3/round-2"
INVOCATION = f"reports/review-context/{FEATURE}-spec-a3r3-a-invocation.json"
RECORD = "reports/verification/a9-fixture-recovery.json"
AUTH = "reports/verification/a9-fixture-authorization.md"
CALIBRATION = "plugins/sdd-review-loop/references/spec-review-calibration.md"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def bash_functions(source):
    # These originals close each top-level function on an unindented brace.
    return "\n".join(re.findall(r"(?ms)^[a-zA-Z_][a-zA-Z_0-9]*\(\) \{(?:[^\n]*\}$|\n.*?^\})", source))


def build(root, original):
    root, original = Path(root), Path(original)
    assert root.is_dir() and not any(root.iterdir()), "fixture root must be empty"

    def put(path, data):
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data if isinstance(data, bytes) else data.encode())

    def put_json(path, value):
        put(path, canonical(value) + b"\n")

    def ref(path):
        return {"path": path, "sha256": digest((root / path).read_bytes())}

    spec = f"specs/{FEATURE}"
    put(f"{spec}/requirements.md", "# Synthetic requirements\nSpec-Review-Status: Pending\n")
    put(f"{spec}/acceptance-tests.md", "# Synthetic acceptance tests\nAC-001: observed fixture only.\n")
    put(f"{spec}/investigation.md", "# Synthetic investigation\nNo live recovery evidence.\n")
    put(CALIBRATION, (original / CALIBRATION).read_bytes())
    pins = sorted([ref(f"{spec}/{name}") for name in (
        "requirements.md", "acceptance-tests.md", "investigation.md")]+[ref(CALIBRATION)], key=lambda item: item["path"])
    hashes = {item["path"].split("/")[-1]: item["sha256"] for item in pins}

    def precheck(round_number):
        return {"schema": "spec-review-precheck/v1", "stage": "spec", "feature": FEATURE,
                "attempt": 3, "round": round_number, "spec_review_status_field": "Pending",
                "requirements_sha256": hashes["requirements.md"],
                "acceptance_sha256": hashes["acceptance-tests.md"],
                "investigation_sha256": hashes["investigation.md"],
                "calibration_sha256": hashes["spec-review-calibration.md"],
                "input_sha256": digest(":".join(hashes[name] for name in (
                    "requirements.md", "acceptance-tests.md", "investigation.md")).encode()),
                "edit_summary": "Synthetic fixture", "reset": False,
                "generated_at": "2026-09-29T00:00:00Z"}

    put_json(f"{PREVIOUS}/precheck-result.json", precheck(2))
    # Reuse the existing complete-round builder without executing its registry writes.
    helper_source = (original / "tests/spec-review-loop.tests.sh").read_text()
    helper = re.search(r"(?ms)^write_contract\(\) \{.*?^\}", helper_source).group()
    subprocess.run(["bash", "-c", "set -euo pipefail\n" + helper + '\nROOT=$1; FEATURE=$2; SPEC_DIR="$ROOT/specs/$FEATURE"\nwrite_contract "$ROOT/$3" NEEDS_WORK Major',
                    "fixture", str(root), FEATURE, PREVIOUS], check=True, capture_output=True)
    put_json(f"{SOURCE}/precheck-result.json", precheck(3))
    inputs = sorted(pins + [ref(f"{SOURCE}/precheck-result.json")], key=lambda item: item["path"])
    input_binding = digest("\n".join(f'{item["path"]}\t{item["sha256"]}' for item in inputs).encode())
    genesis_hash = digest(b"1|spec|spec-reviewer-a|fixture-a9-genesis|fixture-a9-genesis-session|")
    genesis = {"sequence": 1, "stage": "spec", "role": "spec-reviewer-a",
               "run_id": "fixture-a9-genesis", "host_session_id": "fixture-a9-genesis-session",
               "previous_record_sha256": "", "record_sha256": genesis_hash}
    ledger_path = "reports/review-context/identity-ledger.json"
    put_json(ledger_path, {"schema": "review-identity-ledger/v1", "records": [genesis]})
    historical_ledger_hash = ref(ledger_path)["sha256"]
    run, session = "fixture-a9-source-a", "fixture-a9-source-session-a"
    record_hash = digest(f"2|spec|spec-reviewer-a|{run}|{session}|{genesis_hash}|allowed-inputs-v1|{input_binding}".encode())
    identity = {"sequence": 2, "stage": "spec", "role": "spec-reviewer-a", "run_id": run,
                "host_session_id": session, "previous_record_sha256": genesis_hash,
                "record_sha256": record_hash, "allowed_inputs_sha256": input_binding}
    put_json(ledger_path, {"schema": "review-identity-ledger/v1", "records": [genesis, identity]})
    invocation = {"schema": "review-context-invocation/v2", "stage": "spec", "role": "spec-reviewer-a",
                  "feature": FEATURE, "run_id": run, "host_session_id": session, "read_only": True,
                  "input_mode": "file-manifest", "fallback_mode": "none", "sequence": 2,
                  "identity_ledger_path": ledger_path, "identity_ledger_sha256": historical_ledger_hash,
                  "previous_record_sha256": genesis_hash, "allowed_input_manifest": inputs}
    put_json(INVOCATION, invocation)
    a_ids = ["REQ-TESTABILITY", "GOAL-AC-TRACE", "AC-OBSERVABLE", "SCOPE-BOUNDARY",
             "CONSTRAINTS-EXPLICIT", "RISK-VALIDATION-SURFACE", "DOMAIN-CONFORMANCE"]
    put_json(f"{SOURCE}/reviewer-a.json", {"schema": "spec-reviewer-a/v1", "stage": "spec",
             "role": "spec-reviewer-a", "run_id": run, "host_session_id": session,
             "allowed_input_manifest": inputs, "verdict": "BLOCKED", "checks": [
                 {"id": name, "result": "FAIL", "severity": "Critical" if index == 0 else "Major",
                  "finding": "Review blocked before substantive reading: unreadable input prevented manifest hash verification."}
                 for index, name in enumerate(a_ids)]})
    put_json(f"{SOURCE}/reviewer-a-host-receipt.json", {"host": "Synthetic fixture host",
             "rpc": "thread/start", "threadId": session, "sessionId": session,
             "review_execution_started": False})
    put(f"{SOURCE}/reviewer-a-reservation.txt", f"REVIEW_CONTEXT_OK {record_hash} sequence=2 previous_record_sha256={genesis_hash} pre_append_tip_sequence=1 identity_unique=yes\n")
    put(f"{SOURCE}/spec-review-report.md", "# Synthetic interrupted review\nAttempt: 3\nRound: 3\nExecution: BLOCKED before substantive review\nReviewer A launch failure: unreadable input.\nReviewer B was not launched. No integrated verdict or complete review contract exists.\n")
    inventory = sorted([ref(f"{SOURCE}/{name}") for name in (
        "precheck-result.json", "reviewer-a.json", "reviewer-a-reservation.txt",
        "reviewer-a-host-receipt.json", "spec-review-report.md")] + [ref(INVOCATION)], key=lambda item: item["path"])
    record = {"schema": "spec-review-interrupted-recovery/v1", "feature": FEATURE,
              "source": {"attempt": 3, "round": 3}, "target": {"attempt": 4, "round": 1},
              "previous_contract": ref(f"{PREVIOUS}/spec-review-contract.json"),
              "interrupted_precheck": ref(f"{SOURCE}/precheck-result.json"), "pinned_inputs": pins,
              "interrupted_artifacts": inventory,
              "reviewer_a": {"invocation": ref(INVOCATION), "sequence": 2, "stage": "spec",
                             "role": "spec-reviewer-a", "run_id": run, "host_session_id": session,
                             "record_sha256": record_hash}}
    binding = digest(canonical(record))
    put(AUTH, f"Feature: {FEATURE}\nSource Attempt: 3\nSource Round: 3\nTarget Attempt: 4\nTarget Round: 1\nMaximum Rounds: 3\nDecision: Authorize interrupted A-before-B recovery\nRecovery Binding SHA256: {binding}\nSynthetic test input; no human-origin execution evidence.\n")
    record["authorization"] = ref(AUTH)
    put_json(RECORD, record)
    return record
