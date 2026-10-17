#!/usr/bin/env python3
"""Exercise the live driver with isolated executable doubles, never native hosts."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import importlib.util
import shutil

ROOT = Path(__file__).resolve().parents[1]
STUB = r'''import json, os, pathlib, re, subprocess, sys
args=sys.argv[1:]; host=os.environ.get('SDD_STUB_HOST') or pathlib.Path(sys.argv[0]).stem
work=pathlib.Path(args[args.index('--cd')+1] if '--cd' in args else args[args.index('-C')+1] if '-C' in args else '.')
base=work/'tests/fixtures/cross-runtime-handoff'; one=base/'handoff-01-claude-to-codex.yaml'; two=base/'handoff-02-codex-to-copilot.md'
prompt=args[args.index('-p')+1] if '-p' in args else args[-1]
mode=os.environ['SDD_STUB_MODE']
if host=='claude':
 nonce=re.search(r'with ([0-9a-f]{32}),',prompt)[1]; one.write_bytes(one.read_bytes().replace(b'<PLACEHOLDER>',nonce.encode())); print('edited')
elif host=='codex':
 nonce1=re.search(rb'token: "([0-9a-f]{32})"',one.read_bytes())[1].decode()
 if 'CODEX-PRODUCED:' in prompt:
  assert nonce1 in prompt
  nonce=re.search(r'CODEX-PRODUCED:([0-9a-f]{32})',prompt)[1]; two.write_bytes(two.read_bytes().replace(b'PLACEHOLDER',nonce.encode())); print('CODEX-PRODUCED:'+nonce)
 else:
  assert nonce1 not in prompt
  print('HANDOFF-01:'+('0'*32 if mode=='wrong-first-consumer' else nonce1))
else:
 assert '--available-tools=view,apply_patch' in args and '--no-ask-user' in args
 output=base/'handoff-02-output.txt'; assert '--allow-tool=write('+str(output)+')' in args
 assert not any(a.startswith('--allow-all') or a.startswith('--allow-tool=shell') for a in args)
 nonce=re.search(rb'<!-- nonce: ([0-9a-f]{32}) -->',two.read_bytes())[1].decode()
 assert nonce not in prompt, 'consumer prompt leaked the nonce oracle'
 value=('COPILOT-CONSUMED:'+('0'*32 if mode=='wrong-nonce' else nonce)+'\n').encode()
 if mode=='no-lf': value=value[:-1]
 if mode=='extra-lf': value+=b'\n'
 if mode=='crlf': value=value[:-1]+b'\r\n'
 if mode=='bom': value=b'\xef\xbb\xbf'+value
 if mode!='missing-output': output.write_bytes(value)
 if mode=='mutate-input': one.write_bytes(b'changed\n')
 if mode=='removed-input': one.unlink()
 if mode=='extra-file': (work/'unexpected.txt').write_bytes(b'extra')
 if mode=='extra-dir': (work/'unexpected-dir').mkdir()
 if mode=='symlink-dir':
  target=work.parent/'link-target'; target.mkdir()
  if os.name=='nt': subprocess.run(['cmd','/c','mklink','/J',str(work/'alias'),str(target)],check=True,capture_output=True)
  else: (work/'alias').symlink_to(target,target_is_directory=True)
 model=args[args.index('--model')+1]
 if mode!='missing-model':
  actual='gpt-6-luna' if model=='auto' else model
  if mode=='wrong-model': actual='different-model'
  if mode=='auto-observation': actual='auto'
  if mode=='duplicate-model': print('{"type":"model.call_final_result","data":{"model":"gpt-6-luna","model":"other"}}')
  elif mode=='malformed-model': print('not native JSON')
  elif mode=='routing-only': print(json.dumps({'type':'session.auto_mode_resolved','data':{'chosenModel':actual}}))
  else: print(json.dumps({'type':'model.call_final_result','data':{'model':actual}}))
'''


def run(runtime):
    with tempfile.TemporaryDirectory(prefix='sdd-handoff-driver-') as raw:
        temp = Path(raw).resolve()
        bindir = temp / 'bin'
        bindir.mkdir()
        for host in ('claude', 'codex', 'copilot'):
            executable = bindir / host
            executable.write_text('#!' + sys.executable + '\n' + STUB, encoding='utf-8')
            executable.chmod(0o755)
            if os.name == 'nt':
                source = bindir / (host + '.py')
                source.write_text(STUB, encoding='utf-8')
                (bindir / (host + '.cmd')).write_text('@echo off\nset SDD_STUB_HOST=' + host + '\n"' + sys.executable + '" "' + str(source) + '" %*\nexit /b %errorlevel%\n')
        tasks = temp / 'tasks.md'
        # This test covers the handoff only; production AC-006 aggregation is separate.
        tasks.write_text('## T-005 fixture\nStatus: Planned\n', encoding='utf-8')
        cases = [('auto', 'good', True), ('Auto', 'good', True), ('claude-sonnet-4.6', 'good', True)]
        cases += [('auto', mode, False) for mode in ('missing-output', 'no-lf', 'extra-lf', 'crlf', 'bom', 'wrong-nonce', 'wrong-first-consumer', 'missing-model', 'mutate-input', 'removed-input', 'extra-file', 'extra-dir', 'symlink-dir', 'auto-observation', 'duplicate-model', 'malformed-model', 'routing-only')]
        cases += [('claude-sonnet-4.6', 'wrong-model', False), ('', 'good', False), ('auto;echo', 'good', False)]
        for index, (model, mode, success) in enumerate(cases):
            trace = temp / ('trace-' + str(index) + '.json')
            env = {**os.environ, 'PATH': str(bindir) + os.pathsep + os.environ['PATH'],
                   'SDD_A8_CODEX_BIN': str(bindir / ('codex.cmd' if os.name == 'nt' else 'codex')),
                   'SDD_A8_ALLOW_LIVE_CLI': '1', 'SDD_A8_COPILOT_MODEL': model,
                   'SDD_CROSS_RUNTIME_TASKS_PATH': str(tasks), 'SDD_STUB_MODE': mode,
                   'TMPDIR': str(temp), 'TEMP': str(temp)}
            if runtime == 'bash':
                command = ['bash', str(ROOT / 'tests/cross-runtime-handoff.tests.sh'), '--live-e2e', '--trace-file', str(trace)]
            else:
                command = [runtime, '-NoProfile', '-File', str(ROOT / 'tests/cross-runtime-handoff.tests.ps1'), '-LiveE2E', '-TraceFile', str(trace)]
            result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=45)
            assert (result.returncode == 0) == success, (runtime, model, mode, result.stdout, result.stderr)
            if success:
                data = json.loads(trace.read_text(encoding='utf-8-sig'))
                assert data['copilot_model']['requested'] == model
                assert data['copilot_model']['observed_models'] == (['gpt-6-luna'] if model.lower() == 'auto' else [model])
                assert data['copilot_model']['selection'] == ('auto' if model.lower() == 'auto' else 'explicit')
                assert data['steps'][0]['mutation_nonce'] != data['steps'][1]['mutation_nonce']
            else:
                assert not trace.exists(), 'failed handoff published a success trace'
            print('ok:', runtime, model or '<missing>', mode)
        proof_cases(runtime, temp, env)


def proof_cases(runtime, temp, environment):
    """Synthetic signed fixtures exercise the real aggregate, never live proof."""
    spec = importlib.util.spec_from_file_location('proof_fixtures', ROOT / 'tests/fixtures/live-host-proof/run_cases.py')
    fixtures = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fixtures)
    for mode in ('valid-signed', 'explicit-valid', 'stale-consumer', 'missing-record', 'unsigned-record', 'invalid-issuer', 'untrusted-signer'):
        fixture = fixtures.Fixture(temp / mode)
        project = fixture.root
        shutil.copytree(ROOT / 'plugins/sdd-quality-loop/scripts', project / 'plugins/sdd-quality-loop/scripts')
        shutil.copytree(ROOT / 'tests/lib', project / 'tests/lib')
        shutil.copytree(ROOT / 'tests/fixtures/cross-runtime-handoff', project / 'tests/fixtures/cross-runtime-handoff')
        references = project / 'plugins/sdd-review-loop/references'
        references.mkdir(parents=True)
        for source, name in ((fixture.registry, 'a8-trusted-signers.json'), (fixture.manifest, 'a8-expected-hook-config-digests.json'), (ROOT / 'plugins/sdd-review-loop/references/a8-skip-allowlist.json', 'a8-skip-allowlist.json')):
            shutil.copyfile(source, references / name)
        subprocess.run(['git', 'init', '-q', str(project)], check=True)
        subprocess.run(['git', 'add', 'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py', 'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh', 'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1'], cwd=project, check=True)
        subprocess.run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'synthetic activation fixture'], cwd=project, check=True)
        tasks = project / 'tasks.md'
        tasks.write_text('## T-005 fixture\nStatus: In Progress\n', encoding='utf-8')
        proof_records = fixture.records
        if mode in {'explicit-valid', 'stale-consumer'}:
            external = temp / (mode + '-capture')
            proof_records = external / 'tests/hook-activation-live-proof'
            shutil.copytree(fixture.records, proof_records)
            for relative in fixtures.load_validator_module().CONSUMERS.values():
                target = external / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(project / relative, target)
            if mode == 'stale-consumer':
                current = project / next(iter(fixtures.load_validator_module().CONSUMERS.values()))
                current.write_text(current.read_text() + 'Current consumer changed.\n')
        record = fixture.record_path('Claude-active')
        if mode == 'missing-record':
            record.unlink()
        elif mode == 'unsigned-record':
            data = json.loads(record.read_text()); data['operator_signature'] = ''; record.write_text(json.dumps(data))
        elif mode == 'invalid-issuer':
            data = json.loads(fixture.ledger.read_text()); data['entries'][0]['issuer_signature'] = ''; fixture.ledger.write_text(json.dumps(data))
        elif mode == 'untrusted-signer':
            registry = references / 'a8-trusted-signers.json'
            data = json.loads(registry.read_text()); del data['signers']['operator-key']; registry.write_text(json.dumps(data))
        trace = project / 'trace.json'
        env = {**environment, 'SDD_A8_COPILOT_MODEL': 'auto', 'SDD_STUB_MODE': 'good',
               'SDD_CROSS_RUNTIME_TASKS_PATH': str(tasks), 'SDD_CROSS_RUNTIME_MAIN_REF': 'HEAD'}
        if runtime == 'bash':
            command = ['bash', str(ROOT / 'tests/cross-runtime-handoff.tests.sh'), '--live-e2e', '--trace-file', str(trace)]
        else:
            command = [runtime, '-NoProfile', '-File', str(ROOT / 'tests/cross-runtime-handoff.tests.ps1'), '-LiveE2E', '-TraceFile', str(trace)]
        if proof_records != fixture.records:
            command += ['--live-host-proof-dir' if runtime == 'bash' else '-LiveHostProofDir', str(proof_records)]
        result = subprocess.run(command, cwd=project, env=env, capture_output=True, text=True, timeout=60)
        assert (result.returncode == 0) == (mode in {'valid-signed', 'explicit-valid'}), (runtime, mode, result.stdout, result.stderr)
        if mode in {'valid-signed', 'explicit-valid'}:
            data = json.loads(trace.read_text(encoding='utf-8-sig'))
            assert data['result'] == 'PASS' and data['coverage_complete'] is True
            assert data['canary_case']['result'] == 'PASS' and data['canary_case']['skip_reason'] is None
            proof = data['canary_case']['proof']
            assert proof['schema'] == 'cross-runtime-live-proof/v1' and proof['aggregate'] == 'discharged'
            assert len([a for a in proof['artifacts'] if a['kind'] == 'record']) == 5
            assert all(not Path(a['ref']).is_absolute() for a in proof['artifacts'])
            ledger = proof_records / 'nonce-ledger.json'
            assert all(e['consumed_by_record'] for e in json.loads(ledger.read_text())['entries'])
            helper_spec = importlib.util.spec_from_file_location('handoff_proof_helper', project / 'tests/lib/cross-runtime-consumer-evidence.py')
            helper = importlib.util.module_from_spec(helper_spec)
            helper_spec.loader.exec_module(helper)
            before = ledger.read_bytes()
            verified = helper.read_only_proof(project, proof_records)
            assert verified == {key: value for key, value in proof.items() if key != 'stdout'}
            assert ledger.read_bytes() == before, 'read-only verification changed the ledger'
            relocated = temp / (mode + '-transport')
            shutil.copytree(proof_records.parent.parent, relocated)
            replayed = helper.read_only_proof(project, relocated / 'tests/hook-activation-live-proof')
            assert replayed['artifacts'] == verified['artifacts'], 'transport changed stable proof identities'
            for consumed in (None, 'tests/hook-activation-live-proof/another.json'):
                mutated = json.loads(before); mutated['entries'][0]['consumed_by_record'] = consumed
                ledger.write_text(json.dumps(mutated)); changed = ledger.read_bytes()
                try:
                    helper.read_only_proof(project, proof_records)
                except Exception:
                    pass
                else:
                    raise AssertionError('read-only verification accepted an incomplete or different receipt')
                assert ledger.read_bytes() == changed, 'failed read-only validation wrote ledger'
            ledger.write_bytes(before)
        else:
            assert not trace.exists(), 'invalid signed proof published a trace'
        print('ok:', runtime, 'active proof', mode)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', required=True)
    run(parser.parse_args().runtime)
