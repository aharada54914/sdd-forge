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

## CI planning and the legacy observation API

Two interfaces share `tests/verification-impact.py`. The legacy observation
interface proposes a selection and reports its basis; it does not control
required CI jobs. The `ci-plan` job in `.github/workflows/test.yml` instead runs
`--plan` to produce a revision-bound `verification-ci-plan/v1` plan for the
tested revision and uploads it as an artifact. On pull requests the planner is
taken from the trusted base revision when that revision provides it.

Unknown changes, missing comparison revisions, test infrastructure changes, and
shared or sensitive changes retain the full profile. At the 2026-10-21
pre-activation checkpoint, the only catalog category (`readme-contract`) had
`active: false`. For any repository revision, use `tests/verification-catalog.json` at that revision
and its validated `evidence` references to determine eligible categories; the
actual uploaded plan and execution records establish what that run selected or
omitted. Catalog eligibility at an experiment base does not establish rollout to
main. This document alone establishes neither activation nor measured savings.

`SDD_CI_FORCE_FULL` (a repository variable passed as `--force-full`) is a
recovery switch. `true` forces the full profile. An absent or invalid value
also takes the full profile. A literal `false` does not by itself activate a
category that is not marked active.

Conservative full planning requires valid planner inputs. A failed `ci-plan`
job or malformed plan fails the required aggregate check. In particular, older
trusted-base planners reject the new catalog's `setup` descriptors with
`verification-ci-error/v1` / `input-invalid`, even with `--force-full true`.
Upgrade the trusted base to matching planner and catalog tooling before using
the new CI configuration. For recovery, repair the incompatible inputs and run
full manually on a revision with matching tooling; forcing full alone does not
repair this parser incompatibility. At the 2026-10-21 pre-activation checkpoint,
the live repository variable's value had not been verified. Later setting
observations must be dated and bound to the actual run; catalog eligibility alone
does not establish the remote setting or selective execution.

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

## Cloud evidence and platform coverage

The catalog registers cloud-orchestration contracts, routing, execution, verification,
profile and dependency suites, together with the #423 foundation regression. Use
`python3 tests/verification.py --suite tests/cloud-orchestration-routing.tests.py --run`
for scoped iteration; release verification still runs the full exact-commit profile
and test.yml, including required native OS lanes. Do not reintroduce a duplicate inventory.

Local synthetic transports, real pinned Bicep/CDK compilation, native model/guard
invocation and live cloud acceptance are separate classes. TEST-003/005/009 remain
BLOCKED without owner sandbox prerequisites. Native Windows installer/PowerShell
guard/schema tests do not prove provider CLI support: POSIX-positive cases skip,
Windows roots return UNSAFE_ROOT and unsupported safe-file primitives return
UNSUPPORTED_FILESYSTEM. Linux fixtures do not prove native Windows junction coverage;
record that branch only after real CI execution. See [operator guide](cloud-orchestration.md).

CI-efficiency research is not achieved savings. The legacy observation interface
remains observational. Category eligibility comes from the revision-bound catalog
and validated proof, while actual CI behavior comes from its plan and execution
records; skipped/planned checks are never PASS.
Keep required-checks and native Windows compatibility/gate/A9 obligations intact.
