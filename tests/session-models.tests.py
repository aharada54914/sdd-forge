#!/usr/bin/env python3
"""Session selection user paths and native handoff; no real account/model calls."""
import hashlib
import importlib.util
import io
import json
import os
import shutil
from pathlib import Path
from types import SimpleNamespace
import subprocess
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-implementation/scripts'


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


m = load('session_models', SCRIPTS / 'session-models.py')
hook = load('session_hook', SCRIPTS / 'session-model-start.py')


def catalog():
    return {'observed_at': m.now(), 'providers': {h: {'installed': True, 'status': 'unverified', 'reason': ''} for h in m.HOSTS},
            'models': [{'host': h, 'model': n, 'efforts': ['low', 'high'] if h == 'codex-cli' else [],
                        'source': 'fixture', 'verification': 'unverified', 'selectable': True}
                       for h, n in [('codex-cli', 'fixture-gpt'), ('claude-code', 'sonnet'), ('gemini-cli', 'flash')]]}


class Sessions(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.project = self.base / 'project'
        self.project.mkdir()
        self.store = m.Store(self.project, self.base / 'private')
        self.discovery = patch.object(m, 'discover', side_effect=lambda *_: catalog())
        self.discovery.start()
        self.addCleanup(self.discovery.stop)
        m.begin(self.store, 'codex-cli', 'one')

    def configure(self):
        m.set_choice(self.store, 'one', 'main', 'codex-cli', 'fixture-gpt', 'high')
        for role in m.ROLES:
            m.set_choice(self.store, 'one', role, 'codex-cli', 'fixture-gpt', None)

    def cli(self, *args, code=0, driver=SCRIPTS / 'session-models.py', pwsh=None):
        command = [sys.executable, str(driver), '--project', str(self.project),
                   '--config-home', str(self.base / 'private'), *args]
        env = os.environ.copy()
        if pwsh:
            env['SDD_TEST_SESSION_ARGS'] = json.dumps(command)
            command = [pwsh, '-NoProfile', '-Command',
                       '$cmd = @(ConvertFrom-Json $env:SDD_TEST_SESSION_ARGS); '
                       '$exe, $params = $cmd; & $exe @params; exit $LASTEXITCODE']
        result = subprocess.run(command, cwd=self.project, env=env, text=True,
                                capture_output=True, timeout=15)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result.stderr if code else result.stdout

    def test_optional_roles_can_be_disabled_on_a_single_cli_install(self):
        state = self.store.state('one')
        for host, provider in state['catalog']['providers'].items():
            provider['installed'] = host == 'codex-cli'
        state['catalog']['models'] = [item for item in state['catalog']['models'] if item['host'] == 'codex-cli']
        m.write_json(self.store.path('one'), state)
        roles = {'implementer', 'investigator', 'spec-reviewer-a', 'spec-reviewer-b', 'evaluator',
                 'domain-reviewer-a', 'domain-reviewer-b', 'workflow-auditor-a', 'workflow-auditor-b',
                 'diagnosis', 'self-improvement'}
        self.assertEqual(set(m.ROLES), roles)
        self.cli('set', '--session', 'one', '--role', 'main', '--host', 'codex-cli', '--model', 'fixture-gpt')
        for role in sorted(roles):
            self.cli('disable', '--session', 'one', '--role', role)
        confirmed = json.loads(self.cli('confirm', '--session', 'one', '--main-applied'))
        self.assertEqual(confirmed['status'], 'confirmed')
        for role in sorted(roles):
            with self.subTest(role=role):
                self.assertEqual(confirmed['roles'][role], {'disabled': True})
                err = json.loads(self.cli('selection', '--session', 'one', '--role', role, code=2))
                self.assertEqual(err['reason'], 'selection-required')
                self.assertIn('無効', err['message'])

    def test_dynamic_native_effort_and_context_model_survive_save_and_schema(self):
        state = self.store.state('one')
        state['catalog']['models'].append({'host': 'claude-code', 'model': 'claude-new[1m]',
            'efforts': ['medium', 'ultra'], 'source': 'native fixture', 'verification': 'listed',
            'selectable': True, 'display_name': 'New model', 'default_effort': 'medium'})
        m.write_json(self.store.path('one'), state)
        self.configure()
        m.set_choice(self.store, 'one', 'investigator', 'claude-code', 'claude-new[1m]', 'ultra')
        m.confirm(self.store, 'one', True)
        self.assertEqual(m.selection(self.store, 'one', 'investigator')['effort'], 'ultra')
        import jsonschema
        jsonschema.validate(self.store.state('one'), json.loads((ROOT / 'contracts/session-model-selection.schema.json').read_text()))

    def test_expired_picker_refresh_preserves_pending_choices_and_requires_confirmation(self):
        self.configure()
        m.confirm(self.store, 'one', True)
        state = self.store.state('one')
        state['catalog']['observed_at'] = '2000-01-01T00:00:00Z'
        m.write_json(self.store.path('one'), state)
        refreshed = m.begin(self.store, 'codex-cli', 'one')
        self.assertEqual(refreshed['status'], 'pending')
        self.assertEqual(refreshed['roles'], state['roles'])
        with self.assertRaises(m.SelectionError):
            m.selection(self.store, 'one', 'investigator')
        self.assertFalse(m.catalog_stale(refreshed['catalog']))

    def test_expiry_does_not_reopen_cancelled_session(self):
        state = self.store.state('one')
        state['status'] = 'cancelled'
        state['catalog']['observed_at'] = '2000-01-01T00:00:00Z'
        m.write_json(self.store.path('one'), state)
        self.assertEqual(m.begin(self.store, 'codex-cli', 'one')['status'], 'cancelled')
        self.assertEqual(m.begin(self.store, 'codex-cli', 'one', True)['status'], 'pending')

    def test_refresh_rejects_retired_effort_without_substitution(self):
        self.configure()
        m.confirm(self.store, 'one', True)
        changed = catalog()
        changed['models'][0]['efforts'] = ['low']
        with patch.object(m, 'discover', return_value=changed):
            m.begin(self.store, 'codex-cli', 'one', True)
        with self.assertRaises(m.SelectionError):
            m.confirm(self.store, 'one', True)
        self.assertEqual(self.store.state('one')['main']['effort'], 'high')

    def test_cli_error_is_typed_without_traceback(self):
        result = subprocess.run([sys.executable, str(SCRIPTS / 'session-models.py'),
                                 '--project', str(self.project), '--config-home', str(self.base / 'private'),
                                 'selection', '--session', 'one', '--role', 'investigator'],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stderr)['schema'], 'session-model-error/v1')
        self.assertNotIn('Traceback', result.stderr)

    def test_public_schema_accepts_preferences_and_pending_confirmed_states(self):
        import jsonschema
        schema = json.loads((ROOT / 'contracts/session-model-selection.schema.json').read_text())
        jsonschema.Draft202012Validator.check_schema(schema)
        jsonschema.validate(self.store.state('one'), schema)
        self.configure()
        m.confirm(self.store, 'one', True)
        jsonschema.validate(self.store.state('one'), schema)
        jsonschema.validate(self.store.profile(), schema)

    def test_pending_never_admits_a_role(self):
        with self.assertRaises(m.SelectionError):
            m.selection(self.store, 'one', 'investigator')

    def test_main_cannot_move_to_another_cli(self):
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'main', 'claude-code', 'sonnet', None)

    def test_cross_provider_role_selection_and_confirmation(self):
        self.configure()
        m.set_choice(self.store, 'one', 'investigator', 'claude-code', 'sonnet', None)
        m.confirm(self.store, 'one', True)
        self.assertEqual(m.selection(self.store, 'one', 'investigator')['host'], 'claude-code')
        self.assertEqual(m.selection(self.store, 'one', 'main')['effort'], 'high')
        self.assertEqual(m.selection(self.store, 'one', 'main')['proof'], 'configured-only')

    def test_confirmation_requires_main_acknowledgment_and_inherits_unset_roles(self):
        self.configure()
        err = json.loads(self.cli('confirm', '--session', 'one', code=2))
        self.assertIn('--main-applied', err['message'])
        state = self.store.state('one')
        self.assertEqual(state['status'], 'pending')
        state['roles']['evaluator'] = None
        m.write_json(self.store.path('one'), state)
        confirmed = json.loads(self.cli('confirm', '--session', 'one', '--main-applied'))
        self.assertEqual(confirmed['roles']['evaluator'], {'inherit': True})
        selected = json.loads(self.cli('selection', '--session', 'one', '--role', 'evaluator'))
        self.assertTrue(selected['inherited'])
        self.assertEqual((selected['host'], selected['model'], selected['effort']),
                         ('codex-cli', 'fixture-gpt', 'high'))

    def test_previous_preferences_are_not_session_confirmation(self):
        self.configure()
        m.confirm(self.store, 'one', True)
        second = m.begin(self.store, 'codex-cli', 'two')
        self.assertEqual(second['main']['model'], 'fixture-gpt')
        self.assertEqual(second['status'], 'pending')
        m.confirm(self.store, 'two', True)
        self.assertEqual(m.selection(self.store, 'two', 'evaluator')['model'], 'fixture-gpt')

    def test_separate_cli_main_does_not_overwrite_prior_main(self):
        self.configure()
        m.confirm(self.store, 'one', True)
        m.begin(self.store, 'claude-code', 'claude')
        m.set_choice(self.store, 'claude', 'main', 'claude-code', 'sonnet', None)
        m.confirm(self.store, 'claude', True)
        self.assertEqual(set(self.store.profile()['mains']), {'codex-cli', 'claude-code'})

    def test_unknown_and_nonselectable_candidates_are_rejected(self):
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'main', 'codex-cli', 'unknown', None)
        state = self.store.state('one')
        state['catalog']['models'][0]['selectable'] = False
        m.write_json(self.store.path('one'), state)
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'main', 'codex-cli', 'fixture-gpt', None)

    def test_unsupported_effort_is_not_silently_downgraded(self):
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'investigator', 'gemini-cli', 'flash', 'high')

    def test_edit_invalidates_confirmation(self):
        self.configure()
        m.confirm(self.store, 'one', True)
        m.set_choice(self.store, 'one', 'evaluator', 'codex-cli', 'fixture-gpt', 'low')
        with self.assertRaises(m.SelectionError):
            m.selection(self.store, 'one', 'evaluator')

    def test_public_cli_rejects_retired_panelist_roles_before_writing(self):
        path = self.store.path('one')
        before = path.read_bytes()
        for role, host, model in [('panelist-gpt', 'gemini-cli', 'flash'), ('panelist-gemini', 'claude-code', 'sonnet')]:
            with self.subTest(role=role):
                err = self.cli('set', '--session', 'one', '--role', role, '--host', host, '--model', model, code=2)
                self.assertIn('invalid choice', err)
                self.assertIn(role, err)
                self.assertEqual(path.read_bytes(), before)

    def test_new_catalog_rechecks_saved_model(self):
        self.configure()
        m.confirm(self.store, 'one', True)
        changed = catalog()
        changed['models'] = changed['models'][1:]
        with patch.object(m, 'discover', return_value=changed):
            m.begin(self.store, 'codex-cli', 'two')
        with self.assertRaises(m.SelectionError):
            m.confirm(self.store, 'two', True)

    def test_begin_is_idempotent_but_refresh_invalidates_confirmation(self):
        self.configure()
        m.confirm(self.store, 'one', True)
        self.assertEqual(m.begin(self.store, 'codex-cli', 'one')['status'], 'confirmed')
        self.assertEqual(m.begin(self.store, 'codex-cli', 'one', True)['status'], 'pending')

    def test_cross_host_session_reuse_is_rejected_including_refresh(self):
        for refresh in (False, True):
            with self.subTest(refresh=refresh), self.assertRaises(m.SelectionError):
                m.begin(self.store, 'claude-code', 'one', refresh)

    def test_custom_candidate_is_unverified_and_does_not_gain_efforts(self):
        state = m.add_candidate(self.store, 'one', 'gemini-cli', 'gemini-custom')
        item = state['catalog']['models'][-1]
        self.assertEqual(item['verification'], 'unverified')
        self.assertEqual(item['efforts'], [])
        m.set_choice(self.store, 'one', 'investigator', 'gemini-cli', 'gemini-custom', None)

    def test_cancel_blocks_configuration_and_confirmation(self):
        state = self.store.state('one')
        state['status'] = 'cancelled'
        m.write_json(self.store.path('one'), state)
        with self.assertRaises(m.SelectionError):
            m.confirm(self.store, 'one', True)
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'main', 'codex-cli', 'fixture-gpt', None)

    def test_malformed_confirmation_and_catalog_fail_closed(self):
        self.configure()
        m.confirm(self.store, 'one', True)
        state = self.store.state('one')
        original = json.loads(json.dumps(state))
        state['confirmed_at'] = None
        m.write_json(self.store.path('one'), state)
        with self.assertRaises(m.SelectionError):
            m.selection(self.store, 'one', 'investigator')
        original['catalog']['models'][0]['selectable'] = 'false'
        m.write_json(self.store.path('one'), original)
        with self.assertRaises(m.SelectionError):
            self.store.state('one')

    def test_private_storage_is_not_in_project(self):
        with self.assertRaises(m.SelectionError):
            m.Store(self.project, self.project / 'config')
        self.assertFalse(any(self.project.iterdir()))
        if os.name != 'nt':
            self.assertEqual(self.store.path('one').stat().st_mode & 0o777, 0o600)
            self.assertEqual(self.store.root.stat().st_mode & 0o777, 0o700)

    def test_path_escape_and_option_injection_are_rejected(self):
        for ident in ('../../elsewhere', '--model=oops', 'model;command', 'model\ntext'):
            with self.subTest(ident=ident), self.assertRaises(m.SelectionError):
                m.set_choice(self.store, 'one', 'main', 'codex-cli', ident, None)
        with self.assertRaises(m.SelectionError):
            self.store.path('../escape')

    def test_project_isolation(self):
        other = self.base / 'other'
        other.mkdir()
        second = m.Store(other, self.base / 'private')
        self.assertNotEqual(self.store.root, second.root)
        self.assertFalse(second.path('one').exists())

    @unittest.skipIf(os.name == 'nt', 'symlink permissions vary on Windows')
    def test_profile_symlink_is_never_overwritten(self):
        outside = self.base / 'outside'
        outside.write_text('{}')
        self.store.profile_path.symlink_to(outside)
        with self.assertRaises(m.SelectionError):
            self.store.profile()
        self.assertEqual(outside.read_text(), '{}')

    def test_duplicate_json_members_are_rejected(self):
        self.store.profile_path.write_text('{"schema":"x","schema":"y"}')
        with self.assertRaises(m.SelectionError):
            self.store.profile()

    def test_request_bridge_preserves_observation_and_requires_host_match(self):
        self.configure()
        m.confirm(self.store, 'one', True)
        request = {'role': 'investigator', 'host': 'codex-cli', 'policy_path': 'policy.json',
                   'cli': {'model_id': None, 'policy': None}, 'requested_effort': None,
                   'observation_path': 'original-observation.json'}
        policy = {'models': [{'id': 'catalog/id', 'hosts': {'codex-cli': 'fixture-gpt'}}]}
        helper = SimpleNamespace(_validate_policy_request=lambda _: None)
        original_read = m.read_json
        def read(path):
            return policy if Path(path).name == 'policy.json' else original_read(path)
        with patch.object(m, 'load_policy', return_value=helper), patch.object(m, 'read_json', side_effect=read):
            result = m.policy_request(self.store, 'one', 'investigator', request)
            self.assertEqual(result['cli'], {'model_id': 'catalog/id', 'policy': 'pinned'})
            self.assertEqual(result['observation_path'], request['observation_path'])
            self.assertIsNone(request['cli']['model_id'])
            with self.assertRaises(m.SelectionError):
                m.policy_request(self.store, 'one', 'investigator', {**request, 'host': 'gemini-cli'})
            with self.assertRaises(m.SelectionError):
                m.policy_request(self.store, 'one', 'investigator', {**request, 'cli': {'model_id': 'different', 'policy': 'pinned'}})

    def request_fixture(self):
        self.configure()
        m.set_choice(self.store, 'one', 'investigator', 'codex-cli', 'fixture-gpt', 'high')
        m.confirm(self.store, 'one', True)
        (self.project / 'policy.json').write_text(json.dumps({'models': [
            {'id': 'fixture/id', 'hosts': {'codex-cli': 'fixture-gpt'}}]}))
        (self.project / 'obs.json').write_text('{}')
        return {'schema': 'model-policy-request/v1', 'role': 'investigator', 'risk': 'standard',
                'host': 'codex-cli', 'policy_path': 'policy.json', 'observation_path': 'obs.json',
                'project_config_path': None, 'cli': {'model_id': None, 'policy': None},
                'budget': None, 'requested_effort': None, 'resume_selection_path': None}

    def request_cli(self, request, *extra, code=0, **options):
        path = self.project / 'request with space.json'
        path.write_text(json.dumps(request), encoding='utf-8')
        original = path.read_bytes()
        session_bytes = self.store.path('one').read_bytes()
        output = self.cli('request', '--session', 'one', '--role', 'investigator', '--input', str(path),
                          *extra, code=code, **options)
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(self.store.path('one').read_bytes(), session_bytes)
        return output

    def test_request_cli_preserves_input_and_rejects_conflicts(self):
        request = self.request_fixture()
        expected = {**request, 'requested_effort': 'high', 'cli': {'model_id': 'fixture/id', 'policy': 'pinned'}}
        self.assertEqual(json.loads(self.request_cli(request)), expected)
        for update, reason in [({'host': 'gemini-cli'}, '一致'), ({'role': 'evaluator'}, '一致'),
                               ({'requested_effort': 'low'}, '競合'),
                               ({'cli': {'model_id': 'other', 'policy': 'pinned'}}, '競合')]:
            with self.subTest(update=update):
                err = json.loads(self.request_cli({**request, **update}, code=2))
                self.assertEqual(err['reason'], 'selection-required')
                self.assertIn(reason, err['message'])
        override = self.request_cli(request, '--vendor=gemini', code=2)
        self.assertIn('unrecognized arguments: --vendor=gemini', override)

    def test_powershell_request_rejects_explicit_model_conflict(self):
        pwsh = os.environ.get('SDD_TEST_PWSH') or shutil.which('pwsh')
        if not pwsh:
            self.skipTest('PowerShell not configured')
        request = self.request_fixture()
        request['cli'] = {'model_id': 'different', 'policy': 'pinned'}
        err = json.loads(self.request_cli(request, code=2, pwsh=pwsh))
        self.assertEqual(err['reason'], 'selection-required')
        self.assertIn('競合', err['message'])

    def test_request_uses_only_its_installed_policy_version(self):
        request = self.request_fixture()
        owner = self.base / 'cache/sdd-implementation'
        version = json.loads((SCRIPTS.parent / '.codex-plugin/plugin.json').read_text())['version']
        current = owner / version / 'scripts'
        other = owner / '1.26.0/scripts'
        for scripts in (current, other):
            scripts.mkdir(parents=True)
            for name in ('session-models.py', 'model-policy.py'):
                shutil.copyfile(SCRIPTS / name, scripts / name)
        driver = current / 'session-models.py'
        self.assertEqual(json.loads(self.request_cli(request, driver=driver))['cli']['model_id'], 'fixture/id')
        (current / 'model-policy.py').unlink()
        err = json.loads(self.request_cli(request, driver=driver, code=2))
        self.assertEqual(err['reason'], 'selection-required')
        self.assertIn('model-policy.py', err['message'])

    def test_explicit_model_is_parsed_before_missing_session_error(self):
        err = json.loads(self.cli('set', '--session', 'absent', '--role', 'evaluator', '--host', 'codex-cli',
                                  '--model', 'fixture-gpt', code=2))
        self.assertEqual(err['schema'], 'session-model-error/v1')
        self.assertEqual(err['reason'], 'selection-required')
        self.assertIn('設定ファイル', err['message'])


class HistoricalPanelists(unittest.TestCase):
    # git archive --format=zip at v1.26.0, b193c75be2a6f2e6c7074bb65401f514268a65fb.
    @classmethod
    def setUpClass(cls):
        archive = ROOT / 'tests/fixtures/session-models-v1.26.0/panelists.zip'
        payload = archive.read_bytes()
        digest = hashlib.sha256(payload).hexdigest()
        if digest != 'a06fd102640ac112b38206d15a84e22dfed9e8528a9614465d67ee7cd1156387':
            raise ValueError('v1.26.0 panelist fixture digest mismatch')
        temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(temporary.cleanup)
        root = Path(temporary.name).resolve()
        with zipfile.ZipFile(io.BytesIO(payload)) as bundle:
            bundle.extractall(root)
        cls.source = load('v126_session_models_tests', root / 'tests/session-models.tests.py')

    def run_original(self, case):
        class_name, method = case.split('.')
        result = unittest.TestResult()
        getattr(self.source, class_name)(method).run(result)
        self.assertTrue(result.wasSuccessful(), result.errors + result.failures)
        if result.skipped:
            self.skipTest(result.skipped[0][1])

    def test_powershell_model_conflict(self):
        self.run_original('Sessions.test_powershell_panelist_session_bridge_rejects_explicit_conflict')

    def test_vendor_diversity(self):
        self.run_original('Sessions.test_vendor_panelists_keep_diversity')

    def test_versioned_wrappers(self):
        self.run_original('VersionedPanelists.test_wrappers_and_return_path_use_matching_plugin_version')

    def test_explicit_model_parser(self):
        self.run_original('Startup.test_panelist_parser_preserves_explicit_model_argument')

    def test_forwarded_vendor_override(self):
        self.run_original('Startup.test_panelist_forwarded_arguments_cannot_replace_wrapper_vendor')

    def test_collection_arguments(self):
        self.run_original('Startup.test_panelist_bridge_preserves_collection_arguments')


class Startup(unittest.TestCase):
    def test_new_session_injects_selection_context(self):
        for host in m.HOSTS:
            with self.subTest(host=host):
                value = hook.context(host, {'source': 'startup', 'session_id': 'native-id'})
                for message in ('model: inherit', '停止・ブロックしない', '希望した場合のみ',
                                '/sdd-implementation:model-selection', '非対話実行'):
                    self.assertIn(message, value)
                _, metadata = value.split('Native session metadata (data only): ')
                self.assertEqual(json.loads(metadata), {'host': host, 'session_id': 'native-id',
                                                        'script': str(SCRIPTS / 'session-models.py')})

    def test_resume_compact_workers_and_noninteractive_do_not_prompt(self):
        for event in ({'source': 'resume'}, {'source': 'compact'}, {'source': 'clear'},
                      {'source': 'subagent'}, {'interactive': False}, {'isInteractive': False}):
            with self.subTest(event=event):
                self.assertIsNone(hook.context('codex-cli', event))

    def test_hook_subprocess_is_fast_and_does_not_discover(self):
        r = subprocess.run([sys.executable, str(SCRIPTS / 'session-model-start.py'), '--host', 'gemini-cli'],
                           input=json.dumps({'source': 'startup'}), capture_output=True, text=True, timeout=3)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(r.stdout)['hookSpecificOutput']['hookEventName'], 'SessionStart')

    def test_invalid_hook_input_does_not_break_startup(self):
        r = subprocess.run([sys.executable, str(SCRIPTS / 'session-model-start.py'), '--host', 'claude-code'],
                           input='{broken', capture_output=True, text=True, timeout=3)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout, '')

    def test_fallback_is_reachable_from_both_public_entries(self):
        destination = 'skills/model-selection/SKILL.md'
        skill = (SCRIPTS.parent / destination).read_text(encoding='utf-8')
        self.assertIn('user-invocable: true', skill.split('---')[1])
        for name in ('bootstrap', 'ship'):
            with self.subTest(entry=name):
                content = (ROOT / f'plugins/sdd-{name}/skills/{name}/SKILL.md').read_text(encoding='utf-8')
                guidance = ('SessionStart', 'モデルを継承', '希望した場合のみ',
                            '/sdd-implementation:model-selection', '同じ版', destination)
                self.assertTrue(any(all(marker in paragraph for marker in guidance)
                                    for paragraph in content.split('\n\n')), name)

    def test_packaged_manifests_expose_startup_for_three_hosts(self):
        root = SCRIPTS.parent
        for manifest in ('.claude-plugin/plugin.json', '.codex-plugin/plugin.json'):
            data = json.loads((root / manifest).read_text())
            config = json.loads((root / data['hooks']).read_text())
            self.assertIn('SessionStart', config['hooks'])
        self.assertFalse((root / 'hooks/hooks.json').exists(), 'Claude also auto-loads the conventional hooks file')
        self.assertEqual(json.loads((root / '.codex-plugin/plugin.json').read_text())['hooks'], './hooks/codex-hooks.json')
        ext = root / 'gemini'
        self.assertEqual(json.loads((ext / 'gemini-extension.json').read_text())['contextFileName'], 'GEMINI.md')
        self.assertIn('${extensionPath}', (ext / 'hooks/hooks.json').read_text())
        self.assertEqual(json.loads((ext / 'hooks/hooks.json').read_text())['hooks']['SessionStart'][0]['hooks'][0]['timeout'], 10000)


@unittest.skipIf(os.name == 'nt', 'POSIX CLI doubles; Windows quoting has separate native argument suites')
class GeminiInstaller(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload = load('session_install_payload', ROOT / 'tests/lib/install-payload-check.py')
        cls.fixture = cls.payload.Fixture(ROOT)

    @classmethod
    def tearDownClass(cls):
        cls.fixture.close()

    def run_install(self, runtime, plugins='sdd-bootstrap'):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            env = self.payload.scenario_env(base)
            binary = base / 'bin'
            binary.mkdir()
            log = base / 'gemini-log.jsonl'
            fake = binary / 'gemini'
            fake.write_text('#!' + sys.executable + '\nimport json,os,sys\nwith open(os.environ["GEMINI_TEST_LOG"],"a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n')
            fake.chmod(0o755)
            env.update(PATH=str(binary) + os.pathsep + os.environ['PATH'], GEMINI_TEST_LOG=str(log))
            installed = base / 'installed root'
            if runtime == 'bash':
                args = ['bash', str(ROOT / 'install.sh'), '--source-directory', str(self.fixture.path),
                        '--install-root', str(installed), '--target', 'Gemini', '--plugins', plugins,
                        '--skip-mcp', '--skip-agent-install']
            else:
                executable = os.environ.get('SDD_TEST_PWSH') or shutil.which('pwsh')
                if not executable:
                    self.skipTest('PowerShell not configured')
                args = [executable, '-NoProfile', '-File', str(ROOT / 'install.ps1'),
                        '-SourceDirectory', str(self.fixture.path), '-InstallRoot', str(installed),
                        '-Target', 'Gemini', '-Plugins', plugins, '-SkipMcp', '-SkipAgentInstall']
            result = subprocess.run(args, capture_output=True, text=True, env=env, timeout=90)
            self.assertEqual(result.returncode, 0, result.stdout[-2000:] + result.stderr[-2000:])
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            resolved_installed = installed.resolve()
            normalized_calls = [
                [*c[:3], str(Path(c[3]).resolve())]
                if len(c) == 4 and c[:3] == ['extensions', 'link', '--consent'] else c
                for c in calls
            ]
            if plugins == 'sdd-bootstrap':
                self.assertEqual(normalized_calls, [
                    ['extensions', 'link', '--consent', str(resolved_installed / 'plugins/sdd-bootstrap/gemini')],
                    ['extensions', 'link', '--consent', str(resolved_installed / 'plugins/sdd-review-loop/gemini')],
                    ['extensions', 'link', '--consent', str(resolved_installed / 'plugins/sdd-implementation/gemini')],
                ])
                self.assertTrue((installed / 'plugins/sdd-implementation/scripts/session-models.py').is_file())
                self.assertTrue((installed / 'plugins/sdd-implementation/scripts/model-discovery.py').is_file())
                plugin = installed / 'plugins/sdd-implementation'
                for manifest in ('.claude-plugin/plugin.json', '.codex-plugin/plugin.json'):
                    selected_hook = json.loads((plugin / manifest).read_text())['hooks']
                    self.assertTrue((plugin / selected_hook).is_file())
                self.assertFalse((plugin / 'hooks/hooks.json').exists())
                if runtime == 'bash':
                    args = ['bash', str(ROOT / 'uninstall.sh'), '--install-root', str(installed),
                            '--target', 'Gemini', '--plugins', 'sdd-implementation', '--keep-files',
                            '--skip-mcp-uninstall', '--skip-agent-uninstall']
                else:
                    args = [executable, '-NoProfile', '-File', str(ROOT / 'uninstall.ps1'),
                            '-InstallRoot', str(installed), '-Target', 'Gemini', '-Plugins', 'sdd-implementation',
                            '-KeepFiles', '-SkipMcpUninstall', '-SkipAgentUninstall']
                result = subprocess.run(args, capture_output=True, text=True, env=env, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                calls = [json.loads(line) for line in log.read_text().splitlines()]
                self.assertEqual(calls[-1], ['extensions', 'uninstall', 'sdd-forge-model-selection'])
            else:
                self.assertEqual(normalized_calls, [
                    ['extensions', 'link', '--consent', str(resolved_installed / 'plugins/sdd-review-loop/gemini')],
                ])

    def test_bash_bootstrap_installs_picker_and_unregisters_gemini(self):
        self.run_install('bash')

    def test_powershell_bootstrap_installs_picker_and_unregisters_gemini(self):
        self.run_install('powershell')

    def test_unselected_implementation_does_not_register_extension(self):
        self.run_install('bash', 'sdd-review-loop')


if __name__ == '__main__':
    unittest.main()
