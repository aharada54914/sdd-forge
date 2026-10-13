"""Materialize selected regular Git blobs; this does not grant review approval."""
import hashlib
import importlib.util
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys


def verify_approval(document, inventory, *, feature, stage, task_id, key, registry_ids):
    """Authenticate detached approval without converting historical task flags."""
    expected = {'schema', 'commit', 'inputs', 'feature', 'stage', 'task_id',
                'primary_approval', 'effective_at', 'hmac'}
    if not isinstance(document, dict) or set(document) != expected:
        raise ValueError('invalid fixed approval fields')
    validate_inventory(inventory)
    primary = document['primary_approval']
    if (not isinstance(primary, dict) or set(primary) != {'approver'}
            or not isinstance(primary['approver'], str) or not primary['approver'].strip()):
        raise ValueError('invalid fixed approval identity')
    if (document['schema'] != 'sdd-fixed-review-approval/v1'
            or document['commit'] != inventory['commit']
            or document['inputs'] != inventory['inputs']
            or document['feature'] != feature or document['stage'] != stage
            or document['task_id'] != task_id):
        raise ValueError('fixed approval scope mismatch')
    if (not isinstance(key, bytes) or not key
            or not isinstance(document['hmac'], str)
            or not re.fullmatch('[0-9a-f]{64}', document['hmac'])
            or not isinstance(document['effective_at'], str)):
        raise ValueError('invalid fixed approval authentication')
    source = Path(__file__).resolve().parents[2] / 'sdd-quality-loop/scripts/validate-approval-sidecar.py'
    spec = importlib.util.spec_from_file_location('fixed_approval_auth', source)
    auth = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(auth)
    auth._check_hmac(document, key)
    auth._check_approver_identity(document, registry_ids)
    auth._check_effective_at(document)


def state_reference(repo: Path, inventory: dict) -> dict:
    """Reference existing state verbatim; this is not a new approval or transition."""
    validate_inventory(inventory)
    blobs = read_blobs(repo, inventory['commit'], [entry['path'] for entry in inventory['inputs']])
    fields = []
    for entry, (name, mode, content) in zip(inventory['inputs'], blobs):
        if (hashlib.sha256(content).hexdigest() != entry['sha256']
                or mode.decode('ascii') != entry['mode']):
            raise ValueError('state source differs from fixed inventory')
        if not name.endswith('.md'):
            continue
        task_plan = Path(name).name == 'tasks.md'
        task_id = None
        task_ids = set()
        task_fields = set()
        for number, line in enumerate(content.decode('utf-8').splitlines(), 1):
            if task_plan:
                heading = re.match(r'^## (T-[0-9]{3})(?:\s|$)', line)
                if heading:
                    task_id = heading[1]
                    if task_id in task_ids:
                        raise ValueError('ambiguous task state: duplicate task ID')
                    task_ids.add(task_id)
                    task_fields = set()
                elif re.match(r'^#{1,2}(?:\s|$)', line):
                    task_id = None
            if re.match(r'^(?:Approval|Second Approval|Status|(?:Spec|Impl|Task)-Review-Status):', line):
                field = {'path': name, 'line': number, 'text': line}
                if task_plan and not re.match(r'^(?:Spec|Impl|Task)-Review-Status:', line):
                    if task_id is None:
                        continue
                    key = line.split(':', 1)[0]
                    if key in task_fields:
                        raise ValueError('ambiguous task state: duplicate field')
                    task_fields.add(key)
                    field['task_id'] = task_id
                fields.append(field)
    digest = hashlib.sha256(json.dumps(inventory, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'schema': 'sdd-fixed-state-reference/v1', 'commit': inventory['commit'],
            'inventory_sha256': digest, 'fields': fields}


def check_path_spelling(name: str, spellings: dict) -> None:
    parts = name.split('/')
    for count in range(1, len(parts) + 1):
        prefix = '/'.join(parts[:count])
        previous = spellings.setdefault(prefix.casefold(), prefix)
        if previous != prefix:
            raise ValueError('case-colliding input paths')


def validate_inventory(inventory: dict) -> None:
    if (not isinstance(inventory, dict) or set(inventory) != {'commit', 'inputs'}
            or not isinstance(inventory['commit'], str)
            or not re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', inventory['commit'])
            or not isinstance(inventory['inputs'], list) or not inventory['inputs']):
        raise ValueError('invalid snapshot inventory')
    seen = set()
    spellings = {}
    for entry in inventory['inputs']:
        if (not isinstance(entry, dict) or set(entry) != {'path', 'sha256', 'mode'}
                or not isinstance(entry['path'], str)
                or not re.fullmatch(r'[A-Za-z0-9_.\-/]+', entry['path'])
                or any(p in ('', '.', '..') for p in entry['path'].split('/'))
                or entry['path'].casefold() in seen
                or entry['mode'] not in ('100644', '100755')
                or not isinstance(entry['sha256'], str)
                or not re.fullmatch(r'[0-9a-f]{64}', entry['sha256'])):
            raise ValueError('invalid snapshot entry')
        seen.add(entry['path'].casefold())
        check_path_spelling(entry['path'], spellings)


def verify(output: Path, inventory: dict) -> None:
    """Check selected bytes against a trusted launcher inventory, not approval."""
    validate_inventory(inventory)
    expected_files = set()
    expected_directories = {output}
    try:
        if not stat.S_ISDIR(output.lstat().st_mode):
            raise ValueError('snapshot root must be a directory')
        for entry in inventory['inputs']:
            target = output
            parts = entry['path'].split('/')
            for part in parts[:-1]:
                target = target / part
                if not stat.S_ISDIR(target.lstat().st_mode):
                    raise ValueError('snapshot parent must be a directory')
            target = target / parts[-1]
            expected_files.add(target)
            expected_directories.update(list(target.parents)[:len(parts)])
            metadata = target.lstat()
            if not stat.S_ISREG(metadata.st_mode):
                raise ValueError('snapshot input must be a regular file')
            expected_mode = 0o555 if entry['mode'] == '100755' else 0o444
            if os.name != 'nt' and stat.S_IMODE(metadata.st_mode) != expected_mode:
                raise ValueError('snapshot input mode changed')
            if hashlib.sha256(target.read_bytes()).hexdigest() != entry['sha256']:
                raise ValueError('snapshot input bytes changed')
        actual_files = set()
        actual_directories = {output}
        for parent, directories, files in os.walk(output, followlinks=False):
            for name in directories:
                directory = Path(parent) / name
                if not stat.S_ISDIR(directory.lstat().st_mode):
                    raise ValueError('snapshot contains a linked directory')
                actual_directories.add(directory)
            actual_files.update(Path(parent) / name for name in files)
        if actual_files != expected_files or actual_directories != expected_directories:
            raise ValueError('snapshot contains unselected entries')
        if os.name != 'nt' and any(
                stat.S_IMODE(directory.lstat().st_mode) != 0o555
                for directory in actual_directories):
            raise ValueError('snapshot directory mode changed')
    except OSError as exc:
        raise ValueError('snapshot input unavailable') from exc


def read_blobs(repo: Path, commit: str, paths: list[str]) -> list:
    # Inherited Git selectors must not override the explicitly chosen repository.
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith('GIT_')}
    def git(*args: str) -> bytes:
        result = subprocess.run(
            ['git', '--no-replace-objects', '-C', str(repo), *args],
            capture_output=True, env=environment, timeout=30)
        if result.returncode:
            raise ValueError('Git input lookup failed')
        return result.stdout

    if not isinstance(commit, str) or not re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', commit):
        raise ValueError('full commit ID required')
    if git('cat-file', '-t', commit).strip() != b'commit':
        raise ValueError('revision must identify a commit')
    if (not isinstance(paths, list) or not paths
            or any(not isinstance(p, str) for p in paths)
            or len({p.casefold() for p in paths}) != len(paths)):
        raise ValueError('nonempty, unique path selection required')
    blobs = []
    spellings = {}
    for name in paths:
        if (not re.fullmatch(r'[A-Za-z0-9_.\-/]+', name)
                or any(part in ('', '.', '..') for part in name.split('/'))):
            raise ValueError('noncanonical input path')
        check_path_spelling(name, spellings)
        entry = git('ls-tree', '--full-tree', '-z', commit, '--', name).split(b'\0')
        if len(entry) != 2 or not entry[0]:
            raise ValueError('input is missing or ambiguous')
        metadata, actual = entry[0].split(b'\t', 1)
        mode, kind, oid = metadata.split()
        if actual != name.encode() or kind != b'blob' or mode not in (b'100644', b'100755'):
            raise ValueError('input must be an exact regular file')
        data = git('cat-file', 'blob', oid.decode('ascii'))
        blobs.append((name, mode, data))
    return blobs


def verify_revision(repo: Path, commit: str, paths: list[str],
                    output: Path, inventory: dict) -> None:
    verify(output, inventory)
    expected = [{'path': name, 'sha256': hashlib.sha256(data).hexdigest(),
                 'mode': mode.decode('ascii')}
                for name, mode, data in read_blobs(repo, commit, paths)]
    if inventory != {'commit': commit, 'inputs': expected}:
        raise ValueError('snapshot inventory differs from Git revision')


def verify_current_selection(repo: Path, current_commit: str, inventory: dict) -> None:
    """Check staleness of verified inputs without transferring their approval."""
    validate_inventory(inventory)
    current = [{'path': name, 'sha256': hashlib.sha256(data).hexdigest(),
                'mode': mode.decode('ascii')}
               for name, mode, data in read_blobs(
                   repo, current_commit, [entry['path'] for entry in inventory['inputs']])]
    if current != inventory['inputs']:
        raise ValueError('selected inputs changed; fresh review required')


def verify_head_selection(repo: Path, inventory: dict) -> None:
    environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
    result = subprocess.run(
        ['git', '--no-replace-objects', '-C', str(repo), 'rev-parse', '--verify', 'HEAD^{commit}'],
        capture_output=True, env=environment, timeout=30)
    if result.returncode:
        raise ValueError('Git HEAD lookup failed')
    verify_current_selection(repo, result.stdout.decode('ascii').strip(), inventory)


def materialize(repo: Path, commit: str, paths: list[str], output: Path) -> dict:
    blobs = read_blobs(repo, commit, paths)

    # Exclusive creation prevents replacement of another operation's snapshot.
    try:
        output.mkdir()
    except FileExistsError as exc:
        raise ValueError('snapshot destination already exists') from exc
    directories = {output}
    try:
        inventory = []
        for name, mode, data in blobs:
            target = output / name
            target.parent.mkdir(parents=True, exist_ok=True)
            directories.update(list(target.parents)[:len(Path(name).parts)])
            with target.open('xb') as handle:
                handle.write(data)
            target.chmod(0o555 if mode == b'100755' else 0o444)
            inventory.append({'path': name, 'sha256': hashlib.sha256(data).hexdigest(),
                              'mode': mode.decode('ascii')})
        for directory in directories:
            directory.chmod(0o555)
        return {'commit': commit, 'inputs': inventory}
    except BaseException:
        for directory in directories:
            directory.chmod(0o700)
        shutil.rmtree(output)
        raise


def prepare(repo: Path, commit: str, paths: list[str], output: Path,
            record: Path) -> dict:
    """Keep mutable records outside the immutable input tree; never replace either."""
    resolved_output = output.resolve()
    resolved_record = record.resolve()
    if resolved_record == resolved_output or resolved_output in resolved_record.parents:
        raise ValueError('inventory record must be outside snapshot')
    # Reserve the record before creating inputs so existing evidence is never replaced.
    with record.open('x', encoding='utf-8') as handle:
        inventory = materialize(repo, commit, paths, output)
        verify_revision(repo, commit, paths, output, inventory)
        json.dump(inventory, handle, sort_keys=True, separators=(',', ':'))
        handle.write('\n')
    return inventory


def unique_fields(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key')
        result[key] = value
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('prepare', 'verify', 'source-map'))
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--commit')
    parser.add_argument('--input', action='append', dest='inputs')
    parser.add_argument('--snapshot', type=Path, required=True)
    parser.add_argument('--record', type=Path, required=True)
    parser.add_argument('--current-commit', help='compare selected paths only; approval remains bound to --commit')
    args = parser.parse_args()
    try:
        if args.operation == 'source-map':
            if args.record.is_symlink() or not args.record.is_file():
                raise ValueError('inventory must be a regular non-symlink file')
            inventory = json.loads(args.record.read_text(encoding='utf-8'),
                                   object_pairs_hook=unique_fields)
            validate_inventory(inventory)
            verify_revision(args.repo, inventory['commit'],
                            [item['path'] for item in inventory['inputs']],
                            args.snapshot, inventory)
            verify_head_selection(args.repo, inventory)
            print(json.dumps({'commit': inventory['commit'], 'sources': {
                item['path']: str(args.snapshot.resolve() / item['path'])
                for item in inventory['inputs']}}))
            return 0
        if not args.commit or not args.inputs:
            raise ValueError('--commit and --input are required')
        if args.operation == 'prepare':
            if args.current_commit:
                raise ValueError('--current-commit is only valid for verify')
            prepare(args.repo, args.commit, args.inputs, args.snapshot, args.record)
        else:
            inventory = json.loads(args.record.read_text(encoding='utf-8'),
                                   object_pairs_hook=unique_fields)
            verify_revision(args.repo, args.commit, args.inputs, args.snapshot, inventory)
            if args.current_commit:
                verify_current_selection(args.repo, args.current_commit, inventory)
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print('FIXED_INPUTS_STOPPED: ' + str(error), file=sys.stderr)
        return 1
    print('FIXED_INPUTS_OK; approval and reservation not performed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
