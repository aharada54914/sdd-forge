"""Operator nonce issuance: disposable fixture keys, never real identities."""
import base64
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from unittest import mock


def cases(root, keys):
    script = root / 'plugins/sdd-quality-loop/scripts/issue-live-host-nonce.py'
    emitter = Path(__file__).with_name('archived_challenge_emitter.py')
    retired = [script.with_name(f'check-hook-activation-handshake.{ext}') for ext in ('py', 'sh', 'ps1')]
    distributed = [path.name for path in retired if os.path.lexists(path)]
    results = [('issuer-retired-emitter-not-distributed', not distributed, ', '.join(distributed))]
    # Bind the pre-retirement emitter used as historical input, including in a shallow checkout.
    digest = hashlib.sha256(emitter.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
    matches_archive = digest == 'd4ce4de60bbb8d0e369afbb804727858dc48d9dde9b844cf930f9500cb0462b1'
    results.append(('issuer-archived-emitter-integrity', matches_archive, digest))
    if not matches_archive:
        return results
    with tempfile.TemporaryDirectory() as temporary:
        base = Path(temporary).resolve()
        seed, public = keys['issuer-key']
        key = base / 'disposable-fixture-key.der'
        key.write_bytes(bytes.fromhex('302e020100300506032b657004220420') + seed)
        registry = base / 'registry.json'
        registry.write_text(json.dumps({'schema': 'a8-trusted-signers/v1', 'signers': {
            'issuer-key': {'identity': 'fixture-issuer', 'role': 'issuer',
                           'public_key': base64.b64encode(public).decode(), 'added_at': '2026-01-01T00:00:00Z'}}}))
        ledger = base / 'ledger.json'
        ledger.write_text(json.dumps({'schema': 'live-host-nonce-ledger/v1', 'entries': []}))
        challenge = base / 'challenge.json'
        emitted = subprocess.run(
            [sys.executable, str(emitter), '--emit-challenge'],
            cwd=base, capture_output=True, text=True, check=True,
        )
        emit_finished = dt.datetime.now(dt.timezone.utc)
        challenge_nonce = json.loads(emitted.stdout)['nonce']
        challenge.write_text(emitted.stdout)
        common = [sys.executable, str(script), '--challenge', str(challenge), '--matrix-cell', 'Claude-active', '--nonce-ledger', str(ledger), '--trusted-signers', str(registry)]
        issue = common + ['--issue', '--issuer-key-id', 'issuer-key', '--private-key', str(key)]
        def check(name, command, expected, preserved=False):
            before = ledger.read_bytes()
            process = subprocess.run(command, capture_output=True, text=True)
            ok = (process.returncode == 0) == expected
            if preserved:
                ok = ok and ledger.read_bytes() == before
            results.append((name, ok, process.stderr.strip()))
            return process
        issuance = check('issuer-real-openssl-signature', issue, True)
        verification = check('issuer-public-receipt-verification', common + ['--verify-receipt'], True, True)
        check('issuer-duplicate-rejected', issue, False, True)
        spec = importlib.util.spec_from_file_location('issuer_under_test', script)
        if not script.exists():
            return results
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        entry = json.loads(ledger.read_text())['entries'][0]
        for name, record in (
            ('issued-receipt', json.loads(issuance.stdout)),
            ('verified-receipt', json.loads(verification.stdout)),
            ('ledger-entry', entry),
        ):
            results.append(('issuer-challenge-matches-' + name, record.get('nonce') == challenge_nonce,
                            'expected the nonce emitted by the archived host'))
        module.proof.validate_ledger(json.loads(ledger.read_text()), json.loads(registry.read_text()))
        results.append(('issuer-consumption-validator-compatible', True, ''))
        issued = module.proof.parse_utc(entry['issued_at'], 'issued_at')
        results.append(('issuer-real-emit-before-actual-issuance', emit_finished <= issued <= dt.datetime.now(dt.timezone.utc), ''))
        original_issued = ledger.read_bytes()
        issued_ledger = json.loads(original_issued)
        record_ref = 'tests/hook-activation-live-proof/claude-active.json'
        module.proof.publish_consumption(ledger, issued_ledger, [(issued_ledger['entries'][0], record_ref)], original_issued)
        results.append(('issuer-aggregate-consumes-produced-entry', json.loads(ledger.read_text())['entries'][0]['consumed_by_record'] == record_ref, ''))
        check('issuer-reissue-after-aggregate-consumption-rejected', issue, False, True)
        ledger.write_bytes(original_issued)
        check('issuer-wrong-cell-rejected', [part if part != 'Claude-active' else 'Copilot-primary-active' for part in common] + ['--verify-receipt'], False, True)
        for mode in ('directory', 'file'):
            lock = Path(str(ledger) + '.lock')
            lock.mkdir() if mode == 'directory' else lock.write_text('owner')
            check('issuer-existing-' + mode + '-lock-preserved', issue, False, True)
            results.append(('issuer-lock-owner-retained-' + mode, lock.exists(), ''))
            lock.rmdir() if mode == 'directory' else lock.unlink()
        original = ledger.read_bytes()
        for name, mutation in (
            ('consumed', lambda e: e.update(consumed_by_record='tests/hook-activation-live-proof/claude-active.json')),
            ('signature-tamper', lambda e: e.update(issuer_signature=base64.b64encode(b'x' * 64).decode())),
        ):
            value = json.loads(original)
            mutation(value['entries'][0])
            ledger.write_text(json.dumps(value))
            check('issuer-receipt-' + name + '-rejected', common + ['--verify-receipt'], False, True)
        ledger.write_bytes(original)
        changed = json.loads(challenge.read_text())
        changed['nonce'] = ('1' if challenge_nonce[0] == '0' else '0') + challenge_nonce[1:]
        challenge.write_text(json.dumps(changed))
        check('issuer-receipt-other-challenge-rejected', common + ['--verify-receipt'], False, True)
        check('issuer-unknown-key-rejected', [part if part != 'issuer-key' else 'missing' for part in issue], False, True)
        other = base / 'wrong-fixture-key.der'
        other.write_bytes(bytes.fromhex('302e020100300506032b657004220420') + keys['operator-key'][0])
        check('issuer-key-mismatch-rejected', [str(other) if part == str(key) else part for part in issue], False, True)
        check('issuer-no-backdating-option', issue + ['--issued-at', entry['issued_at']], False, True)
        check('issuer-receipt-rejects-private-key', common + ['--verify-receipt', '--private-key', str(key)], False, True)
        args = SimpleNamespace(nonce_ledger=ledger, private_key=key,
                               issuer_key_id='issuer-key', matrix_cell='Claude-active')
        real_load = module.proof.load_json
        def swapped_second_read(path, label):
            if Path(path) != ledger:
                return real_load(path, label)
            ledger.write_text(json.dumps({'schema': 'live-host-nonce-ledger/v1', 'entries': []}))
            swapped = real_load(path, label)
            ledger.write_bytes(original)
            return swapped
        with mock.patch.object(module.proof, 'load_json', side_effect=swapped_second_read):
            module.issue(args, json.loads(registry.read_text()), 'c' * 32)
        nonces = [item['nonce'] for item in json.loads(ledger.read_bytes())['entries']]
        results.append(('issuer-append-uses-one-snapshot', nonces == [entry['nonce'], 'c' * 32], ''))
        ledger.write_bytes(original)
        for name, target in (('sign-failure', 'sign_entry'), ('replace-failure', 'os.replace'),
                             ('fsync-failure', 'os.fsync')):
            before = ledger.read_bytes()
            rejected = False
            owner, attribute = (module.os, target.split('.')[1]) if '.' in target else (module, target)
            with mock.patch.object(owner, attribute, side_effect=OSError()):
                try:
                    module.issue(args, json.loads(registry.read_text()), 'b' * 32)
                except OSError:
                    rejected = True
            results.append(('issuer-' + name + '-atomic', rejected and ledger.read_bytes() == before
                            and not Path(str(ledger) + '.lock').exists()
                            and not list(base.glob('ledger.json.*')), ''))
        for name, instant in (
            ('expired', module.proof.parse_utc(entry['issued_at'], 'issued_at') + dt.timedelta(hours=24)),
            ('future', module.proof.parse_utc(entry['issued_at'], 'issued_at') - dt.timedelta(seconds=1)),
        ):
            with mock.patch.object(module, 'current_time', return_value=instant):
                try:
                    module.verify_receipt(json.loads(original), json.loads(registry.read_text()), entry['nonce'], 'Claude-active')
                    ok = False
                except ValueError:
                    ok = True
            results.append(('issuer-' + name + '-receipt-rejected', ok, ''))
        original_challenge = challenge.read_bytes()
        challenge.write_text('{"schema":"sdd-hook-challenge/v1","nonce":"' + 'a' * 32
                             + '","nonce":"' + 'b' * 32 + '","canary_target":"sdd/.hook-canary-sentinel"}')
        check('issuer-duplicate-json-rejected', issue, False, True)
        challenge.write_bytes(original_challenge)
        for kind in ('symbolic', 'hard'):
            link = base / (kind + '-ledger.json')
            try:
                link.symlink_to(ledger) if kind == 'symbolic' else __import__('os').link(ledger, link)
            except OSError:
                continue  # Windows hosts without symlink privilege still cover hardlinks.
            check('issuer-' + kind + '-ledger-rejected', [str(link) if part == str(ledger) else part for part in issue], False, True)
            link.unlink()
    return results
