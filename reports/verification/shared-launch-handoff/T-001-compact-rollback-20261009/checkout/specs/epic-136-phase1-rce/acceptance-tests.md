# Acceptance Tests: epic-136-phase1-rce

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | unit / static | `prepare-panelist-input.sh` HMAC invocation | Planned |
| AC-002 | REQ-002 | TEST-002 | integration | `tests/prepare-panelist.tests.sh` real-HMAC fixture | Planned |
| AC-003 | REQ-002 | TEST-003 | integration | `tests/prepare-panelist.tests.sh` tampered-token fixture | Planned |
| AC-004 | REQ-003 | TEST-004 | security integration | `tests/prepare-panelist.tests.sh` adversarial operand fixture | Planned |
| AC-005 | REQ-005 | TEST-005 | PowerShell integration | `tests/prepare-panelist.tests.ps1` real-HMAC acceptance and tampered-token denial | Planned |
| AC-006 | REQ-002, REQ-004 | TEST-006 | cross-runtime integration | shell and PowerShell fixtures for valid-signature invalid nonce, TTL, and repository binding | Planned |
| AC-007 | REQ-004 | TEST-007 | regression / isolation | `tests/prepare-panelist.tests.{sh,ps1}` temporary fixtures, no real secrets or network | Planned |

This is a local CLI security fix with no user-facing entry point; the UI
integration checklist is not applicable.
