# Verification workflow

Verification establishes that a change works. A completed document, an agent's
confidence, or a successful command without its required assertions is not a
substitute for that evidence.

## Repository development

`tests/verification-catalog.json` declares the regression suites and the local
and CI execution profiles. The Bash and PowerShell entry points use this same
catalog. Adding a test requires registering it; existing standalone diagnostics
and suites exercised through another suite are identified explicitly.

Use the local profile for the runtime being changed, or run a specific catalog
suite while iterating:

```sh
python3 tests/verification.py --profile local-posix --list
python3 tests/verification.py --suite tests/verification-catalog.tests.py --run
python3 tests/verification.py --profile ci-posix-fallback --plan
```

The runner continues through independent suite failures and exits unsuccessfully
if any required suite fails or cannot start. Optional missing-runtime skips remain
distinct from passing results. `--receipt` writes execution results for the
selected suites; it does not assert that a different profile or all CI succeeded.

CI retains the required platform coverage and the full regression set. The
fallback partitions use measured suite durations rather than equal suite counts.
Timing estimates affect placement only: stale estimates can make a run slower,
but cannot remove a test. The independent Windows compatibility, gate, and A9
lanes remain dependencies of `required-checks`.

## Selection experiment

`tests/verification-impact.py` proposes a selection and reports its basis. It is
an observation-only experiment: the proposal does not control required CI jobs.
Unknown changes, missing comparison revisions, test infrastructure changes, and
shared or sensitive changes retain the full profile. The initial narrower case
is deliberately limited to README changes, which still have documentation and
workflow contracts to verify.

Receipts can be compared with the proposal to find failures it would have missed.
Missing, skipped, or mismatched observations are not successful comparisons.
Even an observed successful comparison is not a reason to disable a required
test automatically. Broader selection needs evidence from representative changes
and review of shared dependencies first.

### CI planning tools before activation

The explicit `--plan` mode of `tests/verification-impact.py`, the contracts in
`contracts/verification-ci-*.schema.json`, and `tests/verification-ci.py` restore
revision-bound planning and observation validation. The current workflow still
runs its full required checks; it does not use these tools to omit work or replace
`required-checks`. No selection categories are activated in the current catalog.

The restored tests cover the planner, same-run API collection, attempt and receipt
binding, and pinned dependency acquisition with local fixtures. The historical
planner dispatcher under `tests/fixtures/verification-ci/` is a test input, not an
active workflow or evidence of hosted execution. The Pester cache helper is also
available before workflow integration; it rehashes package bytes on every reuse
and validates the archive before installing a fresh module tree.

Workflow integration must follow adoption of compatible tools on the trusted base.
The collector requires `actions: read` only in its consuming job. Until actual
plan, observation and result artifacts have been compared on the new revision,
these changes establish neither selective CI activation nor measured time savings.
An absent or invalid force-full value keeps full planning; literal `false` alone
cannot activate an unproven category. Main, merge, release and manual events stay
full.

### Fork observations and rerun recovery

GitHub can return an empty `pull_requests` array for a successful fork PR run.
The collector can preserve the original GitHub event fields with
`--github-event-context`; the workflow supplies only fixed event expressions.
These fields are separate from the plan and contain no token or PR body. The
fallback requires an actual fork, matching API repository IDs, head SHA and
attempt, and a checkout whose two merge parents are the original event base and
head in that order. It accepts only an independently reconstructed full plan
without omissions or activation evidence. Missing or ambiguous identity fails.
The existing single-PR API path remains available without this optional context.

The event fields rely on the trusted GitHub workflow environment, just as API
observations rely on their collector. They are not signed evidence that an
arbitrary offline author can create. Manual recollection without the original
trusted event context cannot recover an empty-array fork run. Compatibility tests
use actual Git merges and simulated Actions transport; the observed public API
shape does not establish a successful fork run of this repository.

If `ci-plan` creates a new planning attempt, rerun **all jobs**. A failed-only
rerun may retain an A9 detector or workload executed before that planning epoch;
the aggregate correctly rejects those stale executions. An unchanged original
plan may reuse eligible execution history, subject to the existing attempt and
receipt checks. Never edit timestamps or relabel inherited attempts to pass.

## Using Lite

For bounded application fixes, select the existing Lite track when the project's
policy permits it. Keep explicit acceptance criteria and verify the reported
failure and its fix. The Lite executor can run named baseline, acceptance, and
regression commands in one invocation and save their actual results. The quality
review references this record rather than copying its results into another table.

An independent postimplementation review still checks the acceptance criteria,
regressions, and scope. A command result is not that review. Full-track selection
and mandatory promotion remain effective; an agent's low-risk description alone
does not authorize downgrading them. Real-host requirements and actual release
observations cannot be satisfied by offline fixtures.

## Measuring improvement

Measure time to the first actionable failure, required-CI elapsed time, total job
time, missed failures in selection experiments, false alarms, and manual
interventions separately. Faster green runs alone do not demonstrate quality.
The initial goals of two minutes to useful local feedback and ten minutes for
ordinary PR validation are targets, not current guarantees. Long individual
suites, runner queues, and necessary platform coverage may exceed them.

Raw test logs and application execution records may contain local paths or other
private data. Keep them private; publish only reviewed summaries. Successful
execution receipts are not credentials, human approvals, or permission to reuse
results against changed source or environments.
