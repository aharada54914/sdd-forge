# Issue 423 T-002 final launch preparation

PREPARATION ONLY — no reservation, formal evaluation, protected apply or Git operation.

## Selected final set

- Candidate: `reports/verification/issue423-t002-evaluator-input-candidate-20261005-final.json`, SHA-256 `aa4b2d9a99d81b6d988c3ab4d164043d6cdc66645af60ebbb921525708a155f9`.
- Authorization declaration: `reports/quality-gate/issue423-t002-post-fix-declaration-20261005-final.md`, SHA-256 `3f5a4aa22b735e7e227cc99348754eea2a2963ad1b10bafa8d38a9912a7e1a87`.
- Machine evidence: `reports/verification/issue423-t002-evaluator-input-final-check-20261005.json`.

72 unique inputs retain all 44 previous pairs and add 28 pairs: two bounded evidence records, seven additional production TypeScript files, five test/support sources, three package/lock/config files, and eleven generated JavaScript entrypoint/dependency files. The 54-row declaration preserves all prior 26 rows. All 74 hash comparisons (72 inputs, declaration, predecessor candidate) matched; JSON readback matched; duplicates/conflicts were zero. No old candidate or declaration was overwritten.

The extra dependencies support the recorded 34-test result and its three-entrypoint `node --test` command, not a package-wide recompilation or full runtime suite. The only non-builtin runtime import in this selected closure is zod; the caller must provide the pinned package dependency using the approved runtime setup. Do not invoke package-wide compile from an evaluator restricted to this subset. A missing runtime dependency must be reported, not downloaded or silently substituted by the evaluator.

## Evidence boundaries

T-002 fixture evidence, old human FilesOnly exact-payload/9-check receipt, current installer 43-test evidence, and new no-write/static 34-test evidence are separate. None is formal gate, native activation, full current-tree distribution or CI. The audit and log are now expressly listed in the final candidate; their earlier candidate44 omission remains historical.

Additional files' targeted secret/local-path scan had no matches. Fixed synthetic credential values in tests are not real credentials. Retained historical inputs contain local provenance: this is a LOCAL evaluator set, not cleared for public export. Raw private build logs, environment/configuration dumps and actual secrets are excluded. No publication was performed.

## Remaining launch conditions

1. Human executes the already prepared three-file manifest-binding apply through `reports/verification/issue423-manifest-binding-human-apply.py`; verify readback and the prescribed post-apply regressions. Agent must not perform this apply.
2. Rehash the selected final set; confirm normal caller/ship contract and dependencies, exact declaration admission and output permissions. The current file is a preparation candidate, not a review-context invocation.
3. Allocate a genuinely fresh evaluator identity, follow the normal unique reservation/receipt chain, construct and validate the complete invocation, and verify complete first-input delivery. No identity or receipt is supplied here.
4. Only then run independent evaluation and quality-gate. CI, native host/delivery checks where required, and Done remain separate outcomes.

No input inconsistency was found in this preparation. Protected apply and formal launch checks, not additional same-green reruns or new reservations, are the current next actions.
