# Other PR / unPR execution — 2026-09-09

## Delivered action

Created draft https://github.com/aharada54914/sdd-forge/pull/402 from the
already-pushed `auto/improve-20260817` branch at
`f6e7427c9648085ca86a0d0835fa28df8e5ff300`. No code, protected files, approval
fields, history, or branch tips were changed. No merge was performed.

Read the complete original commit, both audit issue bodies and the previous
duplicate comparison. The branch contributes one commit, four files (+44/-2)
against main; `git diff --check` succeeded. GitHub reported MERGEABLE and Draft.
The selected older variant has stronger exit-code assertions than August31;
neither is represented as fully verified. The full submission and outstanding
gates are in `issue295-draft-pr-body-20260909.md`.

Actions run 34285985088 started from the PR event. At first observation,
checks were queued/running; no final PASS was claimed. This successful local
PR creation does not establish that the weekly workflow PAT was repaired.
Issue comments link #295 and #380 to #402 and explicitly retain their other
open findings. Neither issue was closed.

## Other current PRs

All were inspected by exact current head before publication:

| PR | Head | Observation |
|---|---|---|
| 245 | 54b1ff247081971e0560cf20d45f4369e01b5c0d | Conflicting; no Actions validation |
| 371 | 9e39c396f4ca8f9abe3c9aabb090868ada17b53f | Windows and MCP failures |
| 381 | 3971c93a5705dc15f86ba56cc62118613e4b19db | POSIX, platform, routing and version failures |
| 390 | ade304948907b5bdc94e9975f80528a0dfbb9e14 | Windows test failure |
| 394 | 423edd3b0f9f6710e1de00183e4040fdd8de8ef3 | Windows test failure |
| 400 | 8fa3eb8561d6f59b692ec574900f87e181145928 | Actions green; amended design/formal review still unresolved |
| 401 | 135b147926689bd3adc8c834932a9b82b9f5a607 | Three platform test failures |

These seven had no running checks at that observation. #402 subsequently
introduced a real active CI run. Do not describe all CI as idle after that.
No failing or unchanged historical job was rerun.

## Duplicate-PR protection

GitHub all-state head lookups found existing merged PRs for:

- `codex/ci-auto-discovery-wfi-027-028-034`: #382.
- `wfi/048-guard-patch-target-extraction`: #355.
- `feature/epic-195-a7-compatibility`: #247.
- `feature/epic-196-a8-integration`: #248.

These are not automatically unPR work. A merged PR alone does not prove all
current branch commits reached main. No duplicate PR or branch deletion was
performed. Preserve the already-recorded nesting / unique-commit findings.

## Next action

Inspect #402 run results by immutable SHA, retain actual failures, then perform
the applicable approved formal repair/review path before ready or merge.
The host-denial contract recovery remains necessary for blocked formal entries
in the other lanes; do not silently skip it. #381's RT001 scope is already
approved; do not ask for the same approval again. #390/#394 still require the
formally verified Windows fixture repair, not a timeout relaxation.
