#!/usr/bin/env python3
"""T-003 fixture stub for `generate-registry-digest --whole`, standing in
for the real dependency for the `registry-swapped-during-validation`
fixture (T-004 confirmation-panel Critical/Major, both vendors -- closed
via `_recheck_registry_snapshot`, resolve-project-context.py step 6.5).

Neither `validate-capability-registry` (step 5) nor `generate-registry-
digest --whole` (step 6) accepts a path/bytes argument bound to the
resolver's own already-retained step-5 `registry_document` read -- three
independent reads of the same file, no binding between them. This stub
stands in for the real step-6 dependency and, as a SIDE EFFECT of that
invocation, overwrites the discovered Registry file in place (the
identical `contracts/capability-registry.json` `_discover_registry`
already read moments earlier) with different bytes -- proving a swap
happening even INSIDE this dependency's own real-tool-equivalent process
window is still caught, since the resolver's own recheck re-reads the
SAME path from its own process, after this stub returns, regardless of
what happened while this stub's own process ran. Returns a well-formed
bare 64-hex digest (this fixture's own concern is the byte-level swap
detection, not this stub's own digest value) so step 6 itself succeeds
normally -- it is step 6.5's own recheck that must Block."""
import sys
from pathlib import Path

REGISTRY_PATH = Path.cwd() / "contracts" / "capability-registry.json"
DUMMY_DIGEST = "ab" * 32


def main():
    original = REGISTRY_PATH.read_bytes()
    REGISTRY_PATH.write_bytes(original + b"\n")
    sys.stdout.write(DUMMY_DIGEST + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
