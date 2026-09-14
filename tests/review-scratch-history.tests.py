"""Isolated fixtures only; never reserves an identity in a working repository."""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value) + "\n")


def exercise(source, runtime, case):
    with tempfile.TemporaryDirectory(prefix="sdd-boundary-fixture-") as directory:
        root = pathlib.Path(directory)
        ledger = root / "reports/review-context/identity-ledger.json"
        first = dict(sequence=1, stage="implementation", role="implementer",
                     run_id="impl", host_session_id="impl-session", previous_record_sha256="")
        first["record_sha256"] = digest(b"1|implementation|implementer|impl|impl-session|")
        records = [first]
        report = root / "reports/implementation/f/T-001.md"
        report.parent.mkdir(parents=True)
        report.write_text("# Implementation Report: T-001\n- Task ID: T-001\n"
                          "- **Scratch Root**: /tmp/impl-one\n")
        scratch = "/tmp/clean-evaluator"
        expected = 0
        if case.startswith("other-"):
            other = report.with_name("T-002.md")
            other.write_text("# Implementation Report: T-002\n- Task ID: T-002\n"
                             "- **Scratch Root**: /opt/feature/impl-two\n")
            scratch = {"other-equal": "/opt/feature/impl-two", "other-child": "/opt/feature/impl-two/child",
                       "other-parent": "/opt/feature", "other-prefix": "/opt/feature/impl-two-more"}[case]
            expected = 0 if case == "other-prefix" else 1
        if case.startswith("prior-") or case == "legacy-missing":
            previous = dict(sequence=2, stage="quality", role="sdd-evaluator",
                            run_id="prior", host_session_id="prior-session",
                            previous_record_sha256=first["record_sha256"])
            previous["record_sha256"] = digest(
                ("2|quality|sdd-evaluator|prior|prior-session|" + first["record_sha256"]).encode())
            records.append(previous)
            if case not in ("prior-missing", "legacy-missing"):
                old = dict(schema="review-context-invocation/v2", feature="f", scratch_root="/opt/history/prior",
                           **{k: v for k, v in previous.items() if k != "record_sha256"})
                write_json(root / "reports/review-context/old-invocation.json", old)
            scratch = {"prior-equal": "/opt/history/prior", "prior-child": "/opt/history/prior/child",
                       "prior-parent": "/opt/history", "prior-prefix": "/opt/history/prior-more",
                       "prior-missing": "/tmp/clean-evaluator", "legacy-missing": "/tmp/clean-evaluator"}[case]
            if case == "prior-missing":
                previous["scratch_declaration_sha256"] = digest(b"f\n/opt/history/prior")
                text = "2|quality|sdd-evaluator|prior|prior-session|" + first["record_sha256"]
                previous["record_sha256"] = digest((text + "|scratch-declaration-v1|" + previous["scratch_declaration_sha256"]).encode())
            expected = 0 if case in ("prior-prefix", "legacy-missing") else 1
        write_json(ledger, dict(schema="review-identity-ledger/v1", records=records))
        invocation = dict(schema="review-context-invocation/v2", input_mode="file-manifest",
                          fallback_mode="none", read_only=True, stage="quality", role="sdd-evaluator",
                          feature="f", task_id="T-001", run_id="next", host_session_id="next-session",
                          sequence=len(records) + 1, previous_record_sha256=records[-1]["record_sha256"],
                          identity_ledger_path="reports/review-context/identity-ledger.json",
                          identity_ledger_sha256=digest(ledger.read_bytes()), scratch_root=scratch,
                          allowed_input_manifest=[dict(path="reports/implementation/f/T-001.md",
                                                       sha256=digest(report.read_bytes()))])
        manifest = root / "invocation.json"
        write_json(manifest, invocation)
        scripts = source / "plugins/sdd-quality-loop/scripts"
        command = (["bash", str(scripts / "validate-review-context-set.sh"), str(manifest), str(root), "--reserve"]
                   if runtime == "bash" else
                   ["pwsh", "-NoProfile", "-File", str(scripts / "validate-review-context-set.ps1"),
                    "-Manifest", str(manifest), "-RepositoryRoot", str(root), "-Reserve"])
        before = ledger.read_bytes()
        result = subprocess.run(command, capture_output=True, text=True, timeout=40)
        passed = (result.returncode == expected and
                  (expected == 0 or (ledger.read_bytes() == before and "REVIEW_CONTEXT_PATH" in result.stderr)))
        print(f"{'ok' if passed else 'not ok'}: {runtime} {case}: exit={result.returncode}, expected={expected}")
        if not passed:
            print(result.stdout, result.stderr)
        if passed and expected == 0:
            saved = list((root / "reports/review-context/scratch-reservations").glob("*.json"))
            passed = len(saved) == 1 and json.loads(saved[0].read_text()) == invocation
            after = ledger.read_bytes()
            verified = subprocess.run(command[:-1], capture_output=True, text=True, timeout=40)
            passed = passed and verified.returncode == 0 and ledger.read_bytes() == after
            invocation["scratch_root"] = "/opt/changed-evaluator"
            write_json(manifest, invocation)
            changed = subprocess.run(command[:-1], capture_output=True, text=True, timeout=40)
            passed = passed and changed.returncode == 1 and "REVIEW_CONTEXT_PATH" in changed.stderr and ledger.read_bytes() == after
            print(f"{'ok' if passed else 'not ok'}: {runtime} {case}: snapshot, unchanged verification, changed-root refusal")
            omitted = dict(invocation)
            omitted.pop("scratch_root")
            write_json(manifest, omitted)
            omitted_result = subprocess.run(command[:-1], capture_output=True, text=True, timeout=40)
            passed = passed and omitted_result.returncode == 1 and ledger.read_bytes() == after
            print(f"{'ok' if passed else 'not ok'}: {runtime} {case}: omitted bound root refused")
            if case in ("snapshot-tampered", "snapshot-deleted"):
                if case == "snapshot-tampered":
                    forged = json.loads(saved[0].read_text())
                    forged["scratch_root"] = "/tmp/forged"
                    write_json(saved[0], forged)
                else:
                    saved[0].unlink()
                invocation.update(scratch_root=scratch, run_id="later", host_session_id="later-session",
                                  sequence=len(records) + 2, identity_ledger_sha256=digest(after),
                                  previous_record_sha256=json.loads(after)["records"][-1]["record_sha256"])
                write_json(manifest, invocation)
                reuse = subprocess.run(command, capture_output=True, text=True, timeout=40)
                passed = passed and reuse.returncode == 1 and ledger.read_bytes() == after
                print(f"{'ok' if passed else 'not ok'}: {runtime} {case}: later reuse exit={reuse.returncode}, expected=1")
        return passed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=pathlib.Path, required=True)
    args = parser.parse_args()
    for runtime in ("bash", "pwsh"):
        if not shutil.which(runtime):
            raise SystemExit(f"Missing required runtime: {runtime}")
    cases = ["clean", "other-equal", "other-child", "other-parent", "other-prefix",
             "prior-equal", "prior-child", "prior-parent", "prior-prefix", "prior-missing",
             "legacy-missing", "snapshot-tampered", "snapshot-deleted"]
    results = [exercise(args.repo, runtime, case) for runtime in ("bash", "pwsh") for case in cases]
    print(f"PASS: {sum(results)}; FAIL: {len(results) - sum(results)}")
    raise SystemExit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
