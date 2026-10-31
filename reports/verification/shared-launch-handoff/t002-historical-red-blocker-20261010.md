# T-002 historical RED blocker — 2026-10-10

This is a continuation note, not a quality-gate verdict or task-state change.

## Scope and current decision

The user's substitute-evidence approval applies only to RT-20261009-001.
That ticket is resolved locally; its adoption record is
`rt-20261009-001-substitute-evidence-approval.md` in this directory.
It does not waive the separate T-002 evidence requirement.

The latest completed formal T-002 evaluator delivery is
`reports/quality-gate/launch-f9e74c8f-6720-4304-b098-1c3c6b1184c6/wrapper.json`.
Its result is NEEDS_WORK with one Major and three Minor findings. The Major
concerns missing retained pre-fix RED evidence for AC-004 (TEST-007 and
TEST-008a–d), not a newly identified runtime defect.

## Evidence and dependency boundary

`specs/shared-review-launch-repair/tasks.md:12` requires retained pre-fix RED
evidence for each task; its T-002 Done When also requires RED-to-GREEN evidence.
`specs/shared-review-launch-repair/verification/T-002/historical-red-recovery-20261010.md`
distinguishes authentic AC-005 structural RED from traceability fixture setup
failures. The latter do not demonstrate an AC-004 product failure before repair.
Passing current tests and disposable restoration cannot prove historical order.

The plan requires T-001 → T-005 → T-002 → T-003 → T-004. T-002 remains
Implementation Complete, not Done. No new reviewer identity is reserved merely
to repeat an unchanged evidence question. No frozen artifact or old verdict is
rewritten. T-003 and integrated delivery remain dependency-blocked.

## Exact reopening condition

Either locate authentic retained pre-fix AC-004 failure evidence, or obtain a
T-002-specific change to the evidence contract and have that amendment formally
rebound and independently evaluated. A retrospective reproduction must be
explicitly labeled as such; the RT-20261009-001 exception is not transferable.

Commit, push, exact-head CI, merge and post-merge validation remain unperformed.
The later four-point architecture change still waits for the first integration.
