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


def run():
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
