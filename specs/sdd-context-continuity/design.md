# Design: SDD context continuity

Impl-Review-Status: Pending
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
| ux-spec.md | frontend-spec.md | Warning/continue versus manual UNSAFE | REQ-003, REQ-007, REQ-008, REQ-012 | AC-004, AC-009–012, AC-015 | TEST-004–008, TEST-027–040, TEST-051, TEST-065 |
| frontend-spec.md | infra-spec.md | Authority-first fresh bounded projection | REQ-002, REQ-004, REQ-010, REQ-011 | AC-001–003, AC-005–006, AC-018 | TEST-001–003, TEST-009–018, TEST-060–064 |

## ADR Change Log

No ADR created in this bounded draft. Before architecture implementation approval,
record the local journal/OS scheduler/read-only boundary decision in `docs/adr/`;
reverify the shared next-free identifier at drafting. This is pending provenance,
not a waived architecture-change rule.

## Data Plan

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
safe, unsafe, unavailable, recovered, no-op. Coverage is explicit
complete/partial/unavailable for the observable input only. `captured` requires
completed sync; `safe` additionally requires reconcile/integrity/publication.
Adapter host serialization must satisfy [budgets](frontend-spec.md#performance-budget).
Contract/schema artifact drafting is pending before implementation approval;
this draft creates no API change or implementation.

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

## Constraint Compliance

| Constraint | Design response |
|---|---|
| No native compact replacement | Bounded hooks, automatic failure always nonblocking |
| No new workflow command/dependency/daemon | Internal bundled Node entries and OS oneshot |
| Own private local logs only | Exact registered owner/files, no home scan/host transcript deletion |
| Source is not authority | Read-only current specs/tasks win; no approval or Done writes |

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
Do not reinterpret existing requirements/acceptance Pending inputs as tested or
review-approved; the design supplies candidates only.

## Risks

OS sync/kill semantics, unsupported manual barrier, scheduler absence/clock change,
partial observable transcripts and false-negative redaction can reduce continuity.
Warnings disclose loss; expired or unsafe records remain non-injectable. Native
evidence, ADR/contracts and independent review remain prerequisites to tasks.
