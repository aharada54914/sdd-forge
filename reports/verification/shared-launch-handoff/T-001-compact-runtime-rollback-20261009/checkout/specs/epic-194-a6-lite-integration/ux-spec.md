# UX Specification: epic-194-a6-lite-integration

N/A — no change: this feature has no UX surface. Every deliverable this
Phase 1 package produces is a *design* (schema fragment, catalog seed,
CLI contract extension, gate-process extension, human-copy runner
contract) for artifacts that are themselves non-interactive: a JSON
Schema fragment (`lite_policy.required_lite_checks`), a new small JSON
catalog (`contracts/lite-check-catalog.json`), a `catalog_version` bump
to an existing JSON catalog (`lite-upgrade-reason-catalog.json`), a CLI
exit-code/stdout contract extension for `check-risk-upgrade.{sh,ps1}`,
and a Markdown gate-process extension for `lite-gate/SKILL.md` and
`lite-spec/SKILL.md` (design.md Feature Type header: "an additive
schema-revision *design*... a documented (not implemented) extension to
two already-protected `sdd-lite` scripts/policy files... and one
already-protected skill... and a documented extension to one
currently-unprotected skill"; design.md Layer Specifications: "this
feature ships no UI and no new infrastructure"). No script this design
touches is authored live by this package at all (requirements.md
Non-goals) — every edit is a design target for a future implementation
task.

The nearest UX-adjacent surface is the diagnostic text a human or
implementation-phase agent reads at a terminal (`lite-eligible` /
`full-required: <reason>; triggers=...` / `VERDICT: FAIL` reasons at
`lite-gate`) — this is CLI/skill-process output, not an interactive UI,
and its exact wording is fixed by design.md's API / Contract Plan, not
this document's scope to restate.

- Target views / navigation / component states / interaction sequence /
  responsive behavior / design tokens / accessibility: N/A — no change
  (no UI exists for this feature to specify).

## Wireframe Attachments

None — manual visual refinement skipped (no UI to mock up).

## Open Questions

- None.
