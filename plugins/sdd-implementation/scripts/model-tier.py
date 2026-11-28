#!/usr/bin/env python3
"""Classify a host-native model ID into a capability tier and check a role floor.

Reads only checked-in contracts beside this plugin: the family rules
(contracts/model-families.v1.json) and the capability registry
(contracts/agent-model-capabilities.v2.json). A registered canonical name
(such as `anthropic/opus-5-5`) uses its registry tier; a host-native ID is
classified by its vendor family, so a new version of a known family needs no
registry edit. An unknown family is
`unclassified` and never satisfies a floor.

  model-tier.py classify <native-id>
  model-tier.py check --role <capability-role> --model <native-id>

`check` prints a JSON verdict and exits 0 when the model meets the role's
`minimum_tier`, 3 when it is below it or unclassified, 2 on bad input.
"""
import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONTRACTS = HERE.parent / 'contracts'
TIERS = ('lightweight', 'standard', 'strong')
NATIVE_ID = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$')


def _load(name):
    return json.loads((CONTRACTS / name).read_text(encoding='utf-8'))


def families(contracts=None):
    data = json.loads((contracts / 'model-families.v1.json').read_text(encoding='utf-8')) if contracts else _load('model-families.v1.json')
    if data.get('schema') != 'model-families/v1' or not isinstance(data.get('families'), list):
        raise ValueError('model-families contract is invalid')
    rules = []
    for item in data['families']:
        if item.get('tier') not in TIERS:
            raise ValueError('model-families tier is unsupported: %r' % item.get('tier'))
        rules.append((re.compile(item['pattern']), item['tier'], item['vendor'], item['family']))
    return rules


def registry_tiers(contracts=None):
    """Registered host-native IDs and canonical names -> registry tier."""
    base = contracts or CONTRACTS
    registry = json.loads((base / 'agent-model-capabilities.v2.json').read_text(encoding='utf-8'))
    return {m['name']: m['canonical_tier'] for m in registry['models']}, registry.get('role_defaults', {})


def classify(native_id, contracts=None):
    if not isinstance(native_id, str) or not NATIVE_ID.match(native_id):
        raise ValueError('model ID must be a plain host-native identifier')
    registered, _ = registry_tiers(contracts)
    if native_id in registered:
        return {'model': native_id, 'tier': registered[native_id], 'source': 'registry'}
    matches = [(tier, vendor, family) for pattern, tier, vendor, family in families(contracts) if pattern.fullmatch(native_id)]
    if len({m[0] for m in matches}) != 1:
        return {'model': native_id, 'tier': 'unclassified', 'source': 'family' if matches else 'none'}
    tier, vendor, family = matches[0]
    return {'model': native_id, 'tier': tier, 'source': 'family', 'vendor': vendor, 'family': family}


def check(role, native_id, contracts=None):
    _, defaults = registry_tiers(contracts)
    if role not in defaults:
        raise ValueError('unknown capability role: %s' % role)
    floor = defaults[role]['minimum_tier']
    result = classify(native_id, contracts)
    ok = result['tier'] in TIERS and TIERS.index(result['tier']) >= TIERS.index(floor)
    return {**result, 'role': role, 'minimum_tier': floor, 'meets_floor': ok}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    sub = parser.add_subparsers(dest='command', required=True)
    one = sub.add_parser('classify')
    one.add_argument('model')
    two = sub.add_parser('check')
    two.add_argument('--role', required=True)
    two.add_argument('--model', required=True)
    args = parser.parse_args(argv)
    try:
        result = classify(args.model) if args.command == 'classify' else check(args.role, args.model)
    except (ValueError, OSError, KeyError) as error:
        print(json.dumps({'error': str(error)}), file=sys.stderr)
        return 2
    print(json.dumps(result, sort_keys=True))
    if args.command == 'check' and not result['meets_floor']:
        return 3
    return 0


if __name__ == '__main__':
    sys.exit(main())
