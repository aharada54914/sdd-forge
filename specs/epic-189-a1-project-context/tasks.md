# Tasks: epic-189-a1-project-context

Task-Review-Status: Pending

Source: Issue #189 (Epic A1 — "Project Context + 承認防衛") /
requirements.md (Spec-Review-Status: Pending) /
design.md (Impl-Review-Status: Pending)

**This task plan is a Draft, authored in the same spec-authoring session as
requirements.md/design.md, ahead of the actual spec-review/impl-review
gates.** Per `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:88-112` and
`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:681-682`,
`tasks.md`'s normal existence precondition is `Impl-Review-Status: Passed`;
this package intentionally deviates from that sequencing at the parent
task's explicit instruction (investigation.md INV-008, requirements.md
OQ-003) and reports the resulting `check-workflow-state.sh` tension
honestly rather than silently working around it. No task below may be
started until a human has actually run `spec-review-loop` and
`impl-review-loop` to `Passed` against this package, in a later session.

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
protected
(`_PROTECTED_GATE_SUFFIXES`, `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`,
loaded by `sdd-hook-guard.py:891`'s `_load_guard_invariants()`, verified
against current HEAD at spec-authoring time):
`plugins/sdd-quality-loop/references/guard-invariants.json`,
`plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`, the four
`generated/guard_invariants.{py,js,ps1,sh}` files,
`plugins/sdd-ship/skills/ship/SKILL.md`,
`plugins/sdd-lite/skills/lite-spec/SKILL.md`, and
`.github/workflows/test.yml`. **No task below writes any of these nine
files directly.** T-006 stages the six guard-invariants files; T-010 stages
the ship and lite-spec skill files; every task registering a new test
suite stages its own `.github/workflows/test.yml` addition. Every staged
file goes under
`specs/epic-189-a1-project-context/human-copy/<repository-relative-path>` +
a `MANIFEST.sha256` entry. **A human maintainer runs the `cp` for each
staged file and verifies its SHA-256 against the manifest — recorded as its
own, separate "human apply" step in that task's Done When — before the
task can be marked Done.** This epic does not extend or reuse
`specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`
(pinned to its own frozen bootstrap inventory, design.md Protected-File
Statement).

This epic ALSO creates five NEW files that become protected only after
T-006's human-copy lands:
`sdd/project-context.approval.json`, `sdd/provider-bindings.approval.json`,
`sdd/approver-registry.yaml`, and the eleven new script files
(`canonicalize-sdd-yaml.{py,sh,ps1,js}`,
`generate-approval-sidecar.{py,sh,ps1}`,
`validate-approval-sidecar.{py,sh,ps1}`,
`detect-policy-weakening.{py,sh,ps1}`,
`check-hook-activation-handshake.{py,sh,ps1}`) — these are ordinary,
agent-editable files at the time each authoring task (T-002..T-005, T-008)
lands, and become protected retroactively once T-006's registration is
applied.

**Re-verification discipline** (requirements.md Assumptions): every task
whose Planned Files include an already-protected path re-runs
`grep -F "<path>" plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
at its own implementation-start time before assuming the human-copy
procedure is still required.

## Global Constraints

- **Two-commit landing plan per task** (commit A = implementation +
  unprotected registrations + staging of any protected-file candidates;
  commit B = `CHANGELOG.md` entry + applicable doc surfaces), mirroring
  epic-159-pillar-c's established convention. Commit A must land before
  commit B within the same task.
- **`tests/run-all.sh` / `.ps1`** (unprotected, direct edit): T-002, T-003,
  T-004, T-005, T-007, T-008, T-011 each append only their OWN new suite's
  registration lines, in this task list's own numeric order.
- **`.github/workflows/test.yml`** (R-10 protected): the same tasks each
  stage their own registration addition via human-copy, in the same order,
  under `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  + a shared, task-appended `MANIFEST.sha256`.
- **`plugins/sdd-quality-loop/references/guard-invariants.json`,
  `generate-guard-invariants.py`, `generated/guard_invariants.*`**: T-006 is
  the SOLE editor within this epic; no other task stages a competing edit.
- **`PLUGIN-CONTRACTS.md`**: T-009 is the sole editor.
- **Version bumps only via `scripts/bump-version.sh`**; no task in this
  epic introduces a version-mutation path or executes a real release.
- CI-resilience (bash 3.2 empty-array safety under `set -u`; macOS
  `$TMPDIR` `pwd -P` normalization; Windows `jq.exe` CRLF stripping; no
  real-validator-gate probing) applies to every new `.sh` suite this epic
  adds.
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Author the project-context.yaml and provider-bindings.yaml schemas

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly.
medium is justified: (1) both artifacts are wholly new, additive JSON
Schema files with no existing consumer to break (AC-004's provider-name
absence proof and the schema's own `additionalProperties: false` posture
are the only behavioral claims this task makes); (2) no existing script,
skill, or contract is edited; (3) no secrets, authentication, or
irreversible operation is touched. It does not reach `high` because nothing
this task adds is yet CONSUMED by runtime code (T-002 onward are the first
consumers) and no existing validation is loosened.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-002

Depends On: none (root of the dependency graph; design.md Technical
Summary).

Planned Files:
- `contracts/project-context.schema.json` (new, agent-editable)
- `contracts/provider-bindings.schema.json` (new, agent-editable)
- `tests/project-context-schema.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (new staged candidate, agent-editable — this suite's CI steps; R-10
  protected real path, human-copy only)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (new,
  agent-editable)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #189)

Data Migration: none.

Breaking API: no; both files are wholly new.

Rollback: revert this task's two commits; the staged `test.yml` candidate
is a human-applied change — the revert PR states explicitly whether a
human should also hand-revert that step.

### Goal

Author `contracts/project-context.schema.json` (schema id
`sdd-project-context/v1`, design.md API/Contract Plan) and
`contracts/provider-bindings.schema.json` (schema id
`sdd-provider-bindings/v1`, skeleton only). Author fixtures proving AC-001
through AC-004.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md`
- `specs/epic-189-a1-project-context/acceptance-tests.md`
- `specs/epic-189-a1-project-context/investigation.md`
- `docs/adr/0016-workflow-axes-separation.md`
- `docs/adr/0018-provider-binding-separation.md`
- `docs/adr/0020-conditional-predicate-dsl.md`
- `docs/ai-dlc-foundation-decision-v2.md` §2, §5, §11, §12

### Scope

Commit A (implementation — schemas + fixtures + CI wiring):

- Write acceptance checks first (TEST-001..004): schema field presence and
  rejection (AC-001); per-path allowlist coverage (AC-002); provider-bindings
  skeleton positive/passthrough proof (AC-003); provider-neutrality proof
  (AC-004).
- CI resilience per Global Constraints.
- Register the new suite directly in `tests/run-all.sh`/`.ps1`; stage the
  `.github/workflows/test.yml` candidate under
  `specs/epic-189-a1-project-context/human-copy/` + `MANIFEST.sha256`.

Commit B (documentation):

- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #189.

### Done When

- [ ] TEST-001 proves schema field presence and required-field rejection
  (AC-001).
- [ ] TEST-002 proves all 8 ADR-0020 allowlist paths resolve against a
  schema field (AC-002).
- [ ] TEST-003 proves the provider-bindings skeleton's positive and
  passthrough behavior (AC-003).
- [ ] TEST-004 proves no fixed Provider enum exists (AC-004).
- [ ] `tests/project-context-schema.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`.
- [ ] Staged `.github/workflows/test.yml` candidate exists with a correct
  `MANIFEST.sha256` entry; the LIVE file's SHA-256 is unchanged before/after
  this task's commits.
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #189.
- [ ] Acceptance-first evidence recorded in the implementation report; an
  independent quality-gate verdict records PASS.

### Out of Scope

- Any consumer of these schemas (T-002 onward).
- The Reverse Coverage Gate (`check-component-coverage`) — Epic A3.

### Blockers

None

---

## T-002 Author the canonicalizer (`canonicalize-sdd-yaml`)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Touches a sensitive surface per
`risk-classification-policy.md` line 16 — this is the security-foundational
primitive every HMAC preimage (T-003) and every weakening-detector diff
(T-004) depends on for byte-stability; a defect here (e.g. an anchor/tag/
duplicate-key document silently accepted rather than rejected) would let an
ambiguous document's canonical hash diverge from a human reviewer's
understanding of its content — the exact class of harm ADR-0019's Context
section describes for the hash-recomputation Blocker attack.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003

Depends On: none (a generic YAML/JSON canonicalization primitive; design.md
Technical Summary treats it as parallel to T-001, not sequentially
dependent on it).

Planned Files:
- `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py` (new,
  agent-editable — becomes protected only after T-006)
- `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.sh` / `.ps1` /
  `.js` (new, agent-editable — thin dispatchers, `sdd-hook-guard.sh` shape)
- `tests/canonicalize-sdd-yaml.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND to #189's entry)

Data Migration: none.

Breaking API: no; wholly new script.

Rollback: revert this task's two commits; nothing protected is touched yet
(this task's own outputs are not yet registered as protected — T-006 does
that later).

### Goal

Implement YAML 1.2 core-schema parsing with explicit anchor/alias/
custom-tag/duplicate-key rejection, NFC string normalization, and RFC 8785
(JCS) canonical JSON serialization plus SHA-256 hashing, per design.md's
canonicalization procedure — a single Python implementation with thin
`sh`/`ps1`/`js` dispatchers mirroring `sdd-hook-guard.sh:1-53`.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md`
- `specs/epic-189-a1-project-context/acceptance-tests.md`
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh:1-53` (dispatcher
  shape to mirror)
- `docs/ai-dlc-foundation-decision-v2.md` §18.3
- `.gitattributes:1-9` (existing line-ending normalization, non-overlapping
  defense)

### Scope

Commit A (TDD Red → Green):

- Red: write TEST-005 (4 rejection-category fixtures), TEST-006 (1.2
  core-schema boolean proof), TEST-007 (NFC fixture pair), TEST-008 (JCS
  golden byte sequence), TEST-009 (multi-runtime hash equality + dispatch
  proof) against a not-yet-implemented script; capture the failing run.
- Green: implement `canonicalize-sdd-yaml.py` plus the three dispatcher
  wrappers; capture the passing run.
- CI resilience per Global Constraints.
- Register the suite; stage the `test.yml` addition.

Commit B (documentation): APPEND to `CHANGELOG.md`'s #189 entry, noting the
canonicalizer's addition.

### Done When

- [ ] TEST-005 proves anchor/alias/custom-tag/duplicate-key rejection, one
  fixture per category (AC-005).
- [ ] TEST-006 proves 1.2 core-schema boolean-coercion avoidance (AC-006).
- [ ] TEST-007 proves NFC-normalized byte/hash identity (AC-007).
- [ ] TEST-008 proves JCS-compliant canonical output against a golden byte
  sequence (AC-008).
- [ ] TEST-009 proves multi-runtime hash equality and dispatch-not-reimplement
  (AC-009).
- [ ] Suite self-registers; `test.yml` staged correctly; live `test.yml`
  unchanged.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red (failing suite against no implementation) and Green (passing
  suite against the real script) evidence recorded; independent quality-gate
  verdict records PASS.

### Out of Scope

- HMAC signing (T-003).
- Any consumer wiring (T-003, T-004).

### Blockers

None

---

## T-003 Author the approval sidecar schema and signer (`generate-approval-sidecar`)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Secrets handling per `risk-classification-policy.md` line
16 — this task implements `SDD_CONTEXT_KEY` resolution and HMAC-SHA256
signing, the direct mechanism ADR-0019 relies on to make approval
authenticity (not merely content binding) achievable.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-004

Depends On: T-001 (schema of the content files being hashed), T-002
(canonicalizer, consumed for the hash and the HMAC preimage).

Planned Files:
- `contracts/approval-sidecar.schema.json` (new, agent-editable)
- `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py` (new,
  agent-editable)
- `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.sh` / `.ps1`
  (new, agent-editable)
- `tests/generate-approval-sidecar.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new files.

Rollback: revert this task's two commits.

### Goal

Implement `contracts/approval-sidecar.schema.json` and
`generate-approval-sidecar.{py,sh,ps1}`: compute `context_sha256` via
T-002's canonicalizer against a content file, accept `--approver`,
`--status`, and `--effective-at`, construct the HMAC preimage (field-excluded,
canonicalized per design.md), resolve `SDD_CONTEXT_KEY` in the documented
four-step order, and sign — refusing to write any sidecar when no key
resolves.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md`
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:330-486`
  (`_resolve_sudo_key`/`sudo_active` precedent)
- `plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh:309-399`
  (`resolve_evidence_key`/`evidence_canonical` precedent)

### Scope

Commit A (TDD Red → Green):

- Red: TEST-010 (schema conformance), TEST-011 (signing round-trip +
  fail-closed-with-no-key), TEST-012 (preimage self-reference exclusion),
  TEST-013 (key-resolution byte-parity fixture matrix) against a
  not-yet-implemented tool.
- Green: implement the schema and the tool; capture the passing run.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-010 proves sidecar schema conformance, positive and negative
  (AC-010).
- [ ] TEST-011 proves a signing round-trip verifies, and no-key ⇒ no file
  written (AC-011).
- [ ] TEST-012 proves the `hmac` field's own value is excluded from its own
  preimage (AC-012).
- [ ] TEST-013 proves key-resolution byte-parity with `_resolve_sudo_key`/
  `resolve_evidence_key` (AC-013).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded; independent quality-gate verdict
  records PASS.

### Out of Scope

- Validation (T-005).
- Two-person/cooldown enforcement logic itself (T-004; this task only
  ACCEPTS a verdict it is given, it does not compute one).

### Blockers

T-001, T-002 (must be Implementation Complete or later)

---

## T-004 Author the approver registry schema and the policy-weakening detector

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Security-policy-decision surface per
`risk-classification-policy.md` line 16 — an under-classification here
(a real weakening change misclassified as non-weakening) would silently
skip the two-person/cooldown gate ADR-0019 item 6 exists specifically to
enforce; this is functionally an access-control decision, not an
informational report.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-006

Depends On: T-001 (diffs `project-context.yaml`/`provider-bindings.yaml`
fields), T-002 (canonicalizer, used to diff before/after documents on
stable byte content).

Planned Files:
- `contracts/approver-registry.schema.json` (new, agent-editable)
- `plugins/sdd-quality-loop/scripts/detect-policy-weakening.py` (new,
  agent-editable)
- `plugins/sdd-quality-loop/scripts/detect-policy-weakening.sh` / `.ps1`
  (new, agent-editable)
- `tests/detect-policy-weakening.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new files.

Rollback: revert this task's two commits.

### Goal

Author `contracts/approver-registry.schema.json` (schema id
`sdd-approver-registry/v1`) and `detect-policy-weakening.{py,sh,ps1}`,
implementing the weakening-category table (design.md API/Contract Plan)
and the two-person/cooldown verdict derivation against
`sdd/approver-registry.yaml`.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md` (weakening-category table)
- `docs/ai-dlc-foundation-decision-v2.md` §9 (Q8) v2
- `docs/adr/0019-approval-sidecar-protection.md`

### Scope

Commit A (TDD Red → Green):

- Red: TEST-016 (per-category classification + N/A reporting), TEST-017
  (strengthening-change negative proof), TEST-018 (two-person/cooldown
  verdict fixture pair) against a not-yet-implemented detector.
- Green: implement the schema and the detector; capture the passing run.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-016 proves every implemented weakening category classifies as
  weakening, and every documented-N/A category is reported as N/A
  explicitly (AC-016).
- [ ] TEST-017 proves a strengthening change is NOT misclassified as
  weakening (AC-017).
- [ ] TEST-018 proves the two-person/cooldown verdict derivation from a
  2-identity vs. 1-identity registry fixture (AC-018).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded; independent quality-gate verdict
  records PASS.

### Out of Scope

- The generator's enforcement of a two-person-required verdict at signing
  time (T-003 already ships that behavior against a verdict it receives;
  the end-to-end wiring proof — AC-019/AC-020 — is T-005's, since it needs
  the validator too).

### Blockers

T-001, T-002 (must be Implementation Complete or later)

---

## T-005 Author the approval validator (`validate-approval-sidecar`)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: This is the approval-defense mechanism's own enforcement
point per `risk-classification-policy.md` line 16 — a false PASS here
(hash/HMAC/identity/cooldown check any one of which is skipped or
mis-implemented) defeats every other REQ-004/REQ-006 guarantee this epic
builds.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-005

Depends On: T-003 (recomputes the generator's own construction), T-004
(re-derives the weakening verdict and reads the approver registry).

Planned Files:
- `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` (new,
  agent-editable)
- `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.sh` / `.ps1`
  (new, agent-editable)
- `tests/validate-approval-sidecar.tests.sh` / `.ps1` (new, agent-editable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new files.

Rollback: revert this task's two commits.

### Goal

Implement the four validation gates (hash match, HMAC verify, approver
identity, `effective_at`) plus the two-person/cooldown enforcement proof
(AC-019/AC-020) end to end against T-003's generator and T-004's detector
and registry.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md`
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:454-486`
  (`sudo_active`'s epoch-gate and `hmac.compare_digest` precedent)

### Scope

Commit A (TDD Red → Green):

- Red: TEST-014 (four independent rejection fixtures), TEST-015 (positive
  fixture), TEST-019 (two-person enforcement at signing — exercised via
  T-003's generator plus this validator's re-derivation), TEST-020
  (cooldown enforcement before/after `effective_at`) against a
  not-yet-implemented validator.
- Green: implement the validator; capture the passing run.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-014 proves all four independent rejection cases (AC-014).
- [ ] TEST-015 proves the positive PASS case (AC-015).
- [ ] TEST-019 proves two-person enforcement blocks premature signing and
  allows correctly-approved signing (AC-019).
- [ ] TEST-020 proves cooldown rejection before `effective_at` and
  acceptance after (AC-020).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded; independent quality-gate verdict
  records PASS.

### Out of Scope

- Wiring this validator into any Capability Mode gate beyond REQ-009's one
  call site (T-009/T-010).

### Blockers

T-003, T-004 (must be Implementation Complete or later)

---

## T-006 Register the sidecar, registry, and verification scripts in guard-invariants (human-copy)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: critical

Risk Rationale: Per `risk-classification-policy.md` line 17 ("safety/
regulated surface ... irreversible destructive operations"), this task
edits the repository's own enforcement-chain protected-file inventory
(`guard-invariants.json`, `generate-guard-invariants.py`, and the four
generated files) — an incorrect or partial edit fails
`generate-guard-invariants.py --check` for EVERY subsequent, unrelated
change in this repository (design.md Risks), and an incorrect
`protected_gate_suffixes` entry could under- or over-protect a path
repository-wide. Two-person review of the staged human-copy candidates
(beyond the standard task-review gate) is warranted given this blast
radius; recorded here as a Risk Rationale note for the human approver's
attention, not as a workflow this Draft task can itself enforce.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-007

Depends On: T-002, T-003, T-004, T-005 (registers every script and sidecar/
registry path those tasks introduce).

Planned Files:
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json`
  (new staged candidate — adds `sdd/project-context.approval.json`,
  `sdd/provider-bindings.approval.json`, `sdd/approver-registry.yaml`, and
  the eleven T-002/T-003/T-004/T-005/T-008 script paths to
  `protected_gate_suffixes`, plus a new `epic_a1_targets` key)
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
  (new staged candidate — adds the `EPIC_A1_TARGETS` constant to
  `expected_protected`'s computation and `REQUIRED_TOP_LEVEL`/validation
  for `epic_a1_targets`)
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
  / `guard-invariants.generated.{js,ps1,sh}` (new staged candidates —
  regenerated outputs)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (new
  entries for all six files above)
- `tests/guard-invariants-epic-a1.tests.sh` / `.ps1` (new, agent-editable —
  asserts the STAGED candidates' internal consistency and a staged-tree
  `--check` pass; cannot assert the live inventory until after human
  application)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable)
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
generated files, registering every new protected path this epic introduces,
under `specs/epic-189-a1-project-context/human-copy/`.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md` (Protected-File Statement)
- `plugins/sdd-quality-loop/references/guard-invariants.json` (current
  live content, to diff against)
- `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:1-296`
  (exact-match validation logic; re-verify `BASELINE_SUFFIXES`/
  `PHASE2_TARGETS` are as this design records before drafting
  `EPIC_A1_TARGETS`)
- `docs/adr/0011-phase2-handle-relative-protected-copy.md`

### Scope

Commit A (implementation — staged candidates + staged-tree proof + test):

- Draft the six staged candidate files, extending JSON and Python source in
  the SAME change (design.md's exact-match constraint).
- Run `generate-guard-invariants.py --check` AGAINST THE STAGED TREE (not
  the live one) and record the passing result as evidence (AC-021).
- Write `tests/guard-invariants-epic-a1.tests.sh`/`.ps1` asserting the
  staged candidates' internal consistency and the staged-tree `--check`
  pass; register the suite.
- Record the LIVE files' SHA-256 before this commit, to be re-compared
  after (AC-022 — this comparison is asserted by the test, run again at
  quality-gate time).

Commit B: APPEND to `CHANGELOG.md`'s #189 entry, explicitly noting this
task requires a human-apply step before Done.

**Human apply step (separate, explicit — required before Done):**

- [ ] A human maintainer copies each of the six staged candidates to its
  live path (`cp specs/epic-189-a1-project-context/human-copy/<path>
  <path>`), verifying each copied file's SHA-256 against
  `MANIFEST.sha256` before and after the copy.
- [ ] The human re-runs `python3
  plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check`
  against the now-live tree and confirms it passes.
- [ ] The human confirms (e.g. via a throwaway write attempt, or by
  inspecting `tests/guard-invariants-epic-a1.tests.sh`'s post-apply mode if
  one is added) that the five new protected paths (three data files plus
  the eleven scripts) are now denied by the live guard.

### Done When

- [ ] TEST-021 proves the staged inventory's internal consistency and
  staged-tree `--check` pass (AC-021).
- [ ] TEST-022 proves the LIVE guard-invariants files are byte-identical
  before/after this task's own agent commit (AC-022).
- [ ] The Human apply step above is complete and recorded in the
  implementation report (file paths, SHA-256s, and the post-apply
  `--check` result).
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded (Red: the staged-tree `--check`
  failing against an intentionally-incomplete draft candidate; Green: the
  final staged candidate passing); independent quality-gate verdict
  records PASS, including confirmation that the human-apply step actually
  occurred.

### Out of Scope

- Any edit to `_is_protected_gate_file`'s decision logic itself (T-007 only
  tests it, per REQ-008's own scope).
- `PHASE2_TARGETS`/`BASELINE_SUFFIXES` — both remain untouched, frozen
  constants (design.md Protected-File Statement).

### Blockers

T-002, T-003, T-004, T-005 (must be Implementation Complete or later)

---

## T-007 Verify the hook-guard extension (sidecar full-write-deny)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Security-sensitive verification of an access-control
enforcement path per `risk-classification-policy.md` line 16 — this task
does not edit `sdd-hook-guard.*`'s decision logic (REQ-008's own scope
excludes that), but a false-positive test result (asserting denial that
does not actually hold) would leave the sidecar/registry/scripts
effectively unprotected while claiming otherwise.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-008

Depends On: T-006 (the human-apply step must have landed; this task tests
the LIVE, now-active deny path, not a staged one).

Planned Files:
- `tests/hook-guard-epic-a1-boundary.tests.sh` / `.ps1` (new,
  agent-editable — exercises the full call-site set against the five new
  protected basenames, including under a fixture `SDD_SUDO` token)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; test-only task, no production code edited.

Rollback: revert this task's two commits; no protected file is edited by
this task itself.

### Goal

Prove, against the LIVE, post-T-006-application hook guard, that a write
attempt against each of `sdd/project-context.approval.json`,
`sdd/provider-bindings.approval.json`, and `sdd/approver-registry.yaml` is
denied through every `_is_protected_gate_file` call site
(`sdd-hook-guard.py:1102,1110,1133,1136,1207,1210,1234,1237,1255,1258,1471,1486`),
including under an active, fixture-constructed `SDD_SUDO` token
(never-bypass proof).

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md`
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:976-989,1102-1258,1471-1497`
  (re-enumerate the current call-site set at this task's own
  implementation-start time, per requirements.md Assumptions)

### Scope

Commit A (TDD Red → Green):

- Red: run the new suite against a PRE-T-006-application state (or a
  fixture guard-invariants snapshot lacking the new entries) and confirm it
  fails (proving the test is not vacuously green).
- Green: run the same suite against the live, post-application state;
  capture the passing run.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-023 proves denial for all five new protected basenames across
  the full call-site set, including under an active fixture `SDD_SUDO`
  token (AC-023).
- [ ] The suite's Red run (pre-application state) is recorded as failing,
  proving the assertion is live.
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded; independent quality-gate verdict
  records PASS.

### Out of Scope

- Any decision-logic edit to `sdd-hook-guard.*` (none is needed or made).

### Blockers

T-006 (must be Implementation Complete or later, INCLUDING the human-apply
step)

---

## T-008 Author the hook-activation handshake (`check-hook-activation-handshake`)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: An availability/fail-open-vs-fail-closed decision per
`risk-classification-policy.md` line 16 — a handshake that reports
`HOOK_ACTIVE` when denial was not actually observed would let Capability
Mode proceed on a runtime whose guard is not installed, exactly the failure
decision doc §7 v2 names (Codex `plugin_hooks` flag absent; Copilot
subagent hook non-firing).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-010

Depends On: T-006, T-007 (the canary probe targets an already-protected,
already-verified-denying path).

Planned Files:
- `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py`
  (new, agent-editable)
- `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh` /
  `.ps1` (new, agent-editable)
- `tests/check-hook-activation-handshake.tests.sh` / `.ps1` (new,
  agent-editable — includes a fixture guard stub that does NOT deny)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: no; wholly new files.

Rollback: revert this task's two commits.

### Goal

Implement the canary-probe handshake against
`sdd/project-context.approval.json` (an already-protected path after
T-006), reporting `HOOK_ACTIVE` on observed denial and
`CAPABILITY_RUNTIME_UNAVAILABLE` otherwise — never the reverse.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md`
- `docs/ai-dlc-foundation-decision-v2.md` §7 v2 (Hook 稼働ハンドシェイク)

### Scope

Commit A (TDD Red → Green):

- Red: TEST-027 against a fixture guard stub that does NOT deny, asserting
  `CAPABILITY_RUNTIME_UNAVAILABLE`, and against a not-yet-implemented
  handshake.
- Green: implement the handshake; run against the real, live guard
  (post-T-006/T-007), asserting `HOOK_ACTIVE`; run again against the
  non-denying fixture stub, asserting `CAPABILITY_RUNTIME_UNAVAILABLE`.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-027 proves both outcomes: real guard ⇒ `HOOK_ACTIVE`; non-denying
  fixture stub ⇒ `CAPABILITY_RUNTIME_UNAVAILABLE`, never the reverse
  (AC-027).
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded; independent quality-gate verdict
  records PASS.

### Out of Scope

- Wiring into every future Capability Mode entry point (Non-goals,
  requirements.md) — only T-010's one call site is wired.

### Blockers

T-006, T-007 (must be Implementation Complete or later)

---

## T-009 Revise PLUGIN-CONTRACTS.md and the unprotected track-selection consumers

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Documentation and skill-instruction prose only per
`risk-classification-policy.md` line 15 — no protected file, no runtime
code, no secrets. Does not reach `high` because the actual protected
consumer edits that ENFORCE the new precedence (`ship`, `lite-spec`) are
T-010's, not this task's; this task changes only the documented contract
and two unprotected orchestrator skills that delegate to `ship`.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-009 (part 1 of 2 — unprotected surfaces)

Depends On: T-001 (Project Context schema), T-005 (validator, consulted for
the fail-closed compatibility-fallback rule).

Planned Files:
- `PLUGIN-CONTRACTS.md` (existing, agent-editable — Track Detection section
  revision)
- `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` (existing,
  agent-editable — track-selection revision)
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`
  (existing, agent-editable — `spec_profile` gating revision at the three
  cited call sites)
- `tests/plugin-contracts-track-selection.tests.sh` / `.ps1` (new,
  agent-editable — document-conformance + fixture-behavior checks)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable)
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (staged, appended)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (appended)
- `CHANGELOG.md` (existing, agent-editable — APPEND)

Data Migration: none.

Breaking API: `PLUGIN-CONTRACTS.md`'s documented priority order changes for
projects WITH a Project Context (new precedence); unchanged for projects
without one (compatibility fallback, ADR-0023 item 2) — not a breaking
change to any existing, already-shipped behavior, since no Project Context
consumer exists in production yet (this epic is the first to define the
schema).

Rollback: revert this task's two commits; no protected file touched.

### Goal

Revise `PLUGIN-CONTRACTS.md:61-66`'s Track Detection section per ADR-0023,
and the two unprotected consumer skills, per design.md's four-case rule.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md`
- `docs/adr/0023-track-selection-contract-migration.md`
- `PLUGIN-CONTRACTS.md:61-66`
- `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:80-132`
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:147,159,199`

### Scope

Commit A (implementation):

- Write TEST-024 (document conformance) and the fixture-driven half of
  TEST-025/TEST-026 that these two unprotected skills' prose can satisfy
  (full end-to-end behavior lock spans into T-010's protected `ship`
  edit — this task's suite asserts what it can from these files alone,
  T-010's own Done When closes the rest).
- Revise `PLUGIN-CONTRACTS.md`, `bootstrap/SKILL.md`, and
  `sdd-bootstrap-interviewer/SKILL.md`.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry.

### Done When

- [ ] TEST-024 proves `PLUGIN-CONTRACTS.md` documents the new precedence
  correctly (AC-024).
- [ ] The unprotected-consumer half of TEST-025/TEST-026's fixture coverage
  passes against `bootstrap/SKILL.md`'s and
  `sdd-bootstrap-interviewer/SKILL.md`'s revised text.
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] Acceptance-first evidence recorded; independent quality-gate verdict
  records PASS.

### Out of Scope

- `ship/SKILL.md` and `lite-spec/SKILL.md` (protected — T-010).
- The hook-activation handshake wiring itself (T-010, since `ship`'s Track
  Detection is where it is wired).

### Blockers

T-001, T-005 (must be Implementation Complete or later)

---

## T-010 Migrate the protected track-selection consumers (`ship`, `lite-spec`) via human-copy

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: `plugins/sdd-ship/skills/ship/SKILL.md` and
`plugins/sdd-lite/skills/lite-spec/SKILL.md` are both R-10-protected
enforcement-chain files (`risk-classification-policy.md` line 16 —
"access control ... anything where a silent defect causes material harm");
this task changes the actual, real-world-enforced track-selection
precedence and wires the hook-activation handshake into `ship`'s one call
site — a defect here is the exact class of "silent downgrade" ADR-0023
exists to close.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-009 (part 2 of 2 — protected surfaces), REQ-010 (the one
call-site wiring)

Depends On: T-009 (documented contract text this task's staged edits must
match), T-008 (handshake script this task's staged `ship/SKILL.md` edit
wires in).

Planned Files:
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`
  (new staged candidate — Step 2 Track Detection revision plus the
  handshake call)
- `specs/epic-189-a1-project-context/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md`
  (new staged candidate — track-selection revision)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (new
  entries for both)
- `plugins/sdd-lite/skills/lite-gate/SKILL.md` (existing, agent-editable —
  IF it reads track selection at this task's implementation-start
  verification; otherwise this file is left untouched and the Done When
  below records the "not applicable" finding instead)
- `tests/ship-track-selection-migration.tests.sh` / `.ps1` (new,
  agent-editable — asserts the STAGED `ship`/`lite-spec` candidates'
  content against AC-025/AC-026)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable)
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
implementing the four-case Project-Context-present rule (design.md
Architecture) plus the handshake wiring, under
`specs/epic-189-a1-project-context/human-copy/`.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md`
- `plugins/sdd-ship/skills/ship/SKILL.md:76-117`
- `plugins/sdd-lite/skills/lite-spec/SKILL.md:48`
- `plugins/sdd-lite/skills/lite-gate/SKILL.md` (verify whether it reads
  track selection at all before assuming it needs an edit)

### Scope

Commit A (implementation — staged candidates + tests):

- Draft the staged `ship/SKILL.md` and `lite-spec/SKILL.md` candidates.
- If `lite-gate/SKILL.md` reads track selection, edit it directly
  (unprotected); otherwise record the verification finding.
- Write `tests/ship-track-selection-migration.tests.sh`/`.ps1` asserting
  the staged candidates' content against the full-lite-`--full` promotion
  case, the full+`--lite` error-stop case, and the failed-validation
  compatibility-fallback case.
- Register the suite; stage the `test.yml` addition.

Commit B: APPEND to `CHANGELOG.md`'s #189 entry, explicitly noting this
task requires a human-apply step before Done.

**Human apply step (separate, explicit — required before Done):**

- [ ] A human maintainer copies the staged `ship/SKILL.md` and
  `lite-spec/SKILL.md` candidates to their live paths, verifying each
  copied file's SHA-256 against `MANIFEST.sha256`.
- [ ] The human confirms (by re-running
  `tests/ship-track-selection-migration.tests.sh`/`.ps1` against the now-live
  files) that the staged behavior matches the live behavior post-copy.

### Done When

- [ ] TEST-025 proves the full+`--lite` error-stop case and the
  lite+`--full` promotion case against the staged candidates (AC-025).
- [ ] TEST-026 proves the failed-validation compatibility-fallback case
  (AC-026).
- [ ] `lite-gate/SKILL.md`'s applicability is verified and recorded (either
  edited, or explicitly found not-applicable).
- [ ] The Human apply step above is complete and recorded in the
  implementation report.
- [ ] Suite self-registers; `test.yml` staged correctly.
- [ ] `CHANGELOG.md` #189 entry updated.
- [ ] TDD Red/Green evidence recorded (Red: staged-candidate assertions
  against the CURRENT, unmigrated live text; Green: against the staged,
  migrated candidates); independent quality-gate verdict records PASS,
  including confirmation the human-apply step occurred.

### Out of Scope

- Any change to `impl-review-loop/SKILL.md`'s own `spec_profile: lite`
  read (`impl-review-loop/SKILL.md:61`) — not a track-*selection* surface,
  out of this epic's named consumer list (investigation.md INV-002).

### Blockers

T-008, T-009 (must be Implementation Complete or later)

---

## T-011 Close out three-environment test coverage and CI wiring

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Test/CI-wiring closing task per
`risk-classification-policy.md` line 15 — no production logic change; the
risk this task manages is coverage-completeness, not behavior correctness
(each prior task already TDD'd its own behavior).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-011

Depends On: T-001 through T-010 (all must be Implementation Complete or
later; this task audits their combined output).

Planned Files:
- `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  (final consolidated staged candidate, superseding each prior task's own
  incremental staging, if any drift is found)
- `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` (final
  consolidated entries)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — audit only, no
  new entries expected if T-001..T-010 registered correctly)
- `CHANGELOG.md` (existing, agent-editable — APPEND, closing entry)

Data Migration: none.

Breaking API: no.

Rollback: revert this task's commits; the final `test.yml` human-apply
step (if any residual staging remains) follows the same human-apply
discipline as prior tasks.

### Goal

Run the full local suite (`bash tests/run-all.sh` and
`pwsh tests/run-all.ps1`) end to end, confirm every suite T-001..T-010
added is registered and green, confirm the non-use declarations (no real
LLM/`gh`/`sdd-sudo` invocation) and CI-resilience checklist (bash 3.2 array
safety, macOS `$TMPDIR` normalization, Windows `jq.exe` CRLF stripping) hold
across every new suite, and reconcile the `.github/workflows/test.yml`
human-copy staging into one final, consistent candidate if any task's
staging left drift.

### Must Read

- `specs/epic-189-a1-project-context/requirements.md`
- `specs/epic-189-a1-project-context/design.md`
- `specs/epic-189-a1-project-context/tasks.md` (this file, T-001..T-010)
- `tests/run-all.sh` / `.ps1` (post-T-001..T-010 state)

### Scope

Commit A (audit + reconciliation):

- Run the full local suite twice (bash, pwsh); record both results.
- Audit every new `.sh` suite against the CI-resilience checklist; fix any
  violation found (should be none, if each prior task followed Global
  Constraints — this is a verification pass, not expected to require new
  logic).
- Reconcile any `.github/workflows/test.yml` staging drift across
  T-001..T-010's incremental candidates into one final, consistent staged
  file.

Commit B: APPEND a closing `CHANGELOG.md` entry summarizing the epic's full
addition under #189's entry.

### Done When

- [ ] TEST-028 proves every new suite self-registers and the
  `.github/workflows/test.yml` staged/live/post-copy three-part proof holds
  across the FULL set of suites T-001..T-010 added (AC-028).
- [ ] TEST-029 proves the non-use declarations and CI-resilience checklist
  hold across every new suite (AC-029).
- [ ] Full local suite run (`bash tests/run-all.sh`,
  `pwsh tests/run-all.ps1`) passes.
- [ ] `CHANGELOG.md`'s #189 entry is finalized.
- [ ] Acceptance-first evidence recorded; independent quality-gate verdict
  records PASS.

### Out of Scope

- Any new production script or schema (this is a closing audit task only).

### Blockers

T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010 (all
must be Implementation Complete or later)
