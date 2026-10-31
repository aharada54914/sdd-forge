# Infrastructure Specification: sdd-domain-concept-contract

N/A — no change to CI workflows, release surfaces, install/uninstall
scripts, or runtime environments: the deliverables are three additive
files (a schema, a validator script pair, a test suite) with no
registration changes.

## Execution Environments

- Validator scripts: any host with bash + python3 (`.sh`) or
  Windows PowerShell 5.1+/pwsh (`.ps1`). Read-only, no network, no
  temp-file persistence beyond mktemp scope.
- Test suite: Pester, invoked directly (the existing
  `tests/sdd-domain/*.Tests.ps1` suites are not referenced by
  `tests/run-all.{sh,ps1}` nor `.github/workflows/test.yml` — INV-007).
  This feature follows that convention and adds no CI registration
  (OQ-002; changing the registration policy for all 12 suites is a
  separate WFI if desired).

## CI / Release Impact

- `.github/workflows/test.yml`: unchanged.
- `.github/workflows/release.yml` and `scripts/bump-version.sh`:
  unchanged — no plugin manifest, marketplace, skill count, or version
  surface is touched (no new skill is added in Phase 0; the validator is
  a script inside the existing sdd-domain plugin directory, which is not
  a release-gated surface by itself).
- `tests/validate-repository.ps1` expectations: unchanged — Phase 0 adds
  no skill, agent, or manifest entry. (Phase 1's new `concept-test`
  skill WILL change these expectations; that cost is scoped to Phase 1,
  per the plan review's P-11.)

## Rollback

All three deliverables are additive files with no consumer wired in
Phase 0 (INV-004 consumers untouched). Rollback = delete the three files;
no data, state, or registration to unwind.
