# Proving a CI selection category

The restored workflow can plan and validate full execution. Its `readme-contract`
category remains inactive until current evidence passes the existing activation
validator. Restoring these tools does not establish selective execution or a
speed improvement.

## Fix the definition before collecting evidence

Merge compatible planning tools before the workflow that invokes them. Then fix a
baseline commit **B** containing the workflow, catalog and all implementation
changes, including model restoration. Use its exact SHA throughout this procedure.

The initial category matches only `README.md`. It retains every current job group
except `cli-hook-enforcement`. Its explicit setup declaration permits omission of
that job's known Claude CLI installation command after proof; it does not allow
arbitrary setup commands to be skipped. `active` is `false` and `evidence` is `null`.
No category-wide skip is inferred from a file extension or directory name.

Before activation, trace the current README consumers, including release/version
checks, cloud installers, installed payload capture and generated files. Confirm
that the proposed omitted CLI job does not consume the changed README contract.
If a missing consumer is found, revise the definition and choose a new B. Historical
consumer lists and the v1.20.0 omission count are investigation aids, not current
proof. A change to the workflow, suite registration, dependency definition or
execution code invalidates the old baseline.

## Collect full execution and a real mutation failure

1. Complete a full GitHub Actions run for B. Record its run ID, planning attempt,
   tested revision, API head SHA and event from the actual run.
2. From B, create a disposable commit **M** changing only the README release/version
   text to an invalid value. Run full CI. Keep catalog and workflow bytes identical
   to B. The result must contain detected test failures; a cancelled run, missing
   evidence or invalid-input error is not mutation proof.
3. Download each run's original planning artifact and collect its actual execution
   observations. Do this against clean worktrees at their exact tested revisions.
   Fetch the tested merge commit separately when a PR API head differs from it.

Use the following commands once the values have been taken from the real run.
`RUN`, `PLAN_ARTIFACT`, `TESTED_TREE` and `EVIDENCE_DIR` are operator-selected values;
the evidence directory must be outside the tested worktree and initially absent.

```bash
REPOSITORY=aharada54914/sdd-forge
mkdir -p "$EVIDENCE_DIR"
gh api "repos/$REPOSITORY/actions/runs/$RUN" > "$EVIDENCE_DIR/run.json"
gh api "repos/$REPOSITORY/actions/runs/$RUN/artifacts" --paginate \
  --jq '.artifacts[] | select(.name | startswith("verification-plan-")) | .name'
# Set PLAN_ARTIFACT to the original ci-plan artifact shown for this execution.
# A failed-job rerun can retain a plan from an earlier planning attempt.
gh run download "$RUN" --repo "$REPOSITORY" --name "$PLAN_ARTIFACT" \
  --dir "$EVIDENCE_DIR/plan"
API_HEAD_SHA=$(jq -r .head_sha "$EVIDENCE_DIR/run.json")
python3 "$TESTED_TREE/tests/verification-ci.py" collect \
  --repository "$REPOSITORY" --run-id "$RUN" \
  --output-dir "$EVIDENCE_DIR/observations"
python3 "$TESTED_TREE/tests/verification-ci.py" aggregate \
  --root "$TESTED_TREE" --plan "$EVIDENCE_DIR/plan/plan.json" \
  --observations "$EVIDENCE_DIR/observations" --run-id "$RUN" \
  --api-head-sha "$API_HEAD_SHA" --output "$EVIDENCE_DIR/result.json"
```

For B, aggregation must exit 0 with `PASS` / `verified` and a full plan whose
`tested_revision` equals B. For M, exit 1 with `FAIL` / `execution-failed` is expected.
Inspect the result rather than treating any nonzero exit as a successful mutation.
Exit 2 is an invalid or unavailable input. Retain genuine prior attempts; do not
rename copied receipts or erase failed history. The collector validates these
boundaries independently of a green job summary.

GitHub may update the nested `run.pull_requests[].base.sha` and `head.sha` when
branches advance, even though `run.head_sha` still identifies the original run.
The hosted collector preserves fixed original-event context and checks it against
the run, PR/repository identity and tested merge parents. Offline collection
without that context must happen while both source and base refs are frozen,
before branch updates or PR retargeting. Preserve collected observations and
original context; never reconstruct the context from a plan's revision fields.
A late collection with moved refs must fail rather than claim the old execution
belongs to a newer commit. Forks remain full-only even with a populated PR array
or context-free observations whose API repository IDs identify a fork.

## Construct and validate the activation packet

Store proof JSON under `reports/verification/ci-selection/`. The current tools have
no packet-generation CLI; construct these documented contract objects from the
collected bytes and current Git blobs:

- `verification-ci-consumers/v1`: B, the normalized `rule_sha256`, and a consumer
  entry for `README.md`. Its `suites` and `groups` must exactly match the category.
  Its nonempty `sources` list contains repository paths and SHA-256 digests of
  their bytes at B. Record the trace that justifies this inventory.
- `verification-ci-mutations/v1`: B, the same rule digest, and a case for
  `README.md` referencing the real M plan and result by `{path, sha256}`.
- `verification-ci-activation/v1`: category `readme-contract`, B, the same rule
  digest, and references to the full plan, full result, consumer inventory and
  mutation evidence. Optional `supporting_evidence` must name and hash passive
  evidence files allowed by the validator.

Compute hashes from the saved bytes; do not copy historical digests or derive a
result from job success flags. Use `rule_digest`, `plan_obligations` and
`validate_activation` in the existing `verification-impact.py` and
`verification-workflow.py` modules. Validation binds every expanded obligation,
checks that the proposed selection detects all observed mutation failures, and
rechecks baseline/current Git definitions and proof freshness.

Create activation commit **C** containing only the proof files and the catalog's
`active`/`evidence` changes. Its evidence reference contains `path`, `sha256`,
`rule_sha256` and `baseline_revision`. Other required source or definition changes
mean choosing a new B and collecting evidence again. The C pull request runs full
CI because it changes shared test configuration. Only after C is the trusted base
can the following README-only PR use the category.

## Compare selected and full execution

`SDD_CI_FORCE_FULL` must be the literal string `false` for same-repository PR
selection. An absent, invalid or `true` value keeps full execution. Fork PRs always
force full execution using the GitHub event's head-repository ID, even if this
variable is `false`. The observed PR #712 planning job used `CI_FORCE_FULL=false`;
no repository-setting change was needed. A settings API 403 alone does not reveal
the variable's value. Do not hardcode `false`, add write permissions, or relabel a
manual run as a pull-request event.

For fork runs with empty API `pull_requests`, the required verifier captures fixed
original-event fields separately from the source plan. It matches API repository
IDs, head SHA and attempt, checks the tested merge's ordered base/head parents,
and reconstructs all full-plan obligations. Missing event context, ambiguous API
metadata, selection or stale execution is rejected. These event values rely on
the trusted workflow environment; they are not signatures or information to
invent during offline recollection. See [fork observations and rerun recovery](../verification.md#fork-observations-and-rerun-recovery) for the trust boundary.
The compatibility regression uses real Git merges with simulated Actions
observations; the independently observed public fork API shape is not a hosted
fork acceptance run of this repository.

When `ci-plan` produces a new planning attempt, use **Re-run all jobs** so A9's
independent detector and selected workload executions belong to that epoch.
Do not use edited timestamps or copied attempt IDs to recover a failed-only rerun.

Create a representative README-only PR **D** against C. Verify that its uploaded
plan says `affected` / `classified-change`, then aggregate the actual run and
receipts. Obtain a full run for the same tested revision. A manual full run can
use a retained branch at that revision; record that its API head equals the tested
commit while the PR API head may differ from the tested merge commit. Never
compare different tested revisions as if they were the same change.

Record queue delay, required-CI elapsed time, summed job durations, planner and
collector overhead, cache misses/hits, detected failures and manual interventions
separately. Keep the source run IDs and attempts. Claim savings only after both
hosted executions and the mutation comparison are complete. If the selected path
misses a failure or its evidence is incomplete, retain full execution, repair the
definition and restart from a new baseline.
