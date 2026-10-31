#!/usr/bin/env python3
"""Exercise the actual suite boundary code, never mutate the live workflow.

The suite entry/exit invariant does not prove historical task-commit provenance.
Run with: python3 tests/parity-workflow-runtime.tests.py
"""
import ast
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
SUITES = ("facet-manifest", "capability-registry", "component-path-ownership")


def block(source, name):
    return textwrap.dedent(source.split(f"# BEGIN workflow {name}\n", 1)[1]
                           .split(f"# END workflow {name}", 1)[0])


class RuntimeBoundary(unittest.TestCase):
    def test_shell_boundaries(self):
        for suite in SUITES:
            for runtime in ("sh", "ps1"):
                source = (ROOT / f"tests/{suite}-parity.tests.{runtime}").read_text()
                snapshot, comparison = block(source, "snapshot"), block(source, "comparison")
                for case in ("unchanged", "changed", "deleted", "unreadable", "initial-unreadable", "initial-missing"):
                    with self.subTest(suite=suite, runtime=runtime, case=case), tempfile.TemporaryDirectory() as directory:
                        base = Path(directory)
                        live = base / ".github/workflows/test.yml"
                        live.parent.mkdir(parents=True)
                        # Pre-existing arbitrary bytes are a valid baseline, including NUL/CRLF.
                        live.write_bytes(b"approved dirty bytes\x00\r\n")
                        if case == "initial-unreadable":
                            live.chmod(0)
                        if case == "initial-missing":
                            live.unlink()
                        env = dict(os.environ, BOUNDARY_ROOT=str(base))
                        if runtime == "sh":
                            mutation = {
                                "unchanged": ":", "changed": 'printf x >> "$LIVE_WORKFLOW"',
                                "deleted": 'rm "$LIVE_WORKFLOW"', "unreadable": 'chmod 000 "$LIVE_WORKFLOW"',
                                "initial-unreadable": 'chmod 600 "$LIVE_WORKFLOW"',
                                "initial-missing": 'printf restored > "$LIVE_WORKFLOW"',
                            }[case]
                            program = ('set -uo pipefail\nROOT="$BOUNDARY_ROOT"\nREPO_ROOT="$ROOT"\n'
                                       'WORKDIR="$ROOT"\nTMP="$ROOT"\n'
                                       'ok() { echo ACCEPT; }; pass() { echo ACCEPT; }; fail() { echo REJECT; };\n'
                                       + snapshot + "\n" + mutation + "\n" + comparison)
                            command = ["bash", "-c", program]
                        else:
                            mutation = {
                                "unchanged": "", "changed": "[IO.File]::AppendAllText($LiveWorkflow, 'x')",
                                "deleted": "[IO.File]::Delete($LiveWorkflow)",
                                "unreadable": "& chmod 000 $LiveWorkflow",
                                "initial-unreadable": "& chmod 600 $LiveWorkflow",
                                "initial-missing": "[IO.File]::WriteAllText($LiveWorkflow, 'restored')",
                            }[case]
                            program = ("$ErrorActionPreference='Stop'\n$Root=$env:BOUNDARY_ROOT\n$RepoRoot=$Root\n"
                                       "function Ok($m) { 'ACCEPT' }; function Pass($m) { 'ACCEPT' }; function Fail($m) { 'REJECT' };\n"
                                       + snapshot + "\n" + mutation + "\n" + comparison)
                            command = ["pwsh", "-NoProfile", "-Command", program]
                        try:
                            # Different cwd on every probe; workflow paths must come from the owner root.
                            result = subprocess.run(command, cwd=ROOT.parent, env=env, capture_output=True, text=True)
                            self.assertEqual(result.returncode, 0, result.stderr)
                            self.assertEqual(result.stdout.strip(), "ACCEPT" if case == "unchanged" else "REJECT", result.stderr)
                        finally:
                            if live.exists():
                                live.chmod(0o600)

    def test_python_boundary(self):
        source = (ROOT / "tests/resolve-project-context-parity-check.py").read_text()
        tree = ast.parse(source)
        functions = [node for node in tree.body if isinstance(node, ast.FunctionDef)
                     and node.name in ("workflow_bytes", "workflow_unchanged")]
        self.assertEqual(len(functions), 2)
        namespace = {}
        exec(compile(ast.Module(body=functions, type_ignores=[]), "actual-boundary", "exec"), namespace)
        read, unchanged = namespace["workflow_bytes"], namespace["workflow_unchanged"]
        with tempfile.TemporaryDirectory() as directory:
            live = Path(directory) / "workflow"
            live.write_bytes(b"approved dirty\x00\r\n")
            before = read(live)
            self.assertTrue(unchanged(live, before))
            live.write_bytes(before + b"x")
            self.assertFalse(unchanged(live, before))
            live.unlink()
            self.assertFalse(unchanged(live, before))
            missing = read(live)
            live.write_bytes(before)
            self.assertFalse(unchanged(live, missing))
            try:
                live.chmod(0)
                self.assertFalse(unchanged(live, before))
                unreadable = read(live)
            finally:
                live.chmod(0o600)
            self.assertFalse(unchanged(live, unreadable))


if __name__ == "__main__":
    unittest.main()
