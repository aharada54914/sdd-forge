# Task Review Report: a9-interrupted-review-recovery — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | a9-interrupted-review-recovery |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | PASS |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |

## Reviewer-A Findings (Structural Coverage)

specs/a9-interrupted-review-recovery/tasks.md:156 は T-003 の全割当 TEST-ID/variant に Red then Green を要求するが、同:133 は既に正しい既存動作には passing baseline と別の failing negative mutation を要求する。acceptance-tests.md の TEST-099（legacy の既存 acceptance 保持）/TEST-100（既存 normal-reset suite を変更せず成功）では、成功済み baseline 自体の Red は発生しない。別 mutation の Red を元ケースの Red とみなす規定もなく、実装者と quality-gate の完了判定が一致しないため Major。Done When を変更対象の失敗再現の Red→Green と、既存互換性ケースの baseline 成功および変更後の回帰成功に分け、各証拠の対応を明記する。これは計画内の証拠条件の矛盾であり、このゲートで試験実行を要求するものではない。

## Reviewer-B Findings (Quality/Risk)

None (9 PASS, 0 FAIL, 0 SKIP).

## Proposed Changes

Human-only: replace only T-003's contradictory all-cases Red/Green Done When item. Require Red→Green for changed defect/negative-mutation cases, and passing pre-change baseline plus post-change regression for already-correct compatibility cases (including TEST-099/100). Map each TEST-ID/variant to the appropriate evidence in verification/T-003.md. Preserve Approval: Draft and Status: Planned.

## Next Steps

A human may inspect and run human-apply-t003.py --apply. The script requires the exact reviewed tasks hash and creates a unique backup before changing one T-003 item. It does not change approval/status or other artifacts. After actual human application, re-invoke round 2 with --edit-summary describing that human change. No task implementation or review reservation is authorized here.
