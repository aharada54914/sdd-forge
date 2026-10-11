#!/usr/bin/env python3
"""Exercise the actual paired admission paths without reserving identities."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.report = 'reports/implementation/f/T-001.md'
        self.declaration = 'specs/f/verification/T-001/delivery.json'
        self.product = 'plugins/task/product.py'
        self.write(self.report, '# Implementation Report: T-001\n- Task ID: T-001\n## Outputs\n')
        self.write(self.product, 'print("product")\n')
        record = dict(sequence=1, stage='implementation', role='implementer', run_id='implementation-run', host_session_id='implementation-session', previous_record_sha256='')
        record['record_sha256'] = digest(b'1|implementation|implementer|implementation-run|implementation-session|')
        self.ledger = 'reports/review-context/identity-ledger.json'
        self.write(self.ledger, json.dumps(dict(schema='review-identity-ledger/v1', records=[record])))
        self.body = dict(schema='supplemental-delivery-declaration/v1', feature='f', task_id='T-001', implementation_report=self.entry(self.report), artifacts=[self.entry(self.product)])
        self.manifest = dict(schema='review-context-invocation/v2', stage='quality', role='sdd-evaluator', feature='f', task_id='T-001', run_id='evaluator-run', host_session_id='evaluator-session', read_only=True, input_mode='file-manifest', fallback_mode='none', identity_ledger_path=self.ledger, identity_ledger_sha256=self.entry(self.ledger)['sha256'], previous_record_sha256=record['record_sha256'], sequence=2)

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def entry(self, path):
        return dict(path=path, sha256=digest((self.root / path).read_bytes()))

    def run_pair(self, valid, raw=None, omit=False, legacy=False, pointer_link=False):
        self.write(self.declaration, raw if raw is not None else json.dumps(self.body))
        self.manifest['supplemental_delivery_declaration'] = self.entry(self.declaration)
        self.manifest['allowed_input_manifest'] = [self.entry(self.report), self.entry(self.product)]
        if not omit:
            self.manifest['allowed_input_manifest'].append(self.entry(self.declaration))
        if legacy:
            del self.manifest['supplemental_delivery_declaration']
            self.manifest['allowed_input_manifest'].pop()
        if pointer_link:
            original = self.root / self.declaration
            original.rename(original.with_suffix('.original'))
            original.symlink_to(original.with_suffix('.original').name)
        self.write('manifest.json', json.dumps(self.manifest))
        before = (self.root / self.ledger).read_bytes()
        commands = [['bash', str(SCRIPTS / 'validate-review-context-set.sh'), str(self.root / 'manifest.json'), str(self.root)]]
        self.assertIsNotNone(shutil.which('pwsh'), 'PowerShell required for parity test')
        commands.append(['pwsh', '-NoLogo', '-NoProfile', '-File', str(SCRIPTS / 'validate-review-context-set.ps1'), '-Manifest', str(self.root / 'manifest.json'), '-RepositoryRoot', str(self.root)])
        for command in commands:
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode == 0, valid, result.stdout + result.stderr)
            self.assertEqual((self.root / self.ledger).read_bytes(), before)
            if not valid:
                result = subprocess.run(command + (['--reserve'] if command[0] == 'bash' else ['-Reserve']), capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.root / self.ledger).read_bytes(), before)

    def test_valid(self):
        self.run_pair(True)

    def test_legacy_outputs(self):
        pin = self.entry(self.product)
        self.write(self.report, '# Implementation Report: T-001\n- Task ID: T-001\n## Outputs\n| `' + pin['path'] + '` | `' + pin['sha256'] + '` |\n')
        self.run_pair(True, legacy=True)

    def test_pointer_symlink(self):
        self.run_pair(False, pointer_link=True)

    def test_extra_verdict(self):
        self.body['verdict'] = 'PASS'
        self.run_pair(False)

    def test_cross_feature_path(self):
        self.write('specs/g/requirements.md', 'other feature')
        self.body['artifacts'].append(self.entry('specs/g/requirements.md'))
        self.run_pair(False)

    def test_reviewer_output(self):
        self.write('reports/spec-review/f/reviewer-a.json', '{}')
        self.body['artifacts'].append(self.entry('reports/spec-review/f/reviewer-a.json'))
        self.run_pair(False)

    def test_wrong_task(self):
        self.body['task_id'] = 'T-002'
        self.run_pair(False)

    def test_wrong_feature(self):
        self.body['feature'] = 'g'
        self.run_pair(False)

    def test_report_hash(self):
        self.body['implementation_report']['sha256'] = '0' * 64
        self.run_pair(False)

    def test_duplicate_path(self):
        self.body['artifacts'] *= 2
        self.run_pair(False)

    def test_duplicate_json(self):
        self.run_pair(False, json.dumps(self.body).replace('"feature": "f"', '"feature": "f", "feature": "f"'))

    def test_unpinned_declaration(self):
        self.run_pair(False, omit=True)

    def test_traversal(self):
        self.body['artifacts'][0]['path'] = 'plugins/task/../task/product.py'
        self.run_pair(False)

    def test_absolute(self):
        self.body['artifacts'][0]['path'] = str(self.root / self.product)
        self.run_pair(False)

    def test_symlink(self):
        (self.root / 'plugins/task/link.py').symlink_to('product.py')
        self.body['artifacts'][0]['path'] = 'plugins/task/link.py'
        self.run_pair(False)

    def test_gate_output(self):
        self.write('reports/quality-gate/other.md', 'not input')
        self.body['artifacts'].append(self.entry('reports/quality-gate/other.md'))
        self.run_pair(False)

    def test_artifact_hash(self):
        self.body['artifacts'][0]['sha256'] = '0' * 64
        self.run_pair(False)


if __name__ == '__main__':
    unittest.main()
