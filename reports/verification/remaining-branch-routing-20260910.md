# Remaining remote branch routing

Observed 2026-09-10 using read-only GitHub PR, issue, branch and comparison APIs. No branch deletion, PR creation, push, merge, or issue closure performed.

Snapshot: 26 open issues, 11 open PRs, 14 remote branches including main. All 13 non-main branches map either to an open PR or the two cases below. Counts do not measure completion or work effort.

## CI discovery / WFI branch

`codex/ci-auto-discovery-wfi-027-028-034` current head is `eba07a297117ec32104fcbdf90c3515a63e2163f`, exactly PR #382's recorded head. PR #382 merged on 2026-08-31, but its base was **codex/conduct-critical-review-and-improve-plugin**, not main.

Merge commit: `92528375705085967c19d75deb5f12e0fa66c276`.

- Comparing merge commit to PR #381 branch: ahead 41, behind 0; merge base equals that merge commit. Its integration is therefore present in #381's current ancestry.
- Comparing merge commit to main: diverged, ahead 62, behind 2; merge base `e00478321327b48e4e4ad21a14391d69e0f1baa9`. This does not prove the change is on main. Do not equate PR #382's MERGED status with main completion.
- The branch has no post-PR-head commits. No duplicate PR is needed. Preserve until cleanup is allowed and exact target rechecked.
- WFI-027 / WFI-028 / WFI-034 work routes through PR #381; issues #288 / #289 / #311 require their own acceptance evidence plus final main integration before closure.

Source: https://github.com/aharada54914/sdd-forge/pull/382

## August 31 improvement branch

`auto/improve-20260831` contains commit `32a81f5ebe3b71d72ef274c7bc3776b6db12a70c`. No associated PR was returned for that commit.

PR #402's existing body explicitly reconciles this branch as a duplicate production repair with weaker regression assertions, selecting `auto/improve-20260817` instead. This turn inspected metadata and the existing reconciliation record, not a fresh full source equivalence review. Do not merge both or delete solely on this metadata.

The two branches diverge substantially in ancestry; comparison statistics alone are not a patch-equivalence proof. Final #402 verification still requires current-baseline tests and exact denial reason / exit status coverage. Issues #295 and #380 include other audit findings and must not be closed solely because this hook fix merges.

Source: https://github.com/aharada54914/sdd-forge/pull/402

## Execution constraint

The recovery-entry prerequisite remains open. This inventory resolves routing only; it does not authorize bypassing that prerequisite to create, merge or delete branches. Human runtime-source evidence requested in the preceding response is still pending.
