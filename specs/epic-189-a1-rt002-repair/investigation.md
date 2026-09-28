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

## Amendment Re-Review Context

The separate repair-plan amendment was recorded in commit `231cfbb80eb4cfc0cd290541933b45112fb0f6e1`; the exact normative byte contract was added in commit `2ae13f266cf5a4bdce9324d950775495bcd9d02f`. The following SHA-256 values are the three documents **as of commit `2ae13f266cf5a4bdce9324d950775495bcd9d02f`**, before adding this declaration. The current review manifest separately pins this declaration's complete bytes; the table is not a self-referential claim about the current investigation hash.

| Document | SHA-256 at the amendment snapshot |
|---|---|
| `specs/epic-189-a1-rt002-repair/requirements.md` | `c46aff291620cd66cc638571d4deed1fa24877ff0b9140315e46031576fe322a` |
| `specs/epic-189-a1-rt002-repair/acceptance-tests.md` | `77f43e0da6461da182d7f03dd9bb756dc52949185dfd246bc45916947b145689` |
| `specs/epic-189-a1-rt002-repair/investigation.md` | `684cec221ea081d23b21a6e6cbd2406483b51b2769c78de09ff764c8cedf4a50` |

Human approval, verbatim, 2026-09-26 (conversation; this committed declaration is its durable record):

> 再試行を承認する
>
> 今回の修復だけを別計画として扱う変更を承認する

This authorizes a separate acceptance-first revalidation of existing repair code, not retrospective test-first evidence, a replacement for failed verdicts, or additional product scope. The initial implementation commit is `c0aaf3a639f4cb4798b16acd115f0b05db44493f`; the comparison baseline is `5362378989f046a851b5005637abad6f942b1841` and recorded candidate is `4a4713380a5cbf8791fcc2fd7be1c7e0c1e3c80a`. Referenced later-phase artifacts are pinned below, without admitting their contents to the spec reviewers or treating their observations as new PASS results.

| Referenced artifact | SHA-256 |
|---|---|
| `reports/verification/rt002-a1-repair-plan-draft-20260926.md` | `b6f58e82c1075cfa29f72c243ba079e9996815f18c038618cf0f51f5d9b7fef2` |
| `reports/verification/rt002-original-path-regression-20260926.md` | `c185beeea761c437ad03cf2acc3b9972513a8f65340fcbfa6e00c3f79b5b2728` |
| `docs/review-tickets/RT-20260909-002.yml` | `ae2b554aa9416c2997bef00143183f3cbcc7d79610c000d7c7b8928175241d74` |
| `reports/verification/hook-recovery-entry-contract-20260909.md` | `2ca4125082c495724b0bbde33e7451edb21fc4042827c1e67b4354eb9215e79f` |
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` | `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5` |
| `tests/check-hook-activation-handshake.tests.sh` | `bf0ca7472e4fc508f5e7da34c3559be79c620e89bb4744441cbb449d798d0dcd` |
| `tests/check-hook-activation-handshake.tests.ps1` | `9506cb7c0605ab37355ba697d8b40129e7492755cb633964532503c79ca47d05` |
| `specs/epic-189-a1-project-context/tasks.md` | `bd66327f71f84f3d555fd4c01a9e2db4cfd0ce4debc18b7adb4e046e600cb044` |
| `reports/task-review/epic-189-a1-project-context/attempt-8/round-1/task-review-contract.json` | `16fe95cd4b18f36108a50e2c80a5867c7b8fd2c33b0c03516a66e5215f62004e` |
| `reports/task-review/epic-189-a1-project-context/attempt-8/round-1/integrated-verdict.json` | `2fbdb1a7fe75b442acec29100d9f522464a1ab72f9ebe3d94027ffd6bbb88c4f` |

The parent task's Done and historical BLOCKED remain unchanged (the pinned task and integrated verdict above). Fresh verification obligations remain AC-006, not assumed success.

### Adopted two-envelope amendment, 2026-09-28

The current amendment snapshot is commit `9428fbe2f16f2e30420712d87fd0ccfea113b3ce`. It adopts only the exact `B(N) | P+B(N)` raw-response grammar and the paired-envelope negative matrix. The following are the documents at that commit, before this provenance addition; the next review manifest separately binds the complete updated investigation. This snapshot supersedes the older snapshot above only for the two-envelope amendment, not for historical verdicts, execution proof or correction limits.

| Document | SHA-256 at the current amendment snapshot |
|---|---|
| `specs/epic-189-a1-rt002-repair/requirements.md` | `b1cd92b7af976c2bbaa0cd14b8dd7386ce36235abb60cae683a4cb35043c5c67` |
| `specs/epic-189-a1-rt002-repair/acceptance-tests.md` | `a27a30070d6c024d9815ac20dfc06c70b1940f86b863047c70b48cce7fc550e9` |
| `specs/epic-189-a1-rt002-repair/investigation.md` | `5cbefe7cfb09ddc4d7ea2a0a1bd21e2f3be88c065d258b08cdba64406b79e5f7` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/two-envelope-extra1-20260928/candidate-precedence-20260928.md` | `e6aa4354777a9b5b844cd9565d85dcdef275f941e1e1543d3dd777db73f5cd3a` |

Human approval, verbatim, 2026-09-28 12:01:47 UTC (conversation; this committed declaration is its durable record):

> A9復旧計画の3タスクを承認した
>
>     追加修正の限定承認する

The immediately preceding request explicitly named “RT002の実拒否出力に対応する契約・検証器修復” among the limited additional repairs. The additional-repair approval above covers that RT002 scope, separately from its first sentence's A9 task approval. The human subsequently generated the bounded candidate and adopted the six documents with the original precheck; those operations do not certify implementation or native activation. The pinned addendum is the dated precedence record for the adopted grammar and identifier sweep; its original candidate-generation statements remain historical. All later-artifact fingerprints in the table above and the preceding historical table remain citations, not reviewer permission to open those artifacts or substitute their old results for fresh proof.
