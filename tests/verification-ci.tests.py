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
import shutil
import socket
import warnings
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

    def test_pr_rebuild_binds_parser_lock_closure_not_unrelated_graph(self):
        fixture = self.use_pr_fixture()
        lock_path = 'mcp/sdd-forge-mcp/package-lock.json'
        parser_entry = {'version': '5.4.3', 'resolved': 'https://registry.npmjs.org/js-yaml/-/js-yaml-5.4.3.tgz',
                        'integrity': 'sha512-yzzNtgczwgoVHNigCyKTXcQJU4Y8t/ikU4UxXW0BvrLfHTGWZhsNcOT2s/a7vn81/'
                                     '4KqVnNmHjaUEPlvWnNwVw==',
                        'license': 'MIT', 'dependencies': {'argparse': '^2.0.1'}, 'bin': {'js-yaml': 'bin/js-yaml.mjs'}}
        base_lock = {'lockfileVersion': 3, 'packages': {
            '': {'dependencies': {'js-yaml': '^5.4.3', 'unrelated': '^1.0.0'}},
            'node_modules/js-yaml': parser_entry,
            'node_modules/argparse': {'version': '2.0.1', 'integrity': 'sha512-argparse', 'license': 'Python-2.0'},
            'node_modules/unrelated': {'version': '1.0.0', 'integrity': 'sha512-old'}}}
        fixture.git('checkout', '-q', fixture.base)
        fixture.write(lock_path, json.dumps(base_lock))
        fixture.base = fixture.commit('trusted base parser lock')
        subprocess.run(['git', '-C', str(fixture.trusted), 'fetch', '-q', str(fixture.root), fixture.base], check=True)
        subprocess.run(['git', '-C', str(fixture.trusted), 'checkout', '-q', fixture.base], check=True)
        fixture.write('docs/guide.txt', 'security patch head')
        fixture.head = fixture.commit('subject head')
        package = {'name': 'js-yaml', 'version': '5.4.3', 'main': './dist/js-yaml.cjs.js'}
        # The planner inventory binds the installed parser bytes copied into the trusted base.
        (fixture.trusted / 'mcp/sdd-forge-mcp/node_modules/js-yaml').mkdir(parents=True)
        (fixture.trusted / 'mcp/sdd-forge-mcp/node_modules/js-yaml/package.json').write_text(json.dumps(package))
        parser_code = 'module.exports = {}; // bounded parser-byte fixture\n'
        parser_file = 'mcp/sdd-forge-mcp/node_modules/js-yaml/dist/js-yaml.cjs.js'
        (fixture.trusted / parser_file).parent.mkdir()
        (fixture.trusted / parser_file).write_text(parser_code)
        self.plan = fixture.plan()
        run = dict(self.api_run, head_sha=fixture.head,
                   pull_requests=[{'base': {'sha': fixture.base}, 'head': {'sha': fixture.head}}])
        self.plan['api_head_sha'] = fixture.head
        ci = module(SCRIPT, 'parser_closure_ci')
        installed = self.scratch / 'installed'

        def rebuild(lock, manifest=package, code=parser_code):
            shutil.rmtree(installed, ignore_errors=True)
            (installed / 'mcp/sdd-forge-mcp/node_modules/js-yaml').mkdir(parents=True)
            (installed / 'mcp/sdd-forge-mcp/node_modules/js-yaml/package.json').write_text(json.dumps(manifest))
            (installed / parser_file).parent.mkdir()
            (installed / parser_file).write_text(code)
            (installed / lock_path).write_text(json.dumps(lock))
            with patch.object(ci, 'ROOT', installed):
                return ci.rebuild_plan(fixture.root, run, self.plan)

        unrelated = copy.deepcopy(base_lock)
        unrelated['packages']['node_modules/unrelated'].update(version='1.0.1', integrity='sha512-new')
        unrelated['packages']['node_modules/added'] = {'version': '3.0.0'}
        self.assertIsNotNone(rebuild(unrelated))
        # This is the existing canonical-plan check, not a new parser trust mechanism.
        with self.assertRaisesRegex(ValueError, 'plan disagrees with independent trusted reconstruction'):
            rebuild(unrelated, code=parser_code + '// changed without changing package metadata\n')
        for raw in ('[]', '{"packages":null}', '{"packages":[]}', '{',
                    '{"packages":{},"packages":{}}'):
            with self.subTest(malformed=raw), self.assertRaises(ValueError):
                ci.parser_lock_closure(raw)
        for name in ('js-yaml', 'argparse'):
            for field in ('dependencies', 'optionalDependencies', 'peerDependencies'):
                for value in ([], None, 'argparse'):
                    malformed = copy.deepcopy(base_lock)
                    malformed['packages']['node_modules/' + name][field] = value
                    with self.subTest(package=name, field=field, value=value), self.assertRaises(ValueError):
                        ci.parser_lock_closure(json.dumps(malformed))
            for value in ([], None, 'package'):
                malformed = copy.deepcopy(base_lock)
                malformed['packages']['node_modules/' + name] = value
                with self.subTest(entry=name, value=value), self.assertRaises(ValueError):
                    ci.parser_lock_closure(json.dumps(malformed))
        for field in ('dependencies', 'optionalDependencies', 'peerDependencies'):
            unsupported = copy.deepcopy(base_lock)
            unsupported['packages']['node_modules/argparse'][field] = {'extra': '^1.0.0'}
            with self.subTest(argparse=field), self.assertRaises(ValueError):
                ci.parser_lock_closure(json.dumps(unsupported))
        unsupported = copy.deepcopy(base_lock)
        unsupported['packages']['node_modules/argparse/node_modules/extra'] = {'version': '1.0.0'}
        with self.assertRaises(ValueError):
            ci.parser_lock_closure(json.dumps(unsupported))
        drifts = {}
        for field, value in (('version', '5.4.4'), ('resolved', 'https://example.invalid/js-yaml.tgz'),
                             ('integrity', 'sha512-drift'), ('dependencies', {'argparse': '^2.0.2'}),
                             ('bin', {'js-yaml': 'bin/other.mjs'})):
            drifts['parser-' + field] = copy.deepcopy(base_lock)
            drifts['parser-' + field]['packages']['node_modules/js-yaml'][field] = value
        drifts['transitive'] = copy.deepcopy(base_lock)
        drifts['transitive']['packages']['node_modules/argparse']['integrity'] = 'sha512-drift'
        drifts['transitive-missing'] = copy.deepcopy(base_lock)
        del drifts['transitive-missing']['packages']['node_modules/argparse']
        drifts['nested'] = copy.deepcopy(base_lock)
        drifts['nested']['packages']['node_modules/js-yaml/node_modules/argparse'] = {'version': '9.0.0'}
        for name, lock in drifts.items():
            with self.subTest(drift=name):
                with self.assertRaisesRegex(ValueError, 'parser'):
                    rebuild(lock)
        for field, value in (('version', '5.4.4'), ('main', './dist/js-yaml.mjs'), ('name', 'other')):
            with self.subTest(installed=field):
                with self.assertRaisesRegex(ValueError, 'parser'):
                    rebuild(base_lock, {**package, field: value})
        # A closure beyond the CLI-only argparse dependency is unsupported even when base and head agree.
        unsupported = copy.deepcopy(base_lock)
        unsupported['packages']['node_modules/js-yaml']['dependencies']['extra'] = '^1.0.0'
        unsupported['packages']['node_modules/extra'] = {'version': '1.0.0'}
        fixture.git('checkout', '-q', fixture.base)
        fixture.write(lock_path, json.dumps(unsupported))
        fixture.base = fixture.commit('unsupported parser closure in base')
        subprocess.run(['git', '-C', str(fixture.trusted), 'fetch', '-q', str(fixture.root), fixture.base], check=True)
        subprocess.run(['git', '-C', str(fixture.trusted), 'checkout', '-q', fixture.base], check=True)
        fixture.write('docs/guide.txt', 'later head')
        fixture.head = fixture.commit('subject head on unsupported base')
        self.plan = fixture.plan()
        run.update(head_sha=fixture.head, pull_requests=[{'base': {'sha': fixture.base}, 'head': {'sha': fixture.head}}])
        with self.assertRaisesRegex(ValueError, 'unsupported parser dependency closure'):
            rebuild(unsupported)

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

    def test_TEST024_unexecuted_skip_retains_requested_runner_labels(self):
        self.configure('workflow_dispatch')
        original = copy.deepcopy(self.jobs[-1])
        for labels in ([], [self.workflow['jobs']['a9-advisory']['runs-on']]):
            for runner_id, runner_name in ((None, None), (0, '')):
                with self.subTest(labels=labels, runner_id=runner_id):
                    self.jobs[-1] = copy.deepcopy(original)
                    self.jobs[-1].update(labels=labels, runner_id=runner_id, runner_name=runner_name)
                    self.check_complete(self.invoke(), False)

    def test_TEST024_unexecuted_skip_rejects_unrequested_runner_labels(self):
        self.configure('workflow_dispatch')
        original = copy.deepcopy(self.jobs[-1])
        for labels in (['windows-latest'], ['ubuntu-latest', 'self-hosted'],
                       ['ubuntu-latest', 'ubuntu-latest'], 'ubuntu-latest', None):
            with self.subTest(labels=labels):
                self.jobs[-1] = copy.deepcopy(original)
                self.jobs[-1].update(labels=labels, runner_id=None, runner_name=None)
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
        for field, value in dict(labels=['windows-latest'], runner_id=999, runner_name='executed',
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
here=Path(__file__).parent
responses=json.loads((here/'responses.json').read_text())
with (here/'calls.log').open('a') as log:
    log.write(args[-1]+'\\n')
value=responses[args[-1]]
if isinstance(value,list):
    # Sequenced observations of one endpoint; the final response repeats.
    value=value[min((here/'calls.log').read_text().splitlines().count(args[-1]),len(value))-1]
sys.stdout.buffer.write(b'HTTP/2.0 200 OK\\r\\n\\r\\n'+base64.b64decode(value))
''')
        fake.chmod(0o755)
        self.environment = {**os.environ, 'PATH': str(self.bin) + os.pathsep + os.environ['PATH']}
        self.original_jobs = copy.deepcopy(self.jobs)
        self.original_receipts = copy.deepcopy(self.receipts)

    def serve(self, mutate=None):
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
        def encode(value):
            return base64.b64encode(value if isinstance(value, bytes) else P.canonical(value)).decode()
        wire = {endpoint: [encode(v) for v in value] if isinstance(value, list) else encode(value)
                for endpoint, value in responses.items()}
        (self.bin / 'responses.json').write_text(json.dumps(wire))
        (self.bin / 'calls.log').write_text('')

    def calls(self):
        return (self.bin / 'calls.log').read_text().splitlines()

    def collect_cli(self, mutate=None, expected=0):
        self.serial += 1
        target = self.scratch / ('collected-' + str(self.serial))
        self.serve(mutate)
        command =[sys.executable, '-B', str(SCRIPT), 'collect', '--repository', 'owner/repo',
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


    def test_RT010_finite_duration_integer_and_float_cli_contract(self):
        for value, expected in ((10**400, 0), (-(10**400), 1), (0, 0), (0.25, 0),
                                (1e308, 0), (-0.25, 1), (True, 1)):
            with self.subTest(seconds=value):
                self.receipts = copy.deepcopy(self.original_receipts)
                for _, _, receipt, _, _ in self.receipts:
                    receipt['results'][0]['seconds'] = value
                self.aggregate_cli(self.collect_cli(), expected=expected)

    def test_RT010_nonfinite_duration_raw_json_cli_rejected(self):
        for token in ('NaN', 'Infinity', '-Infinity', '1e999'):
            with self.subTest(token=token):
                observations = self.collect_cli()
                manifest = json.loads((observations / 'collection.json').read_text())
                ref = manifest['artifacts'][0]
                path = observations / ref['path']
                receipt = json.loads(path.read_text())
                receipt['results'][0]['seconds'] = 'NONFINITE_TOKEN'
                path.write_text(json.dumps(receipt).replace('"NONFINITE_TOKEN"', token))
                ref['sha256'] = sha(path.read_bytes())
                (observations / 'collection.json').write_bytes(P.canonical(manifest))
                self.aggregate_cli(observations, expected=1)

    def test_RT012_supported_lzma_and_corrupt_decoder_cli_boundary(self):
        for corrupt in (False, True):
            with self.subTest(corrupt=corrupt):
                def mutate(responses):
                    for endpoint in list(responses):
                        if not endpoint.endswith('/zip'):
                            continue
                        with zipfile.ZipFile(io.BytesIO(responses[endpoint])) as archive:
                            receipt = archive.read('receipt.json')
                        stream = io.BytesIO()
                        with zipfile.ZipFile(stream, 'w', compression=zipfile.ZIP_LZMA) as archive:
                            archive.writestr('receipt.json', receipt)
                        raw = bytearray(stream.getvalue())
                        if corrupt:
                            offset = 30 + int.from_bytes(raw[26:28], 'little') + int.from_bytes(raw[28:30], 'little')
                            raw[offset + 4] = 255  # Invalid LZMA properties, within a valid ZIP container.
                        responses[endpoint] = bytes(raw)
                observations = self.collect_cli(mutate, expected=2 if corrupt else 0)
                if not corrupt:
                    self.aggregate_cli(observations)

    def test_RT011_deep_json_collect_and_hash_bound_aggregate_cli_boundaries(self):
        deep = b'{"nested":' + b'[' * 10000 + b'0' + b']' * 10000 + b'}'
        prefix = '/repos/owner/repo/actions/runs/123'
        for endpoint in (prefix, prefix + '/attempts/1/jobs?per_page=100'):
            with self.subTest(api=endpoint):
                self.collect_cli(lambda responses: responses.update({endpoint: deep}), expected=2)
        for surface in ('run', 'jobs', 'collection'):
            with self.subTest(surface=surface):
                observations = self.collect_cli()
                manifest = json.loads((observations / 'collection.json').read_text())
                if surface == 'collection':
                    (observations / 'collection.json').write_bytes(deep)
                else:
                    ref = manifest['run'] if surface == 'run' else manifest['jobs'][0]
                    (observations / ref['path']).write_bytes(deep)
                    ref['sha256'] = sha(deep)
                    (observations / 'collection.json').write_bytes(P.canonical(manifest))
                self.aggregate_cli(observations, expected=2 if surface == 'collection' else 1)
        self.aggregate_cli(self.collect_cli())

    def test_RT013_path_resolution_loop_cli_returns_typed_error(self):
        observations = self.collect_cli()
        loop = self.scratch / 'self-loop'
        loop.symlink_to(loop.name)
        plan_path = self.scratch / 'loop-plan.json'
        plan_path.write_bytes(P.canonical(self.plan))
        for field, looping in (('root', False), ('observations', False), ('root', True), ('observations', True)):
            with self.subTest(field=field, looping=looping):
                resolved_input = loop
                if not looping:
                    resolved_input = self.scratch / ('valid-link-' + field)
                    resolved_input.symlink_to(self.root if field == 'root' else observations, target_is_directory=True)
                output = self.scratch / ('loop-result-' + field + str(looping) + '.json')
                command = [sys.executable, '-B', str(SCRIPT), 'aggregate',
                           '--root', str(resolved_input if field == 'root' else self.root),
                           '--plan', str(plan_path),
                           '--observations', str(resolved_input if field == 'observations' else observations),
                           '--run-id', '123', '--api-head-sha', self.revision, '--output', str(output)]
                result = subprocess.run(command, capture_output=True, text=True)
                self.assertNotIn('Traceback', result.stdout + result.stderr)
                self.assertEqual(result.returncode, 2 if looping else 0, result.stdout + result.stderr)
                if looping:
                    self.ci.validate_error(json.loads(result.stderr))
                    self.assertFalse(result.stdout)
                    self.assertFalse(output.exists())
                else:
                    payload = json.loads(result.stdout)
                    self.ci.validate_result(payload)
                    self.assertEqual(payload['status'], 'PASS')
                    self.assertEqual(json.loads(output.read_text()), payload)
                    self.assertFalse(result.stderr)

    # Issue 619: a jobs list can still report an execution job in progress after it
    # completed. Only observed nonterminal rows are re-read, by individual GET.
    def stale(self, job):
        job.update(status='in_progress', conclusion=None, completed_at=None)
        job['steps'][-1].update(status='in_progress', conclusion=None, completed_at=None)
        return job

    def collect_refreshing(self, details, mutate=None):
        """Real collector and fake gh transport in process, so refresh delays are observable."""
        def respond(responses):
            if mutate:
                mutate(responses)
            for jid, sequence in details.items():
                responses[f'/repos/owner/repo/actions/jobs/{jid}'] = sequence
        self.serve(respond)
        self.serial += 1
        target = self.scratch / ('collected-' + str(self.serial))
        with patch.dict(os.environ, PATH=self.environment['PATH']), patch('time.sleep') as sleep:
            self.ci.collect('owner/repo', '123', target)
        return target, sleep

    def refreshes(self):
        return [call for call in self.calls() if call.startswith('/repos/owner/repo/actions/jobs/')]

    def runner_rows(self, result, runner):
        ids = {o['id'] for o in self.plan['obligations'] if o['runner'] == runner}
        return [row for row in result['results'] if row['obligation_id'] in ids]

    def test_issue619_stale_nonterminal_job_refreshes_to_actual_terminal_response(self):
        completed = copy.deepcopy(self.jobs[0])
        pending = copy.deepcopy(self.stale(self.jobs[0]))
        observations, sleep = self.collect_refreshing({100: [pending, completed]})
        self.assertEqual(self.refreshes(), ['/repos/owner/repo/actions/jobs/100'] * 2)
        self.assertEqual(sleep.call_count, 1)
        page = json.loads((observations / 'jobs/1-1.json').read_text())
        self.assertEqual(page['jobs'][0], completed, 'the actual refreshed response is persisted')
        result = self.aggregate_cli(observations)
        self.assertEqual({(r['job_id'], r['source_attempt']) for r in result['results']}, {(100, 1), (101, 1), (102, 1)})

    def test_issue619_perpetual_nonterminal_job_exhausts_budget_and_still_fails(self):
        pending = copy.deepcopy(self.stale(self.jobs[0]))
        self.receipts.pop(0)
        observations, sleep = self.collect_refreshing({100: [pending]})
        refreshes = self.refreshes()
        self.assertGreater(len(refreshes), 1, 'a stale nonterminal row is re-read')
        self.assertEqual(set(refreshes), {'/repos/owner/repo/actions/jobs/100'})
        self.assertEqual(sleep.call_count, len(refreshes) - 1)
        self.assertLessEqual(sum(call.args[0] for call in sleep.call_args_list), 60,
                             'mocked inter-round sleeps stay within the 60-second refresh budget')
        page = json.loads((observations / 'jobs/1-1.json').read_text())
        self.assertEqual(page['jobs'][0], pending, 'the real incomplete observation is persisted')
        result = self.aggregate_cli(observations, expected=1)
        rows = self.runner_rows(result, 'ubuntu-latest')
        self.assertTrue(rows)
        for row in rows:
            self.assertEqual((row['status'], row['reason'], row['job_id'], row['source_attempt']),
                             ('FAIL', 'evidence-missing', None, None))
        self.assertTrue(all(r['status'] == 'PASS' for r in self.runner_rows(result, 'macos-latest')))

    def test_issue619_slow_refreshes_share_one_deadline_and_cap_request_timeouts(self):
        """Fake clock: each individual job read takes 30 s; three jobs stay unfinished."""
        for job in self.jobs:
            self.stale(job)
        self.receipts = []
        details = {job['id']: [copy.deepcopy(job)] for job in self.jobs}
        clock, timeouts, sleeps = [1000.0], [], []
        real_run = subprocess.run
        def run(command, **kwargs):
            if command[-1].startswith('/repos/owner/repo/actions/jobs/'):
                timeouts.append(kwargs.get('timeout'))
                clock[0] += 30
            return real_run(command, **kwargs)
        def sleep(seconds):
            sleeps.append(seconds)
            clock[0] += seconds
        def respond(responses):
            for jid, sequence in details.items():
                responses[f'/repos/owner/repo/actions/jobs/{jid}'] = sequence
        self.serve(respond)
        target = self.scratch / 'collected-deadline'
        with (patch.dict(os.environ, PATH=self.environment['PATH']), patch('time.monotonic', lambda: clock[0]),
              patch('time.sleep', sleep), patch.object(self.ci.subprocess, 'run', run)):
            self.ci.collect('owner/repo', '123', target)
        # 60 s budget: the first read may use all of it, the second only what remains,
        # and at the deadline no third read, sleep or later round starts.
        self.assertEqual(self.refreshes(), ['/repos/owner/repo/actions/jobs/100', '/repos/owner/repo/actions/jobs/101'])
        self.assertEqual(timeouts, [60, 30])
        self.assertEqual(sleeps, [])
        page = json.loads((target / 'jobs/1-1.json').read_text())
        self.assertEqual(page['jobs'], [details[j['id']][0] for j in self.jobs], 'actual unfinished rows persist')
        result = self.aggregate_cli(target, expected=1)
        for row in result['results']:
            self.assertEqual((row['status'], row['reason'], row['job_id']), ('FAIL', 'evidence-missing', None))

    def test_issue619_refreshed_wrong_identity_rejects_collection(self):
        completed = copy.deepcopy(self.jobs[0])
        self.stale(self.jobs[0])
        for field, value in (('id', 999), ('run_id', 124), ('run_attempt', 2), ('head_sha', 'b' * 40),
                             ('name', 'test (macos-latest)'), (None, [completed])):
            with self.subTest(field=field):
                wrong = value if field is None else {**copy.deepcopy(completed), field: value}
                with self.assertRaises(ValueError):
                    self.collect_refreshing({100: [wrong]})
                self.assertIn('/repos/owner/repo/actions/jobs/100', self.refreshes())
                self.assertFalse((self.scratch / f'collected-{self.serial}' / 'collection.json').exists())

    def test_issue619_terminal_failure_is_not_refreshed_or_retried(self):
        self.jobs[0]['conclusion'] = 'failure'
        self.jobs[0]['steps'][-1]['conclusion'] = 'failure'
        observations, sleep = self.collect_refreshing({})
        self.assertEqual(self.refreshes(), [])
        sleep.assert_not_called()
        result = self.aggregate_cli(observations, expected=1)
        for row in self.runner_rows(result, 'ubuntu-latest'):
            self.assertEqual((row['status'], row['reason'], row['job_id']), ('FAIL', 'execution-failed', 100))

    def test_issue619_active_control_is_never_awaited(self):
        completed = copy.deepcopy(self.jobs[0])
        self.stale(self.jobs[0])
        self.jobs.append(dict(id=999, run_id=123, run_attempt=1, head_sha=self.revision, name='required-checks',
                              labels=['ubuntu-latest'], runner_id=2000, runner_name='host-control',
                              status='in_progress', conclusion=None, started_at='2026-10-19T10:02:00Z',
                              completed_at=None, steps=[dict(name='Collect actual same-run execution observations',
                                                             number=1, status='in_progress', conclusion=None,
                                                             started_at='2026-10-19T10:02:00Z', completed_at=None)]))
        observations, sleep = self.collect_refreshing({100: [completed]})
        self.assertEqual(self.refreshes(), ['/repos/owner/repo/actions/jobs/100'])
        sleep.assert_not_called()
        self.aggregate_cli(observations)

    def test_issue619_older_success_cannot_mask_latest_incomplete_attempt(self):
        self.rerun()
        for job in self.jobs[:3]:
            job['conclusion'] = 'success'
            job['steps'][-1]['conclusion'] = 'success'
        for _, _, receipt, _, _ in self.receipts[:3]:
            receipt['results'][0].update(status='passed', exit_code=0)
        pending = copy.deepcopy(self.stale(self.jobs[3]))
        self.receipts.pop(3)
        observations, _ = self.collect_refreshing({200: [pending]})
        self.assertTrue(self.refreshes())
        self.assertEqual(set(self.refreshes()), {'/repos/owner/repo/actions/jobs/200'})
        result = self.aggregate_cli(observations, expected=1)
        for row in self.runner_rows(result, 'ubuntu-latest'):
            self.assertEqual((row['status'], row['reason'], row['job_id']), ('FAIL', 'evidence-missing', None))
        self.assertEqual({(r['job_id'], r['source_attempt']) for r in result['results'] if r['status'] == 'PASS'},
                         {(201, 2), (202, 2)})


class DependencyCacheIntegrationTests(unittest.TestCase):
    """Exercise acquisition integrity with in-memory dependency bytes only."""
    def setUp(self):
        path = ROOT / 'tests/ci-dependency-cache.py'
        self.assertTrue(path.is_file(), 'pinned dependency acquisition/integrity helper is missing')
        self.cache = module(path, 't003_cache')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.target = self.directory / 'pester.nupkg'
        self.payload = b'fixture dependency bytes; never executed'
        self.digest = sha(self.payload)
        self.url = 'https://fixture.invalid/pinned.nupkg'

    def acquire(self):
        return self.cache.acquire(self.target, self.url, self.digest, attempts=3)

    def test_T003_cache_hit_rehashes_bytes_without_network(self):
        self.target.write_bytes(self.payload)
        with patch.object(self.cache.urllib.request, 'urlopen') as request:
            self.assertEqual(self.acquire(), self.target)
        request.assert_not_called()
        self.assertEqual(sha(self.target.read_bytes()), self.digest)

    def test_T003_cache_corruption_is_reacquired_before_reuse(self):
        self.target.write_bytes(b'tampered')
        with patch.object(self.cache.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)) as request:
            self.acquire()
        self.assertEqual(request.call_count, 1)
        self.assertEqual(self.target.read_bytes(), self.payload)

    def test_T003_corrupt_download_never_publishes_a_valid_cache_file(self):
        with patch.object(self.cache.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(b'wrong bytes')):
            with self.assertRaises(ValueError):
                self.acquire()
        self.assertFalse(self.target.exists())

    def test_T003_acquisition_retries_are_bounded_and_failures_logged(self):
        errors = io.StringIO()
        responses = [OSError('temporary acquisition failure'), OSError('temporary acquisition failure'), io.BytesIO(self.payload)]
        with patch.object(self.cache.urllib.request, 'urlopen', side_effect=responses) as request, contextlib.redirect_stderr(errors):
            self.acquire()
        self.assertEqual(request.call_count, 3)
        self.assertIn('attempt 1', errors.getvalue())
        self.assertIn('attempt 2', errors.getvalue())
        self.target.unlink()
        with patch.object(self.cache.urllib.request, 'urlopen', side_effect=OSError('unavailable')) as request:
            with self.assertRaises((OSError, ValueError)):
                self.acquire()
        self.assertEqual(request.call_count, 3)
        self.assertFalse(self.target.exists())

    def test_T003_cache_paths_never_follow_symlinks(self):
        outside = self.directory / 'outside'
        outside.write_bytes(b'untouched')
        try:
            self.target.symlink_to(outside)
        except OSError:
            self.skipTest('host cannot create symlinks')
        with patch.object(self.cache.urllib.request, 'urlopen') as request, self.assertRaises(ValueError):
            self.acquire()
        request.assert_not_called()
        self.assertEqual(outside.read_bytes(), b'untouched')

    def test_T003_pester_package_and_manifest_pins_match_observed_bytes(self):
        self.assertEqual(self.cache.PESTER_VERSION, '4.10.1')
        self.assertEqual(self.cache.PESTER_SHA256, '898210e1a30c52cd46ba317c2278a9324345214213aa2f7d6b7dfa7b98f37ac9')
        self.assertEqual(self.cache.PESTER_MANIFEST_SHA256, '05bf87f45bf2b6604073a6851d0803917adfa87c134b9dd5867ba93b2e872663')


PlanFixture = module(ROOT / 'tests/verification-ci-plan.tests.py', 't003_plan_fixture').GitFixture


class WorkflowPlanIntegrationTests(PlanFixture):  # type: ignore[misc, valid-type]  # Runtime-loaded filename contains hyphens.
    """Run the actual workflow planner body against disposable Git histories."""
    def actual_body(self):
        workflow = W.load_workflow(ROOT / '.github/workflows/test.yml')
        self.assertTrue('ci-plan' in workflow['jobs'], 'workflow does not invoke the accepted planner')
        steps = [s for s in workflow['jobs']['ci-plan']['steps'] if s.get('id') == 'plan']
        self.assertEqual(len(steps), 1)
        step = steps[0]
        self.assertEqual(step['shell'], 'bash')
        self.assertEqual(step['env'], {
            'CI_EVENT': '${{ github.event_name }}',
            'CI_BASE_SHA': '${{ github.event.pull_request.base.sha }}',
            'CI_HEAD_SHA': '${{ github.event.pull_request.head.sha }}',
            'CI_TESTED_SHA': '${{ github.sha }}',
            'CI_API_HEAD_SHA': '${{ github.event.pull_request.head.sha || github.sha }}',
            'CI_FORCE_FULL': '${{ vars.SDD_CI_FORCE_FULL }}'})
        return step['run']

    def invoke_workflow(self, event='pull_request', force='false', body=None, tested=None, expected_exit=0):
        body = self.actual_body() if body is None else body
        tested = self.head if tested is None else tested
        with tempfile.TemporaryDirectory(dir=self.temp.name) as directory:
            runtime = Path(directory)
            output = runtime / 'github-output'
            env = dict(os.environ, GITHUB_WORKSPACE=self.temp.name, RUNNER_TEMP=str(runtime),
                       GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1', GITHUB_OUTPUT=str(output),
                       CI_EVENT=event, CI_BASE_SHA=self.base if event == 'pull_request' else '',
                       CI_HEAD_SHA=self.head if event == 'pull_request' else '', CI_TESTED_SHA=tested,
                       CI_API_HEAD_SHA=self.head, CI_FORCE_FULL=force)
            result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', body], cwd=self.temp.name,
                                    env=env, capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, expected_exit, result.stdout + result.stderr)
            if expected_exit:
                self.assertFalse((runtime / 'verification-plan/plan.json').exists())
                self.assertFalse(output.exists() and output.read_text())
                return None
            plan = P.strict_json((runtime / 'verification-plan/plan.json').read_bytes())
            P.validate_plan(plan)
            actual = dict(line.split('=', 1) for line in output.read_text().splitlines())
            expected = P.condition_outputs(plan, sorted(set(self.workflow['jobs']) - {'required-checks'}))
            expected['plan_artifact_name'] = 'verification-plan-123-1'
            self.assertEqual(actual, expected)
            self.assertEqual(plan['run_id'], '123')
            self.assertEqual(plan['planning_attempt'], 1)
            self.assertEqual(plan['api_head_sha'], self.head)
            self.assertEqual(plan['tested_revision'], tested)
            return plan

    def test_T003_actual_planner_body_keeps_non_pr_and_manual_full(self):
        for event in ('push', 'merge_group', 'release', 'workflow_dispatch'):
            with self.subTest(event=event):
                plan = self.invoke_workflow(event)
                self.assertEqual(plan['mode'], 'full')
                self.assertEqual(plan['reason'], 'event-full')

    def test_T003_actual_pr_body_executes_trusted_planner_and_propagates_force_full(self):
        path = self.root / 'tests/verification-impact.py'
        source = path.read_text()
        marker = "if __name__ == '__main__':"
        self.assertEqual(source.count(marker), 1)
        path.write_text(source.replace(marker, 'raise SystemExit(96)\n\n' + marker))
        self.head = self.commit('PR planner sentinel must never execute')
        for force in ('false', 'true', '', 'False', 'unexpected'):
            with self.subTest(force=force):
                plan = self.invoke_workflow(force=force)
                self.assertEqual(plan['mode'], 'full')
                self.assertEqual(plan['base_revision'], self.base)
                if force != 'false':
                    self.assertEqual(plan['reason'], 'force-full')

    def test_T003_actual_first_adoption_without_base_planner_stays_full(self):
        original = (self.root / 'tests/verification-impact.py').read_text()
        (self.root / 'tests/verification-impact.py').unlink()
        self.base = self.commit('old base lacks explicit planner')
        import shutil
        shutil.rmtree(self.trusted)
        self.git('clone', '-q', '--no-hardlinks', str(self.root), str(self.trusted))
        self.write('tests/verification-impact.py', original)
        self.head = self.commit('first adoption subject')
        plan = self.invoke_workflow()
        self.assertEqual(plan['mode'], 'full')
        self.assertEqual(plan['reason'], 'base-planner-unavailable')

    def test_RT016_present_released_shadow_planner_uses_full_adoption_fallback(self):
        historical = ROOT / 'specs/ci-model-modernization/verification/T-003/cycle1-fix/historical-shadow-impact.py'
        raw = historical.read_bytes()
        self.assertEqual(len(raw), 5968)
        self.assertEqual(sha(raw), '325aa985ddc0746c7276398235fe090700c118b7b0e088baf24e4cb944060ff3')
        self.assertNotIn(b'def plan_main(', raw)
        original = (self.root / 'tests/verification-impact.py').read_bytes()
        (self.root / 'tests/verification-impact.py').write_bytes(raw)
        self.base = self.commit('actual released shadow-only base planner')
        import shutil
        shutil.rmtree(self.trusted)
        self.git('clone', '-q', '--no-hardlinks', str(self.root), str(self.trusted))
        (self.root / 'tests/verification-impact.py').write_bytes(original)
        self.head = self.commit('first adoption over present shadow-only base')
        plan = self.invoke_workflow()
        self.assertEqual(plan['mode'], 'full')
        self.assertEqual(plan['reason'], 'base-planner-unavailable')
        self.assertEqual(plan['base_revision'], self.base)

    def test_RT016_subject_origin_sentinel_detects_wrong_dispatch(self):
        path = self.root / 'tests/verification-impact.py'
        marker = "if __name__ == '__main__':"
        source = path.read_text()
        self.assertEqual(source.count(marker), 1)
        path.write_text(source.replace(marker, 'raise SystemExit(96)\n\n' + marker))
        self.head = self.commit('reachable subject sentinel before terminating main')
        body = self.actual_body()
        invocation = 'python3 -I -B "$planner" --plan'
        self.assertEqual(body.count(invocation), 1)
        mutant = body.replace(invocation, 'planner="$subject/tests/verification-impact.py"\n' + invocation)
        self.invoke_workflow(body=mutant, expected_exit=96)
        # A modern trusted base must still run successfully with these exact subject bytes.
        self.assertEqual(self.invoke_workflow()['mode'], 'full')

    def test_RT016_actual_pr_body_binds_api_head_and_distinct_tested_merge(self):
        pr_head = self.head
        self.git('checkout', '-q', self.base)
        self.write('docs/base-only.txt', 'base branch advanced\n')
        self.base = self.commit('advance trusted base independently')
        import shutil
        shutil.rmtree(self.trusted)
        self.git('clone', '-q', '--no-hardlinks', str(self.root), str(self.trusted))
        self.git('merge', '--no-ff', '-qm', 'synthetic tested PR merge', pr_head)
        tested = self.git('rev-parse', 'HEAD')
        self.assertNotEqual(tested, pr_head)
        self.head = pr_head
        plan = self.invoke_workflow(tested=tested)
        self.assertEqual(plan['api_head_sha'], pr_head)
        self.assertEqual(plan['tested_revision'], tested)
        self.assertEqual(plan['pr_head_revision'], pr_head)
        self.assertEqual(plan['base_revision'], self.base)


# Claude Code test draft, admitted SHA 8a27e7bc806fe98eabbc8dc98b5488fb72bb4a4d6c97c0cf7121e96883f5ad9d.
# Six duplicate acquire cases remain solely in DependencyCacheIntegrationTests above.
#!/usr/bin/env python3
"""T-003 pinned dependency cache fixtures; mocked downloads only, never native install proof."""

HELPER = ROOT / 'tests/ci-dependency-cache.py'

# Observed real package (pester-package-observation.json); never satisfied by synthetic fixtures.
REAL_URL = 'https://www.powershellgallery.com/api/v2/package/Pester/4.10.1'
REAL_VERSION = '4.10.1'
REAL_ARCHIVE_SHA256 = '898210e1a30c52cd46ba317c2278a9324345214213aa2f7d6b7dfa7b98f37ac9'
REAL_MANIFEST_SHA256 = '05bf87f45bf2b6604073a6851d0803917adfa87c134b9dd5867ba93b2e872663'

MANIFEST = b"@{\r\n    ModuleVersion = '4.10.1'\r\n    RootModule = 'Pester.psm1'\r\n}\r\n"
MODULE_FILES = {
    'Pester.psd1': MANIFEST,
    'Pester.psm1': b'# fixture module body; never executed\r\n',
    'Functions/It.ps1': b'function It {}\r\n',
}
PACKAGING_FILES = {
    '[Content_Types].xml': b'<?xml version="1.0"?><Types/>',
    '_rels/.rels': b'<?xml version="1.0"?><Relationships/>',
    'Pester.nuspec': b'<?xml version="1.0"?><package/>',
    'package/services/metadata/core-properties/fixture.psmdcp': b'<?xml version="1.0"?><coreProperties/>',
}






def symlink_entry(name, target='../../outside'):
    info = zipfile.ZipInfo(name)
    info.create_system = 3
    info.external_attr = (stat.S_IFLNK | 0o777) << 16
    return info, target.encode()


def package(*extra, omit=()):
    raw = io.BytesIO()
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')  # duplicate-name fixtures are intentional
        with zipfile.ZipFile(raw, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('Functions/', b'')
            for name, data in {**MODULE_FILES, **PACKAGING_FILES}.items():
                if name not in omit:
                    archive.writestr(name, data)
            for name, data in extra:
                archive.writestr(name, data)
    return raw.getvalue()


def files(root):
    return {path.relative_to(root).as_posix(): path.read_bytes()
            for path in Path(root).rglob('*') if path.is_file() or path.is_symlink()}


def requested_url(call):
    target = call.args[0] if call.args else call.kwargs['url']
    return getattr(target, 'full_url', target)


class CacheFixture(unittest.TestCase):
    def setUp(self):
        self.assertTrue(HELPER.is_file(), f'pinned dependency acquisition/integrity helper is missing: {HELPER.name}')
        self.cache = module(HELPER, 't003_cache_helper')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        # Resolved so host-level symlinked temp roots (e.g. macOS /var) are not fixture ancestors.
        self.directory = Path(self.temp.name).resolve()
        guards = [patch.object(socket.socket, 'connect', side_effect=AssertionError('network forbidden in fixtures')),
                  patch.object(self.cache.urllib.request, 'urlopen', side_effect=AssertionError('unmocked download')),
                  patch('subprocess.Popen', side_effect=AssertionError('dependency bytes must never execute')),
                  patch('os.system', side_effect=AssertionError('dependency bytes must never execute'))]
        self.connect, self.default_urlopen, self.popen, self.system = (guard.start() for guard in guards)
        for guard in guards:
            self.addCleanup(guard.stop)

    def symlink(self, link, target, directory=False):
        try:
            link.symlink_to(target, target_is_directory=directory)
        except OSError:
            self.skipTest('host cannot create symlinks')

    def assert_never_executed(self):
        self.popen.assert_not_called()
        self.system.assert_not_called()
        self.connect.assert_not_called()


class DependencyCacheAcquireTests(CacheFixture):
    """Same contract as parent DependencyCacheIntegrationTests, plus publication and ancestor checks."""
    def setUp(self):
        super().setUp()
        self.target = self.directory / 'pester.nupkg'
        self.payload = b'fixture dependency bytes; never executed'
        self.digest = sha(self.payload)
        self.url = 'https://fixture.invalid/pinned.nupkg'

    def acquire(self, target=None):
        return self.cache.acquire(target or self.target, self.url, self.digest, attempts=3)







    def test_symlinked_cache_ancestor_is_refused_without_network(self):
        real = self.directory / 'real-cache'
        real.mkdir()
        link = self.directory / 'linked-cache'
        self.symlink(link, real, directory=True)
        with patch.object(self.cache.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)) as request:
            with self.assertRaises(ValueError):
                self.acquire(link / 'pester.nupkg')
        request.assert_not_called()
        self.assertEqual(list(real.iterdir()), [])

    def test_every_cache_hit_rehashes_even_when_size_and_mtime_are_unchanged(self):
        self.target.write_bytes(self.payload)
        with patch.object(self.cache.urllib.request, 'urlopen') as request:
            self.acquire()
        request.assert_not_called()
        before = self.target.stat()
        self.target.write_bytes(b'X' * len(self.payload))
        os.utime(self.target, ns=(before.st_atime_ns, before.st_mtime_ns))
        with patch.object(self.cache.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)) as request:
            self.assertEqual(self.acquire(), self.target)
        self.assertEqual(request.call_count, 1)
        self.assertEqual(self.target.read_bytes(), self.payload)

    def test_download_is_published_atomically_from_unique_same_directory_temporary(self):
        decoys = [self.directory / name for name in ('pester.nupkg.tmp', 'pester.nupkg.part', '.pester.nupkg.tmp')]
        for decoy in decoys:
            decoy.write_bytes(b'decoy')
        with patch.object(self.cache.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)), \
                patch('os.replace', wraps=os.replace) as replace:
            self.acquire()
        publications = [call for call in replace.call_args_list if Path(call.args[1]) == self.target]
        self.assertEqual(len(publications), 1, 'cache file must be published by one atomic replace')
        source = Path(publications[0].args[0])
        self.assertEqual(source.parent, self.target.parent)
        self.assertNotIn(source, [self.target, *decoys])
        self.assertEqual({path.name for path in self.directory.iterdir()}, {'pester.nupkg', *(d.name for d in decoys)})
        for decoy in decoys:
            self.assertEqual(decoy.read_bytes(), b'decoy')
        self.assertEqual(self.target.read_bytes(), self.payload)
        self.assertFalse(self.target.stat().st_mode & 0o111, 'cached download must not be executable')
        self.assert_never_executed()


class PesterInstallFixture(CacheFixture):
    def setUp(self):
        super().setUp()
        self.cache_dir = self.directory / 'dependency-cache'
        self.module_root = self.directory / 'modules'
        self.version_dir = self.module_root / 'Pester' / REAL_VERSION

    @contextlib.contextmanager
    def pinned(self, raw, manifest_sha256=None):
        """Patch archive/manifest pins to the synthetic fixture; real pins are asserted separately."""
        with patch.object(self.cache, 'PESTER_SHA256', sha(raw)), \
                patch.object(self.cache, 'PESTER_MANIFEST_SHA256', manifest_sha256 or sha(MANIFEST)), \
                patch.object(self.cache.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(raw)) as request:
            yield request

    def install(self, raw, **kwargs):
        with self.pinned(raw, **kwargs) as request:
            result = self.cache.install_pester(self.cache_dir, self.module_root)
        return result, request

    def assert_rejected(self, raw, **kwargs):
        with self.pinned(raw, **kwargs), self.assertRaises(ValueError):
            self.cache.install_pester(self.cache_dir, self.module_root)
        self.assertFalse(self.version_dir.exists(), 'validation must finish before publishing any module file')
        self.assert_never_executed()

    def assert_fresh_tree(self, version_dir):
        installed = files(version_dir)
        for name, data in MODULE_FILES.items():
            self.assertEqual(installed.get(name), data, name)
        self.assertLessEqual(set(installed), set(MODULE_FILES) | set(PACKAGING_FILES),
                             'only module files and inert NuGet packaging files may be installed')
        self.assertFalse(any(path.is_symlink() for path in Path(version_dir).rglob('*')))

    def assert_cache_holds_only_package(self, raw):
        entries = list(self.cache_dir.iterdir())
        self.assertEqual(len(entries), 1, 'dependency cache must hold only the package bytes')
        self.assertTrue(entries[0].name.endswith('.nupkg') and entries[0].is_file() and not entries[0].is_symlink())
        self.assertEqual(entries[0].read_bytes(), raw)
        return entries[0]


class PesterInstallTests(PesterInstallFixture):
    def test_install_extracts_validated_fresh_tree_and_caches_only_package(self):
        raw = package()
        result, request = self.install(raw)
        self.assertEqual(Path(result), self.version_dir)
        self.assertEqual(request.call_count, 1)
        self.assertEqual(requested_url(request.call_args), self.cache.PESTER_URL)
        self.assert_fresh_tree(self.version_dir)
        self.assertEqual([path.name for path in self.module_root.iterdir()], ['Pester'])
        self.assertEqual([path.name for path in (self.module_root / 'Pester').iterdir()], [REAL_VERSION])
        self.assert_cache_holds_only_package(raw)
        self.assert_never_executed()

    def test_cache_hit_installs_fresh_module_root_without_network(self):
        raw = package()
        self.install(raw)
        self.module_root = self.directory / 'second-job-modules'
        self.version_dir = self.module_root / 'Pester' / REAL_VERSION
        result, request = self.install(raw)
        request.assert_not_called()
        self.assertEqual(Path(result), self.version_dir)
        self.assert_fresh_tree(self.version_dir)

    def test_corrupt_cached_package_is_reacquired_before_extraction(self):
        raw = package()
        self.install(raw)
        cached = self.assert_cache_holds_only_package(raw)
        cached.write_bytes(raw[:-1] + bytes([raw[-1] ^ 1]))
        self.module_root = self.directory / 'after-corruption'
        self.version_dir = self.module_root / 'Pester' / REAL_VERSION
        _, request = self.install(raw)
        self.assertEqual(request.call_count, 1)
        self.assert_cache_holds_only_package(raw)
        self.assert_fresh_tree(self.version_dir)

    def test_symlinked_cache_dir_is_refused_without_network(self):
        real = self.directory / 'real-cache'
        real.mkdir()
        self.symlink(self.cache_dir, real, directory=True)
        with self.pinned(package()) as request, self.assertRaises(ValueError):
            self.cache.install_pester(self.cache_dir, self.module_root)
        request.assert_not_called()
        self.assertEqual(list(real.iterdir()), [])

    def test_unsafe_member_names_are_rejected_before_extraction(self):
        names = ['../escape.ps1', '/absolute.ps1', 'Functions/../../escape.ps1', 'C:/escape.ps1', 'C:escape.ps1',
                 'Functions\\escape.ps1', '\\\\server\\share\\escape.ps1', 'Functions//It2.ps1', './escape.ps1',
                 'Functions/../escape.ps1']
        for name in names:
            with self.subTest(name=name):
                raw = package((name, b'planted'))
                self.assertIn(name, zipfile.ZipFile(io.BytesIO(raw)).namelist(), 'fixture lost the unsafe name')
                self.assert_rejected(raw)
                self.assertFalse((self.directory / 'escape.ps1').exists())

    def test_symlink_duplicate_and_collision_members_are_rejected(self):
        cases = {
            'symlink': [symlink_entry('Functions/Link.ps1')],
            'duplicate': [('Pester.psm1', b'second copy')],
            'case-duplicate': [('functions/it.ps1', b'case variant')],
            'file-then-directory': [('Pester.psm1/inner.ps1', b'nested under file')],
            'directory-entry-over-file': [('Pester.psm1/', b'')],
            'directory-then-file': [('Functions', b'file over directory')],
        }
        for kind, extra in cases.items():
            with self.subTest(kind=kind):
                self.assert_rejected(package(*extra))

    def test_invalid_or_corrupt_archives_are_typed_errors_without_partial_tree(self):
        self.assert_rejected(b'pinned bytes that are not a zip archive')
        raw = bytearray(package())
        info = zipfile.ZipFile(io.BytesIO(bytes(raw))).getinfo('Pester.psm1')
        offset = info.header_offset
        offset += 30 + int.from_bytes(raw[offset+26:offset+28], 'little') + int.from_bytes(raw[offset+28:offset+30], 'little')
        raw[offset:offset+2] = b'\xff\xff'
        self.assert_rejected(bytes(raw))

    def test_root_manifest_bytes_are_validated_not_version_string(self):
        self.assert_rejected(package(omit={'Pester.psd1'}))
        self.assert_rejected(package(('Pester/Pester.psd1', MANIFEST), omit={'Pester.psd1'}))
        forged = MANIFEST + b"# ModuleVersion = '4.10.1' forged\r\n"
        self.assert_rejected(package(('Pester.psd1', forged), omit={'Pester.psd1'}))

    def test_tampered_installed_module_is_repaired_or_fails_closed(self):
        raw = package()
        self.install(raw)
        (self.version_dir / 'Pester.psd1').write_bytes(MANIFEST + b'# tampered, same ModuleVersion\r\n')
        (self.version_dir / 'Functions/It.ps1').write_bytes(b'function It { "tampered" }')
        (self.version_dir / 'planted.ps1').write_bytes(b'planted')
        try:
            result, request = self.install(raw)
        except ValueError:
            return  # fail-closed is acceptable; must not report success over tampered bytes
        request.assert_not_called()
        self.assertEqual(Path(result), self.version_dir)
        self.assert_fresh_tree(self.version_dir)

    def test_existing_symlinks_in_module_root_are_never_written_through(self):
        for relative in ('Pester', f'Pester/{REAL_VERSION}', f'Pester/{REAL_VERSION}/Functions'):
            with self.subTest(link=relative):
                self.module_root = self.directory / f'modules-{relative.count("/")}'
                self.version_dir = self.module_root / 'Pester' / REAL_VERSION
                link = self.module_root / relative
                link.parent.mkdir(parents=True)
                outside = self.directory / f'outside-{relative.count("/")}'
                outside.mkdir()
                self.symlink(link, outside, directory=True)
                try:
                    result, _ = self.install(package())
                except ValueError:
                    pass
                else:
                    self.assertFalse(Path(result).is_symlink())
                    self.assertFalse((self.module_root / 'Pester').is_symlink())
                    self.assert_fresh_tree(result)
                self.assertEqual(list(outside.iterdir()), [], 'install wrote through an existing symlink')


class PinnedPesterTests(PesterInstallFixture):
    """Real observed pins stay in force; synthetic bytes can never satisfy them."""
    def test_real_pins_reject_synthetic_package_without_publishing(self):
        self.assertEqual(self.cache.PESTER_SHA256, REAL_ARCHIVE_SHA256)
        self.assertEqual(self.cache.PESTER_MANIFEST_SHA256, REAL_MANIFEST_SHA256)
        raw = package()
        with patch.object(self.cache.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(raw)) as request:
            with self.assertRaises(ValueError):
                self.cache.install_pester(self.cache_dir, self.module_root)
        self.assertGreaterEqual(request.call_count, 1)
        self.assertTrue(all(requested_url(call) == REAL_URL for call in request.call_args_list))
        self.assertFalse(self.version_dir.exists())
        self.assertFalse(self.cache_dir.exists() and any(self.cache_dir.iterdir()), 'mismatched bytes were cached')


class PesterCliTests(PesterInstallFixture):
    def run_cli(self, argv):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            try:
                code = self.cache.main(argv)
            except SystemExit as exit_:
                code = exit_.code
            except Exception as error:
                self.fail('typed CLI error boundary leaked ' + type(error).__name__)
        return code, stderr.getvalue()

    def argv(self):
        return ['pester', '--cache-dir', str(self.cache_dir), '--module-root', str(self.module_root)]

    def test_cli_installs_pinned_package(self):
        raw = package()
        with self.pinned(raw) as request:
            code, stderr = self.run_cli(self.argv())
        self.assertEqual(code, 0)
        self.assertNotIn('Traceback', stderr)
        self.assertEqual(requested_url(request.call_args), self.cache.PESTER_URL)
        self.assert_fresh_tree(self.version_dir)
        self.assert_cache_holds_only_package(raw)

    def test_cli_failures_return_typed_nonzero_without_traceback(self):
        unavailable = patch.object(self.cache.urllib.request, 'urlopen', side_effect=OSError('unavailable'))
        synthetic = patch.object(self.cache.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(package()))
        for label, mock in (('unavailable', unavailable), ('real-pin-mismatch', synthetic)):
            with self.subTest(failure=label):
                with mock:
                    code, stderr = self.run_cli(self.argv())
                self.assertIsInstance(code, int)
                self.assertNotEqual(code, 0)
                self.assertNotIn('Traceback', stderr)
                self.assertFalse(self.version_dir.exists())
        for argv in (['unknown'], ['pester', '--cache-dir', str(self.cache_dir)]):
            with self.subTest(argv=argv):
                code, stderr = self.run_cli(argv)
                self.assertIsInstance(code, int)
                self.assertNotEqual(code, 0)
                self.assertNotIn('Traceback', stderr)




if __name__ == '__main__':
    unittest.main(verbosity=2)
