# Traceability: epic-193-a5-capability-resolver

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-003, INV-005, INV-006, INV-007, INV-010, INV-012, INV-013 | security-spec.md#trust-boundaries; infra-spec.md#cicd-sequence; infra-spec.md#journal-recovery | design.md#architecture; design.md#api--contract-plan (`resolve-project-context.{py,sh,ps1}` CLI contract, steps 0-14); design.md#design-decisions-resolving-open-questions (union-match; staged generation, journaled transactional commit; track-exclusive publication set); design.md#resolver-publication-transactional-bundle-contract | `resolve-project-context.py` CLI: `--config`/`--source-rev`/`--target-rev`/`--include-untracked`/`--feature`; steps 0-3 (argument validation, state derivation, canonicalization, Context Projection — T-002), steps 4-9 (`resolve-component-paths`/Registry/`evaluate-predicate` fan-out — T-003), steps 10-13 (track branch, Evidence assembly, output schema self-validation, pre-publication recheck — T-004), and step 14 (journaled publication transaction — T-007); the full-pipeline test surface these steps enable is T-005's own | plugins/sdd-quality-loop/scripts/resolve-project-context.py; resolve-project-context.sh; resolve-project-context.ps1 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007, TEST-008, TEST-009, TEST-016, TEST-028, TEST-038, TEST-039, TEST-040, TEST-041, TEST-043, TEST-044, TEST-047, TEST-048, TEST-049, TEST-052, TEST-059 | reports/quality-gate/ for T-002, T-003, T-004, T-005, T-006, T-007; specs/epic-193-a5-capability-resolver/verification/{T-002,T-003,T-004,T-005,T-006,T-007}/ | Planned |
| REQ-002 | investigation.md INV-013, INV-019, INV-020 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#api--contract-plan (sixteen-row Block diagnostic-id table); design.md#resolver-publication-transactional-bundle-contract; design.md#global-constraints (closed sixteen-value enum) | `diagnostics[].id` (sixteen-value closed enum, split across four contributing tasks — T-002 five rows, T-003 five rows, T-004 three rows, T-007 three rows — 5 + 5 + 3 + 3 = 16 unique rows — plus the additional `snapshot-generation-mismatch` fixtures T-003 and T-007 author, which introduce no new row, that row being T-004's; corrected 2026-08-27, human-approved, ruling D(2), from "T-007 four rows", which counted a fixture as a row); exit-code contract `0`/`1`/`2`; `capability-resolver: <check-id>: <detail>` diagnostic-line format | plugins/sdd-quality-loop/scripts/resolve-project-context.py; resolve-project-context.sh; resolve-project-context.ps1 | TEST-010, TEST-011, TEST-012, TEST-013, TEST-014, TEST-015, TEST-038, TEST-039, TEST-040, TEST-041, TEST-047, TEST-048, TEST-049, TEST-055, TEST-057, TEST-058 | reports/quality-gate/ for T-002, T-003, T-004, T-007; specs/epic-193-a5-capability-resolver/verification/{T-002,T-003,T-004,T-007}/ | Planned |
| REQ-003 | investigation.md INV-006, INV-007, INV-013 | security-spec.md#trust-boundaries | design.md#api--contract-plan step 1 (state derivation); design.md#constraint-compliance | `disabled-legacy`/`advisory`/`required` derivation from `workflow.capability_enforcement`; `disabled-legacy-invocation` Block (not a graceful no-op, diverging from `check-component-coverage`) | plugins/sdd-quality-loop/scripts/resolve-project-context.py | TEST-015, TEST-016 | reports/quality-gate/ for T-002, T-005; specs/epic-193-a5-capability-resolver/verification/{T-002,T-005}/ | Planned |
| REQ-004 | investigation.md INV-004, INV-011, INV-018 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#data-plan (Resolver Evidence entity, "B6 Evidence completeness", "B7 predicate-instance keying", "B9"); design.md#contracts-resolver-evidenceschemajson-req-004; design.md#validate-resolver-evidencepyshps1-contract-req-004 | `contracts/resolver-evidence.schema.json` (`sdd-resolver-evidence/v1`); `capability_evaluations[]`/`diagnostics[]` exact-set/cardinality/bidirectional-consistency rules; `validate-resolver-evidence` twelve-value check-id enum + provenance-binding procedure | contracts/resolver-evidence.schema.json; plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py; validate-resolver-evidence.sh; validate-resolver-evidence.ps1; plugins/sdd-quality-loop/scripts/resolve-project-context.py (Evidence assembly, step 11, T-004) | TEST-017, TEST-018, TEST-019, TEST-020, TEST-021, TEST-044, TEST-050, TEST-051, TEST-054, TEST-056 | reports/quality-gate/ for T-001, T-004, T-005, T-007, T-008; specs/epic-193-a5-capability-resolver/verification/{T-001,T-004,T-005,T-007,T-008}/ | Planned |
| REQ-005 | investigation.md INV-005, INV-007, INV-009, INV-011 | security-spec.md#trust-boundaries; infra-spec.md#cicd-sequence | design.md#global-constraints (stable-sort, diagnostic determinism contract); design.md#security-boundaries (no clock/network/provider-API); design.md#test-strategy items 5, 9 | Repeated-`.py`-invocation determinism; `.py`/`.sh`/`.ps1` byte-identical parity; stable-sorted `capability_evaluations[]`/`diagnostics[]`/every Epic-A4-mandated array; input-order invariance | plugins/sdd-quality-loop/scripts/resolve-project-context.py; resolve-project-context.sh; resolve-project-context.ps1; plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py; validate-resolver-evidence.sh; validate-resolver-evidence.ps1 | TEST-022, TEST-023, TEST-024, TEST-025, TEST-045 | reports/quality-gate/ for T-002, T-003, T-004, T-005, T-007, T-008, T-009, T-010; specs/epic-193-a5-capability-resolver/verification/{T-002,T-003,T-004,T-005,T-007,T-008,T-009,T-010}/ | Planned |
| REQ-006 | investigation.md (Test Strategy contract, design.md#test-strategy items 1-10) | infra-spec.md#cicd-sequence; security-spec.md#trust-boundaries | design.md#test-strategy (ten suites, including the T-011 caller suite) | `tests/*.tests.sh`/`.tests.ps1` pairs + `tests/fixtures/capability-resolver/`, REQ-006 items a-h | tests/resolve-project-context-cli.{sh,ps1}; tests/resolve-project-context-block.{sh,ps1}; tests/resolve-project-context-match.{sh,ps1}; tests/resolve-project-context-lite.{sh,ps1}; tests/resolve-project-context-discovery.{sh,ps1}; tests/resolver-evidence-schema.{sh,ps1}; tests/validate-resolver-evidence.{sh,ps1}; tests/resolve-project-context-parity.{sh,ps1}; tests/resolve-project-context-metamorphic.{sh,ps1}; tests/resolve-project-context-caller-contract.{sh,ps1}; tests/run-all.{sh,ps1} | TEST-026, TEST-027, TEST-028, TEST-042, TEST-045, TEST-046, TEST-053 | reports/quality-gate/ for T-001..T-011; specs/epic-193-a5-capability-resolver/verification/{T-001..T-011}/ | Planned |
| REQ-007 | investigation.md INV-017, OQ-003 (resolved) | N/A — cross-layer caller integration; protected resolver/workflow inputs remain human-copy/manifest-checked | design.md#design-decisions-resolving-open-questions ("caller insertion point", "anchor fingerprint") | Live caller phase in `sdd-bootstrap-interviewer/SKILL.md`, anchored by the adjacent `### Capability Interview Phase` / `### Full-Profile Layer Interview` headings; normalized anchor `sha256:d6ae89cb5f9a0be3d2dcc5789c49ede31ace3f4af2e12b14ae9ef7dc84a2f4ba`, ordinal `4` | plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md; tests/resolve-project-context-caller-contract.{sh,ps1}; tests/fixtures/capability-resolver/caller-contract-baseline.json; tests/resolve-project-context-caller-contract-check.py | TEST-029, TEST-030, TEST-031, TEST-032, TEST-042, TEST-046, TEST-053 | reports/implementation/epic-193-a5-capability-resolver/T-011.md; caller-contract suite output | Planned |
| REQ-008 | investigation.md (documentation/versioning discipline, matching every sibling epic's own REQ) | infra-spec.md#cicd-sequence | design.md#constraint-compliance (`AGENTS.md` Rules cross-reference); design.md#adr-change-log (no new ADR) | Per-task `CHANGELOG.md` `## Unreleased` entry citing #193; grep-based no-version-mutation self-check | CHANGELOG.md | TEST-033, TEST-034 | reports/quality-gate/ for T-001..T-011; specs/epic-193-a5-capability-resolver/verification/{T-001..T-011}/ | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — deterministic CLI script family + validator + schema + implemented caller-integration contract | ux-spec.md | No rendered or interactive surface anywhere in this feature's own deliverables (design.md Layer Specifications; ux-spec.md's own "N/A — no change" record). The implemented capability interview phase's conversational prompts remain REQ-007's target-contract scope; T-011 owns orchestration and anchor-drift verification, not prompt or screen content. |
| Frontend | N/A — no browser/frontend bundle | N/A — CLI/script feature work | frontend-spec.md#technology-stack | stdlib-only Python master + `sh`/`ps1` wrappers + fixture tree + one new JSON Schema document is not a frontend surface; frontend-spec.md records N/A. |
| Infrastructure | REQ-001, REQ-005, REQ-006, REQ-007, REQ-008 | AC-026, AC-028, AC-032, AC-033, AC-034 | infra-spec.md#cicd-sequence; infra-spec.md#journal-recovery; infra-spec.md#rollback | Ten `.sh`/`.ps1` suite pairs register directly in `tests/run-all.*`, including T-011's caller contract; workflow wiring and the protected resolver trio remain staged under manifest-checked human-copy inputs. `resolve-project-context.{py,sh,ps1}` content population is likewise human-copy staged, never a direct agent write. |
| Security | REQ-001, REQ-002, REQ-003, REQ-004, REQ-005 | AC-011, AC-012, AC-021, AC-025, AC-038, AC-039, AC-047, AC-049, AC-050, AC-051, AC-054, AC-059 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | Journaled publication transaction / crash-recovery scan / pre- and post-publication snapshot rechecks (T-007) close the atomicity and TOCTOU gaps adversarial review found in an earlier revision (B1/B8); `validate-resolver-evidence`'s own provenance-binding procedure (T-008) closes the "caller-supplied Registry/affected-component-set trusted blindly" gap (B6); the Resolver's own orchestration logic never reads a credential, contacts a network endpoint, or invokes a provider API (REQ-005/Security Boundaries, AC-025's repository-wide grep); every diagnostic `<detail>` is a canonical, Resolver-owned sentence, never a dependency subprocess's own raw stderr (M8). Two already-reserved protected paths inherited from Epic A1 (Protected-File Statement) — no new protection category is introduced by this feature. |

Caller-integration status note (T-011): the historical UX-row wording that called the caller contract “documented (not implemented)” and the capability phase “future” is superseded by the implemented caller phase in `sdd-bootstrap-interviewer/SKILL.md`. T-011 owns orchestration and anchor-drift verification; prompt content remains REQ-007 contract scope. Protected resolver and workflow inputs remain human-copy/manifest-checked.

## Task Mapping

Task decomposition revised by four task-review remedy passes across two
attempts, all closing findings that trace back to the same original
TASK-SIZE root cause (see tasks.md Global Constraints, "Task-decomposition
note" for the full round-by-round history): **attempt-1 round-1/round-2**
progressively isolated the `cli`/`discovery`/`lite` suites and then the
`block` suite out of the original undivided engine task; **attempt-1
round-3 BLOCKED** (3 Major, 0 Critical — TASK-SIZE on the still-undivided
14-step engine; SCOPE-DISJOINT and DEPENDENCY-OVERLAP in the CI-
registration task graph that had grown up around it); **attempt-2
round-1's own first remedy** split the engine itself into T-002 (steps
0-3), T-003 (steps 4-9), and T-004 (steps 10-13, at that point still
paired with the `match` suite), dissolving the standalone `block`-suite
task by distributing its fixtures across T-002/T-003/T-004 and
renumbering every downstream task up by one; **attempt-2 round-1's own
reviewer-b found this insufficient in one respect** (NEEDS_WORK, 1
Major, 0 Critical — TASK-SIZE on T-004, still pairing its own production
code with an entirely new 11-TEST-ID `match` suite under one "and"-
joined title); **this revision's own remedy** isolates the `match` suite
out of T-004 into its own new task, T-005 (Blocked by T-004 and, for
CI-registration ordering, by T-002), renumbering every task from the
former "cli/discovery/lite" task onward once more (T-005 → T-006, T-006 →
T-007, T-007 → T-008, T-008 → T-009, T-009 → T-010). See
`reports/task-review/epic-193-a5-capability-resolver/attempt-1/round-1/
tasks-round-1-proposed-changes.md`, `.../round-2/tasks-round-2-proposed-
changes.md`, `.../round-3/reviewer-b.json`, and `attempt-2/round-1/
tasks-round-1-proposed-changes.md`.

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-004 (schema), REQ-006 (share — item e, one of sixteen Block rows represented structurally), REQ-008 (share) | TEST-017, TEST-018, TEST-019, TEST-020; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-001/green-sh.log, .../T-001/red-sh.log |
| T-002 | REQ-001 (steps 0-3 only — argument validation, state derivation, Project Context canonicalization, Context Projection assembly), REQ-002 (share — five of sixteen non-transactional diagnostic-id rows), REQ-003 (state derivation, in full), REQ-005 (share — determinism baseline), REQ-006 (share — item e's five rows), REQ-008 (share) | TEST-010..TEST-015 (share — five of sixteen rows), TEST-038 (share), TEST-041; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-002/green-sh.log, .../T-002/red-sh.log, specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 (three staged script entries) |
| T-003 | REQ-001 (steps 4-9 only — `resolve-component-paths` invocation, Registry discovery, `registry_digest`, trigger/conditional-facet evaluation, the any-branch WARN check), REQ-002 (share — five more of sixteen non-transactional diagnostic-id rows), REQ-004 (share — evaluation records feeding Evidence assembly), REQ-005 (share), REQ-006 (share — item e's five rows), REQ-008 (share) | TEST-010..TEST-015 (share — five more of sixteen rows, ten complete), TEST-038 (share), **TEST-057 and TEST-058** (the two rulings-C fixtures this task appends to the shared block suite — added here 2026-08-27, human-approved, ruling D(2), completing that ruling's propagation into this row); TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-003/green-sh.log, .../T-003/red-sh.log |
| T-004 | REQ-001 (steps 10-13 only — track branch, Resolver Evidence assembly, output schema self-validation, pre-publication recheck; the full-pipeline `match`-suite test surface this task's own code enables is T-005's own), REQ-002 (share — three more of sixteen non-transactional diagnostic-id rows, thirteen complete), REQ-004 (share — Evidence assembly logic; schema is T-001's own), REQ-005 (share — determinism baseline), REQ-006 (share — item e's remaining three rows), REQ-008 (share) | TEST-010..TEST-015 (share — three more rows), TEST-038 (share), TEST-040 (share — first fixture), TEST-041 (share); TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-004/green-sh.log, .../T-004/red-sh.log, specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 (updated script entries) |
| T-005 | REQ-001 (share — AC-003 through AC-008/016/043/044/052/056, the full-pipeline correctness/aggregation/provenance test surface, split out of T-004 by task-review attempt-2 round-1's own second remedy, closing a TASK-SIZE finding), REQ-004 (share — exercises T-004's already-authored Evidence-assembly logic), REQ-005 (share — byte-identity/aggregation locks), REQ-006 (share — items a-d, f, g), REQ-008 (share) | TEST-003..TEST-008, TEST-016, TEST-043, TEST-044, TEST-052, TEST-056; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-005/green-sh.log, .../T-005/red-sh.log |
| T-006 | REQ-001 (share — AC-001 CLI required-flag matrix, AC-002/AC-028 discovery-contract reuse, AC-009 Lite-track schema-conformance, split out of the then-undivided core-engine task by task-review attempt-1 round-1 remedy), REQ-006 (share — discovery/Lite-track fixture-matrix items), REQ-008 (share) | TEST-001, TEST-002, TEST-009, TEST-028; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-006/green-sh.log, .../T-006/red-sh.log |
| T-007 | REQ-001 (share — step 0 crash-recovery scan, step 14 transaction), REQ-002 (share — three transactional rows plus one additional shared-row fixture), REQ-004 (share — Evidence committed via this transaction), REQ-005 (share — determinism preserved across crash/rollback), REQ-006 (share — item e's remaining three rows plus one additional shared-row fixture), REQ-008 (share) | TEST-010..TEST-015 (share — remaining three rows plus one additional shared-row fixture, completing the sixteen-row matrix), TEST-038 (share, completing), TEST-039, TEST-040 (share — second fixture), TEST-047, TEST-049, TEST-059 (approval-surface write-scope grep self-check, NEW 2026-08-28, human-approved, ruling E — a registration-time and CI-gated grep of TEST-025's kind, not a suite file); TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-007/green-sh.log, .../T-007/red-sh.log, specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 (updated script entries) |
| T-008 | REQ-004 (validator), REQ-005 (share — `array-not-stable-sorted` check), REQ-006 (share — item h's provenance-binding pair), REQ-008 (share) | TEST-021, TEST-050, TEST-051, TEST-054; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-008/green-sh.log, .../T-008/red-sh.log |
| T-009 | REQ-005 (parity/determinism proof), REQ-006 (share — item i, dual-runtime parity suite), REQ-008 (share) | TEST-022, TEST-023, TEST-024, TEST-025; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-009/green-sh.log, .../T-009/red-sh.log |
| T-010 | REQ-005 (share — metamorphic output-invariance proof), REQ-006 (item h, metamorphic-completeness suite; share — AC-026/AC-027 feature-wide completeness confirmation), REQ-008 (share) | TEST-045; TEST-026, TEST-027 (feature-wide completeness); TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-010/green-sh.log, .../T-010/red-sh.log |
| T-011 | REQ-007, REQ-006 | TEST-042, TEST-046, TEST-053; TEST-026, TEST-027 feature-wide registration/fixture checks | plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md; tests/resolve-project-context-caller-contract.{sh,ps1}; tests/resolve-project-context-caller-contract-check.py; tests/fixtures/capability-resolver/caller-contract-baseline.json; reports/implementation/epic-193-a5-capability-resolver/T-011.md; protected resolver/workflow human-copy candidates |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-006 |
| AC-002 | TEST-002 | T-006 |
| AC-003 | TEST-003 | T-005 |
| AC-004 | TEST-004 | T-005 |
| AC-005 | TEST-005 | T-005 |
| AC-006 | TEST-006 | T-005 |
| AC-007 | TEST-007 | T-005 |
| AC-008 | TEST-008 | T-005 |
| AC-009 | TEST-009 | T-006 |
| AC-010 | TEST-010 | T-002 (five of sixteen rows), T-003 (five more, ten complete), T-004 (three more, thirteen complete), T-007 (remaining three rows, sixteen complete) — 5 + 5 + 3 + 3 = 16 unique rows; the extra `snapshot-generation-mismatch` fixtures T-003 and T-007 also author introduce no new row, that row being T-004's (corrected 2026-08-27, human-approved, ruling D(2): this cell read "remaining three rows plus one additional shared-row fixture" after "thirteen complete", which sums to seventeen) |
| AC-011 | TEST-011 | T-002 (share), T-003 (share), T-004 (share), T-007 (share, completes) |
| AC-012 | TEST-012 | T-002 (share), T-003 (share), T-004 (share), T-007 (share, completes) |
| AC-013 | TEST-013 | T-002 (share), T-003 (share), T-004 (share), T-007 (share, completes) |
| AC-014 | TEST-014 | T-002 (share), T-003 (share), T-004 (share), T-007 (share, completes) |
| AC-015 | TEST-015 | T-002 |
| AC-016 | TEST-016 | T-005 |
| AC-017 | TEST-017 | T-001 |
| AC-018 | TEST-018 | T-001 |
| AC-019 | TEST-019 | T-001 |
| AC-020 | TEST-020 | T-001 |
| AC-021 | TEST-021 | T-008 |
| AC-022 | TEST-022 | T-009 |
| AC-023 | TEST-023 | T-009 |
| AC-024 | TEST-024 | T-009 |
| AC-025 | TEST-025 | T-009 |
| AC-026 | TEST-026 | T-001..T-011 (share — registration is serialized; T-003, T-004 and T-007 append fixtures to the shared block suite, while T-011 registers the caller pair); confirmed feature-wide at T-011 |
| AC-027 | TEST-027 | T-005 (own `match`-suite setup check), T-011 (feature-wide confirmation including caller fixtures) |
| AC-028 | TEST-028 | T-006 |
| AC-029 | TEST-029 | No task — satisfied by acceptance-tests.md's own Spec-Authoring-Time Manual Review Record |
| AC-030 | TEST-030 | No task — satisfied by acceptance-tests.md's own Spec-Authoring-Time Manual Review Record |
| AC-031 | TEST-031 | No task — satisfied by acceptance-tests.md's own Spec-Authoring-Time Manual Review Record |
| AC-032 | TEST-032 | T-011 verifies that the protected resolver trio/workflow remain human-copy inputs while the reviewed caller SKILL edit is the only plugin-surface change in this integration; the protected manifest is checked before human application |
| AC-033 | TEST-033 | T-001..T-011 (share — each task's own CHANGELOG entry) |
| AC-034 | TEST-034 | T-001..T-011 (share — each task's own version-mutation self-check) |
| AC-035 (Global) | — | No task — registration-commit-bound, verified directly against the live repository when this `tasks.md`/`traceability.md` registration commit lands (Phase 2 orchestration step, not a future implementation task) |
| AC-036 (Global) | — | No task — registration-commit-bound, verified the same way as AC-035 |
| AC-037 (Global) | — | No task — registration-commit-bound, verified the same way as AC-035 |
| AC-038 | TEST-038 | T-002 (share), T-003 (share), T-004 (share), T-007 (share, completes the staged-generation lock) |
| AC-039 | TEST-039 | T-007 |
| AC-040 | TEST-040 | T-004 (first fixture — digest mismatch), T-007 (second fixture — `affected_components`-set-only mismatch) |
| AC-041 | TEST-041 | T-002 |
| AC-042 | TEST-042 | T-011 — caller non-invocation/event-identity contract |
| AC-043 | TEST-043 | T-005 |
| AC-044 | TEST-044 | T-005 |
| AC-045 | TEST-045 | T-010 |
| AC-046 | TEST-046 | T-011 — live caller ordering, single dispatch, Block surfacing, and drift check |
| AC-047 | TEST-047 | T-007 |
| AC-048 | TEST-048 | T-004 |
| AC-049 | TEST-049 | T-007 |
| AC-050 | TEST-050 | T-008 |
| AC-051 | TEST-051 | T-008 |
| AC-052 | TEST-052 | T-005 |
| AC-053 | TEST-053 | T-011 — normalized adjacent-heading digest `sha256:d6ae89cb5f9a0be3d2dcc5789c49ede31ace3f4af2e12b14ae9ef7dc84a2f4ba`, ordinal `4`, and relocation fixture |
| AC-054 | TEST-054 | T-008 |
| AC-055 | TEST-055 | T-004 |
| AC-056 | TEST-056 | T-005 |
| AC-057 | TEST-057 | T-003 (the `registry-swapped-during-validation` fixture at REQ-001 step (e)'s own recheck site; added here 2026-08-27, human-approved, ruling D(2), completing rulings C(1)/C(2)'s propagation — the criterion, its test row and its task ownership all existed, but this mapping table stopped at AC-056, so a verifier reading it could have declared T-003 and the block suite complete without either fail-closed fixture) |
| AC-058 | TEST-058 | T-003 (the `affected-component-absent-from-context` fixture; same propagation gap and same correction as AC-057) |
| AC-059 | TEST-059 | T-007 (the approval-surface write-scope grep self-check; NEW 2026-08-28, human-approved, ruling E — assigned to T-007 because it is the only task in this package that authors a live-artifact write path, and because T-007 is still `Implementation Complete` rather than `Done`, so the criterion lands before its own quality gate rather than as a backfill onto a completed task; the check is TEST-025's kind, a registration-time and CI-gated grep, so no suite is added and T-007 registers nothing new; scanned set corrected 2026-08-28 under the same ruling to the Resolver alone — `resolve-project-context.{py,sh,ps1}`, which T-007 itself authors and can therefore verify in full at its own gate — after the row first also named `validate-resolver-evidence.*`, which requirements.md's Field Definitions exclude from the term *Resolver* and which T-008 authors afterwards) |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #193 | contracts/resolver-evidence.schema.json; tests/resolver-evidence-schema.tests.sh; tests/resolver-evidence-schema.tests.ps1; tests/fixtures/capability-resolver/resolver-evidence-schema/ | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-002 | #193 | tests/resolve-project-context-block.{sh,ps1} (creates the file — five fixtures); tests/fixtures/capability-resolver/ (base tree, five fixtures); specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1} (staged — steps 0-3) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-001); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-003 | #193 | tests/fixtures/capability-resolver/ (five more fixtures) | tests/resolve-project-context-block.{sh,ps1} (five fixtures appended to T-002's own file); specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1} (staged, updated — adds steps 4-9); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 (updated entries); CHANGELOG.md (CREATE #193 entry) |
| T-004 | #193 | tests/fixtures/capability-resolver/ (three more block fixtures) | tests/resolve-project-context-block.{sh,ps1} (three fixtures appended to T-002/T-003's own file); specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1} (staged, updated — adds steps 10-13); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 (updated entries); CHANGELOG.md (CREATE #193 entry) |
| T-005 | #193 | tests/resolve-project-context-match.{sh,ps1}; tests/fixtures/capability-resolver/ (match fixtures) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-002); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-006 | #193 | tests/resolve-project-context-cli.{sh,ps1}; tests/resolve-project-context-lite.{sh,ps1}; tests/resolve-project-context-discovery.{sh,ps1}; tests/fixtures/capability-resolver/ (cli/lite/discovery fixtures) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-005); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-007 | #193 | (none — extends T-002/T-003/T-004's own suite file and T-004's own staged scripts) | tests/resolve-project-context-block.{sh,ps1} (four fixtures appended); specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1} (staged, updated — adds crash-recovery scan and step 14); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 (updated entries); CHANGELOG.md (CREATE #193 entry) |
| T-008 | #193 | plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py; validate-resolver-evidence.sh; validate-resolver-evidence.ps1; tests/validate-resolver-evidence.tests.sh; tests/validate-resolver-evidence.tests.ps1; tests/fixtures/capability-resolver/validate-resolver-evidence/ | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-006); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-009 | #193 | tests/resolve-project-context-parity.tests.sh; tests/resolve-project-context-parity.tests.ps1; tests/fixtures/capability-resolver/parity/ | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-008); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-010 | #193 | tests/resolve-project-context-metamorphic.tests.sh; tests/resolve-project-context-metamorphic.tests.ps1; tests/fixtures/capability-resolver/metamorphic/ | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-009) |
| T-011 | #353 | plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md; tests/resolve-project-context-caller-contract-check.py; tests/resolve-project-context-caller-contract.tests.sh; tests/resolve-project-context-caller-contract.tests.ps1; tests/fixtures/capability-resolver/caller-contract-baseline.json | tests/run-all.ps1; tests/suite-inventory.posix; protected resolver/workflow human-copy candidates; reports/implementation/epic-193-a5-capability-resolver/T-011.md |

## Human-Copy Boundary

T-011 owns the live caller edit and its contract suite. The protected
resolver trio and workflow wiring remain outside agent-write scope and are
applied only from manifest-checked `human-copy/` candidates by a human.

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Implementation reports are claims, not independent verification
evidence.
