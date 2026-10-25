#!/usr/bin/env python3
"""T-007 bounded launch controls and protected paired Claude argv contracts.

Portable stdlib unittest. Real helper CLI, real selector subprocesses and real paired
builders. The trusted helper, selectors and shipped contracts are copied into a temporary
repository at their installed relative locations so the trusted registry/policy resolve
there. Caller policy differs from the trusted policy only in fixture lifecycle/adoption.
Fixture adoption files and verified-configuration observations are typed fixture data only;
they never claim live access, model behavior or provider authorization. No native model is
executed: PATH shims record any accidental claude/codex/gemini invocation.
"""
import contextlib
import contextvars
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import itertools
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Callable
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parents[1]
HELPER = 'plugins/sdd-implementation/scripts/model-policy.py'
SELECTOR_SH = 'plugins/sdd-implementation/scripts/select-agent-model.sh'
SELECTOR_PS1 = 'plugins/sdd-implementation/scripts/select-agent-model.ps1'
TRUSTED_REGISTRY = 'contracts/agent-model-capabilities.v2.json'
TRUSTED_POLICY = 'contracts/model-policy.v1.json'
CONTROLS_SCHEMA = 'contracts/model-launch-controls.schema.json'
TRUSTED_PATHS = sorted([HELPER, SELECTOR_SH, SELECTOR_PS1, TRUSTED_REGISTRY, TRUSTED_POLICY, CONTROLS_SCHEMA])
COPIED = [HELPER, SELECTOR_SH, SELECTOR_PS1, TRUSTED_REGISTRY, TRUSTED_POLICY,
          'contracts/model-selection.schema.json', 'contracts/model-delivery.schema.json',
          'contracts/model-observation.schema.json', 'contracts/model-policy-request.schema.json',
          'contracts/model-policy-error.schema.json']
# Future product file: copied only when present. Its absence must stay a behavioral CLI
# failure, never a fixture setup exception or a fabricated schema.
OPTIONAL_COPIED = [CONTROLS_SCHEMA]
TRANSPORT_SCRIPT = ROOT / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
LAUNCHER_SCRIPT = ROOT / 'plugins/sdd-review-loop/scripts/launch-impl-review.py'
HOST = 'claude-code'
EFFORTS = ['low', 'medium', 'high', 'xhigh']
ANTHROPIC = ('anthropic/opus', 'anthropic/sonnet', 'anthropic/haiku')
# Protected policy role -> (paired transport stage, transport role name).
PROTECTED = {
    'spec-reviewer-a': ('spec', 'spec-reviewer-a'), 'spec-reviewer-b': ('spec', 'spec-reviewer-b'),
    'impl-reviewer-a': ('impl', 'impl-reviewer-a'), 'impl-reviewer-b': ('impl', 'impl-reviewer-b'),
    'task-reviewer-a': ('task', 'task-reviewer-a'), 'task-reviewer-b': ('task', 'task-reviewer-b'),
    'evaluator': ('quality', 'sdd-evaluator'),
}
REASONS = {'config-invalid', 'config-conflict', 'native-precedence-conflict',
           'discovery-unavailable', 'discovery-incomplete', 'discovery-stale', 'scope-mismatch',
           'model-unavailable', 'model-unverified', 'model-tier-unavailable', 'effort-unavailable',
           'budget-unverifiable', 'resume-conflict', 'actual-id-unavailable', 'actual-id-mismatch',
           'input-invalid'}
MISMATCH = {'input-invalid', 'config-invalid', 'config-conflict', 'scope-mismatch', 'resume-conflict'}
VALIDATION_FIELDS = {'schema', 'controls', 'pins', 'trusted', 'role', 'host', 'run_id', 'session_id',
                     'attempt', 'require_actual_id', 'selection'}
LAUNCH_FIELDS = {'schema', 'controls', 'pins', 'trusted', 'role', 'transport_role', 'host', 'run_id',
                 'session_id', 'attempt', 'require_actual_id', 'selection_sha256', 'native_model', 'effort',
                 'effort_control', 'effort_carrier', 'native_alignment', 'transport', 'argv', 'argv_sha256',
                 'model_argv', 'effort_argv', 'agent_model', 'agent_effort', 'native_overrides'}
NATIVE_OVERRIDES = ('ANTHROPIC_MODEL', 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
                    'ANTHROPIC_DEFAULT_SONNET_MODEL', 'ANTHROPIC_DEFAULT_OPUS_MODEL',
                    'CLAUDE_CODE_SUBAGENT_MODEL', 'CLAUDE_CODE_SUBAGENT_MODEL_FORCE',
                    'CLAUDE_CODE_EFFORT_LEVEL')
DISALLOWED = ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit']
BASH = os.environ.get('SDD_TEST_BASH', 'bash')
# Literal controlled help fixture modelled on the pinned official Claude help text.
HELP_TEXT = '\n'.join([
    'Usage: claude [options] [command] [prompt]',
    '',
    'Options:',
    '  --agent <agent>                       Agent for the current session.',
    '  --agents <json-or-file>               JSON object defining custom agents',
    '  --disallowedTools, --disallowed-tools <tools...>',
    '      Comma or space-separated list of tool names to deny',
    '  --effort <level>                      Effort level for the current session',
    '                                        (low, medium, high, xhigh, max)',
    '  --json-schema <schema>                JSON Schema for structured output',
    '  --model <model>                       Model for the current session.',
    '  --output-format <format>              Output format (only works with --print)',
    '  --permission-mode <mode>              Permission mode to use for the session',
    '  --plugin-dir <path>                   Load a plugin from a directory or .zip',
    '  -p, --print                           Print response and exit',
    '  --session-id <uuid>                   Use a specific session ID',
    '  --settings <file-or-json>             Path to a settings JSON file',
    '  --setting-sources <sources>          Comma-separated list of setting sources',
    '  --tools <tools...>                    Specify the list of available tools',
    ''])
HELP_WITHOUT_EFFORT = '\n'.join(line for line in HELP_TEXT.split('\n')
                                if '--effort' not in line and 'xhigh, max' not in line)
_MODULES = itertools.count()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8')


def digest(value, omit=None):
    return hashlib.sha256(canonical({k: v for k, v in value.items() if k != omit})).hexdigest()


def sha_bytes(raw):
    return hashlib.sha256(raw).hexdigest()


def sha_file(path):
    return sha_bytes(Path(path).read_bytes())


def flip(text):
    return ('1' if text[0] == '0' else '0') + text[1:]


def utc_now(delta=timedelta()):
    return (datetime.now(timezone.utc) + delta).strftime('%Y-%m-%dT%H:%M:%S.%fZ')


def load_module(path, label):
    name = 't007_' + label + '_' + str(next(_MODULES))
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ImportError('Cannot load fixture module: ' + str(path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    try:
        spec.loader.exec_module(module)
    except BaseException:
        sys.modules.pop(name, None)
        raise
    return module


def set_path(target, path, value):
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value


def get_path(target, path):
    for key in path:
        target = target[key]
    return target


def leaf_paths(value, prefix=()):
    """Every nested container and leaf path of a persisted JSON record."""
    if prefix:
        yield prefix
    if isinstance(value, dict):
        for key in sorted(value):
            yield from leaf_paths(value[key], prefix + (key,))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from leaf_paths(item, prefix + (index,))


def altered(value):
    if isinstance(value, bool):
        return not value
    if isinstance(value, int):
        return value + 1
    if isinstance(value, str):
        return flip(value) if len(value) == 64 and all(c in '0123456789abcdef' for c in value) else value + '-x'
    if isinstance(value, list):
        return value[:-1] if value else ['x']
    if isinstance(value, dict):
        return {**value, 'unexpected': True}
    return 'x'


class LaunchFixture(unittest.TestCase):
    # Heterogeneous JSON fixture documents serialized for the helper and selector.
    trusted_policy: dict[str, Any]
    policy: dict[str, Any]
    observation: dict[str, Any]
    request: dict[str, Any]
    project: dict[str, Any]
    selection: dict[str, Any]
    controls_doc: dict[str, Any]
    environment: dict[str, str]

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='model-launch-fixture-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.root = self.base / 'repo'
        for relative in COPIED + [p for p in OPTIONAL_COPIED if (ROOT / p).is_file()]:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        self.marker = self.base / 'native-executed'
        shims = self.base / 'shims'
        shims.mkdir()
        for name in ('claude', 'codex', 'gemini'):
            shim = shims / name
            shim.write_text('#!/bin/sh\necho "$0 $*" >> "' + str(self.marker) + '"\nexit 97\n')
            shim.chmod(0o755)
        self.environment = {k: v for k, v in os.environ.items() if not k.startswith('SDD_MODEL') and k not in NATIVE_OVERRIDES}
        self.environment['PYTHONDONTWRITEBYTECODE'] = '1'
        self.environment['PATH'] = str(shims) + os.pathsep + os.environ.get('PATH', '')
        self.trusted_registry_raw = (self.root / TRUSTED_REGISTRY).read_bytes()
        self.trusted_policy = json.loads((self.root / TRUSTED_POLICY).read_bytes())
        self.registry_raw = self.trusted_registry_raw
        self.policy = self.fixture_policy()
        self.observation = self.fresh_observation()
        self.request = self.fresh_request('spec-reviewer-a')
        self.project = {'schema': 'model-role-config/v1', 'default_policy': None, 'roles': {}}
        self.run_id = 'fixture-run-' + uuid.uuid4().hex[:8]
        self.session_id = str(uuid.uuid4())
        self._helper = None

    # ---- typed fixture documents -------------------------------------------------------------

    def fixture_policy(self):
        """Trusted policy; ONLY fixture lifecycle/adoption differ. Native mappings stay trusted."""
        policy = copy.deepcopy(self.trusted_policy)
        roles = list(policy['roles'])
        for model in policy['models']:
            if model['id'] in ANTHROPIC:
                evidence = canonical({'fixture_only': True, 'catalog_id': model['id'], 'roles': roles,
                                      'claim': 'T-007 fixture adoption only; no live access or behavior claim'})
                path = model['id'].split('/')[1] + '-fixture-adoption.json'
                (self.root / path).write_bytes(evidence)
                model['lifecycle'] = 'current'
                model['adoption'] = [{'role': role, 'path': path, 'sha256': sha_bytes(evidence)} for role in roles]
            else:
                # This caller policy is a synthetic Anthropic fixture, not live adoption evidence.
                model['adoption'] = []
        return policy

    def policy_model(self, name):
        return next(item for item in self.policy['models'] if item['id'] == name)

    def fresh_observation(self, observed_at=None):
        return {'schema': 'model-observation/v1', 'host': HOST, 'cli_version': 'fixture-claude 1.0',
                'scope_id': 'fixture-client-1', 'scope_kind': 'client', 'purpose': 'diagnostic',
                'observed_at': observed_at or utc_now(), 'source': 'verified-configuration',
                'status': 'complete',
                'models': [{'native_id': native, 'efforts': EFFORTS[:], 'available': True}
                           for native in ('opus', 'sonnet', 'haiku')],
                'reason': 'Typed verified-configuration fixture only; not live access or inference proof.'}

    @staticmethod
    def fresh_request(role, risk='high'):
        return {'schema': 'model-policy-request/v1', 'role': role, 'risk': risk, 'host': HOST,
                'policy_path': 'policy.json', 'observation_path': 'observation.json',
                'project_config_path': None, 'cli': {'model_id': None, 'policy': None},
                'budget': None, 'requested_effort': None, 'resume_selection_path': None}

    def write(self, name, value):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(canonical(value))
        return sha_file(target)

    def seal(self, observation):
        observation['observation_sha256'] = digest(observation, 'observation_sha256')
        return observation

    def save(self):
        self.write('request.json', self.request)
        self.write('policy.json', self.policy)
        (self.root / 'registry.json').write_bytes(self.registry_raw)
        self.write('observation.json', self.seal(self.observation))
        if self.request['project_config_path']:
            self.write(self.request['project_config_path'], self.project)

    def helper(self):
        if self._helper is None:
            self._helper = load_module(self.root / HELPER, 'policy')
            self.addCleanup(sys.modules.pop, self._helper.__name__, None)
        return self._helper

    @contextlib.contextmanager
    def in_root(self):
        """Test-side working directory only; production must never os.chdir."""
        previous = Path.cwd()
        os.chdir(self.root)
        try:
            yield
        finally:
            os.chdir(previous)

    @contextlib.contextmanager
    def model_env(self, env=None):
        values = {k: v for k, v in os.environ.items() if not k.startswith('SDD_MODEL') and k not in NATIVE_OVERRIDES}
        values.update(env or {})
        with mock.patch.dict(os.environ, values, clear=True):
            yield

    # ---- bounded subprocesses ----------------------------------------------------------------

    def run_process(self, command, env=None, timeout=60, label='subprocess'):
        try:
            return subprocess.run(command, cwd=self.root, env={**self.environment, **(env or {})}, text=True,
                                  capture_output=True, timeout=timeout, check=False)
        except subprocess.TimeoutExpired:
            self.fail('Bounded ' + label + ' timed out; a blocking canary may have been opened')
        except OSError as error:
            self.fail('Bounded ' + label + ' could not start: ' + type(error).__name__)

    def try_select(self, env=None):
        self.save()
        result = self.run_process([BASH, str(self.root / SELECTOR_SH), '--policy-input', 'request.json',
                                   '--registry', 'registry.json'], env, label='selector')
        if result.returncode != 0:
            return None, result
        return json.loads(result.stdout), result

    def select(self, role, *, risk='high', env=None, trusted_mapping=True):
        """Generate a legitimate selection with the existing real selector subprocess."""
        self.request.update(role=role, risk=risk)
        selection, result = self.try_select(env)
        self.assertIsNotNone(selection, 'Fixture selector failed: ' + result.stderr[:1000])
        self.assertEqual(result.stderr, '')
        self.assertEqual(selection['schema'], 'model-selection/v1')
        self.assertEqual(selection['selection_sha256'], digest(selection, 'selection_sha256'))
        self.assertEqual((selection['role'], selection['host']), (role, HOST))
        self.assertIsNone(selection['binding'])
        if trusted_mapping:
            trusted = next(m for m in self.trusted_policy['models']
                           if m['id'] == selection['resolved']['catalog_id'])
            self.assertEqual(selection['resolved']['native_id'], trusted['hosts'][HOST])
        self.write('selection.json', selection)
        self.selection = selection
        return selection

    def ref(self, path):
        return {'path': path, 'sha256': sha_file(self.root / path)}

    def closure(self):
        request = json.loads((self.root / 'request.json').read_bytes())
        paths = {request['policy_path'], request['observation_path']}
        paths.update(request[f] for f in ('project_config_path', 'resume_selection_path') if request[f])
        policy = json.loads((self.root / request['policy_path']).read_bytes())
        paths.update(ref['path'] for model in policy['models'] for ref in model['adoption'])
        return paths

    def controls(self, role=None, *, attempt=1, require_actual_id=False, extra=(), omit=(), mutate=None,
                 name='controls.json'):
        paths = (self.closure() | set(extra)) - set(omit)
        document = {'schema': 'model-launch-controls/v1', 'role': role or self.request['role'], 'host': HOST,
                    'attempt': attempt, 'require_actual_id': require_actual_id,
                    'selection': self.ref('selection.json'), 'request': self.ref('request.json'),
                    'registry': self.ref('registry.json'),
                    'inputs': [self.ref(path) for path in sorted(paths)]}
        if mutate is not None:
            mutate(document)
        raw = canonical(document)
        (self.root / name).write_bytes(raw)
        self.controls_doc = document
        return sha_bytes(raw)

    def cli(self, role=None, *, sha, host=HOST, run_id=None, session_id=None, native=None, env=None,
            controls='controls.json', timeout=60):
        command = [sys.executable, '-B', str(self.root / HELPER), 'launch-controls', '--controls', controls,
                   '--controls-sha256', sha, '--role', role or self.request['role'], '--host', host,
                   '--run-id', run_id or self.run_id, '--session-id', session_id or self.session_id]
        if native is not None:
            command += ['--native-model', native]
        result = self.run_process(command, env, timeout=timeout, label='launch-controls CLI')
        self.assertFalse(self.marker.exists(), 'A native model executable was invoked')
        return result

    def accepted(self, result):
        self.assertEqual(result.returncode, 0, result.stderr[:1000])
        self.assertEqual(result.stderr, '')
        try:
            value = json.loads(result.stdout)
        except ValueError:
            self.fail('launch-controls did not emit one JSON validation: ' + result.stdout[:300])
        self.assertEqual(result.stdout.rstrip('\n'), canonical(value).decode('utf-8'))
        return value

    def rejected(self, result, reasons):
        self.assertEqual(result.returncode, 2, result.stderr[:1000])
        self.assertEqual(result.stdout, '')
        self.assertNotIn('Traceback', result.stderr)
        try:
            error = json.loads(result.stderr)
        except ValueError:
            self.fail('Rejected launch-controls did not emit one JSON error: ' + result.stderr[:300])
        self.assertEqual(set(error), {'schema', 'reason', 'message'})
        self.assertEqual(error['schema'], 'model-policy-error/v1')
        self.assertIn(error['reason'], {reasons} if isinstance(reasons, str) else reasons)
        self.assertIn(error['reason'], REASONS)
        self.assertTrue(error['message'].strip())
        self.assertLessEqual(len(error['message']), 512)
        return error

    def api(self, sha, role=None, *, env=None, **options):
        helper = self.helper()
        with self.in_root():
            return helper.validate_launch_controls(
                'controls.json', sha, role=role or self.request['role'], host=options.pop('host', HOST),
                run_id=options.pop('run_id', self.run_id), session_id=options.pop('session_id', self.session_id),
                environment=env or {}, **options)

    def api_rejected(self, sha, reasons, **options):
        helper = self.helper()
        with self.assertRaises(helper.PolicyError) as caught:
            self.api(sha, **options)
        self.assertIn(caught.exception.reason, {reasons} if isinstance(reasons, str) else reasons)
        return caught.exception

    def expected_pins(self, document=None):
        document = document or self.controls_doc
        entries = {e['path']: e for e in [document['selection'], document['request'], document['registry'],
                                          *document['inputs']]}
        return [entries[path] for path in sorted(entries)]

    def assert_validation(self, value, *, sha, selection, role=None, attempt=1, run_id=None, session_id=None):
        role = role or self.request['role']
        self.assertEqual(set(value), VALIDATION_FIELDS)
        self.assertEqual(value['schema'], 'model-launch-validation/v1')
        self.assertEqual(value['controls'], {'path': 'controls.json', 'sha256': sha})
        self.assertEqual(value['pins'], self.expected_pins())
        self.assertEqual([entry['path'] for entry in value['trusted']], TRUSTED_PATHS)
        for entry in value['trusted']:
            self.assertEqual(set(entry), {'path', 'sha256'})
            self.assertEqual(entry['sha256'], sha_file(ROOT / entry['path']))
        self.assertEqual((value['role'], value['host']), (role, HOST))
        self.assertEqual((value['run_id'], value['session_id']), (run_id or self.run_id, session_id or self.session_id))
        self.assertIs(type(value['attempt']), int)
        self.assertEqual(value['attempt'], attempt)
        self.assertIs(value['require_actual_id'], False)
        expected = self.helper().bind_selection(selection, run_id=run_id or self.run_id,
                                                session_id=session_id or self.session_id, attempt=attempt)
        self.assertEqual(value['selection'], expected)
        self.assertEqual(value['selection']['selection_sha256'], digest(value['selection'], 'selection_sha256'))
        self.helper().validate_selection_record(value['selection'], require_bound=True)

    def baseline_accepts(self, role='spec-reviewer-a', **select_options):
        """Positive control on the same fixture so every rejection below is not vacuous."""
        selection = self.select(role, **select_options)
        sha = self.controls()
        self.assert_validation(self.accepted(self.cli(sha=sha, env=select_options.get('env'))),
                               sha=sha, selection=selection)
        return selection, sha


class LaunchControls(LaunchFixture):

    def test_synthetic_fixture_does_not_inherit_live_adoption_paths(self):
        model = next(m for m in self.trusted_policy['models'] if m['id'] == 'gpt-6-astra')
        model['adoption'] = [{'role': 'implementer', 'path': 'uncopied-live-adoption.json', 'sha256': 'a' * 64}]
        policy = self.fixture_policy()
        self.assertEqual(next(m for m in policy['models'] if m['id'] == 'gpt-6-astra')['adoption'], [])
        for candidate in policy['models']:
            if candidate['id'] not in ANTHROPIC:
                self.assertEqual(candidate['adoption'], [])
        self.assertFalse((self.root / 'uncopied-live-adoption.json').exists())


    def test_controls_cli_binds_valid_role_selection(self):
        env = {'SDD_MODEL_SPEC_REVIEWER_A': 'anthropic/sonnet'}
        selection = self.select('spec-reviewer-a', risk='medium', env=env)
        self.assertEqual(selection['requested'], {'policy': 'pinned', 'model_id': 'anthropic/sonnet',
                                                  'policy_source': 'environment', 'model_source': 'environment'})
        self.assertEqual(selection['resolved'], {'catalog_id': 'anthropic/sonnet', 'native_id': 'sonnet',
                                                 'effort': 'medium', 'effort_control': 'frontmatter'})
        sha = self.controls()
        value = self.accepted(self.cli(sha=sha, env=env))
        self.assert_validation(value, sha=sha, selection=selection)
        self.assertEqual(value['selection']['resolved'], selection['resolved'])
        self.assertEqual(value['selection']['binding'],
                         {'run_id': self.run_id, 'session_id': self.session_id, 'attempt': 1})
        # Recomputation uses the actual role environment: without it the shipped latest differs.
        self.rejected(self.cli(sha=sha), MISMATCH)
        before = Path.cwd()
        api_value = self.api(sha, env=env)
        self.assertEqual(Path.cwd(), before)
        self.assertEqual(canonical(api_value), canonical(value))
        self.assertEqual(sorted(p.name for p in self.root.iterdir() if p.is_file()),
                         sorted(['controls.json', 'request.json', 'policy.json', 'registry.json',
                                 'observation.json', 'selection.json', 'opus-fixture-adoption.json',
                                 'sonnet-fixture-adoption.json', 'haiku-fixture-adoption.json']),
                         'launch-controls must not write output files')

    def test_controls_role_host_and_binding_mismatches(self):
        helper = self.helper()
        for role in PROTECTED:
            with self.subTest(role=role):
                self.request = self.fresh_request(role)
                selection = self.select(role)
                sha = self.controls()
                self.assert_validation(self.accepted(self.cli(sha=sha)), sha=sha, selection=selection)
                other = next(item for item in PROTECTED if item != role)
                self.rejected(self.cli(other, sha=sha), MISMATCH)
                self.rejected(self.cli(sha=sha, host='codex-cli'), MISMATCH)
                self.rejected(self.cli(other, sha=self.controls(other)), MISMATCH)
                bound = helper.bind_selection(selection, run_id=self.run_id, session_id=self.session_id, attempt=1)
                self.write('selection.json', bound)
                self.rejected(self.cli(sha=self.controls(attempt=2)), MISMATCH)
                sha = self.controls()
                self.rejected(self.cli(sha=sha, session_id=str(uuid.uuid4())), MISMATCH)
                self.rejected(self.cli(sha=sha, run_id='other-run'), MISMATCH)
        with self.subTest(case='identical-resume-and-new-attempt'):
            self.request = self.fresh_request('impl-reviewer-a')
            original = helper.bind_selection(self.select('impl-reviewer-a'), run_id=self.run_id,
                                             session_id=self.session_id, attempt=1)
            self.write('resume.json', original)
            self.write('selection.json', original)
            self.request['resume_selection_path'] = 'resume.json'
            self.save()
            sha = self.controls()
            value = self.accepted(self.cli(sha=sha))
            self.assertEqual(value['selection'], original)
            self.assertEqual(value['attempt'], 1)
            self.rejected(self.cli(sha=sha, session_id=str(uuid.uuid4())), MISMATCH)
            env = {'SDD_MODEL_IMPL_REVIEWER_A': 'anthropic/sonnet'}
            self.request['risk'] = 'medium'
            self.save()
            self.rejected(self.cli(sha=self.controls(), env=env), MISMATCH)
            self.request['resume_selection_path'] = None
            fresh = self.select('impl-reviewer-a', risk='medium', env=env)
            sha = self.controls(attempt=2)
            value = self.accepted(self.cli(sha=sha, env=env))
            self.assert_validation(value, sha=sha, selection=fresh, attempt=2)
            self.assertNotEqual(value['selection']['resolved'], original['resolved'])

    def test_controls_raw_pin_precedes_json(self):
        _, good = self.baseline_accepts('spec-reviewer-b')
        good_raw = (self.root / 'controls.json').read_bytes()
        for raw in [b'{"schema":', b'\xff\xfe\x00', b'[]', b'{"schema":"a","schema":"a"}', b'{"attempt":NaN}']:
            with self.subTest(raw=raw):
                (self.root / 'controls.json').write_bytes(raw)
                self.rejected(self.cli(sha=good), 'input-invalid')
                self.rejected(self.cli(sha=sha_bytes(raw)), {'input-invalid', 'config-invalid'})
        (self.root / 'controls.json').write_bytes(good_raw)
        for pin in [good.upper(), good[:-1], good + '0', '', 'z' * 64]:
            with self.subTest(pin=pin):
                self.rejected(self.cli(sha=pin), 'input-invalid')
        self.accepted(self.cli(sha=good))

    def test_controls_closed_fields_and_all_persisted_leaf_mismatches(self):
        self.baseline_accepts('task-reviewer-a')
        baseline = copy.deepcopy(self.controls_doc)
        self.write('unrelated.json', {'fixture': 'unlisted'})
        unrelated = self.ref('unrelated.json')
        cases: list[tuple[str, Callable[..., Any]]] = [('missing-' + field, lambda d, f=field: d.pop(f)) for field in baseline]
        cases += [('extra-command', lambda d: d.__setitem__('command', 'true')),
                  ('extra-execute', lambda d: d.__setitem__('execute', True))]
        for field, value in [('schema', 'model-launch-controls/v2'), ('role', 'reviewer-c'),
                             ('role', 'Task-reviewer-a'), ('host', 'vim-cli'), ('host', 'codex-cli'),
                             ('attempt', True), ('attempt', 0), ('attempt', -1), ('attempt', '1'),
                             ('attempt', 1.0), ('require_actual_id', 0), ('require_actual_id', None),
                             ('require_actual_id', 'false')]:
            cases.append((field + '=' + repr(value), lambda d, f=field, v=value: d.__setitem__(f, v)))
        for primary in ('selection', 'request', 'registry'):
            cases += [(primary + '-path', lambda d, p=primary: d.__setitem__(p, dict(unrelated))),
                      (primary + '-hash', lambda d, p=primary: d[p].__setitem__('sha256', flip(d[p]['sha256']))),
                      (primary + '-extra', lambda d, p=primary: d[p].__setitem__('mode', 'x')),
                      (primary + '-missing-hash', lambda d, p=primary: d[p].pop('sha256')),
                      (primary + '-missing-path', lambda d, p=primary: d[p].pop('path')),
                      (primary + '-string', lambda d, p=primary: d.__setitem__(p, d[p]['path']))]
        for index, entry in enumerate(baseline['inputs']):
            cases += [('input-hash-' + entry['path'],
                       lambda d, i=index: d['inputs'][i].__setitem__('sha256', flip(d['inputs'][i]['sha256']))),
                      ('input-path-' + entry['path'], lambda d, i=index: d['inputs'].__setitem__(i, dict(unrelated))),
                      ('input-missing-' + entry['path'], lambda d, i=index: d['inputs'].pop(i)),
                      ('input-extra-key-' + entry['path'], lambda d, i=index: d['inputs'][i].__setitem__('role', 'x'))]
        cases += [('inputs-extra', lambda d: d.__setitem__('inputs', sorted(d['inputs'] + [dict(unrelated)],
                                                                           key=lambda e: e['path']))),
                  ('inputs-transposed', lambda d: d['inputs'].reverse()),
                  ('inputs-duplicate', lambda d: d.__setitem__('inputs', sorted(d['inputs'] + [d['inputs'][0]],
                                                                               key=lambda e: e['path']))),
                  ('inputs-empty', lambda d: d.__setitem__('inputs', [])),
                  ('inputs-object', lambda d: d.__setitem__('inputs', {}))]
        self.assertGreater(len(baseline['inputs']), 1)
        for label, mutate in cases:
            with self.subTest(case=label):
                document = copy.deepcopy(baseline)
                mutate(document)
                raw = canonical(document)
                (self.root / 'controls.json').write_bytes(raw)
                self.rejected(self.cli(sha=sha_bytes(raw)), MISMATCH)
        text = canonical(baseline).decode('utf-8')
        self.assertTrue(text.startswith('{"attempt":1,'))
        for label, raw in [('duplicate-key', text.replace('{"attempt":1,', '{"attempt":1,"attempt":1,', 1)),
                           ('unknown-key', text.replace('{"attempt":1,', '{"attempt":1,"Attempt":1,', 1))]:
            with self.subTest(case=label):
                (self.root / 'controls.json').write_text(raw)
                self.rejected(self.cli(sha=sha_bytes(raw.encode())), MISMATCH)

    def test_controls_transitive_paths_are_closed_before_policy_reads(self):
        helper = self.helper()
        selection, _ = self.baseline_accepts('spec-reviewer-a')
        original = helper.bind_selection(selection, run_id=self.run_id, session_id=self.session_id, attempt=1)
        self.write('resume.json', original)
        self.write('unrelated.json', {'fixture': 'unlisted'})
        cases = [('adoption', {}, {'omit': ('opus-fixture-adoption.json',)}),
                 ('observation', {}, {'omit': ('observation.json',)}),
                 ('policy', {}, {'omit': ('policy.json',)}),
                 ('project', {'project_config_path': 'project.json'}, {'omit': ('project.json',)}),
                 ('resume', {'resume_selection_path': 'resume.json'}, {'omit': ('resume.json',)}),
                 ('extra', {}, {'extra': ('unrelated.json',)})]
        for label, request_fields, closure in cases:
            with self.subTest(case=label):
                self.request = {**self.fresh_request('spec-reviewer-a'), **request_fields}
                self.save()
                sha = self.controls(**closure)
                self.rejected(self.cli(sha=sha), MISMATCH)
                with mock.patch.object(helper, 'prepare_policy', wraps=helper.prepare_policy) as prepare, \
                        mock.patch.object(helper, '_validate_role_policy',
                                          wraps=helper._validate_role_policy) as role_policy:
                    self.api_rejected(sha, MISMATCH)
                prepare.assert_not_called()
                role_policy.assert_not_called()

    def path_variants(self, name):
        data = (self.root / name).read_bytes()
        (self.base / ('outside-' + name)).write_bytes(data)
        for folder in ('sub', 'real'):
            (self.root / folder).mkdir(exist_ok=True)
            (self.root / folder / name).write_bytes(data)
        if not (self.root / 'linked').is_symlink():
            (self.root / 'linked').symlink_to('real', target_is_directory=True)
        (self.root / ('link-' + name)).symlink_to(name)
        return [('absolute', str(self.root / name)), ('parent-escape', '../outside-' + name),
                ('dot-component', './' + name), ('duplicate-separator', 'sub//' + name),
                ('backslash', 'sub\\' + name), ('wrong-case', name.upper()),
                ('trailing-separator', name + '/'), ('empty', ''),
                ('file-symlink', 'link-' + name), ('directory-symlink', 'linked/' + name)]

    def test_controls_reject_escape_case_alias_and_symlink_components(self):
        self.baseline_accepts('impl-reviewer-b')
        baseline = copy.deepcopy(self.controls_doc)
        for field in ('request', 'selection'):
            for label, path in self.path_variants(field + '.json'):
                with self.subTest(field=field, variant=label):
                    document = copy.deepcopy(baseline)
                    document[field] = {'path': path, 'sha256': baseline[field]['sha256']}
                    raw = canonical(document)
                    (self.root / 'controls.json').write_bytes(raw)
                    self.rejected(self.cli(sha=sha_bytes(raw)), MISMATCH)
        for label, path in self.path_variants('observation.json'):
            with self.subTest(field='inputs', variant=label):
                document = copy.deepcopy(baseline)
                for entry in document['inputs']:
                    if entry['path'] == 'observation.json':
                        entry['path'] = path
                document['inputs'].sort(key=lambda e: e['path'])
                raw = canonical(document)
                (self.root / 'controls.json').write_bytes(raw)
                self.rejected(self.cli(sha=sha_bytes(raw)), MISMATCH)
        good_raw = canonical(baseline)
        (self.root / 'controls.json').write_bytes(good_raw)
        good = sha_bytes(good_raw)
        (self.root / 'link-controls.json').symlink_to('controls.json')
        (self.root / 'real' / 'controls.json').write_bytes(good_raw)
        for controls in ('link-controls.json', 'linked/controls.json', 'CONTROLS.json', '../repo/controls.json',
                         str(self.root / 'link-controls.json')):
            with self.subTest(controls=controls):
                self.rejected(self.cli(sha=good, controls=controls), MISMATCH)
        # A symlink to a FIFO canary: following it would block until the bounded timeout.
        fifo = self.base / 'canary.fifo'
        os.mkfifo(fifo)
        (self.root / 'canary-link.json').symlink_to(fifo)
        for field in ('request', 'selection'):
            with self.subTest(canary=field):
                document = copy.deepcopy(baseline)
                document[field] = {'path': 'canary-link.json', 'sha256': baseline[field]['sha256']}
                raw = canonical(document)
                (self.root / 'controls.json').write_bytes(raw)
                self.rejected(self.cli(sha=sha_bytes(raw), timeout=30), MISMATCH)
        # A direct listed FIFO must not block at open() before fstat can reject it.
        direct_fifo = self.root / 'direct-canary.fifo'
        os.mkfifo(direct_fifo)
        document = copy.deepcopy(baseline)
        document['request'] = {'path': direct_fifo.name, 'sha256': sha_bytes(b'')}
        raw = canonical(document)
        (self.root / 'controls.json').write_bytes(raw)
        with self.subTest(special_file='listed-request-fifo'):
            self.rejected(self.cli(sha=sha_bytes(raw), timeout=5), 'input-invalid')
        with self.subTest(special_file='controls-fifo'):
            self.rejected(self.cli(sha=sha_bytes(b''), controls=direct_fifo.name, timeout=5), 'input-invalid')
        # Component swap simulation: metadata probes report the symlink components as ordinary
        # entries (as if swapped after lstat). Only descriptor-relative O_NOFOLLOW opens reject.
        real_lstat, real_stat = os.lstat, os.stat
        links = {'linked', 'link-request.json', 'link-selection.json', 'link-observation.json'}

        def swapped(path):
            return not isinstance(path, int) and os.path.basename(os.fsdecode(path).rstrip('/')) in links

        def lying_lstat(path, *, dir_fd=None):
            return real_stat(path, dir_fd=dir_fd) if swapped(path) else real_lstat(path, dir_fd=dir_fd)

        def lying_stat(path, *, dir_fd=None, follow_symlinks=True):
            return real_stat(path, dir_fd=dir_fd, follow_symlinks=follow_symlinks or swapped(path))

        for field, path in [('request', 'link-request.json'), ('request', 'linked/request.json'),
                            ('selection', 'link-selection.json'), ('selection', 'linked/selection.json')]:
            with self.subTest(swap=path):
                document = copy.deepcopy(baseline)
                document[field] = {'path': path, 'sha256': baseline[field]['sha256']}
                raw = canonical(document)
                (self.root / 'controls.json').write_bytes(raw)
                with mock.patch.object(os, 'lstat', lying_lstat), mock.patch.object(os, 'stat', lying_stat):
                    self.api_rejected(sha_bytes(raw), MISMATCH)

    def test_controls_captured_snapshot_survives_original_reference_mutation(self):
        helper = self.helper()
        _, sha = self.baseline_accepts('task-reviewer-b')
        canary = self.root / 'canary-policy.json'
        canary.write_bytes((self.root / 'policy.json').read_bytes())
        real_prepare, real_run, real_open = helper.prepare_policy, subprocess.run, os.open
        seen: dict[str, Any] = {}
        opened: list[str] = []
        selector_cwds: list[Any] = []
        selector_scripts: list[Path] = []

        def mutate_then_prepare(*args, **kwargs):
            if 'cwd' not in seen:
                seen['cwd'] = Path.cwd()
                seen['root'] = helper._output_path('request.json').parent
                seen['fresh'] = contextvars.Context().run(helper._output_path, 'request.json').parent
                seen['copied'] = contextvars.copy_context().run(helper._output_path, 'request.json').parent
                if seen.get('mutate', True):
                    changed = dict(self.request, policy_path='canary-policy.json')
                    (self.root / 'request.json').write_bytes(canonical(changed))
                    policy = dict(self.policy, source_date='2026-10-17T00:00:00Z')
                    (self.root / 'policy.json').write_bytes(canonical(policy))
            return real_prepare(*args, **kwargs)

        def recording_open(path, *args, **kwargs):
            if not isinstance(path, int):
                opened.append(os.path.basename(os.fsdecode(path)))
            return real_open(path, *args, **kwargs)

        def recording_run(command, *args, **kwargs):
            if any('select-agent-model' in str(part) for part in command):
                selector_cwds.append(kwargs.get('cwd'))
                script = next(Path(part).resolve() for part in command if 'select-agent-model' in str(part))
                selector_scripts.append(script)
                scoped_root = helper._output_path('request.json').parent
                if scoped_root != self.root:
                    self.assertEqual(script.parent, scoped_root / 'plugins/sdd-implementation/scripts')
                    self.assertEqual(sha_file(script), sha_file(self.root / SELECTOR_SH))
            return real_run(command, *args, **kwargs)

        patches: list[contextlib.AbstractContextManager[Any]] = [mock.patch.object(helper, 'prepare_policy', side_effect=mutate_then_prepare),
                   mock.patch.object(os, 'open', recording_open),
                   mock.patch.object(os, 'supports_dir_fd', os.supports_dir_fd | {recording_open}),
                   mock.patch.object(helper.subprocess, 'run', side_effect=recording_run)]
        with contextlib.ExitStack() as stack:
            for patch in patches:
                stack.enter_context(patch)
            self.api_rejected(sha, {'input-invalid', 'config-conflict'})
            with self.in_root():
                self.assertEqual(helper._output_path('request.json'), self.root / 'request.json',
                                 'snapshot root leaked after a rejected validation')
        self.assertEqual(seen['cwd'], self.root, 'production must not os.chdir')
        self.assertNotEqual(seen['root'], self.root, 'shared reads must use the private captured snapshot')
        self.assertEqual(seen['fresh'], self.root, 'an independent context keeps the legacy default root')
        self.assertEqual(seen['copied'], seen['root'])
        self.assertNotIn('canary-policy.json', opened, 'unlisted canary reference was opened')
        for cwd in selector_cwds:
            self.assertEqual(Path(cwd).resolve(), seen['root'])
        # Restore identical original bytes; a copied context validates and resets cleanly.
        self.save()
        seen.clear()
        seen['mutate'] = False
        selector_cwds.clear()
        selector_scripts.clear()
        with contextlib.ExitStack() as stack:
            for patch in patches:
                stack.enter_context(patch)
            value = contextvars.copy_context().run(self.api, sha)
            with self.in_root():
                self.assertEqual(helper._output_path('request.json'), self.root / 'request.json')
        self.assert_validation(value, sha=sha, selection=self.selection)
        self.assertNotEqual(seen['root'], self.root)
        self.assertTrue(selector_cwds, 'the existing selector replay must run')
        for cwd in selector_cwds:
            self.assertEqual(Path(cwd).resolve(), seen['root'])
        # Legacy direct preparation keeps cwd=None selector replay and Path.cwd() resolution.
        selector_cwds.clear()
        selector_scripts.clear()
        with self.in_root(), mock.patch.object(helper.subprocess, 'run', side_effect=recording_run):
            context = helper.prepare_policy('request.json', 'registry.json', options={}, environment={})
            helper._replay_policy_winner(context)
        self.assertEqual(selector_cwds, [None])
        self.assertEqual(selector_scripts, [self.root / SELECTOR_SH])

    @staticmethod
    @contextlib.contextmanager
    def without_attribute(target, name):
        missing = object()
        previous = getattr(target, name, missing)
        if previous is not missing:
            delattr(target, name)
        try:
            yield
        finally:
            if previous is not missing:
                setattr(target, name, previous)

    def test_controls_captured_environment_is_scoped_and_resets_on_rejection(self):
        env = {'SDD_MODEL_TASK_REVIEWER_B': 'anthropic/opus'}
        selection, sha = self.baseline_accepts('task-reviewer-b', env=env)
        helper = self.helper()
        real_prepare = helper.prepare_policy
        seen: dict[str, Any] = {}

        def observe_environment(*args, **kwargs):
            if not seen:
                seen['captured'] = contextvars.copy_context().run(
                    real_prepare, 'request.json', 'registry.json')['requested']
                seen['independent'] = contextvars.Context().run(
                    real_prepare, 'request.json', 'registry.json')['requested']
                seen['explicit'] = real_prepare('request.json', 'registry.json',
                                                environment={})['requested']
            return real_prepare(*args, **kwargs)

        with self.model_env(), mock.patch.object(helper, 'prepare_policy', side_effect=observe_environment):
            value = self.api(sha, env=env)
        self.assert_validation(value, sha=sha, selection=selection)
        self.assertEqual(seen['captured']['model_source'], 'environment')
        self.assertEqual(seen['captured']['model_id'], 'anthropic/opus')
        self.assertIsNone(seen['independent']['model_id'])
        self.assertIsNone(seen['explicit']['model_id'])
        with self.model_env(), self.in_root():
            self.assertIsNone(real_prepare('request.json', 'registry.json')['requested']['model_id'])
            with mock.patch.object(helper, 'prepare_policy', side_effect=helper.PolicyError(
                    'input-invalid', 'controlled captured-context rejection')):
                self.api_rejected(sha, 'input-invalid', env=env)
            self.assertIsNone(real_prepare('request.json', 'registry.json')['requested']['model_id'])
            self.assertEqual(helper._output_path('request.json'), self.root / 'request.json')

    def test_controls_reject_unavailable_safe_open_primitive(self):
        helper = self.helper()
        _, sha = self.baseline_accepts('impl-reviewer-a')
        real_run = subprocess.run
        calls = []

        def recording_run(command, *args, **kwargs):
            calls.append(command)
            return real_run(command, *args, **kwargs)

        primitive_contexts: list[tuple[str, Callable[[], contextlib.AbstractContextManager[Any]]]] = [
                               ('no-O_NOFOLLOW', lambda: self.without_attribute(os, 'O_NOFOLLOW')),
                               ('no-dir_fd-open', lambda: mock.patch.object(os, 'supports_dir_fd', set()))]
        for label, context in primitive_contexts:
            with self.subTest(primitive=label):
                calls.clear()
                with mock.patch.object(helper, 'prepare_policy', wraps=helper.prepare_policy) as prepare, \
                        mock.patch.object(helper.subprocess, 'run', side_effect=recording_run):
                    with context():
                        self.api_rejected(sha, 'input-invalid')
                prepare.assert_not_called()
                self.assertEqual(calls, [], 'no selector/model process may run without the safe primitive')
        self.assert_validation(self.api(sha), sha=sha, selection=self.selection)

    def test_controls_aggregate_snapshot_budget_is_bounded_before_selection(self):
        self.baseline_accepts('evaluator')
        helper = self.helper()
        # Distinguish a single oversized read from the sum of individually bounded files.
        cases = [('single-file', ['opus'], helper.MAX_OPERATION_BYTES + 1),
                 ('aggregate-unique-files', ['opus', 'sonnet', 'haiku'], helper.MAX_OPERATION_BYTES // 3 + 1)]
        for label, names, size in cases:
            with self.subTest(budget=label):
                self.policy = self.fixture_policy()
                if len(names) > 1:
                    self.assertLessEqual(size, helper.MAX_OPERATION_BYTES)
                    self.assertGreater(size * len(names), helper.MAX_OPERATION_BYTES)
                raw = b' ' * size
                for name in names:
                    path = self.root / (name + '-fixture-adoption.json')
                    path.write_bytes(raw)
                    for model in self.policy['models']:
                        for evidence in model['adoption']:
                            if evidence['path'] == path.name:
                                evidence['sha256'] = sha_bytes(raw)
                self.save()
                sha = self.controls()
                with mock.patch.object(helper, 'prepare_policy', wraps=helper.prepare_policy) as prepare:
                    self.api_rejected(sha, 'input-invalid')
                prepare.assert_not_called()
                self.assertFalse(self.marker.exists())

    def test_controls_trusted_registry_floor_cannot_be_resealed(self):
        self.baseline_accepts('evaluator')
        legitimate = copy.deepcopy(self.selection)
        trusted = json.loads(self.trusted_registry_raw)
        with self.subTest(case='canonical-equal-registry-bytes'):
            self.registry_raw = canonical(trusted)
            selection = self.select('evaluator')
            sha = self.controls()
            self.assert_validation(self.accepted(self.cli(sha=sha)), sha=sha, selection=selection)

        def floor(registry):
            registry['role_defaults']['sdd-evaluator']['minimum_tier'] = 'lightweight'
            registry['role_defaults']['sdd-evaluator']['claude_frontmatter']['minimum_tier'] = 'lightweight'

        def by_name(registry, name):
            return next(item for item in registry['models'] if item['name'] == name)

        forgeries = [
            ('floor', 'low', floor),
            ('tier', 'low', lambda r: by_name(r, 'anthropic/haiku').__setitem__('canonical_tier', 'strong')),
            ('effort', 'high', lambda r: by_name(r, 'anthropic/haiku').update(
                supported_efforts=['low', 'high'], canonical_tier='strong')),
            ('effort-control', 'high', lambda r: by_name(r, 'anthropic/opus')['effort_control'].__setitem__(
                HOST, 'flag')),
            ('model-addition', 'high', lambda r: r['models'].append({
                'name': 'anthropic/fable', 'canonical_tier': 'strong', 'supported_efforts': ['high'],
                'default_effort': 'high', 'effort_control': {HOST: 'frontmatter'}})),
        ]
        for label, risk, forge in forgeries:
            with self.subTest(forgery=label):
                registry = copy.deepcopy(trusted)
                forge(registry)
                self.registry_raw = canonical(registry)
                self.request = self.fresh_request('evaluator', risk)
                selection, _ = self.try_select()
                if selection is None:
                    selection = dict(legitimate, catalog_sha256=digest(registry))
                    selection['selection_sha256'] = digest(selection, 'selection_sha256')
                self.write('selection.json', selection)
                self.rejected(self.cli(sha=self.controls()), {'config-conflict', 'config-invalid', 'input-invalid'})

    def test_controls_trusted_native_mapping_cannot_be_resealed(self):
        self.baseline_accepts('spec-reviewer-a')
        baseline = copy.deepcopy(self.policy)
        with self.subTest(policy='valid-restricted-subset'):
            self.policy['models'] = [copy.deepcopy(self.policy_model('anthropic/opus'))]
            self.assertEqual(self.policy['models'][0]['successor_of'], [])
            for role in self.policy['roles'].values():
                role['preferences'] = [name for name in role['preferences'] if name == 'anthropic/opus']
            selection = self.select('spec-reviewer-a')
            sha = self.controls()
            self.assertEqual(selection['resolved']['catalog_id'], 'anthropic/opus')
            self.assert_validation(self.accepted(self.cli(sha=sha)), sha=sha, selection=selection)
        swaps = [('strong-to-light', {'anthropic/opus': 'haiku', 'anthropic/haiku': 'opus'}),
                 ('strong-to-standard', {'anthropic/opus': 'sonnet', 'anthropic/sonnet': 'opus'})]
        for label, mapping in swaps:
            with self.subTest(swap=label):
                self.policy = copy.deepcopy(baseline)
                for name, native in mapping.items():
                    self.policy_model(name)['hosts'][HOST] = native
                selection = self.select('spec-reviewer-a', trusted_mapping=False)
                self.assertEqual(selection['resolved']['native_id'], mapping[selection['resolved']['catalog_id']])
                self.rejected(self.cli(sha=self.controls()), 'config-conflict')
        with self.subTest(swap='added-host-mapping'):
            self.policy = copy.deepcopy(baseline)
            self.policy_model('anthropic/opus')['hosts']['codex-cli'] = 'opus-codex-fixture'
            self.select('spec-reviewer-a')
            self.rejected(self.cli(sha=self.controls()), 'config-conflict')

    def test_controls_recompute_every_selection_leaf(self):
        selection, _ = self.baseline_accepts('task-reviewer-b')
        other_binding = {'run_id': self.run_id, 'session_id': str(uuid.uuid4()), 'attempt': 1}
        mutations = [
            ('role', ('role',), 'task-reviewer-a'), ('host', ('host',), 'codex-cli'),
            ('risk', ('risk',), 'critical'), ('cli_version', ('cli_version',), 'fixture-claude 2.0'),
            ('scope_id', ('scope_id',), 'fixture-client-2'),
            ('requested', ('requested',), {'policy': 'pinned', 'model_id': 'anthropic/opus',
                                           'policy_source': 'cli', 'model_source': 'cli'}),
            ('requested.policy_source', ('requested', 'policy_source'), 'project-default'),
            ('resolved.catalog_id', ('resolved', 'catalog_id'), 'anthropic/sonnet'),
            ('resolved.native_id', ('resolved', 'native_id'), 'sonnet'),
            ('resolved.effort', ('resolved', 'effort'), 'medium'),
            ('resolved.effort-xhigh', ('resolved', 'effort'), 'xhigh'),
            ('resolved.effort-max', ('resolved', 'effort'), 'max'),
            ('resolved.effort_control', ('resolved', 'effort_control'), 'flag'),
            ('policy_sha256', ('policy_sha256',), flip(selection['policy_sha256'])),
            ('catalog_sha256', ('catalog_sha256',), flip(selection['catalog_sha256'])),
            ('observation_sha256', ('observation_sha256',), flip(selection['observation_sha256'])),
            ('observed_at', ('observed_at',), utc_now(timedelta(seconds=-5))),
            ('source_date', ('source_date',), '2026-10-17T00:00:00Z'),
            ('reason', ('reason',), 'pinned; verified-configuration; changed provenance.'),
            ('update_candidates', ('update_candidates',), ['anthropic/haiku']),
            ('budget', ('budget',), {'amount': 1, 'unit': 'USD'}),
            ('estimate', ('estimate',), {'catalog_id': selection['resolved']['catalog_id'], 'amount': 0,
                                         'unit': 'USD', 'source_url': 'https://example.invalid/price',
                                         'source_date': '2026-10-18T00:00:00Z'}),
            ('binding', ('binding',), other_binding),
        ]
        mutations += [('all-leaves/' + '/'.join(map(str, path)), path, altered(get_path(selection, path)))
                      for path in leaf_paths(selection)]
        for label, path, value in mutations:
            with self.subTest(leaf=label):
                changed = copy.deepcopy(selection)
                set_path(changed, path, value)
                if path != ('selection_sha256',):
                    changed['selection_sha256'] = digest(changed, 'selection_sha256')
                self.write('selection.json', changed)
                self.rejected(self.cli(sha=self.controls()), REASONS)

    def test_controls_bound_budget_and_estimate_each_leaf_is_recomputed(self):
        self.request['budget'] = {'amount': 2, 'unit': 'USD'}
        self.request['estimates'] = [{'catalog_id': 'anthropic/opus', 'amount': 1, 'unit': 'USD',
                                      'source_url': 'https://example.invalid/fixture-price',
                                      'source_date': '2026-10-18T00:00:00Z'}]
        selection = self.select('spec-reviewer-a')
        self.assertEqual(selection['budget'], self.request['budget'])
        self.assertEqual(selection['estimate'], self.request['estimates'][0])
        bound = self.helper().bind_selection(selection, run_id=self.run_id,
                                             session_id=self.session_id, attempt=1)
        self.write('selection.json', bound)
        self.accepted(self.cli(sha=self.controls()))
        for prefix in ('binding', 'budget', 'estimate'):
            for path in leaf_paths(bound[prefix], (prefix,)):
                with self.subTest(leaf='/'.join(map(str, path))):
                    changed = copy.deepcopy(bound)
                    set_path(changed, path, altered(get_path(bound, path)))
                    changed['selection_sha256'] = digest(changed, 'selection_sha256')
                    self.write('selection.json', changed)
                    self.rejected(self.cli(sha=self.controls()), REASONS)
        self.write('selection.json', bound)
        self.accepted(self.cli(sha=self.controls()))

    def test_controls_require_active_capture_and_preserve_adoption(self):
        legitimate, _ = self.baseline_accepts('evaluator')
        fresh = copy.deepcopy(self.observation)

        def resealed_with(observation):
            self.observation = observation
            self.save()
            changed = dict(legitimate, observation_sha256=observation['observation_sha256'],
                           observed_at=observation['observed_at'])
            changed['reason'] = changed['reason'].replace('verified-configuration', observation['source'])
            changed['selection_sha256'] = digest(changed, 'selection_sha256')
            self.write('selection.json', changed)
            return self.controls()

        with self.subTest(case='persisted-live-without-capture'):
            sha = resealed_with(self.seal(dict(copy.deepcopy(fresh), source='live-discovery', purpose='launch')))
            self.rejected(self.cli(sha=sha), 'scope-mismatch')
            self.api_rejected(sha, 'scope-mismatch')
            self.api_rejected(sha, 'scope-mismatch', capture=object())
        with self.subTest(case='stale-observation'):
            sha = resealed_with(self.seal(dict(copy.deepcopy(fresh), observed_at=utc_now(timedelta(hours=-1)))))
            self.rejected(self.cli(sha=sha), 'discovery-stale')
        with self.subTest(case='changed-adoption-bytes-fresh-pin'):
            self.observation = self.fresh_observation()
            self.select('evaluator')
            (self.root / 'opus-fixture-adoption.json').write_bytes(b'{"fixture_only":true,"changed":true}')
            self.rejected(self.cli(sha=self.controls()), {'config-invalid', 'config-conflict', 'input-invalid'})
        with self.subTest(case='changed-adoption-bytes-stale-pin'):
            self.policy = self.fixture_policy()
            self.select('evaluator')
            sha = self.controls()
            (self.root / 'sonnet-fixture-adoption.json').write_bytes(b'{"fixture_only":true,"changed":true}')
            self.rejected(self.cli(sha=sha), 'input-invalid')
        with self.subTest(case='historical-pin-keeps-trusted-mapping'):
            self.policy = self.fixture_policy()
            self.policy_model('anthropic/opus')['lifecycle'] = 'historical'
            self.request = self.fresh_request('evaluator')
            self.request['cli'] = {'model_id': 'anthropic/opus', 'policy': 'pinned'}
            selection = self.select('evaluator')
            self.assertEqual(selection['requested']['policy'], 'pinned')
            self.assertEqual(selection['resolved']['native_id'], 'opus')
            sha = self.controls()
            value = self.accepted(self.cli(sha=sha))
            self.assert_validation(value, sha=sha, selection=selection)
            self.assertEqual(value['selection']['resolved']['native_id'], 'opus')

    def test_controls_actual_id_requirement_stops_before_launch(self):
        selection, sha = self.baseline_accepts('impl-reviewer-b')
        blocked = self.controls(require_actual_id=True)
        self.rejected(self.cli(sha=blocked), 'actual-id-unavailable')
        self.api_rejected(blocked, 'actual-id-unavailable')
        self.assertFalse(self.marker.exists())
        sha = self.controls()
        self.assert_validation(self.accepted(self.cli(sha=sha)), sha=sha, selection=selection)

    def test_controls_native_precedence_conflict_and_matching(self):
        selection, sha = self.baseline_accepts('spec-reviewer-b')
        native = selection['resolved']['native_id']
        self.assertEqual(native, 'opus')
        for conflict in ('sonnet', 'haiku', 'claude-opus-fixture'):
            with self.subTest(native=conflict):
                self.rejected(self.cli(sha=sha, native=conflict), 'native-precedence-conflict')
        self.api_rejected(sha, 'native-precedence-conflict', native_model='sonnet')
        value = self.accepted(self.cli(sha=sha, native=native))
        self.assert_validation(value, sha=sha, selection=selection)
        self.assert_validation(self.api(sha, native_model=native), sha=sha, selection=selection)

    def test_controls_trusted_inventory_contains_schema_and_selectors(self):
        self.assertTrue((ROOT / CONTROLS_SCHEMA).is_file(), 'model-launch-controls schema is missing')
        schema = json.loads((ROOT / CONTROLS_SCHEMA).read_bytes())
        self.assertEqual(schema['$schema'], 'https://json-schema.org/draft/2020-12/schema')
        self.assertEqual(schema['title'], 'model-launch-controls/v1')
        self.assertIs(schema['additionalProperties'], False)
        self.assertEqual(set(schema['required']), {'schema', 'role', 'host', 'attempt', 'require_actual_id',
                                                   'selection', 'request', 'registry', 'inputs'})
        selection = self.select('task-reviewer-a')
        sha = self.controls()
        result = self.cli(sha=sha)
        value = self.accepted(result)
        self.assert_validation(value, sha=sha, selection=selection)
        self.assertEqual(value['trusted'], [{'path': p, 'sha256': sha_file(self.root / p)} for p in TRUSTED_PATHS])
        self.assertEqual(value['trusted'], [{'path': p, 'sha256': sha_file(ROOT / p)} for p in TRUSTED_PATHS])
        pinned = {entry['path'] for entry in value['pins']}
        self.assertFalse(pinned & set(TRUSTED_PATHS))
        self.assertNotIn('controls.json', pinned)
        self.assertEqual(pinned, self.closure() | {'selection.json', 'request.json', 'registry.json'})
        for entry in value['pins'] + value['trusted'] + [value['controls']]:
            self.assertFalse(entry['path'].startswith('/'))
        self.assertNotIn(tempfile.gettempdir(), result.stdout, 'private snapshot paths must not be returned')
        launcher = load_module(LAUNCHER_SCRIPT, 'runtime-inventory')
        self.addCleanup(sys.modules.pop, launcher.__name__, None)
        for fixed in (False, True):
            with self.subTest(runtime_inventory='fixed' if fixed else 'ordinary'):
                files = launcher.runtime_files(ROOT, 'quality', fixed, model_policy=True)
                self.assertTrue({ROOT / path for path in TRUSTED_PATHS}.issubset(files))


class PairedClaudeLaunch(LaunchFixture):

    def setUp(self):
        super().setUp()
        self.transport = load_module(TRANSPORT_SCRIPT, 'transport')
        self.addCleanup(sys.modules.pop, self.transport.__name__, None)
        self.active_env: dict[str, str] = {}
        self.settings = self.root / 'settings.json'
        self.settings.write_text('{}')
        self.invocation = self.root / 'reports/review-context/invocation.json'
        self.invocation.parent.mkdir(parents=True)
        self.invocation.write_text('{}')
        self.receipt = self.root / 'receipt.txt'
        self.receipt.write_text('receipt')
        self.launch_policy_file = self.root / 'launch-policy.json'
        self.launch_policy_file.write_text('{}')
        guard = self.root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
        guard.parent.mkdir(parents=True, exist_ok=True)
        guard.write_text('// fixture\n')
        source = self.root / 'specs/example/requirements.md'
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text('fixture requirement\n')
        self.permissions = ['Read(specs/example/requirements.md)']

    def invocation_data(self, role, extra=()):
        stage, transport_role = PROTECTED[role]
        manifest = [self.ref('specs/example/requirements.md')] + [self.ref(path) for path in extra]
        return {'stage': stage, 'role': transport_role, 'feature': 'example', 'run_id': self.run_id,
                'host_session_id': self.session_id, 'allowed_input_manifest': manifest}

    def role_definition(self, role, model):
        return {'model': model, 'tools': self.transport.agent_tools(PROTECTED[role][0]),
                'disallowedTools': list(DISALLOWED)}

    def bind(self, role, *, risk='high', env=None, data=None, sha=None):
        self.request = self.fresh_request(role, risk)
        self.select(role, risk=risk, env=env)
        sha = sha or self.controls()
        self.active_env = env or {}
        self.accepted(self.cli(sha=sha, env=env))
        with self.model_env(self.active_env), self.in_root():
            binding = self.transport.model_launch_binding(self.root, data or self.invocation_data(role),
                                                          Path('controls.json'), sha)
        return binding, sha

    def command(self, role, binding, *, help_text=HELP_TEXT, role_def=None):
        transport = self.transport
        data = self.invocation_data(role)
        model = binding['native_model'] if binding else 'sonnet'
        role_def = role_def or {**self.role_definition(role, model),
                                **({'effort': binding['effort']} if binding else {})}
        real_run, real_which = subprocess.run, shutil.which

        def run(command, *args, **kwargs):
            if '--help' in command:
                return subprocess.CompletedProcess(command, 0, help_text, '')
            return real_run(command, *args, **kwargs)

        options = {} if binding is None else {'model_binding': binding}
        with self.model_env(self.active_env), self.in_root(), \
                mock.patch.object(transport, 'manifest', return_value=(data, {})), \
                mock.patch.object(transport, 'launch_policy', return_value=(b'{}', {})), \
                mock.patch.object(transport, 'receipt_control',
                                  return_value={'exact_permission_rules': self.permissions}), \
                mock.patch.object(transport, 'admitted_raw_hashes', return_value={}), \
                mock.patch.object(transport.shutil, 'which',
                                  side_effect=lambda name: '/fixture/bin/claude' if name == 'claude'
                                  else real_which(name)), \
                mock.patch.object(transport.subprocess, 'run', side_effect=run):
            if binding is not None:
                options['environment'] = dict(os.environ)
            return transport.claude_command(self.root, self.session_id, PROTECTED[role][1], role_def,
                                            self.permissions, self.settings, self.invocation, self.receipt,
                                            self.launch_policy_file, **options)

    def assert_reason(self, error, reasons):
        reasons = {reasons} if isinstance(reasons, str) else set(reasons)
        actual = getattr(error, 'reason', None)
        if actual is None:
            self.assertTrue(any(reason in str(error) for reason in reasons), str(error))
        else:
            self.assertIn(actual, reasons)

    def test_paired_selected_model_and_effort_reach_argv_for_all_roles(self):
        for role, (stage, transport_role) in PROTECTED.items():
            with self.subTest(role=role):
                env = {'SDD_MODEL_SPEC_REVIEWER_A': 'anthropic/sonnet'} if role == 'spec-reviewer-a' else None
                binding, sha = self.bind(role, risk='medium' if env else 'high', env=env)
                resolved = self.selection['resolved']
                self.assert_validation({k: binding[k] for k in VALIDATION_FIELDS}, sha=sha,
                                       selection=self.selection, role=role)
                self.assertEqual(binding['transport_role'], transport_role)
                self.assertEqual(binding['native_model'], resolved['native_id'])
                self.assertEqual(binding['effort'], resolved['effort'])
                self.assertEqual(binding['effort_control'], resolved['effort_control'])
                self.assertEqual(binding['effort_control'], 'frontmatter')
                legacy = self.command(role, None)
                bound = self.command(role, binding)
                native, effort = resolved['native_id'], resolved['effort']
                role_def = {**self.role_definition(role, native), 'effort': effort}
                self.assertEqual(bound[bound.index('--model') + 1], native)
                self.assertEqual(json.loads(bound[bound.index('--agents') + 1]), {transport_role: role_def})
                self.assertEqual(bound.count('--effort'), 1)
                index = bound.index('--effort')
                self.assertEqual(bound[index + 1], effort)
                stripped = bound[:index] + bound[index + 2:]
                sources = stripped.index('--setting-sources')
                self.assertEqual(stripped[sources + 1], '')
                stripped = stripped[:sources] + stripped[sources + 2:]
                expected = list(legacy)
                expected[expected.index('--model') + 1] = native
                expected[expected.index('--agents') + 1] = json.dumps({transport_role: role_def})
                self.assertEqual(stripped, expected, 'permissions and every existing argv element are unchanged')
                for flag, value in [('--permission-mode', 'dontAsk'), ('--tools', 'Read,Bash'),
                                    ('--disallowedTools', ','.join(DISALLOWED)), ('--settings', str(self.settings)),
                                    ('--agent', transport_role), ('--session-id', self.session_id),
                                    ('--output-format', 'json')]:
                    self.assertEqual(bound[bound.index(flag) + 1], value)
                self.assertEqual('--json-schema' in bound, stage != 'quality')
                self.assertNotIn('--effort', legacy)

    def test_paired_native_conflict_and_missing_effort_support(self):
        binding, _ = self.bind('evaluator')
        self.assertEqual(binding['native_model'], 'opus')
        for model in ('sonnet', 'haiku', 'Opus'):
            with self.subTest(role_model=model):
                with self.assertRaises(ValueError) as caught:
                    self.command('evaluator', binding, role_def=self.role_definition('evaluator', model))
                self.assert_reason(caught.exception, 'native-precedence-conflict')
        with self.assertRaises(ValueError) as caught:
            self.command('evaluator', binding, help_text=HELP_WITHOUT_EFFORT)
        self.assert_reason(caught.exception, 'effort-unavailable')
        self.assertNotIn('--effort', self.command('evaluator', None, help_text=HELP_WITHOUT_EFFORT))
        self.assertIn('xhigh, max', HELP_TEXT)
        self.assertIn(binding['effort'], EFFORTS, 'the registry never authorizes max')
        bound = self.command('evaluator', binding)
        self.assertEqual(bound[bound.index('--effort') + 1], 'high')
        self.assertFalse(self.marker.exists())

    def test_paired_captured_native_overrides_follow_documented_precedence(self):
        # Public Claude 2.1.303 docs: effort env wins; FORCE wins over agent model;
        # alias remaps are not exact backend identity evidence. No private settings read.
        accepted = [({}, 'clean'),
                    ({'CLAUDE_CODE_EFFORT_LEVEL': 'high'}, 'matching-effort'),
                    ({'CLAUDE_CODE_SUBAGENT_MODEL': 'haiku'}, 'lower-priority-default'),
                    ({'ANTHROPIC_MODEL': 'haiku'}, 'explicit-model-wins'),
                    ({'CLAUDE_CODE_SUBAGENT_MODEL_FORCE': '1',
                      'CLAUDE_CODE_SUBAGENT_MODEL': 'opus'}, 'matching-force'),
                    ({'CLAUDE_CODE_SUBAGENT_MODEL_FORCE': 'true'}, 'force-main-model')]
        for env, label in accepted:
            with self.subTest(native_context=label):
                binding, _ = self.bind('evaluator', env=env)
                self.assertEqual(binding['native_overrides'], {name: env.get(name) for name in NATIVE_OVERRIDES})
                command = self.command('evaluator', binding)
                agent = json.loads(command[command.index('--agents') + 1])['sdd-evaluator']
                self.assertEqual(agent['model'], 'opus')
                self.assertEqual(agent['effort'], 'high')
                self.assertEqual(command[command.index('--effort') + 1], 'high')
        rejected = [({'CLAUDE_CODE_EFFORT_LEVEL': 'low'}, 'effort-env-wins'),
                    ({'CLAUDE_CODE_SUBAGENT_MODEL_FORCE': '1',
                      'CLAUDE_CODE_SUBAGENT_MODEL': 'haiku'}, 'forced-light-model'),
                    ({'CLAUDE_CODE_SUBAGENT_MODEL_FORCE': 'YeS',
                      'CLAUDE_CODE_SUBAGENT_MODEL': 'sonnet'}, 'case-insensitive-force'),
                    ({'CLAUDE_CODE_SUBAGENT_MODEL_FORCE': 'unexpected'}, 'unknown-force-value'),
                    ({'ANTHROPIC_DEFAULT_OPUS_MODEL': 'claude-haiku-fixture'}, 'weak-alias-remap'),
                    ({'ANTHROPIC_DEFAULT_OPUS_MODEL': 'claude-opus-fixture'}, 'unverified-alias-remap')]
        for env, label in rejected:
            with self.subTest(native_context=label):
                with self.assertRaises(ValueError) as caught:
                    binding, _ = self.bind('evaluator', env=env)
                    self.command('evaluator', binding)
                self.assert_reason(caught.exception, 'native-precedence-conflict')
        binding, _ = self.bind('evaluator', env={'CLAUDE_CODE_EFFORT_LEVEL': 'high'})
        self.active_env['CLAUDE_CODE_EFFORT_LEVEL'] = 'low'
        with self.assertRaises(ValueError) as caught:
            self.command('evaluator', binding)
        self.assert_reason(caught.exception, 'native-precedence-conflict')
        self.assertFalse(self.marker.exists())

    def test_paired_generated_agent_effort_conflict_is_rejected(self):
        binding, _ = self.bind('evaluator')
        for effort in ('low', 'medium', 'max', None):
            with self.subTest(agent_effort=effort):
                role = self.role_definition('evaluator', 'opus')
                if effort is not None:
                    role['effort'] = effort
                with self.assertRaises(ValueError) as caught:
                    self.command('evaluator', binding, role_def=role)
                self.assert_reason(caught.exception, 'native-precedence-conflict')

    def test_paired_control_read_overlap_and_pin_mutation(self):
        binding, sha = self.bind('task-reviewer-a')
        for path in sorted(self.closure() | {'controls.json', 'request.json', 'selection.json', 'registry.json'}):
            with self.subTest(overlap=path):
                with self.assertRaises(ValueError) as caught, self.model_env(), self.in_root():
                    self.transport.model_launch_binding(self.root, self.invocation_data('task-reviewer-a', [path]),
                                                        Path('controls.json'), sha)
                self.assert_reason(caught.exception, {'input-invalid', 'config-conflict'})
        with self.subTest(pin='controls'):
            with self.assertRaises(ValueError) as caught, self.model_env(), self.in_root():
                self.transport.model_launch_binding(self.root, self.invocation_data('task-reviewer-a'),
                                                    Path('controls.json'), flip(sha))
            self.assert_reason(caught.exception, 'input-invalid')
        command = self.command('task-reviewer-a', binding)
        output = self.root / 'reports/task-review/example/launch-fixture'
        output.mkdir(parents=True)
        with self.model_env(), self.in_root():
            launch_sha = self.transport.record_model_launch(output, binding, command, 'generated')
            self.transport.verify_model_launch(self.root, output, launch_sha, binding, command)
        for path in ('observation.json', 'policy.json', 'opus-fixture-adoption.json', 'selection.json'):
            with self.subTest(pin=path):
                original = (self.root / path).read_bytes()
                (self.root / path).write_bytes(original + b' ')
                try:
                    with self.model_env(), self.in_root():
                        with self.assertRaises(ValueError) as caught:
                            self.transport.model_launch_binding(self.root, self.invocation_data('task-reviewer-a'),
                                                                Path('controls.json'), sha)
                        self.assert_reason(caught.exception, 'input-invalid')
                        with self.assertRaises(ValueError):
                            self.transport.verify_model_launch(self.root, output, launch_sha, binding, command)
                finally:
                    (self.root / path).write_bytes(original)

    def test_paired_sidecar_rejects_symlinked_parent_before_controls_revalidation(self):
        binding, _ = self.bind('task-reviewer-a')
        command = self.command('task-reviewer-a', binding)
        real = self.root / 'reports/real-parent/launch'
        real.mkdir(parents=True)
        with self.model_env(), self.in_root():
            digest = self.transport.record_model_launch(real, binding, command, 'generated')
            self.transport.verify_model_launch(self.root, real, digest, binding, command)
        alias = self.root / 'reports/aliased-parent'
        alias.symlink_to(real.parent, target_is_directory=True)
        with self.model_env(), self.in_root(), mock.patch.object(
                self.transport, 'fresh_model_binding', return_value=binding) as refreshed:
            with self.assertRaises(ValueError):
                self.transport.verify_model_launch(self.root, alias / 'launch', digest, binding, command)
            refreshed.assert_not_called()

    def test_paired_launch_binding_every_field_counterpart(self):
        role = 'spec-reviewer-a'
        definition = self.root / 'plugins/sdd-review-loop/agents' / (role + '.md')
        definition.parent.mkdir(parents=True, exist_ok=True)
        definition.write_text('---\nmodel: sonnet\neffort: medium\n---\nReview admitted inputs.\n')
        binding, sha = self.bind(role, risk='medium', env={'SDD_MODEL_SPEC_REVIEWER_A': 'anthropic/sonnet'})
        command = self.command(role, binding)
        output = self.root / 'reports/spec-review/example/launch-fixture'
        output.mkdir(parents=True)
        record_path = output / 'model-launch.json'
        with self.model_env(self.active_env), self.in_root():
            launch_sha = self.transport.record_model_launch(output, binding, command, 'matching')
        raw = record_path.read_bytes()
        self.assertEqual(sha_bytes(raw), launch_sha)
        record = json.loads(raw)
        self.assertEqual(set(record), LAUNCH_FIELDS)
        expected = {'schema': 'model-launch-binding/v1', 'controls': {'path': 'controls.json', 'sha256': sha},
                    'pins': binding['pins'], 'trusted': binding['trusted'], 'role': role,
                    'transport_role': role, 'host': HOST, 'run_id': self.run_id, 'session_id': self.session_id,
                    'attempt': 1, 'require_actual_id': False,
                    'selection_sha256': binding['selection']['selection_sha256'], 'native_model': 'sonnet',
                    'effort': 'medium', 'effort_control': 'frontmatter', 'effort_carrier': 'flag+frontmatter',
                    'agent_model': 'sonnet', 'agent_effort': 'medium',
                    'native_overrides': {name: None for name in NATIVE_OVERRIDES},
                    'native_alignment': 'matching', 'transport': 'claude-print', 'argv': command,
                    'model_argv': ['--model', 'sonnet'], 'effort_argv': ['--effort', 'medium']}
        self.assertEqual({k: record[k] for k in expected}, expected)
        with self.model_env(self.active_env), self.in_root():
            self.transport.verify_model_launch(self.root, output, launch_sha, binding, command)
            with self.assertRaises((FileExistsError, ValueError)):
                self.transport.record_model_launch(output, binding, command, 'matching')
        self.assertEqual(record_path.read_bytes(), raw, 'model-launch.json is create-only')
        mutations = [('/'.join(map(str, path)), path, altered(get_path(record, path)))
                     for path in leaf_paths(record)]
        mutations += [('native_alignment=generated', ('native_alignment',), 'generated'),
                      ('transport=codex-exec', ('transport',), 'codex-exec'),
                      ('effort_carrier=frontmatter', ('effort_carrier',), 'frontmatter'),
                      ('effort=high', ('effort',), 'high'), ('native_model=opus', ('native_model',), 'opus'),
                      ('role=spec-reviewer-b', ('role',), 'spec-reviewer-b'),
                      ('host=codex-cli', ('host',), 'codex-cli')]
        removals = [('missing-' + field, field) for field in sorted(record)]
        try:
            for label, path, value in mutations + [(label, None, field) for label, field in removals] + \
                    [('unknown-field', ('unexpected',), True)]:
                with self.subTest(field=label):
                    changed = copy.deepcopy(record)
                    if path is None:
                        changed.pop(value)
                    else:
                        set_path(changed, path, value)
                    mutated = canonical(changed)
                    record_path.write_bytes(mutated)
                    with self.model_env(self.active_env), self.in_root():
                        with self.assertRaises(ValueError):
                            self.transport.verify_model_launch(self.root, output, sha_bytes(mutated), binding, command)
                        with self.assertRaises(ValueError):
                            self.transport.verify_model_launch(self.root, output, launch_sha, binding, command)
        finally:
            record_path.write_bytes(raw)
        index = command.index('--effort')
        static = command[:index + 1] + ['high'] + command[index + 2:]
        for label, candidate in [('static-effort-text', static), ('missing-effort', command[:index] + command[index + 2:]),
                                 ('legacy-command', self.command(role, None))]:
            with self.subTest(counterpart=label):
                with self.model_env(self.active_env), self.in_root():
                    with self.assertRaises(ValueError):
                        self.transport.verify_model_launch(self.root, output, launch_sha, binding, candidate)
        with self.model_env(self.active_env), self.in_root():
            self.transport.verify_model_launch(self.root, output, launch_sha, binding, command)

    def exercise_bound_quality_launch(self, *, controls_sha=None, binding_controls='controls.json', legacy=False,
                                      complete=False):
        """Adapted from QualityTransport.exercise_quality_launch; real claude_command and controls."""
        launcher = load_module(LAUNCHER_SCRIPT, 'launcher')
        self.addCleanup(sys.modules.pop, launcher.__name__, None)
        transport = launcher.transport
        root, session = self.root, self.session_id
        manifest = []
        for relative in ['specs/example/' + name for name in ('requirements.md', 'design.md',
                         'acceptance-tests.md', 'tasks.md', 'traceability.md')] + [
                'plugins/sdd-quality-loop/references/quality-gate-calibration.md',
                'reports/implementation/example/T-001.md']:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(relative + '\n')
            manifest.append({'path': relative, 'sha256': sha_file(path)})
        ledger = self.invocation.parent / 'identity-ledger.json'
        ledger.write_text('unchanged')
        role = root / 'plugins/sdd-quality-loop/agents/evaluator.md'
        role.parent.mkdir(parents=True, exist_ok=True)
        role.write_text('---\nmodel: sonnet\n---\nInspect admitted inputs.\n')
        probe = root / 'plugins/sdd-review-loop/scripts/probe-nontty-review.py'
        probe.write_text('probe')
        executable = root / 'bin'
        executable.write_text('binary')
        output = root / 'reports/quality-gate' / ('launch-' + session)
        output.parent.mkdir(parents=True, exist_ok=True)
        transcript = root / '.claude/projects' / (session + '.jsonl')
        transcript.parent.mkdir(parents=True, exist_ok=True)
        transcript.write_text('{}')
        data: dict[str, Any] = {'stage': 'quality', 'role': 'sdd-evaluator', 'feature': 'example', 'task_id': 'T-001',
                'run_id': session, 'host_session_id': session, 'scratch_root': str(root / 'scratch'),
                'allowed_input_manifest': manifest}
        receipt = ('REVIEW_CONTEXT_OK ' + 'b' * 64 + ' sequence=2 previous_record_sha256=' + 'a' * 64 +
                   ' pre_append_tip_sequence=1 identity_unique=yes\n')
        if complete:
            # Successful wiring fixture: preserve genuine controls and pure guard/receipt rendering.
            # Native probe, reservation and delivery remain explicitly synthetic controller fixtures.
            data.update(schema='review-context-invocation/v2', read_only=True, input_mode='file-manifest',
                        fallback_mode='none', sequence=2, previous_record_sha256='a' * 64,
                        identity_ledger_path='reports/review-context/identity-ledger.json',
                        identity_ledger_sha256=sha_file(ledger))
            self.invocation.write_bytes(canonical(data))
            for relative in (transport.BOUNDARY_PATH, TRANSPORT_SCRIPT.relative_to(ROOT).as_posix()):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
            inputs_hash = sha_bytes('\n'.join(entry['path'] + '\t' + entry['sha256']
                                              for entry in manifest).encode())
            record_text = '|'.join(['2', 'quality', 'sdd-evaluator', session, session, 'a' * 64])
            record_text += '|scratch-declaration-v1|' + sha_bytes(
                (data['feature'] + '\n' + data['scratch_root']).encode())
            if transport.inputs_bound(data):
                record_text += '|allowed-inputs-v1|' + inputs_hash
            receipt = ('REVIEW_CONTEXT_OK ' + sha_bytes(record_text.encode()) +
                       ' sequence=2 previous_record_sha256=' + 'a' * 64 +
                       ' pre_append_tip_sequence=1 identity_unique=yes\n')
        events, native_calls = [], []
        real_run, real_which = subprocess.run, shutil.which

        def preflight(*_args):
            events.append('preflight')
            return {'status': 'PREFLIGHT_OK', 'session_id': session, 'invocation_sha256': sha_file(self.invocation)}

        def run(_root, command, destination, prompt=None, **_kwargs):
            events.append(destination.name)
            if destination.name == 'native.jsonl':
                return json.dumps({'admitted_read_executed': True, 'control_reads_executed': True,
                                   'source_invocation_read_executed': True,
                                   'source_invocation_sha256': sha_file(self.invocation),
                                   'admitted_paths': [entry['path'] for entry in manifest],
                                   'outside_read_pretool_denied': True, 'existing_session_collision_rejected': True,
                                   'chained_bash_pretool_denied': True, 'ordered_hashes_verified': len(manifest) + 5})
            if destination.name == 'reserved.txt':
                events.append('model-launch-before-reservation:' + str((output / 'model-launch.json').is_file()))
                return receipt + ('EVALUATOR_DELIVERY_OK inputs=' + str(len(manifest)) + '; reservation=performed\n')
            if destination.name == 'wrapper.json':
                native_calls.append(list(command))
            destination.write_text(receipt)
            return receipt

        def preview(command, *args, **kwargs):
            text = ' '.join(map(str, command))
            if 'select-agent-model' in text or 'model-policy.py' in text:
                return real_run(command, *args, **kwargs)
            if '--help' in command:
                return subprocess.CompletedProcess(command, 0, HELP_TEXT, '')
            if len(command) > 4 and str(command[4]).endswith('/preflight-evaluator-delivery.py'):
                events.append('scratch-delivery-preflight')
                return subprocess.CompletedProcess(command, 0, 'EVALUATOR_DELIVERY_OK inputs=' + str(len(manifest)) +
                                                   '; reservation=not performed\n', '')
            if len(command) > 3 and str(command[3]).endswith('/preflight-host-review.py'):
                events.append('common-input-preflight')
                return subprocess.CompletedProcess(command, 0, 'HOST_REVIEW_PREFLIGHT_OK inputs=1 '
                                                   'permission-proof=not-established reservation=not-performed\n', '')
            events.append('canonical-preview')
            return subprocess.CompletedProcess(command, 0, receipt, '')

        options = {} if legacy else {'model_binding': {'controls': Path(binding_controls),
                                                       'controls_sha256': controls_sha}}
        error = None
        with self.model_env(self.active_env), \
                mock.patch.object(transport, 'manifest', return_value=(data, {})), \
                mock.patch.object(transport, 'preflight', side_effect=preflight), \
                (contextlib.nullcontext() if complete else
                 mock.patch.object(transport, 'launch_policy', return_value=(b'{}', {}))), \
                (contextlib.nullcontext() if complete else
                 mock.patch.object(transport, 'receipt_control', return_value={'exact_permission_rules': []})), \
                (contextlib.nullcontext() if complete else
                 mock.patch.object(transport, 'admitted_raw_hashes', return_value={})), \
                mock.patch.object(transport, 'expected_prompt', return_value=b'prompt'), \
                mock.patch.object(transport, 'postflight', return_value={'status': 'DELIVERY_OK'},
                    side_effect=None if complete else ValueError('fixture stop after native call')), \
                mock.patch.object(launcher.shutil, 'which',
                                  side_effect=lambda name: real_which(name) if name in ('bash', 'pwsh')
                                  else str(executable)), \
                mock.patch.object(launcher.subprocess, 'run', side_effect=preview), \
                mock.patch.object(launcher, 'run', side_effect=run), \
                mock.patch.object(Path, 'home', return_value=root):
            try:
                launcher.launch(root, self.invocation, output, sha_file(self.invocation), **options)
            except ValueError as caught:
                error = caught
        self.assertEqual(ledger.read_text(), 'unchanged')
        self.assertFalse(self.marker.exists())
        return {'events': events, 'native_calls': native_calls, 'error': error, 'output': output, 'data': data}

    def test_launcher_bad_controls_fail_before_reservation_or_native(self):
        self.active_env = {'SDD_MODEL_EVALUATOR': 'anthropic/sonnet'}
        self.run_id = self.session_id
        self.request = self.fresh_request('evaluator', 'medium')
        selection = self.select('evaluator', risk='medium', env=self.active_env)
        self.assertEqual(selection['resolved']['native_id'], 'sonnet')
        good = self.controls()
        self.accepted(self.cli(sha=good, env=self.active_env))
        good_raw = (self.root / 'controls.json').read_bytes()
        def remove_controls():
            (self.root / 'controls.json').unlink()
            return good

        bad_cases = [('pin', lambda: flip(good)),
                     ('missing-file', remove_controls),
                     ('role', lambda: self.controls('spec-reviewer-a')),
                     ('actual-id', lambda: self.controls(require_actual_id=True))]
        for label, prepare in bad_cases:
            with self.subTest(controls=label):
                (self.root / 'controls.json').write_bytes(good_raw)
                result = self.exercise_bound_quality_launch(controls_sha=prepare())
                self.assertIsNotNone(result['error'])
                self.assertNotIn('fixture stop after native call', str(result['error']))
                self.assertFalse(result['output'].exists(), 'controls must be checked before output creation')
                for event in ('native.jsonl', 'reserved.txt', 'wrapper.json'):
                    self.assertNotIn(event, result['events'])
                self.assertEqual(result['native_calls'], [])
        (self.root / 'controls.json').write_bytes(good_raw)
        result = self.exercise_bound_quality_launch(controls_sha=good)
        self.assertIn('fixture stop after native call', str(result['error']))
        events = result['events']
        self.assertIn('model-launch-before-reservation:True', events)
        self.assertLess(events.index('native.jsonl'), events.index('reserved.txt'))
        self.assertLess(events.index('reserved.txt'), events.index('wrapper.json'))
        self.assertEqual(len(result['native_calls']), 1)
        command = result['native_calls'][0]
        self.assertEqual(command[command.index('--model') + 1], 'sonnet')
        self.assertEqual(command[command.index('--effort') + 1], 'medium')
        self.assertEqual(json.loads(command[command.index('--agents') + 1])['sdd-evaluator']['model'], 'sonnet')
        self.assertEqual(command[command.index('--permission-mode') + 1], 'dontAsk')
        output = result['output']
        launch_sha = sha_file(output / 'model-launch.json')
        record = json.loads((output / 'model-launch.json').read_bytes())
        self.assertEqual(record['argv'], command)
        dependencies = json.loads((output / 'dependencies.json').read_bytes())
        for pin in [record['controls'], *record['pins'], *record['trusted']]:
            with self.subTest(dependency=pin['path']):
                self.assertEqual(dependencies[str(self.root / pin['path'])], pin['sha256'])
        self.assertEqual((record['role'], record['transport_role']), ('evaluator', 'sdd-evaluator'))
        with self.model_env(self.active_env), self.in_root():
            binding = self.transport.model_launch_binding(self.root, result['data'], Path('controls.json'), good)
            self.transport.verify_model_launch(self.root, output, launch_sha, binding, command)
        # Existing default: no model binding keeps the legacy Sonnet argv without --effort.
        shutil.rmtree(output)
        self.active_env = {}
        legacy = self.exercise_bound_quality_launch(legacy=True)
        self.assertEqual(len(legacy['native_calls']), 1)
        self.assertEqual(legacy['native_calls'][0][legacy['native_calls'][0].index('--model') + 1], 'sonnet')
        self.assertNotIn('--effort', legacy['native_calls'][0])
        self.assertFalse((legacy['output'] / 'model-launch.json').exists())


    def test_selected_quality_initial_output_ancestor_alias_has_no_side_effects(self):
        self.active_env = {'SDD_MODEL_EVALUATOR': 'anthropic/sonnet'}
        self.run_id = self.session_id
        self.request = self.fresh_request('evaluator', 'medium')
        self.select('evaluator', risk='medium', env=self.active_env)
        good = self.controls()
        self.accepted(self.cli(sha=good, env=self.active_env))
        positive = self.exercise_bound_quality_launch(controls_sha=good, complete=True)
        self.assertIsNone(positive['error'], 'genuine selected controller positive')
        self.assertEqual(len(positive['native_calls']), 1)
        self.assertTrue((positive['output'] / 'model-delivery-binding.json').is_file())
        shutil.rmtree(positive['output'])
        parent = positive['output'].parent
        original = self.root / 'original-quality-output-parent'
        parent.rename(original)
        outside = self.root / 'quality-output-target'
        outside.mkdir()
        parent.symlink_to(outside, target_is_directory=True)
        result = self.exercise_bound_quality_launch(controls_sha=good, complete=True)
        self.assertEqual(list(outside.iterdir()), [], 'selected quality launch created redirected artifacts')
        self.assertIsNotNone(result['error'])
        for event in ('native.jsonl', 'reserved.txt', 'wrapper.json'):
            self.assertNotIn(event, result['events'])
        self.assertEqual(result['native_calls'], [])
        self.assertFalse((original / positive['output'].name).exists())


class ModelRunRecords(unittest.TestCase):
    """Both shell emitters consume pinned execution records; fixtures claim no native run."""
    launch: dict[str, Any]
    delivery_binding: dict[str, Any]
    selection: dict[str, Any]
    events: dict[str, Any]
    delivery: dict[str, Any]
    context: dict[str, Any]

    def setUp(self):
        self.fixture = PairedClaudeLaunch(methodName='runTest')
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        for name in ('emit-run-record.sh', 'emit-run-record.ps1'):
            relative = 'plugins/sdd-quality-loop/scripts/' + name
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        (self.root / 'specs/example/tasks.md').write_text('## T-001 Fixture\nStatus: In Progress\n')
        self.output = self.root / 'reports/model-fixture'
        self.output.mkdir(parents=True)

    def records(self, role='spec-reviewer-a', *, fixed=False):
        f = self.fixture
        definition = (self.root / 'plugins/sdd-quality-loop/agents/evaluator.md' if role == 'evaluator' else
                      self.root / 'plugins/sdd-review-loop/agents' / (role + '.md'))
        definition.parent.mkdir(parents=True, exist_ok=True)
        definition.write_text('---\nmodel: opus\neffort: high\n---\nFixture review only.\n')
        f.run_id = f.session_id  # Protected adapter keeps its canonical alias rule.
        binding, _ = f.bind(role)
        command = self.execution_fixture(role, binding, definition, fixed=fixed)
        with f.model_env(f.active_env), f.in_root():
            self.launch_sha = f.transport.record_model_launch(self.output, binding, command, 'matching')
        self.launch = json.loads((self.output / 'model-launch.json').read_bytes())
        self.selection = binding['selection']
        self.events = {'host': self.selection['host'], 'cli_version': self.selection['cli_version'],
                       'selection_sha256': self.selection['selection_sha256'], 'run_id': f.run_id,
                       'session_id': f.session_id, 'thread_id': 'local-fixture-correlation',
                       'turn_id': 'local-fixture-delivery', 'thread_read': None, 'turn_start': None,
                       'notifications': []}
        self.delivery = f.helper().verify_delivery(self.selection, self.events, require_actual_id=False)
        refs = {}
        for key, value in [('selection', self.selection), ('events', self.events), ('delivery', self.delivery)]:
            path = 'reports/model-fixture/model-' + key + '.json'
            f.write(path, value)
            refs[key] = f.ref(path)
        self.delivery_binding = {'schema': 'model-delivery-binding/v1', 'launch_sha256': self.launch_sha,
                                 'transport': 'claude-print', **refs,
                                 'execution_context': f.ref('reports/model-fixture/model-execution-context.json'),
                                 'run_id': f.run_id,
                                 'session_id': f.session_id, 'attempt': 1,
                                 'selection_sha256': self.selection['selection_sha256']}
        self.delivery_sha = f.write('reports/model-fixture/model-delivery-binding.json', self.delivery_binding)

    def execution_fixture(self, role, binding, definition, *, fixed=False):
        """Real existing manifest/receipt/guard/argv code; only native help is a local fixture."""
        f = self.fixture
        transport = f.transport
        data = f.invocation_data(role)
        data.update(schema='review-context-invocation/v2', read_only=True, input_mode='file-manifest',
                    fallback_mode='none', sequence=1, previous_record_sha256='-',
                    identity_ledger_path='reports/review-context/identity-ledger.json')
        if data['stage'] == 'quality':
            data.update(task_id='T-001', scratch_root=str(self.root / 'fixture-scratch'))
        f.write(data['identity_ledger_path'], {'schema': 'review-identity-ledger/v1', 'records': []})
        data['identity_ledger_sha256'] = f.ref(data['identity_ledger_path'])['sha256']
        f.invocation.write_bytes(canonical(data))
        for relative in (transport.BOUNDARY_PATH, TRANSPORT_SCRIPT.relative_to(ROOT).as_posix(),
                         'plugins/sdd-review-loop/scripts/fixed-review-inputs.py'):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        inputs_hash = sha_bytes('\n'.join(entry['path'] + '\t' + entry['sha256']
                                          for entry in data['allowed_input_manifest']).encode())
        record_text = '|'.join(['1', data['stage'], data['role'], f.run_id, f.session_id, '-'])
        if data['stage'] == 'quality':
            record_text += '|scratch-declaration-v1|' + sha_bytes(
                (data['feature'] + '\n' + data['scratch_root']).encode())
        if transport.inputs_bound(data):
            record_text += '|allowed-inputs-v1|' + inputs_hash
        f.receipt.write_text('REVIEW_CONTEXT_OK ' + sha_bytes(record_text.encode()) +
                             ' sequence=1 previous_record_sha256=- pre_append_tip_sequence=0 identity_unique=yes\n')
        fixed_data: dict[str, Any] | None = None
        if fixed:
            snapshot = self.root / 'fixed-fixture-snapshot'
            inventory: dict[str, Any] = {'commit': '0' * 40, 'inputs': [
                {**entry, 'mode': '100644'} for entry in data['allowed_input_manifest']]}
            for entry in inventory['inputs']:
                target = snapshot / entry['path']
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(self.root / entry['path'], target)
                target.chmod(0o444)
            inventory_path = 'reports/model-fixture/model-fixed-inputs.json'
            f.write(inventory_path, inventory)
            fixed_data = {'record': str(self.root / inventory_path), 'snapshot': str(snapshot),
                          'inventory': inventory,
                          'state_reference': {'fixture': 'synthetic fixed-rendering context; no Git attestation'}}
            transport.record_fixed_execution(self.output, f.invocation, data, fixed_data)
        policy, settings = transport.launch_policy(self.root, f.invocation, f.receipt, f.launch_policy_file,
                                                   fixed_inputs=fixed_data)
        f.launch_policy_file.write_bytes(policy)
        f.settings.write_bytes(canonical(settings))
        permissions = transport.receipt_control(data, f.receipt.read_text(),
            f.invocation.relative_to(self.root).as_posix(), root=None if fixed else self.root)['exact_permission_rules']
        if fixed:
            permissions = ['Read']
        generated: dict[str, Any] = {'description': 'Repository-bound independent implementation reviewer',
                     'prompt': definition.read_text().split('---', 2)[2].strip(),
                     'model': binding['native_model'], 'effort': binding['effort'],
                     'tools': transport.agent_tools(data['stage']), 'disallowedTools': list(DISALLOWED)}
        if fixed:
            generated['prompt'] += ('\nFixed-input route: the launcher verifies input identity. '
                                    'Do not run hash-only commands or Bash. Read the exact supplied '
                                    'snapshot paths; retain all substantive review checks.')
        executable = self.root / 'fixture-bin/claude'
        executable.parent.mkdir(exist_ok=True)
        executable.write_text('# fixture command identity; never executed\n')
        executable.chmod(0o700)
        real_run, real_which = subprocess.run, shutil.which
        def run(args: list[str], *positional: Any, **kwargs: Any):
            if '--help' in args:
                return subprocess.CompletedProcess(args, 0, HELP_TEXT, '')
            return real_run(args, *positional, **kwargs)
        with f.model_env(f.active_env), f.in_root(), \
                mock.patch.object(transport.shutil, 'which', side_effect=lambda name:
                                  str(executable) if name == 'claude' else real_which(name)), \
                mock.patch.object(transport.subprocess, 'run', side_effect=run), \
                mock.patch.object(transport, 'fixed_input_binding', return_value=fixed_data):
            command = transport.claude_command(self.root, f.session_id, data['role'], generated, permissions,
                        f.settings, f.invocation, f.receipt, f.launch_policy_file,
                        fixed_inputs=fixed_data, model_binding=binding, environment=dict(os.environ))
        dependencies = {str(self.root / ref['path']): ref['sha256'] for ref in
                        [binding['controls'], *binding['pins'], *binding['trusted']]}
        for target in (f.invocation, definition, executable, self.root / transport.BOUNDARY_PATH,
                       self.root / TRANSPORT_SCRIPT.relative_to(ROOT),
                       self.root / 'plugins/sdd-review-loop/scripts/fixed-review-inputs.py',
                       self.root / data['allowed_input_manifest'][0]['path']):
            dependencies[str(target)] = sha_bytes(target.read_bytes())
        if fixed_data is not None:
            for entry in fixed_data['inventory']['inputs']:
                dependencies[str(Path(fixed_data['snapshot']) / entry['path'])] = entry['sha256']
        f.write('reports/model-fixture/dependencies.json', dependencies)
        self.context = {'schema': 'model-execution-context/v1', 'transport': 'claude-print',
                        'stage': data['stage'], 'role': data['role'], 'run_id': f.run_id,
                        'session_id': f.session_id, 'attempt': 1,
                        'invocation': f.ref(f.invocation.relative_to(self.root).as_posix()),
                        'dependencies': f.ref('reports/model-fixture/dependencies.json'),
                        'role_definition': f.ref(definition.relative_to(self.root).as_posix()),
                        'policy': f.ref(f.launch_policy_file.relative_to(self.root).as_posix()),
                        'settings': f.ref(f.settings.relative_to(self.root).as_posix()),
                        'receipt': f.ref(f.receipt.relative_to(self.root).as_posix()),
                        'fixed_inputs': None, 'policy_environment': dict(f.active_env),
                        'native_overrides': binding['native_overrides'],
                        'executable': {'path': str(executable), 'resolved_path': str(executable),
                                       'sha256': sha_bytes(executable.read_bytes())}}
        if fixed_data is not None:
            self.context['fixed_inputs'] = {
                'inventory': f.ref('reports/model-fixture/model-fixed-inputs.json'),
                'execution': f.ref('reports/model-fixture/fixed-execution.json'),
                'snapshot': fixed_data['snapshot']}
        f.write('reports/model-fixture/model-execution-context.json', self.context)
        return command

    def emit(self, shell, slot='reviewers', extra=(), *, selected=True, launch_sha=None, delivery_sha=None,
             feature='example'):
        shutil.rmtree(self.root / 'reports/runs', ignore_errors=True)
        script = self.root / 'plugins/sdd-quality-loop/scripts' / ('emit-run-record.' +
                                                                 ('sh' if shell == 'bash' else 'ps1'))
        if shell == 'bash':
            command = [BASH, str(script), feature]
            names = ['--model-launch', '--model-launch-sha256', '--model-delivery-binding',
                     '--model-delivery-binding-sha256', '--model-slot']
        else:
            command = [os.environ.get('SDD_TEST_PWSH', 'pwsh'), '-NoProfile', '-File', str(script),
                       '-Feature', feature]
            names = ['-ModelLaunch', '-ModelLaunchSha256', '-ModelDeliveryBinding',
                     '-ModelDeliveryBindingSha256', '-ModelSlot']
        if selected:
            values = ['reports/model-fixture/model-launch.json', launch_sha or self.launch_sha,
                      'reports/model-fixture/model-delivery-binding.json', delivery_sha or self.delivery_sha, slot]
            command += list(itertools.chain.from_iterable(zip(names, values)))
        command += list(extra)
        return self.fixture.run_process(command, timeout=60, label='selected run record ' + shell)

    def accepted_record(self, shell, slot='reviewers'):
        result = self.emit(shell, slot)
        self.assertEqual(result.returncode, 0, result.stderr[:1600])
        paths = list((self.root / 'reports/runs').glob('RUN-*.json'))
        self.assertEqual(len(paths), 1)
        # Issue #619: json.loads(bytes) silently strips a UTF-8 BOM, so check raw bytes
        # and keep the validator's multiline stdout with one native newline per line.
        raw = paths[0].read_bytes()
        self.assertFalse(raw.startswith(b'\xef\xbb\xbf'), shell + ' emitter wrote a UTF-8 BOM')
        text = raw.decode('utf-8')
        record = json.loads(text)
        self.assertEqual(text, json.dumps(record, ensure_ascii=False, indent=2).replace('\n', os.linesep) + os.linesep,
                         shell + ' emitter changed the validator line framing')
        node = shutil.which('node')
        if node:  # Node's JSON.parse also rejects a leading BOM when reading the published bytes.
            parsed = subprocess.run([node, '-e', 'process.stdout.write(JSON.stringify(JSON.parse('
                                     'require("fs").readFileSync(process.argv[1], "utf8"))))', str(paths[0])],
                                    capture_output=True, timeout=60, check=False)
            self.assertEqual(parsed.returncode, 0, shell + ' record rejected by Node: ' + parsed.stderr.decode()[-400:])
            self.assertEqual(json.loads(parsed.stdout.decode('utf-8')), record)
        return record

    def reject_record(self, shell, **options):
        result = self.emit(shell, **options)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(list((self.root / 'reports/runs').glob('RUN-*.json')),
                         'rejected model evidence must not publish a run record')


    def test_protected_output_scope_copied_context_cannot_outlive_owner(self):
        import errno
        transport = self.fixture.transport
        first = self.root / 'reports/scope-first'
        second = self.root / 'reports/scope-second'
        with transport.protected_output_scope(first):
            transport.create_launch_output(first)
            retained = contextvars.copy_context()
            retained.run(transport.check_launch_output)
            state = transport._PROTECTED_OUTPUT.get()
            self.assertIsNotNone(state)
            original_fd = state[first]
        # An independent live scope remains valid after the first owner's cleanup.
        with transport.protected_output_scope(second):
            transport.create_launch_output(second)
            transport.check_launch_output()
            transport.write_launch_bytes(second / 'positive.json', b'{}')
        self.assertEqual((second / 'positive.json').read_bytes(), b'{}')
        with self.assertRaises(OSError) as closed:
            os.fstat(original_fd)
        self.assertEqual(closed.exception.errno, errno.EBADF)
        reopened_fd = os.open(first, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_NONBLOCK)
        owned = {reopened_fd}
        try:
            if reopened_fd != original_fd:
                # Never dup2 over a live unrelated descriptor, including one opened by this fixture.
                with self.assertRaises(OSError) as still_closed:
                    os.fstat(original_fd)
                self.assertEqual(still_closed.exception.errno, errno.EBADF)
                os.dup2(reopened_fd, original_fd)
                owned.add(original_fd)
            self.assertEqual(os.fstat(original_fd).st_ino, first.stat().st_ino)
            caught = None
            try:
                retained.run(transport.write_launch_bytes, first / 'stale.json', b'{}')
            except ValueError as error:
                caught = error
            self.assertFalse((first / 'stale.json').exists(), 'closed scope revived write authority via fd reuse')
            self.assertIsNotNone(caught, 'copied closed scope must reject even when its fd and inode match')
        finally:
            for descriptor in owned:
                os.close(descriptor)

    def test_protected_model_writers_reject_initial_output_ancestor_alias(self):
        for fixed, writer in itertools.product((False, True), ('launch', 'execution', 'delivery')):
            with self.subTest(fixed=fixed, writer=writer):
                case = ModelRunRecords(methodName='runTest')
                case.setUp()
                try:
                    case.records(fixed=fixed)
                    f, transport = case.fixture, case.fixture.transport
                    binding = {key: case.launch[key] for key in transport.BINDING_FIELDS if key != 'selection'}
                    binding.update(schema='model-launch-validation/v1', selection=case.selection)
                    context_sha = sha_file(case.output / 'model-execution-context.json')
                    fixed_data = None
                    if fixed:
                        inventory = json.loads((case.output / 'model-fixed-inputs.json').read_bytes())
                        inventory_source = case.root / 'original-fixed-inventory.json'
                        inventory_source.write_bytes(canonical(inventory))
                        fixed_data = {'record': str(inventory_source), 'inventory': inventory,
                                      'snapshot': case.context['fixed_inputs']['snapshot']}
                    names = {'launch': ('model-launch.json',),
                             'execution': ('model-execution-context.json',) +
                                          (('model-fixed-inputs.json',) if fixed else ()),
                             'delivery': tuple('model-' + name + '.json' for name in
                                               ('selection', 'events', 'delivery', 'delivery-binding'))}[writer]
                    def clear() -> None:
                        for name in names:
                            (case.output / name).unlink()
                    def produce() -> str:
                        if writer == 'launch':
                            return transport.record_model_launch(case.output, binding, case.launch['argv'], 'matching')
                        if writer == 'execution':
                            return transport.record_model_execution(case.root, case.output,
                                json.loads(f.invocation.read_bytes()), f.invocation,
                                case.root / case.context['role_definition']['path'], f.launch_policy_file,
                                f.settings, f.receipt, binding, case.launch['argv'], dict(f.active_env), fixed_data)
                        return transport.record_model_delivery(case.root, case.output, binding,
                                                               case.launch_sha, context_sha)
                    clear()
                    with f.model_env(f.active_env), f.in_root():
                        digest = produce()
                    final_name = {'launch': 'model-launch.json', 'execution': 'model-execution-context.json',
                                  'delivery': 'model-delivery-binding.json'}[writer]
                    self.assertEqual(digest, sha_file(case.output / final_name), 'genuine producer positive')
                    clear()
                    original = case.root / 'original-output'
                    case.output.rename(original)
                    outside = case.root / 'alias-target'
                    outside.mkdir()
                    case.output.symlink_to(outside, target_is_directory=True)
                    caught = None
                    with f.model_env(f.active_env), f.in_root():
                        try:
                            produce()
                        except ValueError as error:
                            caught = error
                    self.assertEqual(list(outside.iterdir()), [], 'protected producer wrote through output alias')
                    self.assertIsNotNone(caught, 'selected protected output alias must reject')
                    if writer == 'delivery':
                        self.assertFalse((original / 'model-delivery-binding.json').exists())
                finally:
                    case.doCleanups()

    def test_protected_delivery_rejects_ancestor_swap_before_first_artifact(self):
        for fixed in (False, True):
            with self.subTest(fixed=fixed):
                case = ModelRunRecords(methodName='runTest')
                case.setUp()
                try:
                    case.records(fixed=fixed)
                    transport = case.fixture.transport
                    binding = {key: case.launch[key] for key in transport.BINDING_FIELDS if key != 'selection'}
                    binding.update(schema='model-launch-validation/v1', selection=case.selection)
                    context_sha = sha_file(case.output / 'model-execution-context.json')
                    for name in ('selection', 'events', 'delivery', 'delivery-binding'):
                        (case.output / ('model-' + name + '.json')).unlink()
                    # records() provides the genuine launch/context; prove the actual postproducer first.
                    digest = transport.record_model_delivery(case.root, case.output, binding,
                                                              case.launch_sha, context_sha)
                    self.assertEqual(digest, sha_file(case.output / 'model-delivery-binding.json'))
                    for name in ('selection', 'events', 'delivery', 'delivery-binding'):
                        (case.output / ('model-' + name + '.json')).unlink()
                    original = case.root / 'original-output'
                    outside = case.root / 'swap-target'
                    outside.mkdir()
                    real_write = transport.write_model_record
                    swapped = False
                    def swap_then_write(*args: Any, **kwargs: Any) -> str:
                        nonlocal swapped
                        if not swapped:
                            case.output.rename(original)
                            case.output.symlink_to(outside, target_is_directory=True)
                            swapped = True
                        return real_write(*args, **kwargs)
                    caught = None
                    with mock.patch.object(transport, 'write_model_record', side_effect=swap_then_write):
                        try:
                            transport.record_model_delivery(case.root, case.output, binding,
                                                            case.launch_sha, context_sha)
                        except ValueError as error:
                            caught = error
                    self.assertTrue(swapped, 'mutation reached the real producer write boundary')
                    self.assertEqual(list(outside.iterdir()), [], 'swapped ancestor received model artifacts')
                    self.assertIsNotNone(caught)
                    self.assertFalse((original / 'model-delivery-binding.json').exists())
                finally:
                    case.doCleanups()

    def test_protected_delivery_rejects_ancestor_swap_before_binding_publication(self):
        for fixed in (False, True):
            with self.subTest(fixed=fixed):
                case = ModelRunRecords(methodName='runTest')
                case.setUp()
                try:
                    case.records(fixed=fixed)
                    transport = case.fixture.transport
                    binding = {key: case.launch[key] for key in transport.BINDING_FIELDS if key != 'selection'}
                    binding.update(schema='model-launch-validation/v1', selection=case.selection)
                    context_sha = sha_file(case.output / 'model-execution-context.json')
                    def clear() -> None:
                        for name in ('selection', 'events', 'delivery', 'delivery-binding'):
                            (case.output / ('model-' + name + '.json')).unlink()
                    clear()
                    digest = transport.record_model_delivery(case.root, case.output, binding,
                                                              case.launch_sha, context_sha)
                    self.assertEqual(digest, sha_file(case.output / 'model-delivery-binding.json'))
                    clear()
                    original = case.root / 'original-output'
                    outside = case.root / 'publication-target'
                    outside.mkdir()
                    real_verify = transport.verify_captured_model_run
                    verified = []
                    def verify_then_swap(*args: Any, **kwargs: Any) -> dict[str, Any]:
                        result = real_verify(*args, **kwargs)
                        verified.append(True)
                        case.output.rename(original)
                        case.output.symlink_to(outside, target_is_directory=True)
                        return result
                    caught = None
                    with mock.patch.object(transport, 'verify_captured_model_run', side_effect=verify_then_swap):
                        try:
                            transport.record_model_delivery(case.root, case.output, binding,
                                                            case.launch_sha, context_sha)
                        except ValueError as error:
                            caught = error
                    self.assertEqual(verified, [True], 'genuine verification completed before the swap')
                    self.assertEqual(list(outside.iterdir()), [], 'accepted binding escaped to swapped ancestor')
                    self.assertIsNotNone(caught)
                    self.assertFalse((original / 'model-delivery-binding.json').exists())
                finally:
                    case.doCleanups()

    def test_protected_producer_rejects_changed_context_before_binding_publication(self):
        for fixed in (False,True):
            with self.subTest(fixed=fixed):
                case = ModelRunRecords(methodName='runTest')
                case.setUp()
                try:
                    case.records(fixed=fixed)
                    transport = case.fixture.transport
                    binding = {key:case.launch[key] for key in transport.BINDING_FIELDS if key!='selection'}
                    binding.update(schema='model-launch-validation/v1',selection=case.selection)
                    def clear_postrecords():
                        for name in ('selection','events','delivery','delivery-binding'):
                            (case.output/('model-'+name+'.json')).unlink()
                    def produce():
                        return transport.record_model_delivery(case.root,case.output,binding,case.launch_sha,
                            sha_file(case.output/'model-execution-context.json'))
                    clear_postrecords()
                    digest = produce()
                    self.assertEqual(digest,sha_file(case.output/'model-delivery-binding.json'))
                    clear_postrecords()
                    settings = case.root/case.context['settings']['path']
                    settings.write_bytes(settings.read_bytes()+b' ')
                    with self.assertRaises(ValueError):
                        produce()
                    self.assertFalse((case.output/'model-delivery-binding.json').exists(),
                                     'Rejected protected context left an accepted delivery binding')
                finally:
                    case.doCleanups()

    def test_run_record_feature_matches_original_execution_context(self):
        self.records()
        self.fixture.write('specs/other-feature/placeholder.json', {})
        (self.root / 'specs/other-feature/tasks.md').write_text('## T-001 Other fixture\nStatus: In Progress\n')
        for shell in ('bash', 'powershell'):
            self.accepted_record(shell)
            self.reject_record(shell, feature='other-feature')

    def test_fixed_selected_context_rebuilds_readonly_paths_and_rejects_resealed_fixed_fields(self):
        # Inventory/state are explicit synthetic rendering fixtures, not Git/admission proof.
        self.records(fixed=True)
        f = self.fixture
        self.assertNotIn('--plugin-dir', self.launch['argv'])
        policy = json.loads((self.root / self.context['policy']['path']).read_bytes())
        self.assertEqual(policy['bash_commands'], [])
        self.assertTrue(any('fixed-fixture-snapshot' in path for path in policy['read_paths']))
        for shell in ('bash', 'powershell'):
            self.accepted_record(shell)
        original = copy.deepcopy(self.context)
        binding = copy.deepcopy(self.delivery_binding)
        for path in leaf_paths(original['fixed_inputs']):
            with self.subTest(fixed_leaf='/'.join(map(str, path))):
                changed = copy.deepcopy(original)
                set_path(changed['fixed_inputs'], path, altered(get_path(original['fixed_inputs'], path)))
                f.write('reports/model-fixture/model-execution-context.json', changed)
                changed_binding = copy.deepcopy(binding)
                changed_binding['execution_context'] = f.ref('reports/model-fixture/model-execution-context.json')
                digest = f.write('reports/model-fixture/model-delivery-binding.json', changed_binding)
                self.reject_record('bash', delivery_sha=digest)
        f.write('reports/model-fixture/model-execution-context.json', original)
        f.write('reports/model-fixture/model-delivery-binding.json', binding)

    def test_protected_selected_entry_retains_canonical_run_session_alias(self):
        self.records()
        f = self.fixture
        data, _ = f.transport.manifest(self.root, f.invocation)
        self.assertEqual(data['run_id'], data['host_session_id'])
        launcher = load_module(LAUNCHER_SCRIPT, 'record_selected_entry')
        self.addCleanup(sys.modules.pop, launcher.__name__, None)
        data['run_id'] = 'distinct-valid-generic-run'
        f.invocation.write_bytes(canonical(data))
        with mock.patch.object(launcher, 'run') as native, \
                mock.patch.object(launcher.transport, 'model_launch_binding') as gate:
            with self.assertRaisesRegex(ValueError, 'alias run_id'):
                launcher.launch(self.root, f.invocation, self.root / 'reports/rejected-selected-entry',
                    model_binding={'controls': Path('controls.json'),
                                   'controls_sha256': f.ref('controls.json')['sha256']})
        native.assert_not_called()
        gate.assert_not_called()
        self.assertFalse((self.root / 'reports/rejected-selected-entry').exists())

    def test_retrospective_context_every_field_and_launch_argv_are_independently_rebuilt(self):
        self.records()
        self.accepted_record('bash')
        f = self.fixture
        original_context = copy.deepcopy(self.context)
        original_binding = copy.deepcopy(self.delivery_binding)
        for path in leaf_paths(original_context):
            with self.subTest(context_leaf='/'.join(map(str, path))):
                changed_context = copy.deepcopy(original_context)
                set_path(changed_context, path, altered(get_path(original_context, path)))
                f.write('reports/model-fixture/model-execution-context.json', changed_context)
                changed_binding = copy.deepcopy(original_binding)
                changed_binding['execution_context'] = f.ref('reports/model-fixture/model-execution-context.json')
                digest = f.write('reports/model-fixture/model-delivery-binding.json', changed_binding)
                self.reject_record('bash', delivery_sha=digest)
        f.write('reports/model-fixture/model-execution-context.json', original_context)
        f.write('reports/model-fixture/model-delivery-binding.json', original_binding)
        original_launch = copy.deepcopy(self.launch)
        for path in leaf_paths(original_launch):
            with self.subTest(launch_leaf='/'.join(map(str, path))):
                changed_launch = copy.deepcopy(original_launch)
                set_path(changed_launch, path, altered(get_path(original_launch, path)))
                if path != ('argv_sha256',):
                    changed_launch['argv_sha256'] = sha_bytes(canonical(changed_launch['argv']))
                digest = f.write('reports/model-fixture/model-launch.json', changed_launch)
                changed_binding = copy.deepcopy(original_binding)
                changed_binding['launch_sha256'] = digest
                delivery_digest = f.write('reports/model-fixture/model-delivery-binding.json', changed_binding)
                self.reject_record('bash', launch_sha=digest, delivery_sha=delivery_digest)
        f.write('reports/model-fixture/model-launch.json', original_launch)
        f.write('reports/model-fixture/model-delivery-binding.json', original_binding)

    def test_resealed_context_artifacts_cannot_authorize_changed_permissions_or_role(self):
        self.records()
        self.accepted_record('bash')
        f = self.fixture
        context = copy.deepcopy(self.context)
        binding = copy.deepcopy(self.delivery_binding)
        mutations: dict[str, Callable[[bytes], bytes]] = {
            'invocation': lambda raw: canonical({**json.loads(raw), 'read_only': False}),
            'role_definition': lambda raw: raw + b'\nAdditional unauthorized role prompt.\n',
            'policy': lambda raw: canonical({**json.loads(raw), 'bash_commands': ['arbitrary command']}),
            'settings': lambda raw: canonical({**json.loads(raw), 'permissions': {'allow': ['Bash']}}),
            'receipt': lambda raw: raw.replace(b'identity_unique=yes', b'identity_unique=no'),
            'dependencies': lambda raw: canonical({**json.loads(raw), str(f.invocation): '0' * 64}),
        }
        for name, mutate in mutations.items():
            with self.subTest(resealed_artifact=name):
                target = self.root / context[name]['path']
                original = target.read_bytes()
                target.write_bytes(mutate(original))
                changed_context = copy.deepcopy(context)
                changed_context[name] = f.ref(context[name]['path'])
                f.write('reports/model-fixture/model-execution-context.json', changed_context)
                changed_binding = copy.deepcopy(binding)
                changed_binding['execution_context'] = f.ref('reports/model-fixture/model-execution-context.json')
                digest = f.write('reports/model-fixture/model-delivery-binding.json', changed_binding)
                try:
                    self.reject_record('bash', delivery_sha=digest)
                finally:
                    target.write_bytes(original)
        f.write('reports/model-fixture/model-execution-context.json', context)
        f.write('reports/model-fixture/model-delivery-binding.json', binding)

    def test_retrospective_consumption_never_renews_live_capture_or_model_eligibility(self):
        self.records()
        expected = self.accepted_record('bash')['model_policy']
        transport = self.fixture.transport
        with mock.patch.object(transport, 'model_launch_binding',
                               side_effect=AssertionError('postflight eligibility renewal')) as gate, \
                mock.patch.object(transport, 'fresh_model_binding',
                                  side_effect=AssertionError('postflight capture renewal')) as fresh, \
                mock.patch.object(transport.subprocess, 'run',
                                  side_effect=AssertionError('postflight native process')) as process:
            result = transport.verify_model_run(self.root, 'reports/model-fixture/model-launch.json',
                self.launch_sha, 'reports/model-fixture/model-delivery-binding.json',
                self.delivery_sha, 'reviewers')
        self.assertEqual(result, expected)
        gate.assert_not_called()
        fresh.assert_not_called()
        process.assert_not_called()

    def test_both_shells_bind_role_specific_configured_identity_and_checked_effort(self):
        for role, slot in [('spec-reviewer-a', 'reviewers'), ('evaluator', 'main')]:
            if (self.output / 'model-launch.json').exists():
                (self.output / 'model-launch.json').unlink()
            self.records(role)
            for shell in ('bash', 'powershell'):
                with self.subTest(role=role, shell=shell):
                    record = self.accepted_record(shell, slot)
                    expected = {'actor_slot': slot, 'transport': 'claude-print',
                                'launch_sha256': self.launch_sha, 'delivery_binding_sha256': self.delivery_sha,
                                'selection': self.selection, 'delivery': self.delivery,
                                'events_sha256': self.delivery_binding['events']['sha256']}
                    self.assertEqual(record['schema'], 'sdd-run-record/v2')
                    self.assertEqual(record['model_policy'], expected)
                    self.assertEqual(record['run_id'], self.selection['binding']['run_id'])
                    self.assertEqual(record['model_ids'][slot], self.selection['resolved']['native_id'])
                    self.assertEqual(record['model_ids']['main' if slot == 'reviewers' else 'reviewers'], 'unknown')
                    self.assertEqual(record['effort'][slot], {'effort_requested': 'high',
                                                            'effort_applied': 'high',
                                                            'effort_degraded_reason': None})
                    self.assertIsNone(record['model_policy']['delivery']['actual_id'])

    def test_both_shells_validate_every_delivery_binding_leaf_and_raw_link_before_emission(self):
        self.records()
        original = canonical(self.delivery_binding)
        for shell in ('bash', 'powershell'):
            self.accepted_record(shell)
            for path in leaf_paths(self.delivery_binding):
                with self.subTest(shell=shell, binding_leaf='/'.join(map(str, path))):
                    changed = copy.deepcopy(self.delivery_binding)
                    set_path(changed, path, altered(get_path(changed, path)))
                    raw = canonical(changed)
                    (self.output / 'model-delivery-binding.json').write_bytes(raw)
                    self.reject_record(shell, delivery_sha=sha_bytes(raw))
            (self.output / 'model-delivery-binding.json').write_bytes(original)
            for name in ('selection', 'events', 'delivery'):
                with self.subTest(shell=shell, changed_raw=name):
                    target = self.root / self.delivery_binding[name]['path']
                    raw = target.read_bytes()
                    target.write_bytes(raw + b' ')
                    try:
                        self.reject_record(shell)
                    finally:
                        target.write_bytes(raw)
            self.reject_record(shell, launch_sha='0' * 64)
            self.reject_record(shell, delivery_sha='0' * 64)

    def test_both_shells_reject_slot_metadata_and_blocked_delivery_conflicts(self):
        self.records()
        for shell in ('bash', 'powershell'):
            self.accepted_record(shell)
            self.reject_record(shell, slot='main')
            names = (['--model-reviewers', '--effort-reviewers', '--effort-control-reviewers',
                      '--effort-applied-reviewers'] if shell == 'bash' else
                     ['-ModelReviewers', '-EffortReviewers', '-EffortControlReviewers',
                      '-EffortAppliedReviewers'])
            for name, value in zip(names, ['sonnet', 'medium', 'none', 'medium']):
                with self.subTest(shell=shell, conflicting_metadata=name):
                    self.reject_record(shell, extra=(name, value))
            changed = copy.deepcopy(self.delivery)
            changed.update(status='blocked', reason='actual-id-unavailable')
            delivery_path = self.root / self.delivery_binding['delivery']['path']
            original = delivery_path.read_bytes()
            delivery_path.write_bytes(canonical(changed))
            altered_binding = copy.deepcopy(self.delivery_binding)
            altered_binding['delivery']['sha256'] = sha_file(delivery_path)
            raw = canonical(altered_binding)
            (self.output / 'model-delivery-binding.json').write_bytes(raw)
            try:
                self.reject_record(shell, delivery_sha=sha_bytes(raw))
            finally:
                delivery_path.write_bytes(original)
                (self.output / 'model-delivery-binding.json').write_bytes(canonical(self.delivery_binding))

    def test_both_shells_reject_partial_flag_groups_and_unsafe_record_paths(self):
        self.records()
        for shell in ('bash', 'powershell'):
            self.accepted_record(shell)
            names = (['--model-launch', '--model-launch-sha256', '--model-delivery-binding',
                      '--model-delivery-binding-sha256', '--model-slot'] if shell == 'bash' else
                     ['-ModelLaunch', '-ModelLaunchSha256', '-ModelDeliveryBinding',
                      '-ModelDeliveryBindingSha256', '-ModelSlot'])
            values = ['reports/model-fixture/model-launch.json', self.launch_sha,
                      'reports/model-fixture/model-delivery-binding.json', self.delivery_sha, 'reviewers']
            for name, value in zip(names, values):
                with self.subTest(shell=shell, partial_group=name):
                    self.reject_record(shell, selected=False, extra=(name, value))
            for name in ('model-launch.json', 'model-delivery-binding.json'):
                with self.subTest(shell=shell, symlink=name):
                    target = self.output / name
                    raw = target.read_bytes()
                    outside = self.fixture.base / ('outside-' + name)
                    outside.write_bytes(raw)
                    target.unlink()
                    target.symlink_to(outside)
                    try:
                        self.reject_record(shell)
                    finally:
                        target.unlink()
                        target.write_bytes(raw)
            original = canonical(self.delivery_binding)
            for path in ('../outside-selection.json', '/outside-selection.json',
                         'reports//model-fixture/model-selection.json',
                         'reports/model-fixture/./model-selection.json'):
                with self.subTest(shell=shell, noncanonical_link=path):
                    changed = copy.deepcopy(self.delivery_binding)
                    changed['selection']['path'] = path
                    raw = canonical(changed)
                    (self.output / 'model-delivery-binding.json').write_bytes(raw)
                    self.reject_record(shell, delivery_sha=sha_bytes(raw))
            (self.output / 'model-delivery-binding.json').write_bytes(original)

    def test_protected_controller_publishes_generated_delivery_links_after_bound_execution(self):
        f = self.fixture
        f.run_id = f.session_id
        _, controls_sha = f.bind('evaluator', risk='medium', env={'SDD_MODEL_EVALUATOR': 'anthropic/sonnet'})
        result = f.exercise_bound_quality_launch(controls_sha=controls_sha, complete=True)
        self.assertIsNone(result['error'], str(result['error']))
        self.assertEqual(len(result['native_calls']), 1)
        output = result['output']
        self.assertTrue((output / 'model-delivery-binding.json').is_file(),
                        'successful selected controller must publish its delivery linkage')
        record = json.loads((output / 'model-delivery-binding.json').read_bytes())
        self.assertEqual(record['schema'], 'model-delivery-binding/v1')
        self.assertEqual(record['transport'], 'claude-print')
        self.assertEqual(record['launch_sha256'], sha_file(output / 'model-launch.json'))
        selection = json.loads((f.root / record['selection']['path']).read_bytes())
        events = json.loads((f.root / record['events']['path']).read_bytes())
        delivery = json.loads((f.root / record['delivery']['path']).read_bytes())
        for name in ('selection', 'events', 'delivery'):
            self.assertEqual(record[name]['sha256'], sha_file(f.root / record[name]['path']))
        self.assertEqual(record['selection_sha256'], selection['selection_sha256'])
        self.assertEqual(record['run_id'], selection['binding']['run_id'])
        self.assertEqual(record['session_id'], selection['binding']['session_id'])
        self.assertEqual(record['attempt'], selection['binding']['attempt'])
        f.helper().validate_delivery_record(delivery, selection=selection, events=events,
                                            require_actual_id=False)
        self.assertIsNone(delivery['actual_id'])
        summary = json.loads((output / 'delivery.json').read_bytes())
        self.assertEqual(summary['model_launch_sha256'], record['launch_sha256'])
        self.assertEqual(summary['model_delivery_binding_sha256'], sha_file(output / 'model-delivery-binding.json'))


class SelectedPanelistLaunch(LaunchFixture):
    """Real selectors/consent gates and both wrappers; native commands are recording stubs only."""
    TASK = 'T-007'
    FEATURE = 'panelist-fixture'
    KEY = 'fixture-sudo-key-not-a-real-secret'

    def fixture_policy(self):
        policy = copy.deepcopy(self.trusted_policy)
        # Synthetic transport evidence must not inherit uncopied live adoptions.
        for candidate in policy['models']:
            candidate['adoption'] = []
        model = next(m for m in policy['models'] if m['id'] == 'gpt-6-astra')
        evidence = canonical({'fixture_only': True, 'claim': 'transport fixture, no model adoption or inference'})
        (self.root / 'gpt-fixture-adoption.json').write_bytes(evidence)
        model['lifecycle'] = 'current'
        model['adoption'] = [{'role': role, 'path': 'gpt-fixture-adoption.json', 'sha256': sha_bytes(evidence)}
                             for role in ('panelist-gpt', 'panelist-gemini')]
        return policy

    def fresh_observation(self, observed_at=None):
        return {'schema': 'model-observation/v1', 'host': 'codex-cli', 'cli_version': 'codex-cli 0.159.2',
                'scope_id': 'fixture-panelist-client', 'scope_kind': 'client', 'purpose': 'diagnostic',
                'observed_at': observed_at or utc_now(), 'source': 'verified-configuration', 'status': 'complete',
                'models': [{'native_id': 'gpt-6-astra', 'efforts': EFFORTS[:], 'available': True}],
                'reason': 'Verified-configuration fixture only; no live access or actual backend proof.'}

    def setUp(self):
        super().setUp()
        self.request.update(role='panelist-gpt', host='codex-cli', requested_effort='high',
                            cli={'model_id': 'gpt-6-astra', 'policy': 'pinned'})
        scripts = 'plugins/sdd-quality-loop/scripts/'
        for name in ('run-panelist-gpt.sh', 'run-panelist-gpt.ps1', 'run-panelist-gemini.sh',
                     'run-panelist-gemini.ps1', 'prepare-panelist-input.sh', 'prepare-panelist-input.ps1',
                     'lib/panelist-common.sh', 'emit-run-record.sh', 'emit-run-record.ps1'):
            target = self.root / (scripts + name)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / (scripts + name), target)
        driver = self.root / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
        driver.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / driver.relative_to(self.root), driver)
        self.scripts = self.root / scripts
        self.audit = self.base / 'native-audit.json'
        self.consent_audit = self.base / 'consent-audit.txt'
        self.bundle = self.root / 'bundle.txt'
        self.tasks = self.root / ('specs/' + self.FEATURE + '/tasks.md')
        self.tasks.parent.mkdir(parents=True)
        self.task_consent(True)
        self.write('raw-input.txt', {'fixture': 'Sanitized implementation content, not instructions.'})
        self.environment.update(SDD_SUDO_KEY=self.KEY, SDD_SUDO_SKIP_SIG='0',
            SDD_EVIDENCE_KEY='fixture-evidence-key-not-a-real-secret',
            SDD_SUDO_KEY_FILE=str(self.base / 'sudo-key.txt'),
            SDD_TEST_CONSENT_AUDIT=str(self.consent_audit),
            SDD_TEST_NATIVE_AUDIT=str(self.audit), SDD_PANELIST_TIMEOUT='5')
        (self.base / 'sudo-key.txt').write_text(self.KEY)
        shims = self.base / 'shims'
        # Keep native model tools isolated while admitting the test's actual
        # PowerShell installation (it need not live under /usr/bin).
        pwsh = shutil.which('pwsh')
        if pwsh:
            (shims / 'pwsh').symlink_to(pwsh)
        self.environment['PATH'] = str(shims) + os.pathsep + '/usr/bin:/bin'
        self.environment['SDD_PANELIST_CODEX_CMD'] = str(shims / 'codex')
        self.install_native_stub(shims / 'codex')
        self.install_native_stub(shims / 'gemini')
        # Audit forwarding only; the original complete consent implementation still runs.
        for ext in ('sh', 'ps1'):
            public = self.scripts / ('prepare-panelist-input.' + ext)
            public.rename(self.scripts / ('prepare-panelist-input.real.' + ext))
        (self.scripts / 'prepare-panelist-input.sh').write_text(
            '#!/bin/sh\nprintf "sh\\n" >> "$SDD_TEST_CONSENT_AUDIT"\n'
            'exec bash "$(dirname -- "$0")/prepare-panelist-input.real.sh" "$@"\n')
        (self.scripts / 'prepare-panelist-input.ps1').write_text(
            '[System.IO.File]::AppendAllText($env:SDD_TEST_CONSENT_AUDIT, "ps`n")\n'
            '& "$PSScriptRoot/prepare-panelist-input.real.ps1" @args\nexit $LASTEXITCODE\n')
        selection, result = self.try_select()
        self.assertEqual(result.returncode, 0, result.stderr[:1200])
        self.assertIsNotNone(selection)
        self.selection = selection
        self.assertEqual((selection['host'], selection['role']), ('codex-cli', 'panelist-gpt'))
        self.assertEqual(selection['resolved']['native_id'], 'gpt-6-astra')
        self.assertEqual(selection['resolved']['effort'], 'high')
        self.write('selection.json', selection)
        self.controls_sha = self.controls(mutate=lambda d: d.update(host='codex-cli'))
        self.prepare_bundle()
        self.original_bundle = self.bundle.read_bytes()

    def install_native_stub(self, path):
        path.write_text('''#!/usr/bin/env python3
import json, os, pathlib, re, sys, time
args = sys.argv[1:]
if args == ['--version']:
 print('codex-cli 0.159.2'); raise SystemExit(0)
if '--help' in args:
 print('Usage: codex exec --model MODEL -c CONFIG --sandbox read-only --skip-git-repo-check -C DIR -')
 raise SystemExit(0)
text = sys.stdin.read()
def header(name):
 values = re.findall(r'^# ' + re.escape(name) + r': (.*)$', text, re.MULTILINE)
 return values[-1] if values else 'fixture-missing'
pathlib.Path(os.environ['SDD_TEST_NATIVE_AUDIT']).write_text(json.dumps({
 'argv': args, 'stdin': text, 'cwd': os.getcwd(),
 'key_presence': {k: k in os.environ for k in ('SDD_EVIDENCE_KEY','SDD_SUDO_KEY','SDD_SUDO_KEY_FILE')}}))
mode = os.environ.get('SDD_TEST_NATIVE_MODE', '')
if mode == 'fail': raise SystemExit(17)
if mode == 'timeout': time.sleep(3)
if mode == 'invalid': print('not a verdict'); raise SystemExit(0)
# Simulate an external concurrent source change; this stub is not a sandbox proof.
if mode == 'mutate-source':
 source = pathlib.Path(os.environ['SDD_TEST_MUTATE_PATH'])
 source.write_bytes(source.read_bytes() + b'\\n# fixture concurrent source change\\n')
print(json.dumps({'schema':'cross-model-verdict/v1','task_id':header('task_id'),
 'feature':header('feature'),'vendor':'openai','model':'fixture-self-report-not-attested',
 'verdict':'PASS','findings':[],'blind':True,'input_digest':header('input_digest'),
 'consent':{'kind':header('consent'),'ref':'fixture task or signed-token consent'}}))
''')
        path.chmod(0o700)

    def task_consent(self, enabled, *, task=None):
        self.tasks.write_text('# Tasks\n\n## ' + (task or self.TASK) + ' Fixture\n\nStatus: In Progress\n' +
                              ('Cross-Model: enabled\n' if enabled else ''))

    def prepare_bundle(self):
        result = self.run_process([BASH, str(self.scripts / 'prepare-panelist-input.sh'),
            '--task', self.TASK, '--feature', self.FEATURE, '--input', 'raw-input.txt',
            '--tasks-file', str(self.tasks), '--project-root', str(self.root), '--out', str(self.bundle)],
            label='real fixture bundle preparation')
        self.assertEqual(result.returncode, 0, result.stderr[:1400])
        self.bundle_digest = result.stdout.splitlines()[0]
        self.assertEqual(len(self.bundle_digest), 64)
        header, body = self.bundle.read_bytes().split(b'\n\n', 1)
        self.assertIn(('# input_digest: ' + self.bundle_digest).encode(), header)
        self.assertEqual(sha_bytes(body[:-1] if body.endswith(b'\n') else body), self.bundle_digest)

    def reset_run(self):
        shutil.rmtree(self.tasks.parent / 'verification', ignore_errors=True)
        self.audit.unlink(missing_ok=True)
        self.consent_audit.write_text('')

    def runner(self, shell, *, vendor='gpt', extra=(), env=None, selected=True, digest=None,
               consent='human-flag'):
        script = self.scripts / ('run-panelist-' + vendor + ('.sh' if shell == 'bash' else '.ps1'))
        command = ([BASH, str(script)] if shell == 'bash' else
                   [os.environ.get('SDD_TEST_PWSH', 'pwsh'),
                    '-NoProfile', '-File', str(script)])
        command += ['--task', self.TASK, '--feature', self.FEATURE, '--input', 'bundle.txt',
                    '--spec-root', 'specs', '--digest', digest or self.bundle_digest, '--consent', consent]
        if selected:
            command += ['--model-controls', 'controls.json', '--model-controls-sha256', self.controls_sha,
                        '--run-id', self.run_id, '--session-id', self.session_id]
        command += list(extra)
        return self.run_process(command, env, timeout=20, label='selected fixture panelist ' + shell)

    def verdict_path(self, vendor='gpt'):
        name = 'openai' if vendor == 'gpt' else 'google'
        return self.tasks.parent / 'verification' / (self.TASK + '.panelist-' + name + '.verdict.json')

    def artifact_dir(self, vendor='gpt'):
        name = 'openai' if vendor == 'gpt' else 'google'
        attempt_key = sha_bytes(canonical({'run_id':self.run_id,'session_id':self.session_id,
                                           'attempt':getattr(self,'panelist_attempt',1)}))
        return self.tasks.parent / 'verification' / (self.TASK + '.panelist-' + name) / attempt_key

    def accepted_panelist(self, shell, **options):
        self.reset_run()
        result = self.runner(shell, **options)
        self.assertEqual(result.returncode, 0, result.stderr[:1800])
        self.assertTrue(self.audit.is_file(), 'Selected panelist never reached the recording stub')
        self.assertTrue(self.verdict_path().is_file())
        return json.loads(self.verdict_path().read_bytes()), json.loads(self.audit.read_bytes())

    def rejected_panelist(self, shell, *, vendor='gpt', message=None, **options):
        self.reset_run()
        result = self.runner(shell, vendor=vendor, **options)
        self.assertNotEqual(result.returncode, 0, 'Rejected selected panelist unexpectedly succeeded')
        self.assertFalse(self.audit.exists(), 'Rejected selection/consent reached a vendor')
        self.assertFalse(self.verdict_path(vendor).exists())
        self.assertEqual(result.returncode, 2, result.stderr[:1400])
        self.assertTrue(result.stderr.lstrip().startswith('{'), 'Expected typed model-policy rejection: ' + result.stderr[:500])
        error = json.loads(result.stderr)
        self.assertEqual(error['schema'], 'model-policy-error/v1')
        self.assertIn(error['reason'], REASONS)
        if message:
            self.assertIn(message, error['message'].lower())
        return error

    def signed_sudo(self, *, valid=True, repo=None, expired=False):
        import hmac
        now = int(datetime.now(timezone.utc).timestamp())
        values = ['fixture-operator', 'a' * 32, str(repo or self.root), str(now - 10),
                  str(now - 1 if expired else now + 600)]
        sig = hmac.new(self.KEY.encode(), '\n'.join(values).encode(), hashlib.sha256).hexdigest()
        if not valid:
            sig = flip(sig)
        (self.root / 'SDD_SUDO').write_text('\n'.join(k + ': ' + v for k, v in
            zip(['issuer','nonce','repo','issued-epoch','expires-epoch','sig'], values + [sig])) + '\n')

    def gemini_controls(self):
        # Typed unavailable configuration, not a fabricated trusted Gemini mapping.
        self.request.update(role='panelist-gemini', host='gemini-cli')
        self.observation['host'] = 'gemini-cli'
        self.observation['cli_version'] = 'fixture-gemini-cli'
        self.save()
        selection = copy.deepcopy(self.selection)
        selection.update(host='gemini-cli', role='panelist-gemini', cli_version='fixture-gemini-cli',
                         observation_sha256=self.observation['observation_sha256'])
        selection['selection_sha256'] = digest(selection, 'selection_sha256')
        self.write('selection.json', selection)
        self.controls_sha = self.controls(role='panelist-gemini', mutate=lambda d:d.update(host='gemini-cli'))

    def test_both_shells_apply_selected_gpt_configuration_isolation_and_no_actual_id_claim(self):
        for shell in ('bash', 'powershell'):
            with self.subTest(shell=shell):
                verdict, audit = self.accepted_panelist(shell)
                argv = audit['argv']
                scratch = argv[argv.index('-C') + 1]
                self.assertEqual(argv, ['exec', '--model', 'gpt-6-astra', '-c',
                    'model_reasoning_effort=high', '--sandbox', 'read-only', '--skip-git-repo-check', '-C', scratch, '-'])
                self.assertEqual(audit['cwd'], scratch)
                self.assertNotEqual(Path(scratch), self.root)
                self.assertFalse(Path(scratch).exists(), 'Native scratch was not cleaned')
                self.assertFalse(any(audit['key_presence'].values()))
                self.assertEqual(audit['stdin'].count('# Panelist Input Bundle'), 1)
                self.assertIn(self.original_bundle.decode(), audit['stdin'])
                self.assertTrue(self.consent_audit.read_text().strip(), 'Existing consent authority was not rechecked')
                policy = verdict['model_policy']
                self.assertEqual(policy['actor_slot'], 'reviewers')
                self.assertEqual(policy['transport'], 'codex-exec')
                self.assertEqual(policy['selection']['binding'], {'run_id':self.run_id,
                    'session_id':self.session_id,'attempt':1})
                self.assertEqual(policy['selection']['resolved']['native_id'], 'gpt-6-astra')
                self.assertIsNone(policy['delivery']['actual_id'])
                self.assertEqual(policy['delivery']['proof'], 'unverified')
                self.assertEqual(policy['delivery']['source'], 'codex-exec')
                self.assertEqual(verdict['model'], 'fixture-self-report-not-attested')
                self.assertEqual(verdict['consent']['kind'], 'human-flag')

    def test_both_vendors_recheck_real_task_consent_before_any_send(self):
        for vendor in ('gpt', 'gemini'):
            if vendor == 'gemini':
                self.gemini_controls()
            for shell in ('bash', 'powershell'):
                with self.subTest(vendor=vendor, shell=shell):
                    for authority in ('disabled', 'different-task'):
                        with self.subTest(authority=authority):
                            self.task_consent(authority == 'different-task', task='T-999' if authority == 'different-task' else None)
                            self.rejected_panelist(shell, vendor=vendor, message='consent')
                            self.assertTrue(self.consent_audit.read_text().strip())
                    self.task_consent(True)

    def test_both_shells_reject_bundle_identity_body_digest_and_consent_substitution(self):
        mutations: list[tuple[str, Callable[[bytes], bytes]]] = [('task', lambda b:b.replace(b'# task_id: T-007',b'# task_id: T-999')),
                     ('feature',lambda b:b.replace(b'# feature: panelist-fixture',b'# feature: other-feature')),
                     ('body',lambda b:b+b'changed body\n'),
                     ('extra-newline',lambda b:b+b'\n'),
                     ('header-consent',lambda b:b.replace(b'# consent: human-flag',b'# consent: sudo')),
                     ('duplicate-header',lambda b:b.replace(b'# task_id: T-007',b'# task_id: T-007\n# task_id: T-999'))]
        for shell in ('bash','powershell'):
            self.accepted_panelist(shell)
            for label, mutate in mutations:
                with self.subTest(shell=shell, mutation=label):
                    self.bundle.write_bytes(mutate(self.original_bundle))
                    try:
                        self.rejected_panelist(shell)
                    finally:
                        self.bundle.write_bytes(self.original_bundle)
            self.rejected_panelist(shell, digest='0' * 64)
            self.rejected_panelist(shell, consent='sudo')

    def test_both_shells_retain_real_signed_sudo_and_block_invalid_tokens(self):
        self.task_consent(False)
        self.signed_sudo()
        self.prepare_bundle()
        self.original_bundle = self.bundle.read_bytes()
        for shell in ('bash','powershell'):
            verdict,_ = self.accepted_panelist(shell, consent='sudo')
            self.assertEqual(verdict['consent']['kind'],'sudo')
            token_cases: list[tuple[str, dict[str, Any]]] = [('signature',{'valid':False}),
                ('repo',{'repo':self.base}),('expired',{'expired':True})]
            for label, options in token_cases:
                with self.subTest(shell=shell, token=label):
                    self.signed_sudo(**options)
                    self.rejected_panelist(shell, consent='sudo', message='consent')
                    self.signed_sudo()

    def test_both_shells_block_conflicting_options_actual_id_and_persisted_live_controls(self):
        for shell in ('bash','powershell'):
            self.accepted_panelist(shell,extra=('--model','gpt-6-astra','--effort','high'))
            for args in [('--model','other-model'),('--effort','medium')]:
                self.rejected_panelist(shell,extra=args)
            self.controls_sha = self.controls(require_actual_id=True,mutate=lambda d:d.update(host='codex-cli'))
            error = self.rejected_panelist(shell)
            self.assertEqual(error['reason'],'actual-id-unavailable')
            self.controls_sha = self.controls(mutate=lambda d:d.update(host='codex-cli'))
        live = copy.deepcopy(self.observation)
        live.update(source='live-discovery',purpose='launch')
        self.seal(live)
        self.write('observation.json',live)
        selected = copy.deepcopy(self.selection)
        selected['observation_sha256'] = live['observation_sha256']
        selected['reason'] = selected['reason'].replace('verified-configuration','live-discovery')
        selected['selection_sha256'] = digest(selected,'selection_sha256')
        self.write('selection.json',selected)
        for shell in ('bash','powershell'):
            self.controls_sha = self.controls(mutate=lambda d:d.update(host='codex-cli'))
            error = self.rejected_panelist(shell)
            self.assertEqual(error['reason'], 'scope-mismatch')

    def test_both_shells_gemini_is_explicitly_unavailable_after_valid_consent(self):
        self.gemini_controls()
        for shell in ('bash','powershell'):
            with self.subTest(shell=shell):
                error = self.rejected_panelist(shell,vendor='gemini')
                self.assertEqual(error['reason'],'model-unavailable')
                self.assertTrue(self.consent_audit.read_text().strip())

    def test_native_failures_never_publish_a_verdict_or_accepted_delivery(self):
        for shell in ('bash','powershell'):
            self.accepted_panelist(shell)
            for mode in ('fail','invalid','timeout'):
                with self.subTest(shell=shell, mode=mode):
                    self.reset_run()
                    result = self.runner(shell,env={'SDD_TEST_NATIVE_MODE':mode,'SDD_PANELIST_TIMEOUT':'1'})
                    self.assertNotEqual(result.returncode,0)
                    self.assertFalse(self.verdict_path().exists())
                    self.assertFalse((self.artifact_dir()/'model-delivery-binding.json').exists())

    def test_postnative_source_change_never_publishes_accepted_binding_or_verdict(self):
        for shell in ('bash','powershell'):
            with self.subTest(shell=shell):
                self.accepted_panelist(shell)
                self.reset_run()
                source = self.scripts/('run-panelist-gpt.'+('sh' if shell=='bash' else 'ps1'))
                original = source.read_bytes()
                try:
                    result = self.runner(shell,env={'SDD_TEST_NATIVE_MODE':'mutate-source',
                                                    'SDD_TEST_MUTATE_PATH':str(source)})
                    self.assertTrue(self.audit.is_file(),'Mutation fixture never reached native stub')
                    self.assertNotEqual(source.read_bytes(),original)
                    self.assertNotEqual(result.returncode,0)
                    self.assertFalse(self.verdict_path().exists())
                    self.assertFalse((self.artifact_dir()/'model-delivery-binding.json').exists(),
                                     'Rejected source changes left an accepted delivery binding')
                finally:
                    source.write_bytes(original)

    def test_output_ancestor_symlinks_cause_no_target_writes_or_native_send(self):
        for shell in ('bash','powershell'):
            self.accepted_panelist(shell)
            for level in ('verification','vendor-base','attempt'):
                with self.subTest(shell=shell,ancestor=level):
                    self.reset_run()
                    outside = self.base/('outside-'+shell+'-'+level)
                    outside.mkdir()
                    link = (self.tasks.parent/'verification' if level=='verification' else
                            self.artifact_dir().parent if level=='vendor-base' else self.artifact_dir())
                    link.parent.mkdir(parents=True,exist_ok=True)
                    link.symlink_to(outside,target_is_directory=True)
                    try:
                        result = self.runner(shell)
                        self.assertNotEqual(result.returncode,0)
                        self.assertFalse(self.audit.exists(),'Output symlink reached native execution')
                        self.assertEqual(list(outside.iterdir()),[],
                                         'Rejected output symlink received evidence writes')
                        self.assertFalse(self.verdict_path().exists())
                    finally:
                        link.unlink()

    def test_repeated_binding_rejects_and_distinct_attempt_preserves_immutable_evidence(self):
        self.accepted_panelist('bash')
        first_output = self.artifact_dir()
        before = {p.relative_to(first_output).as_posix():p.read_bytes()
                  for p in first_output.rglob('*') if p.is_file()}
        self.assertIn('model-delivery-binding.json',before)
        verdict_before = self.verdict_path().read_bytes()
        self.audit.unlink()
        result = self.runner('bash')
        self.assertNotEqual(result.returncode,0,'Same immutable binding was reused')
        self.assertFalse(self.audit.exists(),'Repeated binding reached native execution')
        self.assertEqual(self.verdict_path().read_bytes(),verdict_before)
        self.assertEqual({p.relative_to(first_output).as_posix():p.read_bytes()
                          for p in first_output.rglob('*') if p.is_file()},before)
        self.panelist_attempt = 2
        self.controls_sha = self.controls(mutate=lambda d:d.update(host='codex-cli',attempt=2))
        result = self.runner('powershell')
        self.assertEqual(result.returncode,0,result.stderr[:1800])
        self.assertTrue(self.audit.exists())
        self.assertNotEqual(self.artifact_dir(),first_output)
        selected = json.loads((self.artifact_dir()/'model-selection.json').read_bytes())
        self.assertEqual(selected['binding']['attempt'],2)
        self.assertEqual({p.relative_to(first_output).as_posix():p.read_bytes()
                          for p in first_output.rglob('*') if p.is_file()},before)

    def test_panelist_postbindings_and_every_context_leaf_are_checked_retrospectively(self):
        verdict,_ = self.accepted_panelist('bash')
        output = self.artifact_dir()
        binding = json.loads((output/'model-delivery-binding.json').read_bytes())
        context_path = self.root/binding['execution_context']['path']
        context = json.loads(context_path.read_bytes())
        selection = json.loads((self.root/binding['selection']['path']).read_bytes())
        events = json.loads((self.root/binding['events']['path']).read_bytes())
        delivery = json.loads((self.root/binding['delivery']['path']).read_bytes())
        self.helper().validate_delivery_record(delivery,selection=selection,events=events,
                                              require_actual_id=False,transport='codex-exec')
        for key in ('selection','events','delivery','execution_context'):
            self.assertEqual(sha_file(self.root/binding[key]['path']),binding[key]['sha256'])
        self.assertEqual(binding['launch_sha256'],sha_file(output/'model-launch.json'))
        self.assertEqual(verdict['model_policy']['delivery_binding_sha256'],sha_file(output/'model-delivery-binding.json'))
        transport = load_module(ROOT/'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py','panelist_retro')
        launch_rel = (output/'model-launch.json').relative_to(self.root).as_posix()
        bind_rel = (output/'model-delivery-binding.json').relative_to(self.root).as_posix()
        expected = verdict['model_policy']
        def consume(raw_sha, launch_sha=None):
            return transport.verify_model_run(self.root,launch_rel,launch_sha or binding['launch_sha256'],bind_rel,
                                              raw_sha,'reviewers',feature=self.FEATURE)
        with mock.patch.object(transport.subprocess,'run',side_effect=AssertionError('retrospective native call')):
            self.assertEqual(consume(sha_file(output/'model-delivery-binding.json')),expected)
            for path in leaf_paths(context):
                with self.subTest(panelist_context_leaf='/'.join(map(str,path))):
                    changed = copy.deepcopy(context)
                    set_path(changed,path,altered(get_path(context,path)))
                    context_path.write_bytes(canonical(changed))
                    updated = copy.deepcopy(binding)
                    updated['execution_context']['sha256']=sha_file(context_path)
                    (output/'model-delivery-binding.json').write_bytes(canonical(updated))
                    with self.assertRaises(ValueError):
                        consume(sha_file(output/'model-delivery-binding.json'))
        context_path.write_bytes(canonical(context))
        (output/'model-delivery-binding.json').write_bytes(canonical(binding))
        with mock.patch.object(transport.subprocess,'run',side_effect=AssertionError('retrospective native call')):
            for document in ('consent_result','dependencies'):
                target = self.root/context[document]['path']
                original_raw = target.read_bytes()
                original_document = json.loads(original_raw)
                for path in leaf_paths(original_document):
                    with self.subTest(panelist_artifact=document,resealed_leaf='/'.join(map(str,path))):
                        changed = copy.deepcopy(original_document)
                        set_path(changed,path,altered(get_path(original_document,path)))
                        target.write_bytes(canonical(changed))
                        updated_context = copy.deepcopy(context)
                        updated_context[document]['sha256'] = sha_file(target)
                        context_path.write_bytes(canonical(updated_context))
                        updated_binding = copy.deepcopy(binding)
                        updated_binding['execution_context']['sha256'] = sha_file(context_path)
                        (output/'model-delivery-binding.json').write_bytes(canonical(updated_binding))
                        with self.assertRaises(ValueError):
                            consume(sha_file(output/'model-delivery-binding.json'))
                target.write_bytes(original_raw)
                context_path.write_bytes(canonical(context))
                (output/'model-delivery-binding.json').write_bytes(canonical(binding))
        original_launch = json.loads((output/'model-launch.json').read_bytes())
        with mock.patch.object(transport.subprocess,'run',side_effect=AssertionError('retrospective native call')):
            for path in leaf_paths(original_launch):
                with self.subTest(panelist_launch_leaf='/'.join(map(str,path))):
                    changed = copy.deepcopy(original_launch)
                    set_path(changed,path,altered(get_path(original_launch,path)))
                    if path != ('argv_sha256',):
                        changed['argv_sha256'] = sha_bytes(canonical(changed['argv']))
                    (output/'model-launch.json').write_bytes(canonical(changed))
                    launch_sha = sha_file(output/'model-launch.json')
                    updated = {**binding,'launch_sha256':launch_sha}
                    (output/'model-delivery-binding.json').write_bytes(canonical(updated))
                    with self.assertRaises(ValueError):
                        consume(sha_file(output/'model-delivery-binding.json'),launch_sha)
            (output/'model-launch.json').write_bytes(canonical(original_launch))
            for path in leaf_paths(binding):
                with self.subTest(panelist_binding_leaf='/'.join(map(str,path))):
                    updated = copy.deepcopy(binding)
                    set_path(updated,path,altered(get_path(binding,path)))
                    (output/'model-delivery-binding.json').write_bytes(canonical(updated))
                    with self.assertRaises(ValueError):
                        consume(sha_file(output/'model-delivery-binding.json'))
            (output/'model-delivery-binding.json').write_bytes(canonical(binding))
            for name in ('selection','events','delivery'):
                with self.subTest(panelist_raw_link=name):
                    target = self.root/binding[name]['path']
                    raw = target.read_bytes()
                    target.write_bytes(raw+b' ')
                    try:
                        with self.assertRaises(ValueError):
                            consume(sha_file(output/'model-delivery-binding.json'))
                    finally:
                        target.write_bytes(raw)


if __name__ == '__main__':
    unittest.main(verbosity=2)
