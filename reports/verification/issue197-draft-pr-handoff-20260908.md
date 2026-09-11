# Issue 197: existing branch surfaced as Draft PR

PR: https://github.com/aharada54914/sdd-forge/pull/401
Source head: 135b147926689bd3adc8c834932a9b82b9f5a607
Branch: feature/epic-197-a9-dogfood

GitHub reported this branch 8 commits ahead and 62 behind main at inspection.
The prior all-state PR lookup for this head branch returned an empty list.
The existing branch was used unchanged to create the draft; no product files,
ledger records, frozen evidence or task approval fields were changed.

The canonical committed reviewer-b.json for attempt 1 round 1 records one
Critical and three Major findings. In particular, the approved eight-component
map omits plugins/domain/**. The committed handoff explicitly requires a new
human ruling between a ninth component, folding it into an existing component,
or cross-cutting ownership. No such ruling was established in this inspection.
The recommended clarification is a ninth independent component consistent
with the per-plugin ownership rule; this remains a proposal, not approval.

The former worktree path in that handoff no longer exists. EXECUTION_HANDOFF.md
records its intentional removal by another user task while retaining branches.
Do not recover it by applying stale worktree assumptions or duplicate commits.

Next: obtain the ownership ruling, reconcile the intentionally reverted earlier
remediation, define growing-path scope and missing boundary ACs, then perform
fresh formal review. Existing review evidence stays immutable. PR creation
does not prove CI success, formal approval, implementation completion, a full
advisory release cycle or the required post-promotion E2E feature. Neither
Issue 197 nor parent 187 was closed.

## CI registration diagnosis and local validation, 2026-09-08

Run 34173392316 at the source head failed the three OS `test` jobs. The
Ubuntu job 101897943405 reports `registry-unregistered-directory` for A9.
The registry had no A9 entry although AGENTS.md registered the directory.

A dedicated worktree at
`/Users/jrmag/.local/share/sdd-forge-a9-ci-20260908`, local branch
`codex/a9-ci-registry-20260908`, retains that same base HEAD. Its only change
adds A9 to `specs/workflow-state-registry.json` with the existing `full`
profile. No validator, review status, approval or historic evidence changed.
`git diff --check` passed. The change is uncommitted and unpushed.

Both actual validators completed with exit 1:

- `rtk proxy pwsh -NoProfile -File plugins/sdd-quality-loop/scripts/check-workflow-state.ps1`
  (session 47639, macOS PowerShell, not native Windows).
- `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh`
  (session 60394).

Both now report exactly the same A9 failure:
`workflow-state: epic-197-a9-dogfood: task-lifecycle: tasks.md requires Spec and Impl Passed`.
A7/A8 amendment-growth messages are explicitly tolerated diagnostics, not
the reason for these failures. Both local sessions are terminal; do not restart
them merely to wait for a different outcome.

The source checks enforce this prerequisite at check-workflow-state.sh:1361
and check-workflow-state.ps1:1546. A9 tasks.md still has Pending review and
human approval, and Draft/Planned tasks. The registry correction exposes the
existing premature task-plan lifecycle; it does not fix the formal review
findings. Preserve the task plan and FAIL evidence. Do not delete or rename
the plan, switch to a weaker profile, or manufacture Passed statuses to make
CI green. Complete the actual prerequisite reviews after resolving the
outstanding ownership decision. No merge-readiness claim is justified.

At the latest GitHub observation, run 34173392316 still had four running jobs:
Windows installers and all three version-gates jobs. The three failed test
jobs were terminal; do not rerun this unchanged head as a repair.

Subsequent observation: Windows installers job 101897943569 completed SUCCESS
in 10m26s, with no failed steps. The three version-gates jobs remain live;
Ubuntu advanced from the Bash component-coverage suite to its PowerShell
suite, and macOS advanced from the write-boundary matrix to evaluate-predicate.
Windows was executing the bump-version loop-gate prerequisite suite. These
are verified live jobs, not stopped work. No version-gates failed step was
reported at this observation. Local `gh run watch` session 85130 watches this
same run with a 30-second interval; resume that handle rather than starting
another watcher. Existing three workflow-state failures remain unresolved.

Latest direct API observation (after 2026-09-08T00:46:31Z): Ubuntu
version-gates job 101897943475 and macOS version-gates job 101897943485
are completed SUCCESS. Windows job 101897943495 remains in_progress;
its PowerShell bump-version prerequisite completed SUCCESS at 00:45:02Z,
and detect-policy-weakening completed SUCCESS at 00:46:31Z. It advanced to
validate-approval-sidecar. Thus the earlier long bump-version step was not
a terminal failure and no restart was needed. Local watcher session 85130
was also confirmed live by polling its existing handle.

The run has 20 successful jobs, three failed workflow-state jobs and one
running Windows version-gates job at this snapshot. Pending downstream
steps are not coverage evidence. All seven open PR heads were rechecked
and match the previously recorded heads. No rerun, push or merge occurred.

## Terminal CI result

Run `34173392316`, exact head
`135b147926689bd3adc8c834932a9b82b9f5a607`, is now **completed / failure**.
All 21 non-failing jobs completed successfully, including all three native
version-gates jobs and all installer jobs. The three OS `test` jobs failed
`Validate workflow state (PowerShell)`; the required-checks aggregator failed
accordingly. There are no live jobs in this run left to wait on.

A fresh Ubuntu failed-log read (job `101897943405`, session 45474, terminal
exit 0) confirms the failing diagnostic is
`registry-unregistered-directory: specification directory is not registered`
for A9, followed by process exit 1. The local registry addition and subsequent
task-lifecycle failure documented above are different evidence at a different
tree: they must not be conflated with this unchanged remote head's failure.

No unchanged-head rerun is planned. The next A9 action still requires the
unanswered component-ownership ruling for `plugins/domain/**`, followed by
the actual prerequisite reviews and implementation verification. CI success
for the other jobs cannot close Issue #197 or authorize merging this Draft PR.
PR390 and PR394 required checks were also refreshed: both retain failed
Windows tests and failed required-checks; neither is ready to merge.

## Ownership decision received and specification amendment applied

The user explicitly approved the independent ninth domain component on
2026-09-08. This supersedes this report's earlier unanswered-decision state.
The A9 worktree retains base HEAD 135b147926689bd3adc8c834932a9b82b9f5a607.
Read-only tracked-tree inspection found the canonical existing path is
`plugins/sdd-domain/**`, not the `plugins/domain/**` spelling in the old
review/approval prompt; no phantom directory or ownership alias was created.

Applied locally: dated OQ-001/OQ-002 amendment, exact nine-ID and domain-path
acceptance oracles, design/task/traceability propagation, and ADR-0034. The
architecture-decision-records workflow was used to preserve alternatives,
rationale and approval boundaries. The existing uncommitted registry fix was
preserved, not newly recreated. All tasks remain Draft/Planned and review
headers remain Pending. No live Context or sidecar changed.

Validation: `git diff --check` exited 0; the OQ/component/path identifier sweep
covered the full spec directory; `git diff --exit-code --` for the old A9
spec-review evidence and identity ledger exited 0. Historical eight-component
and investigation wording is retained with explicit dated supersession notes.
These are document consistency checks, not executed acceptance tests or a
fresh independent formal PASS. No commit, push or merge occurred.

Next: reconcile the already-authorized remediation in 4349ae40 without
restoring its superseded eight-component ruling; resolve the growing-path
definition and missing edge-case oracles; run the legal next-round precheck
and independent A then B review. Review admission of the design ADR is also
subject to the separately pending ADR-input contract repair RT-20260908-004.
Do not rerun unchanged remote CI or approve Draft tasks as a substitute.

## Acceptance edge-case repair continuation

Added individual TEST-004a–k cases for each omitted component, an extra ID,
and an unjustified empty classification; domain-specific ownership negatives
have their own TEST IDs. Expanded AC-005/006 with publication-blocking
oracles for new overlaps and unowned tracked paths (TEST-005b/006b), and
AC-018 with changed-registry revalidation (TEST-018a/b). These directly cover
the existing Edge Cases cited by canonical reviewer B, not a new approval
mechanism. Traceability explicitly maps suffix tests to T-002 and T-005.
Document diff checking passed; all cases remain Planned, not executed.

A precise growing-path ruling was requested: the seven approved shared
directory patterns versus fixed root metadata. No answer has been assumed.
The old 4349ae40 characteristic-override candidate also needs reconciliation
with the current schema: component characteristics allow seven named booleans
and additionalProperties is false; credential-bearing/release-write are not
present fields. Do not restore that candidate wholesale or claim runtime
support. No new independent review has started.

Fresh PR inventory retains seven open PRs at unchanged heads. PR371 checks
still show failed macOS/Ubuntu mcp-tests, Windows test, and required-checks
(run 33256788058). These are terminal failures, not a live wait handle or
grounds for merging. No commit/push/merge or issue closure in this continuation.

## Selective remediation reconciliation

Compared the complete 4349ae40 requirements/acceptance diff with the current
A9 candidate and current Project Context schema. Restored its non-conflicting
representative-change definition (full-track plugin code, never docs-only),
AC-032 reverse-coverage/digest checks and AC-033 premature-required rejection.
Added individually identified positive/negative TEST-032a–c and TEST-033a–c
cases, and propagated them into T-002/T-005 and traceability. The active AC
count is now 31; old AC-030/031 are not silently renumbered or implemented.
Old AC-034's registry-change intent is already covered by TEST-018a/b.

The characteristic override portion was not restored: the current schema
allows seven named boolean characteristics, omits credential-bearing and
release-write, and rejects additional properties on components/characteristics.
This requires a real producer/consumer contract design, not a purported
backward-compatible YAML-only edit. Nine-component approval does not decide it.

Primary consistency inspection and diff checking found no whitespace errors;
historical A9 review evidence and the identity ledger remain unchanged. These
are specification amendments only: all new tests are Planned, no runtime test
or formal reviewer PASS is claimed. Draft task approvals were not changed.
Formal review still awaits the growing-path ruling and ADR-input contract repair.

## Growing-path ruling received

The user subsequently approved keeping fixed root files as separate shared
rules. Applied that answer to OQ-002: the seven previously proposed directory
patterns are the growing-path set; the four named root metadata files retain
exact-path cross-cutting rules. Installer ownership is unchanged and no root
catch-all is authorized. Added TEST-025a–k planned coverage for new descendants,
exact root rules, unlisted-root rejection, installer ownership preservation,
and missing bootstrap rules. Propagated the resolution through design, tasks
and traceability. This supersedes earlier waiting-for-growing-path statements.

`git diff --check` exited 0; the historical A9 review directory and identity
ledger diff check exited 0. No runtime acceptance test or new formal review was
executed. ADR-input contract repair and characteristic-override reconciliation
remain; the user's clarification is not a formal PASS or Draft-task approval.

Dependency correction: ADR-input repair is not a prerequisite of A9's spec
review, whose allowed inputs do not include design ADRs. It applies to the
later implementation-policy review lane. See
`a9-characteristic-consumer-gap-20260908.md` for source evidence and the newly
identified predicate-allowlist/typed-value consumer requirements. Do not keep
the spec lane waiting for RT-004 solely because of earlier handoff wording.
