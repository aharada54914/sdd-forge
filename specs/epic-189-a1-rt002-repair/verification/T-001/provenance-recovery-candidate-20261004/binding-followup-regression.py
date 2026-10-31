"""Isolated candidate regression: never touches a working identity ledger.

Run: python3 binding-followup-regression.py --repo /path/to/proposed-tree
The proposed tree must contain the #423-equivalent validator and issue311 fixture.
"""

import argparse
import importlib.util
import json
import pathlib
import shutil
import subprocess
import tempfile


def load_fixture(repo):
    spec = importlib.util.spec_from_file_location(
        "issue311_fixture", repo / "tests/issue311-scratch-isolation.tests.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def patched_validators(source, destination):
    rel = pathlib.Path("plugins/sdd-quality-loop/scripts")
    sh = (source / rel / "validate-review-context-set.sh").read_text()
    ps = (source / rel / "validate-review-context-set.ps1").read_text()
    sh_old = '''    (.session_id | type == "string" and length > 0)
  ' "$implementation_manifest" >/dev/null 2>&1 ||
    fail IDENTITY 'implementation manifest task/run/session is invalid'
'''
    sh_new = '''    (.session_id | type == "string" and length > 0) and
    (.allowed_inputs | type == "array" and length > 0) and
    all(.allowed_inputs[]; type == "object" and (keys | sort) == ["path","sha256"] and
      (.path | type == "string" and (explode | all(.[]; . >= 32 and . != 127))) and
      (.sha256 | type == "string" and length == 64 and test("^[0-9a-f]{64}$"))) and
    (([.allowed_inputs[].path] | unique | length) == (.allowed_inputs | length))
  ' "$implementation_manifest" >/dev/null 2>&1 ||
    fail IDENTITY 'implementation manifest task/run/session/inputs is invalid'
  while IFS= read -r pinned; do
    is_canonical_path "$pinned" || fail IDENTITY 'implementation manifest input path is invalid'
  done < <(jq -r '.allowed_inputs[].path' "$implementation_manifest")
'''
    sh_call = 'if $reserve && [[ "$stage:$role" == quality:sdd-evaluator ]]; then\n  verify_implementation_binding\n'
    sh_replacement = 'if [[ "$stage:$role" == quality:sdd-evaluator ]]; then\n  verify_implementation_binding\nfi\nif $reserve && [[ "$stage:$role" == quality:sdd-evaluator ]]; then\n'
    ps_old = """            Fail-ReviewContext 'IDENTITY' 'implementation manifest task/run/session is invalid'
        }
        if (@($implementationReportLines"""
    ps_new = """            Fail-ReviewContext 'IDENTITY' 'implementation manifest task/run/session is invalid'
        }
        if ($implementation.allowed_inputs -isnot [array] -or $implementation.allowed_inputs.Count -eq 0) {
            Fail-ReviewContext 'IDENTITY' 'implementation manifest allowed_inputs is invalid'
        }
        $seenInputs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($entry in $implementation.allowed_inputs) {
            if ($entry -isnot [hashtable] -or -not (Test-ExactKeys $entry @('path','sha256')) -or
                $entry.path -isnot [string] -or -not (Test-CanonicalPath $entry.path) -or
                -not $seenInputs.Add($entry.path) -or
                $entry.sha256 -isnot [string] -or $entry.sha256.Length -ne 64 -or
                $entry.sha256 -cnotmatch '^[0-9a-f]{64}$') {
                Fail-ReviewContext 'IDENTITY' 'implementation manifest allowed_inputs is invalid'
            }
        }
        if (@($implementationReportLines"""
    ps_call = "    if ($Reserve -and \"$($document.stage):$($document.role)\" -ceq 'quality:sdd-evaluator') {\n        $implementation = Get-ImplementationBinding\n"
    ps_replacement = "    if (\"$($document.stage):$($document.role)\" -ceq 'quality:sdd-evaluator') {\n        $implementation = Get-ImplementationBinding\n    }\n    if ($Reserve -and \"$($document.stage):$($document.role)\" -ceq 'quality:sdd-evaluator') {\n"
    ps_path_old = "$Path -cmatch '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$' -and"
    ps_path_new = "$Path -cmatch '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*\\z' -and"
    for label, body, old, new in (
        ("bash schema", sh, sh_old, sh_new),
        ("bash preflight", sh, sh_call, sh_replacement),
        ("PowerShell schema", ps, ps_old, ps_new),
        ("PowerShell preflight", ps, ps_call, ps_replacement),
        ("PowerShell canonical path end", ps, ps_path_old, ps_path_new),
    ):
        if body.count(old) != 1:
            raise RuntimeError(f"candidate anchor changed: {label}")
    sh = sh.replace(sh_old, sh_new).replace(sh_call, sh_replacement)
    ps = ps.replace(ps_old, ps_new).replace(ps_call, ps_replacement).replace(ps_path_old, ps_path_new)
    (destination / rel).mkdir(parents=True, exist_ok=True)
    (destination / rel / "validate-review-context-set.sh").write_text(sh)
    (destination / rel / "validate-review-context-set.ps1").write_text(ps)


def exercise(fixture, source, runtime, variant):
    actual_run = subprocess.run
    captured = []

    def intercept(command, *args, **kwargs):
        invocation = pathlib.Path(command[2] if runtime == "bash" else command[5])
        root = invocation.parent
        data = json.loads(invocation.read_text())
        manifest_path = root / data["implementation_manifest"]["path"]
        task_data = json.loads(manifest_path.read_text())
        report = root / "reports/implementation/f/T-001.md"
        if variant == "missing-inputs":
            task_data.pop("allowed_inputs")
        elif variant == "malformed-inputs":
            task_data["allowed_inputs"] = "not-an-array"
        elif variant == "wrong-task":
            task_data["task_id"] = "T-002"
        elif variant == "wrong-run":
            task_data["run_id"] = "other-worker-run"
        elif variant not in ("valid", "undeclared-source"):
            raise ValueError(variant)
        old_hash = data["implementation_manifest"]["sha256"]
        fixture.write_json(manifest_path, task_data)
        new_hash = fixture.digest(manifest_path.read_bytes())
        report.write_text(report.read_text().replace(old_hash, new_hash))
        data["implementation_manifest"]["sha256"] = new_hash
        for entry in data["allowed_input_manifest"]:
            if entry["path"] == "handoffs/fixture/manifest.json":
                entry["sha256"] = new_hash
            elif entry["path"] == "reports/implementation/f/T-001.md":
                entry["sha256"] = fixture.digest(report.read_bytes())
        fixture.write_json(invocation, data)
        ledger = root / "reports/review-context/identity-ledger.json"
        before = ledger.read_bytes()
        flag = "--reserve" if runtime == "bash" else "-Reserve"
        preflight = actual_run(command, capture_output=True, text=True, timeout=40)
        preflight_unchanged = ledger.read_bytes() == before
        reserve = actual_run(command + [flag], capture_output=True, text=True, timeout=40)
        captured.append((preflight, reserve, preflight_unchanged, ledger.read_bytes() == before))
        raise StopIteration

    subprocess.run = intercept
    try:
        try:
            fixture.exercise(source, runtime, "dependency-undeclared" if variant == "undeclared-source" else "dependency-output-declared")
        except StopIteration:
            pass
    finally:
        subprocess.run = actual_run
    return captured[0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=pathlib.Path, required=True)
    args = parser.parse_args()
    fixture = load_fixture(args.repo)
    failures = 0
    with tempfile.TemporaryDirectory(prefix="rt002-binding-review-") as work:
        overlay = pathlib.Path(work) / "overlay"
        patched_validators(args.repo, overlay)
        for name, source in (("before", args.repo), ("candidate", overlay)):
            for runtime in ("bash", "pwsh"):
                if not shutil.which(runtime):
                    raise RuntimeError(f"missing runtime: {runtime}")
                for variant in ("valid", "missing-inputs", "malformed-inputs", "wrong-task", "wrong-run", "undeclared-source"):
                    pre, reserve, pre_unchanged, reserve_unchanged = exercise(fixture, source, runtime, variant)
                    pre_expected = 0 if name == "before" and variant != "undeclared-source" else (0 if variant == "valid" else 1)
                    reserve_expected = 0 if variant == "valid" or (name == "before" and variant in ("missing-inputs", "malformed-inputs")) else 1
                    passed = (
                        pre_unchanged
                        and pre.returncode == pre_expected
                        and reserve.returncode == reserve_expected
                        and reserve_unchanged == (reserve_expected == 1)
                    )
                    failures += not passed
                    print(f"{'PASS' if passed else 'FAIL'} {name} {runtime} {variant}: "
                          f"preflight={pre.returncode}, reserve={reserve.returncode}, "
                          f"preflight-ledger-unchanged={pre_unchanged}, reserve-ledger-unchanged={reserve_unchanged}")
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
