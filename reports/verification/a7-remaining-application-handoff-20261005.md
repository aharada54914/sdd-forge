# A7 remaining protected application

The user's five-target v2 application is not repeated. The remaining caller repair has a separate pinned three-target batch:

`rtk proxy python3 -B /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/verification/a7-historical-reservation-human-20261005.py --apply-human`

The coordinator reran the default dry run on 2026-10-05: exit 0, `DRY_RUN_OK; no files changed`. Its proposed hashes are:

- spec-review-precheck.sh: `230feaa639b5931447f88d3e720d6d52fed15c697de7e19e5bbc6efdb277d8a4`
- spec-review-precheck.ps1: `9eb8111754b4a3b355da4d465eb53b369c9f2ef09e4d0d246bf2da1478e95ab8`
- spec-review-loop/SKILL.md: `107dd754c3514a34fcba28a2b2bf18d35d004e1dd0a92599956906a9315b45e4`

This removes ordinary current-input launch validation from historical reservations only; historical pinned-chain validation remains in the recovery helper. New-review launch validation is unchanged. Do not overwrite old reviewer outputs or replay reservations.

After application: verify readbacks, run integrated Bash/PowerShell recovery regressions, run the fresh attempt-14 precheck, then conduct independent review with new identities. Helper fixture success is not proof of integrated precheck success or independent review. CI, merge and A7 completion remain unverified. No Git operation or review-state transition was performed by this handoff.
