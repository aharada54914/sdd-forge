#!/usr/bin/env python3
"""T-007 fixture: kill the process BETWEEN the post-publication rollback and
the Block Evidence write.

This is the fixture the round-9 report claimed could not exist. Round 9
deferred the journal's deletion past the Block Evidence write so a crash in
that window would leave the journal for the next invocation's recovery scan,
and disclosed the change as unreachable by any test "without a new
test-harness kill hook between the rollback and the Evidence write". The
Anthropic panel slot pointed out on round 14 that the hook already exists --
`publication-journal-recovery`'s own `sys.addaudithook` observer -- and that
its kill point is one integer. It was right, so this fixture is written
rather than the disclosure repeated.

WHERE THE KILL LANDS. On the post-publication-mismatch path the resolver
renames three live targets (Full track: facet-manifest, the Context
Projection, then Evidence last), detects drift in its own post-publication
verification, rolls the two publication artifacts back, and only then writes
the Block record to Evidence. So `resolver-evidence.yaml` is renamed exactly
TWICE in that run: once by the commit, once by the Block write. Killing
before the SECOND one puts the process exactly in the window under test --
rollback finished, Block record not yet durable.

Counting Evidence renames rather than total renames is deliberate. The total
depends on the track and on how many artifacts the rollback restores, so a
total-based count would silently drift into the wrong window the next time
either changes; "the second write to Evidence" names the window directly.

The observable difference this fixture asserts on lives in the NEXT
invocation, not this one: with the deferral in place the journal is still
standing when the process dies, so the recovery scan finds it and Blocks
`publication-journal-recovery` for a human. With the journal deleted before
the Evidence write -- the pre-round-9 ordering -- the next invocation finds
nothing, and the publication that was rolled back leaves no trace at all.

Everything else about this stub is the established mechanism, verbatim from
`publication-journal-recovery/registry_discovery.py`: the real module is
planted alongside as `registry_discovery_real` and its entire public surface
is re-exported, because this overlay sits in the shared scripts directory and
`validate-capability-registry.py` and `generate-registry-digest.py` import it
too. `os._exit` bypasses every `try`/`finally` and `atexit` handler, which is
what makes the death unrecoverable-by-trap; it is preferred over `SIGKILL`
only because `SIGKILL` does not exist on Windows and this suite's ps1 twin
runs on all three CI runners.
"""
import os
import sys

import registry_discovery_real as _real

for _name in dir(_real):
    if not _name.startswith("__"):
        globals()[_name] = getattr(_real, _name)
del _name


_EVIDENCE_BASENAME = "resolver-evidence.yaml"

# A `pre/<target-basename>` backup shares its target's basename by
# construction, so basename matching alone would count a Prepare-phase backup
# write as an Evidence rename and kill the process far too early.
_STAGING_DIRNAME = ".resolver-staging"

# Kill on the Evidence rename AFTER this many have already happened. One =
# the commit's own Evidence write has landed, and the next Evidence rename is
# the Block record.
_KILL_AFTER_EVIDENCE_RENAMES = 1

_evidence_renames = []


def _kill_hook(event, args):
    if event != "os.rename":
        return
    destination = args[1]
    if isinstance(destination, (bytes, bytearray)):
        destination = os.fsdecode(bytes(destination))
    if not isinstance(destination, str):
        return
    segments = destination.replace("\\", "/").split("/")
    if _STAGING_DIRNAME in segments:
        return
    if segments[-1] != _EVIDENCE_BASENAME:
        return
    if len(_evidence_renames) >= _KILL_AFTER_EVIDENCE_RENAMES:
        # Audit hooks run BEFORE the operation they observe, so this dies
        # with the rollback complete and the Block record never written.
        os._exit(137)
    _evidence_renames.append(destination)


sys.addaudithook(_kill_hook)
