# ADR-0033: Worktree-local context continuity

Status: Proposed
Date: 2026-09-27
Feature: sdd-context-continuity

## Context

Issue #137 requires recoverable local conversation evidence without replacing
current specs/tasks or native compact. The user selected redaction, 30-day
expiry/deletion and warning/continued work on capture failure. Native lifecycle,
durability and scheduler capabilities still require actual verification.

## Decision

Use short-lived bundled Node adapters and a private, redacted worktree-local
JSONL source journal. Derived views are disposable; the existing transport-free
task parser reads current authoritative files. Separate Claude/Codex adapters
validate their actual native schemas. An owning-account OS daily oneshot cleans
only registered owned stores, including inactive worktrees, with catch-up on
return. No daemon, cloud, paid service, new package, public command or MCP tool.

## Alternatives and rationale

- Host transcript dependence alone cannot provide owned deletion or consistent
  recovery coverage; exposed transcripts remain reconciliation inputs only.
- A shared repository journal crosses worktree/session privacy boundaries.
- A database/daemon adds lifecycle and deployment burden without a demonstrated
  need. JSONL plus one bounded per-worktree lock is sufficient for this scope.
- Task/spec mutation or compact replacement would change authority and host
  behavior; both are excluded.

## Consequences

Source remains recoverable when extraction fails, but unknown native capability,
storage failure or missing scheduler leaves continuity unavailable, not a false
success. Redaction is bounded, not complete DLP; removed spans are unrecoverable.
Read-time expiry prevents reinjection even when physical deletion fails. Actual
OS tests must establish durability/catch-up limits before completion. Rollback
must preserve owned expiry cleanup until residual content is removed.

The design and four layer specifications define contracts and acceptance links;
this Proposed ADR neither approves implementation nor claims successful tests.
Reverify shared identifier uniqueness before review/integration.
