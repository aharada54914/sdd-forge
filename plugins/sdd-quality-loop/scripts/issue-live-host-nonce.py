#!/usr/bin/env python3
"""Operator-owned issuance for an actual, paused caller's handshake challenge.

Private keys stay on the operator machine. Receipt verification needs only
the challenge, public registry, and signed ledger. This CLI never creates keys.
"""
import argparse
import base64
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile


spec = importlib.util.spec_from_file_location(
    'live_host_proof', Path(__file__).with_name('validate-live-host-proof.py'))
if spec is None or spec.loader is None:
    raise RuntimeError('live-host proof validator is unavailable')
proof = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proof)


def regular_file(path):
    path = path.absolute()
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current /= part
        info = current.lstat()
        if stat.S_ISLNK(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
            raise ValueError('input paths must not traverse links or reparse points')
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError('input must be a regular file with one link')
    return path


def challenge_nonce(path):
    challenge = proof.load_json(regular_file(path), 'challenge')
    if (not isinstance(challenge, dict) or challenge.get('schema') != 'sdd-hook-challenge/v1'
            or challenge.get('canary_target') != 'sdd/.hook-canary-sentinel'
            or not isinstance(challenge.get('nonce'), str)
            or not proof.NONCE_RE.fullmatch(challenge['nonce'])):
        raise ValueError('use the unmodified native caller challenge')
    return challenge['nonce']


def current_time():
    return dt.datetime.now(dt.timezone.utc)


def sign_entry(entry, private_key, public_key):
    target = hashlib.sha256(proof.jcs(entry) + b':nonce-issuer').digest()
    # Ed25519 needs a sized input file on OpenSSL versions that reject pipes.
    with tempfile.TemporaryDirectory(prefix='sdd-nonce-sign-') as directory:
        message = Path(directory) / 'target.bin'
        message.write_bytes(target)
        signed = subprocess.run(
            ['openssl', 'pkeyutl', '-sign', '-rawin', '-inkey', str(private_key), '-in', str(message)],
            capture_output=True, timeout=60, check=False)
    if signed.returncode or not proof.verify_ed25519(public_key, signed.stdout, target):
        raise ValueError('issuer signing failed or key does not match the registered public key')
    return base64.b64encode(signed.stdout).decode('ascii')


def verify_receipt(ledger, registry, nonce, cell):
    entry = proof.validate_ledger(ledger, registry).get(nonce)
    if entry is None or entry['matrix_cell'] != cell or entry['consumed_by_record'] is not None:
        raise ValueError('nonce must be issued for this cell and remain unconsumed')
    issued = proof.parse_utc(entry['issued_at'], 'issued_at')
    if not dt.timedelta(0) <= current_time() - issued < dt.timedelta(hours=24):
        raise ValueError('issuance is in the future or its 24-hour dispatch window has expired')
    return {'schema': 'live-host-nonce-receipt/v1', 'nonce': nonce, 'matrix_cell': cell,
            'issued_at': entry['issued_at'],
            'expires_at': (issued + dt.timedelta(hours=24)).isoformat().replace('+00:00', 'Z'),
            'issuer_key_id': entry['issuer_key_id'], 'issuer_signature': entry['issuer_signature']}


def issue(args, registry, nonce):
    ledger_path = regular_file(args.nonce_ledger)
    private_key = regular_file(args.private_key)
    _, public_key = proof.signer_for(registry, args.issuer_key_id, 'issuer')
    lock = Path(str(ledger_path) + '.lock')
    try:
        lock.mkdir()
    except FileExistsError:
        raise ValueError('nonce ledger lock is already held') from None
    scratch = None
    try:
        original = ledger_path.read_bytes()
        try:
            ledger = proof.CANON.normalize_and_validate(proof.CANON.parse_json_bytes(original))
        except (ValueError, proof.CANON.CanonicalizeError):
            raise ValueError('nonce ledger is not strict JSON') from None
        if nonce in proof.validate_ledger(ledger, registry):
            raise ValueError('nonce has already been issued; start a fresh caller challenge')
        entry = {'nonce': nonce, 'matrix_cell': args.matrix_cell,
                 'issued_at': current_time().isoformat().replace('+00:00', 'Z'),
                 'issuer': 'check-hook-activation-handshake', 'issuer_key_id': args.issuer_key_id}
        entry['issuer_signature'] = sign_entry(entry, private_key, public_key)
        entry['consumed_by_record'] = None
        ledger['entries'].append(entry)
        receipt = verify_receipt(ledger, registry, nonce, args.matrix_cell)
        # Share the aggregate validator's lock; reject external replacement too.
        regular_file(ledger_path)
        if ledger_path.read_bytes() != original:
            raise ValueError('nonce ledger changed while issuance was in progress')
        descriptor, scratch = tempfile.mkstemp(prefix=ledger_path.name + '.', dir=ledger_path.parent)
        with os.fdopen(descriptor, 'wb') as output:
            output.write((json.dumps(ledger, indent=2, sort_keys=True) + '\n').encode())
            output.flush()
            os.fsync(output.fileno())
        os.chmod(scratch, stat.S_IMODE(ledger_path.stat().st_mode))
        os.replace(scratch, ledger_path)
        scratch = None
        # Match the aggregate's durability step where directory fsync is supported.
        try:
            directory = os.open(ledger_path.parent, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
        except OSError:
            pass
        return receipt
    finally:
        if scratch is not None:
            os.unlink(scratch)
        lock.rmdir()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--issue', action='store_true')
    mode.add_argument('--verify-receipt', action='store_true')
    parser.add_argument('--challenge', type=Path, required=True)
    parser.add_argument('--matrix-cell', choices=proof.CELLS, required=True)
    parser.add_argument('--nonce-ledger', type=Path, required=True)
    parser.add_argument('--trusted-signers', type=Path, required=True)
    parser.add_argument('--issuer-key-id')
    parser.add_argument('--private-key', type=Path)
    args = parser.parse_args(argv)
    if args.issue and (not args.issuer_key_id or args.private_key is None):
        parser.error('--issue requires --issuer-key-id and --private-key on the operator machine')
    if args.verify_receipt and (args.issuer_key_id is not None or args.private_key is not None):
        parser.error('--verify-receipt never accepts a private key or signing options')
    try:
        nonce = challenge_nonce(args.challenge)
        registry = proof.load_json(regular_file(args.trusted_signers), 'trusted-signer registry')
        proof.validate_registry(registry)
        result = issue(args, registry, nonce) if args.issue else verify_receipt(
            proof.load_json(regular_file(args.nonce_ledger), 'nonce ledger'), registry, nonce, args.matrix_cell)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (OSError, ValueError, subprocess.SubprocessError, proof.ValidationError) as exc:
        # Do not forward OpenSSL diagnostics, key paths, or input values.
        detail = str(exc) if isinstance(exc, ValueError) else getattr(exc, 'code', type(exc).__name__)
        print('NONCE_ISSUANCE_BLOCKED: ' + detail, file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
