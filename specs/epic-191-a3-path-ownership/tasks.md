# Tasks: epic-191-a3-path-ownership

Task-Review-Status: Passed

Source: Issue #191 (Epic A3 — Component Path Ownership), tracked under epic
#187 (AI-DLC Foundation) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Protected Files

This feature touches R-10 enforcement-chain protected files in THREE
distinct situations that must not be conflated (design.md Protected-File
Statement, verified against
`plugins/sdd-quality-loop/references/guard-invariants.json` and
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` at
design-authoring time; every task re-verifies the then-current
`PROTECTED_GATE_SUFFIXES` / `check-contract` tier-minimum contents at its
own implementation-start time — this is a live-repository snapshot, not a
permanent guarantee, per requirements.md Assumptions):

1. **Content-protection registration (protected-suffix) — six already-protected
   files.** `plugins/sdd-quality-loop/references/guard-invariants.json`
   gains three new `protected_gate_suffixes` entries
   (`check-component-coverage.{sh,ps1,py}`), and
   `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` is
   **edited** — not merely read — so its own `PHASE2_TARGETS` tuple gains
   the identical three entries, without which `load_and_validate()`'s
   exact-match check rejects the edited JSON before `--check` ever runs
   (INV-015). `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
   and its three `generated/guard-invariants.generated.{js,ps1,sh}`
   siblings are regenerated to match.

2. **Reachability registration (required-check-set), NOT content-protection
   — three already-protected files.** `check-contract.{sh,ps1,py}` (already
   R-10 protected, `guard-invariants.json:14-16`) gain `check-component-coverage`
   in their hardcoded `high`/`critical` tier-minimum set, AND a
   producer-digest verification pass (recomputes `check-component-coverage.py`'s
   live sha256 and rejects a `passes:true` evidence entry whose recorded
   `producer.sha256` diverges, INV-018/INV-019). This is paired with the
   UNPROTECTED `plugins/sdd-quality-loop/references/risk-gate-matrix.md`
   (a direct agent edit, kept textually in sync with `check-contract`'s
   machine-form set per `tests/gates.tests.sh` T-003's existing invariant).
   Per the two-tier defense scope this mirrors (ADR-0019), this closes
   footgun-prevention/tamper-evidence exposure, not an unconditional
   adversarial-agent-proof reachability guarantee.

3. **New files that BECOME protected as a design decision.**
   `check-component-coverage.{sh,ps1,py}` do not exist yet (INV-001) and so
   cannot pre-appear in `guard-invariants.json`; adding them to
   `protected_gate_suffixes` is effected via situation 1's staged edit.

Plus `.github/workflows/test.yml` (R-10 protected, INV-010) — its CI-step
registration is human-copy staged by each of the five suite-owning tasks
(T-001, T-002, T-003, T-004, T-006), in the serialized order the Global
Constraints establish, so no two tasks' staged candidates race.

**No task below writes any protected path directly.** Every corrected copy
is staged under `specs/epic-191-a3-path-ownership/human-copy/<real-relative-path>`
with a `MANIFEST.sha256` entry (INV-007, ADR-0011). A human maintainer runs
the `cp` + SHA-256 verification for each staged file, and runs
`generate-guard-invariants.py --check` against the applied tree (must exit
0), before the staging task can be marked Done. Total staged real paths:
six (situation 1) + three (situation 2) + `.github/workflows/test.yml`
(appended across the five suite tasks) = ten, each with its own
`MANIFEST.sha256` entry. **Reading** any protected file (for `--check`
comparison, live-sha256 recomputation, or a registration-proof grep) is
explicitly permitted — reading is not writing and does not trip the R-10
guard.

Every OTHER file this feature creates or edits (`resolve-component-paths.{py,sh,ps1}`,
`check-component-coverage.{py,sh,ps1}`, the five test-suite pairs, the
fixture tree, `risk-gate-matrix.md`, `quality-gate/SKILL.md`'s `## Process`
edit, the new ADR, `CHANGELOG.md`, `tests/run-all.{sh,ps1}`) is verified
absent from `PROTECTED_GATE_SUFFIXES`/`PROTECTED_GATE_PLUGIN_JSON_SUFFIXES`
and is agent-editable directly.

**No task authors `plugins/sdd-quality-loop/references/default-shared-paths.md`**
— that reference document is withdrawn (REQ-006, design.md Components table);
Epic A1's `contracts/project-context.template.yaml` `shared_paths` section
is the sole canonical source of the default cross-cutting seed list, and A3
authors no competing or duplicate list of its own.

## Global Constraints

- **Two-commit landing plan per task** (commit A = implementation, commit B
  = docs), the same convention `specs/epic-159-pillar-c/tasks.md` Global
  Constraints established: commit A is the script/test edit +
  `tests/run-all.sh`/`.ps1` registration (where applicable) + staging the
  `.github/workflows/test.yml` candidate (and, for T-004, the situation-1/2
  protected candidates) under `human-copy/`; commit B is the `CHANGELOG.md`
  `## Unreleased` entry. Commit A must land before commit B within the same
  task. Each of T-001..T-006 lands its OWN new `## Unreleased` block citing
  issue #191 — never an append to another task's entry.
- **The new ADR (provisionally `docs/adr/0025-component-path-ownership-resolver-semantics.md`)
  is drafted and added as PART OF T-001's implementation commit A** (design.md
  ADR Change Log, Drafting ownership — the resolver's matching algorithm is
  the change this ADR records). T-001's implementer re-verifies via
  `ls docs/adr/` at drafting time that `0025` is still free (`0024` is the
  highest existing number as of this authoring; a concurrent sibling Epic-191
  merge could have occupied `0025`), and, if occupied, renumbers — updating
  both the ADR filename and every `docs/adr/00NN-...` / `ADR-00NN` reference
  in `design.md` in the same commit.
- **Version bumps only via `scripts/bump-version.sh`**; this feature
  introduces NO version-mutation path at all. No task hand-edits a version
  string, and no task executes `scripts/bump-version.sh`.
- **`tests/run-all.sh` / `tests/run-all.ps1`** (unprotected, direct edit):
  one array-append per new suite, serialized **T-001 → T-002 → T-003 →
  T-004 → T-006** (T-005 shares T-001's fixture and adds no new suite of its
  own, so it does not touch this array). Each of the five suite-owning tasks
  appends only its OWN suite's registration line, in that order.
- **`.github/workflows/test.yml`** (R-10 PROTECTED — see Protected Files):
  the same five suite-owning tasks (T-001, T-002, T-003, T-004, T-006) each
  stage their own full corrected copy of the shared candidate under
  `specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml`,
  in the SAME serialized order, so no two tasks' staged candidates race. A
  task that stages after another whose candidate is not yet human-applied
  appends its step to that pending staged file rather than starting from the
  unmodified real file. T-005 does not touch `test.yml`.
- **`guard-invariants.json` + `generate-guard-invariants.py` + generated
  siblings** (situation 1, six files): **T-004 is the sole editor** (via
  human-copy) within this feature.
- **`check-contract.{sh,ps1,py}` + `risk-gate-matrix.md`** (situation 2):
  **T-004 is the sole editor of both** (protected via human-copy for the
  former, direct edit for the latter) within this feature.
- **CI-resilience** (design.md Test Strategy) applies to every new `.sh`/
  `.ps1` suite: no possibly-empty array expanded under `set -u`; every
  directly-created mktemp root normalized with `pwd -P` immediately after
  creation; any `jq` output consumption piped through `tr -d '\r'`
  unconditionally; no suite drives a real validator gate directly.
- Fixture writes happen inside script/test files only; no task places a
  protected basename together with a write verb on a Bash command line.
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Author the component path resolver core, glob semantics, and ADR-0025

Source Issue: https://github.com/aharada54914/sdd-forge/issues/191

Approval: Approved (sudo 2026-07-22T14:38:39Z)

Status: Blocked

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. `high` is justified, not merely asserted: the
resolver is the deterministic classifier every downstream Fail condition
depends on, and a silent misclassification (OVERLAP under-reported as
EXCLUSIVE, or an excluded path wrongly attributed to a component) defeats
the entire purpose of the Reverse Coverage Gate — per-component review
coverage is silently skipped, exactly the "silent defect causes material
harm" surface the policy's `high` tier names (design.md Risks explicitly
directs REQ-001/REQ-002 be treated as `Risk: high` / `Required Workflow:
tdd`). It is not `critical` because it touches no financial-settlement,
physical-safety, or irreversible-destructive surface — it emits
classification data, and only `check-component-coverage` (T-004) turns a
classification into a blocking Gate outcome. Required Workflow is therefore
`tdd` (Red→Green) per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-002, REQ-007 (share — fixture-tree base shape,
AC-045), REQ-008 (share — CHANGELOG + authors ADR-0025)

Depends On: none (functional — the resolver is the root of this feature's
dependency graph). This task is NOT hard-blocked on Epic A1 landing to
start (implementation proceeds against decision-document v2 §12's
already-fixed field shape, OQ-002, design.md Design Decisions), BUT its own
**Done** state is gated on the schema-conformance fixture (AC-011), which
is part of this task's own test suite from the start and is written to FAIL
closed — never skip or conditionally pass — while Epic A1's canonical
`project-context.yaml` schema artifact is absent from its fixed, documented
repository path or diverges from this parser (a Done-gating fail-closed
fixture, not a start blocker — see Blockers).

Planned Files:
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.py` (new,
  agent-editable — glob compiler: `**`/`*`/zero-segment semantics,
  unsupported-metacharacter rejection, NFC + `\`→`/` normalization with raw
  identity preserved, byte-wise case sensitivity, `shared_paths` precedence,
  per-component `(include − exclude)` set arithmetic, `EXCLUDED_MATCH`
  evidence; design.md Components / Data Plan)
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.sh` (new,
  agent-editable — thin wrapper, INV-008 convention)
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.ps1` (new,
  agent-editable — twin)
- `tests/component-path-resolver.tests.sh` (new, agent-editable)
- `tests/component-path-resolver.tests.ps1` (new, agent-editable)
- `tests/fixtures/component-path-ownership/` (new fixture tree — ≥2
  components with overlapping candidate owned paths, a nested excluded
  subtree, a bounded `shared_paths` entry, one fixture per REQ-001 glob
  clause id, the NFC-collision fixture, and the A1 schema-conformance
  fixture path; design.md Components — extended by later tasks)
- `docs/adr/0025-component-path-ownership-resolver-semantics.md` (new,
  agent-editable — drafted in THIS commit A; re-verify number via
  `ls docs/adr/` at drafting time)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml`
  (new staged candidate, agent-editable — this suite's CI steps; R-10
  protected real path, human-copy only)
- `specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256` (new,
  agent-editable — SHA-256 entry for the staged `test.yml` candidate)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #191)

Data Migration: none — new, additive in-process/CLI JSON output shape; no
prior version to migrate from (design.md Data Plan, Migration Strategy).

Breaking API: no; `resolve-component-paths` is a wholly new script; no
existing script's contract changes.

Rollback: revert this task's two commits (B then A, or both). Nothing
protected is written directly (the staged `test.yml` candidate is a
human-applied change; a revert PR states explicitly whether a human should
also hand-revert any already-applied `test.yml` step). Reverting also
removes ADR-0025.

### Goal

Author `resolve-component-paths.py` (+ `.sh`/`.ps1` wrappers) implementing:
`**` = zero-or-more whole path segments including the zero-segment case and
crossing `/`; bare `*` within one segment only; `?`/`[...]`/regex rejected
fail-closed at load time; NFC + `\`→`/` normalization for matching only,
with raw path bytes preserved for identity and a stable sort; byte-wise
case sensitivity; `shared_paths` precedence (bounded vs. cross-cutting
shape, both-or-neither rejected fail-closed) over per-component
`(include − exclude)` classification into EXCLUSIVE / SHARED / OVERLAP /
UNOWNED; and the `EXCLUDED_MATCH` evidence tag for an UNOWNED path caused
entirely by every otherwise-matching component's `exclude`. Author the
resolver suite covering every glob clause id independently, the
NFC-collision fail-closed case, and the A1 schema-conformance fixture
(FAIL-closed on schema absence/divergence). Draft
`docs/adr/0025-component-path-ownership-resolver-semantics.md` in this same
commit.

### Must Read

- `specs/epic-191-a3-path-ownership/requirements.md`
- `specs/epic-191-a3-path-ownership/design.md`
- `specs/epic-191-a3-path-ownership/acceptance-tests.md`
- `specs/epic-191-a3-path-ownership/investigation.md`
- `specs/epic-191-a3-path-ownership/security-spec.md`
- `plugins/sdd-quality-loop/scripts/check-contract.py` (the Python-master +
  wrapper convention this script follows, INV-008)
- `docs/adr/0021-context-projection-staleness.md` (the `ownership_digest`
  binding shape ADR-0025 references, not restates)
- `docs/adr/0020-conditional-predicate-dsl.md` (the restricted-DSL
  determinism rationale ADR-0025's glob subset extends)
- `docs/adr/` directory listing (`ls docs/adr/`, re-verified at drafting
  time before naming ADR-0025)

### Scope

Commit A (implementation — resolver + suite + fixture + ADR + CI wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-001..TEST-010
  (every glob clause id independently, plus the NFC-collision + raw-identity
  + stable-sort case), TEST-011 (schema conformance, **FAIL-closed on schema
  absence** — turns red while Epic A1's schema is unlanded or divergent),
  TEST-012, TEST-015, TEST-016, TEST-017 (EXCLUSIVE/UNOWNED/OVERLAP/shared
  precedence), TEST-013 + TEST-014 (Fail-5 invariant + `EXCLUDED_MATCH`
  evidence), TEST-018 (`shared_paths` config-shape fail-closed check), and
  the base fixture-tree shape (TEST-045).
- CI resilience per Global Constraints.
- Register `component-path-resolver` (`.sh`/`.ps1`) in `tests/run-all.sh`/
  `.ps1`; stage the `.github/workflows/test.yml` candidate with this suite's
  CI steps under `human-copy/` + `MANIFEST.sha256`.
- `ls docs/adr/`; draft `docs/adr/0025-component-path-ownership-resolver-semantics.md`
  (renumber to the next free slot + update every `design.md` reference if
  `0025` is occupied).

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #191.

### Done When

- [ ] **Glob semantics** — TEST-001..TEST-010 pass: each glob-matching
  clause id independently (AC-001..AC-009) plus the NFC-collision
  fail-closed error, raw-identity preservation, and stable sort over raw
  path bytes (AC-010).
- [ ] **A1 schema conformance** — TEST-011 proves the schema-conformance
  fixture FAILS closed (non-zero, red) while Epic A1's schema artifact is
  absent, and validates field-name/type/version conformance when present
  (AC-011) — this task cannot reach Done while that fixture is red for an
  unlanded/divergent schema.
- [ ] **Classification + shared_paths + Fail conditions** — TEST-012..018
  pass: EXCLUSIVE / UNOWNED (Fail-1) / OVERLAP (Fail-3) /
  `shared_paths`-precedence classification (AC-012, AC-015, AC-016,
  AC-017); the exclude-as-include Fail-5 invariant and its `EXCLUDED_MATCH`
  evidence tag (AC-013, AC-014); the `shared_paths` both/neither
  config-shape fail-closed rejection (AC-018).
- [ ] **Fixture + suite/CI registration** — TEST-045 proves the fixture-tree
  base shape (≥2 overlapping components, nested excluded subtree, bounded
  `shared_paths` entry) (AC-045); `tests/component-path-resolver.tests.sh`/
  `.ps1` self-register in `tests/run-all.sh`/`.ps1` (grep self-check); the
  staged `.github/workflows/test.yml` candidate exists with a correct
  `MANIFEST.sha256` entry and the LIVE `test.yml` is byte-unchanged
  before/after this task's own commits.
- [ ] **Governance (ADR + CHANGELOG + version discipline)** —
  `docs/adr/0025-component-path-ownership-resolver-semantics.md` exists, is
  correctly numbered (re-verified via `ls docs/adr/`), and records glob
  semantics, precedence, the six Fail-condition definitions, the
  applicability-derivation decision, and the reachability-registration
  decision (AC-048 share, ADR portion); `CHANGELOG.md` gains a NEW
  `## Unreleased` entry citing #191 (AC-048 share); a grep self-check
  confirms no version string was mutated outside a `scripts/bump-version.sh`
  invocation (AC-049 share).
- [ ] **TDD evidence** — RED (each glob clause / classification test
  against a deliberately broken resolver or fixture) and GREEN (the full
  suite against the correct resolver). An independent quality-gate verdict
  records PASS.

Note on scope breadth (task-review round 1, TASK-SIZE): this task's five
work areas (resolver core, suite, fixture tree, ADR, CI registration) are
not a Phase-2 decomposition choice — design.md's own Technical Summary,
API/Contract Plan (`resolve-component-paths.sh`/`.ps1` (T-001/T-002)
heading), Components table, and Global Constraints ("the new ADR... is
drafted and added as PART OF T-001's implementation commit A") explicitly
bundle every one of these deliverables into T-001. Splitting them into
separate tasks would contradict the frozen (Impl-Review-Status: Passed)
design.md. The commit-conflation risk this check protects against is
mitigated structurally by the two-commit landing plan (Global Constraints):
commit A is the resolver + suite + fixture + ADR + CI-staging work with its
own RED/GREEN evidence; commit B is only the CHANGELOG entry.

### Out of Scope

- The git-diff basis collector (T-002), `ownership_digest` emission (T-003),
  `check-component-coverage` and the `--diagnose` subcommand (T-004), the
  cross-epic seed-inventory validation (T-005), and the parity harness
  (T-006).
- Any edit to a protected file (all protected-file staging is T-004's;
  T-001 only stages the unprotected-context `test.yml` CI-step candidate).

### Blockers

None

(Not a task-ID blocker, but an external Done-gating condition: Epic A1's
canonical `project-context.yaml` schema artifact must land and match for
TEST-011 to go green — until then this task's own schema-conformance
fixture is deterministically red and the task cannot reach Done
(requirements.md Dependencies, AC-011).)

---

## T-002 Wrap the resolver with the deterministic git-diff basis collector

Source Issue: https://github.com/aharada54914/sdd-forge/issues/191

Approval: Approved (sudo 2026-07-22T15:53:17Z)

Status: In Progress

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified: the collector determines the change set the
resolver classifies, so a silent defect (a dropped path under invalid-UTF-8
framing, a rename silently collapsed across a component boundary, a
mixed-snapshot TOCTOU result) produces an under-reported change set — the
exact "component silently omitted" harm the whole feature exists to prevent,
a silent defect causing material harm (missed per-component review coverage).
It additionally implements the submodule/symlink **reference-only boundary**
that security-spec.md names as a security boundary (never dereferencing a
symlink or descending into a submodule prevents a diff smuggling in
ownership-classification input the repository does not control). Every axis
is normatively fail-closed, so Red→Green fail-closed evidence is required.
It is not `critical` (no settlement/safety/irreversible surface). Required
Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-003, REQ-007 (share — fixture-tree diff facets), REQ-008
(share)

Depends On: T-001 (functional — wraps T-001's resolver; the collector code
lands in `resolve-component-paths.py`, invoked by its `.sh`/`.ps1` wrappers,
design.md Architecture). Serialized after T-001 for the shared
`tests/run-all.sh`/`.ps1` array and `.github/workflows/test.yml` staging
(Global Constraints). No epic dependency (this REQ needs only local `git`
plumbing).

Planned Files:
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.py` (existing
  after T-001, agent-editable — adds the git-diff collector:
  `rev-parse --verify <rev>^{commit}` → `merge-base` baseline,
  `baseline..worktree` ∪ untracked via NUL-framed git porcelain, pinned
  rename threshold/`diff.renameLimit`/`--no-ext-diff`, submodule/symlink
  reference-only 4-case contract, single-writer/TOCTOU fingerprint +
  retry-once; design.md API/Contract Plan)
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.sh` (existing,
  agent-editable — wrapper flags `--source-rev`/`--target-rev`/
  `--include-untracked` pass-through)
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.ps1` (existing,
  agent-editable — twin)
- `tests/component-path-diff-basis.tests.sh` (new, agent-editable)
- `tests/component-path-diff-basis.tests.ps1` (new, agent-editable)
- `tests/fixtures/component-path-ownership/` (existing after T-001,
  agent-editable — adds disposable fixture git repos: rename incl.
  cross-component, untracked/staged/unstaged, TAB/LF/invalid-UTF-8 path
  framing, the four submodule/symlink fixtures, unrelated-histories, and the
  TOCTOU-mutation fixtures)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended after
  T-001's; R-10 protected real path)
- `specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry for this task's staged `test.yml` candidate)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #191)

Data Migration: none.

Breaking API: no; the collector is an additive stage of the existing
`resolve-component-paths` invocation; no existing key or exit-code meaning
is removed.

Rollback: revert this task's two commits; nothing protected is written
directly (a revert PR states whether an already-applied `test.yml` step
should be hand-reverted).

### Goal

Add the git-diff basis collector to `resolve-component-paths`: resolve
source (`HEAD`/`--source-rev`) and target (`--target-rev`, complete ref/OID)
to commit OIDs via `git rev-parse --verify <rev>^{commit}` before
`git merge-base`, failing closed on an unresolvable rev or unrelated
histories; collect `baseline..worktree` plus untracked via NUL-framed git
porcelain (`git status --porcelain=v1 -z --untracked-files=all` /
`git ls-files --others --exclude-standard -z`, each path counted once);
parse every path-enumerating invocation as raw bytes, failing closed on
invalid-UTF-8; follow renames under a pinned similarity threshold + pinned
`diff.renameLimit` + `--no-ext-diff`, classifying both paths independently
and surfacing a cross-component rename as its own case; evaluate
submodule/symlink entries reference-only per the four-case contract; and
enforce the single-writer/TOCTOU fingerprint with a retry-once-then-fail-closed
rule.

### Must Read

- `specs/epic-191-a3-path-ownership/requirements.md`
- `specs/epic-191-a3-path-ownership/design.md`
- `specs/epic-191-a3-path-ownership/acceptance-tests.md`
- `specs/epic-191-a3-path-ownership/security-spec.md`
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.py` (T-001's
  resolver this task wraps)
- `tests/fixtures/component-path-ownership/` (T-001's fixture tree this task
  extends)

### Scope

Commit A (implementation — collector + suite + fixtures + CI wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-019 (rev-resolution
  + merge-base baseline + fail-closed unattainable case), TEST-020
  (staged+unstaged+untracked, each once, porcelain-only), TEST-021 (NUL-safe
  framing incl. TAB/LF round-trip + invalid-UTF-8 fail-closed), TEST-022
  (rename-follow incl. cross-component), TEST-023 (pinned threshold/limit +
  followed-vs-limit-exceeded output contract + fail-closed), TEST-024 (the
  four submodule/symlink fixtures), TEST-025 (single-writer/TOCTOU
  retry-then-fail-closed).
- CI resilience per Global Constraints (disposable fixture git repos only,
  never this repository's own history).
- Register `component-path-diff-basis` in `tests/run-all.sh`/`.ps1`; stage
  the `test.yml` candidate appended to T-001's staged file (or the
  unmodified real file if T-001's is already human-applied).

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #191.

### Done When

- [ ] **Baseline + collection + framing** — TEST-019..021 pass:
  rev-resolution, merge-base baseline, and the fail-closed
  unresolvable-rev/unrelated-histories diagnostic (AC-019); staged +
  unstaged + untracked collection with no double-count, porcelain-only
  (AC-020); NUL-safe raw-byte framing, TAB/LF round-trip, invalid-UTF-8
  fail-closed (AC-021).
- [ ] **Rename + submodule/symlink + single-writer** — TEST-022..025 pass:
  rename-follow including the cross-component case (AC-022); the pinned
  rename threshold/limit contract and the followed-vs-limit-exceeded
  fail-closed distinction (AC-023); all four submodule/symlink
  reference-only cases (AC-024); the single-writer/TOCTOU
  retry-then-fail-closed rule (AC-025).
- [ ] **Suite/CI registration + governance** —
  `tests/component-path-diff-basis.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`; the staged `test.yml` candidate exists with a
  correct `MANIFEST.sha256` entry and the LIVE `test.yml` is byte-unchanged
  before/after this task's commits; `CHANGELOG.md` gains a NEW
  `## Unreleased` entry citing #191 (AC-048 share); a grep self-check
  confirms no version string was mutated outside `scripts/bump-version.sh`
  (AC-049 share).
- [ ] **TDD evidence** — RED (each fail-closed axis against a fixture that
  would otherwise silently degrade) and GREEN (the full suite). An
  independent quality-gate verdict records PASS.

### Out of Scope

- Ownership classification itself (T-001), `ownership_digest` (T-003), the
  Gate (T-004), and the parity harness (T-006).
- Any protected-file edit.

### Blockers

T-001

---

## T-003 Emit ownership_digest binding the entire declared ownership input

Source Issue: https://github.com/aharada54914/sdd-forge/issues/191

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task emits binding/provenance
metadata (`ownership_digest` in the ADR-0021 `context_binding` block), an
additive output field with no prior version to migrate, and its blast
radius is bounded — a defect affects staleness re-resolve triggering, not
whether under-reported code passes the Gate (ADR-0021's downstream
semantic-output comparison, not the digest, is the actual selectivity
mechanism, and the digest is explicitly excluded from that comparison). It
does not touch an access-control, secrets, or Gate-blocking surface, so it
falls short of `high`; it is well above `low` because it introduces
behavioral logic (a canonicalized full-input digest) other components
consume. Required Workflow is `acceptance-first` per the policy's
medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-005, REQ-007 (share), REQ-008 (share)

Depends On: T-001, T-002 (functional — binds the resolver's full
`ownership_input` assembled from T-001's declared config, emitted on the
same resolve invocation T-002 completes). Serialized after T-002 for the
shared `tests/run-all.sh`/`.ps1` array and `test.yml` staging (Global
Constraints). **Hard-blocked on Epic A1's canonicalizer utility existing as
a real artifact** (YAML 1.2 + JCS, decision-document v2 §18.3): there is no
shape-only substitute for calling a canonicalization utility that does not
yet exist (design.md Design Decisions, "T-003 (canonicalizer) … remain
hard-blocked on their respective epics landing as artifacts"; requirements.md
Dependencies, AC-037) — re-verify its presence at implementation-start time
and record a documented blocker if absent rather than reimplementing
canonicalization.

Planned Files:
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.py` (existing,
  agent-editable — assembles the complete `ownership_input` (every
  component's `paths` entries + every `shared_paths` entry, unconditionally,
  + the matcher semantics/rule-set version) and emits `ownership_digest` via
  Epic A1's canonicalizer into the `context_binding` block alongside
  `resolver.version`/`resolver.rule_set_revision`; design.md Data Plan)
- `tests/ownership-digest.tests.sh` (new, agent-editable)
- `tests/ownership-digest.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended after
  T-002's; R-10 protected real path)
- `specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry for this task's staged `test.yml` candidate)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #191)

Data Migration: none — additive `ownership_digest`/`context_binding` field;
no prior version.

Breaking API: no; the digest is an additive field on the resolver's existing
output.

Rollback: revert this task's two commits; nothing protected is written
directly.

### Goal

Emit `ownership_digest` — a sha256 over the canonicalized, **complete**
`ownership_input` (every declared component's `paths.include`/`paths.exclude`
entry and every `shared_paths` entry, unconditionally, plus the matcher
semantics/rule-set version), via Epic A1's canonicalizer — identical for
every Feature sharing a config, changing whenever any ownership-input entry
(matched or not) or the matcher version changes. Populate the ADR-0021
`context_binding` block and exclude the digest from ADR-0021's
semantic-output comparison. Author the suite proving full-input binding, the
non-match stale regression, and the selective-stale positive/negative
matrix (selectivity lives in the semantic-output comparison, never in the
digest's scope).

### Must Read

- `specs/epic-191-a3-path-ownership/requirements.md`
- `specs/epic-191-a3-path-ownership/design.md`
- `specs/epic-191-a3-path-ownership/acceptance-tests.md`
- `docs/adr/0021-context-projection-staleness.md` (lines 41-42, 48-53,
  55-68, 78-88 — the `context_binding` shape, full-input binding rationale,
  and semantic-output exclusion this task implements)
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.py` (T-001/T-002
  resolver this task extends)
- Epic A1's canonicalizer entry point (re-verify presence at
  implementation-start time; record a documented blocker if absent)

### Scope

Commit A (implementation — digest emission + suite + CI wiring):
- Write the acceptance checks first (acceptance-first + regression):
  TEST-037 (full-input, unconditional digest binding incl. non-matching
  entries + the matcher-semantics-version component), TEST-038
  (`context_binding` presence + semantic-output exclusion), TEST-039
  (non-match stale regression as an instance of the full-input guarantee),
  TEST-040 (the six-row selective-stale positive/negative matrix), TEST-041
  (suite-wiring self-test across `run-all`, `test.yml` staged candidate, and
  design.md's Components inventory).
- CI resilience per Global Constraints.
- Register `ownership-digest` in `tests/run-all.sh`/`.ps1`; stage the
  `test.yml` candidate appended to the prior task's staged file.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #191.

### Done When

- [ ] **Full-input binding + staleness matrix** — TEST-037..040 pass: the
  digest binds the entire declared ownership input, unconditionally,
  identically across every Feature sharing a config, via Epic A1's
  canonicalizer (AC-037) — or a documented blocker is recorded if that
  canonicalizer is absent at implementation time; `context_binding`
  population and semantic-output exclusion, i.e. a digest-only change does
  not mark a Feature stale (AC-038); the non-match→match stale regression
  changes the digest against identical changed paths (AC-039); all six
  selective-stale matrix rows against ADR-0021's semantic-output comparison
  and `context_binding`/`resolver` metadata update behavior (AC-040).
- [ ] **Suite/CI registration + governance** — TEST-041 proves the
  suite-wiring self-test across all three registration surfaces (AC-041);
  `tests/ownership-digest.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`; the staged `test.yml` candidate exists with a
  correct `MANIFEST.sha256` entry and the LIVE `test.yml` is byte-unchanged
  before/after this task's commits; `CHANGELOG.md` gains a NEW
  `## Unreleased` entry citing #191 (AC-048 share); a grep self-check
  confirms no version string was mutated outside `scripts/bump-version.sh`
  (AC-049 share).
- [ ] **Acceptance-first evidence** — RED (a subset/evaluated-only digest
  binding failing the non-match regression) and GREEN (the full-input
  binding passing the whole matrix). An independent quality-gate verdict
  records PASS.

### Out of Scope

- The resolver core (T-001), the diff collector (T-002), the Gate (T-004),
  and reimplementing Epic A1's canonicalizer (Non-goals).
- Any protected-file edit.

### Blockers

T-001, T-002

(Additional external precondition, not an in-spec blocker: Epic A1's
canonicalizer utility must exist as a real artifact for TEST-037/TEST-041 to
run — a documented blocker is recorded if absent, per Depends On.)

---

## T-004 Author check-component-coverage, the --diagnose command, and the protected-file registrations

Source Issue: https://github.com/aharada54914/sdd-forge/issues/191

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified, not merely asserted: this is the
Implementation Gate check that turns a classification into a blocking Gate
outcome (an access-control/enforcement surface — a silent defect lets an
under-reported `affected_components` claim through to Done), AND it is the
SOLE task editing this feature's R-10 enforcement chain (`guard-invariants.json`
+ `generate-guard-invariants.py` + generated siblings via human-copy;
`check-contract.{sh,ps1,py}`'s protected tier-minimum set via human-copy,
adding a producer-digest tamper-evidence verification pass; and
`risk-gate-matrix.md` directly). Both the three-state
capability-derivation (which must never promote `advisory` to `required`'s
blocking strength) and the two protected-file bundles are surfaces where a
silent defect causes material harm. It is not `critical` (no
settlement/safety/irreversible surface — the enforcement change is additive
fail-closed hardening). Required Workflow is `tdd` per the policy's
high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-004, REQ-006 (share — the `contracts/**` bounded-shared
Fail-4 fixture, AC-046 under REQ-007), REQ-007 (share), REQ-008 (share)

Depends On: T-001, T-002 (functional — the Gate consumes the resolver +
diff collector; the `--diagnose` subcommand wraps the resolver's own
output). Serialized after T-003 SOLELY for the shared `tests/run-all.sh`/
`.ps1` array and `.github/workflows/test.yml` staging (Global Constraints;
T-003 is not a functional dependency — the Gate's Fail conditions do not
consume `ownership_digest`). Full `advisory`/`required`-mode evaluation
additionally needs **Epic A4's Facet Manifest as a real artifact**; the
degraded `disabled-legacy` mode is NOT blocked on A4 and can ship
independently (design.md Design Decisions — this repository's own immediate
adoption resolves to `disabled-legacy` via the ADR-0016 file-absence
fallback, since no `project-context.yaml` exists yet).

Planned Files:
- `plugins/sdd-quality-loop/scripts/check-component-coverage.py` (new,
  agent-editable — three-state derivation from
  `workflow.capability_enforcement`/`disabled-legacy`; all six Fail
  conditions; `emit-run-record`-conformant `check-component-coverage-verdict/v1`
  evidence with `producer.sha256` in every state; design.md Data Plan.
  BECOMES protected once registered — its content is not written via
  human-copy, only its `PROTECTED_GATE_SUFFIXES` registration is)
- `plugins/sdd-quality-loop/scripts/check-component-coverage.sh` (new,
  agent-editable — thin wrapper; BECOMES protected once registered)
- `plugins/sdd-quality-loop/scripts/check-component-coverage.ps1` (new,
  agent-editable — twin; BECOMES protected once registered)
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.py` (existing,
  agent-editable — adds the non-Gate `resolve-component-paths --diagnose`
  subcommand, Fail-1/3/5/6-conditional only, never Gate-invoked)
- `tests/check-component-coverage.tests.sh` (new, agent-editable)
- `tests/check-component-coverage.tests.ps1` (new, agent-editable)
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md` (existing,
  agent-editable — UNPROTECTED direct edit: adds `check-component-coverage`
  to the `high`/`critical` machine-form required-check-set)
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (existing,
  agent-editable — UNPROTECTED `## Process` edit documenting the new check;
  defense-in-depth, not the reachability guarantee, INV-005)
- **Bundle A (situation 1, human-copy staged — content protection, six
  files):**
  - `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json`
  - `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
  - `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
  - `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js`
  - `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1`
  - `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh`
- **Bundle B (situation 2, human-copy staged — reachability + producer-digest,
  three files):**
  - `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/check-contract.sh`
  - `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/check-contract.ps1`
  - `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/check-contract.py`
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended after
  T-003's; R-10 protected real path)
- `specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256` (existing,
  agent-editable — nine new entries: Bundle A's six + Bundle B's three; plus
  this task's `test.yml` entry)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #191)

Data Migration: none — the `check-component-coverage-verdict/v1` evidence
record is a net-new additive shape (design.md Data Plan).

Breaking API: no; `check-component-coverage` is a wholly new script; the
`check-contract`/`guard-invariants.json` edits are additive (one more
required-check id, three more protected suffixes, one more validation pass)
and narrow acceptance rather than loosening it.

Rollback: revert this task's two commits; the new scripts and suites are
additive and independently revertible. The nine staged protected candidates
and `.github/workflows/test.yml` are NEVER part of the agent's own commit
history (human-applied only) — a revert PR must separately state whether any
already-human-applied protected-file change should also be hand-reverted,
and by whom.

### Goal

Author `check-component-coverage.{py,sh,ps1}`: always run to completion and
always emit an `emit-run-record`-conformant `check-component-coverage-verdict/v1`
evidence record carrying `producer.sha256`, deriving one of three states
from `workflow.capability_enforcement`/`disabled-legacy` (ADR-0016) —
`disabled-legacy` (zero evaluation, real N/A record, exit 0), `advisory`
(Facet Manifest required, hard error if missing/unreadable, full
six-Fail-condition evaluation + recording, always exit 0), `required`
(identical evaluation, exit non-zero iff a Fail condition triggers) — never
Facet-Manifest-file-presence-selected, never merging `advisory` into
`required`'s blocking strength. Implement all six Fail conditions (Fail-2/4
mutual exclusivity, Fail-5's `EXCLUDED_MATCH`-driven Gate reachability,
Fail-6's `adapter_paths` rule). Add the non-Gate `resolve-component-paths
--diagnose` subcommand. Register the check: directly in `risk-gate-matrix.md`
and `quality-gate/SKILL.md`'s `## Process`; via human-copy in
`guard-invariants.json` + `generate-guard-invariants.py` + generated
siblings (Bundle A) and `check-contract.{sh,ps1,py}` (Bundle B, adding the
producer-digest verification pass).

### Must Read

- `specs/epic-191-a3-path-ownership/requirements.md`
- `specs/epic-191-a3-path-ownership/design.md`
- `specs/epic-191-a3-path-ownership/acceptance-tests.md`
- `specs/epic-191-a3-path-ownership/security-spec.md`
- `docs/adr/0016-workflow-axes-separation.md` (the three-state derivation
  source, lines 30-39, 56-75, 90-93 — never file presence)
- `docs/adr/0019-approval-sidecar-protection.md:70-77,96-103` (the two-tier
  defense-claim scope AC-035/AC-055's claims must not exceed)
- `plugins/sdd-quality-loop/references/guard-invariants.json` (re-verify
  `protected_gate_suffixes` before staging Bundle A)
- `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:37-56,129-147`
  (`PHASE2_TARGETS` and `load_and_validate()`'s exact-match check that
  forces the generator edit, INV-015)
- `plugins/sdd-quality-loop/scripts/check-contract.py:37-42,127-157` (the
  tier-minimum set with no capability-state axis, INV-018)
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md:80-92` (the
  machine-form required-check-set kept equal to `check-contract`)
- `specs/epic-136-phase2-gates/human-copy/` (the established human-copy
  staging + `MANIFEST.sha256` procedure this task follows)
- `plugins/sdd-quality-loop/scripts/emit-run-record.sh:19-21` (the
  `schema`-tagging convention the verdict record reuses, INV-019)

### Scope

Commit A (implementation — Gate + diagnose + suite + protected staging + CI
wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-026 (applicability
  derived, present-manifest-but-`disabled-legacy` still records
  `disabled-legacy`), TEST-027 (`disabled-legacy` truthful non-evaluation +
  real record), TEST-028 (manifest-required hard error), TEST-029
  (`--diagnose` never Gate-invoked), TEST-030 (one fixture per Fail-1..Fail-6,
  identical in `advisory`/`required`), TEST-031 (Fail-2/Fail-4 mutual
  exclusivity), TEST-032 (Fail-5 Gate-level reachability), TEST-033/TEST-034
  (Fail-6 `adapter_paths` rule + N/A-when-absent), TEST-052 (`advisory`
  non-blocking), TEST-053 (`required` blocking), TEST-054 (evidence producer
  binding + `emit-run-record` conformance across all three states), TEST-055
  (`check-contract` producer-digest verification), TEST-035 (reachability —
  SKILL.md-deletion/script-rename still fails the `high`/`critical` Gate,
  scoped to the two-tier footgun/tamper-evidence claim), TEST-036
  (protected-suffix + generator-inventory registration proof), and TEST-046
  (the `contracts/**` bounded-shared Fail-4 fixture, REQ-007).
- CI resilience per Global Constraints; each Facet Manifest / Provider
  Bindings fixture is a standalone JSON/YAML object (Epic A4's/A1's real
  schema files are NOT required to exist).
- Add the `resolve-component-paths --diagnose` subcommand.
- Directly edit `risk-gate-matrix.md` and `quality-gate/SKILL.md`'s
  `## Process`.
- Stage Bundle A (six files), Bundle B (three files), and this suite's
  `test.yml` step under `human-copy/` + `MANIFEST.sha256`; re-verify
  `generate-guard-invariants.py --check` exits 0 against a staged copy of the
  tree with all six Bundle-A candidates overlaid.
- Register `check-component-coverage` in `tests/run-all.sh`/`.ps1`.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #191.

### Done When

- [ ] **Applicability derivation** — TEST-026..029 pass: applicability is
  derived from `capability_enforcement` (never Facet-Manifest presence) and
  the `disabled-legacy` truthful-non-evaluation record (AC-026, AC-027); the
  manifest-required hard error in `advisory`/`required` (AC-028); `--diagnose`
  is never Gate-invoked (AC-029).
- [ ] **Six Fail conditions** — TEST-030..034/046 pass: one dedicated
  fixture per Fail-1..Fail-6, identical in `advisory` and `required`
  (AC-030); Fail-2/Fail-4 mutual exclusivity (AC-031); Fail-5 Gate-level
  reachability (AC-032); the Fail-6 `adapter_paths` rule and
  N/A-when-absent case (AC-033, AC-034); the `contracts/**` bounded-shared
  out-of-enumeration Fail-4 fixture (AC-046).
- [ ] **Blocking behavior + evidence/tamper-evidence proofs** — TEST-052..055
  pass: `advisory` non-blocking exit-0-despite-trigger (AC-052); `required`
  blocking exit-non-zero-iff-trigger (AC-053); every evidence record (all
  three states) carries `schema`, `check_id`, and a live-computed
  `producer.sha256` (AC-054); `check-contract`'s producer-digest
  verification rejects a substituted-script + stale/unrelated-evidence
  pairing (AC-055).
- [ ] **Reachability + registration proofs** — TEST-035/036 pass: the
  reachability claim (SKILL.md-deletion/script-rename + mismatched-digest
  evidence still fails the `high`/`critical` Gate), scoped to the two-tier
  defense boundary (AC-035); the protected-suffix + generator-inventory
  registration (staged six-file candidate set + correct `MANIFEST.sha256`;
  `generate-guard-invariants.py --check` exits 0 against the staged tree;
  live files byte-identical before/after; post-human-copy self-registration
  grep confirms the three `check-component-coverage.*` entries) (AC-036).
- [ ] **HUMAN APPLY STEP — Bundle A (situation 1, content protection, six
  files):** a human maintainer runs `cp` for each of
  `guard-invariants.json`, `generate-guard-invariants.py`,
  `generated/guard_invariants.py`, and the three
  `generated/guard-invariants.generated.{js,ps1,sh}` siblings from
  `human-copy/`, verifies each file's SHA-256 against `MANIFEST.sha256`, and
  runs `generate-guard-invariants.py --check` against the applied tree
  (exit 0) — confirmed before this task is marked Done.
- [ ] **HUMAN APPLY STEP — Bundle B (situation 2, reachability +
  producer-digest, three files):** a human maintainer runs `cp` for
  `check-contract.sh`, `check-contract.ps1`, and `check-contract.py` from
  `human-copy/`, verifies each file's SHA-256 against `MANIFEST.sha256`, and
  confirms `check-component-coverage` is present in the applied
  `high`/`critical` tier-minimum set and the producer-digest pass is active
  — confirmed before this task is marked Done. (A partial application — one
  bundle applied, the other not — is detectable via the manifest, never
  silently assumed complete.)
- [ ] **Suite/CI registration + governance** —
  `tests/check-component-coverage.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`; the staged `test.yml` candidate exists with a
  correct `MANIFEST.sha256` entry and the LIVE `test.yml` is byte-unchanged
  before/after this task's commits; `CHANGELOG.md` gains a NEW
  `## Unreleased` entry citing #191 (AC-048 share); a grep self-check
  confirms no version string was mutated outside `scripts/bump-version.sh`
  (AC-049 share).
- [ ] **TDD evidence** — RED (each Fail condition, the producer-digest
  rejection, and the registration proofs against deliberately broken
  fixtures) and GREEN (the full suite + the human-copy `--check` exit-0
  proof). An independent quality-gate verdict records PASS, including
  confirmation that both human-copy bundles have been applied and verified.

Note on scope breadth (task-review round 1, TASK-SIZE): this task's six work
areas (three-state Gate logic + six Fail conditions, `--diagnose`, direct
`risk-gate-matrix.md`/`SKILL.md` edits, Bundle A staging, Bundle B staging,
CI registration) are not a Phase-2 decomposition choice — design.md's own
Global Constraints are explicit that T-004 is the SOLE editor of both
protected-file bundles ("T-004 is the sole editor (via human-copy) within
this feature" / "T-004 is the sole editor of both"), precisely to avoid a
human-copy staging race across tasks; splitting this work across multiple
tasks would reintroduce that race and contradict the frozen
(Impl-Review-Status: Passed) design.md. The two independent HUMAN APPLY
STEPs above (Bundle A, Bundle B) are already kept as separate, individually
verifiable Done-When items rather than merged, and the two-commit landing
plan (Global Constraints) keeps the CHANGELOG entry in its own commit B,
separate from the Gate/registration implementation in commit A.

### Out of Scope

- The resolver core / classification (T-001), the diff collector (T-002),
  `ownership_digest` (T-003), the cross-epic seed-inventory validation
  (T-005), and the parity harness (T-006).
- Reimplementing any canonicalizer, Facet Manifest schema, or Provider
  Bindings schema (Non-goals); Fail-6 never reads a `credentials` block.
- Any change to `sdd-hook-guard.*`'s own enforcement logic — this task edits
  only protected data/policy files the existing guard/gate scripts read.

### Blockers

T-001, T-002, T-003

(Additional external precondition, not an in-spec blocker: full
`advisory`/`required`-mode evaluation needs Epic A4's Facet Manifest as a
real artifact; the `disabled-legacy` mode ships independently — see Depends
On.)

---

## T-005 Validate the cross-epic cross-cutting seed inventory (single canonical source)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/191

Approval: Approved (sudo 2026-07-22T15:40:55Z)

Status: Blocked

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task adds fail-closed cross-epic
validation logic (a day-one integration fixture that reads Epic A1's
`contracts/project-context.template.yaml` directly and FAILS closed while it
is absent or divergent), a behavioral test contract other adopters depend
on — above `low` (it is not cosmetic/non-behavioral). Its blast radius is
bounded: a defect surfaces as a spurious/absent Fail-1 on ordinary day-one
changes, not an access-control or Gate-bypass surface, so it does not reach
`high`. It authors no production script and no new suite (it shares T-001's
resolver suite and fixture). Required Workflow is `acceptance-first` per the
policy's medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-006, REQ-007 (share), REQ-008 (share)

Depends On: T-001 (functional — shares T-001's `component-path-resolver`
suite and fixture tree; adds cases rather than a new suite, design.md Global
Constraints "T-005 shares T-001's fixture, no new suite of its own"). No new
`tests/run-all.sh`/`.ps1` or `.github/workflows/test.yml` entry (no new
suite). **The day-one/inventory fixtures are written to FAIL closed (block)
while Epic A1's `contracts/project-context.template.yaml` is absent from the
repository, never passing via a stand-in** — re-verify the artifact's
presence at implementation-start time (AC-042, AC-044, requirements.md
Dependencies).

Planned Files:
- `tests/component-path-resolver.tests.sh` (existing after T-001,
  agent-editable — adds the AC-042/AC-043/AC-044 cross-epic cases)
- `tests/component-path-resolver.tests.ps1` (existing after T-001,
  agent-editable — twin)
- `tests/fixtures/component-path-ownership/` (existing, agent-editable —
  adds the cross-epic day-one fixture that reads Epic A1's
  `contracts/project-context.template.yaml` directly, and the six-entry
  cross-cutting set fixture: `specs/**`, `reports/**`, `docs/**`,
  `.github/**`, `tests/fixtures/**`, `CHANGELOG.md`; `contracts/**`
  deliberately excluded)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #191)

Data Migration: none.

Breaking API: no; test/fixture-only additions to an existing suite.

Rollback: revert this task's two commits; nothing protected is touched, no
new suite registration to unwind.

### Goal

Extend `component-path-resolver.tests.sh`/`.ps1` with the cross-epic
seed-inventory validation: a fixture that reads Epic A1's shipped
`contracts/project-context.template.yaml` directly and asserts its
`shared_paths` cross-cutting entries are exactly the six-entry set
(`specs/**`, `reports/**`, `docs/**`, `.github/**`, `tests/fixtures/**`,
`CHANGELOG.md`) with `contracts/**` absent (a missing/extra/mis-classified
entry each fails); the no-op proof that a diff confined to those six entries
with zero declared owners never trips Fail-1; and the day-one integration
proof that a `project-context.yaml` shaped like that template does not trip
Fail-1 on an ordinary `specs/**`/`reports/**` change. All fixtures FAIL
closed while A1's template is absent — never a stand-in. A3 authors no
competing seed-list document of its own.

### Must Read

- `specs/epic-191-a3-path-ownership/requirements.md`
- `specs/epic-191-a3-path-ownership/design.md`
- `specs/epic-191-a3-path-ownership/acceptance-tests.md`
- `tests/component-path-resolver.tests.sh` (T-001's suite this task extends)
- `tests/fixtures/component-path-ownership/` (T-001's fixture tree this task
  extends)
- `contracts/project-context.template.yaml` (Epic A1's artifact — re-verify
  presence at implementation-start time; the fixture FAILS closed while
  absent)

### Scope

Commit A (implementation — cross-epic cases + fixtures):
- Write the acceptance checks first (acceptance-first): TEST-042 (inventory
  conformance, single source of truth, FAIL-closed on absence/divergence),
  TEST-043 (no-op proof for the six-entry set), TEST-044 (day-one cross-epic
  integration proof, FAIL-closed while A1's template is absent).
- CI resilience per Global Constraints.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #191.

### Done When

- [ ] TEST-042 proves the cross-epic inventory conformance (exact six-entry
  cross-cutting set, `contracts/**` absent, FAIL-closed on missing artifact
  or any divergence) (AC-042).
- [ ] TEST-043 proves a diff confined to the six-entry set with zero
  declared owners never triggers Fail-1 (AC-043).
- [ ] TEST-044 proves the day-one cross-epic integration (template-shaped
  config prevents Fail-1 on an ordinary day-one change; FAIL-closed while
  A1's artifact is absent) (AC-044).
- [ ] The new cases live inside T-001's already-registered
  `component-path-resolver` suite (no new `run-all`/`test.yml` entry — grep
  self-check confirms no duplicate registration).
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #191
  (AC-048 share).
- [ ] A grep self-check confirms no version string was mutated outside
  `scripts/bump-version.sh` (AC-049 share).
- [ ] Acceptance-first evidence recorded: RED (the fixture red while A1's
  template is absent/divergent, and against a deliberately wrong seed set)
  and GREEN (once A1's template lands and matches). An independent
  quality-gate verdict records PASS.

### Out of Scope

- Authoring any A3-owned seed-list document (`default-shared-paths.md` is
  withdrawn, REQ-006) or implementing Epic A1's bootstrap flow (Non-goals).
- A new test suite of its own, or any `run-all`/`test.yml` edit.
- Any protected-file edit.

### Blockers

T-001

(Additional external precondition, not an in-spec blocker: Epic A1's
`contracts/project-context.template.yaml` must land and match the six-entry
set for TEST-042/TEST-044 to go green — until then these fixtures are
deterministically red, per Depends On.)

---

## T-006 Author the dual-runtime parity harness and the whole-feature registration audit

Source Issue: https://github.com/aharada54914/sdd-forge/issues/191

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified, not merely asserted, by the same reasoning
`specs/epic-159-pillar-c/tasks.md` applied to its own behavior-preservation
proof (T-005 there, high/`tdd`): a vacuously-green parity harness would mask
a real cross-runtime defect (a `.ps1` wrapper silently dropping an argument
or mishandling `$LASTEXITCODE`) across BOTH product wrapper pairs this
feature ships — a silent defect causing material harm (CI passes while the
two runtimes diverge), which the mutation-based negative self-check is the
only live proof against. This task also owns the whole-feature registration
+ fixture-tree closing audit (AC-047) across all five suites and interacts
with the protected `.github/workflows/test.yml` registration surface. It is
not `critical` (no settlement/safety/irreversible surface). Required
Workflow is `tdd` per the policy's high-tier row, with the negative
self-check as the Red evidence.

Required Workflow: tdd

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-009, REQ-007 (share — the whole-feature suite-registration
+ 6-case + fixture-tree audit, AC-047), REQ-008 (share)

Depends On: T-001, T-002, T-003, T-004 (functional — both product wrapper
pairs must be functionally complete: `resolve-component-paths.{sh,ps1}`
(T-001/T-002/T-003) and `check-component-coverage.{sh,ps1}` (T-004)).
Terminal in the shared `tests/run-all.sh`/`.ps1` and
`.github/workflows/test.yml` serialization (T-001 → T-002 → T-003 → T-004 →
T-006, Global Constraints).

Planned Files:
- `tests/component-path-ownership-parity.tests.sh` (new, agent-editable)
- `tests/component-path-ownership-parity.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration,
  terminal)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration,
  terminal)
- `specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended after
  T-004's; R-10 protected real path)
- `specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry for this task's staged `test.yml` candidate)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #191)

Data Migration: none.

Breaking API: no; test-only additions.

Rollback: revert this task's two commits; nothing protected is written
directly (a revert PR states whether an already-applied `test.yml` step
should be hand-reverted).

### Goal

Author `component-path-ownership-parity.tests.sh`/`.ps1`: feed identical
fixture + argv DIRECTLY to each product wrapper pair
(`resolve-component-paths.{sh,ps1}`, `check-component-coverage.{sh,ps1}` —
the only two pairs this feature ships) and diff, byte-for-byte, the canonical
normalized-stdout-JSON form (parse, re-serialize with object keys sorted at
every nesting level, arrays in original order, no trailing whitespace),
exit code, WARN/error category strings, and argv pass-through (including an
extra/unrecognized argument and, on the PowerShell side, `$LASTEXITCODE`) —
between each wrapper's two runtimes directly, never a suite-twin-to-suite-twin
comparison. Include the mutation-based negative self-check (a fixture where
the `.ps1` wrapper alone drops an argument or mishandles `$LASTEXITCODE`
must turn the harness red even when each wrapper independently passes its
own same-language suite). Perform the whole-feature registration +
fixture-tree closing audit (AC-047).

### Must Read

- `specs/epic-191-a3-path-ownership/requirements.md`
- `specs/epic-191-a3-path-ownership/design.md` (Test Strategy — the
  "Canonical normalized stdout JSON form" definition)
- `specs/epic-191-a3-path-ownership/acceptance-tests.md`
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.sh`/`.ps1` and
  `plugins/sdd-quality-loop/scripts/check-component-coverage.sh`/`.ps1` (the
  two product wrapper pairs this harness drives directly)
- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:1-20`
  (re-verify `.github/workflows/test.yml`'s protected status before staging)
- `tests/run-all.sh`/`.ps1` and the staged `human-copy/.github/workflows/test.yml`
  (the five-suite registration surfaces this task's AC-047 audit spans)

### Scope

Commit A (implementation — parity harness + registration audit + CI wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-050 (product-wrapper-direct
  parity of both pairs, with the mutation-based negative self-check as the
  live-ness proof), TEST-051 (parity-harness registration), TEST-047 (the
  whole-feature registration grep for all five suites + `.github/workflows/test.yml`
  human-copy proof + the six named cases' positive/red-then-fixed coverage +
  the fixture tree carrying the four submodule/symlink fixtures, the
  NFC-collision fixture, and one fixture per glob clause id).
- CI resilience per Global Constraints.
- Register `component-path-ownership-parity` in `tests/run-all.sh`/`.ps1`
  (terminal); stage the `test.yml` candidate appended to T-004's staged file.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #191.

### Done When

- [ ] TEST-050 proves byte-for-byte product-wrapper-direct parity (canonical
  JSON, exit code, WARN/error category, argv pass-through incl.
  `$LASTEXITCODE`) for both wrapper pairs, and the mutation-based negative
  self-check turns red on a `.ps1`-only argument-drop / `$LASTEXITCODE`
  defect even when both wrappers independently pass their own suites
  (AC-050).
- [ ] TEST-051 proves the parity harness self-registers in
  `tests/run-all.sh`/`.ps1` and is staged into `.github/workflows/test.yml`
  via human-copy (AC-051).
- [ ] TEST-047 proves the whole-feature audit: all five suites registered in
  `run-all` + `test.yml` (human-copy), each of overlap/unowned/rename/
  untracked/exclude-misuse/shared-undeclared with ≥1 positive and ≥1
  red-then-fixed case across the suites, and the fixture tree carrying the
  four submodule/symlink fixtures, the NFC-collision fixture, and one fixture
  per glob clause id (AC-047).
- [ ] The staged `.github/workflows/test.yml` candidate exists with a correct
  `MANIFEST.sha256` entry and the LIVE `test.yml` is byte-unchanged
  before/after this task's commits.
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #191
  (AC-048 share).
- [ ] A grep self-check confirms no version string was mutated outside
  `scripts/bump-version.sh` (AC-049 share).
- [ ] TDD evidence recorded: RED (the negative self-check against a
  deliberately divergent `.ps1` wrapper fixture, turning the harness red) and
  GREEN (both wrapper pairs parity-identical against the real wrappers). An
  independent quality-gate verdict records PASS.

### Out of Scope

- Any change to the product wrappers themselves (T-001/T-002/T-003/T-004) —
  this task only drives and compares them.
- Any protected-file edit beyond staging this suite's own `test.yml` CI-step
  candidate.

### Blockers

T-001, T-002, T-003, T-004
