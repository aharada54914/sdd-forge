#!/usr/bin/env python3
"""T-007 fixture: fail the FIRST directory fsync of the feature directory,
exactly once.

This is the fault injection the round-20 mutation note promised as "future
fixture work, not an impossibility claim", written after the anthropic panel
slot's round-21 Major pointed out that an admittedly-testable fix on a
tdd-required Security-Sensitive surface had shipped untested.

WHAT IT EXERCISES. `_atomic_write_bytes` fsyncs the target's parent directory
after `os.replace`. When that fsync fails the rename is already LIVE, and
round 20's `_ReplacedButNotDurable` exists so the commit loop counts the
entry BEFORE the failure propagates -- otherwise the rollback skips a
visibly published artifact, reports completion, and leaves it standing.
Failing the first fsync of `specs/example-feature` hits the facet-manifest
commit (the first live rename whose parent is the feature directory; the
Context Projection's parent is scripts/generated, and the journal's own
writes fsync the batch directory). The single-shot design is deliberate: the
ROLLBACK of that same target fsyncs the same directory moments later, and a
persistent failure would collapse this into the incomplete-rollback path,
which is a different case with different assertions.

Everything else is the established overlay mechanism, verbatim from
`publication-journal-recovery/registry_discovery.py`: the real module is
planted alongside as `registry_discovery_real` and its entire public surface
re-exported, because this overlay sits in the shared scripts directory and
the subprocess dependencies import it too.
"""
import os
import sys

import registry_discovery_real as _real

for _name in dir(_real):
    if not _name.startswith("__"):
        globals()[_name] = getattr(_real, _name)
del _name


_FEATURE_DIR_SUFFIX = os.path.join("specs", "example-feature")

_real_open = os.open
_real_fsync = os.fsync
_feature_dir_fds = set()
_fired = []


def _tracking_open(path, flags, *args, **kwargs):
    fd = _real_open(path, flags, *args, **kwargs)
    try:
        text = os.fsdecode(path) if not isinstance(path, int) else ""
        if text and os.path.realpath(text).endswith(_FEATURE_DIR_SUFFIX):
            _feature_dir_fds.add(fd)
    except Exception:
        pass
    return fd


def _failing_fsync(fd):
    if fd in _feature_dir_fds and not _fired:
        # Single shot: the first durability barrier on the feature directory
        # dies with EIO; every later one (the rollback's, the Evidence
        # write's) succeeds.
        _fired.append(fd)
        raise OSError(5, "injected: feature-directory fsync failure")
    return _real_fsync(fd)


os.open = _tracking_open
os.fsync = _failing_fsync
