#!/usr/bin/env python3
"""#812: the Concept Test must run from Codex's per-plugin, per-version cache.

Codex installs each plugin listed in `.agents/plugins/marketplace.json` into
its own `<cache>/<marketplace>/<plugin>/<version>/` directory, with no shared
`contracts/` and no sibling `plugins/` directory. This suite rebuilds that
layout from the marketplace file and runs the shipped Concept Test entry
points against an ordinary DDD project whose proposal FITS.

The flat checkout (the `install.sh` layout) is the control and must pass. The
versioned-cache cases document #812 and are expected failures until it is
fixed; an unexpected success fails the run, so the markers must then go.
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


def build_versioned_cache(base):
    """Copy every marketplace plugin to <base>/sdd-plugins/<name>/<version>/."""
    marketplace = json.loads((ROOT / '.agents/plugins/marketplace.json').read_text(encoding='utf-8'))
    installed = {}
    for plugin in marketplace['plugins']:
        source = ROOT / plugin['source']['path']
        target = Path(base) / 'sdd-plugins' / plugin['name'] / plugin['version']
        shutil.copytree(source, target, symlinks=True)
        installed[plugin['name']] = target
    return installed


class CodexVersionedCacheTests(concept_tests.ConceptTests):
    """Reuses ConceptTests' approved-domain fixture; only the entry points move."""

    def setUp(self):
        super().setUp()
        self.local_proposal('FITS_EXISTING_CONCEPTS')
        self.write('specs/example/tasks.md', TASKS)
        self.cache = tempfile.TemporaryDirectory()
        self.addCleanup(self.cache.cleanup)
        self.installed = build_versioned_cache(self.cache.name)

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

    def test_versioned_cache_gate_names_the_workaround(self):
        # Until #812 is fixed the gate must say why it stopped and how to get going.
        check = self.gate(self.installed['sdd-quality-loop'])
        self.assertEqual('BLOCK', check['status'])
        self.assertIn('#812', check['error'])
        self.assertIn('install.sh', check['error'])

    @unittest.expectedFailure  # #812: the wrapper reaches ../../sdd-quality-loop and repo-level contracts/.
    def test_versioned_cache_wrapper_continues(self):
        result = self.wrapper(self.installed['sdd-domain'])
        self.assertEqual((0, 'CONTINUE'), (result.returncode, result.stdout.strip()), result.stderr)

    @unittest.expectedFailure  # #812: the gate resolves ../../../sdd-domain from its own version directory.
    def test_versioned_cache_gate_continues(self):
        self.assertEqual('CONTINUE', self.gate(self.installed['sdd-quality-loop'])['status'])


if __name__ == '__main__':
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(CodexVersionedCacheTests)
    # Run only this class, not the ConceptTests cases it inherits.
    names = [n for n in loader.getTestCaseNames(CodexVersionedCacheTests) if n not in vars(concept_tests.ConceptTests)]
    suite = unittest.TestSuite(CodexVersionedCacheTests(n) for n in names)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
