"""Reflect the user's approval of T-001 through T-006; no status changes."""
import argparse
import hashlib
from pathlib import Path
import re
import shutil
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
target = root / 'specs/sdd-domain-concept-test/tasks.md'
expected = '8ed934fe2dbdc3104669fdf85cc223667cf0271f4464710cd9182b7b4b37ceb0'
before = target.read_bytes()
if hashlib.sha256(before).hexdigest() != expected:
    raise SystemExit('Hash mismatch; no application. Send output to Codex.')
text = before.decode('utf-8')
blocks = re.split(r'(?m)(?=^## T-\d{3}\b)', text)
ids = [re.match(r'## (T-\d{3})\b', block).group(1) for block in blocks[1:]]
if ids != [f'T-{n:03d}' for n in range(1, 7)]:
    raise SystemExit('Unexpected task set; no application.')
for index in range(1, len(blocks)):
    block = blocks[index]
    if len(re.findall(r'^Approval: Draft$', block, re.M)) != 1 or len(re.findall(r'^Status: Planned$', block, re.M)) != 1:
        raise SystemExit('Unexpected approval/status; no application.')
    blocks[index] = re.sub(r'^Approval: Draft$', 'Approval: Approved', block, flags=re.M)
after = ''.join(blocks).encode('utf-8')
print('TARGET:', target)
print('Expected change: six Approval fields only; all Status fields remain Planned.')
if not args.apply:
    print('CHECK ONLY: no files changed. Human execution requires --apply.')
    raise SystemExit(0)
backup = Path(tempfile.mkdtemp(prefix='sdd290-human-approval-')) / 'tasks.md'
shutil.copy2(target, backup)
if target.read_bytes() != before:
    raise SystemExit(f'Target changed; no application. Backup: {backup}')
target.write_bytes(after)
if target.read_bytes() != after:
    raise SystemExit(f'Readback mismatch. Backup: {backup}')
print('Backup:', backup)
print('SHA256:', hashlib.sha256(after).hexdigest())
print('T-001–T-006 Approved. All Status fields remain Planned.')
print('No tests, review verdict, commit, push or merge changes. Send output to Codex.')
