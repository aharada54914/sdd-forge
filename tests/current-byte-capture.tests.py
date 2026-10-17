#!/usr/bin/env python3
"""Current-product reachability regressions, using real installer/validator calls."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('current_capture', ROOT / 'tests/lib/current-byte-capture.py')
CAPTURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CAPTURE)
CANONICAL = ROOT / 'specs/epic-195-a7-compatibility/verification/golden-baseline/canonical'
GENERATOR = 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py'
RUNTIME = 'powershell' if os.name == 'nt' else 'bash'


class CurrentCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix='sdd-current-source-test-')
        cls.product = Path(cls.scratch.name) / 'product'
        subprocess.run(['git', 'clone', '-q', '--shared', str(ROOT), str(cls.product)], check=True)
        # Test the live candidate, including edits not yet committed.
        source = CAPTURE.indexed_source(ROOT)
        for name, data in source.items():
            target = cls.product / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        subprocess.run(['git', '-C', str(cls.product), 'add', '-f', '--pathspec-from-file=-', '--pathspec-file-nul'],
                       input=('\0'.join(source) + '\0').encode(), check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='sdd-current-fixture-test-')
        self.addCleanup(self.temporary.cleanup)
        self.work = Path(self.temporary.name)
        self.fixture = self.work / 'fixture'
        self.fixture.mkdir()
        self.destination = self.work / 'capture'
        self.edits = {}
        self.addCleanup(self.restore)

    def restore(self):
        for name, data in self.edits.items():
            (self.product / name).write_bytes(data)

    def edit(self, name, text):
        path = self.product / name
        self.edits.setdefault(name, path.read_bytes())
        path.write_text(text, encoding='utf-8')

    def capture(self):
        CAPTURE.capture(self.product, self.fixture, self.destination, CANONICAL, RUNTIME)
        targets = json.loads((CANONICAL / 'manifest.json').read_text())['targets']
        return {row['name'] for row in targets
                if (self.destination / row['path']).read_bytes() !=
                (self.destination / 'expected' / row['path']).read_bytes()}

    def inject_generator(self, statements):
        original = (self.product / GENERATOR).read_text()
        self.edit(GENERATOR, original.replace('if __name__ == "__main__":', statements + '\nif __name__ == "__main__":'))

    def test_real_f1_and_f2_fixture_cwd_and_marker_reach_current_generator(self):
        for marker in (None, b'spec_profile: lite\n'):
            with self.subTest(marker=marker):
                if self.destination.exists():
                    shutil.rmtree(self.destination)
                if marker:
                    (self.fixture / 'AGENTS.md').write_bytes(marker)
                statements = (f'assert Path.cwd() == Path({str(self.fixture)!r})\n'
                              'assert not Path("sdd/project-context.yaml").exists()\n'
                              f'assert (Path("AGENTS.md").read_bytes() if Path("AGENTS.md").exists() else None) == {marker!r}')
                if GENERATOR in self.edits:
                    (self.product / GENERATOR).write_bytes(self.edits[GENERATOR])
                self.inject_generator(statements)
                self.assertEqual(set(), self.capture())
                self.assertEqual({'AGENTS.md'} if marker else set(), {p.name for p in self.fixture.iterdir()})

    def test_product_project_metadata_cannot_populate_absent_context_fixture(self):
        names = ('sdd/project-context.yaml', 'sdd/approver-registry.yaml')
        originals = {name: (self.product / name).read_bytes() if (self.product / name).exists() else None for name in names}
        def restore_metadata():
            subprocess.run(['git', '-C', str(self.product), 'reset', '-q', 'HEAD', '--', *names], check=True)
            for name, data in originals.items():
                if data is None:
                    (self.product / name).unlink(missing_ok=True)
                else:
                    (self.product / name).write_bytes(data)
        self.addCleanup(restore_metadata)
        for name in names:
            path = self.product / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('fixture_project_metadata: true\n', encoding='utf-8')
        subprocess.run(['git', '-C', str(self.product), 'add', '-f', '--', *names], check=True)
        (self.fixture / 'AGENTS.md').write_bytes(b'spec_profile: lite\n')
        self.inject_generator('assert not Path("sdd/project-context.yaml").exists()\n'
                              'assert not Path("sdd/approver-registry.yaml").exists()\n'
                              'assert Path("AGENTS.md").read_bytes() == b"spec_profile: lite\\n"')
        self.assertEqual(set(), self.capture())
        installed = (self.destination / 'targets/install-result.sha256').read_text()
        for name in names:
            self.assertNotIn('  ' + name + '\n', installed)

    def test_product_cannot_create_context_during_absent_context_capture(self):
        self.inject_generator('Path("sdd").mkdir(exist_ok=True)\n'
                              'Path("sdd/project-context.yaml").write_bytes(b"unexpected")')
        with self.assertRaisesRegex(ValueError, 'changed absent-Context fixture inputs'):
            self.capture()

    def test_uncommitted_generator_output_and_exit_are_detected(self):
        self.edit(GENERATOR, 'print("CURRENT_PRODUCT_REGRESSION")\nraise SystemExit(42)\n')
        self.assertTrue({'exit-code', 'stdout-stderr', 'deterministic-script-output'} <= self.capture())

    def test_current_validator_must_reject_invalid_contract(self):
        extension = '.ps1' if RUNTIME == 'powershell' else '.sh'
        self.edit('plugins/sdd-domain/scripts/validate-domain-contract' + extension, 'exit 0\n')
        with self.assertRaisesRegex(ValueError, 'did not reject invalid contract'):
            self.capture()

    def test_current_validator_must_accept_valid_contract(self):
        extension = '.ps1' if RUNTIME == 'powershell' else '.sh'
        code = '[Console]::Error.WriteLine("rejected"); exit 1\n' if RUNTIME == 'powershell' else 'echo rejected >&2\nexit 1\n'
        self.edit('plugins/sdd-domain/scripts/validate-domain-contract' + extension, code)
        self.assertIn('schema-validator-result', self.capture())

    def test_installer_missing_extra_and_corrupt_payload_are_detected(self):
        name = 'install.ps1' if RUNTIME == 'powershell' else 'install.sh'
        if RUNTIME == 'powershell':
            # Mutate real installed payload immediately before success returns.
            text = (self.product / name).read_text()
            self.assertIn('$resolvedInstallRoot', text)
            mutation = '\nRemove-Item (Join-Path $resolvedInstallRoot "README.md")\n[IO.File]::WriteAllText((Join-Path $resolvedInstallRoot "unexpected.txt"), "extra")\n[IO.File]::WriteAllText((Join-Path $resolvedInstallRoot "PLUGIN-CONTRACTS.md"), "corrupt")\n'
        else:
            text = (self.product / name).read_text()
            mutation = '\nrm "$RESOLVED_INSTALL_ROOT/README.md"\nprintf extra > "$RESOLVED_INSTALL_ROOT/unexpected.txt"\nprintf corrupt > "$RESOLVED_INSTALL_ROOT/PLUGIN-CONTRACTS.md"\n'
        self.edit(name, text + mutation)
        self.assertIn('install-result', self.capture())

    def test_copy_and_generated_listing_use_preexecution_source_oracles(self):
        template = next(name for name in CAPTURE.indexed_source(self.product) if name.startswith('plugins/') and '/templates/' in name)
        plugin = next(name for name in CAPTURE.indexed_source(self.product) if '/.claude-plugin/plugin.json' in name)
        self.inject_generator(f'Path({template!r}).write_bytes(b"corrupt")\n'
                              f'Path({plugin!r}).write_bytes(b"corrupt")\n'
                              f'Path({str(Path(template).parent / "unexpected.txt")!r}).write_bytes(b"extra")\n'
                              'Path("plugins/unexpected/.claude-plugin").mkdir(parents=True)\n'
                              'Path("plugins/unexpected/.claude-plugin/plugin.json").write_bytes(b"extra")\n'
                              'Path("plugins/sdd-quality-loop/scripts/generated/unexpected.txt").write_bytes(b"extra")')
        self.assertTrue({'template-copy-result', 'plugin-manifest', 'install-result', 'generated-directory-listing'} <= self.capture())
        self.assertIn(b'unexpected.txt', (self.destination / 'targets/template-copy-result.sha256').read_bytes())
        self.assertIn(b'plugins/unexpected/', (self.destination / 'targets/plugin-manifest.sha256').read_bytes())

    def test_current_source_data_additions_and_edits_are_copied_exactly(self):
        template = next(name for name in CAPTURE.indexed_source(self.product) if name.startswith('plugins/') and '/templates/' in name)
        self.edit(template, (self.product / template).read_text() + '\nCurrent input bytes.\n')
        self.assertEqual(set(), self.capture())

    def run_suite(self, env):
        if RUNTIME == 'powershell':
            command = [shutil.which('pwsh') or shutil.which('powershell'), '-NoProfile', '-File', str(ROOT / 'tests/compatibility-byte-identical.tests.ps1')]
        else:
            command = ['bash', str(ROOT / 'tests/compatibility-byte-identical.tests.sh')]
        return subprocess.run(command, env=dict(os.environ, T003_PRODUCT_ROOT_UNDER_TEST=str(self.product), **env), capture_output=True, text=True)

    def test_cached_directories_cannot_hide_current_product_regression(self):
        cache = self.work / 'old-cache'
        for row in ('F1', 'F2'):
            for invocation in (1, 2):
                shutil.copytree(CANONICAL, cache / f'{row}-invocation-{invocation}')
        self.edit(GENERATOR, 'print("CURRENT_PRODUCT_REGRESSION")\nraise SystemExit(42)\n')
        result = self.run_suite({'T003_CAPTURE_CACHE': str(cache)})
        self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn('FAIL: F1 exit-code', result.stdout)
        self.assertIn('FAIL: F2 exit-code', result.stdout)

    def test_matching_wrong_cli_documents_cannot_define_expected_behavior(self):
        for name in ('plugins/sdd-ship/skills/ship/SKILL.md', 'PLUGIN-CONTRACTS.md'):
            text = (self.product / name).read_text()
            self.edit(name, text.replace('FULL', 'LITE'))
        result = self.run_suite({})
        self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn('FAIL: CLI cell none|absent', result.stdout)
        self.assertIn('FAIL: CLI cell --full|present', result.stdout)


if __name__ == '__main__':
    unittest.main()
