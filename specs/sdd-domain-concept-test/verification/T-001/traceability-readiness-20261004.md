# T-001 traceability readiness (2026-10-04)

This is a T-001 verification addendum, not the feature-level `traceability.json` and not a quality-gate verdict.

## Current-source raw results

- `sidecar-bash-current-20261004.log`: `rtk proxy bash tests/validate-approval-sidecar.tests.sh`, exit 0, 113 PASS / 0 FAIL on macOS.
- `sidecar-pwsh-current-20261004.log`: `rtk proxy pwsh -NoLogo -NoProfile -File tests/validate-approval-sidecar.tests.ps1`, exit 0, 112 PASS / 0 FAIL on macOS.
- These files contain complete stdout from this run. Both show TEST-001/006 at line 48, signed non-FITS positives at lines 49–57, missing-decision negatives at lines 58–60, sidecar/signature negatives at lines 65–69, input failures at lines 70–71, and four proposal-class decision mismatches at lines 80/87/94/101. They prove validator-side behavior only, not bootstrap downstream-call assertions, native Windows, CI, or an independent quality gate.

## Genuine T-001 mapping and limits

| Requirement and AC | TEST evidence in both raw logs | Boundary |
| --- | --- | --- |
| REQ-001 / AC-001–004 | TEST-001–004, lines 48 and 58–60 | Contract and validator evidence; proposal authoring is T-002. |
| REQ-003 / AC-005–007, AC-014–016 | TEST-005–007, TEST-014–022, TEST-028–037, TEST-051–078, lines 48–101 | Only the validator assertion of mixed bootstrap/validator TESTs is exercised; downstream-call count zero is T-003. |
| REQ-002 / AC-008–009 | No T-001 test evidence | Human confirmation workflow and domain immutability are T-002; relation enum validation is not equivalent. |
| REQ-004–006 | No T-001 test evidence | T-003/T-005, T-004, and T-006 respectively. |

The frozen `traceability.md:8–13` maps all six feature requirements and future tasks. `specs/risk-adaptive-layer/design.md:143–155` defines one feature-level `specs/<feature>/traceability.json` and requires every REQ → AC → TEST → evidence. `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:84–86` names that exact feature-level path for high-risk tasks. `plugins/sdd-quality-loop/scripts/check-traceability.sh:26–29,60–96` verifies only links present in JSON, so a T-001-only file at the feature-level path could return success despite silently omitting REQ-002/004–006. That would be misleading and has not been created.

Minimum safe contract repair, if T-001 must reach a quality gate before future tasks: explicitly permit a task-local `verification/T-001-traceability.json`, use the existing checker unchanged for link structure and evidence-file checks, then require the independent evaluator to compare every current-task expected REQ/AC/TEST assertion against the approved task and frozen acceptance plan and to record future assertions as pending. Preserve the feature-level complete mapping requirement for later feature completion. This needs a separately reviewed quality-gate contract change and focused regressions, not a new generic checker; merely writing a partial file at the existing feature-level path does not repair the contract. Until then, T-001 remains In Progress; no Implementation Complete or Done claim follows from these logs.

## Existing high-risk precedent and dependency cycle

No `task_id`, expected-ID list, or task filter is accepted by the current checker CLI (`check-traceability.sh:3,14–25`), and the quality-gate skill's high-risk call specifies the feature-root file (`quality-gate/SKILL.md:84–86,284`). `require-evidence` applies to every link, not only the current task (`check-traceability.sh:82–87`). The per-task `verification/<task-id>.evidence.json` described beside it is a separate bundle, not a task-scoped traceability filter.

One superficially similar high-risk case is Epic A7 T-002 (`specs/epic-195-a7-compatibility/tasks.md:249–258`). Its quality report says PASS, but the later backfill README explicitly records that the first three gates never created the required machine-readable traceability file (`verification/qg-backfill/README.md:1–22`). The subsequently derived feature-root JSON says it carries evidence only for Done rows (`traceability.json:2–4`); the current strict checker on that file exits 1 for REQ-002/003/004/007 missing evidence. It is therefore a historical gap, not a sound precedent for declaring a partial feature mapping high-risk PASS.

For this feature, `tasks.md:109–116` gives T-002 a T-001 blocker, while `tasks.md:126–165` gives T-003 the later bootstrap assertions. `sdd-ship/skills/ship/SKILL.md:271–286,333` sequences task completion through Done before advancing. If the high-risk gate demands existing evidence for every future feature REQ, T-001 Done requires evidence owned by T-002–T-006, but those tasks cannot all be completed before T-001 Done. The cycle is in the gate contract, not a reason to fabricate future links or weaken their acceptance criteria.

## RT002 task-local precedent recheck (2026-10-04)

The current source checkout at `/Users/jrmag/sdd-forge` contains `specs/epic-189-a1-rt002-repair/verification/T-001-traceability.json` with five REQ-001–004/AC-001–005 links and no REQ-005/AC-006 final-release link. The existing checker, invoked read-only with `require-evidence`, returned `Traceability check passed for epic-189-a1-rt002-repair: 5 link(s).` This is a *structural task-local* success, not a new task-aware checker contract: `verification/T-001-results.md:186–188` expressly says it checks structure and evidence-file presence, not independent acceptance or bundle readiness, and `tasks.md:70–72` still requires an independent task-scoped quality gate. Its T-001 remains In Progress (`verification/T-001-results.md:172–180`). Thus it supports reusing the existing JSON shape and checker for a bounded supplementary artifact, but not interpreting that output as feature-complete PASS or automatically satisfying #290 T-001's high-risk gate.

For #290, the reviewed primary ownership AC-001–007/014–016 expands to TEST-001–007, TEST-014–022, TEST-028–037 and TEST-051–078. A read-only label inventory of both current sidecar logs, expanding their combined labels `TEST-001/006` and `TEST-037/078`, found zero missing IDs in that expected set. This verifies output labeling only. In particular, TEST-022 and TEST-051–078 retain unexecuted bootstrap/zero-downstream-call clauses, so the log-label inventory and any task-local JSON must not assert complete original TEST acceptance. T-002–T-006 remain Planned and feature traceability remains pending.

Sensitivity check on that label inventory: an in-memory mutant that removed `TEST-028` from the Bash label stream yielded exactly `TEST-028` as missing; no saved log was edited. This confirms the inventory catches a missing owned ID, but does not upgrade label presence to semantic acceptance.

The minimal next artifact may be a task-local `verification/T-001-traceability.json` using the existing RT002 JSON shape, but it must cite only evidence actually proved and be accompanied by this pending-assertion disclosure. The unchanged checker can validate its structure and nonempty evidence files; independent evaluator inspection must still reject omissions from the reviewed task scope and false full-TEST claims. A canonical quality-gate contract amendment is needed before a task-local check may replace the current feature-root requirement in `quality-gate/SKILL.md:84–86,284` or the `requirement-traceability` meaning in `risk-gate-matrix.md:124–125`. No such substitution or Done decision is made here.

## Superseding workflow finding: task-plan-only route (2026-10-04)

The preceding paragraphs analyze a *per-task early quality gate*. They do not establish that the feature-wide quality-gate contract must change. Rechecking `plugins/sdd-implementation/skills/implement-tasks/SKILL.md:72–79,235–258` shows a blocker is satisfied by `Implementation Complete` **or** `Done`, and the batch does not start quality-gate until **all** approved tasks are Implementation Complete/Done. `plugins/sdd-ship/skills/ship/SKILL.md:269–291` has the same implementation-before-QG order. Thus T-001 may reach Implementation Complete on truthful validator-only evidence, T-002/T-003 may then supply the missing bootstrap evidence, and the existing high-risk QG can run later on a genuinely complete feature-root `traceability.json`. The earlier assertion that T-001 Done is required to start T-002, and the consequent claim that a shared QG change is unavoidable, are superseded by this source check.

The remaining task-plan gap is to make T-001's shared TEST scope and post-IC QG timing explicit, and to assign final full-feature traceability assembly and frozen-table comparison to the last dependent task. A one-file unapplied candidate with those exact amendments and successful `patch --dry-run` is `/tmp/sdd290-task-only-traceability-cycle-candidate-20261004.md`. It leaves the shared QG skill and checker unchanged. This addendum is not the amended canonical plan or a new provenance review; T-001 is still In Progress and no partial file is being passed off as feature-complete.
