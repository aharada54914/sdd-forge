# Frontend Specification: sdd-context

N/A — no change: sdd-context is a deterministic Node hook plugin (manifest
files, `.mjs` scripts, sh/PowerShell wrappers, Markdown/JSON artifacts). It
ships no graphical frontend, no web runtime, and no client-side state.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Runtime | Node.js core | 18+ | deterministic script execution shared by Claude Code and Codex wrappers | absent-node path must no-op |
| Wrapper | sh (POSIX) + PowerShell | per host shell | Codex hook invocation may use shell; Claude Code uses node exec | thin wrappers only |
| UI | N/A | — | hook/Markdown only (see ux-spec.md) | — |
| Test | Pester (PowerShell) + bash | PS 5.1+ | matches repository test suites | no non-ASCII in .ps1 |

## Component Tree

N/A — no change: no component tree. Hook dispatch and Node-core composition
are specified in design.md Architecture.

## State Shape

N/A — no change: durable state lives in `.sdd/context/HANDOFF.md`,
`.sdd/context/handoff.json`, and `.sdd/context/compact-log.jsonl`, specified
in requirements.md and design.md.

## Routes and Components

N/A — no change.

## API Client Strategy

N/A — no change: no network access is performed (REQ-007).

## Code Splitting and Size Budget

N/A — no change.

## Performance Budget

N/A — no change: no page metrics. Hook latency is bounded by deterministic
file reads/writes in the repository only; operational concerns are covered in
infra-spec.md.

## Empty, Loading, Error, and Success Behavior

Covered in ux-spec.md Component States (hook equivalents).

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| none new | — | Node standard library only | — | no new supply-chain surface |

## Testing

No frontend tests. Feature tests are enumerated in acceptance-tests.md
(TEST-001..TEST-012).

## Open Questions

- none
