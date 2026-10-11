#!/usr/bin/env python3
"""Resolve role-defined conditional inputs without reserving review identities."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import stat
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


def resolve(root, feature, stage):
    root = Path(root).resolve(strict=True)
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', feature) or stage not in ('spec', 'impl'):
        raise ValueError('unsupported feature or review stage')
    inputs = []
    observed = {}

    def observe(relative, optional=False):
        raw = read_safe(root, relative, optional)
        observed[relative] = hashlib.sha256(raw).hexdigest() if raw is not None else None
        return raw

    def admit(relative, optional=False):
        raw = observe(relative, optional)
        if raw is not None:
            inputs.append({'path': relative, 'sha256': hashlib.sha256(raw).hexdigest()})
        return raw

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
    ds_status = 'not-applicable'
    ds_dir = root / 'design-system'
    if stage == 'impl':
        observed['design-system/'] = 'present' if ds_dir.exists() or ds_dir.is_symlink() else None
    if stage == 'impl' and (ds_dir.exists() or ds_dir.is_symlink()):
        if ds_dir.is_symlink() or not ds_dir.is_dir():
            raise ValueError('unsafe design-system directory')
        design = observe('specs/' + feature + '/design.md').decode('utf-8')
        match = re.search(r'^## Design System Compliance[ \t]*\r?\n(.*?)(?=^## |\Z)', design, re.M | re.S)
        if match and match.group(1).strip() == 'N/A — ds_profile: none':
            ds_status = 'skipped'
        else:
            ds_status = 'active'
            for name in ('design-tokens.json', 'design-system.md', 'ui-patterns.md'):
                admit('design-system/' + name)
    return {'inputs': inputs, 'domain_status': domain_status, 'design_system_status': ds_status,
            'observed': observed}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--feature', required=True)
    parser.add_argument('--stage', choices=('spec', 'impl'), required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(resolve(args.root, args.feature, args.stage), sort_keys=True))
    except (OSError, ValueError, UnicodeError) as error:
        print('CONDITIONAL_INPUTS: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
