# Requirements: SDD context continuity

Spec-Review-Status: Pending
Feature: sdd-context-continuity
Source: https://github.com/aharada54914/sdd-forge/issues/137
Status: Draft — Phase 1 incomplete; no implementation approval

## Overview

Keep observable, not-yet-materialized agreements available across native context
compaction without replacing authoritative SDD files. This draft incorporates
the human's 2026-09-26 decisions: local worktree-separated storage, automatic
30-day deletion, secret removal before persistence, and warning/continued work
after user-input persistence failure. These decisions qualify the issue's
complete/raw-capture wording; they do not authorize claiming lossless recovery.

## Target Users

Developers using Claude Code or Codex with SDD, including users resuming work
after compaction. Copilot and installations without supported hooks retain the
existing file-based workflow without a continuity guarantee.

## Problems

Conversation may contain an accepted option, exception or rejection not yet in
specification files. A derived summary is insufficient as its only evidence.
Existing task interpretation is reusable (`mcp/sdd-forge-mcp/src/parsers/tasks.ts:67`),
but the inspected hook registrations cover PreToolUse, not the required lifecycle
(`plugins/sdd-quality-loop/hooks/hooks.json:1`,
`plugins/sdd-quality-loop/hooks/claude-hooks.json:1`). These are
baseline observations from investigation INV-002 and INV-007, not live-host proof.

## Goals and Requirements

| ID | Requirement |
|---|---|
| REQ-001 | Attempt redacted source-event persistence before interpretation. Confirm capture only after the specified durability boundary succeeds. Extraction must never be the sole copy. |
| REQ-002 | Preserve accepted, rejected, superseded, constraint and open decisions with source sequence references, including composite exceptions and do-not-reopen intent. Inferences are derived, not new human approvals. |
| REQ-003 | Capture available final assistant output and reconcile observable transcript records before compaction, including automatic compaction before Stop. Report unavailable coverage rather than inventing missing events. |
| REQ-004 | Reconcile recovered decisions/projections with current authoritative specifications, task approval/status, reports and verification. Materialization requires a current artifact reference and matching content evidence. |
| REQ-005 | Isolate local storage by canonical repository/worktree identity, feature and host session. HEAD/source changes invalidate projections, not journal ownership. Never inject another owner's journal. |
| REQ-006 | Serialize journal updates, retain a valid prefix after a partial final record, detect interior corruption, and recover without silent loss or duplicate retry claims. |
| REQ-007 | On input persistence failure warn and continue without claiming capture. Manual compaction requires a separate flush/reconciliation safety result. Automatic compaction must never be prevented or indefinitely delayed by continuity handling. |
| REQ-008 | Verify Claude and Codex adapters independently through registered lifecycle entry points. No adapter may require another runtime's exclusive fields. Unsupported hosts/events remain explicitly unavailable. |
| REQ-009 | Store only redacted conversation data locally, outside Git and public evidence. Automatically expire and delete it after 30 days, including derived and recovery copies. Disclose redaction/expiry recovery loss. |
| REQ-010 | Inject a bounded, fresh recovery view prioritizing unresolved agreements, do-not-reopen decisions, workflow state, blockers and next action. Provide local evidence pointers for overflow; never inject the entire journal by default. |
| REQ-011 | Reuse the existing task-state interpretation through a transport-free read-only boundary. Keep MCP read-only and its existing public behavior compatible. HANDOFF, indexes and snapshots are derived, not authorities. |
| REQ-012 | Deliver an internal sdd-context plugin integrated with existing installation/dependencies, without a new user workflow command or changes to native compaction. No-SDD and unsupported-host cases preserve ordinary SDD usability. |

## Non-goals

Replacing native compaction, generic agent memory, recording hidden reasoning,
guaranteeing recovery of never-exposed events, defeating disk/OS corruption,
perfect secret detection, adding a database/network service, or using conversation
content as permission to change task approval. PostCompact diagnostics are optional
and cannot become an authority or substitute for pre-compaction capture.

## User Stories

- After accepting B but retaining A's authentication exception, resume with both
  the decision and exception available even if an extractor missed the exception.
- After explicitly rejecting an option, do not reopen it merely because a summary
  omitted the rejection.
- After a task becomes Done, do not follow an older HANDOFF that says In Progress.
- If persistence fails, see the warning and continue; do not learn later that an
  asserted successful capture never happened.

## Acceptance Criteria

AC-001–AC-012 preserve the source issue's numbering. AC-013–AC-018 make the human
decisions and cross-cutting boundaries testable. Planned test rows are in
`acceptance-tests.md`; none is an executed result.

| ID | Observable acceptance |
|---|---|
| AC-001 | After successful prompt capture and compact, B accepted/A rejected are recoverable with source references; a failed capture follows AC-015 instead of reporting success. |
| AC-002 | The redacted composite statement retains its authentication exception even when decision extraction omits that exception. Redacted spans are marked unrecoverable. |
| AC-003 | Extractor failure leaves captured source evidence available and does not mutate it into the failed extraction result. |
| AC-004 | Automatic compact before Stop reconciles exposed, complete transcript records not yet captured; absent, null, unknown-format and incomplete transcript inputs report their coverage limit. |
| AC-005 | A decision verified as materialized is represented by its authoritative reference, not redundant full-body injection; a stale/missing materialization target cannot suppress unresolved source evidence. |
| AC-006 | Current task state wins over stale HANDOFF and contradictory decision index; HEAD, source-hash, cursor, feature-presence and task-lifecycle changes invalidate the derived view. |
| AC-007 | Foreign repository, worktree, feature or session records cannot contaminate recovery; a canonical alias of the same owner is not mistaken for a foreign owner. |
| AC-008 | Partial final JSONL is isolated while preserving the valid prefix; interior corruption fails integrity checking. Interrupted recovery does not silently discard retained valid events. |
| AC-009 | Failed manual flush, reconciliation, integrity validation or projection publication is visible and never labeled SAFE. Block only through a proven safe host control; otherwise report the unavailable barrier explicitly. |
| AC-010 | Automatic compaction proceeds after write/read/timeout/hook-process failures without a blocking response or indefinite wait. Continuity loss is reported without conversation content. |
| AC-011 | Claude and Codex each demonstrate AC-001–AC-010 through their own actual supported event interfaces; fixture-only results cannot satisfy live-host acceptance. |
| AC-012 | No-hook/Copilot operation remains file-based; a non-SDD directory produces a no-op without creating a journal. |
| AC-013 | At 30 days from original local receipt, a record is ineligible for recovery/reinjection. An OS-standard daily job deletes expired content normally within 24 hours, including inactive worktrees; after power-off/sleep it runs on return. Deletion covers journal, extracted decisions, snapshots, repair/quarantine copies and content-bearing cursors. Retries/rebuilds do not renew age. Failed deletion is reported, never labeled successful. |
| AC-014 | Approved secret patterns are removed before any persistent copy or diagnostic output. Persisted placeholders and recovery feedback disclose omitted content; no unredacted backup is created. |
| AC-015 | User-input append, synchronization, permission and capacity failures warn and permit work without a captured-success marker. Stop failure cannot trigger repeated assistant work as a storage retry. |
| AC-016 | Missing/negated Git ignore rules, tracked journal files, Git-check errors and unsafe path targets prevent persistence without automatic index changes, destructive cleanup or weakening the ordinary workflow. |
| AC-017 | Host-stable identity permits idempotent retry; reused identity with different content is an error. Without proven event identity, equal text and equal turn ID remain separate deliveries, never an exactly-once claim. |
| AC-018 | Recovery input remains within its declared budget; overflow has safe local pointers. MCP read-only checks and task parsing compatibility remain unchanged, including Windows paths and CRLF. |

## Roles and Permissions

The local developer owns retention and disclosure policy. The hook can append
local evidence and derive recovery views within that policy, but cannot grant
approval, mark tasks Done, overwrite authoritative specs, bypass enforcement or
upload conversation bodies. Reviewers consume synthetic fixtures and sanitized
results, not private journals.

## Main Workflows

1. Validate local owner/storage boundary; redact observed prompt; attempt durable
   append; only then derive decisions. On failure warn and continue (OQ-003).
2. Capture available final output. On compact, reconcile observable transcript
   suffix and assess integrity. Manual and automatic failure policies differ.
3. On compact-source resume, apply expiry, read current SDD state, validate
   materialization, rebuild stale projections and inject bounded recovery context.
4. Perform automatic expiry/deletion without resetting original event age. Keep
   only content-free diagnostics of failed deletion; never claim removal succeeded
   if it did not. The approved daily OS scheduling policy is OQ-010 below;
   next-access-only cleanup does not satisfy it.

The native scheduling candidates and account-availability limits are recorded in
`reports/verification/issue137-host-contract-audit-20260926.md` (OQ-010).
This is a design input, not a claim that any cleanup job is installed or tested.

## Edge Cases

Missing host IDs/transcripts, duplicate delivery, conflicting IDs, partial tail,
interior corruption, failed synchronization/replace, concurrent sessions, moved
worktrees, source changes, expired references, redaction failures, unsafe paths,
tracked storage, empty SDD state and hook timeouts have explicit planned tests.

## Security Boundaries

| Boundary | Requirement | Data classification |
|---|---|---|
| Runtime input to local storage | Schema/owner/path validation and redaction before persistence | Private conversation; potentially sensitive even after redaction |
| Storage to recovered context | Integrity, expiry, ownership and authoritative-state reconciliation | Untrusted evidence; never executable instructions or approval |
| Local evidence to Git/review/CI | No raw journal/transcript upload; synthetic test data and content-free diagnostics | Public only after sanitization |

## Assumptions

Repository observations are bound to investigation baseline
`5d5ada70636b3c4774095b8e4139ed83c21f30c3` (INV-001–INV-017).
Recheck shared hooks, ignore rules, build dependencies and protected membership
immediately before review and implementation. Existing `guardedRead` failure is
not safe-absence proof (`mcp/sdd-forge-mcp/src/path-guard.ts:186`, `:218`, `:250`;
INV-017). Installed-host lifecycle support remains unproven; PreToolUse canary
success does not establish it (INV-011–INV-014).

## Open Questions

OQ-001–OQ-003 are resolved by the human and must not be reopened: 30-day deletion,
secret removal/disclosure, warning/continued work. OQ-004 chooses local worktree
ownership. The following technical questions require evidence before affected
implementation is approved, not another request for those same product choices.

| ID | Owner | Resolution path | Blocks |
|---|---|---|---|
| OQ-005 | Adapter implementer | Observe actual retry IDs; retain separate deliveries without stable identity | Retry-support claims |
| OQ-006 | Storage implementer | Native Windows/macOS/Ubuntu append/replace/sync and failure tests; state precise durability limits | Storage contract |
| OQ-007 | Adapter implementer | Probe actual transcript formats and partial-tail behavior; unknown format remains unavailable | Transcript reconciliation |
| OQ-008 | Runtime integration implementer | Real candidate registration plus prompt/Stop/manual+auto compact/resume evidence on both hosts | Live acceptance |
| OQ-009 | Security implementer | Verify effective ignore/tracked/path checks before writes, including failure cases | Storage safety |
| OQ-010 | Infrastructure designer | Human resolved 2026-09-26: OS-standard daily execution, exclusion at 30 days, physical deletion normally within 24 hours, catch-up after power-off/sleep. Only this feature's logs are targets. Native scheduling, catch-up and failure tests remain required. | Mechanism verification; policy resolved |
| OQ-011 | Security designer | [Bounded redaction grammar candidate](security-spec.md#rule-version-1-grammar-and-processing-order), false-negative limits and failure behavior are defined; independent review and synthetic verification of every persistent/output path remain unperformed | Redaction design |
| OQ-012 | Runtime designer | [Timeout/UTF-8 budget candidates](frontend-spec.md#performance-budget) and [wall-clock policy candidate](infra-spec.md#data-residency-and-retention) are defined; independent review, performance measurement and native host-limit verification remain unperformed; byte budget is not a proven token count | Timing and budget contract |

## Risks

Silent capture loss, private-data exposure, stale authority, overclaimed host
support and unbounded hook latency are release blockers where their required
tests fail. A successful fixture, document review or CI run cannot stand in for
the real host/OS evidence named above.
