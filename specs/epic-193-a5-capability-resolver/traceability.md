# Traceability: epic-193-a5-capability-resolver

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-003, INV-005, INV-006, INV-007, INV-010, INV-012, INV-013 | security-spec.md#trust-boundaries; infra-spec.md#cicd-sequence; infra-spec.md#journal-recovery | design.md#architecture; design.md#api--contract-plan (`resolve-project-context.{py,sh,ps1}` CLI contract, steps 0-14); design.md#design-decisions-resolving-open-questions (union-match; staged generation, journaled transactional commit; track-exclusive publication set); design.md#resolver-publication-transactional-bundle-contract | `resolve-project-context.py` CLI: `--config`/`--source-rev`/`--target-rev`/`--include-untracked`/`--feature`; steps 0-13 (state derivation, canonicalization, Context Projection, `resolve-component-paths`/Registry/`evaluate-predicate` fan-out, track branch, Evidence assembly, output schema self-validation, pre-publication recheck) and step 14 (journaled publication transaction) | plugins/sdd-quality-loop/scripts/resolve-project-context.py; resolve-project-context.sh; resolve-project-context.ps1 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007, TEST-008, TEST-009, TEST-016, TEST-028, TEST-038, TEST-039, TEST-040, TEST-041, TEST-043, TEST-044, TEST-047, TEST-048, TEST-049, TEST-052 | reports/quality-gate/ for T-002, T-003, T-004; specs/epic-193-a5-capability-resolver/verification/{T-002,T-003,T-004}/ | Planned |
| REQ-002 | investigation.md INV-013, INV-019, INV-020 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#api--contract-plan (sixteen-row Block diagnostic-id table); design.md#resolver-publication-transactional-bundle-contract; design.md#global-constraints (closed sixteen-value enum) | `diagnostics[].id` (sixteen-value closed enum); exit-code contract `0`/`1`/`2`; `capability-resolver: <check-id>: <detail>` diagnostic-line format | plugins/sdd-quality-loop/scripts/resolve-project-context.py; resolve-project-context.sh; resolve-project-context.ps1 | TEST-010, TEST-011, TEST-012, TEST-013, TEST-014, TEST-015, TEST-038, TEST-039, TEST-040, TEST-041, TEST-047, TEST-048, TEST-049, TEST-055 | reports/quality-gate/ for T-002, T-004; specs/epic-193-a5-capability-resolver/verification/{T-002,T-004}/ | Planned |
| REQ-003 | investigation.md INV-006, INV-007, INV-013 | security-spec.md#trust-boundaries | design.md#api--contract-plan step 1 (state derivation); design.md#constraint-compliance | `disabled-legacy`/`advisory`/`required` derivation from `workflow.capability_enforcement`; `disabled-legacy-invocation` Block (not a graceful no-op, diverging from `check-component-coverage`) | plugins/sdd-quality-loop/scripts/resolve-project-context.py | TEST-015, TEST-016 | reports/quality-gate/ for T-002; specs/epic-193-a5-capability-resolver/verification/T-002/ | Planned |
| REQ-004 | investigation.md INV-004, INV-011, INV-018 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#data-plan (Resolver Evidence entity, "B6 Evidence completeness", "B7 predicate-instance keying", "B9"); design.md#contracts-resolver-evidenceschemajson-req-004; design.md#validate-resolver-evidencepyshps1-contract-req-004 | `contracts/resolver-evidence.schema.json` (`sdd-resolver-evidence/v1`); `capability_evaluations[]`/`diagnostics[]` exact-set/cardinality/bidirectional-consistency rules; `validate-resolver-evidence` twelve-value check-id enum + provenance-binding procedure | contracts/resolver-evidence.schema.json; plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py; validate-resolver-evidence.sh; validate-resolver-evidence.ps1; plugins/sdd-quality-loop/scripts/resolve-project-context.py (Evidence assembly, step 11) | TEST-017, TEST-018, TEST-019, TEST-020, TEST-021, TEST-044, TEST-050, TEST-051, TEST-054, TEST-056 | reports/quality-gate/ for T-001, T-002, T-004, T-005; specs/epic-193-a5-capability-resolver/verification/{T-001,T-002,T-004,T-005}/ | Planned |
| REQ-005 | investigation.md INV-005, INV-007, INV-009, INV-011 | security-spec.md#trust-boundaries; infra-spec.md#cicd-sequence | design.md#global-constraints (stable-sort, diagnostic determinism contract); design.md#security-boundaries (no clock/network/provider-API); design.md#test-strategy items 5, 9 | Repeated-`.py`-invocation determinism; `.py`/`.sh`/`.ps1` byte-identical parity; stable-sorted `capability_evaluations[]`/`diagnostics[]`/every Epic-A4-mandated array; input-order invariance | plugins/sdd-quality-loop/scripts/resolve-project-context.py; resolve-project-context.sh; resolve-project-context.ps1; plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py; validate-resolver-evidence.sh; validate-resolver-evidence.ps1 | TEST-022, TEST-023, TEST-024, TEST-025, TEST-045 | reports/quality-gate/ for T-002, T-004, T-005, T-006, T-007; specs/epic-193-a5-capability-resolver/verification/{T-002,T-004,T-005,T-006,T-007}/ | Planned |
| REQ-006 | investigation.md (Test Strategy contract, design.md#test-strategy items 1-10) | infra-spec.md#cicd-sequence; security-spec.md#trust-boundaries | design.md#test-strategy (ten suites; nine scheduled by this tasks.md, one deferred) | `tests/*.tests.sh`/`.tests.ps1` pairs + `tests/fixtures/capability-resolver/`, REQ-006 items a-h | tests/resolve-project-context-cli.{sh,ps1}; tests/resolve-project-context-block.{sh,ps1}; tests/resolve-project-context-match.{sh,ps1}; tests/resolve-project-context-lite.{sh,ps1}; tests/resolve-project-context-discovery.{sh,ps1}; tests/resolver-evidence-schema.{sh,ps1}; tests/validate-resolver-evidence.{sh,ps1}; tests/resolve-project-context-parity.{sh,ps1}; tests/resolve-project-context-metamorphic.{sh,ps1}; tests/run-all.{sh,ps1} | TEST-026, TEST-027, TEST-028, TEST-045 | reports/quality-gate/ for T-001..T-007; specs/epic-193-a5-capability-resolver/verification/{T-001..T-007}/ | Planned |
| REQ-007 | investigation.md INV-017, OQ-003 (resolved) | N/A — cross-layer only: documentation-only integration-contract citation for a future caller's own file, no UI/frontend/infra/security surface of its own (ux-spec.md and frontend-spec.md both record N/A) | design.md#design-decisions-resolving-open-questions ("caller insertion point", "anchor fingerprint") | Target integration contract only — no code; insertion point `SKILL.md:60`'s `### Full-Profile Layer Interview` heading, anchor-fingerprint `sha256:d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64` + section-order index `3` | (documentation only — no file this package's own tasks write; the future `SKILL.md` edit and its own `resolve-project-context-caller-contract.{sh,ps1}` suite are explicitly out of this tasks.md's own scope, tasks.md Global Constraints "Deferred, Not Scheduled") | TEST-029, TEST-030, TEST-031, TEST-032 (satisfied — Spec-Authoring-Time Manual Review Record, acceptance-tests.md); TEST-042, TEST-046, TEST-053 (deferred — not scheduled by any task below) | acceptance-tests.md "Spec-Authoring-Time Manual Review Record" (AC-029..AC-032, confirmed present) | Documented (AC-029..032) / Deferred (AC-042, AC-046, AC-053) — no task |
| REQ-008 | investigation.md (documentation/versioning discipline, matching every sibling epic's own REQ) | infra-spec.md#cicd-sequence | design.md#constraint-compliance (`AGENTS.md` Rules cross-reference); design.md#adr-change-log (no new ADR) | Per-task `CHANGELOG.md` `## Unreleased` entry citing #193; grep-based no-version-mutation self-check | CHANGELOG.md | TEST-033, TEST-034 | reports/quality-gate/ for T-001..T-006; specs/epic-193-a5-capability-resolver/verification/{T-001..T-006}/ | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — deterministic CLI script family + validator + schema + documented (not implemented) caller-integration contract only | ux-spec.md | No rendered or interactive surface anywhere in this feature's own deliverables (design.md Layer Specifications; ux-spec.md's own "N/A — no change" record). The future capability interview phase's own conversational prompts are REQ-007's target-contract scope to name, not this feature's own UI to design or implement. |
| Frontend | N/A — no browser/frontend bundle | N/A — CLI/script feature work | frontend-spec.md#technology-stack | stdlib-only Python master + `sh`/`ps1` wrappers + fixture tree + one new JSON Schema document is not a frontend surface; frontend-spec.md records N/A. |
| Infrastructure | REQ-001, REQ-005, REQ-006, REQ-007, REQ-008 | AC-026, AC-028, AC-032, AC-033, AC-034 | infra-spec.md#cicd-sequence; infra-spec.md#journal-recovery; infra-spec.md#rollback | Nine new `.sh`/`.ps1` suite pairs register directly in `tests/run-all.*` (T-001..T-007, serialized order per tasks.md Global Constraints) and stage their `.github/workflows/test.yml` CI steps via a single shared human-copy candidate (R-10 protected, INV-010-equivalent boundary); the tenth suite (`resolve-project-context-caller-contract`) is explicitly deferred to a future, not-yet-scheduled task (design.md Test Strategy item 10) — AC-026's own "ten suites" wording is therefore satisfied by this package's own tasks for nine of ten only, a gap named explicitly rather than silently under-delivered. `resolve-project-context.{py,sh,ps1}`'s own content-population registration (two already-reserved protected paths inherited from Epic A1) is likewise human-copy staged, never a direct agent write. |
| Security | REQ-001, REQ-002, REQ-003, REQ-004, REQ-005 | AC-011, AC-012, AC-021, AC-025, AC-038, AC-039, AC-047, AC-049, AC-050, AC-051, AC-054 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | Journaled publication transaction / crash-recovery scan / pre- and post-publication snapshot rechecks (T-004) close the atomicity and TOCTOU gaps adversarial review found in an earlier revision (B1/B8); `validate-resolver-evidence`'s own provenance-binding procedure (T-005) closes the "caller-supplied Registry/affected-component-set trusted blindly" gap (B6); the Resolver's own orchestration logic never reads a credential, contacts a network endpoint, or invokes a provider API (REQ-005/Security Boundaries, AC-025's repository-wide grep); every diagnostic `<detail>` is a canonical, Resolver-owned sentence, never a dependency subprocess's own raw stderr (M8). Two already-reserved protected paths inherited from Epic A1 (Protected-File Statement) — no new protection category is introduced by this feature. |

## Task Mapping

Task decomposition revised by task-review round-1 remedy (closing a
TASK-SIZE finding on the original T-002): the core evaluation engine
(T-002) and its own CLI-validation/discovery-contract/Lite-track test
suites (new T-003) are now separate tasks; every task from the original
T-003 onward renumbers up by one. See `reports/task-review/epic-193-a5-
capability-resolver/attempt-1/round-1/tasks-round-1-proposed-changes.md`.

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-004 (schema), REQ-006 (share — item e, one of sixteen Block rows represented structurally), REQ-008 (share) | TEST-017, TEST-018, TEST-019, TEST-020; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-001/green-sh.log, .../T-001/red-sh.log |
| T-002 | REQ-001 (steps 0-13, core evaluation engine only — AC-001/002/009/028 are T-003's own dedicated coverage), REQ-002 (share — twelve of sixteen non-transactional rows), REQ-003, REQ-004 (share — Evidence assembly logic), REQ-005 (share — determinism baseline), REQ-006 (share — items a-d, e [twelve rows], f, g), REQ-008 (share) | TEST-003..TEST-008, TEST-010..TEST-015 (share — twelve of sixteen rows, completed by T-004), TEST-016, TEST-038 (share), TEST-040 (share — first fixture), TEST-041, TEST-043, TEST-044, TEST-048, TEST-052, TEST-055, TEST-056; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-002/green-sh.log, .../T-002/red-sh.log, specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 (three staged script entries) |
| T-003 | REQ-001 (share — AC-001 CLI required-flag matrix, AC-002/AC-028 discovery-contract reuse, AC-009 Lite-track schema-conformance, split out of T-002 by task-review round-1 remedy), REQ-006 (share — discovery/Lite-track fixture-matrix items), REQ-008 (share) | TEST-001, TEST-002, TEST-009, TEST-028; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-003/green-sh.log, .../T-003/red-sh.log |
| T-004 | REQ-001 (share — step 0 crash-recovery scan, step 14 transaction), REQ-002 (share — four transactional rows), REQ-004 (share — Evidence committed via this transaction), REQ-005 (share — determinism preserved across crash/rollback), REQ-006 (share — item e's remaining four rows), REQ-008 (share) | TEST-010..TEST-015 (share — remaining four rows, completing the sixteen-row matrix), TEST-038 (share, completing), TEST-039, TEST-040 (share — second fixture), TEST-047, TEST-049; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-004/green-sh.log, .../T-004/red-sh.log, specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 (updated script entries) |
| T-005 | REQ-004 (validator), REQ-005 (share — `array-not-stable-sorted` check), REQ-006 (share — item h's provenance-binding pair), REQ-008 (share) | TEST-021, TEST-050, TEST-051, TEST-054; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-005/green-sh.log, .../T-005/red-sh.log |
| T-006 | REQ-005 (parity/determinism proof), REQ-006 (share — item i, dual-runtime parity suite), REQ-008 (share) | TEST-022, TEST-023, TEST-024, TEST-025; TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-006/green-sh.log, .../T-006/red-sh.log |
| T-007 | REQ-005 (share — metamorphic output-invariance proof), REQ-006 (item h, metamorphic-completeness suite; share — AC-026/AC-027 feature-wide completeness confirmation), REQ-008 (share) | TEST-045; TEST-026, TEST-027 (feature-wide completeness, nine-of-ten-suites scope); TEST-033/TEST-034 shares scoped to this task's own diff and issue #193 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-193-a5-capability-resolver/verification/T-007/green-sh.log, .../T-007/red-sh.log |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-003 |
| AC-002 | TEST-002 | T-003 |
| AC-003 | TEST-003 | T-002 |
| AC-004 | TEST-004 | T-002 |
| AC-005 | TEST-005 | T-002 |
| AC-006 | TEST-006 | T-002 |
| AC-007 | TEST-007 | T-002 |
| AC-008 | TEST-008 | T-002 |
| AC-009 | TEST-009 | T-003 |
| AC-010 | TEST-010 | T-002 (twelve of sixteen rows), T-004 (remaining four rows, completes the matrix) |
| AC-011 | TEST-011 | T-002 (share), T-004 (share, completes) |
| AC-012 | TEST-012 | T-002 (share), T-004 (share, completes) |
| AC-013 | TEST-013 | T-002 |
| AC-014 | TEST-014 | T-002 (share), T-004 (share, completes) |
| AC-015 | TEST-015 | T-002 |
| AC-016 | TEST-016 | T-002 |
| AC-017 | TEST-017 | T-001 |
| AC-018 | TEST-018 | T-001 |
| AC-019 | TEST-019 | T-001 |
| AC-020 | TEST-020 | T-001 |
| AC-021 | TEST-021 | T-005 |
| AC-022 | TEST-022 | T-006 |
| AC-023 | TEST-023 | T-006 |
| AC-024 | TEST-024 | T-006 |
| AC-025 | TEST-025 | T-006 |
| AC-026 | TEST-026 | T-001..T-007 (share — each task registers its own suite; confirmed feature-wide at T-007; scoped to nine of ten suites, tenth deferred per tasks.md Global Constraints) |
| AC-027 | TEST-027 | T-002 (own suite's setup check), T-007 (feature-wide confirmation once every suite exists) |
| AC-028 | TEST-028 | T-003 |
| AC-029 | TEST-029 | No task — satisfied by acceptance-tests.md's own Spec-Authoring-Time Manual Review Record |
| AC-030 | TEST-030 | No task — satisfied by acceptance-tests.md's own Spec-Authoring-Time Manual Review Record |
| AC-031 | TEST-031 | No task — satisfied by acceptance-tests.md's own Spec-Authoring-Time Manual Review Record |
| AC-032 | TEST-032 | No task-specific implementation; re-checked (`git diff --stat`, no `plugins/**` path) as part of every task's own Done When (T-001..T-007) |
| AC-033 | TEST-033 | T-001..T-007 (share — each task's own CHANGELOG entry) |
| AC-034 | TEST-034 | T-001..T-007 (share — each task's own version-mutation self-check) |
| AC-035 (Global) | — | No task — registration-commit-bound, verified directly against the live repository when this `tasks.md`/`traceability.md` registration commit lands (Phase 2 orchestration step, not a future implementation task) |
| AC-036 (Global) | — | No task — registration-commit-bound, verified the same way as AC-035 |
| AC-037 (Global) | — | No task — registration-commit-bound, verified the same way as AC-035 |
| AC-038 | TEST-038 | T-002 (share — `lite-check-source-undefined`/`output-schema-validation-failed`/first `snapshot-generation-mismatch` examples), T-004 (share, completes the staged-generation lock) |
| AC-039 | TEST-039 | T-004 |
| AC-040 | TEST-040 | T-002 (first fixture — digest mismatch), T-004 (second fixture — `affected_components`-set-only mismatch) |
| AC-041 | TEST-041 | T-002 |
| AC-042 | TEST-042 | No task — deferred (design.md Test Strategy item 10; caller-contract suite not scheduled) |
| AC-043 | TEST-043 | T-002 |
| AC-044 | TEST-044 | T-002 |
| AC-045 | TEST-045 | T-007 |
| AC-046 | TEST-046 | No task — deferred (design.md Test Strategy item 10; caller-contract suite not scheduled) |
| AC-047 | TEST-047 | T-004 |
| AC-048 | TEST-048 | T-002 |
| AC-049 | TEST-049 | T-004 |
| AC-050 | TEST-050 | T-005 |
| AC-051 | TEST-051 | T-005 |
| AC-052 | TEST-052 | T-002 |
| AC-053 | TEST-053 | No task — deferred (design.md Test Strategy item 10; caller-contract suite not scheduled). The two fingerprint values themselves (`sha256:d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64`, section-order index `3`) are already recorded by design.md's own Design Decisions section; only the automated drift-check fixture is deferred. |
| AC-054 | TEST-054 | T-005 |
| AC-055 | TEST-055 | T-002 |
| AC-056 | TEST-056 | T-002 |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #193 | contracts/resolver-evidence.schema.json; tests/resolver-evidence-schema.tests.sh; tests/resolver-evidence-schema.tests.ps1; tests/fixtures/capability-resolver/resolver-evidence-schema/ | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-002 | #193 | tests/resolve-project-context-match.{sh,ps1}; tests/resolve-project-context-block.{sh,ps1}; tests/fixtures/capability-resolver/ (base tree); specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1} (staged) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-001); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-003 | #193 | tests/resolve-project-context-cli.{sh,ps1}; tests/resolve-project-context-lite.{sh,ps1}; tests/resolve-project-context-discovery.{sh,ps1}; tests/fixtures/capability-resolver/ (cli/lite/discovery fixtures) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-002); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-004 | #193 | (none — extends T-002's own suite and staged scripts) | tests/resolve-project-context-block.{sh,ps1} (fixtures appended); specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1} (staged, updated); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 (updated entries); CHANGELOG.md (CREATE #193 entry) |
| T-005 | #193 | plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py; validate-resolver-evidence.sh; validate-resolver-evidence.ps1; tests/validate-resolver-evidence.tests.sh; tests/validate-resolver-evidence.tests.ps1; tests/fixtures/capability-resolver/validate-resolver-evidence/ | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-003); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-006 | #193 | tests/resolve-project-context-parity.tests.sh; tests/resolve-project-context-parity.tests.ps1; tests/fixtures/capability-resolver/parity/ | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-005); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |
| T-007 | #193 | tests/resolve-project-context-metamorphic.tests.sh; tests/resolve-project-context-metamorphic.tests.ps1; tests/fixtures/capability-resolver/metamorphic/ | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #193 entry); specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml (staged, appended after T-006 — the final entry); specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256 |

## Deferred, Not Scheduled

`tests/resolve-project-context-caller-contract.tests.sh`/`.ps1` (design.md
Test Strategy item 10) exercises the live `sdd-bootstrap-interviewer/
SKILL.md`'s own capability interview phase — a phase requirements.md's own
Non-goals excludes this package's tasks from implementing. Its own
fixture-level contract (the anchor window sha256, the section-order index,
the non-invocation/single-invocation/Block-surfacing assertions) is
already fixed by design.md's own Design Decisions section; only the suite
file itself is deferred, to whichever future, not-yet-scheduled task
actually inserts the `### Capability Interview Phase` subsection into
`SKILL.md`. AC-042, AC-046, and AC-053 (TEST-042, TEST-046, TEST-053) are
therefore not mapped to any task above, and REQ-007's own row in this
document's Requirements table records "Documented / Deferred — no task"
rather than "Planned". This mirrors requirements.md's own Non-goals
("Editing `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/
SKILL.md`... is a future implementation task's own responsibility") and
design.md's own explicit statement that Test Strategy item 10 "is itself
authored once the capability interview phase is actually implemented (a
future task, Non-goals)."

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Implementation reports are claims, not independent verification
evidence.
