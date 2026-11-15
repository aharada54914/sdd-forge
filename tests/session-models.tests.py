#!/usr/bin/env python3
"""Session selection user paths and native handoff; no real account/model calls."""
import importlib.util
import json
import os
import shutil
from pathlib import Path
from types import SimpleNamespace
import subprocess
import sys
import tempfile
import unittest
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
panelist = load('session_panelist', SCRIPTS / 'session-panelist.py')


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
        self.discovery = patch.object(m, 'discover', side_effect=catalog)
        self.discovery.start()
        self.addCleanup(self.discovery.stop)
        m.begin(self.store, 'codex-cli', 'one')

    def configure(self):
        m.set_choice(self.store, 'one', 'main', 'codex-cli', 'fixture-gpt', 'high')
        for role in m.ROLES:
            host, name = ('gemini-cli', 'flash') if role == 'panelist-gemini' else ('codex-cli', 'fixture-gpt')
            m.set_choice(self.store, 'one', role, host, name, None)

    def test_optional_roles_can_be_disabled_on_a_single_cli_install(self):
        state = self.store.state('one')
        state['main'] = {'host': 'codex-cli', 'model': 'fixture-gpt', 'effort': None}
        state['roles'] = {role: {'disabled': True} for role in m.ROLES}
        state['catalog']['providers']['gemini-cli']['installed'] = False
        m.write_json(self.store.path('one'), state)
        self.assertEqual(m.confirm(self.store, 'one', True)['status'], 'confirmed')
        with self.assertRaisesRegex(m.SelectionError, '無効'):
            m.selection(self.store, 'one', 'panelist-gemini')

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
        self.configure(); m.confirm(self.store, 'one', True)
        jsonschema.validate(self.store.state('one'), schema)
        jsonschema.validate(self.store.profile(), schema)

    def test_pending_never_admits_a_role(self):
        with self.assertRaises(m.SelectionError):
            m.selection(self.store, 'one', 'investigator')

    def test_main_cannot_move_to_another_cli(self):
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'main', 'claude-code', 'sonnet', None)

    def test_powershell_panelist_session_bridge_rejects_explicit_conflict(self):
        executable = os.environ.get('SDD_TEST_PWSH') or shutil.which('pwsh')
        if not executable:
            self.skipTest('PowerShell not configured')
        self.configure(); m.confirm(self.store, 'one', True)
        result = subprocess.run([executable, '-NoProfile', '-File',
                                 str(ROOT / 'plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1'),
                                 '--model-session', 'one', '--model-config-home', str(self.base / 'private'),
                                 '--model', 'different'], cwd=self.project, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('SESSION_MODEL_SELECTION_REQUIRED', result.stderr)
        self.assertIn('競合', result.stderr)

    def test_cross_provider_role_selection_and_confirmation(self):
        self.configure()
        m.set_choice(self.store, 'one', 'investigator', 'claude-code', 'sonnet', None)
        m.confirm(self.store, 'one', True)
        self.assertEqual(m.selection(self.store, 'one', 'investigator')['host'], 'claude-code')
        self.assertEqual(m.selection(self.store, 'one', 'main')['effort'], 'high')
        self.assertEqual(m.selection(self.store, 'one', 'main')['proof'], 'configured-only')

    def test_confirmation_requires_all_roles_and_main_acknowledgment(self):
        self.configure()
        with self.assertRaises(m.SelectionError):
            m.confirm(self.store, 'one')
        state = self.store.state('one'); state['roles']['evaluator'] = None
        m.write_json(self.store.path('one'), state)
        with self.assertRaises(m.SelectionError):
            m.confirm(self.store, 'one', True)

    def test_previous_preferences_are_not_session_confirmation(self):
        self.configure(); m.confirm(self.store, 'one', True)
        second = m.begin(self.store, 'codex-cli', 'two')
        self.assertEqual(second['main']['model'], 'fixture-gpt')
        self.assertEqual(second['status'], 'pending')
        m.confirm(self.store, 'two', True)
        self.assertEqual(m.selection(self.store, 'two', 'evaluator')['model'], 'fixture-gpt')

    def test_separate_cli_main_does_not_overwrite_prior_main(self):
        self.configure(); m.confirm(self.store, 'one', True)
        m.begin(self.store, 'claude-code', 'claude')
        m.set_choice(self.store, 'claude', 'main', 'claude-code', 'sonnet', None)
        m.confirm(self.store, 'claude', True)
        self.assertEqual(set(self.store.profile()['mains']), {'codex-cli', 'claude-code'})

    def test_unknown_and_nonselectable_candidates_are_rejected(self):
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'main', 'codex-cli', 'unknown', None)
        state = self.store.state('one'); state['catalog']['models'][0]['selectable'] = False
        m.write_json(self.store.path('one'), state)
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'main', 'codex-cli', 'fixture-gpt', None)

    def test_unsupported_effort_is_not_silently_downgraded(self):
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'investigator', 'gemini-cli', 'flash', 'high')

    def test_edit_invalidates_confirmation(self):
        self.configure(); m.confirm(self.store, 'one', True)
        m.set_choice(self.store, 'one', 'evaluator', 'codex-cli', 'fixture-gpt', 'low')
        with self.assertRaises(m.SelectionError):
            m.selection(self.store, 'one', 'evaluator')

    def test_vendor_panelists_keep_diversity(self):
        for role, host, name in [('panelist-gpt', 'gemini-cli', 'flash'), ('panelist-gemini', 'claude-code', 'sonnet')]:
            with self.subTest(role=role), self.assertRaises(m.SelectionError):
                m.set_choice(self.store, 'one', role, host, name, None)

    def test_new_catalog_rechecks_saved_model(self):
        self.configure(); m.confirm(self.store, 'one', True)
        changed = catalog(); changed['models'] = changed['models'][1:]
        with patch.object(m, 'discover', return_value=changed):
            m.begin(self.store, 'codex-cli', 'two')
        with self.assertRaises(m.SelectionError):
            m.confirm(self.store, 'two', True)

    def test_begin_is_idempotent_but_refresh_invalidates_confirmation(self):
        self.configure(); m.confirm(self.store, 'one', True)
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
        state = self.store.state('one'); state['status'] = 'cancelled'
        m.write_json(self.store.path('one'), state)
        with self.assertRaises(m.SelectionError):
            m.confirm(self.store, 'one', True)
        with self.assertRaises(m.SelectionError):
            m.set_choice(self.store, 'one', 'main', 'codex-cli', 'fixture-gpt', None)

    def test_malformed_confirmation_and_catalog_fail_closed(self):
        self.configure(); m.confirm(self.store, 'one', True)
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
        other = self.base / 'other'; other.mkdir()
        second = m.Store(other, self.base / 'private')
        self.assertNotEqual(self.store.root, second.root)
        self.assertFalse(second.path('one').exists())

    @unittest.skipIf(os.name == 'nt', 'symlink permissions vary on Windows')
    def test_profile_symlink_is_never_overwritten(self):
        outside = self.base / 'outside'; outside.write_text('{}')
        self.store.profile_path.symlink_to(outside)
        with self.assertRaises(m.SelectionError):
            self.store.profile()
        self.assertEqual(outside.read_text(), '{}')

    def test_duplicate_json_members_are_rejected(self):
        self.store.profile_path.write_text('{"schema":"x","schema":"y"}')
        with self.assertRaises(m.SelectionError):
            self.store.profile()

    def test_request_bridge_preserves_observation_and_requires_host_match(self):
        self.configure(); m.confirm(self.store, 'one', True)
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


class Startup(unittest.TestCase):
    def test_new_session_injects_selection_context(self):
        value = hook.context('codex-cli', {'source': 'startup', 'session_id': 'native-id'})
        self.assertIn('model-selection', value)
        self.assertIn('非対話実行', value)
        self.assertIn('対話実行であることを確認できる', value)
        self.assertIn('native-id', value)
        self.assertIn('confirm --main-applied', value)

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

    def test_discovery_labels_official_candidates_honestly(self):
        with patch.object(m.shutil, 'which', return_value=None):
            observed = m.discover()
        self.assertEqual(set(observed['providers']), set(m.HOSTS))
        self.assertTrue(all(not x['selectable'] and x['verification'] == 'unverified' for x in observed['models']))

    def test_gemini_public_model_list_is_discovered_without_inference(self):
        responses = [SimpleNamespace(returncode=0, stdout='  gemini models [command]  Manage models.'),
                     SimpleNamespace(returncode=0, stdout='[{"modelId":"gemini-native"},{"modelId":"auto"}]')]
        with patch.object(m.shutil, 'which', return_value='/fixture/gemini'), \
                patch.object(m.subprocess, 'run', side_effect=responses) as run:
            self.assertEqual(m.gemini_models(), ('listed', ['gemini-native', 'auto']))
            self.assertEqual(run.call_args_list[1].args[0], ['/fixture/gemini', 'models', '--output-format', 'json'])

    def test_older_gemini_without_models_command_never_receives_a_query(self):
        with patch.object(m.shutil, 'which', return_value='/fixture/gemini'), \
                patch.object(m.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='gemini [query..]')) as run:
            self.assertEqual(m.gemini_models(), ('unverified', []))
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[0], ['/fixture/gemini', '--help'])

    def test_invalid_gemini_model_list_is_not_adopted(self):
        for raw in ('{}', '[{"modelId":"--model=oops"}]', '[{"modelId":"x"},{"modelId":"x"}]', 'invalid'):
            with self.subTest(raw=raw), patch.object(m.shutil, 'which', return_value='/fixture/gemini'), \
                    patch.object(m.subprocess, 'run', side_effect=[
                        SimpleNamespace(returncode=0, stdout='gemini models [command]'),
                        SimpleNamespace(returncode=0, stdout=raw)]):
                self.assertEqual(m.gemini_models(), ('unavailable', []))

    def test_claude_effort_options_require_installed_public_carrier(self):
        with patch.object(m.shutil, 'which', return_value='/fixture/claude'), patch.object(m.subprocess, 'run',
                return_value=SimpleNamespace(returncode=0, stdout='--effort <level> choices: low, medium, high')):
            self.assertEqual(m.claude_efforts(), ['low', 'medium', 'high'])
        with patch.object(m.shutil, 'which', return_value=None):
            self.assertEqual(m.claude_efforts(), [])

    def test_fallback_is_reachable_from_both_public_entries(self):
        for path in ['plugins/sdd-bootstrap/skills/bootstrap/SKILL.md', 'plugins/sdd-ship/skills/ship/SKILL.md']:
            self.assertIn('skills/model-selection/SKILL.md', (ROOT / path).read_text())

    def test_panelist_parser_preserves_explicit_model_argument(self):
        with tempfile.TemporaryDirectory() as config:
            result = subprocess.run([sys.executable, str(SCRIPTS / 'session-panelist.py'), '--vendor', 'gpt',
                                     '--shell', 'bash', '--model-session', 'missing-session', '--model-config-home', config,
                                     '--model', 'fixture'], cwd=ROOT, capture_output=True, text=True, timeout=5)
        self.assertNotIn('ambiguous option', result.stderr)
        self.assertIn('SESSION_MODEL_SELECTION_REQUIRED', result.stderr)

    def test_panelist_forwarded_arguments_cannot_replace_wrapper_vendor(self):
        with tempfile.TemporaryDirectory() as config:
            result = subprocess.run(['bash', str(ROOT / 'plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh'),
                                     '--model-session', 'missing-session', '--model-config-home', config,
                                     '--vendor=gemini'], cwd=ROOT, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 2)
        self.assertIn('duplicate session adapter control', result.stderr)

    def test_panelist_bridge_preserves_collection_arguments(self):
        selected = {'host': 'codex-cli', 'model': 'fixture-model', 'effort': 'high'}
        command = panelist.command(selected, 'gpt', 'bash', ['--task', 'T-001', '--input', 'input bundle.json'])
        self.assertTrue(command[1].endswith('run-panelist-gpt.sh'))
        self.assertEqual(command[-4:], ['--model', 'fixture-model', '--effort', 'high'])
        self.assertIn('input bundle.json', command)
        with self.assertRaises(panelist.models.SelectionError):
            panelist.command(selected, 'gpt', 'bash', ['--model', 'different'])
        with self.assertRaises(panelist.models.SelectionError):
            panelist.command(selected, 'gpt', 'bash', ['--model-controls', 'anything'])

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
            binary = base / 'bin'; binary.mkdir()
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
            if plugins == 'sdd-bootstrap':
                self.assertEqual(calls, [['extensions', 'link', str(installed / 'plugins/sdd-implementation/gemini')]])
                self.assertTrue((installed / 'plugins/sdd-implementation/scripts/session-models.py').is_file())
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
                self.assertEqual(calls, [])

    def test_bash_bootstrap_installs_picker_and_unregisters_gemini(self):
        self.run_install('bash')

    def test_powershell_bootstrap_installs_picker_and_unregisters_gemini(self):
        self.run_install('powershell')

    def test_unselected_implementation_does_not_register_extension(self):
        self.run_install('bash', 'sdd-review-loop')


if __name__ == '__main__':
    unittest.main()
