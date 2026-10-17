#!/usr/bin/env python3
"""Actual-runtime decisions for shipped Python reader inputs and trust failures."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'plugins/sdd-quality-loop'
PARSER = argparse.ArgumentParser()
PARSER.add_argument('--runtime', action='append', choices=('python', 'node', 'powershell'))
PARSER.add_argument('--powershell', default='pwsh')
OPTIONS, REMAINING = PARSER.parse_known_args()
RUNTIMES = OPTIONS.runtime or ['python', 'node', 'powershell']


class ReaderInputs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='sdd-reader-inputs-')
        cls.root = Path(cls.temp.name)
        cls.package = cls.root / 'plugins/sdd-quality-loop'
        cls.scripts = cls.package / 'scripts'
        cls.scripts.mkdir(parents=True)
        (cls.package / 'references').mkdir()
        for filename in ('sdd-hook-guard.py', 'sdd-hook-guard.js', 'sdd-hook-guard.ps1',
                         'classify-readonly-inputs.py', 'validate-approval-sidecar.py',
                         'canonicalize-sdd-yaml.py', 'validate-capability-registry.py'):
            shutil.copyfile(SOURCE / 'scripts' / filename, cls.scripts / filename)
        shutil.copytree(SOURCE / 'scripts/generated', cls.scripts / 'generated')
        shutil.copyfile(SOURCE / 'references/readonly-input-contracts.json', cls.package / 'references/readonly-input-contracts.json')
        cls.environ = {k: v for k, v in os.environ.items() if k not in ('PAYLOAD', 'SDD_SUDO')}
        cls.environ['CLAUDE_PROJECT_DIR'] = str(cls.root)
        cls.commands = {
            'python': [shutil.which('python3') or 'python', str(cls.scripts / 'sdd-hook-guard.py')],
            'node': ['node', str(cls.scripts / 'sdd-hook-guard.js')],
            'powershell': [OPTIONS.powershell, '-NoProfile', '-File', str(cls.scripts / 'sdd-hook-guard.ps1')],
        }
        cls.approval = 'python3 plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py --content sdd/project-context.yaml --sidecar sdd/project-context.approval.json --approver-registry sdd/approver-registry.yaml'

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def decision(self, command, expected, *, cwd=None, metadata=None):
        payload = {'sessionId': 'synthetic', 'timestamp': 1, 'cwd': str(cwd or self.root),
                   'toolName': 'bash', 'toolArgs': {'command': command}}
        if metadata:
            payload.update(metadata)
        for runtime in RUNTIMES:
            with self.subTest(runtime=runtime, command=command):
                result = subprocess.run(self.commands[runtime] + ['--emit', 'copilot'], input=json.dumps(payload),
                                        text=True, capture_output=True, cwd=self.root, env=self.environ, timeout=15)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout).get('permissionDecision'), expected)

    def test_public_reader_contracts(self):
        for command in (
            self.approval,
            self.approval + ' > result.json && cat result.json',
            'python plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py --sidecar=sdd/project-context.approval.json --content=sdd/project-context.yaml',
            'python3 plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py --verify-provenance --sidecar sdd/project-context.approval.json',
            'python3 plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py --hash-only --input-format yaml sdd/approver-registry.yaml',
            'python3 plugins/sdd-quality-loop/scripts/validate-capability-registry.py --registry contracts/capability-registry.json --repo-root .',
        ):
            self.decision(command, 'allow')

    def test_unknown_and_mutating_argv(self):
        for command in (
            self.approval + ' --apply', self.approval + ' --reserve',
            self.approval + ' --sidecar sdd/project-context.approval.json',
            self.approval.replace('--sidecar', '--unknown'),
            self.approval.replace('--content sdd/project-context.yaml ', ''),
            self.approval + ' --verify-provenance',
            self.approval + ' sdd/approver-registry.yaml',
            'python3 plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py --input-format unknown sdd/approver-registry.yaml',
            'python3 plugins/sdd-quality-loop/scripts/validate-capability-registry.py --repo-root sdd/approver-registry.yaml',
        ):
            self.decision(command, 'deny')

    def test_write_targets_and_shell_context(self):
        for command in (
            self.approval + ' > sdd/approver-registry.yaml',
            self.approval + ' 2>>sdd/project-context.approval.json',
            self.approval + ' | tee sdd/approver-registry.yaml',
            self.approval + ' && rm sdd/approver-registry.yaml',
            'echo ok; ' + self.approval,
            'alias python3=rm\n' + self.approval,
            'hash -p /bin/rm python3\n' + self.approval,
            'PATH=/tmp ' + self.approval,
            self.approval.replace('python3 ', '/tmp/python3 ', 1),
            self.approval.replace('--content sdd/project-context.yaml', '--content "$INPUT"'),
            self.approval + ' && cd elsewhere',
            self.approval + ' < sdd/approver-registry.yaml',
        ):
            self.decision(command, 'deny')

    def test_execution_directory_binding(self):
        other = self.root / 'other'
        other.mkdir(exist_ok=True)
        self.decision(self.approval, 'deny', cwd=other)
        for value in ('.', '', None, 1):
            self.decision(self.approval, 'deny', metadata={'cwd': value})
        self.decision(self.approval, 'deny', metadata={'workdir': str(other)})
        self.decision(self.approval, 'allow', metadata={'workdir': str(self.root)})
        canonical = {'cwd': str(self.root), 'tool_name': 'bash', 'tool_input': {'command': self.approval, 'workdir': str(other)}}
        for runtime in RUNTIMES:
            with self.subTest(runtime=runtime):
                result = subprocess.run(self.commands[runtime] + ['--emit', 'copilot'], input=json.dumps(canonical), text=True,
                                        capture_output=True, cwd=self.root, env=self.environ, timeout=15)
                self.assertEqual(json.loads(result.stdout)['permissionDecision'], 'deny')

    def test_script_identity(self):
        outside = self.root / 'other/scripts'
        outside.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(self.scripts / 'validate-approval-sidecar.py', outside / 'validate-approval-sidecar.py')
        command = self.approval.replace('plugins/sdd-quality-loop/scripts/', 'other/scripts/')
        self.decision(command, 'deny')
        self.decision(self.approval.replace('scripts/', 'scripts-spoof/'), 'deny')
        script = self.scripts / 'validate-approval-sidecar.py'
        original = script.read_bytes()
        script.unlink()
        try:
            try:
                script.symlink_to(outside / script.name)
            except OSError:
                self.skipTest('symlink creation is unavailable')
            self.decision(self.approval, 'deny')
        finally:
            if script.is_symlink():
                script.unlink()
            script.write_bytes(original)

    def test_dependency_failures(self):
        helper = self.scripts / 'classify-readonly-inputs.py'
        catalog = self.package / 'references/readonly-input-contracts.json'
        for path, replacement in ((helper, None), (catalog, None), (catalog, b'not json'),
                                  (helper, b'raise SystemExit(3)\n'),
                                  (helper, b'print("not json")\n'),
                                  (helper, b'print("[true]")\n'),
                                  (helper, b'import time; time.sleep(10)\n')):
            saved = path.read_bytes()
            try:
                if replacement is None:
                    path.unlink()
                else:
                    path.write_bytes(replacement)
                self.decision(self.approval, 'deny')
            finally:
                path.write_bytes(saved)

    def test_classifier_and_catalog_protection(self):
        for target in ('tests/guard-readonly-inputs.tests.py',
                       'plugins/sdd-quality-loop/scripts/classify-readonly-inputs.py',
                       'plugins/sdd-quality-loop/references/readonly-input-contracts.json'):
            self.decision('cat ' + target, 'allow')
            self.decision('printf changed > ' + target, 'deny')
            payload = {'tool_name': 'write', 'tool_input': {'file_path': target, 'content': 'changed'}}
            for runtime in RUNTIMES:
                with self.subTest(runtime=runtime, target=target):
                    result = subprocess.run(self.commands[runtime] + ['--emit', 'copilot'], input=json.dumps(payload),
                                            text=True, capture_output=True, cwd=self.root, env=self.environ, timeout=15)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(result.stdout)['permissionDecision'], 'deny')


if __name__ == '__main__':
    unittest.main(argv=[__file__] + REMAINING)
