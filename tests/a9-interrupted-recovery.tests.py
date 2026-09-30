"""Baseline admission expectation on actual twin definitions; currently expected RED."""
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ORIGINAL = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("a9_fixture", ORIGINAL / "tests/a9-interrupted-recovery-fixture.py")
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


def report_preflight():
    """Synthetic evidence equality oracle; never attests a T-001 implementation run."""
    spec_dir = ORIGINAL / "specs/a9-interrupted-review-recovery"
    revision = fixture.digest(b"".join((spec_dir / name).read_bytes() for name in
                                     ("requirements.md", "design.md", "acceptance-tests.md")))
    frozen = set()
    for line in (spec_dir / "traceability.md").read_text().splitlines():
        columns = [part.strip() for part in line.split("|")]
        if len(columns) > 9 and columns[9] == "T-001":
            frozen.add((columns[1], columns[8], columns[6]))
    assert ("REQ-002", "AC-002", "TEST-008") in frozen
    # The record, environment and measurement are intentionally independent
    # inputs to the oracle. This synthetic measurement is not A9 admission.
    measured_exit = subprocess.run([sys.executable, "-c", "pass"], capture_output=True).returncode
    execution = {"run_id": "synthetic-run-001", "attempt": 1,
                 "environment": "synthetic-local", "results": {"TEST-008":
                 "PASS" if measured_exit == 0 else "FAIL"}}
    report = {"Run ID": execution["run_id"], "Task Attempt Count": execution["attempt"],
              "spec_revision": revision, "environment": execution["environment"]}
    verification = {"task": "T-001", "req": "REQ-002", "ac": "AC-002",
                    "test": "TEST-008", "result": execution["results"]["TEST-008"]}

    def mismatch(candidate_report, candidate_verification):
        expected_report = {"Run ID": execution["run_id"], "Task Attempt Count": execution["attempt"],
                           "spec_revision": revision, "environment": execution["environment"]}
        for key, expected in expected_report.items():
            if candidate_report.get(key) != expected:
                return key
        row = candidate_verification
        if row.get("task") != "T-001":
            return "verification.task"
        if (row.get("req"), row.get("ac"), row.get("test")) not in frozen:
            return "verification.assignment"
        if row.get("test") not in execution["results"] or row.get("result") != execution["results"][row["test"]]:
            return "verification.result"
        return None

    print(f"synthetic counterpart: three-file raw digest={revision}; measured control exit={measured_exit}", flush=True)
    if mismatch(report, verification) is not None:
        print("BLOCKED: synthetic positive report/verification control did not admit", flush=True)
        return 1
    print("control synthetic report and frozen verification: PASS", flush=True)
    cases = [
        ("report-run-id-mismatch", "Run ID", "different-synthetic-run", "Run ID"),
        ("report-attempt-mismatch", "Task Attempt Count", 2, "Task Attempt Count"),
        ("report-spec-revision-mismatch", "spec_revision", "0" * 64, "spec_revision"),
        ("report-environment-mismatch", "environment", "different-synthetic-host", "environment"),
    ]
    failures = 0
    for name, field, wrong, expected in cases:
        changed = {**report, field: wrong}
        result = mismatch(changed, verification)
        print(f"{name}: {'PASS' if result == expected else 'FAIL'}; mismatch={result!r}", flush=True)
        failures += result != expected
    for name, field, wrong, expected in (
            ("verification-req-mismatch", "req", "REQ-001", "verification.assignment"),
            ("verification-ac-mismatch", "ac", "AC-001", "verification.assignment"),
            ("verification-test-mismatch", "test", "TEST-084", "verification.assignment"),
            ("verification-result-mismatch", "result", "FAIL", "verification.result")):
        changed = {**verification, field: wrong}
        result = mismatch(report, changed)
        print(f"{name}: {'PASS' if result == expected else 'FAIL'}; mismatch={result!r}", flush=True)
        failures += result != expected
    print(f"report-preflight: synthetic negatives=8 rejected={8 - failures}; admission API not exercised", flush=True)
    return int(bool(failures))


def consumer_preflight():
    """Expose downstream sibling mismatches without claiming T-001 admission."""
    with tempfile.TemporaryDirectory(prefix="a9-consumer-preflight-") as directory:
        root = Path(directory)
        feature = "a9-preflight-fixture"
        spec_dir = root / "specs" / feature
        spec_dir.mkdir(parents=True)
        pieces = (b"REQ-002\n", b"design\n", b"AC-002 TEST-008\n")
        for name, contents in zip(("requirements.md", "design.md", "acceptance-tests.md"), pieces):
            (spec_dir / name).write_bytes(contents)
        correct_revision = fixture.digest(b"".join(pieces))
        wrong_revision = "0" * 64 if correct_revision != "0" * 64 else "1" * 64
        evidence = root / "reports" / "test.log"
        evidence.parent.mkdir(parents=True)
        evidence.write_text("synthetic evidence\n")
        required = ("lint", "typecheck", "build", "placeholder-scan", "task-state-check",
                    "unit-tests", "acceptance-tests", "regression", "requirement-traceability")
        contract = {
            "schema": "verification-contract/v2", "task_id": "T-001", "feature": feature,
            "risk": "high", "required_workflow": "tdd", "created": "2026-10-01T00:00:00Z",
            "spec_revision": correct_revision,
            "checks": [{**{"id": name, "required": True, "passes": True,
                           "evidence": "reports/test.log", "waiver_reason": ""},
                        **({"red_evidence": "reports/test.log", "green_evidence": "reports/test.log"}
                           if name in ("unit-tests", "acceptance-tests") else {})}
                       for name in required],
        }
        contract_path = root / "T-001.contract.json"
        trace_path = root / "traceability.json"
        trace = {"feature": feature, "links": [{"req": "REQ-002", "acs": ["AC-002"],
                                                "tests": ["TEST-008"], "evidence": ["reports/test.log"]}]}

        def invoke(label, command):
            result = subprocess.run(command, capture_output=True, text=True)
            print(f"{label}: exit={result.returncode}; stdout={result.stdout.strip()!r}; stderr={result.stderr.strip()!r}", flush=True)
            return result.returncode

        failures = 0
        contract_commands = [("Bash", ["sh", str(ORIGINAL / "plugins/sdd-quality-loop/scripts/check-contract.sh"),
                                      str(contract_path), str(root)])]
        trace_commands = [("Bash", ["sh", str(ORIGINAL / "plugins/sdd-quality-loop/scripts/check-traceability.sh"),
                                   str(trace_path), str(root), "require-evidence"])]
        if shutil.which("pwsh"):
            contract_commands.append(("PowerShell", ["pwsh", "-NoLogo", "-NoProfile", "-File",
                                                    str(ORIGINAL / "plugins/sdd-quality-loop/scripts/check-contract.ps1"),
                                                    str(contract_path), str(root)]))
            trace_commands.append(("PowerShell", ["pwsh", "-NoLogo", "-NoProfile", "-File",
                                                 str(ORIGINAL / "plugins/sdd-quality-loop/scripts/check-traceability.ps1"),
                                                 "-TracePath", str(trace_path), "-RepoRoot", str(root), "-RequireEvidence"]))
        else:
            print("PowerShell consumer preflight unavailable; twin result pending", flush=True)
            failures += 1

        contract_path.write_bytes(fixture.canonical(contract) + b"\n")
        for runtime, command in contract_commands:
            if invoke(f"control correct spec_revision {runtime}", command) != 0:
                print("BLOCKED: positive contract control failed; wrong-revision result is not semantic RED", flush=True)
                return 1
        contract["spec_revision"] = wrong_revision
        contract_path.write_bytes(fixture.canonical(contract) + b"\n")
        print(f"wrong-revision counterpart: actual={correct_revision} persisted={wrong_revision}", flush=True)
        for runtime, command in contract_commands:
            if invoke(f"RED well-formed wrong spec_revision {runtime}", command) == 0:
                print(f"FAIL: {runtime} accepted well-formed revision unequal to current three-file digest", flush=True)
                failures += 1

        trace_path.write_bytes(fixture.canonical(trace) + b"\n")
        for runtime, command in trace_commands:
            if invoke(f"control traceability membership {runtime}", command) != 0:
                print("BLOCKED: positive traceability control failed; membership result is not semantic RED", flush=True)
                return 1
        trace["links"][0].update({"req": "REQ-999", "acs": ["AC-999"], "tests": ["TEST-999"]})
        trace_path.write_bytes(fixture.canonical(trace) + b"\n")
        for runtime, command in trace_commands:
            if invoke(f"RED wrong-but-existing traceability membership {runtime}", command) == 0:
                print(f"FAIL: {runtime} accepted REQ/AC/TEST identifiers absent from the synthetic source set", flush=True)
                failures += 1

        # The T-001 prior-round sibling validator already reconciles these
        # fields. Rebind the summary's manifest hash so a wrong count reaches
        # count consistency rather than stopping at an incidental stale hash.
        with tempfile.TemporaryDirectory(prefix="a9-prior-consistency-") as prior_dir:
            prior_root = Path(prior_dir) / "count"
            prior_root.mkdir()
            fixture.build(prior_root, ORIGINAL)
            source = (ORIGINAL / "plugins/sdd-review-loop/scripts/spec-review-precheck.sh").read_text()
            definitions = fixture.bash_functions(source)
            start = source.index("jq_relative_path='")
            end = source.index(";'", start) + 2
            setup = ('\nrepo_root=$1; repo_root_alias=$1; feature=$2; '
                     'spec_dir="$1/specs/$2"; requirements="$spec_dir/requirements.md"; '
                     'acceptance="$spec_dir/acceptance-tests.md"; investigation="$spec_dir/investigation.md"; '
                     'calibration="$1/' + fixture.CALIBRATION + '"\n')
            loader = "set -euo pipefail\n" + definitions + "\n" + source[start:end] + setup
            prior_command = ["bash", "-c", loader + '\nvalidate_contract "$1/$3/spec-review-contract.json" 3 2 NEEDS_WORK "$1/$3/precheck-result.json"',
                             "fixture", str(prior_root), fixture.FEATURE, fixture.PREVIOUS]
            if invoke("control complete prior contract Bash", prior_command) != 0:
                print("BLOCKED: prior contract control failed; count/identity result is not semantic", flush=True)
                return 1
            prior_round = prior_root / fixture.PREVIOUS
            summary_path = prior_round / "integrated-summary.json"
            contract_prior_path = prior_round / "spec-review-contract.json"
            reviewer_b_path = prior_round / "reviewer-b.json"
            summary = json.loads(summary_path.read_text())
            summary["reviewer_a_fail_count"] = 0
            summary_path.write_bytes(fixture.canonical(summary) + b"\n")
            summary_hash = fixture.digest(summary_path.read_bytes())
            for manifest_path in (contract_prior_path, reviewer_b_path):
                document = json.loads(manifest_path.read_text())
                manifests = ([reviewer["allowed_input_manifest"] for reviewer in document["reviewers"]]
                             if manifest_path == contract_prior_path else [document["allowed_input_manifest"]])
                for manifest in manifests:
                    for ref in manifest:
                        if Path(ref["path"]).name == "integrated-summary.json":
                            ref["sha256"] = summary_hash
                manifest_path.write_bytes(fixture.canonical(document) + b"\n")
            if invoke("count counterpart mismatch prior Bash", prior_command) == 0:
                print("FAIL: prior validator accepted count unequal to reviewer-A FAIL checks", flush=True)
                failures += 1
            identity_root = Path(prior_dir) / "identity"
            identity_root.mkdir()
            fixture.build(identity_root, ORIGINAL)
            identity_command = prior_command.copy()
            identity_command[-3] = str(identity_root)
            raw_a = identity_root / fixture.PREVIOUS / "reviewer-a.json"
            reviewer_a = json.loads(raw_a.read_text())
            reviewer_a["run_id"] = "well-formed-wrong-run-id"
            raw_a.write_bytes(fixture.canonical(reviewer_a) + b"\n")
            if invoke("identity counterpart mismatch prior Bash", identity_command) == 0:
                print("FAIL: prior validator accepted reviewer-A run_id unequal to contract", flush=True)
                failures += 1
        print(f"consumer-preflight: semantic mismatches accepted={failures}; admission API not exercised", flush=True)
        return int(bool(failures))


def run():
    if "--report-preflight" in sys.argv[1:]:
        return report_preflight()
    if "--consumer-preflight" in sys.argv[1:]:
        return consumer_preflight()
    failures = 0
    with tempfile.TemporaryDirectory(prefix="a9-recovery-fixture-") as directory:
        root = Path(directory)
        record = fixture.build(root, ORIGINAL)
        assert len(record) == 10 and len(record["pinned_inputs"]) == 4 and len(record["interrupted_artifacts"]) == 6
        print("fixture: synthetic 10-root/4-pin/6-inventory tree built; semantic admission unverified", flush=True)
        bash_source = (ORIGINAL / "plugins/sdd-review-loop/scripts/spec-review-precheck.sh").read_text()
        functions = fixture.bash_functions(bash_source)
        jq_start = bash_source.index("jq_relative_path='")
        jq_end = bash_source.index(";'", jq_start) + 2
        setup = '\nrepo_root=$1; repo_root_alias=$1; feature=$2; spec_dir="$1/specs/$2"; requirements="$spec_dir/requirements.md"; acceptance="$spec_dir/acceptance-tests.md"; investigation="$spec_dir/investigation.md"; calibration="$1/' + fixture.CALIBRATION + '"\n'
        loader = "set -euo pipefail\n" + functions + "\n" + bash_source[jq_start:jq_end] + setup
        remaining = "--remaining-delta" in sys.argv[1:]
        cases = fixture.remaining_cases() if remaining else fixture.mutations(root, record)
        for option in sys.argv[1:]:
            if option.startswith("--after-case="):
                name = option.split("=", 1)[1]
                cases = cases[next(index for index, case in enumerate(cases) if case[0] == name) + 1:]
        if "--reference-delta" in sys.argv[1:]:
            cases = [case for case in cases if case[0].startswith(("TEST-083-P", "TEST-057-H", "canonical-ref-P"))]
        baseline_snapshot = fixture.snapshot(root)
        catalog = []
        # Materialize every new input once even while admission is RED. This proves
        # the catalog/deltas exist, not that any intended negative was rejected.
        with tempfile.TemporaryDirectory(prefix="a9-mutation-inputs-") as inputs:
            for index, case in enumerate(cases):
                mutated = Path(inputs) / str(index)
                shutil.copytree(root, mutated)
                fixture.write_mutation(mutated, record, case)
                after = fixture.snapshot(mutated)
                delta = {path: {"before": baseline_snapshot.get(path), "after": after.get(path)}
                         for path in sorted(baseline_snapshot.keys() | after.keys())
                         if baseline_snapshot.get(path) != after.get(path)}
                assert delta, case[0]
                catalog.append({"name": case[0], "input_sha256": fixture.digest(fixture.canonical(after)), "delta": delta})
                if remaining:
                    print("case evidence: " + fixture.canonical(catalog[-1]).decode(), flush=True)
                    if case[1] in ("later-valid", "composite", "source-not-latest", "completed-source"):
                        changed_record = json.loads((mutated / fixture.RECORD).read_text())
                        invocation = changed_record["reviewer_a"]["invocation"]["path"]
                        before_check = fixture.snapshot(mutated)
                        identity_commands = [("Bash", ["bash", str(ORIGINAL / "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"), str(mutated / invocation), str(mutated)])]
                        if shutil.which("pwsh"):
                            identity_commands.append(("PowerShell", ["pwsh", "-NoLogo", "-NoProfile", "-File", str(ORIGINAL / "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"), "-Manifest", str(mutated / invocation), "-RepositoryRoot", str(mutated)]))
                        for runtime, command in identity_commands:
                            result = subprocess.run(command, capture_output=True, text=True)
                            print(f"{case[0]} sibling identity {runtime}: exit={result.returncode} unchanged={before_check == fixture.snapshot(mutated)}", flush=True)
                            print(result.stdout + result.stderr, end="", flush=True)
                            assert result.returncode == 0 and before_check == fixture.snapshot(mutated), case[0]
                        if case[1] == "later-valid":
                            changed_invocation = json.loads((mutated / invocation).read_text())
                            assert changed_invocation["identity_ledger_sha256"] == json.loads((root / fixture.INVOCATION).read_text())["identity_ledger_sha256"]
                            assert set(delta) == {fixture.LEDGER}, case[0]
                        else:
                            previous = str(Path(changed_record["previous_contract"]["path"]).parent)
                            source = str(Path(changed_record["interrupted_precheck"]["path"]).parent)
                            checked = source if case[1] == "completed-source" else previous
                            round_number = changed_record["source"]["round"] if case[1] == "completed-source" else changed_record["source"]["round"] - 1
                            result = subprocess.run(["bash", "-c", loader + '\nvalidate_contract "$1/$3/spec-review-contract.json" 3 "$4" NEEDS_WORK "$1/$3/precheck-result.json"', "fixture", str(mutated), fixture.FEATURE, checked, str(round_number)], capture_output=True, text=True)
                            print(f"{case[0]} sibling own-stage NEEDS_WORK: exit={result.returncode}", flush=True)
                            print(result.stdout + result.stderr, end="", flush=True)
                            assert result.returncode == 0, case[0]
                            if case[1] == "composite":
                                precheck = json.loads((mutated / changed_record["interrupted_precheck"]["path"]).read_text())
                                expected = fixture.digest(":".join(precheck[key] for key in ("requirements_sha256", "acceptance_sha256", "investigation_sha256")).encode())
                                assert precheck["input_sha256"] != expected
                                print(f"TEST-082 isolated: actual={precheck['input_sha256']} expected={expected}; invocation/ledger/raw/receipt rebound", flush=True)
            print(f"mutation inputs: count={len(catalog)} baseline_sha256={fixture.digest(fixture.canonical(baseline_snapshot))} catalog_sha256={fixture.digest(fixture.canonical(catalog))}", flush=True)
            print("named cases: " + ", ".join(case[0] for case in cases), flush=True)
        # Existing validator checks the synthetic preceding contract, not merely its verdict.
        prior = subprocess.run(["bash", "-c", loader + '\nvalidate_contract "$1/$3/spec-review-contract.json" 3 2 NEEDS_WORK "$1/$3/precheck-result.json"',
                                "fixture", str(root), fixture.FEATURE, fixture.PREVIOUS], capture_output=True, text=True)
        print(f"fixture previous-contract validator: exit={prior.returncode}", flush=True)
        if prior.returncode:
            print(prior.stdout + prior.stderr, end="")
            return 1
        identity = subprocess.run(["bash", str(ORIGINAL / "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"),
                                   str(root / fixture.INVOCATION), str(root)], capture_output=True, text=True)
        print(f"fixture persisted-identity validator (no reserve): exit={identity.returncode}", flush=True)
        print(identity.stdout + identity.stderr, end="", flush=True)
        if identity.returncode:
            return 1
        bash = subprocess.run(["bash", "-c", loader + '\ndeclare -F validate_interrupted_recovery >/dev/null || { echo "RED: missing validate_interrupted_recovery" >&2; exit 1; }\nvalidate_interrupted_recovery "$1" "$2" 4 1 "$1/$3"',
                               "fixture", str(root), fixture.FEATURE, fixture.RECORD], capture_output=True, text=True)
        print(f"TEST-A9-BASELINE-ADMISSION Bash: exit={bash.returncode}", flush=True)
        print(bash.stdout + bash.stderr, end="", flush=True)
        failures += bash.returncode != 0
        if not shutil.which("pwsh"):
            print("PowerShell: unavailable; twin RED not executed", flush=True)
            return 1
        # AST extraction executes definitions only; top-level CLI/writer is never dot-sourced.
        ps = r'''param($Original, $Root, $Feature, $Record)
$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Original, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'original PowerShell source has parse errors' }
$ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]}, $false) | ForEach-Object { Invoke-Expression $_.Extent.Text }
if (-not (Get-Command Test-ValidateInterruptedRecovery -CommandType Function -ErrorAction SilentlyContinue)) { Write-Output 'RED: missing Test-ValidateInterruptedRecovery'; exit 1 }
$result = Test-ValidateInterruptedRecovery $Root $Feature 4 1 $Record
if ($result -cne $true) { throw 'baseline admission rejected' }
'''
        ps_loader = root / "admission-loader.ps1"
        ps_loader.write_text(ps)
        powershell = subprocess.run(["pwsh", "-NoLogo", "-NoProfile", "-File", str(ps_loader),
                                     str(ORIGINAL / "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1"),
                                     str(root), fixture.FEATURE, str(root / fixture.RECORD)], capture_output=True, text=True)
        print(f"TEST-A9-BASELINE-ADMISSION PowerShell: exit={powershell.returncode}", flush=True)
        print(powershell.stdout + powershell.stderr, end="", flush=True)
        failures += powershell.returncode != 0
        # An undefined API or rejected positive control is never a negative PASS.
        for runtime, baseline in (("Bash", bash), ("PowerShell", powershell)):
            if baseline.returncode:
                positives = sum(case[1] == "later-valid" for case in cases)
                print(f"{runtime}: negative executed=0 PASS=0 pending={len(cases) - positives}; positive admission pending={positives} (positive control failed)", flush=True)
                continue
            rejected = 0
            with tempfile.TemporaryDirectory(prefix="a9-mutation-run-") as inputs:
                for index, case in enumerate(cases):
                    mutated = Path(inputs) / str(index)
                    # Use pristine fixture only; the PS loader is not recovery input.
                    shutil.copytree(root, mutated)
                    fixture.write_mutation(mutated, record, case)
                    before = fixture.snapshot(mutated)
                    if runtime == "Bash":
                        result = subprocess.run(["bash", "-c", loader + '\nvalidate_interrupted_recovery "$1" "$2" 4 1 "$1/$3"',
                                                 "fixture", str(mutated), fixture.FEATURE, fixture.RECORD], capture_output=True, text=True)
                    else:
                        result = subprocess.run(["pwsh", "-NoLogo", "-NoProfile", "-File", str(ps_loader),
                                                 str(ORIGINAL / "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1"),
                                                 str(mutated), fixture.FEATURE, str(mutated / fixture.RECORD)], capture_output=True, text=True)
                    unchanged = before == fixture.snapshot(mutated)
                    no_target = not (mutated / f"reports/spec-review/{fixture.FEATURE}/attempt-4/round-1").exists()
                    expected_accept = case[1] == "later-valid"
                    passed = (result.returncode == 0 if expected_accept else result.returncode != 0) and unchanged and no_target
                    failures += not passed
                    rejected += passed
                    print(f"{runtime} {case[0]}: exit={result.returncode} unchanged={unchanged} no_target={no_target} rejection={'PASS' if passed else 'FAIL'}", flush=True)
                    if not passed:
                        print(result.stdout + result.stderr, end="", flush=True)
            print(f"{runtime}: negative executed={len(cases)} PASS={rejected} pending=0", flush=True)
        print("Admission semantic PASS not established; real source/ledger untouched.", flush=True)
        return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(run())
