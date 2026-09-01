# T-011 scoped regression results

## Required registration TDD

- Bash AC-015 RED: exit 1, exactly six missing workflow suite pairs.
- PowerShell AC-015 RED: exit 1, exactly the same six missing pairs.
- Bash AC-015 GREEN: exit 0, all eleven aggregate and staged-workflow pairs
  present exactly once; both T-012 paths absent.
- PowerShell AC-015 GREEN: exit 0 with the same result. PowerShell was available
  at `/opt/homebrew/bin/pwsh`; there is no runtime gap for T-011's required
  registration assertion.

## Current focused safety check

`promote-golden-baseline-ci-guard` passed against both the live workflow and
the staged candidate in Bash and PowerShell: 3 passed, 0 failed per runtime.
The staged manifest verifies and the candidate parses as YAML.

## Assembled-suite evidence and local rerun gap

The dependency tasks' committed verification records supply passing Bash and
PowerShell evidence for the assembled assertions (enumerated in
`ac-028-legend-confirmation.md`). A fresh long-form aggregate rerun was not
used as T-011's GREEN because it is not the task's authored assertion and the
local macOS host exposed unrelated runner behavior:

- `bash tests/install.tests.sh` exits 141 before emitting suite assertions at
  its `git archive | /usr/bin/bsdtar` fixture-copy pipeline (`git=141`,
  `tar=0` under `pipefail`). This predates and is byte-disjoint from T-011's
  workflow-only implementation.
- A diagnostic retry that drained BSD tar's trailing input proceeded further
  but exposed unrelated installer fake-CLI expectation failures; it was
  stopped rather than misreported as GREEN.
- `uninstall.tests.sh` likewise emitted pre-existing fake-CLI expectation
  failures during a diagnostic run and was stopped after the failure was
  established.
- Other attempted long-form fixture suites were stopped after exceeding a
  reasonable local runtime without completing; no pass or failure is claimed
  for those interrupted invocations.

These host diagnostics do not alter the genuine dual-runtime AC-015 RED/GREEN,
the current dual-runtime AC-040 safety pass, or the dependency tasks' persisted
dual-runtime assertion evidence.
