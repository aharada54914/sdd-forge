# Frontend Specification: epic-159-pillar-a2

N/A — no change: the deliverables are Bash/PowerShell test suites, a
committed fixture directory, and two PowerShell precheck scripts. There is
no browser or frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Terminal-behavior suite | Bash and PowerShell twins | existing supported runtimes | cross-host determinism | `.sh`/`.ps1` pairs; ASCII/no-BOM/LF-only for `.ps1` (`guard-ps1-ascii.tests.sh` extension) |
| Canonical brownfield seed | committed fixture files (Python, Markdown, plain text) | n/a | reusable, reviewable seed for the `brownfield` fixture profile (ADR-0010) | inert — never executed as part of any build; consumed only as scan/copy input |
| Precheck script ports | PowerShell | existing supported runtime (pwsh 7) | full-parity translation of the `.sh` originals, matching `impl-review-precheck.ps1`/`task-review-precheck.ps1` idioms | must land at the exact paths the existing self-healing dispatch expects |
| CI | GitHub Actions | existing | 3-OS matrix, bash+pwsh lanes | deterministic lane (#126 note) |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists.

## Performance and Size Budget

N/A — no change: no frontend asset is built. Suite runtime is governed by
the Runtime Budget section of infra-spec.md.

## Dependencies

No new runtime dependency. The suites use POSIX shell utilities, PowerShell
built-ins, and — for the brownfield-profile leg only, transitively via the
existing loop driver — jq. Neither new `.ps1` precheck port introduces a
dependency beyond what its `.sh` original already requires.

## Testing

TEST-001 through TEST-019 in acceptance-tests.md cover the HITL/WFI-audit
terminal-behavior legs, the brownfield seed and its check-placeholders lock,
the profile-parity leg, the two precheck-port hygiene checks, the
self-healing SKIP-to-green observables, and documentation conformance. No
component, accessibility, browser-performance, or frontend E2E test
applies.

## Open Questions

None. Owner: maintainers; non-blocking.
