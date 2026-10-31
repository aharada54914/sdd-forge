# Acceptance Tests: sdd-domain (DDD Upstream Lane Plugin)

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 public entry `domain-model` only; internal skills hidden | REQ-001 | TEST-001 | unit | tests/validate-repository.ps1 (visibility expectations) | Planned |
| AC-002 full artifact set generated under `domain/` | REQ-002 | TEST-002 | integration | tests/sdd-domain/artifact-set.Tests.ps1 | Planned |
| AC-003 domain-contract.json validates against schema v1 | REQ-002 | TEST-003 | unit | tests/sdd-domain/contract-schema.Tests.ps1 (valid + corrupt fixtures) | Planned |
| AC-004 seeds: text, Markdown path, issue URL; reverse consumes investigation.md | REQ-003 | TEST-004 | integration | tests/sdd-domain/seed-routing.Tests.ps1 | Planned |
| AC-005 two independent reviewers, ≤3 rounds, verdicts recorded | REQ-004 | TEST-005 | integration | reports/domain-review/ fixture run | Planned |
| AC-006 cross-model mismatch → requires_human_decision, no auto-continue | REQ-004 | TEST-006 | integration | tests/sdd-domain/cross-model-gate.Tests.ps1 | Planned |
| AC-007 agent-set `Domain-Model-Status: Approved` rejected by hook guard | REQ-005 | TEST-007 | unit | tests/hooks/domain-approval-guard.Tests.ps1 | Planned |
| AC-008 bootstrap injects Bounded-Context + aggregate refs when Approved model exists | REQ-006 | TEST-008 | integration | tests/sdd-domain/domain-sync.Tests.ps1 | Planned |
| AC-009 check-domain-conformance warn findings; SDD_DOMAIN_ENFORCE=error escalates | REQ-007 | TEST-009 | unit | tests/sdd-domain/check-domain-conformance.Tests.ps1 (conformant + deviant fixtures) | Planned |
| AC-010 no `domain/` → byte-identical existing workflow outputs, one skip line | REQ-008 | TEST-010 | integration | tests/sdd-domain/absence-regression.Tests.ps1 | Planned |
| AC-011 validate-repository passes: 7 plugins, version lock, 6 public skills | REQ-009 | TEST-011 | unit | tests/validate-repository.ps1 | Planned |
| AC-012 retrospective aggregates domain-drift metrics | REQ-010 | TEST-012 | integration | tests/sdd-domain/drift-metrics.Tests.ps1 | Planned |
| AC-013 English templates; UL has EN canonical + JA column + forbidden synonyms | REQ-011 | TEST-013 | unit | tests/sdd-domain/template-language.Tests.ps1 | Planned |
| AC-014 post-approval edit resets status to Pending | REQ-005 | TEST-014 | unit | tests/hooks/domain-approval-guard.Tests.ps1 | Planned |
| AC-015 multi-context feature: declared relation passes, undeclared relation warns | REQ-007 | TEST-015 | unit | tests/sdd-domain/check-domain-conformance.Tests.ps1 (two-context fixtures) | Planned |
| AC-016 update mode: edited + downstream stages re-run in confirmation mode, upstream byte-identical, status reset to Pending | REQ-002 | TEST-016 | integration | tests/sdd-domain/update-mode.Tests.ps1 | Planned |
| AC-017 panelist unavailable → `panelist-unavailable` recorded, requires_human_decision set, no auto-continue | REQ-004 | TEST-017 | integration | tests/sdd-domain/cross-model-gate.Tests.ps1 (unavailable-panelist fixture) | Planned |

## UI Integration Checklist

> The user-facing entry point of this feature is the slash command
> `/sdd-domain:domain-model` (no graphical UI).

- [ ] AC-001: The `domain-model` skill is reachable as
  `/sdd-domain:domain-model` from the Claude Code command surface (plugin
  manifest lists the skill; frontmatter omits `user-invocable: false`).
- [ ] AC-007: The approval safety precondition is enforced at the hook-guard
  call site (line-diff rejection), not only by skill instructions.
- [ ] AC-001: Internal skills (`domain-interviewer`, `domain-reverse`,
  `domain-review-loop`, `domain-sync`) are absent from the user command
  surface (`user-invocable: false` verified by validate-repository).
