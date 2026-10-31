#!/usr/bin/env python3
"""T-004 fixture stub (Fourth Pass, "recheck-internal dependency handlers
have no test" -- the report's own hypothesis, tested here rather than left
untested). Succeeds -- a FIXED, deterministic JSON document, standing in
for the real `resolve-component-paths.py`'s own output shape -- on its
FIRST invocation (this invocation's own step 4) and fails with a generic
non-zero exit and no stdout on every SUBSEQUENT invocation (step 13's own
pre-publication recheck, its SECOND call), via a marker file dropped in
this stub's own script directory (fresh per test run) -- the identical
call-counting technique `snapshot-generation-mismatch`'s own `generate-
registry-digest.py` stub already established for the SAME step-13 recheck
window, applied here to a DIFFERENT recheck-internal dependency
(`resolve-component-paths`, not `generate-registry-digest`) so this
fixture proves `_pre_publication_recheck`'s own dependency-call failures
map to the SAME REQ-002 id step 4 already uses (`affected-component-
resolution-failed`), never `snapshot-generation-mismatch` (an earlier
revision of this function's own defect, cross-model panel finding, T-004
NEEDS_WORK cycle 2).

Cross-model confirmation-panel Minor (Anthropic T-004, RFC-6901 escape
non-vacuity): this fixture's own `affected_components` are already PINNED
(never derived from a real git diff), so it is the safe, minimal place
in this driver's own scope to additionally carry two escape-bearing ids
(`shared/util`, `other~thing` -- the identical two ids T-005's own
`full-pipeline-match` fixture already exercises against the SAME
production escape) alongside the original `comp-a`; this fixture's own
Registry stays EMPTY (`EMPTY_REGISTRY_PATH`, unchanged), so
`capability_evaluations` stays `[]` regardless of how many affected
components exist -- only `context_binding.dependency_pointers[]` is
affected by this addition, which is the exact field this Minor's own
fix targets."""
import sys
from pathlib import Path

MARKER = Path(__file__).resolve().parent / ".t004-recheck-rcp-called"
FIRST_CALL_OUTPUT = (
    '{"affected_components": ["comp-a", "shared/util", "other~thing"], '
    '"context_binding": {"ownership_digest": "sha256:' + ("0" * 64) + '"}}'
)


def main():
    if MARKER.exists():
        sys.stderr.write("FIXTURE_INJECTED_FAILURE: resolve-component-paths failed on its second invocation\n")
        return 3
    MARKER.write_text("called\n", encoding="utf-8")
    sys.stdout.write(FIRST_CALL_OUTPUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
