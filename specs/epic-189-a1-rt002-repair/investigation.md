# Investigation: A1 RT002 bounded repair

Date: 2026-09-26
Scope: acceptance-first revalidation of the existing RT002 verifier/test delta; not a reopening of A1 T-008.

## Authority and observed problem

`docs/review-tickets/RT-20260909-002.yml:12-26` records a real guard denial whose host response lacks the legacy plugin metadata. Absence of those flags is not evidence that hooks were disabled. The authorized replacement criterion is an exact operation-bound guard denial, not proof of plugin origin (`reports/verification/hook-recovery-entry-contract-20260909.md:54-113`). The user authorized a separate repair plan and retry on 2026-09-26. The parent ticket and all historical judgments remain unchanged.

## Current implementation and concrete evidence

Paths below are repository-relative. Re-check the actual contents and input hashes at each review; line numbers are navigation aids, not immutable evidence.

| Observation | Evidence |
|---|---|
| Versioned host-denial adapter uses exactly five keys, Codex-only runtime, nonce syntax/equality and exact full-envelope matching | `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py:381-403` |
| An explicit schema is selected before the three legacy runtime predicates; unknown schema does not fall through | same file `413-424`; legacy predicates `316-378` |
| Shared JSON loader rejects duplicate keys, including nested objects | same file `262-285` |
| Codex challenge contains its generated nonce in the fixed canary patch; Claude/Copilot templates remain separate | same file `175-230` |
| Verification refusals emit unavailable and category-specific exit codes; cleanup does not activate the host | same file `433-450,453-514` |
| Bash/PowerShell cover the new positive, raw-envelope mutations, field errors, nonce errors, selector fallback, duplicate response and cleanup members | `tests/check-hook-activation-handshake.tests.sh:600-866`; `tests/check-hook-activation-handshake.tests.ps1:524-746` |
| Legacy three-runtime positives and cleanup outcomes have existing assertions | Bash `133-214,350-389`; PowerShell `129-199,316-347` |

Static comparison found two direct-assertion gaps: cleanup with a schema field must retain legacy cleanup semantics (`check-hook-activation-handshake.py:453-472`), and unchanged Claude/Copilot emitted templates should be compared as complete objects (Bash currently checks presence at `292`; Codex exact bytes at `781`). These are verification gaps, not demonstrated production defects. Carry them into acceptance tests; do not claim the earlier suite success covers them.

## Scope and historical evidence

The approved draft `reports/verification/rt002-a1-repair-plan-draft-20260926.md` pins comparison main `5362378989f046a851b5005637abad6f942b1841` and candidate `4a4713380a5cbf8791fcc2fd7be1c7e0c1e3c80a`. The source scope is one Python verifier and its existing Bash/PowerShell suites; wrappers and guard behavior are not being redesigned. Re-check that three-path diff before implementation and final review, because shared main may advance.

`reports/verification/rt002-original-path-regression-20260926.md` records prior macOS Bash 401/0 and PowerShell 401/0. These are historical observations, not this feature's fresh review, native Windows result or live-host proof. Initial commit `c0aaf3a6` includes code and tests together: preceding RED ordering is unproven. Preserve A1 T-008 Done and A1 task-review attempt 8 round 1 BLOCKED; this plan provides no replacement verdict.

## Recovery and environment

Only repair-specific new provenance reviews may use recovery-contract item 4. Ordinary implementation, quality-gate completion and integration still require restored activation; actual refusals must not be rerouted. Review identities, complete hash-bound inputs, schemas, prechecks and retry limits remain mandatory (`hook-recovery-entry-contract-20260909.md:21-52`).

At preparation, repository structure validation succeeded; `domain/`, `sdd/project-context.yaml` and `design-system/` were absent (read-only filesystem checks, 2026-09-26). Re-check before consuming these shared-state claims. `domain-sync skipped: no domain/ directory`. No context is downgraded; this repair uses the full review path. No UI or design-system upload is needed.

## Remaining proof

Complete the two direct assertions; independently review this new feature; run both original-path suites and native Windows CI; then verify the installed candidate, fresh nonce, one actual native dispatch, unchanged response and original installed verifier result. A plain-file verifier cannot authenticate a forged collector transcript or establish persistent replay prevention (recovery contract `117-122`). No new attestation service or ledger is in scope.
