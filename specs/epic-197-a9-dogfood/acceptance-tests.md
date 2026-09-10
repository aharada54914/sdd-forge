# Acceptance Tests: epic-197-a9-dogfood

All rows are Planned first-draft mappings. No test has been implemented or run.

| AC | REQ | TEST | Type | Assertion / Oracle | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | automated | schema accepts exact Phase-1 tuple | Planned |
| AC-002 | REQ-001 | TEST-002 | security | missing/invalid binding rejected; human-copy path demonstrated | Planned |
| AC-003 | REQ-002 | TEST-003 | contract | exact nine IDs/fields equal OQ-001 as amended 2026-09-08; `sdd-domain` owns `plugins/sdd-domain/**` independently | Planned |
| AC-004 | REQ-002 | TEST-004 | negative | omission cases TEST-004a–i, extra-ID TEST-004j, and empty-classification TEST-004k each reject | Planned |
| AC-005 | REQ-003 | TEST-005 | ownership | zero unexplained overlaps; TEST-005b rejects a newly introduced overlap | Planned |
| AC-006 | REQ-003 | TEST-006 | ownership | zero unexplained unowned paths; shared rules verified; TEST-006b rejects an unowned tracked path | Planned |
| AC-007 | REQ-004 | TEST-007 | contract | plugin/MCP/installer/CI/release characteristics remain distinct | Planned |
| AC-008 | REQ-005 | TEST-008 | resolver | approved Pack validates and resolves against the defined full-track plugin-code change, never a docs-only substitute | Planned |
| AC-009 | REQ-005 | TEST-009 | scope | no desktop/cloud-service/new durable-workflow Pack added | Planned |
| AC-010 | REQ-006 | TEST-010 | integration | advisory run over the defined full-track plugin-code change emits bound outputs/evidence | Planned |
| AC-011 | REQ-006 | TEST-011 | integration | Pack finding non-blocking; existing blockers unchanged | Planned |
| AC-012 | REQ-007 | TEST-012 | evidence | promotion record has every REQ-007 field and link | Planned |
| AC-013 | REQ-007 | TEST-013 | negative | unmet threshold and stale evidence each reject promotion | Planned |
| AC-014 | REQ-008 | TEST-014 | automated | schema/resolver accept exact Phase-2 tuple | Planned |
| AC-015 | REQ-008 | TEST-015 | negative | layout-only and enforcement-only transitions each reject | Planned |
| AC-016 | REQ-009 | TEST-016 | security | multi-identity rollback requires two distinct approvals | Planned |
| AC-017 | REQ-009 | TEST-017 | security | solo rollback rejects before and accepts at/after effective time | Planned |
| AC-018 | REQ-009 | TEST-018 | security | unsigned, self-approved, duplicate, unbound sidecars each reject; TEST-018a/b revalidate changed registry | Planned |
| AC-019 | REQ-010 | TEST-019 | process | observed friction yields complete Draft WFI, never Approved | Planned |
| AC-020 | REQ-011 | TEST-020 | preflight | one absent/incompatible A1–A8 surface blocks with identity | Planned |
| AC-021 | REQ-011 | TEST-021 | preflight | six named shared-state inventories/hashes recorded | Planned |
| AC-022 | REQ-012 | TEST-022 | parity | applicable shell and PowerShell entry points pass | Planned |
| AC-023 | REQ-012 | TEST-023 | CI | checks run on three OSes in existing topology | Planned |
| AC-024 | REQ-012 | TEST-024 | regression | Phase 1/2 preserve three-host install/release behavior | Planned |
| AC-025 | REQ-013 | TEST-025 | ownership | `specs/` and every approved growing path are cross-cutting from bootstrap | Planned |
| AC-026 | REQ-014 | TEST-026 | provenance | all A1-A8 dependencies usable; #197 recorded under #187 | Planned |
| AC-027 | REQ-006 | TEST-027 | operational | every PR in one bounded full release cycle passed advisory Gate | Planned |
| AC-028 | REQ-008 | TEST-028 | end-to-end | one real post-promotion feature completes under facet-hybrid/required | Planned |
| AC-029 | REQ-010 | TEST-029 | process | friction WFI references recorded, or literal `none` when zero | Planned |
| AC-032 | REQ-003 | TEST-032 | ownership | each component includes tracked paths and recomputed ownership digest equals recorded digest | Planned |
| AC-033 | REQ-008 | TEST-033 | negative | required activation rejects each missing-evidence case TEST-033a–c | Planned |

Coverage note: AC-015 expands both partial-transition branches; AC-018 expands
all four invalid-sidecar branches; AC-021's oracle covers Registry, guards,
components, Active Specs, WFI namespace, and protected targets individually.
AC-027 quantifies over every PR in the named cycle; AC-029 covers both observed
friction and zero-friction branches and names path ownership, staleness, and
approval flow individually.

## OQ-001 amendment coverage (2026-09-08)

These are planned oracles, not executed tests. TEST-003 compares the exact set
`sdd-bootstrap`, `sdd-review-loop`, `sdd-implementation`, `sdd-quality-loop`,
`sdd-ship`, `sdd-lite`, `sdd-domain`, `mcp`, `installer`; an extra or missing ID
fails. It checks `plugins/sdd-domain/**` maps only to `sdd-domain`, not another
component or cross-cutting. TEST-004 has a separate omitted-ID case for each
of those nine IDs and a separate unjustified-empty-classification case.
TEST-006 includes the actual tracked domain-plugin files in its coverage input;
a fixture using only the nonexistent historical spelling `plugins/domain/**`
cannot satisfy that coverage. The other round-1 findings remain unresolved.

The following individually identified cases expand the amended component-set
contract. They are specifications only; none is implementation or PASS evidence.

| AC | REQ | TEST | Assertion / Oracle | Status |
|---|---|---|---|---|
| AC-004 | REQ-002 | TEST-004a | Remove only `sdd-bootstrap` from the otherwise valid nine-component fixture; reject inventory. | Planned |
| AC-004 | REQ-002 | TEST-004b | Remove only `sdd-review-loop`; reject inventory. | Planned |
| AC-004 | REQ-002 | TEST-004c | Remove only `sdd-implementation`; reject inventory. | Planned |
| AC-004 | REQ-002 | TEST-004d | Remove only `sdd-quality-loop`; reject inventory. | Planned |
| AC-004 | REQ-002 | TEST-004e | Remove only `sdd-ship`; reject inventory. | Planned |
| AC-004 | REQ-002 | TEST-004f | Remove only `sdd-lite`; reject inventory. | Planned |
| AC-004 | REQ-002 | TEST-004g | Remove only `sdd-domain`; reject inventory, including the historical eight-component fixture. | Planned |
| AC-004 | REQ-002 | TEST-004h | Remove only `mcp`; reject inventory. | Planned |
| AC-004 | REQ-002 | TEST-004i | Remove only `installer`; reject inventory. | Planned |
| AC-004 | REQ-002 | TEST-004j | Add an unapproved tenth ID to the valid nine-component fixture; reject inventory. | Planned |
| AC-004 | REQ-002 | TEST-004k | Retain all nine IDs but empty a required classification without justification; reject classification. | Planned |
| AC-003 | REQ-002 | TEST-003a | Keep the nine IDs but assign a tracked `plugins/sdd-domain/` file to another component instead; reject the OQ-001 ownership contract. | Planned |
| AC-005 | REQ-003 | TEST-005a | Keep the domain owner and also match the same tracked domain file to another component without an approved shared rule; ownership validation blocks publication. | Planned |
| AC-003 | REQ-002 | TEST-003b | Classify a tracked domain file as cross-cutting instead of its exclusive `sdd-domain` owner; reject the OQ-001 ownership contract. | Planned |
| AC-006 | REQ-003 | TEST-006a | Replace the canonical domain include with nonexistent `plugins/domain/**`; tracked domain files remain unowned and ownership validation blocks publication. | Planned |

## Existing edge-case coverage repair (2026-09-08)

These rows make the existing requirements Edge Cases observable. They do not
change the approval model or retrospectively clear round-1 findings.

| AC | REQ | TEST | Assertion / Oracle | Status |
|---|---|---|---|---|
| AC-005 | REQ-003 | TEST-005b | In an otherwise valid fixture, add a second component match for one tracked path outside the domain fixture, with no shared rule; Phase-1 publication rejects and identifies the overlapping path. | Planned |
| AC-006 | REQ-003 | TEST-006b | Add a tracked fixture path matching neither component nor shared rules; Phase-1 publication rejects and identifies the unowned path. | Planned |
| AC-018 | REQ-009 | TEST-018a | Request solo rollback with one registered identity, then add a second real identity before the signed effective time. At that time, revalidate against the changed registry and reject the solo approval despite elapsed cooldown. | Planned |
| AC-018 | REQ-009 | TEST-018b | In the changed-registry fixture, provide two distinct approvals valid under the current registry and satisfying all remaining binding checks; current-registry validation accepts. Persist the registry revision used so stale request-time evaluation cannot satisfy the oracle. | Planned |

Edge Cases mapping: no owner → TEST-006b; multiple owners → TEST-005b;
stale resolver evidence → TEST-013; changed approver registry → TEST-018a/b;
zero friction → TEST-029. All remain Planned pending implementation and execution.

## Non-conflicting prior remediation (2026-09-08)

These cases restore the reverse-coverage, ownership-digest and premature
enforcement checks from candidate 4349ae40 without restoring its superseded
eight-component ruling or its unresolved characteristic-override schema.
The valid fixture has all nine approved components and current evidence;
each negative fixture changes only the named condition.

| AC | REQ | TEST | Assertion / Oracle | Status |
|---|---|---|---|---|
| AC-032 | REQ-003 | TEST-032a | Valid nine-component map: every component include set matches tracked paths and the recomputed digest equals the recorded digest; ownership validation accepts. | Planned |
| AC-032 | REQ-003 | TEST-032b | Retain a component but replace its include set with a nonmatching path; reverse-coverage validation rejects publication and names that component. | Planned |
| AC-032 | REQ-003 | TEST-032c | Keep the valid map but change the recorded ownership digest; recomputation rejects publication with a digest mismatch. | Planned |
| AC-033 | REQ-008 | TEST-033a | Request required activation with valid resolver evidence but no selected Pack evidence; reject activation. | Planned |
| AC-033 | REQ-008 | TEST-033b | Request required activation with valid selected Pack evidence but no resolver evidence; reject activation. | Planned |
| AC-033 | REQ-008 | TEST-033c | Request required activation without either selected Pack or resolver evidence; reject activation. | Planned |

AC-014/TEST-014 covers the corresponding valid Phase-2 tuple with all required
evidence; the negative cases must not weaken that existing positive case.
AC-030/031 are intentionally not introduced before their contract is reconciled.

## Growing-path clarification coverage (2026-09-08)

These fixtures implement the observable contract of the human-approved OQ-002
definition. They are Planned specifications, not executed tests. Each of
TEST-025a–g adds a tracked descendant after bootstrap and asserts cross-cutting
classification without adding a new ownership rule.

| AC | REQ | TEST | Assertion / Oracle | Status |
|---|---|---|---|---|
| AC-025 | REQ-013 | TEST-025a | New `specs/` descendant remains cross-cutting through the bootstrap rule. | Planned |
| AC-025 | REQ-013 | TEST-025b | New `tests/` descendant remains cross-cutting through the bootstrap rule. | Planned |
| AC-025 | REQ-013 | TEST-025c | New `contracts/` descendant remains cross-cutting through the bootstrap rule. | Planned |
| AC-025 | REQ-013 | TEST-025d | New `docs/` descendant remains cross-cutting through the bootstrap rule. | Planned |
| AC-025 | REQ-013 | TEST-025e | New `reports/` descendant remains cross-cutting through the bootstrap rule. | Planned |
| AC-025 | REQ-013 | TEST-025f | New `marketplaces/` descendant remains cross-cutting through the bootstrap rule. | Planned |
| AC-025 | REQ-013 | TEST-025g | New `.github/` descendant remains cross-cutting through the bootstrap rule. | Planned |
| AC-006 | REQ-003 | TEST-025h | The four approved root metadata files each match their separate exact-path shared rule, not a growing-directory or catch-all rule. | Planned |
| AC-006 | REQ-003 | TEST-025i | Add an unlisted root file with no ownership rule; publication rejects it as unowned rather than implicitly sharing it. | Planned |
| AC-003 | REQ-002 | TEST-025j | Root install/uninstall scripts retain the `installer` owner; broadening the shared map to absorb them rejects the approved-map oracle. | Planned |
| AC-025 | REQ-013 | TEST-025k | Remove one of the seven bootstrap directory rules, in seven separate fixture cases; each rejects bootstrap conformance even if the missing rule is added later. | Planned |
