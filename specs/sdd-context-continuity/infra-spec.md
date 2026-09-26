# Infrastructure Specification: SDD context continuity

Status: Draft — no installed job or durability measurement

## Deployment Topology

Per-user native hook → short-lived bundled Node core → owned worktree-local store.
Per-user OS daily oneshot → content-free private owner registry → same store
cleanup. No cloud, network, DB, new dependency, daemon or recursive home scan.
Registry contains only private canonical owner locators/opaque IDs, schema and
scheduler health/clock watermark, not conversation or content-bearing cursors.
Registration validates all targets afresh at every cleanup; it is not authority.

## CI/CD Sequence

After approved tasks: synthetic unit/fault/privacy tests → existing MCP readonly
regressions → per-host registered lifecycle/native OS tests → independent gates.
Existing release/installation integration only; this draft authorizes no deploy,
trust change, CI execution, scheduler install or public evidence upload.

## Environments

macOS, Ubuntu and Windows owning-account local execution are separate native
lanes. Staging/cloud production/URLs/IaC are N/A because no service is deployed.
OS account access controls protect private files; elevated services and stored
account passwords are excluded. Installed Node availability is an installer
precondition; failure warns and leaves ordinary SDD usable (REQ-008/012).

## Infrastructure as Code

Existing installer owns proposed per-user scheduler definitions and rollback;
no Terraform or remote state. Use fixed internal executable/arguments, never
shell interpolation of journal content. Schema-versioned registry drift or
disabled registration produces warning/unavailable, not an enabled claim.

## Scaling Strategy

One per-worktree lock covers append, projection publication and cleanup. Use
exclusive creation of a private lock record with nonce/process metadata;
bounded acquisition, no lock stealing by age alone. Abandoned-lock handling
requires same-owner/native process-death proof; otherwise unavailable, warn.
Sequence is assigned only while holding the lock. File descriptors/path identity
are checked after open. No unlimited retry or background model invocation.

Append newline-complete redacted JSONL and sync the file before `captured`;
stage projections in the same owned directory, sync then replace, and confirm
directory persistence where supported. Visible write is not confirmed durability.
Sync/replace failure leaves no SAFE/captured success; retain valid source evidence.
Partial final journal record is isolated without changing valid prefix; malformed
interior fails integrity. Any quarantine/staging copy has the same expiry and
redaction rules, never raw backup (REQ-001/006; TEST-024–026/048/066).
Native atomic replacement, flush/directory behavior on all OS remains OQ-006;
portable Node operations alone cannot establish power-loss guarantees.

## Service Level Objectives

No invented cloud availability/p95 SLO. Hook/output limits are explicit design
budgets in [frontend](frontend-spec.md#performance-budget); actual measurements
pending. Retention objective is the approved policy, not observed scheduler uptime.

## Data Residency and Retention

All content copies (journal segments, decisions, snapshots, cursors, repair,
quarantine and staging) stay private locally. Expiry is inclusive at original
receipt + 30 × 24 hours; host/retry/rebuild timestamps never renew age. Read and
inject paths filter expiry even when physical deletion fails. Cleanup rewrites
mixed segments using only eligible retained redacted records, validates/syncs
replacement before retiring the old owned file, and retries interrupted staging
safely. Derived views rebuild without expired source; provenance-expired entries
cannot survive by copying. TEST-041–043/044f/h verify every copy and pre-expiry
controls. Delete is normal filesystem removal, not secure erase or backup purge.
No host transcripts, other feature logs or foreign files are cleanup targets.

For a mixed-segment rewrite, preserve each retained record's original receipt,
sequence and redacted payload; recompute only integrity links/hashes over the
retained segment, with an explicit schema-versioned chain header. Validate
the entire retained chain, sync the same-directory temporary file, then atomically
replace the fixed journal-segment filename. That filename remains authoritative;
do not add a separate current-generation pointer or select temporary files by
timestamp. On crash, validate each canonical segment; temporary files are never
replayed and expiry filtering still applies to any old segment left in place.
Unsupported replacement/durability is unavailable, not silently recovered.
Temporary copies remain owned cleanup targets. Native durability remains OQ-006.
If all source records expire, the derived decision is ineligible. If some expire,
rebuild only from retained sources, without extending their original receipt ages;
an unsupported composite inference becomes unavailable rather than keeping its
expired source through the decision copy (TEST-042/043/026).

Clock policy (design): store original UTC receipt and a content-free maximum
observed UTC watermark; effective expiry time is max(nowUtc, watermark), updating
it under the lock. Known expired events never become eligible on rollback/DST.
Large forward jumps may irreversibly expire data; warn content-free and disclose
the limit, do not reset receipt. Clock rollback can delay expiry of records not
yet known expired: record delay honestly, no 24h guarantee under abnormal clock.
Monotonic time controls hook deadlines, not persistent retention age (OQ-012).

| OS | Proposed standard daily/catch-up mechanism | Verification still required |
|---|---|---|
| macOS | Per-user launchd daily StartCalendarInterval + RunAtLoad | Sleep coalescing and login catch-up, not power-off execution |
| Ubuntu | User systemd daily OnCalendar timer, Persistent=true, oneshot | User manager absent/logged-out limits and return activation |
| Windows | Per-user Task Scheduler daily + logon, StartWhenAvailable=true | Missed-run delay, account availability, no idle/battery/network conditions |

Normally delete within 24 hours after expiry, including unopened registered
worktrees; on sleep/power-off/account absence catch up on return. No forced wake,
elevated service, password or resident loop. Registration rejected/disabled means
no new persistent capture (warning/continue); retained expired content remains
ineligible. Permission/interrupted deletion records failure, not success, and
retries via the standard job. Candidate mechanisms are from
`reports/verification/issue137-host-contract-audit-20260926.md`; none is installed
or measured. TEST-044a–i must use actual OS triggers on every supported OS.

## Observability

Reason/stage, schema version, duration, count and scheduler enabled/failed status
only; opaque correlations bounded, no text/digests/private absolute paths in
public evidence. No external telemetry or raw exception dumps. Local registry
errors remain private. Content-bearing diagnostics are forbidden. Warnings go
through host-supported feedback; cleanup failure is visible on next available
host access, never silently labeled removed (REQ-007/009).

## Cost Estimate

N/A — no paid infrastructure/egress. Local disk depends on redacted input volume
and 30-day window, not yet measured. Capacity failure warns/continues; no claim
of unlimited storage or automatic deletion of unrelated files (TEST-050).

## Rollback

Disable only owned adapter/scheduler registrations through existing installer
integration. Preserve ordinary SDD and authoritative files. Existing private
content must remain expiry-filtered and retain owned cleanup until removed;
uninstall cannot strand 30-day content silently. No rollback implementation or
uninstall change occurs here; exact installer contract requires later review.

## Open Questions

OQ-006 storage implementer: native append/sync/replace, lock abandonment and crash
tests block durability claims. OQ-010 infrastructure implementer: all scheduler
TEST-044 cases block physical-deletion claims; policy resolved, mechanism not
verified. OQ-009 security implementer: owner/ignore/native path tests before writes.
