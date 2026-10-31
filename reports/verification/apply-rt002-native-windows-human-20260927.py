"""Hash-pinned human application; default only validates the candidate.

Use through rtk proxy. --apply is for the maintainer's permitted human path.
An actual refusal must stop; this script does not bypass or retry a denial.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--root', required=True)
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
root = Path(args.root).resolve()
here = Path(__file__).resolve().parent
manifest = json.loads((here / 'rt002-native-windows-20260927.manifest.json').read_text())
head = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
if head != manifest['base_commit']:
    raise SystemExit('STOP: base commit changed; regenerate and review candidate')
inputs = {manifest['target']: manifest['base_sha256'], **manifest['bound_inputs']}
for name, expected in inputs.items():
    if hashlib.sha256((root / name).read_bytes()).hexdigest() != expected:
        raise SystemExit('STOP: pinned input changed: ' + name)
patch = here / manifest['patch']
if hashlib.sha256(patch.read_bytes()).hexdigest() != manifest['patch_sha256']:
    raise SystemExit('STOP: candidate patch changed')
subprocess.run(['git', '-C', str(root), 'apply', '--check', str(patch)], check=True)
if args.apply:
    subprocess.run(['git', '-C', str(root), 'apply', str(patch)], check=True)
    print('Applied candidate once; native Windows execution remains pending.')
else:
    print('Candidate checks passed; protected target unchanged; Windows result pending.')
