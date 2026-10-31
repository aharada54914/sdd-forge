# A8 recovery dependencies: current contract check

2026-10-05. Supplemental read-only audit; no formal verdict, product implementation, reservation or native launch. Existing dirty files preserved. The verification-apply skill was used to distinguish applied A8 recovery from unapplied shared consumers and unapproved guard implementation.

## A8 report cannot be substituted by this coordinator

`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:176-192` explicitly prohibits adding historical provenance to the frozen report, requires a fresh isolated implementation context, actually observed run/session IDs and scratch root, and independent comparison before canonical promotion. Lines 203-206 require the task-input manifest to agree with report task/run/session. The already-applied A8 recovery contract is sufficient authority for that recovery shape; another general approval is not being requested. This long-lived coordinator cannot create its fresh implementation evidence or silently import the older panel verdicts.

## Shared read-policy is not merely awaiting one installation

Source root: `/private/tmp/sdd-guard-main.3JEj4I/repo`.

- `specs/guard-role-read-regression/requirements.md:3`: `Spec-Review-Status: Pending`.
- `specs/guard-role-read-regression/design.md:3`: `Impl-Review-Status: Pending`.
- `reports/verification/read-policy-implementation-boundary-20261004.md:59`: `No Approved implementation task exists in this spec directory yet.` Current bounded file inventory confirms no tasks.md.
- The same boundary, lines 12-24, requires complete-invocation classification across existing runtimes rather than another prefix exception. Thus an ad hoc nonprotected helper cannot legitimately repair the protected guard.
- `contracts/spec-review-prelaunch-recovery.v1.data-contract.md:3` remains Draft; `specs/spec-review-prelaunch-recovery/requirements.md:50,94` and acceptance-tests.md:45 require rejection of changed live inputs. The amended read-policy cannot reuse its old precheck pins under that unchanged-input proposal.

## New current verification

Ran `rtk proxy shasum -a 256 --` against all eight explicit shared-consumer paths, login=false, exit 0. All eight still equal the BEFORE pins in the existing human-apply preparation, not applied outputs:

```text
81e345db1d1d96acec6a5ddd2159e01d6653cfb879ad2cf2a032e20b887b4c1b  plugins/sdd-review-loop/scripts/spec-review-precheck.sh
ac2532f6450dde24b78e4ab7b577a04ef9b1e8d165a180152737789b5ac6fb85  plugins/sdd-review-loop/scripts/spec-review-precheck.ps1
001f6962590b7d9dc9a831d8d90d7171174cca6d890e94b376881ab0193bd85f  plugins/sdd-quality-loop/scripts/check-workflow-state.sh
13351170ba1284d2fa1eb0d096d6e5faf506e3ce0a3a22a3cb81d09b10a028db  plugins/sdd-quality-loop/scripts/check-workflow-state.ps1
b816d5a7f09d458ecd9cab3cf23b7a2f52433ddde3badf80b3ff8d22bf46dad9  plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md
30fe033359d0660feaad0656581cdd5f60db09b76b52bf770703fae12d2fa602  tests/spec-review-loop.tests.sh
fc75d56e0118099f553367adf042aa5865808f3ace2ad48ff403cff0e75ca9de  tests/lib/loop-driver.sh
44283cc14f6377230bb4b9799585c8de6e364a4ce1ea1a4b2ba4454ffd0ed3f0  tests/lib/loop-driver.ps1
```

This verifies the immediate dependency is still outstanding; no failed operation was retried. Existing `consumer-sync-preparation-20261005.md` records candidate-only RED/GREEN and the human apply mechanism. Its normal human-operated command is:

```text
rtk proxy python3 -B /private/tmp/sdd-guard-main.3JEj4I/repo/reports/verification/spec-boundary-consumers-human-apply.py --apply-human
```

Not executed by this agent. This is only the first dependency, not complete read-policy delivery. Afterwards the consumer regressions can run; the changed-input recovery contract must be formally reconciled, review gates and Approved task established, then the guard implemented/applied and exact normal-path caller read verified. No guard success follows merely from consumer application.

## Work disposition

The prior turn added the missing empty-phase receipt regression (two synthetic branches passed), independently of this blocker. Already-green boundary/context/controller suites were not repeated. No new nonprotected product defect was established in this check, and adding arbitrary test churn would not advance the blocked native transition. The available next meaningful execution is post-application consumer regression, owned by the shared-contract lane; A8 fresh recovery follows the corrected legal caller path. Only this note was added. No frozen history, approval, identity or protective control was changed.
