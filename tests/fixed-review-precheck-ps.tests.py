#!/usr/bin/env python3
"""Run real PowerShell prechecks against Git-backed selected input snapshots."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-review-loop/scripts'
spec = importlib.util.spec_from_file_location('fixed_precheck_inputs', SCRIPTS / 'fixed-review-inputs.py')
fixed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixed)


def sha(data):
    return hashlib.sha256(data).hexdigest()


@unittest.skipUnless(shutil.which('pwsh'), 'pwsh unavailable')
class FixedPowerShellPrechecks(unittest.TestCase):
    def fixture(self, stage, *, normalized=False, omitted=None, layers=False, adr=False):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        base = Path(temp.name)
        repo = base / 'repo'
        repo.mkdir()
        shutil.copytree(SCRIPTS, repo / 'plugins/sdd-review-loop/scripts')
        contents = {
            'requirements.md': b'Spec-Review-Status: Pending\n',
            'acceptance-tests.md': b'acceptance\n',
            'design.md': b'design\n',
            'tasks.md': b'## T-001\nStatus: Planned\nApproval: Draft\n',
            'investigation.md': b'investigation\n',
        }
        layer_names = ('ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md')
        if normalized:
            contents['tasks.md'] = b'## T-001\nStatus: Done\nApproval: Approved\n'
        if layers:
            contents['requirements.md'] += b'## REQ-001\n'
            contents.update({name: b'layer\n' for name in layer_names})
            contents['traceability.md'] = (
                b'| Requirement | Design | Layer Spec |\n|---|---|---|\n'
                b'| REQ-001 | D | ux-spec.md#journey |\n')
        if adr:
            contents['design.md'] = b'ADR: `docs/adr/0001-example.md`\n'
        paths = []
        for name, data in contents.items():
            path = repo / 'specs/example' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            paths.append(str(path.relative_to(repo)))
        if adr:
            adr_path = repo / 'docs/adr/0001-example.md'
            adr_path.parent.mkdir(parents=True)
            adr_path.write_bytes(b'ADR bytes\n')
            paths.append('docs/adr/0001-example.md')
        calibration = 'plugins/sdd-review-loop/references/spec-review-calibration.md'
        (repo / calibration).parent.mkdir(parents=True)
        (repo / calibration).write_bytes(b'calibration\n')
        paths.append(calibration)
        (repo / 'specs/workflow-state-registry.json').write_text('{"entries":[]}')
        def git(*args):
            return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()
        git('init', '-q')
        git('add', 'specs', calibration, *(['docs'] if adr else []))
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
            'commit', '-qm', 'fixture')
        snapshot = base / 'snapshot'
        inventory = base / 'inventory.json'
        fixed.prepare(repo, git('rev-parse', 'HEAD'),
                      [p for p in paths if not p.endswith('/' + str(omitted))], snapshot, inventory)
        record = {'schema': stage + '-review-precheck/v1', 'feature': 'example',
                  'attempt': 1, 'round': 1,
                  'requirements_sha256': sha(contents['requirements.md']),
                  'acceptance_sha256': sha(contents['acceptance-tests.md'])}
        if stage == 'spec':
            record.update(stage='spec', spec_review_status_field='Pending',
                          investigation_sha256=sha(contents['investigation.md']),
                          calibration_sha256=sha(b'calibration\n'), edit_summary='',
                          reset=False, generated_at='2026-10-13T00:00:00Z')
            record['input_sha256'] = sha((':'.join(record[k] for k in
                ('requirements_sha256', 'acceptance_sha256', 'investigation_sha256'))).encode())
        elif stage == 'impl':
            record['design_sha256'] = sha(contents['design.md'])
        else:
            record['tasks_sha256'] = sha(contents['tasks.md'])
            if normalized:
                record['tasks_sha256_form'] = 'normalized'
                record['tasks_sha256'] = sha(b'## T-001\nStatus: Planned\nApproval: Draft\n')
        if layers:
            record['layer_sha256'] = {name: sha(contents[name]) for name in layer_names}
            record['design_sha256'] = sha(contents['design.md'])
            record['traceability_sha256'] = sha(contents['traceability.md'])
        if adr:
            record['layer_sha256'] = {}
            record['adr_inputs'] = [{'path': 'docs/adr/0001-example.md', 'sha256': sha(b'ADR bytes\n')}]
            material = ':'.join(record[k] for k in ('design_sha256', 'requirements_sha256', 'acceptance_sha256'))
            material += ':adr_inputs/v1:' + json.dumps(record['adr_inputs'], separators=(',', ':'))
            record['input_sha256'] = sha(material.encode())
        report = repo / f'reports/{stage}-review/example/attempt-1/round-1/precheck-result.json'
        report.parent.mkdir(parents=True)
        report.write_text(json.dumps(record))
        argv = ['pwsh', '-NoProfile', '-File', str(repo / 'plugins/sdd-review-loop/scripts' /
                (stage + '-review-precheck.ps1')), '-Feature', 'example', '-Attempt', '1',
                '-Round', '1', '-VerifyInputs']
        return repo, snapshot, report, argv, ['-FixedInputRecord', str(inventory),
                                            '-FixedInputSnapshot', str(snapshot)]

    def run_check(self, argv, success):
        result = subprocess.run(argv, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def test_fixed_sources_ignore_dirty_live_inputs_and_keep_live_evidence(self):
        for stage in ('spec', 'impl', 'task'):
            with self.subTest(stage=stage):
                repo, snapshot, report, argv, flags = self.fixture(stage)
                self.run_check(argv, True)
                self.run_check(argv + flags, True)
                (repo / 'specs/example/requirements.md').write_text('dirty\n')
                self.run_check(argv, False)
                self.run_check(argv + flags, True)
                record = json.loads(report.read_text())
                record['requirements_sha256'] = '0' * 64
                report.write_text(json.dumps(record))
                self.run_check(argv + flags, False)

    def test_missing_and_tampered_snapshot_inputs_rejected(self):
        for stage in ('spec', 'impl', 'task'):
            with self.subTest(stage=stage):
                _, snapshot, _, argv, flags = self.fixture(stage, omitted='acceptance-tests.md')
                self.run_check(argv + flags, False)
                _, snapshot, _, argv, flags = self.fixture(stage)
                target = snapshot / 'specs/example/acceptance-tests.md'
                target.chmod(0o644)
                target.write_text('changed\n')
                self.run_check(argv + flags, False)

    def test_pair_and_verify_only_options(self):
        for stage in ('spec', 'impl', 'task'):
            with self.subTest(stage=stage):
                _, _, _, argv, flags = self.fixture(stage)
                self.run_check(argv + flags[:2], False)
                self.run_check(argv + flags[2:], False)
                self.run_check([arg for arg in argv if arg != '-VerifyInputs'] + flags, False)

    def test_normalized_task_hash_contract(self):
        _, _, _, argv, flags = self.fixture('task', normalized=True)
        self.run_check(argv + flags, True)

    def test_layers_and_traceability_use_selected_sources(self):
        for stage in ('impl', 'task'):
            with self.subTest(stage=stage):
                repo, _, _, argv, flags = self.fixture(stage, layers=True)
                self.run_check(argv + flags, True)
                for name in ('ux-spec.md', 'traceability.md', 'design.md'):
                    (repo / 'specs/example' / name).write_text('dirty\n')
                self.run_check(argv + flags, True)
                _, _, _, argv, flags = self.fixture(stage, layers=True, omitted='ux-spec.md')
                self.run_check(argv + flags, False)

    def test_adr_uses_selected_source(self):
        repo, _, _, argv, flags = self.fixture('impl', adr=True)
        self.run_check(argv + flags, True)
        (repo / 'docs/adr/0001-example.md').write_text('dirty\n')
        self.run_check(argv + flags, True)
        _, _, _, argv, flags = self.fixture('impl', adr=True, omitted='0001-example.md')
        self.run_check(argv + flags, False)


if __name__ == '__main__':
    unittest.main()
