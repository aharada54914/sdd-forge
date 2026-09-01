#!/usr/bin/env python3
"""T-007 fixture: fail the staging-chain fsync, BEFORE any live rename.

Round 24 added a durability barrier on the staging CHAIN -- the batch
directory's entry in the staging root, and the staging root's entry in
specs/<feature> -- fsynced BEFORE the journal is written and therefore
before the first live rename. Failing that barrier must Block with a
ZERO-rename rollback clause, because nothing is published yet.

This is the sibling of `publication-fsync-failure`, which arms only AFTER a
rename lands. Together the two fixtures separate the two durability
barriers: remove the staging-chain fsync calls and this case's injection
never fires, the publication succeeds, and this case fails -- which is how
mutant P dies. The overlay mechanism (real module re-exported as
`registry_discovery_real`) is unchanged from its siblings.
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
_real_close = os.close
_real_replace = os.replace
_feature_dir_fds = set()
_renamed = []
_fired = []


def _tracking_replace(src, dst, *args, **kwargs):
    result = _real_replace(src, dst, *args, **kwargs)
    # Arm only once a rename has actually landed in the feature directory.
    # Round 24 added a staging-chain fsync of that same directory BEFORE the
    # first rename, so an unarmed overlay fired there instead and produced a
    # zero-rename Block -- correct behaviour, but not the state this case
    # exists to observe. The arm makes the fixture mean what its name says.
    try:
        if os.path.realpath(os.path.dirname(os.fsdecode(dst))).endswith(_FEATURE_DIR_SUFFIX):
            _renamed.append(dst)
    except Exception:
        pass
    return result


def _tracking_open(path, flags, *args, **kwargs):
    fd = _real_open(path, flags, *args, **kwargs)
    try:
        text = os.fsdecode(path) if not isinstance(path, int) else ""
        if text and os.path.realpath(text).endswith(_FEATURE_DIR_SUFFIX):
            _feature_dir_fds.add(fd)
    except Exception:
        pass
    return fd


def _tracking_close(fd):
    # Discard the fd on close. WITHOUT this the set holds STALE descriptor
    # numbers: a directory fd is opened, fsynced and closed, then the kernel
    # hands the same number to the next temp file, and the injection fires on
    # a FILE fsync inside _atomic_write_bytes instead of the directory
    # barrier this fixture exists to fail. Round 24's staging-chain fsync
    # made that misfire actually happen, and a stack-trace probe caught it --
    # the case had started passing for the wrong reason, which is precisely
    # how a test stops testing anything.
    _feature_dir_fds.discard(fd)
    return _real_close(fd)


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
os.close = _tracking_close
os.replace = _tracking_replace
