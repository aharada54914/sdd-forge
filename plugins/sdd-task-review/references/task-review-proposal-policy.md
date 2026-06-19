# Task Review Proposal Policy

Rules governing what proposed changes the task reviewers may suggest when the
verdict is NEEDS_WORK. Proposals are advisory only — humans implement all changes.

## Guiding Principles

1. **No auto-fix.** Reviewers identify and describe problems; humans decide how
   to resolve them. A reviewer that rewrites tasks.md or silently corrects a
   field has violated its read-only contract.

2. **Reference, don't invent.** Every proposal must cite the specific task ID
   and field name being addressed (e.g. "T-003 › Blockers"). Proposals that
   reference vague locations ("somewhere in the tasks") are not actionable.

3. **No new tasks.** Reviewers may propose modifications to existing tasks only.
   If a gap is so severe that it cannot be addressed by modifying existing tasks,
   the finding is BLOCKED (not a proposal for new tasks). The human decides
   whether to add tasks.

4. **Risk tier changes require policy citation.** Any proposal to change a task's
   `Risk:` or `Required Workflow:` field must cite the specific surface or rule in
   `plugins/sdd-quality-loop/references/risk-classification-policy.md` that
   justifies the change.

## Proposal Format

Each proposal in `tasks-round-N-proposed-changes.md` must follow this structure:

```
### Proposal: <Check-ID> — <Task-ID> › <Field>

**Finding:** <What the reviewer found>

**Proposed Change:**
- Field: <exact field name>
- Current value: <current field content>
- Suggested direction: <description of what a correct value would look like>
  (Do not write the exact corrected text — describe the intent; the human writes
  the final value.)

**Policy Reference:** <If risk change: cite risk-classification-policy.md section>
```

## Scope Constraints

### What proposals MAY cover

- `Blockers:` field — correct format or add/remove a T-NNN reference.
- `Done When:` items — replace vague verbs with observable criteria; remove
  duplicate items; add missing mandatory items for high/critical tasks.
- `Requirements:` field — add missing REQ-NNN or AC-NNN references.
- `Risk:` and `Required Workflow:` fields — with mandatory policy citation.
- `Scope` section — suggest splitting or tightening the description.
- `Rollback:` field — suggest adding rollback evidence.
- `Status:` and `Approval:` fields — only to correct back to Draft/Planned if
  incorrectly set (these are human-only fields; proposals to change these are
  informational only and require human action).

### What proposals MUST NOT do

- Propose adding a new `## T-NNN` task section.
- Propose deleting an existing task (suggest scope reduction instead).
- Write corrected task text directly into tasks.md (only humans write the file).
- Waive or override a Critical or Major finding by reclassifying it as Minor.
- Propose changes to `requirements.md`, `design.md`, or `acceptance-tests.md`
  (those files are outside the scope of task-review-loop).

## Proposal Limit

Each round may include at most one proposal per failing check ID per task.
If a check fails for multiple tasks, list each separately. Do not merge
proposals for different tasks into a single entry.

## Human Edit Acknowledgement

When the human re-invokes with `--edit-summary`, the orchestrator:
1. Computes the new tasks.md sha256.
2. Verifies it differs from the prior round sha256.
3. Records the edit summary in task-review-contract.json.

If tasks.md is unchanged between rounds, the orchestrator rejects the re-invocation
with: "tasks.md sha256 unchanged since round N. Please edit tasks.md before
re-invoking."

## Escalation Path

If round 3 concludes with Critical or Major findings:
- The review loop reaches BLOCKED state.
- No further proposals are generated.
- The human must use `--reset` to start a new attempt.
- The root cause of persistent failures should be diagnosed before the new
  attempt; reviewers may not prescribe the diagnosis.
