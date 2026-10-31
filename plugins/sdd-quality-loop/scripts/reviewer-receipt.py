#!/usr/bin/env python3
"""Spec reviewer calculation only: no ledger, reservation, output files or verdict."""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return (isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*', value)
            and not any(p in ('.', '..') for p in value.split('/')))


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'duplicate JSON member')
        result[key] = value
    return result


def read_at(root_fd, path):
    """Open canonical components without following links; never open arbitrary absolute paths."""
    require(canonical(path), 'noncanonical path')
    fd = os.dup(root_fd)
    try:
        parts = path.split('/')
        for component in parts[:-1]:
            child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        leaf = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        with os.fdopen(leaf, 'rb') as handle:
            info = os.fstat(handle.fileno())
            require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1, 'not a single-link regular file')
            return handle.read()
    finally:
        os.close(fd)


def verify(manifest, root, receipt):
    require(os.name == 'posix' and os.open in os.supports_dir_fd, 'unsupported safe-read runtime')
    require(Path(root).is_absolute() and str(Path(root).resolve()) == root, 'noncanonical root')
    require(canonical(manifest) and re.fullmatch(r'reports/review-context/[A-Za-z0-9._-]+[.]json', manifest),
            'manifest must be a fixed review-context JSON path')
    require(receipt == manifest + '.receipt.txt', 'receipt must be the fixed manifest sidecar')
    root_fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        raw_manifest = read_at(root_fd, manifest)
        m = json.loads(raw_manifest.decode('utf-8'), object_pairs_hook=unique_object)
        keys = {'schema', 'stage', 'role', 'feature', 'run_id', 'host_session_id', 'read_only',
                'input_mode', 'fallback_mode', 'identity_ledger_path', 'identity_ledger_sha256',
                'previous_record_sha256', 'sequence', 'allowed_input_manifest'}
        require(type(m) is dict and set(m) == keys, 'invalid manifest keys')
        require(m['schema'] == 'review-context-invocation/v2' and m['stage'] == 'spec'
                and m['role'] in ('spec-reviewer-a', 'spec-reviewer-b'), 'spec reviewer mode only')
        require(m['read_only'] is True and m['input_mode'] == 'file-manifest'
                and m['fallback_mode'] == 'none', 'invalid read-only invocation')
        for key in ('run_id', 'host_session_id'):
            require(isinstance(m[key], str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._:-]*', m[key]),
                    'invalid identity')
        feature = m['feature']
        require(isinstance(feature, str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', feature), 'invalid feature')
        require(type(m['sequence']) is int and m['sequence'] >= 2, 'invalid sequence')
        for key in ('identity_ledger_sha256', 'previous_record_sha256'):
            require(isinstance(m[key], str) and re.fullmatch('[0-9a-f]{64}', m[key]), 'invalid hash')
        require(m['identity_ledger_path'] == 'reports/review-context/identity-ledger.json', 'invalid ledger declaration')
        entries = m['allowed_input_manifest']
        require(type(entries) is list and entries, 'missing input manifest')
        paths = []
        prechecks = []
        for entry in entries:
            require(type(entry) is dict and set(entry) == {'path', 'sha256'}, 'invalid input entry')
            path, sha = entry['path'], entry['sha256']
            require(canonical(path) and isinstance(sha, str) and re.fullmatch('[0-9a-f]{64}', sha), 'invalid input path/hash')
            require(path not in paths, 'duplicate input path')
            base = 'reports/spec-review/' + feature + '/'
            is_precheck = re.fullmatch(re.escape(base) + r'attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result[.]json', path)
            is_summary = (m['role'] == 'spec-reviewer-b' and
                          re.fullmatch(re.escape(base) + r'attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary[.]json', path))
            require(path in ('specs/' + feature + '/requirements.md', 'specs/' + feature + '/acceptance-tests.md',
                            'specs/' + feature + '/investigation.md',
                            'plugins/sdd-review-loop/references/spec-review-calibration.md')
                    or is_precheck or is_summary, 'unlisted spec input')
            paths.append(path)
            if is_precheck:
                prechecks.append(path)
        required = {'specs/' + feature + '/requirements.md', 'specs/' + feature + '/acceptance-tests.md',
                    'plugins/sdd-review-loop/references/spec-review-calibration.md'}
        require(required.issubset(paths) and len(prechecks) == 1, 'missing required spec inputs')
        summaries = [p for p in paths if p.endswith('/integrated-summary.json')]
        require(summaries == ([prechecks[0].replace('precheck-result.json', 'integrated-summary.json')]
                             if m['role'] == 'spec-reviewer-b' else []), 'invalid summary input')

        raw_receipt = read_at(root_fd, receipt)
        pattern = (rb'REVIEW_CONTEXT_OK ([0-9a-f]{64}) sequence=([1-9][0-9]*) '
                   rb'previous_record_sha256=([0-9a-f]{64}) pre_append_tip_sequence=([1-9][0-9]*) identity_unique=yes\n?')
        match = re.fullmatch(pattern, raw_receipt)
        require(match is not None, 'invalid saved receipt')
        record, sequence, previous, tip = [v.decode('ascii') for v in match.groups()]
        require(int(sequence) == m['sequence'] and int(tip) == m['sequence'] - 1
                and previous == m['previous_record_sha256'], 'receipt identity-chain mismatch')
        input_text = '\n'.join(e['path'] + '\t' + e['sha256'] for e in entries)
        inputs_sha = digest(input_text.encode('utf-8'))
        chain = '|'.join((str(m['sequence']), m['stage'], m['role'], m['run_id'],
                          m['host_session_id'], m['previous_record_sha256'], 'allowed-inputs-v1', inputs_sha))
        require(digest(chain.encode('utf-8')) == record, 'receipt record hash mismatch')
        # Read domain bytes only after all paths and the receipt binding pass.
        for entry in entries:
            require(digest(read_at(root_fd, entry['path'])) == entry['sha256'], 'input hash mismatch: ' + entry['path'])
        return 'REVIEWER_DIGEST_OK manifest_sha256=' + digest(raw_manifest) + ' receipt_sha256=' + digest(raw_receipt)
    finally:
        os.close(root_fd)


def main():
    try:
        require(len(sys.argv) == 4, 'usage: reviewer-receipt.py manifest root receipt')
        print(verify(*sys.argv[1:]))
        return 0
    except (ValueError, OSError, UnicodeError, TypeError, KeyError) as error:
        print('REVIEWER_DIGEST_ERROR: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
