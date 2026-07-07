# Frontend Specification: sdd-domain

N/A — no change: sdd-domain is a Markdown/CLI plugin (skills, agent
definitions, PowerShell/bash gate scripts, JSON Schema). It ships no graphical
frontend, no web runtime, and no client-side state.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Runtime | Claude Code / Codex / Copilot harness | per host | Same 3-environment manifest pattern as the other six plugins | manifest version lock |
| UI | N/A | — | conversational CLI only (see ux-spec.md) | — |
| Test | Pester (PowerShell) + bash | PS 5.1+ | matches existing test suites | no non-ASCII in .ps1 |

## Component Tree

N/A — no change: no component tree; skill orchestration is specified in
design.md Architecture.

## State Shape

N/A — no change: durable state lives in `domain/` artifacts and
`Domain-Model-Status` lines, specified in requirements.md and design.md.

## Routes and Components

N/A — no change.

## API Client Strategy

N/A — no change: the only remote access is read-only seed retrieval (issue
URLs) handled by the harness's fetch tooling; failure feedback specified in
ux-spec.md Component States.

## Code Splitting and Size Budget

N/A — no change.

## Performance Budget

N/A — no change: no page metrics. Operational latency concerns (cross-model
panel cost) are covered in design.md Risks and infra-spec.md.

## Empty, Loading, Error, and Success Behavior

Covered in ux-spec.md Component States (conversational equivalents).

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| none new | — | reuses existing repo tooling only | — | no new supply-chain surface |

## Testing

No frontend tests. Feature tests are enumerated in acceptance-tests.md
(TEST-001..TEST-014).

## Open Questions

- none
