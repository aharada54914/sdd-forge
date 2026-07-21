# Frontend Specification: epic-136-phase3

N/A — no change: the deliverables across the 3 unblocked streams are two
new Bash test-suite files (`tests/guard-dispatch-fallback.tests.sh`,
`tests/guard-negative-corpus.tests.sh`) and one protected CI workflow file
(`.github/workflows/test.yml`, human-copy staged, one shared batch for
Streams A + D). Stream C's target shape (`tests/workflow-scenarios/` + a
JSON scenario schema) is defined but its implementation is Blocked pending
ADR-0010. There is no browser or frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| `tests/guard-dispatch-fallback.tests.sh`, `tests/guard-negative-corpus.tests.sh` | Bash (existing supported runtime) | existing | new, narrow, evidence-quoted coverage additions | bash-3.2-safe (no `declare -A`, no unguarded `set -u` array expansion); driven via `PATH`/env-var indirection against real guard binaries, never a reimplementation |
| `.github/workflows/test.yml` | GitHub Actions YAML | existing | 2 new CI steps (Streams A + B) plus a `[deterministic]` step-name-prefix restructuring (Stream D), all one shared human-copy batch | staged via human-copy (protected) |
| `tests/workflow-scenarios/scenario-schema.json` (target shape only, Stream C) | JSON Schema | n/a — not yet created | fixture-classification field reuses ADR-0010's closed `greenfield`\|`brownfield` set verbatim | Blocked pending ADR-0010 `Status: Accepted`; no file exists as an output of this feature |
| test suites | Bash-only (Streams A, B); no native `.ps1` twin | existing supported runtime | both new suites drive `.ps1`/`.js` targets via subprocess indirection rather than shipping a native `.ps1` driver, matching `guard-cwd-bypass.tests.sh`'s own shape | no `run-all.ps1` registration needed for either (design.md Global Constraints) |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists.

## Performance and Size Budget

N/A — no change: no frontend asset is built. Suite runtime requires no
budget assertion (design.md Test Strategy item 4) — every new/changed
test is pure fixture-driven function/script testing; Stream B's
3-class x 4-runtime x 3-tool_name-shape matrix (36 leaf assertions) is
comparable in cost to `guard-cwd-bypass.tests.sh`'s own existing corpus
size, not a new order-of-magnitude runtime addition.

## Dependencies

No new runtime dependency for Streams A, B, or D. Both new suites already
depend on the same interpreters the guard binaries themselves require
(`node`, `python3`, `pwsh`/`powershell.exe`/`powershell`, `bash`) —
unchanged, SKIP-on-absence behavior mirrors `guard-parity.tests.sh`'s
existing convention. No new suite drives a live network call or the real
`gh` CLI. Stream C's target shape (once unblocked) would depend on
`tests/lib/loop-driver.sh`'s existing helper functions for the
`"spec"`-stage scenarios — no new dependency beyond what that library
already requires.

## Testing

TEST-001 through TEST-011 and TEST-016 through TEST-023 in
acceptance-tests.md cover the fixture-driven script tests (Streams A, B),
the staged-YAML conformance and self-check (Stream D), the CI-registration
conformance checks (Streams A, B), and the document-conformance checks
(all 3 unblocked streams). TEST-012 through TEST-015 (Stream C) are
`Blocked`, not runnable today. No component, accessibility,
browser-performance, or frontend E2E test applies.

## Open Questions

None. Owner: maintainers; non-blocking.
