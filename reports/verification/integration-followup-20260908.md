# Integration follow-up — 2026-09-08

Diagnostic and test observations only; not a quality-gate verdict or merge approval.
Historical evidence, status fields, and protection rules remain unchanged.

## Human application results

- T-002 reopening applied. Logs in `/tmp/sdd-t002-reopening.itP7VoHz`
  confirm the runtime-matrix test, both registry suites, and both targeted
  workflow checks succeeded. Whole-repository PowerShell workflow validation
  failed. The current `epic-136-phase4-docs` implementation-review
  attempt-4/round-1 integrated verdict is NEEDS_WORK, with four Major findings.
  This is not grounds to change that verdict or exempt the feature.
- PR381 human output reports 30 pass / 0 fail / 0 designed-red and
  `Applied and verified`. The recovery checkout now contains the two mirror
  changes. This does not establish a fresh independent T-006 gate or remote CI.

## PR245 isolated candidate

Repository: `/tmp/sdd-pr245-integration.qSYmqr/repo`.
Main comparison pin: `4366438f3b243210a4ece5a17f873ca2d920600a`.

- `git diff --name-only --diff-filter=U`: exit 0, no unresolved paths.
- `git diff --cached --check`: exit 2. Diagnostic paths cover 81 files;
  byte comparison of each index blob against the pinned main blob found
  80 identical files. CHANGELOG.md differs, but its reported whitespace does
  not appear in the main-relative check below. This comparison does not waive
  the original failed check.
- `git diff --cached --check <main-pin>`: exit 2, identifying new blank lines
  at EOF in three A5 historical artifacts:
  `verification/T-002/step3-mutation-evidence.log:297`,
  `verification/T-008.panelist-input.txt:18396`, and
  `verification/T-009/mutation-captures.log:47`, all under
  `specs/epic-193-a5-capability-resolver/`.
  Do not strip historical evidence or patch-file whitespace indiscriminately.
  All three index blobs are identical to the original PR head
  `54b1ff247081971e0560cf20d45f4369e01b5c0d` (respectively
  `7e8e453f3dfdde4258998e971dc3f6b5d5f20ff4`,
  `2c6000ec22fdcc57c2a81dfe2a3e3a36f5652377`, and
  `c30c847dcebcf6db881e2ed6cadab85ea41c9676`). The integration did not
  introduce these bytes, although they remain new relative to main.

Fresh executions from this candidate, all through `rtk proxy`:

| Command | Result | Tool output reference |
|---|---|---|
| `bash tests/resolver-evidence-schema.tests.sh` | 20 pass, 0 fail; exit 0 | bdc541 |
| `pwsh -NoProfile -File tests/resolver-evidence-schema.tests.ps1` | 20 pass, 0 fail; exit 0 | 68f92a, d44dde |
| `bash tests/resolve-project-context-block.tests.sh` | 398 pass, 0 fail; exit 0 | ce4a5a, ef786a |

PowerShell ran on macOS, not native Windows. The block suite tests staged
human-copy Resolver candidates and explicitly reports zero of three live
Resolver files applied. These results do not prove live installation or
complete integration. Tool references locate conversation output, not canonical
hash-bound gate evidence; the longer block output was truncated by the tool.
Capture complete file-backed output for formal evaluation.

A complete-output run of nine named A5 suites in both Bash and PowerShell
was started in tool session `76421`, with logs in
`/tmp/sdd-pr245-suites.ai9pHFcA`. Its result is pending; do not count the
initial successful schema command as completion of all eighteen executions.

Progress from that same run: schema, block, match, CLI, discovery, lite,
and evidence-validation suites each exited 0 in both launchers (14 executions).
Parity exited 1 in both launchers, each reporting 69 pass / 1 fail. The sole
failure is the assertion at `tests/resolve-project-context-parity-check.py:695`
which compares the live workflow against HEAD. This uncommitted merge includes
main's workflow changes (131 insertions / 1 deletion against the original PR
HEAD). A separate `git diff --quiet <main-pin> -- .github/workflows/test.yml`
exited 0: the file exactly matches pinned main. This identifies the failing
precondition but does not convert either failed execution into a pass. Preserve
the assertion; re-run it on the eventual reviewed, committed integration head.
Both metamorphic executions subsequently exited 0. Session `76421` completed
with exit 1 / `failure_flag=1`: 16 of 18 suite executions succeeded, with only
the two parity executions failing as described above. Full logs remain in the
named log directory. No test assertion, source implementation, commit, or
review verdict was changed to obtain these results.

## Current remote scope

GitHub currently reports seven open PRs: 245, 371, 381, 390, 394, 400, 401
(rechecked with a number-only query). This corrects the earlier conversational
count of eight. PR400's
published head `8fa3eb8561d6f59b692ec574900f87e181145928` has successful checks,
but does not contain current uncommitted amendments. Other listed PRs have
failed or absent required CI. No commit, push, merge, or issue closure occurred.

## Next actions

### PR381 follow-up preflight (after human application)

The recovery checkout still has HEAD
`3971c93a5705dc15f86ba56cc62118613e4b19db` and eleven modified files.
`check-sdd-structure.sh` exited 0. `git diff --check` exited 0.
Running `shasum -a 256 -c
specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256` **from the
repository root** verified all seven live target files, not just the staged
copies. A repeated human apply is therefore not the next action.

The whole-repository `check-workflow-state.sh` finished with exit 1 (session
81827): `wfi-034-scratch-isolation` is an unregistered specification directory.
A7/A8 amendment-growth diagnostics were explicitly tolerated. The earlier
issue311 reconciliation report already identifies this directory as non-spec
patch storage and records an approved relocation, but that relocation is not
in this checkout. Locate/recover its actual diff before inventing a new one.

T-006 remains historically Done, with PASS report
`reports/quality-gate/20260811T111350Z-epic-190-a2-capability-registry-T-006.md`,
while RT-20260809-002 remains open. Neither historical verdict nor the ticket
has been rewritten. A fresh evaluation must follow the authorized post-fix
reopening and post-fix declaration path, including the security-sensitive
cross-model requirement; it cannot be launched as an ordinary Implementation
Complete task while its actual state is Done.

Fresh remote log inspection of run 34017386320, job 101443472805, isolates
all four loop-inventory failures to TEST-004.1 for loop-inventory, loop-driver,
loop-consistency and loop-escalation. The other 67 assertions passed. The
current source still greps the former static run-all source at
`tests/loop-inventory.tests.sh:349`, instead of querying its inventory-backed
`--list` contract. Preserve actual execution/CI registration checks when
repairing these consumers; deleting the assertions is not a remedy. The
historical four-consumer review does not cover these consumers. Its old
`/private/tmp/pr381-verify.7id2mX/worktree` is listed by Git as prunable with
a missing location; do not mistake its historical logs for a live worker.

No evaluator was launched, no status changed, and no protected write was
attempted in this preflight. PR381 remains draft/behind with failing remote
checks on its unchanged published head.

1. Preserve and classify PR245 historical-whitespace findings; resolve their
   disposition through the applicable evidence policy, retaining failed checks.
2. Capture complete remaining A5 suite output and validate the integrated
   review-context changes, mirrors, and provenance before proposing a commit.
3. Finish PR400's approved design/ADR-contract and protection-evidence work;
   obtain genuine fresh review results, not a manual PASS edit.
4. Re-evaluate PR381 T-006 against the human-applied candidate, then integrate
   and require all mandatory remote checks on the exact head to be merged.
