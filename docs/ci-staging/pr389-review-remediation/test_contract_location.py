#!/usr/bin/env python3
"""A-1 actual-gate and A-3 unchanged-function parity regressions.

No product file is modified or copied. Temporary fixtures are test-owned.
Parity cases isolate original functions, not the complete gate.
"""
import argparse
import ast
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

PARSER = argparse.ArgumentParser()
PARSER.add_argument("--repo", required=True, type=Path)
ARGS, REST = PARSER.parse_known_args()
REPO = ARGS.repo.resolve()
GATE = REPO / "plugins/sdd-quality-loop/scripts/check-contract.ps1"
PS_SOURCE = GATE.read_text()
PS_START = PS_SOURCE.index("function Get-ContractProjectRoot {")
PS_END = PS_SOURCE.index("\n$absEvidenceRoot =", PS_START)
PS_FUNCTION = PS_SOURCE[PS_START:PS_END]
PY_SOURCE = (GATE.parent / "check-contract.py").read_text()
PY_FUNCTION = next(
    node for node in ast.parse(PY_SOURCE).body
    if isinstance(node, ast.FunctionDef) and node.name == "_discover_project_root"
)
PY_NAMESPACE = {"os": os}
exec(compile(ast.Module(body=[PY_FUNCTION], type_ignores=[]), str(GATE.with_suffix(".py")), "exec"), PY_NAMESPACE)
DISCOVER_PY = PY_NAMESPACE["_discover_project_root"]


def powershell(script, cwd, **variables):
    return subprocess.run(
        ["pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script],
        cwd=cwd, env=dict(os.environ, **variables),
        text=True, capture_output=True, timeout=30,
    )


class ContractLocationTests(unittest.TestCase):
    def test_actual_gate_relative_and_absolute_after_location_change(self):
        relative = "./specs/epic-194-a6-lite-integration/verification/T-003.contract.json"
        self.assertTrue((REPO / relative).is_file())
        script = r'''
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $env:CANDIDATE
if ([Environment]::CurrentDirectory -eq $PWD.Path) {
    throw 'Fixture invalid: process CWD must differ from PowerShell location'
}
# No native command here: that can synchronize process CWD and hide A-1.
& $env:GATE $env:CONTRACT_FILE -RepoRoot $env:CANDIDATE
exit $LASTEXITCODE
'''
        with tempfile.TemporaryDirectory(prefix="pr389-a1-cwd-") as outside:
            absolute_result = powershell(
                script, outside, CANDIDATE=str(REPO), GATE=str(GATE),
                CONTRACT_FILE=str(REPO / relative),
            )
            relative_result = powershell(
                script, outside, CANDIDATE=str(REPO), GATE=str(GATE),
                CONTRACT_FILE=relative,
            )
        self.assertEqual(absolute_result.returncode, 0, absolute_result.stdout + absolute_result.stderr)
        self.assertEqual(relative_result.returncode, 0, relative_result.stdout + relative_result.stderr)
        self.assertEqual(relative_result.stdout, absolute_result.stdout)

    def assert_parity(self, segment, discover_project):
        with tempfile.TemporaryDirectory(prefix="pr389-a3-") as owned:
            project = Path(owned) / "project"
            contract = project / segment / "feature" / "verification" / "contract.json"
            contract.parent.mkdir(parents=True)
            contract.write_text("{}\n")
            fallback = Path(owned) / "fallback"
            fallback.mkdir()
            expected = str(project if discover_project else fallback)
            python_result = DISCOVER_PY(str(contract), str(fallback))
            self.assertEqual(python_result, expected)
            result = powershell(
                PS_FUNCTION + "\nGet-ContractProjectRoot -ContractPath $env:CONTRACT_FILE -FallbackRoot $env:FALLBACK_ROOT\n",
                owned, CONTRACT_FILE=str(contract), FALLBACK_ROOT=str(fallback),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), python_result)

    def test_lowercase_specs_discovers_project_in_both_original_functions(self):
        self.assert_parity("specs", True)

    def test_misc_uses_fallback_in_both_original_functions(self):
        self.assert_parity("misc", False)

    def test_mixedcase_specs_uses_fallback_in_both_original_functions(self):
        # Separate fixture: no case-sensitive filesystem is needed.
        self.assert_parity("Specs", False)


if __name__ == "__main__":
    unittest.main(argv=[__file__] + REST)
