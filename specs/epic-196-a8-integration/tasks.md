# Tasks: epic-196-a8-integration

Task-Review-Status: Passed

Source: Issue #196 (Epic A8 — 3環境統合検証), tracked under epic #187
(AI-DLC Foundation) / #188 (Epic A0) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation
Complete`. Only `quality-gate` may set `Done`.

## Protected Files

`.github/workflows/test.yml` is R-10 protected
(`plugins/sdd-quality-loop/references/guard-invariants.json`'s
`protected_gate_suffixes`/`phase2_human_copy_targets`, confirmed present in
this worktree's copy of that file) — every task below that registers a new
suite's CI steps stages its own candidate under
`specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml` with a
`MANIFEST.sha256` entry (ADR-0011 pattern); no task edits the live file
directly. `tests/run-all.sh`/`.ps1` are **not** protected (INV-014 of this
package's own investigation.md; confirmed absent from
`guard-invariants.json`'s suffix list) — new suite registration there is a
direct agent edit, one array-append per task.

**No task edits `plugins/sdd-quality-loop/scripts/sdd-hook-guard.{js,py,sh,ps1}`,
`plugins/sdd-quality-loop/hooks/{claude-hooks,hooks,copilot-hooks}.json`,
`check-contract.*`, `check-evidence-bundle.*`, or any other
`guard-invariants.json`-listed path.** This epic verifies the guard's own
cross-runtime behavior; it never modifies the guard, matching design.md's own
Protected-File Statement ("This epic adds no `PROTECTED_GATE_SUFFIXES`/
guard-invariants entries... every component above is a read-only verification
tool").

**No task drafts a new ADR.** `docs/adr/0028-live-host-proof-ed25519-signing.md`
already exists (`Status: Proposed`, dated 2026-07-23) and is the accepted
source for T-005's Signing Contract; T-005 implements it exactly as written
and may flip its own `Status:` header to `Accepted` in the same commit once
its implementation conforms — it never re-authors the ADR's own content.

**Two shared, ordinary (non-protected) files each span two tasks:**
`plugins/sdd-review-loop/references/a8-skip-allowlist.json` — T-001 creates
it with the `AC-006` `case_id` entry only; T-008 later appends the `AC-015`
and `AC-016` entries. No other task touches this file (SKIP Allowlist
Activation Gate, design.md). `plugins/sdd-review-loop/references/
a8-trusted-signers.json` — T-005 seeds it empty
(`{"schema": "a8-trusted-signers/v1", "signers": {}}`) as part of authoring
the validator that resolves signer identities against it; T-008's own HUMAN
APPLY STEP later appends the real `operator`/`reviewer` (and, once ready,
`issuer`) key entries. No other task touches either file.

**No task produces a genuine, signed `live-host-verification-record/v1`
claiming a real CLI session occurred.** Every record any task in this
feature commits under `tests/hook-activation-live-proof/` is either (a) a
schema-valid `SKIP` record whose `operator_signature`/`reviewer_signature`
require a maintainer-registered Ed25519 keypair that does not yet exist in
this repository (a human action, see T-008's Done When), or (b) a
disposable, clearly-fixture-only record used solely inside a task's own test
suite to exercise `validate-live-host-proof`'s validation logic, never
committed as this epic's own evidence. Fabricating a "genuine" session
record is out of scope for every task (Safety constraints, investigation.md;
AC-027).

## Global Constraints

- **Serialized order T-001 → T-002 → T-003 → T-005 → T-006 → T-007** for
  every shared-resource append: the `tests/run-all.sh`/`.ps1` array (each
  task appends only its own suite's registration line) and the one staged
  `specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml`
  candidate (each task appends its own suite's CI steps to whatever the
  previous task in this chain already staged, or to the unmodified real file
  if the previous task's candidate has already been human-applied) — this
  ordering is followed even where two adjacent tasks in the chain have no
  functional dependency on each other, matching this repository's own
  established convention (`specs/epic-190-a2-capability-registry/tasks.md`
  Global Constraints). **T-004 is deliberately outside this chain**: it
  extends `tests/cli-hook-enforcement.ps1`, a file already registered in
  both `tests/run-all.*` and `.github/workflows/test.yml`, so it touches
  neither shared resource and carries no ordering requirement relative to
  the others (matching design.md's own AC-017 structural-separation
  decision, which keeps the synthetic regression file independent of every
  other REQ-003 surface). **T-008 is likewise deliberately outside this
  chain**: it extends `tests/validate-live-host-proof.tests.{sh,ps1}`,
  which T-005 already registers in both `tests/run-all.*` and the staged
  `.github/workflows/test.yml` candidate, so T-008 itself touches neither
  shared resource and carries no ordering requirement relative to
  T-002/T-003/T-006/T-007 (matching T-004's identical positioning above).
- **`plugins/sdd-review-loop/references/a8-skip-allowlist.json`: T-001 →
  T-008** (Protected Files, above) — the only two tasks that touch it, in
  that order. **`plugins/sdd-review-loop/references/a8-trusted-signers.json`:
  T-005 → T-008** (Protected Files, above) — the only two tasks that touch
  it, in that order.
- **CI resilience** (design.md Constraint Compliance) applies to every new
  `.sh`/`.ps1`/`.py` suite: no possibly-empty array expanded under `set -u`;
  every directly-created `mktemp` root normalized with `pwd -P` immediately
  after creation; any `jq`/JSON-parsing output consumption piped through
  `tr -d '\r'` unconditionally where cross-platform line endings could
  appear; every fixture is disposable, offline, and self-contained (no live
  LLM, Provider API, or network call beyond what `install.sh`'s own existing
  `gh`-authenticated path already makes, External Integrations, design.md).
- **No new CI topology**: every automated check registers as a new step
  inside the existing `tests/run-all.{sh,ps1}` and
  `.github/workflows/test.yml` 3-OS matrix (INV-014) — no task provisions a
  new workflow file or a new matrix dimension (Global Constraints,
  design.md).
- **No secrets, credentials, or real production signing key material** is
  committed by any task; T-005's own fixture Ed25519 keys are clearly
  disposable test material scoped to its own test suite, never registered
  in `a8-trusted-signers.json` as production entries (Protected Files,
  above). T-008's own HUMAN APPLY STEP registers only the operator's/
  reviewer's public keys (`a8-trusted-signers.json`'s own schema carries
  `public_key` only); no private key material is ever committed by any
  task.
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Author the REQ-001 cross-runtime handoff fixture and test driver

Source Issue: https://github.com/aharada54914/sdd-forge/issues/196

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task builds new integration-test
infrastructure (a fixture project plus a driver script) with observable
behavior (a `PASS`/`FAIL`/`SKIP` trace per handoff step) and no sensitive
surface of its own — the one embedded security-relevant case (the
hook-activation canary, AC-006) is presence-only in this task's own scope
(design.md's Automated/Manual Classification Table marks it `automated`
precisely because "the live-host proof is AC-015's own, separate check"),
and the genuine live-host proof mechanism is T-005's exclusive scope. It is
not `high`: this task never implements a security boundary, never signs or
validates an attestation, and never accepts or rejects a security-relevant
claim on its own authority. Required Workflow is `acceptance-first` per the
policy's medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-005, AC-006)

Depends On: none (foundational — first task in the shared-resource chain;
nothing else in this feature functionally requires the fixture to exist
first, but this task is first in file-registration order, Global
Constraints).

Planned Files:
- `tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml`
  (new — fixed YAML stub whose `token` field holds the exact sentinel
  string design.md's own Fixture Contract table fixes, per design.md Data
  Plan)
- `tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md`
  (new — fixed Markdown stub whose `nonce` HTML comment holds the exact
  sentinel string the same table fixes)
- `tests/cross-runtime-handoff.tests.sh` (new — drives both adjacent
  handoffs, the full 3-hop chain, and the canary case; emits
  `cross-runtime-handoff-trace/v1`)
- `tests/cross-runtime-handoff.tests.ps1` (new — twin)
- `plugins/sdd-review-loop/references/a8-skip-allowlist.json` (new — seeds
  exactly one entry, `case_id: "AC-006"`, per the Allowlist record shape,
  SKIP Allowlist Activation Gate, design.md; T-005 appends the AC-015/AC-016
  entries later, Protected Files above)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable)
- `specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml`
  (new staged candidate, agent-editable — this suite's CI steps; R-10
  protected real path, human-copy only)
- `specs/epic-196-a8-integration/human-copy/MANIFEST.sha256` (new —
  SHA-256 entry for the staged candidate)

Data Migration: none — net-new fixture and suite, no prior version.

Breaking API: no; every planned file is wholly new except the two shared
registration files, which receive additive entries only.

Rollback: revert this task's commit(s). Nothing protected is written
directly (the staged `test.yml` candidate is human-applied only); a revert
PR states explicitly whether an already-applied `test.yml` step should also
be hand-reverted.

### Goal

Author the two fixed fixture files and `tests/cross-runtime-handoff.
tests.sh`/`.ps1` exactly per design.md's Fixture Contract table: for each
adjacent handoff (Claude→Codex, Codex→Copilot), drive the producing
runtime's mutation of a per-run `mutation_nonce` into the fixture, then
assert the consuming runtime's own `consumer_observable` (a stdout
substring for Claude→Codex, a generated-file hash for Codex→Copilot);
chain both steps into one continuous 3-hop run reusing `handoff-02`'s own
nonce (AC-004); register the hook-activation canary as a named, `SKIP`ped
case citing Epic A1's tracking issue (`sdd-forge-wt-epic-189`, #189/#187);
and record, for each of the three CLIs independently, either a confirmed
headless/non-interactive invocation contract (with file:line or
external-doc evidence) or an explicit "unconfirmed as of this package"
marker (AC-005) — per REQ-006's classification, never assuming a contract
that has not actually been confirmed at implementation time (INV-021,
OQ-001).

### Must Read

- `specs/epic-196-a8-integration/requirements.md` (REQ-001, AC-001–006,
  Edge Cases)
- `specs/epic-196-a8-integration/design.md` (Data Plan
  `cross-runtime-handoff-trace/v1` and Fixture Contract table; SKIP
  Allowlist Activation Gate; Automated/Manual Classification Table rows for
  AC-001–006; Test Strategy item 1)
- `specs/epic-196-a8-integration/investigation.md` (INV-015, INV-021,
  INV-013 — no existing suite launches a real multi-CLI session today;
  Safety constraints)
- `tests/cli-hook-enforcement.ps1:1-101` (the existing direct-invocation
  guard-contract pattern this fixture's canary case must NOT be confused
  with — the canary here is presence-only, not a live-host proof)
- `tests/install.tests.sh:150-157` (`make_fake_commands` — the existing
  fake-shim precedent for CLI-presence detection this task must not reuse
  as a substitute for a genuine session, per investigation.md INV-015)

### Scope

- Investigate, at implementation start, whether any of the Claude Code CLI,
  Codex CLI, or Copilot CLI now exposes a confirmed, scripted
  headless/non-interactive invocation contract (OQ-001). Record the
  finding — confirmed-with-citation or explicitly unconfirmed — in the
  fixture driver's own output and in AC-005's marker; do not assume a
  contract that was not actually verified this session.
- Write the acceptance checks first (acceptance-first): TEST-001 (Fixture
  Contract table fields are exact and machine-checkable, not free text),
  TEST-002 (Claude→Codex handoff, automated where OQ-001 confirms a
  contract, else a REQ-006-format manual-session record consumed by the
  same trace schema), TEST-003 (Codex→Copilot handoff, same conditional
  branch), TEST-004 (full 3-hop chain, `handoff-02`'s nonce reused end to
  end), TEST-005 (per-CLI headless-contract marker), TEST-006 (canary case
  present, `SKIP`, citing Epic A1's tracking issue, `coverage_complete:
  false` while `SKIP`ped pre-merge is itself asserted as the correct,
  non-`FAIL` state).
- CI resilience per Global Constraints.
- Register `cross-runtime-handoff` (`.sh`/`.ps1`) in `tests/run-all.sh`/
  `.ps1`; stage the `.github/workflows/test.yml` candidate under
  `human-copy/` + `MANIFEST.sha256`.
- Seed `a8-skip-allowlist.json` with the `AC-006` entry only (Protected
  Files, above).

### Done When

- [ ] **Fixture Contract fidelity** — TEST-001 passes: the fixed artifact
  paths, initial bytes, producer mutation, final-byte oracle, and
  `consumer_observable` for both handoffs match design.md's own table
  exactly (AC-001).
- [ ] **Adjacent handoffs + full chain** — TEST-002/003/004 pass, each
  either fully automated (with the confirmed contract cited in the trace)
  or recorded as a REQ-006-format manual-session step, never silently
  dropped (AC-002, AC-003, AC-004); the 3-hop chain's own final state is
  verifiably derived from both upstream steps' contributions, not merely
  their having both run.
- [ ] **Headless-contract marker** — TEST-005 passes: each of the three
  CLIs carries either a cited confirmed contract or an explicit
  "unconfirmed as of this package" marker (AC-005).
- [ ] **Canary presence** — TEST-006 passes: the hook-activation canary is
  a named, mandatory case inside the trace, `SKIP`ped citing Epic A1's
  tracking issue, registered in `a8-skip-allowlist.json` (AC-006).
- [ ] **Suite/CI registration** — `tests/cross-runtime-handoff.tests.sh`/
  `.ps1` self-register in `tests/run-all.sh`/`.ps1`; the staged
  `test.yml` candidate exists with a correct `MANIFEST.sha256` entry; the
  LIVE `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **Acceptance-first evidence** — RED (each oracle against a
  deliberately permissive driver) and GREEN (the full suite against the
  correct fixture/driver). An independent quality-gate verdict records
  PASS.

### Out of Scope

- The REQ-003 live-host proof itself, the semantic 5-cell matrix, and the
  aggregate validator (T-005) — this task only registers the canary's
  presence and its `SKIP` state.
- The install/uninstall matrix (T-003), the drift check (T-002), the
  `cli-hook-enforcement.ps1` extension (T-004), the path/line-ending matrix
  (T-006), and the classification/scope-boundary static checks (T-007).
- Un-skipping AC-006 or exercising Epic A1's own artifacts — that is a
  follow-up task once Epic A1 merges (Main Workflows step 7, requirements.md).

### Blockers

None

---

## T-002 Author the REQ-005 installed-plugin drift check

Source Issue: https://github.com/aharada54914/sdd-forge/issues/196

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. `high` is justified: this script is the concrete
implementation of Security Boundary B2 (design.md Security Boundaries —
read-only comparison, never remediates), the sole mechanism that can catch
the `AGENTS.md` WFI-004/issue #86 divergence class (a plugin-shipped
definition silently diverging from its own source, INV-017) before it
causes a downstream failure. A silent defect here — a real divergence
reported `installed_synced`, a `not_installed` state silently accepted as
`PASS` in `verify` mode, a delimited-region MCP-block comparison that
hashes the wrong bytes — lets a stale or tampered installed cache pass
undetected, the exact "silent defect causes material harm" surface the
policy's `high` tier names on a security-boundary-adjacent check (matching
`specs/epic-190-a2-capability-registry/tasks.md` T-004's identical
reasoning for a read-only validator). It is not `critical`: no
settlement/safety/irreversible-destructive surface — the check only
reports, never remediates (Protected-File Statement, design.md). Required
Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-005 (AC-022, AC-023)

Depends On: T-001 (Global Constraints — serialized only; no functional
dependency, this drift check is independent of the handoff fixture).

Planned Files:
- `plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.py` (new,
  agent-editable — Python master, matching `generate-guard-invariants.py`/
  `registry_discovery.py`'s own master+wrapper convention, INV-014 of this
  package's investigation.md: `--mode preflight|verify`,
  `--install-root <path>` override, whole-file comparison for `plugins/**`/
  agent-role TOML/hook-config files, delimited-region comparison for the
  Codex `config.toml` MCP block per the Region Extraction Rule, emits
  `installed-plugin-drift-report/v1`)
- `plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.ps1` (new,
  agent-editable — twin, using the Platform Install-Root Defaults table's
  own `%LOCALAPPDATA%\sdd-plugins` default)
- `tests/check-installed-plugin-drift.tests.sh` (new, agent-editable)
- `tests/check-installed-plugin-drift.tests.ps1` (new, agent-editable)
- `tests/fixtures/installed-plugin-drift/` (new fixture tree — a
  freshly-synced install-root fixture, one fixture per `change_type`
  (`added`/`removed`/`modified`/`type-changed`) across both `surface: file`
  and `surface: delimited-region`, a `not_installed` fixture exercised in
  both `preflight` and `verify` mode, and the independent negative-lifecycle
  fixture — prior-version install followed by a source-tree revision, or a
  direct installed-cache mutation)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable)
- `specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-001's; R-10 protected real path)
- `specs/epic-196-a8-integration/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry)

Data Migration: none — new, additive CLI JSON output; no prior version.

Breaking API: no; `check-installed-plugin-drift` is a wholly new script.

Rollback: revert this task's commit(s); nothing protected is written
directly; the script never writes to the install root or the repository
(Protected-File Statement).

### Goal

Author `check-installed-plugin-drift.{py,sh,ps1}` implementing the full
Coverage Scope table (design.md): whole-file content-hash + `change_type`
comparison for `plugins/**`-sourced files, the Codex agent-role TOML files,
and the three hook config files; delimited-region comparison (Region
Extraction Rule) for the Codex `config.toml` MCP block only. In `preflight`
mode (the default when run standalone), a `not_installed` install root is a
distinct, non-failing result; in `verify` mode, `not_installed` is a `FAIL`
(AC-023's own two-mode disambiguation, never a design-only elaboration this
script's behavior may contradict). Exit non-zero on `installed_drifted` in
either mode.

### Must Read

- `specs/epic-196-a8-integration/requirements.md` (REQ-005, AC-022–024,
  Field Definitions "Installed-cache drift")
- `specs/epic-196-a8-integration/design.md` (Data Plan
  `installed-plugin-drift-report/v1`, Region Extraction Rule, Platform
  Install-Root Defaults, Coverage Scope table; API/Contract Plan's
  `check-installed-plugin-drift` entry)
- `specs/epic-196-a8-integration/investigation.md` (INV-016, INV-017,
  INV-019)
- `install.sh:11,174-224,261-284,377-378,519-533`; `install.ps1:5,239-246,
  353-382,385-403`; `uninstall.sh:12`; `uninstall.ps1:3` (the real install
  root defaults, MCP delimited-block markers, and copy targets this check
  compares against)
- `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` (the
  `--check` no-write, sha256-comparison convention this script's
  `preflight`/`verify` modes mirror)

### Scope

- Write the acceptance checks first (TDD Red→Green): TEST-022 (positive
  divergence across every `change_type` and both comparison surfaces, plus
  the independent negative-lifecycle case, bundled in one row per
  design.md's own instruction never to split it across two), TEST-023
  (`not_installed`/`installed_synced`/`installed_drifted` as three
  distinct states; `not_installed` non-failing only in `preflight`, a
  `FAIL` in `verify`).
- CI resilience per Global Constraints.
- Register `check-installed-plugin-drift` in `tests/run-all.sh`/`.ps1`;
  stage the `.github/workflows/test.yml` candidate appended to T-001's
  staged file.

### Done When

- [ ] **Divergence detection** — TEST-022 passes: every `change_type`
  (`added`/`removed`/`modified`/`type-changed`) is correctly reported on
  both `surface: file` and `surface: delimited-region`; the independent
  negative-lifecycle case reports the exact expected `diverged[]` entries
  and a non-zero exit (AC-022).
- [ ] **Mode-dependent not-installed semantics** — TEST-023 passes:
  `not_installed` is non-failing (exit 0) only in `preflight` mode and a
  `FAIL` (exit 1) in `verify` mode; `installed_synced` and
  `installed_drifted` are correctly distinguished in both modes (AC-023).
- [ ] **Suite/CI registration** — `tests/check-installed-plugin-drift.
  tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1`; the staged
  `test.yml` candidate exists with a correct `MANIFEST.sha256` entry; the
  LIVE `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **TDD evidence** — RED (each divergence/mode case against a
  deliberately permissive comparator) and GREEN (the full suite against
  the correct implementation). An independent quality-gate verdict records
  PASS.
- [ ] **Requirement-traceability evidence** (high tier) — the
  `check-traceability` report is recorded as evidence, per
  `risk-gate-matrix.md`'s `high` row.

### Out of Scope

- Wiring this check into REQ-002's own matrix as a `verify`-mode sub-step
  (T-003, AC-024) — this task only implements the script's own two-mode
  contract.
- Any write path against the install root or the repository (the script is
  read-only by design, Security Boundary B2).
- The REQ-003 live-host proof machinery (T-005), which is a structurally
  separate security surface.

### Blockers

None

---

## T-003 Author the REQ-002 install/uninstall matrix driver

Source Issue: https://github.com/aharada54914/sdd-forge/issues/196

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task drives the existing,
already-shipped `install.sh`/`install.ps1`/`uninstall.sh`/`uninstall.ps1`
scripts (unmodified) through four `--target` cells with an observable
present/absent/unchanged oracle per cell (Target × Phase × Surface
Registration Table) — a normal, fully-tested integration-test surface with
no sensitive surface of its own: the security-relevant read-only comparison
this cycle also exercises (the REQ-005 drift check) is T-002's own,
already-`high`-classified implementation, consumed here only as a
sub-step. It is not `high`: this task neither authors nor modifies any
authentication, authorization, secrets-handling, or drift-detection logic
itself. Required Workflow is `acceptance-first` per the policy's
medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-002 (AC-007, AC-008, AC-009, AC-010, AC-011), REQ-005
(share — AC-024, the `check-installed-plugin-drift --mode verify` wiring;
this suite's own integration proof that the sub-step actually runs)

Depends On: T-001 (Global Constraints — serialized only), T-002
(functional — this driver invokes `check-installed-plugin-drift` in
`mode: "verify"` as its own post-`install` sub-step on every cell, API/
Contract Plan; the script must exist first).

Planned Files:
- `tests/install-uninstall-matrix.tests.sh` (new — drives
  install→verify→uninstall→verify per `--target` cell (`All`/`Codex`/
  `Claude`/`Copilot`), no `--target` runs all four sequentially; emits
  `install-uninstall-matrix-result/v1`, always invoking
  `check-installed-plugin-drift --mode verify`)
- `tests/install-uninstall-matrix.tests.ps1` (new — twin)
- `tests/fixtures/install-uninstall-matrix/` (new — per-cell Required
  MCP-Surface Preconditions: a `~/.codex/config.toml` stub for
  Codex-exercising cells, a VS Code user-profile directory stub for
  Copilot-exercising cells, a Node.js ≥ 20 stub, matching design.md's own
  "required-provisioning" contract)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable)
- `specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-002's; documents the local-macOS-run/CI-3-OS split in the job's
  own step name, AC-010)
- `specs/epic-196-a8-integration/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry)

Data Migration: none — new, additive CLI JSON output; no prior version.

Breaking API: no; `install-uninstall-matrix.tests.{sh,ps1}` is wholly new
and calls `install.sh`/`.ps1`/`uninstall.sh`/`.ps1` unmodified.

Rollback: revert this task's commit(s); nothing protected is written
directly; the driver never edits `install.sh`/`.ps1`/`uninstall.sh`/`.ps1`
themselves.

### Goal

Author `tests/install-uninstall-matrix.tests.sh`/`.ps1` exactly per the
Target × Phase × Surface Registration Table: for each of the four
`--target` values, provision the Required MCP-Surface Preconditions, run
`install` then `verify_1` then a second `install` (idempotency check,
`diff_from_install_1` must be empty) then `uninstall` then `verify_residue`
(residual paths must be empty, scoped to this project's own installer
output only), invoking `check-installed-plugin-drift --mode verify`
immediately after each `install` phase. Record `--target FilesOnly` as
explicitly out-of-matrix (AC-011) and the local-macOS/existing-3-OS-CI
division of labor (AC-010) in the driver's own doc comment and the staged
CI step name.

### Must Read

- `specs/epic-196-a8-integration/requirements.md` (REQ-002, AC-007–011,
  Edge Cases)
- `specs/epic-196-a8-integration/design.md` (Data Plan
  `install-uninstall-matrix-result/v1`, Target × Phase × Surface
  Registration Table, Required MCP-Surface Preconditions; API/Contract
  Plan's `install-uninstall-matrix.tests` entry; Test Strategy items 2–3)
- `specs/epic-196-a8-integration/investigation.md` (INV-010, INV-014,
  INV-016)
- `install.sh:38,77-78,361-371,472-493,498-518,519-533`; `install.ps1:239-
  246,353-382,385-403`; `uninstall.sh:37,85-86`; `uninstall.ps1` (the real
  `--target` conditional-skip behavior this driver's fixture preconditions
  must provision for)
- `tests/install.tests.sh` (the existing `git archive`-based fixture-clone
  convention this driver reuses, per Constraint Compliance, design.md)

### Scope

- Write the acceptance checks first (acceptance-first): TEST-007 (the
  4-cell cycle against the Registration Table's own present/absent/
  unchanged oracle, with required preconditions provisioned), TEST-008
  (idempotent re-install, empty diff), TEST-009 (zero-residue
  post-uninstall verify), TEST-010 (doc-review: local-macOS vs. 3-OS-CI
  division of labor recorded in the staged CI step name), TEST-011
  (`--target FilesOnly` recorded out-of-matrix, never silently a fifth
  cell), TEST-024 (this suite's own integration proof that
  `check-installed-plugin-drift --mode verify` actually runs as a
  sub-step of every cell's `verify_1`).
- CI resilience per Global Constraints.
- Register `install-uninstall-matrix` in `tests/run-all.sh`/`.ps1`; stage
  the `.github/workflows/test.yml` candidate appended to T-002's staged
  file, naming the local-macOS/3-OS-CI split in the step name.

### Done When

- [ ] **4-cell registration table** — TEST-007 passes: every target ×
  phase × surface cell matches the Registration Table's own present/
  absent/unchanged oracle, with the Required MCP-Surface Preconditions
  provisioned before each cell's `install` phase (AC-007).
- [ ] **Idempotency + zero residue** — TEST-008/009 pass: a second install
  over an already-installed state produces an empty `diff_from_install_1`
  (AC-008); post-uninstall verify reports an empty `residual_paths`, scoped
  to this project's own installer output (AC-009).
- [ ] **Division of labor + FilesOnly exclusion** — TEST-010/011 pass: the
  local-macOS-run/existing-3-OS-CI split is documented, never presented as
  a CI substitute (AC-010); `--target FilesOnly` is recorded explicitly
  out-of-matrix (AC-011).
- [ ] **Drift-check wiring** — TEST-024 passes: every cell's own
  `install-uninstall-matrix-result/v1.drift_check` is populated by a real
  `check-installed-plugin-drift --mode verify` invocation, never a stubbed
  or omitted field (AC-024).
- [ ] **Suite/CI registration** — `tests/install-uninstall-matrix.
  tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1`; the staged
  `test.yml` candidate exists with a correct `MANIFEST.sha256` entry; the
  LIVE `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **Acceptance-first evidence** — RED (each cell/idempotency/residue
  oracle against a deliberately permissive driver) and GREEN (the full
  suite against the correct driver, local macOS run). An independent
  quality-gate verdict records PASS.

### Out of Scope

- The drift check's own implementation (T-002, this task only invokes it).
- Registering the new CI step's actual matrix-parallel-vs-sequential
  placement inside `.github/workflows/test.yml` beyond the staged
  candidate — the live registration into the 3-OS CI matrix is the human
  apply step (Deployment/CI Plan; Test Strategy item 3 leaves the
  parallel-vs-sequential choice to the implementer's own report).
- `--target FilesOnly`'s own behavior (Non-goals, requirements.md).

### Blockers

T-002

---

## T-004 Extend `tests/cli-hook-enforcement.ps1` with the REQ-003 synthetic assertions

Source Issue: https://github.com/aharada54914/sdd-forge/issues/196

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified, not merely asserted: requirements.md's own
Risks section names this exact task's regression exposure explicitly
("High: extending `tests/cli-hook-enforcement.ps1`... an existing,
already-passing 3-OS CI asset — carries regression risk if the new
cross-runtime/flag-state assertions this epic adds are not kept
structurally independent... from the live-host proof's own potentially-
manual, potentially-`SKIP`ped status"). This file is a security-relevant,
already-green CI asset asserting the hook guard's own deny/allow contract
on every OS; a defect here (a broken existing assertion, a new assertion
that accidentally depends on live-host proof availability) could silently
regress this repository's only automated hook-guard regression coverage.
It is not `critical`: the additions are direct-invocation synthetic checks
only, never a live-host proof (Direct-Invocation De-Spoofing, design.md).
Required Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003 (AC-012, AC-017)

Depends On: none (self-contained edit to an existing, already-registered
file; touches neither `tests/run-all.*` nor `.github/workflows/test.yml`,
so it carries no Global-Constraints ordering requirement relative to the
other tasks in this feature).

Planned Files:
- `tests/cli-hook-enforcement.ps1` (existing, agent-editable — extended in
  place: new, explicitly-labeled synthetic sub-assertions for the Codex
  `plugin_hooks` config-toggle state and the Copilot subagent-context flag
  state, each clearly marked as a direct-invocation regression check and
  never presented as a live-host proof (Direct-Invocation De-Spoofing);
  every existing assertion line (lines 1-101 of the current file) preserved
  verbatim)

Data Migration: none.

Breaking API: no; this task edits one existing test file, adding
assertions only — no existing assertion is removed or altered.

Rollback: revert this task's commit(s); the file's pre-existing 101 lines
are restored exactly.

### Goal

Add new, explicitly-labeled synthetic sub-assertions to
`tests/cli-hook-enforcement.ps1` covering the Codex `plugin_hooks`
config-toggle state (both a config file stating the flag enabled and one
stating it disabled, each exercised via the existing direct-invocation
`sdd-hook-guard` call) and the Copilot subagent-context flag/indicator
state, each output labeled unambiguously as a config/guard-contract
regression check — never a substitute for AC-013/AC-014's own genuine
session-dispatch Done condition (Direct-Invocation De-Spoofing, design.md;
T-005 owns that separate, `manual-required` surface). Preserve every one of
the file's existing assertions (CLI presence probe, the three per-runtime
deny/allow checks, the three config-drift regexes) unmodified.

### Must Read

- `specs/epic-196-a8-integration/requirements.md` (REQ-003, AC-012,
  AC-017, Edge Cases — Codex-disabled and Copilot-subagent as *correctly
  detected* non-firing states, never a harness failure)
- `specs/epic-196-a8-integration/design.md` (Direct-Invocation
  De-Spoofing section in full; Test Strategy item 4; Automated/Manual
  Classification Table rows for AC-012/AC-017)
- `specs/epic-196-a8-integration/investigation.md` (INV-011, INV-012,
  INV-013 — the three hook configs' own runtime-distinct caveats and the
  documented `docs/troubleshooting.md` non-firing causes this file's new
  assertions must reproduce as *labeled synthetic* checks)
- `tests/cli-hook-enforcement.ps1:1-101` (the full existing file — read
  before editing; every existing `ok`/`bad` assertion line)
- `docs/troubleshooting.md:185-204` (the manual-fallback commands this
  file's new Copilot-subagent assertion cross-references, never claims to
  supersede)

### Scope

- Write the acceptance checks first (TDD Red→Green): TEST-012 (the
  3-runtime deny/allow direct-invocation fixture, extended with the
  labeled Codex-flag-state and Copilot-subagent-indicator sub-cases,
  still passing on every OS in the matrix), TEST-017 (regression
  continuity — every pre-existing assertion in the file is unchanged and
  still passes, independent of the new additions and independent of
  AC-015's own live-host proof availability).
- CI resilience per Global Constraints (this task touches a `pwsh` file
  only; no new `mktemp`/array-safety surface beyond what the file already
  uses).
- No suite/CI registration change: `cli-hook-enforcement.ps1` is already
  registered in `tests/run-all.*` and `.github/workflows/test.yml`.

### Done When

- [ ] **Synthetic flag/subagent sub-assertions** — TEST-012 passes: the
  new Codex `plugin_hooks`-state and Copilot subagent-indicator
  sub-assertions run via the existing direct-invocation pattern, each
  output labeled as a synthetic config/guard-contract check, never phrased
  as a live-host observation (AC-012).
- [ ] **Non-regression** — TEST-017 passes: every one of the file's
  pre-existing assertions (CLI presence, 3-runtime deny/allow, 3
  config-drift regexes) still passes unmodified, and this suite's own
  pass/fail is structurally independent of AC-015's live-host proof state
  (`SKIP`, `pending`, or `discharged`) (AC-017).
- [ ] **TDD evidence** — RED (each new sub-assertion against a
  deliberately permissive addition) and GREEN (the full, extended file on
  every OS in the 3-OS matrix). An independent quality-gate verdict
  records PASS.
- [ ] **Requirement-traceability evidence** (high tier) — the
  `check-traceability` report is recorded as evidence.

### Out of Scope

- The genuine, session-dispatched Codex-flag-state and Copilot-subagent
  Done conditions (AC-013, AC-014) and the live-host proof itself
  (AC-015, AC-016) — all four are T-005's exclusive scope; this task's own
  new assertions never satisfy them.
- Any change to `plugins/sdd-quality-loop/hooks/*.json` or
  `sdd-hook-guard.{js,py,sh,ps1}` (Protected Files, above).

### Blockers

None

---

## T-005 Author the REQ-003/REQ-006 live-host-proof validator engine

Source Issue: https://github.com/aharada54914/sdd-forge/issues/196

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. `high` is justified: this task implements the
mechanical core of Security Boundary B1 (design.md) — the fortified
`live-host-verification-record/v1` schema, the Nonce Issuance Ledger and
Expected-Digest Manifest comparisons, Ed25519 signing verification, the
AC-027 classification-mismatch/replay guard, and the aggregate
`validate-live-host-proof` Done/release gate discharging ADR-0019's own
"conditioned on the hook-activation handshake" defense claim. A silent
defect (a forged or replayed record accepted, a digest mismatch silently
passed, a single-signature record accepted as two-party, a stale
post-merge `SKIP` reported `pending`) would let a fabricated security
proof pass as genuine — the exact "silent defect causes material harm"
surface the policy's `high` tier names on an access-control-adjacent
enforcement surface (matching `specs/epic-190-a2-capability-registry/
tasks.md` T-002/T-004's identical reasoning for security-boundary
primitives). It is not `critical`: no financial-settlement,
physical-safety, or irreversible-destructive surface — the validator
emits `discharged`/`pending`/a named error code plus evidence, and its
one write (marking a consumed nonce) is a narrow, lock-guarded, reversible
ledger update, not itself the security decision. Required Workflow is
`tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003 (AC-028), REQ-006 (AC-026, AC-027)

Depends On: T-001, T-002, T-003 (Global Constraints — serialized only; no
functional dependency on any of them — this validator's own TDD suite
exercises its schema/nonce/signing/aggregate-gate logic entirely against
disposable fixture keypairs and fixture allowlist/registry records under
`tests/fixtures/live-host-proof/`, never the shared, real
`a8-skip-allowlist.json`/`a8-trusted-signers.json` entries T-001/T-008
create).

Planned Files:
- `plugins/sdd-review-loop/references/a8-trusted-signers.json` (new,
  agent-editable — schema `a8-trusted-signers/v1`; seeded empty
  (`{"schema": "a8-trusted-signers/v1", "signers": {}}`) as the real,
  maintainer-committed registry this validator resolves `operator_key_id`/
  `reviewer_key_id` against; T-008's own HUMAN APPLY STEP later appends
  the real signer entries — this task's own test suite uses separate,
  disposable fixture keypairs, never registering them here)
- `plugins/sdd-review-loop/references/a8-expected-hook-config-digests.json`
  (new, agent-editable — one entry per semantic cell, `expected_sha256`
  computed now from the actual, currently-committed
  `claude-hooks.json`/`hooks.json`/`copilot-hooks.json` content — a
  deterministic, human-independent computation)
- `tests/hook-activation-live-proof/nonce-ledger.json` (new, agent-editable
  — schema `live-host-nonce-ledger/v1`, seeded `{"schema":
  "live-host-nonce-ledger/v1", "entries": []}`; Epic A1's own handshake
  script appends real entries once it exists)
- `plugins/sdd-quality-loop/scripts/validate-live-host-proof.py` (new,
  agent-editable — Python master: Schema Validation Rules, the
  `matrix_cell` ↔ `runtime`/`plugin_hooks_flag` discriminator, Nonce
  Issuance Ledger checks, Expected-Digest Manifest comparison, the
  Signing Contract's JCS canonicalization + domain-separated Ed25519
  verification, the SKIP Representation three-state logic, the
  classification-mismatch/replay guard, the aggregate
  `discharged`/`pending`/hard-failure gate, and the one lock-guarded
  atomic `consumed_by_record` write)
- `plugins/sdd-quality-loop/scripts/validate-live-host-proof.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/validate-live-host-proof.ps1` (new,
  agent-editable — twin)
- `tests/validate-live-host-proof.tests.sh` (new, agent-editable — this
  task's own TEST-026/027/028 cases; T-008 later extends this same file
  in place with its own TEST-013–016 cases, an existing-file edit that
  carries no new suite/CI registration of its own)
- `tests/validate-live-host-proof.tests.ps1` (new, agent-editable — twin)
- `tests/fixtures/live-host-proof/` (new fixture tree — disposable
  fixture Ed25519 keypairs; one fixture per named error code
  (`ERR_MISSING_CELL`, `ERR_SCHEMA_INVALID`, `ERR_CELL_RUNTIME_MISMATCH`,
  `ERR_FEATURE_CONFIG_MISMATCH`, `ERR_NONCE_UNKNOWN`, `ERR_NONCE_REUSED`,
  `ERR_NONCE_CELL_MISMATCH`, `ERR_NONCE_ISSUED_AFTER_SESSION`,
  `ERR_NONCE_EXPIRED`, `ERR_NONCE_DUPLICATE_LEDGER_ENTRY`,
  `ERR_ISSUER_SIGNATURE_INVALID`, `ERR_HASH_MISMATCH`,
  `ERR_DIGEST_MISMATCH`, `ERR_SIGNATURE_INVALID`, `ERR_SIGNER_UNTRUSTED`,
  `ERR_SIGNER_IDENTITY_MISMATCH`, `ERR_SIGNER_KEY_COLLISION`,
  `ERR_SYNTHETIC_SUBSTITUTION`, `ERR_STALE_SKIP`); a disposable
  `SKIP`-record fixture per SKIP Representation state (missing/valid
  pre-merge/stale post-merge); a `discharged`-state fixture set proving
  the aggregate gate cannot pass vacuously)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable)
- `specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-003's)
- `specs/epic-196-a8-integration/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry)

Data Migration: none — every data entity is net-new, no prior version.

Breaking API: no; every planned file is wholly new.

Rollback: revert this task's commit(s); nothing protected is written
directly; `a8-trusted-signers.json` stays seeded empty by this task alone
(T-008's own commit adds the real signer entries), so a revert of this
task's commit(s) changes no signed security claim.

### Goal

Author `validate-live-host-proof.{py,sh,ps1}` implementing the full Data
Plan/API Contract Plan for `live-host-verification-record/v1`: Schema
Validation Rules (`additionalProperties: false`, conditional
required/non-null per `verdict`), the `matrix_cell` ↔ `runtime`/
`plugin_hooks_flag` discriminator table, the Nonce Issuance Ledger checks
(unknown/reused/cell-mismatch/issued-after-session/expired/duplicate-entry),
the Expected-Digest Manifest comparison, the Signing Contract (RFC 8785
JCS canonicalization, domain-separated Ed25519 verification per ADR-0028),
the three-state SKIP Representation (missing / valid pre-merge SKIP /
stale post-merge SKIP), the AC-027 classification-mismatch/replay guard,
and the aggregate `discharged`/`pending`/hard-failure gate. Seed the
Trusted-Signer Registry, Expected-Digest Manifest, and Nonce Ledger as
real (empty or deterministically-computed) files; every behavior this
task's own Done When claims is proved against disposable fixtures under
`tests/fixtures/live-host-proof/`, never against the five real semantic
cells (T-008's own scope) or a real signer identity.

### Must Read

- `specs/epic-196-a8-integration/requirements.md` (REQ-003(b)(c), REQ-006,
  AC-026–028, Field Definitions "Live-host hook-activation handshake
  proof")
- `specs/epic-196-a8-integration/design.md` (Data Plan
  `live-host-verification-record/v1` in full, including SKIP
  Representation, Schema Validation Rules, Raw Capture/Nonce Ledger/
  Expected-Digest Manifest, Signing Contract; Live-Host Semantic Matrix
  (for the `matrix_cell` discriminator table this schema enforces); SKIP
  Allowlist Activation Gate (for the allowlist shape this validator
  reads); API/Contract Plan's `validate-live-host-proof` entry; Test
  Strategy items 8, 10)
- `docs/adr/0028-live-host-proof-ed25519-signing.md` (the accepted Signing
  Contract source this task implements verbatim, never re-derives)
- `specs/epic-196-a8-integration/investigation.md` (INV-002, INV-004–007,
  Safety constraints)
- `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` (the
  `mkdir` lock + `mktemp` scratch + atomic-rename + `trap`-guarded release
  pattern this validator's own single ledger write reuses)

### Scope

- Write the acceptance checks first (TDD Red→Green): TEST-026 (schema
  round-trip for every field, every named error code fixture individually
  triggered, including the three-state SKIP Representation against
  disposable fixture records), TEST-027 (classification-mismatch/replay
  guard: no automated↔manual substitution, no nonce reuse, no unsigned or
  single-signature record accepted), TEST-028 (the aggregate
  `discharged`/`pending`/hard-failure states, exit codes, and the one
  lock-guarded `consumed_by_record` write, idempotent under a repeat run).
- CI resilience per Global Constraints.
- Register `validate-live-host-proof` in `tests/run-all.sh`/`.ps1`; stage
  the `.github/workflows/test.yml` candidate appended to T-003's staged
  file.
- Seed `a8-trusted-signers.json` empty, `a8-expected-hook-config-
  digests.json` computed, and `nonce-ledger.json` empty — the three real
  registries this validator reads/writes; `a8-skip-allowlist.json` and the
  five draft `SKIP` records are T-008's own scope, not this task's.

### Done When

- [ ] **Schema + discriminator correctness** — TEST-026 passes: every
  field's type/format constraint and every named error code
  (`ERR_SCHEMA_INVALID`, `ERR_CELL_RUNTIME_MISMATCH`,
  `ERR_FEATURE_CONFIG_MISMATCH`, `ERR_HASH_MISMATCH`,
  `ERR_DIGEST_MISMATCH`) is independently exercised, including all three
  SKIP Representation states (missing/valid pre-merge SKIP/stale
  post-merge SKIP) against disposable fixture records (AC-026).
- [ ] **Nonce ledger + signing verification** — TEST-026/027 pass: every
  ledger error code (`ERR_NONCE_UNKNOWN`, `ERR_NONCE_REUSED`,
  `ERR_NONCE_CELL_MISMATCH`, `ERR_NONCE_ISSUED_AFTER_SESSION`,
  `ERR_NONCE_EXPIRED`, `ERR_NONCE_DUPLICATE_LEDGER_ENTRY`,
  `ERR_ISSUER_SIGNATURE_INVALID`) and every signer error code
  (`ERR_SIGNATURE_INVALID`, `ERR_SIGNER_UNTRUSTED`,
  `ERR_SIGNER_IDENTITY_MISMATCH`, `ERR_SIGNER_KEY_COLLISION`) is
  independently exercised against disposable fixture keypairs (AC-026,
  AC-027).
- [ ] **Classification-mismatch/replay guard** — TEST-027 passes: an
  `automated`-claimed record for a `manual-required` check, a reused
  nonce, a missing `reviewer_signature`, and a raw capture byte-identical
  to a known synthetic fixture are each rejected (`ERR_SYNTHETIC_
  SUBSTITUTION` for the last case) (AC-027).
- [ ] **Aggregate gate** — TEST-028 passes: `discharged` only when all
  five cells pass in full; `pending` (exit 0) when every cell is a valid
  pre-merge `SKIP`; a hard, non-zero-exit failure with a named error code
  on any missing/stale/`FAIL`/digest-mismatched/duplicate-nonce record; the
  one `consumed_by_record` write is lock-guarded, atomic, and idempotent
  under a repeat run against the same record (AC-028).
- [ ] **Suite/CI registration** — `tests/validate-live-host-proof.
  tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1`; the staged
  `test.yml` candidate exists with a correct `MANIFEST.sha256` entry; the
  LIVE `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **TDD evidence** — RED (each error-code/state case against a
  deliberately permissive validator) and GREEN (the full suite against the
  correct implementation, including the one fully-clean `discharged`-shape
  fixture proving the suite cannot pass vacuously). An independent
  quality-gate verdict records PASS.
- [ ] **Requirement-traceability evidence** (high tier) — the
  `check-traceability` report is recorded as evidence.

### Out of Scope

- The five real semantic-cell classifications (AC-013, AC-014), the
  five-cell live-host proof discharge across the actual Live-Host Semantic
  Matrix (AC-015), the consumer-entry-point inventory (AC-016), the five
  draft `SKIP` records, the `a8-skip-allowlist.json` `AC-015`/`AC-016`
  entries, and the HUMAN APPLY STEP that registers real signer identities
  and countersigns those records — all T-008's exclusive scope, layered on
  top of this task's already-implemented validator.
- Producing a genuine, real-session `live-host-verification-record/v1`
  with `verdict: PASS`/`FAIL` for any of the five cells — that is
  produced only by a human running Epic A1's own handshake script
  (`check-hook-activation-handshake.{py,sh,ps1}`, merged to `main` on
  2026-08-08) in a real, installed-toolchain CLI session, inside
  T-008's HUMAN APPLY STEP; out of scope for this task (Main Workflows
  step 7, requirements.md).
- Epic A1's own `check-hook-activation-handshake.{py,sh,ps1}` and its five
  migrated consumer entry points — this task only wires the schema/
  validator contract they feed; implementing or modifying Epic A1's own
  artifacts stays out of scope.
- The synthetic direct-invocation extension to `cli-hook-enforcement.ps1`
  (T-004) — a structurally separate artifact (AC-017).

### Blockers

None

---

## T-006 Author the REQ-004 path/line-ending pairwise regression matrix

Source Issue: https://github.com/aharada54914/sdd-forge/issues/196

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task is filesystem/fixture-only
regression testing (Windows path separators, `.gitattributes`-layer
CRLF-vs-LF, NFC-vs-NFD filename/content) with a fully enumerated,
machine-checked 16-row × 3-case oracle and no sensitive surface — no
authentication, secrets, or migration path is touched. It is not `high`:
a defect here produces an incorrect test result, never a security-relevant
false pass on a boundary another component depends on for trust (contrast
T-002/T-005). Required Workflow is `acceptance-first` per the policy's
medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-004 (AC-018, AC-019, AC-020, AC-021)

Depends On: T-001, T-002, T-003, T-005 (Global Constraints — serialized
only; no functional dependency on any of them).

Planned Files:
- `tests/path-lineending-regression.tests.sh` (new — enumerates the full
  16-row pairwise covering combination matrix per design.md's own
  generation algorithm; runs all three cases (`windows-path-separator`,
  `crlf-lf-gitattributes-layer`, `nfc-nfd-filename`) against every
  applicable row)
- `tests/path-lineending-regression.tests.ps1` (new — twin)
- `tests/fixtures/path-lineending-regression/` (new — the NFD-authored
  source fixture (macOS-default decomposed form) whose NFC form is the
  fixture's own expected per-OS byte sequence, plus one fixture per EOL
  variant)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable)
- `specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-005's)
- `specs/epic-196-a8-integration/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry)

Data Migration: none.

Breaking API: no; every planned file is wholly new.

Rollback: revert this task's commit(s); nothing protected is written
directly.

### Goal

Author `tests/path-lineending-regression.tests.sh`/`.ps1`, enumerating the
16-row pairwise covering combination matrix exactly per design.md's own
generation algorithm (16 combinations of `script` × `eol` ×
`normalization` × `phase`, `os` cycled `windows, linux, macos` by
`((i-1) mod 3)`), evaluating all three cases per row against the fixed
oracle fields (`source_bytes_sha256`, `resolved_path`,
`copied_bytes_sha256`, `stdout_substring`, `uninstall_residue`), with
`windows-path-separator` asserted only on rows where `os == windows AND
script == ps1` (rows 10, 13, 16) and `N/A` elsewhere, and the other two
cases asserted on every row per the Unicode-Normalization Contract this
epic owns independently of `.gitattributes`.

### Must Read

- `specs/epic-196-a8-integration/requirements.md` (REQ-004, AC-018–021)
- `specs/epic-196-a8-integration/design.md` (Data Plan
  `path-lineending-fixture-result/v1`, the full REQ-004 Pairwise Covering
  Combination Matrix section including its 16-row table, the
  Unicode-Normalization Contract, Path/Line-Ending Regression Matrix
  layer-disposition table)
- `specs/epic-196-a8-integration/investigation.md` (INV-022)
- `.gitattributes:1-9` (the git-layer normalization this epic's own
  `crlf-lf-gitattributes-layer` case asserts against, and explicitly does
  NOT extend with a Unicode rule)

### Scope

- Write the acceptance checks first (acceptance-first): TEST-018
  (`windows-path-separator`, `ASSERT` on rows 10/13/16 only, `N/A`
  elsewhere), TEST-019 (`crlf-lf-gitattributes-layer`, `ASSERT` on every
  row, both the LF-identity and CRLF-correction confirmations), TEST-020
  (`nfc-nfd-filename`, `ASSERT` on every row per the Unicode-Normalization
  Contract, plus the collision-policy zero-residue check on every
  `phase=uninstall` row), TEST-021 (the layer-disposition table's own
  cell-per-case exhaustiveness, including the explicit `N/A for this
  package` canonicalizer-layer row).
- CI resilience per Global Constraints.
- Register `path-lineending-regression` in `tests/run-all.sh`/`.ps1`;
  stage the `.github/workflows/test.yml` candidate appended to T-005's
  staged file.

### Done When

- [ ] **Path-separator axis** — TEST-018 passes: `ASSERT` only on rows 10,
  13, 16; `N/A`, never omitted, on the other 13 rows (AC-018).
- [ ] **CRLF/LF axis** — TEST-019 passes: `copied_bytes_sha256` equals the
  LF-normalized repository blob hash on all 16 rows (AC-019).
- [ ] **NFC/NFD axis** — TEST-020 passes: `resolved_path`/
  `copied_bytes_sha256` match the Unicode-Normalization Contract's own
  fixed NFC bytes on all 16 rows; zero uninstall residue under both byte
  forms on every uninstall row (AC-020).
- [ ] **Layer-disposition table** — TEST-021 passes: every REQ-004 case
  carries exactly one disposition, including the canonicalizer-layer row
  fixed `N/A for this package` (AC-021).
- [ ] **Suite/CI registration** — `tests/path-lineending-regression.
  tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1`; the staged
  `test.yml` candidate exists with a correct `MANIFEST.sha256` entry; the
  LIVE `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **Acceptance-first evidence** — RED (each of the 48 row×case cells
  against a deliberately permissive fixture harness) and GREEN (the full
  suite on the existing 3-OS CI matrix). An independent quality-gate
  verdict records PASS.

### Out of Scope

- Epic A1's own canonicalizer-layer CRLF/YAML handling (Non-goals,
  requirements.md) — this task never asserts against it.
- Any change to `.gitattributes` itself.

### Blockers

None

---

## T-007 Author the REQ-006/REQ-007 process-integrity static checks

Source Issue: https://github.com/aharada54914/sdd-forge/issues/196

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task is internal tooling — three
static/doc-review checks over this package's own frozen Phase 1 documents
(design.md's Classification Table exhaustiveness; a scope-boundary
self-check confirming no AC re-specifies another Epic's own 3-environment
build-out; a citation-format check over investigation.md/requirements.md/
design.md) — real parsing logic other maintainers may come to rely on for
audit trust, but it gates no runtime behavior and touches no sensitive
surface. It is not `low`: the checks have genuine control-flow (markdown
table parsing, per-AC exhaustiveness accounting) that a silent defect
could render vacuously passing, unlike a purely cosmetic change. Required
Workflow is `acceptance-first` per the policy's medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-006 (AC-025), REQ-007 (AC-029, AC-030)

Depends On: T-001, T-002, T-003, T-005, T-006 (functional — this task's own
"Test-registration procedure proof" Done When requires every one of those
tasks' suite-registration entries, in the shared runners and in the staged
CI candidate, to already exist, so it cannot be correctly implemented
before them; the same basis on which T-003 → T-002 is marked functional.
Also the natural final task, since AC-030's own citation check reads every
other Phase 1 document this feature already froze, matching this
repository's own established "last task re-confirms cumulative state"
convention, `specs/epic-190-a2-capability-registry/tasks.md` T-007).

Planned Files:
- `plugins/sdd-quality-loop/scripts/check-a8-classification-table.py`
  (new, agent-editable — parses design.md's Automated/Manual
  Classification Table, confirms every AC-001–024 that REQ-001–REQ-005
  name appears in exactly one row with exactly one of `automated`/
  `automated-pending-confirmation`/`manual-required`, and confirms the
  separate AC-028 row is its own single entry)
- `plugins/sdd-quality-loop/scripts/check-a8-classification-table.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/check-a8-classification-table.ps1`
  (new, agent-editable — twin)
- `plugins/sdd-quality-loop/scripts/check-a8-scope-boundary.py` (new,
  agent-editable — greps requirements.md's own AC-001–030 text for a
  forbidden pattern: a new `.sh`/`.ps1` pair name, a new plugin hook
  config path, or a new environment-specific test name this epic's own
  Phase 2/3 would build *for* another Epic's own surface, distinct from
  the artifacts this package's own Components table already names)
- `plugins/sdd-quality-loop/scripts/check-a8-scope-boundary.sh`/`.ps1`
  (new, agent-editable — wrappers)
- `plugins/sdd-quality-loop/scripts/check-a8-citation-compliance.py` (new,
  agent-editable — confirms every checkable factual claim paragraph in
  this package's own investigation.md/requirements.md/design.md carries a
  file:line or external-doc citation, per the WFI-011 convention
  `AGENTS.md:137-145` already establishes)
- `plugins/sdd-quality-loop/scripts/check-a8-citation-compliance.sh`/`.ps1`
  (new, agent-editable — wrappers)
- `tests/check-a8-process-integrity.tests.sh` (new, agent-editable —
  exercises all three checks above against this feature's own frozen
  documents plus a mutated-copy negative fixture per check)
- `tests/check-a8-process-integrity.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable)
- `specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-006's — the final cumulative candidate)
- `specs/epic-196-a8-integration/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new, final entry)

Data Migration: none.

Breaking API: no; every planned file is wholly new.

Rollback: revert this task's commit(s); nothing protected is written
directly.

### Goal

Author three small static-check scripts confirming properties of this
package's own already-frozen Phase 1 documents: (1) design.md's
Automated/Manual Classification Table is exhaustive over AC-001–024 plus
its own single AC-028 row, with exactly one classification value per row
(AC-025); (2) requirements.md's own AC-001–030 list never names a new
`.sh`/`.ps1` pair, plugin hook config, or environment-specific test this
epic's own Phase 2/3 would build *for* another Epic's own surface —
verifying composition/integration of another Epic's artifacts only
(AC-029); (3) every checkable factual claim in investigation.md/
requirements.md/design.md carries a file:line or external-doc citation,
per the WFI-011 convention (AC-030).

### Must Read

- `specs/epic-196-a8-integration/requirements.md` (AC-025, AC-029, AC-030,
  Non-goals — the exact scope-boundary text this task's check re-verifies
  mechanically)
- `specs/epic-196-a8-integration/design.md` (Automated/Manual
  Classification Table in full — the artifact TEST-025 parses)
- `specs/epic-196-a8-integration/investigation.md` (the citation style
  every INV-NNN row already follows — the pattern TEST-030 checks for)
- `AGENTS.md:137-145` (WFI-011, "Spec factual-claim evidence citations" —
  the convention this task's citation check formalizes as a script rather
  than a manual spec-review-time judgment)
- `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh` (the `missing:
  <item>`-style diagnostic-line convention these scripts' own output
  follows)

### Scope

- Write the acceptance checks first (acceptance-first): TEST-025
  (classification-table exhaustiveness, with a mutated-copy fixture
  missing one AC row and a fixture with two classification values on one
  row, both correctly rejected), TEST-029 (scope-boundary self-check, with
  a mutated-copy fixture that names a new `.sh`/`.ps1` pair for another
  Epic's own surface, correctly rejected), TEST-030 (citation compliance,
  with a mutated-copy fixture containing one uncited factual-claim
  paragraph, correctly rejected).
- CI resilience per Global Constraints.
- Register `check-a8-process-integrity` in `tests/run-all.sh`/`.ps1`;
  stage the `.github/workflows/test.yml` candidate appended to T-006's
  staged file — the final cumulative candidate for this feature.

### Done When

- [ ] **Classification-table exhaustiveness** — TEST-025 passes against
  the real design.md (clean pass) and rejects both mutated-copy fixtures
  (missing row; ambiguous row) (AC-025).
- [ ] **Scope-boundary self-check** — TEST-029 passes against the real
  requirements.md (clean pass) and rejects the mutated-copy fixture naming
  a new per-Epic artifact (AC-029).
- [ ] **Citation compliance** — TEST-030 passes against the real
  investigation.md/requirements.md/design.md (clean pass) and rejects the
  mutated-copy fixture with an uncited claim (AC-030).
- [ ] **Test-registration procedure proof** — every one of the seven
  `tests/*.tests.sh`/`.tests.ps1` pairs this feature's tasks author
  (T-001's `cross-runtime-handoff`, T-002's `check-installed-plugin-drift`,
  T-003's `install-uninstall-matrix`, T-005's `validate-live-host-proof`,
  T-006's `path-lineending-regression`, this task's own
  `check-a8-process-integrity`, plus T-004's in-place extension of the
  already-registered `cli-hook-enforcement.ps1`) is registered in
  `tests/run-all.sh`/`.ps1`; the final staged `.github/workflows/test.yml`
  candidate under `human-copy/` carries every suite's CI steps with a
  correct, cumulative `MANIFEST.sha256` entry set.
- [ ] **Suite registration + structural checks** —
  `tests/check-a8-process-integrity.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`; a grep self-check confirms no version string
  was mutated outside `scripts/bump-version.sh`.
- [ ] **Acceptance-first evidence** — RED (each of the three checks
  against its own mutated-copy fixture) and GREEN (the full suite against
  this feature's own real, unmodified documents). An independent
  quality-gate verdict records PASS.

### Out of Scope

- Editing investigation.md, requirements.md, design.md, or
  acceptance-tests.md themselves (frozen, hash-bound; these checks are
  read-only over them).
- Any check REQ-001–REQ-005 already name (Automated/Manual Classification
  Table's own AC-001–024/AC-028 rows) — this task only checks the table's
  own exhaustiveness property, never re-implements any individual check.

### Blockers

T-001, T-002, T-003, T-005, T-006

---

## T-008 Classify the REQ-003 live-host semantic matrix and author its draft SKIP records

Source Issue: https://github.com/aharada54914/sdd-forge/issues/196

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified: this task performs the concrete,
trust-establishing half of Security Boundary B1 (design.md) — determining
and recording the Codex `plugin_hooks`-flag and Copilot subagent/primary
semantic-cell classifications AC-013/AC-014 gate on, authoring the five
draft `SKIP` records `validate-live-host-proof` (T-005) evaluates, wiring
the five-migrated-consumer inventory (AC-016), and performing the HUMAN
APPLY STEP that seeds the real Trusted-Signer Registry
(`a8-trusted-signers.json`) with the operator/reviewer identities and
produces the two-party Ed25519 countersignature on those records. A
silent defect here (a cell misclassified `automated` when no genuine
session-dispatch contract is actually confirmed, a draft record missing
its `AC-015` allowlist citation, a signer registered under the wrong role
or identity) would let an unverified or misattributed claim later be
accepted by T-005's own validator as a genuine live-host proof — the same
"silent defect causes material harm" surface T-005's own Risk Rationale
names on this identical security boundary (matching
`specs/epic-190-a2-capability-registry/tasks.md` T-002/T-004's identical
reasoning for security-boundary primitives). It is not `critical`: this
task produces no genuine, signed `live-host-verification-record/v1`
claiming a real CLI session occurred (Protected Files, above) — every
record it commits stays an explicit, unsigned, non-authoritative draft
until a human completes the apply step below, and `validate-live-host-
proof` (T-005) remains the sole authority that accepts or rejects any
record. Required Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003 (AC-013, AC-014, AC-015, AC-016)

Depends On: T-001 (functional — appends the `AC-015`/`AC-016` entries to
the `a8-skip-allowlist.json` T-001 creates with the `AC-006` entry;
Protected Files, above), T-005 (functional — this task's own TEST-013–016
cases exercise `validate-live-host-proof`, which must exist first, and the
HUMAN APPLY STEP's own `discharged` confirmation re-runs that same script;
API/Contract Plan). This task touches neither `tests/run-all.*` nor the
staged `.github/workflows/test.yml` candidate — it extends T-005's
already-registered `tests/validate-live-host-proof.tests.{sh,ps1}` in
place, so it carries no Global-Constraints chain-ordering requirement of
its own relative to T-002/T-003/T-006/T-007 (matching T-004's identical
positioning outside that chain).

Planned Files:
- `tests/hook-activation-live-proof/claude-active.json`,
  `codex-enabled-active.json`, `codex-disabled-expected-unavailable.json`,
  `copilot-primary-active.json`,
  `copilot-subagent-expected-unavailable.json` (new — five DRAFT `SKIP`
  records, schema-complete and citing the `AC-015` allowlist entry, with
  `operator_signature`/`reviewer_signature` left as an explicit unsigned
  marker pending the HUMAN APPLY STEP below; never committed as a signed,
  authoritative record by this task itself)
- `plugins/sdd-review-loop/references/a8-skip-allowlist.json` (existing
  after T-001, agent-editable — appends the `AC-015` and `AC-016` entries
  only; the `AC-006` entry T-001 seeded is left untouched)
- `plugins/sdd-review-loop/references/a8-trusted-signers.json` (existing
  after T-005, human-apply-editable — the HUMAN APPLY STEP appends the
  real `operator`/`reviewer` key entries; the agent portion of this task
  never invents or commits a real keypair)
- `tests/validate-live-host-proof.tests.sh` (existing after T-005,
  agent-editable — extended in place with this task's own TEST-013–016
  cases; every one of T-005's pre-existing TEST-026/027/028 cases
  preserved verbatim)
- `tests/validate-live-host-proof.tests.ps1` (existing after T-005,
  agent-editable — twin, extended in place)
- `tests/fixtures/live-host-proof/` (existing after T-005, agent-editable
  — this task may add cell-specific classification fixtures alongside
  T-005's own error-code/SKIP-state fixtures; no existing fixture removed)

Data Migration: none — every new file is net-new; the two edited files
receive additive entries only.

Breaking API: no; this task edits two existing, agent-editable files
(`a8-skip-allowlist.json`, `tests/validate-live-host-proof.tests.{sh,
ps1}`) with additive content only, and one existing file
(`a8-trusted-signers.json`) via the human-only apply step.

Rollback: revert this task's commit(s); the five draft `SKIP` records
remain unsigned (non-authoritative) until a human completes the apply
step, so a revert before that step changes no signed security claim; a
revert after the human apply step must also state whether the now-signed
records and the `a8-trusted-signers.json` entries should be hand-reverted
(mirroring T-001/T-003's own staged-candidate revert note for signed/
applied artifacts).

### Goal

Determine and record, per the Live-Host Semantic Matrix (design.md), the
Codex `plugin_hooks`-flag classification (`Codex-enabled-active`/
`Codex-disabled-expected-unavailable`) and the Copilot subagent/primary
classification (`Copilot-primary-active`/`Copilot-subagent-expected-
unavailable`), each `manual-required`/`automated-pending-confirmation`
until a genuine, native-dispatcher-engaging session contract is confirmed
for that runtime; wire the five-migrated-consumer fingerprinted inventory
`SKIP`ped pre-merge (AC-016); author five schema-complete but explicitly
unsigned draft `SKIP` records for the five semantic cells, each citing the
`AC-015` allowlist entry; append the `AC-015`/`AC-016` entries to
`a8-skip-allowlist.json`; and complete the HUMAN APPLY STEP — a
maintainer and an independent reviewer each generate an Ed25519 keypair,
register them in `a8-trusted-signers.json`, sign the five draft
records, and run Epic A1's merged handshake script
(`check-hook-activation-handshake.{py,sh,ps1}`, on `main` since
2026-08-08) to produce the genuine session records that discharge the
five cells — leaving `validate-live-host-proof` (T-005) to independently
confirm `discharged`, not a hard failure, before this task is marked
Done.

### Must Read

- `specs/epic-196-a8-integration/requirements.md` (REQ-003(b)(c), REQ-006,
  AC-013–016, Field Definitions "Live-host hook-activation handshake
  proof", Roles and Permissions)
- `specs/epic-196-a8-integration/design.md` (Live-Host Semantic Matrix in
  full; Direct-Invocation De-Spoofing; SKIP Allowlist Activation Gate
  (Allowlist record shape, Activation predicate); Signing Contract
  (Trusted-Signer Registry shape); Automated/Manual Classification Table;
  Test Strategy item 5)
- `docs/adr/0028-live-host-proof-ed25519-signing.md` (the accepted Signing
  Contract this task's human apply step follows verbatim when generating
  and registering keypairs)
- `specs/epic-196-a8-integration/investigation.md` (INV-011, INV-012,
  Safety constraints)
- `docs/troubleshooting.md:185-204` (the documented Copilot-subagent
  fallback this task's classification record cross-references)
- `plugins/sdd-quality-loop/scripts/validate-live-host-proof.py` (T-005's
  own implementation — read before extending its test suite, so this
  task's new cases exercise the real schema/discriminator contract rather
  than an assumed one)

### Scope

- Write the acceptance checks first (TDD Red→Green), extending T-005's
  existing suite in place: TEST-013 (Codex `plugin_hooks` flag matrix
  classified `manual-required` until a scripted session contract is
  confirmed; the two Codex semantic cells' schema/discriminator behavior
  against T-005's own validator), TEST-014 (Copilot subagent/primary
  contrast classified the same way; the two Copilot semantic cells'
  behavior, plus a reference to `docs/troubleshooting.md`'s documented
  fallback), TEST-015 (all five semantic cells' `SKIP`/`PASS`/`FAIL`
  handling against the actual draft records this task commits), TEST-016
  (the 5-consumer fingerprinted-inventory shape, `SKIP`ped pre-merge,
  wired for Epic A1's own five entry points once they exist).
- Confirm every one of T-005's pre-existing TEST-026/027/028 cases still
  passes unmodified after this task's own extension (non-regression).
- Author the five draft `SKIP` records; append the `AC-015`/`AC-016`
  entries to `a8-skip-allowlist.json`.
- Complete the HUMAN APPLY STEP (see Done When) and re-run
  `validate-live-host-proof` to confirm `discharged`.

### Done When

- [ ] **Codex/Copilot semantic-cell classification** — TEST-013/014 pass:
  both Codex cells and both Copilot cells are correctly classified
  `manual-required`/`automated-pending-confirmation` per the Classification
  Table, with `docs/troubleshooting.md`'s fallback commands referenced for
  the Copilot-subagent cell (AC-013, AC-014).
- [ ] **Five-cell live-host proof handling** — TEST-015 passes against the
  five draft records this task commits: all three SKIP Representation
  states (missing/valid pre-merge SKIP/stale post-merge SKIP) are
  correctly distinguished across all five semantic cells (AC-015).
- [ ] **Consumer-entry-point inventory shape** — TEST-016 passes: the
  fingerprinted-inventory schema for Epic A1's five migrated consumers is
  wired and `SKIP`ped pre-merge, never a partial inventory silently
  presented as complete (AC-016).
- [ ] **Draft SKIP records + allowlist entries committed, unsigned** — the
  five files under `tests/hook-activation-live-proof/` are schema-complete,
  cite the `AC-015` allowlist entry, and are explicitly marked
  unsigned/non-authoritative pending the human apply step below; the
  `AC-015`/`AC-016` entries exist in `a8-skip-allowlist.json`.
- [ ] **HUMAN APPLY STEP — Trusted-Signer Registry, two-party signing,
  and live-host discharge:** a maintainer and an independent reviewer
  each generate an Ed25519 keypair, register them in
  `a8-trusted-signers.json` with roles `operator`/`reviewer` (and the
  `issuer`-role entry for Epic A1's handshake script, the sole nonce
  issuer), sign the five draft `SKIP` records, and run Epic A1's merged
  handshake script (`check-hook-activation-handshake.{py,sh,ps1}`, on
  `main` since 2026-08-08 and present at the canonical installed path)
  against the five semantic cells to produce the genuine, attributable
  session records that discharge them — confirmed by re-running
  `validate-live-host-proof` and observing `discharged` (not a hard
  failure) before this task is marked Done (AC-028's own aggregate,
  computed by T-005, reaching `discharged` is the Done state; a
  surviving post-activation `SKIP` is `ERR_STALE_SKIP`, a hard failure,
  per the SKIP Allowlist Activation Gate).
- [ ] **Non-regression** — every one of T-005's pre-existing
  TEST-026/027/028 cases in `tests/validate-live-host-proof.tests.sh`/
  `.ps1` still passes unmodified after this task's own in-place extension.
- [ ] **TDD evidence** — RED (each new classification/inventory case
  against a deliberately permissive addition) and GREEN (the full,
  extended suite). An independent quality-gate verdict records PASS.
- [ ] **Requirement-traceability evidence** (high tier) — the
  `check-traceability` report is recorded as evidence.

### Out of Scope

- `validate-live-host-proof`'s own schema, nonce-ledger, signing-
  verification, classification-mismatch-guard, and aggregate-gate
  implementation — T-005's exclusive scope; this task only exercises and
  feeds it.
- Producing a genuine, real-session `live-host-verification-record/v1`
  by any agent-automated means — the genuine records are produced only
  inside the HUMAN APPLY STEP above, by a human running Epic A1's own
  handshake script (`check-hook-activation-handshake.{py,sh,ps1}`,
  merged to `main` on 2026-08-08 and present at the canonical installed
  path) in a real, installed-toolchain CLI session; the agent portion of
  this task never fabricates, signs, or classifies such a record as
  genuine (Main Workflows step 7, requirements.md; investigation.md
  Safety constraints).
- Epic A1's own `check-hook-activation-handshake.{py,sh,ps1}` and its five
  migrated consumer entry points — this task only wires the inventory
  contract they feed; implementing or modifying Epic A1's own artifacts
  stays out of scope.
- The synthetic direct-invocation extension to `cli-hook-enforcement.ps1`
  (T-004) — a structurally separate artifact (AC-017).
- Any new suite/CI registration — this task extends an already-registered
  file only (Depends On, above).

### Blockers

T-001, T-005
