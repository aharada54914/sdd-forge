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

### Native macOS runner

Required macOS jobs use GitHub's standard `macos-26-intel` runner. This keeps
native macOS and Bash 3.2 compatibility checks running during the observed
ARM64 runner capacity shortage, without a paid runner or removing test steps.
The main test lane retains its 40-minute timeout. Planning and collection still
admit `macos-latest` as well as the explicit Intel label; neither label is an
alias for recorded evidence from the other.

Branch protection still requires the historical display context
`test (macos-latest)`. That display name is stable; the test matrix's separate
`os` field, `runs-on`, plan obligations and collected runner labels identify
`macos-26-intel`. The Windows and Linux display contexts are also unchanged.
A display name does not assert the runner architecture.

Report completed runs as Intel macOS 26 coverage. This change does not establish
ARM64 execution or compatibility, and queued ARM64 jobs are not passing checks.
Workflow changes require new baseline and mutation runs before selective CI
activation; observations from earlier runner definitions cannot be reused.

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

### Revision-bound CI planning

`ci-plan` invokes the trusted base planner for pull requests. Its generated outputs
select the existing job groups; the three native `test` contexts remain present.
`required-checks` downloads that run's original plan, collects Actions job results
and execution receipts, and validates their revisions, attempts and identities.
Only this collector job adds `actions: read`; no write permission is needed.
A9 activation and the distinct Windows 5.1/7 profiles remain required contracts.

The README-only category is defined but inactive. Unknown changes and missing or
invalid evidence keep full execution. `SDD_CI_FORCE_FULL` must be literal `false`
before a proven pull-request category can omit work; absent, invalid and `true`
values retain full execution. Main, merge, release and manual events stay full.
A variable-setting failure is not permission to replace this default or simulate
a pull-request event.

Pester caching retains pinned package bytes, rehashes every hit and installs a
fresh validated module tree. npm caches contain download bytes keyed by runtime,
lockfile and event trust scope; every job still runs `npm ci`. Cache hits are not
reused test results.

Local protocol tests and the historical dispatcher fixture establish no hosted
execution or timing improvement. Follow [CI selection recovery](contributor/ci-selection-recovery.md)
to collect current full and mutation evidence, validate category activation, and
compare selected execution against full execution at the same tested revision.

### Fork observations and rerun recovery

GitHub can return an empty `pull_requests` array for a successful fork PR run.
The collector can preserve the original GitHub event fields with
`--github-event-context`; the workflow supplies only fixed event expressions.
These fields are separate from the plan and contain no token or PR body. The
fallback requires an actual fork, matching API repository IDs, head SHA and
attempt, and a checkout whose two merge parents are the original event base and
head in that order. It accepts only an independently reconstructed full plan
without omissions or activation evidence. Missing or ambiguous identity fails.
For ordinary PRs, the same original-event context also binds revisions when the
API's nested PR base or head SHA has changed after the run started. The immutable
run head, event head, tested merge parents, PR number and repository IDs must
still agree. Current nested PR SHAs are validated as metadata, not used as the
original revisions. The existing context-free single-PR path remains strict and
fails if those API revisions no longer describe the tested run.

The event fields rely on the trusted GitHub workflow environment, just as API
observations rely on their collector. They are not signed evidence that an
arbitrary offline author can create. Preserve original context and observations
before PR or base refs advance. Manual recollection without that trusted context
cannot recover an empty-array fork run or a PR whose API revisions have moved;
never synthesize the context from the plan. For context-free proof collection,
freeze the source and base refs and collect before any branch update or retarget. Compatibility tests
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
