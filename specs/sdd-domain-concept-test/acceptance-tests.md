# Acceptance: Feature Concept Test

The executable suite is tests/concept-test.tests.py. Subtests exercise the
classification/decision matrix with actual test-only signatures and registry
validation. They do not mock signature acceptance.

| Requirement | Verification |
|---|---|
| REQ-001 | FITS and all three non-FITS classifications; valid schema; unknown classification and decision rejected |
| REQ-002 | unconfirmed distinctions and unknown concept references rejected; every gate execution preserves domain bytes |
| REQ-003 | real signature round trips; missing sidecar, forged signature, missing key and unregistered approver rejected |
| REQ-003 | every Markdown/JSON field difference rejected; missing or malformed files rejected |
| REQ-004 | all nine non-FITS decision combinations return the correct continuation/hold/stop exit code; no-domain skip preserved |
| REQ-005 | stale/missing/symlinked inputs rejected; conditional review dependencies include all evidence and approval |
| REQ-006 | installed Bash and PowerShell dispatchers exercise the same validator; manifests use directory discovery |

Existing approval generator/validator, review conditional-input/runtime-admission,
workflow conditional-input, domain-sync, and Phase 0 domain-contract suites are
regression coverage. CI and merging are separate completion conditions; a local
suite passing does not close the tracking issue or prove Phases 2–4 complete.
