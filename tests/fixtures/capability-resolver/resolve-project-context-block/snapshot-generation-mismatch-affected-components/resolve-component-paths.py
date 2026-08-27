#!/usr/bin/env python3
"""T-007 fixture stub (AC-040's own SECOND fixture / TEST-040 companion,
B8 revised): every digest this invocation compares at step 13 -- including
`context_binding.ownership_digest` -- stays BYTE-IDENTICAL between the
step-4 snapshot and the step-13 pre-publication recheck, and ONLY the
re-derived `affected_components` set differs.

`ownership_digest` is a blunt, project-wide "the ownership *config*
changed" signal (Epic A3 `requirements.md:530-569`) and does not itself
change when only the underlying worktree/index/untracked state shifts which
components are affected between this invocation's own two `resolve-
component-paths` calls. The existing `snapshot-generation-mismatch` fixture
drives the Block through a `registry_digest` difference, so it would still
pass against a resolver that compared digests ONLY; this companion is the
one that fails such a mutant, because the set comparison is the sole
signal available to it (requirements.md REQ-002's own
`snapshot-generation-mismatch` row: "Now fires on an `affected_components`
set difference alone, even when every digest including `ownership_digest`
still matches").

Neither the Project Context nor the Registry is touched by this stub, so
`source_sha256` and `registry_digest` are recomputed from unchanged bytes
by the real dependencies and match by construction. The call-counting
marker-file technique is `recheck-dependency-failed`'s own, reused.
"""
import json
import sys
from pathlib import Path

MARKER = Path(__file__).resolve().parent / ".t007-affected-components-call-count"

# Byte-identical across BOTH calls -- this fixture's whole point.
OWNERSHIP_DIGEST = "sha256:" + ("0" * 64)

SNAPSHOT_AFFECTED_COMPONENTS = ["comp-a"]
RECHECK_AFFECTED_COMPONENTS = ["comp-a", "comp-b"]


def _call_number():
    try:
        previous = int(MARKER.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        previous = 0
    current = previous + 1
    MARKER.write_text(f"{current}\n", encoding="utf-8")
    return current


def main():
    affected_components = (
        SNAPSHOT_AFFECTED_COMPONENTS if _call_number() == 1 else RECHECK_AFFECTED_COMPONENTS
    )
    sys.stdout.write(json.dumps({
        "affected_components": affected_components,
        "context_binding": {"ownership_digest": OWNERSHIP_DIGEST},
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
