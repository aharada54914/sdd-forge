#!/usr/bin/env python3
"""Exact Sol registration and fail-closed routing on both selector hosts."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / 'contracts/agent-model-capabilities.v2.json'
MODEL = 'openai/gpt-5.6-sol'
SELECTOR = ROOT / 'plugins/sdd-implementation/scripts/select-agent-model'


class SolRegistration(unittest.TestCase):
    def test_exact_registration(self):
        registry = json.loads(REGISTRY.read_text())
        entries = [item for item in registry['models'] if item['name'] == MODEL]
        self.assertEqual(entries, [{
            'name': MODEL, 'canonical_tier': 'standard',
            'supported_efforts': ['low', 'medium', 'high', 'xhigh'],
            'default_effort': 'low',
            'effort_control': {'claude-code': 'none', 'codex-cli': 'flag'},
        }])
        self.assertEqual(registry['role_defaults']['task-reviewer'],
                         {'minimum_tier': 'standard', 'default_effort': 'medium'})
        self.assertEqual(registry['role_defaults']['sdd-evaluator']['minimum_tier'],
                         'strong')

    def exercise(self, powershell=False):
        with tempfile.TemporaryDirectory(prefix='sol-routing-') as scratch:
            candidate = Path(scratch) / 'candidate.json'

            def invoke(effort='high', available=True, required=None):
                candidate.write_text(json.dumps([
                    {'name': MODEL, 'available': available, 'cost': '0.01'}]))
                if powershell:
                    cmd = ['pwsh', '-NoProfile', '-File', str(SELECTOR) + '.ps1',
                           '-Risk', 'medium', '-Registry', str(REGISTRY),
                           '-CandidatesFile', str(candidate), '-Role', 'task-reviewer',
                           '-HostName', 'codex-cli', '-RequestedEffort', effort, '-Json']
                    if required:
                        cmd.extend(['-RequiredTier', required])
                else:
                    cmd = ['bash', str(SELECTOR) + '.sh', '--risk', 'medium',
                           '--registry', str(REGISTRY), '--candidates-file', str(candidate),
                           '--role', 'task-reviewer', '--host', 'codex-cli',
                           '--requested-effort', effort, '--json']
                    if required:
                        cmd.extend(['--required-tier', required])
                result = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                return result.stdout.strip()

            for effort in ['medium', 'high']:
                with self.subTest(effort=effort, powershell=powershell):
                    result = json.loads(invoke(effort))
                    self.assertEqual(result['model'], MODEL)
                    self.assertEqual(result['canonical_tier'], 'standard')
                    self.assertEqual(result['effort'], effort)
                    self.assertEqual(result['effort_source'], 'requested')
                    self.assertEqual(result['effort_control'], 'flag')
            for options in [{'available': False}, {'required': 'strong'}, {'effort': 'xhigh'}]:
                with self.subTest(options=options, powershell=powershell):
                    self.assertEqual(invoke(**options), 'BLOCKED model-tier-unavailable')

    def test_shell_routing(self):
        self.exercise()

    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell is unavailable')
    def test_powershell_routing(self):
        self.exercise(powershell=True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
