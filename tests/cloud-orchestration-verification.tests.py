"""T-006 synthetic tests. No credentials, native provider or cloud side effects.

Preflight uses the existing CLI boundary, not a nonexistent module import. The
baseline fails at OPERATION_UNIMPLEMENTED, not at a claimed collector assertion.
"""
from __future__ import annotations

import copy
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / 'plugins/sdd-quality-loop/scripts'
sys.path.insert(0, str(SHARED))
import cloud_contracts as c  # noqa: E402


def encode(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True) + '\n').encode()


def request(provider: str) -> dict:
    ref = dict(path='input.json', sha256='a' * 64)
    return dict(schema='cloud-run-request/v1', run_id='synthetic-run',
                unit_id='synthetic-unit', provider=provider, binding_id='synthetic-binding',
                environment='synthetic', scope=dict(account_id='synthetic-account',
                region='synthetic-region', deployment_scope='synthetic-scope'),
                owner='cdk' if provider == 'aws' else 'bicep',
                route='aws-cdk' if provider == 'aws' else 'azure-bicep',
                operation='apply', predecessor_receipts=[], source_revision='b' * 40,
                input_artifacts=[dict(kind='compiled', **ref)], dependency_lock=ref,
                policy=ref, verification_profile=dict(id='synthetic-profile', version='1', **ref))


class EntryPreflight(unittest.TestCase):
    def test_fake_native_payload_never_confers_collector_provenance(self):
        # These are concrete persisted field/counterpart mismatches. The public CLI
        # must reject saved native assertions, not turn them into health evidence.
        for provider in ('azure', 'aws'):
            with self.subTest(provider=provider), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                (root / 'request.json').write_bytes(encode(request(provider)))
                proc = subprocess.run([sys.executable, '-B', str(ROOT / f'plugins/sdd-{provider}-cloud/scripts/cloud.py'),
                    'verify', '--request', str(root / 'request.json'), '--output', str(root / 'out.json')],
                    env={'PATH': os.defpath, 'HOME': temp, 'CLOUD_WORKSPACE_ROOT': temp},
                    capture_output=True, timeout=10)
                result = c.parse_artifact(proc.stdout)
                self.assertEqual(proc.returncode, 2)
                self.assertEqual(result['result'], 'BLOCKED')
                self.assertEqual(result['error_code'], 'TRUSTED_COLLECTOR_REQUIRED')
                self.assertFalse((root / 'out.json').exists())

    def test_observation_settings_have_closed_executable_contract(self):
        for provider in ('azure', 'aws'):
            path = ROOT / f'plugins/sdd-{provider}-cloud/references/{provider}-local-config.schema.json'
            schema = json.loads(path.read_bytes())
            self.assertIn('observation', schema['oneOf'][1]['properties'])

    def test_shared_reducer_available(self):
        path = SHARED / 'cloud_verification.py'
        self.assertTrue(path.is_file(), 'Shared reducer has not yet been implemented')
        spec = importlib.util.spec_from_file_location('cloud_verification', path)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertTrue(callable(module.reduce))


def ref(path: str, value: object) -> dict:
    return dict(path=path, sha256=hashlib.sha256(encode(value)).hexdigest())


def reducer_case():
    req = request('aws')
    policy = dict(backup_required=True)
    profile = dict(schema='cloud-verification-profile/v1', id='synthetic-profile', version='1',
                   required_check_ids=['resource', 'network', 'identity', 'monitoring', 'workload', 'backup'],
                   max_age_seconds=300)
    req['verification_profile'] = dict(id=profile['id'], version=profile['version'], **ref('profile.json', profile))
    request_ref = ref('request.json', req)
    context = dict(schema='cloud-collection-context/v1', request=request_ref,
        **{k:copy.deepcopy(req[k]) for k in ('run_id','unit_id','provider','scope','dependency_lock','policy','verification_profile')},
        native_operation_id='synthetic-operation', resource_ids=['synthetic-resource'],
        principal='synthetic-observer', completed_at='2026-10-18T06:00:00Z',
        collected_at='2026-10-18T06:01:00Z', classification='synthetic')
    records = []
    for check in profile['required_check_ids']:
        payload = dict(schema='cloud-check-result/v1', context_sha256=ref('context.json',context)['sha256'],
            check_id=check, status='PASS', reason='HEALTHY', sampled_at='2026-10-18T06:01:00Z',
            queries=[dict(locator='https://synthetic.example/read', request_sha256='a'*64,
                          response_sha256='b'*64, http_status=200)])
        payload_ref = ref(check+'.result.json',payload)
        observation = dict(schema='cloud-observation/v1',
            **{k:context[k] for k in ('run_id','unit_id','provider','native_operation_id','resource_ids','principal','classification')},
            query=check, timestamp=context['collected_at'], exit_code=0, status='PASS', result=payload_ref)
        records.append(dict(check_id=check, observation_path=check+'.json', observation_bytes=encode(observation),
                            payload_bytes=encode(payload)))
    return req, request_ref, profile, policy, context, records


class ReducerCases(unittest.TestCase):
    def reduce(self, case):
        # Missing import is initial component Red only, never mismatch-validation evidence.
        import cloud_verification
        return cloud_verification.reduce(*case, now='2026-10-18T06:01:01Z')

    def test_all_checks_synthetic_never_complete(self):
        result = self.reduce(reducer_case())
        self.assertEqual(result['overall_result'], 'PASS')
        self.assertFalse(result['evidence_complete'])

    def test_each_context_counterpart_mismatch(self):
        for field in ('request','run_id','unit_id','provider','scope','dependency_lock','policy','verification_profile'):
            case = reducer_case()
            ctx = case[4]
            ctx[field] = dict(path='other.json',sha256='f'*64) if isinstance(ctx[field],dict) else 'wrong'
            with self.subTest(field=field), self.assertRaisesRegex(ValueError,'COLLECTION_BINDING_MISMATCH'):
                self.reduce(case)

    def test_each_observation_counterpart_mismatch(self):
        for field in ('run_id','unit_id','provider','native_operation_id','resource_ids','principal','timestamp','query','classification','result','status','exit_code'):
            case = reducer_case()
            record = case[5][0]
            observation = json.loads(record['observation_bytes'])
            replacements = dict(provider='azure',classification='native',resource_ids=['other'],
                timestamp='2026-10-18T05:00:00Z',result=dict(path='other.json',sha256='f'*64),status='FAIL',exit_code=1)
            observation[field] = replacements.get(field,'wrong')
            record['observation_bytes'] = encode(observation)
            with self.subTest(field=field), self.assertRaisesRegex(ValueError,'OBSERVATION_BINDING_MISMATCH'):
                self.reduce(case)

    def test_each_payload_counterpart_mismatch(self):
        for field in ('context_sha256','check_id','status'):
            case = reducer_case()
            record = case[5][0]
            payload = json.loads(record['payload_bytes'])
            payload[field] = 'f'*64 if field == 'context_sha256' else 'wrong'
            record['payload_bytes'] = encode(payload)
            observation = json.loads(record['observation_bytes'])
            observation['result']['sha256'] = hashlib.sha256(record['payload_bytes']).hexdigest()
            record['observation_bytes'] = encode(observation)
            with self.subTest(field=field), self.assertRaisesRegex(ValueError,'OBSERVATION_BINDING_MISMATCH'):
                self.reduce(case)

    def test_check_fail_block_unknown_stale_missing_tampered(self):
        for check in range(6):
            for variant in ('FAIL','BLOCKED','UNKNOWN','stale','missing','tampered'):
                case = reducer_case()
                record = case[5][check]
                observation=json.loads(record['observation_bytes']); payload=json.loads(record['payload_bytes'])
                if variant == 'missing':
                    case[5].pop(check)
                elif variant == 'tampered':
                    record['payload_bytes'] += b' '
                else:
                    if variant == 'stale': payload['sampled_at']='2026-10-18T05:59:59Z'
                    else:
                        payload['status']=observation['status']=variant
                        observation['exit_code']=1
                    record['payload_bytes']=encode(payload)
                    observation['result']['sha256']=hashlib.sha256(record['payload_bytes']).hexdigest()
                    record['observation_bytes']=encode(observation)
                with self.subTest(check=check, variant=variant):
                    if variant in ('missing','tampered'):
                        with self.assertRaises(ValueError): self.reduce(case)
                    else:
                        result=self.reduce(case)
                        self.assertEqual(result['overall_result'],'FAIL' if variant=='FAIL' else 'BLOCKED')
                        self.assertFalse(result['evidence_complete'])

    def test_context_shape_and_window(self):
        for field, value in [('schema','unknown/v1'),('extra',True),('completed_at','2026-10-18T06:02:00Z'),
                             ('collected_at','2026-10-18T06:02:00Z'),('classification','native')]:
            case=reducer_case();case[4][field]=value
            with self.subTest(field=field), self.assertRaises(ValueError): self.reduce(case)

    def test_profile_policy_and_check_set(self):
        for variant in ('missing-backup','profile-version','profile-digest','extra-check','duplicate-check'):
            case=reducer_case()
            if variant=='missing-backup': case[2]['required_check_ids'].remove('backup')
            elif variant=='profile-version': case[2]['version']='9'
            elif variant=='profile-digest': case[2]['max_age_seconds']=900
            elif variant=='extra-check': case[2]['required_check_ids'].append('unknown')
            else: case[5].append(copy.deepcopy(case[5][0]))
            with self.subTest(variant=variant), self.assertRaises(ValueError): self.reduce(case)

    def test_query_trace_shape(self):
        for field,value in [('locator','http://untrusted.example'),('request_sha256','wrong'),
                            ('response_sha256','wrong'),('http_status',-1),('extra','unknown')]:
            case=reducer_case();record=case[5][0];payload=json.loads(record['payload_bytes'])
            payload['queries'][0][field]=value;record['payload_bytes']=encode(payload)
            observation=json.loads(record['observation_bytes'])
            observation['result']['sha256']=hashlib.sha256(record['payload_bytes']).hexdigest()
            record['observation_bytes']=encode(observation)
            with self.subTest(field=field), self.assertRaises(ValueError):self.reduce(case)


if __name__ == '__main__':
    unittest.main(verbosity=2)
