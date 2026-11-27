"""Exercise the distributed Core lifecycle CLI and read-only audit using a scratch project."""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts/v2"
FEATURE = "lifecycle"
TASK = "T-001"


def invoke(root, command, expected=0, data=None):
    result = subprocess.run(command, cwd=root, input=data, capture_output=True, text=True, timeout=45)
    if result.returncode != expected:
        raise AssertionError(f"{command} returned {result.returncode}, expected {expected}\n"
                             f"{result.stdout}\n{result.stderr}")
    return result.stdout


def write_task(root, approval="Approved", status="Implementation Complete"):
    (root / "specs" / FEATURE / "tasks.md").write_text(
        f"## {TASK} Check lifecycle\nApproval: {approval}\nStatus: {status}\nRisk: low\n",
        encoding="utf-8")


def gate(root, passes):
    evidence = root / "reports/quality-gate" / f"{FEATURE}-{TASK}.execution.json"
    evidence.unlink(missing_ok=True)
    invoke(root, ["node", str(SCRIPTS / "run-sdd-gate.mjs"), "--root", str(root),
                  "--feature", FEATURE, "--task", TASK, "--cmd", "test=node --version"],
           expected=0 if passes else 1)
    report = json.loads(evidence.read_text(encoding="utf-8"))
    assert report["feature"] == FEATURE and report["taskId"] == TASK
    assert (report["verdict"] == "PASS") == passes, report
    return report


def audit(root):
    requests = [
        {"id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05",
         "capabilities": {}, "clientInfo": {"name": "lifecycle-fixture", "version": "1"}}},
        {"id": 2, "method": "tools/call", "params": {"name": "sdd_gate_audit",
         "arguments": {"feature": FEATURE, "taskId": TASK}}},
    ]
    data = "".join(json.dumps({"jsonrpc": "2.0", **request}) + "\n" for request in requests)
    output = invoke(root, ["node", str(ROOT / "mcp/sdd-forge-mcp/dist/index.js"), "--root", str(root)], data=data)
    response = next(row for row in map(json.loads, output.splitlines()) if row.get("id") == 2)
    return json.loads(response["result"]["content"][0]["text"])["data"]["tasks"][0]


def templates(root):
    tickets = root / "docs/review-tickets"
    tickets.mkdir(parents=True)
    for severity, blocking in [("critical", True), ("major", True), ("minor", False)]:
        (tickets / "case.yml").write_text(
            f"ticket_id: RT-fixture\nstatus: open\nseverity: {severity}\ntarget:\n"
            f"  feature: {FEATURE}\n  task: {TASK}\n", encoding="utf-8")
        report = gate(root, not blocking)
        check = report["checks"]["reviewTickets"]
        expected = [{"ticketId": "RT-fixture", "severity": severity, "status": "open"}] if blocking else []
        assert check == {"passed": not blocking, "blocking": expected}, check
    assert report["coverage"]["complete"]
    gate_report = root / "reports/quality-gate" / f"{FEATURE}-{TASK}.md"
    original = (ROOT / "plugins/sdd-quality-loop/templates/sdd-gate-report.md").read_text(encoding="utf-8")
    assert original.count("- **VERDICT**: FAIL") == 1
    for verdict, ready in [("FAIL", False), ("PASS", True)]:
        gate_report.write_text(original.replace("- **VERDICT**: FAIL", f"- **VERDICT**: {verdict}"), encoding="utf-8")
        record = audit(root)
        assert record["reviewReport"]["verdict"] == verdict and record["readyForDone"] is ready, record
    gate_report.rename(gate_report.with_name(f"{FEATURE}-T-002.md"))
    record = audit(root)
    assert not record["reviewReport"]["exists"] and not record["readyForDone"], record
    print("Core gate blocked critical/major and accepted minor. Only the target PASS report enabled Done readiness.")


def workflow(root):
    clean = gate(root, True)
    assert clean["checks"]["specDrift"]["status"] == "CLEAN"
    requirements = root / "specs" / FEATURE / "requirements.md"
    requirements.write_text("# Requirements\n- AC-001: Revised acceptance criterion.\n", encoding="utf-8")
    changed = gate(root, False)
    drift = changed["checks"]["specDrift"]
    assert drift["status"] == "UNDECLARED_DRIFT" and not drift["passed"], drift
    assert any(row["id"] == "AC-001" for row in drift["modifiedIdentifiers"]), drift
    print("Core gate accepted the target baseline and rejected its unrecorded AC-001 change.")


def lifecycle(root):
    for status in ["Planned", "In Progress", "Blocked", "Implementation Complete", "Done", "Unknown", "done"]:
        write_task(root, status=status)
        ready = status in ("Implementation Complete", "Done")
        record = gate(root, ready)["checks"]["taskPrecondition"]
        assert record["status"] == status and record["passed"] is ready, record
    print("Core lifecycle precondition exercised all five statuses, unknown and mis-cased Done.")


def approvals(root):
    for value, approved in [("Draft", False), ("Approved", True),
                            ("Approved (alice 2026-08-22T01:02:03Z)", True),
                            ("Approved (owner confirmed)", True), ("Approved ()", True),
                            ("approved", False), ("APPROVED", False), ("ApProVeD", False),
                            ("approved (owner)", False), ("Approved later", False),
                            ("Approved (nested (note))", False)]:
        write_task(root, value)
        record = gate(root, approved)["checks"]["taskPrecondition"]
        assert record["approval"] == value and record["passed"] is approved, record
    print("Core gate distinguished exact Approved and a single annotation from malformed approval values.")


def main():
    action = {"templates": templates, "lifecycle": lifecycle, "approvals": approvals, "workflow": workflow}[sys.argv[1]]
    with tempfile.TemporaryDirectory(prefix="core lifecycle [fixture] ") as temporary:
        root = Path(temporary).resolve()
        spec = root / "specs" / FEATURE
        spec.mkdir(parents=True)
        (root / "AGENTS.md").write_text(f"## Active Spec Directories\n- `specs/{FEATURE}/`\n", encoding="utf-8")
        (spec / "requirements.md").write_text("# Requirements\n- AC-001: Check lifecycle.\n", encoding="utf-8")
        (spec / "design.md").write_text("# Design\nLifecycle verification.\n", encoding="utf-8")
        write_task(root)
        invoke(root, ["git", "init", "-q"])
        invoke(root, ["git", "add", "."])
        invoke(root, ["git", "-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid",
                      "commit", "-qm", "fixture baseline"])
        invoke(root, ["node", str(SCRIPTS / "record-spec-baseline.mjs"), "--root", str(root), "--feature", FEATURE])
        action(root)


if __name__ == "__main__":
    main()
