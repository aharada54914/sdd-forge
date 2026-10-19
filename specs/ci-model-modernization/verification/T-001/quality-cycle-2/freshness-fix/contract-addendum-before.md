# T-001 CI plan and activation-proof contract addendum

This is a non-frozen implementation addendum, not an amendment to the approved
specification. Root clarified the proof detail and narrow verifier boundary during
this implementation. T-002 owns actual execution collection/aggregation; T-003 owns
workflow conditions and wiring; T-011 owns actual hosted comparison and activation.
No live category is active. Fixture evidence in the new tests is synthetic, not hosted.

## Callable boundaries and trust

`tests/verification-impact.py --plan` implements the exact arguments in design.md.
The old CLI without `--plan` remains observational `verification-impact/v1`.
`make_plan(...)` rejects missing mandatory identities; optional unavailable PR
identities restore a bound full plan. PR head/API head and tested merge are separate.
A tested merge must have exactly `[base, head]` parents; a head checkout explicitly
records tested=head. The complete NUL diff unions merge-base→head and head→tested
resolution changes, including both rename paths. Tracked checkout dirt forces full.

For a compatible base, the bootstrap re-executes the actual base script with
`python -I -B` before loading workflow/candidate data. The base Git HEAD and
tracked source/rules bytes are checked. The shipped parser and runner are compiled
from their source bytes, not mutable bytecode caches. The digest binds the sorted
path/hash inventory of planner, workflow parser, runner, catalog, present shard
weights/wrapper/lockfile and installed parser module files. The tested catalog and
workflow separately bind the exact tested Git blobs. Base planner absence or
untrusted source cannot authorize affected mode. This is the approved reviewed-
workflow trust boundary, not an independent defense against replacement of the
entire invoking workflow. Installed parser dependencies still require the existing
locked installation; this task changes no acquisition or runner behavior.

`validate_plan(candidate, expected=independently_reconstructed_plan)` checks every
wire field against its counterpart. Without `expected` it checks syntax, uniqueness,
partition disjointness, mode constraints and digest only. T-002 must reconstruct
expectations from trusted source/revisions; it must not copy candidate fields into
`expected` or equate a valid digest with observed execution.

`plan_obligations(workflow, catalog, weights)` uses the existing bounded interpreter
and existing weighted shard algorithm. IDs hash `{job, matrix, step}`. Command hashes
use canonical `{run, shell, env}` with admitted matrix expansion, effective defaults,
merged structural environment and CRLF normalization. Working directory and all
other workflow semantics remain bound by the raw workflow digest. Unknown command
bodies/conditions stay mandatory; they are not inferred as suite execution. Explicit
build/audit omission declarations admit only the small exact npm/tsc command list.
Unknown matrix keys cannot authorize omission. Existing best-effort acquisition
steps do not become mandatory successful workload proof. A9 remains independently
activation-governed, never a performance-category omission.

## Rules and definition-only identity

The optional catalog `impact` object has schema `verification-impact-rules/v1`,
`categories`, `dependencies`, and optional `non_suite_steps`. See
`contracts/verification-ci-plan.schema.json#/$defs/impactRules`.

Each category has exact `id`, `paths`, bounded `prefixes`, `suites`, `groups`,
`active`, and `evidence`. The latter is null or
`{path, sha256, rule_sha256, baseline_revision}`. Group IDs currently correspond to
workload job IDs. Broad docs/specs/reports/plugins prefix classes are rejected;
shared/control/authorization paths take full precedence. README is an inactive
contract category retaining the existing consumer hypothesis and native/POSIX groups.
New suite registration is POSIX local and the existing fallback partition only.

Selection unions categories, then iterates declared suite dependencies and
indivisible-step membership to a fixed point, including mandatory opaque consumers.
Every unselected obligation receives `unrelated-category`; full plans omit nothing.
The rule digest covers category definitions, dependency definitions, suite invocation
metadata, profiles, explicit non-suite declarations and workflow topology. It excludes
`active` and all category `evidence` pointers/digests. It does not hash ordinary
classified product contents. Runtime catalog/workflow byte digests remain exact.

## Activation proof payload

All payloads reject undeclared fields, duplicate keys/identities, nonfinite numbers,
unsafe references and incorrect lowercase hashes. All file references are exactly
`{path, sha256}`, contained and committed in the trusted base. A source reference
in the consumer inventory instead resolves to a regular Git blob at the baseline.
The schema definitions and the producer/consumer mismatch tests are authoritative
for the following precise implementation shapes:

* `activationProof`: `{schema: verification-ci-activation/v1, category,
  rule_sha256, baseline_revision, full_plan, full_result, consumer_inventory,
  mutation_evidence}`. The last four fields are file references.
* `consumerInventory`: `{schema: verification-ci-consumers/v1,
  baseline_revision, rule_sha256, consumers}`. Each consumer is
  `{input, suites, groups, sources}`. `input` names one exact path/prefix selector;
  the suite/group declarations must match the category; nonempty unique source
  references must match actual baseline Git blobs. Every selector is covered once.
* `mutationEvidence`: `{schema: verification-ci-mutations/v1,
  baseline_revision, rule_sha256, cases}`. Each case is `{input, plan, result}`;
  the latter two are file references. Cases cover every selector, have unique
  concrete matching inputs, and reference full mutation plans/results.
* `comparisonResult` is the scoped full-run subset of the frozen
  `verification-ci-result/v1` envelope: identity fields match its plan;
  every obligation has one `{obligation_id, status, reason, job_id, source_attempt}`
  result with positive execution IDs/attempts. Status is PASS or FAIL, with
  `verified` or `execution-failed` respectively. No NOT_SELECTED result can
  satisfy full-baseline/mutation evidence. This does not implement the T-002 collector.

The baseline plan must be full at the recorded baseline commit. Its actual catalog
and workflow blobs, definition hash, and complete obligation inventory are rebound.
Its result must be complete and PASS. Each mutation must change its named input,
retain the baseline catalog/workflow/obligations, have a complete FAIL result with
at least one failure, and have every failing obligation in the predicted selection.
Empty success flags, missing consumers/cases, unrelated missed failures, changed
references and stale definition hashes cannot activate a category. Future hosted
records still require T-002 verification and T-011 source/mutation review; a synthetic
fixture satisfying this data protocol is not native execution evidence.

## Exact orchestration-verifier boundary

The aggregate cannot require a completed observation of itself while running.
`control_dispositions(...)` therefore returns a separately persisted inventory;
these rows are not plan omissions, successful workload results, or receipts.
Each row retains the full identity/command projection plus
`disposition: orchestration-verifier`.

Only job ID **required-checks**, display name **required-checks**, runner
**ubuntu-latest**, no matrix, `if: always()` (optionally expression-wrapped),
non-best-effort, with unique `needs` covering every other workflow job qualifies.
It must have exactly one unconditional, non-best-effort run step named
**Check all required tests passed**, effective Bash at repository root. Beside
that run step, only a full-SHA-pinned actions/checkout setup is admitted.

That run step must be either:

1. The exact current command/environment/shell projection SHA-256
   `6d256d00b814a57e078c113e5edea91380207aa7728e8b5bc07baefc9066f0e7`; or
2. One argv-only `python3 -B tests/verification-ci.py aggregate` invocation with
   exactly the required `--root`, `--plan`, `--observations`, `--run-id`,
   `--api-head-sha` arguments and optional `--output`. Argument values are simple
   literal paths/IDs or quoted environment-variable/path forms. No duplicate
   options, newline statements, pipelines, substitution, redirection, or extra
   command is admitted. T-003 may use this narrow successor shape without changing
   workload behavior; other orchestration shapes require their own scoped tests.

A real test command appended to that body, an extra run step, changed identity,
continue-on-error, or arbitrary setup action is rejected, not silently exempted.
A differently named job receives no exemption even with identical text. No
`run_required_checks` output is emitted. T-002/T-003 must keep this job unconditional
and let GitHub establish its required status after the verifier exits. They must
not synthesize a successful completed self-observation. The three native wrappers,
all workload commands, and all four required status contexts remain unchanged.

## Acceptance and limits

The test methods cover TEST-001–015, TEST-025/026, TEST-039–054, TEST-064–066 and
TEST-078 by complete Git, wire, proof, dependency, event and inventory fixtures.
The existing impact suite retains TEST-010 shadow/compare semantics. Exact native
hosted execution, actual performance, Actions observations, cache changes, live
conditions and release are intentionally not claimed. All current categories stay
inactive. This addendum and local structural inventories cannot establish quality-
gate PASS or Done; root owns independent review and the final full suite.

## Timeout error boundary

Both the trusted planner (120 seconds) and existing YAML parser (20 seconds)
return exit 2 through the plan CLI if they time out. The exact envelope retains
`schema: verification-ci-error/v1`, `reason: input-invalid`, and a fixed message
`Planning subprocess timed out; verify local dependencies and retry.` No raw
exception command, environment, stdout or stderr is rendered. The timeout test
executes each real call site with scoped subprocess injection; it is not a
claim of a real two-minute stall or hosted execution.
