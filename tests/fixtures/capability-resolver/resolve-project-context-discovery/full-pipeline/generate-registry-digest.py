#!/usr/bin/env python3
"""T-006 fixture-owned stub standing in for `generate-registry-digest
--whole` (`full-pipeline`, TEST-002): the identical, already-established
two-fixed-digest technique T-004/T-005 already use (tests/fixtures/
capability-resolver/resolve-project-context-block/snapshot-generation-
mismatch/generate-registry-digest.py, reused here rather than reinvented)
-- returns a FIXED digest on its first call (step 6) and a DIFFERENT
FIXED digest on every later call (step 13's own pre-publication recheck),
forcing `snapshot-generation-mismatch` so this invocation reaches as far
as step 13 -- proving every governing-schema/Registry discovery step 5-12
already ran successfully -- without this suite needing to reach T-007's
own not-yet-landed live publication step."""
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
