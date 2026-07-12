# Frontend Specification: epic-136-phase1-guards

N/A — no change: the affected implementation is guard scripts (Bash, Python,
Node, PowerShell), a Markdown skill, a JSON hook config, and a GitHub Actions
workflow. There is no browser or frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Guard runtimes | Python 3, Node.js, Windows PowerShell 5.1, Bash | existing supported runtimes | three deterministic guard twins | `.ps1` ASCII-only; decision parity |
| Cycle-limit script | Bash and PowerShell | existing | deterministic count | sh/ps1 parity |
| CI | GitHub Actions | existing | weekly self-improvement | minimized permissions |
| Test | Bash + PowerShell fixture suites | existing | drive guards and scripts | no network, no real secrets |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists.

## Performance and Size Budget

N/A — no change: no frontend asset is built. Guard checks are short
single-process operations; the added Bash matcher coverage under Claude Code
adds one guard invocation per Bash call, matching the cost already paid under
Codex.

## Dependencies

No new runtime dependency. Python uses only standard-library modules; Node
uses built-ins; PowerShell uses .NET already present; the cycle-limit scripts
use POSIX shell utilities and PowerShell built-ins.

## Testing

TEST-001 through TEST-013 in acceptance-tests.md cover guard decisions, the
cycle-limit script, the ship-skill conformance, the CI guard, and the Bash
matcher. No component, accessibility, browser-performance, or frontend E2E
test applies.

## Open Questions

None. Owner: maintainers; non-blocking.
