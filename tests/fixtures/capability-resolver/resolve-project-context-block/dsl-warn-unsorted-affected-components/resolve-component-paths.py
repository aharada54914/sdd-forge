#!/usr/bin/env python3
"""T-003 fixture stub: deterministically returns `affected_components` in a
DESCENDING (non-ascending-lexicographic) order, standing in for Epic A3's
own genuinely unordered contract (investigation.md INV-006: no ordering
guarantee) -- this suite's other fixtures happen to observe git-diff output
that is already ascending, which is exactly why a missing explicit sort at
the resolve-project-context.py fan-out previously went uncaught. This one
fixture exists solely to prove the sort happens at the fan-out itself,
never assumed from upstream."""
import hashlib
import sys

digest = hashlib.sha256(b"dsl-warn-unsorted-affected-components").hexdigest()
sys.stdout.write(
    '{"affected_components": ["comp-z", "comp-a"], '
    '"context_binding": {"ownership_digest": "sha256:' + digest + '"}}'
)
sys.exit(0)
