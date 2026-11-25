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


DECISIONS = {'proceed': 'CONTINUE', 'defer-to-domain-update': 'DEFER', 'rejected': 'REJECT'}


def check_schema(filename, document):
    schema = parse((ROOT / 'contracts' / filename).read_bytes())
    if not isinstance(document, dict) or auth._schema_validate(schema, document):
        raise ValueError('invalid Concept Test document')


def snapshot_reader(source):
    observed = {}

    def read(path, optional=False):
        if path not in observed:
            observed[path] = source(path, optional)
        if observed[path] is None and not optional:
            raise ValueError('missing Concept Test input: ' + path)
        return observed[path]

    return read, observed


def collect(feature, read, *, allow_local, require_v2=False, preparing=False):
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', feature):
        raise ValueError('invalid feature')
    prefix = 'specs/' + feature + '/concept-test'
    document = parse(read(prefix + '.json'))
    version = document.get('schema') if isinstance(document, dict) else None
    if version == 'concept-test/v2' and allow_local:
        check_schema('concept-test.v2.schema.json', document)
    elif version == 'concept-test/v1' and not require_v2:
        check_schema('concept-test.v1.schema.json', document)
    else:
        raise ValueError('unsupported Concept Test version for this operation')
    if document['feature'] != feature:
        raise ValueError('wrong Concept Test feature')
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
    fits = document['proposal'] == 'FITS_EXISTING_CONCEPTS'
    legacy = version == 'concept-test/v1'
    approval_path = prefix + '.approval.json'
    decision_path = prefix + '.decision.json'
    approval = read(approval_path, True)
    decision_raw = read(decision_path, True)
    if (fits and (approval is not None or decision_raw is not None or 'decision' in document)
            or legacy and decision_raw is not None or not legacy and approval is not None):
        raise ValueError('incompatible Concept Test decision records')
    result = [{'path': prefix + ext, 'sha256': hashlib.sha256(read(prefix + ext)).hexdigest()}
              for ext in ('.md', '.json')]
    result.extend(document['inputs'])
    if not fits and legacy:
        if 'decision' not in document or approval is None:
            raise ValueError('signed human decision is required')
        result.append({'path': approval_path, 'sha256': hashlib.sha256(approval).hexdigest()})
    elif not fits:
        if decision_raw is not None:
            decision = parse(decision_raw)
            check_schema('concept-test-decision.v1.schema.json', decision)
            if decision['feature'] != feature:
                raise ValueError('wrong local decision feature')
            if not preparing:
                if (decision['proposal_md_sha256'] != result[0]['sha256']
                        or decision['proposal_json_sha256'] != result[1]['sha256']):
                    raise ValueError('local decision refers to an earlier proposal')
                document = dict(document, decision=decision['decision'])
                result.append({'path': decision_path, 'sha256': hashlib.sha256(decision_raw).hexdigest()})
        elif not preparing:
            raise ValueError('run --confirm in a separate human-operated terminal')
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
        if not fits and legacy:
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


class FeatureNameError(ValueError):
    """A feature name the DDD lane cannot use; the message says why."""


def evidence(root, feature, read=None, *, allow_local=False, require_v2=False):
    """Legacy decision packets require signed evidence. Other consumers opt in explicitly."""
    source = read or (lambda path, optional: conditional.read_safe(root, path, optional))
    cached, observed = snapshot_reader(source)
    document, inputs = collect(feature, cached, allow_local=allow_local, require_v2=require_v2)
    for path, data in observed.items():
        if source(path, True) != data:
            raise ValueError('Concept Test inputs changed during validation')
    return document, inputs


def validate(root, feature, require_v2=False):
    root = Path(root).resolve(strict=True)
    # Applicability first (#809): without domain/ the Concept Test does not
    # apply, for every feature name ship accepts (no separators, not . or ..).
    if not feature or feature in ('.', '..') or re.search(r'[\\/\0]', feature):
        raise ValueError('invalid feature')
    domain = root / 'domain'
    if domain.is_symlink() or (domain.exists() and not domain.is_dir()):
        raise ValueError('unsafe domain directory')
    if not domain.exists() and not require_v2:
        return 'SKIP'
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', feature):
        raise FeatureNameError('concept-test: BLOCK: DDD features need lowercase kebab-case names '
                               '([a-z0-9][a-z0-9-]*); rename specs/' + feature + '/ to use the DDD lane')
    document, _ = evidence(root, feature, allow_local=True, require_v2=require_v2)
    return DECISIONS[document['decision']] if 'decision' in document else 'CONTINUE'


def confirm(root, feature):
    """Record one local operator choice. The terminal is an operational boundary, not authentication."""
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        raise ValueError('confirmation requires an interactive human-operated terminal')
    root = Path(root).resolve(strict=True)
    source = lambda path, optional: conditional.read_safe(root, path, optional)
    cached, observed = snapshot_reader(source)
    proposal, inputs = collect(feature, cached, allow_local=True, require_v2=True, preparing=True)
    if proposal['proposal'] == 'FITS_EXISTING_CONCEPTS':
        raise ValueError('FITS needs no decision')
    prefix = 'specs/' + feature + '/concept-test'
    decision_path = prefix + '.decision.json'
    receipt = {'schema': 'concept-test-decision/v1', 'feature': feature,
               'proposal_md_sha256': inputs[0]['sha256'], 'proposal_json_sha256': inputs[1]['sha256']}
    display = {'project': str(root), **proposal, 'proposal_md_sha256': receipt['proposal_md_sha256'],
               'proposal_json_sha256': receipt['proposal_json_sha256']}
    if observed[decision_path] is not None:
        display['previous_local_decision'] = parse(observed[decision_path])
    # Escape control characters in project-authored text before displaying it on the terminal.
    rendered = json.dumps(display, indent=2, ensure_ascii=False)
    print(''.join(ch if ch == '\n' or ch.isprintable() else json.dumps(ch)[1:-1] for ch in rendered))
    answer = input('Select proceed / defer-to-domain-update / rejected (Enter cancels): ').strip()
    if answer not in DECISIONS:
        raise ValueError('no valid decision selected')
    receipt['decision'] = answer
    dest = root / decision_path
    lock = dest.with_suffix('.lock')
    # Only one issuer can publish. Compare the complete proposal and previous decision after
    # the operator replies so concurrent confirmations cannot silently overwrite one another.
    def check_unchanged(expected):
        for path, data in expected.items():
            if source(path, True) != data:
                raise ValueError('inputs or the prior decision changed during confirmation')

    check_unchanged(observed)
    owner = lock.open('x')
    try:
        with tempfile.TemporaryDirectory(dir=dest.parent) as staging:
            temporary = Path(staging) / 'decision.json'
            with temporary.open('w', encoding='utf-8', newline='\n') as output:
                json.dump(receipt, output, ensure_ascii=False, indent=2)
                output.write('\n')
                output.flush()
                os.fsync(output.fileno())
            published = temporary.read_bytes()
            check_unchanged(observed)
            os.replace(temporary, dest)
            # Project inputs can be edited independently of the issuer lock. If the
            # published decision cannot be admitted, preserve the previous choice.
            try:
                outcome = validate(root, feature, require_v2=True)
                check_unchanged({**observed, decision_path: published})
                return outcome
            except (Exception, KeyboardInterrupt):
                if source(decision_path, True) == published:
                    previous = observed[decision_path]
                    if previous is None:
                        dest.unlink()
                    else:
                        temporary.write_bytes(previous)
                        os.replace(temporary, dest)
                raise
    finally:
        owner.close()
        lock.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--root', required=True)
    parser.add_argument('--feature', required=True)
    parser.add_argument('--require-v2', action='store_true', help='reject missing domain or older proposals')
    parser.add_argument('--confirm', action='store_true', help='interactively record a local v2 decision')
    args = parser.parse_args()
    try:
        result = confirm(args.root, args.feature) if args.confirm else validate(args.root, args.feature, args.require_v2)
        print(result)
        return {'SKIP': 0, 'CONTINUE': 0, 'DEFER': 2, 'REJECT': 3}[result]
    except FeatureNameError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (EOFError, KeyboardInterrupt):
        print('concept-test: BLOCK: confirmation cancelled', file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError, TypeError, UnicodeError, subprocess.SubprocessError, auth.ValidateApprovalSidecarError) as error:
        print('concept-test: BLOCK: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
