# T-004 deterministic gate preparation

Implementation-side checks only; not an evaluator verdict or a Done decision.
Commands used `rtk proxy`, `login=false`; each log prefix below is
`specs/epic-195-a7-compatibility/verification/T-004/activation-gate-` and suffix
`-20261004.log`. No previous GREEN suite was rerun during this preparation.

| Check / exact arguments after script | Result | Log middle |
|---|---|---|
| `check-risk.sh specs/epic-195-a7-compatibility/tasks.md T-004` | exit 0 | risk |
| `check-task-state.sh specs/epic-195-a7-compatibility/tasks.md` | exit 0; 13 tasks; historical Done evidence emits dirty-tree warnings | task-state |
| `check-workflow-state.sh` (no feature filter) | exit 0; approved amendment-growth tolerances reported | workflow-state |
| `check-placeholders.sh tests/structural-compatibility.tests.sh tests/structural-compatibility.tests.ps1 tests/lib/markdown-ast-canonicalizer.sh tests/lib/markdown-ast-canonicalizer.ps1` | exit 0 | placeholder |
| `check-component-coverage.sh --repo-root .` | exit 0; canonical disabled-legacy N/A, manifest not consulted | component-coverage |
| `check-contract.sh specs/epic-195-a7-compatibility/verification/T-004.contract.json .` | exit 0 on historical contract, NOT fresh evidence acceptance | historical-contract |
| `check-traceability.sh specs/epic-195-a7-compatibility/traceability.json . require-evidence` | exit 1: REQ-002/003/004/007 require evidence but none listed | traceability |

Scripts are under `plugins/sdd-quality-loop/scripts/`. The historical contract
still cites the withdrawn malformed RED accounting and old GREEN captures.
Do not reuse its booleans for the new gate. The coordinator must construct a
fresh Default-FAIL contract, admit current evidence explicitly, and resolve
the required machine traceability evidence gaps rather than omit the check.
This implementer has not changed the historical contract, traceability.json,
evidence bundles or any gate verdict.

## Authorized wording amendment preparation

`donewhen-amendment-candidate-20261004.patch` changes only T-004's final
Done When from direct frozen traceability.md mutation to its equivalent
non-frozen report/addendum mapping, with the human-authorized 2026-10-04
amendment and provenance re-review requirement recorded in the task section.
`git apply --check` passes (initial candidate hunk syntax was corrected before
the successful check). This is applicability validation, not an apply or
guard authorization result. The coordinator is the task-plan owner and must
use the normal protected edit route. No protected write was attempted here;
no refusal was bypassed.

## Remaining gate work

- Apply the authorized minimal task amendment through the coordinator and
  perform the required post-implementation provenance re-review.
- Resolve the machine traceability failure with authorized evidence records;
  unrelated REQ-003/004/007 gaps are not silently assigned to T-004.
- Classify the current historical CI-candidate scope finding using
  `ci-candidate-ownership-audit-20261004.md`; the stale whole-file candidate
  must not overwrite today's workflow.
- Declare current exact artifact hashes in the gate-admissible output channel,
  freeze the report, create the allowed-input manifest and independently
  reserve the evaluator. Existing historical output rows are not a current
  manifest. The implementer must not run its own independent critical review.
