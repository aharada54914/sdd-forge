# Tasks: epic-159-pillar-d

Task-Review-Status: Passed

Source: Issues #156 (D1 — capability refresh process step), #157 (D2 —
weekly freshness-check automation), #158 (D3 — v2 registry
current-generation data) under epic #159 (Pillar D) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Protected Files

ONE protected-file touch point, owned by T-003 (unlike epic-159-pillar-b's
"None"): `.github/workflows/test.yml` IS in `_PROTECTED_GATE_SUFFIXES`
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`; source
of truth `plugins/sdd-quality-loop/references/guard-invariants.json`,
added by commit `2b8a52f` — design.md Protected-File Statement). T-003
therefore stages its `tests/model-freshness-check.tests` registration
candidate under `specs/epic-159-pillar-d/human-copy/.github/workflows/test.yml`
with a sibling `MANIFEST.sha256` (epic-136 Human-Copy Procedure,
`epic-136-phase2-gates/tasks.md:16-25`, followed verbatim) and NEVER writes
the live protected target; the human maintainer applies the staged
candidate as a commit on the feature PR branch BEFORE merge (AC-011).
Every other deliverable in all three tasks — including
`.github/workflows/model-freshness-check.yml` (a DIFFERENT file from
`test.yml`), `.github/scripts/check-model-freshness.sh`,
`tests/model-freshness-check.tests.sh`/`.ps1`, `tests/run-all.sh`/`.ps1`,
`docs/contributor/workflow-detail.md`, `docs/agent-capability-matrix.md`,
`contracts/agent-model-capabilities.v2.json`, and `CHANGELOG.md` — is
verified absent from `_PROTECTED_GATE_SUFFIXES` and agent-editable
(design.md Protected-File Statement).

## Global Constraints

- Each task lands in TWO sequential commits (epic-159-pillar-b's accepted
  two-commit convention, adapted per task): commit A = the substantive
  implementation; commit B = documentation (the task's own `CHANGELOG.md`
  `## Unreleased` entry + doc-surface verification). Commit A lands before
  commit B within the same task. Per task: T-001 commit A = the
  `docs/contributor/workflow-detail.md` + `docs/agent-capability-matrix.md`
  edits (with the `tests/agent-model-routing.tests.sh` re-run recorded);
  T-002 commit A = the `contracts/agent-model-capabilities.v2.json` data
  edit + the confirmation-date/reference-URL record (+ both existing-suite
  re-runs recorded); T-003 commit A = workflow + script + suite twin +
  `tests/run-all.sh`/`.ps1` registration + the human-copy staging
  (candidate + `MANIFEST.sha256`). T-003 additionally has a THIRD,
  HUMAN-authored commit — the human-copy application onto the same feature
  PR branch before merge (AC-011); the PR's CI is expected red on TEST-009's
  live-file self-check until that human commit lands (designed fail-closed
  state, no staged-candidate fallback — requirements.md Edge Cases,
  design.md Deployment / CI Plan).
- `CHANGELOG.md`'s `## Unreleased` section: THREE independent entries, one
  per task citing its own issue (#156 by T-001, #158 by T-002, #157 by
  T-003) — no create-then-append serialization across tasks (unlike
  epic-159-pillar-b's single shared-issue entry; requirements.md REQ-005,
  design.md Global Constraints).
- Shared registration files (`tests/run-all.sh`/`.ps1`,
  `.github/workflows/test.yml`): only T-003 adds a suite in this spec, so
  no cross-task registration collision or serialization is needed
  (design.md Global Constraints).
- External Blocker (Main Workflows): T-002 and T-003 each carry an
  External Blocker — Pillar C's C1 (#149,
  `contracts/agent-model-capabilities.v2.json`) landing on `main`. This is
  a precondition on task START: neither task may enter `In Progress`
  before the landing is RE-VERIFIED at that task's actual start time
  (never assumed from this spec's investigation-time snapshot). If C1's
  landed schema differs from issue #149's description, re-verify against
  the landed file before implementing (requirements.md Assumptions).
- Stable title markers are pinned literals shared across tasks
  (requirements.md Field Definitions): `[model-freshness-divergence]`
  (divergence reports — used identically by T-001's manual-filing checklist
  text, AC-002, and T-003's automated dedup matching, AC-007) and
  `[model-freshness-fetch-unavailable]` (T-003's fail-soft tracking
  issue, AC-006). T-003 is blocked on T-001 partly so the two surfaces
  cite ONE canonical source list and ONE marker literal, never two
  divergent copies.
- CI-resilience constraints apply to the one new suite pair
  (`tests/model-freshness-check.tests.sh`/`.ps1`; requirements.md Edge
  Cases, design.md Constraint Compliance): bash-3.2 `set -u` empty-array
  safety; `pwd -P` normalization of every directly-created mktemp root
  immediately after creation; no jq consumption (non-use declaration IS
  the compliance); no real-validator invocation (non-use declaration).
- Fixture isolation (security-spec.md B4): all fixtures are synthetic and
  mktemp-scoped; the suite drives the real `check-model-freshness.sh`
  read-only through injectable fixture source files and a PATH-prepended
  stubbed `gh` wrapper — never a live network call, never the real `gh`
  CLI, never a write to a real repo path, never an approval string.
- Version bumps only via `scripts/bump-version.sh`; no version-literal
  edit anywhere in any task (REQ-005/AC-019, carried forward from
  `specs/epic-159-pillar-a/requirements.md:164-173` REQ-006's rule).
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Add the capability-refresh process step and matrix confirmation columns

Source Issue: https://github.com/aharada54914/sdd-forge/issues/156

Approval: Approved

Status: In Progress

Risk: low

Risk Rationale: Documentation-only change (requirements.md REQ-001; Main
Workflows item 1: "independent, low-risk, docs-only", INV-002): a
checklist-style process step inside `docs/contributor/workflow-detail.md`'s
existing WFI lifecycle prose plus two trailing columns appended to
`docs/agent-capability-matrix.md`'s Provider Tier Mapping table. No
control-flow, data, or security impact — per
`plugins/sdd-quality-loop/references/risk-classification-policy.md`,
cosmetic/non-behavioral docs classify `low`. The one behavioral adjacency
— `tests/agent-model-routing.tests.sh`'s `assert_literal` fixed-string
checks against that exact table — is prefix-compatible by design-time
analysis (design.md API/Contract Plan Compatibility proof) AND mechanically
re-verified by re-running that unedited suite after the edit
(AC-003/TEST-003), so the tier does not rest on the analysis alone.

Required Workflow: test-after

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-004 (share — AC-015), REQ-005 (share — AC-018/
AC-019, this task's own #156 leg)

Depends On: none

Planned Files:
- `docs/contributor/workflow-detail.md` (existing, agent-editable —
  capability-refresh step inserted in the WFI lifecycle section §5 at the
  insertion point design.md API/Contract Plan specifies, including the
  canonical source list verbatim, the four check items, the D2
  connection/manual fallback, and the `[model-freshness-divergence]`
  marker literal stated verbatim)
- `docs/agent-capability-matrix.md` (existing, agent-editable — trailing
  "最終確認日"/"参照ソース" columns appended to the Provider Tier Mapping
  header and all six data rows)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #156)
- `README.md`/`USERGUIDE.md`/`docs/workflow-guide.md`/
  `docs/skill-reference.md`/`PLUGIN-CONTRACTS.md`/`docs/troubleshooting.md`/
  `docs/contributor/*` (conditional — verify for genuine references,
  verify-and-leave-unchanged expected; REQ-005)

Data Migration: none

Breaking API: no; prose and trailing-column additions only. No existing
cell content, script, gate, or artifact format changes; the
`assert_literal` prefix guarantee keeps `tests/agent-model-routing.tests.sh`
green unedited (AC-003).

Rollback: reviewed revert of this task's two commits (together); docs-only,
nothing protected, no human-copy step in the rollback path. Reverting
restores today's WFI lifecycle section and Provider Tier Mapping table
exactly (infra-spec.md Rollback).

### Goal

Add the "capability refresh" step to `docs/contributor/workflow-detail.md`'s
WFI lifecycle section — canonical source list verbatim (Anthropic official
docs (models overview) / Anthropic blog; OpenAI developers docs (Codex) /
OpenAI blog; release notes for Claude Code / Codex CLI / Copilot CLI), the
four check items, the D2 automated-flow connection with the manual-issue
fallback carrying the `[model-freshness-divergence]` title marker stated
verbatim, and the `Mechanism: model-routing` checklist reminder — and
append the 最終確認日/参照ソース trailing columns to
`docs/agent-capability-matrix.md`'s Provider Tier Mapping table, keeping
`tests/agent-model-routing.tests.sh` green unmodified.

### Must Read

- `specs/epic-159-pillar-d/requirements.md`
- `specs/epic-159-pillar-d/design.md`
- `specs/epic-159-pillar-d/acceptance-tests.md`
- `specs/epic-159-pillar-d/investigation.md`
- `specs/epic-159-pillar-d/security-spec.md`
- `specs/epic-159-pillar-d/infra-spec.md`
- `docs/contributor/workflow-detail.md:469-546` (the WFI lifecycle section
  this task extends; INV-001)
- `docs/agent-capability-matrix.md:127-159` (the Provider Tier Mapping /
  Role Floors tables; INV-001)
- `tests/agent-model-routing.tests.sh:79-97` (the `assert_literal`
  fixed-string checks the trailing-column append must not break — re-verify
  they are still `grep -F` substring matches before editing, design.md
  Assumptions)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`

### Scope

Commit A (implementation — the two documentation edits):

- Insert the capability-refresh step at the design.md API/Contract Plan
  insertion point (between the existing Draft step and the human-approval
  step), with the exact content elements AC-001/AC-002/AC-004 name —
  including the `[model-freshness-divergence]` marker literal verbatim and
  the requirement that a manually-filed issue's title carry it.
- Append the two trailing columns to the Provider Tier Mapping header and
  all six data rows; change no existing cell content.
- Re-run `tests/agent-model-routing.tests.sh` (unedited) and record it
  green (AC-003's mechanical proof).

Commit B (documentation — CHANGELOG + doc-surface verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #156.
- Verify the applicable doc surfaces (REQ-005 list) and edit only where a
  genuine reference exists (verify-and-leave-unchanged expected);
  re-run `tests/validate-repository.sh` and the skill-reference count sync
  and confirm both green (AC-019).

### Done When

- [ ] TEST-001 confirms the WFI lifecycle section (§5) contains the
  capability-refresh step naming the canonical source list verbatim
  (AC-001).
- [ ] TEST-002 confirms the same step lists the four check items, the D2
  automated-flow connection / manual fallback, and states the
  `[model-freshness-divergence]` marker string verbatim with the
  manual-issue-title requirement (AC-002).
- [ ] TEST-003 confirms the Provider Tier Mapping table gains both trailing
  columns on all six rows AND `tests/agent-model-routing.tests.sh`
  (unedited) re-runs green after the edit (AC-003).
- [ ] TEST-004 confirms the explicit checklist reminder tied to
  `Mechanism: model-routing` WFIs referencing the capability-refresh step
  (AC-004).
- [ ] TEST-015 confirms the new prose is a single host-neutral block with
  no host-specific conditional branch (AC-015).
- [ ] TEST-018's #156 leg: `CHANGELOG.md` `## Unreleased` gains this
  task's OWN entry citing #156; applicable doc surfaces verified with
  edits only where a genuine reference exists (AC-018 share).
- [ ] TEST-019's #156 leg: `validate-repository` and the skill-reference
  count sync are green after both commits; no version-literal edit exists
  outside `scripts/bump-version.sh` (AC-019 share).
- [ ] Test-after evidence (low-risk workflow) is recorded in the
  implementation report: the document-conformance checks (TEST-001/002/
  004/015 grep-level inspection) and the TEST-003 suite re-run log, both
  captured after the edits land. An independent quality-gate verdict
  records PASS for this task.

### Out of Scope

- Any new template artifact (e.g. a standalone capability-refresh
  checklist file) — the lifecycle-prose placement is the decided
  resolution (requirements.md Non-goals, design.md Design Decisions).
- Editing `tests/agent-model-routing.tests.sh` (re-run only, never edited).
- Anything under `.github/` or `contracts/` (T-002/T-003 surfaces).
- CI automation of any kind (REQ-001 is manual-cadence documentation;
  OQ-005 resolution).

### Blockers

None

---

## T-002 Populate the v2 registry with current-generation model data

Source Issue: https://github.com/aharada54914/sdd-forge/issues/158

Approval: Approved

Status: Planned

Risk: medium

Risk Rationale: This task mutates data in a consumed contract file
(`contracts/agent-model-capabilities.v2.json`), so it is evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. medium (not low) because registry data is
observable behavior for every v2-registry consumer — a wrong
`supported_efforts` value silently misroutes model/effort decisions.
medium (not high) on three grounds: (1) the edit is DATA-ONLY within the
schema Pillar C's C1 defines — no schema shape, script, gate, or release
surface changes (design.md Data Plan; the v1 registry stays frozen
byte-for-byte, AC-013's hash proof); (2) verification is external and
mechanical — Pillar C's own parity suite
(`tests/agent-capabilities-v2.tests.sh`/`.ps1`) and the existing
`tests/agent-model-routing.tests.sh` are re-run unedited and recorded
green (AC-014), not self-certified; (3) no sensitive surface in the policy
sense is touched (no auth, release path, enforcement chain, or data
migration — the file is internal configuration data with a reviewed-revert
rollback). Per policy: normal observable-behavior change without a
sensitive surface → medium → acceptance-first.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-003, REQ-004 (share — AC-017), REQ-005 (share — AC-018/
AC-019, this task's own #158 leg)

Depends On: none (in-spec; see Blockers for the external precondition)

Planned Files:
- `contracts/agent-model-capabilities.v2.json` (existing once C1 lands,
  agent-editable — `models[]` entries updated to current-generation
  Anthropic (Claude 5 family alias policy) and OpenAI
  (`gpt-5.4`/`5.5`/`5.6` family) data with accurate `supported_efforts`
  and BOTH hosts' `effort_control` paths per entry)
- confirmation-date/reference-URL record (adjacent comment or sibling doc
  section — concrete placement is a task-time decision per design.md
  API/Contract Plan, e.g. a sibling `.md` note or `PLUGIN-CONTRACTS.md`
  addendum)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #158)
- applicable doc surfaces (conditional — verify-and-leave-unchanged
  expected; REQ-005)

Data Migration: none — data population WITHIN C1's already-defined schema;
no consumer cutover; v1 stays frozen so any remaining v1 consumer is
unaffected (design.md Data Plan).

Breaking API: no; data values only, schema shape untouched (schema is
C1's ownership). Both existing suites must stay green unedited (AC-014).

Rollback: reviewed revert of this task's two commits (together); restores
C1's bootstrap ("may start with v1-equivalent content") state. v1 was
never touched, so no consumer-facing rollback risk exists
(infra-spec.md Rollback).

### Goal

Once Pillar C's C1 (#149) has landed `contracts/agent-model-capabilities.v2.json`
on `main` (re-verified at task start), update its `models[]` entries to
current-generation Anthropic and OpenAI data with accurate
`supported_efforts` per model and BOTH hosts' `effort_control` paths
populated per entry, record the confirmation date and reference URLs
adjacent to the file, prove the v1 registry byte-identical, and re-run
both existing suites green.

### Must Read

- `specs/epic-159-pillar-d/requirements.md`
- `specs/epic-159-pillar-d/design.md`
- `specs/epic-159-pillar-d/acceptance-tests.md`
- `specs/epic-159-pillar-d/investigation.md`
- `specs/epic-159-pillar-d/security-spec.md`
- `specs/epic-159-pillar-d/infra-spec.md`
- `contracts/agent-model-capabilities.v2.json` AS LANDED by C1 (re-verify
  the actual schema shape against issue #149's description before
  editing — requirements.md Assumptions; never implement from this spec's
  description alone)
- `contracts/agent-model-capabilities.json` (v1 — frozen; capture its
  pre-task hash for AC-013)
- `tests/agent-capabilities-v2.tests.sh`/`.ps1` (Pillar C's parity suite,
  re-run only)
- `tests/agent-model-routing.tests.sh` (re-run only)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`

### Scope

Commit A (implementation — registry data + confirmation record):

- Record the v1 registry's pre-task hash (AC-013 baseline) and the
  pre-edit v2 `models[]` state (acceptance-first red-side context: C1's
  intentionally-permissive bootstrap content).
- Update `models[]` to current-generation entries — per model: `name`,
  `canonical_tier`, `supported_efforts`, `default_effort`, and BOTH the
  Claude Code (plugin/frontmatter) and Codex (CLI-flag) `effort_control`
  paths (AC-012, AC-017).
- Record the confirmation date + reference URL per vendor family in the
  decided adjacent placement.
- Re-run `tests/agent-capabilities-v2.tests.sh`/`.ps1` and
  `tests/agent-model-routing.tests.sh` (all unedited) and record green
  (AC-014); re-compare the v1 hash (AC-013).

Commit B (documentation — CHANGELOG + doc-surface verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #158.
- Verify the applicable doc surfaces (REQ-005 list; edits only where a
  genuine reference exists — `docs/agent-capability-matrix.md` gets its
  confirmation-date column VALUES only if T-001 has landed and a genuine
  reference exists); re-run `tests/validate-repository.sh` and the
  skill-reference count sync, confirm green (AC-019).

### Done When

- [ ] TEST-012 confirms the v2 `models[]` entries match the
  current-generation Anthropic/OpenAI families with per-model
  `supported_efforts`, and the confirmation date + reference URL are
  present in the adjacent record (AC-012).
- [ ] TEST-013 proves `contracts/agent-model-capabilities.json` (v1) is
  byte-for-byte identical to its pre-task content via hash comparison
  (AC-013).
- [ ] TEST-014 records `tests/agent-capabilities-v2.tests.sh`/`.ps1` and
  `tests/agent-model-routing.tests.sh` (both unedited) exiting 0 after
  the data update (AC-014).
- [ ] TEST-017's review-time check confirms each entry populates both the
  Claude Code and Codex `effort_control` paths per C1's LANDED v2 schema,
  recorded in the implementation report (AC-017).
- [ ] TEST-018's #158 leg: `CHANGELOG.md` `## Unreleased` gains this
  task's OWN entry citing #158; doc surfaces verified (AC-018 share).
- [ ] TEST-019's #158 leg: `validate-repository` and the skill-reference
  count sync green; no version-literal edit (AC-019 share).
- [ ] Acceptance-first evidence is recorded in the implementation report:
  the acceptance checks (TEST-012's expected current-generation content,
  TEST-013's hash pair, TEST-014's suite list) are written down BEFORE the
  data edit, with the pre-edit registry state captured as the red-side
  context (C1 bootstrap data failing TEST-012's expectations), then the
  post-edit green runs. An independent quality-gate verdict records PASS
  for this task.

### Out of Scope

- Creating or reshaping the v2 schema (C1/#149's ownership —
  requirements.md Non-goals).
- Any edit to the v1 registry (frozen, AC-013).
- Authoring new test suites or extending
  `tests/agent-model-routing.tests.sh`/`tests/agent-capabilities-v2.tests.sh`
  (verification-only obligation — requirements.md Non-goals).
- `check-model-freshness.sh` writing to `contracts/` (T-003's boundary,
  Security Boundaries B2 — registry corrections remain this task's
  human-reviewed shape).

### Blockers

None

(External precondition, not an in-spec blocker: Pillar C's T-001 (#149,
C1) landed on `main`, RE-VERIFIED at this task's actual start — Main
Workflows item 2; this task cannot enter `In Progress` before that
verification.)

---

## T-003 Add the weekly model-freshness-check automation

Source Issue: https://github.com/aharada54914/sdd-forge/issues/157

Approval: Approved

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. high because this task touches sensitive surfaces in the
policy's sense, on three grounds: (1) it creates a scheduled CI workflow
holding an elevated write scope (`issues: write`) that processes
UNTRUSTED external content — fetched vendor pages cross trust boundary B1
into publicly-posted issue bodies, where a silent sanitization defect
publishes adversarial content (AC-021) and a silently-swallowed genuine
divergence defeats the feature's entire purpose (AC-007;
security-spec.md STRIDE B1/B2 rows); (2) it carries this spec's ONE
protected enforcement-chain file touch (`.github/workflows/test.yml` via
the epic-136 human-copy procedure, AC-011, Security Boundaries B3); (3)
its fail-soft/fail-closed split (fetch outage → exit 0 vs. genuine drift
→ no-bypass filing) is exactly the kind of branch logic where a silent
miswiring causes material harm without failing any build. Per the policy
and `check-risk.(sh|ps1)`'s deterministic enforcement, `high` REQUIRES
`Required Workflow: tdd` (Red→Green) — the fixture suite
(TEST-005..007/009/010/016/020/021) is authored first and run RED against
the pre-landing tree (no workflow, no script, no suite registration to
find), then GREEN after commit A.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-002, REQ-004 (share — AC-016), REQ-005 (share — AC-018/
AC-019, this task's own #157 leg)

Depends On: T-001 (content dependency — this task's filed-issue body cites
the SAME canonical source list T-001 documents, and the D1 checklist and
this task's dedup logic must share the identical
`[model-freshness-divergence]` marker literal; Global Constraints)

Planned Files:
- `.github/workflows/model-freshness-check.yml` (new, agent-editable —
  weekly `cron: "0 3 * * 1"` + `workflow_dispatch`, `ubuntu-latest`,
  `contents: read`/`issues: write` only, design.md API/Contract Plan)
- `.github/scripts/check-model-freshness.sh` (new, agent-editable,
  bash-only by recorded design decision — REQ-004/AC-016;
  `fetch_source_or_unavailable` / `compute_divergence` /
  `file_or_dedupe_issue` / `main` structure per design.md)
- `tests/model-freshness-check.tests.sh` (new, agent-editable)
- `tests/model-freshness-check.tests.ps1` (new, agent-editable — native
  reimplementation, no bash shell-out; both lanes unconditional)
- `tests/run-all.sh` / `tests/run-all.ps1` (existing, agent-editable —
  this suite's registration, written directly)
- `specs/epic-159-pillar-d/human-copy/.github/workflows/test.yml` +
  `specs/epic-159-pillar-d/human-copy/MANIFEST.sha256` (new — STAGED
  candidate only; the live protected target is never written by the agent)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #157)
- applicable doc surfaces (conditional — verify-and-leave-unchanged
  expected; REQ-005)

Data Migration: none

Breaking API: no; a new standalone workflow + script + suite. No existing
workflow, script, gate, or artifact format changes;
`self-improvement.yml` is never edited (requirements.md Non-goals) and
`test.yml`'s only change is the staged registration line a human applies.

Rollback: reviewed revert of this task's commits PLUS a second human-copy
application reverting `.github/workflows/test.yml`'s registration line
(staging a candidate with the line removed, human re-applies) — the same
human-in-the-loop mechanism that added it, never a direct agent revert of
the live protected file (infra-spec.md Rollback).

### Goal

Add the standalone, fully-deterministic weekly freshness-check:
`.github/workflows/model-freshness-check.yml` (weekly cron + manual
dispatch, minimal permissions) invoking
`.github/scripts/check-model-freshness.sh` — best-effort fetch of both
vendors' official sources; fail-soft "取得不能" comment + exit 0 on ANY
fetch failure (never a red CI run, never a partial-data diff);
allowlist-validated divergence detection against the v2 registry; dedup
issue filing under the `[model-freshness-divergence]` marker with
no-bypass on genuine drift; zero side effects on the no-diff branch —
locked by the `tests/model-freshness-check.tests.sh`/`.ps1` twin pair
driving the real script against injectable fixtures and a stubbed `gh`
wrapper, with the `test.yml` registration staged via the epic-136
human-copy procedure.

### Must Read

- `specs/epic-159-pillar-d/requirements.md`
- `specs/epic-159-pillar-d/design.md`
- `specs/epic-159-pillar-d/acceptance-tests.md`
- `specs/epic-159-pillar-d/investigation.md`
- `specs/epic-159-pillar-d/security-spec.md`
- `specs/epic-159-pillar-d/infra-spec.md`
- `docs/contributor/workflow-detail.md` (T-001's landed capability-refresh
  step — the canonical source list and marker literal this task's issue
  body must cite identically)
- `contracts/agent-model-capabilities.v2.json` AS LANDED by C1 (the diff
  target's actual `models[]` shape — re-verify before implementing)
- `.github/scripts/self-improvement-pr-guard.sh` (TEST-010 greps its
  `.github/workflows/*` case pattern at line 34; read-only precedent for
  the bash-only non-twin decision)
- `.github/workflows/self-improvement.yml` (permission/concurrency
  contrast — never edited; design.md Design Decisions)
- `tests/second-approval-mask.tests.sh:285-289` (the self-registration
  grep-check pattern TEST-009 mirrors)
- `tests/release-loop-gate.tests.sh`/`.ps1` (the text-marker technique and
  native `.ps1` full-parity-port idiom this suite follows)
- `epic-136-phase2-gates/tasks.md:16-25` (the Human-Copy Procedure,
  followed verbatim)
- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`
  (re-verify `.github/workflows/test.yml` is still the only protected
  touch at implementation time — design.md Risks)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

Commit A is a single focused implementation session, deliberately NOT
split: the five stages below execute strictly in order, each yields one
small artifact, and the fixture/stub harness built once in stage (i) is
shared by every script-driving assertion (TEST-006/007/020/021 all drive
the same stubbed-`gh` + fixture-source harness — no per-test
infrastructure). Stage (v) is a mechanical `cp` + SHA-256 hash of one
file, and AC-008 is not code work at all — a single recorded dispatch
execution. Commit A implementation begins only AFTER the stage-(i) RED
evidence is recorded, and at commit-A completion every suite-verifiable
Done-When bundle below must be green (TEST-009's live-file half excepted
per AC-011's designed red window) — independently re-verified by the
quality gate, so a stalled Red, a partial landing, or a skipped bundle
cannot pass.

Commit A (implementation — one focused session, stages in order):

- Stage (i) — TDD RED: author the full suite twin
  `tests/model-freshness-check.tests.sh`/`.ps1` — the shared
  fixture-source + stubbed-`gh` harness plus every assertion (TEST-005
  text-marker; TEST-006 three fetch-failure scenarios — both fail /
  Anthropic-only fails / OpenAI-only fails — each exit 0 + "取得不能"
  comment + zero issue-creates + no partial-data diff; TEST-007
  divergence + dedup second invocation; TEST-009 CI-resilience +
  self-registration; TEST-010 weekly-session-denial grep; TEST-016
  non-twin/twin-pair conformance; TEST-020 no-diff zero-invocation;
  TEST-021 adversarial issue-body allowlist) — and record it failing
  meaningfully against the pre-landing tree. No implementation stage
  starts before this RED recording exists.
- Stage (ii) — GREEN, script: author
  `.github/scripts/check-model-freshness.sh` with the three separable
  functions design.md specifies — fixture-injectable fetch
  (`$<VENDOR>_FIXTURE_SOURCE` env override), pure allowlist-validated
  (`[A-Za-z0-9.\-]`) divergence computation, marker-literal dedup filing
  (`[model-freshness-divergence]` / `[model-freshness-fetch-unavailable]`),
  fail-soft exits, no `contracts/` write path, no bypass conditional on
  the divergence branch — until the script-driving assertions
  (TEST-006/007/020/021) pass.
- Stage (iii) — GREEN, workflow: author
  `.github/workflows/model-freshness-check.yml` per the design.md
  planned shape (schedule + dispatch, `ubuntu-latest`,
  `contents: read`/`issues: write` only, own concurrency group, pinned
  checkout SHA, `timeout-minutes: 10`) — until TEST-005's text-markers
  and TEST-010's denial grep pass.
- Stage (iv) — registration: add the suite to `tests/run-all.sh`/`.ps1`
  directly (the agent-editable half of TEST-009's self-registration).
  CI resilience per Global Constraints (pwd -P, set -u array safety, jq
  non-use, validator non-use) is woven through stage (i)'s harness, not
  a separate build step.
- Stage (v) — human-copy staging (mechanical, lightweight): copy the
  `.github/workflows/test.yml` registration candidate to
  `specs/epic-159-pillar-d/human-copy/.github/workflows/test.yml` and
  write `MANIFEST.sha256` — a `cp` + hash step, not new implementation;
  the live protected file is never written.
- AC-008's verification is NOT a code stage: one recorded manual
  `workflow_dispatch` execution against a disposable fixture branch with
  an intentionally stale registry entry, its filed issue captured in the
  implementation report (never CI-repeated).

Commit B (documentation — CHANGELOG + doc-surface verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #157.
- Verify the applicable doc surfaces (REQ-005 list), edit only where a
  genuine reference exists; re-run `tests/validate-repository.sh` and the
  skill-reference count sync, confirm green (AC-019).

Human-copy application (HUMAN-authored commit, after commit A/B, before merge):

- The human maintainer validates target identity + SHA-256 and applies the
  staged candidate as a commit on this feature PR branch (AC-011). Until
  that commit lands, the PR CI is expected RED on TEST-009's live-file
  self-check — the designed fail-closed state; from that commit onward
  the PR's own CI proves the registration landed (green required before
  merge).

### Done When

- [ ] Fixture-driven fail-soft/divergence bundle: TEST-005 proves
  `model-freshness-check.yml` declares the weekly `schedule:` +
  `workflow_dispatch:` triggers, `runs-on: ubuntu-latest`, and a
  `permissions:` block containing only `contents: read` and
  `issues: write` (AC-005); TEST-006 proves all THREE fetch-failure
  scenarios (both-fail, Anthropic-only-fail, OpenAI-only-fail) exit 0
  with a "取得不能" comment call, zero issue-creates, and — in the
  asymmetric scenarios — no divergence computed from the surviving
  vendor's partial data (AC-006); TEST-007 proves a genuine,
  previously-unfiled divergence records an issue-create call labeled
  `workflow-improvement`, and a second invocation against a stubbed
  already-open `[model-freshness-divergence]` issue records zero
  additional creates (AC-007).
- [ ] Branch-completeness bundle: TEST-020 proves the no-diff branch
  (fetch success, registry current) exits 0 with ZERO stubbed-`gh`
  invocations of any kind (AC-020); TEST-021 proves an adversarial
  fixture payload (markdown injection, instruction text, script
  fragments) never reaches the recorded issue body verbatim — only
  allowlist-validated (`[A-Za-z0-9.\-]`) model-ID tokens do (AC-021).
- [ ] Self-consistency bundle: TEST-009 proves the suite's CI-resilience
  conformance (pwd -P / set -u / jq non-use / validator non-use) and the
  self-registration grep-check against `tests/run-all.sh`/`.ps1` and the
  LIVE `.github/workflows/test.yml` — green in the PR's own CI only
  after the human-copy application commit lands; red before it is the
  designed state (AC-009, AC-011); TEST-010 proves
  `self-improvement-pr-guard.sh`'s `.github/workflows/*` pattern still
  matches `.github/workflows/model-freshness-check.yml` (AC-010);
  TEST-016 proves `.github/scripts/check-model-freshness.ps1` does NOT
  exist (recorded non-twin) while BOTH suite twins exist and register in
  `tests/run-all.sh`/`.ps1` (AC-016).
- [ ] Protected-file boundary bundle: TEST-011 proves the staged
  candidate + `MANIFEST.sha256` exist and match, the live `test.yml` is
  unmodified by the agent at staging time, and the human-copy
  application lands as a pre-merge commit on this feature PR branch that
  turns TEST-009's live-file self-check green (AC-011).
- [ ] One-time manual verification: TEST-008's single recorded
  `workflow_dispatch` run against the disposable fixture branch
  demonstrably files an issue, captured in the implementation report —
  never CI-repeated (AC-008).
- [ ] Shared legs bundle: TEST-018's #157 leg — `CHANGELOG.md`
  `## Unreleased` gains this task's OWN entry citing #157 with doc
  surfaces verified, edits only where a genuine reference exists
  (AC-018 share); TEST-019's #157 leg — `validate-repository` and the
  skill-reference count sync green, no version-literal edit outside
  `scripts/bump-version.sh` (AC-019 share).
- [ ] TDD evidence is recorded in the implementation report with Red and
  Green explicitly separated: RED — the authored suite run against the
  pre-landing tree (no workflow to text-mark, no script for the fixtures
  to drive, no registration to self-find) failing meaningfully; GREEN —
  the post-commit-A run of every bundle above passing (TEST-009's
  live-file half green only after the human-copy commit), re-confirmed
  after commit B. An independent quality-gate verdict records PASS for
  this task.

### Out of Scope

- Writing the live `.github/workflows/test.yml` (human-copy only — the
  ONE protected touch).
- `check-model-freshness.sh` writing to `contracts/` or any release
  surface (Security Boundaries B2; Non-goals).
- A `.ps1` twin of `check-model-freshness.sh` itself (recorded non-twin,
  REQ-004/AC-016 — only the test suite is a twin pair).
- Modifying `.github/workflows/self-improvement.yml` or
  `self-improvement-pr-guard.sh` (grepped read-only by TEST-010).
- A precise vendor-page parser (conservative heuristic decided —
  Non-goals; false negatives acceptable, false positives human-triaged).
- Any environment-variable or flag bypass of the genuine-drift filing
  branch (Edge Cases "No-bypass on genuine drift").

### Blockers

T-001

(In-spec rationale: shared canonical-source list + marker literal.
Additional external precondition: Pillar C's T-001 (#149, C1) landed on
`main`, RE-VERIFIED at this task's actual start — Main Workflows item 3;
this task cannot enter `In Progress` before that verification.)
