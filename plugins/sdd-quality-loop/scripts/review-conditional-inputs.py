#!/usr/bin/env python3
"""Resolve role-defined conditional inputs without reserving review identities."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

sys.dont_write_bytecode = True


def read_safe(root, relative, optional=False):
    parts = relative.split('/')
    if any(p in ('', '.', '..') for p in parts) or '\\' in relative:
        raise ValueError('unsafe conditional input path')
    current = root
    for i, part in enumerate(parts):
        if current.exists() and part not in {p.name for p in current.iterdir()}:
            if optional:
                return None
            raise ValueError('missing conditional input: ' + relative)
        current = current / part
        try:
            mode = current.lstat().st_mode
        except FileNotFoundError:
            if optional:
                return None
            raise ValueError('missing conditional input: ' + relative)
        if stat.S_ISLNK(mode) or (i < len(parts) - 1 and not stat.S_ISDIR(mode)):
            raise ValueError('unsafe conditional input: ' + relative)
        if i == len(parts) - 1 and not stat.S_ISREG(mode):
            raise ValueError('non-regular conditional input: ' + relative)
    return current.read_bytes()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key')
        result[key] = value
    return result


def failed_research_history(root, feature, stage, relative):
    """Saved failed-review agreement only; does not verify current source bytes."""
    match = re.fullmatch(r'reports/impl-review/' + re.escape(feature) +
                         r'/attempt-([1-9][0-9]*)/round-([1-9][0-9]*)/impl-review-contract.json', relative)
    if stage != 'impl' or match is None:
        raise ValueError('invalid failed research history location')
    directory = relative.rsplit('/', 1)[0]

    def saved(name):
        value = json.loads(read_safe(root, directory + '/' + name), object_pairs_hook=unique_object)
        if not isinstance(value, dict):
            raise ValueError('invalid failed research history object')
        return value

    contract = saved('impl-review-contract.json')
    verdict = saved('integrated-verdict.json')
    if (contract.get('schema') != 'impl-review-contract/v1'
            or verdict.get('schema') != 'integrated-verdict/v1'
            or contract.get('verdict') not in ('NEEDS_WORK', 'BLOCKED')
            or any(contract.get(key) != verdict.get(key) for key in
                   ('feature', 'stage', 'attempt', 'round', 'verdict', 'run_id'))
            or contract.get('feature') != feature or contract.get('stage') != stage
            or not isinstance(contract.get('run_id'), str) or not contract['run_id'].strip()
            or type(contract.get('attempt')) is not int or type(contract.get('round')) is not int
            or contract.get('attempt') != int(match[1]) or contract.get('round') != int(match[2])):
        raise ValueError('failed research history identity mismatch')
    trio = {f'specs/{feature}/research/{name}' for name in
            ('records/research-evidence.json', 'relations.json', 'review-input.json')}
    declared_entries = contract.get('adr_inputs', [])
    if not isinstance(declared_entries, list) or any(not isinstance(entry, dict)
            or not isinstance(entry.get('path'), str) for entry in declared_entries):
        raise ValueError('invalid failed design ADR declarations')
    declared = {entry['path'] for entry in declared_entries}

    def pins(owner):
        selected = {}
        manifest = owner.get('allowed_input_manifest')
        if not isinstance(manifest, list):
            raise ValueError('invalid failed research manifest')
        for entry in manifest:
            if (not isinstance(entry, dict) or set(entry) != {'path', 'sha256'}
                    or not isinstance(entry['path'], str) or not isinstance(entry['sha256'], str)
                    or re.fullmatch(r'[0-9a-f]{64}', entry['sha256']) is None):
                raise ValueError('invalid failed research pin')
            path = entry['path'].replace('\\', '/')
            if any(part in ('.', '..') for part in path.split('/')):
                raise ValueError('invalid failed research path')
            candidates = [name for name in trio if path == name or path.endswith('/' + name)]
            adr = re.search(r'(?:^|/)(docs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*[.]md)$', path)
            if adr and adr[1] not in declared:
                candidates.append(adr[1])
            if not candidates:
                if f'specs/{feature}/research/' in path.casefold():
                    raise ValueError('unlisted failed research input')
                if re.search(r'(?:^|/)docs/adr/', path, re.I) and not (adr and adr[1] in declared):
                    raise ValueError('invalid failed research ADR path')
                continue
            canonical = candidates[0]
            if (len(candidates) != 1 or canonical in selected
                    or (path != canonical and not re.match(r'^(?:/|[A-Za-z]:/)', path))):
                raise ValueError('ambiguous failed research path')
            selected[canonical] = entry['sha256']
        if not trio.issubset(selected):
            raise ValueError('incomplete failed research manifest')
        return selected

    reviewers = contract.get('reviewers')
    if (not isinstance(reviewers, list) or len(reviewers) != 2
            or any(not isinstance(reviewer, dict) or not isinstance(reviewer.get('role'), str) for reviewer in reviewers)
            or {reviewer.get('role') for reviewer in reviewers} != {'impl-reviewer-a', 'impl-reviewer-b'}):
        raise ValueError('invalid failed research reviewers')
    all_pins: list[dict[str, str]] = []
    runs, sessions = set(), set()
    for reviewer in reviewers:
        actual = saved('reviewer-' + reviewer['role'][-1] + '.json')
        if (actual.get('schema') != reviewer['role'] + '/v1' or actual.get('stage') != stage
                or any(actual.get(key) != reviewer.get(key) for key in ('role', 'run_id', 'host_session_id'))
                or any(not isinstance(reviewer.get(key), str) or not reviewer[key].strip()
                       for key in ('run_id', 'host_session_id'))):
            raise ValueError('failed research reviewer identity mismatch')
        runs.add(reviewer['run_id'])
        sessions.add(reviewer['host_session_id'])
        all_pins.extend((pins(reviewer), pins(actual)))
    if len(runs) != 2 or len(sessions) != 2 or any(value != all_pins[0] for value in all_pins[1:]):
        raise ValueError('failed research reviewer pins disagree')
    return [dict(path=path, sha256=sha) for path, sha in sorted(all_pins[0].items())]


def resolve(root, feature, stage, revision=None, *, include_research=True, history_contract=None):
    root = Path(root).resolve(strict=True)
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', feature) or stage not in ('spec', 'impl', 'task', 'quality'):
        raise ValueError('unsupported feature or review stage')
    inputs = []
    research_inputs = []
    observed = {}
    tree = {}
    if revision is not None:
        if not re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', revision):
            raise ValueError('invalid fixed revision')
        env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
        def git(*args):
            result = subprocess.run(['git', '--no-replace-objects', '-C', str(root), *args],
                                    env=env, capture_output=True, timeout=30)
            if result.returncode:
                raise ValueError('fixed revision could not be read')
            return result.stdout
        for entry in git('ls-tree', '-r', '-t', '-z', '--full-tree', revision).split(b'\0'):
            if entry:
                metadata, name = entry.split(b'\t', 1)
                tree[name.decode('utf-8')] = metadata.decode('ascii').split()

    def source(relative, optional=False):
        if revision is None:
            return read_safe(root, relative, optional)
        entry = tree.get(relative)
        if entry is None:
            if optional:
                return None
            raise ValueError('missing conditional input: ' + relative)
        mode, kind, oid = entry
        if mode not in ('100644', '100755') or kind != 'blob':
            raise ValueError('non-regular conditional input: ' + relative)
        return git('cat-file', 'blob', oid)

    def observe(relative, optional=False):
        raw = source(relative, optional)
        observed[relative] = hashlib.sha256(raw).hexdigest() if raw is not None else None
        return raw

    def admit(relative, optional=False):
        raw = observe(relative, optional)
        if raw is not None:
            inputs.append({'path': relative, 'sha256': hashlib.sha256(raw).hexdigest()})
        return raw

    # Research is explicit opt-in and stays bound to the same live/fixed source reader.
    research_packet = 'specs/' + feature + '/research/review-input.json'
    if history_contract is not None:
        if revision is not None or not include_research:
            raise ValueError('invalid failed research history mode')
        research_inputs = failed_research_history(root, feature, stage, history_contract)
        inputs.extend(research_inputs)
    elif include_research and stage in ('spec', 'impl') and source(research_packet, True) is not None:
        scripts = str(Path(__file__).resolve().parent)
        if scripts not in sys.path:
            sys.path.insert(0, scripts)
        from research_consumers import review_inputs
        research_inputs = review_inputs(feature, source)
        for entry in research_inputs:
            observe(entry['path'])
            if entry['path'] != 'specs/' + feature + '/requirements.md':
                inputs.append(entry)

    raw_contract = source('domain/domain-contract.json', True)
    try:
        candidate = json.loads(raw_contract, object_pairs_hook=unique_object) if raw_contract is not None else {}
    except (ValueError, UnicodeError):
        candidate = {}
    concept_required = isinstance(candidate, dict) and candidate.get('schema') == 'domain-contract/v2'
    if stage in ('task', 'quality'):
        if not concept_required and source('specs/' + feature + '/concept-test.json', True) is None:
            return {'inputs': [], 'research_inputs': [], 'domain_status': 'skipped', 'design_system_status': 'not-applicable', 'observed': {}}
    if stage == 'impl':
        admit('specs/' + feature + '/investigation.md', True)
    context = admit('domain/context-map.md', True)
    contract = admit('domain/domain-contract.json', True)
    domain_status = 'skipped'
    if context is not None and re.search(r'^Domain-Model-Status: Approved[ \t]*\r?$', context.decode('utf-8'), re.M) and contract is not None:
        try:
            document = json.loads(contract, object_pairs_hook=unique_object)
            version = document.get('schema') if isinstance(document, dict) else None
            if version not in ('domain-contract/v1', 'domain-contract/v2'):
                raise ValueError('unsupported domain schema')
        except (ValueError, UnicodeError):
            version = None
        valid = False
        if version is not None:
            schema = json.loads(observe('contracts/' + version.replace('/', '.') + '.schema.json'))
            spec = importlib.util.spec_from_file_location('review_schema', Path(__file__).with_name('validate-facet-manifest.py'))
            if spec is None or spec.loader is None:
                raise ValueError('schema validator loader unavailable')
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            valid = not module.validate_against_schema(document, schema)
        if valid:
            domain_status = 'active'
            if stage == 'impl':
                requirements = observe('specs/' + feature + '/requirements.md').decode('utf-8')
                match = re.search(r'^Bounded-Context:[ \t]*([^\r\n]*)', requirements, re.M)
                names = {s.strip() for s in re.sub(r'\(.*\)$', '', match.group(1)).split(',')} if match else set()
                cards = {a['card'] for c in document['contexts'] if c['name'] in names
                         for a in c['aggregates']}
                for card in sorted(cards):
                    if not re.fullmatch(r'domain/aggregates/[^/]+\.md', card):
                        raise ValueError('unsafe aggregate card path: ' + card)
                    admit(card)
    concept_path = 'specs/' + feature + '/concept-test.json'
    if concept_required or source(concept_path, True) is not None:
        module_path = Path(__file__).resolve().parents[2] / 'sdd-domain/scripts/validate-concept-test.py'
        spec = importlib.util.spec_from_file_location('conditional_concept', module_path)
        if spec is None or spec.loader is None:
            raise ValueError('Concept Test validator loader unavailable')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        concept, concept_inputs = module.evidence(root, feature, observe)
        if concept.get('decision', 'proceed') != 'proceed':
            raise ValueError('Concept Test does not permit continuing feature work')
        for entry in concept_inputs:
            if entry['path'] not in {item['path'] for item in inputs}:
                admit(entry['path'])
    ds_status = 'not-applicable'
    ds_dir = root / 'design-system'
    ds_present = ('design-system' in tree if revision is not None else
                  ds_dir.exists() or ds_dir.is_symlink())
    if stage == 'impl':
        observed['design-system/'] = 'present' if ds_present else None
    if stage == 'impl' and ds_present:
        if ((revision is not None and tree['design-system'][:2] != ['040000', 'tree']) or
                (revision is None and (ds_dir.is_symlink() or not ds_dir.is_dir()))):
            raise ValueError('unsafe design-system directory')
        design = observe('specs/' + feature + '/design.md').decode('utf-8')
        match = re.search(r'^## Design System Compliance[ \t]*\r?\n(.*?)(?=^## |\Z)', design, re.M | re.S)
        if match and match.group(1).strip() == 'N/A — ds_profile: none':
            ds_status = 'skipped'
        else:
            ds_status = 'active'
            for name in ('design-tokens.json', 'design-system.md', 'ui-patterns.md'):
                admit('design-system/' + name)
    return {'inputs': inputs, 'research_inputs': research_inputs, 'research_history_only': history_contract is not None,
            'domain_status': domain_status, 'design_system_status': ds_status,
            'observed': observed}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--feature', required=True)
    parser.add_argument('--stage', choices=('spec', 'impl', 'task', 'quality'), required=True)
    parser.add_argument('--revision')
    parser.add_argument('--without-research', action='store_true',
                        help='Historical manifests without research inputs only')
    parser.add_argument('--history-contract', help='Canonical failed impl review record; no current-input authority')
    args = parser.parse_args()
    try:
        print(json.dumps(resolve(args.root, args.feature, args.stage, args.revision,
                                 include_research=not args.without_research,
                                 history_contract=args.history_contract), sort_keys=True))
    except (OSError, ValueError, UnicodeError, subprocess.SubprocessError) as error:
        print('CONDITIONAL_INPUTS: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
