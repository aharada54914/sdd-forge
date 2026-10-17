#!/usr/bin/env python3
"""Record the requested Copilot selection separately from native model events."""
import argparse
import json
import hashlib
import stat
from pathlib import Path
import re
import importlib.util
import subprocess
import sys
import contextlib
import io

ROOT = Path(__file__).resolve().parents[2]


def artifact(kind, path, base):
    if path.is_symlink() or not path.is_file():
        raise ValueError('proof artifact must be a regular file')
    return {'kind': kind, 'ref': path.relative_to(base).as_posix(),
            'sha256': 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest()}


def proof_validator(repo):
    validator = repo / 'plugins/sdd-quality-loop/scripts/validate-live-host-proof.py'
    spec = importlib.util.spec_from_file_location('handoff_live_proof', validator)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def current_proof_inputs(repo, records):
    """Keep proof collection roots separate from the current trusted policy."""
    validator = repo / 'plugins/sdd-quality-loop/scripts/validate-live-host-proof.py'
    module = proof_validator(repo)
    inputs = [artifact('validator', validator, repo),
              artifact('handshake_verifier', validator.with_name('check-hook-activation-handshake.py'), repo)]
    for relative in module.CONSUMERS.values():
        current = artifact('consumer', repo / relative, repo)
        captured = artifact('consumer', records.parent.parent / relative, records.parent.parent)
        if current['sha256'] != captured['sha256']:
            raise ValueError('proof consumer differs from the current checkout')
        inputs.append(current)
    references = repo / 'plugins/sdd-review-loop/references'
    for kind, name in (('trusted_signers', 'a8-trusted-signers.json'),
                       ('expected_manifest', 'a8-expected-hook-config-digests.json'),
                       ('skip_allowlist', 'a8-skip-allowlist.json')):
        inputs.append(artifact(kind, references / name, repo))
    inputs.extend(artifact('record', records / name, records) for name in module.FILENAMES.values())
    return inputs


def read_only_proof(repo, records):
    """Revalidate a completed receipt without writing or resetting nonce state."""
    repo, records = Path(repo).resolve(), Path(records).resolve()
    inputs = current_proof_inputs(repo, records)
    ledger_path = records / 'nonce-ledger.json'
    before = artifact('nonce_ledger', ledger_path, records)
    module = proof_validator(repo)
    args = module.parser().parse_args(['--records-dir', str(records), '--nonce-ledger', str(ledger_path)])
    stdout = io.StringIO()
    with contextlib.redirect_stdout(stdout):
        module.run(args, consume=False)
    if stdout.getvalue() != 'discharged\n':
        raise ValueError('signed live-host proof did not discharge')
    ledger = module.load_json(ledger_path, 'consumed nonce ledger')
    consumed = {entry['nonce']: entry['consumed_by_record'] for entry in ledger['entries']}
    for filename in module.FILENAMES.values():
        record = module.load_json(records / filename, 'completed record')
        nonces = {record['nonce']} | {entry['nonce'] for entry in record['consumer_executions']}
        expected = 'tests/hook-activation-live-proof/' + filename
        if any(consumed[nonce] != expected for nonce in nonces):
            raise ValueError('proof nonce has no matching completed consumption receipt')
    if current_proof_inputs(repo, records) != inputs or artifact('nonce_ledger', ledger_path, records) != before:
        raise ValueError('proof inputs changed during read-only validation')
    return {'schema': 'cross-runtime-live-proof/v1', 'aggregate': 'discharged',
            'records_dir': str(records), 'artifacts': inputs + [before]}


def validate_live_proof(records, evidence):
    records = records.resolve()
    inputs = current_proof_inputs(ROOT, records)
    ledger = records / 'nonce-ledger.json'
    artifact('nonce_ledger', ledger, records)
    validator = ROOT / 'plugins/sdd-quality-loop/scripts/validate-live-host-proof.py'
    completed = subprocess.run([sys.executable, str(validator), '--records-dir', str(records),
                                '--nonce-ledger', str(ledger)], capture_output=True)
    stdout = evidence / 'live-host-proof.stdout.log'
    stdout.write_bytes(completed.stdout)
    (evidence / 'live-host-proof.stderr.log').write_bytes(completed.stderr)
    if completed.returncode != 0 or completed.stdout not in {b'discharged\n', b'discharged\r\n'}:
        raise ValueError('signed live-host proof did not discharge')
    if current_proof_inputs(ROOT, records) != inputs:
        raise ValueError('proof inputs changed during validation')
    # Same-record revalidation is idempotent; preserve the consumed ledger,
    # never reset its nonce entries for downstream promotion verification.
    inputs.append(artifact('nonce_ledger', ledger, records))
    return {'schema': 'cross-runtime-live-proof/v1', 'aggregate': 'discharged',
            'records_dir': str(records), 'artifacts': inputs,
            'stdout': artifact('validator_stdout', stdout, evidence)}


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
    proof = commands.add_parser('proof')
    proof.add_argument('records', type=Path)
    proof.add_argument('evidence', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'proof':
            print(json.dumps(validate_live_proof(args.records, args.evidence), sort_keys=True))
            return
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
    except (OSError, ValueError) as exc:
        parser.exit(1, 'Handoff evidence is missing, invalid, or inconsistent (' + type(exc).__name__ + ')\n')
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()
