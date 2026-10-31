# Current T-004 verification (2026-10-04)

This addendum does not replace historical reports or assert native host activation.

- PR #513 head: `ac97422d6e347f4899a32d16fa9ceddc51b10416`.
- CI run: https://github.com/aharada54914/sdd-forge/actions/runs/37162860278
- CI checked the PR merge ref `131b407`, merging that head into `3a1afcab243fcebb769dc4314599999af4545050`.
- `git diff ac97422d6e347f4899a32d16fa9ceddc51b10416 -- tests/cli-hook-enforcement.ps1`: exit 0, no difference.
- Actual job logs were retrieved with `gh run view --job … --log`, each exit 0.

| OS | Job | Observed result |
|---|---|---|
| Windows | 111319724236 | 14 passed, 0 failed |
| macOS | 111319724305 | 16 passed, 0 failed |
| Ubuntu | 111319724185 | 16 passed, 0 failed |

Every job records TEST-017 continuity and all three TEST-012 cases: Codex enabled, Codex disabled, and Copilot subagent indicator. These are direct-invocation synthetic checks, not session-dispatched live-host proof. Counts also include optional CLI-presence probes and OS-specific POSIX cases; they are not a fixed acceptance threshold.

Current local PowerShell execution also returned exit 0, 17 passed / 0 failed. PR required-checks succeeded, but the PR is BEHIND main. Independent quality verification, required cross-model collection, current-main integration and post-merge validation remain pending. No task status or review verdict is changed by this record.
