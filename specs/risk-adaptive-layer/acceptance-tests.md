# Acceptance Tests: risk-adaptive-layer

Demonstrates the target traceability format: every AC links a REQ to a TEST id,
a test type, and a concrete target. (This format itself is what REQ-004 makes
standard in `acceptance-tests.template.md`.)

| AC | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | gate (unit) | `tests/gates.tests.sh` + `tests/scripts.tests.ps1` :: check-risk missing/invalid/valid | Planned |
| AC-002 | REQ-002 | TEST-002 | gate (unit) | check-contract: required-set ⊉ tier-minimum ⇒ fail; ⊇ ⇒ pass (both runtimes) | Planned |
| AC-003 | REQ-003 | TEST-003 | gate (unit) | check-contract: `required_workflow=tdd` test check missing/empty `red_evidence` ⇒ fail; Red→Green ⇒ pass | Planned |
| AC-004 | REQ-004 | TEST-004 | gate (unit) | check-traceability: broken REQ→AC→TEST→evidence chain ⇒ fail; complete ⇒ pass | Planned |
| AC-005 | REQ-005 | TEST-005 | gate (unit) | check-contract/check-evidence-bundle: high/critical missing `spec_revision` ⇒ fail; present ⇒ pass | Planned |
| AC-006 | REQ-006 | TEST-006 | gate (integration) | generate-evidence-bundle emits provenance fields; check-evidence-bundle validates them | Planned |
| AC-007 | REQ-007 | TEST-007 | gate (unit) | check-task-state: critical Done without distinct `Second Approval` ⇒ fail; with ⇒ pass; sudo cannot auto-pass it | Planned |
| AC-008 | REQ-008 | TEST-008 | config (lint) | rulesets/CODEOWNERS parse; `merge_group` present in test.yml; release gated on CI | Planned |
| AC-009 | REQ-009, REQ-010 | TEST-009 | doc/config presence | `docs/THREAT-MODEL.md` + `docs/agent-capability-matrix.md` enumerate controls/agents; `.codex/agents/*.toml` declare `model` | Planned |
| AC-010 | (all) | TEST-010 | regression | every pre-feature fixture in gates/guards/scripts/eval suites still passes unchanged | Planned |
| AC-011 | REQ-011 | TEST-011 | dogfood | `specs/risk-adaptive-layer/` carries risk-tiered tasks + `traceability.json` + per-task evidence; self gates pass | Planned |
