# Frontend Specification: epic-159-pillar-d

N/A — no change: the deliverables are edits to two Markdown contributor
documents, a new GitHub Actions workflow, a new Bash script, a new
Bash/PowerShell test-suite twin pair, and a JSON registry data update.
There is no browser or frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| `docs/contributor/workflow-detail.md` / `docs/agent-capability-matrix.md` | Markdown | existing | prose extension inside an already-established section/table (design.md API/Contract Plan) | append-only column edits, verified compatible with `tests/agent-model-routing.tests.sh`'s existing fixed-string checks |
| `model-freshness-check.yml` | GitHub Actions YAML | existing | new, standalone workflow (design.md Design Decisions) rather than extending `self-improvement.yml` | `ubuntu-latest` only; `contents: read`/`issues: write` only |
| `check-model-freshness.sh` | Bash | existing supported runtime (`set -euo pipefail` expected) | GitHub-Actions-only script, mirrors the established `.github/scripts/self-improvement-pr-guard.sh` non-twin precedent | bash-only by design decision (REQ-004) — no `.ps1` twin of the script itself |
| `tests/model-freshness-check.tests.sh` / `.ps1` | Bash and PowerShell twins | existing supported runtimes | cross-host determinism on the 3-OS matrix; native reimplementation (no shell-out to bash), since the script under test has no cross-host runtime claim to make | `.sh`/`.ps1` pairs mandatory for this suite (unlike the script itself) |
| `contracts/agent-model-capabilities.v2.json` | JSON | existing-once-C1-lands | data-only edit within Pillar C's C1-defined schema | schema shape is not this feature's to change |
| CI | GitHub Actions | existing | 3-OS matrix (`test.yml`, the new suite) + `ubuntu-latest` (`model-freshness-check.yml`'s own weekly/manual-dispatch scope) | deterministic lane (#126 note) |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists.

## Performance and Size Budget

N/A — no change: no frontend asset is built. Suite runtime is governed by
the Runtime Budget section of infra-spec.md (the new suite requires no
budget assertion — design.md Test Strategy item 4).

## Dependencies

No new runtime dependency for the documentation or registry-data edits.
`check-model-freshness.sh` uses `curl` (or equivalent, already available
on GitHub-hosted `ubuntu-latest` runners) for its best-effort fetches and
`gh` (already a repository dependency, e.g.
`.github/scripts/self-improvement-pr-guard.sh`'s own `gh pr`/`gh issue`
usage via `self-improvement.yml`) for issue creation/comment/dedup. The
two new test suites use POSIX shell/PowerShell built-ins and mktemp-scoped
fixture files only — neither drives a live network call or the real `gh`
CLI (design.md Test Strategy, Security Boundaries B4).

## Testing

TEST-001 through TEST-019 in acceptance-tests.md cover the documentation
conformance and existing-suite regression checks for T-001, the
fetch-failure/divergence-detected/dedup/CI-resilience/self-registration/
weekly-session-denial/protected-file-staging checks for T-003, and the
data-conformance/non-mutation/existing-suite-regression checks for T-002.
No component, accessibility, browser-performance, or frontend E2E test
applies.

## Open Questions

None. Owner: maintainers; non-blocking.
