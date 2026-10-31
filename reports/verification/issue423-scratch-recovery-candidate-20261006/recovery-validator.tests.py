"""Exercise real candidate validators in disposable repositories only."""
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
APPLIED_ORIGINALS = sys.argv[1:] == ["--applied-originals"]
if sys.argv[1:] and not APPLIED_ORIGINALS:
    raise SystemExit("usage: recovery-validator.tests.py [--applied-originals]")
VALIDATOR_SH = (REPO / "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
                if APPLIED_ORIGINALS else HERE / "validator-bash.candidate.txt")
VALIDATOR_PS1 = (REPO / "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
                 if APPLIED_ORIGINALS else HERE / "validator-pwsh.candidate.txt")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def put(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value))


def exercise(runtime, case):
    with tempfile.TemporaryDirectory(prefix="sdd-recovery-validator-") as directory:
        root = pathlib.Path(directory).resolve()
        ledger = root / "reports/review-context/identity-ledger.json"
        first = dict(sequence=1, stage="implementation", role="implementer", run_id="impl",
                     host_session_id="impl-session", previous_record_sha256="")
        first["record_sha256"] = hashlib.sha256(b"1|implementation|implementer|impl|impl-session|").hexdigest()
        put(ledger, dict(schema="review-identity-ledger/v1", records=[first]))
        impl = root / "handoffs/fixture/manifest.json"
        put(impl, dict(schema="task-input-manifest/v1", task_id="T-001", run_id="worker", session_id="worker-session"))
        report = root / "reports/implementation/f/T-001.md"
        report.parent.mkdir(parents=True)
        report.write_text("# Implementation Report: T-001\n- Task ID: T-001\nRun ID: worker\n- **Run ID**: worker\n- **Session ID**: worker-session\n"
                          "- **Scratch Root**: /tmp/unrelated-worker\n"
                          f"Input manifest: `handoffs/fixture/manifest.json`, SHA-256 `{sha(impl)}`\n")
        old = report.with_name("T-002.md")
        raw = "old/scratch/"
        if case == "traversal": raw = "../scratch/"
        if case == "dot": raw = "old/./scratch/"
        if case == "empty-component": raw = "old//scratch/"
        if case == "backslash": raw = "old\\scratch"
        old.write_text(f"Run ID: historical\nTask Attempt Count: 2\n- **Session ID**: old-session\n- **Scratch Root**: {raw}\n")
        observation = root / "evidence/owner.json"
        put(observation, dict(owner=str(root), run="historical", report_sha256=sha(old)))
        receipt = old.with_suffix(".scratch-owner.json")
        value = dict(report=str(old), report_sha256=sha(old), raw_root=raw, run="historical",
                     session="old-session", attempt=2, owner=str(root), owner_observation=str(observation),
                     owner_observation_sha256=sha(observation))
        if case == "wrong-run": value["run"] = "different"
        if case == "wrong-session": value["session"] = "different"
        if case == "wrong-attempt": value["attempt"] = 3
        if case == "bool-attempt": value["attempt"] = True
        if case == "wrong-raw": value["raw_root"] = "other"
        if case == "extra-key": value["extra"] = 1
        if case == "bad-report-hash": value["report_sha256"] = "0" * 64
        if case == "bad-owner-hash": value["owner_observation_sha256"] = "0" * 64
        if case == "owner-conflict": put(observation, dict(owner=str(root), run="other", report_sha256=sha(old))); value["owner_observation_sha256"] = sha(observation)
        if case == "other-owner":
            value["owner"] = str(root.parent)
            put(observation, dict(owner=str(root.parent), run="historical", report_sha256=sha(old)))
            value["owner_observation_sha256"] = sha(observation)
        if case == "symlink-escape":
            (root / "old").symlink_to(root.parent, target_is_directory=True)
        put(receipt, value)
        if case == "duplicate-key": receipt.write_text(receipt.read_text()[:-1] + ',"run":"historical"}')
        declaration = root / "reports/quality-gate/fixture.md"
        declared = [old, receipt, observation]
        if case == "undeclared-receipt": declared.remove(receipt)
        if case == "undeclared-report": declared.remove(old)
        if case == "undeclared-observation": declared.remove(observation)
        declaration.parent.mkdir(parents=True)
        declaration.write_text("# Fixture gate declaration\n\n## Post-Fix Artifacts\n\n" + "\n".join(
            f"| `{p.relative_to(root)}` | `{('0' * 64) if case == 'wrong-declared-hash' and p == receipt else sha(p)}` |"
            for p in declared) + "\n")
        files = [report, impl, old, receipt, observation]
        scratch = str(root / "evaluator")
        if case == "equal": scratch = str(root / "old/scratch")
        if case == "parent": scratch = str(root / "old")
        if case == "child": scratch = str(root / "old/scratch/child")
        if case == "prefix": scratch = str(root / "old/scratch-more")
        invocation = dict(schema="review-context-invocation/v2", input_mode="file-manifest", fallback_mode="none",
                          read_only=True, stage="quality", role="sdd-evaluator", feature="f", task_id="T-001",
                          run_id="next", host_session_id="next-session", sequence=2, previous_record_sha256=first["record_sha256"],
                          identity_ledger_path=str(ledger.relative_to(root)), identity_ledger_sha256=sha(ledger),
                          scratch_root=scratch, implementation_manifest=dict(path=str(impl.relative_to(root)), sha256=sha(impl)),
                          gate_report_declaration=dict(path=str(declaration.relative_to(root)), sha256=sha(declaration)),
                          allowed_input_manifest=[dict(path=str(p.relative_to(root)), sha256=sha(p)) for p in files])
        if case == "missing-declaration": del invocation["gate_report_declaration"]
        manifest = root / "invocation.json"
        put(manifest, invocation)
        if case == "mutated-declaration": declaration.write_text(declaration.read_text() + "changed\n")
        if case == "missing-receipt": receipt.unlink()
        if case == "mutated-receipt": receipt.write_text(receipt.read_text() + " ")
        if case == "mutated-report": old.write_text(old.read_text() + "changed\n")
        if case == "mutated-observation": observation.write_text(observation.read_text() + " ")
        command = (["bash", str(VALIDATOR_SH), str(manifest), str(root), "--reserve"]
                   if runtime == "bash" else ["pwsh", "-NoProfile", "-File", str(VALIDATOR_PS1),
                                               "-Manifest", str(manifest), "-RepositoryRoot", str(root), "-Reserve"])
        # PowerShell requires a .ps1 file extension; copy bytes into the fixture.
        if runtime == "pwsh" and not APPLIED_ORIGINALS:
            script = root / "validator.ps1"
            script.write_bytes(VALIDATOR_PS1.read_bytes())
            command[3] = str(script)
        before = ledger.read_bytes()
        result = subprocess.run(command, capture_output=True, text=True, timeout=45)
        expected = 0 if case in ("valid", "prefix") else 1
        admission_case = case in ("undeclared-receipt", "undeclared-report", "undeclared-observation",
                                  "missing-declaration", "wrong-declared-hash")
        passed = result.returncode == expected and (not expected or
                  (ledger.read_bytes() == before and "REVIEW_CONTEXT_CONTRACT" not in result.stderr and
                   ("role-unlisted" in result.stderr if admission_case else "role-unlisted" not in result.stderr) and
                   ("REVIEW_CONTEXT_PATH" in result.stderr or "REVIEW_CONTEXT_HASH" in result.stderr)))
        print(f"{'ok' if passed else 'not ok'}: {runtime} {case}: exit={result.returncode}, expected={expected}", flush=True)
        if not passed: print(result.stdout, result.stderr, flush=True)
        return passed


cases = ["valid", "prefix", "equal", "parent", "child", "traversal", "dot", "empty-component", "backslash",
         "wrong-run", "wrong-session", "wrong-attempt", "bool-attempt", "wrong-raw", "extra-key",
         "bad-report-hash", "bad-owner-hash", "owner-conflict", "other-owner", "symlink-escape", "duplicate-key",
         "undeclared-receipt", "undeclared-report", "undeclared-observation", "missing-declaration",
         "wrong-declared-hash", "mutated-declaration", "missing-receipt",
         "mutated-receipt", "mutated-report", "mutated-observation"]
results = [exercise(runtime, case) for runtime in ("bash", "pwsh") for case in cases]
print(f"PASS: {sum(results)}; FAIL: {len(results) - sum(results)}")
raise SystemExit(0 if all(results) else 1)
