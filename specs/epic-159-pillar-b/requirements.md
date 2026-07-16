# Requirements: epic-159-pillar-b

Spec-Review-Status: Passed
Source Issue: https://github.com/aharada54914/sdd-forge/issues/148
Epic: https://github.com/aharada54914/sdd-forge/issues/159 (Pillar B —
loop-consistency / loop-inventory の release-gate 化, size S)
Investigation: specs/epic-159-pillar-b/investigation.md (INV-001..INV-017,
OQ-001..OQ-007)

## Overview

Both loop suites (`tests/loop-consistency.tests.sh`, `tests/loop-inventory.tests.sh`)
already run in CI on every push/PR across all 3 matrix OSes (INV-002:
`.github/workflows/test.yml:71-79`, `:91-99`), but nothing in the release
path consumes their result: `scripts/bump-version.sh` has no loop-suite
invocation anywhere (INV-001: `scripts/bump-version.sh:38-42`), and
`.github/workflows/release.yml` contains no `needs:` gate on test results at
all (INV-006: `release.yml:30-100`; INV-007: `release.yml:10-13` triggers
only on `release: [published]`/`workflow_dispatch`, with no `workflow_run`
predicate on `test.yml`). Issue #148 closes this narrow gap for the two
loop suites specifically — it is deliberately NOT the wider
release-gating question a sibling spec already tracks at broader scope
(INV-015: `specs/risk-adaptive-layer/{investigation,design}.md`). Two legs,
matching the issue's own Done condition wording (OQ-001 decision): a
CLI-side prerequisite in `bump-version.sh` (T-001) that runs both suites
fail-closed before any release surface is mutated, and a `release.yml`-side
required job (T-002) that the tarball/SBOM/attestation/upload job `needs`.

## Target Users

- Release operators running `scripts/bump-version.sh <version>` locally
  (bash-only host — INV-008: no `.ps1` twin exists) — they need the same
  two loop suites that already gate CI pushes/PRs to also gate the version
  bump itself, so a regression in either suite cannot reach a tagged
  release surface.
- Maintainers publishing a `release: [published]` event or running
  `workflow_dispatch` on `release.yml` — they need the
  tarball/SBOM/checksums/attestation/upload chain (INV-006) to structurally
  depend on both loop suites passing, not merely trust that some earlier
  `test.yml` run happened to be green (INV-007).
- Windows-host contributors and CI runners — `bump-version.sh` has no
  cross-host twin (INV-008); REQ-004 records this as an explicit, recorded
  degradation rather than a silent gap, with the `release.yml` leg (REQ-002)
  providing the equivalent guarantee on any host that triggers a release.

## Problems

- `scripts/bump-version.sh`'s only precondition is a CHANGELOG heading check
  (INV-001: `scripts/bump-version.sh:38-42`); a release operator can run it
  against a repository whose loop suites are currently failing and every
  release surface (18 plugin manifests, both marketplaces, `README.md`,
  `tests/validate-repository.ps1`, `tests/repository-release-validation.tests.sh`)
  still gets rewritten (INV-001, `scripts/bump-version.sh:51-70`).
- `.github/workflows/release.yml` has no `needs:` gate at all (INV-006:
  `release.yml:30-100`) and triggers independently of `test.yml` (INV-007:
  `release.yml:10-13`); a tag published against a commit whose CI run
  happened to fail, or was never re-run, still produces a signed, attested,
  checksummed, uploaded release artifact.
- Neither loop suite's already-established, machine-parsable summary line
  (INV-012: `loop-consistency.tests.sh:451`, `loop-inventory.tests.sh:378`)
  nor its documented CI-resilience convention (INV-017:
  `loop-consistency.tests.sh:44`, `loop-inventory.tests.sh:43`, the `pwd -P`
  repo-root convention) is consumed anywhere on the release path (INV-011:
  registered only in `tests/run-all.sh` and `test.yml`).
- No document currently states that a release requires loop-suite green
  (INV-014): the closest existing references either predate the suites
  (`docs/superpowers/plans/2026-07-03-v1.8.0-release.md`) or mention
  `bump-version.sh` only as existing automation
  (`docs/contributor/self-improvement-measurement-proposal.md`).

## Goals

- REQ-001 (T-001; INV-001, INV-003, INV-004, INV-005, INV-009, INV-012,
  INV-013, INV-017, OQ-002, OQ-007): `scripts/bump-version.sh` gains a
  loop-gate prerequisite that runs both `tests/loop-consistency.tests.sh`
  and `tests/loop-inventory.tests.sh` to completion and fails closed
  (non-zero exit, no release surface touched) if either suite's own exit
  code is non-zero — before any of the script's existing mutation steps run
  (before the mutation section beginning at `scripts/bump-version.sh:51`,
  whose first `sed -i` call is at `scripts/bump-version.sh:58`). No
  environment variable, CLI flag, or other bypass exists (OQ-007 decision:
  fail-closed with no override, matching the repository's guard philosophy
  — `scripts/bump-version.sh` is not a protected gate file, INV-005, so
  this is a design choice, not a guard-enforced one).
  `tests/bump-version-gate.tests.sh`/`.ps1` locks this behavior against a
  fixture copy of the repository (never the real repository), driving the
  real, fixture-copied `bump-version.sh` read-only.
- REQ-002 (T-002; INV-006, INV-007, INV-011, INV-012, OQ-001, OQ-002):
  `.github/workflows/release.yml` gains a new required job that runs both
  loop suites on `ubuntu-latest` (matching the workflow's existing
  single-OS scope — `release.yml:32`, INV-006; no 3-OS matrix requirement
  here, unlike `test.yml`'s, since `release.yml` has never had one); the
  existing build job (the sole job currently defined, named `release:`,
  INV-006) gains a `needs:` dependency on it, so none of the
  tarball/SBOM/checksum/attestation/upload steps run unless both suites
  pass. `tests/release-loop-gate.tests.sh`/`.ps1` locks the workflow's YAML
  structure via text-marker assertions (grep/string-index checks),
  following the established `tests/workflow-state-ci-integration.tests.sh`
  technique as a precedent (that suite itself is scoped to `test.yml` +
  quality-gate wiring and is not extended to also cover `release.yml`).
- REQ-003 (T-001, T-002; INV-009, INV-014): The PR updates the applicable
  documents in the same PR — a new `docs/contributor/release-runbook.md`
  section documenting both loop-gate legs (no such document exists today,
  INV-014), a `CHANGELOG.md` `## Unreleased` entry citing #148, and
  `README.md`/`docs/troubleshooting.md` updates wherever they reference the
  release procedure; `validate-repository` and the skill-reference count
  sync stay green; no version bump happens outside `scripts/bump-version.sh`
  (consistent with `specs/epic-159-pillar-a/requirements.md:164-173`
  (REQ-006)'s existing rule that any release version bump goes exclusively
  through `scripts/bump-version.sh`).
- REQ-004 (T-001; INV-008, OQ-003): `scripts/bump-version.sh` remains
  bash-only — no `bump-version.ps1` twin is authored (OQ-003 decision: it
  is a release-operator CLI, not a test suite, so the `.sh`/`.ps1` twin
  mandate the loop suites themselves follow does not bind it). This is
  recorded as an explicit, reviewable design decision, not a silent gap:
  `docs/contributor/release-runbook.md` (REQ-003) states plainly that the
  CLI-side loop-gate prerequisite is bash-only, and that Windows-host
  operators and CI rely on the `release.yml` job (REQ-002) for the
  equivalent guarantee.

## Non-goals

- Implementing the broader "release.yml not gated on CI" issue at its full
  scope: `specs/risk-adaptive-layer/{investigation,design}.md` already
  tracks that gap; this feature implements only the
  loop-consistency/loop-inventory subset issue #148 asks for (INV-015).
- Harmonizing the two suites' runtime budgets (`LOOP_SUITE_BUDGET_SECONDS`,
  `loop-consistency.tests.sh:431` vs. `loop-inventory.tests.sh:41`'s
  hardcoded 300s): out of scope; each suite self-manages (OQ-005).
- Emitting either suite's timing summary into release notes or the sigstore
  attestation: non-goal (OQ-006).
- Authoring `scripts/bump-version.ps1`: explicitly not delivered by this
  feature (REQ-004, OQ-003).
- Adding a `workflow_run` trigger predicate linking `release.yml` to
  `test.yml`, or any other broadening of `release.yml`'s trigger surface
  (`release.yml:10-13`): REQ-002 adds a required job inside the existing
  trigger surface, it does not change what triggers the workflow.
- Modifying any protected gate file (`tests/gates.tests.sh`,
  `tests/eval.tests.sh`, `tests/guard-parity.tests.sh`,
  `tests/constant-parity.tests.sh`, or the `sdd-hook-guard.*`/hook
  registration files listed at `sdd-hook-guard.py:886-927`); neither
  `scripts/bump-version.sh` nor `.github/workflows/release.yml` appears in
  that list (INV-005 extended: `sdd-hook-guard.py:886-927`).
- tasks.md and traceability.md (Phase 2 artifacts, authored after spec
  approval).

## User Stories

As a release operator, when I run `scripts/bump-version.sh <version>`
against a repository whose loop-consistency or loop-inventory suite is
currently red, the script refuses to touch any release surface and tells
me why — the same guarantee CI already gives every push. As a maintainer
publishing a GitHub Release, the tarball/SBOM/attestation/upload chain
structurally cannot run unless both loop suites pass on the release
commit, independent of whatever `test.yml` run may or may not have
happened earlier. As a Windows-host contributor, I know from the release
runbook, not from silent absence, that the CLI-side gate is bash-only and
that the `release.yml` job is my host's equivalent guarantee.

## Acceptance Criteria

- AC-001: `scripts/bump-version.sh`, invoked against a fixture-repository
  copy whose `tests/loop-consistency.tests.sh` and
  `tests/loop-inventory.tests.sh` are both left passing (or replaced with
  trivially-passing stubs) and whose `CHANGELOG.md` already carries the
  target `## v<NEW>` heading, exits 0 and mutates the fixture's release
  surfaces exactly as it does today — the new prerequisite does not
  regress the happy path. (REQ-001)
- AC-002: The same fixture, but with `tests/loop-consistency.tests.sh`
  replaced by a stub that exits non-zero, causes `scripts/bump-version.sh`
  to exit 1 before any release surface is mutated; the fixture (initialized
  as a git working tree at fixture-build time, mirroring
  `tests/repository-release-validation.tests.sh:9-16`'s tar-copy technique)
  reports zero `git status --porcelain` output after the run. (REQ-001)
- AC-003: The same fixture, but with only `tests/loop-inventory.tests.sh`
  replaced by a non-zero-exit stub (loop-consistency left passing),
  produces the same fail-closed, zero-mutation outcome — proving both
  suites gate independently, not just one. (REQ-001)
- AC-004: No environment variable, CLI flag, or other conditional exists
  anywhere in `scripts/bump-version.sh` that skips or bypasses the
  loop-gate prerequisite (OQ-007 decision: no override); asserted by a
  grep-based self-check over the script's source finding no such
  conditional around the two suite invocations. (REQ-001)
- AC-005: The loop-gate prerequisite's invocation of both suites appears,
  by line position in `scripts/bump-version.sh`, before every one of the
  script's existing mutation steps (the `sed -i` calls beginning at
  `scripts/bump-version.sh:58` and following); asserted by a line-number
  comparison in the suite. (REQ-001)
- AC-006: `tests/bump-version-gate.tests.sh`/`.ps1` conforms to the
  CI-resilience bar INV-017 records as established for any new `.sh` suite
  this feature adds: fixture roots normalized with `pwd -P` immediately
  after creation; no possibly-empty bash array expanded under `set -u`; no
  jq consumption (non-use declaration — the suite inspects exit codes and
  `git status --porcelain` output only); no real-validator invocation
  (non-use declaration); and self-registers, via a grep-based self-check
  against `tests/run-all.sh`/`.ps1` and
  `.github/workflows/test.yml` for its own basename (mirroring
  `tests/second-approval-mask.tests.sh:285-289`'s established pattern).
  (REQ-001)
- AC-007: `.github/workflows/release.yml` gains a new job whose steps run
  `tests/loop-consistency.tests.sh` and `tests/loop-inventory.tests.sh` on
  `ubuntu-latest`; asserted by `tests/release-loop-gate.tests.sh`/`.ps1` via
  text-marker checks (mirroring
  `tests/workflow-state-ci-integration.tests.sh`'s technique) confirming
  both suite invocations exist as steps under the new job. (REQ-002)
- AC-008: The existing build job (`release:` in `release.yml`, INV-006)
  carries a `needs:` entry naming the new loop-gate job, and neither the
  loop-gate job's steps nor the build job itself carry a
  `continue-on-error: true` or an `if: always()`/`if: success() ||
  failure()` condition that would let the build job run regardless of the
  loop-gate job's outcome; asserted by the same text-marker suite.
  (REQ-002)
- AC-009: A fixture copy of `release.yml` with the `needs:` entry removed
  is asserted, by the same suite's own text-marker logic applied to the
  mutated copy, to be distinguishable from the compliant version — proving
  the assertion is not vacuously true (negative-branch canary). (REQ-002)
- AC-010: The new loop-gate job runs on `ubuntu-latest` only, matching
  `release.yml`'s existing single-OS scope (`release.yml:32`); and
  `tests/release-loop-gate.tests.sh`/`.ps1` itself self-registers, via the
  same grep-based self-check pattern as AC-006, against
  `tests/run-all.sh`/`.ps1` and `.github/workflows/test.yml`; both
  asserted by the same suite. (REQ-002)
- AC-011: `CHANGELOG.md`'s `## Unreleased` section gains an entry citing
  issue #148; `validate-repository` and the skill-reference count sync stay
  green; no version bump happens outside `scripts/bump-version.sh`.
  (REQ-003)
- AC-012: `docs/contributor/release-runbook.md` (new file) documents both
  loop-gate legs (the `bump-version.sh` CLI prerequisite and the
  `release.yml` required job) and states the REQ-004 cross-host degradation
  explicitly; `README.md` and `docs/troubleshooting.md` are updated
  wherever they reference the release procedure, in the same PR. (REQ-003)
- AC-013: `scripts/` contains no `bump-version.ps1` (INV-008); this absence
  is recorded as an explicit design decision (design.md Design Decisions),
  not treated as a gap by any twin-parity or hygiene suite. (REQ-004)
- AC-014: `docs/contributor/release-runbook.md` (AC-012) states, in terms a
  Windows-host operator can act on, that the CLI-side loop-gate
  prerequisite is bash-only and that the `release.yml` loop-gate job
  (REQ-002) is the equivalent guarantee on any host that triggers a
  release. (REQ-004)

## Field Definitions

- `loop-gate` (REQ-001, REQ-002) — the fail-closed prerequisite this
  feature adds in two independent legs: a CLI-side leg inside
  `scripts/bump-version.sh` (REQ-001) and a CI-side leg inside
  `.github/workflows/release.yml` (REQ-002), both requiring
  `tests/loop-consistency.tests.sh` and `tests/loop-inventory.tests.sh` to
  exit 0 before, respectively, any release-surface mutation or any
  tarball/SBOM/attestation/upload step.
- `build job` (REQ-002) — the sole job currently defined in
  `.github/workflows/release.yml`, named `release:` (INV-006:
  `release.yml:30-100`); this feature adds a `needs:` dependency from that
  job onto the new loop-gate job, without renaming it.

## Roles and Permissions

- Agent: authors `scripts/bump-version.sh` edits,
  `.github/workflows/release.yml` edits, the two new `tests/*.tests.sh`/
  `.ps1` suites, `tests/run-all.sh`/`.ps1` and `test.yml` registration
  edits, and the doc/CHANGELOG updates — none of which are in the
  protected-gate table (verified against `_PROTECTED_GATE_SUFFIXES`,
  `sdd-hook-guard.py:886-927`; see design.md's Protected-File Statement).
- Human maintainer: approves the spec and tasks; publishes GitHub Releases
  that exercise the REQ-002 leg in production.
- CI: runs both new suites, and the existing loop suites via the new
  release.yml job, on the matrices described in infra-spec.md.

## Main Workflows

1. T-001: add the loop-gate prerequisite to `scripts/bump-version.sh`;
   author `tests/bump-version-gate.tests.sh`/`.ps1`; wire into
   `run-all.sh`/`.ps1` and `test.yml`; CREATE the single `CHANGELOG.md`
   `## Unreleased` entry citing #148 (describing the T-001 leg) and the
   REQ-003 doc surfaces this leg touches
   (`docs/contributor/release-runbook.md` bump-version section).
2. T-002: add the required loop-gate job to
   `.github/workflows/release.yml`; author
   `tests/release-loop-gate.tests.sh`/`.ps1`; wire into `run-all.sh`/`.ps1`
   and `test.yml`; APPEND the T-002 leg's lines to the SAME #148
   `CHANGELOG.md` entry T-001 created, and extend the REQ-003 doc surfaces
   this leg touches (release-runbook release.yml section; `README.md`/
   `docs/troubleshooting.md` where applicable).
3. Verification: each task lands with `validate-repository` and the
   skill-reference count sync green; the quality gate evaluates each task
   with the standard evidence chain. The net REQ-003 end-state (one #148
   entry covering both legs; the full runbook) is asserted by AC-011/AC-012
   after T-002 lands.

## Edge Cases

- CI-resilience (INV-017): both new `.sh` suites must meet the same
  four-constraint bar the loop suites themselves already meet — never
  expand a possibly-empty bash array under `set -u`; normalize every new
  mktemp fixture root with `pwd -P` immediately after creation
  (`loop-consistency.tests.sh:44`, `loop-inventory.tests.sh:43`
  convention); pipe any jq output through `tr -d '\r'` unconditionally if
  jq is ever consumed (neither new suite consumes jq — non-use declaration
  is the compliance, mirroring epic-159-pillar-a2's AC-018 pattern); gate
  any real-validator-driving leg through a capability probe rather than
  assuming availability (neither new suite drives the real validator).
- Red-suite `bump-version.sh` behavior: whenever either loop suite exits
  non-zero, `CHANGELOG.md` and every plugin/marketplace manifest
  `scripts/bump-version.sh` would otherwise touch must be byte-for-byte
  unchanged after the run — not merely "the script exited 1" but zero file
  mutation, asserted via `git status --porcelain` on the fixture (AC-002,
  AC-003).
- Weakened-gate threat on the `release.yml` leg: a future edit could add
  `continue-on-error: true` to the loop-gate job's steps, or `if:
  always()`/`if: success() || failure()` to the build job, silently
  letting the release proceed regardless of loop-suite outcome. AC-008/
  AC-009 make this a locked, reviewable assertion rather than an unstated
  expectation.
- `release.yml`'s trigger surface (`release.yml:10-13`) is unchanged by
  this feature; a release published from a commit that never ran
  `test.yml` (e.g., a tag pushed directly, or a `workflow_dispatch` run
  against an older ref) still gets the loop-gate job's own, independent
  execution — this is precisely why OQ-001 resolved to both legs rather
  than relying on `test.yml` alone.
- Global-Constraint shared files: `tests/run-all.sh`/`.ps1` and
  `.github/workflows/test.yml` are each edited by both T-001 and T-002
  (own registration lines only). `CHANGELOG.md`'s `## Unreleased` #148
  entry is CREATED by T-001 (its leg) and APPENDED to by T-002 (its leg) —
  a single shared entry, never two parallel entries, matching Main
  Workflows items 1-2. All of these are serialized by T-002's Blocker on
  T-001; see design.md's Global Constraints section for the serialization
  convention.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: release path vs. test-suite fixtures | fixture-repository copies (tar-based, mktemp-scoped) never overwrite the real repository; the real `scripts/bump-version.sh`, `README.md`, `CHANGELOG.md`, and plugin manifests are never mutated by any suite in this feature | synthetic fixture copies only | none identified |
| B2: weakened-gate / bypass threat | no environment-variable or CLI-flag bypass exists in the CLI leg (AC-004); no `continue-on-error`/`if: always()` escape hatch exists in the CI leg (AC-008) | internal source only | none identified |
| B3: fixture world vs. real repository state | mktemp isolation; fixture roots normalized with `pwd -P`; real release surfaces read only to build the fixture copy, never written in place | internal source only | none identified |
| B4: GitHub release path | the loop-gate job in `release.yml` structurally precedes (via `needs:`) every artifact-producing step (tarball, SBOM, checksums, sigstore attestation, upload); no network call is added by either new suite | internal source only | none identified |

Details: [Security specification](security-spec.md#trust-boundaries).

## Assumptions

- Both suites remain fail-closed on their own terms (`set -euo pipefail` /
  equivalent, non-zero exit on any FAIL) as observed at investigation time
  (INV-003, INV-004); this feature consumes their exit code, it does not
  change their internal pass/fail logic.
- `_PROTECTED_GATE_SUFFIXES` (`sdd-hook-guard.py:886-927`) remains as
  observed; neither `scripts/bump-version.sh` nor
  `.github/workflows/release.yml` is added to it during this feature's
  lifetime.
- `tests/workflow-state-ci-integration.tests.sh`'s text-marker technique
  (`Path.read_text` + substring/index checks) remains a valid, unmodified
  precedent for the new `release-loop-gate` suite to follow.
- `specs/epic-159-pillar-a/requirements.md:164-173` (REQ-006)'s existing
  rule — any release version bump goes exclusively through
  `scripts/bump-version.sh` — remains in force.

## Open Questions

- OQ-001 — RESOLVED: both legs (CLI prerequisite + required CI job),
  matching the issue's own Done condition wording (investigation.md
  OQ-001).
- OQ-002 — RESOLVED: the 300s budget is viable; `test.yml` already runs
  both suites on all 3 OSes well under budget, and `release.yml` runs
  `ubuntu-latest` only (investigation.md OQ-002).
- OQ-003 — RESOLVED: no `bump-version.ps1` twin; recorded degradation,
  Windows/CI covered by the REQ-002 leg (investigation.md OQ-003; REQ-004
  above).
- OQ-004 — RESOLVED: documentation home is
  `docs/contributor/release-runbook.md` (new) + `README.md` release note +
  `CHANGELOG.md` `## Unreleased` entry (investigation.md OQ-004; REQ-003
  above).
- OQ-005 — RESOLVED: out of scope; suites self-manage their own runtime
  budgets (investigation.md OQ-005).
- OQ-006 — RESOLVED: non-goal; suite timings are not emitted into release
  notes or the attestation (investigation.md OQ-006).
- OQ-007 — RESOLVED: no bypass override; fail-closed with no exception,
  matching the repository's guard philosophy (investigation.md OQ-007;
  AC-004 above).

## Risks

- High: a future edit could add a bypass to either leg (an env-var skip in
  `bump-version.sh`, or `continue-on-error`/`if: always()` in
  `release.yml`) without anyone noticing. Mitigation: AC-004 and
  AC-008/AC-009 make both the absence of a bypass and the presence of the
  `needs:` dependency locked, reviewable assertions rather than unstated
  expectations.
- Medium: the two new suites' shared registration surfaces
  (`tests/run-all.sh`/`.ps1`, `test.yml`, `CHANGELOG.md`'s `## Unreleased`
  section) could collide if T-001 and T-002 land in the same commit.
  Mitigation: design.md's Global Constraints section (serialized,
  per-task commits, epic-159-pillar-a2 precedent).
- Medium: the CLI leg's fixture-copy technique (tar-copy + git-init,
  extending `tests/repository-release-validation.tests.sh`'s precedent)
  must correctly resolve `scripts/bump-version.sh`'s own `$ROOT`-relative
  path logic (`scripts/bump-version.sh:18`) against the fixture, not the
  real repository, or the test would silently exercise the wrong script.
  Mitigation: design.md's Test Strategy documents the exact mechanism;
  AC-001's happy-path assertion is the first canary that would fail if
  resolution were wrong.
- Low: scope creep into the wider risk-adaptive-layer release-gating work
  (INV-015). Mitigation: Non-goals explicitly excludes it; this feature is
  the loop-suite subset only.
