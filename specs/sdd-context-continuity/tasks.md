# Tasks: SDD context continuity

Task-Review-Status: Passed
Feature: sdd-context-continuity
Source: Issue #137
Profile: full (C1 COMPATIBILITY_FALLBACK; project context absent)

## Review and execution boundary

Existing human approval and lifecycle fields remain unchanged. The current
specification and design lineage is spec attempt-2/round-3 and impl
attempt-3/round-1; earlier PASS records are historical, not proof for changed
inputs. Task attempt-2/round-1 findings are retained. This plan repairs their
missing TEST-067 mapping and splits delivery from acceptance verification;
it must receive fresh task-stage provenance review before execution resumes.
T-007 is a new Draft task, not an extension of T-006's human approval.
T-008 splits the Codex adapter from T-004 and remains Draft. T-007's
medium/acceptance-first classification applies only to its still-Draft
verification/registration scope; no approved task's risk or checks are lowered.

## Global constraints

- Reuse `parseTaskState` and existing root/path interpretation through a transport-free build entry; no duplicate task parser, MCP startup import, dependency, daemon, network service or user command.
- Source capture follows schema/owner/path validation and redaction, precedes extraction, and succeeds only after sync. Failed capture warns and continues; automatic compact never blocks; Stop never requests extra model work for storage retry.
- Original receipt + 30 days determines inclusive expiry; all copies share age. Daily standard OS jobs delete owned expired logs normally within 24 hours and catch up on return. No home scan, host-transcript deletion, index mutation, trust weakening or refusal bypass.
- Native Claude/Codex and Windows/macOS/Ubuntu evidence are separate lanes. Fixtures, direct cleanup calls and configuration inspection cannot satisfy native acceptance. Unsupported capability stays unavailable/pending.
- Reverify shared registrations, guard membership, ignore/build/CI inventory and ADR-0033 uniqueness immediately before consuming them. Protected-file changes require the existing human-apply path; a refusal stops that operation, not an alternate route.
- Post-review frozen files remain unchanged; OQ resolutions and executed results go in `specs/sdd-context-continuity/verification/` addenda, not acceptance-test status cells or layer bodies.
- Before implementation, commit a failing TDD regression and record its commit plus Red result; after implementation, record the named independent reviewer and run ID, distinct from the implementer. Each high/critical implementation report must first enumerate persisted evidence field, sibling contract/traceability counterpart, and a failing mismatch test (WFI-001), then capture Red→Green, independent review and provenance with `spec_revision` plus environment. This is a future requirement, not current evidence.
- Execute one approved task at a time. T-001 → T-002 → T-003 supplies T-004 and T-005; T-008 follows T-003 and T-004 to serialize shared adapter entries; T-006 requires T-004, T-005 and T-008; T-007 follows T-006. This is a dependency graph, not authorization for concurrent implementation. Shared installer/build/CI edits are serialized. Only quality-gate may set Done.

## T-001 Define closed contracts and pre-write privacy boundary

Approval: Approved
Status: In Progress
Risk: high
Risk Rationale: Secrets handling and owner/path access control protect private conversation before every write/output.
Required Workflow: tdd
Requirements: REQ-001, REQ-005, REQ-009, REQ-012; AC-007, AC-014, AC-016 (privacy/owner validation implementation)
Depends On: none
Blockers: None
Planned Files: `contracts/sdd-context/` (new internal schema-v1 contracts); `plugins/sdd-context/` privacy/validation modules; synthetic continuity tests.
Scope: Implement the design's exact closed entities/requests/outcomes, canonical owner and safe opened-path/ignore/tracked checks, restrictive new-store permissions, bounded rule-v1 redaction and allowlisted diagnostics. Reuse known principles, not environment harvesting or MCP logging. Reject unknown/duplicate keys, Unicode/schema errors and exhausted bounds before all persistence.
Tests: TEST-019–023, TEST-045a–i, TEST-046a–c, TEST-052–056; TEST-045/046 parent acceptance rows.
Completion Preconditions: OQ-009 native path/ACL evidence and OQ-011 synthetic path-complete redaction verification block corresponding completion claims; product policy is already resolved.
Rollback: Verify infra-spec.md#rollback: disable new capture on validation/privacy regression, retain owner/expiry protections and residual cleanup; never export unredacted data.
Done When:
- Record the committed failing regression and Red result before implementation, plus the named independent reviewer and run ID, distinct from the implementer, after implementation.
- Contract/schema counterparts and WFI-001 mismatch preflight are recorded before code; all named privacy tests demonstrate Red→Green across every copy/output path.
- Native positive/negative owner/path/ignore/error cases are recorded per supported OS without real secrets or private absolute paths in public evidence.
- Lint/typecheck/build, unit/acceptance/regression, placeholder/task-state/traceability/component coverage and independent review verdict are recorded with provenance `spec_revision` and environment.

## T-002 Implement serialized durable source journal

Approval: Approved
Status: Planned
Risk: high
Risk Rationale: Private data mutation, integrity and durability failures can silently lose or expose captured source.
Required Workflow: tdd
Requirements: REQ-001, REQ-002, REQ-005, REQ-006, REQ-007, REQ-009; AC-001, AC-002, AC-003, AC-008, AC-015, AC-017 (journal implementation; AC-015 store failures only)
Depends On: T-001
Blockers: T-001
Planned Files: `plugins/sdd-context/` store/lock/capture modules; synthetic/native storage tests; verification addenda.
Scope: Owned journal header/hash chain, append+sync before extraction, disposable decisions, shared lock/death proof, stable-ID-only idempotence, partial-tail isolation/interior-corruption rejection, interrupted publication recovery and content-free warning. Every staging/quarantine copy is redacted and age-bound. No durability inferred from visible writes.
Tests: TEST-001–003, TEST-024–026, TEST-047–050, TEST-057–059, TEST-063–064, TEST-066.
Completion Preconditions: OQ-006 native append/sync/replace/crash/lock proof; OQ-005 actual retry IDs constrain dedup support (without proof preserve separate deliveries).
Rollback: Verify infra-spec.md#rollback: disable capture and preserve valid owned journal bytes; do not restore corrupt/unredacted or expired copies.
Done When:
- Record the committed failing regression and Red result before implementation, plus the named independent reviewer and run ID, distinct from the implementer, after implementation.
- WFI-001 preflight and Red→Green prove sync/extraction ordering, receipt preservation, error discriminants and concurrency; every native OS durability limit is explicit.
- Unproven stable identity never deduplicates by text/turn ID; source references survive extractor failure and supersession.
- All high-tier checks, independent review verdict and provenance `spec_revision`/environment are recorded in non-frozen addenda.

## T-003 Reuse authoritative task reader and bounded fresh recovery

Approval: Approved
Status: Planned
Risk: high
Risk Rationale: Recovery of untrusted private data must not invent approval, overwrite authority or leak stale/expired content.
Required Workflow: tdd
Requirements: REQ-002, REQ-004, REQ-005, REQ-009, REQ-010, REQ-011; AC-005, AC-006, AC-018, AC-013 (recovery implementation; AC-013 expiry-filtered reads only)
Depends On: T-002
Blockers: T-002
Planned Files: existing MCP transport-free build entry/build declaration; `plugins/sdd-context/` authority/projection/recovery modules; existing MCP regression tests and new recovery fixtures.
Scope: Reuse `parseTaskState`, root/path validation without stdio startup or a parallel parser. Preserve unsafe/unreadable versus absent authority; current HEAD/hashes/lifecycle/feature/cursor invalidate projections; verify materialization targets. Filter expiry on every read/output and fit whole entries in the complete 8,192 UTF-8 byte response with opaque pointers/omission/coverage.
Tests: TEST-009–018, TEST-041–043 (read/recovery branches), TEST-060–064, TEST-062 Windows/CRLF compatibility.
Completion Preconditions: OQ-012 final response measurements; expired/missing/unsafe authority cannot be treated as complete recovery.
Rollback: Verify infra-spec.md#rollback: disable recovery injection and retain authoritative task files, expiry filtering and residual cleanup.
Done When:
- Record the committed failing regression and Red result before implementation, plus the named independent reviewer and run ID, distinct from the implementer, after implementation.
- WFI-001 mismatch preflight and Red→Green cover freshness fields, source references, no approval writes, final escaped-byte size and minimal unavailable fallback.
- Existing MCP static read-only/snapshot regressions and native Windows/CRLF behavior remain compatible; no duplicate parser/dependency is introduced.
- All high-tier checks, independent review and provenance `spec_revision`/environment are recorded outside frozen artifacts.

## T-004 Implement Claude native lifecycle adapter

Approval: Approved
Status: Planned
Risk: high
Risk Rationale: Host lifecycle control and private transcript capture can block ordinary work or falsely claim safe compaction.
Required Workflow: tdd
Requirements: REQ-003, REQ-007, REQ-008, REQ-010, REQ-012; AC-004, AC-009, AC-010, AC-011, AC-012, AC-015 (Claude native adapter implementation; AC-015 Stop failure only)
Depends On: T-003
Blockers: T-003
Planned Files: `plugins/sdd-context/` Claude adapter and internal bundle entries; host fixtures; sanitized verification addenda. Shared bundle entries are serialized with T-008.
Scope: Normalize actual native Claude observations to closed core requests, capture final output, bounded complete-record transcript reconciliation and compact resume. Use 3,000 ms core deadline and separately prove candidate 5-second native termination with content-free host warning. Manual SAFE requires all stages and proven safe barrier; automatic/input/Stop failures warn/continue; unsupported/no-hook/Copilot stays file-based and non-SDD no-op.
Tests: TEST-004–008, TEST-027–035, TEST-038–040, TEST-051, TEST-065, TEST-067 (host-neutral, exercised by both adapter tasks); TEST-034/035 budgets and TEST-036 registered Claude lane.
Completion Preconditions: OQ-005/007/008 native identity, schema, registration, barrier and visibility; OQ-012 native termination/input limits. Observe before enabling affected contracts; do not coerce unsupported payloads.
Rollback: Verify infra-spec.md#rollback: disable only owned lifecycle registrations; preserve ordinary SDD, private data protection and residual expiry cleanup.
Done When:
- Record the committed failing regression and Red result before implementation, plus the named independent reviewer and run ID, distinct from the implementer, after implementation.
- WFI-001 preflight and Red→Green exercise all schema/coverage/failure branches and final host serializer bounds.
- Actual registered prompt/Stop/manual+automatic compact/resume is recorded for Claude, including visible warnings and auto-process-failure continuation; missing capability remains pending, never fixture PASS.
- All high-tier checks, independent review and provenance `spec_revision`/environment are recorded in sanitized non-frozen addenda.

## T-005 Implement owned expiry deletion and OS daily cleanup

Approval: Draft
Status: Planned
Risk: critical
Risk Rationale: Irreversible deletion of private expired content requires exact owned targets and preservation of nonexpired/foreign data.
Required Workflow: tdd
Requirements: REQ-005, REQ-006, REQ-009, REQ-012; AC-013 (physical deletion and native scheduling implementation)
Depends On: T-003
Blockers: T-003
Planned Files: `plugins/sdd-context/` cleanup/registry modules; existing installer integration and owned per-user scheduler templates; native cleanup tests; verification addenda.
Scope: Original-receipt inclusive 30-day exclusion and all-copy physical deletion, watermark/clock policy, validated mixed-segment rewrite/sync/replace under shared lock. Only registered exact owners/files; standard launchd/systemd/Task Scheduler daily+return activation, no daemon/elevation/password/wake. Disabled/failed scheduling denies new capture while retaining expiry-filtered residual cleanup. Interrupted removal warns, never cleaned.
Tests: TEST-041–044i, TEST-044a–i actual OS triggers; TEST-044f/h nonexpired/concurrency controls, TEST-044g unsafe targets, TEST-066.
Completion Preconditions: OQ-006 replacement durability; OQ-009 safe targets; OQ-010 actual scheduler catch-up/failure/account availability. Two distinct named human approvers must be selected before approval; no names/approval are invented here.
Rollback: Verify infra-spec.md#rollback: stop unsafe capture/new scheduling without reviving expired content; keep validated residual cleanup and prove foreign/nonexpired files untouched.
Done When:
- Record the committed failing regression and Red result before implementation, plus the named independent reviewer and run ID, distinct from the implementer, after implementation.
- WFI-001 preflight and Red→Green cover every content location, original age, clock rollback, foreign/nonexpired controls and partial cleanup outcomes.
- Each supported OS executes actual daily/catch-up/failure native triggers; direct core calls do not satisfy scheduler acceptance. No host transcript/foreign content is removed.
- All high-tier checks plus HMAC-signed evidence bundle, required cross-model verification, two-person approval with distinct named second approver, independent review and provenance `spec_revision`/environment are recorded; unavailable required controls leave completion blocked, not bypassed.

## T-006 Integrate existing installer and internal bundle

Approval: Approved
Status: Planned
Risk: high
Risk Rationale: Installing private-data capture and cleanup must preserve trust, release safety and ordinary SDD behavior.
Required Workflow: tdd
Requirements: REQ-001, REQ-005, REQ-006, REQ-009, REQ-012; AC-007, AC-008, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017 (delivery integration only; no duplicate primary implementation claim)
Depends On: T-004, T-005, T-008
Blockers: T-004, T-005, T-008
Planned Files: existing installer/build entrypoints; internal plugin metadata; focused install/rollback tests and verification addenda.
Scope: Bundle internal entrypoints with existing dependencies, safe exclusion/registry provisioning and rollback that retains residual expiry cleanup. Reuse existing installer and scheduler integration. No new workflow command, CI registration, user-documentation rollout or full-acceptance aggregation in this task.
Tests: TEST-038–040, TEST-047–051, TEST-052–059, TEST-066 (install/rollback/owner/failure integration); owning tasks retain primary evidence.
Completion Preconditions: T-004, T-005 and T-008 completion, including their affected native host, owner and scheduler evidence. Protected edits/trust/scheduler refusal needs human resolution, not bypass.
Rollback: Verify infra-spec.md#rollback: disable only new capture and owned registrations while retaining validated residual expiry cleanup; preserve nonexpired and foreign data.
Done When:
- Record the committed failing regression and Red result before implementation, plus the named independent reviewer and run ID, distinct from the implementer, after implementation.
- WFI-001 preflight and Red→Green cover install/rollback/no-hook/no-SDD behavior; all inventory/jobs/dependencies are reverified before editing.
- Existing install, upgrade, rollback, no-hook and non-SDD behavior is verified; delivery records accurately identify supported and unavailable hosts.
- All high-tier checks, independent review and provenance `spec_revision`/environment are recorded. Release remains blocked on T-007's full acceptance verification.

## T-007 Register tests and verify complete acceptance before release

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: Behavioral test registration and acceptance mapping, not implementation of private capture or deletion. Documentation alone is low risk; the behavioral registration makes this task medium. No existing check or release condition is relaxed.
Required Workflow: acceptance-first
Requirements: REQ-001–012; AC-001–018 (verification/inventory ownership only; no duplicate primary implementation claim)
Depends On: T-006
Blockers: T-006
Planned Files: existing test inventory and candidate protected CI edits via authorized human apply; user documentation; feature verification addenda.
Scope: Register synthetic/fault/privacy tests in existing Ubuntu inventory and portable/native tests in the existing three-OS matrix without duplicate jobs or check relaxation. Publish supported-host limitations and complete acceptance mapping. Isolated owning-account host lanes never inject credentials into public CI; no installer or core reimplementation.
Tests: All TEST-001–067 including every suffixed TEST-044/045/046 case; retain TEST-061/062 MCP compatibility; fixtures and native lanes reported separately.
Completion Preconditions: T-006 completion and all OQ-005–012 evidence. Protected edits require the authorized human-apply path; native accounts/OS availability are external prerequisites, never inferred from fixtures.
Rollback: Retain existing CI jobs/checks and revert only new registrations or inaccurate documentation; disable release/capture on acceptance regression while retaining safe residual expiry cleanup.
Done When:
- Write acceptance/regression checks before or with the registration change proving missing test registrations and missing/native-mismatched acceptance evidence are rejected; reverify all jobs and dependencies before editing.
- Complete REQ→AC→TEST→sanitized evidence mapping records executed and still-pending lanes accurately in verification addenda; no frozen acceptance/layer/status retrofits.
- All medium-tier checks, independent review and provenance `spec_revision`/environment are recorded. Full live/native acceptance is required before release; no fixture-only or historical-success substitution.

## T-008 Implement Codex native lifecycle adapter

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Host lifecycle control and private transcript capture can block ordinary work or falsely claim safe compaction.
Required Workflow: tdd
Requirements: REQ-003, REQ-007, REQ-008, REQ-010, REQ-012; AC-004, AC-009, AC-010, AC-011, AC-012, AC-015 (Codex native adapter implementation; AC-015 Stop failure only)
Depends On: T-003, T-004
Blockers: T-003, T-004
Planned Files: `plugins/sdd-context/` Codex adapter and internal bundle entries; host fixtures; sanitized verification addenda. Shared bundle entries are serialized with T-004.
Scope: Normalize actual native Codex observations to closed core requests, capture final output, bounded complete-record transcript reconciliation and compact resume. Use 3,000 ms core deadline and separately prove candidate 5-second native termination with content-free host warning. Manual SAFE requires all stages and proven safe barrier; automatic/input/Stop failures warn/continue; unsupported/no-hook/Copilot stays file-based and non-SDD no-op.
Tests: TEST-004–008, TEST-027–035, TEST-038–040, TEST-051, TEST-065, TEST-067 (host-neutral, exercised by both adapter tasks); TEST-034/035 budgets and TEST-037 registered Codex lane.
Completion Preconditions: OQ-005/007/008 native identity, schema, registration, barrier and visibility; OQ-012 native termination/input limits. Observe before enabling affected contracts; do not coerce unsupported payloads.
Rollback: Verify infra-spec.md#rollback: disable only owned lifecycle registrations; preserve ordinary SDD, private data protection and residual expiry cleanup.
Done When:
- Record the committed failing regression and Red result before implementation, plus the named independent reviewer and run ID, distinct from the implementer, after implementation.
- WFI-001 preflight and Red→Green exercise all schema/coverage/failure branches and final host serializer bounds.
- Actual registered prompt/Stop/manual+automatic compact/resume is recorded for Codex, including visible warnings and auto-process-failure continuation; missing capability remains pending, never fixture PASS.
- All high-tier checks, independent review and provenance `spec_revision`/environment are recorded in sanitized non-frozen addenda.

## Next step

Run fresh task-stage provenance review of this repaired plan. Preserve all prior
approvals and verdicts; T-005, T-007 and T-008 still require their stated human approval.
Then resume the first eligible approved task in dependency order; affected OQs
remain completion blockers, not implicit acceptance evidence.
