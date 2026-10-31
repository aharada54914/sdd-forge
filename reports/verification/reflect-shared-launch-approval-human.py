"""Human-only reflection of existing authorization; no task status changes."""
import hashlib
from pathlib import Path
import sys
import tempfile

root = Path(__file__).resolve().parents[2]
target = root / 'specs/shared-review-launch-repair/tasks.md'
before = target.read_bytes()
expected = '0a20596aaee6b774342b27ae495ccfe7439d021c494885393b42e91c31ec9cb7'
if hashlib.sha256(before).hexdigest() != expected:
    sys.exit('STOP: task plan changed; no application')
if before.count(b'\nApproval: Draft\n') != 5:
    sys.exit('STOP: expected five Draft approvals; no application')
after = before.replace(b'\nApproval: Draft\n', b'\nApproval: Approved\n')
if sys.argv[1:] != ['--apply-human']:
    sys.exit('Check passed; human invocation requires --apply-human')
backup = Path(tempfile.mkdtemp(prefix='shared-launch-approval-')) / 'tasks.md'
backup.write_bytes(before)
if target.read_bytes() != before:
    sys.exit('STOP: task plan changed during backup; no application')
target.write_bytes(after)
if target.read_bytes() != after:
    sys.exit(f'STOP: readback mismatch; backup={backup}')
print(f'T-001 through T-005 Approved; statuses unchanged. Backup: {backup}')
print('SHA256:', hashlib.sha256(after).hexdigest())
