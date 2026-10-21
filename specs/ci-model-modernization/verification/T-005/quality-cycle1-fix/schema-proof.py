"""Run frozen 40-case proof and original-string URI producer/CLI cases with real jsonschema."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time

import jsonschema

ROOT = Path('/workspace/sdd-forge')
OLD = ROOT / 'specs/ci-model-modernization/verification/T-005/attempt-1'
BASE = ROOT / 'specs/ci-model-modernization/verification/T-005/quality-cycle1-fix'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    old_driver = OLD / 'supplemental-schema-final-proof.py'
    old = module('qa1_frozen_boundary_proof', old_driver)
    old.OUTPUT = BASE / 'frozen-40-results.json'
    assert old.main() == 0
    fixture_path = OLD / 'independent-schema-proof.py'
    fixture = module('qa1_uri_fixture', fixture_path)
    helper_path = ROOT / 'plugins/sdd-implementation/scripts/model-policy.py'
    helper = module('qa1_uri_helper', helper_path)
    schema_path = ROOT / 'contracts/model-selection.schema.json'
    schema = json.loads(schema_path.read_bytes())
    jsonschema.Draft202012Validator.check_schema(schema)
    validator = jsonschema.Draft202012Validator(schema)
    pattern = schema['properties']['estimate']['anyOf'][0]['properties']['source_url']['pattern']
    assert helper._HTTPS_METADATA_RE.pattern == pattern
    cases = [
        ('empty-domain-path', 'https://pricing.example.invalid:/pricing', True),
        ('empty-domain-uppercase', 'HTTPS://pricing.example.invalid:', True),
        ('empty-ipv6-path', 'https://[::1]:/pricing', True),
        ('empty-ipv6', 'https://[2001:db8::1]:', True),
        ('suffix-ipv6', 'https://[::1]garbage/pricing', False),
        ('suffix-ipv6-port', 'https://[::1]garbage:443/pricing', False),
        ('suffix-ipv6-long', 'https://[2001:db8::1]unexpected/pricing', False),
        *[('leading-control-' + str(code), chr(code) + 'https://pricing.example.invalid/pricing', False)
          for code in (0, 1, 27)],
    ]
    output = BASE / 'uri-proof'
    output.mkdir(exist_ok=False)
    results = []
    for name, url, accepted in cases:
        record = fixture.selection()
        record['binding'] = None
        record['estimate']['source_url'] = url
        record = fixture.seal(record)
        assert validator.is_valid(record) == accepted
        bound = None
        try:
            helper.validate_selection_record(record)
            bound = helper.bind_selection(record, run_id='run-fixture', session_id='session-fixture', attempt=1)
            runtime_ok = True
        except helper.PolicyError as error:
            runtime_ok = False
            assert error.reason == 'input-invalid'
        assert runtime_ok == accepted
        if accepted:
            assert validator.is_valid(bound)
            assert bound['estimate']['source_url'] == url
        work = output / name
        work.mkdir()
        raw = fixture.canonical(record)
        (work / 'selection.json').write_bytes(raw)
        argv = [sys.executable, '-B', str(helper_path), 'bind', '--selection', 'selection.json',
                '--run-id', 'run-fixture', '--session-id', 'session-fixture', '--attempt', '1',
                '--output', 'bound.json']
        started = datetime.now(timezone.utc).isoformat()
        tick = time.monotonic()
        actual = subprocess.run(argv, cwd=work, capture_output=True)
        elapsed = time.monotonic() - tick
        (work / 'stdout').write_bytes(actual.stdout)
        (work / 'stderr').write_bytes(actual.stderr)
        assert (work / 'selection.json').read_bytes() == raw
        if accepted:
            assert actual.returncode == 0
            published = json.loads((work / 'bound.json').read_bytes())
            validator.validate(published)
            assert published['estimate']['source_url'] == url
            assert published == bound
        else:
            assert actual.returncode == 2
            assert json.loads(actual.stderr)['reason'] == 'input-invalid'
            assert not (work / 'bound.json').exists()
        results.append({'case': name, 'url': url, 'expected_accept': accepted,
                        'schema_accept': accepted, 'runtime_accept': runtime_ok,
                        'cli_argv': argv, 'cwd': str(work), 'started_at': started,
                        'elapsed_seconds': elapsed, 'cli_exit_code': actual.returncode,
                        'stdout_sha256': sha(actual.stdout), 'stderr_sha256': sha(actual.stderr),
                        'input_sha256': sha(raw), 'bound_sha256': sha((work / 'bound.json').read_bytes()) if accepted else None,
                        'passed': True})
    report = {'schema': 'task-local-original-uri-proof/v1', 'ticket_id': 'RT-20261019-019',
              'red_commit': 'ab98aa5670c5b6764778e6ce2066f483b9b1c9ed',
              'frozen_supplement_cases': 40, 'new_uri_cases': len(cases), 'cases': results,
              'shared_lexical_pattern_identical': True, 'native_execution': False,
              'sources': [{'path': str(p.relative_to(ROOT)), 'sha256': sha(p.read_bytes())}
                          for p in (old_driver, fixture_path, helper_path, schema_path, Path(__file__))]}
    (BASE / 'uri-schema-results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'frozen_cases': 40, 'uri_cases': len(cases), 'passed': True}))


if __name__ == '__main__':
    main()
