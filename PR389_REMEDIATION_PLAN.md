# PR #389 review remediation — 2026-09-05

## Execution addendum: remaining assertion failures

The owner's latest direction explicitly requests resolving the outstanding integration conditions, including the three local shell assertion failures reported immediately beforehand. This addendum supersedes the earlier exclusion of those assertions only. It does not expand product-gate changes or authorize bypassing runtime protection.

Target: the existing candidate at `25304d3b842d76e5da152e659af0d678d537e026`, `tests/prepare-panelist.tests.sh` only. Astra independent plan review found four early-exiting grep consumers across three assertion blocks (TEST-049b, TEST-055b, TEST-075c), not just three consumers. Incorporate that finding: remove quiet mode from all four consumers and redirect their stdout to `/dev/null`; preserve the exact regexes, case flags, producer, conjunction, exit/file/digest negatives, and all other assertions. No guard, product, fixture, mirror, status, or approval-field change.

Verification: long input with early match and no match; TEST-075c with both messages, only either message, and neither; the complete existing prepare-panelist shell suite on scoped system Bash; existing WFI suites and relevant regression evidence; independent exact-diff review; fresh hosted CI on the new head. No failed assertion may be suppressed. This is a test-harness correction within WFI-058/059 integration, not a fabricated review-ticket or new task approval. Only this current four-consumer delta is delegated; original remediation below remains historical.

The owner has now granted conditional administrator approval-review bypass for this and other consolidation PRs after completed applicable gates and mandatory CI success. Older narrow exception statements below are superseded; protection rules remain unchanged.

## State and authority boundary

This is a narrow follow-up to independently reviewed WFI-058/059 integration, not a new task approval, a Done declaration, or permission to alter deterministic guards. User transferred ownership and approved the remaining consolidation program. Existing PR #389 is updated for CI at `c5d3230714dd064b3e5a48ac79fb179f45ae3a76`, tree `e677808be1a9df76573978a853626c86c180b996`. Astra review returned merge NEEDS_WORK: Critical 0, Major 1, Minor 2. Only a reviewable staged patch and tests may be prepared in this step. Applying changes to live protected gates must follow the repository's human-apply path; no alternative writer or guard workaround is authorized.

## Exact scope

| Finding | Target | Minimal correction | Required regression |
|---|---|---|---|
| A-1 Major | `plugins/sdd-quality-loop/scripts/check-contract.ps1:115` | Resolve an existing contract with PowerShell `Resolve-Path -LiteralPath` and use its filesystem provider path, preserving the existing caller fallback on resolution failure. | Start PowerShell with process CWD outside the project, change its location to the project, and compare relative/absolute invocation of the same valid contract: both must pass and resolve the same evidence. Existing missing-evidence negatives still fail. |
| A-2 Minor/security | `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:901-907` | Replace the newly introduced predictable history-scan file with exclusive private `mktemp` allocation; clean it on normal completion and handled failure. Allocation failure must fail closed before using any historical anchor. No changes to authorization or sanitizer behavior. | Verify no new predictable filename write, private mode and successful cleanup; allocation failure rejects the stale-output fallback; existing WFI-058 positive and wrong-hash controls preserve results. Cover interrupted/error cleanup where the implemented lifetime contract promises it. |
| A-3 Minor/parity | `plugins/sdd-quality-loop/scripts/check-contract.ps1:122` | Use exact case-sensitive matching for the literal `specs`, matching Python. | Mis-cased `Specs` must retain the caller-base fallback and match Python; lowercase `specs` still discovers the project. Do not rely on case-sensitive filesystem availability to exercise the string rule. |

The older predictable file in the pre-existing fallback is explicitly outside this patch, and is not represented as fixed. Do not extend scope to the unrelated Bash/BSD-grep message assertions: baseline and candidate both returned 183 passed and 3 failed under the same environment. Do not change Bash installation or global PATH.

## Order and acceptance

1. Independently review this scope before patch authoring.
2. A cheap worker may author a standalone staged regression harness, run it against the untouched candidate, and record the expected failing assertions before writing a patch. The harness must leave real repository files untouched and use only exact-owned temporary fixtures with cleanup.
3. Prepare a current-base unified patch and verification instructions under an unprotected staging location. Validate its application to a disposable copy only if repository instructions permit that staging workflow; never present a scratch result as an in-tree gate result.
4. After correction, rerun the new regressions, both WFI suites, PowerShell prepare-panelist, the relevant contract golden cases, and mirror freshness. Package files are out of scope; preserve their current 446 passing test evidence by hash.
5. Copy the corrected PowerShell gate into only its two already-stale-on-change human-copy mirrors and update the corresponding manifests through the established resync procedure, after human application. Preserve all 15 pending unrelated mirrors.
6. Independent Astra re-review binds the patch and tests by hash. Prepare exact base/digest/apply commands for the human. Stop at the live protected-file boundary. No self-application after denial, no protection-rule edits, no claim that the live PR is fixed before application and revalidation.
7. After human application, verify the actual in-tree bytes and CI, rerun independent review, and only then consider normal PR merge. PR #386's administrator-review exception does not apply to #389.

## Rollback

Before live application, there is no product-state mutation to roll back: preserve or remove only the specifically authored staging artifacts. After application, use a reviewed inverse patch bound to the actual applied commit; never reset shared worktrees or discard unrelated changes.
