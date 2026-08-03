# Tasks: epic-189-a1-project-context

Task-Review-Status: Passed

Source: Issue #189 (Epic A1 — "Project Context + 承認防衛"), tracked under epic
#187 (AI-DLC Foundation) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation
Complete`. Only `quality-gate` may set `Done`. **Every task below carries
`Approval: Draft` and `Status: Planned` — none carries an approved
designation. Changing a task's Approval field is a human-only action,
performed by editing the file directly; this package never performs it.**

## Protected Files

Nine files this epic's tasks touch are already R-10 enforcement-chain
protected (verified directly against
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`, which
`sdd-hook-guard.py:891`'s `_load_guard_invariants()` loads, at
task-authoring time — design.md Protected-File Statement):
`plugins/sdd-quality-loop/references/guard-invariants.json`,
`plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`, the four
`generated/guard_invariants.{py,js,ps1,sh}` files,
`plugins/sdd-ship/skills/ship/SKILL.md`,
`plugins/sdd-lite/skills/lite-spec/SKILL.md`, and
`.github/workflows/test.yml`. **No task below writes any of these nine
files directly.** T-009 stages the six guard-invariants files; T-012 stages
`ship/SKILL.md` and `lite-spec/SKILL.md`; every task registering a new test
suite stages its own `.github/workflows/test.yml` addition. Every staged
file goes under
`specs/epic-189-a1-project-context/human-copy/<repository-relative-path>` +
a `MANIFEST.sha256` entry (design.md's single canonical
`PROTECTED-MANIFEST.md`, staged by T-009).

This epic ALSO builds `apply-human-copy.sh`/`.ps1` (T-007, REQ-007) — the
anchored-publisher-equivalent tool every other task's staged artifact is
applied through (design.md Global Constraints) — and BECOMES itself a
concrete `PROTECTED-MANIFEST.md` entry once T-009's registration lands,
after exactly one human-verified bootstrap `cp` (design.md Protected-File
Statement, "Publisher self-protection", B9). Before T-009 lands,
`apply-human-copy.{sh,ps1}` is an ordinary, agent-editable file; T-009's
human-apply step is what makes it, and the 24 concrete + 4 reserved paths
listed in the staged `PROTECTED-MANIFEST.md`, protected going forward. This
epic does not extend or reuse
`specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1` (pinned
to its own frozen bootstrap inventory, out of this epic's edit scope,
design.md INV-011).

**Re-verification discipline** (requirements.md Assumptions): every task
whose Planned Files include an already-protected path re-runs
`grep -F "<path>" plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
at its own implementation-start time before assuming the human-copy
procedure is still required.

## Global Constraints

- **Two-commit landing plan per task** (commit A = implementation +
  unprotected registrations + staging of any protected-file candidates;
  commit B = `CHANGELOG.md` entry + applicable doc surfaces), mirroring
  epic-159-pillar-c's established convention (design.md Technical
  Summary). Commit A must land before commit B within the same task.
- **`tests/run-all.sh` / `.ps1`** (unprotected, direct edit): every task
  below that registers a new suite appends ONLY its own suite's
  registration lines, in this task list's own numeric order (T-001 through
  T-012 — every task except T-013, the closing audit, which registers no
  new suite of its own — one array-append per task, landed in serialized,
  per-task commits). **This numeric-order serialization is enforced
  machine-checkably, not merely by convention**: every one of T-001..T-012
  declares the immediately-preceding numeric-order task among its
  `Blockers:` (directly, or transitively through another declared
  blocker — e.g. T-006 blocks on T-005, which itself blocks on T-004, which
  blocks on T-003, and so on back to T-001), so no two of these twelve
  tasks can be scheduled out of order or in parallel against this shared
  file (round-1 task-review remedy — closes reviewer-b's round-1
  SCOPE-DISJOINT/DEPENDENCY-OVERLAP findings, `--edit-summary` below).
- **`.github/workflows/test.yml`** (R-10 protected): the same tasks each
  stage their own registration addition via human-copy, in the SAME
  numeric order, under
  `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  + a shared, task-appended `MANIFEST.sha256`.
- **`plugins/sdd-quality-loop/references/guard-invariants.json`,
  `generate-guard-invariants.py`, `generated/guard_invariants.*`**: T-009
  is the SOLE editor within this epic (design.md Global Constraints); no
  other task stages a competing edit.
- **`apply-human-copy.{sh,ps1}`**: T-007 is the sole author. Every OTHER
  task's staged human-copy artifact (T-003's sidecar+anchor publication,
  T-012's `ship`/`lite-spec` edits, every suite's `test.yml` registration)
  is APPLIED using this tool once it exists; no other task edits the tool
  itself (design.md Global Constraints).
- **`PLUGIN-CONTRACTS.md`**: T-011 is the sole editor.
- **`sdd/.staging/`** (unprotected, T-003) and **`sdd/.hook-canary-sentinel`**
  (protected once T-009 lands, T-008/T-010): neither path is ever targeted
  by more than its own task; no task ever authors real, committed content
  for the sentinel path — its only legitimate occupant is the handshake's
  own transient hook-inactive detection branch at test/run time (design.md
  Global Constraints, REQ-010 Design Decisions).
- **`sdd/.staging/*/TRANSACTION.json`** (unprotected, T-007, REQ-007): written
  and deleted ONLY by `apply-human-copy` itself; no task, script, or test
  fixture ever authors or edits this path directly — a fixture proving
  recovery correctness drives it only through `apply-human-copy`'s own CLI
  (design.md Global Constraints).
- **Version bumps only via `scripts/bump-version.sh`**; no task in this
  epic introduces a version-mutation path or executes a real release.
- **`CHANGELOG.md`'s `## Unreleased` section** — each task adds its own
  entry citing issue #189; tasks append distinct entries, never edit
  another task's entry in place.
- CI-resilience (bash 3.2 empty-array safety under `set -u`; macOS
  `$TMPDIR` `pwd -P` normalization; Windows `jq.exe` CRLF stripping; no
  real-validator-gate probing) applies to every new `.sh` suite this epic
  adds (design.md Test Strategy item 12).
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Author the project-context.yaml and provider-bindings.yaml schemas

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (sudo 2026-07-22T14:31:01Z)

Status: Blocked

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md:15`
directly. `medium` is justified: (1) both schema artifacts and the
template scaffold are wholly new, additive files with no existing consumer
to break; (2) no existing script, skill, or contract is edited; (3) no
secrets, authentication, or irreversible operation is touched. It does not
reach `high` because nothing this task adds is yet CONSUMED by runtime
code (T-002 onward are the first consumers) and no existing validation is
loosened.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-002

Depends On: none (root of the dependency graph; design.md Technical
Summary: "REQ-001/REQ-002 ... are consumed by REQ-003 ... and by REQ-009").

Planned Files:
- `contracts/project-context.schema.json` (new, agent-editable — schema id
  `sdd-project-context/v1`, design.md API/Contract Plan)
- `contracts/project-context.template.yaml` (new, agent-editable —
  single-source cross-cutting seed-list scaffold, design.md Data Plan;
  `shared_paths` pre-populated with the six canonical patterns:
  `specs/**`, `reports/**`, `docs/**`, `.github/**`, `tests/fixtures/**`,
  `CHANGELOG.md`, each `classification: cross-cutting`)
- `contracts/provider-bindings.schema.json` (new, agent-editable — schema
  id `sdd-provider-bindings/v1`, skeleton only, design.md API/Contract
  Plan)
- `tests/project-context-schema.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this suite's
  registration, first in numeric order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (new staged candidate, agent-editable — this suite's CI steps; R-10
  protected real path, human-copy only)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (new,
  agent-editable)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #189)

Data Migration: none.

Breaking API: no; all three files are wholly new.

Rollback: revert this task's two commits; the staged `test.yml` candidate
is a human-applied change — the revert PR states explicitly whether a
human should also hand-revert that step.

### Goal

Author `contracts/project-context.schema.json`, `contracts/provider-bindings.schema.json`,
and `contracts/project-context.template.yaml`. Prove field presence,
per-path allowlist coverage, provider-neutrality, duplicate-`id` rejection,
optional `adapter_paths` passthrough, and the template's six-pattern seed
inventory.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md` (API/Contract Plan; Data
  Plan; Field Requirement Matrix; Constraint Compliance)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-001..AC-004,
  AC-040..AC-042)
- `specs/epic-189-a1-project-context/investigation.md`
- `docs/adr/0016-workflow-axes-separation.md`
- `docs/adr/0018-provider-binding-separation.md`
- `docs/adr/0020-conditional-predicate-dsl.md`

### Scope

Commit A (implementation — schemas + template + fixtures + CI wiring):

- Write acceptance checks first: TEST-001 (parameterized schema conformance
  — one fixture per REQUIRED JSON Pointer in design.md's Field Requirement
  Matrix, each deleting exactly that pointer), TEST-002 (per-path
  allowlist coverage — all 8 ADR-0020 paths resolve to a schema field),
  TEST-003 (provider-bindings parameterized conformance + `state_authority`/
  `credentials` passthrough), TEST-004 (provider-neutrality — no fixed
  Provider enum), TEST-040 (`components[]`/`bindings[]` duplicate-`id`
  semantic-validator rejection — `DUPLICATE_COMPONENT_ID`/
  `DUPLICATE_BINDING_ID`), TEST-041 (`adapter_paths` optional array-of-glob
  passthrough, present and absent), TEST-042 (template conformance +
  six-pattern `shared_paths` presence check).
- CI resilience per Global Constraints.
- Register the new suite directly in `tests/run-all.sh`/`.ps1`; stage the
  `.github/workflows/test.yml` candidate under
  `specs/epic-189-a1-project-context/human-copy/` + `MANIFEST.sha256`.

Commit B (documentation):

- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #189.

### Done When

- [ ] TEST-001 proves schema field presence and the parameterized
  required-field rejection set (AC-001).
- [ ] TEST-002 proves all 8 ADR-0020 allowlist paths resolve against a
  schema field (AC-002).
- [ ] TEST-003 proves the provider-bindings parameterized conformance and
  passthrough behavior (AC-003).
- [ ] TEST-004 proves no fixed Provider enum exists (AC-004).
- [ ] TEST-040 proves duplicate-`id` rejection for both `components[]` and
  `bindings[]` at the semantic-validator layer (AC-040).
- [ ] TEST-041 proves `adapter_paths` validates present and absent
  (AC-041).
- [ ] TEST-042 proves `project-context.template.yaml` validates and its
  `shared_paths` contains all six canonical seed patterns (AC-042).
- [ ] `tests/project-context-schema.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`.
- [ ] Staged `.github/workflows/test.yml` candidate exists with a correct
  `MANIFEST.sha256` entry; the LIVE file's SHA-256 is unchanged before/after
  this task's commits (`sha256sum .github/workflows/test.yml` recorded
  before and after in the implementation report).
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #189.
- [ ] Acceptance-first evidence (acceptance checks written before/with the
  implementation, per risk-classification-policy.md:15) recorded in the
  implementation report; an independent quality-gate verdict (a named
  second reviewer, not the implementing agent) records PASS.

### Out of Scope

- Any consumer of these schemas (T-002 onward).
- The Reverse Coverage Gate / `check-component-coverage` (Epic A3).
- `contracts/approval-sidecar.schema.json` (T-003) and
  `contracts/approver-registry.schema.json` (T-004).

### Blockers

None

BLOCKED (2026-07-22, implementation session): every Done-When item this
task can perform directly is complete and independently verified
(`contracts/project-context.schema.json`,
`contracts/provider-bindings.schema.json`,
`contracts/project-context.template.yaml`,
`tests/project-context-schema.tests.sh`/`.ps1` — TEST-001/002/003/004/
040/041/042 all PASS, real run captured at
`specs/epic-189-a1-project-context/verification/T-001/acceptance-sh.log`
(exit=0, 41/41) and `.../acceptance-ps1.log` (exit=0, 41/41); both suites
registered in `tests/run-all.sh`/`.ps1`). The remaining Done-When item —
"Staged `.github/workflows/test.yml` candidate exists with a correct
`MANIFEST.sha256` entry" — cannot currently be produced: writing to
`specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
(via both the Write tool and `cp` through Bash) is denied by
`sdd-hook-guard.py`'s R-10 gate with "エージェントはゲートスクリプト・
フック設定・テストファイルを書き換えられません...sudo でもバイパスでき
ません" (confirmed not a sudo-bypassable checkpoint per
`plugins/sdd-quality-loop/references/sudo-mode-policy.md`'s own
"Deterministic gate scripts" enforced-list). Root cause, read directly:
`_is_protected_gate_file()` (`plugins/sdd-quality-loop/scripts/
sdd-hook-guard.py:976-990`) matches via pure path-suffix
`normalized.endswith(suffix.lower())` against
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`'s
`PROTECTED_GATE_SUFFIXES`, which contains the bare string
`'.github/workflows/test.yml'` with **no exemption for any
`specs/**/human-copy/**` staging prefix** — so the sanctioned staging
candidate path is indistinguishable from the live protected path to this
check. This is not scoped to T-001: every task in this epic that stages a
`test.yml` addition (T-001 through every suite-registering task) and
T-012 (`ship/SKILL.md`, `lite-spec/SKILL.md`) hits the identical suffix
match for their own staged candidates, since the same unconditional
suffix list applies. (A pre-existing precedent,
`specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml`
(commit `825d6c6`), shows this same path was staged successfully in the
past even though the identical suffix was already present in that
commit's own `guard_invariants.py` — the guard's Write/Edit-tool
enforcement for this exact case is not something this session was able
to explain from the history available; it may have been wired more
strictly since, or applied through a path this session's tool set does
not have.) No workaround was attempted (per this session's operating
constraints: a guard denial is reported, not routed around). Human
decision needed: (a) patch `_is_protected_gate_file()` to exempt
`specs/**/human-copy/**` staging prefixes (a guard change, itself outside
this task's edit scope and requiring its own review), (b) amend this
task's (and every sibling task's) Done When to defer `test.yml` staging
to a single later consolidated task performed via a channel outside this
guard's purview, or (c) some other resolution. `tasks/run-all.sh`/`.ps1`
registration (the unprotected half of the same Done-When item family) is
unaffected and already complete above.

UPDATE (2026-07-23, follow-up session): option (a) has been prepared and
pre-verified. The guard patch (bugs 1+2: human-copy staging exemption plus
token-based pre-filter), its verification evidence, and the human apply
procedure are recorded in `reports/implementation/
epic-189-a1-project-context/HUMAN-APPLY-STEPS.md` ("Guard fix" section),
with the git-apply-ready patch file beside it; a permanent regression
suite (`tests/guard-staging-exemption.tests.sh`, registered in
`tests/run-all.sh`) runs its invariant block now and its fix block once
the patch lands. The related workflow-state validator false positive on
`Status: Blocked` (bug 3 in HUMAN-APPLY-STEPS.md) was fixed directly in
the same follow-up session. This blocker remains open until a human
applies the patch; after application, complete the staged `test.yml` +
MANIFEST items per HUMAN-APPLY-STEPS.md.

Accepted-deviation record (decision-7 = A): specs/epic-189-a1-project-context/verification/T-001/sizing-accepted-deviation.md

---

## T-002 Author the canonicalizer (`canonicalize-sdd-yaml`)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (sudo 2026-07-22T15:16:57Z)

Status: Done

Risk: high

Risk Rationale: Touches a sensitive surface per
`risk-classification-policy.md:16` — this is the security-foundational
primitive every HMAC preimage (T-003) and every weakening-detector diff
(T-005) depends on for byte-stability; a defect here (e.g. an anchor/tag/
duplicate-key document silently accepted rather than rejected, or a
non-finite/out-of-range number silently normalized) would let an ambiguous
document's canonical hash diverge from a human reviewer's understanding of
its content — the exact class of harm ADR-0019's Context section
describes for the hash-recomputation Blocker attack.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003

Depends On: T-001 only for this task list's mandatory shared-file
numeric-order append serialization (Global Constraints) — this task's own
functional content (a generic YAML/JSON canonicalization primitive; design.md
Technical Summary treats REQ-003 as consuming REQ-001/REQ-002 only at the
content-instance level) has no compile-time dependency on the schema files
T-001 authors; the canonicalizer's own code takes an arbitrary content-file
path argument.

Planned Files:
- `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py` (new,
  agent-editable — becomes protected only after T-009)
- `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.sh` / `.ps1` /
  `.js` (new, agent-editable — thin dispatchers, `python3`/`python`
  resolution ONLY, mirroring `sdd-hook-guard.sh:1-53`'s dispatch shape but
  NOT its native-`.ps1`-fallback shape, design.md Constraint Compliance)
- `tests/canonicalize-sdd-yaml.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — second in
  numeric order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND to #189's entry)

Data Migration: none.

Breaking API: no; wholly new script.

Rollback: revert this task's two commits; nothing protected is touched yet
(this task's own outputs are not yet registered as protected — T-009 does
that later).

### Goal

Implement YAML 1.2 core-schema parsing with explicit anchor/alias/
custom-tag/duplicate-key/non-string-key/post-NFC-collision/out-of-range-number
rejection, NFC string normalization, and RFC 8785 (JCS) canonical JSON
serialization plus SHA-256 hashing, per design.md's canonicalization
procedure — one Python implementation with thin `sh`/`ps1`/`js`
dispatchers.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Canonicalization
  procedure; Design Decisions — parser library choice)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-005..AC-009,
  AC-037)
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh:1-53` (dispatcher
  shape to mirror)
- `.gitattributes:1-9` (existing line-ending normalization, non-overlapping
  defense)

### Scope

Commit A (TDD Red → Green):

- Red: write TEST-005 (4 rejection-category fixtures: anchor, alias,
  custom tag, duplicate key), TEST-006 (1.2 core-schema boolean-coercion
  avoidance), TEST-007 (NFC precomposed/decomposed fixture pair),
  TEST-008 (JCS golden byte sequence), TEST-009 (multi-runtime hash
  equality + dispatch-target proof for `.py`/`.sh`/`.ps1`/`.js`),
  TEST-037 (accepted-domain boundary vectors: multi-document rejection,
  non-string-key rejection, post-NFC duplicate-key collision, non-finite/
  out-of-range-number rejection, an RFC 8785 §3.2.2.3 numeric-formatting
  boundary vector, byte-exact stdout-framing + exit-code assertion for
  success and every rejection path) against a not-yet-implemented script;
  capture the failing run.
- Green: implement `canonicalize-sdd-yaml.py` plus the three dispatcher
  wrappers; capture the passing run.
- CI resilience per Global Constraints.
- Register the suite; stage the `test.yml` addition.

Commit B (documentation): APPEND to `CHANGELOG.md`'s #189 entry, noting the
canonicalizer's addition.

### Done When

- [ ] TEST-005 proves anchor/alias/custom-tag/duplicate-key rejection, one
  fixture per category, each with a category-specific diagnostic (AC-005).
- [ ] TEST-006 proves 1.2 core-schema boolean-coercion avoidance (AC-006).
- [ ] TEST-007 proves NFC-normalized byte/hash identity (AC-007).
- [ ] TEST-008 proves JCS-compliant canonical output against a golden byte
  sequence (AC-008).
- [ ] TEST-009 proves multi-runtime hash equality and dispatch-not-reimplement
  for `.py`/`.sh`/`.ps1`/`.js` (AC-009).
- [ ] TEST-037 proves the six accepted-domain boundary vectors independently
  (AC-037).
- [ ] Suite self-registers; `test.yml` staged correctly; live `test.yml`
  unchanged (SHA-256 recorded before/after).
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red (failing suite against no implementation) and Green (passing
  suite against the real script) evidence recorded in the implementation
  report; an independent quality-gate verdict (a named second reviewer)
  records PASS.

### Out of Scope

- HMAC signing (T-003).
- Any consumer wiring (T-003, T-005).

### Blockers

T-001

(satisfied — its shared-file edits to `tests/run-all.sh`/`.ps1`
landed in commit `4bd2ec3`).

BLOCKED (2026-07-22, implementation session, before any code was
written): design.md's own "Design Decisions" section (parser library
choice, ~line 1279-1291) explicitly decides "use a standard library
(`PyYAML` or `ruamel.yaml`, confirmed available at a future
implementation session)" over a hand-rolled 1.2-core-schema parser,
specifically FOR the security reason this task's own Risk Rationale
states (an ambiguous/malformed document must never be silently accepted).
At this implementation session, neither is available: `python3 -c "import
yaml"` and `python3 -c "import ruamel.yaml"` both raise
`ModuleNotFoundError`; `pip3 show pyyaml`/`pip3 show ruamel.yaml` both
report "Package(s) not found". No `requirements.txt`/`pyproject.toml`/
`setup.py`/`Pipfile` exists anywhere in this repository (checked
repo-wide), and a repo-wide grep of every existing `.py` file under
`plugins/`+`scripts/` shows every single one imports only Python stdlib
modules — this would be the first third-party Python dependency this
tool has ever had. This is not a routine approval checkpoint sudo can
pass: it is exactly the "architecture... decision" class
`implement-task/SKILL.md`'s Block-And-Stop section names, for the
single most security-sensitive component in this epic (every later HMAC
preimage (T-003) and weakening-detector diff (T-005) depends on this
task's byte-stability guarantee). Silently substituting a hand-rolled
parser would override an explicit, already-impl-reviewed design decision
by guessing; silently adding a new pip dependency would make an
unauthorized packaging/distribution decision for a tool installed by
end users via a Claude Code plugin. Human decision needed: (a) accept
PyYAML/ruamel.yaml as this tool's first-ever third-party Python
dependency (and decide how it gets installed for end users — a real
packaging change outside this task's own scope), (b) revise design.md to
authorize a hand-rolled parser after all (itself requiring the frozen
design.md to be amended and likely re-run through impl-review), or (c)
some other resolution. **This blocks T-002's own further work
completely (no Scope items were started — this was found while
completing Required Reading, before any Red/Green TDD work began) and
transitively blocks every downstream task that consumes the
canonicalizer's actual function** (T-003 HMAC preimage, T-005 diffing,
and everything chained after them: T-006 through T-010, T-012) — this is
architecture-critical for the whole epic, not T-002-local.

UNBLOCKED (2026-07-29, implementation session): human decision-3 = B
resolved the parser-library question — design.md's Design Decisions and
Canonicalization procedure sections were amended (REVISED 2026-07-24) to
require a HAND-WRITTEN, stdlib-only, restricted YAML-subset parser (no
PyYAML/ruamel.yaml, no `requirements.txt`, no packaging change), recorded
in `reports/notes/epic-189-a1-decision-3-yaml-parser.md`, and the amended
design.md re-passed impl-review (attempt-3, PASS clean) plus a
post-implementation provenance re-review. This session resumes T-002 from
its Scope's Red step under that resolved design.

STAGING DEFERRED (2026-07-29, same implementation session, after TDD
Green): `canonicalize-sdd-yaml.py`/`.sh`/`.ps1`/`.js`,
`tests/canonicalize-sdd-yaml.tests.sh`/`.ps1`, and this suite's direct
`tests/run-all.sh`/`.ps1` registration are all complete — TDD Red
(`bash` 19/29, `pwsh` crashes without the implementation present) →
Green (`bash` 29/29, `pwsh` 26/26) captured for both runtimes at
`specs/epic-189-a1-project-context/verification/T-002/`. The remaining
Done-When item — staging this suite's `.github/workflows/test.yml`
addition under `specs/epic-189-a1-project-context/human-copy/` +
`MANIFEST.sha256` — is DEFERRED, not blocked: `git status` shows
`specs/epic-189-a1-project-context/human-copy/` as an untracked,
uncommitted directory at this session's start, already containing a
`.github/workflows/test.yml` candidate + `MANIFEST.sha256` (T-001's and
T-004's own staged registrations) from a concurrent session's staging
flow that this session did not author and has not seen committed. Per
this session's own operating constraints, appending to or committing
those uncommitted foreign files risks corrupting or silently dropping
that other session's in-flight work, so this task defers ONLY that
staging sub-item (mirroring T-001's own "CI staging deferred" precedent
above, though for a different underlying reason: a concurrent-session
working-tree conflict here, a guard denial there) — every other Scope
item and Done-When item is complete. The intended staged addition (two
new CI steps, `canonicalize-sdd-yaml.tests.sh`/`.ps1`, inserted directly
after T-001's `project-context-schema` steps and before T-004's
`approver-registry-schema` steps, matching this suite's `tests/run-all.sh`/
`.ps1` position) is recorded in
`reports/implementation/epic-189-a1-project-context/T-002.md` for
whichever session next finds `human-copy/` clean or committed. Live
`.github/workflows/test.yml` SHA-256 unchanged this session (never
written): `3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4`
(recorded before and after this session's work; identical to T-004's own
recorded value above, confirming no session has touched the live file
since).

QUALITY-GATE REMEDY (2026-07-29, follow-up session, seq0346, verdict
NEEDS_WORK): the independent evaluator confirmed the implementation core
genuine (independent JCS differential across 8,023 numbers and 400
whole-document fixtures, both zero mismatches) and found 3 Major
findings, all remedied in this session: (1) a lone (unpaired) UTF-16
surrogate reaching the serializer raised an uncaught `UnicodeEncodeError`
(exit 1, raw traceback) instead of a documented category — fixed by
rejecting it as `INVALID_UTF8_REJECTED` (exit 10), assigned to that
EXISTING category rather than a new one: design.md's Canonicalization
procedure step 1 ("decode as UTF-8 (reject on decode error)") and step 6
("the canonical UTF-8 byte sequence") together establish that the whole
pipeline operates only on valid Unicode text representable in UTF-8; a
lone surrogate produced via a `\uXXXX` escape (itself inside the accepted
subset's own text, "JSON's escape set exactly, incl. `\uXXXX`") violates
that exact invariant discovered at a later pipeline stage, not a
different one — `INVALID_UTF8_REJECTED`'s plain meaning covers both.
(2) A plain scalar containing an embedded `": "` or ending with `":"`
(e.g. `a: b: c`) was best-effort split on the first `": "` and accepted
(`{"a":"b: c"}`, rc=0) instead of rejected — fixed by rejecting with
`UNSUPPORTED_SYNTAX_REJECTED` (exit 26) and the quote-the-scalar hint,
per Design Decisions' explicit "never a best-effort interpretation".
(3) Neither test suite exercised `UNSUPPORTED_SYNTAX_REJECTED` (26),
`INVALID_UTF8_REJECTED` (10), `INVALID_JSON_REJECTED` (11), or JSON input
mode at all — remedied with 23 new regression assertions per runtime
(TDD Red 9 FAIL/43 PASS `bash`, 9 FAIL/40 PASS `pwsh` against the
pre-remedy script → Green 52/52 `bash`, 49/49 `pwsh`, evidence at
`specs/epic-189-a1-project-context/verification/T-002/remedy-{red,green}-{sh,ps1}.log`),
plus the Minor finding's tautological exit-code-table test replaced with
one that reads `CATEGORY_EXIT_CODES` directly from
`canonicalize-sdd-yaml.py` via `importlib`. Full detail:
`reports/implementation/epic-189-a1-project-context/T-002.md`. The two
remaining Minor findings (block-sequence-flush-left-style coverage gap;
this section's own staging-deferral checklist item) are unchanged by this
remedy and remain open for a future task/session per the evaluator's own
scoping.

QUALITY-GATE REMEDY 2 (2026-07-29, follow-up session, seq0347, verdict
NEEDS_WORK): the re-evaluation independently reconfirmed both seq0346
Major fixes genuine, judged the `INVALID_UTF8_REJECTED` category
assignment "defensible and design-grounded", and cleared the JCS core
again (10,018-double + 400-document differential, zero mismatches). This
round found 1 new Major (same silent-best-effort-interpretation family as
seq0346 finding #2) + 2 Minor, remedied here: (1) block-sequence items
separated from the `-` marker by MORE than one space, or by a tab, were
silently best-effort misparsed at exit 0 (`-  a` → `[" a"]`; `-  k: v` →
key-corrupted `[{" k":"v"}]`; `-<TAB>a` → the whole document's type
silently changed from sequence to string; `- - a` → `["- a"]`, swallowing
an inline nested-sequence lookalike) instead of parsed correctly or
rejected. **Reading chosen, derived from design.md's own text**: the
accepted subset's literal grammar shows only the single-space
`- item`/`- key: value` shapes (Design Decisions), the subset is framed
as "exactly what the real artifacts actually use" (which use exactly one
space), and the dominant fail-closed posture ("never a best-effort
interpretation") outweighs extending parsing to accept variant
separators — so EVERY deviation from exactly one space after `-`
(2+ spaces, any tab, or an inline nested-sequence lookalike) is now
rejected fail-closed with `UNSUPPORTED_SYNTAX_REJECTED` (26) and a
construct-specific diagnostic, rather than parsed per full YAML. Multi-line
nested sequences (a bare `-` followed by an indented block) already work
and remain the sole accepted nesting form, satisfying "nested arbitrarily"
without a second inline-nesting shape. This also fixes the "coupled site"
misleading multi-line diagnostic as a direct side effect — the malformed
separator is now caught at the offending line itself, before the
previously-reached generic "bad indentation" fallback. (2)+(3) [Minor,
both remedied]: `%` directives and `?` explicit keys now get
construct-specific diagnostics (naming "directive"/"explicit-key")
instead of the generic multi-top-level-lines fallback message. TDD Red
(`bash` 9 FAIL/56 PASS, `pwsh` 9 FAIL/53 PASS against the pre-remedy-2
script) → Green (`bash` 65/65, `pwsh` 62/62) captured at
`specs/epic-189-a1-project-context/verification/T-002/remedy2-{red,green}-{sh,ps1}.log`.
Full detail: `reports/implementation/epic-189-a1-project-context/T-002.md`.
The two remaining Minor findings (block-sequence-flush-left-style coverage
gap; the `.github/workflows/test.yml` staging deferral) are unchanged by
this round and remain open per the evaluator's own scoping.

QUALITY-GATE REMEDY 3 (2026-07-29, follow-up session, seq0348, verdict
NEEDS_WORK): the re-evaluation independently reconfirmed the remedy-2 fix
genuine (its own disable-the-fix differential reproduced the exact
pre-fix corruption) and judged the separator REJECT reading defensible,
then found 2 new Major + 3 Minor, all remedied here. (1) [Major] YAML
merge-key syntax (`<<`) was never rejected — design.md's Canonicalization
procedure and Design Decisions both name `<<` merge keys explicitly as
out-of-subset, but `_RESERVED_SIGIL_GENERIC` had no `<`, so an unquoted
`<<` key resolved as an ordinary string key at every position (top-level,
nested, with a map/sequence/scalar/empty-flow value), corrupting the
canonical hash exactly as the task's Risk Rationale forbids. Fixed with a
KEY-POSITION-ONLY check (not folded into the general reserved-sigil scalar
check, which also runs against values) for the exact token `<<`, since `<`
is not itself a reserved indicator for an ordinary scalar (`a: <foo>` is
legal plain text) — a blanket "reject any scalar starting with `<`" would
over-reject content the accepted subset permits; only the exact unquoted
key `<<` is merge-key syntax, and a quoted `"<<"` key is unaffected (same
quote-exempts-reserved-sigil pattern as anchor/alias/tag). Documented
behavior change: `<<: *base` now reports the merge-key rejection instead
of `ALIAS_REJECTED`, since key-parsing (and this new check) now runs
before the value is examined — both constructs are independently
out-of-subset, and naming the key construct is more informative.
(2) [Major] an in-subset deeply nested document (depth ≥250) raised an
uncaught `RecursionError` — Python's default recursion limit/thread stack
size are this interpreter's resource defaults, not part of design.md's
grammar, which states block collections nest "arbitrarily" with no depth
cap of its own; inventing a rejection category for depth would itself be
a design violation. Fixed by running the whole parse/normalize/serialize
pipeline (three recursions that execute sequentially, never stacked on
each other) in a dedicated thread with a substantially raised recursion
limit (100,000) and a much larger stack (512 MiB), so any realistic
"arbitrarily nested" document now succeeds normally (verified through
depth 10,000) with no error at all. A new `RECURSION_DEPTH_EXCEEDED` exit
code (4) exists only as a documented, non-crashing backstop for the
residual case where even this dramatically raised limit is exceeded — the
SAME KIND of exit as `CANONICALIZER_RUNTIME_UNAVAILABLE` (an environment/
resource-capability signal), not a new member of the 10-28
content-rejection family, since such a document is still accepted-subset
-valid; verified to fire cleanly (not a raw crash) via a scratch copy with
artificially lowered limits. (3) [Minor, remedied] `%`/`?` construct-
specific diagnostics, added at the document-root level in remedy 2, now
also apply at NESTED mapping-key positions. (4) [Minor, decided and
recorded, not changed] the evaluator's separator-strictness asymmetry
finding (mapping-side `k:   v` still accepts 2+ spaces via `.lstrip(' ')`
while sequence-side `-  a` now rejects) is NOT aligned to a symmetric
reject: the sequence-side bug was a silent CORRUPTION defect (extra
whitespace absorbed into resolved content, e.g. a leading-space-polluted
string or a corrupted key), which is why it was Major; the mapping side's
`.lstrip(' ')` already discards extra separator whitespace with ZERO
corruption risk before any further processing, so it is safe and
unambiguous, not the same defect class — tightening it to match would be
grammar-conformance purity, not a risk/safety fix, and the design's
dominant concern (this task's own Risk Rationale, ADR-0019) is never
silently corrupting content, not textual-grammar minimalism for its own
sake. (5) [Minor, remedied] `T-002.md`'s `## Outputs` table now also
declares `tests/run-all.sh`, `tests/run-all.ps1`, `CHANGELOG.md`, and (per
a separate coordinator instruction) `contracts/project-context.template.yaml`
(referenced, unchanged by this task — the empirical basis for the
remedy-2 separator reading) so a future evaluator's manifest-scoped read
access can independently verify claims this round's evaluator flagged as
unverifiable. TDD Red (`bash` 10 FAIL/70 PASS, `pwsh` 10 FAIL/67 PASS
against the pre-remedy-3 script) → Green (`bash` 80/80, `pwsh` 77/77)
captured at
`specs/epic-189-a1-project-context/verification/T-002/remedy3-{red,green}-{sh,ps1}.log`.
Full detail: `reports/implementation/epic-189-a1-project-context/T-002.md`.
The flush-left-block-sequence-style Minor finding and the `test.yml`
staging deferral remain open, unchanged by this round.

---

## T-003 Author the approval sidecar schema and staging-only signer (`generate-approval-sidecar`)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (sudo 2026-07-30T13:22:34Z)

Status: Done

Risk: high

Risk Rationale: Secrets handling per `risk-classification-policy.md:16` —
this task implements `SDD_CONTEXT_KEY` resolution and HMAC-SHA256 signing,
the direct mechanism ADR-0019 relies on to make approval authenticity (not
merely content binding) achievable, plus the staging-only output
discipline (B7) that keeps the live sidecar path unreachable from any
agent-driven signing invocation.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-004

Depends On: T-002 (canonicalizer, consumed for the content hash and the
HMAC preimage; design.md Technical Summary: "REQ-003 is consumed by
REQ-004").

Planned Files:
- `contracts/approval-sidecar.schema.json` (new, agent-editable)
- `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py` (new,
  agent-editable)
- `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.sh` / `.ps1`
  (new, agent-editable)
- `tests/generate-approval-sidecar.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — third in numeric
  order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new files.

Rollback: revert this task's two commits; a staged candidate that is never
applied leaves no live-state change to roll back (staging-only output).

### Goal

Implement `contracts/approval-sidecar.schema.json` and
`generate-approval-sidecar.{py,sh,ps1}`: compute `context_sha256` via
T-002's canonicalizer, accept `--approver`, `--status`, `--effective-at`,
and the two-person verdict fields, construct the field-excluded HMAC
preimage, resolve `SDD_CONTEXT_KEY` in the documented four-step order,
sign, and write ONLY a staged candidate (never the live path) plus a
staged approved-context content snapshot and manifest — refusing to write
anything when no key resolves.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (HMAC preimage and
  signing; API/Contract Plan `approval-sidecar.schema.json`)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-010..AC-013,
  AC-034, AC-036)
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:330-486`
  (`_resolve_sudo_key`/`sudo_active` precedent)
- `plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh:309-399`
  (`resolve_evidence_key`/`evidence_canonical` precedent)

### Scope

Commit A (TDD Red → Green):

- Red: TEST-010 (schema conformance, positive+negative), TEST-011
  (staged-signing round-trip + staged approved-context snapshot +
  fail-closed-with-no-key), TEST-012 (preimage self-reference exclusion),
  TEST-013 (key-resolution byte-parity fixture matrix), TEST-034 (signer
  never opens the live sidecar or live anchor path for writing under any
  invocation; simulated mid-write failure leaves no partial artifact;
  re-run after failure succeeds with a fresh nonce), TEST-036 (HMAC golden
  vector + fifteen one-field-mutated variants, including the three
  provenance fields) against a not-yet-implemented tool.
- Green: implement the schema and the tool; capture the passing run.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-010 proves sidecar schema conformance, positive and negative,
  including `hmac` length/case rejection (AC-010).
- [ ] TEST-011 proves a staged signing round-trip verifies under
  `validate-approval-sidecar`'s independent recomputation, a staged
  approved-context snapshot is produced alongside it, and no-key ⇒ no
  staged artifact written (AC-011).
- [ ] TEST-012 proves the `hmac` field's own value is excluded from its own
  preimage (AC-012).
- [ ] TEST-013 proves key-resolution byte-parity with `_resolve_sudo_key`/
  `resolve_evidence_key` (AC-013).
- [ ] TEST-034 proves the signer never writes the live sidecar or live
  anchor path, and recovers cleanly after a simulated mid-write failure
  (AC-034).
- [ ] TEST-036 proves the HMAC golden vector and all fifteen per-field
  mutations produce a different HMAC (AC-036).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] The provenance seam is proven WITHOUT any detector present, via
  `tests/generate-approval-sidecar.tests.sh` / `.ps1`: a bootstrap fixture
  (no live sidecar) signs with `predecessor_context_sha256` /
  `weakening_verdict` = null and `approval_epoch` = 1; a non-bootstrap
  fixture (live sidecar present) exits non-zero with the
  `WEAKENING_DETECTOR_UNAVAILABLE` diagnostic and writes NO staged
  candidate; both runs' outputs captured under
  `specs/epic-189-a1-project-context/verification/T-003/`
  (`seam-bootstrap-sh.log` / `-ps1.log`, `seam-failclosed-sh.log` /
  `-ps1.log`). (Remedy, task-review attempt-3 round-2 OBSERVABLE-DONE
  finding — verification-command/evidence-artifact form; the frozen
  acceptance-tests.md gains no new AC/TEST IDs, and the transitional
  diagnostic is task-sequencing state, not a design.md final-state
  change.)
- [ ] TDD Red/Green evidence recorded in the implementation report; an
  independent quality-gate verdict (a named second reviewer, not the
  implementing agent) records PASS.

### Out of Scope

- Validation (T-006).
- The two-person/cooldown verdict's own COMPUTATION (T-005's
  `detect-policy-weakening`). This task DOES build the generator's
  provenance-field resolution exactly as design.md's "HMAC preimage and
  signing" section requires — reading the currently-live sidecar for
  `predecessor_context_sha256`/`approval_epoch`, and resolving
  `weakening_verdict` via an IN-PROCESS invocation seam, never from any
  caller-supplied value (the CLI's accepted fields are the second-approval
  identity/timestamp fields only, not a verdict): the bootstrap case (no
  live sidecar → null/null/epoch 1) is completed entirely within this
  task; a non-bootstrap transition calls the seam, which — until T-005's
  detector lands — fails CLOSED with a named diagnostic
  (`WEAKENING_DETECTOR_UNAVAILABLE`) instead of signing. T-005 completes
  the seam by wiring its detector into `generate-approval-sidecar.py`
  in-process (see T-005 Planned Files), closing the transition to
  design.md's final state (remedy, task-review attempt-3 round-1
  DEPENDENCY-OVERLAP finding).
- Publishing the staged candidate to the live path (T-007's
  `apply-human-copy`, applied by T-009/T-012's tasks after this task's own
  Done).

### Blockers

T-002

(satisfied — T-002 is `Done`, quality-gate PASS seq0349, evidence bundle
green.)

STAGING DEFERRED (2026-07-30, implementation session, after TDD Green):
`contracts/approval-sidecar.schema.json`,
`generate-approval-sidecar.py`/`.sh`/`.ps1`,
`tests/generate-approval-sidecar.tests.sh`/`.ps1`, and this suite's direct
`tests/run-all.sh`/`.ps1` registration (inserted between T-002's
`canonicalize-sdd-yaml` entry and T-004's `approver-registry-schema` entry,
correct numeric order) are all complete — TDD Red (`bash` 29/50, `pwsh`
crashes without the implementation present) → Green (`bash` 50/50, `pwsh`
48/48) captured for both runtimes at
`specs/epic-189-a1-project-context/verification/T-003/`, plus the four
dedicated seam Done-When logs (`seam-bootstrap-{sh,ps1}.log`,
`seam-failclosed-{sh,ps1}.log`). The remaining Done-When item — staging
this suite's `.github/workflows/test.yml` addition under
`specs/epic-189-a1-project-context/human-copy/` + `MANIFEST.sha256` — is
DEFERRED, not blocked, for the SAME reason recorded in T-002's own
"STAGING DEFERRED" note above (unchanged root cause, T-001/T-002/T-004
precedent): `specs/epic-189-a1-project-context/human-copy/` is an
untracked, uncommitted directory at this session's start, already holding
T-001's and T-004's own staged `test.yml` + `MANIFEST.sha256` content
(verified: references to `project-context-schema`/`approver-registry-schema`,
none to `generate-approval-sidecar`, in that staged file — none of it
authored by this session). Appending to or committing another session's
uncommitted staging work risks corrupting or silently dropping it, so this
task defers ONLY that one staging sub-item — every other Scope/Done-When
item is complete. The intended staged addition (two new CI steps,
`generate-approval-sidecar.tests.sh`/`.ps1`, to be inserted directly after
T-002's `canonicalize-sdd-yaml` steps and before T-004's
`approver-registry-schema` steps, matching this suite's `tests/run-all.sh`/
`.ps1` position) is recorded in
`reports/implementation/epic-189-a1-project-context/T-003.md` for whichever
session next finds `human-copy/` clean or committed. Live
`.github/workflows/test.yml` SHA-256 unchanged this session (never
written): `3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4`
(recorded before and after this session's work; identical to T-002's/T-004's
own recorded value, confirming no session has touched the live file since).

QUALITY-GATE REMEDY (2026-07-30, follow-up session, seq0350, verdict
NEEDS_WORK): the independent evaluator reproduced 5/5 a Major finding —
`generate-approval-sidecar.py:302,347`'s `os.makedirs(parent_dir)` and
`os.rename(tmp_leaf, stage_dir)` raised OSError subclasses
(`NotADirectoryError`/`FileExistsError`/`PermissionError`) that escaped
`main()`'s narrow `except GenerateApprovalSidecarError` handler, producing
a raw traceback and undocumented exit 1, contradicting the module's own
"never an uncaught traceback" docstring promise and the stable
documented-exit-code contract — including the DEFAULT (no `--stage-dir`)
path, when `sdd` itself is an existing regular file. The evaluator judged
this Major rather than Critical because fail-closed behavior itself
(no stray temp directories, no partial/unsigned artifact) was already
intact. Remedied here: `_write_staged_outputs`'s entire filesystem
sequence (directory creation through the final commit rename) is now
inside one `try`/`except OSError`, wrapping any such error as a new,
documented category (`STAGING_IO_ERROR`, exit 16 — the next available slot
in the existing 0/2/10-15/90 exit-code space) while preserving the
existing cleanup-then-reraise behavior for the `SIMULATED_MID_WRITE_FAILURE`
test hook (an `except BaseException` clause below the new `except OSError`
handles that non-OSError case unchanged). All 5 of the evaluator's
reproduction cases re-verified fixed by hand before writing any test.
TDD Red (both suites' 3 new `TEST-HARDEN(d)` "clean exit code" assertions
fail genuinely against the pre-remedy script, with a real captured
traceback) → Green (`bash` 57/57, `pwsh` 55/55) captured for both runtimes
at `specs/epic-189-a1-project-context/verification/T-003/remedy-{red,green}-{sh,ps1}.log`.
The two Minor findings (AC-013's `resolve_evidence_key` half unproven by
execution; the pwsh suite's one documented TEST-HARDEN(b) delivery-method
difference) are unchanged by this remedy and remain open per the
evaluator's own scoping — no other file or behavior was touched. Full
detail: `reports/implementation/epic-189-a1-project-context/T-003.md`.

---

## T-004 Author the approver registry schema

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (sudo 2026-07-22T15:24:55Z)

Status: Done

Risk: high

Risk Rationale: Security-policy-decision surface per
`risk-classification-policy.md:16` — this schema defines the immutable
identity key (`id`) every two-person/cooldown verdict (T-005) and every
validation-time identity/duplicate-identity check (T-006) is anchored
against; a malformed or under-constrained schema (e.g. permitting a
non-unique or mutable identity key) would silently defeat the two-person
review guarantee ADR-0019 item 6 exists to enforce, even though this task
itself computes no verdict.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-006

Depends On: T-003 only for this task list's mandatory shared-file
numeric-order append serialization (Global Constraints) — this schema has
no functional code dependency on T-003's signer; it is a standalone JSON
Schema artifact, like T-001's schemas.

Planned Files:
- `contracts/approver-registry.schema.json` (new, agent-editable — schema
  id `sdd-approver-registry/v1`)
- `tests/approver-registry-schema.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — fourth in
  numeric order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new file.

Rollback: revert this task's two commits.

### Goal

Author `contracts/approver-registry.schema.json` (schema id
`sdd-approver-registry/v1`): `schema` (const), `approvers[]` (`id` unique
string — the immutable identity key, `name` string — mutable display
label, `registered_at` ISO 8601). Prove field-level conformance, the
malformed-registry rejection path, the registry-side duplicate-`id`
semantic rejection, and the zero-entry boundary case.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Data Plan —
  `sdd/approver-registry.yaml` entity; Design Decisions — OQ-001 location)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-044..AC-046)
- `docs/adr/0019-approval-sidecar-protection.md`

### Scope

Commit A (TDD Red → Green):

- Red: TEST-044 (schema conformance, parameterized required-field
  rejection on `id`/`name`, malformed-`approvers`-shape rejection,
  zero-entry `[]` VALIDATES), TEST-045 (registry-side duplicate-`id`
  semantic rejection, `DUPLICATE_APPROVER_REGISTRY_ID`, at the
  semantic-validator layer not the JSON Schema), TEST-046 (zero-identity
  boundary: a schema-valid `approvers: []` fixture, combined with T-003's/
  T-006's structural fail-closed-signing/validating consequence for that
  same empty registry — this task's own Done When scopes to proving the
  registry itself validates the empty-array case; the downstream
  fail-closed proof is T-006's) against a not-yet-implemented schema.
- Green: author the schema; capture the passing run.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-044 proves schema conformance including the malformed-registry
  rejection path and the zero-entry validating case (AC-044).
- [ ] TEST-045 proves the registry-side duplicate-`id` semantic rejection
  (AC-045).
- [ ] TEST-046 proves the zero-identity registry fixture itself validates
  against the schema, as the precondition T-005/T-006 build their
  classification/fail-closed proofs on (AC-046, schema-conformance half —
  the verdict/fail-closed half is T-005's/T-006's own Done When).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded in the implementation report; an
  independent quality-gate verdict (a named second reviewer) records PASS.

### Out of Scope

- The policy-weakening detector and its two-person/cooldown verdict
  derivation (T-005) — a functionally distinct algorithmic deliverable
  from this schema, split out per round-1 task-review remedy (below).
- The generator's/validator's own consumption of this schema (T-003
  already ships against a verdict it receives; T-006 re-derives identity/
  duplicate-identity checks against this schema's data shape).

### Blockers

T-003

(documentation-only dependency for shared-file numeric-order
serialization; not a real conflict here since T-002/T-003 are themselves
blocked pre-code and have contributed no lines to `tests/run-all.sh`/
`.ps1` yet).

BLOCKED (2026-07-22, staging only): all of this task's own Done-When
items are complete and verified — TEST-044/045/046 pass 8/8 in both
`bash` and `pwsh`, with genuine TDD Red (schema absent, 7/8 fail) → Green
(schema present, 8/8 pass) evidence captured for both runtimes at
`specs/epic-189-a1-project-context/verification/T-004/`; the suite is
registered in `tests/run-all.sh`/`.ps1`; `CHANGELOG.md` is updated. The
sole remaining item — staging this suite's CI workflow registration
under human-copy — hits the identical guard block already recorded in
T-001's `### Blockers` (same root cause, same fix options A/B/C). Exact
intended CI step content and the human-apply procedure are recorded in
`reports/implementation/epic-189-a1-project-context/HUMAN-APPLY-STEPS.md`.
Live CI workflow file SHA-256 unchanged
(`3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4`,
verified before and after this task's work).

STAGING DEFERRED (2026-07-30, coordinator decision, close-out session):
per coordinator decision, this task proceeds via a RECORDED DEFERRAL of
the one remaining staging sub-item, the same precedent already recorded
above for T-001 and, in the same shape, for T-002's and T-003's own
"STAGING DEFERRED" notes. `specs/epic-189-a1-project-context/human-copy/`
remains an untracked, uncommitted directory holding another, concurrent
session's in-flight staged `test.yml` + `MANIFEST.sha256` content that
this session did not author and has not seen committed; appending to or
committing those foreign uncommitted files risks corrupting or silently
dropping that other session's work, so this task defers ONLY that one
staging sub-item. Every other Scope/Done-When item for this task is
complete and independently re-verified this session (TEST-044/045/046,
8/8 in both `bash` and `pwsh`, fresh recheck logs at
`specs/epic-189-a1-project-context/verification/T-004/
recheck-green-sh.log` and `.../recheck-green-ps1.log`). Staging completes
via the human-copy flow once that tree is clean or committed (the T-009/
T-013 chain). Live CI workflow file SHA-256 unchanged
(`3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4`,
reconfirmed this session).

---

## T-005 Author the policy-weakening detector

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (sudo 2026-07-30T15:42:24Z)

Status: Done

Risk: high

Risk Rationale: Security-policy-decision surface per
`risk-classification-policy.md:16` — an under-classification here (a real
weakening change misclassified as non-weakening, or a caller-supplied
anchor accepted on the production call path) would silently skip the
two-person/cooldown gate ADR-0019 item 6 exists specifically to enforce;
this is functionally an access-control decision, not an informational
report.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-006

Depends On: T-002 (canonicalizer, used to diff before/after documents on
stable byte content; design.md Technical Summary: "REQ-003 is consumed
by ... REQ-006"), T-004 (this task list's shared-file numeric-order append
serialization, and the approver-registry schema this detector's
two-person/cooldown verdict reads `sdd/approver-registry.yaml` against).

Planned Files:
- `plugins/sdd-quality-loop/scripts/detect-policy-weakening.py` (new,
  agent-editable)
- `plugins/sdd-quality-loop/scripts/detect-policy-weakening.sh` / `.ps1`
  (new, agent-editable)
- `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py` (existing
  by T-003, agent-editable — completes T-003's fail-closed
  `WEAKENING_DETECTOR_UNAVAILABLE` seam by wiring `detect-policy-weakening`
  IN-PROCESS for non-bootstrap transitions, per design.md "HMAC preimage
  and signing"; no CLI-surface change, never a caller-supplied verdict —
  remedy, task-review attempt-3 round-1 DEPENDENCY-OVERLAP finding)
- `tests/detect-policy-weakening.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — fifth in numeric
  order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new files.

Rollback: revert this task's two commits.

### Goal

Author `detect-policy-weakening.{py,sh,ps1}`, implementing the
renormalized 3-implemented/6-N/A weakening-category table, the
glob-coverage narrowing algorithm, the two-person/cooldown verdict
derivation against `sdd/approver-registry.yaml` (T-004's schema,
including the zero-identity boundary case), and the default trust-anchor
resolution against the protected `sdd/.approved-context/*.approved.yaml`
snapshot (never git HEAD, never caller-supplied on the production call
path).

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Policy-weakening
  categories; Weakening-detector approved-context anchor CLI contract;
  Design Decisions — B3 anchor choice)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-016..AC-018,
  AC-030, AC-031, AC-046)
- `docs/adr/0019-approval-sidecar-protection.md`

### Scope

Commit A (TDD Red → Green):

- Red: TEST-016 (per-category classification: 3 implemented categories
  classify `policy_weakening: true`; 6 documented-N/A categories reported
  N/A explicitly, no proxy classification), TEST-017 (strengthening-change
  negative proof), TEST-018 (two-person/cooldown verdict fixture pair: a
  2-identity registry fixture → `two_person_required: true`; a 1-identity
  registry fixture → `two_person_required: false, cooldown_hours: 24`),
  TEST-030 (approved-context anchor CLI contract: identical-to-anchor ⇒
  false; genuine diff ⇒ true, both immediately and after landing as
  ordinary git commits; production call path immune to
  `--approved-context` override; `NO_APPROVED_CONTEXT_ANCHOR` fail-closed
  rule; `HUMAN_COPY_PUBLISH_IN_PROGRESS` fail-closed on a live
  `TRANSACTION.json`), TEST-031 (glob-coverage narrowing algorithm: pattern
  removed, pattern replaced at unchanged count, exclude added, exclude
  replaced broader, pure-broadening non-weakening — five independent
  fixtures), TEST-046 (zero-identity verdict half: given a
  policy-weakening change and T-004's schema-valid `approvers: []`
  fixture, the detector emits `two_person_required: false,
  cooldown_hours: 24`, identical to the 1-identity case) against a
  not-yet-implemented detector.
- Green: implement the detector; capture the passing run.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-016 proves every implemented weakening category classifies as
  weakening and every documented-N/A category is reported N/A explicitly
  (AC-016).
- [ ] TEST-017 proves a strengthening change is NOT misclassified as
  weakening (AC-017).
- [ ] TEST-018 proves the two-person/cooldown verdict derivation from a
  2-identity vs. 1-identity registry fixture (AC-018).
- [ ] TEST-030 proves the approved-context anchor CLI contract, including
  the commit-cannot-move-the-anchor case and the in-progress-publish
  fail-closed case (AC-030).
- [ ] TEST-031 proves all five glob-coverage narrowing boundary cases
  (AC-031).
- [ ] TEST-046 proves the zero-identity registry classification verdict
  (AC-046, verdict half — the schema-conformance half is T-004's).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] The wiring completion is proven end-to-end via
  `tests/detect-policy-weakening.tests.sh` / `.ps1`: with the detector
  present, a non-bootstrap signing fixture through
  `generate-approval-sidecar.py` embeds the EXACT in-process-computed
  verdict (no caller-supplied verdict path exists; the
  `WEAKENING_DETECTOR_UNAVAILABLE` diagnostic no longer fires for this
  fixture), outputs captured under
  `specs/epic-189-a1-project-context/verification/T-005/`
  (`wiring-sh.log` / `wiring-ps1.log`). (Remedy, task-review attempt-3
  round-2 OBSERVABLE-DONE finding — closes T-003's fail-closed seam to
  design.md's final in-process state.)
- [ ] TDD Red/Green evidence recorded in the implementation report; an
  independent quality-gate verdict (a named second reviewer) records PASS.

### Out of Scope

- The approver-registry schema itself (T-004).
- The generator's enforcement of a two-person-required verdict at signing
  time (T-003 already ships that behavior against a verdict it receives).
- End-to-end signing/validation wiring of this verdict (T-006).

### Blockers

T-002, T-003, T-004

(T-003 added — remedy, task-review attempt-3 round-1 DEPENDENCY-OVERLAP
finding: this task now edits `generate-approval-sidecar.py`, which T-003
creates, to complete the in-process weakening-verdict wiring.)

STAGING DEFERRED (2026-07-30, same recorded precedent as T-001/T-002/
T-003/T-004's own "STAGING DEFERRED" notes): all of this task's own
Scope/Done-When items are complete and verified — TEST-016/017/018/030/
031/046 pass in both `bash` (56/56) and `pwsh` (55/55), with genuine TDD
Red (detector absent, 51/56 fail in `bash`; `pwsh` aborts on the first
missing-script invocation) → Green (detector present, full PASS in both
runtimes) evidence captured at
`specs/epic-189-a1-project-context/verification/T-005/` (`red-sh.log`,
`red-ps1.log`, `green-sh.log`, `green-ps1.log`); the wiring-completion
Done-When item is additionally proven end-to-end via a dedicated
standalone reproduction (`wiring-sh.log`, `wiring-ps1.log`, same
directory) showing the staged sidecar's embedded `weakening_verdict`
exactly matches the detector's own direct-invocation output and that
`WEAKENING_DETECTOR_UNAVAILABLE` no longer fires for that fixture; the
suite is registered in `tests/run-all.sh`/`.ps1` (fifth in numeric order);
`CHANGELOG.md` is updated. The sole remaining item — staging this suite's
CI workflow registration under human-copy — hits the identical condition
already recorded in T-001/T-002/T-003/T-004's own `### Blockers`:
`specs/epic-189-a1-project-context/human-copy/` remains an untracked,
uncommitted directory holding another, concurrent session's in-flight
staged `test.yml` + `MANIFEST.sha256` content this session did not author
and has not seen committed; appending to or committing those foreign
uncommitted files risks corrupting or silently dropping that other
session's work, so this task defers ONLY that one staging sub-item. Exact
intended CI step content and the human-apply procedure are recorded in
`reports/implementation/epic-189-a1-project-context/HUMAN-APPLY-STEPS.md`
(T-005 entry, inserted after T-004's block). Live CI workflow file
SHA-256 unchanged
(`3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4`,
verified before and after this task's work). Staging completes via the
human-copy flow once that tree is clean or committed (the T-009/T-013
chain).

---

## T-006 Author the approval validator (`validate-approval-sidecar`)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (sudo 2026-07-30T16:59:46Z)

Status: Done

Risk: high

Risk Rationale: This is the approval-defense mechanism's own enforcement
point per `risk-classification-policy.md:16` — a false PASS here (hash/
HMAC/identity/duplicate-identity/cooldown check any one of which is
skipped or mis-implemented, or a provenance-verification bypass) defeats
every other REQ-004/REQ-006 guarantee this epic builds.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-005

Depends On: T-003 (recomputes the generator's own construction), T-004
(the approver-registry schema this validator checks identity/duplicate-
identity against), T-005 (this task list's mandatory shared-file
numeric-order append serialization).

Planned Files:
- `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` (new,
  agent-editable)
- `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.sh` / `.ps1`
  (new, agent-editable)
- `tests/validate-approval-sidecar.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — sixth in numeric
  order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new files.

Rollback: revert this task's two commits.

### Goal

Implement the six validation gates (content-schema incl. duplicate-`id`,
hash match, HMAC verify, unregistered approver, duplicate approver
identity, premature `effective_at`) plus the two-person/cooldown
enforcement proof, the zero-identity structural fail-closed-signing/
validating consequence, and the `--verify-provenance` historical re-check
mode.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Data Plan; Constraint
  Compliance — historical weakening binding)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-014, AC-015,
  AC-019, AC-020, AC-043, AC-046)
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:454-486`
  (`sudo_active`'s epoch-gate and `hmac.compare_digest` precedent)

### Scope

Commit A (TDD Red → Green):

- Red: TEST-014 (six independent rejection fixtures), TEST-015 (positive
  fixture), TEST-019 (two-person enforcement: refuses solo-approver
  signing of a weakening change; signs with two distinct registered ids;
  refuses same-identity `DUPLICATE_APPROVER_IDENTITY`), TEST-020
  (cooldown enforcement before/after `effective_at`), TEST-043 (post-publish
  provenance re-provability: `--verify-provenance` still PASSES after the
  predecessor anchor is gone when `second_approval` is distinct, still
  FAILS `WEAKENING_PROVENANCE_UNDERAPPROVED` when null/duplicate; bootstrap
  case `approval_epoch: 1` passes with no second-approval requirement
  implied), TEST-046 (zero-identity structural fail-closed half: given
  T-004's schema-valid `approvers: []` fixture, `generate-approval-sidecar.py`/
  `validate-approval-sidecar.py` refuse to sign/validate since no `id` can
  ever resolve) against a not-yet-implemented validator.
- Green: implement the validator; capture the passing run.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-014 proves all six independent rejection cases (AC-014).
- [ ] TEST-015 proves the positive PASS case (AC-015).
- [ ] TEST-019 proves two-person enforcement blocks premature and
  same-identity signing and allows correctly-approved signing (AC-019).
- [ ] TEST-020 proves cooldown rejection before `effective_at` and
  acceptance after (AC-020).
- [ ] TEST-043 proves post-publish provenance re-provability and
  underapproval rejection, including the bootstrap case (AC-043).
- [ ] TEST-046 proves the zero-identity structural fail-closed-signing/
  validating consequence (AC-046, structural half — the verdict half is
  T-005's).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded in the implementation report; an
  independent quality-gate verdict (a named second reviewer) records PASS.

### Out of Scope

- Wiring this validator into any Capability Mode gate beyond REQ-009's
  call sites (T-011/T-012).
- The staging-only signer's own behavior (T-003).
- The weakening detector's own category/verdict computation (T-005).

### Blockers

T-003, T-004, T-005

(satisfied — T-003, T-004, T-005 are all `Status: Done`; T-003 quality-gate
PASS seq0350 remedy, T-004 quality-gate PASS, T-005 quality-gate PASS
seq0354, all with green evidence bundles.)

STAGING DEFERRED (2026-07-30, implementation session, after TDD Green): all
of this task's own Scope/Done-When items are complete and verified --
TEST-014/015/019/020/043/046 pass 38/38 in `bash` and 37/37 in `pwsh` (the
`.sh` suite carries one extra self-registration assertion, matching every
sibling suite's own convention), with genuine TDD Red (`bash` 8/38,
`pwsh` 7/37, script absent) -> Green (`bash` 38/38, `pwsh` 37/37) captured
for both runtimes at
`specs/epic-189-a1-project-context/verification/T-006/`, plus the
dedicated `key-parity-sh.log`/`key-parity-ps1.log` pair for carry-forward
obligation 1. The suite is registered in `tests/run-all.sh`/`.ps1` (sixth
in numeric order, directly after `detect-policy-weakening.tests.sh` and
before the unrelated `guard-staging-exemption.tests.sh`). The remaining
Done-When item -- staging this suite's `.github/workflows/test.yml`
addition under `specs/epic-189-a1-project-context/human-copy/` +
`MANIFEST.sha256` -- is DEFERRED, not blocked, for the SAME reason
recorded in T-001/T-002/T-003/T-004/T-005's own "STAGING DEFERRED" notes
above (unchanged root cause): `specs/epic-189-a1-project-context/human-copy/`
is an untracked, uncommitted directory at this session's start, still
holding only T-001's and T-004's own staged `test.yml` + `MANIFEST.sha256`
content (verified: references to
`project-context-schema`/`approver-registry-schema` only; none to
`canonicalize-sdd-yaml`/`generate-approval-sidecar`/`detect-policy-weakening`/
`validate-approval-sidecar` -- none of it authored by this session, and
T-002/T-003/T-005's own staging remains equally deferred as of this
session's start). Appending to or committing another session's uncommitted
staging work risks corrupting or silently dropping it, so this task defers
ONLY that one staging sub-item -- every other Scope/Done-When item is
complete. The intended staged addition (two new CI steps,
`validate-approval-sidecar.tests.sh`/`.ps1`, to be inserted directly after
T-005's own `detect-policy-weakening` steps (once staged) and before any
T-007+ addition, matching this suite's `tests/run-all.sh`/`.ps1` position)
is recorded in
`reports/implementation/epic-189-a1-project-context/T-006.md` for
whichever session next finds `human-copy/` clean or committed. Live
`.github/workflows/test.yml` SHA-256 unchanged this session (never
written): `3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4`
(recorded before and after this session's work; identical to
T-001/T-002/T-003/T-004/T-005's own recorded value, confirming no session
has touched the live file since).

---

## T-007 Author the anchored-publisher-equivalent human-copy tool (`apply-human-copy`)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (aharada54914 2026-08-01T12:58:44Z)

Second Approval: Approved (aharada227 2026-08-01T12:59:05Z)

Status: Done

Risk: critical

Risk Rationale: Per `risk-classification-policy.md:17` ("irreversible
destructive operations"), this task builds the SOLE mechanism through
which every protected-file publish in this epic (T-003's sidecar+anchor
pair, T-009's guard-invariants registration batch, T-012's `ship`/
`lite-spec` edits, every suite's `test.yml` registration) lands on a live
path — held handle, handle-relative traversal, temp-rehash, atomic
rename, no path-copy fallback, journaled multi-target transaction with
crash recovery. A defect here (a TOCTOU window, a non-atomic multi-target
partial-publish, or a symlink/hard-link bypass) undermines every other
protection this epic builds, not merely this task's own surface.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-007

Depends On: T-006 only for this task list's mandatory shared-file
numeric-order append serialization (Global Constraints) — this task's own
functional content (a generic, content-agnostic publisher; design.md
Global Constraints: authored and tested UNPROTECTED first, self-protected
only later by T-009's registration batch) has no code dependency on
T-002..T-006's own artifacts.

Planned Files:
- `plugins/sdd-quality-loop/scripts/apply-human-copy.sh` / `.ps1` (new,
  agent-editable at authoring time — becomes protected only after T-009)
- `tests/apply-human-copy.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — seventh in
  numeric order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new tool, no existing consumer.

Rollback: revert this task's two commits; no protected file is touched by
this task (the tool is not yet registered protected — T-009 does that).

### Goal

Implement `apply-human-copy.{sh,ps1}`: held-handle staged-candidate
validation, handle-relative traversal, temp-rehash-before-rename, atomic
rename (never path-based copy), and — for a 2+ target batch — a
journaled prepare/journal/commit/complete/crash-recovery protocol that
converges every target to exactly one of two terminal states (all-pre or
all-post), run automatically at the start of every invocation, per
design.md's Human-copy publisher transactional bundle contract and
ADR-0025.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Human-copy publisher
  transactional bundle contract; Design Decisions — multi-target
  atomicity; ADR Change Log)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-033)
- `docs/adr/0011-phase2-handle-relative-protected-copy.md`
- `docs/adr/0025-human-copy-transactional-bundle.md` (drafted as part of
  this task's implementation; this design's own ADR Change Log records it
  as the closing artifact for this task's transactional pattern)

### Scope

Commit A (TDD Red → Green):

- Red: TEST-033 (symlink/reparse-point denial at either held handle;
  hard-link-alias non-propagation; held-handle substitution resistance;
  atomic-rename-only publish; live target unchanged on preparation-stage
  failure; 2+ target batch crash-recovery to exactly one of two terminal
  states for a crash between renames, before the first rename, and after
  the last rename but before journal deletion; a second crash injected
  during recovery itself still converges correctly) against a
  not-yet-implemented tool.
- Green: implement `apply-human-copy.{sh,ps1}`; capture the passing run.
- Draft `docs/adr/0025-human-copy-transactional-bundle.md`, re-verifying
  via `ls docs/adr/` at drafting time that `0025` is still free.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-033 proves the full anchored-publisher contract and the
  multi-target crash-recovery proof across all four injection points
  (AC-033).
- [ ] `docs/adr/0025-human-copy-transactional-bundle.md` is committed as
  part of this task's implementation commit.
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded in the implementation report; an
  independent quality-gate verdict (a named second reviewer, not the
  implementing agent) records PASS; a second, distinct named approver
  additionally reviews and signs the evidence bundle (Risk: critical,
  `risk-classification-policy.md:17`).

### Out of Scope

- Registering the tool itself as protected (T-009).
- Applying any OTHER task's staged artifact through this tool (T-003's
  sidecar publish is applied later by T-009/T-012's own human-apply
  steps; T-012's `ship`/`lite-spec` publish).

### Blockers

T-006

STAGING DEFERRED (2026-07-30, implementation session, after TDD Green): all
of this task's own Scope/Done-When items are complete and verified --
TEST-033 proves the full anchored-publisher contract plus the multi-target
crash-recovery proof across all four AC-033 injection points (before any
rename; mid-batch; after the last rename but before journal deletion; a
second crash injected during recovery itself), each independently
exercised for both runtimes and additionally captured as dedicated
crash-injection transcripts (`specs/epic-189-a1-project-context/
verification/T-007/crash-injection-{sh,ps1}.log`). `tests/apply-human-copy
.tests.sh`/`.ps1` pass 38/38 (`bash`) and 27/27 (`pwsh`), with genuine TDD
Red (`bash` 19/38, `pwsh` 10/27, script relocated out of the plugin
directory) -> Green (`bash` 38/38, `pwsh` 27/27) captured for both runtimes
at `specs/epic-189-a1-project-context/verification/T-007/`. The suite is
registered in `tests/run-all.sh`/`.ps1` (seventh in numeric order,
directly after `validate-approval-sidecar.tests.sh` and before the
unrelated `guard-staging-exemption.tests.sh`, matching T-006's own
recorded position note). `docs/adr/0025-human-copy-transactional-bundle.md`
was found ALREADY drafted and committed (round-1 impl-review remedy,
commit `e28ba891`), predating this implementation session; its content was
verified line-by-line against the actual implementation (journal shape,
six-step prepare/journal/commit/complete/recovery protocol, all four
AC-033 convergence states, and it already names
`tests/apply-human-copy.tests.sh`/`.ps1` by their real filenames) and
found fully consistent -- no edit was needed or made. The remaining
Done-When item -- staging this suite's `.github/workflows/test.yml`
addition under `specs/epic-189-a1-project-context/human-copy/` +
`MANIFEST.sha256` -- is DEFERRED, not blocked, for the SAME reason recorded
in T-001..T-006's own "STAGING DEFERRED" notes above (unchanged root
cause): `specs/epic-189-a1-project-context/human-copy/` is an untracked,
uncommitted directory at this session's start, still holding only prior
sessions' own staged `test.yml` + `MANIFEST.sha256` content (verified:
references to `project-context-schema`/`approver-registry-schema` only;
none to `apply-human-copy`). Appending to or committing another session's
uncommitted staging work risks corrupting or silently dropping it, so this
task defers ONLY that one staging sub-item -- every other Scope/Done-When
item is complete. The intended staged addition (two new CI steps,
`apply-human-copy.tests.sh`/`.ps1`, to be inserted directly after
T-006's own `validate-approval-sidecar` steps (once staged) and before any
T-008+ addition, matching this suite's `tests/run-all.sh`/`.ps1` position)
is recorded in
`reports/implementation/epic-189-a1-project-context/T-007.md` for
whichever session next finds `human-copy/` clean or committed. Live
`.github/workflows/test.yml` SHA-256 unchanged this session (never
written): `3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4`
(recorded before and after this session's work; identical to
T-001..T-006's own recorded value, confirming no session has touched the
live file since). Carry-forward obligations 1 and 2 (T-005 relay,
registered carry-forward items) are discharged: this publisher's own
journal writer conforms exactly to the `targets[]` =
`{live_path, pre_hash, post_hash}` shape T-005's reader already consumes,
and this publisher's own recovery/publish path REJECTS (fail-closed,
`JOURNAL_SHAPE_INVALID`) a journal that is valid JSON but lacks/mis-shapes
`targets[]`, in contrast to `detect-policy-weakening.py:201-203`'s known
fail-open behavior on that same shape violation (that file is NOT in this
task's Planned Files and was NOT edited; the residual is recorded, not
silently papered over, in the implementation report's Unresolved Items).
Two implementation-time architecture findings are recorded in the
implementation report and in code comments: (1) neither POSIX shell nor
cross-platform PowerShell can produce a literal `openat()`/`NtCreateFile`
handle chain, so both runtimes realize "handle-relative traversal" via the
process's own kernel-mediated current-working-directory binding
(`chdir`/`Directory.SetCurrentDirectory`), walked one segment at a time
with a symlink/reparse-point check before each descent -- documented in
both scripts' own header comments and cross-referenced from ADR-0025;
(2) PowerShell cmdlets (`Copy-Item`, `Test-Path`, `Move-Item`) resolve a
relative path via PowerShell's own `$PWD` bookkeeping, NOT via
`[System.Environment]::CurrentDirectory` -- a genuine substitution-
resistance defect (not merely a test artifact) found and fixed during
this session by routing every actual destination-side read/write through
raw `[System.IO.File]`/`[System.IO.Directory]` calls resolved fresh
against `[System.Environment]::CurrentDirectory` at the moment of use.

QUALITY-GATE REMEDY (2026-07-31, seq0357 NEEDS_WORK -> remedy applied):
`reports/quality-gate/2026-07-30T204328Z-T-007.md` (commit `f6e227af`)
returned Critical 1 / Major 3 / Minor 3. All Critical + 3 Major findings
fixed with TDD (Red-first, confirmed via genuine script relocation) plus
new regression tests in BOTH runtimes; the 3 Minor findings are left as
carryover (no code change, per the coordinator's explicit instruction),
with this task's own implementation report corrected where it had
overstated or misstated the underlying mechanism. Summary: (a) Critical
-- `backup_pre_bytes`/`Backup-PreBytes` deleted a legitimately zero-byte
pre-transaction backup, permanently bricking the sh publisher after a
mid-batch crash on a batch containing an empty pre-existing live target
(ps1 was already correct); fixed via an explicit found/not-found signal
instead of a byte-count heuristic. (b) Major -- two targets sharing a
basename in different directories within one batch collided on the
design.md:1011-specified `pre/<basename>` backup slot, permanently
blocking recovery in both runtimes; design.md:1011 was read in full
before choosing a remedy, and since its literal text specifies the
basename-keyed layout, a path-derived rename would have required a design
amendment (review-process matter) -- chose instead a new prepare-time
classified rejection, `DUPLICATE_BASENAME_IN_BATCH`, in both runtimes.
(c) Major -- `tests/apply-human-copy.tests.ps1` had NO TEST-033d/e
coverage on any platform, and this task's own report had falsely claimed
an `$IsWindows` skip branch existed; both tests are now genuinely
implemented (running on macOS/Linux, skipped only on native Windows,
matching TEST-033c's own convention). (d) Major -- the ps1 journal writer
emitted a UTF-8 BOM, byte-diverging from the sh journal and breaking
carry-forward obligation 1's "no silent divergence against a plain Python
reader" for real (not merely by key-name inspection, which is all the
original report had verified); fixed via an explicit BOM-less
`UTF8Encoding` instance, with a new cross-runtime regression test.
TDD Red (script relocated, both runtimes together): `bash` 20/43 (43
reached, not 45 -- some downstream blocks short-circuit when the tool is
wholly absent), `pwsh` 15/36 (36 reached, not 37) -> Green (post-fix):
`bash` 45/45, `pwsh` 37/37. Full detail, root-cause analysis, and the
corrected mechanism descriptions are in
`reports/implementation/epic-189-a1-project-context/T-007.md`'s own
"Quality Gate Remedy (seq0357)" section.

QUALITY-GATE REMEDY 2 (2026-07-31, seq0358 NEEDS_WORK -> remedy applied;
round-1 (seq0357) findings independently reconfirmed fixed by this
round's evaluator, including a mutation test reverting each round-1 fix
and observing the regression lock genuinely fail): `reports/quality-gate/
2026-07-30T213553Z-T-007.md` (commit `02e25f98`) returned Major 1 (new) /
Minor 5. Fixed: a manifest target path containing whitespace passed
`parse_manifest` unrejected but was then corrupted by `apply-human-copy
.sh`'s internal `read -r a b c` IFS field-splitting (in `write_journal`
and the commit loop) -- fields shifted, the journal's `post_hash` became
two concatenated hashes, `json_get_targets`'s own shape check still
passed (all three keys non-empty) so `JOURNAL_SHAPE_INVALID` never fired,
and T-005's `detect-policy-weakening.py` reader would have probed the
WRONG `live_path` and failed open on the file actually mid-publish
(design.md:1064-1070 step 6) -- while the `.ps1` twin already handled the
identical batch correctly (a genuine parity break). design.md's own
manifest/journal contract text (the "Human-copy publisher transactional
bundle contract" section) was read in full before choosing a remedy: it
places no restriction on path characters, and the `.ps1` runtime already
proved whitespace-containing paths are a legitimately supported input, so
the chosen fix is (i) -- make `.sh` handle them correctly end-to-end,
restoring parity, rather than a new rejection category. Every internal
work-file that carries a path (`TARGETS_FILE`, and `json_get_targets`'s
own re-serialization of a live journal's targets for the crash-recovery
scan) was migrated to a fixed-width "target record" encoding
(`<64-char-pre><64-char-post><space><path-to-end-of-line>`, with a
reserved 64-'z' sentinel for "ABSENT" -- 'z' is never a valid lowercase-
hex digit, so it cannot collide with a real digest) split ONLY via
fixed-column `cut`, never via `read` IFS field-splitting, which was
ALSO found to silently strip a path's own leading/trailing whitespace
even where embedded spaces happened to parse correctly (an adjacent
defect class the coordinator's remedy instructions asked to be pinned
alongside the reported one). A separate, related latent bug was found
and fixed in the same pass: `parse_manifest`'s prior duplicate-path/
duplicate-basename detection joined seen paths into a SPACE-separated
string and checked containment via a `case "* $x *"` substring pattern --
unsound once paths may contain spaces (a target literally named "b.txt"
would have been FALSELY rejected as a duplicate of an earlier, unrelated
"a b.txt", since " a b.txt " contains " b.txt " as a literal substring);
replaced with newline-delimited accumulator files checked via
`grep -qxF` (exact whole-line match -- a path can never itself contain a
newline in this line-oriented manifest format, so this is unambiguous).
New regression coverage in BOTH runtimes proves: whitespace-path publish
success + byte-exact journal `live_path` + single (never concatenated)
hash values per field; mid-batch-crash convergence with a whitespace
path, including the journal read during recovery; the false-positive-
duplicate fix; genuine duplicate-path/duplicate-basename detection still
firing correctly; and (sh-only, where the fix lives) a literal tab
character embedded in a path surviving end-to-end. TDD Red (script
relocated, both runtimes): `bash` 21/50 reached, `pwsh` 15/40 reached ->
Green: `bash` 52/52, `pwsh` 41/41. The 5 Minor findings: #1
(CHANGELOG.md's stale 38/27 tally) was explicitly authorized for update
by the coordinator and is corrected in this same entry, above; the other
4 are carryover (no code change) per the coordinator's instruction. Full
detail in `reports/implementation/epic-189-a1-project-context/T-007.md`'s
own "Quality Gate Remedy (seq0358)" section.

QUALITY-GATE REMEDY 3 (2026-07-31, seq0359 NEEDS_WORK -> remedy applied,
FINAL round of this attempt): `reports/quality-gate/
2026-07-30T224124Z-T-007.md` (commit `9b23592f`) returned Critical 2 /
Major 1 / Minor 3 -- the THIRD consecutive round finding the same
underlying CLASS (sh/ps1 diverging on a path character the design
contract never restricts), each round in a different mechanism. This
remedy targets CLASS ELIMINATION per the coordinator's explicit mandate.
Root cause: `json_get_targets` (sh journal reader) used hand-rolled sed/
character-scanning that could not reverse json_escape's own JSON string
escaping (Critical: a `"` or `\` in live_path made recovery probe the
WRONG path, declare false ALL-PRE, and delete the journal+backups --
an unrecoverable mixed state reported as SUCCESS) nor correctly find
object boundaries when live_path contained a literal `}` (Critical:
permanently bricked the publisher on its own well-formed journal).
Separately, `walk_relative_dir`'s unquoted `set -- $relpath` underwent
pathname expansion (Major, sh): a glob-metacharacter segment (e.g.
`a*b`) silently redirected the publish to an unrelated EXISTING
directory while reporting success under the declared name. Fixing the
reported ps1-side `New-Item -Path` equivalent surfaced a DEEPER
PowerShell/.NET bug: `Set-Location -LiteralPath` itself was verified,
empirically, to mis-resolve ANY wildcard-containing segment (relative,
absolute, or `[WildcardPattern]::Escape()`-escaped) against an existing
directory -- not a caller error but a genuine FileSystemProvider quirk.
Fix: sh's `json_get_targets` rewritten as a real JSON-string-aware
parser in awk (character-by-character, correctly treats structural
characters inside a parsed string as ordinary content, reverses every
escape json_escape's closed emit set produces plus the standard JSON
escapes generally). sh's `walk_relative_dir` now splits segments via
pure parameter expansion (`${rest%%/*}`/`${rest#*/}`), never touching
the filesystem. ps1's three anchoring helpers were rewritten to use
ONLY `[System.IO.Directory]::SetCurrentDirectory` (verified wildcard-
safe in every case tested), never Set-Location/Push-Location/
Pop-Location again -- `$PWD` is deliberately never touched, so every
remaining cmdlet call that relied on it was converted to an absolute
path computed via `[System.IO.Path]::Combine` against
`[System.Environment]::CurrentDirectory`. Two further genuine bugs
found during the hostile-path matrix build, fixed in the same pass:
json_escape did not escape TAB (invalid per RFC 8259, rejected by a
strict `python3 json.load`); and a literal backslash is GENUINELY
unsupportable on ps1 (PowerShell/.NET treats `\` as a directory
separator on every platform, verified) -- classified-rejected
(`UNSUPPORTED_PATH_CHARACTER`) in BOTH runtimes rather than a silent
sh/ps1 capability divergence. A literal newline in a path was confirmed
structurally unrepresentable in the line-oriented manifest format (no
new code needed). Authorized Minor fix: `write_journal` now round-trip-
verifies before rename, matching design.md:1020-1022 (ps1 already did).
New hostile-path property matrix (TEST-033t, both suites): publish ->
mid-batch crash -> recovery convergence -> journal byte round-trip (real
python3 json.load / ConvertFrom-Json) -> T-005-reader surrogate query ->
sh/ps1 parity, machine-driven across space, tab, leading/trailing
whitespace, `"`, `{`, `}`, `,`, `*`, `?`, `[`, `]`, `$`, backtick, `'`,
UTF-8 multi-byte (backslash verified rejected identically instead).
`bash` 52->130 (78 new), `pwsh` 41->72 (31 new); both 100% PASS. TDD Red
(script relocated): `bash` 66/128 reached, `pwsh` 15/71 reached ->
Green: 130/130, 72/72. All four AC-033 crash-injection scenarios
re-verified in both runtimes. Full detail in `reports/implementation/
epic-189-a1-project-context/T-007.md`'s own "Quality Gate Remedy
(seq0359)" section.

QUALITY-GATE REMEDY 4 (2026-07-31, seq0360 NEEDS_WORK -> remedy applied,
human explicitly authorized remedy-4 + a possible round-5):
`reports/quality-gate/2026-07-31T113826Z-T-007.md` (commit `3f57c485`)
returned Critical 1 NEW / Major 3 / Minor 1 -- the first Critical, past
three parity-focused rounds, where `sh` and `ps1` fail IDENTICALLY (not
a parity break), reached via a far more easily triggered vector than any
prior round. Critical: the live-hash probe coerced ANY walk failure
(missing parent segment, symlink replacement, or access-denied `cd`/
`SetCurrentDirectory`, e.g. chmod 000) to the bare string "ABSENT",
indistinguishable from a confirmed absence -- during recovery this let a
target already advanced to POST look identical, after an ordinary
parent-directory disturbance, to one never touched, and recovery deleted
the journal and pre/ backup UNCONDITIONALLY, permanently stranding the
live target at POST with no way back. design.md:1055-1056's own required
post-revert confirmation step did not exist in code at all. Fix: the
probe never coerces a walk failure to ABSENT again; `walk_relative_dir`/
`Invoke-WalkRelativeDir` now distinguish "plainly does not exist" from
"exists but blocked" (symlink/access-denied/non-directory); an explicit
tolerate-not-found flag, passed ONLY by the very first journal-free
PREPARE-time probe, is the sole exception; recovery (classification
pass, revert pass, and a NEW mandatory post-revert confirmation pass
implementing design.md:1055-1056 literally) never uses it, and fails
closed (RECOVERY_FAILED, journal/backups retained) on any probe failure
of any kind. The equivalent PREPARE-time failure is now also fail-closed
via a new LIVE_PROBE_FAILED category (exit 21, both runtimes). Two
further latent bugs found while building the regression fixture, fixed
in the same pass: the awk journal reader's `\uXXXX` decoder restricted
decoding to printable ASCII, corrupting every C0 control byte back to
"?"; and its hex-to-integer conversion used `strtonum`, a gawk-only
extension absent from macOS's default `/usr/bin/awk`, hard-crashing the
first time this path was ever actually exercised -- both fixed (widened
range; portable `hex2dec` helper). Major #1+#2 (sh `json_escape`
under-escaping C0 controls; ps1 `Get-Content` mis-splitting a bare CR)
resolved under one consistent per-character policy: end-to-end
representable in both runtimes -> escape + cover in the matrix;
structurally unrepresentable in either runtime -> UNSUPPORTED_PATH_
CHARACTER in both, symmetrically. Major #3: a new glob-in-directory-
segment regression lock (TEST-033u, both suites) closes the coverage
gap the evaluator proved by mutation (TEST-033t's own fragments are
always the manifest leaf, never a directory segment). Minor (--help
absence) confirmed non-blocking by the evaluator's own adjudication, no
code change. `bash` 130->174 (44 new), `pwsh` 72->100 (28 new); both
100% PASS. TDD Red (script relocated to pre-remedy4 state): `bash`
151/174 reached, `pwsh` 88/100 reached -> Green: 174/174, 100/100. All
four AC-033 crash-injection scenarios re-verified in both runtimes (logs
re-captured, since the recovery-path internals changed substantially).
Full detail, including the per-character policy table, in
`reports/implementation/epic-189-a1-project-context/T-007.md`'s own
"Quality Gate Remedy (seq0360)" section.

QUALITY-GATE REMEDY 5 (2026-08-01, seq0361 NEEDS_WORK -> remedy applied;
human-authorized round, escalated to a stronger model because remedy 4
INTRODUCED the Critical): `reports/quality-gate/
2026-07-31T141033Z-T-007.md` (commit `a462bf73`) returned Critical 1 /
Major 3 / Minor 1. (a) Critical (a REGRESSION from remedy 4) -- remedy 4
made every recovery-stage walk failure fatal, including "this segment
plainly does not exist", which is the ordinary state of every
not-yet-committed target in a first-ever publish (the tool creates
destination directories on demand, and PREPARE already tolerates
not-found for exactly that reason). With NO hostile input, a 2-target
batch into not-yet-existing directories crashed at `journal-write`
returned exit 17 RECOVERY_FAILED forever and retained the journal, so
every later unrelated batch also failed -- a permanent brick, in both
runtimes, violating AC-033 and design.md:1042-1046/1056-1063. design.md
was read in full before choosing the remedy and is NOT ambiguous here:
:1036-1037 requires the probe to "re-hash ... (or note `ABSENT`)" and
:1042-1046 makes "(or both are `ABSENT`) => SAFE abandonment" a REQUIRED
terminal verdict, so observing ABSENT is mandatory, not optional. The fix
keeps remedy 4's Critical fix fully intact by distinguishing an
OBSERVATION from a FAILURE-TO-OBSERVE, using the journal's OWN recorded
`pre_hash` as the discriminator: symlink / access-denied /
blocked-by-a-non-directory always fail closed (the segment exists but its
contents cannot be read); a plainly-missing chain is accepted ONLY where
the journal recorded `pre_hash="ABSENT"`, because a REAL recorded
pre_hash proves the whole chain existed and held a regular file at
journal-write time, making a clean not-found now evidence of destruction
rather than the first-ever-publish shape. Implemented as one named helper
per runtime (`recovery_probe_live_target` / `Get-RecoveryProbe`) used by
all three recovery probes. (b) Major #1 -- remedy 4's own headline fix
(the design.md:1055-1056 post-revert confirmation pass) had ZERO
regression coverage; new TEST-033x in both suites locks it via a target
moved to a THIRD state after the crash, where the classification pass
sees a MIX and the revert pass legitimately skips it, so only the
confirmation pass can catch the non-terminal state. (c) Major #2 -- the
DUPLICATE_BASENAME_IN_BATCH guard was byte-exact, so `d1/File.txt` +
`d2/file.txt` collided in the single design.md:1011 `pre/<basename>` slot
on macOS APFS and destroyed one target's PRE bytes; fixed with a
conservative always-ASCII-case-insensitive parse-time fold (identical in
both runtimes by construction, applied on every platform so the verdict
never depends on the volume) PLUS a PREPARE-time backup-slot exclusivity
check that lets the filesystem itself decide non-ASCII/normalization
collisions -- both under the existing category and exit code 19, both
before any live mutation. (d) Major #3 -- `exec 8<. 2>/dev/null`
redirected the sh script's OWN stderr for the remainder of execution,
discarding every diagnostic after it (measured: 0 bytes on stderr for a
denial that put 205 bytes on stdout, against 205/205 in pwsh -- also a
live parity break); the suppression and both vestigial, never-read file
descriptors were removed and the header's inaccurate "held fd provides
identity pinning" claim corrected to name the real mechanism (the
`stat_id` device+inode re-check before the rename). (e) Minor -- the
report's stale 130/72 Test Result line refreshed to the delivered
numbers. STRUCTURAL (the reason for the escalation): the fixture harness
now varies a destination-directory-existence AXIS -- every
crash-injection/recovery scenario runs in BOTH `pre-existing` and
`absent` (first-ever-publish) form in BOTH runtimes, asserting against
abstract PRE/POST states rather than hardcoded bytes -- instead of
gaining one more point fixture; TEST-033v is now the 3-trigger axis
crossed with the existence axis (6 combinations per runtime), and
TEST-033y gained a no-live-content sub-case specifically to isolate the
two collision guards, which otherwise mask each other on a
case-insensitive volume. Every fix is mutation-proven in scratch copies
(never the repository): reverting each one makes the matching assertions
fail -- Critical 11 sh / 11 ps1, confirmation pass 5 / 5, ASCII fold
2 / 2, slot check 2 / 2, stderr 1 (sh-only defect). `bash` 174->218 (44
new), `pwsh` 100->146 (46 new); both 100% PASS. TDD Red (the FINAL test
set run against the pre-remedy HEAD scripts in a scratch layout): `bash`
200 passed / 18 failed, `pwsh` 129 passed / 17 failed -> Green 218/218,
146/146. All four AC-033 crash-injection scenarios re-proved in both
runtimes across both axis variants (8 scenario runs per runtime, all
converging with journals-left=0; transcripts re-captured). Full detail,
including the design derivation and the axis-variation table, in
`reports/implementation/epic-189-a1-project-context/T-007.md`'s own
"Quality Gate Remedy (seq0361)" section.

---

## T-008 Author the hook-activation handshake (`check-hook-activation-handshake`)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (sudo 2026-08-01T13:46:38Z)

Status: Done

Risk: high

Risk Rationale: An availability/fail-open-vs-fail-closed decision per
`risk-classification-policy.md:16` — a handshake that reports
`HOOK_ACTIVE` when denial was not actually observed would let Capability
Mode proceed on a runtime whose guard is not installed, exactly the
failure decision doc §7 v2 names (Codex `plugin_hooks` flag absent;
Copilot subagent hook non-firing). The redesigned sentinel two-branch/
cleanup-confirmation/stale-start logic is itself a fail-open surface if
misclassified.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-010

Depends On: T-007 only for this task list's mandatory shared-file
numeric-order append serialization (Global Constraints) — this task's own
proof is FIXTURE-SIMULATED (synthetic recorded-result evidence, design.md
Test Strategy item 9), so it does not require the sentinel path to already
be live-protected; it only requires the SCRIPT to exist before T-009 can
register its path as protected.

Planned Files:
- `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py`
  (new, agent-editable — becomes protected only after T-009)
- `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh` /
  `.ps1` (new, agent-editable)
- `tests/check-hook-activation-handshake.tests.sh` / `.ps1` (new,
  agent-editable — fixture recorded-result evidence per runtime; a fixture
  guard stub that does NOT deny; stale-sentinel and cleanup-failure
  fixtures)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — eighth in
  numeric order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new files.

Rollback: revert this task's two commits.

### Goal

Implement the challenge/response handshake: `--emit-challenge` issues a
nonce and sentinel target; `--verify-response` reports `HOOK_ACTIVE` only
given a recorded result matching a runtime's documented expected-deny
signature AND a matching nonce, `CAPABILITY_RUNTIME_UNAVAILABLE` otherwise
— including the sentinel's two-branch non-mutation behavior, mandatory
cleanup-success confirmation, `SENTINEL_CLEANUP_UNCONFIRMED` reporting,
and the next invocation's stale-start detection/cleanup-first recovery.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Architecture — HANDSHAKE
  node; Design Decisions — B4/B5/sentinel-cleanup-confirmation)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-027, AC-032)
- `docs/ai-dlc-foundation-decision-v2.md` §7 v2 (Hook 稼働ハンドシェイク)

### Scope

Commit A (TDD Red → Green):

- Red: TEST-027 (fixture recorded-result matching each of the three
  runtimes' expected-deny signatures + matching nonce ⇒ `HOOK_ACTIVE`;
  write-executed / unrecognized / missing / stale-nonce results ⇒
  `CAPABILITY_RUNTIME_UNAVAILABLE`), TEST-032 (sentinel two-branch:
  hook-fires branch absent-before/absent-after, no cleanup triggered;
  hook-does-not-fire branch requires a RECORDED, confirmed-successful
  cleanup-delete result before resolving; a missing/denied cleanup result
  reports `SENTINEL_CLEANUP_UNCONFIRMED` alongside
  `CAPABILITY_RUNTIME_UNAVAILABLE`; the NEXT `--emit-challenge` detects a
  stale sentinel at START, cleans it up first, and still resolves its own
  new challenge correctly) against a not-yet-implemented handshake and a
  fixture guard stub that does NOT deny.
- Green: implement the handshake; run against the fixture recorded-result
  set for all three runtimes.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-027 proves the fail-closed verify-response contract across all
  three runtimes' fixture evidence, never `HOOK_ACTIVE` without a genuine,
  fresh, runtime-matched denial (AC-027).
- [ ] TEST-032 proves the sentinel two-branch non-mutation behavior,
  mandatory cleanup-success confirmation, `SENTINEL_CLEANUP_UNCONFIRMED`
  reporting, and stale-start recovery (AC-032).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded in the implementation report; an
  independent quality-gate verdict (a named second reviewer) records PASS.

### Out of Scope

- Wiring the handshake into any of REQ-009's five entry points (T-011,
  T-012).
- A live, cross-runtime, real-agent-session proof of the underlying guard
  actually firing — explicitly Epic A8's own mandatory Done condition
  (design.md Test Strategy item 9, Non-goals), never claimed here.

### Blockers

T-007

---

## T-009 Register the sidecar, registry, publisher, and verification scripts in guard-invariants (human-copy)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (aharada54914 2026-08-01T12:58:44Z)

Second Approval: Approved (aharada227 2026-08-03T13:14:21Z)

Status: Done

Risk: critical

Risk Rationale: Per `risk-classification-policy.md:17` ("irreversible
destructive operations" / safety-regulated surface), this task edits the
repository's own enforcement-chain protected-file inventory
(`guard-invariants.json`, `generate-guard-invariants.py`, and the four
generated files) — an incorrect or partial edit fails
`generate-guard-invariants.py --check` for EVERY subsequent, unrelated
change in this repository (design.md Risks), and an incorrect
`protected_gate_suffixes` entry could under- or over-protect a path
repository-wide. This task also performs the one-time bootstrap that makes
`apply-human-copy.{sh,ps1}` itself protected (B9).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-007

Depends On: T-002, T-003, T-005, T-006, T-007, T-008 (registers every
concrete script/data path those tasks introduce, per the single canonical
`PROTECTED-MANIFEST.md` — design.md Protected-File Statement: 24 concrete
+ 4 reserved = 28 entries; T-004's schema is not itself a protected-file
registration target, but T-005/T-006 transitively cover it for this task
list's shared-file numeric-order append serialization since T-005 blocks
on T-004).

Planned Files:
- `specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md`
  (new — the single canonical protected-path manifest every other count in
  this package derives from; the six ADR-0019-item-3 categories, 24
  concrete + 4 reserved entries)
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json`
  (new staged candidate — adds the 24 concrete + 4 reserved entries to
  `protected_gate_suffixes`, plus a new `epic_a1_targets` key)
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
  (new staged candidate — adds the `EPIC_A1_TARGETS` constant, 28 entries
  generated from `PROTECTED-MANIFEST.md`, to `expected_protected`'s
  computation and `REQUIRED_TOP_LEVEL`/validation for `epic_a1_targets`)
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
  / `guard-invariants.generated.{js,ps1,sh}` (new staged candidates —
  regenerated outputs)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (new
  entries for all six guard-invariants files plus `PROTECTED-MANIFEST.md`)
- `tests/guard-invariants-epic-a1.tests.sh` / `.ps1` (new, agent-editable —
  asserts the STAGED candidates' internal consistency (`EPIC_A1_TARGETS`
  matches `PROTECTED-MANIFEST.md`'s table exactly) and a staged-tree
  `--check` pass; cannot assert the live inventory until after human
  application)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — ninth in numeric
  order)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; purely additive registration.

Rollback: reverting this task's agent-authored commit does NOT
automatically revert an already-human-applied `guard-invariants.json`/
generated-file change — the revert PR states explicitly whether a human
should also hand-revert that application.

### Goal

Stage a consistent, staged-tree-`--check`-passing update to
`guard-invariants.json` + `generate-guard-invariants.py` + the four
generated files, registering every new protected path this epic
introduces (24 concrete + 4 reserved = 28 entries) via the single
canonical `PROTECTED-MANIFEST.md`, applied through T-007's
`apply-human-copy` — including the one-time bootstrap that makes
`apply-human-copy.{sh,ps1}` itself protected.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Protected-File Statement,
  in full — the six ADR-0019-item-3 categories, the 24+4 count, the
  exact-match constraint, publisher self-protection)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-021, AC-022,
  AC-038)
- `plugins/sdd-quality-loop/references/guard-invariants.json` (current
  live content, to diff against)
- `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:1-296`
  (exact-match validation logic; re-verify `BASELINE_SUFFIXES`/
  `PHASE2_TARGETS` are as design.md records before drafting
  `EPIC_A1_TARGETS`)
- `docs/adr/0011-phase2-handle-relative-protected-copy.md`

### Scope

Commit A (implementation — manifest + staged candidates + staged-tree
proof + test):

- Author `PROTECTED-MANIFEST.md` listing all 24 concrete + 4 reserved
  entries by ADR-0019-item-3 category.
- Draft the six staged guard-invariants candidate files, extending JSON
  and Python source in the SAME change (design.md's exact-match
  constraint), generated FROM the manifest, never hand-duplicated.
- Run `generate-guard-invariants.py --check` AGAINST THE STAGED TREE (not
  the live one) and record the passing result as evidence (AC-021).
- Write `tests/guard-invariants-epic-a1.tests.sh`/`.ps1` asserting the
  staged candidates' internal consistency, the manifest/generator sync,
  and the staged-tree `--check` pass; register the suite.
- Record the LIVE files' SHA-256 before this commit, to be re-compared
  after (AC-022).

Commit B: APPEND to `CHANGELOG.md`'s #189 entry, explicitly noting this
task requires a human-apply step before Done.

**Human apply step (separate, explicit — required before Done):**

- [ ] A human maintainer bootstraps `apply-human-copy.{sh,ps1}` itself via
  one plain, human-verified `cp` + SHA-256 check (B9, this is the ONE
  exception to "every human-copy application goes through the tool").
- [ ] The human then uses the now-live `apply-human-copy` to publish
  `PROTECTED-MANIFEST.md` and the six guard-invariants candidates, each
  verified against `MANIFEST.sha256` before and after.
- [ ] The human re-runs `python3
  plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check`
  against the now-live tree and confirms it passes.
- [ ] The human confirms (via `tests/hook-guard-epic-a1-boundary.tests.sh`
  once T-010 lands, or a throwaway write attempt beforehand) that the new
  protected paths are now denied by the live guard.

### Done When

- [ ] TEST-021 proves the staged inventory's internal consistency, the
  manifest-derived 28-entry count, and the staged-tree `--check` pass
  (AC-021).
- [ ] TEST-022 proves the LIVE guard-invariants files are byte-identical
  before/after this task's own agent commit (AC-022).
- [ ] TEST-038 proves both RESERVED entries
  (`resolve-project-context.{py,sh,ps1}`,
  `generated/project-context.resolved.json`) are present in the staged
  candidate and all six ADR-0019-item-3 categories are represented,
  concretely or as a reservation (AC-038).
- [ ] The Human apply step above is complete and recorded in the
  implementation report (file paths, SHA-256s, and the post-apply
  `--check` result).
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded (Red: the staged-tree `--check`
  failing against an intentionally-incomplete draft candidate; Green: the
  final staged candidate passing) in the implementation report; an
  independent quality-gate verdict (a named second reviewer) records PASS,
  including confirmation the human-apply step occurred; a second, distinct
  named approver additionally reviews and signs the evidence bundle
  (Risk: critical, `risk-classification-policy.md:17`).

### Out of Scope

- Any edit to `_is_protected_gate_file`'s decision logic itself (T-010
  only verifies it, per REQ-008's own scope).
- `PHASE2_TARGETS`/`BASELINE_SUFFIXES` — both remain untouched, frozen
  constants.

### Blockers

T-002, T-003, T-005, T-006, T-007, T-008

---

## T-010 Verify the hook-guard extension (protected-write full-matrix deny)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (aharada54914 2026-08-03T13:46:18Z)

Status: Planned

Risk: high

Risk Rationale: Security-sensitive verification of an access-control
enforcement path per `risk-classification-policy.md:16` — this task does
not edit `sdd-hook-guard.*`'s decision logic (REQ-008's own scope excludes
that), but a false-positive test result (asserting denial that does not
actually hold, across any of the 96 cells) would leave the sidecar/
registry/scripts/sentinel effectively unprotected while claiming
otherwise.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-008

Depends On: T-009 (the human-apply step must have landed; this task tests
the LIVE, now-active deny path, not a staged one — this is also the
immediately-preceding numeric-order task for this task list's shared-file
append serialization).

Planned Files:
- `tests/hook-guard-epic-a1-boundary.tests.sh` / `.ps1` (new,
  agent-editable — exercises the full 12-call-site matrix against the four
  new protected basenames, including under a fixture `SDD_SUDO` token)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — tenth in numeric
  order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; test-only task, no production code edited.

Rollback: revert this task's two commits; no protected file is edited by
this task itself.

### Goal

Prove, against the LIVE, post-T-009-application hook guard, that a write
attempt against each of the four protected basenames
(`sdd/project-context.approval.json`, `sdd/provider-bindings.approval.json`,
`sdd/approver-registry.yaml`, `sdd/.hook-canary-sentinel`) is denied
through all 12 of `_is_protected_gate_file`'s call sites, including under
an active, fixture-constructed `SDD_SUDO` token — 4×12×2 = 96 independent
assertions, never a per-basename spot check (design.md Test Strategy item
8's explicit surface table).

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Test Strategy item 8, the
  12-row surface table, in full)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-023)
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` (re-enumerate the
  current 12-call-site set at this task's own implementation-start time,
  per requirements.md Assumptions)

### Scope

Commit A (TDD Red → Green):

- Red: run the new suite against a PRE-T-009-application state (or a
  fixture guard-invariants snapshot lacking the new entries) and confirm
  it fails (proving the test is not vacuously green).
- Green: run the same suite against the live, post-application state;
  capture the passing run, all 96 cells.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-023 proves denial for all four new protected basenames across
  all 12 call sites, including under an active fixture `SDD_SUDO` token —
  96 independent assertions (AC-023).
- [ ] The suite's Red run (pre-application state) is recorded as failing,
  proving the assertion is live.
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded in the implementation report; an
  independent quality-gate verdict (a named second reviewer) records PASS.

### Out of Scope

- Any decision-logic edit to `sdd-hook-guard.*` (none is needed or made).
- Surfaces documented as a residual gap (`ln`, in-process interpreter
  writes) — design.md Test Strategy item 8's documented exclusion.

### Blockers

T-009

---

## T-011 Revise PLUGIN-CONTRACTS.md and the unprotected track-selection consumers

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (aharada54914 2026-08-03T13:46:18Z)

Status: Planned

Risk: high

Risk Rationale: Revised in this round, closing round-1 task-review's
RISK-APPROPRIATE finding (see `--edit-summary` below). Evaluated against
`risk-classification-policy.md:16` directly. This task implements, for 3
of REQ-009's 5 migrated consumers (`bootstrap`, `sdd-bootstrap-interviewer`,
`lite-gate`), the SAME ADR-0023 access-control precedence logic T-012
implements for the other 2 (`ship`, `lite-spec`): the four-case rule
(absent → compatibility fallback; present+valid → new precedence;
present-but-failing-REQ-005-validation → explicit `PROJECT_CONTEXT_INVALID`
stop, never treated as absent — security-spec.md's B5 "Track-selection
fail-open" boundary). A silent defect in this precedence logic (e.g. a
present-but-invalid Context mistakenly treated as absent) reproduces
exactly the "silent downgrade" ADR-0023 exists to close — the same failure
mode T-012's own `high` classification is justified against, for the
identical decision-branch class in the remaining 2 consumers. `medium`
was the round-1 classification; the Risk Rationale then claimed these 3
consumers "implement no new security-decision logic themselves," which
this task's own Goal/Scope text (the four-case rule these files gain)
contradicted — corrected here to `high`/`tdd` by direct parity with T-012.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-009

Depends On: T-001 (Project Context schema, for the four-case rule), T-006
(validator, consulted for the `PROJECT_CONTEXT_INVALID` explicit-stop
rule), T-008 (handshake, wired into each of this task's three entry
points), T-010 (this task list's mandatory shared-file numeric-order
append serialization).

Planned Files:
- `PLUGIN-CONTRACTS.md` (existing, agent-editable — Track Detection section
  revision)
- `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` (existing,
  agent-editable — track-selection revision + handshake wiring)
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`
  (existing, agent-editable — `spec_profile` gating revision at the three
  cited call sites + handshake wiring)
- `plugins/sdd-lite/skills/lite-gate/SKILL.md` (existing, agent-editable —
  track-selection revision + handshake wiring; confirmed in scope,
  design.md Components)
- `tests/plugin-contracts-track-selection.tests.sh` / `.ps1` (new,
  agent-editable — document-conformance + fixture-behavior checks for
  these four consumers)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — eleventh in
  numeric order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: `PLUGIN-CONTRACTS.md`'s documented priority order changes for
projects WITH a Project Context (new precedence); unchanged for projects
without one (compatibility fallback) — not a breaking change to any
existing, already-shipped behavior, since no Project Context consumer
exists in production yet.

Rollback: revert this task's two commits; no protected file touched.

### Goal

Revise `PLUGIN-CONTRACTS.md`'s Track Detection section per ADR-0023, and
the three unprotected consumer skills (`bootstrap`,
`sdd-bootstrap-interviewer`, `lite-gate`), per design.md's four-case rule:
Project Context physically absent → compatibility fallback (unchanged);
physically present and valid → the new precedence; physically present but
failing REQ-005 validation → explicit `PROJECT_CONTEXT_INVALID` stop,
never treated as absent; each entry point additionally calls T-008's
handshake.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Architecture — ENTRYPOINTS;
  Constraint Compliance — track-selection rows)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-024, and the
  unprotected-consumer half of AC-025/AC-026/AC-039)
- `docs/adr/0023-track-selection-contract-migration.md`
- `PLUGIN-CONTRACTS.md:61-66`
- `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:80-132`
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:147,159,199`
- `plugins/sdd-lite/skills/lite-gate/SKILL.md` (verify it reads track
  selection before assuming the edit's exact shape)

### Scope

Commit A (implementation):

- Write TEST-024 (document conformance) and the fixture-driven half of
  TEST-025/TEST-026/TEST-039 these three unprotected skills' prose can
  satisfy on their own (full end-to-end behavior lock for `ship`/
  `lite-spec` spans into T-012's own Done When).
- Revise `PLUGIN-CONTRACTS.md`, `bootstrap/SKILL.md`,
  `sdd-bootstrap-interviewer/SKILL.md`, and `lite-gate/SKILL.md`, wiring
  T-008's handshake at each entry point.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-024 proves `PLUGIN-CONTRACTS.md` documents the new precedence
  correctly (AC-024).
- [ ] The unprotected-consumer half of TEST-025/TEST-026/TEST-039's
  fixture coverage passes against `bootstrap/SKILL.md`'s,
  `sdd-bootstrap-interviewer/SKILL.md`'s, and `lite-gate/SKILL.md`'s
  revised text, including the `PROJECT_CONTEXT_INVALID` explicit-stop case
  distinct from the compatibility fallback.
- [ ] Each of these three consumers' handshake wiring is present at its
  own entry point (partial evidence toward AC-035, completed at T-012).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded in the implementation report,
  matching this task's now-`high` Risk tier (Red: fixture assertions
  against the CURRENT, unmigrated live text for all three consumers;
  Green: against the revised text); an independent quality-gate verdict
  (a named second reviewer, not the implementing agent) records PASS.

### Out of Scope

- `ship/SKILL.md` and `lite-spec/SKILL.md` (protected — T-012).
- The full 5-consumer common-contract-suite matrix and the full
  entry-point wiring inventory (T-012, since both need the protected
  consumers wired too).

### Blockers

T-001, T-006, T-008, T-010

---

## T-012 Migrate the protected track-selection consumers (`ship`, `lite-spec`) via human-copy and close out consumer wiring

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (aharada54914 2026-08-03T13:46:18Z)

Status: Planned

Risk: high

Risk Rationale: `plugins/sdd-ship/skills/ship/SKILL.md` and
`plugins/sdd-lite/skills/lite-spec/SKILL.md` are both R-10-protected
enforcement-chain files (`risk-classification-policy.md:16` — "access
control ... anything where a silent defect causes material harm"); this
task changes the actual, real-world-enforced track-selection precedence
and wires the hook-activation handshake into `ship`'s call site — a
defect here is the exact class of "silent downgrade" ADR-0023 exists to
close.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-009, REQ-010

Depends On: T-009 (`apply-human-copy` must be bootstrapped and protected
before this task's staged candidates are applied through it), T-011
(documented contract text and the three unprotected consumers this task's
matrix completes against — also this task list's mandatory shared-file
numeric-order append serialization, T-011 being the immediately-preceding
numeric-order task).

Planned Files:
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`
  (new staged candidate — Step 2 Track Detection revision plus the
  handshake call)
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md`
  (new staged candidate — track-selection revision + handshake wiring)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (new
  entries for both)
- `tests/ship-track-selection-migration.tests.sh` / `.ps1` (new,
  agent-editable — asserts the STAGED `ship`/`lite-spec` candidates'
  content, the full 5-consumer common-contract-suite matrix, and the full
  entry-point wiring inventory)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — twelfth in
  numeric order)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: the enforced track-selection precedence changes for projects
with a Project Context (intended; ADR-0023).

Rollback: reverting this task's agent-authored commit does NOT
automatically revert an already-human-applied `ship/SKILL.md`/
`lite-spec/SKILL.md` change — the revert PR states explicitly whether a
human should also hand-revert that application.

### Goal

Stage corrected `ship/SKILL.md` and `lite-spec/SKILL.md` content
implementing the four-case rule plus handshake wiring, apply it through
T-007's `apply-human-copy`, and prove the full 5-consumer common-contract-
suite matrix (`sdd-ship`, `sdd-bootstrap`, `sdd-bootstrap-interviewer`,
`lite-spec`, `lite-gate`) plus the full entry-point wiring inventory.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Architecture; Constraint
  Compliance)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-025, AC-026,
  AC-035, AC-039)
- `plugins/sdd-ship/skills/ship/SKILL.md:76-117`
- `plugins/sdd-lite/skills/lite-spec/SKILL.md:48`

### Scope

Commit A (implementation — staged candidates + tests):

- Draft the staged `ship/SKILL.md` and `lite-spec/SKILL.md` candidates,
  wiring T-008's handshake into `ship`'s call site.
- Write `tests/ship-track-selection-migration.tests.sh`/`.ps1` asserting
  the staged candidates' content against the full+`--lite` error-stop
  case, the lite+`--full` promotion case, the `PROJECT_CONTEXT_INVALID`
  explicit-stop case, the full 6-case × 5-consumer common-contract-suite
  matrix (30 assertions), and the full 5-consumer entry-point wiring
  inventory.
- Register the suite; stage the `test.yml` addition.

**Human apply step (separate, explicit — required before Done):**

- [ ] A human maintainer applies the staged `ship/SKILL.md` and
  `lite-spec/SKILL.md` candidates via the now-protected
  `apply-human-copy`, verifying each against `MANIFEST.sha256`.
- [ ] The human confirms (by re-running
  `tests/ship-track-selection-migration.tests.sh`/`.ps1` against the
  now-live files) that the staged behavior matches the live behavior
  post-copy.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry, explicitly noting this
task requires a human-apply step before Done.

### Done When

- [ ] TEST-025 proves the full+`--lite` error-stop case and the
  lite+`--full` promotion case against the staged candidates (AC-025).
- [ ] TEST-026 proves the `PROJECT_CONTEXT_INVALID` explicit-stop case,
  distinct from the compatibility fallback (AC-026).
- [ ] TEST-035 proves each of the five migrated consumers independently
  invokes the handshake at its own entry point (AC-035).
- [ ] TEST-039 proves the full per-consumer common-contract-suite matrix:
  each of the five consumers exercised against the identical six cases —
  30 independent assertions (AC-039).
- [ ] The Human apply step above is complete and recorded in the
  implementation report.
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded (Red: staged-candidate assertions
  against the CURRENT, unmigrated live text; Green: against the staged,
  migrated candidates) in the implementation report; an independent
  quality-gate verdict (a named second reviewer) records PASS, including
  confirmation the human-apply step occurred.

### Out of Scope

- Any change to `impl-review-loop/SKILL.md`'s own `spec_profile: lite`
  read — not a track-*selection* surface, out of this epic's named
  consumer list (investigation.md).

### Blockers

T-009, T-011

---

## T-013 Close out three-environment test coverage and CI wiring

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved (aharada54914 2026-08-03T13:46:18Z)

Status: Planned

Risk: medium

Risk Rationale: Test/CI-wiring closing task per
`risk-classification-policy.md:15` — no production logic change; the risk
this task manages is coverage-completeness, not behavior correctness (each
prior task already TDD'd its own behavior).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-011

Depends On: T-001 through T-012 (all must be Implementation Complete or
later; this task audits their combined output).

Planned Files:
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (final consolidated staged candidate, superseding each prior task's own
  incremental staging, if any drift is found)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (final
  consolidated entries)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — audit only, no
  new entries expected if T-001..T-012 registered correctly)
- `CHANGELOG.md` (existing, agent-editable — APPEND, closing entry)

Data Migration: none.

Breaking API: no.

Rollback: revert this task's commits; the final `test.yml` human-apply
step (if any residual staging remains) follows the same human-apply
discipline as prior tasks.

### Goal

Run the full local suite (`bash tests/run-all.sh` and
`pwsh tests/run-all.ps1`) end to end, confirm every suite T-001..T-012
added is registered and green, confirm the non-use declarations (no real
LLM/`gh`/`sdd-sudo` invocation — `SDD_SUDO` in T-010's suite is a
locally-signed fixture token, never a live grant) and the CI-resilience
checklist hold across every new suite, and reconcile the
`.github/workflows/test.yml` human-copy staging into one final, consistent
candidate if any task's staging left drift.

### Must Read

- `specs/epic-189-a1-project-context/design.md` (Test Strategy items 11
  and 12; Deployment / CI Plan)
- `specs/epic-189-a1-project-context/acceptance-tests.md` (AC-028, AC-029)
- `specs/epic-189-a1-project-context/tasks.md` (this file, T-001..T-012)
- `tests/run-all.sh` / `.ps1` (post-T-001..T-012 state)

### Scope

Commit A (audit + reconciliation):

- Run the full local suite twice (bash, pwsh); record both results.
- Audit every new `.sh` suite against the CI-resilience checklist; fix any
  violation found (should be none, if each prior task followed Global
  Constraints — this is a verification pass, not expected to require new
  logic).
- Reconcile any `.github/workflows/test.yml` staging drift across
  T-001..T-012's incremental candidates into one final, consistent staged
  file.

Commit B: APPEND a closing `CHANGELOG.md` entry summarizing the epic's full
addition under #189's entry.

### Done When

- [ ] TEST-028 proves every new suite self-registers and the
  `.github/workflows/test.yml` staged/live-unchanged/post-copy-registered
  3-part proof holds across the FULL set of suites T-001..T-012 added
  (AC-028).
- [ ] TEST-029 proves the non-use declarations and CI-resilience checklist
  hold across every new suite (AC-029).
- [ ] Full local suite run (`bash tests/run-all.sh`,
  `pwsh tests/run-all.ps1`) passes, recorded in the implementation report.
- [ ] `CHANGELOG.md`'s #189 entry is finalized.
- [ ] Acceptance-first evidence (per risk-classification-policy.md:15)
  recorded in the implementation report; an independent quality-gate
  verdict (a named second reviewer) records PASS.

### Out of Scope

- Any new production script or schema (this is a closing audit task only).

### Blockers

T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010, T-011, T-012
