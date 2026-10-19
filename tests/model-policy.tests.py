#!/usr/bin/env python3
"""T-006 policy selection contracts. Typed fixtures only; no native discovery or inference.

Uses unittest/stdlib and real selector subprocesses. Fixture adoption files establish
only deterministic reference validation, never real model behavior or provider access.
Actual draft-2020-12 schema validation is separate task-local verification.
"""
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import json
import itertools
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-implementation/scripts'
HOSTS = ('claude-code', 'codex-cli', 'copilot-cli', 'gemini-cli')
EFFORTS = ['low', 'medium', 'high', 'xhigh']
ROLES = {
    'implementer': None, 'investigator': 'sdd-investigator',
    'spec-reviewer-a': 'spec-reviewer', 'spec-reviewer-b': 'spec-reviewer',
    'impl-reviewer-a': 'impl-reviewer', 'impl-reviewer-b': 'impl-reviewer',
    'task-reviewer-a': 'task-reviewer', 'task-reviewer-b': 'task-reviewer',
    'evaluator': 'sdd-evaluator', 'domain-reviewer-a': 'domain-reviewer',
    'domain-reviewer-b': 'domain-reviewer', 'workflow-auditor-a': 'workflow-auditor',
    'workflow-auditor-b': 'workflow-auditor', 'diagnosis': 'diagnosis',
    'self-improvement': 'self-improvement', 'panelist-gpt': 'panelist-gpt',
    'panelist-gemini': 'panelist-gemini',
}
CURRENT, OLD, NEW = 'vendor/current', 'vendor/old', 'vendor/new'
LIGHT, STANDARD = 'vendor/light', 'vendor/standard'
REASONS = {'config-invalid', 'config-conflict', 'native-precedence-conflict',
           'discovery-unavailable', 'discovery-incomplete', 'discovery-stale', 'scope-mismatch',
           'model-unavailable', 'model-unverified', 'model-tier-unavailable', 'effort-unavailable',
           'budget-unverifiable', 'resume-conflict', 'actual-id-unavailable', 'actual-id-mismatch',
           'input-invalid'}
SOURCE_DATE = '2026-10-18T00:00:00Z'
PWSH = os.environ.get('SDD_TEST_PWSH', 'pwsh')
BASH = os.environ.get('SDD_TEST_BASH', 'bash')


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8')


def digest(value, omit=None):
    return hashlib.sha256(canonical({k: v for k, v in value.items() if k != omit})).hexdigest()


def seal_observation(value):
    value['observation_sha256'] = digest(value, 'observation_sha256')
    return value


def load_helper():
    spec = importlib.util.spec_from_file_location('t006_policy', SCRIPTS / 'model-policy.py')
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class PolicySelection(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='model-policy-fixture-')
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.environment = {key: value for key, value in os.environ.items()
                            if not key.startswith('SDD_MODEL')}
        self.environment['PYTHONDONTWRITEBYTECODE'] = '1'
        self.registry = {
            'schema': 'agent-model-capabilities/v2',
            'models': [self.capability(name, tier) for name, tier in
                       [(CURRENT, 'strong'), (OLD, 'strong'), (NEW, 'strong'),
                        (STANDARD, 'standard'), (LIGHT, 'lightweight')]],
            'risk_effort_matrix': {'low': 'low', 'medium': 'medium', 'high': 'high',
                                   'critical': 'high', 'escalation_bump': True},
            'role_defaults': {role: {'minimum_tier': 'standard', 'default_effort': 'medium'}
                              for role in set(ROLES.values()) if role},
        }
        self.registry['role_defaults']['sdd-investigator'] = {
            'minimum_tier': 'lightweight', 'default_effort': 'low'}
        self.registry['role_defaults']['sdd-evaluator'] = {
            'minimum_tier': 'strong', 'default_effort': 'high',
            'claude_frontmatter': {'minimum_tier': 'standard', 'default_effort': 'medium'}}
        self.policy = {
            'schema': 'model-policy/v1', 'source_date': SOURCE_DATE,
            'observation_max_age_seconds': 300, 'default_policy': 'latest-compatible',
            'roles': {role: {'capability_role': capability,
                             'model_env': 'SDD_MODEL_' + role.upper().replace('-', '_'),
                             'preferences': [CURRENT, NEW, OLD, STANDARD, LIGHT]}
                      for role, capability in ROLES.items()},
            'models': [self.policy_model(name, lifecycle) for name, lifecycle in
                       [(CURRENT, 'current'), (OLD, 'historical'), (NEW, 'candidate'),
                        (STANDARD, 'current'), (LIGHT, 'current')]],
        }
        self.observation = seal_observation({
            'schema': 'model-observation/v1', 'host': 'codex-cli',
            'cli_version': 'fixture-cli 1.0', 'scope_id': 'fixture-client-1',
            'scope_kind': 'client', 'purpose': 'diagnostic',
            'observed_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ'),
            'source': 'verified-configuration', 'status': 'complete',
            'models': [{'native_id': 'native-' + name.split('/')[1], 'efforts': EFFORTS[:],
                        'available': True} for name in [CURRENT, OLD, NEW, STANDARD, LIGHT]],
            'reason': 'Typed fixture only; not live access or inference proof.',
        })
        self.request = {
            'schema': 'model-policy-request/v1', 'role': 'implementer', 'risk': 'high',
            'host': 'codex-cli', 'policy_path': 'policy.json', 'observation_path': 'observation.json',
            'project_config_path': None, 'cli': {'model_id': None, 'policy': None},
            'budget': None, 'requested_effort': None, 'resume_selection_path': None,
            'estimates': None,
        }
        self.project = {'schema': 'model-role-config/v1', 'default_policy': None, 'roles': {}}

    @staticmethod
    def capability(name, tier):
        return {'name': name, 'canonical_tier': tier, 'supported_efforts': EFFORTS[:],
                'default_effort': 'high', 'effort_control': {host: 'flag' for host in HOSTS}}

    def policy_model(self, name, lifecycle):
        evidence = canonical({'fixture_only': True, 'catalog_id': name, 'roles': list(ROLES)})
        path = name.split('/')[1] + '-fixture-adoption.json'
        (self.work / path).write_bytes(evidence)
        return {'id': name, 'lifecycle': lifecycle, 'source_url': 'https://example.invalid/models',
                'source_date': SOURCE_DATE, 'successor_of': [],
                'hosts': {host: 'native-' + name.split('/')[1] for host in HOSTS},
                'adoption': [] if lifecycle == 'candidate' else
                [{'role': role, 'path': path, 'sha256': hashlib.sha256(evidence).hexdigest()}
                 for role in ROLES]}

    def model(self, name):
        return next(item for item in self.policy['models'] if item['id'] == name)

    def write(self, name, value):
        (self.work / name).write_bytes(canonical(value))

    def save(self):
        for name, value in [('request.json', self.request), ('policy.json', self.policy),
                            ('registry.json', self.registry), ('project.json', self.project)]:
            self.write(name, value)
        self.write('observation.json', seal_observation(self.observation))

    def invoke(self, backend='bash', extra=(), env=None, save=True):
        if save:
            self.save()
        if backend == 'powershell':
            command = [PWSH, '-NoProfile', '-File', str(SCRIPTS / 'select-agent-model.ps1'),
                       '-PolicyInput', 'request.json', '-Registry', 'registry.json']
        else:
            command = [BASH, str(SCRIPTS / 'select-agent-model.sh'), '--policy-input',
                       'request.json', '--registry', 'registry.json']
        try:
            return subprocess.run(command + list(extra), cwd=self.work,
                                  env={**self.environment, **(env or {})}, text=True,
                                  capture_output=True, timeout=45, check=False)
        except (OSError, subprocess.TimeoutExpired) as error:
            self.fail('Selector execution failed: ' + type(error).__name__)

    def selected(self, result, model=None):
        self.assertEqual(result.returncode, 0, result.stderr[:1000])
        self.assertEqual(result.stderr, '')
        try:
            selection = json.loads(result.stdout)
        except ValueError:
            self.fail('Successful selector did not emit one JSON selection: ' + result.stdout[:300])
        self.assertEqual(selection['schema'], 'model-selection/v1')
        self.assertEqual(selection['selection_sha256'], digest(selection, 'selection_sha256'))
        self.assertEqual(selection['host'], self.request['host'])
        self.assertEqual(selection['role'], self.request['role'])
        self.assertEqual(selection['risk'], self.request['risk'])
        self.assertEqual(selection['policy_sha256'], digest(self.policy))
        self.assertEqual(selection['catalog_sha256'], digest(self.registry))
        self.assertEqual(selection['observation_sha256'], self.observation['observation_sha256'])
        self.assertEqual(selection['scope_id'], self.observation['scope_id'])
        self.assertEqual(selection['cli_version'], self.observation['cli_version'])
        self.assertEqual(selection['observed_at'], self.observation['observed_at'])
        self.assertEqual(selection['source_date'], self.policy['source_date'])
        if model:
            self.assertEqual(selection['resolved']['catalog_id'], model)
        self.assertIn(selection['resolved']['effort'], EFFORTS)
        self.assertEqual(selection['resolved']['native_id'],
                         self.model(selection['resolved']['catalog_id'])['hosts'][self.request['host']])
        load_helper().validate_selection_record(selection)
        return selection

    def blocked(self, result, reasons):
        self.assertEqual(result.returncode, 2, result.stderr[:1000])
        self.assertEqual(result.stdout, '')
        try:
            error = json.loads(result.stderr)
        except ValueError:
            self.fail('Blocked selector did not emit one JSON error: ' + result.stderr[:300])
        self.assertEqual(set(error), {'schema', 'reason', 'message'})
        self.assertEqual(error['schema'], 'model-policy-error/v1')
        self.assertIn(error['reason'], {reasons} if isinstance(reasons, str) else reasons)
        self.assertIn(error['reason'], REASONS)
        self.assertTrue(error['message'].strip())
        self.assertLessEqual(len(error['message']), 512)
        return error

    def pin(self, name=OLD, policy='pinned'):
        self.request['cli'] = {'model_id': name, 'policy': policy}

    def test_TEST079_all_seventeen_roles_use_shared_policy(self):
        for role in ROLES:
            with self.subTest(role=role):
                self.request['role'] = role
                self.selected(self.invoke(), CURRENT)

    def test_TEST080_role_floor_cannot_be_lowered_by_explicit_pin_or_cli_minimum(self):
        self.request['role'] = 'evaluator'
        self.request['risk'] = 'low'
        self.pin(LIGHT)
        self.blocked(self.invoke(), 'model-tier-unavailable')
        self.blocked(self.invoke(extra=['--minimum-tier', 'lightweight']), 'model-tier-unavailable')
        self.pin(STANDARD)
        self.blocked(self.invoke(), 'model-tier-unavailable')
        self.request['host'] = self.observation['host'] = 'claude-code'
        self.selected(self.invoke(), STANDARD)

    def test_TEST081_risk_escalation_and_terminal_recurrence(self):
        for risk, model in [('low', LIGHT), ('medium', STANDARD), ('high', CURRENT), ('critical', CURRENT)]:
            with self.subTest(risk=risk):
                self.request['risk'] = risk
                self.selected(self.invoke(), model)
        self.request['risk'] = 'low'
        args = ['--failure-history', 'test,test', '--previous-tier', 'lightweight', '--attempt-number', '2']
        self.selected(self.invoke(extra=args), STANDARD)
        args[3] = 'standard'
        self.selected(self.invoke(extra=args), CURRENT)
        args[3] = 'strong'
        self.blocked(self.invoke(extra=args), 'model-tier-unavailable')
        self.selected(self.invoke(extra=['--failure-history', 'test,lint', '--previous-tier', 'lightweight',
                                        '--attempt-number', '2']), LIGHT)

    def test_TEST089_verified_successor_wins_after_eligibility(self):
        self.model(NEW)['lifecycle'] = 'current'
        self.model(NEW)['adoption'] = self.policy_model(NEW, 'current')['adoption']
        self.model(NEW)['successor_of'] = [CURRENT]
        self.selected(self.invoke(), NEW)
        for item in self.observation['models']:
            if item['native_id'] == 'native-new':
                item['available'] = False
        self.selected(self.invoke(), CURRENT)

    def test_TEST090_TEST151_unknown_successor_is_notice_not_adoption(self):
        self.observation['models'].append({'native_id': 'native-future-999', 'efforts': EFFORTS[:],
                                           'available': True})
        result = self.selected(self.invoke(), CURRENT)
        self.assertIn('native-future-999', result['update_candidates'])
        self.assertIn('latest-verified', result['reason'])
        self.assertIn('verified-configuration', result['reason'])
        self.assertIsNone(result['binding'])
        self.assertIsNone(result['estimate'])

    def test_TEST091_names_and_list_order_do_not_rank_families(self):
        other = 'vendor/z999'
        self.registry['models'].append(self.capability(other, 'strong'))
        self.policy['models'].insert(0, self.policy_model(other, 'current'))
        for role in self.policy['roles'].values():
            role['preferences'].append(other)
        self.observation['models'].insert(0, {'native_id': 'native-z999', 'efforts': EFFORTS[:], 'available': True})
        self.selected(self.invoke(), CURRENT)
        self.policy['models'].reverse()
        self.observation['models'].reverse()
        self.selected(self.invoke(), CURRENT)

    def test_TEST092_retired_historical_candidate_cannot_fill_current_gap(self):
        for lifecycle in ['historical', 'retired', 'candidate']:
            with self.subTest(lifecycle=lifecycle):
                for item in self.policy['models']:
                    item['lifecycle'] = lifecycle
                self.blocked(self.invoke(), {'model-unverified', 'model-unavailable', 'model-tier-unavailable'})

    def test_TEST093_host_registry_and_effort_intersection(self):
        self.request['requested_effort'] = 'high'
        self.pin(CURRENT)
        for item in self.observation['models']:
            item['efforts'] = ['low']
        self.blocked(self.invoke(), 'effort-unavailable')
        self.observation['models'][0]['efforts'] = EFFORTS[:]
        del self.registry['models'][0]['effort_control']['codex-cli']
        self.blocked(self.invoke(), {'model-unavailable', 'effort-unavailable'})

    def test_TEST094_TEST110_explicit_historical_pin_stays_labelled_pinned(self):
        self.pin()
        result = self.selected(self.invoke(), OLD)
        self.assertEqual(result['requested'], {'policy': 'pinned', 'model_id': OLD,
                                              'policy_source': 'cli', 'model_source': 'cli'})
        self.assertIn('pinned', result['reason'])
        self.assertNotIn('latest-verified', result['reason'])

    def test_TEST097_unknown_and_miscased_policy_operator_layer(self):
        for policy in ['auto', 'Latest-compatible', 'PINNED', '', 'pinned\n']:
            with self.subTest(policy=policy):
                self.request['cli']['policy'] = policy
                self.blocked(self.invoke(), 'config-invalid')

    def test_TEST098_TEST148_TEST149_injection_ids_are_rejected_without_execution(self):
        marker = self.work / 'executed'
        for model in ['two words', '--model', '-x', 'x;touch executed', 'x|touch executed',
                      '$(touch executed)', 'x`touch executed`', 'x\ny', 'café', 'a' * 129]:
            with self.subTest(model=model):
                self.pin(model)
                self.blocked(self.invoke(), 'config-invalid')
                self.assertFalse(marker.exists())

    def test_TEST099_TEST106_pin_cannot_grant_access_or_fallback(self):
        self.pin(CURRENT)
        self.observation['models'][0]['available'] = False
        self.blocked(self.invoke(), 'model-unavailable')
        self.observation['models'] = [item for item in self.observation['models']
                                       if item['native_id'] != 'native-current']
        self.blocked(self.invoke(), 'model-unavailable')

    def test_TEST105_empty_current_intersection_blocks(self):
        self.observation['models'] = []
        self.blocked(self.invoke(), {'model-unavailable', 'model-tier-unavailable'})

    def test_TEST109_budget_unknown_is_not_zero(self):
        self.request['budget'] = {'amount': 1, 'unit': 'USD'}
        self.blocked(self.invoke(), 'budget-unverifiable')
        self.request['estimates'] = [{'catalog_id': CURRENT, 'amount': 0, 'unit': 'credits',
                                      'source_url': 'https://example.invalid/price', 'source_date': SOURCE_DATE}]
        self.blocked(self.invoke(), {'config-invalid', 'budget-unverifiable'})
        self.request['estimates'][0]['unit'] = 'USD'
        self.request['estimates'][0]['amount'] = 2
        self.blocked(self.invoke(), 'budget-unverifiable')
        self.request['estimates'][0]['amount'] = 1
        result = self.selected(self.invoke(), CURRENT)
        self.assertEqual(result['budget'], self.request['budget'])
        self.assertEqual(result['estimate'], self.request['estimates'][0])
        self.request['estimates'][0]['amount'] = 0
        self.assertEqual(self.selected(self.invoke(), CURRENT)['estimate']['amount'], 0)

    def test_TEST109_unknown_cost_without_budget_remains_null_and_preference_wins(self):
        self.request['estimates'] = [{'catalog_id': OLD, 'amount': 0, 'unit': 'USD',
                                      'source_url': 'https://example.invalid/price', 'source_date': SOURCE_DATE}]
        self.assertIsNone(self.selected(self.invoke(), CURRENT)['estimate'])

    def test_TEST122_TEST123_legacy_v1_v2_cost_and_fallback_contract(self):
        for version in [1, 2]:
            with self.subTest(version=version):
                registry = copy.deepcopy(self.registry)
                registry['schema'] = f'agent-model-capabilities/v{version}'
                registry['models'] = [self.capability('vendor/zprimary', 'strong'),
                                      self.capability('vendor/afallback', 'strong')]
                for item in registry['models']:
                    item['efforts'] = EFFORTS[:]
                registry['models'][1]['fallback_for'] = 'vendor/zprimary'
                self.write('legacy-registry.json', registry)
                candidates = [{'name': item['name'], 'available': True, 'cost': '1.25', 'effort': 'high'}
                              for item in registry['models']]
                self.write('legacy-candidates.json', candidates)
                command = [BASH, str(SCRIPTS / 'select-agent-model.sh'), '--risk', 'high', '--registry',
                           'legacy-registry.json', '--candidates-file', 'legacy-candidates.json', '--json']
                result = subprocess.run(command, cwd=self.work, env=self.environment, text=True,
                                        capture_output=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout)['model'], 'vendor/zprimary')
                del candidates[0]['cost']
                self.write('legacy-candidates.json', candidates)
                result = subprocess.run(command, cwd=self.work, env=self.environment, text=True,
                                        capture_output=True, timeout=30)
                self.assertNotEqual(result.returncode, 0)

    def test_TEST124_bash_powershell_fixture_parity(self):
        first = self.selected(self.invoke(), CURRENT)
        second = self.selected(self.invoke('powershell'), CURRENT)
        self.assertEqual(first, second)
        self.pin(OLD)
        self.assertEqual(self.selected(self.invoke(), OLD), self.selected(self.invoke('powershell'), OLD))

    def test_TEST124_all_four_hosts_are_explicit_fixture_capabilities(self):
        for host in HOSTS:
            with self.subTest(host=host):
                self.request['host'] = self.observation['host'] = host
                self.selected(self.invoke(), CURRENT)
                self.selected(self.invoke('powershell'), CURRENT)
                self.model(CURRENT)['hosts'].pop(host)
                self.pin(CURRENT)
                self.blocked(self.invoke(), 'model-unavailable')
                self.blocked(self.invoke('powershell'), 'model-unavailable')
                self.model(CURRENT)['hosts'][host] = 'native-current'
                self.request['cli'] = {'model_id': None, 'policy': None}

    def test_TEST125_effort_never_enables_extra_modes(self):
        for effort in ['max', 'ultra']:
            with self.subTest(effort=effort):
                self.request['requested_effort'] = effort
                self.blocked(self.invoke(), 'config-invalid')
        self.request['requested_effort'] = 'xhigh'
        self.blocked(self.invoke(), {'effort-unavailable', 'model-tier-unavailable'})
        result = self.selected(self.invoke(extra=['--xhigh-reason', 'explicit fixture justification']), CURRENT)
        self.assertEqual(result['resolved']['effort'], 'xhigh')
        self.assertNotIn('agents', result)
        self.assertNotIn('delegation', result)

    def test_TEST126_selector_preserves_historical_input_bytes(self):
        self.save()
        before = {p.name: p.read_bytes() for p in self.work.iterdir() if p.is_file()}
        self.selected(self.invoke(save=False), CURRENT)
        after = {p.name: p.read_bytes() for p in self.work.iterdir() if p.is_file()}
        self.assertEqual(before, after)

    def test_TEST147_TEST159_pin_requires_id_and_implicit_pin_records_source(self):
        self.request['cli']['policy'] = 'pinned'
        self.blocked(self.invoke(), 'config-conflict')
        self.pin(OLD, None)
        result = self.selected(self.invoke(), OLD)
        self.assertEqual(result['requested']['policy'], 'pinned')
        self.assertEqual(result['requested']['policy_source'], 'cli')
        self.request['cli']['model_id'] = None
        result = self.selected(self.invoke(env={'SDD_MODEL_IMPLEMENTER': OLD}), OLD)
        self.assertEqual(result['requested']['policy_source'], 'environment')

    def test_TEST150_native_mapping_is_explicit_and_unambiguous(self):
        self.pin(CURRENT)
        self.model(CURRENT)['hosts']['codex-cli'] = 'provider-specific-exact-name'
        self.observation['models'][0]['native_id'] = 'provider-specific-exact-name'
        self.assertEqual(self.selected(self.invoke(), CURRENT)['resolved']['native_id'],
                         'provider-specific-exact-name')
        self.model(OLD)['hosts']['codex-cli'] = 'provider-specific-exact-name'
        self.blocked(self.invoke(), 'config-invalid')

    def project_id(self, value):
        self.request['project_config_path'] = 'project.json'
        self.project['roles']['implementer'] = {'model_id': value, 'policy': None}

    def test_TEST152_cli_model_shadows_valid_environment_and_project(self):
        self.project_id(NEW)
        self.pin(OLD, None)
        result = self.selected(self.invoke(env={'SDD_MODEL_IMPLEMENTER': CURRENT}), OLD)
        self.assertEqual(result['requested']['model_source'], 'cli')

    def test_TEST153_environment_model_shadows_project(self):
        self.project_id(NEW)
        result = self.selected(self.invoke(env={'SDD_MODEL_IMPLEMENTER': OLD}), OLD)
        self.assertEqual(result['requested']['model_source'], 'environment')

    def test_TEST154_project_model_and_shipped_default(self):
        self.project_id(OLD)
        result = self.selected(self.invoke(), OLD)
        self.assertEqual(result['requested']['model_source'], 'project-role')
        self.request['project_config_path'] = None
        result = self.selected(self.invoke(), CURRENT)
        self.assertEqual(result['requested'], {'policy': 'latest-compatible', 'model_id': None,
                                              'policy_source': 'shipped', 'model_source': None})

    def test_TEST155_generic_model_environment_is_rejected(self):
        for env in [{'SDD_MODEL': OLD}, {'SDD_MODEL': OLD, 'SDD_MODEL_IMPLEMENTER': CURRENT},
                    {'SDD_MODEL': ''}]:
            with self.subTest(env=env):
                self.blocked(self.invoke(env=env), 'config-invalid')

    def test_TEST156_policy_precedence_is_independent_from_model_precedence(self):
        self.project_id(OLD)
        self.project['roles']['implementer']['policy'] = 'latest-compatible'
        self.request['cli']['policy'] = 'pinned'
        result = self.selected(self.invoke(env={'SDD_MODEL_POLICY': 'latest-compatible'}), OLD)
        self.assertEqual(result['requested']['policy_source'], 'cli')
        self.assertEqual(result['requested']['model_source'], 'project-role')
        self.request['cli']['policy'] = None
        result = self.selected(self.invoke(env={'SDD_MODEL_POLICY': 'pinned'}), OLD)
        self.assertEqual(result['requested']['policy_source'], 'environment')
        self.project['roles']['implementer']['policy'] = 'pinned'
        self.assertEqual(self.selected(self.invoke(), OLD)['requested']['policy_source'], 'project-role')

    def test_TEST157_project_role_policy_beats_project_default(self):
        self.project_id(OLD)
        self.project['default_policy'] = 'latest-compatible'
        self.project['roles']['implementer']['policy'] = 'pinned'
        self.assertEqual(self.selected(self.invoke(), OLD)['requested']['policy_source'], 'project-role')
        self.project['roles']['implementer']['policy'] = None
        self.project['default_policy'] = 'pinned'
        self.assertEqual(self.selected(self.invoke(), OLD)['requested']['policy_source'], 'project-default')

    def test_TEST158_explicit_latest_and_any_effective_id_conflict(self):
        self.project_id(OLD)
        for source in ['cli', 'environment', 'project-role', 'project-default']:
            with self.subTest(source=source):
                self.request['cli']['policy'] = 'latest-compatible' if source == 'cli' else None
                self.project['default_policy'] = 'latest-compatible' if source == 'project-default' else None
                self.project['roles']['implementer']['policy'] = 'latest-compatible' if source == 'project-role' else None
                env = {'SDD_MODEL_POLICY': 'latest-compatible'} if source == 'environment' else {}
                self.blocked(self.invoke(env=env), 'config-conflict')

    def test_TEST160_all_shadowed_supported_values_are_validated(self):
        self.pin(OLD)
        self.project_id(CURRENT)
        for env in [{'SDD_MODEL_IMPLEMENTER': 'bad id'}, {'SDD_MODEL_EVALUATOR': '--bad'},
                    {'SDD_MODEL_POLICY': 'PINNED'}, {'SDD_MODEL_IMPLEMENTER_POLICY': 'pinned'}]:
            with self.subTest(env=env):
                self.blocked(self.invoke(env=env), 'config-invalid')
        self.project['roles']['evaluator'] = {'model_id': 'bad;id', 'policy': None}
        self.blocked(self.invoke(), 'config-invalid')
        self.project['roles']['evaluator']['model_id'] = OLD
        self.project['default_policy'] = 'PINNED'
        self.blocked(self.invoke(), 'config-invalid')

    def test_powershell_separate_operator_and_language_negative_fixtures(self):
        cases = [('operator-policy', {'policy': 'Latest-compatible'}),
                 ('language-model-key', {'model_id': 'Vendor/current'}),
                 ('language-property-key', {'Policy': 'pinned'})]
        for layer, bad in cases:
            with self.subTest(layer=layer):
                self.request['cli'] = {'model_id': None, 'policy': None, **bad}
                expected = {'config-invalid', 'model-unavailable'}
                left = self.blocked(self.invoke(), expected)
                right = self.blocked(self.invoke('powershell'), expected)
                self.assertEqual(left['reason'], right['reason'])
        self.request['cli'] = {'model_id': None, 'policy': None}
        self.blocked(self.invoke(extra=['--risk', 'High']), {'config-invalid', 'config-conflict'})
        self.blocked(self.invoke('powershell', extra=['-Risk', 'High']), {'config-invalid', 'config-conflict'})

    def test_policy_reference_source_and_adoption_mismatches(self):
        mutations = [
            ('id', lambda: self.model(CURRENT).__setitem__('id', 'vendor/unregistered')),
            ('lifecycle', lambda: self.model(CURRENT).__setitem__('lifecycle', 'Current')),
            ('source_url', lambda: self.model(CURRENT).__setitem__('source_url', 'http://example.invalid')),
            ('source_date', lambda: self.model(CURRENT).__setitem__('source_date', '2026-02-30T00:00:00Z')),
            ('successor', lambda: self.model(CURRENT).__setitem__('successor_of', [CURRENT])),
            ('cycle', lambda: (self.model(CURRENT).__setitem__('successor_of', [OLD]),
                               self.model(OLD).__setitem__('successor_of', [CURRENT]))),
            ('capability_role', lambda: self.policy['roles']['implementer'].__setitem__('capability_role', 'missing')),
            ('model_env', lambda: self.policy['roles']['implementer'].__setitem__('model_env', 'SDD_MODEL_EVALUATOR')),
            ('preference', lambda: self.policy['roles']['implementer'].__setitem__('preferences', [CURRENT, CURRENT])),
            ('adoption_path', lambda: self.model(CURRENT)['adoption'][0].__setitem__('path', '../outside')),
            ('adoption_hash', lambda: self.model(CURRENT)['adoption'][0].__setitem__('sha256', '0' * 64)),
            ('adoption_role', lambda: self.model(CURRENT)['adoption'][0].__setitem__('role', 'missing-role')),
        ]
        baseline = copy.deepcopy(self.policy)
        for name, mutate in mutations:
            with self.subTest(field=name):
                self.policy = copy.deepcopy(baseline)
                mutate()
                self.blocked(self.invoke(), {'config-invalid', 'model-unverified'})

    def test_missing_adoption_is_not_a_current_verified_model(self):
        self.model(CURRENT)['adoption'] = []
        self.pin(CURRENT)
        self.blocked(self.invoke(), 'model-unverified')

    def test_observation_scope_freshness_completeness_and_active_capture_boundary(self):
        baseline = copy.deepcopy(self.observation)
        cases = [('host', 'claude-code', 'scope-mismatch'), ('status', 'incomplete', 'discovery-incomplete'),
                 ('source', 'live-discovery', 'scope-mismatch'),
                 ('observed_at', '2020-01-01T00:00:00Z', 'discovery-stale')]
        for field, value, reason in cases:
            with self.subTest(field=field):
                self.observation = copy.deepcopy(baseline)
                self.observation[field] = value
                self.blocked(self.invoke(), reason)
        self.observation = copy.deepcopy(baseline)
        self.observation['observed_at'] = (datetime.now(timezone.utc) + timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%SZ')
        self.blocked(self.invoke(), 'discovery-stale')
        self.observation = copy.deepcopy(baseline)
        self.observation.update({'source': 'unsupported', 'status': 'unavailable', 'models': []})
        self.blocked(self.invoke(), 'discovery-unavailable')

    def test_request_project_and_policy_closed_fields(self):
        objects = [('request', self.request), ('project', self.project), ('policy', self.policy)]
        self.request['project_config_path'] = 'project.json'
        for label, target in objects:
            with self.subTest(contract=label):
                target['unexpected'] = True
                self.blocked(self.invoke(), 'config-invalid')
                del target['unexpected']
        for field in list(self.request):
            if field == 'estimates':
                continue
            with self.subTest(missing=field):
                previous = self.request.pop(field)
                self.blocked(self.invoke(), 'config-invalid')
                self.request[field] = previous

    def test_strict_json_duplicate_keys_nonfinite_and_unsafe_paths(self):
        self.save()
        for raw in ['{"schema":"model-policy-request/v1","schema":"model-policy-request/v1"}',
                    '{"amount":NaN}', '{"amount":1e999}', '[]']:
            with self.subTest(raw=raw):
                (self.work / 'request.json').write_text(raw)
                self.blocked(self.invoke(save=False), 'config-invalid')
        for path in ['../policy.json', '/policy.json', 'C:/policy.json', 'x\\policy.json']:
            with self.subTest(path=path):
                self.request['policy_path'] = path
                self.blocked(self.invoke(), 'config-invalid')

    def test_resume_selection_roundtrip_and_resealed_mismatch(self):
        selection = self.selected(self.invoke(), CURRENT)
        helper = load_helper()
        original = helper.bind_selection(selection, run_id='fixture-run', session_id='fixture-session', attempt=1)
        self.write('resume.json', original)
        self.request['resume_selection_path'] = 'resume.json'
        self.assertEqual(self.selected(self.invoke(), CURRENT), original)
        changed = copy.deepcopy(original)
        changed['reason'] = 'Otherwise valid but different original provenance.'
        changed['selection_sha256'] = digest(changed, 'selection_sha256')
        self.write('resume.json', changed)
        self.blocked(self.invoke(), 'resume-conflict')

    def test_explicit_selector_values_match_request_and_candidate_inputs_conflict(self):
        self.selected(self.invoke(extra=['--risk', 'high', '--host', 'codex-cli', '--role', 'implementer']), CURRENT)
        for args in [['--risk', 'low'], ['--host', 'claude-code'], ['--role', 'evaluator'],
                     ['--candidate', 'vendor/x:strong:0'], ['--candidates-file', 'extra.json']]:
            with self.subTest(args=args):
                self.blocked(self.invoke(extra=args), 'config-conflict')

    def test_mixed_known_unknown_costs_have_total_order_for_every_permutation(self):
        names = ['vendor/unknown', 'vendor/cheap', 'vendor/dear']
        self.policy['models'] = [self.policy_model(name, 'current') for name in names]
        self.registry['models'] = [self.capability(name, 'strong') for name in names]
        for role in self.policy['roles'].values():
            role['preferences'] = []
        self.request['estimates'] = [
            {'catalog_id': name, 'amount': amount, 'unit': 'USD',
             'source_url': 'https://example.invalid/price', 'source_date': SOURCE_DATE}
            for name, amount in [('vendor/cheap', 1), ('vendor/dear', 2)]]
        for order in itertools.permutations(names):
            with self.subTest(order=order):
                self.policy['models'].sort(key=lambda item: order.index(item['id']))
                self.registry['models'].sort(key=lambda item: order.index(item['name']))
                self.observation['models'] = [
                    {'native_id': 'native-' + name.split('/')[1], 'efforts': EFFORTS[:], 'available': True}
                    for name in reversed(order)]
                self.selected(self.invoke(), 'vendor/cheap')
        self.request['estimates'] = None
        self.selected(self.invoke(), 'vendor/cheap')  # Stable catalog ID, not order or fabricated price.
        for role in self.policy['roles'].values():
            role['preferences'] = ['vendor/unknown', 'vendor/cheap', 'vendor/dear']
        self.assertIsNone(self.selected(self.invoke(), 'vendor/unknown')['estimate'])

    def bridge(self, command, payload):
        return subprocess.run([sys.executable, '-B', str(SCRIPTS / 'model-policy.py'), command],
                              cwd=self.work, input=json.dumps(payload), text=True, capture_output=True,
                              env=self.environment, timeout=30, check=False)

    def test_bridge_closed_grammar_and_direct_winner_counterparts(self):
        self.request['role'] = 'evaluator'
        self.save()
        payload = {'request_path': 'request.json', 'registry_path': 'registry.json', 'selector_options': {}}
        prepared = self.bridge('prepare-selection', payload)
        self.assertEqual(prepared.returncode, 0, prepared.stderr[:1000])
        context = json.loads(prepared.stdout)
        winner = {'model': CURRENT, 'canonical_tier': 'strong', 'effort': 'high', 'effort_control': 'flag'}
        self.selected(self.bridge('complete-selection', {'context': context, 'winner': winner}), CURRENT)
        for field, value in [('model', LIGHT), ('model', 'vendor/missing'), ('canonical_tier', 'lightweight'),
                             ('effort', 'ultra'), ('effort', 'xhigh'), ('effort_control', 'none')]:
            with self.subTest(field=field, value=value):
                bad = {**winner, field: value}
                self.blocked(self.bridge('complete-selection', {'context': context, 'winner': bad}),
                             {'input-invalid', 'config-invalid', 'model-tier-unavailable',
                              'model-unavailable', 'effort-unavailable', 'config-conflict'})
        self.blocked(self.bridge('prepare-selection', {**payload, 'trusted': True}), 'input-invalid')
        self.blocked(self.bridge('complete-selection', {'context': context, 'winner': winner, 'trusted': True}),
                     'input-invalid')
        self.policy['source_date'] = '2026-10-17T00:00:00Z'
        self.save()
        self.blocked(self.bridge('complete-selection', {'context': context, 'winner': winner}),
                     {'input-invalid', 'config-conflict', 'resume-conflict'})

    def test_direct_completion_cannot_bypass_risk_effort_or_escalation(self):
        cases = [
            ('high-risk-tier', 'implementer', 'high', {}, LIGHT, 'lightweight', 'low'),
            ('high-risk-effort', 'implementer', 'high', {}, CURRENT, 'strong', 'low'),
            ('role-effort-fallback', 'evaluator', 'low', {}, CURRENT, 'strong', 'low'),
            ('escalation', 'implementer', 'low',
             {'failure_history': 'test,test', 'previous_tier': 'lightweight', 'attempt_number': '2'},
             LIGHT, 'lightweight', 'low'),
        ]
        for label, role, risk, options, model, tier, effort in cases:
            with self.subTest(boundary=label):
                self.request.update(role=role, risk=risk)
                if label == 'role-effort-fallback':
                    self.registry['risk_effort_matrix'].pop('low')
                self.save()
                prepared = self.bridge('prepare-selection', {
                    'request_path': 'request.json', 'registry_path': 'registry.json',
                    'selector_options': options})
                self.assertEqual(prepared.returncode, 0, prepared.stderr[:1000])
                winner = {'model': model, 'canonical_tier': tier,
                          'effort': effort, 'effort_control': 'flag'}
                self.blocked(self.bridge('complete-selection', {
                    'context': json.loads(prepared.stdout), 'winner': winner}),
                    {'config-conflict', 'model-tier-unavailable', 'effort-unavailable'})

    def test_deep_successor_cycle_is_a_typed_configuration_error(self):
        names = ['vendor/deep-' + str(index) for index in range(1100)]
        self.registry['models'] = [self.capability(name, 'strong') for name in names]
        self.policy['models'] = [
            {'id': name, 'lifecycle': 'candidate',
             'source_url': 'https://example.invalid/models', 'source_date': SOURCE_DATE,
             'successor_of': [names[index - 1]], 'hosts': {'codex-cli': 'deep-' + str(index)},
             'adoption': []} for index, name in enumerate(names)]
        self.policy['models'].reverse()
        for role in self.policy['roles'].values():
            role['preferences'] = []
        self.blocked(self.invoke(), 'config-invalid')

    def test_powershell_mixed_known_prices_and_signed_zero_are_total_ordered(self):
        names = ['vendor/unknown', 'vendor/cheap', 'vendor/dear']
        self.policy['models'] = [self.policy_model(name, 'current') for name in names]
        self.registry['models'] = [self.capability(name, 'strong') for name in names]
        for role in self.policy['roles'].values():
            role['preferences'] = []
        for prices in [(1, 2), (-0.0, 0.0)]:
            self.request['estimates'] = [
                {'catalog_id': name, 'amount': amount, 'unit': 'USD',
                 'source_url': 'https://example.invalid/price', 'source_date': SOURCE_DATE}
                for name, amount in [('vendor/cheap', prices[0]), ('vendor/dear', prices[1])]]
            for order in itertools.permutations(names):
                with self.subTest(prices=prices, order=order):
                    self.policy['models'].sort(key=lambda item: order.index(item['id']))
                    self.registry['models'].sort(key=lambda item: order.index(item['name']))
                    self.observation['models'] = [
                        {'native_id': 'native-' + name.split('/')[1],
                         'efforts': EFFORTS[:], 'available': True} for name in reversed(order)]
                    expected = self.selected(self.invoke(), 'vendor/cheap')
                    actual = self.selected(self.invoke('powershell'), 'vendor/cheap')
                    self.assertEqual(actual, expected)

    def test_genuine_diagnostic_capture_cannot_authorize_selection(self):
        specification = importlib.util.spec_from_file_location(
            't006_observation_fixture', ROOT / 'tests/model-observation.tests.py')
        observation_fixture = importlib.util.module_from_spec(specification)
        specification.loader.exec_module(observation_fixture)
        helper = observation_fixture.MP
        self.assertIsNotNone(helper, observation_fixture.MP_ERROR)
        pages = [observation_fixture.page([
            observation_fixture.native_model('fixture-current', 'native-current', EFFORTS)])]
        observation_fixture.NativeFake(self, pages).start()
        with helper.CodexClient('t006-purpose-fixture') as client:
            diagnostic = client.capture(purpose='diagnostic')
            self.observation = diagnostic.observation
            self.save()
            previous = Path.cwd()
            try:
                os.chdir(self.work)
                with self.assertRaises(helper.PolicyError) as caught:
                    helper.prepare_policy('request.json', 'registry.json',
                                          options={}, environment={}, capture=diagnostic)
                self.assertEqual(caught.exception.reason, 'scope-mismatch')
            finally:
                os.chdir(previous)

    def test_completion_rechecks_sources_after_real_native_replay(self):
        from unittest.mock import patch
        helper = load_helper()
        self.save()
        previous = Path.cwd()
        try:
            os.chdir(self.work)
            context = helper.prepare_policy('request.json', 'registry.json', options={}, environment={})
            replay = helper._replay_policy_winner
            winner = replay(context)

            def replay_then_change_policy(prepared):
                result = replay(prepared)
                self.policy['source_date'] = '2026-10-17T00:00:00Z'
                self.write('policy.json', self.policy)
                return result

            with patch.object(helper, '_replay_policy_winner', replay_then_change_policy):
                with self.assertRaises(helper.PolicyError) as caught:
                    helper.complete_policy(context, winner)
                self.assertEqual(caught.exception.reason, 'config-conflict')
        finally:
            os.chdir(previous)

    def test_supported_policy_options_always_fail_with_one_typed_error(self):
        cases = [
            ('required-tier', 'RequiredTier', 'bogus'),
            ('minimum-tier', 'MinimumTier', 'bogus'),
            ('previous-tier', 'PreviousTier', 'bogus'),
            ('failure-class', 'FailureClass', 'bogus'),
            ('failure-history', 'FailureHistory', 'bogus,bogus'),
            ('attempt-number', 'AttemptNumber', 'not-an-integer'),
            ('consecutive-failures', 'ConsecutiveFailures', 'not-an-integer'),
            ('effort-policy', 'EffortPolicy', 'MATRIX'),
            ('deterministic-runtime-command', 'DeterministicRuntimeCommand', 'missing-t006-runtime'),
        ]
        for shell_name, ps_name, value in cases:
            for backend, args in [('bash', ['--' + shell_name, value]),
                                  ('powershell', ['-' + ps_name, value])]:
                with self.subTest(option=shell_name, backend=backend):
                    self.blocked(self.invoke(backend, extra=args),
                                 {'config-invalid', 'config-conflict', 'input-invalid'})

    def test_python_api_rejects_fabricated_active_capture(self):
        helper = load_helper()
        prepare = getattr(helper, 'prepare_policy', None)
        self.assertTrue(callable(prepare), 'Policy preparation API is missing')
        self.observation['source'] = 'live-discovery'
        self.save()
        old_cwd = Path.cwd()
        try:
            os.chdir(self.work)
            with self.assertRaises(helper.PolicyError):
                prepare('request.json', 'registry.json', options={}, environment={}, capture=object())
        finally:
            os.chdir(old_cwd)

    def test_wrapper_policy_smoke(self):
        backend = os.environ.get('SDD_TEST_POLICY_BACKEND', 'bash')
        self.selected(self.invoke(backend), CURRENT)
        self.request['cli']['policy'] = 'Latest-compatible'
        self.blocked(self.invoke(backend), 'config-invalid')
        self.request['cli'] = {'model_id': None, 'policy': None, 'Policy': 'pinned'}
        self.blocked(self.invoke(backend), 'config-invalid')

    def test_shipped_contracts_have_actual_schemas_and_no_unproved_adoption(self):
        for filename, title in [('model-policy.schema.json', 'model-policy/v1'),
                                ('model-policy-request.schema.json', 'model-policy-request/v1'),
                                ('model-role-config.schema.json', 'model-role-config/v1')]:
            with self.subTest(schema=filename):
                path = ROOT / 'contracts' / filename
                self.assertTrue(path.is_file(), 'Required policy contract is missing: ' + filename)
                schema = json.loads(path.read_text())
                self.assertEqual(schema['$schema'], 'https://json-schema.org/draft/2020-12/schema')
                self.assertEqual(schema['title'], title)
                self.assertIs(schema['additionalProperties'], False)
        policy_path = ROOT / 'contracts/model-policy.v1.json'
        self.assertTrue(policy_path.is_file(), 'Required shared shipped policy is missing')
        policy = json.loads(policy_path.read_text())
        self.assertEqual(set(policy['roles']), set(ROLES))
        self.assertEqual(policy['default_policy'], 'latest-compatible')
        for model in policy['models']:
            self.assertEqual(model['adoption'], [], 'T-006 must not invent new controlled adoption evidence')


if __name__ == '__main__':
    unittest.main(verbosity=2)
