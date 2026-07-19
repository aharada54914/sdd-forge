# Frontend Specification: quality-loop-fixes

N/A — no change: the deliverables across all 4 streams are edits to
existing Bash/PowerShell scripts, one Markdown skill-prose file
(`cross-model-verify/SKILL.md`), one protected Markdown skill file
(`ship/SKILL.md`, human-copy staged), and one protected CI workflow file
(`.github/workflows/test.yml`, human-copy staged). There is no browser or
frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| `check-quality-gate-cycle-limit.sh` / `.ps1`, `emit-run-record.sh` / `.ps1`, `prepare-panelist-input.sh` / `.ps1`, `validate-review-context-set.sh` | Bash and PowerShell (existing supported runtimes) | existing | narrow, evidence-quoted fixes to already-shipped deterministic scripts | bash-3.2-safe (no `declare -A`, no unguarded `set -u` array expansion); `.ps1` files keep an explicit `exit N` |
| `ship/SKILL.md`, `cross-model-verify/SKILL.md` | Markdown (skill prose) | existing | prose extension inside already-established sections (design.md API/Contract Plan) | `ship/SKILL.md` edited via human-copy (protected); `cross-model-verify/SKILL.md` edited directly (not protected) |
| `.github/workflows/test.yml` | GitHub Actions YAML | existing | one new CI step for an already-registered `tests/run-all.sh` suite (Stream 1 only) | staged via human-copy (protected) |
| test suites | Bash and PowerShell twins (Streams 1-3); Bash-only fixture suite (Stream 4) | existing supported runtimes | cross-host determinism on the existing 3-OS matrix | `.sh`/`.ps1` pairs mandatory for Streams 1-3; Stream 4 is the recorded non-twin (`validate-review-context-set.ps1` does not share the defect, INV-019) |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists.

## Performance and Size Budget

N/A — no change: no frontend asset is built. Suite runtime requires no
budget assertion (design.md Test Strategy item 4) — every new/changed
test is pure fixture-driven function/script testing.

## Dependencies

No new runtime dependency for any of the 4 streams. All scripts already
depend on POSIX shell/PowerShell built-ins, `jq` (Stream 4's target
already depends on it — this feature only changes how its output is
consumed), and `python3` (Stream 3's `prepare-panelist-input.sh` already
depends on it for sanitization/hashing — unchanged). No new suite drives a
live network call or the real `gh` CLI.

## Testing

TEST-001 through TEST-030 in acceptance-tests.md cover the fixture-driven
script tests (Streams 1, 2, 3a, 4), the document/skill-prose conformance
checks (Stream 3b, Stream 1's `ship/SKILL.md` edit), and the
existing-suite regression checks (all 4 streams). No component,
accessibility, browser-performance, or frontend E2E test applies.

## Open Questions

None. Owner: maintainers; non-blocking.
