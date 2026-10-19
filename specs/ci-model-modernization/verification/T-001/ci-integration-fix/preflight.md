# RT014 implementation preflight — recorded before production edits

Authority: RT-20261019-014 and root task scope. Same T-001 implementation context, new pinned readonly input snapshot. Original A9 report remains frozen.

## Diagnosis and chosen caller shape

Current verifier_job accepts exactly one run; plan_inventory additionally only recognizes the legacy verifier or aggregate argv. A standalone collector's actual API snapshot sees itself running, so C correctly reports its ordinary selected obligation evidence-missing. A second collector repeats the cycle. Combining collection into C.aggregate would change the passed C public API and is unnecessary. The selected bounded compatibility repair admits preparation within the existing control job, then the unchanged final aggregate; it adds no generic control role or exemption.

The exact positive fixture is prepared_verifier in tests/verification-ci-plan.tests.py. Root confirmed routine names before production: ci-plan output plan_artifact_name; tested checkout ref github.sha, fetch-depth 0, persist false; contents/actions read; GH_TOKEN=github.token only on download/collect; PLAN_ARTIFACT_NAME=needs.ci-plan.outputs.plan_artifact_name only on download; API_HEAD_SHA=github.event.pull_request.head.sha || github.sha only on final aggregate. No output artifact upload or new action is included. Same-run original-planning-attempt data acquisition is still checked by the unchanged plan/aggregate consumer; this admission does not label the plan artifact itself execution proof.

The inherited global env is either absent (hermetic fixture) or the unchanged current GIT_CONFIG_COUNT=1, GIT_CONFIG_KEY_0=core.longpaths, GIT_CONFIG_VALUE_0=true string mapping. Unknown inherited execution env/defaults and unknown job/step execution modifiers fail closed for the new shape. Actual workflow adoption remains T-003.

## Persisted field / counterpart / failing mismatch matrix

| Persisted or interpreted field | Counterpart | Test |
|---|---|---|
| control.id | Digest of exact job/matrix/step identity; no workload result ID fabricated | PreparedVerifierTests.test_exact_preparation_is_control_with_all_projection_counterparts; per-leaf name mutation |
| control.job/matrix/runner | required-checks/empty matrix/Ubuntu; all workload/native identities retained | test_exact_preparation_is_control_with_all_projection_counterparts; strategy/job identity mutations; test_live_workload_and_a9_inventory_survives_preparation |
| control.step/order | Exact three preparation names followed by sole final aggregate; one pinned tested checkout first | test_every_preparation_field_order_and_hidden_work_mutation_is_rejected: deletion, duplication and all ten step swaps |
| control.command_sha256 | Canonical run/shell/merged env projection; cwd enforced exactly repository root independently of digest | test_exact_preparation_is_control_with_all_projection_counterparts; test_live_workload_and_a9_inventory_survives_preparation; every argv token, shell/cwd/env mutation |
| control.suites/receipt_required/disposition | Empty suites/false/orchestration-verifier; no control PASS, omission or receipt | test_exact_preparation_is_control_with_all_projection_counterparts; test_actual_collect_aggregate_has_no_control_completion_cycle |
| workload obligations/results/full omissions | Existing workload multiset and zero full omissions; only completed actual workload observations count | test_live_workload_and_a9_inventory_survives_preparation; actual collector/aggregate successor and predecessor controls |
| job needs/condition/name/permissions | All other job IDs uniquely required including ci-plan; always/required-checks/contents+actions read | test_every_preparation_field_order_and_hidden_work_mutation_is_rejected |
| checkout setup | Only current full-SHA actions/checkout, github.sha tested tree at root, fetch-depth 0, persist-credentials false | every checkout leaf/key/additional-run/action mutation; extra-action negative |
| parser setup | One exact npm ci --prefix mcp/sdd-forge-mcp --ignore-scripts, Bash/root; lock-driven parser only | argv mutation per token; substitutions/composition/hidden-test negatives |
| plan data acquisition | Exact gh same-run download; repo/run standard env; original ci-plan output artifact_name; fixed scratch target | argv/token/env/flag mutations; Root installed gh help observation supplies supported syntax only |
| collector preparation | Unchanged C collect argv; exact current repo/run; fixed scratch observations; no standalone exemption | test_actual_collect_aggregate_has_no_control_completion_cycle and test_predecessor_collector_still_requires_actual_completion |
| aggregate execution | Unchanged aggregate_command grammar; exact prepared final argv and immutable API-head env | old sole-aggregate positive and composed/replaced command negative; prepared argv mutation |
| execution modifiers/inherited env | Bounded job/step fields; absent defaults; only unchanged current global Git config env or empty fixture env; tokens restricted to acquisition steps | workflow/job/step env injection (BASH_ENV,ENV,PYTHONPATH,PYTHONHOME,NODE_OPTIONS,PATH,RUNNER_TEMP,run/repo identity,GH_TOKEN,PLAN_ARTIFACT_NAME); container/services/defaults/unknown keys |
| A9 projection and ordinary legacy control | Existing exact A9 jobs/global env and old sole aggregate interpretation retained | test_live_workload_and_a9_inventory_survives_preparation; existing A9 suite; test_old_sole_aggregate_and_arbitrary_job_boundaries_remain |

No schema field is added. Existing control command_sha256 hashes run/shell/env; cwd remains exactly root through admission. Existing P/C serializers, catalog, workflows and schemas are read-only. No live network, credential inspection, workflow run or hosted artifact download occurs.

## Red outcome

Six new test methods executed against unchanged W. Three desired successor positives fail at the actual current admission boundary with ValueError: workload or extra run step in orchestration verifier (direct verifier; live inventory; actual P.make_plan before C.collect/C.aggregate fixture). The other three tests pass: 219 bounded mutation variants at each of two admission boundaries (438 checks), old sole-aggregate/hidden-work control, and actual standalone predecessor collection still FAIL/evidence-missing alongside seven completed workload PASS rows. Those negative branches are initially conservatively rejected by the old run-count gate; Green must execute them after the desired valid successor is accepted. No missing helper/signature/syntax failure is credited as Red.

The C AggregateFixture is instantiated as a helper; no C test class or existing test methods are inherited. The unchanged C 52-test suite runs separately after GO. Synthetic fixture commits are test data, not a shared repository commit or hosted proof.

## Scope and next step

Only tests/verification-workflow.py and tests/verification-ci-plan.tests.py may change, plus this task-local evidence. Parent owns statuses/ticket/ledger, checkpoint commits and final scoped self-review. Root must commit the Red checkpoint and send GO before production changes. Final independent full T001 review is cycle10 under existing authorization; this implementer makes no quality verdict.
