#!/usr/bin/env python3
"""Register the invoking Copilot host from its native session-start event."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import tempfile


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate event key')
        result[key] = value
    return result


def redirected(path):
    info = path.lstat()
    return stat.S_ISLNK(info.st_mode) or bool(
        getattr(info, 'st_file_attributes', 0) & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0x400))


def regular_file(path):
    path = path.absolute()
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current /= part
        mode = current.lstat().st_mode
        if redirected(current):
            raise ValueError('native event path contains a symbolic link')
        if current != path and not stat.S_ISDIR(mode):
            raise ValueError('native event path is not a directory')
    if not stat.S_ISREG(path.lstat().st_mode):
        raise ValueError('native event source is not a regular file')
    if path.stat().st_nlink != 1:
        raise ValueError('native event source must not be hard-linked')
    return path


def native_identity(root, events):
    events = regular_file(Path(events))
    native_home = Path(os.environ.get('COPILOT_HOME') or Path.home() / '.copilot').absolute()
    if events.name != 'events.jsonl' or events.parent.parent != native_home / 'session-state':
        raise ValueError('use the original Copilot session-state events file')
    with events.open('rb') as source:
        first = source.readline(65537)
    if len(first) > 65536:
        raise ValueError('native session-start event is too large')
    event = json.loads(first, object_pairs_hook=unique_object)
    if not isinstance(event, dict) or event.get('type') != 'session.start' or 'parentId' not in event or event['parentId'] is not None:
        raise ValueError('native session-start event is missing')
    data = event.get('data')
    if not isinstance(data, dict) or data.get('producer') != 'copilot-agent' or type(data.get('version')) is not int or data['version'] != 1:
        raise ValueError('unsupported native session-start producer')
    run, session = event.get('id'), data.get('sessionId')
    if any(not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._:-]*', value)
           for value in (run, session)) or events.parent.name != session:
        raise ValueError('native session identity does not match its directory')
    context = data.get('context')
    if not isinstance(context, dict) or not isinstance(context.get('cwd'), str):
        raise ValueError('native session has no working directory')
    if Path(context['cwd']).resolve(strict=True) != root:
        raise ValueError('native session belongs to another project')
    return run, session


def directory(root, relative):
    current = root
    for part in relative.split('/'):
        current /= part
        try:
            current.mkdir()
        except FileExistsError:
            pass
        if redirected(current) or not current.is_dir():
            raise ValueError('identity directory is not a real directory')
        if part not in {entry.name for entry in current.parent.iterdir()}:
            raise ValueError('identity directory is not canonically named')
    return current


def initialize(root, events):
    root = Path(root).resolve(strict=True)
    if not root.is_dir():
        raise ValueError('project root is not a directory')
    run, session = native_identity(root, events)
    destination = directory(root, 'reports/review-context')
    ledger = destination / 'identity-ledger.json'
    lock = destination / 'identity-ledger.json.lock'
    lock.mkdir()  # Same exclusion path as both review reservation validators.
    staged = None
    try:
        if ledger.exists() or ledger.is_symlink():
            raise ValueError('identity ledger already exists; it was left unchanged')
        # Initial registration is not recovery. Never replace missing history
        # with a convenient new first record, including after a failed review.
        for name in ('spec-review', 'impl-review', 'task-review', 'domain-review', 'quality-gate', 'implementation'):
            history = root / 'reports' / name
            if history.is_symlink() or (history.exists() and redirected(history)) or (history.exists() and (not history.is_dir() or any(history.rglob('*')))):
                raise ValueError('prior review or implementation history prevents initialization')
        if any(path.name != lock.name for path in destination.iterdir()):
            raise ValueError('prior review-context evidence prevents initialization')
        record = dict(sequence=1, stage='host', role='orchestrator', run_id=run,
                      host_session_id=session, previous_record_sha256='')
        record['record_sha256'] = hashlib.sha256(f'1|host|orchestrator|{run}|{session}|'.encode()).hexdigest()
        document = dict(schema='review-identity-ledger/v1', records=[record])
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=destination,
                                         prefix='.identity-bootstrap-', delete=False) as stream:
            staged = Path(stream.name)
            json.dump(document, stream, sort_keys=True)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        # Publish fully written bytes without replacing an existing destination.
        os.link(staged, ledger)
        return document
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)
        lock.rmdir()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--copilot-events', required=True)
    args = parser.parse_args()
    try:
        initialize(args.root, args.copilot_events)
        print('REVIEW_HOST_REGISTERED')
        return 0
    except (OSError, ValueError, TypeError, KeyError):
        print('REVIEW_HOST_BLOCKED: native identity, fresh-project history, or exclusive publication check failed')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
