# T-004 activation implementation addendum

Run ID: epic-195-a7-compatibility-t004-activation-intake-20261004
Task Attempt Count: 2

This is a new intake/handoff addendum, not a replacement for the historical
implementation report, a new completed implementation attempt, or quality-gate
evidence. The attempt count is carried from the historical report; no production
change or RED test has started in this session.

## Session Handoff

The implementation session stopped after context compaction, as required by
`implement-task/references/agent-delegation-policy.md`, Context Hygiene:
"If the context has grown long, or if compaction has occurred, write the
current state to the Session Handoff section of the implementation report
and end the session. Do not rely on summaries or compacted context."

The historical report is preserved. This addendum records the handoff instead
of rewriting its frozen evidence. Task status has not been changed.

### Current verified state

- `tasks.md` T-004 still says Approved, Implementation Complete, Risk high,
  Required Workflow tdd, Security-Sensitive true. Requirements include AC-042.
- Historical report `reports/implementation/epic-195-a7-compatibility/T-004.md`
  carries Run ID `epic-195-a7-compatibility-t004-remediation-20260814`, attempt 2,
  and a prior RED-accounting supersession note. It is not fresh evidence.
- This session made no production or test edits and ran no new RED/GREEN tests.
- The only new output from this session is this handoff addendum.
- Existing T-010 dirty changes, T-008 host records and other untracked evidence
  belong to concurrent/prior work and remain untouched.

### Requested continuation, not yet verified or implemented

The parent requested minimal Bash/PowerShell F3 / AC-042 activation after the
A1 dependency merge, using the existing F4 / AC-007 activation pattern. Parent
reports current structural-suite failures Bash 60/1 and PowerShell 67/1; these
counts are parent-provided context, not executions by this session. Reproduce
them before relying on them. Existing recorded F3 artifacts must not be
refreshed or relabelled as native-host evidence.

On fresh-session resume, first read the task and historical report plus this
addendum from disk. Read required skill instructions and task contracts rather
than treating this handoff as an authoritative substitute. Before production
edits, complete and record the high-risk field/counterpart/failing-test preflight,
write and run a failing regression test, and ask the parent to perform any
necessary task-status transition. Then implement the scoped suite twins, run
relevant regressions and the separate PowerShell operator/cmdlet case sweeps,
and record the newly reachable F3 branch and matching offline execution.

Do not modify frozen specifications, traceability, corpus or historical evidence;
do not commit, push or set Done. The parent owns task-status changes. Native
T-008 permission recovery is outside this scope.
