# A8 T-004 owner continuity and regression — 2026-10-05

Non-frozen preparatory evidence only. Not a fresh implementation report,
independent quality verdict, native-host observation, or task transition.

Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`.
HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`.
Tracked dirty state: 11 files, 500 insertions / 63 deletions at observation.
The approved eight-file recovery remains uncommitted; this is not a claim about
PR #513's head or an integrated candidate checkout. No candidate was substituted.

## Current observed checks

Commands ran through `rtk proxy`, `login=false`, on macOS. The tester skill was
used to keep synthetic verification separate from native and formal evidence.

| Check | Result |
| --- | --- |
| Recompute all eight after hashes in `a8-t004-recovery-v2-pins.json` | 8/8 exact matches |
| Canonical T-004 report versus `T-004.pre-recovery-20261004.md` | byte-identical; both SHA-256 `48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f` |
| Recompute canonical report's five exact Outputs path/hash rows | 5/5 exact matches |
| Ordered-line comparison to `git show c886b790:tests/cli-hook-enforcement.ps1` | all 100 baseline lines preserved in order |
| `pwsh -NoProfile -File tests/cli-hook-enforcement.ps1` | exit 0; 17 passed / 0 failed; TEST-017 13 prior checks retained; all three TEST-012 synthetic cases pass |
| `sh plugins/sdd-quality-loop/scripts/check-task-state.sh specs/epic-196-a8-integration/tasks.md reports/quality-gate reports/implementation .` | exit 0; 8 tasks |
| `sh plugins/sdd-quality-loop/scripts/check-traceability.sh specs/epic-196-a8-integration/verification/T-004/traceability.json . require-evidence` | exit 0; 1 link |
| `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh` | exit 0; workflow-state: ok; existing A8/A7 amendment-record-growth warnings retained |
| `sh plugins/sdd-quality-loop/scripts/check-contract.sh specs/epic-196-a8-integration/verification/T-004.contract.json .` | exit 1; only required `cross-model-verification` remains passes=false |
| `git diff --check` | exit 0; empty output |

Suite SHA-256: `343aa50f12d790619dc5d636831d6f1c7d1559745b9ca289ad67fb28564a3bec`.
Baseline SHA-256: `22f984afdf51698d575b375f6654a98310149f7ba5caba1a81af5ff0d9d17f40`.
Task plan SHA-256: `8c17b0f6b2fa299d23ce6e892a8e80a841ac4ab68d613c84d6c36fe09bbcde66`.
Canonical identity ledger before/after checks was unchanged:
`722081ffaa0b21d5cf63abbb0eff4aa85d902f634d378239896da9e260b67143`.

No test invokes a new Claude/Codex/Copilot session: the suite detects binaries on
PATH and invokes their guard command forms directly using disposable fixtures.
This is not CLI startup diagnosis or installed-host activation proof. No quota
was consumed through model calls, no identity was reserved and no canary was
performed by a formal evaluator. This report is the only file added by this run.

## Remaining recovery boundary

The four mandatory recovery suites and isolated reserve fixture already have
passing captures in `recovery-validation-20261004/readiness.md`; their eight
source/test pins still match. They were not redundantly rerun here.
The shared-session observation in `recovery-fresh-20261004/observations.md` is
still not a fresh distinct host-session implementation report. Host startup
diagnosis belongs to the separate active owner and was not duplicated.

The current consumer predicates (`validate-review-context-set.sh:422` and
`.ps1:495`) still require `handoffs/<directory>/manifest.json`. For the genuinely
new recovery run, allocate its own new handoff directory with this basename;
do not overwrite a prior manifest, import the separate Issue 423 repair candidate,
or bind a differently named manifest without an approved consumer contract change.
The new report must initially be noncanonical, use observed fresh identities,
pin the old archive and exact admitted inputs, and receive independent hash/report
comparison before promotion. Scratch provenance belongs in the report, not an
extra task-input-manifest schema key.

Current task/workflow validity does not adopt the incomplete or non-adopted task
review attempt-5 output recorded in `a8-t004-task-rereview-transport-audit-20261004.md`.
Formal primary evaluation, cross-model completion, evidence bundle, final
integration-head CI and Done remain outstanding. T-007 registration wording and
T-008 real five-cell signatures/native proof remain separate; this 17/0 synthetic
result discharges neither. No task, ledger, historical evidence, source, protected
file, approval or git history was modified by these checks.
