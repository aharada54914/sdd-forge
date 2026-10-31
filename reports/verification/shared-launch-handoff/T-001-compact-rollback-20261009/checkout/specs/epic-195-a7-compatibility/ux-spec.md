# UX Specification: epic-195-a7-compatibility

N/A — no change: this feature has no UX surface. Design.md's Feature Type
header fixes this package as "test-infrastructure specification (Phase
1 — no code)" and its own Layer Specifications section already records
"UX: N/A — no GUI, view, dialog, menu item, or human interactive shell
surface. The only human-observable effects are suite pass/fail output
and CI job status, governed by acceptance-tests.md." This document
restates that determination in the review harness's canonical layer-file
shape; it introduces no UX judgment beyond what design.md already fixes.

Every deliverable this Phase 1 package specifies is a *design* for a
future implementation task: a canonical event-trace schema
(`compatibility-event-trace/v1`), additive extension points on five
already-existing test-infrastructure files, a golden-baseline
capture/promote script pair, a fixture-matrix builder, and a SKIP
allowlist manifest (design.md Components). None of these is an
interactive surface — every one is either a JSON/Markdown data
artifact or a Bash/PowerShell CLI script whose only observable output is
stdout text and an exit code, consumed by a test suite or a CI job, never
by a human operating a UI.

The nearest UX-adjacent surface is the diagnostic/verdict text a human or
implementation-phase agent reads at a terminal or in CI logs — suite
PASS/FAIL lines, `SKIP` lines with their cited issue-number template
string, and the `PROJECT_CONTEXT_INVALID` stop template string (design.md
Data Plan, "Per-kind producer call sites," `skip-stop-message` row). This
is CLI/test-runner output, not an interactive UI, and its exact wording
is fixed by design.md's Data Plan and API / Contract Plan, not this
document's scope to restate.

- Target views / navigation / component states / interaction sequence /
  responsive behavior / design tokens / accessibility: N/A — no change
  (no UI exists for this feature to specify).

## Wireframe Attachments

None — manual visual refinement skipped (no UI to mock up).

## Open Questions

- None.
