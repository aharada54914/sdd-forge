#!/usr/bin/env python3
"""T-003 fixture stub: deterministically returns `affected_components` in a
DESCENDING (non-ascending-lexicographic) order, standing in for Epic A3's
own genuinely unordered contract (investigation.md INV-006: no ordering
guarantee) -- this suite's other fixtures happen to observe git-diff output
that is already ascending, which is exactly why a missing explicit sort at
the resolve-project-context.py fan-out previously went uncaught. This one
fixture exists solely to prove the sort happens at the fan-out itself,
never assumed from upstream.

Also records this invocation's own argv verbatim to `rcp-argv-capture.json`
(T-003 confirmation-panel Minor, Anthropic v3): `t003_resolver_argv`'s own
`include_untracked` parameter had no caller passing `True` anywhere in this
driver, so the SUPPLIED half of AC-004's pass-through claim (that
`--include-untracked` reaches `resolve-component-paths` verbatim, in its
own CLI-contract position) was untested by this task's own suite -- only
by T-005's `resolve-project-context-match-check.py`, outside this bundle.
This fixture's own return value is unaffected by `--include-untracked`
either way (its ordering-proof purpose is orthogonal to that flag), so
wiring `run_t003_case` to call it with `include_untracked=True` costs
nothing functionally and lets this one case close both gaps at once."""
import hashlib
import json
import sys
from pathlib import Path

CAPTURE = Path(__file__).resolve().parent / "rcp-argv-capture.json"
CAPTURE.write_text(json.dumps(sys.argv[1:]), encoding="utf-8")

digest = hashlib.sha256(b"dsl-warn-unsorted-affected-components").hexdigest()
sys.stdout.write(
    '{"affected_components": ["comp-z", "comp-a"], '
    '"context_binding": {"ownership_digest": "sha256:' + digest + '"}}'
)
sys.exit(0)
