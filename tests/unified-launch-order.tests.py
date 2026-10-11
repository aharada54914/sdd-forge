"""Launch ordering with mock transport and real validators on fixture ledgers."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import uuid
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('launcher', ROOT / 'plugins/sdd-review-loop/scripts/launch-impl-review.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class LaunchOrderTests(unittest.TestCase):
    def exercise(self, failure=None, stage='impl', validator_runtime=None):
        process_run = launcher.subprocess.run
        receipt_control = launcher.transport.receipt_control
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            session = str(uuid.uuid4())
            relative = f'reports/{stage}-review/demo/attempt-1/round-1/precheck-result.json'
            calibration = ('spec-review-calibration.md' if stage == 'spec' else 'reviewer-calibration.md')
            required = [relative, 'specs/demo/requirements.md', 'specs/demo/acceptance-tests.md',
                        'plugins/sdd-review-loop/references/' + calibration]
            if stage in ('impl', 'task'):
                required.append('specs/demo/design.md')
            if stage == 'task':
                required.extend('specs/demo/' + name for name in (
                    'tasks.md', 'traceability.md', 'ux-spec.md', 'frontend-spec.md',
                    'infra-spec.md', 'security-spec.md'))
                required.append(str(Path(relative).parent / 'dependency-graph.json'))
            paths = required + ['invocation.json', 'bin',
                     'plugins/sdd-review-loop/references/review-context-boundary.md',
                     'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py',
                     'plugins/sdd-review-loop/scripts/probe-nontty-review.py',
                     f'plugins/sdd-review-loop/agents/{stage}-reviewer-a.md']
            for name in paths:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('---\nname: impl-reviewer-a\n---\nRead only.')
            precheck = {
                'schema': stage + '-review-precheck/v1', 'feature': 'demo',
                'attempt': 1, 'round': 1, 'investigation_sha256': None,
                'layer_sha256': {}, 'adr_inputs': []}
            if validator_runtime:
                for name in ('requirements', 'acceptance-tests', 'design'):
                    path = root / f'specs/demo/{name}.md'
                    if path.exists():
                        key = 'acceptance' if name == 'acceptance-tests' else name
                        precheck[key + '_sha256'] = launcher.transport.sha(path)
                if stage != 'task':
                    conditional = root / 'domain/context-map.md'
                    conditional.parent.mkdir()
                    conditional.write_text('Domain-Model-Status: Draft\n')
                    required.append('domain/context-map.md')
            (root / relative).write_text(json.dumps(precheck))
            entries = [{'path': path, 'sha256': launcher.transport.sha(root / path)}
                       for path in required]
            if failure == 'changed-digest':
                entries[1]['sha256'] = '0' * 64
            if failure == 'missing-required':
                entries = entries[:-1]
            if failure == 'extra-path':
                entries.append({'path': 'bin', 'sha256': launcher.transport.sha(root / 'bin')})
            if failure == 'unsafe-path':
                entries.append({'path': '../outside', 'sha256': '0' * 64})
            if failure == 'absolute-path':
                entries.append({'path': str(root / 'bin'), 'sha256': '0' * 64})
            if failure == 'duplicate-path':
                entries.append(dict(entries[0]))
            if failure == 'case-alias':
                entries.append({'path': 'BIN', 'sha256': '0' * 64})
            if failure == 'symlink-path':
                (root / 'linked').symlink_to(root / 'bin')
                entries.append({'path': 'linked', 'sha256': '0' * 64})
            if failure == 'adr-bin':
                (root / relative).write_text(json.dumps({
                    'schema': 'impl-review-precheck/v1', 'feature': 'demo',
                    'attempt': 1, 'round': 1, 'layer_sha256': {},
                    'adr_inputs': [{'path': 'bin', 'sha256': launcher.transport.sha(root / 'bin')}]}))
                entries.append({'path': 'bin', 'sha256': launcher.transport.sha(root / 'bin')})
            data = {'stage': stage, 'feature': 'demo', 'role': f'{stage}-reviewer-a',
                    'host_session_id': session, 'allowed_input_manifest': entries}
            output = (root / relative).parent / ('launch-' + session)
            round_dir = output.parent
            allocation = round_dir / 'reviewer-a-host-allocation.json'
            preflight_file = round_dir / 'reviewer-a-nontty-preflight.json'
            if failure == 'allocation-exists':
                allocation.write_text('original allocation')
            if failure == 'preflight-exists':
                preflight_file.write_text('original preflight')
            native = root / '.claude/projects' / (session + '.jsonl')
            native.parent.mkdir(parents=True)
            native.write_text('{}')
            ledger = root / 'reports/review-context/identity-ledger.json'
            ledger.parent.mkdir(parents=True)
            first = dict(sequence=1, stage='spec', role='spec-reviewer-a',
                         run_id='fixture-1', host_session_id='session-1', previous_record_sha256='',
                         record_sha256=hashlib.sha256(b'1|spec|spec-reviewer-a|fixture-1|session-1|').hexdigest())
            ledger.write_text(json.dumps({'schema': 'review-identity-ledger/v1', 'records': [first]}))
            before = ledger.read_bytes()
            data.update(schema='review-context-invocation/v2', input_mode='file-manifest',
                        fallback_mode='none', read_only=True, run_id='fixture-2', sequence=2,
                        identity_ledger_path=ledger.relative_to(root).as_posix(),
                        identity_ledger_sha256=launcher.transport.sha(ledger),
                        previous_record_sha256=first['record_sha256'])
            (root / 'invocation.json').write_text(json.dumps(data))
            pin = '0' * 64 if failure == 'raw-pin' else launcher.transport.sha(root / 'invocation.json')
            events = []
            reserve_commands = []

            def validate(reserve=False):
                script = ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set'
                command = (['rtk', 'proxy', 'bash', str(script) + '.sh', str(root / 'invocation.json'), str(root)]
                           if validator_runtime == 'bash' else
                           ['rtk', 'proxy', 'pwsh', '-NoProfile', '-File', str(script) + '.ps1',
                            '-Manifest', str(root / 'invocation.json'), '-RepositoryRoot', str(root)])
                if reserve:
                    command += ['--reserve' if validator_runtime == 'bash' else '-Reserve']
                    reserve_commands.append(command)
                return process_run(command, cwd=root, text=True, capture_output=True, timeout=60)

            def precheck_process(command, **kwargs):
                if 'preflight-host-review.py' in command[3]:
                    if not output.exists():
                        events.append('common-input-preflight')
                    self.assertEqual(command[-2:], ['--manifest-sha256',
                        launcher.transport.sha(root / 'invocation.json')])
                    return SimpleNamespace(returncode=1 if failure == 'common-preflight' else 0,
                        stdout=('invalid' if failure == 'common-result' else
                            'HOST_REVIEW_PREFLIGHT_OK inputs=4 permission-proof=not-established '
                            'reservation=not-performed\n'), stderr='injected input failure')
                self.assertEqual(command[-1], '--verify-inputs')
                if not output.exists():
                    events.append('precheck-before-output')
                if failure == 'precheck-drift':
                    (root / relative).write_text((root / relative).read_text() + '\n')
                return SimpleNamespace(returncode=1 if failure == 'early-precheck' else 0)

            def run(_root, command, destination, prompt=None):
                event = destination.name
                events.append(event)
                if event == 'reserved.txt':
                    self.assertEqual(allocation.read_bytes(), (output / 'caller-proposal.json').read_bytes())
                    self.assertEqual(json.loads(preflight_file.read_text())['status'], 'PREFLIGHT_OK')
                if failure == event:
                    raise ValueError('injected failure')
                if validator_runtime and event in ('preview.txt', 'preview-after.txt', 'reserved.txt'):
                    result = validate(reserve=event == 'reserved.txt')
                    destination.write_text(result.stdout)
                    if failure == 'changed-digest' and event == 'preview.txt':
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn('hash mismatch', result.stdout + result.stderr)
                        raise ValueError('canonical input hash mismatch')
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    if event == 'reserved.txt':
                        self.assertEqual(len(json.loads(ledger.read_text())['records']), 2)
                    if ((event == 'preview-after.txt' and failure == 'receipt') or
                            (event == 'reserved.txt' and failure == 'postappend-receipt')):
                        altered = result.stdout.replace('identity_unique=yes', 'identity_unique=no')
                        self.assertNotEqual(altered, result.stdout)
                        destination.write_text(altered)
                        return altered
                    return result.stdout
                if event == 'native.jsonl':
                    if failure == 'drift':
                        (root / 'bin').write_text('changed')
                    if failure == 'conditional-presence':
                        domain = root / 'domain'
                        domain.mkdir(exist_ok=True)
                        (domain / 'context-map.md').write_text('Domain-Model-Status: Approved\n')
                    return json.dumps({'admitted_read_executed': True,
                        'control_reads_executed': True,
                        'source_invocation_read_executed': failure != 'source-not-read',
                        'source_invocation_sha256': launcher.transport.sha(root / 'invocation.json') if failure != 'wrong-proof' else 'wrong',
                        'admitted_paths': [entry['path'] for entry in
                                           (list(reversed(entries)) if failure == 'proof-order' else entries)],
                        'outside_read_pretool_denied': True,
                        'existing_session_collision_rejected': failure != 'collision-not-rejected',
                        'chained_bash_pretool_denied': True,
                        'ordered_hashes_verified': len(entries) + 5})
                if event == 'preview-after.txt' and failure == 'receipt':
                    return 'different'
                destination.write_text('receipt')
                return 'receipt'

            def command(*args):
                if failure == 'unsupported-cli':
                    raise ValueError('unsupported CLI flag')
                return ['fake-claude']

            def preflight(*args):
                if failure == 'input':
                    raise ValueError('missing input')
                return {'status': 'PREFLIGHT_OK', 'session_id': session,
                        'invocation_sha256': launcher.transport.sha(root / 'invocation.json')}

            with patch.object(launcher.transport, 'manifest', return_value=(data, {})), \
                 patch.object(launcher.transport, 'preflight', side_effect=preflight), \
                 patch.object(launcher.transport, 'launch_policy', return_value=(b'{}', {})), \
                 patch.object(launcher.transport, 'receipt_control',
                              side_effect=receipt_control if validator_runtime else
                              lambda *args, **kwargs: {'exact_permission_rules': []}), \
                 patch.object(launcher.transport, 'claude_command', side_effect=command), \
                 patch.object(launcher.transport, 'expected_prompt', return_value=b'prompt') as expected_prompt, \
                 patch.object(launcher.transport, 'postflight', return_value={'delivery': 'ok'}), \
                 patch.object(launcher.shutil, 'which', return_value=str(root / 'bin')), \
                 patch.object(launcher.subprocess, 'run', side_effect=precheck_process), \
                 patch.object(launcher, 'run', side_effect=run), \
                 patch.object(Path, 'home', return_value=root):
                if failure:
                    with self.assertRaises(ValueError) as caught:
                        launcher.launch(root, root / 'invocation.json', output, pin)
                    if failure == 'postappend-receipt':
                        self.assertEqual(str(caught.exception), 'reservation differs from preview; do not retry identity')
                    if failure == 'raw-pin':
                        self.assertEqual(str(caught.exception), 'caller invocation pin mismatch')
                    if validator_runtime:
                        reason = {
                            'missing-required': 'conditional input missing or stale',
                            'changed-digest': 'canonical input hash mismatch',
                            'case-alias': 'input path has a case alias',
                            'symlink-path': 'input path traverses a symlink',
                            'extra-path': 'input manifest differs from required stage/role set',
                            'receipt': 'admission changed during native preflight',
                            'proof-order': 'native permission proof incomplete or for different inputs',
                            'conditional-presence': 'conditional input missing or stale',
                        }.get(failure)
                        if reason:
                            self.assertIn(reason, str(caught.exception))
                else:
                    self.assertEqual(launcher.launch(root, root / 'invocation.json', output, pin), {'delivery': 'ok'})
                    conditional_state = expected_prompt.call_args.kwargs['conditional_state']
                    if stage in ('spec', 'impl'):
                        self.assertEqual(conditional_state['domain_status'], 'skipped')
                        self.assertEqual(conditional_state['observed']['domain/context-map.md'],
                                         launcher.transport.sha(root / 'domain/context-map.md') if validator_runtime else None)
                        self.assertIsNone(conditional_state['observed']['domain/domain-contract.json'])
                    proposal = json.loads(allocation.read_text())
                    self.assertEqual(proposal, json.loads((output / 'caller-proposal.json').read_text()))
                    self.assertEqual(proposal['kind'], 'claude-nontty-caller-proposal')
                    self.assertEqual(proposal['host_id'], session)
                    self.assertEqual(proposal['host_session_id'], session)
                    self.assertEqual(proposal['role'], f'{stage}-reviewer-a')
                    self.assertEqual((proposal['feature'], proposal['attempt'], proposal['round']), ('demo', 1, 1))
                    self.assertIs(proposal['review_turn_started'], False)
                    self.assertEqual(proposal['preflight_result_path'], preflight_file.relative_to(root).as_posix())
                    self.assertEqual(proposal['preflight_result_sha256'], launcher.transport.sha(preflight_file))
                    self.assertEqual(proposal['preflight_result'], 'PREFLIGHT_OK')
                    with self.assertRaises(FileExistsError):
                        launcher.launch(root, root / 'invocation.json', output)
                if failure == 'allocation-exists':
                    self.assertEqual(allocation.read_text(), 'original allocation')
                if failure == 'preflight-exists':
                    self.assertEqual(preflight_file.read_text(), 'original preflight')
                if failure in ('missing-required', 'extra-path', 'unsafe-path',
                               'absolute-path', 'duplicate-path', 'case-alias', 'symlink-path',
                               'adr-bin', 'early-precheck', 'precheck-drift',
                               'common-preflight', 'common-result'):
                    self.assertFalse(output.exists())
                    self.assertFalse(preflight_file.exists())
                    self.assertFalse(allocation.exists())
                    self.assertEqual(ledger.read_bytes(), before)
            if validator_runtime and (failure is None or failure == 'postappend-receipt'):
                persisted = ledger.read_bytes()
                records = json.loads(persisted)['records']
                self.assertEqual(records[:-1], [first])
                self.assertEqual(len(records), 2)
                for field in ('sequence', 'stage', 'role', 'run_id', 'host_session_id', 'previous_record_sha256'):
                    self.assertEqual(records[-1][field], data[field])
                self.assertEqual(records[-1]['record_sha256'],
                                 (output / 'preview.txt').read_text().split()[1])
                self.assertEqual(len(reserve_commands), 1, 'launcher must reserve exactly once')
                if failure == 'postappend-receipt':
                    expected_prompt.assert_not_called()
                    self.assertNotIn('wrapper.json', events)
                # Explicit adversarial retry is outside launch; the consumed record must survive it.
                retry = validate(reserve=True)
                self.assertNotEqual(retry.returncode, 0)
                self.assertIn('cannot be reserved twice', retry.stdout + retry.stderr)
                self.assertEqual(ledger.read_bytes(), persisted)
            else:
                self.assertEqual(ledger.read_bytes(), before)
                self.assertEqual(reserve_commands, [])
            return events

    def test_success_order_and_no_replay(self):
        for stage in ('spec', 'impl', 'task'):
            self.assertEqual(self.exercise(stage=stage), ['common-input-preflight', 'precheck-before-output',
                'verify-before.txt', 'preview.txt', 'native.jsonl',
                'verify-after.txt', 'preview-after.txt', 'reserved.txt', 'wrapper.json'])

    def test_failures_before_reservation(self):
        for failure in ('input', 'allocation-exists', 'preflight-exists',
                        'unsupported-cli', 'verify-before.txt', 'preview.txt',
                        'native.jsonl', 'drift', 'conditional-presence', 'wrong-proof', 'source-not-read',
                        'collision-not-rejected', 'verify-after.txt', 'preview-after.txt', 'receipt',
                        'missing-required', 'extra-path', 'unsafe-path', 'absolute-path',
                        'duplicate-path', 'case-alias', 'symlink-path', 'adr-bin', 'early-precheck',
                        'precheck-drift', 'common-preflight', 'common-result'):
            with self.subTest(failure=failure):
                events = self.exercise(failure)
                self.assertNotIn('reserved.txt', events)
                self.assertNotIn('wrapper.json', events)

    def test_reservation_failure_never_launches(self):
        self.assertNotIn('wrapper.json', self.exercise('reserved.txt'))
        for runtime in ('bash', 'powershell'):
            for stage in ('spec', 'impl', 'task'):
                with self.subTest(runtime=runtime, stage=stage):
                    self.assertNotIn('wrapper.json', self.exercise('postappend-receipt', stage, runtime))

    def test_canonical_admission_and_preappend_failures(self):
        for runtime in ('bash', 'powershell'):
            with self.subTest(runtime=runtime, case='authorized'):
                events = self.exercise(stage='spec', validator_runtime=runtime)
                self.assertEqual(events.count('reserved.txt'), 1)
                self.assertEqual(events.count('wrapper.json'), 1)
            for failure in ('missing-required', 'changed-digest', 'case-alias', 'symlink-path',
                            'extra-path', 'raw-pin', 'receipt', 'proof-order', 'conditional-presence'):
                with self.subTest(runtime=runtime, failure=failure):
                    events = self.exercise(failure, 'spec', runtime)
                    self.assertNotIn('reserved.txt', events)
                    self.assertNotIn('wrapper.json', events)

    def test_common_rejection_stops_every_stage_before_mutation(self):
        for stage in ('spec', 'impl', 'task', 'quality'):
            with self.subTest(stage=stage), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                invocation = root / 'invocation.json'
                invocation.write_text('{}')
                ledger = root / 'ledger.json'
                ledger.write_text('unchanged')
                output = root / 'output'
                data = {'stage': stage, 'feature': 'demo', 'host_session_id': str(uuid.uuid4())}
                with patch.object(launcher.transport, 'manifest', return_value=(data, {})), \
                     patch.object(launcher.subprocess, 'run', return_value=SimpleNamespace(
                         returncode=1, stdout='', stderr='missing required input')) as process, \
                     patch.object(launcher, 'run') as launch_process:
                    with self.assertRaisesRegex(ValueError, 'missing required input'):
                        launcher.launch(root, invocation, output,
                                        launcher.transport.sha(invocation) if stage == 'quality' else None)
                    self.assertEqual(process.call_count, 1)
                    launch_process.assert_not_called()
                self.assertFalse(output.exists())
                self.assertEqual(ledger.read_text(), 'unchanged')

    def test_conditional_input_is_not_silently_skipped(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'domain').mkdir()
            (root / 'domain/context-map.md').write_text('Domain-Model-Status: Approved')
            data = {'stage': 'spec', 'feature': 'demo', 'allowed_input_manifest': []}
            with self.assertRaisesRegex(ValueError, 'conditional input missing or stale'):
                launcher.required_dependencies(root, data)
            data['allowed_input_manifest'] = [{'path': 'domain/context-map.md', 'sha256': 'wrong'}]
            with self.assertRaisesRegex(ValueError, 'conditional input missing or stale'):
                launcher.required_dependencies(root, data)
            data['allowed_input_manifest'][0]['sha256'] = launcher.transport.sha(root / 'domain/context-map.md')
            self.assertEqual(launcher.required_dependencies(root, data)['domain_status'], 'skipped')

    def test_strict_prompt_carries_revalidated_absent_domain_without_shell_probe(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            boundary = root / 'plugins/sdd-review-loop/references/review-context-boundary.md'
            boundary.parent.mkdir(parents=True)
            boundary.write_text('boundary\n')
            invocation = root / 'invocation.json'
            invocation.write_text('{}')
            receipt = root / 'receipt.txt'
            receipt.write_text('REVIEW_CONTEXT_OK ' + 'b' * 64 + ' sequence=2 '
                               'previous_record_sha256=' + 'a' * 64 +
                               ' pre_append_tip_sequence=1 identity_unique=yes\n')
            data = {'stage': 'impl', 'role': 'impl-reviewer-a', 'feature': 'demo',
                    'allowed_input_manifest': []}
            state = launcher.required_dependencies(root, data)
            with patch.object(launcher.transport, 'manifest', return_value=(data, {})), \
                 patch.object(launcher.transport, 'control_prompt', return_value='control\n'):
                prompt = launcher.transport.expected_prompt(root, invocation, receipt,
                                                            strict=True, conditional_state=state).decode()
                historical = launcher.transport.expected_prompt(root, invocation, receipt,
                                                                 strict=True).decode()
            self.assertIn('"domain_status": "skipped"', prompt)
            self.assertIn('"domain/context-map.md": null', prompt)
            self.assertIn('"domain/domain-contract.json": null', prompt)
            self.assertIn('Do not run directory/presence shell probes', prompt)
            self.assertNotIn('Pre-reservation conditional-input resolution', historical)

    def test_design_system_is_only_an_impl_dependency(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'design-system').mkdir()
            data = {'stage': 'spec', 'feature': 'demo', 'allowed_input_manifest': []}
            launcher.required_dependencies(root, data)
            data['stage'] = 'impl'
            with self.assertRaisesRegex(ValueError, 'missing conditional input'):
                launcher.required_dependencies(root, data)

    def test_required_set_follows_stage_role_and_precheck(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            feature = 'demo'
            for stage in ('spec', 'impl'):
                round_number = 2 if stage == 'impl' else 1
                round_dir = root / f'reports/{stage}-review/{feature}/attempt-1/round-{round_number}'
                round_dir.mkdir(parents=True)
                precheck = round_dir / 'precheck-result.json'
                precheck.write_text(json.dumps({
                    'schema': stage + '-review-precheck/v1', 'feature': feature,
                    'attempt': 1, 'round': round_number,
                    'investigation_sha256': '0' * 64,
                    'layer_sha256': {'ux-spec.md': '0' * 64} if stage == 'impl' else {},
                    'adr_inputs': [{'path': 'docs/adr/0036-example.md', 'sha256': '0' * 64}]
                    if stage == 'impl' else []}))
                if stage == 'impl':
                    investigation = root / 'specs/demo/investigation.md'
                    investigation.parent.mkdir(parents=True, exist_ok=True)
                    investigation.write_text('evidence')
                for suffix in ('a', 'b'):
                    data = {'stage': stage, 'feature': feature,
                            'role': f'{stage}-reviewer-{suffix}',
                            'allowed_input_manifest': []}
                    expected = launcher.required_input_paths(root, data, precheck, 1, round_number)
                    self.assertIn(f'specs/{feature}/requirements.md', expected)
                    self.assertIn(f'specs/{feature}/investigation.md', expected)
                    self.assertEqual(any(path.endswith('/integrated-summary.json') and
                                         f'round-{round_number}/' in path for path in expected),
                                     suffix == 'b')
                    if stage == 'impl':
                        self.assertIn('specs/demo/ux-spec.md', expected)
                        self.assertIn('docs/adr/0036-example.md', expected)
                        self.assertEqual(f'reports/impl-review/demo/attempt-1/round-1/integrated-summary.json'
                                         in expected, suffix == 'a')


if __name__ == '__main__':
    unittest.main()
