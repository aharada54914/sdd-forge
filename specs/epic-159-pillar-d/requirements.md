# Requirements: epic-159-pillar-d

Spec-Review-Status: Passed

Source Issues:
- https://github.com/aharada54914/sdd-forge/issues/156 (D1 — capability
  refresh process step)
- https://github.com/aharada54914/sdd-forge/issues/157 (D2 — weekly
  freshness-check automation)
- https://github.com/aharada54914/sdd-forge/issues/158 (D3 — v2 registry
  current-generation data)

Epic: https://github.com/aharada54914/sdd-forge/issues/159 (Pillar D —
model-freshness maintenance process/automation/registry-update)

Investigation: specs/epic-159-pillar-d/investigation.md (INV-001..INV-013,
OQ-001..OQ-005)

## Overview

The available Anthropic/OpenAI models and their capabilities change
frequently, but nothing in this repository currently keeps
`docs/agent-capability-matrix.md` or the model-capabilities registry
current against official sources (investigation.md Final Assessment). Pillar
D closes this gap in three parts that share Category/Mechanism ancestry but
carry different dependency shapes: D1 (#156) adds a manual "capability
refresh" process step to contributor documentation (no dependency,
INV-002); D2 (#157) adds a weekly automated freshness-check workflow that
diffs official model documentation against the v2 registry and files an
issue on drift, fail-soft on fetch failure (INV-009); D3 (#158) populates
the v2 registry with current-generation model data. D2 and D3 both name
Pillar C's C1 (issue #149, `contracts/agent-model-capabilities.v2.json`) as
a declared dependency (INV-003, INV-005), and at spec-authoring time C1 has
not yet landed on `main` — it is mid-pipeline on a sibling branch
(`feature/epic-159-pillar-c`, investigation.md header note). This is
recorded below as an external Blocker on both D2 and D3, not as an
in-repository Depends-On relationship this spec can resolve.

This spec also records one fact investigation.md's own protected-file check
(INV-012) did not surface: `.github/workflows/test.yml` is, as of this
worktree's current HEAD, itself an enforcement-chain protected file
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`,
`protected_gate_suffixes` tuple; source of truth
`plugins/sdd-quality-loop/references/guard-invariants.json`
`protected_gate_suffixes` array — added by commit `2b8a52f` "feat(phase2):
implement epic 136 guard gates through T006", which is NOT an ancestor of
the pillar-b investigation/spec commits INV-012's own precedent examined,
confirmed via `git merge-base --is-ancestor`). INV-012 checked only
`docs/`/`contracts/` paths against the protected list for #156/#158 and did
not check `.github/workflows/test.yml` for #157's CI-registration need.
Because D2 (#157) ships its own `.sh`/`.ps1` test-suite pair (INV-008's
cross-OS mandate applies to it, same as every other new suite in this
repository) and that pair must register in `.github/workflows/test.yml`
alongside `tests/run-all.sh`/`.ps1`, D2's task carries a protected-file
obligation the epic-136 human-copy procedure governs (see design.md
Protected-File Statement) — D1 and D3 do not.

## Target Users

- Contributors performing plugin-improvement work involving model/effort
  routing (D1's audience): they need a documented, referenceable list of
  canonical sources and a concrete check procedure so a capability refresh
  is not ad hoc.
- Maintainers who would otherwise discover registry staleness only by
  accident (D2's audience, investigation.md background: "現に OpenAI エント
  リが 2 世代前"): they need a weekly, fail-soft safety net that files an
  issue rather than silently doing nothing when official sources have moved
  on.
- Any consumer of `contracts/agent-model-capabilities.v2.json` once Pillar C
  ships it (D3's audience): they need current-generation model data with
  its confirmation date and source recorded, not stale placeholder data
  carried over unchanged from C1's "may start with v1-equivalent content"
  allowance (issue #149 body).
- Windows-host and Codex-host contributors/CI (REQ-004's audience): the
  weekly automation is GitHub-Actions-only (a CI concern, not a per-host
  concern) and is recorded as such rather than silently assumed
  cross-host-neutral.

## Problems

- No canonical source list or check procedure exists anywhere in
  `docs/contributor/workflow-detail.md` (INV-001) for verifying model IDs,
  new-model/new-feature availability, effort/tool-support changes, or
  registry divergence — the only relevant existing content is the WFI
  lifecycle section (`docs/contributor/workflow-detail.md:469-546`) and the
  Provider Tier Mapping / Role Floors tables in
  `docs/agent-capability-matrix.md:127-159`, neither of which records a
  confirmation date or source.
- No automated process detects registry staleness (investigation.md
  background). The nearest existing automation,
  `.github/workflows/self-improvement.yml`, is a broad,
  Claude-agent-driven weekly audit (INV-009) that cannot itself extend to
  cover this without also inheriting its own `self-improvement-pr-guard.sh`
  restriction against self-modifying `.github/workflows/*`
  (`self-improvement-pr-guard.sh:34`, INV-004) — meaning any freshness
  automation must land via a normal PR, and (design.md Design Decisions)
  is better kept as its own deterministic, non-LLM workflow than folded
  into that broad session.
- `contracts/agent-model-capabilities.v2.json` does not yet exist
  (INV-013); once Pillar C's C1 creates it, issue #149's own body states it
  "may start with v1-equivalent content" — meaning the registry would ship
  structurally new but still data-stale unless D3 explicitly curates
  current-generation entries.

## Goals

- REQ-001 (T-001, #156; INV-001, INV-002, INV-012, OQ-005): Add a
  "capability refresh" step to `docs/contributor/workflow-detail.md`'s
  existing WFI (Workflow Improvement) lifecycle section
  (`docs/contributor/workflow-detail.md:469-546`) naming the canonical
  source list verbatim from the issue body — Anthropic official docs
  (models overview) / Anthropic blog; OpenAI developers docs (Codex) /
  OpenAI blog; release notes for each CLI (Claude Code / Codex CLI /
  Copilot CLI) — the check items (model ID validity; new model/feature
  availability; effort/tool-support changes; divergence from the v2
  registry), and the connection to D2's automated issue-filing flow (#157)
  as the fallback path when a divergence is found outside a scheduled
  D2 run — any such manually-filed issue MUST carry the same stable title
  marker (Field Definitions) in its title that REQ-002's dedup matching
  uses, and the checklist text states that marker string verbatim so D2's
  weekly run recognizes the manual issue as already filed. Add a
  "最終確認日" (last-confirmed date) and "参照ソース"
  (reference source) trailing column pair to
  `docs/agent-capability-matrix.md`'s Provider Tier Mapping table
  (`docs/agent-capability-matrix.md:127-136`), appended after each row's
  existing last column so `tests/agent-model-routing.tests.sh`'s existing
  `assert_literal` substring checks against that exact table
  (`tests/agent-model-routing.tests.sh:79-86`, fixed-string/`grep -F`
  matching — verified: those checks match a PREFIX of each row, so
  appended trailing columns do not invalidate them) remain green
  unmodified. This is manual-cadence process documentation — no CI
  automation is added by this requirement (OQ-005 resolution).
- REQ-002 (T-003, #157; INV-003, INV-004, INV-006, INV-008, INV-009,
  INV-012, INV-013, OQ-001, OQ-004): A new, standalone
  `.github/workflows/model-freshness-check.yml` (weekly `cron` +
  `workflow_dispatch`, `ubuntu-latest`, minimal `contents: read` /
  `issues: write` permissions) invokes a new
  `.github/scripts/check-model-freshness.sh` that: (a) best-effort fetches
  official Anthropic and OpenAI model-listing sources; (b) on ANY fetch
  failure, posts/updates a dedicated tracking-issue comment stating fetch
  was unavailable and exits 0 — the job never fails CI on an external-source
  outage (INV-009's "取得失敗時は fail ではなく「取得不能」を issue コメン
  ト" requirement, non-negotiable, no bypass — see Constraint Compliance);
  (c) on a successful fetch, diffs the fetched model-ID tokens against
  `contracts/agent-model-capabilities.v2.json`'s `models[].name` entries
  (once Pillar C's C1 creates that file) and, if a divergence is found,
  files a new GitHub issue labeled `workflow-improvement` describing the
  divergence and citing the same canonical-source list REQ-001 documents —
  deduplicated against any already-open issue matching a stable title
  marker (Field Definitions — the same literal marker string REQ-001's
  manual filing path must carry), never creating a duplicate.
  `check-model-freshness.sh` never
  writes to `contracts/` or any other release surface — it only reads the
  registry and creates/comments on issues (Security Boundaries B2) — and
  any issue body it produces embeds only model-ID tokens validated against
  a charset allowlist (`[A-Za-z0-9.\-]`); fetched content never reaches an
  issue body verbatim (Security Boundaries B1, AC-021). A new
  `tests/model-freshness-check.tests.sh`/`.ps1` pair locks the fetch-failure,
  diff-detected, no-diff, and dedup branches against the real script with
  injectable fixture source files (no live network call in CI), each branch
  mapped to its own named acceptance test (AC-009, AC-020).
- REQ-003 (T-002, #158; INV-005, INV-006, INV-008, INV-013, OQ-001, OQ-004):
  Once Pillar C's C1 lands `contracts/agent-model-capabilities.v2.json`
  on `main` (external Blocker, Main Workflows below), update its
  `models[]` entries to current-generation Anthropic (Claude 5 family
  alias policy) and OpenAI (`gpt-5.4`/`5.5`/`5.6` family) data with
  accurate `supported_efforts` per model, and record the confirmation date
  and reference URLs in an adjacent comment or sibling doc section. The v1
  registry (`contracts/agent-model-capabilities.json:1-40`) stays frozen
  and byte-for-byte unchanged. Pillar C's own v1⇔v2 parity suite
  (`tests/agent-capabilities-v2.tests.sh`/`.ps1`, created by C1) and the
  existing `tests/agent-model-routing.tests.sh`
  (`tests/agent-model-routing.tests.sh:32`, currently reads only the v1
  file — unaffected by this requirement, verification-only obligation) must
  both stay green after the data update; this requirement authors no new
  test suite of its own.
- REQ-004 (T-001, T-002, T-003; INV-007): Cross-host requirement across all
  three tasks. D1 is documentation read identically by Claude Code and
  Codex contributors — no host-specific runtime path exists, so no
  degradation applies. D2's automation is GitHub-Actions-only CI, not a
  per-host agent runtime concern; its result (a filed issue) benefits both
  hosts equally. `check-model-freshness.sh` itself is recorded as an
  explicit bash-only, no-`.ps1`-twin design decision (it only ever runs
  inside a GitHub Actions `ubuntu-latest` runner, mirroring the existing,
  already-established non-twin precedent at
  `.github/scripts/self-improvement-pr-guard.sh`, which likewise has no
  `.ps1` counterpart) — its LOCKING test suite
  (`tests/model-freshness-check.tests.sh`/`.ps1`) IS a full twin pair,
  because that suite lives under `tests/` and runs on the 3-OS matrix like
  every other suite there. D3 populates, per model, BOTH host paths C1's v2
  schema defines under `effort_control` (issue #149 body: "host ごと
  flag/frontmatter/none") — the Claude Code plugin/frontmatter path and the
  Codex `.codex-plugin` manifest / `.codex/agents/*.toml` / CLI
  `--model`/`--effort` path — for every current-generation model entry it
  adds.
- REQ-005 (T-001, T-002, T-003; INV-006, INV-011): Each task's PR carries
  its OWN `CHANGELOG.md` `## Unreleased` entry citing its own issue number
  (#156, #157, or #158 respectively — unlike epic-159-pillar-b's single
  shared-issue two-task entry, these are three distinct issues, so no
  create-then-append serialization is needed across tasks); each verifies
  the applicable doc surfaces
  (`README.md`/`USERGUIDE.md`/`docs/workflow-guide.md`/
  `docs/skill-reference.md`/`docs/agent-capability-matrix.md`/
  `PLUGIN-CONTRACTS.md`/`docs/troubleshooting.md`/`docs/contributor/*`) and
  edits only where a genuine reference exists, leaving the rest
  verified-and-unchanged; `validate-repository` and the skill-reference
  count sync stay green; no version-literal edit happens outside
  `scripts/bump-version.sh` (consistent with
  `specs/epic-159-pillar-a/requirements.md:164-173` REQ-006's existing
  rule, carried forward unmodified by every epic-159 pillar spec to date).

## Non-goals

- Implementing Pillar C's C1 (issue #149,
  `contracts/agent-model-capabilities.v2.json` schema creation) — that is a
  separate spec on `feature/epic-159-pillar-c`; this spec only records it
  as an external Blocker (Main Workflows).
- `check-model-freshness.sh` writing directly to
  `contracts/agent-model-capabilities.v2.json` or any other release
  surface. It only reads the registry and creates/comments on GitHub
  issues (Security Boundaries B2) — any registry correction remains a
  human-reviewed, D3-shaped change.
- A precise, complete parser of official model-listing pages. The
  fetch-then-diff heuristic (design.md API/Contract Plan) is deliberately
  conservative: false negatives (a real new model missed) are acceptable
  because D1's manual checklist is the primary defense and D2 is a
  best-effort safety net, not the sole detection path; false positives are
  triaged by a human reading the filed issue, never auto-applied to the
  registry.
- Authoring a `.ps1` twin of `check-model-freshness.sh` itself (REQ-004,
  recorded non-twin degradation) — only its locking test suite is a twin
  pair.
- Extending `tests/agent-model-routing.tests.sh` or
  `tests/agent-capabilities-v2.tests.sh` to add new assertions of their
  own; REQ-003 only requires that both stay green after D3's data update
  (verification-only obligation, not an authoring one).
- Adding a new WFI template artifact (e.g. a standalone
  "capability-refresh checklist" file). REQ-001's "WFI テンプレートのチェ
  ックリスト" Done condition is resolved by extending the WFI lifecycle
  section already inside `docs/contributor/workflow-detail.md` (Design
  Decisions, OQ-005), matching investigation.md INV-001's own two-file
  target-file list rather than introducing a third artifact.
- Modifying `.github/workflows/self-improvement.yml` itself (design.md
  Design Decisions: a new, standalone workflow file is used instead — see
  Problems above).
- tasks.md and traceability.md (Phase 2 artifacts, authored after spec
  approval).

## User Stories

As a contributor doing plugin-improvement work that touches model or effort
routing, I read `docs/contributor/workflow-detail.md`'s WFI lifecycle
section and find a concrete capability-refresh checklist naming exactly
which official sources to check and what "stale" looks like, instead of
guessing. As a maintainer, I get a weekly issue — never a broken CI run —
whenever the registry has drifted from what Anthropic or OpenAI currently
publish, and I get an honest "fetch unavailable" comment instead of silence
when the official sources themselves are unreachable. As a consumer of the
v2 registry once Pillar C ships it, I can trust that its model entries
reflect the current generation, not a stale carry-over from C1's
intentionally-permissive bootstrap content, and I can see when and against
which source each entry was last confirmed.

## Acceptance Criteria

- AC-001: `docs/contributor/workflow-detail.md`'s WFI lifecycle section
  gains a "capability refresh" step naming the canonical source list
  verbatim: Anthropic official docs (models overview) / Anthropic blog;
  OpenAI developers docs (Codex) / OpenAI blog; release notes for Claude
  Code / Codex CLI / Copilot CLI. (REQ-001)
- AC-002: The same step lists concrete check items — model ID validity; new
  model/feature availability; effort/tool-support changes; divergence from
  the v2 registry — and states that a divergence found outside a scheduled
  D2 run is filed as a manual issue or connects to D2's automated flow
  (#157); the step states the stable title marker string
  (`[model-freshness-divergence]`, Field Definitions) verbatim and requires
  any manually-filed issue's title to carry it, so D2's dedup matching
  (AC-007) recognizes the manual issue and never files a duplicate.
  (REQ-001)
- AC-003: `docs/agent-capability-matrix.md`'s Provider Tier Mapping table
  (`docs/agent-capability-matrix.md:127-136`) gains "最終確認日" and "参照
  ソース" as trailing columns appended after each row's existing last
  column, for all six rows; `tests/agent-model-routing.tests.sh` (unedited
  by this feature) stays green, proven by re-running it after the edit.
  (REQ-001)
- AC-004: The WFI lifecycle section (`docs/contributor/workflow-detail.md`
  §5) gains an explicit checklist-style reminder tied to
  `Mechanism: model-routing` WFIs, pointing at the capability-refresh step
  AC-001/AC-002 add — resolving #156's "WFI テンプレートのチェックリスト
  に項目が入る" Done condition without a new template artifact. (REQ-001)
- AC-005: `.github/workflows/model-freshness-check.yml` exists with a
  weekly `schedule:` trigger and a `workflow_dispatch:` trigger, runs on
  `ubuntu-latest`, and declares only `contents: read` and `issues: write`
  permissions (no `pull-requests: write`, unlike `self-improvement.yml` —
  this feature never opens a PR). (REQ-002)
- AC-006: `check-model-freshness.sh`, when either the Anthropic or the
  OpenAI fetch fails, posts or updates a comment on a dedicated tracking
  issue stating "取得不能" (fetch unavailable) and exits 0 — the workflow
  run is not marked failed. (REQ-002)
- AC-007: `check-model-freshness.sh`, when both fetches succeed and a
  divergence against `contracts/agent-model-capabilities.v2.json` is
  detected, creates a new issue labeled `workflow-improvement` describing
  the divergence and citing the canonical source list, OR — if an open
  issue already matches the stable title marker — takes no duplicate
  action. (REQ-002)
- AC-008: A manual `workflow_dispatch` run against a fixture branch whose
  registry carries an intentionally stale entry demonstrably files an
  issue — the integration-level proof the issue's own Done condition
  requires ("レジストリに意図的な古いエントリを置いた検証で起票されるこ
  とを確認"), recorded once in the implementation report rather than
  re-run on every CI pass. (REQ-002)
- AC-009: `tests/model-freshness-check.tests.sh`/`.ps1` locks the
  fetch-failure (AC-006 → TEST-006), diff-detected (AC-007 → TEST-007),
  no-diff (AC-020 → TEST-020), and dedup (AC-007's second-invocation
  negative branch → TEST-007) branches against the real
  `check-model-freshness.sh` using injectable
  fixture source files (no live network call in CI); conforms to the same
  CI-resilience bar this repository's other new `.sh` suites meet
  (`pwd -P` fixture-root normalization, no possibly-empty bash array under
  `set -u`, no unconditional jq consumption, no real-validator
  invocation); self-registers via a grep-based self-check against
  `tests/run-all.sh`/`.ps1` and `.github/workflows/test.yml`. (REQ-002)
- AC-010: `.github/workflows/model-freshness-check.yml` is a file the
  weekly `self-improvement.yml` session could never have authored itself —
  `self-improvement-pr-guard.sh`'s `.github/workflows/*` denylist pattern
  (`self-improvement-pr-guard.sh:34`) would reject any session-created PR
  touching it — confirming this feature's file is, and must remain,
  authored only via normal PR flow (INV-004), asserted by a grep-based
  self-check in `tests/model-freshness-check.tests.sh` confirming the
  denylist pattern still matches `.github/workflows/model-freshness-check.yml`.
  (REQ-002)
- AC-011: `tests/model-freshness-check.tests`'s registration line inside
  `.github/workflows/test.yml` is staged under
  `specs/epic-159-pillar-d/human-copy/.github/workflows/test.yml` with a
  `MANIFEST.sha256` (epic-136 human-copy procedure) rather than written
  directly, because `.github/workflows/test.yml` is an enforcement-chain
  protected file (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`
  `protected_gate_suffixes`); its registration in `tests/run-all.sh`/`.ps1`
  (unprotected) is written directly by the agent. The human maintainer
  applies the staged candidate as a commit on the feature PR branch BEFORE
  merge, so AC-009's live-file self-check turns green in the PR's own CI;
  until that commit exists the PR's CI stays red — the designed
  fail-closed gate, with no staged-candidate fallback or other special
  case. (REQ-002)
- AC-012: `contracts/agent-model-capabilities.v2.json`'s `models[]` array
  (once C1 lands it) is updated to current-generation Anthropic (Claude 5
  family alias policy) and OpenAI (`gpt-5.4`/`5.5`/`5.6` family) entries
  with accurate `supported_efforts` per model; the confirmation date and
  reference URLs are recorded in an adjacent comment or sibling doc
  section. (REQ-003)
- AC-013: `contracts/agent-model-capabilities.json` (v1) is byte-for-byte
  unchanged after D3 lands, asserted by a diff/hash comparison against its
  pre-D3 content. (REQ-003)
- AC-014: `tests/agent-capabilities-v2.tests.sh`/`.ps1` (Pillar C's parity
  suite) and `tests/agent-model-routing.tests.sh` both exit 0 after D3's
  data update — re-run and recorded in the implementation report, not
  re-authored by this feature. (REQ-003)
- AC-015: D1's process documentation (AC-001/AC-002) contains no
  host-specific runtime branch — it is read identically by Claude Code and
  Codex contributors; no degradation statement is needed because no
  degradation exists. (REQ-004)
- AC-016: `check-model-freshness.sh` has no `.ps1` counterpart, recorded as
  an explicit design decision in design.md citing the
  `self-improvement-pr-guard.sh` non-twin precedent; its locking suite
  `tests/model-freshness-check.tests.sh`/`.ps1` IS a full twin pair on the
  existing 3-OS matrix. (REQ-004)
- AC-017: D3's current-generation entries (AC-012) each populate both the
  Claude Code (`effort_control` plugin/frontmatter) path and the Codex
  (`effort_control` CLI-flag) path per C1's v2 schema — asserted by review
  against issue #149's schema description at task-implementation time
  (no automated assertion is authored by this spec beyond AC-014's
  existing-suite green requirement). (REQ-004)
- AC-018: Each of T-001/T-002/T-003's PRs carries `CHANGELOG.md`'s
  `## Unreleased` section gaining its own entry citing its own issue
  number (#156, #158, #157 respectively); each verifies applicable doc
  surfaces and edits only where a genuine reference exists. (REQ-005)
- AC-019: `validate-repository` and the skill-reference count sync stay
  green after each task; no version-literal edit exists outside
  `scripts/bump-version.sh` for any of the three tasks. (REQ-005)
- AC-020: `check-model-freshness.sh`, when both fetches succeed and NO
  divergence against `contracts/agent-model-capabilities.v2.json` is
  detected, creates no issue, posts no comment, performs no other side
  effect, and exits 0 — proven fixture-driven, with the suite's stubbed
  `gh` wrapper recording ZERO invocations for the run. (REQ-002)
- AC-021: any issue body `check-model-freshness.sh` produces embeds only
  model-ID tokens validated against a charset allowlist
  (`[A-Za-z0-9.\-]`); a malformed or adversarial fetch payload (markdown
  injection, instruction-like text, script fragments) never reaches an
  issue body verbatim — Security Boundaries B1 covers issue bodies, not
  only repository files. (REQ-002)

## Field Definitions

- `capability refresh` (REQ-001) — the documented manual check procedure
  D1 adds: verify model IDs, new model/feature availability,
  effort/tool-support changes, and v2-registry divergence against the
  canonical source list, connecting to D2's automated flow as the
  scheduled complement.
- `freshness-check` (REQ-002) — the weekly automated workflow D2 adds:
  fetch official sources, diff against the v2 registry, file/dedup an
  issue on divergence, fail-soft ("取得不能" comment, exit 0) on fetch
  failure.
- `current-generation` (REQ-003) — the D3 Done condition: v2 registry
  entries reflecting the Anthropic and OpenAI model families current as of
  D3's own implementation time, each with a recorded confirmation date and
  reference URL, distinct from C1's permissive "may start with
  v1-equivalent content" bootstrap state.
- `external Blocker` (Main Workflows) — a dependency this spec cannot
  resolve because it is owned by a different, in-flight spec
  (epic-159-pillar-c's T-001/#149) on a different branch; recorded as a
  Blocker on T-002 and T-003 distinct from the in-spec `Depends On: T-001`
  relationship T-003 also carries.
- `stable title marker` (REQ-001, REQ-002) — the literal, dedup-bearing
  title substring every model-freshness issue carries regardless of filing
  path: `[model-freshness-divergence]` for divergence reports (D2's
  automated filings and D1's manual filings alike — AC-002, AC-007) and
  `[model-freshness-fetch-unavailable]` for D2's dedicated fail-soft
  tracking issue (AC-006). D2's dedup matching searches open-issue titles
  for exactly this substring; a manual issue missing the marker would
  escape that matching, which is why AC-002 requires the checklist text to
  state the string verbatim.

## Roles and Permissions

- Agent: authors `docs/contributor/workflow-detail.md` and
  `docs/agent-capability-matrix.md` edits (T-001); authors
  `.github/workflows/model-freshness-check.yml`,
  `.github/scripts/check-model-freshness.sh`,
  `tests/model-freshness-check.tests.sh`/`.ps1`, and the
  `tests/run-all.sh`/`.ps1` registration directly, but stages the
  `.github/workflows/test.yml` registration under
  `specs/epic-159-pillar-d/human-copy/` per the epic-136 human-copy
  procedure (T-003); authors `contracts/agent-model-capabilities.v2.json`
  data edits once C1 has landed (T-002); authors CHANGELOG/doc-follow
  edits for all three tasks — none of the agent-direct edits are in the
  protected-gate table (design.md Protected-File Statement), except the
  one `.github/workflows/test.yml` line explicitly carved out above.
- Human maintainer: approves the spec and tasks; copies the staged
  `.github/workflows/test.yml` candidate into place per the human-copy
  procedure, committing it onto the feature PR branch BEFORE merge so
  AC-009's live-file self-check is green in the PR's own CI — until that
  commit exists the PR's CI stays red, by design (fail-closed, no special
  case) (T-003); merges Pillar C's C1 PR to `main` (the external
  Blocker T-002/T-003 wait on); reviews and closes/merges the filed
  freshness-divergence issues D2 produces.
- CI: runs the new `model-freshness-check.tests` suite pair on the
  existing 3-OS matrix (`test.yml`); runs `model-freshness-check.yml`
  itself only on its own weekly schedule or manual dispatch, on
  `ubuntu-latest` — never as part of the push/PR matrix (mirrors
  `release.yml`'s own release-only trigger scope, `test.yml:1-7` unedited
  by this feature).

## Main Workflows

1. T-001 (#156, D1): add the capability-refresh step to
   `docs/contributor/workflow-detail.md`'s WFI lifecycle section and the
   confirmation-date/reference-source columns to
   `docs/agent-capability-matrix.md`'s Provider Tier Mapping table; CREATE
   the `CHANGELOG.md` `## Unreleased` entry citing #156.
   Blockers: None — independent, low-risk, docs-only (investigation.md
   INV-002).
2. T-002 (#158, D3): once Pillar C's C1 (#149,
   `contracts/agent-model-capabilities.v2.json`) has landed on `main`,
   update the registry's `models[]` entries to current-generation data and
   record confirmation date/sources; verify Pillar C's parity suite and
   `tests/agent-model-routing.tests.sh` stay green; CREATE the
   `CHANGELOG.md` `## Unreleased` entry citing #158.
   Blockers: External — Pillar C's T-001 (#149) landing on `main`
   (epic-159-pillar-c is mid-pipeline on a sibling branch at
   spec-authoring time; this spec cannot resolve or wait on that landing
   itself — implementation of T-002 cannot start before it).
3. T-003 (#157, D2): add `model-freshness-check.yml` +
   `check-model-freshness.sh` + `tests/model-freshness-check.tests.sh`/
   `.ps1`; register the suite in `tests/run-all.sh`/`.ps1` directly and
   stage the `.github/workflows/test.yml` registration under
   `specs/epic-159-pillar-d/human-copy/` (protected-file carve-out,
   Overview); the human maintainer then applies that staged candidate as a
   pre-merge commit on the same feature PR branch (AC-011), turning
   AC-009's live-file self-check green in the PR's own CI — the PR merges
   only after this application; CREATE the `CHANGELOG.md` `## Unreleased`
   entry citing #157.
   Blockers: T-001 (in-spec — D2's filed-issue body cites the SAME
   canonical-source list T-001 documents, so that content must exist
   first to avoid two divergent source lists, mirroring
   epic-159-pillar-b's shared-content serialization convention) AND
   External — Pillar C's T-001 (#149) landing on `main` (D2's diff logic
   reads `contracts/agent-model-capabilities.v2.json`, which does not
   exist until C1 lands).
4. Verification: each task lands with `validate-repository` and the
   skill-reference count sync green; the quality gate evaluates each task
   with the standard evidence chain. T-002 and T-003 cannot enter
   `In Progress` before the external Blocker (Pillar C's #149 landing on
   `main`) is satisfied — this is a precondition on task START, recorded
   here because it is not expressible as an in-spec `Depends On:` line in
   Phase 2's tasks.md.

## Edge Cases

- CI-resilience (INV-008 cross-OS mandate; mirrors epic-159-pillar-b's
  established bar): `tests/model-freshness-check.tests.sh`/`.ps1` must
  never expand a possibly-empty bash array under `set -u`; must normalize
  any mktemp fixture root with `pwd -P` immediately after creation; must
  not consume jq output unconditionally without `tr -d '\r'` if jq is ever
  used (this suite's own fixtures are plain files, not jq-parsed —
  non-use declaration is the compliance); must not drive the real
  validator (non-use declaration).
- External-dependency fail-soft (INV-009, REQ-002's central edge case): a
  fetch failure for EITHER vendor's source must never fail the CI job —
  this is the one place in this spec where "fail-soft," not "fail-closed,"
  is the correct and required behavior, and it must not be confused with
  the no-bypass constraint below (design.md Constraint Compliance
  distinguishes the two explicitly).
- No-bypass on genuine drift (REQ-002): once a fetch succeeds and a
  divergence is detected, no environment variable or configuration flag
  may suppress issue creation — a real drift can never be silently
  swallowed, even though a fetch outage legitimately can be (the mirror
  image of pillar-b's REQ-001 no-bypass constraint, applied to the
  opposite failure mode).
- Protected-file carve-out (Overview; design.md Protected-File Statement):
  T-003's `.github/workflows/test.yml` registration line is the only
  protected-file touch anywhere in this spec. Every other deliverable —
  including the new workflow file itself, `.github/scripts/`, and
  `tests/run-all.sh`/`.ps1` — is agent-editable, verified directly against
  `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`. The
  staged candidate is applied by the human as a pre-merge commit on the
  feature PR branch (AC-011); a red PR CI before that commit is the
  designed fail-closed state, not an error to special-case.
- External Blocker vs. in-spec Blocker (Main Workflows): T-002 and T-003
  each carry an External Blocker (Pillar C's #149 landing on `main`) that
  this spec's own task graph cannot resolve or track completion of —
  Phase 2 task authoring must re-verify the external landing status at
  the time each task actually starts, not rely on this spec's
  investigation-time snapshot.
- Registry write boundary (Non-goals; Security Boundaries B2):
  `check-model-freshness.sh` never writes `contracts/`; only D3
  (human/agent-reviewed, T-002) mutates registry data. A future edit that
  gave D2 write access to the registry would cross a scope boundary this
  spec deliberately does not cross.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: external official-source fetch vs. repository state | `check-model-freshness.sh` treats fetched content as untrusted diff input only — never executed, never written verbatim into any repository file; fetch failures degrade to a comment, never a repository write; issue bodies are inside this boundary — only model-ID tokens validated against a charset allowlist reach an issue body, never verbatim fetched content (AC-021) | public vendor documentation only, no credentials | none identified |
| B2: freshness-check job vs. registry/release surfaces | `check-model-freshness.sh` and `model-freshness-check.yml` hold no write path to `contracts/`, `scripts/bump-version.sh`, or any plugin manifest — `issues: write` is the only elevated scope requested (AC-005) | internal source only | none identified |
| B3: protected `.github/workflows/test.yml` vs. agent-direct edits | T-003's registration line is staged under `specs/epic-159-pillar-d/human-copy/` with a SHA-256 manifest; only a human copies it into the live protected target (AC-011) | internal source only | none identified |
| B4: fixture world vs. real repository state | `tests/model-freshness-check.tests.sh`/`.ps1`'s injectable fixture source files are mktemp-scoped and never the real repository's registry or network state; no suite in this feature makes a live network call | synthetic fixtures only | none identified |

Details: [Security specification](security-spec.md#trust-boundaries).

## Assumptions

- Pillar C's C1 (#149) ships `contracts/agent-model-capabilities.v2.json`
  with the schema issue #149's body describes (`supported_efforts`,
  `default_effort`, `effort_control`, `risk_effort_matrix`,
  `role_defaults`) without material shape changes between this spec's
  authoring time and T-002/T-003's actual implementation time; if C1's
  landed schema differs, T-002/T-003 re-verify against the landed file
  before implementing, not against this spec's description alone.
- `self-improvement-pr-guard.sh`'s `.github/workflows/*` denylist pattern
  (`self-improvement-pr-guard.sh:34`) remains as observed — it protects
  workflow files against the WEEKLY SESSION's own self-authored PRs only,
  not against normal, human-reviewed PR flow (INV-004); this spec's own
  implementation lands via normal PR flow, so this restriction does not
  block it.
- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`'s
  `protected_gate_suffixes` tuple remains as observed at spec-authoring
  time; if a future, unrelated edit removes `.github/workflows/test.yml`
  from that list before T-003 implements, the human-copy carve-out
  (AC-011) becomes unnecessary but harmless to keep.
- `tests/agent-model-routing.tests.sh`'s `assert_literal` checks
  (`tests/agent-model-routing.tests.sh:79-97`) remain fixed-string
  (`grep -F`) substring matches, not full-line matches, so AC-003's
  trailing-column append remains compatible without editing that suite.

## Open Questions

- OQ-001 — RESOLVED: Pillar C's C1 (#149) is not yet on `main` at
  spec-authoring time (investigation.md header note); this is recorded as
  an External Blocker on T-002 and T-003 (Main Workflows), re-verified at
  each task's actual start rather than resolved once here.
- OQ-002 — RESOLVED: the only file-level overlap this spec's own
  investigation surfaces between Pillar D and epic-136 Phase 2+ is exactly
  the `.github/workflows/test.yml` protection this spec's Overview
  documents (added by epic-136 Phase 2's guard-invariants change,
  commit `2b8a52f`) — already accounted for via the human-copy carve-out
  (AC-011); no other Phase 2+ overlap is identified.
- OQ-003 — RESOLVED: one feature branch / one PR covers all three tasks
  (T-001, T-002, T-003), matching epic-159-pillar-a's and
  epic-159-pillar-b's established precedent (multiple issues, one spec
  folder, one PR) rather than three independent PRs — though the external
  Blocker on T-002/T-003 means the PR cannot merge all three tasks'
  commits until Pillar C's #149 has landed; T-001 may land and merge
  independently if that proves faster (design.md Deployment / CI Plan).
- OQ-004 — RESOLVED: C1 (Pillar C) completes the v2 SCHEMA; D3 (#158, this
  spec) completes the v2 DATA currency; D2 (#157, this spec) is a
  hardening/maintenance addition that keeps that data current going
  forward, not part of "effort-routing v2"'s own completion criteria.
- OQ-005 — RESOLVED: D1 (#156) is manual, event-triggered (performed
  whenever plugin-improvement work touches model/effort routing), not on a
  fixed schedule; D2 (#157) supplies the fixed weekly cadence as the
  automated complement (requirements.md REQ-001, REQ-002 above).

## Risks

- High: T-002 and T-003 depend on a concurrently in-flight, separately
  approved spec (epic-159-pillar-c's C1/#149) whose exact landed schema
  and timing this spec cannot control. Mitigation: both tasks carry an
  explicit External Blocker (Main Workflows) that Phase 2 task authoring
  must re-verify before starting either task, rather than assuming this
  spec's investigation-time snapshot still holds.
- Medium: `check-model-freshness.sh`'s fetch-then-diff heuristic against
  official vendor documentation is inherently imprecise (Non-goals).
  Mitigation: the heuristic is deliberately conservative (false negatives
  acceptable, false positives human-triaged, never auto-applied to the
  registry) and is a safety-net complement to D1's manual checklist, not
  the sole detection path.
- Medium: `.github/workflows/test.yml`'s protected status (discovered
  during this spec's own investigation, not by investigation.md's own
  INV-012) could be missed by a less careful implementer of T-003,
  producing a rejected/blocked write attempt at implementation time.
  Mitigation: the Overview, AC-011, and design.md's Protected-File
  Statement all state this explicitly and independently, with the exact
  citation (`guard_invariants.py:4`) any implementer or reviewer can
  re-verify directly.
- Low: the two-workflow-file design (keeping `model-freshness-check.yml`
  separate from `self-improvement.yml`) adds one more scheduled workflow
  to maintain. Mitigation: design.md Design Decisions records the
  separation rationale (deterministic CI job vs. LLM-session runtime) as a
  deliberate, reviewable trade-off, not an oversight.
