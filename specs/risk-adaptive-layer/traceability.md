# Traceability: risk-adaptive-layer

Requirement → Investigation → Design → Acceptance/Test → Code Target → Task → Status.
The machine-readable form now exists at `traceability.json` (produced in T-011, validated by
`check-traceability` in both default and require-evidence modes). Per-task live status is tracked
in `tasks.md`; the `Status` column below is the planning snapshot. T-011 surfaced two findings —
see `reports/implementation/T-011.md` (check-contract medium-tier calibration; AC-009 wording vs M-04).

| Requirement | Investigation | Design | AC / Test | Code Target | Task | Status |
|---|---|---|---|---|---|---|
| REQ-001 | INV-001 | design.md §1,§API (check-risk) | AC-001 / TEST-001 | scripts/check-risk.{sh,ps1}; tasks.template.md | T-001, T-002 | Planned |
| REQ-002 | INV-002 | design.md §3 (matrix) | AC-002 / TEST-002 | scripts/check-contract.{sh,ps1}; references/risk-gate-matrix.md | T-001, T-003 | Planned |
| REQ-003 | INV-003 | design.md §2,§3 (red/green) | AC-003 / TEST-003 | scripts/check-contract.{sh,ps1}; verification-contract.template.json | T-004 | Planned |
| REQ-004 | INV-004 | design.md §4 (traceability) | AC-004 / TEST-004 | scripts/check-traceability.{sh,ps1}; spec-id-rules.md; traceability.json | T-001, T-005 | Planned |
| REQ-005 | INV-005 | design.md §2,§5 (spec_revision) | AC-005 / TEST-005 | scripts/generate-evidence-bundle.{sh,ps1}; check-contract | T-006 | Planned |
| REQ-006 | INV-006 | design.md §5,§6 (provenance+sign) | AC-006 / TEST-006 | scripts/generate-evidence-bundle, check-evidence-bundle; evidence-bundle.template.json | T-006, T-007 | Planned |
| REQ-007 | INV-007 | design.md §7 (two-person) | AC-007 / TEST-007 | scripts/check-task-state.{sh,ps1}; sdd-hook-guard.* | T-007 | Planned |
| REQ-008 | INV-008 | design.md §Deployment/CI | AC-008 / TEST-008 | .github/rulesets/main.json; CODEOWNERS; workflows/*; scripts/apply-branch-protection.sh | T-008 | Planned |
| REQ-009 | INV-009 | design.md §Security | AC-009 / TEST-009 | docs/THREAT-MODEL.md; docs/agent-capability-matrix.md | T-009 | Planned |
| REQ-010 | INV-010 | design.md §Security | AC-009 / TEST-009 | .codex/agents/sdd-investigator.toml; sdd-evaluator.toml | T-009 | Planned |
| REQ-011 | INV-011 | design.md (dogfood) | AC-011 / TEST-011 | specs/risk-adaptive-layer/traceability.json; verification/ | T-011 | Planned |
| (all) | (all) | design.md §Migration | AC-010 / TEST-010 | tests/{gates,guards,eval}.tests.sh; scripts.tests.ps1 | T-002..T-007 | Planned |
