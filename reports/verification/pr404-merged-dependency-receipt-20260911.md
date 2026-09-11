# A7 dependency ancestry after branch cleanup

## Root cause and scoped contract clarification

`tests/lib/skip-allowlist-evaluator.{sh,ps1}` required a live epic-named
branch even after its work had merged. Deleting that branch converted a
completed dependency into an apparently unmerged one. PowerShell additionally
required that branch before selecting main for fingerprint validation.

The dependency object now optionally accepts `merged_commit`, a full lowercase
40-character Git commit identifier. It records an independently confirmed
integration, rather than relying on a mutable branch name. The ancestry test
against the caller's main reference, Passed specification/design checks, and
separate source-window fingerprint check remain required. An explicit invalid
or unavailable receipt is an error, not permission to skip. Dependencies with
no receipt retain their existing branch-ancestry behavior.

This clarification preserves AC-034/035's ancestry requirement and the
existing activation-expression grammar. It does not mark any task Done or
rewrite historical review evidence. The user's current authorization covers
necessary implementation and documentation changes; independent approval and
current-head CI are still required before merging.

## Actual A4 evidence

- Issue 192 closed by PR 301, merged 2026-08-18T15:38:19Z.
- Integration: `02166dbabb0979081337b1d408b26019be3668d6`.
- `git merge-base --is-ancestor` against origin/main returned 0.
- Before fix: actual A4 `merged` returned 1; no A4 branch remains.
- After fix and receipt: actual A4 `merged` and `fingerprint-match` returned 0.
- The existing A4 fingerprint is unchanged, not regenerated to hide drift.

## Regression results

Both runtimes reproduced deleted-branch failure: 7 passed, 1 failed.
After the fix, each full allowlist suite passed 16 assertions. Cases include
deleted branch with valid receipt, receipt outside target ancestry, malformed
receipt, unavailable commit, existing unmerged behavior, fingerprint drift,
unknown skips and non-vacuous clean audit. Negative-case ERROR diagnostics
are expected and asserted, not swallowed success.

## Remaining A7 work

The structural suites still emit their historical F4/AC-007 SKIP. With a
correct merged-dependency predicate that SKIP is no longer justified and must
fail audit until real F4 acceptance coverage is enabled. Do not label A7 or
its live CLI corpus complete based on these unit-test results. This change
fixes dependency evidence; it does not manufacture refreshed CLI output.
