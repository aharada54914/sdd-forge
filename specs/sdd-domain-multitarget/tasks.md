# Tasks: sdd-domain-multitarget

Task-Review-Status: Passed

Source: Issue #423 (Multi-target Foundation Phase 1)

## Scope and constraints

- Preserve legacy and `facet-hybrid` behavior; this tranche adds explicit selection boundaries only.
- Do not add provider writes, cloud deployment, new gate stages, or a facet-native migration.
- Re-verify all baseline facts in `requirements.md` and `design.md` against consuming files before implementation.
- Keep resolver and registry contracts provider-neutral; unavailable required checks fail closed.
- Implement one task at a time and retain a focused regression test for each changed boundary.

## T-001 Consumer inventory and boundary fixtures

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: The inventory drives later routing decisions; a stale or incomplete mapping can silently bypass an existing consumer.
Required Workflow: acceptance-first
Blockers: None
Requirements: REQ-001
Acceptance: AC-001
Tests: TEST-001a, TEST-001b, TEST-001c, TEST-001d, TEST-001e, TEST-001f, TEST-001g, TEST-001h, TEST-001i

Done When:

- [ ] A machine-readable boundary inventory records each named consumer, one disposition, rationale, source mapping, and re-verification command.
- [ ] TEST-001a through TEST-001i each run against the current consuming file and fail on missing or duplicate classification.
- [ ] Review evidence records the inventory and fixture paths without requiring a post-review edit to traceability.md.

## T-002 Ownership and contract boundary fixtures

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: Ownership and provider-neutral contract rules protect shared Core policy from provider leakage.
Required Workflow: acceptance-first
Blockers: T-001
Requirements: REQ-001, REQ-002
Acceptance: AC-002, AC-012
Tests: TEST-002, TEST-012

Done When:

- [ ] Shared Core, Capability/Registry, Provider Binding, Host Adapter, and optional UI-provider ownership/non-ownership are asserted from the existing contracts.
- [ ] Capability examples contain no provider names or credentials, and Project Context uses Provider Binding IDs only for provider-specific details.
- [ ] ci-mcp remains read-only and no write/API dependency enters shared Core contracts.
- [ ] Mismatch fixtures fail when provider-specific fields cross the Core boundary.

## T-003 Target capability resolution and verification obligations

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Resolver output controls required checks and fail-closed behavior at a trust boundary; an incorrect obligation can permit an unverified target.
Required Workflow: tdd
Blockers: T-002
Rollback: Keep the legacy resolver path behind the existing context-presence check; revert the additive resolver/fixture commit if any baseline check changes.
Requirements: REQ-003, REQ-006
Acceptance: AC-003, AC-004, AC-013
Tests: TEST-003a, TEST-003b, TEST-003c, TEST-003d, TEST-003e, TEST-004, TEST-013

Done When:

- [ ] The existing Registry/Project Context resolver is reused or minimally extended to select obligations without a second source of truth.
- [ ] CLI/library, UI, design-only, IaC/cloud, and low-code fixtures each resolve their own obligations; candidate selection does not waive legacy-required checks.
- [ ] Required, optional, not-applicable, unavailable, not-run, and unknown outcomes follow the fail-closed contract.
- [ ] The selected plan emits implementation-stage checks only and never claims deployment or promotion success.
- [ ] High-risk evidence records each persisted resolver field, its sibling contract, and a mismatch test.
- [ ] Red tests fail before the resolver change and green tests pass after it; the implementation report records both runs and an independent reviewer verdict.

## T-004 Compatibility and hybrid fallback

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Compatibility behavior is shared by existing consumers; a regression could alter approval, evidence, or artifact semantics for legacy projects.
Required Workflow: tdd
Blockers: T-003
Rollback: Revert the compatibility commit and restore the pre-change legacy reader/writer contract; retain the captured baseline fixture.
Requirements: REQ-004
Acceptance: AC-005, AC-006, AC-007
Tests: TEST-005, TEST-006, TEST-007

Done When:

- [ ] Absent or invalid context preserves the current legacy artifact shape and equivalent workflow outcomes.
- [ ] `facet-hybrid` retains all seven legacy layer documents and records applicability only in a separate manifest.
- [ ] Any changed field, schema, or check vocabulary is versioned with enumerated reader/writer migration evidence.
- [ ] Tests cover absent, valid, stale, and malformed context inputs without changing default behavior.
- [ ] Red compatibility tests fail before the change and green tests pass after it; the implementation report records both runs and an independent reviewer verdict.

## T-005 UI provider boundary and consent-safe fallback

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Provider extraction crosses an egress and consent boundary; a routing error could send design data without configured consent.
Required Workflow: tdd
Blockers: T-004
Rollback: Disable the additive provider selection and restore the local manual-fallback path; revert only the provider-boundary commit if consent or upload assertions regress.
Requirements: REQ-005
Acceptance: AC-008, AC-009
Tests: TEST-008a, TEST-008b, TEST-008c, TEST-008d, TEST-008e, TEST-008f, TEST-008g, TEST-009a, TEST-009b

Done When:

- [ ] Generic UI questions and local canonical artifacts remain in bootstrap; provider operations are selected only for applicable UI profiles.
- [ ] Per-feature, standing, off, unknown, and missing consent settings are re-read at resolution time and produce the specified audit/no-upload/manual-fallback behavior.
- [ ] Provider-unavailable and non-UI fixtures retain a usable local path without network access.
- [ ] Tests prove no upload for off, unknown, decline, and unavailable-provider cases.
- [ ] Red consent-boundary tests fail before the change and green tests pass after it; the implementation report records both runs and an independent reviewer verdict.

## T-006 Provider evidence, host conformance, and release evidence

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: Evidence and host adapters must agree on the same obligations; a missing host mapping can make a correct resolver result unenforced.
Required Workflow: acceptance-first
Blockers: T-005
Requirements: REQ-002, REQ-004, REQ-005, REQ-006
Acceptance: AC-010, AC-011, AC-014
Tests: TEST-010, TEST-011, TEST-014

Done When:

- [ ] Provider results are normalized into the existing evidence contract without provider-specific fields entering Core policy.
- [ ] Claude Code, Codex, and Copilot host adapters expose identical workflow, approval, and evidence semantics despite invocation differences.
- [ ] The release evidence bundle demonstrates consumer inventory, compatibility, consent/fallback, provider ownership, and host conformance.
- [ ] Verification reports carry the final implementation/test paths; no task step edits frozen traceability artifacts after task review passes.
