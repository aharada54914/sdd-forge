# UX Specification: SDD context continuity

Status: Draft — no runtime verification

## Scope and User Journeys

The local SDD developer continues ordinary Claude/Codex interaction. Successful
capture needs no new command. On resume, a bounded evidence-labeled view restores
unmaterialized agreements; current files remain authoritative (REQ-001–004,
REQ-010–012; AC-001–006, AC-018). No browser view, account UI or cloud workflow.

## Target Views

| Surface | Purpose | Entry / Exit | REQ | AC |
|---|---|---|---|---|
| Native warning | Capture unavailable; input continues | Capture failure / ordinary work | REQ-007 | AC-015 |
| Manual compact safety | SAFE only after all stages; otherwise UNSAFE/unavailable barrier | Manual compact / proven barrier or honest limitation | REQ-007, REQ-008 | AC-009 |
| Resume context | Current state, source pointers and coverage/redaction/expiry limits | Native resume / ordinary work | REQ-002–005, REQ-010 | AC-001–007, AC-018 |

## Component States

| State | Feedback | Recovery | REQ | AC |
|---|---|---|---|---|
| Empty/no-SDD | No-op, no files; unsupported hooks remain file-based | Ordinary SDD files | REQ-012 | AC-012 |
| Capturing | No guaranteed-success message before sync | Deadline → warning | REQ-001, REQ-007 | AC-015 |
| Failure | “Continuity capture unavailable; work can continue.” + reason code, no content/path | Later capture attempt, not a Stop model retry | REQ-007 | AC-010, AC-015 |
| Manual unsafe | “Compaction safety not confirmed.” + failed stage; never SAFE | Supported host barrier only | REQ-007, REQ-008 | AC-009 |
| Recovered | Derived label, current authority, source sequence pointers, omission/coverage notice | Open private evidence through existing tools if desired | REQ-002–004, REQ-009, REQ-010 | AC-001–006, AC-013–014, AC-018 |
| Expired/cleanup failure | Expired evidence unavailable; deletion pending/failed accurately | Native cleanup safely retries | REQ-009 | AC-013 |

## Interaction Sequence

Prompt → privacy validation/redaction → capture attempt → input continues → compact
reconciles observable tail → resume checks authority/expiry → bounded context.
Manual failures and automatic failures have different adapter response contracts;
see [frontend](frontend-spec.md#api-client-strategy). No retained statement grants
approval or reopens do-not-reopen decisions (TEST-063/064).

## Wireframe Attachments

None — manual visual refinement skipped

No mockup provided — optional visualization skipped

## Navigation Map

N/A — no new routes, panels or commands. Overflow references use opaque local
sequence pointers, not public URLs or absolute paths. Lost-state recovery falls
back to current SDD files, never a fabricated complete history.

## Accessibility

Plain text native feedback, short reason codes and non-color-only status. No
spinner, focus capture or animated output. Native host owns focus, keyboard,
screen-reader presentation and WCAG rendering; adapter implementer must inspect
actual warning visibility in TEST-036/037. No claim of host WCAG conformance.

## Responsive Behavior

N/A — host terminal/application owns layout and breakpoints. Messages avoid
fixed-width tables and long private paths; final output uses the bounded format.

## Design Tokens

N/A — ds_profile: none; no rendered components or new visual tokens.

## Open Questions

OQ-008: adapter implementer, actual visibility and supported manual barrier on
each host (AC-009/011), blocking live acceptance. OQ-007: transcript coverage
language follows measured availability (AC-004), never “lossless”.
