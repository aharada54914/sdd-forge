# Proposed design.md changes: impl-review attempt 3, round 1

Verdict: NEEDS_WORK (reviewer A PASS; reviewer B 1 Major FAIL,
NO-REQ-CONTRADICTION). Amendment re-review context: this attempt runs
under the human-approved amendment lane (`--provenance-rereview`,
investigation.md `## Amendment Re-Review Context`); reviewer B applied
the lane correctly and explicitly ruled this finding is NOT the
suppressed amendment-supersession class — it is an internal
contradiction inside the currently pinned package.

## The finding (reviewer B, NO-REQ-CONTRADICTION, Major)

design.md's `Global Constraints` section (design.md:1054-1065) states,
without qualification or an amendment pointer:

- "No edits to `plugins/**`, `scripts/**`, `.github/**`, `tests/**`,
  `contracts/**`, or `docs/**` in this task."
- "No tasks.md/traceability.md in this Phase 1 package."

Both statements are contradicted, inside the same reviewed package, by
investigation.md's `## Amendment Re-Review Context` (commit
`7652d01b3a152863afefd38bd11e1bac5767e3de` edited
`tests/lib/loop-driver.{sh,ps1}` and `tests/loop-inventory.tests.{sh,ps1}`;
tasks.md/traceability.md/traceability.json exist and are hash-cited).
requirements.md's Overview reconciles the identical tension with a dated
amendment-note pointer; design.md carries no equivalent.

## Proposed remedy (for human authorization — not applied)

Mirror the treatment the human already approved for requirements.md's
Overview/Non-goals: add a dated amendment-note pointer to design.md's
`Global Constraints` section stating that the constraint list described
this package at authoring time, and pointing at investigation.md
`## Amendment Re-Review Context` for the commit/SHA-256-cited record of
the later-phase work (including the `7652d01b` tests/** edits and the
existing tasks.md/traceability files). Do not rewrite or delete the
original constraint text. This is a frozen-document (design.md)
amendment: it changes the hash the terminal impl contract will pin, and
per the standing approval's scope it needs explicit authorization before
an orchestrator may apply it — reported upward rather than remediated
unilaterally.
