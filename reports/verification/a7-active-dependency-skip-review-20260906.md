# A7 active-dependency SKIP review — 2026-09-06

Read-only primary review; not a formal quality-gate verdict or a task status change.

## Finding: F3/F4 SKIP conditions are no longer satisfied

Inspected worktree: `/Users/jrmag/.local/share/sdd-forge-a7-t004-evidence-20260905`.

- `specs/epic-195-a7-compatibility/design.md:558` defines `merged(epic)` as both non-Pending terminal spec/design review status and feature merge ancestry. Lines 571–579 require failure for dependency-present SKIP, independently of fingerprint drift.
- `specs/epic-195-a7-compatibility/acceptance-tests.md:11` allows F4/AC-007 SKIP only until A4 merges; line 46 allows F3/AC-042 SKIP only until A1 merges.
- A1 and A4 each have `Spec-Review-Status: Passed` in requirements.md:3 and `Impl-Review-Status: Passed` in design.md:3. All task Status fields in their task plans are Done.
- GitHub PR #229 merged into main on 2026-08-08, commit `a8d65c7316f53787121874968e14878bc90c75aa`; PR #301 merged into main on 2026-08-18, commit `02166dbabb0979081337b1d408b26019be3668d6`. Fresh `gh pr view` queries verified both facts.
- `git merge-base --is-ancestor <commit> HEAD` returned 0 for both merge commits in the inspected A7 worktree.
- `tests/structural-compatibility.tests.sh:251` and :252 still emit recorded F4/F3 skips. The PowerShell counterpart at `tests/structural-compatibility.tests.ps1:178` also emits the two skips using recorded dependencies, without testing current merge state.

Therefore earlier 44/0 and 51/0 suite results with four named SKIPs do not establish completion of all currently activated structural acceptance conditions. The raw test results remain valid as historical executions; their interpretation must not treat F3/F4 as still blocked on unmerged A1/A4. F5/F6 depend additionally on A6 and are not resolved by this finding.

## Required disposition

Keep this finding open in T-004/T-010 completion review. Add or activate real F3/F4 structural assertions and enforce the existing dependency-present SKIP rule through the task-owned mechanism, with scoped regression evidence. Check frozen artifact and review-ticket scope before changing implementation; this observation does not itself amend frozen specifications or expand the current collector-only repair assignment. Do not close issue #195 or mark T-004 Done based on the historical four-SKIP result.
