#!/usr/bin/env python3
"""Host-neutral, non-reserving review input preflight.

This is not a permission proof. The canonical validator remains the only
reservation authority and must recheck current bytes immediately before launch.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ValueError('module loader unavailable: ' + str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def preflight(root, invocation, pin, host_cli=None, required_flags=(),
              help_subcommands=(), runtime='bash', verify_scratch_projection=False):
    root = root.resolve(strict=True)
    require(runtime in ('bash', 'powershell'), 'unsupported review runtime')
    require(invocation.is_file() and not invocation.is_symlink(), 'invocation is not a regular file')
    raw = invocation.read_bytes()
    require(re.fullmatch(r'[0-9a-f]{64}', pin) is not None and
            hashlib.sha256(raw).hexdigest() == pin, 'caller invocation pin mismatch')
    data = json.loads(raw)
    require(isinstance(data, dict), 'invocation must be a JSON object')
    require(data.get('schema') == 'review-context-invocation/v2' and
            data.get('stage') in ('spec', 'impl', 'task', 'quality') and
            data.get('read_only') is True, 'unsupported invocation')
    launcher = load_module('review_launcher', Path(__file__).with_name('launch-impl-review.py'))
    admitted = launcher.checked_input_paths(root, data)
    stage, feature = data['stage'], data['feature']
    require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', feature) is not None,
            'unsafe feature')
    if stage == 'quality':
        task = data.get('task_id', '')
        require(re.fullmatch(r'T-[0-9]{3}', task) is not None, 'invalid task ID')
        required = {'specs/' + feature + '/' + name for name in
                    ('requirements.md', 'design.md', 'acceptance-tests.md',
                     'tasks.md', 'traceability.md')}
        required.update(('plugins/sdd-quality-loop/references/quality-gate-calibration.md',
                         'reports/implementation/' + feature + '/' + task + '.md'))
        require(required <= admitted, 'required quality inputs missing')
        scratch_name = data.get('scratch_root')
        require(not verify_scratch_projection or scratch_name is not None,
                'scratch projection requires scratch_root')
        if scratch_name is not None:
            scratch = Path(scratch_name)
            require(scratch.is_absolute() and scratch.is_dir() and
                    not scratch.is_symlink(), 'invalid scratch root')
            scratch = scratch.resolve(strict=True)
            require(scratch != root, 'scratch root cannot be repository root')
            if verify_scratch_projection:
                for entry in data['allowed_input_manifest']:
                    relative = Path(entry['path'])
                    path = scratch
                    for part in relative.parts:
                        path = path / part
                        require(not path.is_symlink(), 'scratch path is a symlink')
                    require(path.is_file() and sha(path) == entry['sha256'],
                            'scratch input missing or changed: ' + entry['path'])
    else:
        pattern = re.compile(r'reports/' + stage + r'-review/' + re.escape(feature) +
                             r'/attempt-([1-9][0-9]*)/round-([1-9][0-9]*)/precheck-result.json')
        matches = [pattern.fullmatch(entry['path']) for entry in data['allowed_input_manifest']]
        rounds = [match for match in matches if match is not None]
        require(len(rounds) == 1, 'one admitted precheck required')
        attempt, round_number = map(int, rounds[0].groups())
        precheck = root / rounds[0].group()
        precheck_pin = sha(precheck)
        launcher.verify_inputs_before_output(root, stage, feature, attempt,
                                             round_number, runtime=runtime)
        expected = launcher.required_input_paths(root, data, precheck, attempt, round_number)
        require(sha(precheck) == precheck_pin and admitted == expected,
                'required stage inputs differ or changed')
    if host_cli is not None:
        require(host_cli.is_absolute() and host_cli.is_file(), 'host CLI is not an absolute file')
        require(all(re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]*', part) for part in help_subcommands),
                'unsafe CLI help subcommand')
        result = subprocess.run(['rtk', 'proxy', str(host_cli), *help_subcommands, '--help'], cwd=root, capture_output=True,
                                text=True, timeout=30)
        require(result.returncode == 0, 'host CLI help failed')
        declarations = '\n'.join(line.split('  ', 1)[0] for line in
                                 (line.strip() for line in result.stdout.splitlines())
                                 if line.startswith('-'))
        for flag in required_flags:
            require(re.search(r'(?<![\w-])' + re.escape(flag) + r'(?=[\s,=<\[]|$)',
                              declarations) is not None, 'unsupported CLI argument: ' + flag)
    else:
        require(not required_flags and not help_subcommands, 'CLI flags require a host CLI')
    validator = root / ('plugins/sdd-quality-loop/scripts/validate-review-context-set.' +
                        ('sh' if runtime == 'bash' else 'ps1'))
    command = (['rtk', 'proxy', 'bash', str(validator), str(invocation), str(root)]
               if runtime == 'bash' else
               ['rtk', 'proxy', 'pwsh', '-NoProfile', '-File', str(validator),
                '-Manifest', str(invocation), '-RepositoryRoot', str(root)])
    result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=600)
    require(result.returncode == 0 and
            re.fullmatch(r'REVIEW_CONTEXT_OK [0-9a-f]{64} sequence=[1-9][0-9]* '
                         r'previous_record_sha256=(?:-|[0-9a-f]{64}) '
                         r'pre_append_tip_sequence=[0-9]+ identity_unique=yes\n?',
                         result.stdout) is not None, 'canonical preview rejected')
    require(invocation.read_bytes() == raw, 'invocation changed during preflight')
    return len(admitted)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('repository_root', type=Path)
    parser.add_argument('invocation', type=Path)
    parser.add_argument('--manifest-sha256', required=True)
    parser.add_argument('--host-cli', type=Path)
    parser.add_argument('--required-flag', action='append', default=[])
    parser.add_argument('--help-subcommand', action='append', default=[])
    parser.add_argument('--runtime', choices=('bash', 'powershell'), default='bash')
    parser.add_argument('--verify-scratch-projection', action='store_true')
    args = parser.parse_args()
    try:
        count = preflight(args.repository_root, args.invocation,
                          args.manifest_sha256, args.host_cli, args.required_flag,
                          args.help_subcommand, args.runtime,
                          args.verify_scratch_projection)
    except (OSError, ValueError, TypeError, KeyError, subprocess.TimeoutExpired) as error:
        print('HOST_REVIEW_PREFLIGHT_REJECTED: ' + str(error), file=sys.stderr)
        return 1
    print(f'HOST_REVIEW_PREFLIGHT_OK inputs={count} '
          'permission-proof=not-established reservation=not-performed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
