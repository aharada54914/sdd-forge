#!/usr/bin/env python3
"""T-003 fixture stub: deterministically returns a zero-exit {result,
evidence} shape whose own `evidence[]` array elements are NOT objects
(`["x"]` rather than a list of evidence nodes) -- standing in for an
upstream evaluate-predicate contract violation. Asserts step 7's own
element-wise evidence-shape validation raises `dependency-output-malformed`
(design.md step 7) instead of `_evidence_has_warn`'s `.get()` crashing with
an uncaught AttributeError on a bare string."""
import sys

sys.stdout.write('{"result": true, "evidence": ["x"]}')
sys.exit(0)
