# Frontend Specification: epic-159-pillar-a

N/A — no change: the deliverables are a JSON inventory, Bash/PowerShell test
helpers and suites, and CI registration edits. There is no browser or
frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Inventory | JSON (`loop-inventory/v1`) | n/a | machine-readable single registry | closed `fixture_profiles` vocabulary (ADR-0010) |
| Driver + suites | Bash and PowerShell twins | existing supported runtimes | cross-host determinism (INV-021) | `.sh`/`.ps1` pairs; crlf-parity / constant-parity enforced |
| Structural validation | jq | existing | schema and manifest assertions | already a repository dependency |
| CI | GitHub Actions | existing | 3-OS matrix, bash+pwsh lanes | deterministic lane (#126 note) |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists.

## Performance and Size Budget

N/A — no change: no frontend asset is built. Suite runtime is governed by
the Runtime Budget section of infra-spec.md.

## Dependencies

No new runtime dependency. The suites use POSIX shell utilities, PowerShell
built-ins, jq, and — indirectly through the real gate scripts — python3
with the explicit `deterministic-runtime-unavailable` degradation (INV-017).

## Testing

TEST-001 through TEST-016 in acceptance-tests.md cover the inventory checks,
driver contracts, consistency legs, escalation chain, parity extension,
degradation paths, and documentation conformance. No component,
accessibility, browser-performance, or frontend E2E test applies.

## Open Questions

None. Owner: maintainers; non-blocking.
