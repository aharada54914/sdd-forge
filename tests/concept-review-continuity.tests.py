#!/usr/bin/env python3
"""Concept evidence survives real admission, prechecks and persisted validation."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


workflow = load('workflow_fixture', ROOT / 'tests/workflow-conditional-inputs.tests.py')
concept = load('concept_fixture', ROOT / 'tests/concept-test.tests.py')
launcher = load('concept_launcher', ROOT / 'plugins/sdd-review-loop/scripts/launch-impl-review.py')


class PersistedConcept(workflow.WorkflowFixture, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        for relative in ('plugins/sdd-domain/scripts/validate-concept-test.py',
                         'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py',
                         'contracts/concept-test.v1.schema.json'):
            cls.put(relative, (ROOT / relative).read_text())
        contract = json.loads((cls.root / 'domain/domain-contract.json').read_text())
        contract['schema'] = 'domain-contract/v2'
        contract['meta']['generated_from'].append('domain/domain-story.md')
        contract['concepts'] = [dict(id='CONCEPT-ORDER', name='Order', context='sales',
                                    definition='An order', essence='Purchase intent',
                                    responsibilities=['Record intent'], evidence=['domain/domain-story.md'])]
        cls.put('domain/domain-contract.json', json.dumps(contract))
        cls.put('domain/domain-story.md', 'A buyer places an order.\n')
        cls.put(f'specs/{cls.feature}/concept-test-seed.md', 'Record a purchase.\n')
        pinned = ['domain/context-map.md', 'domain/domain-contract.json', 'domain/domain-story.md',
                  f'specs/{cls.feature}/concept-test-seed.md']
        record = dict(schema='concept-test/v1', feature=cls.feature, proposal='FITS_EXISTING_CONCEPTS',
                      rationale='Purchase intent is already modeled.',
                      distinctions=[dict(concepts=['CONCEPT-ORDER'], judgment='same', confirmed=True)],
                      inputs=[dict(path=p, sha256=hashlib.sha256((cls.root / p).read_bytes()).hexdigest()) for p in pinned])
        cls.put(f'specs/{cls.feature}/concept-test.json', json.dumps(record))
        cls.put(f'specs/{cls.feature}/concept-test.md', '```json\n' + json.dumps(record) + '\n```\n')
        cls.domain = pinned + [f'specs/{cls.feature}/concept-test.json', f'specs/{cls.feature}/concept-test.md']
        cls.impl = cls.domain + ['domain/aggregates/Order.md', 'design-system/design-tokens.json',
                                 'design-system/design-system.md', 'design-system/ui-patterns.md']

    def test_persisted_and_next_round_accept_all_pins(self):
        self.manifests(self.domain, self.impl)
        self.check(True)
        self.precheck('impl', True)
        self.precheck('task', True)

    def test_relocated_story_and_concept_paths(self):
        self.manifests(self.domain, self.impl, relocated=True)
        self.check(True)
        self.precheck('impl', True)
        self.precheck('task', True)

    def test_changed_seed_invalidates_persisted_reviews(self):
        self.manifests(self.domain, self.impl)
        seed = self.root / f'specs/{self.feature}/concept-test-seed.md'
        before = seed.read_bytes()
        try:
            seed.write_bytes(before + b'changed')
            self.check(False)
            self.precheck('impl', False)
            self.precheck('task', False)
        finally:
            seed.write_bytes(before)

    def test_task_round_persists_and_revalidates_concept_inputs(self):
        self.manifests(self.domain, self.impl)
        original = self.root
        with tempfile.TemporaryDirectory() as directory:
            self.root = Path(directory) / 'fixture'
            shutil.copytree(original, self.root)
            try:
                script = r'''
set -euo pipefail
source "$1/tests/lib/loop-driver.sh"
LOOP_FIXTURE_ROOT="$2"
LOOP_FIXTURE_FEATURE="$3"
eval "$(declare -f _loop_task_manifest_a | sed '1s/_loop_task_manifest_a/_base_task_manifest_a/')"
eval "$(declare -f _loop_task_manifest_b | sed '1s/_loop_task_manifest_b/_base_task_manifest_b/')"
selected=$(python3 "$1/plugins/sdd-quality-loop/scripts/review-conditional-inputs.py" --root "$2" --feature "$3" --stage task)
_loop_task_manifest_a() { _base_task_manifest_a "$@" | jq --argjson selected "$selected" '. + $selected.inputs'; }
_loop_task_manifest_b() { _base_task_manifest_b "$@" | jq --argjson selected "$selected" '. + $selected.inputs'; }
drive_review_round task 1 1 PASS none
_loop_set_status_field "$2/specs/$3/tasks.md" Task-Review-Status Passed
'''
                result = subprocess.run(['bash', '-c', script, 'fixture', str(ROOT), str(self.root), self.feature],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                # The generic loop driver emits the older reviewer fixture shape.
                # Model today's structured task outputs with the actual precheck pins.
                round_dir = self.root / f'reports/task-review/{self.feature}/attempt-1/round-1'
                precheck = json.loads((round_dir / 'precheck-result.json').read_bytes())
                selected = concept.concept.conditional.resolve(self.root, self.feature, 'task')['inputs']
                extra_paths = [f'specs/{self.feature}/traceability.md'] + [
                    f'specs/{self.feature}/{name}' for name in precheck['layer_sha256']]
                extras = selected + [dict(path=p, sha256=hashlib.sha256((self.root / p).read_bytes()).hexdigest())
                                     for p in extra_paths]
                contract_path = round_dir / 'task-review-contract.json'
                contract = json.loads(contract_path.read_bytes())
                for index, role in enumerate(('a', 'b')):
                    path = round_dir / f'reviewer-{role}.json'
                    document = json.loads(path.read_bytes())
                    manifest = document.pop('allowed_input_manifest') + extras
                    for entry in manifest:
                        if entry['path'].endswith('/tasks.md'):
                            entry['sha256'] = precheck['tasks_sha256']
                    document.update(feature=self.feature, attempt=1, round=1, findings=[])
                    if role == 'a':
                        document.update(stage='task-review', role='reviewer-a', manifest=manifest)
                        for check in document['checks']:
                            check['status'] = check.pop('result')
                    else:
                        document['manifest'] = dict(allowed_inputs=manifest)
                    path.write_text(json.dumps(document))
                    contract['reviewers'][index]['allowed_input_manifest'] = manifest
                for key in ('tasks_sha256', 'traceability_sha256', 'design_sha256', 'layer_sha256'):
                    contract[key] = precheck[key]
                contract_path.write_text(json.dumps(contract))
                self.check(True)
                seed = self.root / f'specs/{self.feature}/concept-test-seed.md'
                seed.write_bytes(seed.read_bytes() + b'changed')
                self.check(False)
            finally:
                self.root = original


class LateStageAdmission(unittest.TestCase):
    def setUp(self):
        # Reuse only the data builder; its independent gate cases run elsewhere.
        self.fixture = concept.ConceptTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root

    def test_task_and_quality_require_every_concept_pin(self):
        self.assertIsNotNone(shutil.which('pwsh'), 'PowerShell required for parity')
        for stage, role in [('task', 'task-reviewer-a'), ('quality', 'sdd-evaluator')]:
            selected = concept.concept.conditional.resolve(self.root, 'example', stage)['inputs']
            base = []
            extra = {}
            if stage == 'quality':
                implementation = 'handoffs/fixture/manifest.json'
                target = self.root / implementation
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(json.dumps(dict(schema='task-input-manifest/v1', task_id='T-001',
                                                 run_id='implementation-run', session_id='implementation-session')))
                pin = dict(path=implementation, sha256=hashlib.sha256(target.read_bytes()).hexdigest())
                report = 'reports/implementation/example/T-001.md'
                target = self.root / report
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text('# Implementation Report: T-001\n- Task ID: T-001\n'
                                  'Run ID: implementation-run\n'
                                  '- **Run ID**: implementation-run\n- **Session ID**: implementation-session\n'
                                  f"Input manifest: `{implementation}`, SHA-256 `{pin['sha256']}`\n"
                                  '- **Scratch Root**: /fixture/implementation\n')
                base = [pin, dict(path=report, sha256=hashlib.sha256(target.read_bytes()).hexdigest())]
                extra = dict(task_id='T-001', implementation_manifest=pin,
                             scratch_root='/fixture/evaluation')
            ledger = self.root / 'reports/review-context/identity-ledger.json'
            ledger.parent.mkdir(parents=True, exist_ok=True)
            first = dict(sequence=1, stage='implementation', role='implementer', run_id='initial',
                         host_session_id='initial-session', previous_record_sha256='')
            first['record_sha256'] = hashlib.sha256(b'1|implementation|implementer|initial|initial-session|').hexdigest()
            before = json.dumps(dict(schema='review-identity-ledger/v1', records=[first])).encode()
            invocation = dict(schema='review-context-invocation/v2', input_mode='file-manifest',
                              fallback_mode='none', read_only=True, stage=stage, role=role, feature='example',
                              run_id='next', host_session_id='next-session', sequence=2,
                              identity_ledger_path='reports/review-context/identity-ledger.json',
                              identity_ledger_sha256=hashlib.sha256(before).hexdigest(),
                              previous_record_sha256=first['record_sha256'], **extra)
            for runtime in ('bash', 'pwsh'):
                shutil.rmtree(self.root / 'reports/review-context/scratch-reservations', ignore_errors=True)
                for omitted in [None] + [entry['path'] for entry in selected]:
                    with self.subTest(stage=stage, runtime=runtime, omitted=omitted):
                        ledger.write_bytes(before)
                        invocation['allowed_input_manifest'] = base + [e for e in selected if e['path'] != omitted]
                        path = self.root / 'invocation.json'
                        path.write_text(json.dumps(invocation))
                        script = ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set'
                        command = ([runtime, str(script) + '.sh', str(path), str(self.root)] if runtime == 'bash' else
                                   [runtime, '-NoProfile', '-File', str(script) + '.ps1', '-Manifest', str(path),
                                    '-RepositoryRoot', str(self.root)])
                        result = subprocess.run(command, capture_output=True, text=True, timeout=40)
                        self.assertEqual(result.returncode == 0, omitted is None, result.stdout + result.stderr)
                        self.assertEqual(ledger.read_bytes(), before)
                        if omitted is None:
                            self.assertEqual(launcher.required_dependencies(self.root, invocation)['inputs'], selected)
                            reserved = subprocess.run(command + ['--reserve' if runtime == 'bash' else '-Reserve'],
                                                      capture_output=True, text=True, timeout=40)
                            self.assertEqual(reserved.returncode, 0, reserved.stdout + reserved.stderr)
                            after = ledger.read_bytes()
                            last = json.loads(after)['records'][-1]
                            self.assertIn('allowed_inputs_sha256', last)
                            if stage == 'quality':
                                self.assertIn('scratch_declaration_sha256', last)
                            control = launcher.transport.receipt_control(invocation, reserved.stdout)
                            self.assertEqual(control['record_sha256'], last['record_sha256'])
                            verified = subprocess.run(command, capture_output=True, text=True, timeout=40)
                            self.assertEqual(verified.returncode, 0, verified.stdout + verified.stderr)
                            self.assertEqual(ledger.read_bytes(), after)
                            changed = dict(invocation, allowed_input_manifest=invocation['allowed_input_manifest'][:-1])
                            path.write_text(json.dumps(changed))
                            rejected = subprocess.run(command, capture_output=True, text=True, timeout=40)
                            self.assertNotEqual(rejected.returncode, 0, rejected.stdout + rejected.stderr)
                            self.assertEqual(ledger.read_bytes(), after)
                        else:
                            with self.assertRaises(ValueError):
                                launcher.required_dependencies(self.root, invocation)


if __name__ == '__main__':
    unittest.main()
