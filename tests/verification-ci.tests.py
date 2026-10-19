#!/usr/bin/env python3
"""Deterministic Actions protocol fixtures; never hosted/native acceptance proof."""
import base64
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tests/verification-ci.py'


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


P = module(ROOT / 'tests/verification-impact.py', 'ci_test_impact')
W = P.workflow_module()
R = W.runner_module()


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def job_key(job, matrix):
    name = job + (' (' + ', '.join(str(v) for v in matrix.values()) + ')' if matrix else '')
    return sha(P.canonical({'name': name}))


def receipt_name(run, attempt, job, matrix):
    return f'verification-receipts-{run}-{attempt}-{job_key(job, matrix)}'


class BoundaryTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.is_file(), 'T-002 collector/aggregate implementation is missing')
        self.ci = module(SCRIPT, 'verification_ci_test')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.scratch = Path(self.temp.name)

    def test_strict_contract_inputs(self):
        for value in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":1e999}', '[]', '{} {}', '\ufeff{}'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.ci.P.strict_json(value)

    def test_result_and_error_all_persisted_field_counterparts(self):
        good: dict[str, Any] = dict(schema='verification-ci-result/v1', status='PASS', reason='verified', run_id='123',
                    api_head_sha='a'*40, tested_revision='b'*40, plan_sha256='c'*64,
                    results=[dict(obligation_id='test:fixture', status='PASS', reason='verified',
                                  job_id=1, source_attempt=1)])
        self.ci.validate_result(good, expected=good)
        changes: dict[str, Any] = dict(schema='wrong', status='FAIL', reason='evidence-missing', run_id='124',
                       api_head_sha='d'*40, tested_revision='e'*40, plan_sha256='f'*64, results=[])
        value: Any
        for field, value in changes.items():
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.ci.validate_result({**good, field: value}, expected=good)
        for field, value in dict(obligation_id='other', status='NOT_SELECTED', reason='other',
                                 job_id=2, source_attempt=2).items():
            bad = copy.deepcopy(good)
            bad['results'][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.ci.validate_result(bad, expected=good)
        error = dict(schema='verification-ci-error/v1', reason='input-invalid', message='Invalid input')
        self.ci.validate_error(error)
        for field, value in dict(schema='other', reason='other', message='').items():
            with self.subTest(error_field=field), self.assertRaises(ValueError):
                self.ci.validate_error({**error, field: value})
        schema = json.loads((ROOT / 'contracts/verification-ci-result.schema.json').read_text())
        self.assertEqual(set(schema['$defs']['result']['required']), set(good))
        self.assertEqual(set(schema['$defs']['error']['required']), set(error))

    def test_zip_safety_complete_before_extraction(self):
        cases = ['../escape.json', '/absolute.json', 'a/../../escape.json', 'C:/escape.json',
                 'a\\escape.json', 'a//b.json', './receipt.json', 'a/../b.json', 'nul\x01.json']
        for name in cases:
            with self.subTest(name=name):
                raw = io.BytesIO()
                with zipfile.ZipFile(raw, 'w') as archive:
                    archive.writestr('valid.json', '{}')
                    archive.writestr(name, '{}')
                target = self.scratch / str(len(list(self.scratch.iterdir())))
                with self.assertRaises(ValueError):
                    self.ci.extract_receipts(raw.getvalue(), target)
                self.assertFalse(target.exists(), 'validation must finish before publishing any member')
        for kind in ('duplicate', 'symlink', 'too-many', 'too-big', 'non-json', 'directory-conflict'):
            with self.subTest(kind=kind):
                raw = io.BytesIO()
                with zipfile.ZipFile(raw, 'w') as archive:
                    if kind == 'symlink':
                        info = zipfile.ZipInfo('link.json')
                        info.create_system = 3
                        info.external_attr = (stat.S_IFLNK | 0o777) << 16
                        archive.writestr(info, 'target')
                    elif kind == 'duplicate':
                        archive.writestr('same.json', '{}')
                        with __import__('warnings').catch_warnings():
                            __import__('warnings').simplefilter('ignore')
                            archive.writestr('same.json', '{}')
                    elif kind == 'too-many':
                        for i in range(4):
                            archive.writestr(f'{i}.json', '{}')
                    elif kind == 'too-big':
                        archive.writestr('huge.json', ' ' * 100)
                    elif kind == 'directory-conflict':
                        archive.writestr('a.json', '{}')
                        archive.writestr('a.json/b.json', '{}')
                    else:
                        archive.writestr('log.txt', 'unrelated log')
                with patch.object(self.ci, 'MAX_MEMBERS', 3), patch.object(self.ci, 'MAX_EXPANDED_BYTES', 50):
                    with self.assertRaises(ValueError):
                        self.ci.extract_receipts(raw.getvalue(), self.scratch / kind)
        with self.assertRaises(ValueError):
            self.ci.extract_receipts(b'not a zip', self.scratch / 'invalid')

    def test_zip_valid_json_payloads_and_create_only(self):
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, 'w') as archive:
            archive.writestr('receipts/', '')
            archive.writestr('receipts/a.json', '{"schema":"fixture"}')
        target = self.scratch / 'valid'
        paths = self.ci.extract_receipts(raw.getvalue(), target)
        self.assertEqual([p.relative_to(target).as_posix() for p in paths], ['receipts/a.json'])
        with self.assertRaises(ValueError):
            self.ci.extract_receipts(raw.getvalue(), target)

    def test_collection_pagination_history_and_get_only(self):
        run = dict(id=123, run_attempt=2, head_sha='a' * 40, event='push',
                   repository={'full_name': 'owner/repo'}, path='.github/workflows/test.yml')
        calls = []
        def request(endpoint):
            calls.append(endpoint)
            if endpoint.endswith('/runs/123'):
                return run, {}
            if '/jobs' in endpoint:
                attempt = int(endpoint.split('/attempts/')[1].split('/')[0])
                second = 'page=2' in endpoint
                job = dict(id=attempt * 10 + int(second), run_id=123, run_attempt=attempt,
                           head_sha='a' * 40, name='fixture ' + str(int(second)))
                headers = {} if second else {'link': '<https://api.github.com' + endpoint + '&page=2>; rel="next"'}
                return {'total_count': 2, 'jobs': [job]}, headers
            return {'total_count': 0, 'artifacts': []}, {}
        with patch.object(self.ci, 'api_get', side_effect=request):
            collection = self.ci.collect('owner/repo', '123', self.scratch / 'collection')
        self.assertEqual(collection['api_version'], '2026-03-10')
        self.assertEqual(len(collection['jobs']), 4)
        self.assertEqual(collection['artifacts'], [])
        self.assertNotIn('status', collection, 'acquisition is not verification')
        self.assertEqual(len(calls), 6)
        self.ci.validate_collection(collection)
        with patch.object(self.ci.subprocess, 'run') as execute:
            execute.return_value = subprocess.CompletedProcess([], 0, b'HTTP/2.0 200 OK\r\n\r\n{}', b'')
            self.ci.api_get('/repos/owner/repo/actions/runs/123')
        argv = execute.call_args.args[0]
        self.assertEqual(argv[:2], ['gh', 'api'])
        self.assertIn('GET', argv)
        self.assertIn('X-GitHub-Api-Version: 2026-03-10', argv)
        self.assertNotIn('--verbose', argv)

    def test_pagination_rejects_partial_duplicate_loop_and_other_origin(self):
        for mode in ('partial', 'duplicate', 'loop', 'other-origin', 'other-resource', 'wrong-total'):
            with self.subTest(mode=mode):
                def request(endpoint):
                    if endpoint.endswith('/runs/123'):
                        return dict(id=123, run_attempt=1, head_sha='a' * 40,
                                    repository={'full_name': 'owner/repo'}), {}
                    if '/jobs' in endpoint:
                        rows = [dict(id=1, run_id=123, run_attempt=1, head_sha='a' * 40)]
                        headers = {}
                        if mode == 'duplicate':
                            rows *= 2
                        elif mode in ('loop', 'other-origin', 'other-resource'):
                            url = ('https://evil.invalid/stolen' if mode == 'other-origin' else
                                   'https://api.github.com/repos/other/repo/actions/runs/123/jobs' if mode == 'other-resource'
                                   else 'https://api.github.com' + endpoint)
                            headers = {'link': f'<{url}>; rel="next"'}
                        return {'total_count': 3 if mode == 'partial' else -1 if mode == 'wrong-total' else 2,
                                'jobs': rows}, headers
                    return {'total_count': 0, 'artifacts': []}, {}
                with patch.object(self.ci, 'api_get', side_effect=request), self.assertRaises(ValueError):
                    self.ci.collect('owner/repo', '123', self.scratch / mode)
                self.assertFalse((self.scratch / mode / 'collection.json').exists())

    def test_collection_field_counterparts_and_schema(self):
        good: dict[str, Any] = dict(schema='verification-ci-observations/v1', repository='owner/repo', run_id='123',
                    api_head_sha='a' * 40, collected_at='2026-10-19T12:00:00Z', api_version='2026-03-10',
                    run={'path': 'run.json', 'sha256': 'b' * 64}, jobs=[{'path': 'jobs/1.json', 'sha256': 'c' * 64}],
                    artifacts=[{'path': 'artifacts/a/r.json', 'sha256': 'd' * 64, 'job_id': 1, 'source_attempt': 1}])
        self.ci.validate_collection(good)
        changes: dict[str, Any] = dict(schema='other', repository='https://evil.invalid', run_id=123, api_head_sha='bad',
                       collected_at='yesterday', api_version='2022-11-28', run={}, jobs=[], artifacts={})
        value: Any
        for field, value in changes.items():
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.ci.validate_collection({**good, field: value})
        for container in ('run', 'jobs', 'artifacts'):
            row = good[container] if container == 'run' else good[container][0]
            for field in row:
                value = '../escape' if field == 'path' else 'invalid' if field == 'sha256' else True
                bad = copy.deepcopy(good)
                (bad[container] if container == 'run' else bad[container][0])[field] = value
                with self.subTest(container=container, field=field), self.assertRaises(ValueError):
                    self.ci.validate_collection(bad)
        for field in ('jobs', 'artifacts'):
            with self.assertRaises(ValueError):
                self.ci.validate_collection({**good, field: good[field] * 2})
        schema = json.loads((ROOT / 'contracts/verification-ci-observations.schema.json').read_text())
        self.assertEqual(set(schema['required']), set(good))
        self.assertFalse(schema['additionalProperties'])

    def test_expanded_name_binding_matrix_order_and_collisions(self):
        workflow: dict[str, Any] = {'jobs': {
            'simple': {'runs-on': 'ubuntu-latest'},
            'matrix-job': {'strategy': {'matrix': {'os': ['ubuntu-latest'], 'lane': ['a', 'b']}},
                           'runs-on': '${{ matrix.os }}'},
            'explicit': {'name': 'custom (${{ matrix.flag }})', 'runs-on': 'ubuntu-latest',
                         'strategy': {'matrix': {'flag': [True, False]}}}}}
        result = self.ci.expanded_jobs(workflow)
        self.assertEqual(set(result), {'simple', 'matrix-job (ubuntu-latest, a)', 'matrix-job (ubuntu-latest, b)',
                                       'custom (true)', 'custom (false)'})
        self.assertEqual(self.ci.name_key('matrix-job (ubuntu-latest, a)'),
                         sha(P.canonical({'name': 'matrix-job (ubuntu-latest, a)'})))
        self.assertNotEqual(self.ci.name_key('matrix-job (ubuntu-latest, a)'), self.ci.name_key('matrix-job (a, ubuntu-latest)'))
        self.assertNotEqual(self.ci.name_key('simple'), self.ci.name_key('Simple'))
        workflow['jobs']['matrix-job']['name'] = 'same'
        with self.assertRaises(ValueError):
            self.ci.expanded_jobs(workflow)
        workflow['jobs'].pop('matrix-job')
        workflow['jobs']['explicit']['name'] = 'simple'
        with self.assertRaises(ValueError):
            self.ci.expanded_jobs(workflow)

    def test_collection_artifact_job_name_binding_and_mismatches(self):
        run = dict(id=123, run_attempt=1, head_sha='a'*40, repository={'full_name':'owner/repo'})
        job = dict(id=42, run_id=123, run_attempt=1, head_sha='a'*40, name='native (ubuntu-latest)')
        name = receipt_name('123', 1, 'native', {'os':'ubuntu-latest'})
        artifact = dict(id=9, name=name, expired=False, workflow_run={'id':123, 'head_sha':'a'*40})
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, 'w') as archive:
            archive.writestr('receipt.json', '{"schema":"verification-receipt/v1"}')
        def run_case(mode):
            selected = copy.deepcopy(artifact)
            jobs = [copy.deepcopy(job)]
            if mode == 'wrong-run':
                selected['workflow_run']['id'] = 124
            elif mode == 'wrong-head':
                selected['workflow_run']['head_sha'] = 'b'*40
            elif mode == 'expired':
                selected['expired'] = True
            elif mode == 'wrong-name':
                selected['name'] = receipt_name('123', 1, 'native', {'os':'macos-latest'})
            elif mode == 'wrong-attempt':
                selected['name'] = receipt_name('123', 2, 'native', {'os':'ubuntu-latest'})
            elif mode == 'ambiguous-name':
                jobs.append({**job, 'id':43})
            def request(endpoint):
                if endpoint.endswith('/runs/123'):
                    return run, {}
                if '/jobs' in endpoint:
                    return {'total_count':len(jobs),'jobs':jobs}, {}
                rows = [selected, {**selected,'id':10}] if mode == 'duplicate-artifact' else [selected]
                return {'total_count':len(rows),'artifacts':rows}, {}
            target = self.scratch / mode
            with patch.object(self.ci, 'api_get', side_effect=request), patch.object(self.ci, 'api_response', return_value=(raw.getvalue(), {})):
                return self.ci.collect('owner/repo', '123', target)
        result = run_case('valid')
        self.assertEqual(len(result['artifacts']), 1)
        self.assertEqual(result['artifacts'][0]['job_id'], 42)
        self.assertEqual(result['artifacts'][0]['source_attempt'], 1)
        self.assertIn(name, result['artifacts'][0]['path'])
        for mode in ('wrong-run','wrong-head','expired','wrong-name','wrong-attempt','ambiguous-name','duplicate-artifact'):
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                run_case(mode)

    def test_transport_failures_redact_headers_and_signed_urls(self):
        secret = b'authorization: fixture-secret https://storage.invalid/file?signature=fixture-secret'
        for result in (subprocess.CompletedProcess([], 1, b'', secret),
                       subprocess.CompletedProcess([], 0, b'HTTP/2.0 403 Forbidden\r\n\r\n' + secret, b''),
                       subprocess.CompletedProcess([], 0, b'HTTP/2.0 200 OK\r\nX-GitHub-Api-Version-Selected: old\r\n\r\n{}', b'')):
            with patch.object(self.ci.subprocess, 'run', return_value=result):
                with self.assertRaises(ValueError) as caught:
                    self.ci.api_get('/repos/owner/repo/actions/runs/123')
            self.assertNotIn('fixture-secret', str(caught.exception))
            self.assertNotIn('signature=', str(caught.exception))
        with patch.object(self.ci.subprocess, 'run', side_effect=subprocess.TimeoutExpired('gh', 60)):
            with self.assertRaises(ValueError):
                self.ci.api_get('/repos/owner/repo/actions/runs/123')
        with patch.object(self.ci.subprocess, 'run') as execute:
            execute.return_value = subprocess.CompletedProcess([], 0, b'HTTP/2.0 200 OK\r\n\r\n{}', b'')
            self.ci.api_get('/repos/owner/repo/actions/runs/123')
            argv = execute.call_args.args[0]
            self.assertIn('--hostname', argv, 'GitHub origin must be explicit')
            self.assertEqual(argv[argv.index('--hostname')+1], 'github.com')

    def test_schema_enums_and_all_properties_match_producers(self):
        observations = json.loads((ROOT / 'contracts/verification-ci-observations.schema.json').read_text())
        result = json.loads((ROOT / 'contracts/verification-ci-result.schema.json').read_text())
        for node in (observations, result['$defs']['result'], result['$defs']['error'],
                     result['$defs']['result']['properties']['results']['items']):
            self.assertEqual(set(node['required']), set(node['properties']))
            self.assertFalse(node['additionalProperties'])
        for name in ('result', 'error'):
            self.assertEqual(set(result['$defs'][name]['properties']['reason']['enum']), self.ci.REASONS)
        self.assertEqual(observations['properties']['api_version']['const'], self.ci.API_VERSION)


    def test_current_workflow_all_receipt_callers_match_existing_profiles(self):
        workflow = W.load_workflow(ROOT / '.github/workflows/test.yml')
        catalog = R.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        weights = R.load_weights(ROOT / 'tests/verification-timings.json')
        obligations = [o for o in W.plan_obligations(workflow, catalog, weights) if o['receipt_required']]
        expected = {
            'Test shared review launch and conditional input contracts': 'ci-shared-python',
            'Run POSIX inventory shard': 'ci-posix-fallback',
            '[deterministic] Test cloud suites, installed packages and current multitarget boundaries': 'ci-cloud',
            '[deterministic] Test portable review-loop prechecks (pwsh)': 'ci-portable-prechecks',
            '[deterministic] Test portable review-loop prechecks': 'ci-portable-prechecks',
            '[deterministic] Test Epic A7 compatibility suites (pwsh)': 'ci-a7-native',
            'Test bump-version loop-gate prerequisite': None,
        }
        self.assertEqual(len(obligations), 14)
        for obligation in obligations:
            with self.subTest(job=obligation['job'], matrix=obligation['matrix'], step=obligation['step']):
                self.assertIn(obligation['step'], expected)
                try:
                    profile = self.ci.receipt_profile(workflow, obligation)
                except ValueError as error:
                    self.fail('existing receipt caller rejected: ' + str(error))
                self.assertEqual(profile, expected[obligation['step']])

    def test_corrupt_deflate_is_typed_error_without_partial_files(self):
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('receipt.json', '{}')
        malformed = bytearray(raw.getvalue())
        offset = 30 + int.from_bytes(malformed[26:28], 'little') + int.from_bytes(malformed[28:30], 'little')
        malformed[offset:offset+2] = b'\xff\xff'
        target = self.scratch / 'bad-deflate'
        try:
            self.ci.extract_receipts(bytes(malformed), target)
        except Exception as error:
            self.assertIsInstance(error, ValueError)
        else:
            self.fail('corrupt compressed data was accepted')
        self.assertFalse(target.exists())
        run = dict(id=123,run_attempt=1,head_sha='a'*40,repository={'full_name':'owner/repo'})
        job = dict(id=1,run_id=123,run_attempt=1,head_sha='a'*40,name='native')
        artifact = dict(id=2,name=receipt_name('123',1,'native',{}),expired=False,
                        workflow_run={'id':123,'head_sha':'a'*40})
        def request(endpoint):
            if endpoint.endswith('/runs/123'):
                return run, {}
            if '/jobs' in endpoint:
                return {'total_count':1,'jobs':[job]}, {}
            return {'total_count':1,'artifacts':[artifact]}, {}
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(self.ci,'api_get',side_effect=request), patch.object(self.ci,'api_response',return_value=(bytes(malformed),{})), contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            try:
                code = self.ci.main(['collect','--repository','owner/repo','--run-id','123',
                                     '--output-dir',str(self.scratch/'failed-collection')])
            except Exception as error:
                self.fail('typed CLI error boundary leaked ' + type(error).__name__)
        self.assertEqual(code,2)
        self.assertFalse(stdout.getvalue())
        self.assertEqual(json.loads(stderr.getvalue())['schema'],'verification-ci-error/v1')
        self.assertFalse((self.scratch/'failed-collection'/'collection.json').exists())
        self.assertFalse((self.scratch/'failed-collection'/'artifacts').exists())



class AggregateFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.scratch = Path(self.temp.name)
        self.root = self.scratch / 'repo'
        self.root.mkdir()
        self.git('init', '-q')
        self.git('config', 'user.name', 'Protocol fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.suite = 'tests/sample.tests.py'
        self.write(self.suite, 'print("fixture execution")\n')
        self.catalog: dict[str, Any] = dict(schema='verification-catalog/v1', suites=[dict(path=self.suite, runtime='python')],
                            profiles={'fixture': [self.suite]},
                            impact=dict(schema='verification-impact-rules/v1', categories=[], dependencies={}))
        self.workflow: dict[str, Any] = {'jobs': {'test': {
            'strategy': {'matrix': {'os': ['ubuntu-latest', 'macos-latest', 'windows-latest']}},
            'runs-on': '${{ matrix.os }}', 'steps': [
                {'name': 'integrity', 'run': 'git diff --exit-code'},
                {'name': 'runner', 'run': 'python3 tests/verification.py --run --profile fixture --receipt receipt.json'}]}}}
        for path in P.PLANNER_FILES:
            if path != 'tests/verification-catalog.json':
                self.write(path, (ROOT / path).read_text())
        self.write('tests/verification-catalog.json', json.dumps(self.catalog))
        self.write('.github/workflows/test.yml', json.dumps(self.workflow))
        self.revision = self.commit('fixture baseline')
        self.plan = P.make_plan(self.root, self.root, 'push', '123', 1, self.revision, self.revision)
        # The producer is the existing real runner. API/native jobs remain fixtures.
        with contextlib.redirect_stdout(io.StringIO()):
            self.receipt, code = R.execute(R.load_catalog(self.root / 'tests/verification-catalog.json', self.root),
                                         [self.suite], self.root, 'fixture')
        self.assertEqual(code, 0)
        self.api_run = dict(id=123, run_attempt=1, head_sha=self.revision, event='push',
                        repository={'full_name': 'owner/repo'}, path='.github/workflows/test.yml', pull_requests=[])
        self.jobs = []
        self.receipts = []
        for i, runner in enumerate(self.workflow['jobs']['test']['strategy']['matrix']['os']):
            self.jobs.append(dict(id=100+i, run_id=123, run_attempt=1, head_sha=self.revision,
                                 name=f'test ({runner})', labels=[runner], runner_id=1000+i,
                                 runner_name=f'host-{i}', status='completed', conclusion='success',
                                 started_at='2026-10-19T10:00:00Z', completed_at='2026-10-19T10:01:00Z',
                                 steps=[dict(name=name, number=n+1, status='completed', conclusion='success',
                                             started_at='2026-10-19T10:00:00Z', completed_at='2026-10-19T10:01:00Z')
                                        for n, name in enumerate(('integrity', 'runner'))]))
            self.receipts.append((100+i, 1, copy.deepcopy(self.receipt), 'test', {'os': runner}))

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True, capture_output=True, text=True).stdout.strip()

    def write(self, path, data):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(data)

    def commit(self, message):
        self.git('add', '.')
        self.git('commit', '-qm', message)
        return self.git('rev-parse', 'HEAD')

    def prepare(self):
        observations = self.scratch / 'observations'
        observations.mkdir(exist_ok=True)
        def persist(path, value):
            target = observations / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(P.canonical(value))
            return {'path': path, 'sha256': sha(target.read_bytes())}
        manifest = dict(schema='verification-ci-observations/v1', repository='owner/repo', run_id='123',
                        api_head_sha=self.api_run['head_sha'], collected_at='2026-10-19T12:00:00Z',
                        api_version='2026-03-10', run=persist('run.json', self.api_run), jobs=[], artifacts=[])
        for attempt in range(1, self.api_run['run_attempt']+1):
            rows = [j for j in self.jobs if j['run_attempt'] == attempt]
            manifest['jobs'].append(persist(f'jobs/{attempt}.json', {'total_count': len(rows), 'jobs': rows}))
        for i, (jid, attempt, receipt, job, matrix) in enumerate(self.receipts):
            name = receipt_name('123', attempt, job, matrix)
            reference = persist(f'artifacts/{name}/receipt-{i}.json', receipt)
            manifest['artifacts'].append({**reference, 'job_id': jid, 'source_attempt': attempt})
        (observations / 'collection.json').write_bytes(P.canonical(manifest))
        self.plan['plan_sha256'] = sha(P.canonical({k: v for k, v in self.plan.items() if k != 'plan_sha256'}))
        plan_path = self.scratch / 'plan.json'
        plan_path.write_bytes(P.canonical(self.plan))
        return plan_path, observations

    def invoke(self, mutate=None, expected=0):
        plan_path, observations = self.prepare()
        if mutate:
            mutate(plan_path, observations)
        command = [sys.executable, '-B', str(SCRIPT), 'aggregate', '--root', str(self.root),
                   '--plan', str(plan_path), '--observations', str(observations), '--run-id', '123',
                   '--api-head-sha', self.api_run['head_sha']]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        raw = result.stderr if expected == 2 else result.stdout
        self.assertTrue(raw.lstrip().startswith('{'), 'missing T-002 JSON protocol: ' + raw)
        payload = json.loads(raw)
        self.assertEqual(payload['schema'], 'verification-ci-error/v1' if expected == 2 else 'verification-ci-result/v1')
        if expected == 2:
            self.assertFalse(result.stdout)
        else:
            self.assertEqual(payload['status'], 'PASS' if expected == 0 else 'FAIL')
        return payload


class AggregateTests(AggregateFixture):
    def test_full_result_consumed_by_predecessor_activation_validator(self):
        result = self.invoke()
        try:
            self.assertEqual(P.validate_result_binding(result, self.plan, True), set())
        except ValueError as error:
            self.fail('aggregate result is incompatible with T-001: ' + str(error))

    def test_TEST019_positive_full_receipts_native_obligations(self):
        result = self.invoke()
        self.assertEqual(len(result['results']), 6)
        self.assertEqual({r['job_id'] for r in result['results']}, {100,101,102})
        self.assertEqual(result['tested_revision'], self.revision)

    def test_TEST020_055_056_failure_cancel_skip_timeout_neutral(self):
        original = copy.deepcopy(self.jobs)
        for conclusion in ('failure', 'cancelled', 'skipped', 'timed_out', 'neutral', 'action_required', None):
            for level in ('job', 'step'):
                with self.subTest(conclusion=conclusion, level=level):
                    self.jobs = copy.deepcopy(original)
                    target = self.jobs[0] if level == 'job' else self.jobs[0]['steps'][1]
                    target['conclusion'] = conclusion
                    result = self.invoke(expected=1)
                    self.assertIn('FAIL', [r['status'] for r in result['results']])

    def test_TEST021_057_absent_malformed_plan_and_empty_evidence(self):
        for raw in (b'{}', b'{"schema":1,"schema":2}', b'[]', b'not-json'):
            self.invoke(lambda path, _obs: path.write_bytes(raw), expected=2)
        self.invoke(lambda path, _obs: path.unlink(), expected=2)
        self.jobs = []
        self.invoke(expected=1)

    def test_TEST058_missing_receipt(self):
        self.receipts = self.receipts[1:]
        self.invoke(expected=1)

    def test_TEST059_empty_receipt_success(self):
        self.receipts[0][2]['results'] = []
        self.invoke(expected=1)

    def test_receipt_persisted_fields_counterparts(self):
        changes: dict[str, Any] = dict(schema='wrong', profile='other', revision='a'*40, revision_after='a'*40,
                       clean_before=False, clean_after=False, reusable=True, catalog_sha256='a'*64,
                       selected=[], results=[])
        original = copy.deepcopy(self.receipts)
        value: Any
        for field, value in changes.items():
            with self.subTest(field=field):
                self.receipts = copy.deepcopy(original)
                self.receipts[0][2][field] = value
                self.invoke(expected=1)
        for field, value in dict(suite='tests/other.tests.py', source_sha256='a'*64,
                                 status='skipped', exit_code=1, seconds=-1).items():
            with self.subTest(field=field):
                self.receipts = copy.deepcopy(original)
                self.receipts[0][2]['results'][0][field] = value
                self.invoke(expected=1)

    def test_TEST022_060_061_062_063_identity_and_hash_mutations(self):
        original = copy.deepcopy(self.jobs)
        for field, value in dict(run_id=999, head_sha='a'*40, id=True, run_attempt=0,
                                 name='other', labels=['macos-latest'], status='in_progress').items():
            with self.subTest(field=field):
                self.jobs = copy.deepcopy(original)
                self.jobs[0][field] = value
                self.invoke(expected=1)
        self.jobs = copy.deepcopy(original) + [copy.deepcopy(original[0])]
        self.invoke(expected=1)
        self.jobs = copy.deepcopy(original)
        self.jobs[0]['steps'].append(copy.deepcopy(self.jobs[0]['steps'][0]))
        self.invoke(expected=1)
        self.jobs = original
        for field in ('catalog_sha256', 'workflow_sha256', 'trusted_planner_sha256'):
            old = self.plan[field]
            self.plan[field] = 'a'*64
            self.invoke(expected=1)
            self.plan[field] = old

    def test_plan_partition_recomputed_not_self_authorized(self):
        original = copy.deepcopy(self.plan)
        for field, value in dict(id='invented', job='other', matrix={}, runner='macos-latest',
                                 step='wrong', command_sha256='a'*64, suites=[], receipt_required=False).items():
            with self.subTest(field=field):
                self.plan = copy.deepcopy(original)
                self.plan['obligations'][1][field] = value
                # A malformed group relation is syntax-invalid; all other mutations are binding failures.
                self.invoke(expected=2 if field == 'job' else 1)
        self.plan = copy.deepcopy(original)
        self.plan['obligations'].pop()
        self.invoke(expected=1)
        self.plan = copy.deepcopy(original)
        self.plan['obligations'].append({**self.plan['obligations'][0], 'id': 'extra'})
        self.invoke(expected=1)

    def test_manifest_hash_and_containment_counterparts(self):
        def corrupt(_plan, obs):
            (obs / 'run.json').write_text('{}')
        self.invoke(corrupt, expected=1)
        def escape(_plan, obs):
            manifest = json.loads((obs / 'collection.json').read_text())
            manifest['run']['path'] = '../outside'
            (obs / 'collection.json').write_text(json.dumps(manifest))
        self.invoke(escape, expected=2)
        def symlink(_plan, obs):
            target = obs / 'run.json'
            target.unlink()
            target.symlink_to(self.scratch / 'plan.json')
        self.invoke(symlink, expected=1)

    def test_TEST023_copied_success_preserves_original_ids_and_attempts(self):
        self.api_run['run_attempt'] = 2
        copies = copy.deepcopy(self.jobs)
        for job in copies:
            job['id'] += 100
            job['run_attempt'] = 2
        self.jobs += copies
        result = self.invoke()
        self.assertEqual({r['source_attempt'] for r in result['results']}, {1})
        self.assertEqual({r['job_id'] for r in result['results']}, {100, 101, 102})
        self.receipts = []
        self.invoke(expected=1)

    def test_TEST023_genuine_rerun_keeps_failed_history(self):
        self.api_run['run_attempt'] = 2
        newer = copy.deepcopy(self.jobs)
        for job in newer:
            job['id'] += 100
            job['run_attempt'] = 2
            job['started_at'] = '2026-10-19T11:00:00Z'
            job['completed_at'] = '2026-10-19T11:01:00Z'
            for step in job['steps']:
                step['started_at'] = job['started_at']
                step['completed_at'] = job['completed_at']
        for job in self.jobs:
            job['conclusion'] = 'failure'
        self.jobs += newer
        self.receipts = [(jid+100, 2, receipt, job, matrix) for jid, _, receipt, job, matrix in self.receipts]
        result = self.invoke()
        self.assertEqual({r['source_attempt'] for r in result['results']}, {2})
        self.assertEqual({r['job_id'] for r in result['results']}, {200, 201, 202})

    def test_rerun_missing_history_ambiguous_lineage_and_relabelled_receipts(self):
        self.api_run['run_attempt'] = 2
        original = copy.deepcopy(self.jobs)
        copied = copy.deepcopy(original)
        for job in copied:
            job.update(id=job['id']+100, run_attempt=2)
        for mode in ('missing', 'ambiguous', 'relabelled'):
            with self.subTest(mode=mode):
                self.jobs = copy.deepcopy(original + copied)
                if mode == 'missing':
                    self.jobs = copy.deepcopy(copied)
                elif mode == 'ambiguous':
                    self.jobs.append({**original[0], 'id': 999})
                else:
                    self.receipts = [(jid+100, 2, receipt, job, matrix) for jid, _, receipt, job, matrix in self.receipts]
                self.invoke(expected=1)

    def use_pr_fixture(self, merge=False):
        predecessor = module(ROOT / 'tests/verification-ci-plan.tests.py', 'ci_plan_fixture')
        fixture = predecessor.ProofTests('test_positive_affected_dependency_partition_and_bound_proof')
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        self.root = fixture.root
        tested = fixture.head
        if merge:
            _, tested = fixture.verified_merge()
        self.plan = fixture.plan(tested_revision=tested)
        self.api_run.update(event='pull_request', head_sha=fixture.head,
                        pull_requests=[{'base': {'sha': fixture.base}, 'head': {'sha': fixture.head}}])
        self.jobs, self.receipts = [], []
        for i, (job_id, job) in enumerate(fixture.workflow['jobs'].items()):
            selected = [o for o in self.plan['obligations'] if o['job'] == job_id]
            self.jobs.append(dict(id=500+i, run_id=123, run_attempt=1, head_sha=fixture.head, name=job_id,
                                 labels=['ubuntu-latest'], runner_id=600+i if selected else None,
                                 runner_name='fixture' if selected else None, status='completed',
                                 conclusion='success' if selected else 'skipped',
                                 started_at='2026-10-19T10:00:00Z' if selected else None,
                                 completed_at='2026-10-19T10:01:00Z' if selected else None,
                                 steps=[dict(name=o['step'], number=n+1, status='completed', conclusion='success',
                                             started_at='2026-10-19T10:00:00Z', completed_at='2026-10-19T10:01:00Z')
                                        for n, o in enumerate(selected)]))
        return fixture

    def test_affected_partition_omissions_and_verified_merge(self):
        self.use_pr_fixture(merge=True)
        self.assertNotEqual(self.plan['api_head_sha'], self.plan['tested_revision'])
        self.assertTrue(self.plan['omissions'])
        result = self.invoke()
        omitted = [r for r in result['results'] if r['status'] == 'NOT_SELECTED']
        self.assertEqual({r['obligation_id'] for r in omitted}, {o['id'] for o in self.plan['omissions']})
        self.assertTrue(all(r['job_id'] is None and r['source_attempt'] is None for r in omitted))
        original = copy.deepcopy(self.plan)
        for mutation in ('missing-omission', 'extra-omission', 'selected-omitted', 'empty-reason', 'wrong-evidence'):
            with self.subTest(mutation=mutation):
                self.plan = copy.deepcopy(original)
                if mutation == 'missing-omission':
                    self.plan['omissions'].pop()
                elif mutation == 'extra-omission':
                    self.plan['omissions'].append({'id': 'invented', 'reason': 'unrelated-category'})
                elif mutation == 'selected-omitted':
                    removed = self.plan['obligations'].pop()
                    self.plan['omissions'].append({'id': removed['id'], 'reason': 'unrelated-category'})
                elif mutation == 'empty-reason':
                    self.plan['omissions'][0]['reason'] = ''
                else:
                    self.plan['activation_evidence'][0]['sha256'] = 'f'*64
                self.invoke(expected=2 if mutation == 'empty-reason' else 1)

    def test_pr_independent_persisted_plan_fields(self):
        fixture = self.use_pr_fixture()
        self.invoke()
        original = copy.deepcopy(self.plan)
        changes: dict[str, Any] = dict(run_id='124', event='push', planning_attempt=2, api_head_sha=fixture.base,
                       tested_revision=fixture.base, base_revision=fixture.head, pr_head_revision=fixture.base,
                       merge_base_revision=fixture.head, catalog_sha256='f'*64, workflow_sha256='f'*64,
                       trusted_planner_sha256='f'*64, changed_path_count=999, groups=['test', 'optional'])
        value: Any
        for field, value in changes.items():
            with self.subTest(field=field):
                self.plan = copy.deepcopy(original)
                self.plan[field] = value
                self.invoke(expected=2 if field == 'event' else 1)
        self.plan = original
        for field in ('base', 'head'):
            self.api_run['pull_requests'][0][field]['sha'] = 'f'*40
            self.invoke(expected=1)
            self.api_run['pull_requests'][0][field]['sha'] = fixture.base if field == 'base' else fixture.head

    def test_history_unstarted_cancel_then_true_success(self):
        self.api_run['run_attempt'] = 2
        new = copy.deepcopy(self.jobs)
        for job in self.jobs:
            job.update(status='completed', conclusion='cancelled', started_at=None, completed_at=None,
                       runner_id=None, runner_name=None, steps=[])
        for job in new:
            job.update(id=job['id']+100, run_attempt=2)
        self.jobs += new
        self.receipts = [(jid+100, 2, receipt, job, matrix) for jid, _, receipt, job, matrix in self.receipts]
        self.invoke()

    def test_receipt_profile_is_exact_invocation_not_equivalent_membership(self):
        self.catalog['profiles']['other'] = [self.suite]
        self.write('tests/verification-catalog.json', json.dumps(self.catalog))
        self.revision = self.commit('equivalent alternate profile')
        self.plan = P.make_plan(self.root, self.root, 'push', '123', 1, self.revision, self.revision)
        self.api_run['head_sha'] = self.revision
        for job in self.jobs:
            job['head_sha'] = self.revision
        for _, _, receipt, _, _ in self.receipts:
            receipt.update(revision=self.revision, revision_after=self.revision, catalog_sha256=self.plan['catalog_sha256'])
        self.invoke()
        self.receipts[0][2]['profile'] = 'other'
        self.invoke(expected=1)

    def test_unexpected_receipt_and_duplicate_selected_receipt_fail(self):
        self.receipts.append(copy.deepcopy(self.receipts[0]))
        self.invoke(expected=1)
        self.receipts.pop()
        self.receipts[0][2]['selected'] = ['tests/other.tests.py']
        self.invoke(expected=1)

    def test_cli_create_only_output_and_fixed_error(self):
        plan_path, observations = self.prepare()
        output = self.scratch / 'result.json'
        command = [sys.executable, '-B', str(SCRIPT), 'aggregate', '--root', str(self.root), '--plan', str(plan_path),
                   '--observations', str(observations), '--run-id', '123', '--api-head-sha', self.revision,
                   '--output', str(output)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), json.loads(output.read_text()))
        before = output.read_bytes()
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(output.read_bytes(), before)
        self.assertFalse(result.stdout)
        for args in ([], ['unknown'], ['collect', '--repository', '--evil', '--run-id', '123', '--output-dir', str(output)]):
            result = subprocess.run([sys.executable, '-B', str(SCRIPT), *args], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(json.loads(result.stderr)['schema'], 'verification-ci-error/v1')

    def test_second_planning_attempt_without_specific_planner_job(self):
        self.api_run['run_attempt'] = 2
        current = copy.deepcopy(self.jobs)
        for job in current:
            job.update(id=job['id']+100,run_attempt=2,started_at='2026-10-19T11:00:00Z',completed_at='2026-10-19T11:01:00Z')
            for step in job['steps']:
                step.update(started_at=job['started_at'],completed_at=job['completed_at'])
        self.jobs += current
        self.plan = P.make_plan(self.root,self.root,'push','123',2,self.revision,self.revision)
        self.receipts = [(jid+100,2,receipt,job,matrix) for jid,_,receipt,job,matrix in self.receipts]
        self.invoke()
        self.plan['planning_attempt'] = 3
        self.invoke(expected=1)

    def test_direct_work_rejects_dirty_checked_out_source(self):
        self.workflow['jobs']['test']['steps'][1]['run'] = 'python3 tests/sample.tests.py'
        self.write('.github/workflows/test.yml', json.dumps(self.workflow))
        self.revision = self.commit('direct execution fixture')
        self.plan = P.make_plan(self.root, self.root, 'push', '123', 1, self.revision, self.revision)
        self.api_run['head_sha'] = self.revision
        for job in self.jobs:
            job['head_sha'] = self.revision
        self.receipts = []
        self.invoke()
        self.write(self.suite, 'raise SystemExit(7)\n')
        self.invoke(expected=1)

    def test_new_planner_attempt_requires_fresh_execution(self):
        self.workflow['jobs']['plan'] = {'name':'Plan verification', 'runs-on':'ubuntu-latest',
                                         'steps':[{'name':'Plan', 'run':'echo fixture-plan'}]}
        self.write('.github/workflows/test.yml', json.dumps(self.workflow))
        self.revision = self.commit('planner execution fixture')
        self.api_run.update(head_sha=self.revision, run_attempt=2)
        self.jobs.append(dict(id=103, run_id=123, run_attempt=1, head_sha=self.revision, name='Plan verification',
                              labels=['ubuntu-latest'], runner_id=1003, runner_name='planner',
                              status='completed', conclusion='success', started_at='2026-10-19T10:00:00Z',
                              completed_at='2026-10-19T10:01:00Z', steps=[dict(name='Plan', number=1,
                              status='completed', conclusion='success', started_at='2026-10-19T10:00:00Z',
                              completed_at='2026-10-19T10:01:00Z')]))
        for job in self.jobs:
            job['head_sha'] = self.revision
        old = copy.deepcopy(self.jobs)
        latest = copy.deepcopy(old)
        for job in latest:
            job.update(id=job['id']+100, run_attempt=2, started_at='2026-10-19T11:00:00Z',
                       completed_at='2026-10-19T11:01:00Z')
            for step in job['steps']:
                step.update(started_at=job['started_at'], completed_at=job['completed_at'])
        self.jobs = old + latest
        self.plan = P.make_plan(self.root, self.root, 'push', '123', 2, self.revision, self.revision)
        self.receipts = [(jid+100, 2, {**receipt,'revision':self.revision,'revision_after':self.revision,
                                     'catalog_sha256':self.plan['catalog_sha256']},job,matrix)
                         for jid,_,receipt,job,matrix in self.receipts]
        self.invoke()
        # A freshly executed planner cannot relabel inherited workload as fresh.
        self.jobs[4] = {**copy.deepcopy(old[0]), 'id':200, 'run_attempt':2}
        self.receipts[0] = (100, 1, self.receipts[0][2], 'test', {'os':'ubuntu-latest'})
        self.invoke(expected=1)

    def test_copied_job_missing_original_despite_other_history_fails(self):
        self.api_run['run_attempt'] = 2
        original = copy.deepcopy(self.jobs)
        copied = copy.deepcopy(original)
        for job in copied:
            job.update(id=job['id']+100, run_attempt=2)
        self.jobs = original[1:] + copied
        self.receipts[0] = (200, 2, self.receipts[0][2], 'test', {'os':'ubuntu-latest'})
        self.invoke(expected=1)


class A9AggregateTests(AggregateFixture):
    """Actual Git/event reconstruction with simulated Actions observations only."""

    def setUp(self):
        super().setUp()
        self.ci = module(SCRIPT, 'a9_ci_test')
        live = W.load_workflow(ROOT / '.github/workflows/test.yml')
        self.workflow['env'] = live['env']
        for job in ('a9-advisory-inputs', 'a9-advisory'):
            self.workflow['jobs'][job] = copy.deepcopy(live['jobs'][job])
        self.write('.github/workflows/test.yml', json.dumps(self.workflow))
        self.a9_base = self.commit('synthetic exact A9 workflow')
        self.normal_jobs = copy.deepcopy(self.jobs)

    def configure(self, event='push', base_context=False, head_context=False):
        self.git('checkout', '-q', '--detach', self.a9_base)
        if base_context:
            self.write('sdd/project-context.yaml', 'fixture: true\n')
        self.base = self.commit('synthetic base context') if base_context else self.a9_base
        if head_context:
            self.write('sdd/project-context.yaml', 'fixture: head\n')
        elif base_context:
            (self.root / 'sdd/project-context.yaml').unlink()
        self.write('docs/change.txt', 'synthetic PR head\n')
        self.revision = self.commit('synthetic exact head')
        kwargs = dict(base=self.base, head=self.revision, force_full='true') if event == 'pull_request' else {}
        with tempfile.TemporaryDirectory(dir=self.scratch) as directory:
            trusted = self.root
            if event == 'pull_request':
                trusted = Path(directory) / 'trusted'
                subprocess.run(['git', 'clone', '-q', '--no-checkout', str(self.root), str(trusted)],
                               check=True, capture_output=True)
                subprocess.run(['git', '-C', str(trusted), 'checkout', '-q', '--detach', self.base],
                               check=True, capture_output=True)
            self.plan = P.make_plan(self.root, trusted, event, '123', 1, self.revision, self.revision, **kwargs)
        self.api_run.update(event=event, head_sha=self.revision, run_attempt=1,
                            pull_requests=[{'base': {'sha': self.base}, 'head': {'sha': self.revision}}]
                            if event == 'pull_request' else [])
        self.jobs = copy.deepcopy(self.normal_jobs)
        for job in self.jobs:
            job['head_sha'] = self.revision
        with contextlib.redirect_stdout(io.StringIO()):
            receipt, code = R.execute(R.load_catalog(self.root / 'tests/verification-catalog.json', self.root),
                                     [self.suite], self.root, 'fixture')
        self.assertEqual(code, 0)
        self.receipts = [(j['id'], 1, copy.deepcopy(receipt), 'test', {'os': j['labels'][0]}) for j in self.jobs]
        active = event == 'pull_request' and (base_context or head_context)
        for jid, key in [(300, 'a9-advisory-inputs'), (301, 'a9-advisory')]:
            job = copy.deepcopy(self.jobs[0])
            job.update(id=jid, name=self.workflow['jobs'][key]['name'], labels=['ubuntu-latest'], steps=[])
            for number, step in enumerate(self.workflow['jobs'][key]['steps'], 1):
                job['steps'].append(dict(name=step['name'], number=number, status='completed', conclusion='success',
                                         started_at=job['started_at'], completed_at=job['completed_at']))
            if key == 'a9-advisory-inputs' and event != 'pull_request':
                for step in job['steps'][:-1]:
                    step.update(conclusion='skipped', started_at=None, completed_at=None)
            if key == 'a9-advisory' and not active:
                job.update(conclusion='skipped', runner_id=0, runner_name='', labels=[], steps=[])
                # Real admitted skipped observations can carry timestamps, including reversed rerun times.
                job['completed_at'] = job['started_at']
            self.jobs.append(job)
        return active

    def advisory_rows(self, result):
        ids = {o['id'] for o in self.plan['obligations'] if o['job'] == 'a9-advisory'}
        return [row for row in result['results'] if row['obligation_id'] in ids]

    def check_complete(self, result, active):
        self.assertEqual(self.plan['mode'], 'full')
        self.assertEqual(self.plan['omissions'], [])
        self.assertEqual({r['obligation_id'] for r in result['results']}, {o['id'] for o in self.plan['obligations']})
        self.assertEqual(P.validate_result_binding(result, self.plan, True, root=self.root, workflow=self.workflow), set())
        self.assertTrue(self.advisory_rows(result))
        for row in self.advisory_rows(result):
            self.assertEqual((row['status'], row['reason'], row['job_id'], row['source_attempt']),
                             ('PASS', 'verified', 301, 1) if active else
                             ('EXPECTED_SKIP', 'advisory-inactive', None, None))
        if not active:
            with self.assertRaises(ValueError):
                P.validate_result_binding(result, self.plan, True)

    def test_TEST024_event_and_git_context_positive_branches(self):
        for event, base, head in [('push', False, True), ('merge_group', False, False),
                                  ('workflow_dispatch', False, False), ('release', False, False),
                                  ('pull_request', False, False), ('pull_request', True, False),
                                  ('pull_request', False, True), ('pull_request', True, True)]:
            with self.subTest(event=event, base=base, head=head):
                active = self.configure(event, base, head)
                self.check_complete(self.invoke(), active)

    def test_TEST024_inactive_success_and_active_skip_are_failures(self):
        self.configure('pull_request', False, True)
        successful = copy.deepcopy(self.jobs[-1])
        self.check_complete(self.invoke(), True)
        self.jobs[-1].update(conclusion='skipped', runner_id=0, runner_name='', steps=[], labels=[])
        self.invoke(expected=1)
        self.configure()
        successful['head_sha'] = self.revision
        self.jobs[-1] = successful
        self.invoke(expected=1)

    def test_TEST024_detector_and_skip_observation_mismatch_matrix(self):
        self.configure()
        original = copy.deepcopy(self.jobs)
        changes: list[tuple[str, int, str, Any]] = [('detector-missing', -2, 'remove', None), ('advisory-missing', -1, 'remove', None)]
        for index in (-2, -1):
            for field, value in dict(run_id=124, head_sha='f'*40, id=True, run_attempt=2,
                                     name='similar A9 name', status='in_progress', conclusion='failure').items():
                changes.append((str(index)+'-'+field, index, field, value))
        for field, value in dict(labels=['windows-latest'], runner_id=0, runner_name='',
                                 started_at=None, completed_at=None).items():
            changes.append(('detector-'+field, -2, field, value))
        for field, value in dict(labels=['ubuntu-latest'], runner_id=999, runner_name='executed',
                                 steps=[copy.deepcopy(original[-2]['steps'][-1])]).items():
            changes.append(('skip-'+field, -1, field, value))
        for label, index, field, value in changes:
            with self.subTest(mutation=label):
                self.jobs = copy.deepcopy(original)
                if field == 'remove':
                    self.jobs.pop(index)
                else:
                    self.jobs[index][field] = value
                self.invoke(expected=1)
        for field, value in dict(name='Detect something else', status='in_progress', conclusion='failure',
                                 number=True, started_at=None, completed_at=None).items():
            with self.subTest(detector_step=field):
                self.jobs = copy.deepcopy(original)
                self.jobs[-2]['steps'][-1][field] = value
                self.invoke(expected=1)
        self.jobs = copy.deepcopy(original)
        self.jobs[-2]['steps'].pop()
        self.invoke(expected=1)
        self.jobs = copy.deepcopy(original)
        self.jobs[-2]['steps'].append(copy.deepcopy(self.jobs[-2]['steps'][-1]))
        self.invoke(expected=1)
        self.jobs = original
        self.check_complete(self.invoke(), False)

    def test_TEST024_rerun_skipped_timestamps_and_detector_lineage(self):
        self.configure()
        original = copy.deepcopy(self.jobs)
        copied = copy.deepcopy(original)
        for job in copied:
            job.update(id=job['id']+1000, run_attempt=2)
        copied[-1].update(started_at='2026-10-19T11:00:00Z', completed_at='2026-10-19T10:00:00Z')
        self.api_run['run_attempt'] = 2
        self.jobs = original + copied
        self.check_complete(self.invoke(), False)
        for index in (-1, -2):
            with self.subTest(missing_original=index):
                self.jobs = original[:index] + original[index+1:] + copied if index != -1 else original[:-1] + copied
                self.invoke(expected=1)
        self.jobs = copy.deepcopy(original + copied)
        self.jobs[-2]['runner_id'] += 1
        self.invoke(expected=1)
        self.jobs = copy.deepcopy(original + copied)
        self.jobs[-2] = copy.deepcopy(copied[-2])
        # A fresh plan cannot reinterpret copied detector execution as fresh.
        self.plan = P.make_plan(self.root, self.root, 'push', '123', 2, self.revision, self.revision)
        for job in self.jobs[5:8]:
            job.update(started_at='2026-10-19T11:00:00Z', completed_at='2026-10-19T11:01:00Z')
            for step in job['steps']:
                step.update(started_at=job['started_at'], completed_at=job['completed_at'])
        self.receipts = [(jid+1000, 2, receipt, job, matrix) for jid, _, receipt, job, matrix in self.receipts]
        self.invoke(expected=1)
        detector = self.jobs[-2]
        detector.update(started_at='2026-10-19T11:00:00Z', completed_at='2026-10-19T11:01:00Z')
        for step in detector['steps']:
            if step['conclusion'] == 'success':
                step.update(started_at=detector['started_at'], completed_at=detector['completed_at'])
        self.check_complete(self.invoke(), False)

    def test_TEST024_unknown_projection_and_bound_event_fail_closed(self):
        self.configure()
        self.jobs[-1].update(conclusion='success', labels=['ubuntu-latest'], runner_id=1000, runner_name='host-0',
                             steps=[dict(name=self.workflow['jobs']['a9-advisory']['steps'][-1]['name'], number=3,
                                         status='completed', conclusion='success', started_at='2026-10-19T10:00:00Z',
                                         completed_at='2026-10-19T10:01:00Z')], completed_at='2026-10-19T10:01:00Z')
        plan_path, observations = self.prepare()
        # Sensitivity control: absence of A9 semantics is not proof of inactivity.
        with patch.object(self.ci.W, 'a9_activation', return_value=None):
            result = self.ci.aggregate(self.root, self.plan, observations, '123', self.revision)
        self.assertEqual(result['status'], 'FAIL')
        self.workflow['env'] = {'A9_EVENT_NAME': 'push'}
        self.write('.github/workflows/test.yml', json.dumps(self.workflow))
        self.revision = self.commit('synthetic unknown A9 projection')
        self.plan = P.make_plan(self.root, self.root, 'push', '123', 1, self.revision, self.revision)
        self.api_run['head_sha'] = self.revision
        for job in self.jobs:
            job['head_sha'] = self.revision
        for _, _, receipt, _, _ in self.receipts:
            receipt.update(revision=self.revision, revision_after=self.revision)
        self.invoke(expected=1)
        self.configure('pull_request', False, False)
        self.api_run['event'] = 'push'
        self.invoke(expected=1)

    def test_TEST024_result_shape_and_consumer_counterparts(self):
        schema = json.loads((ROOT / 'contracts/verification-ci-result.schema.json').read_text())
        item = schema['$defs']['result']['properties']['results']['items']
        self.assertIn('EXPECTED_SKIP', item['properties']['status']['enum'])
        self.assertTrue(any(c.get('if', {}).get('properties', {}).get('status', {}).get('const') == 'EXPECTED_SKIP'
                            for c in item['allOf']))
        self.configure()
        result = self.invoke()
        self.ci.validate_result(result)
        self.check_complete(result, False)
        row = self.advisory_rows(result)[0]
        index = result['results'].index(row)
        for field, value in dict(reason='verified', job_id=1, source_attempt=1, status='PASS').items():
            bad = copy.deepcopy(result)
            bad['results'][index][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.ci.validate_result(bad)
        for mutation in ('other-obligation', 'omission', 'fake-execution', 'hide-failure'):
            bad = copy.deepcopy(result)
            if mutation == 'other-obligation':
                bad['results'][0].update(status='EXPECTED_SKIP', reason='advisory-inactive', job_id=None, source_attempt=None)
            elif mutation == 'omission':
                bad['results'][index].update(status='NOT_SELECTED', reason='unrelated-category')
            elif mutation == 'fake-execution':
                bad['results'][index].update(status='PASS', reason='verified', job_id=301, source_attempt=1)
            else:
                bad['results'][0].update(status='FAIL', reason='execution-failed')
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                P.validate_result_binding(bad, self.plan, True, root=self.root, workflow=self.workflow)


class Cycle1RegressionTests(AggregateFixture):
    """Real collector/aggregate CLIs, with a local fake gh transport and real ZIPs."""

    def setUp(self):
        super().setUp()
        self.ci = module(SCRIPT, 'cycle1_ci')
        self.serial = 0
        self.bin = self.scratch / 'bin'
        self.bin.mkdir()
        fake = self.bin / 'gh'
        fake.write_text('#!' + sys.executable + '\n' + '''import base64,json,sys
from pathlib import Path
args=sys.argv[1:]
assert args[0]=='api' and args[args.index('--method')+1]=='GET'
assert 'X-GitHub-Api-Version: 2026-03-10' in args
responses=json.loads((Path(__file__).parent/'responses.json').read_text())
sys.stdout.buffer.write(b'HTTP/2.0 200 OK\\r\\n\\r\\n'+base64.b64decode(responses[args[-1]]))
''')
        fake.chmod(0o755)
        self.environment = {**os.environ, 'PATH': str(self.bin) + os.pathsep + os.environ['PATH']}
        self.original_jobs = copy.deepcopy(self.jobs)
        self.original_receipts = copy.deepcopy(self.receipts)

    def collect_cli(self, mutate=None, expected=0):
        self.serial += 1
        target = self.scratch / ('collected-' + str(self.serial))
        prefix = '/repos/owner/repo/actions'
        responses: dict[str, Any] = {prefix + '/runs/123': copy.deepcopy(self.api_run)}
        for attempt in range(1, self.api_run['run_attempt'] + 1):
            rows = [copy.deepcopy(j) for j in self.jobs if j['run_attempt'] == attempt]
            responses[prefix + f'/runs/123/attempts/{attempt}/jobs?per_page=100'] = dict(total_count=len(rows), jobs=rows)
        artifacts = []
        for i, (_jid, attempt, receipt, job, matrix) in enumerate(self.receipts, 1):
            artifacts.append(dict(id=i, name=receipt_name('123', attempt, job, matrix), expired=False,
                                  workflow_run=dict(id=123, head_sha=self.api_run['head_sha'])))
            raw = io.BytesIO()
            with zipfile.ZipFile(raw, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr('receipt.json', P.canonical(receipt))
            responses[prefix + f'/artifacts/{i}/zip'] = raw.getvalue()
        responses[prefix + '/runs/123/artifacts?per_page=100'] = dict(total_count=len(artifacts), artifacts=artifacts)
        if mutate:
            mutate(responses)
        wire = {endpoint: base64.b64encode(value if isinstance(value, bytes) else P.canonical(value)).decode()
                for endpoint, value in responses.items()}
        (self.bin / 'responses.json').write_text(json.dumps(wire))
        command = [sys.executable, '-B', str(SCRIPT), 'collect', '--repository', 'owner/repo',
                   '--run-id', '123', '--output-dir', str(target)]
        result = subprocess.run(command, env=self.environment, capture_output=True, text=True)
        self.assertNotIn('Traceback', result.stdout + result.stderr)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertFalse(result.stdout)
        if expected:
            error = json.loads(result.stderr)
            self.ci.validate_error(error)
            self.assertFalse((target / 'collection.json').exists(), 'failed acquisition cannot publish success manifest')
        else:
            self.assertFalse(result.stderr)
            manifest = json.loads((target / 'collection.json').read_text())
            self.ci.validate_collection(manifest)
            self.assertEqual(len(manifest['artifacts']), len(self.receipts), 'all source-attempt receipts must be retained')
            self.assertEqual(len(manifest['jobs']), self.api_run['run_attempt'])
        return target

    def aggregate_cli(self, observations, expected=0):
        self.serial += 1
        plan_path = self.scratch / ('bound-plan-' + str(self.serial) + '.json')
        plan_path.write_bytes(P.canonical(self.plan))
        output = self.scratch / ('result-' + str(self.serial) + '.json')
        command = [sys.executable, '-B', str(SCRIPT), 'aggregate', '--root', str(self.root),
                   '--plan', str(plan_path), '--observations', str(observations), '--run-id', '123',
                   '--api-head-sha', self.api_run['head_sha'], '--output', str(output)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotIn('Traceback', result.stdout + result.stderr)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        payload = json.loads(result.stderr if expected == 2 else result.stdout)
        if expected == 2:
            self.ci.validate_error(payload)
            self.assertFalse(output.exists())
            self.assertFalse(result.stdout)
        else:
            self.ci.validate_result(payload)
            self.assertEqual(payload['status'], 'FAIL' if expected else 'PASS')
            self.assertEqual(json.loads(output.read_text()), payload)
            self.assertFalse(result.stderr)
        return payload

    def rerun(self, partial=False, copied_intermediate=False):
        old = copy.deepcopy(self.original_jobs)
        old_receipts = copy.deepcopy(self.original_receipts)
        current = copy.deepcopy(old)
        attempt = 3 if copied_intermediate else 2
        for index, job in enumerate(old):
            if not partial or index == 0:
                job['conclusion'] = 'failure'
                job['steps'][-1]['conclusion'] = 'failure'
                old_receipts[index][2]['results'][0].update(status='failed', exit_code=1)
        for index, job in enumerate(current):
            job.update(id=job['id'] + (attempt - 1) * 100, run_attempt=attempt)
            if not partial or index == 0:
                job.update(started_at='2026-10-19T11:00:00Z', completed_at='2026-10-19T11:01:00Z')
                for step in job['steps']:
                    step.update(started_at=job['started_at'], completed_at=job['completed_at'])
        middle = []
        if copied_intermediate:
            middle = copy.deepcopy(old)
            for job in middle:
                job.update(id=job['id'] + 100, run_attempt=2)
        self.jobs = old + middle + current
        self.receipts = old_receipts + [(jid + (attempt - 1) * 100, attempt, copy.deepcopy(receipt), key, matrix)
                                        for index, (jid, _, receipt, key, matrix) in enumerate(self.original_receipts)
                                        if not partial or index == 0]
        self.api_run['run_attempt'] = attempt

    def test_RT008_collector_to_aggregate_retains_failed_history_for_genuine_and_partial_reruns(self):
        self.aggregate_cli(self.collect_cli())
        for partial in (False, True):
            with self.subTest(partial=partial):
                self.rerun(partial)
                result = self.aggregate_cli(self.collect_cli())
                expected = {(200, 2), (101, 1), (102, 1)} if partial else {(200, 2), (201, 2), (202, 2)}
                self.assertEqual({(row['job_id'], row['source_attempt']) for row in result['results']}, expected)

    def test_RT008_historical_receipts_cannot_replace_current_required_proof(self):
        for mode in ('missing-current', 'failed-current', 'unselected-current', 'malformed-current'):
            with self.subTest(mode=mode):
                self.rerun()
                if mode == 'missing-current':
                    self.receipts.pop()
                elif mode == 'failed-current':
                    self.receipts[-1][2]['results'][0].update(status='failed', exit_code=1)
                elif mode == 'unselected-current':
                    self.receipts[-1][2]['selected'] = []
                else:
                    self.receipts[-1][2]['results'] = [None]
                self.aggregate_cli(self.collect_cli(), expected=1)
        self.rerun()
        self.aggregate_cli(self.collect_cli())

    def test_RT008_copied_observation_id_is_not_historical_execution_origin(self):
        self.rerun(copied_intermediate=True)
        for job in self.jobs[:6]:
            job['conclusion'] = 'success'
            job['steps'][-1]['conclusion'] = 'success'
        for _, _, receipt, _, _ in self.receipts[:3]:
            receipt['results'][0].update(status='passed', exit_code=0)
        self.aggregate_cli(self.collect_cli())
        jid, _, receipt, key, matrix = self.receipts[0]
        self.receipts.append((jid + 100, 2, copy.deepcopy(receipt), key, matrix))
        # Collector binds the artifact to a real API job instance. The aggregate must
        # still reject this copied observation ID as a fabricated execution source.
        self.aggregate_cli(self.collect_cli(), expected=1)
        self.receipts.pop()
        self.aggregate_cli(self.collect_cli())

    def test_RT009_collect_nested_json_types_return_typed_cli_errors(self):
        self.collect_cli()
        prefix = '/repos/owner/repo/actions'
        for value in (None, 7, 'scalar', [], [1]):
            for surface in ('repository', 'job', 'artifact', 'workflow_run'):
                with self.subTest(surface=surface, value=value):
                    def mutate(responses):
                        if surface == 'repository':
                            responses[prefix + '/runs/123']['repository'] = value
                        elif surface == 'job':
                            responses[prefix + '/runs/123/attempts/1/jobs?per_page=100']['jobs'][0] = value
                        else:
                            rows = responses[prefix + '/runs/123/artifacts?per_page=100']['artifacts']
                            if surface == 'artifact':
                                rows[0] = value
                            else:
                                rows[0]['workflow_run'] = value
                    self.collect_cli(mutate, expected=2)
        self.collect_cli()

    def test_RT009_aggregate_hash_consistent_nested_json_types_return_typed_failures(self):
        observations = self.collect_cli()
        original_manifest = json.loads((observations / 'collection.json').read_text())
        original_run = json.loads((observations / 'run.json').read_text())
        jobs_reference = original_manifest['jobs'][0]
        job_path = observations / jobs_reference['path']
        original_page = json.loads(job_path.read_text())
        self.aggregate_cli(observations)
        for value in (None, 7, 'scalar', [], [1]):
            for surface in ('repository', 'job', 'step', 'steps'):
                with self.subTest(surface=surface, value=value):
                    manifest, run, page = (copy.deepcopy(v) for v in (original_manifest, original_run, original_page))
                    if surface == 'repository':
                        run['repository'] = value
                    elif surface == 'job':
                        page['jobs'][0] = value
                    elif surface == 'step':
                        page['jobs'][0]['steps'][0] = value
                    else:
                        page['jobs'][0]['steps'] = value
                    (observations / 'run.json').write_bytes(P.canonical(run))
                    job_path.write_bytes(P.canonical(page))
                    manifest['run']['sha256'] = sha((observations / 'run.json').read_bytes())
                    manifest['jobs'][0]['sha256'] = sha(job_path.read_bytes())
                    (observations / 'collection.json').write_bytes(P.canonical(manifest))
                    self.aggregate_cli(observations, expected=1)
        (observations / 'run.json').write_bytes(P.canonical(original_run))
        job_path.write_bytes(P.canonical(original_page))
        original_manifest['run']['sha256'] = sha((observations / 'run.json').read_bytes())
        original_manifest['jobs'][0]['sha256'] = sha(job_path.read_bytes())
        (observations / 'collection.json').write_bytes(P.canonical(original_manifest))
        self.aggregate_cli(observations)


if __name__ == '__main__':
    unittest.main(verbosity=2)
