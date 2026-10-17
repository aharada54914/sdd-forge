# Acceptance Tests: epic-197-a9-dogfood

All rows are Planned first-draft mappings. No test has been implemented or run.

| AC | REQ | TEST | Type | Assertion / Oracle | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | automated | schema accepts exact Phase-1 tuple | Planned |
| AC-002 | REQ-001 | TEST-002 | security | missing/invalid binding rejected; human-copy path demonstrated | Planned |
| AC-003 | REQ-002 | TEST-003 | contract | exact nine IDs, classification values/justified omissions, and OQ-002 paths equal approved decomposition and dated A9 classification oracle; domain path remains exclusively owned | Planned |
| AC-004 | REQ-002 | TEST-004 | negative | omission cases TEST-004a–i, extra-ID TEST-004j, empty-classification TEST-004k, and per-field negatives TEST-003c–i each reject | Planned |
| AC-005 | REQ-003 | TEST-005 | ownership | zero unexplained overlaps; TEST-005b rejects a newly introduced overlap | Planned |
| AC-006 | REQ-003 | TEST-006 | ownership | zero unexplained unowned paths; shared rules verified; TEST-006b rejects an unowned tracked path | Planned |
| AC-007 | REQ-004 | TEST-007 | contract | plugin/MCP/installer/CI/release characteristics remain distinct | Planned |
| AC-008 | REQ-005 | TEST-008a–n | resolver/review | exact minimal Pack contract below; representative run uses full-track plugin code, never a docs-only substitute | Planned |
| AC-009 | REQ-005 | TEST-009 | scope | no desktop/cloud-service/new durable-workflow Pack added | Planned |
| AC-010 | REQ-006 | TEST-010 | integration | advisory run over the defined full-track plugin-code change emits bound outputs/evidence | Planned |
| AC-011 | REQ-006 | TEST-011 | integration | Pack finding non-blocking; existing blockers unchanged | Planned |
| AC-012 | REQ-007 | TEST-012 | evidence | promotion record has every REQ-007 field and link | Planned |
| AC-013 | REQ-007 | TEST-013 (TEST-013a/b, TEST-013c1–c3, TEST-013d1–d2, TEST-013e) | negative | four independent OQ-003 failure conditions (including each OS lane and missing/failed rehearsal) and stale evidence each reject promotion | Planned |
| AC-014 | REQ-008 | TEST-014 | automated | schema/resolver accept exact Phase-2 tuple | Planned |
| AC-015 | REQ-008 | TEST-015 | negative | layout-only and enforcement-only transitions each reject | Planned |
| AC-016 | REQ-009 | TEST-016 | security | multi-identity rollback requires two distinct approvals | Planned |
| AC-017 | REQ-009 | TEST-017a–c | security | with `effective_at` set to first approval + 24h, reject immediately before, accept exactly at, and accept immediately after the signed boundary for a valid one-identity rollback | Planned |
| AC-018 | REQ-009 | TEST-018a–i, TEST-018c2 | security | separate changed-registry, zero-identity-at-request/application, four invalid sidecar, and invalid Ed25519-record-signature assertions | Planned |
| AC-019 | REQ-010 | TEST-019 | process | observed friction yields complete Draft WFI, never Approved | Planned |
| AC-020 | REQ-011 | TEST-020 (TEST-020a–p) | preflight | for each A1–A8 epic, an absent and an incompatible required surface independently block and identify the epic/surface | Planned |
| AC-021 | REQ-011 | TEST-021 | preflight | six named shared-state inventories/hashes recorded | Planned |
| AC-022 | REQ-012 | TEST-022 | parity | applicable shell and PowerShell entry points pass | Planned |
| AC-023 | REQ-012 | TEST-023 | CI | checks run on three OSes in existing topology | Planned |
| AC-024 | REQ-012 | TEST-024 | regression | Phase 1/2 preserve three-host install/release behavior | Planned |
| AC-025 | REQ-013 | TEST-025 | ownership | `specs/` and every approved growing path are cross-cutting from bootstrap | Planned |
| AC-026 | REQ-014 | TEST-026 | provenance | all A1-A8 dependencies usable; #197 recorded under #187 | Planned |
| AC-027 | REQ-006 | TEST-027 | operational | every PR in one bounded full release cycle passed advisory Gate | Planned |
| AC-028 | REQ-008 | TEST-028 | end-to-end | one real post-promotion feature completes under facet-hybrid/required | Planned |
| AC-029 | REQ-010 | TEST-029 | process | friction WFI references recorded, or literal `none` when zero | Planned |
| AC-030 | REQ-004 | TEST-030 | contract | live Context has exactly two entries: `mcp` / `mcp/ci-mcp` / `credential_bearing: true`; OQ-002 `.github/**` rule / `.github/**` / `release_write: true`, exercised on `.github/workflows/release.yml`; other count/scope/name/value rejects | Planned |
| AC-031 | REQ-004 | TEST-031a–k | negative | unknown name, out-of-scope, both per-characteristic no-ops, four missing fields, extra field, and each invalid record placement independently reject | Planned |
| AC-032 | REQ-003 | TEST-032 | ownership | each component includes tracked paths and recomputed ownership digest equals recorded digest | Planned |
| AC-033 | REQ-008 | TEST-033 | negative | required activation rejects each missing-evidence case TEST-033a–c | Planned |
| AC-034 | REQ-009 | TEST-034 | security | registry-cardinality change mid-cooldown re-evaluates the branch with the current registry | Planned |
| AC-035 | REQ-007, REQ-008 | TEST-035a–c | security | otherwise ready Phase-2 publication rejects absent, wrong-transition-bound, and agent-authored approval separately | Planned |

Coverage note: AC-013 expands all four OQ-003 conditions plus stale evidence;
AC-015 expands both partial-transition branches; AC-018 expands
all four invalid-sidecar branches; AC-021's oracle covers Registry, guards,
components, Active Specs, WFI namespace, and protected targets individually.
AC-027 quantifies over every PR in the named cycle; AC-029 covers both observed
friction and zero-friction branches and names path ownership, staleness, and
approval flow individually. AC-030 covers the two approved characteristic
overrides with exact field-level oracle (machine names `credential_bearing` and
`release_write`, exact scope, value, and record type); AC-031 expands the
unknown-name, out-of-scope, and both override-specific no-op rejection branches
as separately exercised negative fixtures TEST-031a–d; TEST-031e–i each reject
one missing/extra entry field and TEST-031j–k reject each invalid placement.
TEST-017a–c separately cover pre-boundary, exact-boundary, and post-boundary
time. TEST-018c/c2 separately cover zero identities at request and application;
TEST-018d–g cover unsigned authorization, unbound HMAC sidecar, self-approval,
and duplicate identity; TEST-018h/i reject invalid/untrusted Ed25519 rollback
signatures. The HMAC sidecar authenticates approval input, while Ed25519 signs
the persisted rollback proof. AC-032 covers the
reverse-coverage and ownership-digest checks; AC-033 covers premature required-enforcement
activation; AC-034 covers a registry-cardinality change during rollback
cooldown; AC-035 covers the independent Phase-2 human-approval boundary.

## Minimal Pack contract cases

These cases implement the 2026-09-26 human decision in REQ-005. They are
planned oracles, not execution evidence. TEST-008 remains their parent mapping.
Where a row names independent mutations, execute each from a fresh valid input.

| AC | REQ | TEST | Assertion / oracle | Status |
|---|---|---|---|---|
| AC-008 | REQ-005 | TEST-008a | A full-track plugin-code change selects both capabilities, exactly both required facets and both review-check IDs from REQ-005, and no Pack gate IDs. | Planned |
| AC-008 | REQ-005 | TEST-008b | An MCP-only affected component selects only developer-tooling and its one facet/check, with no Pack gate IDs. | Planned |
| AC-008 | REQ-005 | TEST-008c | An installer-only affected component selects only developer-tooling and its one facet/check, with no Pack gate IDs. | Planned |
| AC-008 | REQ-005 | TEST-008d | A component with none of the three trigger artifact kinds selects neither capability. Independently test uppercase variants of plugin_package, mcp_server, and installer_script; none matches. | Planned |
| AC-008 | REQ-005 | TEST-008e | A plugin plus MCP plus installer change produces the same deduplicated two-capability/facet/check union as TEST-008a. | Planned |
| AC-008 | REQ-005 | TEST-008f | Validate each exact Registry record against the existing schema and REQ-005 oracle. For each record independently mutate its ID, trigger, required facets, conditional facets, review checks, gate IDs, minimum enforcement presence, delivery kind, and Lite eligibility; the contract check rejects each mismatch, even when schema-valid. | Planned |
| AC-008 | REQ-005 | TEST-008g | The developer-tooling review requires changed distribution/install surface, supported hosts, and compatibility evidence; independently omit each item and obtain a finding. An unaffected surface needs an explicit reason. | Planned |
| AC-008 | REQ-005 | TEST-008h | The cli-library review covers affected command/skill/script inputs, outputs, failure behavior, and compatibility evidence; independently omit each dimension and obtain a finding. An unaffected interface needs an explicit reason. | Planned |
| AC-008 | REQ-005 | TEST-008i | With the same two records and omitted minimum_enforcement, Phase-1 resolution stays advisory and Phase-2 stays required; neither record forces escalation or downgrade. | Planned |
| AC-008 | REQ-005 | TEST-008j | Pack delivery uses human-copy staging and does not publish or apply protected files automatically; compare protected destinations before/after staging. | Planned |
| AC-008 | REQ-005 | TEST-008k | A docs-only fixture whose Context and existing Lite rules already permit Lite gains no veto from these two eligible records; all other Lite checks still run. This is not the actual full A9 Context or its representative evidence. | Planned |
| AC-008 | REQ-005 | TEST-008l | A docs-only change with the actual full A9 Context stays full; an incompatible explicit Lite request is rejected under the existing track contract without changing Context. | Planned |
| AC-008 | REQ-005 | TEST-008m | Independently test code-only and mixed code/docs A9 changes; both remain full. | Planned |
| AC-008 | REQ-005 | TEST-008n | The execution-gate inventory is unchanged by these two records. An existing blocking-gate failure still blocks; only new Pack review findings are advisory in Phase 1 (TEST-011). | Planned |

## Promotion, dependency, and human-approval boundary cases

The existing parent TEST-013 and TEST-020 identifiers remain the mappings used
by sibling layer/traceability artifacts; the individually named suffix cases
below make their assertions observable without changing those parent mappings.
All cases remain Planned. Each negative fixture starts from a valid Phase-2
candidate or dependency preflight and changes only the stated condition; other
OQ-003 conditions, required A1–A8 surfaces, and evidence bindings remain valid.
The preflight cases identify the failing epic and surface in saved diagnostics,
not merely a generic dependency failure. Surface examples below follow the
Foundation A1–A8 deliverables (`docs/ai-dlc-foundation-decision-v2.md:522-549`);
the preflight also checks every other required surface named by those contracts
at the current HEAD, rather than treating a representative fixture as an
exhaustive artifact inventory.

| AC | REQ | TEST | Single-fault assertion / oracle | Status |
|---|---|---|---|---|
| AC-013 | REQ-007 | TEST-013a | Leave one observed advisory guard/gate false positive without WFI triage; reject promotion despite all other OQ-003 conditions passing. | Planned |
| AC-013 | REQ-007 | TEST-013b | Retain one unresolved Critical or Major finding; reject promotion despite all other conditions passing. | Planned |
| AC-013 | REQ-007 | TEST-013c1 | Make only the Windows CI lane non-green; reject promotion. | Planned |
| AC-013 | REQ-007 | TEST-013c2 | Make only the macOS CI lane non-green; reject promotion. | Planned |
| AC-013 | REQ-007 | TEST-013c3 | Make only the Linux CI lane non-green; reject promotion. | Planned |
| AC-013 | REQ-007 | TEST-013d1 | Omit the end-to-end OQ-004 rollback rehearsal; reject promotion. | Planned |
| AC-013 | REQ-007 | TEST-013d2 | Supply an unsuccessful end-to-end OQ-004 rollback rehearsal; reject promotion. | Planned |
| AC-013 | REQ-007 | TEST-013e | Make the promotion record's bound Context revision, Registry digest, ownership digest, or resolver version stale against the current evidence; reject promotion. | Planned |
| AC-020 | REQ-011 | TEST-020a | A1 Project Context schema/approval validator absent; preflight identifies and blocks A1. | Planned |
| AC-020 | REQ-011 | TEST-020b | A1 approval validator accepts an invalid approval binding; preflight identifies the incompatible A1 contract and blocks. | Planned |
| AC-020 | REQ-011 | TEST-020c | A2 Capability Registry schema/validator absent; preflight identifies and blocks A2. | Planned |
| AC-020 | REQ-011 | TEST-020d | A2 Registry instance fails its schema/validator; preflight identifies the incompatible A2 contract and blocks. | Planned |
| AC-020 | REQ-011 | TEST-020e | A3 path-ownership resolver absent; preflight identifies and blocks A3. | Planned |
| AC-020 | REQ-011 | TEST-020f | A3 resolver result lacks a usable ownership digest; preflight identifies the incompatible A3 contract and blocks. | Planned |
| AC-020 | REQ-011 | TEST-020g | A4 Facet Manifest schema/validator absent; preflight identifies and blocks A4. | Planned |
| AC-020 | REQ-011 | TEST-020h | A4 Manifest contract cannot bind Context/Registry/ownership digests; preflight identifies the incompatible A4 contract and blocks. | Planned |
| AC-020 | REQ-011 | TEST-020i | A5 Capability Resolver absent; preflight identifies and blocks A5. | Planned |
| AC-020 | REQ-011 | TEST-020j | A5 Resolver output cannot satisfy the merged Manifest/Resolver Evidence contract; preflight identifies the incompatible A5 contract and blocks. | Planned |
| AC-020 | REQ-011 | TEST-020k | A6 Capability-aware Lite integration absent; preflight identifies and blocks A6. | Planned |
| AC-020 | REQ-011 | TEST-020l | A6 Lite path bypasses a required capability risk-upgrade; preflight identifies the incompatible A6 contract and blocks. | Planned |
| AC-020 | REQ-011 | TEST-020m | A7 compatibility regression surface absent; preflight identifies and blocks A7. | Planned |
| AC-020 | REQ-011 | TEST-020n | A7 deterministic/structural/orchestration compatibility check fails; preflight identifies the incompatible A7 surface and blocks. | Planned |
| AC-020 | REQ-011 | TEST-020o | A8 three-environment handoff/install/guard regression evidence absent; preflight identifies and blocks A8. | Planned |
| AC-020 | REQ-011 | TEST-020p | A8 evidence omits a required host or contains a failed required regression; preflight identifies the incompatible A8 evidence and blocks. | Planned |
| AC-035 | REQ-007, REQ-008 | TEST-035a | With all OQ-003 evidence and Pack/Resolver evidence valid, omit Phase-2 human approval; protected publication rejects without changing the live Context. | Planned |
| AC-035 | REQ-007, REQ-008 | TEST-035b | Present a human Phase-2 approval protected and bound to a different Context transition; reject the wrong-transition binding without changing the live Context. | Planned |
| AC-035 | REQ-007, REQ-008 | TEST-035c | Present an agent-authored approval in place of human authorization; reject without changing the live Context. | Planned |

## A9 classification and override-oracle additions (draft, 2026-09-26)

These are planned, separately named negative fixtures for each schema
classification field; they do not add runtime implementation or alter the nine
approved IDs/ownership. Each starts with the valid TEST-003 fixture and changes
only the named field/value. Optional omissions are rejected if silently
replaced with an invented value; no test asserts that data is PII-free or
credential-free.

| AC | REQ | TEST | Assertion / Oracle | Status |
|---|---|---|---|---|
| AC-004 | REQ-002 | TEST-003c | Change one component's `artifact_kinds` from its table value; classification oracle rejects. | Planned |
| AC-004 | REQ-002 | TEST-003d | Change one component's `runtime_classes` from its table value; classification oracle rejects. | Planned |
| AC-004 | REQ-002 | TEST-003e | Add an invented `platform_targets` entry, including unsupported architecture; omitted-field oracle rejects. | Planned |
| AC-004 | REQ-002 | TEST-003f | Add or alter a `characteristics` boolean not specified by the inventory; omission oracle rejects without inferring a `pii` value. | Planned |
| AC-004 | REQ-002 | TEST-003g | Change one component's `distribution_channels`; classification oracle rejects. | Planned |
| AC-004 | REQ-002 | TEST-003h | Change one component's `data_classification`; classification oracle rejects. | Planned |
| AC-004 | REQ-002 | TEST-003i | Add an unapproved `provider_binding_ids` value; omission oracle rejects. | Planned |
| AC-031 | REQ-004 | TEST-031a | Replace only `credential_bearing` in an otherwise valid `mcp` / `mcp/ci-mcp` override with unknown name `credential_required`; reject the override and do not publish the candidate Context. | Planned |
| AC-031 | REQ-004 | TEST-031b | Replace only the scope of that valid `mcp` override with `.github/**`, outside its owning component; reject the override and do not publish the candidate Context. | Planned |
| AC-031 | REQ-004 | TEST-031c | Set only the `mcp` / `mcp/ci-mcp` `credential_bearing` override to `false`; absent override-only baseline is false, so reject as no-op. | Planned |
| AC-031 | REQ-004 | TEST-031d | Set only the `.github/**` `release_write` override's value to `false`; its absent override-only baseline is false, so reject as no-op. | Planned |
| AC-031 | REQ-004 | TEST-031e | Remove only `scope` from an otherwise valid override entry; reject because the entry must have exactly four fields. | Planned |
| AC-031 | REQ-004 | TEST-031f | Remove only `characteristic`; reject because the entry must have exactly four fields. | Planned |
| AC-031 | REQ-004 | TEST-031g | Remove only `value`; reject because the entry must have exactly four fields. | Planned |
| AC-031 | REQ-004 | TEST-031h | Remove only `rationale`; reject because the entry must have exactly four fields. | Planned |
| AC-031 | REQ-004 | TEST-031i | Add one unrecognized fifth entry field; reject because the entry must have exactly four fields. | Planned |
| AC-031 | REQ-004 | TEST-031j | Put an otherwise valid override on a workflow record rather than the owning `.github/**` cross-cutting rule; reject placement. | Planned |
| AC-031 | REQ-004 | TEST-031k | Put an otherwise valid override at Context top level rather than on an allowed component or cross-cutting record; reject placement. | Planned |
| AC-018 | REQ-009 | TEST-018c | At request time, an empty trusted approver registry rejects rollback request; no unanchored identity or signed record may be created. | Planned |
| AC-018 | REQ-009 | TEST-018c2 | After a valid request, remove the final trusted approver before application; current-registry revalidation rejects application and does not use the request-time identity set. | Planned |
| AC-018 | REQ-009 | TEST-018d | Remove the HMAC-authenticated approval sidecar from an otherwise valid solo rollback; reject the unsigned authorization. | Planned |
| AC-018 | REQ-009 | TEST-018e | Bind an otherwise correctly HMAC-signed approval sidecar to different canonical content; reject the unbound sidecar. | Planned |
| AC-018 | REQ-009 | TEST-018f | Use the requester as the sole approving identity; reject self-approval. | Planned |
| AC-018 | REQ-009 | TEST-018g | Populate both approval slots with the same registered identity; reject duplicated-identity authorization. | Planned |
| AC-018 | REQ-009 | TEST-018h | Alter the signed rollback record after Ed25519 signing; reject the invalid live-host-proof signature. | Planned |
| AC-018 | REQ-009 | TEST-018i | Remove the Ed25519 signer from the trusted-signer registry before application; reject the now-untrusted signature. | Planned |
| AC-017 | REQ-009 | TEST-017a | Set HMAC-authorized `effective_at` to first approval + 24h; applying a correctly Ed25519-signed solo rollback one second before that boundary rejects. | Planned |
| AC-017 | REQ-009 | TEST-017b | Apply the same valid solo rollback exactly at its HMAC-authorized `effective_at` boundary (first approval + 24h); accept the time condition. | Planned |
| AC-017 | REQ-009 | TEST-017c | Apply the same valid solo rollback one second after its HMAC-authorized `effective_at` boundary; accept the time condition. | Planned |

## OQ-001 amendment coverage (2026-09-08)

These are planned oracles, not executed tests. TEST-003 compares the exact set
`sdd-bootstrap`, `sdd-review-loop`, `sdd-implementation`, `sdd-quality-loop`,
`sdd-ship`, `sdd-lite`, `sdd-domain`, `mcp`, `installer`; an extra or missing ID
fails. It checks `plugins/sdd-domain/**` maps only to `sdd-domain`, not another
component or cross-cutting. TEST-004 has a separate omitted-ID case for each
of those nine IDs and a separate unjustified-empty-classification case.
TEST-006 includes the actual tracked domain-plugin files in its coverage input;
a fixture using only the nonexistent historical spelling `plugins/domain/**`
cannot satisfy that coverage. The sealed round-1 findings remain historical
review evidence; this dated draft addition supplies classification and
override-baseline oracles for a future round and does not rewrite or
retroactively change those findings.

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
stale resolver evidence → TEST-013e; changed approver registry → TEST-018a/b;
zero friction → TEST-029. All remain Planned pending implementation and execution.

## Non-conflicting prior remediation (2026-09-08; AC-030/031 reconciled 2026-09-17)

These cases restore the reverse-coverage, ownership-digest and premature
enforcement checks from candidate 4349ae40 without restoring its superseded
eight-component ruling. The valid fixture has all nine approved components and
current evidence; each negative fixture changes only the named condition.

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
AC-030/031 are now reconciled: their exact oracles (machine names
`credential_bearing` and `release_write`, four required entry fields, exact
positive and negative fixtures TEST-031a–k) are defined in REQ-004 and
reflected in the main table above and coverage note.

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
