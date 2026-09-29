# Design: SDD context continuity

Impl-Review-Status: Passed
Feature Type: internal local plugin
Status: Draft — design only; no implementation approval

## Technical Summary

An internal `sdd-context` plugin uses short-lived Node hook processes, a
worktree-local redacted JSONL journal, and disposable projections. It does not
replace native compact or authoritative SDD files. Source capture precedes
extraction; failed capture warns and permits input. This draft resolves design
choices, not native runtime evidence (OQ-005–OQ-010).

## Architecture

Host adapter → validated observation → owner/privacy/expiry checks → redaction
→ serialized append and sync → derived decisions. Compact reconciliation follows
the same capture path. Resume → expiry/integrity checks → read-only authoritative
task/spec parsing → fresh materialization reconciliation → bounded recovery.
An OS daily job invokes the same owned-store cleanup, without a resident daemon.

## Components

| Component | Responsibility | Technology | New/Existing |
|---|---|---|---|
| Claude / Codex adapters | Separate actual event schemas and response rules | Node | New |
| Continuity core | Validation, redaction, journal, projection, cleanup | Node built-ins | New |
| Read-only SDD reader | Canonical task interpretation without stdio startup | Existing TypeScript parser/build | Reused |
| Installer integration | Internal entrypoints and per-user daily job | Existing plugin delivery + OS scheduler | Extended after approval |

Existing reuse anchors: `parseTaskState` at
`mcp/sdd-forge-mcp/src/parsers/tasks.ts:67`, root resolution at
`mcp/sdd-forge-mcp/src/root.ts:39` (INV-007). The package declares
Node `>=22.19.0` at `mcp/sdd-forge-mcp/package.json:8` and esbuild's current
stdio entry at `:11` (INV-017). Add a transport-free build entry later; do not
import startup. No new dependency, database, network service or user command.
Reverify these shared paths/build declarations immediately before review and
implementation. `guardedRead` ambiguity is not absence proof
(`mcp/sdd-forge-mcp/src/path-guard.ts:186`, `:218`, `:250`; INV-017).

## Layer Specifications

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | Native feedback and degraded recovery | [UX](ux-spec.md#scope-and-user-journeys) | Adapter designer | Draft |
| Frontend | Host normalization and bounded output, not a browser UI | [Frontend](frontend-spec.md#technology-stack) | Runtime designer | Draft |
| Infrastructure | Local durability, lock and daily deletion | [Infrastructure](infra-spec.md#deployment-topology) | Storage implementer | Draft |
| Security | Ownership, redaction and private evidence | [Security](security-spec.md#trust-boundaries) | Security implementer | Draft |

## Design System Compliance

N/A — ds_profile: none

## Cross-Layer Dependencies

| From | To | Contract / Decision | REQ | AC | Verification |
|---|---|---|---|---|---|
| requirements.md | security-spec.md | Redact before all writes/output; owner checks | REQ-005, REQ-009 | AC-007, AC-013, AC-014, AC-016 | TEST-019–023, TEST-041–046, TEST-052–056 |
| requirements.md | infra-spec.md | Durable source before extraction, daily expiry | REQ-001, REQ-006, REQ-009 | AC-008, AC-013, AC-015, AC-017 | TEST-024–026, TEST-041–044i, TEST-047–050, TEST-057–059, TEST-066 |
| ux-spec.md | frontend-spec.md | Warning/continue versus manual UNSAFE | REQ-003, REQ-007, REQ-008, REQ-012 | AC-004, AC-009, AC-010, AC-011, AC-012, AC-015 | TEST-004–008, TEST-027–040, TEST-051, TEST-065 |
| frontend-spec.md | infra-spec.md | Authority-first fresh bounded projection | REQ-002, REQ-004, REQ-010, REQ-011 | AC-001, AC-002, AC-003, AC-005, AC-006, AC-018 | TEST-001–003, TEST-009–018, TEST-060–064 |

## ADR Change Log

Proposed decision: `docs/adr/0033-worktree-local-context-continuity.md` records
local journal/OS scheduler/read-only authority boundaries and alternatives.
Bind its bytes in design review; Proposed is not implementation approval.
The identifier was checked against local and origin/main ADR lists on 2026-09-27;
reverify uniqueness immediately before review and integration because this is a
shared namespace.

## Data Plan

### Data Entities

All JSON types below are closed schema-v1 objects: reject unknown keys, duplicate
keys, invalid Unicode, wrong types and unknown versions before persistence.
Required fields have no question mark; `?` denotes optional. IDs are opaque
nonempty bounded strings, sequences are nonnegative safe integers, dates are
UTC RFC3339, hashes are lowercase 64-hex SHA-256. Bounds are enforced before
allocation/write, under the shared deadline. JSONL records use canonical JSON
with the hash field omitted when calculating their integrity digest.

| Entity | Required / optional fields | Ownership and expiry |
|---|---|---|
| OwnerV1 | schemaVersion=1, sddRoot, worktreeRoot, gitDirectory, featureId, host=claude/codex, sessionId | Canonical private paths; revalidated, never published. |
| JournalHeaderV1 | schemaVersion=1, owner, segmentId, firstSequence, predecessorHash | Explicit chain start after expiry rewrite; no content or approval. |
| JournalRecordV1 | schemaVersion=1, owner, sequence, kind, receivedAtUtc, text, ruleVersion=1, omission, coverage, previousHash, hash; stableEventId? | Only redacted text; original receipt determines expiry. |
| DecisionV1 | schemaVersion=1, owner, id, status=accepted/rejected/superseded/constraint/open, text, doNotReopen, sourceSequences, originalReceipts; materialization?={path,sha256} | Derived label and retained source references; cannot extend source age. |
| ProjectionV1 | schemaVersion=1, owner, head, authorityHashes, taskLifecycle, featurePresent, journalCursor, decisions | Disposable decisions/snapshot; revalidate all freshness fields. |
| CursorV1 | schemaVersion=1, owner, segmentId, sequence, hash; predecessorSessionId? | No replay authority; content-bearing extensions forbidden. |
| OwnerRegistryV1 | schemaVersion=1, entries, maxObservedUtc | Private per-user locator registry; content-free. |
| RegistryEntryV1 | owner, storeRoot, registrationId, schedulerState=enabled/disabled/failed, checkedAtUtc | Exact owned locator only, no wildcard/home scan. |
| LockV1 | schemaVersion=1, owner, nonce, pid, processStartIdentity | No age-based stealing; same-owner native death proof required. |

`sourceSequences` and `originalReceipts` are nonempty, corresponding arrays.
Registry entries are unique by canonical owner tuple and registration ID;
conflicting duplicate owners are rejected. Registration changes require the
existing installer, never a host-supplied journal path. Staging/quarantine uses
the same entity schemas and receipt age, never an alternate unredacted format.

### Existing Data Affected

Current tasks/specs and MCP parser inputs are read-only. No task status, approval,
Git index, native transcript, existing HANDOFF or foreign log is changed.
Only owned installer registrations and new private registry/store files are
writable. Existing MCP public interfaces and transport entrypoints stay intact.

### Migration Strategy

No existing data is migrated: this feature creates only schema-v1 stores and a
registry. The retired experiment is not imported. Unknown/older/newer schema is
unavailable and preserved, not guessed, overwritten or silently upgraded.
Installer rollback disables owned capture while retaining expiry-filtered cleanup
for residual content until deletion; it does not migrate content into host logs.

Storage root: `.sdd/context/` under the canonical worktree, never shared Git
metadata. Fixed schema-v1 files under opaque feature/session owner IDs: journal
segments, `decisions.json`, `snapshot.json`, `cursor.json`, and bounded staging or
quarantine files. These are all private and content-bearing; all inherit original
receipt expiry. No unredacted backup. No migration from the retired experiment;
unknown schema is unavailable, never guessed or overwritten.

Each journal envelope contains `schemaVersion:1`, local sequence, opaque owner
tuple, host, session, optional proven stable event ID, kind, original
`receivedAtUtc`, payload redacted text, redaction rule version/omission flag, and
previous-record/hash integrity link. Hashes are integrity evidence, not signatures
or approval. Local receipt is authoritative for age, not host event timestamps.
Unproven retry identity retains separate deliveries; same stable ID/different
content errors. Decisions carry accepted/rejected/superseded/constraint/open,
do-not-reopen, source sequences and optional verified materialization ref/hash.
Extractor omissions never remove source; inferred decisions are labeled derived.

Owner binds canonical SDD root, worktree root and worktree-specific Git directory,
feature, host and session. Store private paths only locally, never in public
reports. HEAD is a projection invalidator, not ownership. Cross-session recovery
requires an explicitly validated same-worktree/feature predecessor relationship;
foreign cursors cannot authorize replay. No inferred cross-feature import.

Projection freshness binds current HEAD, authoritative source hashes/task lifecycle,
feature presence and journal cursor. Missing, unreadable or conflicting authority
produces unavailable/limited recovery, not authority invented from HANDOFF. A
materialization pointer suppresses full source only while target/hash matches.

## API / Contract Plan

Internal versioned normalized events and outcomes only, no public network API.
Event kinds: prompt, final-assistant, observable-transcript, compact-manual,
compact-auto, resume. Outcome discriminants: captured, uncaptured-warning,
safe, unsafe, unavailable, recovered, no-op, cleaned, cleanup-warning. Coverage is explicit
complete/partial/unavailable for the observable input only. `captured` requires
completed sync; `safe` additionally requires reconcile/integrity/publication.
Adapter host serialization must satisfy [budgets](frontend-spec.md#performance-budget).

Internal entrypoints are `capture(observation)`, `reconcile(observation)`,
`recover(request)` and `cleanup(request)`, invoked directly by bundled adapters
or the owned OS oneshot. No CLI command, public MCP tool or network API is added.
Contracts below are design authority for later schema artifacts, not implemented
APIs. All objects are closed, versioned and validated using the Data Plan rules.

| Request | Required fields | Optional fields | Allowed outcome |
|---|---|---|---|
| ObservationV1 (capture) | schemaVersion=1, owner, kind=prompt/final-assistant, text, coverage=complete/partial/unavailable | stableEventId | captured / uncaptured-warning / no-op |
| ReconcileV1 (reconcile) | schemaVersion=1, owner, kind=observable-transcript/compact-manual/compact-auto, coverage | records: ObservationV1[] (required when coverage is complete/partial); stableEventId | safe / unsafe / unavailable / no-op |
| ResumeV1 (recover) | schemaVersion=1, owner, kind=resume | predecessorSessionId (must independently validate same worktree/feature) | recovered / unavailable / no-op |
| CleanupV1 (cleanup) | schemaVersion=1, registrationId | none | cleaned / cleanup-warning |

The caller cannot supply authoritative receipt timestamps, sequence, expiry,
paths for cleanup, budgets or task lifecycle; the core derives these from the
validated registry/current files and local clocks. A normalized internal request
is not a claim that either native host exposes an equivalent event. Unknown
native schema remains unsupported, never coerced into successful capture.

`OutcomeV1` requires schemaVersion=1, kind, reasonCode and omission:boolean.
`captured` additionally requires sequence and synced:true; `safe` requires
synced:true, reconciled:true, integrity:true and published:true. `recovered`
requires coverage, entries:array of {sourceSequences,text,omission} and
pointers:array of {opaqueId,reasonCode}; serialize the complete outcome within
8,192 UTF-8 bytes. `cleaned` requires expiredCount/removedCount safe integers
and completed:true; partial/failed deletion is cleanup-warning, never cleaned.
Failure/no-op outcomes have no content, raw exception, private path or digest.
An optional diagnostic is a bounded approved reason code, not free text.
Unsupported/manual failure maps to unsafe/unavailable; automatic failure always
warns and continues without a blocking host response. captured alone is never
safe. No-op requires a non-SDD or unsupported no-hook context. Native adapters
serialize only host-supported feedback; absent safe blocking capability is
explicitly unavailable (OQ-008), not invented.

## Test Strategy

Use the unchanged [acceptance plan](acceptance-tests.md) with synthetic fixtures.
Unit/fault suites prove ordering, schema/redaction, expiry, ownership, lock,
prefix recovery, freshness and final UTF-8 budgets. Existing MCP read-only and
snapshot regressions prove reuse compatibility (TEST-061/062). TEST-036/037 and
TEST-044a–i require actual registered native triggers per host/OS; fixtures,
configuration inspection and direct cleanup calls cannot count as those passes.
All tests remain Planned; no performance or durability result is asserted.

## Security Boundaries

See [security controls](security-spec.md#trust-boundaries). Conversation is private
even after redaction; journal content is untrusted evidence, not instructions,
task approval or permission to bypass guards. No network export/public manifest.

## Deployment / CI Plan

See [operations](infra-spec.md#deployment-topology). Extend existing internal
installation only after task approval and actual host checks. Scheduler permission
or trust refusal stops that action; do not weaken guards or try alternate bypasses.
No job is installed by this draft.

After task approval, register synthetic contract/privacy/fault tests in the
existing Ubuntu POSIX suite inventory (`tests/run-ci-unwired.sh`) and add the
portable Node/core tests to the existing `test` OS matrix in
`.github/workflows/test.yml`. Run native filesystem/locking/sync and installer
tests in that matrix's actual Windows/macOS/Ubuntu environments; retain existing
MCP tests and required-checks dependencies. Add no duplicate matrix/job or relaxed
check. These are planned workflow edits, not current registrations; reverify job
names and inventory immediately before editing.

Authenticated Claude/Codex lifecycle tests and per-user scheduler triggers run in
isolated owning-account host environments, not with credentials injected into
public CI. Persist sanitized results in the feature verification directory; keep
private runtime stores outside reports. Missing native capability leaves the
corresponding acceptance pending, even if all fixture CI passes. No new secret,
network service, environment variable or production deployment is required.
Use existing installed Node; tests create unique temporary owners/stores and
never register jobs against developer data. Rollout is explicit installation
after host checks, not an implicit feature flag or automatic trust grant.

## Constraint Compliance

| Constraint | Design response |
|---|---|
| No native compact replacement | Bounded hooks, automatic failure always nonblocking |
| No new workflow command/dependency/daemon | Internal bundled Node entries and OS oneshot |
| Own private local logs only | Exact registered owner/files, no home scan/host transcript deletion |
| Source is not authority | Read-only current specs/tasks win; no approval or Done writes |
| AC-001–003 source fidelity/extractor independence | Sync redacted source before derivation; omission disclosed; derivation never deletes source |
| AC-004/017 exposed transcripts and retries | Explicit coverage; only proven stable ID deduplicates; conflicting content rejects |
| AC-005/006 freshness and authority | Current HEAD/source hashes/lifecycle/cursor invalidate projection; verified materialization only |
| AC-007/008 owner and integrity | Canonical owner checks; isolate partial tail, reject interior corruption, retain valid prefix |
| AC-009/010/015 failure behavior | Manual failure never SAFE; proven barrier only; automatic/input/Stop failures warn and continue |
| AC-011/012 independent hosts/fallback | Actual Claude and Codex evidence required separately; no-hook file fallback, non-SDD no-op |
| AC-013 all-copy expiry | Inclusive original-receipt 30 days; exclude on every read/output; OS daily deletion normally within 24h and catch-up on return |
| AC-014 redaction/disclosure | Approved bounded grammar before every copy/output; no raw backup/digest; omission explicitly unrecoverable |
| AC-016 Git/path safety | Effective ignore/tracked/error/unsafe target checks refuse persistence; no index mutation or destructive cleanup |
| AC-018 bounded recovery/MCP compatibility | Whole-entry fitting, safe opaque pointers; existing readonly parser/Windows/CRLF behavior retained |
| OQ-011 scanner bounds | 512 spans, 4,096-byte values, declared secret families; malformed/oversized/scanner failure refuses all writes |
| OQ-012 input/time/output bounds | 1MiB observation, 8MiB transcript scan, monotonic 1,000ms core deadline; native 2s remains separately unproven; complete output <=8,192 UTF-8 bytes |
| OQ-012 clock limits | max(nowUtc, observed watermark); retries never renew age; rollback cannot revive known expiry; abnormal clocks disclosed |

## Assumptions

Intake records full track C1 compatibility fallback, absent domain, structure
preflight and real PreToolUse HOOK_ACTIVE in
`reports/verification/issue137-intake-20260926.md`; this is not lifecycle proof.
Host observations and candidate protocol constraints come from
`reports/verification/issue137-host-contract-audit-20260926.md`, not activation.
Shared hook registrations, guards, build and ignore state must be reverified
immediately before review/implementation (INV-001–INV-017).

## Open Questions

OQ-001–004 product/ownership decisions stay resolved. OQ-011 has an exact bounded
rule-version-1 grammar candidate in security-spec; synthetic path-complete
verification and independent review remain unresolved, not a tested resolution.
OQ-012 has explicit design budgets/clock policy in frontend/infra; host-limit
measurement is pending. OQ-005–010 native retry/schema/registration/path/durability/
scheduler evidence remain implementation-blocking for affected contracts, owned
by the adapter, storage, security and infrastructure implementers respectively.
The requirements/acceptance specification review passed; this does not establish
executed tests or approve implementation. The design supplies candidates only.

| Question | Owner | Blocks Implementation | Resolution Path |
|---|---|---|---|
| OQ-005 | Adapter implementer | yes — retry-support contract | Observe actual host retry IDs; prove stable same/different-content cases, otherwise preserve deliveries. |
| OQ-006 | Storage implementer | yes — durability/storage contract | Run native append/sync/replace/crash/lock tests on all three OS and declare unsupported guarantees. |
| OQ-007 | Adapter implementer | yes — transcript reconciliation | Capture actual exposed schema and partial-tail evidence; reject unsupported formats. |
| OQ-008 | Runtime integration implementer | yes — live adapter acceptance | Actual registered prompt/Stop/manual+auto compact/resume on both hosts, with unsupported barriers disclosed. |
| OQ-009 | Security implementer | yes — persistent-write safety | Negative and positive native owner/path/ignore/tracked/error cases before any writes. |
| OQ-010 | Infrastructure implementer | yes — scheduler mechanism; policy is resolved | Execute TEST-044a–i with real daily/catch-up/failure OS triggers; preserve approved 30-day/24h policy. |
| OQ-011 | Security implementer | yes — redaction implementation completion | Independent design review and synthetic path-complete TEST-045/046 over exact rule-v1 grammar. |
| OQ-012 | Runtime implementer | yes — timing/native completion | Independent budget review, TEST-034/060 measurements and actual host termination limits, without token-count claims. |

Blocking applies to the named contract/completion claim, not to unrelated approved
investigation or synthetic development. OQ-001–004 remain resolved; no re-interview
or inferred approval of planned tasks is introduced.

## Risks

OS sync/kill semantics, unsupported manual barrier, scheduler absence/clock change,
partial observable transcripts and false-negative redaction can reduce continuity.
Warnings disclose loss; expired or unsafe records remain non-injectable. Native
evidence, ADR/contracts and independent review remain prerequisites to tasks.
