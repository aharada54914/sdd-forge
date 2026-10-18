"""Strict cloud v1 artifact integrity, NOT authorization or provider execution.

parse_artifact validates bytes and internal consistency; read_verified hashes
exact bytes under a caller-selected artifact root. verify_binding links request,
lock, preview and optional receipt; verify_lock additionally requires independently
observed dependency/tool inventories from a trusted adapter. Neither authenticates
an issuer, grants writes, verifies provider health, or proves an inventory complete.

publish_artifact requires a trusted secret scanner returning literal True on the
exact bytes. Supply the run evidence directory as root, never the workspace root.
Parents must already exist. Publication is atomic and exclusive (no overwrite).
Filesystem operations require POSIX no-follow/dir-fd primitives; unsupported hosts
fail closed. Callers own root permissions, exclusive directory ownership and cloud
admission. Do not treat integrity success as approval or log untrusted payloads.
"""
from contextlib import contextmanager
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import stat

OWNERS = ('bicep', 'cdk', 'terraform', 'sam', 'cloudformation', 'azd')
MAX_BYTES = 4 * 1024 * 1024
OPERATIONS = ('route', 'plan', 'validate', 'prepare', 'apply', 'reconcile', 'observe', 'verify')
SUCCESS_STATES = ('ROUTED', 'PLANNED', 'LOCAL_VALIDATED', 'PREPARE_AUTHORIZED',
                  'PREVIEW_READY', 'APPLY_AUTHORIZED', 'EXECUTING', 'OBSERVED',
                  'VERIFIED', 'EVIDENCE_COMPLETE')
EXIT_CODES = {'PASS': 0, 'NO_CHANGE': 0, 'BLOCKED': 2, 'FAIL': 1, 'UNKNOWN': 3}


class ContractError(ValueError):
    """Safe fixed diagnostic; never includes input bytes, secrets or native errors."""


def _require(condition, code='INVALID_ARTIFACT'):
    if not condition:
        raise ContractError(code)


def _match(value, pattern):
    _require(type(value) is str and re.fullmatch(pattern, value) is not None)


def _text(value):
    _match(value, r'[\x20-\x7e]{1,2048}')


def _id(value):
    _match(value, r'[A-Za-z0-9][A-Za-z0-9._:-]{0,127}')


def _sha(value):
    _match(value, r'[a-f0-9]{64}')


def _revision(value):
    _match(value, r'(?:[a-f0-9]{40}|[a-f0-9]{64})')


def _version(value):
    _match(value, r'[0-9]+(?:\.[0-9]+){0,3}(?:-[A-Za-z0-9.-]+)?')


def _url(value):
    # No credentials, query secrets, fragments, port tricks or encoded traversal.
    _match(value, r'https://[a-z0-9]+(?:[.-][a-z0-9]+)*(?:/(?!\.{1,2}(?:/|$))[A-Za-z0-9._-]+)*')
    _require(all(p not in ('.', '..') for p in value.split('/')[3:]))


def _enum(value, choices):
    _require(type(value) is str and value in choices)


def _integer(value, minimum=0):
    _require(type(value) is int and minimum <= value <= 2147483647)


def _boolean(value):
    _require(type(value) is bool)


def _utc(value):
    _match(value, r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z')
    try:
        return datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ')
    except ValueError:
        raise ContractError('INVALID_UTC') from None


def _path(value):
    _require(type(value) is str and 1 <= len(value) <= 1024, 'UNSAFE_PATH')
    for part in value.split('/'):
        _require(re.fullmatch(r'[A-Za-z0-9_.][A-Za-z0-9._-]*', part) is not None
                 and not part.endswith('.') and len(part) <= 255, 'UNSAFE_PATH')
        _require(part.split('.')[0].upper() not in
                 {'CON', 'PRN', 'AUX', 'NUL', *(f'COM{i}' for i in range(10)),
                  *(f'LPT{i}' for i in range(10))}, 'UNSAFE_PATH')


def _record(value, fields, optional=None):
    optional = optional or {}
    _require(type(value) is dict)
    _require(set(fields) <= set(value) <= set(fields) | set(optional))
    for name, validator in {**fields, **optional}.items():
        if name in value:
            validator(value[name])


def _list(value, validator, minimum=0):
    _require(type(value) is list and minimum <= len(value) <= 4096)
    for item in value:
        validator(item)


def _unique(values):
    _require(len(values) == len(set(values)), 'DUPLICATE_ENTRY')


def _ids(value, minimum=0):
    _list(value, _id, minimum)
    _unique(value)


def _ref(value):
    _record(value, {'path': _path, 'sha256': _sha})


def _profile(value):
    _record(value, {'id': _id, 'version': _version, 'path': _path, 'sha256': _sha})


def _scope(value):
    _record(value, {'account_id': _id, 'region': _id, 'deployment_scope': _id})


def _nullable_ref(value):
    if value is not None:
        _ref(value)


def _nullable_text(value):
    if value is not None:
        _text(value)


def _identity_fields():
    return {'run_id': _id, 'unit_id': _id, 'provider': lambda v: _enum(v, ('azure', 'aws'))}


def _binding_fields():
    return {**_identity_fields(), 'scope': _scope, 'request': _ref,
            'dependency_lock': _ref, 'policy': _ref, 'verification_profile': _ref}


def _schema(value, name, fields, optional=None):
    _record(value, {'schema': lambda v: _enum(v, (name,)), **fields}, optional)


def _owner(value):
    _enum(value, OWNERS)


def _local_context(value):
    def directories(v):
        _list(v, _path, 1)
        _unique(v)
    _record(value, {
        'workspace_anchor': lambda v: _enum(v, ('CLOUD_WORKSPACE_ROOT',)),
        'artifact_root': _path, 'unit_roots': directories, 'evidence_directory': _path,
        'feature': lambda v: (_match(v, r'[a-z0-9]+(?:-[a-z0-9]+)*'), _path(v)),
        'task_id': lambda v: _match(v, r'T-[0-9]{3}'),
        'ownership': _ref, 'provider_config': _ref})


def _ownership(value):
    def owner(v):
        _record(v, {'owner': _owner, 'root': _path})
    def resource(v):
        _record(v, {'resource_id': _text, 'owner': _owner,
                    'attachments': lambda a: _list(a, lambda x: _record(x, {
                        'resource_type': _text, 'name': _id}))})
        _unique([(a['resource_type'], a['name']) for a in v['attachments']])
    _schema(value, 'cloud-ownership/v1', {
        'owners': lambda v: _list(v, owner),
        'existing_resources': lambda v: _list(v, resource)})
    _unique([(o['owner'], o['root']) for o in value['owners']])
    _unique([r['resource_id'] for r in value['existing_resources']])


def _deployment_policy(value):
    def scopes(v):
        _list(v, _scope, 1)
        _unique([tuple(s[k] for k in ('account_id', 'region', 'deployment_scope')) for s in v])
    def types(v):
        _list(v, _text, 1)
        _unique(v)
    _schema(value, 'cloud-deployment-policy/v1', {
        'allowed_scopes': scopes, 'allowed_resource_types': types,
        'backup_required': _boolean,
        'private_networking': lambda v: _require(v is True),
        'budget': lambda v: _record(v, {'ceiling_minor_units': lambda n: _integer(n, 1),
                                      'currency': lambda c: _match(c, r'[A-Z]{3}')}),
        'evidence': lambda v: _record(v, {'residency': _id,
            'retention_days': lambda n: _integer(n, 1),
            'access': lambda a: _enum(a, ('restricted',))})})


def _verification_profile(value):
    _schema(value, 'cloud-verification-profile/v1', {
        'id': _id, 'version': _version, 'required_check_ids': lambda v: _ids(v, 1),
        'max_age_seconds': lambda n: _integer(n, 1)})


def _request(value):
    def artifact(v):
        _record(v, {'kind': lambda k: _enum(k, ('source', 'compiled', 'asset', 'parameters', 'module')),
                    'path': _path, 'sha256': _sha})
    def predecessor(v):
        _record(v, {'unit_id': _id, 'path': _path, 'sha256': _sha})
    _schema(value, 'cloud-run-request/v1', {
        **_identity_fields(), 'binding_id': _id, 'environment': _id, 'scope': _scope,
        'owner': lambda v: None if v is None else _owner(v),
        'route': lambda v: None if v is None else _enum(v, ('azure-bicep', 'aws-cdk')),
        'operation': lambda v: _enum(v, OPERATIONS),
        'predecessor_receipts': lambda v: _list(v, predecessor), 'source_revision': _revision,
        'input_artifacts': lambda v: _list(v, artifact, 1), 'dependency_lock': _ref,
        'policy': _ref, 'verification_profile': _profile}, {'local_context': _local_context})
    _require((value['operation'] == 'route' and value['route'] is None) or (value['provider'], value['owner'], value['route']) in
             (('azure', 'bicep', 'azure-bicep'), ('aws', 'cdk', 'aws-cdk')))
    _unique([v['path'] for v in value['input_artifacts']])
    _unique([v['unit_id'] for v in value['predecessor_receipts']])
    _require(value['unit_id'] not in [v['unit_id'] for v in value['predecessor_receipts']])


def _lock(value):
    def file(v):
        _record(v, {'path': _path, 'sha256': _sha, 'references': lambda r: _list(r, _path)})
        _unique(v['references'])
    def upstream(v):
        _record(v, {'repository': _url, 'commit': _revision, 'root': _path,
                    'files': lambda f: _list(f, file, 1)})
        paths = [f['path'] for f in v['files']]
        _unique(paths)
        _require(all(p.startswith(v['root'] + '/') for p in paths), 'UNLOCKED_DEPENDENCY')
        _require(all(p in paths for f in v['files'] for p in f['references']), 'UNLOCKED_DEPENDENCY')
    def tool(v):
        _record(v, {'name': _id, 'version': _version, 'sha256': _sha})
    def endpoint(v):
        _record(v, {'endpoint': _url, 'tool_schema': _ref})
    _schema(value, 'cloud-dependency-lock/v1', {
        'upstream': lambda v: _list(v, upstream, 1), 'tools': lambda v: _list(v, tool, 1),
        'adapter_version': _version, 'managed_endpoints': lambda v: _list(v, endpoint)})
    _unique([f['path'] for u in value['upstream'] for f in u['files']])
    _unique([t['name'] for t in value['tools']])
    _unique([e['endpoint'] for e in value['managed_endpoints']])


def _window(value, start):
    _require(_utc(value[start]) < _utc(value['expires_at']), 'INVALID_TIME_WINDOW')


def _preview(value):
    _schema(value, 'cloud-preview/v1', {
        **_binding_fields(), 'preview_identity': _text, 'semantic_sha256': _sha,
        'changes': _ref, 'replacements': lambda v: _list(v, _text),
        'deletes': lambda v: _list(v, _text), 'created_at': _utc, 'expires_at': _utc})
    _window(value, 'created_at')


def _receipt(value):
    def ci(v):
        _record(v, {'repository': _text, 'workflow': _path, 'workflow_revision': _revision,
                    'ref': _text, 'environment': _id, 'run_id': _id,
                    'run_attempt': lambda n: _integer(n, 1)})
    def approval(v):
        _record(v, {'locator': _url, 'sha256': _sha})
    _schema(value, 'cloud-authorization-receipt/v1', {
        **_binding_fields(), 'operation': lambda v: _enum(v, ('prepare', 'apply')),
        'issuer': _url, 'principal': _text, 'subject': _text, 'ci': ci,
        'preview': _nullable_ref, 'issued_at': _utc, 'expires_at': _utc,
        'approval_evidence': approval})
    _require(value['operation'] != 'apply' or value['preview'] is not None)
    _window(value, 'issued_at')


def _observation(value):
    _schema(value, 'cloud-observation/v1', {
        **_identity_fields(), 'native_operation_id': _nullable_text,
        'resource_ids': lambda v: _list(v, _text, 1), 'principal': _text,
        'query': _text, 'timestamp': _utc, 'exit_code': _integer,
        'status': lambda v: _enum(v, ('PASS', 'FAIL', 'BLOCKED', 'UNKNOWN')),
        'result': _ref, 'classification': lambda v: _enum(v, ('synthetic', 'native'))})
    _require(value['status'] != 'PASS' or value['exit_code'] == 0)


def _verification(value):
    def check(v):
        _record(v, {'check_id': _id, 'observation': _ref,
                    'result': lambda r: _enum(r, ('PASS', 'FAIL', 'BLOCKED'))})
    _schema(value, 'cloud-verification/v1', {
        **_identity_fields(), 'profile': _profile, 'required_check_ids': lambda v: _ids(v, 1),
        'checks': lambda v: _list(v, check, 1),
        'overall_result': lambda v: _enum(v, ('PASS', 'FAIL', 'BLOCKED')),
        'evidence_complete': _boolean})
    ids = [c['check_id'] for c in value['checks']]
    _unique(ids)
    _require(set(ids) == set(value['required_check_ids']), 'CHECK_SET_MISMATCH')
    if value['overall_result'] == 'PASS':
        _require(all(c['result'] == 'PASS' for c in value['checks']), 'RESULT_MISMATCH')
    _require(not value['evidence_complete'] or value['overall_result'] == 'PASS', 'RESULT_MISMATCH')


def _result(value):
    _schema(value, 'cloud-operation-result/v1', {
        **_identity_fields(), 'operation': lambda v: _enum(v, OPERATIONS),
        'state': lambda v: _enum(v, SUCCESS_STATES + ('NO_CHANGE', 'BLOCKED', 'FAILED', 'UNKNOWN')),
        'result': lambda v: _enum(v, EXIT_CODES), 'error_code': lambda v: None if v is None else _id(v),
        'message': _text, 'input_manifest_sha256': _sha,
        'evidence_manifest_path': lambda v: None if v is None else _path(v)},
        {'native_operation_id': _text})
    result = value['result']
    _require(value['evidence_manifest_path'] is not None or
             (result in ('BLOCKED', 'FAIL') and 'native_operation_id' not in value))
    _require((value['error_code'] is None) == (result in ('PASS', 'NO_CHANGE')))
    if result == 'PASS':
        _require(value['state'] in SUCCESS_STATES)
    else:
        _require(value['state'] == {'FAIL': 'FAILED'}.get(result, result))
    _require(result != 'NO_CHANGE' or 'native_operation_id' not in value)


def _input_error(value):
    _schema(value, 'cloud-input-error/v1', {'error_code': _id, 'message': _text, 'field': _id})


VALIDATORS = {'cloud-ownership/v1': _ownership,
              'cloud-deployment-policy/v1': _deployment_policy,
              'cloud-verification-profile/v1': _verification_profile, 'cloud-run-request/v1': _request, 'cloud-dependency-lock/v1': _lock,
              'cloud-preview/v1': _preview, 'cloud-authorization-receipt/v1': _receipt,
              'cloud-observation/v1': _observation, 'cloud-verification/v1': _verification,
              'cloud-operation-result/v1': _result, 'cloud-input-error/v1': _input_error}


def parse_artifact(data, expected_schema=None):
    """Parse bounded UTF-8 JSON; no duplicate keys, non-finite numbers or coercion."""
    _require(type(data) is bytes and len(data) <= MAX_BYTES, 'INVALID_JSON')
    def pairs(items):
        result = {}
        for key, value in items:
            _require(key not in result, 'DUPLICATE_KEY')
            result[key] = value
        return result
    def no_number(_):
        raise ContractError('INVALID_NUMBER')
    try:
        value = json.loads(data.decode('utf-8'), object_pairs_hook=pairs,
                           parse_constant=no_number, parse_float=no_number)
        _require(type(value) is dict and type(value.get('schema')) is str)
        schema = value['schema']
        _require(schema in VALIDATORS and (expected_schema is None or schema == expected_schema), 'UNKNOWN_SCHEMA')
        VALIDATORS[schema](value)
        return value
    except ContractError:
        raise
    except (UnicodeError, ValueError, RecursionError, OverflowError):
        raise ContractError('INVALID_JSON') from None


@contextmanager
def _parent(root, relative):
    _path(relative)
    _require(hasattr(os, 'O_NOFOLLOW') and hasattr(os, 'O_DIRECTORY')
             and os.open in os.supports_dir_fd and os.link in os.supports_dir_fd,
             'UNSUPPORTED_FILESYSTEM')
    root = os.fspath(root)
    _require(os.path.isabs(root) and all(p not in ('.', '..') for p in root.split('/')), 'UNSAFE_ROOT')
    fd = None
    try:
        fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
        for part in [p for p in root.split('/') if p] + relative.split('/')[:-1]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        yield fd, relative.split('/')[-1]
    except OSError:
        raise ContractError('UNSAFE_OR_UNAVAILABLE_FILE') from None
    finally:
        if fd is not None:
            os.close(fd)


def read_verified(root, reference):
    """Read one canonical regular single-link file and check its exact-byte digest."""
    _ref(reference)
    with _parent(root, reference['path']) as (parent, name):
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
        with os.fdopen(fd, 'rb') as stream:
            before = os.fstat(stream.fileno())
            _require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1, 'UNSAFE_FILE')
            _require(before.st_size <= MAX_BYTES, 'ARTIFACT_TOO_LARGE')
            data = stream.read(MAX_BYTES + 1)
            after = os.fstat(stream.fileno())
            _require((before.st_size, before.st_mtime_ns, before.st_ctime_ns) ==
                     (after.st_size, after.st_mtime_ns, after.st_ctime_ns), 'INPUT_DRIFT')
    _require(len(data) <= MAX_BYTES and hashlib.sha256(data).hexdigest() == reference['sha256'], 'DIGEST_MISMATCH')
    return data


def _file_ref(value):
    return {k: value[k] for k in ('path', 'sha256')}


def read_artifact(root, reference, expected_schema=None):
    """Read a contract and verify every directly referenced file's exact bytes.

References to contracts are hashed but not recursively authenticated or reduced.
Consumers must parse referenced observations/receipts and check their identities.
"""
    value = parse_artifact(read_verified(root, reference), expected_schema)
    def references(node):
        if type(node) is dict:
            if 'path' in node and 'sha256' in node:
                read_verified(root, _file_ref(node))
            for child in node.values():
                references(child)
        elif type(node) is list:
            for child in node:
                references(child)
    references(value)
    return value


def _verify_lock_files(root, lock):
    for upstream in lock['upstream']:
        for file in upstream['files']:
            read_verified(root, _file_ref(file))
    for endpoint in lock['managed_endpoints']:
        read_verified(root, endpoint['tool_schema'])


def verify_lock(root, lock, *, consumed_paths, tools, adapter_version, tool_schemas):
    """Compare declared closure to independently observed adapter inputs (mandatory).

The caller must enumerate actual transitive reads, not copy these from the lock.
Managed schema digests are fresh read-only probes, not asserted server identity.
"""
    _lock(lock)
    _list(consumed_paths, _path, 1)
    _unique(consumed_paths)
    paths = [f['path'] for u in lock['upstream'] for f in u['files']]
    _require(set(paths) == set(consumed_paths), 'UNLOCKED_DEPENDENCY')
    _list(tools, lambda v: _record(v, {'name': _id, 'version': _version, 'sha256': _sha}), 1)
    _require(sorted(tools, key=lambda t: t['name']) ==
             sorted(lock['tools'], key=lambda t: t['name']), 'TOOL_DRIFT')
    _require(adapter_version == lock['adapter_version'], 'ADAPTER_DRIFT')
    _require(tool_schemas == {e['endpoint']: e['tool_schema']['sha256']
                              for e in lock['managed_endpoints']}, 'TOOL_SCHEMA_DRIFT')
    _verify_lock_files(root, lock)


def workspace_root():
    """Resolve ONLY explicit CLOUD_WORKSPACE_ROOT; reject normalization and links.

    Returns a physical absolute Path. No cwd, home or request-parent fallback.
    This boundary grants no authority and must be owned by the trusted caller.
    """
    root = os.environ.get('CLOUD_WORKSPACE_ROOT', '')
    _require(type(root) is str and not any(ord(c) < 32 or ord(c) == 127 for c in root)
             and root.startswith('/') and root != '/' and
             all(p and p not in ('.', '..') for p in root.split('/')[1:]), 'UNSAFE_ROOT')
    with _parent(root, 'boundary-probe'):
        pass
    return Path(root)


def _within(path, directory):
    return path == directory or path.startswith(directory + '/')


def _scan_unit(root, directory):
    """List every regular file recursively; never follow links or hide metadata."""
    found = []
    def visit(fd, relative):
        _path(relative)
        for name in sorted(os.listdir(fd)):
            path = relative + '/' + name
            _path(path)
            info = os.stat(name, dir_fd=fd, follow_symlinks=False)
            if stat.S_ISDIR(info.st_mode):
                child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
                try:
                    visit(child, path)
                finally:
                    os.close(child)
            else:
                _require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1, 'UNSAFE_FILE')
                found.append(path)
                _require(len(found) <= 4096, 'SCAN_TOO_LARGE')
    with _parent(root, directory + '/boundary-probe') as (fd, _):
        visit(fd, directory)
    return found


def verify_local_context(root, request, *, execution=False):
    """Check declared roots, immutable local bodies and return ALL scanned paths.

    Required for provider entry/admission. Router must detect owners from these
    actual files as well as inventory; this helper is not an IaC classifier or
    provider-config validator. Missing context is a typed ContractError for the
    CLI to map to BLOCKED. No directory is created and no authority is granted.
    """
    _request(request)
    _require('local_context' in request, 'LOCAL_CONTEXT_REQUIRED')
    _require(os.fspath(root) == os.fspath(workspace_root()), 'WORKSPACE_MISMATCH')
    context = request['local_context']
    artifact = context['artifact_root']
    evidence = context['evidence_directory']
    expected = (f"specs/{context['feature']}/verification/{context['task_id']}/cloud/"
                f"{request['run_id']}/{request['unit_id']}")
    _path(expected)
    _require(evidence == expected and not _within(evidence, artifact)
             and not _within(artifact, evidence), 'EVIDENCE_BOUNDARY_MISMATCH')
    with _parent(root, artifact + '/boundary-probe'):
        pass
    # Validate all existing output components without requiring the future directory.
    parts = evidence.split('/')
    for i in range(1, len(parts) + 1):
        relative = '/'.join(parts[:i])
        with _parent(root, relative) as (fd, name):
            try:
                info = os.stat(name, dir_fd=fd, follow_symlinks=False)
            except FileNotFoundError:
                break
            _require(stat.S_ISDIR(info.st_mode), 'UNSAFE_EVIDENCE_DIRECTORY')
    refs = [*request['input_artifacts'], request['dependency_lock'], request['policy'],
            request['verification_profile'], context['ownership'], context['provider_config']]
    lock = parse_artifact(read_verified(root, request['dependency_lock']), 'cloud-dependency-lock/v1')
    refs += [f for u in lock['upstream'] for f in u['files']]
    refs += [e['tool_schema'] for e in lock['managed_endpoints']]
    for ref in refs:
        _require(_within(ref['path'], artifact), 'INPUT_OUTSIDE_ARTIFACT_ROOT')
        read_verified(root, _file_ref(ref))
    ownership = read_artifact(root, context['ownership'], 'cloud-ownership/v1')
    policy = read_artifact(root, request['policy'], 'cloud-deployment-policy/v1')
    profile = read_artifact(root, _file_ref(request['verification_profile']), 'cloud-verification-profile/v1')
    _require(all(profile[k] == request['verification_profile'][k] for k in ('id', 'version')),
             'PROFILE_MISMATCH')
    _require(request['scope'] in policy['allowed_scopes'], 'SCOPE_DENIED')
    checks = {'resource', 'network', 'identity', 'monitoring', 'workload'}
    if policy['backup_required']:
        checks.add('backup')
    _require(checks <= set(profile['required_check_ids']), 'CHECK_SET_MISMATCH')
    files = set()
    for unit in context['unit_roots']:
        _require(_within(unit, artifact), 'UNIT_OUTSIDE_ARTIFACT_ROOT')
        files.update(_scan_unit(root, unit))
        _require(len(files) <= 4096, 'SCAN_TOO_LARGE')
    for owner in ownership['owners']:
        _require(any(_within(owner['root'], unit) for unit in context['unit_roots']), 'OWNER_OUTSIDE_UNIT_ROOT')
    if execution:
        _require(request['operation'] == 'apply' and
                 (request['provider'], request['owner'], request['route']) in
                 (('azure', 'bicep', 'azure-bicep'), ('aws', 'cdk', 'aws-cdk')), 'EXECUTION_ROUTE_REQUIRED')
        _require({o['owner'] for o in ownership['owners']} == {request['owner']}, 'OWNER_MISMATCH')
    for ref in request['predecessor_receipts']:
        prior = read_artifact(root, _file_ref(ref), 'cloud-verification/v1')
        _require(prior['unit_id'] == ref['unit_id'], 'PREDECESSOR_MISMATCH')
        prefix = f"specs/{context['feature']}/verification/"
        suffix = f"/cloud/{prior['run_id']}/{prior['unit_id']}/"
        _require(re.fullmatch(re.escape(prefix) + r'T-[0-9]{3}' + re.escape(suffix) + r'[^/]+', ref['path'])
                 is not None, 'PREDECESSOR_PATH_MISMATCH')
    return sorted(files)


def verify_binding(root, request_ref, preview_ref, receipt_ref=None, *, now, operation=None):
    """Check exact bytes and cross-artifact bindings. Returns None, NEVER authority.

operation is required for local_context requests: prepare/apply are stages of
the same apply intent. None preserves legacy integrity-only behavior. Protected
CI environment is authenticated by admission, not equated to the logical target.
Caller must separately authenticate admission, check live tool closure via
verify_lock and recheck immediately at the write site. Preview semantics are
provider-owned: semantic_sha256 binds the adapter's normalized changes file.
"""
    _utc(now)
    request = read_artifact(root, request_ref, 'cloud-run-request/v1')
    if operation is not None:
        _enum(operation, ('prepare', 'apply'))
        verify_local_context(root, request, execution=True)
    elif 'local_context' in request:
        raise ContractError('EXPLICIT_PHASE_REQUIRED')
    phase = request['operation'] if operation is None else operation
    preview = None if preview_ref is None else read_artifact(root, preview_ref, 'cloud-preview/v1')
    _require(phase != 'apply' or preview is not None, 'PREVIEW_REQUIRED')
    read_artifact(root, request['dependency_lock'], 'cloud-dependency-lock/v1')
    expected = {key: request[key] for key in ('run_id', 'unit_id', 'provider', 'scope', 'dependency_lock', 'policy')}
    expected.update(request=request_ref, verification_profile=_file_ref(request['verification_profile']))
    if 'local_context' in request:
        evidence = request['local_context']['evidence_directory']
        for ref in (preview_ref, receipt_ref, None if preview is None else preview['changes']):
            if ref is not None:
                _require(ref['path'].startswith(evidence + '/'), 'EVIDENCE_BOUNDARY_MISMATCH')
    if preview is not None:
        _require(preview['semantic_sha256'] == preview['changes']['sha256'], 'PREVIEW_DRIFT')
        for key, value in expected.items():
            _require(preview[key] == value, 'BINDING_MISMATCH')
        _require(_utc(preview['created_at']) <= _utc(now) < _utc(preview['expires_at']), 'STALE_PREVIEW')
    if receipt_ref is not None:
        receipt = read_artifact(root, receipt_ref, 'cloud-authorization-receipt/v1')
        for key, value in expected.items():
            _require(receipt[key] == value, 'BINDING_MISMATCH')
        _require(receipt['operation'] == phase, 'BINDING_MISMATCH')
        if operation is None:
            _require(receipt['ci']['environment'] == request['environment'], 'BINDING_MISMATCH')
        _require(receipt['preview'] == preview_ref, 'BINDING_MISMATCH')
        _require(_utc(receipt['issued_at']) <= _utc(now) < _utc(receipt['expires_at']), 'EXPIRED_RECEIPT')


def publish_artifact(root, relative, data, *, scan):
    """Publish exact validated bytes atomically, after a mandatory secret scan.

Scanner exceptions/falsy/non-boolean verdicts are rejected without echoing them.
No temporary/final file is written until validation and scanning succeed.
"""
    parse_artifact(data)
    try:
        safe = scan(data)
    except Exception:
        raise ContractError('SECRET_SCAN_FAILED') from None
    _require(safe is True, 'SECRET_SCAN_FAILED')
    with _parent(root, relative) as (parent, name):
        temporary = '.cloud-' + secrets.token_hex(16)
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.link(temporary, name, src_dir_fd=parent, dst_dir_fd=parent, follow_symlinks=False)
            os.fsync(parent)
        finally:
            os.unlink(temporary, dir_fd=parent)
    return {'path': relative, 'sha256': hashlib.sha256(data).hexdigest()}


def input_error(error_code, field):
    """Identity-free deterministic envelope: never echoes an invalid request."""
    value = {'schema': 'cloud-input-error/v1', 'error_code': error_code,
             'message': 'Invalid request. Correct the named field before retrying.', 'field': field}
    _input_error(value)
    return value


def exit_code(value):
    """Design's CLI exit mapping; wrappers serialize separately in later tasks."""
    if value.get('schema') == 'cloud-input-error/v1':
        _input_error(value)
        return 2
    _result(value)
    return EXIT_CODES[value['result']]
