# UX Specification: cloud-orchestration

## Scope and User Journeys

Primary users are platform engineers and environment approvers. Entry points
are bootstrap routing and direct provider skills. Success is an evidence-backed
verified deployment or a clear no-change result (REQ-009, AC-009). Production
deployment without separately configured authorization is excluded.

## Target Views

| View | User | Purpose | Entry | Exit | REQ | AC |
|---|---|---|---|---|---|---|
| CLI route result | Engineer | Show provider, scope, one owner and path | Bootstrap/direct skill | Plan or BLOCKED | REQ-002 | AC-002 |
| CI approval summary | Approver | Inspect exact preview, writes, costs and digest | Protected prepare/apply environment | Authorize or reject | REQ-005 | AC-005 |
| Verification summary | Operator | Show actual checks and recovery action | Observe/verify/reconcile | Verified, failed or blocked evidence | REQ-009 | AC-009 |

## Component States

| Component | State | Trigger | Visible Feedback | Recovery | REQ | AC |
|---|---|---|---|---|---|---|
| Router | Empty | No target/owner | Required fields, no guessed target | Supply explicit scope/owner | REQ-002 | AC-002 |
| Executor | Loading | Native operation submitted | Native ID and elapsed time | Read-only reconcile | REQ-006 | AC-006 |
| Executor | Unknown | Submission/poll timeout | UNKNOWN, original operation ID | Query original operation; no blind retry | REQ-006 | AC-006 |
| Gate | Blocked | Missing approval/input/observation | Named missing condition | Correct condition and obtain fresh authorization where needed | REQ-005 | AC-005 |
| Verifier | Success | All mandatory fresh checks pass | VERIFIED with check/evidence references | Complete evidence publication | REQ-009 | AC-009 |

## Interaction Sequence

Engineer routes and validates → CI prepare authorization → preview summary →
apply authorization → exact execution → readback → mandatory health checks →
evidence. Direct invocation takes the same guarded path. The summary shows
provider, account/subscription, region, unit, owner, operation, artifact digest,
preview changes/replacements/deletes, expiry, policy verdict and required checks.
Cloud write authority is never represented by a local confirmation checkbox.

## Wireframe Attachments

None — manual visual refinement skipped. CLI and existing CI surfaces only.

## Navigation Map

Bootstrap/direct plugin → route → plan → prepare → approve → apply → verify.
Failure links to the exact CI/native operation and its redacted evidence. Resume
uses persisted run identity and verifies artifacts; rerunning a command does
not silently create another operation or reuse an approval.

## Accessibility

Plain-text labels and structured JSON accompany status; color is not the only
signal. Errors identify the failed field/check and next allowed action. No new
graphical surface; WCAG layout/focus implementation is N/A — no change to CI UI.
CLI outputs must remain readable without ANSI sequences (TEST-011).

## Responsive Behavior

N/A — no change: no browser layout. Text summaries wrap without relying on
wide tables; machine output is a separate JSON document.

## Design Tokens

N/A — no change: no visual component or design-token dependency.

## Open Questions

None for implementation. Live target details are the deployment prerequisites
listed in requirements.md.
