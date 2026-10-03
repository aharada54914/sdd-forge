# Task Review Report: a9-interrupted-review-recovery — Round 2 / Attempt 1

## Verdict: NEEDS_WORK

Reviewer A: NEEDS_WORK (13 PASS, 1 FAIL, 0 SKIP). Reviewer B: PASS (9 PASS, 0 FAIL, 0 SKIP). Critical: 0; Major: 1; Minor: 0.

## Reviewer A finding

OBSERVABLE-DONE / Major / T-002: tasks.md:73 assigns TEST-001–007, but tasks.md:103 requires Red then Green for every assigned case. acceptance-tests.md:9 TEST-003 preserves the already-correct ordinary reset terminal-contract rejection. Its passing pre-change baseline cannot honestly provide Red. Distinguish changed-defect/negative-mutation Red→Green from existing compatibility pre-change and post-change PASS, mapping exact per-case outputs in verification/T-002.md. See reviewer-a.json for the exact unmodified native finding.

## Reviewer B findings

None. See reviewer-b.json for the exact unmodified native output.

## Full Done When sweep

T-001 tasks.md:50 retains the blanket wording, but no already-correct assigned case was established in its TEST-008–083 range; no speculative change proposed. T-002 has the confirmed TEST-003 contradiction above. T-003 tasks.md:156 already distinguishes evidence categories; unchanged. Approval/Status remain Draft/Planned for every task.

## Proposed human-only change

Replace only T-002's one contradictory Done When item, following T-003's evidence-category wording. No implementation, task approval, or historical verdict changes.

Human application command from repository root:

```sh
rtk proxy python3 reports/task-review/a9-interrupted-review-recovery/attempt-1/round-2/human-apply-evidence-categories.py --apply
```

Dry-run verified exit 0. Reviewed before SHA-256: 7f1d42139b34fce4f798ec80f522e68344378867452ead169f9234131b9c143f. Proposed after SHA-256: 240b55e8f9ba9068c67deccf772ef24b90a749e3ed084ea0b4c436b0a3f7c8d2. The helper creates a unique backup, checks exact input bytes and preserves all approval/status fields. It has not been applied.

After actual human application, re-invoke round 3 with --edit-summary describing this single T-002 change. The persisted round-2 contract and verdict are honest NEEDS_WORK; check-workflow-state.sh --feature a9-interrupted-review-recovery exited 0 (workflow-state: ok).
