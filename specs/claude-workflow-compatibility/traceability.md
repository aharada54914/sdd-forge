# Traceability: Claude workflow compatibility

| Requirement | Investigation | Design | API/Schema | Code Target | Test ID | Test Target | Status |
|---|---|---|---|---|---|---|---|
| REQ-001 | INV-001 | design.md | plugin manifests | T-003 | TEST-001 | Claude manifest validation | Planned |
| REQ-002 | INV-001 | design.md | skill metadata | T-004 | TEST-002 | isolated registration/release smoke | Planned |
| REQ-003 | INV-001 | design.md | Claude manifest policy | T-003 | TEST-003 | manifest-policy assertions | Planned |
| REQ-004 | INV-001 | design.md | YAML frontmatter | T-003 | TEST-004 | shipped skill validation | Planned |
| REQ-005 | INV-003 | design.md | CI workflow | T-004 | TEST-005 | OS-matrix CI validation | Planned |
| REQ-006 | INV-004 | design.md | installer/docs | T-003 | TEST-006 | installer/documentation tests | Planned |
| REQ-007 | INV-002 | design.md | review contract JSON | T-001 | TEST-007 | spec-review state machine | Planned |
| REQ-008 | INV-002 | design.md | reviewer contract JSON | T-001, T-006 | TEST-008 | role/session isolation | Planned |
| REQ-009 | INV-005 | design.md | portable precheck JSON | T-002, T-006 | TEST-009 | shell/PowerShell parity | Implementation Complete (T-002); T-006 Planned |
| REQ-010 | INV-003 | design.md | host/marketplace catalogs | T-004 | TEST-010 | release consistency | Planned |
| REQ-011 | INV-004 | design.md | workflow documentation | T-005 | TEST-011 | documentation consistency | Planned |

## Task Mapping

| Task | Requirements | Acceptance Criteria | Status |
|---|---|---|---|
| T-001 | REQ-007, REQ-008 | AC-007 | Planned |
| T-002 | REQ-009 | None (shared foundation) | Implementation Complete |
| T-003 | REQ-001, REQ-003, REQ-004, REQ-006 | AC-001, AC-003, AC-004, AC-006 | Planned |
| T-004 | REQ-002, REQ-005, REQ-010 | AC-002, AC-005, AC-010 | Planned |
| T-005 | REQ-011 | AC-011 | Planned |
| T-006 | REQ-008, REQ-009 | AC-008, AC-009 | Planned |
