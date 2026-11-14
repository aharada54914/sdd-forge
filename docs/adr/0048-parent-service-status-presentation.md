# ADR 0048: Parent service owns status presentation

Status: Accepted for implementation by the user's 2026-11-05 request.
Native Claude publication remains unverified in the current ChatGPT session.

## Context

The user requested the six Jira-style views, automatic updates and honest
freshness/failure states in either Sites or Claude Artifacts, selected by the
service that initiated SDD. Workers may use another service. Existing state and
validation live in files and guarded MCP operations (`mcp/sdd-forge-mcp/src/server.ts`,
`src/tools/core.ts`, `src/parsers/tasks.ts`). Re-check these shared interfaces
against the consuming revision before extending them.

## Decision

The parent binds ChatGPT to Sites and Claude to Artifacts before delegating.
Unknown/unavailable parents report an unsupported presentation rather than
inferring service from a worker or CLI name. No Plane migration or task-write
interface is introduced. Both renderers use the versioned `sdd-dashboard/v1`
snapshot, available through a new read-only MCP tool and independent CLI stream.

Sites uses a private Worker and R2 snapshot, updated by a separately authenticated
collector. The browser polls the snapshot, while source observation timestamps
come from the collector. Hosted HTTP success cannot freshen an unchanged cached
source. A stopped collector becomes stale after 60 seconds.

Artifacts HTML exposes an explicit SDD-owned reader callback, bound by the
Claude parent to its actual declared connector API. Native capability discovery,
consent and publication belong to that parent. Local stdio registration cannot
stand in for a remote connector, and tests cannot stand in for native host proof.

Two complete observations must agree before a snapshot is promoted. Source
read failures retain last-good data and its timestamps. SHA-256 includes source
content so equal-size/equal-mtime changes are detected. This is a bounded
consistency check, not filesystem transactional isolation.

## Alternatives and consequences

A separate management database would duplicate workflow authority. Static
uploads on assistant turns recreate the stale-screen problem. A shared display
model plus service-specific transport preserves the existing gate semantics
and allows independent testing. Runtime credentials and collector lifetime need
operational ownership; no credentials are stored in the package. Existing
`--status-ui` and MCP tool contracts remain compatible, with one additive tool.

The read-model's report lookup is reused only within each full observation;
independent observations have independent caches. No cache survives to hide
changes between samples. Detailed failures remain separate from declared task
status. Release membership uses an explicit optional `Release:` field and never
implies deployment/publication.

## Verification and rollback

See `reports/verification/hosted-status-views-20261105/README.md` for actual checks
and the native-Claude limit. Stop the collector and revert this task's code to
restore the old presentation. Existing source tasks, approval, evidence, review
history and gate verdicts require no migration or rollback edits. Disable the
Site separately if desired; do not expose a private Site to solve authentication.
