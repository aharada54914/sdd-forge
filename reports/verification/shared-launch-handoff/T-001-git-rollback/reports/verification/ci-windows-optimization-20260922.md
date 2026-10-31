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
- The bump-version prerequisite now creates one tracked-file `git archive`
  snapshot and one shared fixture baseline, resets that fixture between cases,
  and stages only each case's changed paths. This removes repeated recursive
  checkout copies and repeated full-index commits without removing or weakening
  any case. Test-003 now uses a passing fixture stub with a filesystem marker
  for the preceding loop-consistency leg and a failing inventory stub that
  consumes that marker; the full loop-consistency suite remains covered by its
  dedicated CI entry, while the gate-order proof no longer reruns it inside a
  fixture. This is the fixture-scoped real/stubbed technique specified by the
  pillar-B design and keeps the zero-mutation assertion.
- The shared-fixture refactor was rerun locally after the latest edit:
  PowerShell reported `13 passed, 0 failed` (11.44s on macOS; TEST-001 is the
  pre-existing BSD-sed skip) and Bash reported `19 passed, 0 failed` (9.20s).
- `tests/human-copy-mirror-freshness.tests.sh`: 6 passed, 0 failed, 21
  pending informational.
- `git diff --check`: passed.

## Protected-file note

The live `.github/workflows/test.yml` is protected by the repository gate. The
staged payload at
`specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml` and
its adjacent `MANIFEST.sha256` were applied by the human-copy runner in commit
`998c280a`; the live and staged workflow digests now match. The subsequent
GitHub run is the authoritative check for the dispatcher.
