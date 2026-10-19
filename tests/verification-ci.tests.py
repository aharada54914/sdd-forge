#!/usr/bin/env python3
"""Deterministic Actions protocol fixtures; never hosted/native acceptance proof."""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch

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
        good = dict(schema='verification-ci-result/v1', status='PASS', reason='verified', run_id='123',
                    api_head_sha='a'*40, tested_revision='b'*40, plan_sha256='c'*64,
                    results=[dict(obligation_id='test:fixture', status='PASS', reason='executed',
                                  job_id=1, source_attempt=1)])
        self.ci.validate_result(good, expected=good)
        changes = dict(schema='wrong', status='FAIL', reason='evidence-missing', run_id='124',
                       api_head_sha='d'*40, tested_revision='e'*40, plan_sha256='f'*64, results=[])
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
        good = dict(schema='verification-ci-observations/v1', repository='owner/repo', run_id='123',
                    api_head_sha='a' * 40, collected_at='2026-10-19T12:00:00Z', api_version='2026-03-10',
                    run={'path': 'run.json', 'sha256': 'b' * 64}, jobs=[{'path': 'jobs/1.json', 'sha256': 'c' * 64}],
                    artifacts=[{'path': 'artifacts/a/r.json', 'sha256': 'd' * 64, 'job_id': 1, 'source_attempt': 1}])
        self.ci.validate_collection(good)
        changes = dict(schema='other', repository='https://evil.invalid', run_id=123, api_head_sha='bad',
                       collected_at='yesterday', api_version='2022-11-28', run={}, jobs=[], artifacts={})
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


class AggregateTests(unittest.TestCase):
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
        self.catalog = dict(schema='verification-catalog/v1', suites=[dict(path=self.suite, runtime='python')],
                            profiles={'fixture': [self.suite]},
                            impact=dict(schema='verification-impact-rules/v1', categories=[], dependencies={}))
        self.workflow = {'jobs': {'test': {
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
        self.run = dict(id=123, run_attempt=1, head_sha=self.revision, event='push',
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
                        api_head_sha=self.run['head_sha'], collected_at='2026-10-19T12:00:00Z',
                        api_version='2026-03-10', run=persist('run.json', self.run), jobs=[], artifacts=[])
        for attempt in range(1, self.run['run_attempt']+1):
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
                   '--api-head-sha', self.run['head_sha']]
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
        changes = dict(schema='wrong', profile='other', revision='a'*40, revision_after='a'*40,
                       clean_before=False, clean_after=False, reusable=True, catalog_sha256='a'*64,
                       selected=[], results=[])
        original = copy.deepcopy(self.receipts)
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
        self.run['run_attempt'] = 2
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
        self.run['run_attempt'] = 2
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
        self.run['run_attempt'] = 2
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


if __name__ == '__main__':
    unittest.main(verbosity=2)
