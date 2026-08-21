#!/usr/bin/env python3
"""T-004 test-harness-only stub (TEST-040 first, digest-mismatch fixture).

Standing in for the real `generate-registry-digest --whole` for exactly one
fixture: returns a FIXED digest on its first invocation (this invocation's
own step 6) and a DIFFERENT FIXED digest on every subsequent invocation
(step 13's own pre-publication recheck) -- simulating a Registry that
mutates between this invocation's own snapshot and its own recheck, via a
marker file dropped in this stub's own script directory (fresh per test run,
since each fixture invocation gets its own isolated tempdir)."""
import sys
from pathlib import Path

MARKER = Path(__file__).resolve().parent / ".t004-registry-digest-called"
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
