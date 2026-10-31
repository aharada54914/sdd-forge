# Investigation: epic-159-pillar-b (issue #148 — ループ一貫性スイートのリリースゲート化)

Source: issue #148 (size S, depends on A3/A4 — both satisfied at main).
Investigated: 2026-07-16, branch feature/epic-159-pillar-b (main = f6b1365).
Method: read-only survey with file:line evidence (sdd-investigator).

## Findings

- INV-001: `scripts/bump-version.sh:38-42` checks only that CHANGELOG.md has a
  `## v<NEW>` heading (fail-closed `set -euo pipefail`, exit 1 with rename
  guidance). No loop-suite invocation exists anywhere in the script.
- INV-002: both loop suites already run in CI on all 3 matrix OSes —
  `.github/workflows/test.yml:71-79` (loop-inventory bash/pwsh) and
  `:91-99` (loop-consistency bash/pwsh).
- INV-003: `tests/loop-consistency.tests.sh:54` requires jq (fail-closed),
  `:431` runtime budget via `LOOP_SUITE_BUDGET_SECONDS`, `:451` emits a
  `N passed, N failed, Ns elapsed` summary line.
- INV-004: `tests/loop-inventory.tests.sh:41` hardcodes
  `LOOP_SUITE_BUDGET_SECONDS=300`, `:55` requires jq, `:378-379` emits the
  summary line and exits non-zero on any FAIL. Both suites write only
  mktemp-scoped fixtures (loop-consistency.tests.sh:56-57,
  loop-inventory.tests.sh:57).
- INV-005: `scripts/bump-version.sh` is NOT in
  `sdd-hook-guard.py:886-927` `_PROTECTED_GATE_SUFFIXES` — agent-editable,
  no human-copy procedure needed.
- INV-006: `.github/workflows/release.yml:30-100` (checkout, tag resolution,
  reproducible tarball, optional release-host-smoke, SBOM, checksums,
  sigstore attestation, upload) contains no loop-suite invocation and no
  `needs:` gate on test results.
- INV-007: `release.yml:10-13` triggers on `release: [published]` and
  `workflow_dispatch` only — no `workflow_run` predicate on test.yml. This
  matches the broader gap already recorded by the risk-adaptive-layer spec
  (see INV-015).
- INV-008: `scripts/` has no `bump-version.ps1` twin (only the one-off
  `rollback-1.5.0.ps1` migration script). The loop suites themselves have
  full .sh/.ps1 pairs.
- INV-009: `CHANGELOG.md:1-3` uses the `## Unreleased` heading convention;
  the rename to `## v<version>` is manual and is what bump-version.sh's
  precondition (INV-001) verifies (v1.9.0 incident prevention).
- INV-010: `specs/epic-159-pillar-a/requirements.md:164-173` (REQ-006)
  establishes that any release version bump goes exclusively through
  `scripts/bump-version.sh`.
- INV-011: all four loop suites are registered in `tests/run-all.sh` and
  test.yml but nothing in release.yml references them.
- INV-012: both suites emit machine-parsable summary lines
  (loop-consistency.tests.sh:451; loop-inventory.tests.sh:378) suitable for
  a release-gate log capture.
- INV-013: the suites already carry the jq-CRLF resilience pattern
  (`tr -d '\r'` at loop-inventory.tests.sh:107, 179).
- INV-014: no document currently states that release requires loop-suite
  green: docs/contributor/self-improvement-measurement-proposal.md mentions
  bump-version.sh only as existing automation;
  docs/superpowers/plans/2026-07-03-v1.8.0-release.md predates the suites.
- INV-015: specs/risk-adaptive-layer/{investigation,design}.md record the
  "release.yml not gated on CI" gap as a security issue at wider scope;
  issue #148 is the narrower loop-suite subset (avoid scope collision:
  #148 must not implement the full risk-adaptive-layer AC-008 gating).
- INV-016: `tests/loop-inventory.tests.sh:183-192, 253-262` prove the
  suite's own validation is live via mktemp-mutation negative self-checks.
- INV-017: both suites use the `pwd -P` repo-root convention
  (loop-consistency.tests.sh:44, loop-inventory.tests.sh:43) — the
  CI-resilience constraints (bash 3.2 empty arrays, pwd -P, jq CRLF,
  validator probe) are the established bar for any NEW .sh suite this
  feature adds.

## Open Questions (resolved by design decisions unless noted)

- OQ-001: gate in bump-version.sh (CLI prerequisite) or release.yml
  (required job)? — DECISION: both legs, matching the issue's own Done
  condition wording: primary = bump-version.sh runs the two suites
  fail-closed before any file mutation; secondary = release.yml gains a
  required loop-gate job that the build job `needs`.
- OQ-002: is the 300s budget viable in CI? — yes: test.yml already runs the
  identical suites on all 3 OSes well under budget (INV-002); release.yml
  runs ubuntu only.
- OQ-003: bump-version.ps1 twin? — DECISION: no twin. bump-version.sh is a
  release-operator CLI (not a test suite); the cross-host clause allows
  explicit recorded degradation. Windows operators rely on the release.yml
  leg. Recorded as a design decision; constant-parity/crlf-parity do not
  bind unpaired scripts/*.sh.
- OQ-004: documentation home? — docs/contributor release/runbook section +
  README release note + CHANGELOG Unreleased entry (per #148 common Done).
- OQ-005: harmonize budgets? — out of scope; suites self-manage (INV-003/004).
- OQ-006: emit suite timings into release notes/attestation? — non-goal.
- OQ-007 (open for spec review): should the new gate leg in bump-version.sh
  be skippable via an explicit env override (e.g. BUMP_SKIP_LOOP_GATE=1 for
  emergency releases)? Default recommendation: NO override — fail-closed
  with no bypass, matching the repository's guard philosophy.

## Estimated decomposition (S)

- T-001: bump-version.sh loop-suite prerequisite (fail-closed, before any
  mutation) + new `tests/bump-version-gate.tests.sh`/`.ps1` twin locking the
  gate behavior against a fixture copy (green path + red path via a stubbed
  failing suite) + run-all/test.yml registration + CHANGELOG + docs.
- T-002: release.yml required loop-gate job (build job `needs` it) +
  workflow-content assertions extension (workflow-state-ci-integration
  precedent) + contributor docs release-prerequisites section.
