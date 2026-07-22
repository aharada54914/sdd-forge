# Acceptance Tests: epic-195-a7-compatibility

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-006 | TEST-001 | static / doc-review | golden-baseline capture script contract (fully scripted, no manual step) | Planned |
| AC-002 | REQ-001 | TEST-002 | integration, negative self-check | byte-identical suite vs. a deliberately mutated fixture | Planned |
| AC-003 | REQ-001 | TEST-003 | integration | representative script per §4.1 category, two invocations, fixed env | Planned |
| AC-004 | REQ-001, REQ-007 | TEST-004 | integration (named SKIP until Epic A5 merges) | Context-absent: no capability subprocess invoked | Planned |
| AC-005 | REQ-002 | TEST-005 | integration | Context-absent generation: exact legacy-seven-layer file set, no capability/Facet files | Planned |
| AC-006 | REQ-002 | TEST-006 | static / regex | `REQ-NNN`/`AC-NNN` identifier format unchanged | Planned |
| AC-007 | REQ-002, REQ-007 | TEST-007 | integration (named SKIP until Epic A4 merges) | Context-present-required: no Facet reference leaks into legacy-shaped output | Planned |
| AC-008 | REQ-003 | TEST-008 | static / registration-forcing | `tests/loops/loop-inventory.json` entry count stays 8 | Planned |
| AC-009 | REQ-003 | TEST-009 | static / schema | `quality-gate` entry carries additive `capability_applicability`; driver reads it with no code change | Planned |
| AC-010 | REQ-003 | TEST-010 | integration | `TEST-019` in `tests/loop-escalation.tests.sh`: capability event trace vs. golden trace | Planned |
| AC-011 | REQ-003 | TEST-011 | regression, byte-identical | `emit-run-record.sh` no-flag output unchanged | Planned |
| AC-012 | REQ-003 | TEST-012 | integration | `emit-run-record.sh --capability-enforcement <state>` emits additive object only when flagged | Planned |
| AC-013 | REQ-004 | TEST-013 | traceability review | decision doc §4 requirement decomposed into ≥3 traced clauses | Planned |
| AC-014 | REQ-005 | TEST-014 | integration | fixture-matrix builder constructs all 4 named states | Planned |
| AC-015 | REQ-005 | TEST-015 | static / registration-forcing | every new/extended suite has a `.sh`/`.ps1` pair registered in `run-all.{sh,ps1}` and `test.yml` | Planned |
| AC-016 | REQ-007 | TEST-016 | static | every upstream-dependent assertion degrades to a named, issue-cited `SKIP` | Planned |
| AC-017 | REQ-004 (process) | TEST-017 | doc-review | every factual claim in this package cites file:line evidence (WFI-011) | Planned |
| AC-018 | REQ-006 | TEST-018 | static / doc-review | baseline capture records commit SHA, fixed env, script sha256; update requires human-reviewed diff | Planned |

This is internal test-infrastructure specification work with no
user-facing entry point; the UI Integration Checklist is not applicable.

Every `Planned` status above is a Phase 1 (specification-only) placeholder:
no test code exists yet. Test IDs and targets are fixed here so the Phase
2/3 implementation task has no remaining test-identity ambiguity to
resolve, matching this repository's own precedent for fixing a deferred
suite's contract at design time (investigation.md INV-016, citing Epic
A5's `resolve-project-context-caller-contract`).
