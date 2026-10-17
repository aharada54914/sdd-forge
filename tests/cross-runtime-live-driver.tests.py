#!/usr/bin/env python3
"""Exercise the live driver with isolated executable doubles, never native hosts."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

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


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', required=True)
    run(parser.parse_args().runtime)
