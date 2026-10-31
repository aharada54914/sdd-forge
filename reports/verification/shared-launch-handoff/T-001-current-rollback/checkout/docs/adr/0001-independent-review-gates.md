# ADR-0001: Add an independent specification-review gate

## Status

Accepted

## Context

The full SDD workflow required `spec-review-loop` before implementation-policy
review, but no such skill existed. The resulting dead end could be bypassed by
hand-writing a status field, which defeats the workflow's review assurance. The
repository maintainer also requires specification, implementation-policy, and
task reviewers to be independent agents.

## Decision

Add `spec-review-loop` to `sdd-review-loop`, with two new read-only reviewers:
`spec-reviewer-a` and `spec-reviewer-b`. Keep these definitions, their report
paths, and their fresh execution contexts distinct from `impl-reviewer-a/b` and
`task-reviewer-a/b`. A review-loop state machine, not a reviewer, is the only
writer of a Passed status after a verified integrated verdict.

Contract verification is an integrity check for local artifact consistency:
schema, stage, feature, attempt, round, input hash, run identifier, and verdict
must agree. It is not a claim to protect evidence from an actor with unrestricted
local filesystem write access. The host runtime supplies fresh-agent isolation;
the plugin supplies distinct agent definitions, declared path restrictions, and
structural tests for those declarations.

## Alternatives considered

- Remove the missing prerequisite and begin with implementation-policy review.
  Rejected because it reduces the workflow's advertised independent
  specification-review assurance.
- Reuse implementation-policy reviewers for specification review. Rejected
  because it violates the required separation of reviewer responsibilities and
  would mix incompatible evidence scopes.

## Consequences

- Phase 1 gains a required, persisted review gate before design review.
- All prechecks must validate predecessor status and contracts instead of
  trusting an editable header.
- The plugin gains reviewer definitions, scripts, templates, documentation, and
  cross-platform tests.
- Existing workflow diagrams and references must show the additional gate.
- The release smoke records skipped host discovery separately from a successful
  discovery assertion.
