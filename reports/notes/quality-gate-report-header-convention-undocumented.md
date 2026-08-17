# Defect note: quality-gate report header convention is undocumented

Found: 2026-07-23, during epic-190-a2-capability-registry T-001's quality
gate (persisting `reports/quality-gate/2026-07-23T003000Z.md`,
`specs/epic-190-a2-capability-registry/verification/T-001.{contract,evidence}.json`).

## What happened

The evidence-bundle validator (`plugins/sdd-quality-loop/scripts/
check-evidence-bundle.sh`) unconditionally (regardless of risk tier)
requires the bound `quality_report` file to contain three literal,
unprefixed lines, matched by exact regex:

- `^Task ID:\s*<task_id>\s*$`
- `^Feature:\s*(.*?)\s*$` (exactly one match)
- `^VERDICT:\s*PASS\s*$`

Neither `AGENTS.md`'s "Evidence report identity fields" section (which
documents only a `Task: T-NNN` line and a `Run ID:` line) nor the
`sdd-evaluator` role file's (`plugins/sdd-quality-loop/agents/evaluator.md`)
Output Format template (`VERDICT: PASS | NEEDS_WORK`, `RUN_ID:`,
`HOST_SESSION_ID:`, `ALLOWED_INPUT_MANIFEST:`, `FINDINGS:`, `CHECKED:`)
documents this exact unprefixed-header requirement. A first, otherwise
substantively correct quality-gate report -- following AGENTS.md's
documented convention with a bulleted field list (`- Task: T-001`,
`- Feature: ...`, `- Verdict: PASS`) -- failed
`check-evidence-bundle.sh` with all three of the above errors. The gap was
only discoverable by reading the validator's source directly (or, as here,
by an existing precedent report) -- not from either documented convention.

## Working precedent (undocumented but real)

118 files under `reports/quality-gate/*.md` already satisfy
`^VERDICT: PASS$` literally. One inspected example,
`reports/quality-gate/20260719T055902Z-epic-159-pillar-c-T-005.md`, carries
both conventions side by side as separate, unprefixed lines:

```
Task: T-005
Task ID: T-005
Feature: epic-159-pillar-c
Run ID: RUN-epic-159-pillar-c-qg-T-005-seq0302
Evaluator Host Session: SESS-qg-epic-159-pillar-c-T-005-0302
VERDICT: PASS
```

## Resolution for this task

The evaluator re-emitted the report with this exact unprefixed header block
prepended (same session/transcript, content after the `# Quality Gate
Report` heading byte-identical to the first version -- verified
programmatically, zero change to findings/verdict/wording). The corrected
version is what is committed as `reports/quality-gate/2026-07-23T003000Z.md`.

## Recommendation (not actioned here -- out of T-001's scope)

Document the exact required unprefixed header block (`Task:`, `Task ID:`,
`Feature:`, `Run ID:`, `VERDICT: PASS`) in one of: `AGENTS.md`'s "Evidence
report identity fields" section, the `sdd-evaluator` role file's Output
Format template, or `quality-gate/SKILL.md` step 15. Ideally as a small,
shared report-header template file both role files and SKILL.md can point
to, so the requirement lives in one place instead of being re-derived from
`check-evidence-bundle.sh`'s source on each occurrence. This is the same
class of drift as the `implementation-report.template.md` vs.
`tests/turn-first-workflow.tests.sh` mismatch (`## Outputs` vs. `##
Output Paths And Hashes`) found earlier in this same task's implementation
report -- a validator and its producing template/role-file have drifted
apart without either being updated to match the other.
