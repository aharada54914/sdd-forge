# ADR-0002: Repository-wide workflow-state integrity

- Status: Proposed
- Date: 2026-06-27
- Feature: `workflow-state-integrity`

## Context

Stage prechecks protect individual review transitions, but persisted repository
state is not revalidated as a complete chain. The repository currently contains
historical artifacts that cannot satisfy today's review provenance contract.

## Decision

Adopt a versioned registry covering every specification directory and validate
it with portable shell and PowerShell gates. Strict full-profile features must
prove ordered Spec, Impl, and Task PASS states with current review contracts.
Lite features remain explicitly isolated. Historical artifacts use narrow,
auditable legacy entries tied to a fixed migration cutoff; no review evidence
is fabricated.

The integrity gate runs in repository validation, CI, downstream review
prechecks, and the full quality gate.

## Consequences

- Invalid persisted state becomes a branch-blocking error.
- Adding a spec directory requires a registry entry.
- Historical debt remains visible and cannot silently expand.
- Two runtime implementations and parity tests are required.
- The release is revised from 1.2.0 to 1.3.0.

## Rejected alternatives

- **Rewrite historical headers to Passed:** rejected because it creates false
  provenance.
- **Grandfather every missing header implicitly:** rejected because new work
  could bypass enforcement by omission.
- **Validate only at transition time:** rejected because merges, old tools, and
  manual edits can introduce persisted inconsistencies.
- **Use only one runtime:** rejected because Windows and POSIX are supported
  enforcement surfaces.
