# Acceptance Tests: epic-159-pillar-b

TEST IDs (TEST-001..TEST-014) are namespaced to this feature
(`specs/epic-159-pillar-b/`) and do not collide with any other spec
folder's own TEST numbering (different suite files, different CI step
names — design.md Test Strategy).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | integration (fixture-driven, real script) | `tests/bump-version-gate.tests.sh`/`.ps1`: fixture-repo copy (tar-copy + local `git init` baseline) whose loop suites are left passing/stubbed-passing and whose `CHANGELOG.md` carries a synthetic `## v<test-version>` heading; `bash "$fixture_root/scripts/bump-version.sh" <test-version>` exits 0 and the fixture's plugin manifests/`README.md`/`tests/validate-repository.ps1` contain the new version string | Planned |
| AC-002 | REQ-001 | TEST-002 | negative-branch (fixture-driven) | same suite: `tests/loop-consistency.tests.sh` inside the fixture replaced by a two-line non-zero-exit stub; asserts `scripts/bump-version.sh` exits 1 and `git -C "$fixture_root" status --porcelain` is empty (zero mutation) | Planned |
| AC-003 | REQ-001 | TEST-003 | negative-branch (fixture-driven, independent leg) | same suite: `tests/loop-inventory.tests.sh` inside the fixture replaced by a non-zero-exit stub (loop-consistency left passing); same fail-closed, zero-mutation assertion, proving both suites gate independently | Planned |
| AC-004 | REQ-001 | TEST-004 | construction proof (grep self-check) | same suite: a grep-based self-check over the real `scripts/bump-version.sh` source asserts no environment-variable/CLI-flag conditional wraps the loop-gate invocation (OQ-007: no bypass) | Planned |
| AC-005 | REQ-001 | TEST-005 | structural ordering assertion | same suite: a line-number comparison in the real `scripts/bump-version.sh` source asserts the loop-gate invocation's line number is less than the first `sed -i` mutation call's line number | Planned |
| AC-006 | REQ-001 | TEST-006 | CI resilience + self-registration conformance | same suite: asserts its own fixture-root normalization uses `pwd -P`; no possibly-empty bash array is expanded under `set -u`; no jq consumption; no real-validator invocation; and a grep-based self-check confirms its own basename appears in `tests/run-all.sh`/`.ps1` and `.github/workflows/test.yml` (mirrors `tests/second-approval-mask.tests.sh:285-289`) | Planned |
| AC-007 | REQ-002 | TEST-007 | configuration conformance (text-marker) | `tests/release-loop-gate.tests.sh`/`.ps1`: text-marker check over the real `.github/workflows/release.yml` asserts both `tests/loop-consistency.tests.sh` and `tests/loop-inventory.tests.sh` invocation strings appear inside the new `loop-gate:` job's slice of the workflow text | Planned |
| AC-008 | REQ-002 | TEST-008 | configuration conformance + weakened-gate negative scan | same suite: asserts a `needs: loop-gate` (or equivalent list form) substring appears inside the build job's (`release:`) text slice, and that neither that slice nor the `loop-gate:` job's slice contains `continue-on-error: true` or `if: always()`/`if: success() \|\| failure()` | Planned |
| AC-009 | REQ-002 | TEST-009 | negative-branch canary (structural) | same suite: a mktemp fixture copy of `release.yml` with the `needs:` line textually stripped is re-run through the same marker-check function; asserts the function now reports non-compliance, proving TEST-008's assertion is not vacuously true | Planned |
| AC-010 | REQ-002 | TEST-010 | configuration conformance + self-registration | same suite: asserts the `loop-gate:` job's slice contains `runs-on: ubuntu-latest` and no `strategy:`/`matrix:` key; and a grep-based self-check confirms its own basename appears in `tests/run-all.sh`/`.ps1` and `.github/workflows/test.yml` | Planned |
| AC-011 | REQ-003 | TEST-011 | document conformance | `CHANGELOG.md`'s `## Unreleased` section contains an entry citing `#148`; existing `validate-repository`/skill-reference count sync CI steps (unchanged by this feature) stay green; review-time check that no version-literal edit exists outside a `scripts/bump-version.sh` invocation | Planned |
| AC-012 | REQ-003 | TEST-012 | document conformance | `docs/contributor/release-runbook.md` (new file) exists and documents both loop-gate legs; `README.md` and `docs/troubleshooting.md` reviewed for release-procedure mentions requiring the same-PR update | Planned |
| AC-013 | REQ-004 | TEST-013 | hygiene / non-existence assertion | `scripts/bump-version.ps1` does not exist (`test -e` / `Test-Path` negative assertion); no twin-parity or hygiene suite's target list references it | Planned |
| AC-014 | REQ-004 | TEST-014 | document conformance | `docs/contributor/release-runbook.md` contains the REQ-004 degradation-note markers: the CLI-side loop-gate prerequisite is bash-only, and the `release.yml` `loop-gate` job (REQ-002) is the equivalent guarantee on any host that triggers a release | Planned |

Notes:

- Every suite this feature adds is red-demonstrable at the granularity that
  applies to it: TEST-001/TEST-002/TEST-003 form a positive/negative triple
  (green path plus two independently-stubbed red paths, proving both loop
  suites gate on their own), and TEST-008/TEST-009 form a positive/negative
  pair (the compliant real file plus a textually-mutated, non-compliant
  fixture copy) — mirroring epic-159-pillar-a2's AC-008/AC-009 and
  AC-001/AC-002 pairing conventions.
- `tests/gates.tests.sh`, `tests/eval.tests.sh`, `tests/guard-parity.tests.sh`,
  and `tests/constant-parity.tests.sh` are enforcement-chain protected
  files; nothing in this feature touches them.
- Fixtures are synthetic and mktemp-scoped in every case: TEST-001..006
  operate on a tar-copied, locally `git init`-ed fixture-repository copy
  that is never the real repository; TEST-009 operates on a small mktemp
  copy of `release.yml` alone. No test writes a real repo path, invokes
  `gh`, or emits an approval string (security-spec.md).
- This is release-gate CLI/CI wiring with no user-facing entry point; the
  UI integration checklist is not applicable.
- `tests/bump-version-gate.tests.ps1` shells out to `bash` to drive the
  bash-only real `scripts/bump-version.sh` (REQ-004, OQ-003); if `bash` is
  not found on `PATH`, TEST-001..006 degrade to a named SKIP with reason,
  mirroring `tests/hitl-wfi-terminal.tests.ps1:101-107`'s established
  pattern, rather than failing silently.
