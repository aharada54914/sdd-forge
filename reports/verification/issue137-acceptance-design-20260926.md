# Issue #137 acceptance-to-test mapping (proposal)

Status: proposed test design only; not an approved specification. No tests were
executed. Source: [Issue #137](https://github.com/aharada54914/sdd-forge/issues/137),
sections “Acceptance Criteria” and “Required Scenario Tests”. Repository
constraints and known gaps: `specs/sdd-context-continuity/investigation.md`
(INV-001–INV-017) and `specs/sdd-context-continuity/codemap.md`, saved in
`b7390462995fe15e46bf03b0f06d4c8cc7a7f90d`; their source audit baseline is
`5d5ada70636b3c4774095b8e4139ed83c21f30c3`.

## Acceptance criteria: minimum observable assertions

| AC | Minimum assertion(s) |
|---|---|
| 1 | Before interpretation, persist the user input; resume reports B accepted and A rejected, each traceable to raw WAL evidence. |
| 2 | Preserve the complete composite raw statement; recovery can recover/reference its exception even when extraction omits it. |
| 3 | Forced extractor failure leaves raw evidence durable and available for recovery. |
| 4 | A simulated pre-Stop automatic compact reconciles transcript-tail events observable to the runtime but absent from WAL. |
| 5 | A verified materialized decision is not redundantly injected as a full body; authoritative artifact remains the reference. |
| 6 | Current `tasks.md` state wins over stale HANDOFF and the projection is regenerated. |
| 7 | Reject or quarantine incompatible repository/feature state without contaminating resume. |
| 8 | Detect a partial final JSONL record; preserve the valid prefix and deterministically isolate/recover only the invalid tail. |
| 9 | Manual compact does not report continuity-safe success after critical flush failure; block only when the runtime safely supports it. |
| 10 | Automatic compact is not blocked or stalled by continuity failure; return diagnostic/best-effort outcome. |
| 11 | Claude and Codex adapters each satisfy the common correctness assertions without depending on runtime-exclusive fields or summaries. |
| 12 | With hooks unavailable, ordinary file-based SDD workflow remains usable. |

## Required scenarios: minimum observable assertions

| # | Scenario | Minimum assertion(s) |
|---:|---|---|
| 1 | B decision then manual compact | Prompt is persisted before interpretation; resume restores accepted decision with evidence reference. |
| 2 | B with A-style authentication exception | Raw composite statement and exception remain recoverable. |
| 3 | A superseded by B | Preserve both evidence records; resolve B as current and A as superseded. |
| 4 | Reject / do-not-reopen then compact | Preserve and restore rejected/DNR semantics. |
| 5 | Assistant response then compact | Capture available final assistant message and associate it with the corresponding prompt/turn. |
| 6 | Auto compact during tool execution | Recover observable pre-Stop tail without duplicating already-persisted events. |
| 7 | Extractor forced failure | Raw WAL remains unchanged and recoverable. |
| 8 | Stale HANDOFF | Reconcile against authoritative current state and regenerate. |
| 9 | JSONL partial tail | Keep valid prefix, detect bad tail, and recover only the tail deterministically. |
| 10 | tasks.md / decision-index conflict | Prefer authoritative SDD state; mark/re-evaluate conflicting derived decision state. |
| 11 | Git HEAD changed | Do not reuse a stale projection as current; re-resolve against current state. |
| 12 | Stale journal from another feature/repository | Reject/quarantine before it influences resume. |
| 13 | Claude compact/resume | Exercise actual Claude command-hook input and compact-source resume path. |
| 14 | Codex compact/resume | Exercise actual Codex command-hook input and compact-source resume without requiring a compact summary. |
| 15 | Hook process failure | Surface failure rather than claiming success; prompt failure policy remains unresolved. |
| 16 | Duplicate hook delivery/retry | Deduplicate only when the same event has stable identity; keep legitimate repeated content distinct. |
| 17 | Windows path and CRLF | Preserve equivalent parsed state under CRLF/Windows paths; reject unsafe traversal separately. |
| 18 | No-SDD repository | Graceful no-op and no journal writes outside an SDD project root. |

## Limits and unresolved contract points

- Do not infer event identity from equal content or `turn_id` alone. Exact retry
  idempotency requires a runtime-provided stable event identifier; the current
  contract audit found no documented Codex event-unique retry ID
  (`investigation.md`, INV-013; lines 76–81).
- Complete transcript-tail recovery is only testable against events the host
  actually exposes. Null/missing transcript paths, undocumented formats, or
  events never exposed by a hook cannot be covered by a guarantee
  (`investigation.md`, INV-013; lines 76–81).
- Upstream hook documentation is not proof that a particular installed host
  version has the candidate hook registered or delivers the expected payload
  (`investigation.md`, lines 61–63 and 79–81).
- Product decisions still pending: WAL retention/deletion, secret redaction and
  accepted recovery loss, and whether a failed user-prompt append stops input or
  continues with a warning (`investigation.md`, OQ-001–OQ-003, lines 85–90).
- Technical contracts still pending: worktree/repository identity and storage
  isolation, retry identity, portable durability semantics, missing/partial
  transcript-tail handling, host-version support, and safety for missing ignore
  rules or already-tracked journal files (`investigation.md`, OQ-004–OQ-009,
  lines 90–95).
