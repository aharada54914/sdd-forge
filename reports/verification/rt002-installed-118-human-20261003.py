#!/usr/bin/env python3
"""Pinned RT002 installer adapter. --apply and --restore are human-only.

Reuses the reviewed backup, atomic replacement, restoration and self-tests.
Only the Codex 1.18.0 verifier is targeted; no guard or verdict is changed.
"""
import hashlib
import os
from pathlib import Path
import stat

HELPER = Path('/Users/jrmag/sdd-forge/specs/epic-189-a1-rt002-repair/verification/apply-installed-verifier-human.py')
HELPER_SHA256 = '6ff32fbfbeefda0b7c980c0dd6369b58e3b5f622b6436ad7c8d345d58644eded'


def main():
    with os.fdopen(os.open(HELPER, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise SystemExit('STOP: installer helper is not a single-link regular file')
        code = stream.read()
    if hashlib.sha256(code).hexdigest() != HELPER_SHA256:
        raise SystemExit('STOP: installer helper changed; no application')
    namespace = {'__name__': 'rt002_pinned_installer', '__file__': str(Path(__file__).resolve())}
    exec(compile(code, str(HELPER), 'exec'), namespace)
    namespace.update(
        SOURCE=Path('/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge/plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py'),
        TARGET=Path('/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.18.0/scripts/check-hook-activation-handshake.py'),
        NEW='1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d',
    )
    namespace['main']()


if __name__ == '__main__':
    main()
