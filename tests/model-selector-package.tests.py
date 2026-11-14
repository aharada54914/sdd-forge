#!/usr/bin/env python3
"""Real Bash/PowerShell selectors in isolated marketplace-style plugin packages."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PWSH = os.environ.get('SDD_TEST_PWSH') or shutil.which('pwsh')
spec = importlib.util.spec_from_file_location('package_policy_fixture', ROOT / 'tests/model-policy.tests.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class SelectorPackage(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(PWSH, 'PowerShell is required for package parity')
        self.temp = tempfile.TemporaryDirectory(prefix='selector-package-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.package = self.root / 'cache/sdd-plugins/sdd-implementation/1.23.1'
        scripts = self.package / 'scripts'
        scripts.mkdir(parents=True)
        for name in ('select-agent-model.sh', 'select-agent-model.ps1', 'model-policy.py'):
            shutil.copyfile(ROOT / 'plugins/sdd-implementation/scripts' / name, scripts / name)
        shutil.copytree(ROOT / 'plugins/sdd-implementation/contracts', self.package / 'contracts')
        target = self.root / 'cache/sdd-plugins/sdd-quality-loop/1.23.1/scripts/lib/native-arguments.ps1'
        target.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / 'plugins/sdd-quality-loop/scripts/lib/native-arguments.ps1', target)
        self.work = self.root / 'consumer'
        self.work.mkdir()
        # Neither the former three-parent root nor consumer cwd is authority.
        for path in (self.root / 'cache/sdd-plugins/contracts', self.work / 'contracts'):
            path.mkdir()
            for name in ('agent-model-capabilities.json', 'agent-model-capabilities.v2.json'):
                (path / name).write_text('{"poisoned":"must not be used"}')
        (self.work / 'candidates.json').write_text(json.dumps([
            {'name': 'openai/gpt-5.1-codex', 'cost': '0.02', 'available': True, 'effort': 'medium'}]))

    def invoke(self, shell, *, policy=False, explicit=None, cwd=None):
        scripts = self.package / 'scripts'
        if shell == 'bash':
            command = fixture.bash_command(scripts / 'select-agent-model.sh', [])
            command += ['--policy-input', 'request.json'] if policy else ['--risk', 'low', '--candidates-file', 'candidates.json', '--json']
            if explicit:
                command += ['--registry', str(explicit)]
        else:
            command = [PWSH, '-NoProfile', '-File', str(scripts / 'select-agent-model.ps1')]
            command += ['-PolicyInput', 'request.json'] if policy else ['-Risk', 'low', '-CandidatesFile', 'candidates.json', '-Json']
            if explicit:
                command += ['-Registry', str(explicit)]
        return subprocess.run(command, cwd=cwd or self.work, text=True, capture_output=True,
                              env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'}, timeout=45)

    def test_bundled_contracts_are_exact_canonical_mirrors(self):
        for name in ('agent-model-capabilities.json', 'agent-model-capabilities.v2.json'):
            self.assertEqual((self.package / 'contracts' / name).read_bytes(), (ROOT / 'contracts' / name).read_bytes())

    def test_default_registry_uses_package_not_consumer_or_cache_parent(self):
        for shell in ('bash', 'powershell'):
            with self.subTest(shell=shell):
                result = self.invoke(shell)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('openai/gpt-5.1-codex', result.stdout)
                self.assertNotIn('BLOCKED', result.stdout)

    def test_missing_package_registry_does_not_fall_back(self):
        (self.package / 'contracts/agent-model-capabilities.json').unlink()
        for shell in ('bash', 'powershell'):
            with self.subTest(shell=shell):
                result = self.invoke(shell)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('MODEL_SELECTION_ERROR', result.stdout + result.stderr)
                self.assertEqual(result.stdout, '')

    def test_explicit_registry_override_is_preserved(self):
        (self.package / 'contracts/agent-model-capabilities.json').unlink()
        registry = self.work / 'explicit.json'
        shutil.copyfile(ROOT / 'contracts/agent-model-capabilities.json', registry)
        for shell in ('bash', 'powershell'):
            with self.subTest(shell=shell):
                result = self.invoke(shell, explicit=registry)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('openai/gpt-5.1-codex', result.stdout)
                self.assertNotIn('BLOCKED', result.stdout)

    def test_unknown_model_is_not_assigned_an_inferred_tier(self):
        (self.work / 'candidates.json').write_text(json.dumps([
            {'name': 'unregistered-model', 'cost': '0.02', 'available': True, 'effort': 'high'}]))
        for shell in ('bash', 'powershell'):
            with self.subTest(shell=shell):
                result = self.invoke(shell, explicit=self.package / 'contracts/agent-model-capabilities.v2.json')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('MODEL_SELECTION_ERROR', result.stdout + result.stderr)

    def test_explicit_packaged_v2_selects_only_registered_capability(self):
        (self.work / 'candidates.json').write_text(json.dumps([
            {'name': 'gpt-6-astra', 'cost': '0.02', 'available': True, 'effort': 'high'}]))
        for shell in ('bash', 'powershell'):
            with self.subTest(shell=shell):
                result = self.invoke(shell, explicit=self.package / 'contracts/agent-model-capabilities.v2.json')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('gpt-6-astra', result.stdout)
                self.assertIn('strong', result.stdout)
                self.assertNotIn('BLOCKED', result.stdout)

    def test_standalone_package_default_and_policy_bridge(self):
        standalone = self.root / 'standalone/sdd-implementation'
        shutil.copytree(self.package, standalone)
        self.package = standalone
        target = standalone.parent / 'sdd-quality-loop/scripts/lib/native-arguments.ps1'
        target.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / 'plugins/sdd-quality-loop/scripts/lib/native-arguments.ps1', target)
        self.test_default_registry_uses_package_not_consumer_or_cache_parent()
        self.test_policy_default_and_versioned_powershell_bridge()

    def test_policy_default_and_versioned_powershell_bridge(self):
        policy = fixture.PolicySelection()
        policy.setUp()
        self.addCleanup(policy.doCleanups)
        policy.save()
        # Typed policy fixture models, not a production registry or availability claim.
        (self.package / 'contracts/agent-model-capabilities.v2.json').write_text(json.dumps(policy.registry))
        for shell in ('bash', 'powershell'):
            with self.subTest(shell=shell):
                result = self.invoke(shell, policy=True, cwd=policy.work)
                policy.selected(result, fixture.CURRENT)
        (self.package / 'contracts/agent-model-capabilities.v2.json').unlink()
        for shell in ('bash', 'powershell'):
            with self.subTest(shell=shell, missing=True):
                result = self.invoke(shell, policy=True, cwd=policy.work)
                self.assertEqual(result.returncode, 2)
                self.assertIn('config-invalid', result.stderr)
                self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
