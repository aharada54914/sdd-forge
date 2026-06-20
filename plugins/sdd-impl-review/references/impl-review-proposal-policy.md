# Implementation Policy Review Proposal Policy

Rules governing what proposed changes the implementation reviewers may suggest
when the verdict is NEEDS_WORK. Proposals are advisory only — humans implement
all changes.

## Guiding Principles

1. **No auto-fix.** Reviewers identify and describe problems; humans decide how
   to resolve them. A reviewer that rewrites design.md or silently corrects a
   section has violated its read-only contract.

2. **Reference, don't invent.** Every proposal must cite the specific section
   name and field being addressed (e.g. "## Data Plan › Migration Strategy").
   Proposals that reference vague locations ("somewhere in the design") are not
   actionable.

3. **No new sections invented.** Reviewers propose adding specified required
   sections (from the design template) that are absent. They must not invent
   non-standard sections.

4. **Constraint compliance requires policy citation.** Any proposal about
   `## Constraint Compliance` or `## Security Boundaries` must cite the specific
   requirement text from requirements.md that is unaddressed.

## Proposal Format

Each proposal in `design-round-N-proposed-changes.md` must follow this structure:

```
### Proposal: <Check-ID> — <Section> › <Field or Sub-section>

**Finding:** <What the reviewer found>

**Proposed Change:**
- Section: <exact section or field name>
- Current state: <absent / incomplete / inconsistent>
- Suggested direction: <description of what a correct entry would contain>
  (Do not write the exact corrected text — describe the intent; the human writes
  the final content.)

**Requirements Reference:** <cite REQ-NNN or AC-NNN if applicable>
**Constraint Reference:** <cite requirements.md constraint text if applicable>
```

## Scope Constraints

### What proposals MAY cover

- `## Architecture` — suggest adding missing elements (component boundaries,
  tech choices, integration description).
- `## Data Plan` — suggest adding `Data Entities:`, `Existing Data Affected:`,
  or `Migration Strategy:` sub-fields.
- `## API / Contract Plan` — suggest adding missing endpoints or schema fields.
- `## Security Boundaries` — suggest adding the section with specified content.
- `## Test Strategy` — suggest expanding to cover missing test levels.
- `## Deployment / CI Plan` — suggest adding migration execution order or
  feature flag strategy.
- `## Open Questions` — suggest adding owner or resolution path to existing
  questions.
- `## Assumptions` — suggest adding investigation.md grounding or accepted-risk
  marking.
- `## Architecture Decision Records` — suggest creating missing ADR files.
- `## Constraint Compliance` — suggest addressing specific unaddressed constraints.

### What proposals MUST NOT do

- Propose adding new functional requirements (those belong in requirements.md).
- Propose changing the feature's Risk classification at the design level.
- Write corrected design content directly into design.md (only humans write it).
- Waive or override a Critical or Major finding by reclassifying it as Minor.
- Propose changes to `requirements.md`, `tasks.md`, or `acceptance-tests.md`
  (those files are outside the scope of impl-review-loop).
- Propose architectural decisions that have not been discussed with the human
  (the reviewer identifies gaps, not solutions).

## Proposal Limit

Each round may include at most one proposal per failing check ID. Multiple
failing instances of the same check (e.g. multiple unjustified decisions) may
be listed together within a single proposal entry.

## Human Edit Acknowledgement

When the human re-invokes with `--edit-summary`, the orchestrator:
1. Computes the new design.md sha256.
2. Verifies it differs from the prior round sha256.
3. Records the edit summary in impl-review-contract.json.

If design.md is unchanged between rounds, the orchestrator rejects the
re-invocation with: "design.md sha256 unchanged since round N. Please edit
design.md before re-invoking."

## Escalation Path

If round 3 concludes with Critical or Major findings:
- The review loop reaches BLOCKED state.
- No further proposals are generated.
- The human must use `--reset` to start a new attempt.
- The root cause of persistent failures should be diagnosed before the new
  attempt; reviewers may not prescribe the diagnosis.
