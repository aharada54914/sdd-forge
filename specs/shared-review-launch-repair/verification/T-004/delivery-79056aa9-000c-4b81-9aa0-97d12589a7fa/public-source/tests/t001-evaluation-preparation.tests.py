"""Caller preparation preserves old reports and validates updates before delivery."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FEATURE = 'shared-review-launch-repair'
PREPARE = 'reports/verification/shared-launch-handoff/prepare-t001-evaluation.py'


class PreparationTests(unittest.TestCase):
    task = 'T-001'
    prepare = PREPARE
    output_count = 30
    handoff_suffix = 'T-001'

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in (self.prepare, 'plugins/sdd-quality-loop/scripts/supplemental-delivery-inputs.py',
                     'plugins/sdd-quality-loop/scripts/review-conditional-inputs.py'):
            self.write(name, (ROOT / name).read_bytes())
        self.write('plugins/sdd-quality-loop/references/quality-gate-calibration.md', b'calibration')
        self.write(f'handoffs/{FEATURE}-{self.handoff_suffix}/manifest.json', b'{}')
        self.paths = [f'plugins/product/file-{i}.py' for i in range(self.output_count)]
        for name in self.paths:
            self.write(name, b'original')
        self.report = f'reports/implementation/{FEATURE}/{self.task}.md'
        self.write(self.report, ('## Outputs\n' + ''.join(
            f'| `{name}` | `{self.pin(name)["sha256"]}` |\n' for name in self.paths)).encode())
        self.report_before = (self.root / self.report).read_bytes()
        self.ledger = 'reports/review-context/identity-ledger.json'
        self.write(self.ledger, b'{"records":[{"sequence":1,"record_sha256":"old"}]}')
        self.ledger_before = (self.root / self.ledger).read_bytes()
        self.declaration = f'specs/{FEATURE}/verification/{self.task}/delivery.json'

    def write(self, name, raw):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)

    def pin(self, name):
        return {'path': name, 'sha256': hashlib.sha256((self.root / name).read_bytes()).hexdigest()}

    def supplement(self):
        return {'schema': 'supplemental-delivery-declaration/v1', 'feature': FEATURE,
                'task_id': self.task, 'implementation_report': self.pin(self.report),
                'artifacts': [self.pin(self.paths[0])]}

    def run_preparation(self, expected, declaration=None):
        args = [sys.executable, '-B', str(self.root / self.prepare)]
        if declaration is not None:
            raw = declaration if isinstance(declaration, bytes) else json.dumps(declaration).encode()
            self.write(self.declaration, raw)
            args += ['--supplemental', self.declaration]
        result = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, expected, result.stderr)
        self.assertEqual((self.root / self.ledger).read_bytes(), self.ledger_before)
        self.assertEqual((self.root / self.report).read_bytes(), self.report_before)
        if expected:
            output = json.loads(result.stdout)
            self.addCleanup(shutil.rmtree, output['scratch'])
            document = json.loads(Path(output['invocation']).read_text())
            for entry in document['allowed_input_manifest']:
                self.assertEqual(self.pin(entry['path']), entry)
        else:
            self.assertEqual(list((self.root / 'reports/review-context').glob('shared-launch-*.json')), [])

    def test_legacy_valid(self):
        self.run_preparation(True)

    def test_undeclared_update_rejected(self):
        self.write(self.paths[0], b'updated')
        self.run_preparation(False)

    def test_declared_update_admitted(self):
        self.write(self.paths[0], b'updated')
        self.run_preparation(True, self.supplement())

    def test_stale_pin_rejected(self):
        declaration = self.supplement()
        self.write(self.paths[0], b'updated')
        self.run_preparation(False, declaration)

    def test_missing_input_rejected(self):
        declaration = self.supplement()
        (self.root / self.paths[1]).unlink()
        self.run_preparation(False, declaration)

    def test_cross_feature_rejected(self):
        name = 'specs/other/requirements.md'
        self.write(name, b'other')
        declaration = self.supplement()
        declaration['artifacts'].append(self.pin(name))
        self.run_preparation(False, declaration)

    def test_duplicate_path_rejected(self):
        declaration = self.supplement()
        declaration['artifacts'] *= 2
        self.run_preparation(False, declaration)

    def test_duplicate_json_rejected(self):
        field = f'"task_id": "{self.task}"'
        raw = json.dumps(self.supplement()).replace(field, f'{field}, {field}')
        self.run_preparation(False, raw.encode())


class T005PreparationTests(PreparationTests):
    task = 'T-005'
    prepare = 'reports/verification/shared-launch-handoff/prepare-t005-evaluation.py'
    output_count = 32
    handoff_suffix = 'T-005-attempt-6'


if __name__ == '__main__':
    unittest.main()
