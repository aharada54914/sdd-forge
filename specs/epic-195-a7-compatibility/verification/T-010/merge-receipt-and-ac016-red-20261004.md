# T-010 merge-receipt correction and AC-016 RED (non-gate)

Date: 2026-10-04. This is a local, uncommitted T-010 verification addendum, not an Implementation Complete or quality-gate verdict. No frozen specification or task status was changed.

## Integrated merge evidence

- GitHub PR #229 (Epic A1) reports merge commit `a8d65c7316f53787121874968e14878bc90c75aa`; PR #245 (Epic A5) reports `fe646175ba62256f71a560662a292dd84f6af8b1`. `git merge-base --is-ancestor <each-commit> origin/main` returned 0 for both. The feature branch names are no longer reliable merge evidence after branch cleanup; the shipped manifest previously omitted both receipts and classified AC-004/AC-021 as inactive.
- The manifest now pins each A1/A5 dependency to its corresponding merge commit, following its existing A4 pattern. `condition` for AC-004 and AC-021 against `origin/main` returned 0 (active); against the A5 merge first parent `fe646175ba62256f71a560662a292dd84f6af8b1^1` returned 1 (not active). This is activation evidence, **not** a real resolver invocation test.
- Manifest-contract receipt assertions were introduced first and produced expected RED: Bash 2 passed/1 failed, PowerShell 3 passed/1 failed. After the pins, the same cases were GREEN: Bash 3 passed/0 failed, PowerShell 4 passed/0 failed. `tests/escalation-skip-activation.tests.sh` initially failed because its old “clean” case used already-merged `origin/main`; after using the pre-A5 parent for that case and the real manifest/current main for the active case, it passed 10/10 (Bash and PowerShell). The active mutation is rejected as a stale SKIP.
- `audit` against an empty SKIP log on `origin/main` returned 0 and reported zero allowlisted lines. That proves no stale line in the supplied empty log, not that the consumer ran.

## AC-016 source false positive — intentional RED remains

`tests/loop-escalation.tests.sh` contained `skip_allowlist_line AC-004/AC-021` only in a comment. The Bash and PowerShell `case_manifest_contract` checks counted that text as if a consumer called the helper. Both checks now exclude comment-only lines. Current result: Bash 2 passed/1 failed (exit 1); PowerShell 2 passed/1 failed (exit 1), each failing at `AC-016 AC-004 output is not sourced through skip_allowlist_line`. This is a real missing implementation, not a regression to suppress by changing the expected assertion list or reintroducing a SKIP.

`tests/loop-escalation.tests.sh` TEST-019.10b currently builds F1/F3/F4 fixtures and reports informational deferral without driving the actual bootstrap host or invoking `skip_allowlist_line`. Its positive spy self-check directly calls the shadow command but does not prove interception of the actual host dispatcher. T-008's approved Done When requires a real F1/F3/F4 resolver no-call spy, while its saved diagnostic records host permission denial and `UNVERIFIED`. T-008 remains `Implementation Complete` in the existing task plan, but that historical status is not proof that its current Done When is met. Do not promote T-010 or T-008 to Done, call AC-004/AC-021 passed, or run a formal quality gate from this addendum.

## Minimum next implementation boundary

Continue T-008's own approved scope, not a T-010 test-only workaround: in a clean isolated host with normal hooks and specifically authorized permissions, first prove the spy intercepts one real resolver dispatch with explicit config/target-rev/feature arguments, then drive F1/F3-invalid/F4-invalid host branches and assert zero captured invocations plus reached-branch evidence. Only after that, wire TEST-019.10b's real conditional output through the manifest helper and make both Bash/PowerShell AC-016 source checks GREEN. A `find`/source-grep marker or the current INFO deferral cannot replace actual invocation evidence. Preserve the earlier permission denial and do not retry it via another executor.

## Remaining formal conditions

Current A5 item 10(a) has a stale live SKILL window/hash/ordinal relative to the live A7 probe; A7's frozen AC-036 citation also points to the old A5 item-10 span. Those normative differences require prospective amendment and independent re-review, separately recorded in `prospective-contract-repair-diff-20261004.md`. All current local regression results are non-gate, macOS PowerShell results are not Windows proof, and no current-head CI exists for these uncommitted edits.
