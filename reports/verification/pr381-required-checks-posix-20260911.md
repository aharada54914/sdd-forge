# PR #381: require the complete POSIX lane

Status: human application verified; targeted live-workflow checks passed;
clean-commit rerun, exact-head CI, required approval and merge pending.

## Post-application update (supersedes the historical pending states below)

The user applied the combined workflow and A6 mirror batch. Both workflow
files hash to `982e5036bbaa970c27276dbba7efc588b583fd151500454b85df3664d4195308`;
the mirror manifest agrees. The agent did not run the human application batch.

Actual macOS results after application: aggregator regression 4 test methods
passed (including 36 non-success subcases); deterministic lane 29/0 with zero
designed-red; Bash design contract 121/0; PowerShell design contract passed
its initial contract checks and 51/0 consent checks; Bash standing consent
55/0, including deferred TEST-054 PASS. Mirror freshness: 6/0, 16 informational
pending artifacts retained, not promoted to verified/applied.

PowerShell standing consent initially failed TEST-053 (54/1): it searched
the runner source for a literal path, but the POSIX runner now reads its
inventory. The public `bash tests/run-all.sh --list` included the exact suite.
The test now checks successful listing plus case-sensitive full-item membership,
matching its Bash counterpart. Rerun: 55/0, deferred TEST-054 PASS, exit 0.
`pwsh -NoProfile -File reports/verification/pr381-consent-registration-regression.ps1`
executes the actual revised predicate: 7/0, including missing, mis-cased,
prefix/suffix mismatches, failed listing with matching output, and missing
PowerShell registration. This is a test-oracle repair, not removed coverage.

Main-agent review: listing exit status is captured immediately; `-ccontains`
rejects partial/mis-cased paths; no product behavior or review verdict changed.
The broader `tests/run-ci-unwired.sh` execution finished with exit 1:
59 suites executed, 58 successful and one failed suite. Its failure is
facet-manifest parity TEST-033:
`tests/facet-manifest-parity.tests.sh:431` explicitly compares the live workflow
against HEAD. The human-applied workflow is not yet committed, so this
clean-worktree assertion fails. Preserve the assertion; rerun after the
checkpoint commit. Do not infer full-suite success from targeted results.

The agent's explicit `git add` for this checkpoint was rejected by PreToolUse.
No staging/commit/push occurred. `pr381-human-stage-20260911.sh` is a human-only
staging command, syntax-checked but not executed by the agent; it checks HEAD,
branch and absence of unrelated staged changes and performs no commit/push.

Logs: `/tmp/sdd-pr381-consent-pwsh-postapply-20260911.log` preserves the failure;
`/tmp/sdd-pr381-consent-pwsh-fixed-20260911.log` records the corrected run;
`/tmp/sdd-pr381-unwired-postapply-20260911.log` records the completed broad run.

## Combined candidate update

Use `pr381-current-lane-20260911.patch` instead of the earlier aggregation-only
patch below. It also names/prefixes the current test job's 33 steps without
changing their commands, conditions, dependencies or action pins. All current
jobs remain; the obsolete phase3 snapshot is not used. Main-agent diff review
confirmed only the new POSIX steps, labels and required aggregation changes.

The self-check now defaults to the real workflow, with an optional explicit
candidate path for pre-application testing. Against
`/tmp/sdd-pr381-required-checks.Dlsfoh/current-lane-candidate.draft.yml`:
deterministic lane 29 passed/0 failed/0 designed-red; aggregation tests 4 passed
(including 36 non-success cases). Ruby/Psych YAML parsing passed inside the suite.

Actual design-system reruns: Bash 120 passed/1 failed; PowerShell initial
contract checks passed, consent checks 50 passed/1 failed. Both failures are
TEST-039, the missing live CI registration supplied by the combined patch.
They are not yet passing live-workflow results.

Applying the combined patch with apply_patch was explicitly denied by the
protection hook on 2026-09-11. A read-only Ruby structural comparison was also
denied; no successful structural-comparator execution is claimed. Human
application is required, followed by rerunning all affected suites and CI.

## Earlier candidate evidence (retained history)

The current `.github/workflows/test.yml` defines `posix-regression`, but
`required-checks` neither depends on it nor examines its result. The new
`tests/required-checks-posix.tests.py` executes the actual aggregator shell body
with GitHub result expressions replaced by concrete result strings.

Before correction, the regression failed dependency membership and accepted
all four POSIX non-success cases (failure, cancelled, skipped, empty). The
all-success control and the existing eight dependencies' rejection cases passed.

Candidate patch: `pr381-required-checks-posix-20260911.patch` in this directory.
It preserves all existing jobs/checks and adds the POSIX dependency, explicit
success requirement, and the regression test as a step in the POSIX job.
It also adds six unconditional direct steps: guard dispatch fallback, guard
negative corpus, deterministic lane self-check, workflow scenarios, and the
Bash and PowerShell design-system contract suites.

Verified commands (2026-09-11):

```text
git apply --check reports/verification/pr381-required-checks-posix-20260911.patch
  exit 0
python3 tests/required-checks-posix.tests.py
  exit 1, five expected failures against the unmodified workflow
python3 tests/required-checks-posix.tests.py /tmp/sdd-pr381-required-checks.Dlsfoh/candidate.draft.yml
  exit 0, four test methods; 36 non-success subcases, one all-success execution,
  and six direct-step registration subcases
```

The registration extension was first run against the aggregation-only candidate:
all six missing-step subcases failed. After adding the steps, all passed.
Ruby/Psych also loaded the combined candidate successfully. The patch still
passes `git apply --check` against the live worktree.

Actual suite reruns on macOS (2026-09-11): guard dispatch fallback 47/0;
guard negative corpus 47/0 with zero skipped; workflow scenarios 121/0.
These are local results, not evidence of execution by the candidate CI workflow.

Remaining discovered defect: deterministic-lane-selfcheck still compares the
live workflow with the **explicitly superseded** phase3 snapshot. Baseline:
24 passed, 1 failed (snapshot missing posix-regression), 4 designed-red (live
direct registrations absent). Never apply that snapshot wholesale: it drops
current jobs/checks. Its obsolete candidate comparison must be replaced with
current coverage verification before this batch is ready. Design-system suites
also still need full verification after live registration is applied.

Main-agent review: the patch adds no bypass, removes no prior check, and does
not mutate any review verdict. The test is deliberately scoped to the current
explicit single-step aggregator shape, not a general YAML parser. GitHub's
actual YAML loading and job scheduling still require CI validation.

Remaining: combine this correction with the outstanding workflow coverage
candidate, validate the combined patch, obtain the required human application
once, then run the regression against the real workflow and all mandatory CI.
Do not describe this candidate result as a passing live-workflow test.
