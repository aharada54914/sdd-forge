#!/usr/bin/env python3
"""#812 / V-07: the Concept Test must run from Codex's per-plugin, per-version cache.

Codex installs each plugin listed in `.agents/plugins/marketplace.json` into
its own `<cache>/<marketplace>/<plugin>/<version>/` directory, with no shared
`contracts/` and no sibling `plugins/` directory. This suite stages the product
through the installer (which materializes `plugins/sdd-domain/runtime/`), builds
that per-version cache layout from the marketplace file, and runs both the
shipped Concept Test wrapper and `run-sdd-gate.mjs` against an ordinary DDD
project whose proposal FITS.
"""

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('concept_tests', ROOT / 'tests/concept-test.tests.py')
concept_tests = importlib.util.module_from_spec(spec)
spec.loader.exec_module(concept_tests)

TASKS = ('## T-001 t\nApproval: Approved\nStatus: Implementation Complete\nRisk: standard\n\n'
         '### Scope\n- `src/a.js`\n\n### Done When\n- AC-001\n')


def stage_install_tree(base):
    """Run install.sh --target FilesOnly so per-plugin runtimes are materialized."""
    install_root = Path(base) / 'staged-install'
    result = subprocess.run(
        ['bash', str(ROOT / 'install.sh'), '--source-directory', str(ROOT),
         '--install-root', str(install_root), '--target', 'FilesOnly', '--skip-mcp'],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(f'install.sh FilesOnly failed: {result.stdout}\n{result.stderr}')
    return install_root


def build_versioned_cache(base, source_root=None):
    """Copy every marketplace plugin to <base>/sdd-plugins/<name>/<version>/."""
    origin = Path(source_root) if source_root is not None else ROOT
    marketplace = json.loads((origin / '.agents/plugins/marketplace.json').read_text(encoding='utf-8'))
    installed = {}
    for plugin in marketplace['plugins']:
        source = origin / plugin['source']['path']
        target = Path(base) / 'sdd-plugins' / plugin['name'] / plugin['version']
        shutil.copytree(source, target, symlinks=True)
        installed[plugin['name']] = target
    return installed


class CodexVersionedCacheTests(concept_tests.ConceptTests):
    """Reuses ConceptTests' approved-domain fixture; only the entry points move."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.stage_tmp = tempfile.TemporaryDirectory(prefix='codex-cache-stage-')
        cls.staged_root = stage_install_tree(cls.stage_tmp.name)

    @classmethod
    def tearDownClass(cls):
        cls.stage_tmp.cleanup()
        super().tearDownClass()

    def setUp(self):
        super().setUp()
        self.local_proposal('FITS_EXISTING_CONCEPTS')
        self.write('specs/example/tasks.md', TASKS)
        self.cache = tempfile.TemporaryDirectory()
        self.addCleanup(self.cache.cleanup)
        self.installed = build_versioned_cache(self.cache.name, source_root=self.staged_root)

    def wrapper(self, plugin_root):
        script = plugin_root / 'scripts/validate-concept-test.sh'
        return subprocess.run(['sh', str(script), '--root', str(self.root), '--feature', 'example', '--require-v2'],
                              env=self.env, capture_output=True, text=True, timeout=60)

    def gate(self, quality_root):
        program = ('import(process.argv[1]).then((m) => { const { result } = m.runSddGate('
                   '{ feature: "example", taskId: "T-001", projectRoot: process.argv[2], skipDrift: true, skipSensors: true });'
                   ' console.log(JSON.stringify(result.checks.conceptTest)); })')
        gate = quality_root / 'scripts/v2/run-sdd-gate.mjs'
        result = subprocess.run(['node', '--input-type=module', '-e', program, gate.as_uri(), str(self.root)],
                                env=self.env, capture_output=True, text=True, timeout=120)
        self.assertEqual(0, result.returncode, result.stderr)
        return json.loads(result.stdout.strip().splitlines()[-1])

    def test_flat_checkout_control_continues(self):
        result = self.wrapper(ROOT / 'plugins/sdd-domain')
        self.assertEqual((0, 'CONTINUE'), (result.returncode, result.stdout.strip()), result.stderr)
        self.assertEqual('CONTINUE', self.gate(ROOT / 'plugins/sdd-quality-loop')['status'])

    def test_cache_layout_has_no_shared_contracts_or_plugins_dir(self):
        domain = self.installed['sdd-domain']
        self.assertFalse((domain.parents[1] / 'contracts').exists())
        self.assertFalse((domain.parents[2] / 'plugins').exists())

    def test_versioned_cache_gate_names_the_workaround_when_domain_missing(self):
        # When sdd-domain of the matching version is absent from the cache, the gate stops with actionable guidance.
        shutil.rmtree(self.installed['sdd-domain'])
        check = self.gate(self.installed['sdd-quality-loop'])
        self.assertEqual('BLOCK', check['status'])
        self.assertIn('#812', check['error'])
        self.assertIn('source checkout', check['error'])
        self.assertNotIn('install with install.sh', check['error'])

    def test_versioned_cache_gate_names_the_v1_retirement_before_the_runtime(self):
        # A retired v1 record needs recreating whatever the runtime layout; #812 would mislead.
        shutil.rmtree(self.installed['sdd-domain'])
        self.record['schema'] = 'concept-test/v1'
        self.save()
        for markdown_only in (False, True):
            with self.subTest(markdown_only=markdown_only):
                if markdown_only:
                    (self.feature / 'concept-test.json').unlink()
                check = self.gate(self.installed['sdd-quality-loop'])
                self.assertEqual('BLOCK', check['status'])
                self.assertTrue(check['error'].startswith(
                    'concept-test: BLOCK: ' + concept_tests.V1_RETIRED_PREFIX), check['error'])
                self.assertNotIn('#812', check['error'])
                self.assertNotIn('Git index', check['error'])

    def test_versioned_cache_wrapper_continues(self):
        result = self.wrapper(self.installed['sdd-domain'])
        self.assertEqual((0, 'CONTINUE'), (result.returncode, result.stdout.strip()), result.stderr)

    def test_versioned_cache_gate_continues(self):
        self.assertEqual('CONTINUE', self.gate(self.installed['sdd-quality-loop'])['status'])

    def test_versioned_cache_rejects_mismatched_domain_version(self):
        # Manifest version must match sdd-quality-loop's version; a mismatched manifest is rejected.
        domain_manifest = self.installed['sdd-domain'] / '.codex-plugin/plugin.json'
        data = json.loads(domain_manifest.read_text(encoding='utf-8'))
        data['version'] = '0.0.1-mismatch'
        domain_manifest.write_text(json.dumps(data), encoding='utf-8')
        check = self.gate(self.installed['sdd-quality-loop'])
        self.assertEqual('BLOCK', check['status'])


if __name__ == '__main__':
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(CodexVersionedCacheTests)
    # Run only this class, not the ConceptTests cases it inherits.
    names = [n for n in loader.getTestCaseNames(CodexVersionedCacheTests) if n not in vars(concept_tests.ConceptTests)]
    suite = unittest.TestSuite(CodexVersionedCacheTests(n) for n in names)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
