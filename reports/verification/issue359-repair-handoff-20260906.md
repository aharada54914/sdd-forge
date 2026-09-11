# Issue #359 approved repair handoff

Ticket: docs/review-tickets/RT-20260906-002.yml
Feature/task: cross-model-verification / T-005
Worktree: /tmp/issue359-repair.foCPkp/worktree
Branch: codex/issue359-collection-fixtures
Base: 4366438f3b243210a4ece5a17f873ca2d920600a

The base was checked against remote main during this turn (777f89). Worktree
creation succeeded (ae2936). The bounded implementation was delegated to
`/root/issue359_fixture_fix`; no implementation or test completion is claimed
by this handoff. Last observed worktree status was clean (5fe99b), and the
agent remained running. Do not restart a still-running agent merely because
its progress report has not arrived.

Scope is the approved PowerShell fixture EOF consumption and CL-012c
expectation correction only. Production runners, timeouts, historical FAILs,
and other assertions remain unchanged. Stop on protected-file denial; do not
try a different path/tool to bypass it.

## Verification gap discovered before implementation

Primary current-base registration inspection (1bd2de):

- `tests/run-all.sh:90` registers the Bash collection-layer suite.
- Both run-panelist-effort suites have direct CI steps at
  `.github/workflows/test.yml:441-450`.
- Neither `.github/workflows/test.yml` nor `tests/run-all.ps1` registers
  `collection-layer.tests.ps1`.

Consequently, existing CI success alone cannot prove the ticket's Windows
collection-layer fixture requirement. Matching-host execution must be
recorded before integration; adding CI wiring is not silently included in
this single-test-file repair. The worker has been told to retain the
existing explicit CL-018 Windows skip and not misreport it as exercised.

PR #381 T-006 is separately paused on the requested generator-candidate
scope extension; its unsafe whole-bundle apply is not a prerequisite for
working on this independent approved ticket.

## Fresh exact-worktree validation (supersedes initial assignment state)

Independent tester `/root/pr400_merged_mcp_tests` verified the target cwd,
base HEAD above, and candidate SHA-256
`416ab9cfd98b9390e37c60bf246aff0ea0d89014863739c692a1581e70307b6a`
before executing `pwsh -NoProfile -File tests/collection-layer.tests.ps1`.
It reported exit 0, 47 passed and 0 failed. Primary inspected the persisted
log tail (4ca4bf) and independently matched source and log hashes (ccbe00).
Log: `/tmp/issue359-exact-candidate-ps-fresh.log`, SHA-256
`3852b330c2d622b5552699095bcef15d91113ed1356df48edb64c2b4a9023e98`.
This is local macOS PowerShell evidence, not native Windows evidence or a
formal quality-gate verdict. Earlier worker results from the root PR400 cwd
cannot be attributed to this candidate and are not used here.

Native Windows execution and the separately identified Bash CL-021b
output-consumption repair remain outstanding. No assertions or production
runners were changed in this verification. T-006's generator scope extension
has since been approved and repaired; its remaining hold is protected-mirror
application, not that earlier scope request. No ticket was resolved, task
marked Done, branch pushed or issue closed by this verification.
