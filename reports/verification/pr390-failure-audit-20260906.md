# PR #390 Windows failure audit

Read-only investigation. PR head ade304948907b5bdc94e9975f80528a0dfbb9e14; compared main b453fc9351c3bdc2e1a32524db071a4790b80201.

GitHub confirms the only changed path is .github/workflows/self-improvement.yml (primary result 197f67), updating claude-code-action. The independent explorer traced failed run 34008982110, job 101421310980 to test.yml's Test cross-model gate (pwsh), which invokes tests/cross-model.tests.ps1, not the updated action.

Explorer reports TEST-004(c) near-boundary failures in job log lines approximately 646-683: gpt iteration 1 elapsed_ms=2558, deadline_ms=2000, exit=1, verdict=0; final suite 56 passed / 8 failed. This is delegated log evidence, not a newly executed test.

Primary git diff between the exact main and PR head for tests/cross-model.tests.{sh,ps1} and both PowerShell panelist runners is empty (fd4508). Therefore the dependency-only change does not contain a repair to those files. File equality alone does not prove root cause or justify calling a failure harmless/flaky. The failed CI remains failed; no rerun, bypass, merge or issue closure was performed.

Next: reconcile with the existing T-002 timing diagnostics and its authorized repair workflow before any source change. Do not increase deadlines, drop assertions, or treat another successful run as proof the cause was fixed.

## Primary dependency inspection, 2026-09-08

Fresh GitHub PR metadata still reports the exact head above, OPEN, BEHIND,
REVIEW_REQUIRED, with 23 successful and two failed completed checks. Failed
checks are Windows test and required-checks; no live run was observed.
Primary retrieval of job 101421310980 confirms TEST-004(c) failures for GPT
iterations 1–5 and Gemini iterations 2, 4, 5, with suite total 56 passed / 8
failed. Historical failures remain failures.

The PR diff remains exactly one pinned-action substitution in
`.github/workflows/self-improvement.yml`, with no permissions/input changes.
GitHub's upstream tag API resolves annotated tag v1.0.214 through tag object
`f90699222fdbc06942ba7bd0cc5dfed38177ee55` to commit
`fa2b2666b747000bf42767d1f332065b375e3c8f`, matching the PR pin. The API marks
the tag unsigned (`verified: false`); tag-to-pin equality is not a signature
verification claim.

Comparison of old pin `3f854a8fb5146b39d5cbf8b57f70d80810e1366f` with the new
pin reports 26 commits and 32 changed files, not a metadata-only dependency
change. The root action.yml is absent from that complete changed-file list.
Direct patch inspection establishes that base-action/action.yml updates the
installed Claude Code from 2.1.238 to 2.1.259; SDK output now includes selected
model limit fields; branch cleanup now excludes restored configuration paths
from both status detection and staging. This is a bounded upstream inspection,
not a full security audit or an execution test of the action.

Authoritative endpoints:
- https://api.github.com/repos/anthropics/claude-code-action/git/ref/tags/v1.0.214
- https://api.github.com/repos/anthropics/claude-code-action/git/tags/f90699222fdbc06942ba7bd0cc5dfed38177ee55
- https://api.github.com/repos/anthropics/claude-code-action/compare/3f854a8fb5146b39d5cbf8b57f70d80810e1366f...fa2b2666b747000bf42767d1f332065b375e3c8f

No rerun, source modification, push, merge, or issue closure. Next integration
still depends on the approved Windows fixture repair's formal review and fresh
required CI; an unrelated action update does not justify waiving those tests.
