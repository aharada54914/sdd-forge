# ADR-0004 DDD upstream domain lane as a seventh plugin

## Status

Accepted

## Context

sdd-forge generates feature-scoped specifications with no upstream domain
model. On large systems with complex business logic, terminology drifts
across features, aggregate boundaries are re-derived per design.md, and
context relationships stay implicit. Marketplace prior art (2026-07-03
survey) offers standalone DDD skills but none integrated with an SDD
framework's contracts and review gates. LLMs are effective at early domain
understanding (term extraction, event discovery, context clustering), while
final domain-model and architecture decisions require human review — the
workflow must encode that division of labor.

Alternatives considered: (B) an independent general-purpose `ddd-forge`
plugin — rejected: duplicates review-loop/guard/contract infrastructure;
(C) extending bootstrap's project mode — rejected: the domain model would be
buried in one feature's spec, losing cross-feature governance of the
ubiquitous language and context map.

## Decision

Add `plugins/sdd-domain` as the seventh plugin: an opt-in upstream lane with
one public skill (`domain-model`) orchestrating a seven-stage pipeline —
Domain Story, Event Storming, Ubiquitous Language, Context Map, Domain Model
(aggregates), Domain Message Flow, C4 Container — producing Markdown
artifacts plus a machine-readable `domain/domain-contract.json`
(`domain-contract/v1`). The gate reuses the independent two-reviewer loop
(≤3 rounds) and integrates cross-model verification before a human-only,
hook-guard-protected approval (`Domain-Model-Status: Approved`). Downstream,
`domain-sync` injects approved context/terms into bootstrap Phase 1 and
`check-domain-conformance` runs at quality-gate as warn, escalating to error
two releases later by human edit. Absence of `domain/` disables the lane
entirely. Input modes: interview, existing documents, and reverse-generation
from code via investigate-codebase.

## Consequences

- Plugins 6 → 7, skills 21 → 26, public skills 5 → 6; all manifests
  version-bump together; validate-repository expectations change.
- New protected-surface work: hook-guard extension and validate-repository
  edits follow the protected-file procedure.
- Cross-model panel cost added at the domain gate (once per review-loop
  PASS); unavailable panelists fail toward `requires_human_decision`.
- The unidirectional flow gains one upstream stage; feedback from
  implementation returns only via WFI/diagnose into a `domain-model update`
  run.
- Future work (deferred): lexical-variant conformance matching, per-context
  re-approval, CQRS/Event Sourcing support, lite-track integration.
