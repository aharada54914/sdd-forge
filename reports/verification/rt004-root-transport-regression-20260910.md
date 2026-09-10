# RT004: raw root transport regression

Date: 2026-09-10
Status: RED; implementation and formal review remain incomplete.

## Executed scope

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-path-only`

Original-path Bash and PowerShell consumers, both implementation reviewer
roles, on macOS with PowerShell 7.6.2. Final terminal session: 19961.
Result: 24 passed, 20 failed; process exit 1.

Test source SHA-256:
`582357d2c246dc585710cbb2880dd64353529186a4c42c5b3c7d6d562ccb17dc`

Earlier session 46506 also returned 24 passed / 20 failed at source SHA-256
`a51ed97d6bf2ce53cf8b2d2f86c4c92211fde973d03b7062e58e700db1fa7b72`.
The final execution additionally asserts that each altered root names the
same existing fixture (`-ef`) and the legacy case has no `adr_inputs` member.

The prior root-link suite had 24 passed / 4 failed. This extension adds four
negative cases for each runtime/role, all failing for the intended reason:

| Root input | Precheck shape | Observed result per runtime/role |
| --- | --- | --- |
| Root symlink | Legacy, no `adr_inputs` member | Exit 0, synthetic ledger changed |
| Physical fixture plus `/.` | Explicit empty ADR set | Exit 0, synthetic ledger changed |
| Existing child followed by `/..` | Explicit empty ADR set | Exit 0, synthetic ledger changed |
| Interior doubled separator | Explicit empty ADR set | Exit 0, synthetic ledger changed |

The original new-format root-symlink negatives also remain failing. Existing
legacy and empty-set positive controls and descendant-link negatives remain
successful. No failed case is counted as a product PASS.

## Fixture isolation and review

The invocation manifest argument retains its ordinary fixture path; only the
RepositoryRoot argument is altered. This prevents a future manifest-path
rejection from falsely proving repository-root validation. Every altered root
still resolves to the same existing fixture. Pins are generated before the
root argument is changed; no stale hash or absent input is used to force a
negative result. Each negative requires nonzero exit below the timeout range
and an unchanged synthetic ledger. All files and ledger records belong to the
temporary fixture, not the production review ledger.

Primary review corrected the initial coupling between the manifest argument
and the root argument before final execution. Independent bounded review by
`/root/rt004_check_contract_review` found no Critical or Major findings in the
supplied delta through source `a51ed97d...`. Its scope was message-provided
delta text only, not independent full-source or SHA verification. The primary
reviewed the two subsequent fixture setup assertions. This is not a formal
gate, race/Windows proof, or independent implementation PASS.

## Consequence and remaining proof

The legacy root-symlink case confirms that secure input acquisition cannot be
limited to prechecks already known to have the ADR extension. ADR-0034's common
transport prerequisite must precede schema dispatch. Dot and empty components
must be checked before normalization loses them.

These are stationary-path tests, not a deterministic initial-open race test,
handle-identity proof, or native Windows drive/UNC validation. Those obligations
remain open. The protected implementation candidate is unchanged and has not
been executed or applied by this work. Before complete candidate application,
retain the independent security review and original-path verification rules.

## Integration snapshot

A fresh GitHub query found 11 open PRs and no running check jobs. Failure,
conflict, behind-base and review/provenance conditions remain; no CI rerun,
commit, push, merge or issue closure was performed in this slice. Green
workflow-history fixtures (137/0 in the preceding verification) do not prove
admission safety or repository-wide merge eligibility.
