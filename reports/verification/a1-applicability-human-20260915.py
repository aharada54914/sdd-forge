#!/usr/bin/env python3
"""Human-only, pinned design amendment; never changes review verdicts."""
import datetime
import hashlib
import os
from pathlib import Path
import shutil
import stat
import tempfile

repo = Path('/Users/jrmag/sdd-forge')
target = repo / 'specs/epic-189-a1-project-context/design.md'
expected = '9aea7f51d7d70fcd4c9f1e3ea339c8cdd20f5826010ff2539e31f2d1ba9faf91'
old = '''Re-run that root-entry probe immediately before the next review consumes this
claim and record its result with the current design hash in the precheck
evidence. If the entry appears or the probe fails for a reason other than
`ENOENT`, stop and resolve applicability instead of reusing this observation.
If a design system applies, bind its required inputs through an authorized
review contract and supply the version, token groups and component rationale
before review. Reviewers receive this declaration as part of their hash-bound
design input; it does not authorize additional filesystem reads outside their
reserved input boundary. The prior round's FAIL is retained pending genuine
re-review, and its contract must not be rewritten to bind these new bytes.
'''

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    for entry in [target, *target.parents]:
        if entry.is_symlink():
            raise SystemExit('Stop: symlink in target path')
    info = target.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise SystemExit('Stop: target must be a single-link regular file')
    before = target.read_bytes()
    if digest(before) != expected:
        raise SystemExit('Stop: design hash changed; no files modified')
    content = before.decode('utf-8')
    if content.count(old) != 1:
        raise SystemExit('Stop: expected paragraph is not unique')
    try:
        (repo / 'design-system').lstat()
    except FileNotFoundError:
        observed = datetime.datetime.now(datetime.timezone.utc).isoformat()
    else:
        raise SystemExit('Stop: design-system entry exists; resolve applicability')
    replacement = f'''Supersession for attempt 6 round 2, human application at {observed}:
a fresh read-only lstat of `/Users/jrmag/sdd-forge/design-system` returned
`ENOENT`. The September 9 observation above is historical, not the evidence
for this next round. This current observation supports only the absent-root
entry branch; it does not declare a ds_profile setting or waive UI checks.

Record applicability observations in this design input BEFORE generating the
next precheck, rather than adding an unsupported field to precheck evidence.
The precheck's design_sha256 and both reserved reviewer manifests bind the
exact design bytes containing the observation. Recheck the root entry just
before reservation; if it exists or inspection fails for any non-ENOENT
reason, stop and resolve applicability before launch. If review is delayed
or the design changes, refresh the observation through the same authorized
design-amendment path before generating new review inputs.

If a design system applies, bind its required inputs through an authorized
review contract and supply the version, token groups and component rationale.
Reviewers may not read outside their reserved boundary. All previous FAILs,
reservations and consumed prechecks remain unchanged. This amendment and its
new hash require genuine round-2 review; no PASS or task completion is granted.
'''
    after = content.replace(old, replacement).encode('utf-8')
    backup = Path(tempfile.mkdtemp(prefix='sdd-a1-applicability-'))
    shutil.copy2(target, backup / 'design.md')
    if target.read_bytes() != before or target.stat().st_ino != info.st_ino:
        raise SystemExit(f'Stop: concurrent change; backup: {backup}')
    fd, name = tempfile.mkstemp(prefix='.design-amendment-', dir=target.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(after)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(name, stat.S_IMODE(info.st_mode))
        os.replace(name, target)
    finally:
        if os.path.exists(name):
            os.unlink(name)
    print(f'Backup: {backup}')
    print(f'{digest(target.read_bytes())}  {target}')
    print(f'Applicability observed: {observed}; lstat returned ENOENT')
    print('Applied one design paragraph only. Send output to Codex.')
    print('No review status, commit, push, CI or merge was performed.')

if __name__ == '__main__':
    main()
