# Frontend Specification: epic-136-phase3

**Stream C status.** ADR-0010 reached `Status: Accepted` (commit `67015a5`,
2026-07-22), discharging Stream C's Blocker, and Stream C landed in this
feature (T-004). requirements.md and design.md carry the authoritative
record; this document is reconciled to it.

N/A — no change: the deliverables across the four streams are three new
Bash test-suite files (`tests/guard-dispatch-fallback.tests.sh`,
`tests/guard-negative-corpus.tests.sh`,
`tests/workflow-scenarios/workflow-scenarios.tests.sh`) plus Stream C's JSON
scenario schema, and one protected CI workflow file
(`.github/workflows/test.yml`, human-copy staged, one shared batch for
Streams A + B + C + D). There is no browser or frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| `tests/guard-dispatch-fallback.tests.sh`, `tests/guard-negative-corpus.tests.sh` | Bash (existing supported runtime) | existing | new, narrow, evidence-quoted coverage additions | bash-3.2-safe (no `declare -A`, no unguarded `set -u` array expansion); driven via `PATH`/env-var indirection against real guard binaries, never a reimplementation |
| `.github/workflows/test.yml` | GitHub Actions YAML | existing | 2 new CI steps (Streams A + B) plus a `[deterministic]` step-name-prefix restructuring (Stream D), all one shared human-copy batch | staged via human-copy (protected) |
| `tests/workflow-scenarios/scenario-schema.json` (Stream C) | JSON Schema | created by T-004 | fixture-classification field reuses ADR-0010's closed `greenfield`\|`brownfield` set verbatim | authored only after ADR-0010 reached `Status: Accepted` (commit `67015a5`), never speculatively |
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
`gh` CLI. Stream C depends on
`tests/lib/loop-driver.sh`'s existing helper functions for the
`"spec"`-stage scenarios — no new dependency beyond what that library
already requires.

## Testing

TEST-001 through TEST-023 in acceptance-tests.md cover the fixture-driven
script tests (Streams A, B), Stream C's scenario-schema and driver checks
(TEST-012 through TEST-015, runnable today via
`bash tests/workflow-scenarios/workflow-scenarios.tests.sh`), the staged-YAML
conformance and self-check (Stream D), the CI-registration conformance checks
(Streams A, B, C), and the document-conformance checks across all four
streams. No component, accessibility, browser-performance, or frontend E2E
test applies.

## Open Questions

None. Owner: maintainers; non-blocking.
