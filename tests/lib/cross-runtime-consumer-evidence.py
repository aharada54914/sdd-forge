#!/usr/bin/env python3
"""Record the requested Copilot selection separately from native model events."""
import argparse
import json
import hashlib
import stat
from pathlib import Path
import re


def model_id(value):
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,127}', value):
        raise ValueError('invalid Copilot model selection')
    return value


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate native event field')
        result[key] = value
    return result


def observe(requested, log):
    requested = model_id(requested)
    automatic = requested.lower() == 'auto'
    observed = set()
    for line in log.read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        event = json.loads(line, object_pairs_hook=unique_object)
        if not isinstance(event, dict):
            raise ValueError('invalid native event object')
        if event.get('type') == 'model.call_final_result':
            data = event.get('data')
            if not isinstance(data, dict):
                raise ValueError('invalid native model event')
            model = model_id(data.get('model'))
            if model.lower() == 'auto':
                raise ValueError('native model observation must name a concrete model')
            observed.add(model)
    if not observed:
        raise ValueError('native completed-model observation is unavailable')
    if not automatic and observed != {requested}:
        raise ValueError('native model differs from the explicit selection')
    return {'requested': requested, 'selection': 'auto' if automatic else 'explicit',
            'observed_models': sorted(observed), 'evidence_ref': 'copilot-consumer.log',
            'observation': 'native-model-call-final-result'}


def snapshot(workspace):
    result = {}
    for path in sorted(workspace.rglob('*')):
        info = path.lstat()
        if getattr(info, 'st_file_attributes', 0) & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0x400):
            raise ValueError('workspace reparse point')
        mode = info.st_mode
        relative = path.relative_to(workspace).as_posix()
        if stat.S_ISDIR(mode):
            result[relative] = {'kind': 'directory'}
        elif stat.S_ISREG(mode):
            result[relative] = {'kind': 'file', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        else:
            raise ValueError('non-regular workspace entry')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    before = commands.add_parser('snapshot')
    before.add_argument('workspace', type=Path)
    before.add_argument('destination', type=Path)
    after = commands.add_parser('observe')
    after.add_argument('requested')
    after.add_argument('log', type=Path)
    after.add_argument('workspace', type=Path)
    after.add_argument('before', type=Path)
    after.add_argument('output_sha256')
    args = parser.parse_args()
    try:
        if args.command == 'snapshot':
            args.destination.write_text(json.dumps(snapshot(args.workspace)), encoding='utf-8')
            return
        expected = json.loads(args.before.read_text(encoding='utf-8'), object_pairs_hook=unique_object)
        output = 'tests/fixtures/cross-runtime-handoff/handoff-02-output.txt'
        if output in expected:
            raise ValueError('consumer output existed before invocation')
        expected[output] = {'kind': 'file', 'sha256': args.output_sha256}
        if snapshot(args.workspace) != expected:
            raise ValueError('consumer changed unexpected workspace entries')
        result = observe(args.requested, args.log)
    except (OSError, ValueError):
        parser.exit(1, 'Copilot model or workspace evidence is missing, invalid, or inconsistent\n')
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()
