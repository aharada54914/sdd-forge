# PR #409 applied precheck repair: verification

The user's pinned three-file application was verified in the issue298 worktree.
All three files match commit 3c514d915054861a93ff9959538b6e89482380eb exactly.
The diff against worktree HEAD remains 82 insertions and 3 deletions.

Executed `bash tests/spec-review-loop.tests.sh`: exit 0. Both Bash and
PowerShell investigation-only remedy scenarios passed after the negative cases;
the suite's final state/hash/replay/reset/safe-path assertion passed. This suite
does not emit a numerical assertion count; no count is inferred.

Full output: `/tmp/sdd-pr409-precheck-recheck-20260913.log`
SHA-256: `efee801079471e56162288883230d14d58851ab9b69935e7173ef068bbd6321e`.

`git diff --check` returned 0. The fixture restored the tracked workflow-state
registry: `git diff --quiet -- specs/workflow-state-registry.json` returned 0.

Applied source SHA-256:

- spec-review-precheck.sh: 6e1d117ea7a67653962a7654851529168ab86b36accc858ecb5e9b59451bd1f4
- spec-review-precheck.ps1: cfbaad2db2f3a44a5ed6cbcf40808e049b1d13267e17acd11ae9d9ba0bbb1f76
- spec-review-loop.tests.sh: ca81030fcb9fbd0b4237440ac46ba65c33345b4fa5d535068a82bfb81841241e

GitHub PR #409 remains OPEN at 075a932c573567bd2f7291dece341211b3075cc6.
Fresh status query shows all three OS test jobs and required-checks FAILURE,
21 other workflow jobs SUCCESS, and REVIEW_REQUIRED. Local repair tests are
not a CI success or formal design/task/cross-model verdict. The actual design
review launch denial remains recorded in pr409-impl-review-launch-denied-20260913.md.
At the time of the verification above, no commit, push, merge, or
verdict/task-status modification had been performed.

## Publication scope (2026-09-14)

Publish only the human-applied three-file repair and this report. The separate
dirty design, investigation, identity ledger, consent record, and untracked
formal-review outputs are excluded and preserved. Publishing this repair does
not declare those reviews complete. The three source hashes were rechecked
against this report, and `git diff --check` passed before publication.
Local source review confirmed that historical contract validation still runs
before admitting an investigation-only change, unchanged/unbound/missing/
symlinked/inconsistent inputs remain rejected, and replay protection remains
in place. This is not an independent gate verdict. New-head CI is required.
