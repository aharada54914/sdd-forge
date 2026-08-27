#!/usr/bin/env python3
"""T-007 fixture: the TEST-HARNESS-ONLY KILL HOOK AC-047/design.md:1866
name by name ("test-harness-only hook: kill the process after the first
rename, before the second").

WHY IT LIVES IN A DEPENDENCY STUB RATHER THAN IN THE RESOLVER ITSELF.
The two obvious ways to build a crash hook are both closed to this task by
its own frozen contract: tasks.md's own "Breaking API" line forbids
"adding no new CLI flag" (so the `--simulate-crash-after <stage>` shape
Epic A1's own `apply-human-copy` uses for the isomorphic mechanism is not
available here), and security-spec.md's Secrets Management section fixes
"No script it ships reads an environment variable" (so an env-var-keyed
hook is closed too). The hook therefore has to live entirely OUTSIDE the
shipped scripts -- which is exactly what tasks.md's own Planned Files line
already says it is: `tests/fixtures/capability-resolver/` "(extended --
journal/crash-recovery/post-publication-race fixtures, **including a
test-harness-only kill hook** ...)". A fixture file, never production code.

The lever is `registry_discovery`, the ONE co-located sibling MODULE
`resolve-project-context.py` imports into its own process (step 5's own
`_discover_registry_with_sibling_module`). Overlaying it with this stub --
the identical `stub_name` overlay mechanism the `registry-discovery-
unimportable`/`registry-discovery-syntax-error` fixtures already use for
this same module -- gets fixture-authored code running INSIDE the resolver
process, at step 5, before step 14's own commit phase, with no change to
any shipped byte. Discovery itself must still work normally (this fixture
has to reach step 14 to have two renames to crash between), so every real
entry point is delegated verbatim to `registry_discovery_real`, the
untouched real module the harness plants alongside this stub -- the
identical "install the real dependency under a delegate name, put the stub
in its place" technique `copy_projection_inputs` already established for
`canonicalize-sdd-yaml`.

The kill itself is a `sys.addaudithook` observer of the CPython `os.rename`
audit event (raised by BOTH `os.rename` and `os.replace`, and raised
BEFORE the syscall runs). It counts only renames whose destination is one
of this feature's own LIVE publication targets -- never the journal's own
`TRANSACTION.json` rename, and never a `pre/<target-basename>` backup
write inside the batch's own `.resolver-staging/` area -- and kills the
process on the SECOND such rename, before it executes. The observable
result is precisely design.md's own "target 1 advanced, target 2 did not"
partial-publish state, with the journal still standing.

`os._exit` is deliberate and is NOT a soft `exit`: it terminates the
process immediately, bypassing every `try`/`finally`, `atexit` handler and
buffered-stream flush, so the resolver gets no opportunity whatsoever to
tidy up after itself -- the same "a real, unrecoverable-by-trap process
death" property Epic A1's own crash-injection harness documents for its
own `SIGKILL`. It is preferred over `signal.SIGKILL` here only because
`SIGKILL` does not exist on Windows, and this suite's own ps1 twin runs on
all three CI runners.
"""
import os
import sys

import registry_discovery_real as _real

# Re-export the real module's ENTIRE public surface verbatim, not just the
# two names `resolve-project-context.py` itself binds. This overlay sits in
# the shared scripts directory, so `validate-capability-registry.py` and
# `generate-registry-digest.py` import it too (each in its own subprocess),
# and a partial stand-in breaks them with an ImportError long before step 14
# is ever reached. Copying attributes off the real module keeps discovery
# behaviour byte-for-byte identical rather than reimplemented.
for _name in dir(_real):
    if not _name.startswith("__"):
        globals()[_name] = getattr(_real, _name)
del _name


# Every live publication target basename this feature owns (design.md's own
# track-exclusive output sets). Matched on the rename DESTINATION only.
_LIVE_TARGET_BASENAMES = frozenset((
    "facet-manifest.yaml",
    "capability-summary.yaml",
    "project-context.resolved.json",
    "resolver-evidence.yaml",
))

# The transaction's own unprotected staging area. A `pre/<target-basename>`
# backup shares its target's basename by construction (design.md fixes that
# naming), so basename matching ALONE would miscount a backup write as a
# live rename and kill the process during Prepare instead of during Commit.
_STAGING_DIRNAME = ".resolver-staging"

# Kill on the rename AFTER this many live renames have already committed.
_KILL_AFTER_COMMITTED_RENAMES = 1

_committed_live_renames = []


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
    if segments[-1] not in _LIVE_TARGET_BASENAMES:
        return
    if len(_committed_live_renames) >= _KILL_AFTER_COMMITTED_RENAMES:
        # Audit hooks run BEFORE the operation they observe, so this dies
        # with rename N-1 already durable and rename N never attempted.
        os._exit(137)
    _committed_live_renames.append(destination)


sys.addaudithook(_kill_hook)
