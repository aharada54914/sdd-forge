"""Baseline admission expectation on actual twin definitions; currently expected RED."""
import importlib.util
import json
import shutil
import subprocess
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
        print("Admission semantic PASS not established; real source/ledger untouched.", flush=True)
        return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(run())
