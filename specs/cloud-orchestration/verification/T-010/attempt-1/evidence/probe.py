"""Offline T-010 preflight reachability, not dependency acceptance evidence."""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys
from types import ModuleType
from unittest.mock import patch


def load(root: Path, filename: str, name: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(name, root / 'tests' / filename)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(root: Path) -> None:
    execution = load(root, 'cloud-orchestration-execution.tests.py', 'dependency_execution_probe')
    verification = load(root, 'cloud-orchestration-verification.tests.py', 'dependency_verification_probe')
    observations: list[dict] = []
    import urllib.request
    with patch('urllib.request.OpenerDirector.open', side_effect=AssertionError('T010_NETWORK_FORBIDDEN')):
        try:
            urllib.request.OpenerDirector().open('https://invalid.example')
        except AssertionError as exc:
            assert str(exc) == 'T010_NETWORK_FORBIDDEN'
            observations.append(dict(case='network-sentinel', result='intercepted-before-I/O'))
        else:
            raise AssertionError('network sentinel not exercised')
        for provider in ('aws', 'azure'):
            for stage in ('prepare', 'apply'):
                for variant in ('empty', 'local-pass', 'failed', 'incomplete', 'wrong-run', 'wrong-unit', 'wrong-provider', 'wrong-profile', 'tamper', 'missing'):
                    case = execution.Admission()
                    case.setUp()
                    try:
                        case.setup_case(provider, stage)
                        if variant != 'empty':
                            profile_ref = case.put('bundle/prior-profile.json', dict(schema='cloud-verification-profile/v1', id='cloud-compute', version='2', required_check_ids=['resource','network','identity','monitoring','workload'], max_age_seconds=300))
                            observation_ref = case.put('bundle/prior-observation.json', b'{}')
                            receipt: dict = dict(schema='cloud-verification/v1', run_id='prior-run', unit_id='prior', provider=provider,
                                           profile=dict(id='cloud-compute', version='2', **profile_ref),
                                           required_check_ids=['resource'], checks=[dict(check_id='resource', result='PASS', observation=observation_ref)],
                                           overall_result='PASS', evidence_complete=True)
                            # These are locally asserted labels, NEVER authenticated proof.
                            if variant == 'failed':
                                receipt.update(overall_result='FAIL', evidence_complete=False)
                                receipt['checks'][0]['result'] = 'FAIL'
                            if variant == 'incomplete':
                                receipt['evidence_complete'] = False
                            for field, name in (('run_id','wrong-run'), ('unit_id','wrong-unit'), ('provider','wrong-provider')):
                                if variant == name:
                                    receipt[field] = ('azure' if provider == 'aws' else 'aws') if field == 'provider' else 'wrong'
                            if variant == 'wrong-profile':
                                receipt['profile']['version'] = '999'
                            directory = f"specs/{case.request['local_context']['feature']}/verification/T-010/cloud/prior-run/prior"
                            reference = case.put(directory + '/verification.json', receipt)
                            case.request['predecessor_receipts'] = [dict(unit_id='prior', **reference)]
                            case.request_ref = case.put('request.json', case.request)
                            if case.preview_ref:
                                preview = json.loads((case.root / case.preview_ref['path']).read_bytes())
                                preview['request'] = case.request_ref
                                case.preview_ref = case.put(case.preview_ref['path'], preview)
                            case.transport.run['display_title'] = 'cloud:' + case.request_ref['sha256'] + ':' + (case.preview_ref['sha256'] if case.preview_ref else 'none')
                            if variant == 'tamper':
                                (case.root / reference['path']).write_bytes(b'{}')
                            if variant == 'missing':
                                (case.root / reference['path']).unlink()
                        points: list[str] = []
                        original_require = case.a.require
                        original_contract_require = execution.contracts._require
                        original_binding = execution.contracts.verify_binding

                        def binding(*args, **kwargs):
                            try:
                                return original_binding(*args, **kwargs)
                            except Exception as exc:
                                points.append('binding:' + type(exc).__name__ + ':' + str(exc))
                                raise

                        def admission_require(condition: object, code: str = 'ADMISSION_DENIED') -> None:
                            if not condition:
                                points.append('admission:' + code)
                            original_require(condition, code)

                        def contract_require(condition: object, code: str = 'INVALID_ARTIFACT') -> None:
                            if not condition:
                                points.append('contract:' + code)
                            original_contract_require(condition, code)

                        with patch.object(case.a, 'require', side_effect=admission_require), patch.object(execution.contracts, '_require', side_effect=contract_require), patch.object(execution.contracts, 'verify_binding', side_effect=binding):
                            try:
                                case.write()
                                outcome = 'submitted-synthetic-callback'
                            except case.a.AdmissionDenied as exc:
                                outcome = str(exc)
                        expected_point = {
                            'wrong-run': 'binding:ContractError:PREDECESSOR_PATH_MISMATCH',
                            'wrong-unit': 'binding:ContractError:PREDECESSOR_MISMATCH',
                            'tamper': 'binding:ContractError:DIGEST_MISMATCH',
                            'missing': 'binding:ContractError:UNSAFE_OR_UNAVAILABLE_FILE',
                        }.get(variant, 'admission:DEPENDENCY_ADMISSION_REQUIRED')
                        if variant == 'empty':
                            assert points == []
                        else:
                            assert points[-1] == expected_point, points
                        assert len(case.writes) == (1 if variant == 'empty' else 0)
                        observations.append(dict(provider=provider, stage=stage, case=variant, outcome=outcome,
                                                 failure_points=points, synthetic_submissions=len(case.writes),
                                                 authenticated_service_calls=len(case.transport.calls)))
                    finally:
                        case.doCleanups()
        completion = verification.AzureCompletionCases()
        completion.setUp()
        try:
            stamp = completion.completion()
            observations.append(dict(case='existing-apply-job-control', completion=stamp))

            def verify_job(run: dict, job: dict, jobs: dict, workflow: dict) -> None:
                job['name'] = 'verify'
                job['steps'][0]['name'] = workflow['jobs']['verify']['steps'][1]['name']

            try:
                completion.completion(verify_job)
            except ValueError as exc:
                assert str(exc) == 'ORIGINAL_APPLY_JOB_REQUIRED'
                observations.append(dict(case='verify-job-through-existing-apply-primitive', failure_point=str(exc),
                                         classification='unsupported-purpose; not an executed verify-producer field guard'))
            else:
                raise AssertionError('apply-specific primitive unexpectedly accepted verify job')
        finally:
            completion.doCleanups()
    print(json.dumps(dict(classification='synthetic-protocol-only', observations=observations,
                         production_edits=False, complete_preflight=False), indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo-root', type=Path, required=True)
    args = parser.parse_args()
    sys.dont_write_bytecode = True
    main(args.repo_root.resolve())
