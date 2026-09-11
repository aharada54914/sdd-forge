# Issue #311 branch reconciliation

Date: 2026-09-06
Status: OPEN — source review, not a quality-gate verdict

## Authoritative identity

- Inspected main: `9dd531f94882eb18fe7f783de395cd1c7a8ee208`.
- Existing implementation branch: `codex/ci-auto-discovery-wfi-027-028-034`,
  `eba07a297117ec32104fcbdf90c3515a63e2163f`.
- GitHub PR #382 is MERGED, but its base is
  `codex/conduct-critical-review-and-improve-plugin`, **not main**.
  Merge commit `92528375705085967c19d75deb5f12e0fa66c276` is PR #381's
  pending head. `git merge-base --is-ancestor` against inspected main returned
  1. Do not mistake this nested merge for delivery to main.

## Primary source review

The branch contains existing implementation, not just a proposal:
`scripts/measure-evaluator-scratch-isolation.py`, its metric test, Bash and
PowerShell review-context validator changes, and isolation regression cases.
The delegated claim of an eight-file branch delta was rejected: the actual
three-dot diff against inspected main contains 40 files. The main WFI-034
historical result does not describe the complete branch state.

The metric's `measure()` loops over implementation reports for the feature and
compares each recorded root. In contrast, the validator additions compare the
evaluator only with the **current task's** implementation report: Bash diff
at new lines 469-483 and PowerShell at 431-446. The quality-gate skill still
requires no reuse by any implementation context for the feature or earlier
evaluator. Thus the current-task check is not evidence that the complete
launch-isolation requirement is mechanically enforced. Metric detection after
the fact is not equivalent to rejecting a contaminated launch.

`scratch_root` remains optional in the invocation contract. Existing tests
exercise same-task equal/ancestor/descendant roots and reject the field on
non-quality stages; the metric test additionally covers a cross-task overlap.
Those are different verification scopes. This review has not executed either
suite or proved a cross-task rejection in the actual launch validator.

The branch WFI result also says protected enforcement is staged despite live
validator changes in that same branch. Reconcile this stale declaration with
actual candidate files and sanctioned application evidence before integration.

## Continuation

Use PR #381's existing implementation as the starting point; do not create a
duplicate resolver or conclude no branch work exists. Complete exact-candidate
review, task/approval mapping, cross-task and prior-evaluator enforcement
assessment, required negative controls, and the specified five real-run
observations. No issue closure, task Done, or merge is claimed here.

## Exact-candidate verification — 2026-09-06

Primary confirmed clean worktree `/private/tmp/pr381-verify.7id2mX/worktree`
at `92528375705085967c19d75deb5f12e0fa66c276`. The delegated first invocation
used a login shell followed by `./tests/...`; since the suite shebang is
`#!/usr/bin/env bash`, this did not establish which Bash interpreted the suite.
A second invocation explicitly used `/bin/bash tests/<suite>` without edits.

Agent-reported direct invocation results: scratch metric exit 0; isolation suite
exit 141 with no output/counts. Primary read the raw files in
`/private/tmp/pr381-verify.7id2mX/logs.vVGzuX/`: the metric log contains
`WFI-034 scratch metric tests passed`; the isolation log is empty. Those files
alone do not encode exit status, so the exit codes above are attributed to the
agent, not falsely described as independently recovered from log markers.
Neither the initial nor direct isolation invocation is a PASS. No test was
weakened and no five-real-run isolation claim follows from the metric test.
# Primary isolation-suite failure localization — 2026-09-06

At unchanged PR381 head 92528375705085967c19d75deb5f12e0fa66c276, primary ran
the suite with Homebrew Bash 5.3.9 and BASH_XTRACEFD=3, preserving stderr capture
assertions by directing xtrace to an independently inherited descriptor. Session
28006 completed with exit 141 (terminal chunk d5960c). Unlike the earlier system
Bash xtrace diagnostic, captured error categories remained uncontaminated.

The final traced pipeline is tests/review-agent-isolation.tests.sh:713:
git archive of pinned baseline 7df7318 piped to tar extraction. The suite had
already passed the WFI-036 PowerShell call. The delegated assertion that that
call was the failing path is therefore rejected. No test/fail function was
changed by the primary, and the worktree status was clean before the run.

A reduced read-only probe using the same eleven archived paths piped into tar
listing returned PIPESTATUS `141 0` (chunk 679fab): the producer failed with
SIGPIPE while tar succeeded. Toolchain: Apple Git 2.50.1 and bsdtar 3.5.3 /
libarchive 3.7.4. This localizes the current blocker to archive consumption,
not the isolation validator. It does not prove the remainder of the suite passes.

A diagnostic attempt using tar -it was unsupported by this local tar (141 1);
it is not a fix or successful regression. The preferable candidate for review
is to write git archive to a fixture-local archive file, check its exit normally,
then extract that completed file with tar. Preserve set -e/pipefail, rollback
comparison assertions, fixture contents and the pinned baseline; do not swallow
141 or neutralize fail. No suite edit or repair approval is claimed here.

A subsequent reduced probe wrote the same eleven-path baseline archive to
`/tmp/sdd-archive-probe.P3Domu/baseline.tar`: git archive exited 0, then tar -tf
listed the expected entries and exited 0 (primary chunk 6c6d3f). This verifies
archive generation and file-based listing only, not suite completion or extraction.
Explicit approval for the narrow suite repair and regression was requested.
RT-20260821-018 remains an independent human-decision blocker for historical
T-005 criterion/evidence issues; fixing this pipeline does not resolve that ticket.

## Limited repair approval — 2026-09-06

The user explicitly approved replacing the failing `git archive | tar` line
with temporary archive generation, success verification, then extraction and
regression verification. Scope is the archive statement in
`tests/review-agent-isolation.tests.sh` only; preserve baseline 7df7318,
all assertions, fail-closed behavior and active protection. Use the existing
private fixture directory and cleanup. This decision does not adjudicate
RT-20260821-018, authorize frozen evidence edits or establish T-005 Done.
The lightweight worker was assigned the scoped change and unchanged full-suite
run; primary independently reviews the resulting diff and evidence.

### Limited repair result

Candidate remains based on PR381 head 92528375705085967c19d75deb5f12e0fa66c276
in `/private/tmp/pr381-verify.7id2mX/worktree`. Only
`tests/review-agent-isolation.tests.sh` is modified: six added lines replace
the single pipeline, using `$tmp/rollback-baseline.tar`, explicit archive
failure handling, a nonempty-file check and explicit extraction failure handling.
Primary reviewed the complete diff: pinned ref, path list, assertions and
cleanup remain unchanged; no validator or frozen evidence was modified.

Primary independently ran `/opt/homebrew/bin/bash -n` on that suite (exit 0,
chunk 3ca3ce), `git diff --check` (exit 0, chunk 700605), and the complete
suite with `/opt/homebrew/bin/bash` (session 26496, terminal chunk 9e573d,
exit 0). Actual output: `ok: sequential reviewer and evaluator contexts are
distinct, authorized, and hash-chained`. The suite does not emit an assertion
count; no numeric coverage is inferred. This passes beyond the previously
observed archive SIGPIPE failure and executes the remaining assertions.

Source SHA256: eeb0c8750c54d7d65a2688448b0d5a3c4bec5445f056ef05ebc6e4b80c80697f
Worker's separate successful run log: `/tmp/pr381-review-agent-isolation.log`
Log SHA256: 0811ce88ee2cfebe6ecd064e74c4f542fc89c6797051117c646886db414c940a

Scoped patch review: accepted. This is local regression evidence, not formal
T-005 quality-gate PASS. No commit, push, merge or issue closure was performed;
required CI, current-main integration and historical evidence findings remain.

### Publication and current integration blocker

The reviewed one-file repair was committed as
4ee8c34fd58ebf0789bd7bab16d77775bd98ab7a and normally pushed to the existing
PR381 branch (exit 0, chunk ef0e61). Comment 5557447971 records its narrow
verification scope and unresolved historical findings. PR remains Draft.
GitHub reports CONFLICTING/DIRTY rather than starting Actions; only a CodeRabbit
status is present, which is not mandatory CI. Primary merge-tree against main
91cf642ccbacbae3dafdf4ee89386eb3275e612f returned exit 1, tree
962db3d90e5ebe1d5e31fd49e22f9650b26a91a4, with the sole conflict in
tests/run-all.sh. No index/worktree merge was performed. Read-only conflict
analysis was delegated to preserve the full suite list and paired behavior.

### Subsequent staged integration verification (2026-09-06)

The worktree now contains a pending, resolved `--no-commit` merge of main
91cf642ccbacbae3dafdf4ee89386eb3275e612f. It is not yet a merge commit.
Primary compared the staged result to Git's merge-tree: only run-all.sh and
suite-inventory.posix differ from its automatic result. The inventory retains
all 136 main suites in their relative order and lists 139 unique suites, with
the three existing PR additions. This is runtime `--list` verification, not
execution of 139 suites (chunk 223717). Both newly imported PowerShell suites
appear exactly once. Scoped runner diff checking passes; full diff checking
still reports existing patch-context whitespace and is not claimed clean.

Homebrew Bash wiring verification did not finish. Sampling its child PID 66513
for one second recorded 783/783 samples in `heredoc_write -> write` (chunk
f43b13), matching the previously recorded local Bash pipe deadlock. Primary
sent TERM only to that owned child; the parent session 71976 had not returned
at the last observation. This run is not a pass.

As an explicitly labelled runtime comparison, the unchanged wiring suite ran
with `/bin` first in PATH and `/bin/bash`: session 3527, terminal chunk 48f2a3,
exit 0, `CI suite wiring tests passed`. No test, production gate, assertion,
or timeout was edited for this comparison. Required GitHub CI and the separate
historical evidence findings remain unresolved; no main merge or issue closure
is justified by this scoped result alone.

The integration candidate was subsequently committed as
3971c93a5705dc15f86ba56cc62118613e4b19db and normally pushed to the existing
PR381 branch (terminal push chunk c40fb1, exit 0). GitHub now reports MERGEABLE
and queued/running required Actions including the complete POSIX regression
inventory. Draft status is retained. This resolves the merge conflict, not the
historical evidence findings or final main-merge conditions.

### Current-head CI diagnosis

Run 34017386320 executes candidate 3971c93a against main91cf (GitHub merge ref
1d1c1dba96ce7025a704e6aff754a25e8dc9ac86). Completed failed jobs are not
restarted or treated as a transient timeout:

- Test jobs on all three OSes fail PowerShell workflow-state validation.
  Ubuntu job101443473011 reports `wfi-034-scratch-isolation:
  registry-unregistered-directory: specification directory is not registered`
  (raw log sanitized, chunk ba3bb1). The directory actually contains only
  human-copy README and two patch files, no tasks.md or specification.
  It is absent from both the registry and AGENTS active specs list. Adding a
  permissive legacy exemption would not establish valid specification evidence.
- Ubuntu version-gates job101443473166 records pass=16 fail=1 in
  bump-version-gate: TEST-006 cannot find registration in run-all.sh and/or
  workflow (chunk aa9368). The PR moved POSIX registration to an external
  inventory, while this self-registration assertion still checks old sources.
- All three loops-routing jobs fail loop-inventory tests. Independent read-only
  diagnosis has been dispatched; its cause is not yet assumed identical.

These failures are separate from the successful archive regression. No gate
or assertion has been relaxed. Resolving the staging-directory location and
updating every old registration consumer requires a scoped repair and review;
the historical RT-20260821-018 human decision is still separately required.
