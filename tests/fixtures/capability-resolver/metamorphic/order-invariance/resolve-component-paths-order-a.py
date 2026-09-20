#!/usr/bin/env python3
"""T-010 fixture stub (order-invariance, design.md Test Strategy item 9(b)):
returns the identical two-element `affected_components` set as its own
`-order-b` sibling, in the OPPOSITE literal array order --
`["comp-a", "comp-b"]` here, `["comp-b", "comp-a"]` there -- and the
identical fixed `ownership_digest` both variants share, so the ONLY input
difference between the two resolver invocations this fixture drives is the
raw JSON array order of `affected_components` itself. `resolve-project-
context.py`'s own step 7 fan-out explicitly re-sorts (`sorted_affected_
components`, ascending lexicographic, REQ-005/AC-024) before ever calling
`evaluate-predicate`, so a correct implementation's published output must
be byte-identical regardless of which of this pair supplied the input --
this fixture is what makes that invariance genuinely non-vacuous to check
(a mutant that skipped the re-sort and instead trusted the raw dependency
order would diverge between this stub and its sibling)."""
import json
import sys

OWNERSHIP_DIGEST = "sha256:" + ("9" * 64)

sys.stdout.write(json.dumps({
    "affected_components": ["comp-a", "comp-b"],
    "context_binding": {"ownership_digest": OWNERSHIP_DIGEST},
}))
sys.exit(0)
