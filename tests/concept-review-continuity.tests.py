#!/usr/bin/env python3
"""Concept evidence survives real admission, prechecks and persisted validation."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


workflow = load('workflow_fixture', ROOT / 'tests/workflow-conditional-inputs.tests.py')
concept = load('concept_fixture', ROOT / 'tests/concept-test.tests.py')
launcher = load('concept_launcher', ROOT / 'plugins/sdd-review-loop/scripts/launch-impl-review.py')


class ConceptFixture(workflow.WorkflowFixture):
    """Passed spec/impl/task reviews whose manifests pin a FITS Concept Test record."""
    schema = 'concept-test/v2'

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        for relative in ('plugins/sdd-domain/scripts/validate-concept-test.py',
                         'plugins/sdd-domain/scripts/validate-domain-contract.sh',
                         'plugins/sdd-domain/scripts/validate-domain-contract.ps1',
                         'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py',
                         'contracts/concept-test.v1.schema.json', 'contracts/concept-test.v2.schema.json'):
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
        record = dict(schema=cls.schema, feature=cls.feature, proposal='FITS_EXISTING_CONCEPTS',
                      rationale='Purchase intent is already modeled.',
                      distinctions=[dict(concepts=['CONCEPT-ORDER'], judgment='same', confirmed=True)],
                      inputs=[dict(path=p, sha256=hashlib.sha256((cls.root / p).read_bytes()).hexdigest()) for p in pinned])
        cls.put(f'specs/{cls.feature}/concept-test.json', json.dumps(record))
        cls.put(f'specs/{cls.feature}/concept-test.md', '```json\n' + json.dumps(record) + '\n```\n')
        cls.domain = pinned + [f'specs/{cls.feature}/concept-test.json', f'specs/{cls.feature}/concept-test.md']
        cls.impl = cls.domain + ['domain/aggregates/Order.md', 'design-system/design-tokens.json',
                                 'design-system/design-system.md', 'design-system/ui-patterns.md']


class PersistedV1History(ConceptFixture, unittest.TestCase):
    """Owner decision 2026-11-26: passed reviews keep their v1 provenance; new rounds refuse v1."""
    schema = 'concept-test/v1'

    def test_passed_reviews_keep_their_v1_provenance(self):
        self.manifests(self.domain, self.impl)
        self.check(True)

    def test_changed_seed_still_invalidates_v1_provenance(self):
        self.manifests(self.domain, self.impl)
        seed = self.root / f'specs/{self.feature}/concept-test-seed.md'
        before = seed.read_bytes()
        try:
            seed.write_bytes(before + b'changed')
            self.check(False)
            # The stale pin, not the retirement, refuses the history.
            with self.assertRaisesRegex(ValueError, 'Concept Test input changed'):
                concept.concept.conditional.resolve(self.root, self.feature, 'spec', v1_history=True)
        finally:
            seed.write_bytes(before)

    def test_migrating_to_v2_makes_passed_reviews_stale(self):
        # Documented: history holds only while the v1 inputs are unchanged. Recreating the
        # record as v2 means re-running the feature's spec/impl/task reviews.
        self.manifests(self.domain, self.impl)
        self.check(True)
        paths = [self.root / f'specs/{self.feature}/concept-test.{ext}' for ext in ('json', 'md')]
        before = [path.read_bytes() for path in paths]
        try:
            record = json.loads(before[0])
            record['schema'] = 'concept-test/v2'
            paths[0].write_text(json.dumps(record))
            paths[1].write_text('```json\n' + json.dumps(record) + '\n```\n')
            for runtime, suffix in self.runtimes:
                with self.subTest(runtime=runtime):
                    command = [runtime] + (['-NoProfile', '-File'] if runtime == 'pwsh' else [])
                    command += [str(ROOT / ('plugins/sdd-quality-loop/scripts/check-workflow-state' + suffix)),
                                '--registry', str(self.root / 'specs/workflow-state-registry.json'),
                                '--feature', self.feature]
                    result = subprocess.run(command, text=True, capture_output=True)
                    output = result.stdout + result.stderr
                    self.assertNotEqual(result.returncode, 0, output)
                    self.assertIn('stage-provenance', output)
                    self.assertRegex(output, r'(?i)input hash is stale', output)
        finally:
            for path, data in zip(paths, before):
                path.write_bytes(data)

    def test_new_rounds_refuse_v1(self):
        self.manifests(self.domain, self.impl)
        for runtime, suffix in self.runtimes:
            with self.subTest(runtime=runtime):
                command = [runtime] + (['-NoProfile', '-File'] if runtime == 'pwsh' else [])
                command += [str(self.root / f'plugins/sdd-review-loop/scripts/task-review-precheck{suffix}'),
                            self.feature, '2', '1']
                result = subprocess.run(command, cwd=self.root, text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(concept.V1_RETIRED_PREFIX, result.stdout + result.stderr)
                self.assertFalse((self.root / f'reports/task-review/{self.feature}/attempt-2').exists())


class PersistedConcept(ConceptFixture, unittest.TestCase):
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

    def test_local_decision_admission_and_persistence(self):
        # Installed consumer projects receive schemas from the plugin.
        shutil.rmtree(self.root / 'contracts')
        subprocess.run(['git', '-C', str(self.root), 'init', '-q'], check=True)
        story = 'domain/domain-story.md'
        self.fixture.write(story, 'A visitor finds a publication.\n')
        contract = 'domain/domain-contract.json'
        domain = json.loads((self.root / contract).read_bytes())
        domain['meta']['generated_from'].append(story)
        self.fixture.write(contract, domain)
        self.fixture.record['inputs'].append({'path': story})
        for item in self.fixture.record['inputs']:
            item['sha256'] = hashlib.sha256((self.root / item['path']).read_bytes()).hexdigest()
        self.fixture.local_proposal()
        self.fixture.local_confirmation('proceed')
        self.test_task_and_quality_require_every_concept_pin()

    def check_fixed_with_live_changes(self, command, runtime, selected):
        fixed = load('local_concept_snapshot', ROOT / 'plugins/sdd-review-loop/scripts/fixed-review-inputs.py')
        git = ['git', '-C', str(self.root)]
        names = [entry['path'] for entry in selected]
        subprocess.run(git + ['add', '--', *names], check=True)
        subprocess.run(git + ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                              'commit', '--allow-empty', '-qm', 'Synthetic review inputs'], check=True)
        commit = subprocess.check_output(git + ['rev-parse', 'HEAD'], text=True).strip()
        with tempfile.TemporaryDirectory() as directory:
            record = Path(directory) / 'fixed.json'
            snapshot = Path(directory) / 'snapshot'
            fixed.prepare(self.root, commit, names, snapshot, record)
            flags = (['--fixed-input-record', str(record), '--fixed-input-snapshot', str(snapshot)] if runtime == 'bash'
                     else ['-FixedInputRecord', str(record), '-FixedInputSnapshot', str(snapshot)])
            proposal = self.root / 'specs/example/concept-test.json'
            before = proposal.read_bytes()
            try:
                proposal.write_bytes(b'{}')
                live = subprocess.run(command, capture_output=True, text=True, timeout=40)
                self.assertNotEqual(live.returncode, 0, live.stdout + live.stderr)
                selected_revision = subprocess.run(command + flags, capture_output=True, text=True, timeout=40)
                self.assertEqual(selected_revision.returncode, 0, selected_revision.stdout + selected_revision.stderr)
            finally:
                proposal.write_bytes(before)
            # Identical relative filenames and content cannot bind a repository inventory to a subproject.
            with tempfile.TemporaryDirectory(dir=self.root) as nested_dir:
                nested = Path(nested_dir)
                for name in ('domain', 'specs', 'reports'):
                    shutil.copytree(self.root / name, nested / name)
                invocation = self.root / 'invocation.json'
                shutil.copyfile(invocation, nested / invocation.name)
                locations = {str(self.root): str(nested), str(invocation): str(nested / invocation.name)}
                nested_command = [locations.get(arg, arg) for arg in command]
                live = subprocess.run(nested_command, capture_output=True, text=True, timeout=40)
                self.assertEqual(live.returncode, 0, live.stdout + live.stderr)
                mismatch = subprocess.run(nested_command + flags, capture_output=True, text=True, timeout=40)
                self.assertNotEqual(mismatch.returncode, 0, mismatch.stdout + mismatch.stderr)
                self.assertIn('legacy fixed review inventory requires the Git worktree root',
                              mismatch.stdout + mismatch.stderr)

    def test_packet_uses_only_original_signed_contract(self):
        factory = load('local_concept_packet_fixture', ROOT / 'tests/factory-workflow.tests.py')
        packet = factory.fixture(self.root)
        task_path = 'specs/example/tasks.md'
        (self.root / task_path).write_bytes((self.root / 'specs/pilot/tasks.md').read_bytes())
        packet.update(feature='example', approval=factory.reference(self.root, task_path), concept_test=True)
        def validate_packet():
            return factory.packet.validate(self.root, packet, 'example', 'T-001', 'experiment-1',
                                           factory.packet.packet_digest(packet))
        local = self.fixture.local_proposal()
        self.fixture.local_confirmation('proceed')
        with self.assertRaisesRegex(ValueError, 'unsupported Concept Test version'):
            validate_packet()
        local.unlink()
        self.fixture.record.update(schema='concept-test/v1', decision='proceed')
        self.fixture.save()
        self.fixture.sign()
        with mock.patch.dict(os.environ, self.fixture.env, clear=True):
            self.assertEqual('proceed', validate_packet()['concept_decision'])

    def test_live_v1_is_refused_while_a_pinned_revision_still_resolves(self):
        # Owner decision 2026-11-26: new review launches read the working tree and refuse v1;
        # a review pinned to a historical revision still reads that revision's signed v1 record.
        self.fixture.record.update(schema='concept-test/v1', proposal='RESPONSIBILITY_CONFLICT', decision='proceed')
        self.fixture.save()
        self.fixture.sign()
        self.fixture.write('specs/example/requirements.md', 'Bounded-Context: catalog\n')
        revision = self.fixture.commit('Signed v1 decision')
        script = ROOT / 'plugins/sdd-quality-loop/scripts/review-conditional-inputs.py'
        for stage in ('spec', 'impl', 'task', 'quality'):
            with self.subTest(stage=stage), mock.patch.dict(os.environ, self.fixture.env, clear=True):
                with self.assertRaisesRegex(ValueError, concept.V1_RETIRED_PREFIX):
                    concept.concept.conditional.resolve(self.root, 'example', stage)
                pinned = concept.concept.conditional.resolve(self.root, 'example', stage, revision)
                self.assertIn('specs/example/concept-test.approval.json', {e['path'] for e in pinned['inputs']})
                command = [sys.executable, str(script), '--root', str(self.root), '--feature', 'example', '--stage', stage]
                live = subprocess.run(command, capture_output=True, text=True)
                self.assertEqual(1, live.returncode, live.stdout + live.stderr)
                self.assertIn('CONDITIONAL_INPUTS: ' + concept.V1_RETIRED_PREFIX, live.stderr)
                fixed = subprocess.run(command + ['--revision', revision], capture_output=True, text=True)
                self.assertEqual(0, fixed.returncode, fixed.stdout + fixed.stderr)

    def test_task_and_quality_require_every_concept_pin(self):
        self.assertIsNotNone(shutil.which('pwsh'), 'PowerShell required for parity')
        for stage, role in [('task', 'task-reviewer-a'), ('quality', 'sdd-evaluator')]:
            selected = concept.concept.conditional.resolve(self.root, 'example', stage)['inputs']
            base = []
            extra = {}
            if stage == 'quality':
                source = self.root / 'specs/example/requirements.md'
                source.parent.mkdir(parents=True, exist_ok=True)
                if not source.exists():
                    source.write_text('fixture requirement\n')
                implementation = 'handoffs/fixture/manifest.json'
                target = self.root / implementation
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(json.dumps(dict(schema='task-input-manifest/v1', task_id='T-001',
                                                 run_id='implementation-run', session_id='implementation-session',
                                                 allowed_inputs=[dict(path='specs/example/requirements.md',
                                                                      sha256=hashlib.sha256(source.read_bytes()).hexdigest())])))
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
                            if stage == 'task' and (self.root / 'specs/example/concept-test.decision.json').exists():
                                self.check_fixed_with_live_changes(command, runtime, selected)
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


class DomainInputManifest(unittest.TestCase):
    def test_legacy_domain_precheck_inputs_form_a_reservable_unique_manifest(self):
        canonical = ['domain/domain-story.md', 'domain/event-storming.md', 'domain/concept-model.md',
                     'domain/ubiquitous-language.md', 'domain/context-map.md', 'domain/aggregates/Order.md',
                     'domain/message-flow.md']
        author = (ROOT / 'plugins/sdd-domain/skills/domain-interviewer/SKILL.md').read_text()
        documented = re.findall(r'`(domain/[^`]+\.md)`', author)
        outputs = {re.sub(r'/<[^>/]+>\.md$', '/Order.md', path) for path in documented}
        self.assertTrue(set(canonical) <= outputs, set(canonical) - outputs)
        # The v1 precheck still consumes these inputs; the public v2 review writes latest.md.
        calibration = 'plugins/sdd-domain/references/domain-review-calibration.md'
        additional = ['domain/domain-contract.json', calibration]
        precheck = 'reports/domain-review/attempt-1/round-1/precheck-result.json'
        paths = canonical + additional + [precheck]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            for name in paths:
                if name == precheck:
                    continue
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                if name == calibration:
                    shutil.copyfile(ROOT / calibration, target)
                    continue
                target.write_text('Domain-Model-Status: Pending\n' if name == 'domain/context-map.md'
                                  else '{}\n' if name.endswith('.json') else '# Domain fixture\n')
            script = root / 'plugins/sdd-domain/scripts/domain-review-precheck.sh'
            script.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / script.relative_to(root), script)
            (root / 'reports').mkdir(exist_ok=True)
            # Synthetic native metadata exercises the actual producer, not a hand-built ledger.
            events = root / 'native/session-state/fixture-host-session/events.jsonl'
            events.parent.mkdir(parents=True)
            events.write_text(json.dumps(dict(type='session.start', id='fixture-host', parentId=None,
                                             data=dict(version=1, producer='copilot-agent',
                                                       sessionId='fixture-host-session', context=dict(cwd=str(root))))))
            with mock.patch.dict(os.environ, COPILOT_HOME=str(root / 'native')):
                initial_document = concept.identity.initialize(root, events)
            checked = subprocess.run(['bash', str(script), '1', '1'], capture_output=True, text=True)
            self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)
            report = json.loads((root / precheck).read_bytes())
            self.assertEqual((report['schema'], report['stage'], report['domain_model_status_field']),
                             ('domain-review-precheck/v1', 'domain', 'Pending'))
            self.assertEqual(report['calibration_sha256'], hashlib.sha256((root / calibration).read_bytes()).hexdigest())
            entries = [dict(path=p, sha256=hashlib.sha256((root / p).read_bytes()).hexdigest()) for p in paths]
            ledger = root / 'reports/review-context/identity-ledger.json'
            initial = initial_document['records'][0]
            before = ledger.read_bytes()
            invocation = dict(schema='review-context-invocation/v2', input_mode='file-manifest', fallback_mode='none',
                              read_only=True, stage='domain', role='domain-reviewer-a', feature='sdd-domain-model',
                              run_id='fixture-review', host_session_id='fixture-review-session', sequence=2,
                              identity_ledger_path='reports/review-context/identity-ledger.json',
                              identity_ledger_sha256=hashlib.sha256(before).hexdigest(),
                              previous_record_sha256=initial['record_sha256'], allowed_input_manifest=entries)
            manifest = root / 'invocation.json'
            for runtime in ('bash', 'pwsh'):
                with self.subTest(runtime=runtime):
                    manifest.write_text(json.dumps(invocation))
                    ledger.write_bytes(before)
                    validator = ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set'
                    command = (['bash', str(validator) + '.sh', str(manifest), str(root), '--reserve']
                               if runtime == 'bash' else ['pwsh', '-NoProfile', '-File', str(validator) + '.ps1',
                                                         '-Manifest', str(manifest), '-RepositoryRoot', str(root), '-Reserve'])
                    result = subprocess.run(command, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn('REVIEW_CONTEXT_OK', result.stdout)
                    self.assertEqual(len(json.loads(ledger.read_bytes())['records']), 2)
                    ledger.write_bytes(before)
                    changed = dict(invocation, allowed_input_manifest=[
                        dict(entry, sha256='0' * 64) if entry['path'] == calibration else entry
                        for entry in entries])
                    manifest.write_text(json.dumps(changed))
                    rejected = subprocess.run(command, capture_output=True, text=True)
                    self.assertNotEqual(rejected.returncode, 0)
                    self.assertIn('hash mismatch', (rejected.stderr + rejected.stdout).lower())
                    self.assertIn(calibration, rejected.stderr + rejected.stdout)
                    self.assertEqual(ledger.read_bytes(), before)
            self.assertEqual(len(paths), len(set(paths)))


if __name__ == '__main__':
    unittest.main()
