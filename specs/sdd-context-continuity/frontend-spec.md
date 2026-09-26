# Frontend Specification: SDD context continuity

Status: Draft — native adapter boundary, no web frontend

## Technology Stack

Node built-ins with existing TypeScript/esbuild toolchain; Node >=22.19.0 is the
reuse baseline (`mcp/sdd-forge-mcp/package.json:8`, `:11`; INV-017), to reverify
before review/implementation. No UI framework, network client or added package.
Node test runner/fixtures and existing MCP regressions are proposed, not run.

## Component Tree

Claude adapter / Codex adapter → normalized internal event → shared continuity
core → read-only task reader + private store → host-specific response serializer.
Do not unify host-exclusive request fields or launch MCP stdio startup. Adapter
boundaries validate event kind, host/session/feature identity, optional transcript
path and optional stable event identity before core use (REQ-008/011).

## State Shape

`ObservationV1`: schemaVersion, host, eventKind, opaque session/feature, observed
text, optional transcript locator, optional *proven* stable event identity.
Observed text exists in process memory until redacted. `OutcomeV1`: discriminant,
content-free reason/stage, coverage, optional redacted recovery. Capture success
is a core result after sync, never inferred from process exit alone. Projection
includes source cursor/hashes, current HEAD/task state and verified target refs;
all persisted projections are private, expiring and disposable (REQ-001–006).

## Routes and Components

N/A — no browser routes or user commands. Native lifecycle registration is the
only integration surface. Missing hooks/Copilot remain file-based, non-SDD no-op
(REQ-012; TEST-038–040). No hook or scheduler is registered in this draft.

## API Client Strategy

No network API. Versioned internal schemas reject unknown payload/format and
report unavailable; absent/null transcript never invents a path. Only complete
observable records advance cursor; tail incompleteness retries after completion.
Host-stable identity permits same-content retry dedup; same ID/different payload
errors; turn ID/text alone never dedup (TEST-004–008, TEST-057–059, TEST-065).

Claude and Codex have separate serializers. Candidate audit indicates Claude
manual PreCompact exit 2 / `decision:block` and Codex manual `continue:false`;
these are design inputs, requiring actual safe-barrier proof before enabled use.
Automatic compact never emits blocking response, even if capture fails. Codex
prompt/Stop uses supported warning `systemMessage`; Stop never requests another
model turn to retry storage. Claude manual PreCompact does not assume
`systemMessage`/`continue` is honored. Exact candidate evidence/limits are in
`reports/verification/issue137-host-contract-audit-20260926.md` (OQ-008).
Failure diagnostics contain reason/stage only, not text, paths or secret values.

## Code Splitting and Size Budget

N/A — no web chunks. Add an internal transport-free bundle using existing
esbuild only after approval; package size measurement pending, no invented target
or measured gain. MCP public interfaces stay unchanged (TEST-061/062).

## Performance Budget

All numbers below are conservative **design values**, not measured performance
or token equivalence. OQ-012 remains native-limit verification pending.

| Boundary | Design value | Measurement / failure | AC |
|---|---|---|---|
| Core hook wall time | 1,000 ms total from process entry, using monotonic elapsed time | TEST-034; remaining-time propagation, stop work on exhaustion | AC-010 |
| Native registered timeout | 2 seconds candidate, must be supported/validated separately | TEST-035/036/037; host process-kill behavior must proceed for auto | AC-010/011 |
| Single observation input | 1 MiB UTF-8 | Oversize → no capture, warning; never silently truncate source | AC-015 |
| Transcript reconciliation scan | 8 MiB suffix per invocation | Complete records only; partial coverage + unchanged uncaptured cursor | AC-004/010 |
| Final recovery adapter output | 8,192 UTF-8 bytes including JSON escaping, keys, diagnostics and pointers | TEST-060 measures `Buffer.byteLength` of final serialized bytes | AC-018 |

Prioritize unresolved agreements/exceptions, do-not-reopen, current workflow,
blockers then next action. Fit whole entries by measuring final serialization;
never split surrogate pairs/UTF-8 or cut JSON. Reserve space for coverage/omission
and safe opaque pointers; if envelope cannot fit, return minimal unavailable,
not invalid JSON. This is a byte budget, not a claimed host token count.
Native evidence must confirm host input/token limits before live approval.
Bounded cancellable I/O/lock attempts and remaining-time checks use no retry loop
after deadline. OS uninterruptible sync is not solved by a JS timer; native kill
and durability tests are mandatory, with no successful capture claim on timeout.

## Empty, Loading, Error, and Success Behavior

Canonical feedback is [UX states](ux-spec.md#component-states). Distinguish no-op,
unavailable coverage, failed capture and confirmed durable capture. Do not claim
complete transcript or SAFE from a fixture or unavailable authority read.

## Dependencies

Existing locked build/runtime dependencies only. Shared lockfile/build declarations
must be reverified at review/implementation. No external API, credentials or
daemon. Internal bundle must not acquire MCP transport behavior.

## Testing

TEST-001–018/063–065: source/authority/extraction and transcript contracts;
TEST-027–040/047–051: manual/auto and failure serializers; TEST-057–062/066:
identity, byte boundaries, parser compatibility/concurrency. TEST-036/037 remain
independent actual-host lanes; unit fixtures cannot prove registration/visibility.

## Open Questions

OQ-005/007/008: adapter implementer owns real IDs, transcript format, lifecycle
and serializer/barrier proof; blocks corresponding live contracts. OQ-012:
runtime implementer owns host timeout/token-limit measurement; design values
above may need an explicit reviewed design amendment, never a fabricated result.
