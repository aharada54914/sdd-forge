#!/usr/bin/env python3
"""Verify A9 rollback authorization; optionally invoke the existing human publisher.

No signing, registry edits, approval generation, or policy inference from model text.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tempfile

SOURCE = Path(__file__).resolve().parents[1]
SCRIPTS = SOURCE / 'plugins/sdd-quality-loop/scripts'
TARGETS = ('sdd/project-context.yaml', 'sdd/project-context.approval.json',
           'sdd/.approved-context/project-context.approved.yaml')
BINDINGS = {'before_context', 'before_approval', 'candidate_context', 'candidate_approval',
            'candidate_snapshot', 'manifest', 'request_registry', 'current_registry'}
SHA = re.compile(r'[0-9a-f]{64}')


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), SCRIPTS / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


APPROVAL = load('validate-approval-sidecar')
PROOF = load('validate-live-host-proof')


class Refusal(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Refusal(message)


def keys(value, expected, label):
    require(isinstance(value, dict) and set(value) == set(expected), label + ' fields are invalid')


def utc(value):
    require(isinstance(value, str) and re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', value), 'invalid UTC timestamp')
    return datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)


def digest(data):
    return hashlib.sha256(data).hexdigest()


class Check:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.observed = {}

    def path(self, value):
        require(isinstance(value, str) and value and '\\' not in value and ':' not in value,
                'input path must be repository relative')
        parts = PurePosixPath(value).parts
        require(not value.startswith('/') and all(p not in ('', '.', '..') for p in value.split('/')),
                'input path must be canonical and relative')
        path = self.root
        for part in parts:
            path /= part
            info = path.lstat()
            require(not stat.S_ISLNK(info.st_mode) and not getattr(info, 'st_file_attributes', 0) & 0x400,
                    'symlink/reparse input is forbidden')
        require(path.is_file() and path.stat().st_nlink == 1, 'input must be a single regular file')
        return path

    def read(self, value):
        path = self.path(value)
        data = path.read_bytes()
        previous = self.observed.setdefault(value, digest(data))
        require(previous == digest(data), 'input changed during validation')
        return data

    def document(self, value):
        document = PROOF.CANON.parse_json_bytes(self.read(value))
        PROOF.CANON.normalize_and_validate(document)
        return document

    def bound(self, binding):
        keys(binding, {'path', 'sha256'}, 'file binding')
        require(isinstance(binding['sha256'], str) and SHA.fullmatch(binding['sha256']), 'invalid SHA-256 binding')
        data = self.read(binding['path'])
        require(digest(data) == binding['sha256'], 'bound input bytes differ')
        return data

    def unchanged(self, exclude=()):
        for path, expected in list(self.observed.items()):
            if path not in exclude:
                require(digest(self.path(path).read_bytes()) == expected, 'input changed during validation')


def verify_signature(record, registry, domain, primary):
    require(PROOF.nonempty_string(record['signer_key_id']) and PROOF.nonempty_string(record['signer']), 'signature identity/key is required')
    require(record['signer'] == primary, 'proof signer must be the HMAC-authorized primary approver')
    entry, public_key = PROOF.signer_for(registry, record['signer_key_id'], 'operator')
    require(entry['identity'] == record['signer'], 'proof signer does not match trusted key identity')
    signature = PROOF.strict_b64(record['signature'], 64, 'ERR_SIGNATURE_INVALID', 'rollback signature')
    unsigned = {k: v for k, v in record.items() if k != 'signature'}
    target = hashlib.sha256(PROOF.jcs(unsigned) + domain).digest()
    require(PROOF.verify_ed25519(public_key, signature, target), 'rollback signature is invalid')


def check_authorization(args, check, *, applied=False):
    record = check.document(args.receipt)
    keys(record, {'schema', 'requester', 'requested_at', 'application_at', 'application_result',
                  'approval_epoch', 'bindings', 'signer', 'signer_key_id', 'signature'}, 'rollback authorization')
    require(record['schema'] == 'a9-rollback-authorization/v1' and record['application_result'] == 'authorized',
            'not an A9 pre-application authorization')
    require(PROOF.nonempty_string(record['requester']), 'requester identity is required')
    keys(record['bindings'], BINDINGS, 'rollback input bindings')
    bindings = record['bindings']
    for binding in bindings.values():
        check.bound(binding)
    stage = PurePosixPath(args.staging_dir)
    expected_paths = dict(zip(('candidate_context', 'candidate_approval', 'candidate_snapshot'),
                              (str(stage / target) for target in TARGETS)))
    expected_paths.update(manifest=str(stage / 'MANIFEST.sha256'), current_registry='sdd/approver-registry.yaml')
    for name, path in expected_paths.items():
        require(bindings[name]['path'] == path, 'binding does not name the supplied staging/trust input')
    identities = [(check.path(b['path']).stat().st_dev, check.path(b['path']).stat().st_ino) for b in bindings.values()]
    require(len(set(identities)) == len(bindings), 'bound inputs must be distinct files')
    candidate = check.bound(bindings['candidate_context'])
    require(candidate == check.bound(bindings['candidate_snapshot']), 'approved snapshot differs from candidate Context')
    expected_manifest = ''.join(bindings[name]['sha256'] + '  ' + target + '\n'
                                for name, target in zip(('candidate_context', 'candidate_approval', 'candidate_snapshot'), TARGETS))
    require(check.bound(bindings['manifest']) == expected_manifest.encode(), 'manifest must bind exactly the three rollback targets in order')
    require(not any(check.path(bindings[name]['path']).samefile(check.path(target))
                    for name in ('before_context', 'before_approval') for target in TARGETS),
            'predecessor evidence must be preserved outside publication targets')
    current_live = check.read(TARGETS[0])
    current_context = check.read(TARGETS[2])
    current_approval = check.read(TARGETS[1])
    require(current_live == current_context, 'live Context differs from the approved anchor')
    if applied:
        require(current_context == candidate and current_approval == check.bound(bindings['candidate_approval']),
                'live approved state does not match applied candidate')
    else:
        require(current_context == check.bound(bindings['before_context']) and
                current_approval == check.bound(bindings['before_approval']), 'current approved anchor differs from authorized predecessor')
    paths = {name: check.path(binding['path']) for name, binding in bindings.items()}
    request_ids = APPROVAL._validate_registry(paths['request_registry'])
    current_ids = APPROVAL._validate_registry(paths['current_registry'])
    require(request_ids and current_ids, 'zero-identity registry rejects rollback')
    before = APPROVAL._load_sidecar(paths['before_approval'])
    after = APPROVAL._load_sidecar(paths['candidate_approval'])
    APPROVAL._validate_sidecar_schema(before, paths['before_approval'])
    APPROVAL._validate_sidecar_schema(after, paths['candidate_approval'])
    require(before['schema'] == after['schema'] == 'sdd-project-context-approval/v1', 'only Context approval sidecars are accepted')
    APPROVAL.run_verify_provenance(paths['before_approval'])
    APPROVAL._validate_content(paths['before_context'], APPROVAL.CONTENT_SCHEMA_INFO[before['schema']])
    APPROVAL._check_hash_match(paths['before_context'], before)
    APPROVAL.run_standard_validation(paths['candidate_context'], paths['candidate_approval'], paths['current_registry'])
    require(after['predecessor_context_sha256'] == before['context_sha256'], 'candidate approval has a different predecessor')
    require(type(record['approval_epoch']) is int and record['approval_epoch'] == after['approval_epoch'] == before['approval_epoch'] + 1,
            'rollback approval epoch is not the current successor')
    old = APPROVAL._canonicalize_file_to_json(paths['before_context'], 'CONTENT_CANONICALIZATION_FAILED')
    new = APPROVAL._canonicalize_file_to_json(paths['candidate_context'], 'CONTENT_CANONICALIZATION_FAILED')
    require(old['workflow']['capability_enforcement'] == 'required' and new['workflow']['capability_enforcement'] == 'advisory',
            'rollback must change required enforcement to advisory')
    old['workflow']['capability_enforcement'] = 'advisory'
    require(old == new, 'rollback includes changes beyond enforcement')
    primary = after['primary_approval']['approver']
    require(primary in request_ids, 'primary approver was absent from request-time registry')
    first = utc(after['primary_approval']['approved_at'])
    requested = utc(record['requested_at'])
    application = utc(record['application_at'])
    now = datetime.now(timezone.utc)
    require(requested <= first <= application <= now, 'request/approval/application time ordering is invalid')
    verdict = after['weakening_verdict']
    require(isinstance(verdict, dict) and verdict['policy_weakening'] is True and
            verdict['categories']['capability_enforcement_weakened'] == 'weakened', 'HMAC sidecar does not authorize enforcement weakening')
    if len(current_ids) == 1:
        require(after['second_approval'] is None and record['requester'] != primary, 'sole self-approval is forbidden')
        require(verdict['two_person_required'] is False and verdict['cooldown_hours'] == 24,
                'solo approval must authorize the 24-hour branch')
        effective = utc(after['effective_at'])
        require(effective == first + timedelta(hours=24) and application >= effective, 'solo 24-hour boundary is not satisfied')
        branch = 'solo-cooldown'
    else:
        require(after['second_approval'] is not None and verdict['two_person_required'] is True and verdict['cooldown_hours'] is None,
                'current registry requires two distinct approvals')
        require(requested <= utc(after['second_approval']['approved_at']) <= application, 'second approval time is outside the authorized request')
        if after['effective_at'] is not None:
            require(application >= utc(after['effective_at']), 'application predates signed effective time')
        branch = 'two-party'
    registry = check.document(args.trusted_signers)
    PROOF.validate_registry(registry)
    verify_signature(record, registry, b':a9-rollback-authorized', primary)
    return record, registry, branch


def post_state(check, record):
    bindings = record['bindings']
    hashes = {}
    for name, target in zip(('candidate_context', 'candidate_approval', 'candidate_snapshot'), TARGETS):
        data = check.path(target).read_bytes()
        require(data == check.bound(bindings[name]), 'published rollback bytes differ from authorized candidate')
        hashes[target] = digest(data)
    return hashes


def verify_applied(args, check, record, registry):
    attestation = check.document(args.applied_attestation)
    keys(attestation, {'schema', 'authorization', 'publisher_result', 'applied_at', 'signer', 'signer_key_id', 'signature'}, 'applied attestation')
    require(attestation['schema'] == 'a9-rollback-applied/v1', 'invalid applied-attestation schema')
    check.bound(attestation['authorization'])
    require(attestation['authorization']['path'] == args.receipt, 'attestation references another authorization')
    raw = check.bound(attestation['publisher_result'])
    result = PROOF.CANON.parse_json_bytes(raw)
    keys(result, {'schema', 'result', 'authorization_sha256', 'applied_at', 'publisher', 'post_hashes'}, 'publisher result')
    require(result['schema'] == 'a9-rollback-application-result/v1' and result['result'] == 'APPLIED', 'publisher did not report application success')
    require(result['authorization_sha256'] == digest(check.read(args.receipt)), 'publisher result is bound to another authorization')
    require(result['applied_at'] == attestation['applied_at'] and
            utc(record['application_at']) <= utc(result['applied_at']) <= datetime.now(timezone.utc), 'applied timestamp is inconsistent')
    publisher = result['publisher']
    require(isinstance(publisher, dict) and publisher.get('status') == 'ok' and publisher.get('targets') == list(TARGETS),
            'transactional publisher targets/status differ')
    require(result['post_hashes'] == post_state(check, record), 'attested post-publication hashes differ')
    verify_signature(attestation, registry, b':a9-rollback-applied', record['signer'])
    return {'schema': 'a9-rollback-validation/v1', 'result': 'APPLIED_VERIFIED', 'authorization_checked': True,
            'signed_application_checked': True, 'current_registry_sha256': record['bindings']['current_registry']['sha256']}


def run(args):
    # Existing publisher consistency checks are relative to the project root.
    root = Path(args.root).resolve()
    previous = Path.cwd()
    try:
        os.chdir(root)
        return run_at_root(args, Check(root))
    finally:
        os.chdir(previous)


def run_at_root(args, check):
    APPROVAL._check_no_publish_in_progress(*TARGETS)
    record, registry, branch = check_authorization(args, check, applied=bool(args.applied_attestation))
    if args.applied_attestation:
        result = verify_applied(args, check, record, registry)
        check.unchanged()
        return result
    check.unchanged()
    if not args.apply:
        return {'schema': 'a9-rollback-validation/v1', 'result': 'ADMISSIBLE', 'branch': branch,
                'authorization_checked': True, 'applied': False,
                'current_registry_sha256': record['bindings']['current_registry']['sha256']}
    publisher = SCRIPTS / ('apply-human-copy.ps1' if args.publisher_runtime == 'ps1' else 'apply-human-copy.sh')
    # Publish a private byte-for-byte snapshot of the authenticated inputs. The
    # original staged manifest cannot be replaced after admission to expand the
    # publisher's targets. Its existing hash checks and transaction recovery stay
    # responsible for the actual copy; this is not an OS boundary against the owner.
    with tempfile.TemporaryDirectory(prefix='a9-authorized-') as directory:
        staged = Path(directory)
        for name, target in zip(('candidate_context', 'candidate_approval', 'candidate_snapshot'), TARGETS):
            destination = staged / target
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(check.bound(record['bindings'][name]))
        manifest = staged / 'MANIFEST.sha256'
        manifest.write_bytes(check.bound(record['bindings']['manifest']))
        check.unchanged()
        command = (['pwsh', '-NoProfile', '-File', str(publisher), '-StagingDir', str(staged),
                    '-Manifest', str(manifest)] if args.publisher_runtime == 'ps1' else
                   ['bash', str(publisher), '--staging-dir', str(staged), '--manifest', str(manifest)])
        completed = subprocess.run(command, cwd=check.root, capture_output=True, text=True)
    require(completed.returncode == 0, 'transactional publisher refused; use its existing recovery procedure')
    published = PROOF.CANON.parse_json_bytes(completed.stdout.encode())
    require(published.get('status') == 'ok' and published.get('targets') == list(TARGETS), 'publisher success/target receipt is invalid')
    hashes = post_state(check, record)
    check.unchanged(exclude=TARGETS)
    return {'schema': 'a9-rollback-application-result/v1', 'result': 'APPLIED',
            'authorization_sha256': digest(check.read(args.receipt)),
            'applied_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'publisher': published, 'post_hashes': hashes}


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=Path.cwd())
    p.add_argument('--receipt', required=True)
    p.add_argument('--staging-dir', required=True)
    p.add_argument('--trusted-signers', default='plugins/sdd-review-loop/references/a8-trusted-signers.json')
    mode = p.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--applied-attestation')
    p.add_argument('--publisher-runtime', choices=('sh', 'ps1'), default='ps1' if os.name == 'nt' else 'sh')
    return p


def main(argv=None):
    try:
        result = run(parser().parse_args(argv))
        print(json.dumps(result, sort_keys=True))
        return 0
    except (Refusal, OSError, ValueError, APPROVAL.ValidateApprovalSidecarError, PROOF.ValidationError,
            PROOF.CANON.CanonicalizeError) as error:
        # Never expose input paths, identities, HMACs or document bytes in public diagnostics.
        code = getattr(error, 'category', getattr(error, 'code', 'ROLLBACK_REFUSED'))
        print(json.dumps({'schema': 'a9-rollback-validation/v1', 'result': 'BLOCKED', 'category': code,
                          'reason': str(error) if isinstance(error, Refusal) else 'input validation failed'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
