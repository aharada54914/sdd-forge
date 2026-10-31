# Acceptance Tests: shared-review-launch-repair

These are expected checks, not claims that a formal review or final-head CI has run. Each test uses disposable fixtures unless the separately authorized gate launches an actual host context.

| Test | AC | Concrete assertion |
|---|---|---|
| TEST-001 | AC-001 | Compare constructed real-caller argv with current CLI help; accepted flag aliases and exact model/permission/session set match. |
| TEST-002 | AC-001 | Delete one required flag; launch admission rejects before reservation. |
| TEST-003a | AC-001 | Wrong model refuses. |
| TEST-003b | AC-001 | Compound Bash refuses. |
| TEST-003c | AC-001 | Outside Read refuses. |
| TEST-004 | AC-002 | Ordered complete inputs, raw invocation hash, conditional inputs, permission proof, and receipt all match; one authorized fixture reaches exactly one reservation. |
| TEST-005a | AC-002 | Missing required input rejects before reservation; copied ledger unchanged. |
| TEST-005b | AC-002 | Changed input digest rejects before reservation; copied ledger unchanged. |
| TEST-005c | AC-002 | Case-alias path rejects before reservation; copied ledger unchanged. |
| TEST-005d | AC-002 | Symlink path rejects before reservation; copied ledger unchanged. |
| TEST-005e | AC-002 | Out-of-scope path rejects before reservation; copied ledger unchanged. |
| TEST-005f | AC-002 | Altered raw invocation hash rejects before reservation; copied ledger unchanged. |
| TEST-005g | AC-002 | Changed preview receipt rejects before reservation; copied ledger unchanged. |
| TEST-005h | AC-002 | Reservation result differing from preview stops before launch; appended record remains and identity is not retried. |
| TEST-006a | AC-003 | Both applicable run-all entrypoints execute the focused suites; report skips. |
| TEST-006b | AC-003 | Permanent CI steps execute on the exact submitted HEAD; report native/Windows gaps separately. |
| TEST-007 | AC-004 | A lifecycle-only REQ final-status transition retains the admitted normalized digest. |
| TEST-008a | AC-004 | Unknown status invalidates normalized digest. |
| TEST-008b | AC-004 | Annotated status invalidates normalized digest. |
| TEST-008c | AC-004 | Evidence-cell edit invalidates normalized digest. |
| TEST-008d | AC-004 | Non-status body edit invalidates normalized digest. |
| TEST-009 | AC-005 | Shared and pre-refactor PowerShell digests match for LF, CRLF and mixed status lines. |
| TEST-010a | AC-005 | Malformed, empty and missing-field content produces the same digest in both PowerShell recipes; missing/unreadable files preserve read failures. |
| TEST-010b | AC-005 | Mis-cased keys and values preserve the pre-refactor PowerShell digest; caller-specific state validation remains unchanged. |
| TEST-011a | AC-006 | `launch-impl-review.py` denies write and permits authorized read in each applicable runtime. |
| TEST-011b | AC-006 | `preflight-host-review.py` denies write and permits authorized read in each applicable runtime. |
| TEST-011c | AC-006 | `validate-nontty-spec-launch.py` denies write and permits authorized read in each applicable runtime. |
| TEST-011d | AC-006 | `probe-nontty-review.py` denies write and permits authorized read in each applicable runtime. |
| TEST-011e | AC-006 | `nontty-impl-pretool-guard.mjs` denies write and permits authorized read in each applicable runtime. |
| TEST-011f | AC-006 | `preflight-evaluator-delivery.py` denies write and permits authorized read in each applicable runtime. |
| TEST-012a | AC-006 | Canonical-only inventory addition fails invariant check. |
| TEST-012b | AC-006 | Generator-only inventory addition fails invariant check. |
| TEST-012c | AC-006 | Stale generated projection fails invariant check. |
| TEST-012d | AC-006 | Unrelated protection membership remains unchanged. |
| TEST-013 | AC-006 | Remove CI transport registration in a disposable copy; inventory check fails. |

The formal reviewer must inspect current bytes and independently classify observed outcomes; historical local green tests and a diagnostic `DELIVERY_OK` are not PASS.
