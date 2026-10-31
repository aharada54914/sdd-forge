#!/usr/bin/env python3
"""T-007 fixture: fail the barrier on a NEWLY CREATED directory's parent.

Round 34's OpenAI Major: mkdir -p creates ancestor directory entries whose
durability lives in THEIR parents, and every earlier barrier fsynced only
directories that already existed. On a first Full-track publication
generated/ is created fresh, so its entry in scripts/ was never fsynced --
a power loss after verification and journal removal could keep the manifest
and Evidence while losing the whole directory and the Projection inside it.

This overlay deletes generated/ at import time (before the resolver computes
PRE hashes, making the Projection's PRE legitimately ABSENT) and then fails,
exactly once, the first fsync of a directory named scripts -- which under the
round-34 fix is the barrier _mkdir_durable runs for the created generated/
entry. Expected: the commit loop's OSError path Blocks with a one-rename
rollback (the facet manifest was already live). Remove _mkdir_durable
(mutant U) and no such fsync ever happens, the injection never fires, the
publication succeeds, and this case fails.

The overlay mechanism (real module re-exported as registry_discovery_real,
fd tracking with discard-on-close) is unchanged from its siblings.
"""
import os
import shutil

import registry_discovery_real as _real

for _name in dir(_real):
    if not _name.startswith("__"):
        globals()[_name] = getattr(_real, _name)
del _name


# Make generated/ ABSENT so the publication must CREATE it.
_generated = os.path.join(os.path.dirname(os.path.abspath(__file__)), "generated")
if os.path.isdir(_generated):
    shutil.rmtree(_generated)

_real_open = os.open
_real_fsync = os.fsync
_real_close = os.close
_script_dir_fds = set()
_fired = []


def _tracking_open(path, flags, *args, **kwargs):
    fd = _real_open(path, flags, *args, **kwargs)
    try:
        text = os.fsdecode(path) if not isinstance(path, int) else ""
        if text and os.path.basename(os.path.realpath(text)) == "scripts":
            _script_dir_fds.add(fd)
    except Exception:
        pass
    return fd


def _tracking_close(fd):
    _script_dir_fds.discard(fd)
    return _real_close(fd)


def _failing_fsync(fd):
    if fd in _script_dir_fds and not _fired:
        _fired.append(fd)
        raise OSError(5, "injected: created-directory parent fsync failure")
    return _real_fsync(fd)


os.open = _tracking_open
os.fsync = _failing_fsync
os.close = _tracking_close
