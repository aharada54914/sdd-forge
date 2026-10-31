# Traceability: A1 RT002 bounded repair

Authorized amendment (2026-09-28, limited extra1): exact two-envelope contract adopted for formal re-review. Existing review/status/approval lines remain historical, not a PASS of these changed bytes. No implementation, execution proof, task-attempt reset or correction-budget reset. Governing dated precedence: [amendment addendum](verification/T-001/two-envelope-extra1-20260928/candidate-precedence-20260928.md).

All statuses are Planned. Proposed ownership after human adoption/re-review: T-001 owns REQ-001–004/AC-001–005 and supplies installed TEST-089; dependent T-002 owns final REQ-005/AC-006, native Windows/latest-head CI, integration and post-merge proof; references to existing checks do not claim their completion for this feature. Investigation evidence is cited by named section because investigation.md has no INV IDs.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md#current-implementation-and-concrete-evidence | security-spec.md#trust-boundaries | design.md#api--contract-plan | requirements.md#normative-codex-bytes | check-hook-activation-handshake.py; T-001 | TEST-001, TEST-090–TEST-091 | original Bash/PowerShell handshake suites | verification/T-001-results.md (pending) | Planned |
| REQ-002 | investigation.md#current-implementation-and-concrete-evidence | security-spec.md#high-risk-persisted-field-preflight | design.md#api--contract-plan | requirements.md#normative-codex-bytes | check-hook-activation-handshake.py; T-001 | TEST-002–057, TEST-061, TEST-092–TEST-097 | original Bash/PowerShell handshake suites | verification/T-001-results.md (pending) | Planned |
| REQ-003 | investigation.md#current-implementation-and-concrete-evidence | security-spec.md#authorization-and-evidence-limits | design.md#data-plan | requirements.md#acceptance-criteria | check-hook-activation-handshake.py; T-001 | TEST-058–082, TEST-086 | original Bash/PowerShell handshake suites | verification/T-001-results.md (pending) | Planned |
| REQ-004 | investigation.md#current-implementation-and-concrete-evidence | ux-spec.md#scope-and-user-journeys; frontend-spec.md#technology-stack | design.md#test-strategy | requirements.md#normative-codex-bytes | check-hook-activation-handshake.py; T-001 | TEST-081–086 | original Bash/PowerShell handshake suites | verification/T-001-results.md (pending) | Planned |
| REQ-005 | investigation.md#remaining-proof | infra-spec.md#cicd-sequence; security-spec.md#trust-boundaries | design.md#deployment--ci-plan | requirements.md#acceptance-criteria | T-002 release verification; T-001 installed original verifier prerequisite | TEST-087–089 | independent gates; native Windows/current-head CI; real installed native host | verification/T-001-results.md (TEST-089 prerequisite, pending); verification/T-002-results.md (final acceptance, pending) | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | REQ-004 | AC-005 | ux-spec.md#scope-and-user-journeys | N/A — no visual journey change; emitted CLI templates preserved |
| Frontend | REQ-004 | AC-005 | frontend-spec.md#technology-stack | N/A — no UI/client component |
| Infrastructure | REQ-005 | AC-006 | infra-spec.md#deployment-topology | Native Windows and installed activation pending |
| Security | REQ-001–005 | AC-001–006 | security-spec.md#trust-boundaries | Exact refusal branches and live proof required |

## Final Status

After task review, this body is frozen. Record task-scoped functional/activation evidence in verification/T-001-results.md and final whole-feature acceptance/integration status in verification/T-002-results.md rather than mutating this table. An implementation report is a claim, not an independent verification verdict. Missing activation, CI or quality-gate evidence leaves the feature incomplete.

## Task-size amendment proposal, 2026-09-29

Attempt 2 round 1 returned TASK-SIZE / Major. This two-task ownership amendment requires human adoption and fresh task re-review; no current implementation or release success is claimed. REQ-001–004/AC-001–005 belong only to T-001; REQ-005/AC-006 final acceptance belongs only to T-002, with T-001 TEST-089 as a prerequisite. The tasks.md preservation table allocates every original Done When obligation. Historical single-task ownership statements in the dated candidate addendum are superseded only for this proposed task split; other frozen requirements, designs and acceptance tests are unchanged.
