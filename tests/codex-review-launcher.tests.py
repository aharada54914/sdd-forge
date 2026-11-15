#!/usr/bin/env python3
"""Bounded native transport controls; no model or network required."""
import hashlib
import importlib.util
import json
import os
import shutil
from pathlib import Path
import tempfile
import tomllib
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('native_review', ROOT / 'plugins/sdd-review-loop/scripts/launch-codex-review.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LaunchTests(unittest.TestCase):
    def run_case(self, *, reserve_ok=True, mutate=False, identity_bad=False, profile_bad=False,
                 output_bad=False, event_bad=False, timeout=False, path_escape=False, quality=False, no_inspection=False,
                 selected_model=None, selected_effort=None, model_bad=False, effort_bad=False):
        calls = []
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'input').write_text('admitted')
            ledger = root / 'reports/review-context/identity-ledger.json'
            ledger.parent.mkdir(parents=True)
            ledger.write_text(json.dumps({'records': [{'record_sha256': 'b' * 64, 'sequence': 1}]}))
            data = {'schema': 'review-context-invocation/v2', 'stage': 'spec',
                    'role': 'spec-reviewer-a', 'feature': 'demo', 'input_mode': 'file-manifest',
                    'fallback_mode': 'none', 'read_only': True,
                    'allowed_input_manifest': [{'path': 'input', 'sha256': module.sha(root / 'input')}]}
            if quality:
                data.update(stage='quality', role='sdd-evaluator', task_id='T-001')
            invocation = root / 'template.json'
            invocation.write_text(json.dumps(data))
            args = SimpleNamespace(repository_root=root, invocation=invocation,
                manifest_sha256=module.sha(invocation), output=root / 'output',
                codex='/bin/true', fixed_input_record=None, fixed_input_snapshot=None,
                runtime='bash', timeout=10, selected_model=selected_model, selected_effort=selected_effort)
            if path_escape:
                args.output = root / '..' / ('escape-' + root.name)
            class FakeRpc:
                def __init__(self, command, cwd, output, timeout):
                    self.events = []
                    self.cwd = str(cwd)
                def request(self, method, params, **kwargs):
                    calls.append(method)
                    if method == 'config/read':
                        return {'config': {'mcp_servers': {}, 'features': dict.fromkeys(
                            ('plugins', 'apps', 'hooks', 'multi_agent'), False), 'web_search': 'disabled'}}
                    if method == 'thread/start':
                        if selected_model:
                            assert params['model'] == selected_model
                        if selected_effort:
                            assert params['config']['model_reasoning_effort'] == selected_effort
                        return {'model': 'different' if model_bad else selected_model,
                                'reasoningEffort': 'different' if effort_bad else selected_effort, 'thread': {'id': 'host-allocated', 'turns': [1] if identity_bad else [],
                                           'status': {'type': 'idle'},
                                           'environments': [{'environmentId': 'local', 'cwd': self.cwd}]},
                                'activePermissionProfile': {'id': 'wrong' if profile_bad else module.PROFILE}}
                    if method == 'turn/start':
                        if selected_model:
                            assert params['model'] == selected_model
                        if selected_effort:
                            assert params['effort'] == selected_effort
                        self.events = [{'method': 'item/completed', 'params': {
                            'threadId': 'wrong' if event_bad else 'host-allocated', 'turnId': 'turn-1',
                            'item': {'type': 'agentMessage', 'text': json.dumps({
                                'schema': 'spec-reviewer-a/v1', 'stage': 'spec', 'role': 'spec-reviewer-a',
                                'run_id': 'wrong' if output_bad else 'host-allocated',
                                'host_session_id': 'host-allocated', 'verdict': 'NEEDS_WORK',
                                'checks': [{'id': 'REQ-TESTABILITY', 'result': 'FAIL'}],
                                'allowed_input_manifest': data['allowed_input_manifest']})}}},
                            {'method': 'turn/completed', 'params': {'threadId': 'host-allocated',
                             'turn': {'id': 'turn-1', 'status': 'completed'}}}]
                        if quality:
                            raw = ('RUN_ID: host-allocated\nHOST_SESSION_ID: host-allocated\n'
                                   'ALLOWED_INPUT_MANIFEST: output/invocation.json ' + module.sha(root / 'output/invocation.json') +
                                   '\nVERDICT: PASS\nFINDINGS:\n- None\nCHECKED:\n- Inspected admitted input.\n')
                            self.events[0]['params']['item']['text'] = raw
                            if not no_inspection:
                                self.events.insert(0, {'method': 'item/completed', 'params': {
                                    'threadId': 'host-allocated', 'turnId': 'turn-1', 'item': {
                                    'type': 'commandExecution', 'command': '/bin/cat input', 'exitCode': 0, 'cwd': self.cwd}}})
                        if timeout:
                            self.events = []
                        return {'turn': {'id': 'turn-1'}}
                    return {}
                def send(self, data):
                    pass
                def close(self):
                    calls.append('close')
                def receive(self):
                    raise TimeoutError('bounded wait')
            def reserve(*args, **kwargs):
                calls.append('reserve')
                if mutate:
                    (root / 'input').write_text('changed')
                bound = json.loads((root / 'output/invocation.json').read_text())
                inputs = '\n'.join(e['path'] + '\t' + e['sha256'] for e in bound['allowed_input_manifest'])
                fields = '|'.join(str(bound[key]) for key in ('sequence', 'stage', 'role', 'run_id', 'host_session_id', 'previous_record_sha256'))
                suffix = ('|scratch-declaration-v1|' + hashlib.sha256((bound['feature'] + '\n' + bound['scratch_root']).encode()).hexdigest()
                          if quality else '|allowed-inputs-v1|' + hashlib.sha256(inputs.encode()).hexdigest())
                digest = hashlib.sha256((fields + suffix).encode()).hexdigest()
                return SimpleNamespace(returncode=0 if reserve_ok else 1, stderr='', stdout=
                    'REVIEW_CONTEXT_OK ' + digest + ' sequence=2 previous_record_sha256=' + 'b'*64 + ' pre_append_tip_sequence=1 identity_unique=yes\n')
            def quality_delivery(invocation, pin, repository, scratch, reserve=True, **kwargs):
                self.assertEqual(module.sha(invocation), pin)
                bound = json.loads(invocation.read_text())
                self.assertEqual(bound['scratch_root'], str(scratch))
                self.assertEqual((scratch / 'input').read_text(), 'admitted')
                result = reserve_result()
                if result.returncode:
                    raise ValueError('delivery reservation rejected')
                print(result.stdout, end='')
                return 1
            reserve_result = reserve
            real_module = module.module
            def load_module(name, filename):
                return SimpleNamespace(check=quality_delivery) if name == 'codex_evaluator_delivery' else real_module(name, filename)
            with patch.object(module, 'module', side_effect=load_module), \
                 patch.object(module, 'Rpc', FakeRpc), \
                 patch.object(module, 'probe_permissions', return_value=[]), \
                 patch.object(module.transport, 'fixed_input_binding', return_value=None), \
                 patch.object(module.launcher, 'checked_input_paths'), \
                 patch.object(module.preflight, 'preflight'), \
                 patch.object(module.subprocess, 'run', side_effect=reserve):
                failed = not reserve_ok or mutate or identity_bad or profile_bad or output_bad or event_bad or timeout or path_escape or no_inspection or model_bad or effort_bad
                if failed:
                    with self.assertRaises((ValueError, TimeoutError)):
                        module.launch(args)
                    self.assertFalse((args.output / 'reviewer.json').exists())
                    self.assertFalse((args.output / 'evaluator.txt').exists())
                else:
                    result = module.launch(args)
                    if quality:
                        self.assertIn('VERDICT: PASS', result.read_text())
                    else:
                        self.assertEqual(json.loads(result.read_text())['verdict'], 'NEEDS_WORK')
            if calls:
                self.assertEqual(calls[-1], 'close')
            return calls

    def test_selected_model_and_effort_reach_native_thread_and_turn(self):
        calls = self.run_case(selected_model='fixture-model', selected_effort='high')
        self.assertLess(calls.index('reserve'), calls.index('turn/start'))

    def test_model_mismatch_stops_before_reservation_or_work(self):
        calls = self.run_case(selected_model='fixture-model', model_bad=True)
        self.assertNotIn('reserve', calls)
        self.assertNotIn('turn/start', calls)

    def test_effort_mismatch_stops_before_reservation_or_work(self):
        calls = self.run_case(selected_model='fixture-model', selected_effort='high', effort_bad=True)
        self.assertNotIn('reserve', calls)
        self.assertNotIn('turn/start', calls)

    def test_effort_without_model_is_rejected(self):
        with self.assertRaises(ValueError):
            module.selected_controls(SimpleNamespace(selected_effort='high'), ROOT, 'spec-reviewer-a')

    def test_quality_delivery_reserves_before_model(self):
        calls = self.run_case(quality=True)
        self.assertLess(calls.index('reserve'), calls.index('turn/start'))

    def test_quality_delivery_rejection_never_starts_model(self):
        self.assertNotIn('turn/start', self.run_case(quality=True, reserve_ok=False))

    def test_quality_pass_requires_observed_input_inspection(self):
        self.run_case(quality=True, no_inspection=True)

    def test_quality_text_contract_rejects_false_claims(self):
        raw = ('RUN_ID: id\nHOST_SESSION_ID: id\nALLOWED_INPUT_MANIFEST: invocation.json ' + 'a'*64 +
               '\nVERDICT: PASS\nFINDINGS:\n- None\nCHECKED:\n- Read source.\n')
        for changed in (raw.replace('RUN_ID: id', 'RUN_ID: foreign'),
                        raw.replace('a'*64, 'b'*64), raw.replace('- None', '- [Major] Missing tests'),
                        raw.replace('- Read source.', ''), raw + 'VERDICT: PASS\n'):
            with self.assertRaises(ValueError):
                module.transport.validate_evaluator_text(changed, 'id', 'invocation.json', 'a'*64)

    def test_read_observation_rejects_shell_tricks(self):
        scratch = Path('/projection')
        for command in ('echo /bin/cat input', '/bin/cat invocation.json', '/bin/cat input; echo yes',
                        '/bin/cat ../outside', '/bin/cat input /outside'):
            self.assertFalse(module.observed_input_read({'command': command, 'exitCode': 0, 'cwd': str(scratch)}, {'input': 'a'*64}, scratch))
        self.assertTrue(module.observed_input_read({'command': "/bin/bash -lc '/bin/cat input'", 'exitCode': 0, 'cwd': str(scratch)}, {'input': 'a'*64}, scratch))
        for cwd in ('/outside', 'relative', ''):
            self.assertFalse(module.observed_input_read({'command': '/bin/cat input', 'exitCode': 0, 'cwd': cwd}, {'input': 'a'*64}, scratch))

    def test_output_parent_traversal_rejected_before_host(self):
        self.assertEqual(self.run_case(path_escape=True), [])

    @unittest.skipUnless(os.environ.get('SDD_TEST_CODEX_PERMISSIONS') == '1',
                         'opt-in native Linux permission probe; no model turn')
    def test_native_outside_read_write_network_denial(self):
        cli = shutil.which('codex')
        self.assertIsNotNone(cli, 'native probe requested but Codex is missing')
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            scratch = root / 'inputs'
            scratch.mkdir()
            output = root / 'logs'
            output.mkdir()
            outside = root / 'outside'
            outside.write_text('not admitted')
            rpc = module.Rpc(module.command_base(Path(cli).resolve(), scratch), scratch, output, 20)
            try:
                module.initialize(rpc)
                results = module.probe_permissions(rpc, scratch, outside)
                self.assertEqual([item['exitCode'] == 0 for item in results], [True, False, False, False, True])
                self.assertNotIn('turn/start', (output / 'native-events.jsonl').read_text())
            finally:
                rpc.close()

    def test_allocate_reserve_then_first_turn(self):
        calls = self.run_case()
        self.assertLess(calls.index('thread/start'), calls.index('reserve'))
        self.assertLess(calls.index('reserve'), calls.index('turn/start'))
        self.assertEqual(calls.count('turn/start'), 1)

    def test_failed_reservation_never_starts_model(self):
        self.assertNotIn('turn/start', self.run_case(reserve_ok=False))

    def test_input_mutation_after_reservation_never_starts_model(self):
        self.assertNotIn('turn/start', self.run_case(mutate=True))

    def test_nonempty_identity_never_reserves(self):
        self.assertNotIn('reserve', self.run_case(identity_bad=True))

    def test_wrong_profile_never_reserves(self):
        self.assertNotIn('reserve', self.run_case(profile_bad=True))

    def test_foreign_result_not_adopted(self):
        self.run_case(output_bad=True)

    def test_foreign_event_not_adopted(self):
        self.run_case(event_bad=True)

    def test_timeout_closes_host_without_candidate(self):
        self.run_case(timeout=True)

    def test_task_role_contract_encoding(self):
        for role in ('task-reviewer-a', 'task-reviewer-b'):
            data = dict(stage='task', role=role, run_id='id', host_session_id='id', allowed_input_manifest=[])
            result = dict(data, schema=role+'/v1', verdict='BLOCKED', checks=[{}])
            if role.endswith('-a'):
                result.update(stage='task-review', role='reviewer-a', manifest=[])
            else:
                result['manifest'] = {'allowed_inputs': []}
            module.check_result(result, data)

    def test_session_preferences_resolve_same_versioned_plugin_release(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            cache = base / 'cache/sdd-plugins'
            version = '1.23.1'
            review_scripts = cache / 'sdd-review-loop' / version / 'scripts'
            impl_scripts = cache / 'sdd-implementation' / version / 'scripts'
            impl_scripts.mkdir(parents=True)
            helper_path = impl_scripts / 'session-models.py'
            shutil.copyfile(ROOT / 'plugins/sdd-implementation/scripts/session-models.py', helper_path)
            helper = module.module('versioned_session_fixture', helper_path)
            project = base / 'project'; project.mkdir()
            store = helper.Store(project, base / 'private')
            item = {'host': 'codex-cli', 'model': 'fixture-native', 'effort': 'high'}
            catalog = {'observed_at': helper.now(), 'providers': {h: {'installed': True,
                'status': 'listed', 'reason': 'fixture'} for h in helper.HOSTS}, 'models': [
                {'host': 'codex-cli', 'model': 'fixture-native', 'efforts': ['high'],
                 'source': 'fixture', 'verification': 'listed', 'selectable': True}]}
            roles = {r: {'disabled': True} for r in helper.ROLES}; roles['spec-reviewer-a'] = item
            helper.write_json(store.path('session'), {'schema': 'session-model-selection/v1',
                'project_id': store.project_id, 'session_id': 'session', 'host': 'codex-cli',
                'status': 'confirmed', 'catalog': catalog, 'main': item, 'roles': roles,
                'confirmed_at': helper.now()})
            args = SimpleNamespace(model_session='session', model_config_home=base / 'private')
            with patch.object(module, '__file__', str(review_scripts / 'launch-codex-review.py')), \
                    patch.object(module.transport, '__file__', str(review_scripts / 'validate-nontty-spec-launch.py')):
                self.assertEqual(module.selected_controls(args, project, 'spec-reviewer-a'), ('fixture-native', 'high'))
                other = impl_scripts.parent.parent / '2.0.0/scripts'; other.mkdir(parents=True)
                helper_path.rename(other / helper_path.name)
                with self.assertRaisesRegex(ValueError, 'missing trusted review runtime asset'):
                    module.selected_controls(args, project, 'spec-reviewer-a')

    def test_runtime_asset_does_not_use_reviewed_project(self):
        self.assertEqual(module.transport.plugin_file('plugins/sdd-quality-loop/scripts/validate-review-context-set.sh'),
                         ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh')
        with self.assertRaises(ValueError):
            module.transport.plugin_file('plugins/sdd-review-loop/../secret')



class EvaluatorRoleContract(unittest.TestCase):
    def test_codex_role_preserves_canonical_evaluator_boundary(self):
        canonical = (ROOT / 'plugins/sdd-quality-loop/agents/evaluator.md').read_text(encoding='utf-8')
        body = canonical.split('---', 2)[2].strip()
        if body.startswith('<!-- x-sdd-effort:'):
            body = body.split('\n', 1)[1].strip()
        role = tomllib.loads((ROOT / '.codex/agents/sdd-evaluator.toml').read_text(encoding='utf-8'))
        self.assertEqual(role['sandbox_mode'], 'read-only')
        self.assertEqual(role['developer_instructions'].strip(), body)


if __name__ == '__main__':
    unittest.main()
