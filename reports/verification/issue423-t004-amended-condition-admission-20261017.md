# T-004 amended completion condition: admission checkpoint

## Scope

The 2026-10-17 explicit human decision is recorded in
`specs/sdd-domain-multitarget/verification/T-004/completion-condition-approval-20261017.md`.
Only T-004's final Done When item changes. Risk, workflow, other tasks, production
code, tests, runtime schemas and existing reports remain unchanged. No production
failure was invented. This is an admission checkpoint, not a quality-gate PASS,
an evaluator reservation, Implementation Complete, or Done.

## Cloud commands and actual results

Commands ran against parent `7848ad97cfbead8e67245d94cc03c2adf33ad209`
with the documented amendment in the working tree:

| Command / inspection | Actual result |
|---|---|
| `git fetch origin codex/issue423-boundary-checkpoint` | exit 0; fetched remote and initial HEAD both equal the parent above; initial working tree clean |
| `bash scripts/check-sdd-structure.sh` | exit 0; `check-sdd-structure: OK`, advisory `CLAUDE.md` |
| `bash plugins/sdd-review-loop/scripts/task-review-precheck.sh sdd-domain-multitarget 4 1 --provenance-rereview` | exit 0; task-plan hash stale as expected after authorized body amendment, allowed only for this explicit provenance re-review; precheck complete |
| Same task-review precheck with `--verify-inputs` | exit 0 before both reviewer launches; inputs verified |
| `bash plugins/sdd-quality-loop/scripts/validate-review-context-set.sh reports/review-context/issue423-t004-task-a4r1-a-invocation.json . --reserve` | exit 0; `REVIEW_CONTEXT_OK`, sequence 1192, identity uniqueness checked |
| Equivalent reservation for `issue423-t004-task-a4r1-b-invocation.json` | exit 0; `REVIEW_CONTEXT_OK`, sequence 1193, chained from 1192 |
| `bash plugins/sdd-implementation/scripts/validate-implementation-report.sh reports/implementation/sdd-domain-multitarget/T-004.md` | **exit 1**; `IMPLEMENTATION_REPORT_FIELD: missing ## Test Evidence` |
| `python3 -B plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check` | exit 0, no drift output |
| `git diff --check` | exit 0 |
| Read-only comparison with parent | exactly one task-plan line amended; zero production/test/runtime changes; existing implementation report unchanged |

Tool discovery: Python 3 and jq available; `codex`, `pwsh`, `ruff`, and `mypy`
unavailable. No installation or trust/permission changes were attempted.

The caller initially mislabeled the reviewer-A reservation record hash as an
invocation raw hash. The independent reviewer stopped before substantive reads.
The caller corrected the distinction, supplied the actual separately measured
raw invocation pin, and the reviewer verified it before proceeding. Neither
the invocation nor reservation was replaced or bypassed.

Attempt 4's first task-review delivery was rejected by `check-workflow-state`
(exit 1): the caller's review brief omitted TRACEABILITY-SYNC and the output
did not explicitly adjudicate precheck's T-001 frozen-artifact citation. The
returned reports and their original summary are retained. Supplemental output
was not used to silently replace already admitted input: the original bytes
were restored and a fresh attempt 5 was launched with the complete checklist.
The unused corrected-B reservation in attempt 4 conveys no evaluation verdict.
See that round's `delivery-rejection.md` for the rejected-delivery distinction.

Attempt 5 round 1 subsequently received independent reviewer A/B PASS with zero
findings. Its chronological reservations are sequences 1195/1196; both contexts
were fresh and conversation-isolated. The reviewer-A delivery key was corrected
by that reviewer to the canonical `manifest` array, without changing its checks
or verdict. `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh
--feature sdd-domain-multitarget` then exited 0 with `workflow-state: ok`.
The amended task body is now bound by new provenance review; the independent
task-plan reviews are not a formal implementation-quality verdict.

The repository-wide `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh`
also exited 0 (`workflow-state: ok`), with the existing A7/A8 amendment-record
growth tolerance notices. No prior artifact was changed to suppress them.

## Remaining formal admission boundary

The preserved T-004 implementation report explicitly describes itself as a
partial checkpoint. Besides the first validator diagnostic above, read-only
inspection finds no task-input manifest citation, session/agent-instance
binding, isolation section, or output hash table. No T-004 implementation
manifest is present under its verification directory. The original heading is
also not the formal evaluator's required `# Implementation Report: T-004`.

`quality-gate` requires the pinned same-task implementation manifest and report
identity, canonical ledger continuity, admitted delivery, and a fresh evaluator.
A supplemental delivery declaration admits additional files; it does not
manufacture an implementation reservation, change report identity, or waive
launch admission. The previous independent development diff-review PASS and
the task-plan provenance reviewers cannot substitute for that evaluation.
The native Codex evaluator CLI is additionally unavailable in this environment.

Do not advance T-004 to Done until a legitimate forward implementation-report/
delivery continuation satisfies those requirements while preserving the old
report and its bindings. No retrospective identity, fake RED, forged evidence bundle,
or passing contract is created here. The approved alternative compatibility
acceptance remains valid; the obstruction is formal delivery, not a demand to
change correct product behavior. Do not start T-005 or merge PR #535.

## Attributed earlier observations

The user confirmed all 37 CI jobs, including required-checks, on the parent
above, plus four macOS PowerShell runner cases and five T-004 Python cases.
They also confirmed the existing T-005 standing-consent suite (55/0), its CI
registration check, and scan suite (101/0). These were not rerun here and do not
prove a later head. Consent structure inspection remains distinct from real
egress verification. No T-005 implementation has started.

## Concurrent remote reconciliation

Before publication a new fetch found remote
`76e442b35100000a0e5592f2c9e801e7c402253c`, including another context's
UI-provider implementation and release-validation report. That remote changes
T-002 through T-006 to Implementation Complete, including reverting T-003 from
Done. The current user instruction still requires T-004 Done before this
context begins T-005. The remote report is not treated as a new user approval
or a formal gate verdict. Its existing changes and statuses were preserved by
a normal merge, not overwritten or force-pushed. The task-plan normalized body
hash remains unchanged by these lifecycle-only edits.

The no-T-005-implementation statement above describes this context only; it
does not deny the other context's now-published implementation. No runtime,
test or contract changes were added by this context relative to that remote.
After reconciliation, feature workflow-state, generator freshness and diff
checks exited 0. The T-004 suite was rerun because the remote changed a consumed
bootstrap skill; its actual outcome is recorded below.

`python3 -B tests/sdd-domain-multitarget-T-004.tests.py`: exit 0,
`Ran 5 tests in 28.026s`, `OK`; all five stale-snapshot diagnostic/schema/
no-partial-publication assertions also passed. These are new cloud results on
the reconciled tree, distinct from the earlier user-reported macOS results.

## Premature lifecycle correction

The published independent PR review on `7e110ebb763d24b7ee7d73f383d774e8f935823b`
[flags T-004's premature Implementation Complete state](https://github.com/aharada54914/sdd-forge/pull/535#discussion_r4301115053).
The human amendment resolves the production-RED part of that historical concern,
but the preserved report still fails formal admission as measured above. After
preserving the concurrent remote changes, this context corrects only T-004 back
to In Progress; it does not claim the independent finding is dismissed, restore
other task states, close a review thread, or set Done. Lifecycle normalization
preserves the task-stage body binding. PR #535 remains open and unmerged.
