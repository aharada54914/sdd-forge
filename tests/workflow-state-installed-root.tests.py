#!/usr/bin/env python3
"""Installed workflow checker selects consumer state and packaged schema (#726)."""
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
parser = argparse.ArgumentParser()
parser.add_argument('--powershell', default='pwsh')
options, remaining = parser.parse_known_args()


class InstalledRoot(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='workflow-installed-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.package = self.root / 'cache/sdd-plugins/sdd-quality-loop/1.23.1'
        (self.package / 'scripts').mkdir(parents=True)
        (self.package / 'contracts').mkdir()
        for extension in ('sh', 'ps1'):
            shutil.copyfile(SOURCE / f'scripts/check-workflow-state.{extension}', self.package / f'scripts/check-workflow-state.{extension}')
        shutil.copyfile(SOURCE / 'contracts/workflow-state-registry.schema.json', self.package / 'contracts/workflow-state-registry.schema.json')
        self.project = self.root / 'consumer project'
        self.spec = self.project / 'specs/demo'
        self.spec.mkdir(parents=True)
        (self.spec / 'requirements.md').write_text('Spec-Review-Status: Pending\n')
        (self.spec / 'design.md').write_text('Impl-Review-Status: Pending\n')
        (self.spec / 'acceptance-tests.md').write_text('# Acceptance\n')
        self.registry = self.project / 'specs/workflow-state-registry.json'
        self.registry.write_text(json.dumps({'schema_version':1,'migration_baseline_commit':'0369c8c96de2eb3179868d1949d66644488f65aa','entries':[{'feature':'demo','profile':'full'}]}))
        self.commands = (
            ['bash',str(self.package / 'scripts/check-workflow-state.sh')],
            [options.powershell,'-NoProfile','-File',str(self.package / 'scripts/check-workflow-state.ps1')],
        )

    def run_gate(self, args=(), cwd=None, code=0, text='workflow-state: ok'):
        for command in self.commands:
            with self.subTest(runtime=command[0], args=args):
                result = subprocess.run([*command,*args],cwd=cwd or self.project,text=True,capture_output=True,timeout=30)
                self.assertEqual(result.returncode,code,result.stdout+result.stderr)
                self.assertIn(text,result.stdout+result.stderr)

    def test_installed_defaults_to_cwd(self):
        self.run_gate(['--feature','demo'])
        self.assertFalse((self.root / 'cache/specs').exists())

    def test_explicit_root_and_registry_binding(self):
        self.run_gate(['--repository-root',str(self.project),'--feature','demo'],cwd=self.root)
        self.run_gate(['--repository-root',str(self.root),'--registry',str(self.registry)],code=1,text='registry is outside')

    def test_missing_packaged_schema_fails(self):
        (self.package / 'contracts/workflow-state-registry.schema.json').unlink()
        self.run_gate(code=1,text='registry-schema')

    def test_forged_pass_remains_denied(self):
        (self.spec / 'requirements.md').write_text('Spec-Review-Status: Passed\n')
        self.run_gate(code=1,text='stage-provenance')

    def test_packaged_schema_matches_canonical(self):
        self.assertEqual((SOURCE / 'contracts/workflow-state-registry.schema.json').read_bytes(),(ROOT / 'contracts/workflow-state-registry.schema.json').read_bytes())


if __name__ == '__main__':
    unittest.main(argv=[__file__,*remaining])
