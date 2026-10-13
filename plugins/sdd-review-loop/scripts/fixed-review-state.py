"""Authenticated review progress observations; never task approval or lifecycle transitions."""
import argparse
import copy
import hashlib
import hmac
import importlib.util
import json
from pathlib import Path
import re
import sys


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


fixed = load_module('detached_fixed_inputs', Path(__file__).with_name('fixed-review-inputs.py'))
auth = load_module('detached_approval_auth', Path(__file__).resolve().parents[2] /
                   'sdd-quality-loop/scripts/validate-approval-sidecar.py')
PROGRESS = ('prepared', 'running', 'completed', 'blocked')
FIELDS = {'schema', 'inventory', 'feature', 'stage', 'task_id', 'approval',
          'source_state', 'progress', 'hmac'}


def verify(document, repo, inventory, *, feature, stage, task_id, key, registry_ids):
    """Consume a record against caller-owned scope and canonical approval trust."""
    if not isinstance(document, dict) or set(document) != FIELDS:
        raise ValueError('invalid detached state fields')
    if (document['schema'] != 'sdd-fixed-review-state/v1'
            or document['inventory'] != inventory
            or document['feature'] != feature or document['stage'] != stage
            or document['task_id'] != task_id
            or document['progress'] not in PROGRESS
            or not isinstance(document['hmac'], str)
            or not re.fullmatch('[0-9a-f]{64}', document['hmac'])):
        raise ValueError('detached state scope or progress mismatch')
    fixed.verify_approval(document['approval'], inventory, feature=feature, stage=stage,
                          task_id=task_id, key=key, registry_ids=registry_ids)
    auth._check_hmac(document, key)
    if document['source_state'] != fixed.state_reference(repo, inventory):
        raise ValueError('detached historical state differs from Git inputs')
    return document


def create(repo, inventory, approval, *, feature, stage, task_id, progress, key, registry_ids):
    """Authenticate an observation only after consuming already-authenticated approval."""
    if progress not in PROGRESS:
        raise ValueError('invalid review progress; task statuses and verdicts are not accepted')
    fixed.verify_approval(approval, inventory, feature=feature, stage=stage,
                          task_id=task_id, key=key, registry_ids=registry_ids)
    document = {'schema': 'sdd-fixed-review-state/v1', 'inventory': copy.deepcopy(inventory),
                'feature': feature, 'stage': stage, 'task_id': task_id,
                'approval': copy.deepcopy(approval), 'progress': progress,
                'source_state': fixed.state_reference(repo, inventory)}
    document['hmac'] = hmac.new(key, auth._canonicalize_json_preimage(document),
                                hashlib.sha256).hexdigest()
    return document


def persist(path, document, repo, inventory):
    """Append a separate observation file without replacing any prior record."""
    if path.resolve() in {(repo / entry['path']).resolve() for entry in inventory['inputs']}:
        raise ValueError('state record must be outside selected source paths')
    with path.open('x', encoding='utf-8') as handle:
        json.dump(document, handle, sort_keys=True, separators=(',', ':'))
        handle.write('\n')


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=fixed.unique_fields)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('record', 'verify'))
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--record', type=Path, required=True)
    parser.add_argument('--feature', required=True)
    parser.add_argument('--stage', required=True)
    parser.add_argument('--task-id')
    parser.add_argument('--approval', type=Path)
    parser.add_argument('--progress', choices=PROGRESS)
    args = parser.parse_args()
    try:
        inventory = read_json(args.inventory)
        trust = dict(key=auth._resolve_key_or_raise(), registry_ids=auth._validate_registry(
            args.repo / 'sdd/approver-registry.yaml'))
        scope = dict(feature=args.feature, stage=args.stage, task_id=args.task_id)
        if args.operation == 'record':
            if args.approval is None or args.progress is None:
                raise ValueError('record requires --approval and --progress')
            document = create(args.repo, inventory, read_json(args.approval),
                              progress=args.progress, **scope, **trust)
            persist(args.record, document, args.repo, inventory)
        else:
            if args.approval is not None or args.progress is not None:
                raise ValueError('verify consumes embedded approval and progress')
            verify(read_json(args.record), args.repo, inventory, **scope, **trust)
    except Exception as error:
        print('FIXED_STATE_STOPPED: ' + str(error), file=sys.stderr)
        return 1
    print('FIXED_STATE_OK; review observation only, no task transition or verdict')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
