# Windows CI optimization verification

## Scope

The Windows `version-gates` job still runs every Bash and PowerShell suite. No
test case was removed or weakened. The Windows PowerShell suites are grouped
by fixture scope and run in four independent child processes; suites within a
lane remain sequential so their existing fixture assumptions are unchanged.
On Windows, the original PowerShell steps are skipped only because the
dispatcher runs the same scripts; POSIX jobs retain the original steps.

## Evidence

- Baseline Windows installers job: about 10m32s (`35575859481`).
- The existing installer-lane split is green and caps each Windows lane at
  about 4m02s (`35618427088`).
- The new dispatcher was run locally with PowerShell 7.6.2 using
  `-Lane all`; governance, capability, ownership, and lite all passed and the
  process exited 0.
- `tests/human-copy-mirror-freshness.tests.sh`: 6 passed, 0 failed, 21
  pending informational.
- `git diff --check`: passed.

## Protected-file note

The live `.github/workflows/test.yml` is protected by the repository gate. The
candidate workflow is therefore staged at
`specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml` and
its digest is updated in the adjacent `MANIFEST.sha256`. A human must apply
that staged payload with the feature-scoped runner before the new Windows CI
dispatcher can run on GitHub.
