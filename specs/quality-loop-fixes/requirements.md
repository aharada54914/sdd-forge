# Requirements: quality-loop-fixes

Spec-Review-Status: Passed

Source Issues:
- https://github.com/aharada54914/sdd-forge/issues/167 (Stream 1 —
  quality-gate cycle-limit counts across features; ticket
  `docs/review-tickets/RT-20260712-001.yml`)
- https://github.com/aharada54914/sdd-forge/issues/176 (Stream 2 —
  `emit-run-record` blocked-count keyword scan; WFI
  `docs/workflow-improvements/WFI-010.md`)
- https://github.com/aharada54914/sdd-forge/issues/166 (Stream 3 —
  panelist-input bundle completeness + pre-panel readiness; WFI
  `docs/workflow-improvements/WFI-009.md`)
- https://github.com/aharada54914/sdd-forge/issues/179 (Stream 4 —
  `validate-review-context-set.sh` CRLF/jq contamination; no WFI/RT yet,
  OQ-6)

Investigation: specs/quality-loop-fixes/investigation.md (INV-001..INV-028,
OQ-1..OQ-6). Baseline: specs/quality-loop-fixes/baseline-behavior.md
(BL-001..BL-012, BL-101..BL-105).

## Overview

Four independent, already-approved defect-fix streams inside
`plugins/sdd-quality-loop/` (plus one `plugins/sdd-ship/skills/ship/SKILL.md`
prose reference) share one property: each is a narrow, evidence-quoted
correction to an existing deterministic gate script or skill, not a new
capability. Stream 1 (#167) scopes the quality-gate cycle-limit count to the
current feature, closing a false `Escalate-Human` RT-20260712-001 recorded
for `epic-136-phase1-guards` (INV-001, INV-002). Stream 2 (#176) replaces an
unanchored whole-file `BLOCKED` keyword scan with a read of the gate
report's own `^VERDICT:` header, per the human-decided narrowed scope of
WFI-010 (INV-006). Stream 3 (#166) closes two evidence-completeness gaps
WFI-009 records from the `epic-136-phase1-guards` retrospective: the
panelist-input bundle collector does not recurse and never verifies itself
against the implementation report's declared-outputs table (INV-011,
INV-012), and `cross-model-verify/SKILL.md` has no deterministic pre-panel
readiness step for specification-enumerated coverage requirements
(INV-014). Stream 4 (#179) appends `| tr -d '\r'` to every `jq -r`
consumption site in `validate-review-context-set.sh`'s record-hash
recomputation path, following the proven pattern from commit `c756a5a`
(INV-016, INV-017), so a Windows Git-Bash `jq.exe` CRLF byte does not
corrupt a byte-exact hash comparison on an otherwise valid identity ledger.

This spec's own investigation (INV-020..INV-022) additionally resolves a
discrepancy the issue text for stream 4 does not reflect: the
machine-enforced protected-file list
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4,18`)
does NOT include `validate-review-context-set.sh` — only
`plugins/sdd-ship/skills/ship/SKILL.md` (a stream-1 reference target) is
genuinely R-10-protected among the 8 target files. See Open Questions
(OQ-1) for the resolution and Assumptions for the re-verification
instruction this finding carries.

## Target Users

- The `ship` skill (`plugins/sdd-ship/skills/ship/SKILL.md`) and any human
  or agent session invoking `/sdd-ship:ship`: Stream 1's audience — they
  currently see a false `Escalate-Human` once three or more DIFFERENT
  features happen to share a task id (e.g. every feature's own `T-001`),
  stalling a healthy feature that has zero gate reports of its own
  (INV-001).
- `emit-run-record.{sh,ps1}` callers (the retrospective/run-record
  emission step): Stream 2's audience — they currently see an inflated
  `gate_reports.blocked` count whenever a same-feature report's PROSE
  happens to contain the word "BLOCKED" outside its own `VERDICT:` line
  (INV-006, INV-009).
- `cross-model-verify` skill operators and the panelists it blindly
  invokes: Stream 3's audience — they currently receive a bundle that may
  silently omit subdirectory evidence or evidence the implementation
  report declares but the bundle never collected, producing exactly the
  kind of evidence-completeness NEEDS_WORK the `epic-136-phase1-guards`
  retrospective recorded (INV-011).
- `validate-review-context-set.sh` callers on Windows Git Bash (every
  review-context-gated reviewer/evaluator/loop-driver invocation on that
  runtime): Stream 4's audience — they currently see every invocation fail
  closed with `REVIEW_CONTEXT_IDENTITY: canonical identity ledger record
  hash is invalid` even against a canonically valid ledger, entirely
  because of an untreated trailing `\r` (INV-016, INV-018).

## Problems

- BL-101: `check-quality-gate-cycle-limit.{sh,ps1}` counts gate reports for
  a task id across ALL features sharing `reports/quality-gate/`, not just
  the current feature (`check-quality-gate-cycle-limit.sh:42`;
  `.ps1:39-40`; RT-20260712-001).
- BL-102: `emit-run-record.{sh,ps1}` `gate_reports.blocked` counts any
  feature-scoped gate report whose BODY contains the literal substring
  `BLOCKED` anywhere, not just reports whose own `VERDICT:` header says
  `BLOCKED` (`emit-run-record.sh:138`; `.ps1:149-151`; WFI-010).
- BL-103/BL-104: `prepare-panelist-input.{sh,ps1}` collects only top-level
  files of `--input` (no recursion) and never verifies the collected
  bundle against the implementation report's declared-outputs table before
  printing a digest (`prepare-panelist-input.sh:272`; `.ps1:210`;
  WFI-009); `cross-model-verify/SKILL.md` invokes panelists with no
  deterministic pre-panel readiness step for specification-enumerated
  coverage requirements (`cross-model-verify/SKILL.md:40-148`; WFI-009).
- BL-105: `validate-review-context-set.sh`'s record-hash recomputation
  reads `jq -r ... | @tsv` output without stripping `\r`, so on Windows Git
  Bash (`jq.exe`) a trailing CR on the final TSV field corrupts the
  byte-exact hash comparison, producing
  `"canonical identity ledger record hash is invalid"` on a canonically
  valid ledger (`validate-review-context-set.sh:241-258,307`; also line
  187's conditional `task_id` read and lines 275/305 — the two sites
  outside the record-hash path proper; issue #179).

## Goals

- REQ-001 (Stream 1, #167/RT-20260712-001; INV-001..005, INV-020..023,
  OQ-1, OQ-2, OQ-3, OQ-5): Give
  `check-quality-gate-cycle-limit.{sh,ps1}` a new CLI contract —
  `<task-id> <feature> [reports-dir]`, feature a REQUIRED second
  positional — and scope the count to reports matching BOTH the
  word-bounded task id (BL-001, preserved) AND an anchored
  `^Feature:[[:space:]]*<feature>[[:space:]]*$` line (the same anchor
  `emit-run-record.sh:125` already uses, INV-007). Update
  `plugins/sdd-ship/skills/ship/SKILL.md` Step 4 prose and both invocation
  examples to describe and pass the feature argument, staged via
  human-copy (protected, OQ-2). Register the suite's CI coverage (OQ-5).
- REQ-002 (Stream 2, #176/WFI-010; INV-006..010, OQ-4): Change
  `emit-run-record.{sh,ps1}`'s `gate_reports.blocked` computation from an
  unanchored whole-file `BLOCKED` scan to a read of each feature-scoped
  report's own anchored `^VERDICT:[[:space:]]*BLOCKED[[:space:]]*$` line;
  a report with no `VERDICT:` line at all is not counted as blocked
  (OQ-4). Close the existing test-suite coverage gap (INV-010) that lets a
  same-feature, non-BLOCKED-verdict report with body-text "BLOCKED"
  silently miscount.
- REQ-003 (Stream 3a, #166/WFI-009; INV-011..013, INV-015): Make
  `prepare-panelist-input.{sh,ps1}`'s collector recurse into
  subdirectories of `--input`, and verify the collected bundle contains an
  artifact for every path in the implementation report's `## Outputs`
  table (path AND content hash must match, reusing the parser shape
  `validate-review-context-set.sh:63-74` already establishes for the same
  table format). On any missing or hash-mismatched path, fail closed with
  the list of gaps and do NOT print an input digest.
- REQ-004 (Stream 3b, #166/WFI-009; INV-014): Add a deterministic
  pre-panel readiness step to `cross-model-verify/SKILL.md`, inserted
  between Step 1 (Consent + Sanitize) and Step 2 (Detect available
  panelists): when the task's specification flags an enumerable coverage
  requirement, require the bundle to include a machine-checkable coverage
  manifest and fail the readiness step — before any panelist is invoked —
  when any enumerated element is unmapped.
- REQ-005 (Stream 4, #179; INV-016..019, OQ-6): Append `| tr -d '\r'`
  unconditionally (no `uname`/OS branching, per the proven pattern in
  commit `c756a5a`, INV-017) to every `jq -r` consumption site in
  `validate-review-context-set.sh`: the 9 manifest single-value reads
  (lines 178-185 plus the conditional `task_id` read at line 187 — this
  last site is beyond INV-016's own enumeration, found directly during
  this spec's authoring by reading the full file), the ledger `@tsv`
  batch read (lines 250-258), and the two remaining sites (line 275, line
  305). `.ps1` is unmodified (INV-019 — parses via `ConvertFrom-Json`, not
  `jq`). Cites issue #179 directly as the Source Issue (OQ-6 — no new
  WFI/RT is filed).
- REQ-006 (cross-cutting, all streams; INV-026): Every `.sh` line any
  stream adds or changes avoids `declare -A` and guards any possibly-empty
  array under `set -u` (bash 3.2 safety); every `.ps1` file any stream
  touches keeps (or gains) an explicit `exit N`. BL-001..BL-012
  (Must-Preserve, baseline-behavior.md) all re-verify green after all 4
  streams land, except the exact BL-101..BL-105 replacements each stream
  makes.
- REQ-007 (cross-cutting, all streams): Each stream's own PR/commit set
  carries its own `CHANGELOG.md` `## Unreleased` entry citing its own
  issue number (#167, #176, #166, #179 — four independent entries, mirrors
  epic-159-pillar-d's REQ-005 precedent); `validate-repository` and the
  skill-reference count sync stay green after each stream; no
  version-literal edit exists outside `scripts/bump-version.sh`.

## Non-goals

- The directory-move remedy for Stream 1 (`reports/quality-gate/<feature>/`
  subdirectories) — explicitly rejected (OQ-3): blast radius ~121 existing
  report files plus every consumer that globs `reports/quality-gate/`
  (e.g. `emit-run-record.sh:125`). The grep-both remedy is adopted
  instead.
- Restoring the WFI-010 header-association concern (`Task:`/`Run ID:`
  lines in gate reports) — already resolved by remedy (b)'s prior,
  already-landed authoring fix (INV-006); this spec's Stream 2 is
  narrowed to the blocked-count keyword-scan fix only.
- A precise, general-purpose Markdown table parser for Stream 3's
  declared-outputs check. It reuses the EXACT existing row shape
  (`| \`path\` | \`hash\` |`) and heading (`## Outputs`) the loop already
  parses at `validate-review-context-set.sh:63-74` — no new table format
  is invented.
- A general coverage-manifest schema usable outside cross-model
  verification. Stream 3b's readiness step is scoped to the existing
  `cross-model-verify` flow only.
- Extending guard protection (`PROTECTED_GATE_SUFFIXES`) to
  `validate-review-context-set.sh` (OQ-1's option (a)). This spec proceeds
  under option (b) — a direct edit — per the human decision recorded in
  Open Questions; guard-list extension may be proposed later as its own
  WFI, out of scope here.
- A `.ps1` twin of any Stream-4 change (INV-019 — `validate-review-context-set.ps1`
  does not share the `jq` CRLF defect by construction).
- tasks.md and traceability.md (Phase 2 artifacts, authored after spec
  approval). This spec deliberately does not pre-assign `T-NNN` task
  numbers to the 4 streams — Main Workflows below refers to "Stream 1..4"
  so Phase 2's own task decomposition (one task per stream, or a different
  split) is not constrained by a numbering choice made here.

## User Stories

As the `ship` skill invoking the cycle-limit gate for a task, I get
`continue` when MY feature's own gate-report count is below three, even if
two other features independently happened to use the same bare task id —
I am never falsely told to escalate to a human because of reports that
have nothing to do with my feature. As a maintainer reading a run record, I
see `gate_reports.blocked` count only the reports that actually verdicted
BLOCKED, not every report whose prose happens to mention the word. As a
panelist reviewing a sanitized input bundle, I can trust that every file
the implementation report declares as an output is actually present in
what I am given, wherever in the input tree it lives, and that a
completeness gap is caught and reported BEFORE I am asked to review
anything, not discovered after two blind panelists both flag the same
evidence gap. As a Windows Git Bash user running any review-context-gated
step, my canonically valid identity-ledger chain is accepted, not rejected
by a byte a shell function control character introduced and my own code
never touched.

## Acceptance Criteria

- AC-001: `check-quality-gate-cycle-limit.(sh|ps1)` accepts
  `<task-id> <feature> [reports-dir]`; `feature` is a REQUIRED second
  positional matching `^[a-z0-9][a-z0-9-]*$` (Field Definitions); a
  missing or malformed feature argument is a usage error, exit 2
  (mirrors BL-004's task-id validation pattern). (REQ-001)
- AC-002: count = reports under `reports-dir` matching BOTH the
  word-bounded task id (BL-001) AND an anchored
  `^Feature:[[:space:]]*<feature>[[:space:]]*$` line (the same anchor
  `emit-run-record.sh:125` uses). (REQ-001)
- AC-003: 0/1/2 feature-scoped matches → `continue`, exit 0; 3+ →
  `Escalate-Human`, exit 1 (BL-002/BL-003 preserved, now feature-scoped).
  (REQ-001)
- AC-004: cross-feature collision regression — a task id with 3+ reports
  filed under a DIFFERENT feature and 0, 1, or 2 reports under the target
  feature returns `continue` (closes RT-20260712-001's measured
  false-positive, the exact scenario INV-001 records for
  `epic-136-phase1-guards`). (REQ-001)
- AC-005: `.sh`/`.ps1` output+exit parity holds for the new 2-required-arg
  contract, including the new usage-error branch. (REQ-001)
- AC-006: `plugins/sdd-ship/skills/ship/SKILL.md` Step 4 prose
  (`SKILL.md:205-207`) and both invocation examples (`SKILL.md:196,202`)
  are updated to describe and pass the feature argument; the edited copy
  is staged at
  `specs/quality-loop-fixes/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`
  with a `MANIFEST.sha256` entry, never written to the live protected
  file directly (OQ-2). (REQ-001)
- AC-007: `tests/quality-gate-cycle-limit.tests.sh` keeps its existing
  entry in `tests/run-all.sh`; it is NOT added to `tests/run-all.ps1`,
  matching the established combined-suite convention (the suite already
  drives both the `.sh` and `.ps1` target scripts internally via a `pwsh`
  subprocess, the same pattern `tests/second-approval-mask.tests.sh`,
  `tests/review-agent-isolation.tests.sh`, and
  `tests/review-contract-foundation-parity.tests.sh` establish — none of
  which appear in `run-all.ps1`, which lists only native `.tests.ps1`
  files). A CI step for the suite is staged under
  `specs/quality-loop-fixes/human-copy/.github/workflows/test.yml` with a
  `MANIFEST.sha256` entry (OQ-5) — the human maintainer applies both
  staged human-copy candidates as pre-merge commits on the feature PR
  branch. (REQ-001)
- AC-008: `emit-run-record.{sh,ps1}` `gate_reports.blocked` = count of
  feature-scoped gate reports matching the anchored
  `^VERDICT:[[:space:]]*BLOCKED[[:space:]]*$` line (replaces the
  unanchored scan at `emit-run-record.sh:138` / `.ps1:149-151`).
  (REQ-002)
- AC-009: a report with NO `^VERDICT:` line at all is not counted as
  blocked (OQ-4 — fail-open for that one pre-convention legacy report,
  documented, not treated as a hard error). (REQ-002)
- AC-010: a report whose `VERDICT:` line says `PASS` or `NEEDS_WORK` but
  whose BODY prose independently contains the literal substring "BLOCKED"
  (the `T-008.md`-style case, INV-009) is NOT counted as blocked. (REQ-002)
- AC-011: a new same-feature, body-text-"BLOCKED" fixture is added to
  `tests/emit-run-record-feature-scope.tests.sh`/`.ps1`, closing the
  INV-010 coverage gap (the existing fixture only proves cross-feature
  exclusion, never a same-feature, non-BLOCKED-verdict, body-text-BLOCKED
  case). (REQ-002)
- AC-012: BL-005/BL-006 (gate_total/max_gate_runs/first_pass_tasks
  feature-scoping; review-ticket severity anchoring and feature-scoping)
  stay unedited and green — non-regression. (REQ-002)
- AC-013: `prepare-panelist-input.{sh,ps1}`'s collector recurses into
  subdirectories of `--input` (replaces the single-level glob at
  `prepare-panelist-input.sh:272` / the non-`-Recurse`
  `Get-ChildItem` at `.ps1:210`). (REQ-003)
- AC-014: every path in the implementation report's `## Outputs` table
  (`| \`path\` | \`hash\` |` row shape, INV-015) is verified present in
  the collected bundle with a matching content hash, reusing the parser
  shape `validate-review-context-set.sh:63-74`'s `evaluator_output_is_declared`
  already establishes for the identical table format, AND reusing the
  same site's `path_is_authorized` containment discipline (INV-015): a
  declared path is resolved and containment-checked against the bundle's
  own input root BEFORE any read is attempted. (REQ-003)
- AC-015: a declared path MISSING from the collected bundle causes a
  fail-closed exit (nonzero), the list of gaps is printed, and NO input
  digest line is printed. (REQ-003)
- AC-016: a declared path present in the bundle but with a content HASH
  MISMATCH against the implementation report's declared hash causes the
  same fail-closed, gap-list, no-digest contract as AC-015. (REQ-003)
- AC-017: a declared path that lives in a SUBDIRECTORY of `--input` is
  correctly located and verified present+matching — proving AC-013's
  recursion actually feeds AC-014's completeness check, not merely
  collected without being checked. (REQ-003)
- AC-018: the success path (every declared output present with a matching
  hash) preserves BL-007/BL-008 (fail-closed consent gate; secret/path/URL
  sanitization) and BL-009's exact stdout contract (digest line, then an
  optional `effort=<e>` second line only when `--effort` was passed)
  completely unchanged. (REQ-003)
- AC-019: `cross-model-verify/SKILL.md` gains a deterministic pre-panel
  readiness step, inserted between Step 1 (Consent + Sanitize) and Step 2
  (Detect available panelists), that — when the task's specification
  flags an enumerable coverage requirement — requires the bundle to
  include a machine-checkable coverage manifest (required element →
  exercising-fixture mapping). (REQ-004)
- AC-020: the readiness step fails closed — does not proceed to Step 2 /
  panelist invocation — when any enumerated element in the coverage
  manifest is unmapped. (REQ-004)
- AC-021: for a task whose specification does NOT flag an enumerable
  coverage requirement, the readiness step is a documented no-op; ordinary
  tasks proceed to Step 2 exactly as today (non-regression). (REQ-004)
- AC-022: all 9 manifest single-value `jq -r` reads in
  `validate-review-context-set.sh` (lines 178-185 plus the conditional
  `task_id` read at line 187) are each piped through `tr -d '\r'`.
  (REQ-005)
- AC-023: the ledger `@tsv` batch read feeding the
  `while IFS=$'\t' read -r ...` loop (lines 250-258) is piped through
  `tr -d '\r'`. (REQ-005)
- AC-024: the two remaining sites outside the record-hash path proper
  (`jq -r '.allowed_input_manifest[].path'` at line 275;
  `jq -r '.allowed_input_manifest[] | [.path, .sha256] | @tsv'` at line
  305) are each piped through `tr -d '\r'`. (REQ-005)
- AC-025: a CRLF-emitting `jq` shim fixture (a wrapper that appends `\r`
  to every `-r` invocation's output, prepended onto `PATH` for the test)
  proves the fixed validator accepts a canonically valid genesis ledger on
  ANY OS — a portable, OS-independent exercise of the defect, not only
  reproducible on real Windows CI; `loop_validator_capability_probe`
  (`tests/lib/loop-driver.sh:460-519`, INV-018) flipping to `ok` on real
  Windows CI is recorded as corroborating evidence in the implementation
  report, not re-asserted by the new fixture test. (REQ-005)
- AC-026: non-regression — genuinely tampered ledgers (BL-010: wrong
  sequence, wrong previous hash, symlink traversal, duplicate run/session
  id) still fail closed with the correct
  `REVIEW_CONTEXT_IDENTITY`/`REVIEW_CONTEXT_PATH` coded error after the
  fix; `validate-review-context-set.ps1` is unmodified (INV-019).
  (REQ-005)
- AC-027: BL-001..BL-012 (Must-Preserve) all re-verify green after all 4
  streams land, except the exact BL-101..BL-105 replacements each stream
  makes — re-run and recorded per stream in its implementation report.
  (REQ-006)
- AC-028: every `.sh` line any stream adds or changes avoids `declare -A`
  and guards any possibly-empty array under `set -u`; every `.ps1` file
  any stream touches ends with an explicit `exit N`. (REQ-006)
- AC-029: each of the 4 streams' own PR/commit set carries its own
  `CHANGELOG.md` `## Unreleased` entry citing its own issue number (#167,
  #176, #166, #179 — four independent entries, never merged into one).
  (REQ-007)
- AC-030: `validate-repository` and the skill-reference count sync stay
  green after each stream; no version-literal edit exists outside
  `scripts/bump-version.sh` for any of the 4 streams. (REQ-007)
- AC-031: for a task whose specification DOES flag an enumerable coverage
  requirement and whose bundle's coverage manifest maps every enumerated
  element, the readiness step's text states explicitly that the check
  passes and execution proceeds to Step 2 / panelist invocation — the
  positive continuation branch, completing REQ-004's branch set alongside
  AC-020 (failure branch) and AC-021 (no-op branch). (REQ-004)
- AC-032: a crafted `## Outputs` row whose path resolves OUTSIDE the
  bundle's own input root (e.g. a `../`-traversal or absolute path
  escaping the root) is rejected fail-closed by the completeness check —
  the out-of-root path is reported as a violation, NO content outside the
  input root is read (observable via a sentinel file outside the root
  remaining unread/unreferenced in the bundle), and NO input digest line
  is printed — operationalizing Security Boundary B1 as its own
  acceptance criterion. (REQ-003)

## Field Definitions

- `feature-scoped` (REQ-001) — a gate-report count restricted to reports
  matching BOTH the word-bounded task id AND the current feature's
  anchored `Feature:` header line, as opposed to a bare task-id scan
  across every feature's reports.
- `feature-slug grammar` (REQ-001, AC-001) — `^[a-z0-9][a-z0-9-]*$`,
  matching every existing `specs/<feature>/` directory name in this
  repository at spec-authoring time (confirmed by direct enumeration);
  stricter than the general `review-context-invocation/v2` manifest
  schema's feature field (`[A-Za-z0-9][A-Za-z0-9._-]*`, allows dots and
  uppercase) — see Assumptions for the scoping note.
- `anchored VERDICT read` (REQ-002) — reading a gate report's blocked
  status from its own `^VERDICT:[[:space:]]*BLOCKED[[:space:]]*$` line
  only, never scanning the report body for the bare word.
- `declared-outputs completeness` (REQ-003) — the check that every
  `| \`path\` | \`hash\` |` row in the implementation report's
  `## Outputs` table has a corresponding, hash-matching artifact in the
  collected panelist-input bundle.
- `pre-panel readiness` (REQ-004) — the deterministic, fail-closed check
  `cross-model-verify/SKILL.md` performs before invoking any panelist,
  when the task's specification flags an enumerable coverage requirement.
- `combined suite` (REQ-001, AC-007) — a single `.tests.sh` file that
  exercises BOTH the `.sh` and `.ps1` target scripts internally (via a
  `pwsh` subprocess call), as opposed to a `.tests.sh`/`.tests.ps1` twin
  pair. `tests/quality-gate-cycle-limit.tests.sh` is a combined suite;
  combined suites register only in `tests/run-all.sh`, never
  `tests/run-all.ps1` (established convention, confirmed by direct
  enumeration of `tests/*.tests.sh` files that internally invoke `pwsh`).
- `human-copy staging` (REQ-001, AC-006, AC-007) — the epic-136 procedure
  (`epic-136-phase2-gates/tasks.md:16-25`, precedent at INV-023): the
  agent stages an edited copy under
  `specs/quality-loop-fixes/human-copy/<repository-relative-target>` plus
  a `MANIFEST.sha256` line (`<sha256>  <path>`) per staged file; it never
  writes the live protected target; a human validates and applies the
  candidate.

## Roles and Permissions

- Agent: authors `check-quality-gate-cycle-limit.{sh,ps1}`,
  `emit-run-record.{sh,ps1}`, `prepare-panelist-input.{sh,ps1}`,
  `cross-model-verify/SKILL.md`, `validate-review-context-set.sh`, and all
  new/changed test fixtures directly — none of these 9 files are in
  `PROTECTED_GATE_SUFFIXES` (INV-021). The agent stages, but never writes
  live, TWO protected-file candidates: `plugins/sdd-ship/skills/ship/SKILL.md`
  (AC-006) and `.github/workflows/test.yml` (AC-007), both under
  `specs/quality-loop-fixes/human-copy/` with a shared `MANIFEST.sha256`.
  Authors each stream's own `CHANGELOG.md` entry.
- Human maintainer: approves the spec and (Phase 2) tasks; validates and
  applies both staged human-copy candidates as pre-merge commits on the
  feature PR branch, turning the corresponding live-file self-checks green
  in the PR's own CI before merge.
- CI: runs all 4 streams' suites on the existing 3-OS matrix once the
  `.github/workflows/test.yml` human-copy candidate is applied; until
  then, the quality-gate-cycle-limit suite's CI coverage is red by design
  (fail-closed, no special case).

## Main Workflows

1. Stream 1 (#167): rewrite `check-quality-gate-cycle-limit.{sh,ps1}`'s
   counting logic to the new 2-required-arg, feature-scoped contract;
   update `ship/SKILL.md` Step 4 + invocation examples (human-copy staged);
   stage the CI-registration line for `tests/quality-gate-cycle-limit.tests.sh`
   (human-copy staged); add the cross-feature-collision regression case;
   CREATE the `CHANGELOG.md` entry citing #167.
   Blockers: None — independent (investigation.md Recommended Next Steps).
2. Stream 2 (#176): rewrite `emit-run-record.{sh,ps1}`'s
   `gate_reports.blocked` computation to the anchored `VERDICT:` read; add
   the same-feature body-text-"BLOCKED" fixture closing the INV-010
   coverage gap; CREATE the `CHANGELOG.md` entry citing #176.
   Blockers: None — independent.
3. Stream 3 (#166): make `prepare-panelist-input.{sh,ps1}`'s collector
   recurse and add the declared-outputs completeness check
   (missing/mismatch/subdirectory cases each their own test); add the
   `cross-model-verify/SKILL.md` pre-panel readiness step; CREATE the
   `CHANGELOG.md` entry citing #166. The bundle-completeness code change
   and the SKILL.md readiness-step change may land together or as two
   sub-workflows within this one stream — Phase 2 task decomposition
   decides the split, not this spec.
   Blockers: None — independent.
4. Stream 4 (#179): append `| tr -d '\r'` to every `jq -r` consumption
   site in `validate-review-context-set.sh`; add the CRLF-shim portable
   fixture test plus the BL-010 tamper non-regression cases; record the
   Windows-CI capability-probe flip as corroborating evidence; CREATE the
   `CHANGELOG.md` entry citing #179.
   Blockers: None — independent.
5. Verification: each stream lands with `validate-repository` and the
   skill-reference count sync green; the quality gate evaluates each
   stream's task(s) with the standard evidence chain. No stream blocks
   another — all 4 are independently shippable (investigation.md
   Recommended Next Steps item 3).

## Edge Cases

- Fail-open vs. fail-closed, precisely distinguished per stream (do not
  confuse them): Stream 2's missing-`VERDICT:` case is the one
  deliberately fail-OPEN outcome in this spec (AC-009, a pre-convention
  legacy report counts as NOT blocked, matching current de-facto
  behavior) — contrast with Stream 3's missing/mismatched declared-output
  case, which is fail-CLOSED (AC-015/AC-016, no digest printed), and
  Stream 4's tampered-ledger case, which stays fail-CLOSED (AC-026,
  non-regression).
- Protected-file carve-out, TWO targets in this spec (unlike
  epic-159-pillar-d's one): `plugins/sdd-ship/skills/ship/SKILL.md`
  (Stream 1 prose) and `.github/workflows/test.yml` (Stream 1 CI
  registration) — both staged under the SAME
  `specs/quality-loop-fixes/human-copy/` tree with one shared
  `MANIFEST.sha256`; every other deliverable in every stream is
  agent-editable, verified directly against `guard_invariants.py:4,18`
  (INV-021).
- `run-all.ps1` combined-suite exclusion (AC-007) is itself observed,
  shared, git-tracked state — re-verify at implementation time that the
  convention (combined suites absent from `run-all.ps1`) still holds
  before relying on it, per Assumptions.
- Cross-host: Streams 1-3 need `.sh`/`.ps1` behavioral parity (bash 3.2
  `set -u` empty-array safety; PowerShell explicit `exit`, ASCII-only
  `.ps1` where existing files already are). Stream 4 is `.sh`-only by
  design (INV-019) — `validate-review-context-set.ps1` parses JSON via
  `ConvertFrom-Json`, never `jq`, so it is structurally not subject to the
  defect this stream fixes.
- Stream 3's declared-outputs check must not become a path-traversal
  vector: a crafted `## Outputs` row pointing outside the bundle's own
  input root must not cause the completeness check to read outside the
  declared bundle root (security-spec.md STRIDE).

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: declared-outputs table (implementation report, agent-authored) vs. panelist-input bundle root | Stream 3's completeness check treats the `## Outputs` table as input to a path-containment check, not a trusted read target list — a declared path resolving outside the bundle's own input root must be rejected, never read (security-spec.md) | internal repository content only | none identified |
| B2: identity-ledger record-hash recomputation vs. `jq` runtime byte behavior | Stream 4's `tr -d '\r'` normalization is applied to `jq -r` OUTPUT only, never to the ledger's own persisted JSON content — a genuinely tampered record must still fail (AC-026) | internal repository content only | none identified |
| B3: protected `ship/SKILL.md` / `.github/workflows/test.yml` vs. agent-direct edits | both staged under `specs/quality-loop-fixes/human-copy/` with `MANIFEST.sha256`; only a human applies either (AC-006, AC-007) | internal source only | none identified |
| B4: fixture world vs. real repository/network state | every new test fixture (cross-feature collision, body-text-BLOCKED, declared-outputs gap cases, CRLF `jq` shim) is mktemp-scoped; no suite in this feature makes a live network call or drives the real identity ledger outside a fixture copy | synthetic fixtures only | none identified |

Details: [Security specification](security-spec.md#trust-boundaries).

## Assumptions

- OQ-1's finding (`validate-review-context-set.sh` is absent from
  `PROTECTED_GATE_SUFFIXES`/`PHASE2_HUMAN_COPY_TARGETS`, INV-020..022)
  holds at spec-authoring time. This is shared, git-tracked state a
  sibling branch could change before Stream 4 implements — RE-VERIFY
  directly against `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4,18`
  at implementation time, not against this assumption alone (WFI-013
  discipline). If the list has been extended to include this file by
  then, Stream 4 must switch to human-copy staging before making any
  edit.
- The `run-all.ps1` combined-suite exclusion convention (AC-007,
  confirmed against `tests/second-approval-mask.tests.sh`,
  `tests/review-agent-isolation.tests.sh`, and
  `tests/review-contract-foundation-parity.tests.sh` at spec-authoring
  time) remains in force. RE-VERIFY by re-running the same enumeration
  (`grep -l 'PWSH=\|command -v pwsh' tests/*.tests.sh` cross-checked
  against `tests/run-all.ps1`'s own contents) at implementation time
  before deciding not to add an entry there (WFI-013 discipline).
- `tests/run-all.sh` already lists `tests/quality-gate-cycle-limit.tests.sh`
  (INV-005) and `.github/workflows/test.yml` does not yet reference it
  (INV-005, INV-025) at spec-authoring time. A concurrent session may
  have already registered the suite in either place — RE-VERIFY both
  facts directly before staging the human-copy candidate (WFI-013
  discipline; OQ-5).
- The identity ledger's tail (`reports/review-context/identity-ledger.json`,
  `sequence: 319`, `record_sha256: 1a4bfebc...aa441`, INV-024) is current
  at spec-authoring time. Any Stream-4 fixture or regression test that
  reserves a REAL new record (as opposed to a fixture-copy ledger) must
  re-read the actual tail at implementation time, not assume `sequence
  320` is still free (WFI-013 discipline) — in practice, Stream 4's own
  test fixtures should use a fixture-scoped ledger copy, never
  `--reserve` against the real ledger, avoiding this risk entirely.
- `emit-run-record.sh:125`'s `^Feature:[[:space:]]*${feature_re}[[:space:]]*$`
  anchor pattern (already landed, INV-007) remains the convention Stream 1
  and Stream 2 both reuse verbatim; if a future edit changes that anchor's
  exact form, both streams' new/changed code must follow the landed form,
  not this spec's quoted snapshot.

## Open Questions

- OQ-1 — RESOLVED (direct edit): the machine-enforced suffix list
  (INV-020/021/022) is the authority; `validate-review-context-set.sh` is
  NOT in `PROTECTED_GATE_SUFFIXES` or `PHASE2_HUMAN_COPY_TARGETS`, so
  Stream 4 proceeds as a normal, direct edit. Issue #179's "protected gate
  script" framing is recorded as an inaccuracy (INV-022). Per WFI-013
  discipline, Assumptions above requires re-verification of this fact at
  Stream-4 implementation time, since it is shared, git-tracked state a
  sibling branch could change. Non-goal: extending guard protection to
  this file is out of scope for this spec; it may be proposed later as
  its own WFI.
- OQ-2 — RESOLVED (yes): Stream 1 updates `ship/SKILL.md`'s Step 4 prose
  and both invocation examples via the human-copy procedure (INV-023
  precedent) — staged at
  `specs/quality-loop-fixes/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`
  with a `MANIFEST.sha256` entry (`<sha256>  <path>`); a human applies it;
  agent commits never touch the live file (AC-006).
- OQ-3 — RESOLVED (grep-both): the new CLI contract is
  `check-quality-gate-cycle-limit.(sh|ps1) <task-id> <feature> [reports-dir]`,
  feature a REQUIRED second positional; missing/malformed feature is a
  usage error, exit 2 (AC-001), grammar `[a-z0-9][a-z0-9-]*` (Field
  Definitions). A report counts only if it matches BOTH the word-bounded
  task id AND an anchored `^Feature:[[:space:]]*<feature>[[:space:]]*$`
  line (AC-002). The directory-move option is explicitly rejected
  (Non-goals; blast radius ~121 files). Breaking-CLI note: the only
  documented caller is the `ship` skill (updated in this same feature via
  AC-006) plus the test suite (updated via AC-005/AC-007) — no other
  caller of this script exists in the repository.
- OQ-4 — RESOLVED (anchored VERDICT only; missing VERDICT → not counted):
  blocked = count of reports matching
  `^VERDICT:[[:space:]]*BLOCKED[[:space:]]*$` (AC-008). The one legacy
  report with no `VERDICT:` line at all is intentionally uncounted
  (AC-009), documented rather than treated as an error.
- OQ-5 — RESOLVED (in scope): `tests/quality-gate-cycle-limit.tests.sh`
  keeps its existing `tests/run-all.sh` registration; it is explicitly NOT
  added to `tests/run-all.ps1` per the combined-suite convention finding
  (AC-007, Field Definitions). A CI step IS registered — staged via
  human-copy (`.github/workflows/test.yml` is R-10 protected) alongside
  the `ship/SKILL.md` candidate under the same
  `specs/quality-loop-fixes/human-copy/` tree. Carries a WFI-013-style
  re-verification instruction (Assumptions) for both the run-all.sh
  presence and the test.yml absence, since a concurrent session may have
  already registered the suite.
- OQ-6 — RESOLVED (cite issue #179 directly): no new WFI/RT is filed;
  Main Workflows and this requirements.md cite `#179` directly as the
  Source Issue for Stream 4, matching the only existing tracking artifact
  (`tests/lib/loop-driver.sh:460-481`'s inline comment/`SKIP` reason,
  INV-018) rather than requiring the other 3 streams' WFI/RT-approval
  convention retroactively.

## Risks

- Medium: Stream 1's new 2-required-arg CLI contract is a breaking change
  to `check-quality-gate-cycle-limit.{sh,ps1}`'s invocation shape.
  Mitigation: the only documented caller (`ship/SKILL.md`) is updated in
  the SAME feature (AC-006), and the human-copy staging for that file
  means a reviewer explicitly sees and applies both the script change and
  the prose change together, closing the window where one lands without
  the other.
- Medium: Stream 2's coverage gap (INV-010) means the existing test suite
  could pass while the actual WFI-010 regression remains unfixed if the
  new fixture (AC-011) is omitted or miswritten. Mitigation: AC-011 is an
  explicit, separately-tracked acceptance criterion, not folded silently
  into AC-008's positive case.
- Medium: Stream 3's declared-outputs completeness check, if implemented
  naively, could introduce a path-traversal read outside the bundle root
  from a crafted `## Outputs` table entry. Mitigation: security-spec.md's
  STRIDE analysis and AC-014's explicit reuse of the EXISTING, already
  path-validated parser shape (`validate-review-context-set.sh:63-74`)
  rather than a new, unvetted parser.
- Low-Medium: `.sh`/`.ps1` parity drift on Streams 1-3 (bash 3.2
  empty-array/`set -u` traps, INV-026) could pass macOS/Linux CI locally
  but fail Windows CI, or vice versa. Mitigation: follow the `install.sh`
  bash-3.2 guard idiom and keep explicit `exit N` in every `.ps1` file
  touched (REQ-006, AC-028).
- Low: this spec's TWO protected-file carve-outs (`ship/SKILL.md` and
  `.github/workflows/test.yml`, both staged under one human-copy tree)
  double the surface a human must review and apply before either turns
  green in CI, compared to epic-159-pillar-d's single carve-out.
  Mitigation: both candidates share one `MANIFEST.sha256`, so the human
  applies both in one pass rather than two separate reviews.
