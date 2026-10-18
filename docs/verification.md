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
