#!/usr/bin/env python3
"""Register the invoking review host: fresh Copilot projects, or a Claude host appended to an existing ledger."""
import argparse
import errno
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


# Existing-ledger append of a Claude Code host (review-host-registration/v1).
# Hashes, canonical paths and receipts are local evidence, not signatures: a
# same-UID writer able to rewrite every input consistently is out of scope.
CLAUDE_VERSIONS = frozenset({'2.1.303'})  # Native result/transcript formats actually observed.
NATIVE_LIMIT = LEDGER_LIMIT = 64 * 1024 * 1024
# EVIDENCE_FILES bounds every visited directory entry (selected or not) in one scan.
EVIDENCE_LIMIT, EVIDENCE_FILES, EVIDENCE_TOTAL = 16 * 1024 * 1024, 10000, 512 * 1024 * 1024
# Transcript record types observed in the CLI 2.1.303 probe; any other type is an unknown format.
NATIVE_TYPES = frozenset({'queue-operation', 'user', 'attachment', 'atis-latch', 'api-request-shape',
                          'api-request-blob', 'api-request', 'last-prompt', 'assistant', 'cost-state'})
EVIDENCE_ROOTS = ('reports/implementation', 'handoffs', 'reports/quality-gate')
IDENTIFIER = re.compile(r'[A-Za-z0-9][A-Za-z0-9._:-]*')
DIGEST = re.compile(r'[0-9a-f]{64}')
SESSION = re.compile(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
RELATIVE = re.compile(r'[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*')
RECORD_KEYS = frozenset({'sequence', 'stage', 'role', 'run_id', 'host_session_id',
                         'previous_record_sha256', 'record_sha256'})
RECEIPT_KEYS = frozenset({'schema', 'host', 'source_kind', 'cli_version', 'canonical_root', 'result',
                          'transcript', 'run_id', 'host_session_id', 'sequence', 'record_sha256',
                          'ledger_before_sha256', 'ledger_after_sha256', 'before_record_count',
                          'receipt_sha256'})
RECEIPT_STAGING = '.host-registration-'


class Blocked(ValueError):
    """A refusal whose fixed message is safe to print (never input content)."""


class Busy(Blocked):
    """Another process holds the ledger lock; retry later."""


class Unpublished(Blocked):
    """A receipt exists without its ledger record; it is preserved."""


def reject_constant(_):
    raise ValueError('non-finite JSON number')


def strict_json(text):
    return json.loads(text, object_pairs_hook=unique_object, parse_constant=reject_constant)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def is_digest(value):
    return isinstance(value, str) and DIGEST.fullmatch(value) is not None


def read_regular(path, limit):
    """Read a non-redirected single-link regular file; return its bytes and file identity."""
    path = regular_file(Path(path))
    expected = path.lstat()
    descriptor = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_BINARY', 0))
    with os.fdopen(descriptor, 'rb') as stream:
        # Recheck the opened file itself: a link or replacement after the path check is refused.
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1
                or (info.st_dev, info.st_ino) != (expected.st_dev, expected.st_ino)):
            raise Blocked('input is not a single-link regular file')
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise Blocked('input exceeds its size limit')
    return data, (info.st_dev, info.st_ino)


def existing_directory(root, relative):
    """Like directory(), but never creates anything."""
    current = root
    for part in relative.split('/'):
        current /= part
        if not os.path.lexists(current):
            raise Blocked('existing identity ledger is missing; append mode never creates one')
        if redirected(current) or not current.is_dir() or part not in {entry.name for entry in current.parent.iterdir()}:
            raise Blocked('identity directory is not a canonical real directory')
    return current


def same_root(root, cwd, cache):
    if cwd not in cache:
        try:
            cache[cwd] = Path(cwd).is_absolute() and Path(cwd).resolve(strict=True) == root
        except OSError:
            cache[cwd] = False
    return cache[cwd]


def claude_result(root, path):
    """Accept one captured `--output-format json` result or one `stream-json` session ending in it."""
    path = Path(path).absolute()
    raw, identity = read_regular(path, NATIVE_LIMIT)
    text = raw.decode('utf-8')
    try:
        documents = [strict_json(text)]
    except ValueError:
        # JSONL frames on LF only: raw U+2028/U+2029 and similar are valid inside JSON strings.
        documents = [strict_json(line) for line in text.split('\n') if line.strip()]
    if not documents or not all(isinstance(item, dict) for item in documents):
        raise Blocked('Claude result is empty or is not native JSON records')
    final = documents[-1]
    session = final.get('session_id')
    if (final.get('type') != 'result' or final.get('subtype') != 'success' or final.get('is_error') is not False
            or not isinstance(final.get('result'), str) or any(item.get('type') == 'result' for item in documents[:-1])):
        raise Blocked('Claude result is not exactly one successful completed result')
    if not isinstance(session, str) or not SESSION.fullmatch(session):
        raise Blocked('Claude result has no native session identity')
    version = None
    if len(documents) > 1:
        init = documents[0]
        if (init.get('type') != 'system' or init.get('subtype') != 'init'
                or any(item.get('session_id') != session for item in documents)
                or not isinstance(init.get('cwd'), str) or not isinstance(init.get('claude_code_version'), str)):
            raise Blocked('Claude stream result is not one native session')
        version = init['claude_code_version']
        if version not in CLAUDE_VERSIONS:
            raise Blocked('Claude CLI version is not a supported native format')
        if not same_root(root, init['cwd'], {}):
            raise Blocked('Claude result belongs to another project')
    return dict(source=path, raw=raw, identity=identity, session=session, version=version)


def claude_transcript(root, path, session):
    """Locate the canonical native transcript of `session`; copies elsewhere are not native input."""
    # shortcut: only `/` -> `-` was observed (CLI 2.1.303, POSIX); add characters/platforms once observed.
    if os.name == 'nt' or not re.fullmatch(r'(?:/[A-Za-z0-9-]+)+', str(root)):
        raise Blocked('project root needs a Claude native project encoding this helper has not observed')
    if os.environ.get('CLAUDE_CONFIG_DIR'):
        raise Blocked('custom Claude configuration roots are not supported')
    home = (Path.home() / '.claude').absolute()
    source = Path(path).absolute()
    if source.name != session + '.jsonl' or source.parent != home / 'projects' / str(root).replace('/', '-'):
        raise Blocked('use the original Claude native transcript of the result session and project')
    raw, identity = read_regular(source, NATIVE_LIMIT)
    return dict(source=source, raw=raw, identity=identity, path=source.relative_to(home).as_posix())


def transcript_version(root, data, session, result_version):
    """Validate bound transcript bytes and return their one supported CLI version."""
    if not data.endswith(b'\n'):
        raise Blocked('Claude transcript does not end with a complete native record')
    exchange, versions, roots = set(), set(), {}
    for line in data.decode('utf-8').split('\n')[:-1]:
        record = strict_json(line)
        if not isinstance(record, dict) or record.get('sessionId') != session:
            raise Blocked('Claude transcript record is not part of the result session')
        if record.get('type') not in NATIVE_TYPES:
            raise Blocked('Claude transcript contains an unknown native record type')
        # The encoded directory is lossy; the recorded cwd decides the project.
        if 'cwd' in record and not same_root(root, record['cwd'], roots):
            raise Blocked('Claude transcript belongs to another project')
        if record.get('isSidechain', False) is not False:
            raise Blocked('Claude transcript sidechain records are not supported')
        if 'version' in record:
            versions.add(record['version'])
        message = record.get('message')
        if (record['type'] in ('user', 'assistant') and 'cwd' in record and isinstance(message, dict)
                and message.get('role') == record['type']):
            exchange.add(record['type'])
    if exchange != {'user', 'assistant'} or len(versions) != 1 or not versions <= CLAUDE_VERSIONS:
        raise Blocked('Claude transcript lacks one supported native user/assistant exchange')
    version = versions.pop()
    if result_version not in (None, version):
        raise Blocked('Claude result and transcript versions differ')
    return version


def record_hash(record):
    text = '|'.join(str(record[key]) for key in
                    ('sequence', 'stage', 'role', 'run_id', 'host_session_id', 'previous_record_sha256'))
    if 'scratch_declaration_sha256' in record:
        text += '|scratch-declaration-v1|' + record['scratch_declaration_sha256']
    if 'allowed_inputs_sha256' in record:
        text += '|allowed-inputs-v1|' + record['allowed_inputs_sha256']
    return digest(text.encode())


def ledger_records(raw):
    """Apply the Bash/PowerShell ledger contract, including optional binding stages and hash suffixes."""
    document = strict_json(raw.decode('utf-8'))
    if (not isinstance(document, dict) or set(document) != {'schema', 'records'}
            or document['schema'] != 'review-identity-ledger/v1'
            or not isinstance(document['records'], list) or not document['records']):
        raise Blocked('existing identity ledger contract is invalid')
    previous, runs, sessions = '', set(), set()
    for sequence, record in enumerate(document['records'], 1):
        if not (isinstance(record, dict) and RECORD_KEYS <= set(record)
                and set(record) - RECORD_KEYS <= {'scratch_declaration_sha256', 'allowed_inputs_sha256'}
                and type(record['sequence']) is int and record['sequence'] == sequence
                and all(isinstance(record[key], str) and IDENTIFIER.fullmatch(record[key])
                        for key in ('stage', 'role', 'run_id', 'host_session_id'))
                and record['previous_record_sha256'] == previous and is_digest(record['record_sha256'])
                and ('scratch_declaration_sha256' not in record or (
                    record['stage'] == 'quality' and record['role'] == 'sdd-evaluator'
                    and is_digest(record['scratch_declaration_sha256'])))
                and ('allowed_inputs_sha256' not in record or (
                    record['stage'] in ('spec', 'impl', 'task', 'quality', 'domain')
                    and is_digest(record['allowed_inputs_sha256'])))
                and record['run_id'] not in runs and record['host_session_id'] not in sessions
                and record_hash(record) == record['record_sha256']):
            raise Blocked('existing identity ledger chain is invalid')
        previous = record['record_sha256']
        runs.add(record['run_id'])
        sessions.add(record['host_session_id'])
    return document['records']


def ledger_bytes(records):
    return (json.dumps(dict(schema='review-identity-ledger/v1', records=records), sort_keys=True) + '\n').encode()


def sealed(body):
    """Encode a receipt with its self-digest: detects isolated field corruption, not a signature."""
    body = {key: value for key, value in body.items() if key != 'receipt_sha256'}
    body['receipt_sha256'] = digest(json.dumps(body, sort_keys=True, separators=(',', ':')).encode())
    return (json.dumps(body, indent=2, sort_keys=True) + '\n').encode()


def receipt_bytes(root, record, evidence, before, after):
    return sealed(dict(
        schema='review-host-registration/v1', host='claude-code',
        source_kind='claude-code-native-result-and-transcript', cli_version=evidence['version'],
        canonical_root=str(root),
        result=dict(sha256=digest(evidence['result']), bytes=len(evidence['result'])),
        transcript=dict(path=evidence['path'], sha256=digest(evidence['transcript']),
                        bytes=len(evidence['transcript'])),
        run_id=record['run_id'], host_session_id=record['host_session_id'], sequence=record['sequence'],
        record_sha256=record['record_sha256'], ledger_before_sha256=before, ledger_after_sha256=after,
        before_record_count=record['sequence'] - 1))


def published_receipts(root, destination, records):
    """Return every receipt keyed by record hash after checking its own consistency and ledger link.

    Receipts are never deleted or rewritten here.
    """
    folder = destination / 'host-registrations'
    if not os.path.lexists(folder):
        return {}
    if redirected(folder) or not folder.is_dir():
        raise Blocked('registration receipt directory is not a real directory')
    entries = []
    with os.scandir(folder) as listing:
        for entry in listing:
            entries.append(entry.name)
            if len(entries) > EVIDENCE_FILES:
                raise Blocked('registration receipt directory exceeds its entry limit')
    by_hash = {record['record_sha256']: record for record in records}
    receipts, total = {}, 0
    for name in sorted(entries):
        if name.startswith(RECEIPT_STAGING):
            continue  # Staging bytes of an interrupted write were never published.
        stem = name[:-len('.json')]
        if not name.endswith('.json') or not DIGEST.fullmatch(stem):
            raise Blocked('registration receipt directory contains an unknown entry')
        info = os.lstat(folder / name)
        staged_links = [other for other in entries if other.startswith(RECEIPT_STAGING)
                        and os.path.samestat(os.lstat(folder / other), info)]
        if stat.S_ISREG(info.st_mode) and info.st_nlink == 2 and len(staged_links) == 1:
            # Interrupted between the exclusive link and the staging unlink: recognized, never mutated.
            raise Unpublished('a registration receipt still shares its file with one staging name after an '
                              'interrupted write; it was preserved and needs the documented manual recovery')
        raw = read_regular(folder / name, EVIDENCE_LIMIT)[0]
        total += len(raw)
        if total > EVIDENCE_TOTAL:
            raise Blocked('registration receipts exceed their size limit')
        document = strict_json(raw.decode('utf-8'))
        if not (isinstance(document, dict) and set(document) == RECEIPT_KEYS and raw == sealed(document)
                and (document['schema'], document['host'], document['source_kind'], document['canonical_root'])
                == ('review-host-registration/v1', 'claude-code', 'claude-code-native-result-and-transcript', str(root))
                and document['cli_version'] in CLAUDE_VERSIONS and document['record_sha256'] == stem
                and isinstance(document['run_id'], str) and SESSION.fullmatch(document['run_id'])
                and document['host_session_id'] == document['run_id']
                and type(document['sequence']) is int and document['sequence'] > 1
                and document['before_record_count'] == document['sequence'] - 1
                and is_digest(document['ledger_before_sha256']) and is_digest(document['ledger_after_sha256'])
                and isinstance(document['result'], dict) and set(document['result']) == {'sha256', 'bytes'}
                and isinstance(document['transcript'], dict)
                and set(document['transcript']) == {'path', 'sha256', 'bytes'}
                and all(is_digest(item['sha256']) and type(item['bytes']) is int and item['bytes'] > 0
                        for item in (document['result'], document['transcript']))):
            raise Blocked('registration receipt is malformed')
        record = by_hash.get(stem)
        if record is not None and (
                (record['stage'], record['role'], record['run_id'], record['host_session_id'], record['sequence'])
                != ('host', 'orchestrator', document['run_id'], document['run_id'], document['sequence'])
                or document['ledger_after_sha256'] != digest(ledger_bytes(records[:record['sequence']]))):
            raise Blocked('registration receipt does not describe its ledger record')
        receipts[stem] = (raw, document)
    return receipts


def implementation_identities(root):
    """Collect run/session IDs from the bounded implementation evidence set; unreadable members block.

    Returns the IDs and a fingerprint of every visited entry and read byte, so a later
    scan can prove the set did not change. This is not proof that no unreferenced
    manifest exists elsewhere.
    """
    identities, cache, budget, visited = set(), {}, [EVIDENCE_FILES, EVIDENCE_TOTAL], []

    def load(relative):
        if relative not in cache:
            raw, _ = read_regular(root / relative, EVIDENCE_LIMIT)
            budget[0], budget[1] = budget[0] - 1, budget[1] - len(raw)
            if budget[0] < 0 or budget[1] < 0:
                raise Blocked('bounded implementation evidence exceeds its limit')
            cache[relative] = raw
        return cache[relative]

    def collect(document, manifest=False):
        if isinstance(document, dict) and (manifest or document.get('schema') == 'task-input-manifest/v1'):
            if document.get('schema') != 'task-input-manifest/v1' or not all(
                    isinstance(document.get(key), str) and document[key] for key in ('run_id', 'session_id')):
                raise Blocked('implementation task manifest identity is invalid')
        if isinstance(document, dict):
            identities.update(document[key] for key in ('run_id', 'session_id', 'host_session_id')
                              if isinstance(document.get(key), str))

    def follow(reference, manifest=True):
        if (not isinstance(reference, dict) or set(reference) != {'path', 'sha256'}
                or not isinstance(reference['path'], str) or not RELATIVE.fullmatch(reference['path'])
                or any(part in ('.', '..') for part in reference['path'].split('/'))
                or not is_digest(reference['sha256'])):
            raise Blocked('implementation manifest reference is malformed')
        raw = load(reference['path'])
        if digest(raw) != reference['sha256']:
            raise Blocked('implementation manifest reference hash does not match')
        document = strict_json(raw.decode('utf-8'))
        collect(document, manifest)
        return document

    def report(raw):
        for line in raw.decode('utf-8').splitlines():
            match = re.match(r'(?:- \*\*)?(?:Run|Session) ID(?:\*\*)?: (.*)', line)
            if match:
                identities.add(match.group(1).strip().strip('`'))
            if line.startswith('Input manifest:'):
                citation = re.fullmatch(r'Input manifest: `([^`]+)`, SHA-256 `([0-9a-f]{64})`(?:\..*)?', line)
                if not citation:
                    raise Blocked('implementation report manifest citation is malformed')
                follow(dict(path=citation.group(1), sha256=citation.group(2)))

    def unreadable(error):
        raise Blocked('implementation evidence directory is unreadable') from error

    for top in EVIDENCE_ROOTS:
        base = root / top
        if not os.path.lexists(base):
            continue
        if redirected(base) or not base.is_dir():
            raise Blocked('implementation evidence directory is not a real directory')
        for folder, folders, files in os.walk(base, onerror=unreadable):
            # shortcut: one directory listing is read whole before counting; a per-entry scandir cap is the upgrade.
            for name in folders + files:
                entry = Path(folder) / name
                visited.append(entry.relative_to(root).as_posix())
                if len(visited) > EVIDENCE_FILES:
                    raise Blocked('bounded implementation evidence exceeds its entry limit')
                if redirected(entry) or not (entry.is_dir() if name in folders else stat.S_ISREG(entry.lstat().st_mode)):
                    raise Blocked('implementation evidence contains a link or special file')
            for name in sorted(files):
                relative = (Path(folder) / name).relative_to(root).as_posix()
                if top == 'reports/implementation' and name.endswith('.md'):
                    report(load(relative))
                elif name.endswith('.json'):
                    document = strict_json(load(relative).decode('utf-8'))
                    collect(document)
                    if isinstance(document, dict) and document.get('schema') == 'review-context-invocation/v2':
                        if 'implementation_manifest' in document:
                            follow(document['implementation_manifest'])
                        if 'supplemental_delivery_declaration' in document:
                            declaration = follow(document['supplemental_delivery_declaration'], manifest=False)
                            if isinstance(declaration, dict) and 'implementation_manifest' in declaration:
                                follow(declaration['implementation_manifest'])
    fingerprint = digest(json.dumps([sorted(visited), sorted((path, digest(raw)) for path, raw in cache.items())])
                         .encode())
    return identities, fingerprint


def fsync_directory(path):
    # Windows cannot open a directory for fsync; os.replace is still the publication step there.
    if os.name == 'nt':
        return
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    except OSError as error:
        if error.errno not in {errno.EINVAL, errno.EBADF, errno.ENOTSUP, getattr(errno, 'EOPNOTSUPP', errno.ENOTSUP)}:
            raise
    finally:
        os.close(descriptor)


def stage_file(folder, prefix, data):
    with tempfile.NamedTemporaryFile(dir=folder, prefix=prefix, delete=False) as stream:
        staged = Path(stream.name)
        try:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        except BaseException:
            stream.close()
            staged.unlink(missing_ok=True)
            raise
    return staged


def publish_receipt(root, name, data):
    folder = directory(root, 'reports/review-context/host-registrations')
    staged = stage_file(folder, RECEIPT_STAGING, data)
    try:
        os.link(staged, folder / (name + '.json'))  # Exclusive: never replaces an existing receipt.
    finally:
        staged.unlink(missing_ok=True)
    fsync_directory(folder)


def publish_ledger(ledger, before, after, unchanged):
    staged = stage_file(ledger.parent, '.identity-append-', after)
    try:
        if read_regular(ledger, LEDGER_LIMIT)[0] != before:
            raise Unpublished('identity ledger changed after the receipt was published; the receipt was preserved')
        try:
            unchanged()
        except Blocked as error:
            raise Unpublished(str(error) + '; the receipt was preserved') from None
        os.replace(staged, ledger)
    finally:
        staged.unlink(missing_ok=True)
    fsync_directory(ledger.parent)


def register_existing(root, result, transcript, check_only=False):
    """Append the Claude host of a stopped native session to an existing ledger, or verify it."""
    root = Path(root).resolve(strict=True)
    if not root.is_dir():
        raise Blocked('project root is not a directory')
    captured = claude_result(root, result)
    session = captured['session']
    native = claude_transcript(root, transcript, session)
    destination = existing_directory(root, 'reports/review-context')
    ledger = destination / 'identity-ledger.json'
    lock = destination / 'identity-ledger.json.lock'
    try:
        lock.mkdir()  # Same exclusion path as both review reservation validators.
    except FileExistsError:
        raise Busy('identity ledger lock is held by another process; it was left in place') from None
    try:
        # Every check reruns under the lock; an earlier --check-only authorizes nothing.
        if read_regular(captured['source'], NATIVE_LIMIT) != (captured['raw'], captured['identity']):
            raise Blocked('Claude result changed during registration')
        current, identity = read_regular(native['source'], NATIVE_LIMIT)
        if identity != native['identity']:
            raise Blocked('Claude transcript was replaced during registration')
        if not os.path.lexists(ledger):
            raise Blocked('existing identity ledger is missing; append mode never creates one')
        before = read_regular(ledger, LEDGER_LIMIT)[0]
        records = ledger_records(before)
        receipts = published_receipts(root, destination, records)
        own = [record for record in records if session in (record['run_id'], record['host_session_id'])]
        if own:
            record = own[0]
            if len(own) != 1 or (record['stage'], record['role'], record['run_id'], record['host_session_id']) != (
                    'host', 'orchestrator', session, session):
                raise Blocked('candidate identity collides with a persisted identity-ledger record')
            if record['record_sha256'] not in receipts:
                raise Blocked('registered host has no registration receipt; history is not retrofitted')
            raw, receipt = receipts[record['record_sha256']]
            bound = receipt['transcript']
            # A later same-ID resume may append to the transcript; the bound prefix must not change.
            if not isinstance(bound, dict) or type(bound.get('bytes')) is not int or not 0 < bound['bytes'] <= len(current):
                raise Blocked('registration receipt does not match the native transcript prefix')
            prefix = current[:bound['bytes']]
            evidence = dict(result=captured['raw'], path=native['path'], transcript=prefix,
                            version=transcript_version(root, prefix, session, captured['version']))
            # Pre-append bytes are gone once published: ledger_before_sha256 is held by the receipt
            # self-digest (published_receipts) and, for unpublished completion, by equality here.
            after = digest(ledger_bytes(records[:record['sequence']]))
            if not is_digest(receipt['ledger_before_sha256']) or raw != receipt_bytes(
                    root, record, evidence, receipt['ledger_before_sha256'], after):
                raise Blocked('registration receipt does not match the ledger record and native evidence')
            return dict(outcome='REVIEW_HOST_ALREADY_REGISTERED', record=record)
        if current != native['raw']:
            raise Blocked('Claude transcript changed during registration; register only a stopped session')
        evidence = dict(result=captured['raw'], path=native['path'], transcript=current,
                        version=transcript_version(root, current, session, captured['version']))
        tip = records[-1]
        record = dict(sequence=tip['sequence'] + 1, stage='host', role='orchestrator', run_id=session,
                      host_session_id=session, previous_record_sha256=tip['record_sha256'])
        record['record_sha256'] = record_hash(record)
        after = ledger_bytes(records + [record])
        receipt = receipt_bytes(root, record, evidence, digest(before), digest(after))
        known = {item['record_sha256'] for item in records}
        orphans = {name: raw for name, (raw, _) in receipts.items() if name not in known}
        pending = orphans.pop(record['record_sha256'], None)
        # Only this exact interrupted append may be completed; anything else is never rebased or removed.
        if orphans or pending not in (None, receipt):
            raise Unpublished('a registration receipt has no ledger record; it was preserved and needs investigation')
        identities, fingerprint = implementation_identities(root)
        if session in identities:
            raise Blocked('candidate identity is already recorded by implementation evidence')

        def unchanged():
            # Recheck immediately before each publication step, not only once after locking.
            if (read_regular(captured['source'], NATIVE_LIMIT) != (captured['raw'], captured['identity'])
                    or read_regular(native['source'], NATIVE_LIMIT) != (native['raw'], native['identity'])):
                raise Blocked('Claude native evidence changed during registration')
            if implementation_identities(root)[1] != fingerprint:
                raise Blocked('implementation evidence changed during registration')
        if check_only:
            return dict(outcome='REVIEW_HOST_CHECK_REGISTRABLE', record=record, pending=pending is not None)
        if pending is None:
            unchanged()
            publish_receipt(root, record['record_sha256'], receipt)
        publish_ledger(ledger, before, after, unchanged)
        published = destination / 'host-registrations' / (record['record_sha256'] + '.json')
        if read_regular(ledger, LEDGER_LIMIT)[0] != after or read_regular(published, EVIDENCE_LIMIT)[0] != receipt:
            raise Blocked('published ledger and receipt do not correspond')
        return dict(outcome='REVIEW_HOST_REGISTERED', record=record, pending=pending is not None)
    finally:
        lock.rmdir()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--copilot-events', help='fresh project only: original Copilot session-state events.jsonl')
    parser.add_argument('--register-existing', action='store_true',
                        help='append the Claude host of a stopped native session to the existing ledger')
    parser.add_argument('--claude-result', help='original captured Claude CLI result (json or stream-json)')
    parser.add_argument('--claude-transcript', help='original $HOME/.claude/projects/<encoded-root>/<session>.jsonl')
    parser.add_argument('--check-only', action='store_true', help='run every append check under the lock; write nothing')
    args = parser.parse_args()
    append_options = (args.register_existing, args.claude_result, args.claude_transcript, args.check_only)
    if args.copilot_events is not None:
        if any(option not in (False, None) for option in append_options):
            parser.error('--copilot-events cannot be combined with append-mode options')
        try:
            initialize(args.root, args.copilot_events)
            print('REVIEW_HOST_REGISTERED')
            return 0
        except (OSError, ValueError, TypeError, KeyError):
            print('REVIEW_HOST_BLOCKED: native identity, fresh-project history, or exclusive publication check failed')
            return 1
    if not (args.register_existing and args.claude_result and args.claude_transcript):
        parser.error('use --copilot-events, or --register-existing with --claude-result and --claude-transcript')
    try:
        status = register_existing(args.root, args.claude_result, args.claude_transcript, args.check_only)
    except Busy as error:
        print('REVIEW_HOST_BUSY: ' + str(error))
        return 1
    except Unpublished as error:
        print('REVIEW_HOST_UNPUBLISHED: ' + str(error))
        return 1
    except Blocked as error:
        print('REVIEW_HOST_BLOCKED: ' + str(error))
        return 1
    except (OSError, ValueError, TypeError, KeyError, RecursionError):
        print('REVIEW_HOST_BLOCKED: native evidence, existing ledger, or publication check failed; '
              'rerun with --check-only to diagnose')
        return 1
    record = status['record']
    print(f"{status['outcome']} sequence={record['sequence']} record_sha256={record['record_sha256']} "
          f"run_id={record['run_id']} host_session_id={record['host_session_id']}"
          + (' unpublished_receipt=completes' if status.get('pending') else ''))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
