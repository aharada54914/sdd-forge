# Independent Implementation Review: T-005 Escalated Attempt 4

## Identity and Manifest Gate

- Task: `T-005`
- Feature: `agent-cost-context-isolation`
- Reviewer run ID: `agent-cost-context-isolation-T-005-review-run-04`
- Reviewer session ID: `agent-cost-context-isolation-T-005-review-session-04`
- Reviewer agent instance ID: `agent-cost-context-isolation-T-005-review-agent-04`
- Model tier: `strong`
- Provider/model: `openai/gpt-5.2-codex`
- Isolation mode: `fresh-agent`
- Fallback mode: `none`
- Input manifest:
  `reports/implementation/agent-cost-context-isolation/manifests/T-005-review-4.json`
- Authorized output:
  `reports/implementation/agent-cost-context-isolation/T-005-review-4.md`

The manifest was the first substantive project input read. Its schema, task,
feature, run, session, agent-instance, model, isolation, fallback, and output
identity fields exactly matched this invocation. All 24 `allowed_inputs`
existed and independently matched their declared lowercase SHA-256 values.
The authorized output did not exist before the review. The gate therefore
passed; no unlisted project input was used.

## Scope and Compliance Review

Reviewed the approved T-005 contract, REQ-005, REQ-010, AC-002, TEST-002,
design boundaries, prior independent findings, and the complete current T-005
boundary. The implementation:

- gives each of the six reviewer roles and the Done evaluator a one-role,
  read-only, no-fallback `review-context-invocation/v2` boundary;
- persists and atomically reserves unique run/session identity through the
  hash-chained canonical ledger before launch;
- rejects missing manifests, stale or malformed ledgers, identity reuse,
  unlisted paths, hash mismatches, chat-only input, writable context, fallback,
  symlinks, and malformed contracts;
- binds evaluator non-specification inputs to exact path/SHA pairs in the
  current task implementation report; and
- provides equivalent Bash and PowerShell validation outcomes for the reviewed
  contract and adversarial cases.

The quality-gate contract does supply the current task ID: quality-gate
`SKILL.md` requires setting `task_id` to the current T-NNN before reservation
and requires the report path, heading, and Task ID field to match. The evaluator
contract independently requires the same binding. Both deterministic validators
make `task_id` mandatory only for the quality stage and enforce the exact
`reports/implementation/<feature>/<task_id>.md` path plus report identity before
authorizing any report-declared output.

## Commands and Results

| Check | Result |
|---|---|
| Manifest identity and 24 SHA-256 verifications | PASS |
| `git diff --check` | PASS |
| `/bin/bash -n plugins/sdd-quality-loop/scripts/validate-review-context-set.sh tests/review-agent-isolation.tests.sh` | PASS |
| PowerShell parser check for `validate-review-context-set.ps1` | PASS (`POWERSHELL_PARSE_OK`) |
| `PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin /bin/bash tests/review-agent-isolation.tests.sh` | PASS |
| Homebrew Bash focused test | PASS |
| Isolated `git archive HEAD`, overlay of the complete T-005 boundary, then focused test with `T005_SOURCE_GIT_ROOT` bound to the source repository | PASS |

Both focused executions and the corrected archive-overlay execution ended with:

```text
ok: sequential reviewer and evaluator contexts are distinct, authorized, and hash-chained
```

The first overlay harness attempt did not reach the test because `path` is a
special zsh variable and using it as a loop variable replaced `PATH`. Renaming
that harness variable to `item` produced the passing result above; no repository
artifact was changed.

Targeted temporary-fixture retests against both validators confirmed matching
fail-closed categories:

| Adversarial case | Bash | PowerShell |
|---|---|---|
| quality invocation missing `task_id` | `REVIEW_CONTEXT_CONTRACT` | `REVIEW_CONTEXT_CONTRACT` |
| same-feature report for the wrong task | `REVIEW_CONTEXT_PATH` | `REVIEW_CONTEXT_PATH` |
| report heading mismatches current task | `REVIEW_CONTEXT_PATH` | `REVIEW_CONTEXT_PATH` |
| report `Task ID` field mismatches current task | `REVIEW_CONTEXT_PATH` | `REVIEW_CONTEXT_PATH` |
| Outputs row has an extra column | `REVIEW_CONTEXT_PATH` | `REVIEW_CONTEXT_PATH` |
| Outputs row has trailing content | `REVIEW_CONTEXT_PATH` | `REVIEW_CONTEXT_PATH` |
| Outputs row is missing a delimiter | `REVIEW_CONTEXT_PATH` | `REVIEW_CONTEXT_PATH` |
| Outputs row has malformed backticks | `REVIEW_CONTEXT_PATH` | `REVIEW_CONTEXT_PATH` |

A canonical two-column Outputs row was accepted by both runtimes.

## Prior-Finding Closure

| Review-3 finding | Result | Evidence |
|---|---|---|
| Evaluator was not bound to the current task | CLOSED | Quality contracts require current `task_id`; both validators require the exact report path, first-line heading, and Task ID field. Wrong-task, heading-mismatch, and field-mismatch fixtures fail closed in both runtimes. |
| Bash and PowerShell used different Outputs grammars | CLOSED | Bash compares the entire row to the exact canonical two-column string; PowerShell uses an anchored equivalent expression. Extra columns, trailing content, missing delimiters, and malformed backticks all reject with category parity. |

The review-2 evaluator allowlist, foreign-lock ownership, JSON collection type,
and integer type findings also remain closed in the current code and focused
suite. The review-1 sequential launch, persisted freshness, whitespace parity,
rollback, and committed-Red findings remain covered and passing.

## Findings

### Critical

None.

### Major

None.

### Minor

None.

## Remaining Risks

- The launch instructions are repository contracts executed by host adapters;
  this review verifies their deterministic boundary and structural integration,
  not a live invocation on every supported host.
- Identity-ledger locking is intentionally filesystem-local. Cross-machine
  coordination would require a separate shared-storage contract and is outside
  T-005.

Neither residual risk contradicts REQ-005, REQ-010, AC-002, or the approved
task scope.

## Verdict

**PASS**

There are zero Critical and zero Major findings. T-005 is suitable to proceed
to `quality-gate`. This review does not change `tasks.md`; only `quality-gate`
may decide `Done`.
