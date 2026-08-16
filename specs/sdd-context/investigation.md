# Investigation: sdd-context

Source Issues: https://github.com/aharada54914/sdd-forge/issues/137

## Purpose

`design.md` accepted three assumptions from `requirements.md`. This
investigation grounds those assumptions in observable, local repository
evidence so implementation-review can treat them as deliberate technical
defaults rather than unverified claims.

## Findings

### INV-001 — Hook runtime input contract

`requirements.md` Field Definitions specify that hook runtimes provide a
`source` string and optional `auto_compaction` and `compact_summary` inputs.
The `sdd-context` design consumes only these documented fields and ignores all
other input. No local SDK or runtime implementation is bundled with this
repository, so the contract is accepted as the plugin's public hook interface
rather than verified against a vendored runtime.

Decision: proceed with `source` as required and `auto_compaction` /
`compact_summary` as optional. Unknown fields are ignored. A missing `source`
is a warning plus exit 0, not a blocking failure.

### INV-002 — Node 18+ implementation runtime

The single deterministic Node core is the only runtime dependency and uses
Node 18+ built-ins only. The wrapper layer performs no logic beyond `node`
detection and argv normalization. The repository has no vendored Node binary;
if `node` is absent on PATH, the wrapper must exit 0 and emit at most a
warning (REQ-006 / AC-010).

Decision: Node 18+ is an accepted implementation-runtime assumption. Missing
Node is a graceful, non-blocking no-op; no snapshot is produced for that
compaction event.

### INV-003 — Write-path gitignore layout

`design.md` constrains all writes to `.sdd/context/` (working handoff files)
and `reports/context/` (committable report files). `.sdd/` is runtime-local
state and must be git-ignored; `reports/` is an existing repository-artifact
tree that remains committable. REQ-007 confines writes to these two paths
regardless of gitignore configuration.

Decision: add `.sdd/context/` to the repository `.gitignore` during
implementation and keep `reports/context/` committable. No protected SDD
source or state path is written.
