# A7 terminal transition regression — 2026-10-05

Scope: terminal comparison ordering and its inventory regressions only.
Owner HEAD: `d64cffcb22b114779202847be33e41700c4ba11f` plus existing working-tree changes.

The prior terminal assertion emitted a transition event before checking the expected result. A mismatched result could therefore leave an apparent successful transition. Both drivers now compare first and emit only on success. Existing comparison case semantics are unchanged.

## Verification observed in this session

- Implementer RED: Bash 79 passed / 1 failed; PowerShell 78 passed / 1 failed. Failure was the mismatch/event assertion. These counts came from tool output; no separate raw RED log was retained.
- Coordinator GREEN rerun: `rtk proxy bash tests/loop-inventory.tests.sh` — 80 passed, 0 failed, exit 0.
- Coordinator GREEN rerun: `rtk proxy pwsh -NoProfile -File tests/loop-inventory.tests.ps1` — 79 passed, 0 failed, exit 0.
- Scoped `git diff --check` — exit 0.
- Implementer broader driver results: Bash 26/0, PowerShell 23/0.
- Implementer consistency results: Bash 34/0, PowerShell 38/0.
- Escalation results: Bash 36/1, PowerShell 35/1. TEST-019.10b remains unsatisfied: no real interviewer invocation was driven. This is not a PASS or an approved skip.

Covered branches: matching success emits exactly one transition; mismatch, nonzero outcome, and missing expected value fail without that transition.

## Remaining boundaries

The prior AC-009 body hashes described the previous ordering, conflicting with AC-026 transition semantics. The authorized seven-document amendment was applied on 2026-10-05 after all seven original hashes matched and originals were backed up at `/tmp/a7-seven-docs-backup.71Hz0D`. The application succeeded through the normal editing tool; `git diff --check` passed. New review binding remains pending. Attempt 13 reviewer output remains preserved as noncanonical raw evidence; no integrated PASS is asserted.

The same escalation failure appears in the saved T-010 current-working-tree regression record dated 2026-10-04. That historical observation is not a fresh baseline execution.

Formal review, native T-008 validation, current-change CI, quality gate and merge remain pending. No task status or historical verdict is changed by this report.

## Independent local code audit

Agent `a7_hash_role_review` inspected the four-file delta independently and reported Critical 0 / Major 0 / Minor 0. It verified the sole event-emission call follows the successful comparison, failure branches exit before it, and trace/sequence assertions inspect actual event changes. Its scoped whitespace check passed. It also executed a lower-case expected-value probe: Bash rejected it with zero events; PowerShell accepted it with one event, confirming the pre-existing case-semantics difference is preserved rather than repaired. This narrow audit is not the formal SDD review or quality gate.
