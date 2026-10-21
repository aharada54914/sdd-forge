#!/usr/bin/env python3
"""External transport adapter; the pinned repository collector remains unchanged."""
import argparse
import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def strict_json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'duplicate JSON key')
            result[key] = value
        return result
    def invalid_constant(_):
        raise ValueError('non-finite JSON constant')
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid_constant)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read_bounded(value, maximum):
    path = Path(value)
    require(path.is_absolute() and not path.is_symlink() and path.is_file(), 'invalid local input file')
    with path.open('rb') as handle:
        raw = handle.read(maximum + 1)
    require(len(raw) <= maximum, 'local input exceeds bound')
    return raw


def load_collector(manifest):
    source = manifest['collector']
    raw = read_bounded(source['path'], 1024 * 1024)
    require(re.fullmatch(r'[0-9a-f]{64}', source['sha256']) is not None
            and sha(raw) == source['sha256'], 'collector source pin mismatch')
    path = Path(source['path'])
    require(path.name == 'verification-ci.py' and path.parent.name == 'tests', 'unexpected collector path')
    spec = importlib.util.spec_from_file_location('external_pinned_ci_collector', path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    require(sha(path.read_bytes()) == source['sha256'], 'collector changed during import')
    return module


def prepare(manifest, collector):
    require(manifest.get('schema') == 'connector-artifact-transport/v1', 'unsupported transport manifest')
    repository, run_id, head = manifest['repository'], manifest['run_id'], manifest['head_sha']
    require(isinstance(repository, str) and collector.repository_identity(repository), 'invalid repository')
    require(isinstance(run_id, str) and collector.run_identity(run_id), 'invalid run ID')
    require(isinstance(head, str) and re.fullmatch(r'[0-9a-f]{40}', head), 'invalid head SHA')
    rows = manifest['artifacts']
    require(isinstance(rows, list) and 0 < len(rows) <= 1000, 'invalid artifact allowlist size')
    prefix = f'/repos/{repository}/actions'
    # Fresh authoritative metadata uses exactly the original authenticated transport.
    run, _ = collector.api_get(prefix + '/runs/' + run_id)
    require(run.get('id') == int(run_id) and run.get('head_sha') == head
            and run.get('repository', {}).get('full_name') == repository, 'fresh run binding mismatch')
    cached, receipts, total_bytes = {}, [], 0
    for row in rows:
        artifact_id = row['artifact_id']
        require(type(artifact_id) is int and artifact_id > 0, 'invalid artifact ID')
        endpoint = prefix + f'/artifacts/{artifact_id}/zip'
        require(row['endpoint'] == endpoint and endpoint not in cached, 'endpoint mismatch or duplicate')
        digest = row['sha256']
        require(isinstance(digest, str) and re.fullmatch(r'[0-9a-f]{64}', digest), 'invalid ZIP hash')
        require(type(row['size_bytes']) is int and 0 < row['size_bytes'] <= collector.MAX_RESPONSE_BYTES,
                'invalid ZIP size')
        metadata_raw = read_bounded(row['metadata_path'], 1024 * 1024)
        require(sha(metadata_raw) == row['metadata_sha256'], 'saved artifact metadata hash mismatch')
        saved = strict_json(metadata_raw)
        fresh, _ = collector.api_get(prefix + f'/artifacts/{artifact_id}')
        for metadata in (saved, fresh):
            require(isinstance(metadata, dict) and metadata.get('id') == artifact_id
                    and metadata.get('name') == row['name'] and metadata.get('expired') is False
                    and metadata.get('digest') == 'sha256:' + digest
                    and metadata.get('workflow_run', {}).get('id') == int(run_id)
                    and metadata.get('workflow_run', {}).get('head_sha') == head,
                    'artifact metadata binding or digest mismatch')
        require(isinstance(row['name'], str) and row['name'].startswith('verification-receipts-'),
                'artifact is outside receipt scope')
        raw = read_bounded(row['zip_path'], collector.MAX_RESPONSE_BYTES)
        require(len(raw) == row['size_bytes'] and sha(raw) == digest, 'ZIP bytes mismatch')
        total_bytes += len(raw)
        require(total_bytes <= 256 * 1024 * 1024, 'combined ZIP inputs exceed bound')
        # Keep verified bytes immutable in memory; there is no later file-read race.
        cached[endpoint] = raw
        receipts.append(dict(artifact_id=artifact_id, endpoint=endpoint, name=row['name'],
                             sha256=digest, size_bytes=len(raw), metadata_sha256=sha(metadata_raw),
                             fresh_metadata_checked=True, zip_response_headers_observed=False))
    return cached, receipts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--transport-report', type=Path, required=True)
    args = parser.parse_args()
    require(not args.output_dir.exists() and not args.transport_report.exists(), 'outputs must be create-only')
    require(args.transport_report.resolve() != args.manifest.resolve(), 'report cannot replace manifest')
    manifest_raw = read_bounded(str(args.manifest.resolve()), 2 * 1024 * 1024)
    manifest = strict_json(manifest_raw)
    collector = load_collector(manifest)
    cached, receipts = prepare(manifest, collector)
    original = collector.api_response
    used = []

    def api_response(endpoint):
        if endpoint in cached:
            used.append(endpoint)
            # Connector ZIP download exposes bytes, not HTTP headers. None are invented.
            return cached[endpoint], {}
        return original(endpoint)

    collector.api_response = api_response
    try:
        collector.collect(manifest['repository'], manifest['run_id'], args.output_dir)
    finally:
        collector.api_response = original
    require(set(used) == set(cached) and len(used) == len(cached), 'unused or repeated ZIP allowlist entry')
    require(sha(Path(manifest['collector']['path']).read_bytes()) == manifest['collector']['sha256'],
            'collector source changed during collection')
    report = dict(schema='connector-artifact-transport-report/v1',
                  recorded_at=dt.datetime.now(dt.timezone.utc).isoformat(),
                  manifest_sha256=sha(manifest_raw), controller_sha256=sha(Path(__file__).read_bytes()),
                  collector=manifest['collector'], repository=manifest['repository'],
                  run_id=manifest['run_id'], head_sha=manifest['head_sha'], artifacts=receipts,
                  transport='pre-downloaded connector ZIP bytes; all other API calls use original gh transport',
                  collector_logic='unchanged collect/validate/extract; aggregation not invoked by this controller',
                  status='collection-completed-not-aggregate-acceptance')
    args.transport_report.parent.mkdir(parents=True, exist_ok=True)
    with args.transport_report.open('x', encoding='utf-8') as handle:
        json.dump(report, handle, indent=2)
        handle.write('\n')
    print(json.dumps({'status': report['status'], 'artifacts': len(receipts)}))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, AttributeError):
        # Bound error text: never echo URLs, authentication, or remote response bodies.
        print('External artifact transport rejected invalid or unavailable input.', file=sys.stderr)
        sys.exit(2)
