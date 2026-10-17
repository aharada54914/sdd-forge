#!/usr/bin/env python3
"""Validate feature Concept Test evidence before domain sync. Content is data."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import subprocess
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


auth = load_module('concept_approval', ROOT / 'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py')
conditional = load_module('concept_inputs', ROOT / 'plugins/sdd-quality-loop/scripts/review-conditional-inputs.py')


def parse(raw):
    return json.loads(raw, object_pairs_hook=conditional.unique_object)


def evidence(root, feature, read=None):
    """Return the evidence plus every pinned input, using live or fixed reads."""
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', feature):
        raise ValueError('invalid feature')
    source = read or (lambda path: conditional.read_safe(root, path))
    snapshot_bytes = {}

    def read(path):
        if path not in snapshot_bytes:
            snapshot_bytes[path] = source(path)
        return snapshot_bytes[path]
    prefix = 'specs/' + feature + '/concept-test'
    document = parse(read(prefix + '.json'))
    schema = parse((ROOT / 'contracts/concept-test.v1.schema.json').read_bytes())
    errors = auth._schema_validate(schema, document)
    if errors or document.get('feature') != feature:
        raise ValueError('invalid Concept Test record')
    blocks = re.findall(r'^```json\r?\n(.*?)^```[ \t]*\r?$', read(prefix + '.md').decode('utf-8'), re.M | re.S)
    if len(blocks) != 1 or json.dumps(parse(blocks[0]), sort_keys=True) != json.dumps(document, sort_keys=True):
        raise ValueError('Markdown and JSON evidence differ')
    paths = set()
    for item in document['inputs']:
        path = item['path']
        if path in paths or path.startswith(prefix + '.'):
            raise ValueError('duplicate or circular Concept Test input')
        # Enforce canonical paths even when the supplied reader uses Git blobs.
        if path.startswith('/') or '\\' in path or ':' in path or any(p in ('', '.', '..') for p in path.split('/')):
            raise ValueError('unsafe Concept Test input')
        if not path.startswith('domain/') and path != 'specs/' + feature + '/concept-test-seed.md':
            raise ValueError('Concept Test inputs must be domain evidence or the feature seed')
        paths.add(path)
        if hashlib.sha256(read(path)).hexdigest() != item['sha256']:
            raise ValueError('Concept Test input changed')
    if not {'domain/domain-contract.json', 'specs/' + feature + '/concept-test-seed.md'} <= paths:
        raise ValueError('domain contract and feature seed must be pinned')
    domain = parse(read('domain/domain-contract.json'))
    domain_schema = parse((ROOT / 'contracts/domain-contract.v2.schema.json').read_bytes())
    if auth._schema_validate(domain_schema, domain):
        raise ValueError('invalid v2 domain contract')
    if domain['meta']['status'] != 'Approved':
        raise ValueError('domain model must be approved')
    if 'domain/context-map.md' not in paths or not re.search(
            r'^Domain-Model-Status: Approved[ \t]*\r?$', read('domain/context-map.md').decode('utf-8'), re.M):
        raise ValueError('approved context map must be pinned')
    if not set(domain['meta']['generated_from']) <= paths:
        raise ValueError('domain source inputs must be pinned')
    known = {c['id'] for c in domain['concepts']}
    for distinction in document['distinctions']:
        if not set(distinction['concepts']) <= known:
            raise ValueError('unknown concept in distinction')
    if document['proposal'] == 'FITS_EXISTING_CONCEPTS':
        if 'decision' in document:
            raise ValueError('FITS evidence must omit decision')
    elif 'decision' not in document:
        raise ValueError('human decision is required')
    result = [{'path': prefix + ext, 'sha256': hashlib.sha256(read(prefix + ext)).hexdigest()}
              for ext in ('.md', '.json')]
    result.extend(document['inputs'])
    if document['proposal'] != 'FITS_EXISTING_CONCEPTS':
        sidecar = prefix + '.approval.json'
        result.append({'path': sidecar, 'sha256': hashlib.sha256(read(sidecar)).hexdigest()})
    # Reuse the exact gate checks against the selected source, including Git
    # snapshots. Never fall back to live files when resolving a fixed revision.
    with tempfile.TemporaryDirectory(prefix='concept-validation-') as temporary:
        snapshot = Path(temporary)
        contract_path = snapshot / 'domain-contract.json'
        contract_path.write_bytes(read('domain/domain-contract.json'))
        validator = Path(__file__).with_name('validate-domain-contract')
        command = (['pwsh', '-NoProfile', '-File', str(validator.with_suffix('.ps1'))]
                   if os.name == 'nt' else ['bash', str(validator.with_suffix('.sh'))])
        validation = subprocess.run(command + [str(contract_path)], capture_output=True, timeout=30)
        if validation.returncode:
            raise ValueError('invalid v2 domain contract references')
        if document['proposal'] != 'FITS_EXISTING_CONCEPTS':
            content = snapshot / 'concept-test.json'
            approval = snapshot / 'concept-test.approval.json'
            registry = snapshot / 'approver-registry.yaml'
            content.write_bytes(read(prefix + '.json'))
            approval.write_bytes(read(prefix + '.approval.json'))
            registry.write_bytes(read('sdd/approver-registry.yaml'))
            if parse(approval.read_bytes()).get('schema') != 'sdd-concept-test-approval/v1':
                raise ValueError('wrong approval type')
            try:
                auth.run_standard_validation(content, approval, registry)
            except auth.ValidateApprovalSidecarError as error:
                raise ValueError('invalid Concept Test approval') from error
    return document, result


def validate(root, feature):
    root = Path(root).resolve(strict=True)
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', feature):
        raise ValueError('invalid feature')
    domain = root / 'domain'
    if domain.is_symlink() or (domain.exists() and not domain.is_dir()):
        raise ValueError('unsafe domain directory')
    if not domain.exists():
        return 'SKIP'
    document, _ = evidence(root, feature)
    return {'proceed': 'CONTINUE', 'defer-to-domain-update': 'DEFER', 'rejected': 'REJECT'}.get(document.get('decision'), 'CONTINUE')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--feature', required=True)
    args = parser.parse_args()
    try:
        result = validate(args.root, args.feature)
        print(result)
        return {'SKIP': 0, 'CONTINUE': 0, 'DEFER': 2, 'REJECT': 3}[result]
    except (OSError, ValueError, KeyError, TypeError, UnicodeError, subprocess.SubprocessError, auth.ValidateApprovalSidecarError):
        print('concept-test: BLOCK: evidence is missing, invalid, stale, or unapproved', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
