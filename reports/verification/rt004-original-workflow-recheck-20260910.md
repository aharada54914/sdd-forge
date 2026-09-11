# RT004 original-path workflow recheck

Date: 2026-09-10. Agent-executed verification; no production edits.

The previous receipt-only turn did not advance integration. This run used the
existing original test driver and validators, not extracted patch executables.
PowerShell reports version 7.6.2 on this Mac.

## Inputs

- tests/impl-review-adr-inputs.tests.sh: `582357d2c246dc585710cbb2880dd64353529186a4c42c5b3c7d6d562ccb17dc`
- plugins/sdd-quality-loop/scripts/check-workflow-state.sh: `0bffcea97568257c86997245aa72542860ac9ef5cff9836efd4411d80dd6104a`
- plugins/sdd-quality-loop/scripts/check-workflow-state.ps1: `291ee7531594757d6ebc04c144bb8b35938f7715ae76665c9bdf723df09b1ff5`

## Executed results

`rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only`

Session 82617 completed with exit 0: `ADR workflow history: passed=137 failed=0`.
Both runtimes accepted controls and rejected missing, duplicate, unknown,
mis-cased and reordered required check IDs. Interrupted outputs, malformed
JSON, historical pin forgery and current ADR declaration changes were covered
by this selection. Complete emitted output is retained in the thread tool
results; this report is a summary, not a substitute raw transcript.

`rtk proxy pwsh -NoLogo -NoProfile -File plugins/sdd-quality-loop/scripts/check-workflow-state.ps1 --registry specs/workflow-state-registry.json`

Session 98804 completed with exit 1. Blocking diagnostics:

```text
workflow-state: epic-136-phase4-docs: stage-provenance: impl integrated verdict is not a valid PASS
workflow-state: epic-189-a1-project-context: stage-provenance: impl integrated verdict is not a valid PASS
```

A7 and A8 additionally emitted amendment-record-growth tolerances; those were
not reported as the failing conditions. No verdict was rewritten.

## Scope and next action

The 137-case result establishes the current workflow-history selection, not
admission/precheck coverage, native Windows behavior, the pending PowerShell
boundary observer, or formal review completion. RT004's acquisition candidate
and RT002's formal recovery remain incomplete. The canonical-state failure
must be resolved through valid review evidence, not a test exception.

GitHub read-only refresh found 11 open PRs, no queued/in-progress checks and
unchanged recorded heads. PRs 245, 403 and 405 remain conflicting. A zero-length
failed-check list on those PRs is not mandatory CI success. No commit, push,
merge, branch deletion, issue closure or task Done transition occurred.
