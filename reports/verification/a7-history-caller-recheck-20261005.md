# A7 applied caller regression recheck

Scope: verification of the three user-applied caller files, not acceptance of the subsequent failed-final-round recovery candidate.

Worktree: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.

Readback SHA-256 matched the user receipt:

- `plugins/sdd-review-loop/scripts/spec-review-precheck.sh`: `230feaa639b5931447f88d3e720d6d52fed15c697de7e19e5bbc6efdb277d8a4`
- `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1`: `9eb8111754b4a3b355da4d465eb53b369c9f2ef09e4d0d246bf2da1478e95ab8`
- `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md`: `107dd754c3514a34fcba28a2b2bf18d35d004e1dd0a92599956906a9315b45e4`

Commands executed through `rtk proxy` in that worktree:

| Command | Observed result |
|---|---|
| `python3 specs/epic-195-a7-compatibility/verification/spec-review-fresh-chain.fixture.py` | exit 0; 16 Bash and 16 PowerShell cases passed |
| `python3 specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py` | exit 0; 12 Bash and 12 PowerShell cases passed |
| `python3 -B tests/spec-reviewer-hash-capability.tests.py -v` | exit 0; 3 tests passed |
| `git diff --check` | exit 0 |

These 59 local checks do not establish native Windows behavior, successful delivery of a complete first-turn review prompt, a formal reviewer verdict, current-head CI, or merge. Historical attempt 15 round 3 remains preserved; no reservation or review-status change was performed for this recheck.

The separate candidate under `reports/verification/a7-attempt16-recovery-candidate-20261005/` is still being tested. Its results must not be attributed to the applied production callers above.
