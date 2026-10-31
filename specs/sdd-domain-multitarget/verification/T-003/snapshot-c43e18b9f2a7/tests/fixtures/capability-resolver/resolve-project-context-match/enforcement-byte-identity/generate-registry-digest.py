#!/usr/bin/env python3
"""T-005 fixture-owned stub (`enforcement-byte-identity`, TEST-016):
forces `snapshot-generation-mismatch` at step 13 after the entire steps
0-12 pipeline has genuinely run to completion, so this invocation's own
full Resolver Evidence content (including `capability_evaluations[]`) is
observable. Identical two-fixed-digest technique to `full-pipeline-
match`'s own stub and to T-004's own already-established
`resolve-project-context-block/snapshot-generation-mismatch` fixture --
reused here, not reinvented."""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MARKER = HERE / ".t005-registry-digest-called"
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
