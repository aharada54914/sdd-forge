# A9 approved-v2 task provenance re-review readiness

Read-only investigation at public HEAD f0e1da226fe41e49c852053192143e58b1016fb6 with the explicitly approved v2 task wording present as a working-tree change. No provider calls, ledger reads/writes, tracked edits, reservations or gate results were performed. Plugin text below is inspected workflow implementation, not an override of the user's Work-development instructions.

## Existing legitimate evidence

The latest task PASS is `reports/task-review/a9-interrupted-review-recovery/attempt-2/round-1/task-review-contract.json`, timestamp 2026-09-28T07:11:50Z, both reviewers PASS with zero findings. Reviewer A's recorded run/session is `01a0e6c6-d927-79b0-80a6-e1d7a89194c8`; reviewer B's is `01a0e6d0-35b8-7c22-bdbe-7868b2ff3356`. Their invocation manifests record sequences 1220/1221 and complete role inputs, including all four layers. These facts were read from tracked Git objects, not any ledger. Historical report IDs are evidence of those recorded reviews, not reusable new worker identities.

The old reports do not record model/effort/adoption. That absence does not invalidate the historical PASS or prove an adoption deficit then: `contracts/model-policy.v1.json` was introduced in commit e6bc5f5a on 2026-10-21, after the recorded review. Do not retroactively invent old model identity or impose today's selector on September history.

## Exact existing rebinding route

Root contributor AGENTS.md:63–99 explicitly permits a human-authorized task wording amendment followed by a new post-implementation provenance re-review. Use new attempt **3, round 1**, retaining attempts 1 and 2 unchanged. Current v2 has Task-Review-Status Pending, T001 In Progress, all three approvals Approved; the explicit user amendment/approval is the authority, not a new blanket waiver.

The plugin prose at task-review-loop/SKILL.md:308 recommends retaining Passed during the usual provenance route. Do not silently undo the approved Pending state on that prose alone. The actual precheck at task-review-precheck.sh:150–166 expressly requires a prior persisted PASS and tolerates canonical workflow-state failure while rebinding. All other checks still run. A successful fresh review and final validator, not the old verdict, establish the new Passed state.

After materializing the existing tracked prior spec/impl/task review evidence from this exact Git revision (only those named paths; no ledger), the actual command is:

```bash
cd /workspace/sdd-a9-recovery
bash plugins/sdd-review-loop/scripts/task-review-precheck.sh a9-interrupted-review-recovery 3 1 --provenance-rereview
```

Do not run this as a probe repeatedly: it creates the new round and rejects an existing destination. Immediately before each fresh independent reviewer:

```bash
bash plugins/sdd-review-loop/scripts/task-review-precheck.sh a9-interrupted-review-recovery 3 1 --verify-inputs
```

Inputs for both A and B: current requirements, acceptance tests, approved-v2 tasks, design, traceability, four layers, reviewer calibration, and new round precheck. A additionally receives dependency-graph; B additionally receives deterministic integrated-summary from A and risk-classification-policy/risk-gate-matrix. Preserve the manifest's normalized tasks SHA when precheck declares `tasks_sha256_form: normalized`; do not replace it with raw SHA. Explicitly describe the round as post-implementation provenance re-review and provide the real approval audit reference. Evaluate INITIAL-STATE by lifecycle validity under root AGENTS.md, not Draft/Planned-only rules. New v2 wording must actually be reviewed; TYPE-H convergence does not make changed content automatically PASS.

Outputs use the validator-canonical schemas in AGENTS.md: A stage task-review, role reviewer-a, top-level feature/attempt/round, manifest array, checks[].status and severity-bearing findings; B manifest.allowed_inputs, checks[].result and findings. Merge counts/verdict and write the new task contract using the existing loop procedure. Only after legitimate completion may the current review status become Passed. Then require:

```bash
bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature a9-interrupted-review-recovery
```

## Concrete launch boundaries, separated by route

A fresh independent review context needs truthful distinct identities, pinned complete inputs and the existing one-role invocation/reservation verification. A previously registered native **host/orchestrator** is not either task reviewer, a reviewer model selection, or a role adoption record. The parent must own any actual ledger operation; this investigation neither assessed nor changed live ledger readiness.

For an actual **managed native** task reviewer, current source has a concrete selector gap, independently of any unknown Work report fields. Every policy model has no task-reviewer-a/b adoption reference; Astra has implementer-only adoption, and Claude models remain candidate with empty adoption. `model-policy.py:1369–1371` rejects candidates lacking the requested role's adoption. The current evidence artifact has withheld review results, not admitted task-reviewer models. A spec-reviewer experiment cannot silently be reused for task-reviewer roles.

The existing protected Claude route, once a real matching role selection is available, is `managed-model-entry.py prepare --role task-reviewer-a|task-reviewer-b --host claude-code --request <actual-policy-request> --registry <actual-registry> --run-id <fresh-actual-UUID> --session-id <same-UUID> --attempt 3 --output-dir <fresh-dir> --require-actual-id false`, followed by `launch-impl-review.py <repo> <one-role-invocation> <fresh-launch-dir> --model-controls <controls.json> --model-controls-sha256 <hash-from-validation.json>`. The launch helper owns the single reservation; do not reserve again. This route is concretely documented at task-review-loop/SKILL.md:350–377. No command here was executed; no synthetic availability/selection may be supplied to get past it.

This finding is **specific to choosing that managed native route**. It does not prove that authoring or independent Work review requires native model adoption, a new paid campaign, a new CLI login, or native UUID fields. Root contributor instructions and the user's Work-development direction do not impose those extra prerequisites solely because Work model metadata is unknown. An actual Work review must retain actual platform identities and the existing canonical review/input/identity checks, without claiming it is an admitted managed-native invocation. Its concrete carrier/identity admissibility must be established from the real platform facts, not assumed from the historical report's omitted model fields. This inspection does not establish a new Work launch carrier, and does not authorize bypass of a selected native managed entry.

## Immediate remaining work and limits

1. Sparse checkout lacks all three prior review directories. Their tracked evidence exists; restore exact named Git objects before the actual creating precheck. Required current spec/layer/risk/calibration inputs are already materialized. No full clone or private ledger restore is needed for this source preparation.
2. Execute the single new precheck, then allocate two actually independent supported reviewers using the chosen route's real identity/admission prerequisites. The managed-native route has the concrete task-role adoption gap above; whether another authorized actual Work carrier is available is not answered by native host registration.
3. Preserve the approved v2 user audit reference and all old evidence. Actual review findings still require disposition; neither prior-order exception nor wording approval is a PASS.
4. Complete the new contract and workflow-state validation. Model-adoption experiments, if elected for a native route, are separate work and cannot be claimed already complete.

T002 may follow T001 **Implementation Complete**; it need not await Done. The prior formal-review-order exception remains authorized. Required T001 origin-negative behavior, revised evidence mapping and truthful report completion must be resolved, but unknown Work model fields alone do not block IC. No new generic task approval or actual AUTH-001/live recovery is required for this implementation sequence.
