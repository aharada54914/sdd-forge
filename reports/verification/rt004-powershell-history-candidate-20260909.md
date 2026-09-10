# RT004 PowerShell prior-round progress — partial candidate

Date: 2026-09-09
Status: not applied, not executed, not formally reviewed; RT004 remains open.

Updated candidate: `adr-precheck-powershell-generation-candidate-20260909.patch`
Current SHA-256: `533a24fe12a44e1098f0032330cf977b6bfc8af4b441d359d74b2c5112b2d070`
Supersedes `2c61323a8ec25a09556065717187c6e47a07812c5cccc284c304eedb7f1a5ccd`.
Earlier reports and old evidence are retained as historical records.

## Scope and change

The current real `impl-review-precheck.ps1:374` rejects an unchanged design
without considering ADR remediation. Added candidate-only previous-round
validation and changed that comparison to reject when BOTH design and admitted
ADR path/hash set are unchanged. Legacy evidence retains design-only progress.

The prior-round helper checks paired extension presence, exact canonical
attempt/round, NEEDS_WORK identity, strict sorted ADR entries, matching core and
layer pins, both reviewer roles and exact raw precheck/design/ADR manifest pins.
It recomputes the prior input material hash from prior recorded inputs. It does
not compare current ADR bytes with the historical failed round's hashes.
Current ADR data is derived by the generation candidate before this comparison.
No previous verdict, contract, reviewer report or reservation is rewritten.

The actual attempt-4/round-1 contract was read with jq: schema
impl-review-contract/v1, stage impl, verdict NEEDS_WORK, attempt 4, round 1.
That is baseline identity evidence, not proof the new helper passes a real test.

## Data checks and unresolved review items

- Seven final patch hunks, counts, cumulative offsets and removed-line anchors
  matched a fresh complete read of the actual PowerShell precheck source.
- Actual product precheck git diff remained empty.
- Candidate execution, regression tests and native Windows checks: NOT RUN.
- Existing workflow-state validation runs before this progress comparison and
  must also support internally consistent ADR-bound historical evidence.
- Existing identity/session, verdict linkage, narrative isolation and allowed
  non-ADR checks remain the responsibility of that unchanged gate; the helper
  is not a replacement for them or a standalone review validator.
- Legacy precheck path checks, JSON duplicate properties, raw-path aliases and
  evidence replacement races require complete-chain regression/security review.
- The Bash counterpart and workflow-state counterparts are still incomplete.

This remains incomplete patch data, not a human-application package. Complete
the consumer chain and independent review before requesting human application.
