# UX Spec: review-cross-critique

## Scope and User Journeys

**No GUI, web, or desktop surface — but not fully N/A, and the difference
matters.**

This feature has no rendered, interactive, or graphical surface. It changes
agent-orchestration prose, deterministic shell/PowerShell gates, and JSON
artifacts. Recording it as a flat `N/A` would be wrong, though, because the
review loop already has one deliberately human-facing artifact and this feature
would change what appears in it.

### The one human-facing surface: the rendered review report

`plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md:277-288` specifies what
the loop must always show a human, using
`plugins/sdd-review-loop/templates/impl-review-report.template.md`:

> 1. Verdict (PASS / PASS-with-warnings / NEEDS_WORK / BLOCKED)
> 2. Round and attempt numbers.
> 3. All reviewer-a findings that are FAIL.
> 4. All reviewer-b findings that are FAIL.
> 5. Proposed changes (if NEEDS_WORK).
> 6. Next steps instruction.

`task-review-loop/SKILL.md:304-315` carries the identical requirement. On
NEEDS_WORK the human is handed a `*-round-<N>-proposed-changes.md` file and is
expected to edit the spec from it (`impl-review-loop/SKILL.md:220-226`).

That is the surface a human actually reads to decide what to change. A
cross-critique phase adds a second layer of judgement about the same findings —
a `SUPPORT` and a `REJECT` on the same finding, from two reviewers who disagree.
How that reaches the human is a real presentation decision, and it is
**undetermined**:

- If cross-critique is advisory only (one resolution of OQ-7), the human sees a
  finding that stands, annotated with a peer's rejection of it. Whether that
  makes the report more useful or merely louder depends entirely on how the
  disagreement is displayed.
- If a `REJECT` can retire a finding (a different resolution of OQ-7 and OQ-8),
  the human sees fewer findings — and the report must make it visible that a
  finding *was* raised and *was* retired, otherwise the gate silently drops
  evidence. `skills/adversarial-review/SKILL.md:38` states the source protocol's
  answer for its own report format: "Rejected findings stay in the report with
  the rejection reason." That is prior art, not a decision this document may
  adopt on the issue's behalf.

**No presentation is specified here.** It follows OQ-7, OQ-8 and OQ-14, and is
recorded so a task author does not discover at implementation time that the
report template has an unspecified new section.

### Design tokens

`ds_profile: none`. There is no design system, no token set, and no visual
artifact in scope. Recorded explicitly rather than omitted, per the interviewer's
requirement to record the profile choice
(`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:76-87`).

### Shell reachability

No new user-facing entry point is added. The three review loops are invoked
exactly as they are today —
`/sdd-review-loop:{spec,impl,task}-review-loop --feature <slug>`
(`impl-review-loop/SKILL.md:21-24`) — and this feature adds no command, flag, or
menu affordance of its own under any resolution currently on the table. If a
resolution of OQ-4 introduces a new invocation flag, this section must be
revisited before Phase 2.

No mockup provided — optional visualization skipped.
