# Issue 423 T-004 / T-005 research handoff

## Scope and provenance

Repository: `aharada54914/sdd-forge`; continuation branch:
`codex/issue423-boundary-checkpoint`. Inspected baseline:
`e6673e683ed45aa49b6a9b2efad9ce4dd76e2589` in a clean publishing checkout.
This is a documentation-only research checkpoint, not an implementation report,
approval, formal review verdict, or task-state transition. It records inspection
of the current authoritative sources, not a recovered historical agent verdict.
No runtime contract, frozen specification, ledger or existing evidence is changed.

Read the current `AGENTS.md` and canonical task before implementation. Recheck
these references against the implementation commit; line numbers describe the
baseline above. Do not publish local backups, credentials, terminal paths or raw
host transcripts with future evidence.

## Dependency and admission

`specs/sdd-domain-multitarget/tasks.md:74` defines T-004 as Approved / Planned,
high risk, TDD, blocked by T-003. Line 95 defines T-005 as Approved / Planned,
high risk, TDD, blocked by T-004. Sequence: T-003 quality-gate Done, T-004
implementation and quality gate, then T-005 implementation and quality gate.
T-006 follows T-005. Reading and preparing test cases is not dependent execution.

T-003 has 28 passing behavioral regressions, but that does not repair its
T-001/T-002 canonical evidence admission automatically. The public prerequisite
contract/bundle gap and the requested scoped evidence migration are documented
in `reports/verification/issue423-t003-cloud-20261017/README.md`. Preserve old
records and obtain the required migration authority before replacing bindings.
Only the quality gate may mark a task Done.

## T-004: compatibility and hybrid fallback

Authoritative scope: REQ-004 (`requirements.md:168`), AC-005/006/007 and
TEST-005/006/007 (`acceptance-tests.md:21`), all beneath
`specs/sdd-domain-multitarget/`. `design.md:61`, `:132` and `:143` describe
the retained template surface, absent-context fallback and reader/writer migration.

Required behavior and test preparation:

- Capture the legacy baseline before consumer changes. Absent and invalid
  project context must retain the approved legacy artifact shape and equivalent
  workflow outcomes; exercise valid, stale and malformed context as well.
- Facet-hybrid retains all seven legacy layer documents for every target,
  including non-UI targets. Applicability belongs in the separate manifest, not
  document omission, deletion, rewriting or a changed default/check policy.
- Enumerate readers and writers before any schema, field, status or check
  vocabulary change. Version migrations explicitly. Facet-native is not part of
  this task and requires separately approved migration.
- Verify structural/output compatibility and behavioral workflow events; one
  cannot substitute for the other. Preserve historical golden bytes rather than
  regenerating them to hide a failure.

Existing reuse candidates (inspect their current prerequisites before running):

- `tests/compatibility-byte-identical.tests.sh` and `.ps1`: golden baseline and
  disposable capture/comparison; the Bash driver uses
  `tests/lib/fixture-matrix-builder.sh` and A7 canonical fixtures under
  `specs/epic-195-a7-compatibility/verification/golden-baseline/canonical`.
- `tests/structural-compatibility.tests.sh` and `.ps1`, plus
  `tests/structural-compatibility-live-refresh.tests.sh` and `.ps1`: layer/template
  and structural surfaces. Structural checks alone do not prove workflow parity.
- `tests/project-context-schema.tests.sh` / `.ps1`,
  `tests/context-projection-schema.tests.sh` / `.ps1`, and the existing
  `resolve-project-context-*` drivers: context validation, fallback, discovery,
  selection, caller contracts and parity.

Before changing implementation, record the high-risk persisted-field / sibling
contract / failing-mismatch-test mapping required by AGENTS WFI-001. Use the
existing helper and consumer inventory instead of adding a second resolver.
Rollback is the task's scoped compatibility revert and retained legacy fixtures,
not deletion or rewriting of prior evidence.

## T-005: UI provider boundary and consent-safe fallback

Authoritative scope: REQ-005 (`requirements.md:187`), AC-008/009 and
TEST-008a through TEST-008g / TEST-009a through TEST-009b
(`acceptance-tests.md:24-32`). `design.md:41`, `:45`, `:63`, `:117-126` and
`:152-158` separate Core, local artifacts, optional providers and consent.
The existing resolution behavior is in
`plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md:87-148` and `:244-288`.

Required behavior and test preparation:

- Keep generic UI questions, local canonical design and disposable local mockups
  in bootstrap. External provider operations belong only to applicable UI
  profiles. Core must not gain provider credentials or service-specific APIs.
- Re-read consent at every resolution. Exact `standing` skips prompting but
  audits at most once per feature/destination; exact `off` persistently forbids
  upload and uses the manual fallback.
- `per-feature`, missing, unknown and mis-cased settings use per-feature consent,
  not an implicit grant. Verify feature/session/destination scope, grant and
  withdrawal records, transient decline and a subsequent prompt. Unknown/missing
  does not mean uploads are forbidden forever after an explicit valid grant.
- Provider unavailable, non-UI targets, decline, `off`, and ungranted defaults
  must not upload. Local generation remains usable; unavailable providers use
  the manual path for every consent setting. Local Figma/DTCG input does not
  authorize remote API access.

Reuse `tests/design-sync-standing-consent.tests.sh` / `.ps1` and
`tests/design-sync-scan.tests.sh` / `.ps1` after checking their current coverage.
The standing-consent suite contains static contract checks and preservation of
earlier checks: those do not alone prove runtime absence of network operations.
Add task-scoped fake-provider call/write assertions for the required branches;
do not use real uploads or global trust/permission changes as test setup.
Preserve the task's provider-disable/local-fallback rollback boundary.

## Verification status and continuation checklist

This handoff inspected the cited task, requirements, design, acceptance criteria
and representative existing test drivers. It did not execute T-004/T-005 suites,
implement either task, establish native host parity or perform formal review.
The baseline CI run is
https://github.com/aharada54914/sdd-forge/actions/runs/38964412245 (37 successful
jobs); a new documentation commit still needs its own applicable CI result.

1. Fetch the continuation branch and record its exact HEAD; check concurrent
   changes and canonical prerequisite states before selecting an implementation.
2. Resolve T-003's remaining formal prerequisites without promoting synthetic
   fixtures or old verdicts to new acceptance.
3. Start T-004 in a new implementation context only when its dependency is Done.
   Inventory live consumers, record high-risk preflight, establish RED, make the
   bounded repair, run affected regressions and independent quality verification.
4. Carry T-005's consent matrix forward unchanged unless explicitly amended;
   implement only after T-004 Done, with no-egress negative tests and independent
   verification. Preserve required checks and platform limitations explicitly.

Open implementation questions are factual inventory/coverage checks, not new
requirements: which live consumers have already incorporated compatible changes,
which test cases already cover each branch, and whether available runners can
exercise the required parity paths. Reuse existing results only when their input
identity and scope actually match; otherwise run the missing evidence.
