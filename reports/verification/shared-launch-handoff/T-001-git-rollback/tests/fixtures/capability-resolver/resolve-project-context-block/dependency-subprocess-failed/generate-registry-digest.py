#!/usr/bin/env python3
"""T-003 fixture stub: deterministically fails for a reason OTHER than an
internal canonicalizer failure (no "canonicalizer-failed" token in stderr),
standing in for step 6's own `dependency-subprocess-failed` Block (B3's
generic, otherwise-unnamed dependency non-zero-exit catch-all)."""
import sys

sys.stderr.write("generate-registry-digest: FIXTURE_INJECTED_FAILURE\n")
sys.exit(1)
