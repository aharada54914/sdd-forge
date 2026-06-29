# Traceability: workflow-state-integrity

| Requirement | Investigation | Design | API/Schema | Code Target | Test ID | Test Target | Status |
|---|---|---|---|---|---|---|---|
| REQ-001 | INV-005 | Data Plan, Discovery | registry schema v1 | T-002 | AC-001, AC-002 | registry/schema fixtures | Done |
| REQ-002 | INV-001 | State Model | internal validator CLI | T-003 | AC-003 | workflow-state suites | Done |
| REQ-003 | INV-001, INV-002 | State Model | review contracts | T-001, T-003 | AC-004, AC-014 | transition and provenance fixtures | Done |
| REQ-004 | INV-001, INV-003 | State Model | task fields | T-003 | AC-005 | lifecycle matrix fixtures | Done |
| REQ-005 | INV-005 | Data Plan | registry legacy schema | T-002 | AC-006 | bounded legacy fixtures | Done |
| REQ-006 | INV-005 | Lite profile | registry lite schema | T-002, T-003 | AC-007 | lite fixture + existing lite suite | Done |
| REQ-007 | INV-007 | Backend Plan, Test Strategy | paired CLI contract | T-002, T-003 | AC-002, AC-008, AC-014 | shell/PowerShell parity | Done |
| REQ-008 | INV-002, INV-003, INV-004 | Integration | gate invocation contract | T-001, T-004, T-005 | AC-009, AC-010, AC-012 | repository/CI/gate integration | Done |
| REQ-009 | INV-005, INV-006 | Data Plan | retrospective metadata | T-002 | AC-011 | registry and retrospective inspection | Done |
| REQ-010 | INV-007 | Test Strategy | test evidence | T-001, T-003, T-004, T-005 | AC-008, AC-012 | parity and run-all suites | Done |
| REQ-011 | INV-008 | Deployment / CI Plan | release manifests | T-006 | AC-013 | repository/version validation | Done |
| REQ-012 | INV-001, INV-003 | State Model | validator policy | T-001, T-003 | AC-005 | sudo/header/task bypass fixtures | Done |

## Task Mapping

| Task | Requirements | Acceptance Criteria | Status |
|---|---|---|---|
| T-001 | REQ-003, REQ-008, REQ-010, REQ-012 | — | Done |
| T-002 | REQ-001, REQ-005, REQ-006, REQ-007, REQ-009 | AC-001, AC-002, AC-006, AC-011 | Done |
| T-003 | REQ-002, REQ-003, REQ-004, REQ-006, REQ-007, REQ-010, REQ-012 | AC-003, AC-004, AC-005, AC-007, AC-008, AC-014 | Done |
| T-004 | REQ-008, REQ-010 | AC-009 | Done |
| T-005 | REQ-008, REQ-010 | AC-010, AC-012 | Done |
| T-006 | REQ-011 | AC-013 | Done |
