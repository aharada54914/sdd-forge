#!/usr/bin/env python3
"""Exercise installed review gates against independent consumer projects (#726)."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
PLUGIN = REPO / 'plugins/sdd-review-loop'
PWSH = os.environ.get('PWSH', shutil.which('pwsh') or '/workspace/.tools/sdd-forge-dev/bin/pwsh')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(root):
    return {str(path.relative_to(root)): (digest(path) if path.is_file() else 'directory')
            for path in root.rglob('*')}


class InstalledPrecheckTests(unittest.TestCase):
    def run_case(self, engine, layout, explicit=False):
        with tempfile.TemporaryDirectory(prefix='review install space ') as temporary:
            base = Path(temporary)
            installation = base / 'installed'
            plugin = installation / ('plugins/sdd-review-loop' if layout == 'flat' else 'cache/sdd-plugins/sdd-review-loop/1.23.1')
            shutil.copytree(PLUGIN, plugin)
            # A plausible decoy must never become the consumer root or output root.
            for root in [installation, installation / 'cache/sdd-plugins']:
                (root / 'specs/task-board').mkdir(parents=True, exist_ok=True)
                (root / 'specs/task-board/requirements.md').write_text('Spec-Review-Status: Pending\nwrong installation input\n', encoding='utf-8')
                (root / 'specs/task-board/acceptance-tests.md').write_text('wrong installation acceptance\n', encoding='utf-8')
                (root / 'reports').mkdir(exist_ok=True)
            before = snapshot(installation)
            consumer = base / "consumer app $dollar 'quoted'"
            spec = consumer / 'specs/task-board'
            spec.mkdir(parents=True)
            (consumer / 'reports').mkdir()
            requirements = spec / 'requirements.md'
            requirements.write_text('Spec-Review-Status: Pending\nREQ-001: add a task\n', encoding='utf-8')
            (spec / 'acceptance-tests.md').write_text('AC-001: task appears\n', encoding='utf-8')
            script = (PLUGIN if explicit else plugin) / ('scripts/spec-review-precheck.' + ('sh' if engine == 'bash' else 'ps1'))
            command = ([engine, str(script), 'task-board', '1', '1'] if engine == 'bash' else
                       [PWSH, '-NoProfile', '-File', str(script), '-Feature', 'task-board', '-Attempt', '1', '-Round', '1'])
            if explicit:
                command += [('--repository-root' if engine == 'bash' else '-RepositoryRoot'), str(consumer)]
            cwd = base if explicit else consumer
            result = subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            evidence = consumer / 'reports/spec-review/task-board/attempt-1/round-1/precheck-result.json'
            report = json.loads(evidence.read_text(encoding='utf-8'))
            self.assertEqual(report['requirements_sha256'], digest(requirements))
            self.assertEqual(report['calibration_sha256'], digest((PLUGIN if explicit else plugin) / 'references/spec-review-calibration.md'))
            projected = consumer / 'plugins/sdd-review-loop/references/spec-review-calibration.md'
            self.assertEqual(projected.read_bytes(), ((PLUGIN if explicit else plugin) / 'references/spec-review-calibration.md').read_bytes())
            self.assertFalse((consumer / 'plugins/sdd-review-loop/scripts').exists())
            verify = command + [('--verify-inputs' if engine == 'bash' else '-VerifyInputs')]
            result = subprocess.run(verify, cwd=cwd, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            expected_reference = projected.read_bytes()
            projected.write_bytes(b'changed installed reference projection')
            result = subprocess.run(verify, cwd=cwd, text=True, capture_output=True, check=False)
            self.assertNotEqual(result.returncode, 0, 'modified projection was accepted')
            self.assertEqual(projected.read_bytes(), b'changed installed reference projection')
            projected.write_bytes(expected_reference)
            # Drift must still be detected after resolving roots.
            requirements.write_text(requirements.read_text(encoding='utf-8') + 'changed\n', encoding='utf-8')
            result = subprocess.run(verify, cwd=cwd, text=True, capture_output=True, check=False)
            self.assertNotEqual(result.returncode, 0, 'changed consumer inputs were accepted')
            self.assertEqual(snapshot(installation), before, 'installed assets or decoys were modified')
            self.assertFalse((REPO / 'reports/spec-review/task-board').exists(), 'source checkout received consumer output')

    def test_installed_impl_and_task_input_verification(self):
        engines = ['bash'] + (['powershell'] if Path(PWSH).is_file() else [])
        for engine in engines:
            for stage in ['impl', 'task']:
                with self.subTest(engine=engine, stage=stage), tempfile.TemporaryDirectory() as temporary:
                    base = Path(temporary)
                    cache = base / 'cache'
                    plugin = cache / 'sdd-review-loop/1.23.1'
                    shutil.copytree(PLUGIN, plugin)
                    shutil.copytree(REPO / 'plugins/sdd-quality-loop/references', cache / 'sdd-quality-loop/1.23.1/references')
                    before = snapshot(cache)
                    consumer = base / 'consumer'
                    spec = consumer / 'specs/task-board'
                    spec.mkdir(parents=True)
                    contents = {'requirements.md': 'REQ-001: task management', 'acceptance-tests.md': 'AC-001: task appears',
                                'design.md': '# Design', 'tasks.md': '# Tasks',
                                'traceability.md': '| Requirement | Layer Spec |\n|---|---|\n| REQ-001 | ux-spec.md#scope |\n'}
                    layers = ['ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md']
                    contents.update({name: '# Scope' for name in layers})
                    for name, content in contents.items():
                        (spec / name).write_text(content, encoding='utf-8')
                    (consumer / 'specs/workflow-state-registry.json').write_text(json.dumps({'entries': [{'feature': 'task-board', 'profile': 'full'}]}), encoding='utf-8')
                    precheck = {'schema': stage + '-review-precheck/v1', 'feature': 'task-board', 'attempt': 1, 'round': 1,
                                'layer_sha256': {name: digest(spec / name) for name in layers}}
                    for field, name in [('requirements', 'requirements.md'), ('acceptance', 'acceptance-tests.md'),
                                        ('design', 'design.md'), ('tasks', 'tasks.md'), ('traceability', 'traceability.md')]:
                        precheck[field + '_sha256'] = digest(spec / name)
                    report = consumer / f'reports/{stage}-review/task-board/attempt-1/round-1/precheck-result.json'
                    report.parent.mkdir(parents=True)
                    report.write_text(json.dumps(precheck), encoding='utf-8')
                    prepare = ['python3', str(plugin / 'scripts/prepare-review-assets.py'), '--root', str(consumer), '--stage', stage]
                    result = subprocess.run(prepare, capture_output=True, text=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    script = plugin / f'scripts/{stage}-review-precheck.'
                    command = (['bash', str(script) + 'sh', 'task-board', '1', '1', '--verify-inputs', '--repository-root', str(consumer)]
                               if engine == 'bash' else [PWSH, '-NoProfile', '-File', str(script) + 'ps1', '-Feature', 'task-board', '-Attempt', '1', '-Round', '1', '-VerifyInputs', '-RepositoryRoot', str(consumer)])
                    result = subprocess.run(command, cwd=base, capture_output=True, text=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    (spec / 'ux-spec.md').write_text('tampered layer', encoding='utf-8')
                    result = subprocess.run(command, cwd=base, capture_output=True, text=True, check=False)
                    self.assertNotEqual(result.returncode, 0, 'changed layer was accepted')
                    self.assertEqual(snapshot(cache), before)

    def test_projection_refuses_links_and_conflicts_without_overwriting(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = base / 'consumer'
            root.mkdir()
            outside = base / 'outside'
            outside.mkdir()
            (root / 'plugins').symlink_to(outside, target_is_directory=True)
            command = ['python3', str(PLUGIN / 'scripts/prepare-review-assets.py'), '--root', str(root), '--stage', 'spec']
            result = subprocess.run(command, capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(outside.iterdir()), [])
            (root / 'plugins').unlink()
            target = root / 'plugins/sdd-review-loop/references/spec-review-calibration.md'
            target.parent.mkdir(parents=True)
            target.write_text('consumer-owned conflicting bytes', encoding='utf-8')
            result = subprocess.run(command, capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_text(encoding='utf-8'), 'consumer-owned conflicting bytes')

    def test_bash_installed_and_checkout_override(self):
        for layout in ['flat', 'cache']:
            with self.subTest(layout=layout):
                self.run_case('bash', layout)
        self.run_case('bash', 'cache', explicit=True)

    @unittest.skipUnless(Path(PWSH).is_file(), 'PowerShell executable unavailable')
    def test_powershell_installed_and_checkout_override(self):
        for layout in ['flat', 'cache']:
            with self.subTest(layout=layout):
                self.run_case('powershell', layout)
        self.run_case('powershell', 'cache', explicit=True)


if __name__ == '__main__':
    unittest.main()
