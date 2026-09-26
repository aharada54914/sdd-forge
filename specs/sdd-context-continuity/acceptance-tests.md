# Acceptance Tests: SDD context continuity

Status: Draft — planned assertions, no executed tests or review verdict

Targets below name logical suites to create after task approval, not existing
files. Every row is Planned. AC-011 expands the common AC-001–AC-010 behaviors
into separate Claude and Codex real-host lanes; lack of host support is reported
as unavailable, never a fixture-derived PASS. Test secrets must be synthetic.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001, REQ-002 | TEST-001 | integration | Prompt→durable capture→extract ordering; B accepted/A rejected survive manual compact with source sequences | Planned |
| AC-002 | REQ-001, REQ-002 | TEST-002 | integration | B with A-auth exception; omit exception in extraction, retain redacted source and evidence pointer | Planned |
| AC-003 | REQ-001 | TEST-003 | unit | Extractor raises; source bytes/sequence remain intact and recoverable | Planned |
| AC-004 | REQ-003 | TEST-004 | integration | Mid-tool automatic compact before Stop captures exposed complete transcript tail | Planned |
| AC-004 | REQ-003 | TEST-005 | unit | Missing transcript field: capture observed prompt only and mark coverage incomplete | Planned |
| AC-004 | REQ-003 | TEST-006 | unit | Null transcript path: no invented path or complete-capture claim | Planned |
| AC-004 | REQ-003 | TEST-007 | unit | Unknown transcript format: no guessed events/cursor advancement | Planned |
| AC-004 | REQ-003 | TEST-008 | integration | Partial transcript record: keep complete prefix, retry suffix after completion, no skipped event | Planned |
| AC-005 | REQ-004 | TEST-009 | integration | Verified materialization target/hash suppresses duplicate full body, retains authoritative pointer | Planned |
| AC-005 | REQ-004 | TEST-010 | unit | Materialization target missing: source decision remains unresolved | Planned |
| AC-005 | REQ-004 | TEST-011 | unit | Materialization content changed: stale marker cannot suppress source | Planned |
| AC-006 | REQ-004 | TEST-012 | integration | HANDOFF says In Progress while tasks.md says Done: recover Done | Planned |
| AC-006 | REQ-004 | TEST-013 | integration | Decision index contradicts task approval/status: task authority wins, no approval mutation | Planned |
| AC-006 | REQ-004, REQ-005 | TEST-014 | integration | HEAD changes within same worktree: retain owner, rebuild projection | Planned |
| AC-006 | REQ-004 | TEST-015 | unit | Source hash changes at same HEAD: rebuild, not cached state | Planned |
| AC-006 | REQ-004 | TEST-016 | unit | WAL cursor advances: regenerate missing decisions in view | Planned |
| AC-006 | REQ-004 | TEST-017 | unit | Feature disappears: old feature projection not injected | Planned |
| AC-006 | REQ-004 | TEST-018 | unit | Task lifecycle changes: regenerate from current state | Planned |
| AC-007 | REQ-005 | TEST-019 | integration | Copied foreign repository journal rejected before injection | Planned |
| AC-007 | REQ-005 | TEST-020 | integration | Two worktrees of one repository remain isolated | Planned |
| AC-007 | REQ-005 | TEST-021 | unit | Another feature's records excluded from selected feature recovery | Planned |
| AC-007 | REQ-005 | TEST-022 | unit | Another session's cursor cannot silently authorize replay; explicit owner reconciliation required | Planned |
| AC-007 | REQ-005 | TEST-023 | integration | Canonical alias of same worktree resolves same owner without escaping storage root | Planned |
| AC-008 | REQ-006 | TEST-024 | integration | Partial final WAL record isolated; valid prefix preserved byte-for-byte | Planned |
| AC-008 | REQ-006 | TEST-025 | unit | Interior malformed record not silently truncated as partial tail | Planned |
| AC-008 | REQ-006 | TEST-026 | integration | Interrupt recovery between staging/publish; retained valid events survive next run | Planned |
| AC-009 | REQ-007 | TEST-027 | integration | Manual flush failure: UNSAFE, explicit diagnostic, proven host barrier only | Planned |
| AC-009 | REQ-007 | TEST-028 | integration | Manual reconciliation failure: no SAFE result | Planned |
| AC-009 | REQ-007 | TEST-029 | integration | Manual integrity failure: no SAFE result | Planned |
| AC-009 | REQ-007 | TEST-030 | integration | Manual projection publication failure: no SAFE result | Planned |
| AC-009 | REQ-007, REQ-008 | TEST-031 | adapter | Unsupported manual barrier: explicit unavailable result, no fabricated protection | Planned |
| AC-010 | REQ-007 | TEST-032 | adapter | Auto write failure: allow compact, content-free diagnostic | Planned |
| AC-010 | REQ-007 | TEST-033 | adapter | Auto read failure: allow compact, no invented capture | Planned |
| AC-010 | REQ-007 | TEST-034 | adapter | Auto deadline exhaustion: return within specified bound, no background model retry | Planned |
| AC-010 | REQ-007 | TEST-035 | e2e | Hook process termination: actual host proceeds, no blocking protocol response | Planned |
| AC-011 | REQ-008 | TEST-036 | live-host | Claude candidate-loaded lifecycle lane: AC-001–AC-010, record individual case outcomes and host version | Planned |
| AC-011 | REQ-008 | TEST-037 | live-host | Codex candidate-loaded lifecycle lane: AC-001–AC-010, no Claude-only summary/field dependency | Planned |
| AC-012 | REQ-012 | TEST-038 | integration | Hooks unavailable: ordinary file-based SDD behavior unchanged | Planned |
| AC-012 | REQ-012 | TEST-039 | integration | Copilot fallback: no continuity guarantee and no new required hook dependency | Planned |
| AC-012 | REQ-012 | TEST-040 | integration | Non-SDD directory: no-op, no journal files created | Planned |
| AC-013 | REQ-009 | TEST-041 | clock-controlled | Just before 30-day expiry is eligible; exact boundary and later are excluded | Planned |
| AC-013 | REQ-009 | TEST-042 | integration | Expiry deletes journal content, decisions, snapshots, recovery/quarantine data and content-bearing cursors; assert each location | Planned |
| AC-013 | REQ-009 | TEST-043 | integration | Retry/rebuild does not renew original receipt age or revive expired references | Planned |
| AC-013 | REQ-009 | TEST-044 | platform | OS-standard daily job: inactive-worktree deletion normally within 24 hours of expiry; catch up after shutdown/sleep; deletion failure visible and expired data non-injectable; only owned continuity logs deleted | Planned |
| AC-014 | REQ-009 | TEST-045 | security | Each reviewed redaction pattern absent from primary/temp/derived/recovery files and diagnostics; placeholders disclose loss | Planned |
| AC-014 | REQ-009 | TEST-046 | security | Redaction failure never falls back to unredacted persistence or backup | Planned |
| AC-015 | REQ-001, REQ-007 | TEST-047 | fault-injection | Append failure warns, continues, emits no capture-success marker | Planned |
| AC-015 | REQ-001, REQ-007 | TEST-048 | fault-injection | Synchronization failure warns/continues; distinguish visible data from confirmed durability | Planned |
| AC-015 | REQ-001, REQ-007 | TEST-049 | fault-injection | Permission failure warns/continues, no chmod escalation | Planned |
| AC-015 | REQ-001, REQ-007 | TEST-050 | fault-injection | Storage capacity failure warns/continues, no successful capture claim | Planned |
| AC-015 | REQ-003, REQ-007 | TEST-051 | adapter | Stop capture failure does not ask assistant to continue as a retry | Planned |
| AC-016 | REQ-009 | TEST-052 | security | Missing ignore entry: no write, no implicit ignore/index repair | Planned |
| AC-016 | REQ-009 | TEST-053 | security | Negated ignore entry: effective exclusion check rejects persistence | Planned |
| AC-016 | REQ-009 | TEST-054 | security | Already tracked journal: no write/delete/index mutation | Planned |
| AC-016 | REQ-009 | TEST-055 | security | Git check error: no assumed private storage | Planned |
| AC-016 | REQ-005, REQ-009 | TEST-056 | security | Symlink/junction/traversal escape: no external read/write; each applicable native OS case explicit | Planned |
| AC-017 | REQ-006 | TEST-057 | unit | Proven stable event ID duplicate: no second append; same ID/different content rejected | Planned |
| AC-017 | REQ-006 | TEST-058 | unit | Equal text without stable ID persists as distinct deliveries | Planned |
| AC-017 | REQ-006 | TEST-059 | unit | Same turn ID with distinct observed events persists both | Planned |
| AC-018 | REQ-010 | TEST-060 | unit | Small/empty view, exact budget, overflow, Unicode and escaped content respect measured bound and safe pointers | Planned |
| AC-018 | REQ-011 | TEST-061 | regression | Existing MCP read-only/static and core snapshot suites unchanged | Planned |
| AC-018 | REQ-011 | TEST-062 | native-platform | Windows path/CRLF task interpretation matches existing canonical parser; Ubuntu/macOS controls | Planned |
| AC-001, AC-002 | REQ-002 | TEST-063 | integration | A superseded by B: keep both source records, present B as current | Planned |
| AC-001 | REQ-002 | TEST-064 | integration | Explicit reject/do-not-reopen remains after compact, without reopening the question | Planned |
| AC-004 | REQ-003 | TEST-065 | adapter | Available final assistant output captured with actual session/turn correlation; absent output not invented | Planned |
| AC-008, AC-017 | REQ-006 | TEST-066 | concurrency | Concurrent same-worktree deliveries yield serialized valid records and unique local sequences | Planned |

## Source scenario coverage

Issue #137 scenarios 1–18 map respectively to TEST-001, TEST-002, TEST-063,
TEST-064, TEST-065, TEST-004, TEST-003, TEST-012, TEST-024, TEST-013, TEST-014,
TEST-019–022, TEST-036, TEST-037, TEST-027–035/047–051, TEST-057–059,
TEST-062 and TEST-040. Live-host rows rerun the concrete logical cases rather
than adding ambiguous generic success checks. OS rows must name each executed
OS; skipped native behavior remains unproven.

## Pending design inputs

### TEST-044 native scheduling cases

Each case is Planned on macOS, Ubuntu and Windows separately. The same cleanup
assertions are reused; configuration inspection or a direct cleanup invocation
cannot prove an OS trigger fired. Record native version, trigger, dispatch time,
expiry time and content-free result. A disabled/unavailable user scheduler is
not PASS. The owning account may need to log in after power-on; this limitation
must be visible rather than an unconditional reboot guarantee.

| Test ID | Concrete assertion |
|---|---|
| TEST-044a | Registered daily trigger deletes expired owned data in an unopened worktree; a pre-expiry control remains unchanged. Measure the normal 24-hour objective. |
| TEST-044b | Missed trigger during sleep runs after wake; expired data remains non-injectable before cleanup. |
| TEST-044c | Missed trigger during power-off runs after restart and owner login without opening the worktree. |
| TEST-044d | Owner logged out or user manager unavailable: report unavailable execution, then catch up on its return; never claim deletion while absent. |
| TEST-044e | Registration rejected/disabled: no false enabled status or new persistent capture; ordinary work continues with a warning. |
| TEST-044f | Delete denied or interrupted: report failure, preserve non-expired records, keep expired records ineligible and safely retry. |
| TEST-044g | Foreign, replaced or unsafe registry target: reject cleanup and preserve both the foreign file and a host-transcript control. |
| TEST-044h | Scheduled cleanup overlaps prompt append: serialize operations; no lost retained event or partially published projection. |
| TEST-044i | Daily trigger across clock/DST change: record actual delay; expiry never uses a refreshed retry/rebuild timestamp or reinjects already expired records. |

### Remaining contracts

TEST-034/060 have [numeric timeout/UTF-8 budget candidates](frontend-spec.md#performance-budget)
and a [wall-clock policy candidate](infra-spec.md#data-residency-and-retention)
(OQ-012); independent review, performance measurement and native host-limit
verification remain unperformed. The byte budget is not a proven token count.
TEST-044 awaits native verification of the human-approved daily/catch-up expiry
mechanism (OQ-010; policy resolved 2026-09-26). TEST-045/046 have a
[bounded redaction grammar candidate](security-spec.md#rule-version-1-grammar-and-processing-order)
(OQ-011); independent review and synthetic verification remain unperformed.
Storage/platform and live-host tests depend on OQ-005–OQ-009 evidence.
This draft is not ready for a PASS or task generation while those contracts remain
open. No UI Integration Checklist: no new user-facing command/view is introduced.
