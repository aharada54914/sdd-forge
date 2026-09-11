# RT-20260908-005: mixed-failure helper correction

Date: 2026-09-08
Scope: two golden-test files only; user-approved bounded fix.
State: implementation and local validation successful; ticket remains open.

## Reproduction and correction

The helper previously collected orphaned-commit causes without rejecting other
bundle failure details. Four new controls cover same/separate bundles crossed
with environment-first/content-first ordering. Before the helper change, all
four failed with a nonempty causes array instead of the required empty array;
the five existing controls passed. Compilation succeeded before this RED run.

The correction ignores recognized bundle summaries, collects only the existing
environment-dependent detail shape, and returns an empty array immediately for
any other failure detail. Thus a content failure anywhere retains the strict
comparison. Product parsers, gate scripts, snapshots and CI requirements are
unchanged. Existing controls were retained.

## Actual commands and evidence

Package directory: `mcp/sdd-forge-mcp`. All runs are local macOS, not native
Windows or exact PR-head CI. Full console logs are in the paths below.

| Command | Result | Log |
|---|---|---|
| `rtk proxy npm run pretest` before RED | exit 0 | console |
| `rtk proxy bash -o pipefail -c 'node --test dist-test/tests/golden/environment-dependence.test.js 2>&1 \| tee /tmp/rt005-red-20260908.log'` | exit 1; 5 pass, 4 expected failures | `/tmp/rt005-red-20260908.log` |
| `rtk proxy npm run pretest` after fix | exit 0 | console |
| `rtk proxy bash -o pipefail -c 'node --test dist-test/tests/golden/task-state-golden.test.js dist-test/tests/golden/environment-dependence.test.js 2>&1 \| tee /tmp/rt005-green-20260908.log'` | exit 0; 11 pass, 0 fail, 0 skip | `/tmp/rt005-green-20260908.log` |
| `rtk proxy npm run typecheck` | exit 0 | console |
| `rtk proxy bash -o pipefail -c 'npm test 2>&1 \| tee /tmp/rt005-full-20260908.log'` | exit 0; 251 pass, 0 fail, 0 skip | `/tmp/rt005-full-20260908.log` |
| `rtk proxy git diff --check` (repository root) | exit 0 | console |

SHA-256 at verification time:

| Artifact | SHA-256 |
|---|---|
| mcp/sdd-forge-mcp/tests/golden/shell-runner.ts | a5c1f8a86bb5731499b9ad657631aa7d56fff962f6125db6db252b13aabdb814 |
| mcp/sdd-forge-mcp/tests/golden/environment-dependence.test.ts | 233032beb6496589799c8a9cf3d925db3d29d427fb8e57a7e6f5e8abad5feb36 |
| /tmp/rt005-red-20260908.log | da4291f9543151b7940744a746574296b0e1b4ffcc6491acb017c4e19f9b796c |
| /tmp/rt005-green-20260908.log | 3350ca42a06fd36547b70adacd082653cd022f1d5fd44f4ed87f8413dd2411e3 |
| /tmp/rt005-full-20260908.log | 2b0438ae0706318cf322557baeefbf85b58661d4dea37e7b393ed65961504bb2 |

## Independent review

Fresh subagent `/root/rt005_independent_review` performed a read-only ordinary
code review of the two-file diff against the ticket and original reproduction.
Result: no findings / LGTM. It confirmed rejection of all non-environment
detail failures, preservation of orphan-only diagnostics, and all four new
combinations. It did not rerun tests or reserve gate identities. This review
is explicitly NOT a formal quality-gate evaluator verdict.

## Formal gate and integration remain pending

`specs/sdd-forge-mcp/tasks.md:52–83` identifies the relevant original T-002,
currently Approved / Done / high risk. The installed quality-gate skill's
Process step 1 rejects targets not at Implementation Complete. Its step 8
also requires fresh hash-declared inputs and a reserved evaluator identity.
The historical `verification/qg/invocation-T-002.json` has only specification,
calibration and implementation-report inputs, not these changed test files.
The old implementation report has no hash-bearing Outputs table, and the old
quality report has no Post-Fix Artifacts declaration. Do not replay that
manifest, retrofit old evidence, or treat the ordinary review as the gate.

Read-only cycle-limit check:
`rtk proxy bash plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh T-002 sdd-forge-mcp`
returned `continue`, exit 0. A cycle-limit block was NOT observed.

Next: reconcile the post-Done review-ticket lifecycle, prepare a new post-fix
declaration and fresh evaluator manifest through the sanctioned gate flow,
then run the formal gate. Keep this ticket open until it passes. Integrate the
fix into the relevant PR rather than restoring old test sources; required
PR-head CI must pass before merge. No commit, push, merge, task-state change,
old-report change, or ticket resolution was performed in this correction.

## Continuation: lifecycle preflight (2026-09-08)

This section supersedes the earlier point-in-time statement about task state,
not the historical test results. Following the repository
`plugins/sdd-quality-loop/skills/fix-by-review-ticket/SKILL.md` Process step 6,
T-002 was returned from Done to Implementation Complete; approval and task
body were preserved. No new Done verdict has been issued.

- Task-state preflight passed, exit 0, 11 tasks:
  `/tmp/rt005-task-preflight-20260908.log`.
- Global workflow-state preflight completed with exit 1:
  `/tmp/rt005-workflow-preflight-20260908.log`.
- The target failure is `sdd-forge-mcp: legacy-state: task lifecycle is
  broader than the migration record`. A separate existing failure reports
  `epic-136-phase4-docs: stage-provenance: impl integrated verdict is not a
  valid PASS`; it is not attributed to the helper correction.

The target cause is explicit: `specs/workflow-state-registry.json:183`
permits only Done for this legacy feature, and
`contracts/workflow-state-registry.schema.json:418` pins that same list
inside a const entry. `check-workflow-state.sh:1318` rejects the reopened
state. `specs/workflow-state-integrity/requirements.md:45` (REQ-005)
requires bounded legacy migration rather than broader implicit exceptions.

Neither registry nor schema was changed. Adding Implementation Complete to
the feature-wide list would also admit other tasks, so it is not an adequate
task-scoped recovery design. A separately approved, task-specific reopening
contract and its negative tests are needed before changing this behavior.
The two-file RT005 authorization does not cover that contract change; Process
step 2 of fix-by-review-ticket requires stopping an out-of-ticket change.
Formal evaluator launch, ticket resolution and integration remain pending.
