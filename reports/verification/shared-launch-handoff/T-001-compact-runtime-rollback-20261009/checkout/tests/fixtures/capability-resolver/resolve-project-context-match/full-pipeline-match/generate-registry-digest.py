#!/usr/bin/env python3
"""T-005 fixture-owned stub standing in for `generate-registry-digest
--whole` (`full-pipeline-match`, TEST-005/TEST-006): captures this
invocation's own argv (AC-005 -- confirms the Resolver calls this
dependency with exactly `--whole`, never a `--capability-ids`/`--gate-ids`
fragment) to `argv-capture.json`, then returns a FIXED digest on its first
call (this invocation's own step 6) and a DIFFERENT FIXED digest on every
later call (step 13's own pre-publication recheck) -- forcing
`snapshot-generation-mismatch` attributable to `registry_digest` alone,
since every other step-13 input (`ownership_digest`, `affected_components`)
is unchanged between calls, this being the only stubbed dependency. The
two-fixed-digest technique itself is T-004's own, already-established
mechanism (tests/fixtures/capability-resolver/resolve-project-context-
block/snapshot-generation-mismatch/generate-registry-digest.py), reused
here rather than reinvented; this stub additionally captures its own argv,
which that earlier fixture's stub does not need."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MARKER = HERE / ".t005-registry-digest-called"
ARGV_CAPTURE = HERE / "argv-capture.json"
FIRST_DIGEST = "1" * 64
SECOND_DIGEST = "2" * 64


def main():
    if not ARGV_CAPTURE.exists():
        ARGV_CAPTURE.write_text(json.dumps(sys.argv[1:]), encoding="utf-8")
    if MARKER.exists():
        sys.stdout.write(SECOND_DIGEST + "\n")
    else:
        MARKER.write_text("called\n", encoding="utf-8")
        sys.stdout.write(FIRST_DIGEST + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
