# Frontend Specification: epic-159-pillar-b

N/A — no change: the deliverables are an edit to a Bash CLI script
(`scripts/bump-version.sh`), an edit to a GitHub Actions workflow
(`.github/workflows/release.yml`), and two new Bash/PowerShell test-suite
twins. There is no browser or frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| `bump-version.sh` loop-gate prerequisite | Bash | existing supported runtime (`set -euo pipefail`) | reuses the script's own `$ROOT`-relative resolution (`scripts/bump-version.sh:18`) | bash-only by design decision (REQ-004, OQ-003) — no `.ps1` twin of the CLI script itself |
| `tests/bump-version-gate.tests.sh` / `.ps1` | Bash and PowerShell twins | existing supported runtimes | cross-host determinism; the `.ps1` twin shells to `bash` to drive the bash-only real script, degrading to a named SKIP if `bash` is absent from `PATH` (mirrors `tests/hitl-wfi-terminal.tests.ps1:101-107`) | `.sh`/`.ps1` pairs; ASCII/no-BOM/LF-only if the `.ps1` twin is ever added to `guard-ps1-ascii.tests.sh`'s targets (not required by this feature) |
| `release.yml` loop-gate job | GitHub Actions YAML | existing | required job the build job `needs:` | `ubuntu-latest` only, matching `release.yml`'s existing single-OS scope |
| `tests/release-loop-gate.tests.sh` / `.ps1` | Bash (python3 heredoc) and PowerShell (native regex) twins | existing supported runtimes | text-marker structural lock, following `tests/workflow-state-ci-integration.tests.sh`'s established technique | `.sh`/`.ps1` pairs; the `.ps1` twin re-implements the same logic natively rather than shelling to `python3` |
| CI | GitHub Actions | existing | 3-OS matrix (`test.yml`, both new suites) + `ubuntu-latest` (`release.yml`'s existing and new jobs) | deterministic lane (#126 note) |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists.

## Performance and Size Budget

N/A — no change: no frontend asset is built. Suite runtime is governed by
the Runtime Budget section of infra-spec.md (neither new suite requires a
budget assertion — design.md Test Strategy item 3).

## Dependencies

No new runtime dependency for the CLI or CI legs themselves. The two new
test suites use POSIX shell utilities, `git`, `tar` (bash lane, fixture
construction — both already repository dependencies via
`tests/repository-release-validation.tests.sh`), `python3` (bash lane,
`release-loop-gate` text-marker technique — already a repository
dependency via `tests/workflow-state-ci-integration.tests.sh` and
`.github/scripts/generate-sbom.py`), and PowerShell built-ins (`.ps1`
lane). Neither new suite introduces jq consumption or drives the real
validator (design.md Constraint Compliance).

## Testing

TEST-001 through TEST-014 in acceptance-tests.md cover the
`bump-version.sh` loop-gate prerequisite's green/red/no-bypass/ordering/
CI-resilience legs, the `release.yml` required-job structural lock and its
negative-branch canary, and documentation/cross-host conformance. No
component, accessibility, browser-performance, or frontend E2E test
applies.

## Open Questions

None. Owner: maintainers; non-blocking.
