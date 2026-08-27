#!/usr/bin/env python3
"""T-006 fixture-owned stub standing in for `generate-registry-digest
--whole` (`advisory-missing`, TEST-009): the identical, already-established
two-fixed-digest technique T-004/T-005 already use (tests/fixtures/
capability-resolver/resolve-project-context-block/snapshot-generation-
mismatch/generate-registry-digest.py, reused here rather than reinvented)
-- forces `snapshot-generation-mismatch` at step 13, AFTER step 10b's own
Capability Summary assembly and step 12's own output-schema
self-validation already ran, so this invocation's own `capability_
evaluations[]` becomes observable via Resolver Evidence, the same
disclosed oracle-reconstruction premise `tests/resolve-project-context-
match-check.py`'s own module docstring already establishes for the Full
track (live publication of the track-exclusive artifact itself remains
T-007's own not-yet-landed scope on this branch, Block or clean)."""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MARKER = HERE / ".t006-registry-digest-called"
FIRST_DIGEST = "1" * 64
SECOND_DIGEST = "2" * 64


def main():
    if MARKER.exists():
        sys.stdout.write(SECOND_DIGEST + "\n")
    else:
        MARKER.write_text("called\n", encoding="utf-8")
        sys.stdout.write(FIRST_DIGEST + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
