# Tasks: ci-model-modernization

Task-Review-Status: Passed

## Lifecycle and authorization

These tasks begin Draft/Planned for independent review. The user approved both CI efficiency and latest-model policy proposals on 2026-10-18, recorded in reports/verification/ci-efficiency-approval-20261018.md and reports/verification/model-selection-policy-approval-20261018.md. Record that existing authorization in approval fields only after task review passes. This is not self-approval or an extension to external protection changes, automatic merges, new providers/credentials or cloud operations.

One Approved task executes at a time in dependency order. Each has a fresh implementation context and independent quality verification; only quality-gate sets Done. Reports are reports/implementation/ci-model-modernization/T-NNN.md with Run ID, Task Attempt Count, spec revision, exact commands/results and Session Handoff. Scratch/evidence belongs under specs/ci-model-modernization/verification/T-NNN/. Frozen specifications and traceability body are never edited for outcomes; only permitted final status cells change. Record new facts, native limitations and resolutions in non-frozen addenda.

## Shared file ordering and rollback

T-001 owns CI plans and obligation interpretation; T-002 consumes them for execution evidence aggregation; T-003 wires the passed producer/verifier into CI. T-004 owns documented host discovery and observation contracts. T-005 owns immutable selection binding, resume validation and delivery identity proof using typed selection fixtures; it does not choose models. T-006 consumes both to extend the existing selector and shared role policy. T-007 owns protected transports; T-008 owns generated installed roles; T-009 owns existing freshness maintenance; T-010 owns controlled adoption; T-011 owns final activation references, docs and release. Algorithm repairs remain in their owning scope.

Dependencies follow actual contracts: T-001 → T-002 → T-003 → T-004 → T-005 → T-006 → T-007 → T-008. Maintenance T-009 consumes policy T-006; adoption T-010 consumes installed entries T-008. Final T-011 joins maintenance and adoption. The orchestrator executes one task at a time and serializes shared helper/catalog edits; there is no invented dependency between independent maintenance and adoption.

Each task captures its base and before-byte/source hashes. Its rollback restores only task-owned code/config in a disposable checkout and reruns baseline checks; never truncate identity ledgers or rewrite frozen history. CI rollback uses the force-full switch, preserving mandatory aggregate checks. Model rollback uses a validated explicit pin or the prior tested release, preserving access/identity/consent checks. Never roll back by accepting unknown execution proof.

## Acceptance ownership

The Test Ownership table assigns each TEST exactly one final owner. Shared REQ/AC references identify distinct planner/core, integration or hosted-delivery portions, not duplicate independent ownership. T-001/T-002/T-003 can pass deterministic implementation acceptance while category activation and actual hosted rollout remain explicitly T-011 work. T-004/T-005/T-006 can pass their scoped core acceptance without asserting T-010 candidate adoption or T-008 managed launch reachability. No task may claim the later task's outcome.

## T-001 Revision-bound CI plans and obligations

Approval: Approved (user-recorded 2026-10-18T20:33:18Z)
Status: Done
Risk: high
Risk Rationale: Changes externally visible CI selection or execution-evidence contracts.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-001, REQ-002, REQ-003, REQ-006

### Goal

Implement the explicit CI planning mode and its typed plan/obligation contract using the existing impact tool, bounded workflow interpreter and catalog. Own revision/dependency planning and obligation production only. Preserve legacy shadow behavior; execution evidence collection/aggregation and runner/workflow wiring belong to T-002/T-003.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- tests/verification-impact.py
- tests/verification-workflow.py
- tests/verification-catalog.json (inactive selection rules and planner test registration)
- contracts/verification-ci-plan.schema.json (new)
- tests/verification-ci-plan.tests.py (new)
- tests/verification-impact.tests.py
- tests/verification-catalog.tests.py

### Scope

Implement the explicit CI planning mode and its typed plan/obligation contract using the existing impact tool, bounded workflow interpreter and catalog. Own revision/dependency planning and obligation production only. Preserve legacy shadow behavior; execution evidence collection/aggregation and runner/workflow wiring belong to T-002/T-003.

### Done When

- All assigned acceptance branches pass with python3 -B tests/verification-ci-plan.tests.py, tests/verification-impact.tests.py and tests/verification-catalog.tests.py; preserve the existing v1 shadow/compare contract.
- Prove complete NUL-safe Git change/revision binding, actual trusted-base source/rules, dependency/indivisible-step closure, full fallback and explicit omission reasons. Initial categories remain inactive pending T-011 actual validation.
- Plan schema and emitted fields agree, definition-only activation identity excludes proof pointers, and full mode emits the complete current command/argument/shell/OS obligation inventory. Persist that baseline for T-002/T-003/T-011; unrecognized workflow syntax cannot authorize an omission.
- Unit/integration fixtures distinguish tested merge from API head and invalid selective inputs from missing mandatory execution identity. Do not collect Actions results, claim selected execution success or change runner behavior in this task.
- Capture Red→Green evidence, with failing tests committed before implementation and each persisted field/counterpart/mismatch preflight recorded before product edits; record a named independent reviewer verdict and formal quality-gate result.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, live workflow activation, model implementation, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

None

## T-002 CI execution evidence collection and aggregation

Approval: Approved (user-recorded 2026-10-18T20:33:18Z)
Status: Done
Risk: high
Risk Rationale: Changes externally visible CI selection or execution-evidence contracts.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-005

### Goal

Consume the passed T-001 plan and obligation contract to collect read-only Actions observations and validate actual job/step/native execution and existing runner receipts. Own evidence collection/aggregation only; do not change planning rules, runtime test execution or live workflow wiring.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- tests/verification-ci.py (new collector/aggregate helper)
- contracts/verification-ci-result.schema.json (new)
- contracts/verification-ci-observations.schema.json (new)
- tests/verification-ci.tests.py (new)
- tests/verification-catalog.json (aggregate test/dependency registration only)

### Scope

Consume the passed T-001 plan and obligation contract to collect read-only Actions observations and validate actual job/step/native execution and existing runner receipts. Own evidence collection/aggregation only; do not change planning rules, runtime test execution or live workflow wiring.

### Done When

- All assigned acceptance branches pass with python3 -B tests/verification-ci.tests.py plus the predecessor plan/impact/catalog regressions; aggregation independently reconciles the selected/omitted partition against the bound full workflow inventory.
- Enforce exact run/API head/tested revision/catalog/workflow/plan, selected job/step/OS completion and existing source-hashed runner receipts. Missing, malformed, duplicate, wrong-native, cancelled, failed or unexpected skipped work fails; planned omissions never become executed PASS. Preserve A9 active-success/inactive-skipped semantics.
- Collect all documented GitHub API pages and retain source attempts without exposing tokens/signed redirect queries. Validate artifact extraction paths, duplicates, symlinks and bounds. Include copied-success job observations with new API IDs/reported attempts but unchanged execution timestamps; unambiguous historical lineage and original receipts establish actual execution origin, otherwise fail.
- Keep protocol fixtures distinct from native observations; record typed result/error schemas and field/counterpart/mismatch evidence. The source-attempt interpretation is documented in reports/verification/ci-model-modernization-rerun-semantics-20261018.md; no local fixture claims hosted acceptance.
- Capture Red→Green evidence, with failing tests committed before implementation and each persisted field/counterpart/mismatch preflight recorded before product edits; record a named independent reviewer verdict and formal quality-gate result.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, live workflow activation, model implementation, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-001

## T-003 CI workflow integration and dependency reuse

Approval: Approved (user-recorded 2026-10-18T20:33:18Z)
Status: Done
Risk: high
Risk Rationale: Changes runtime selection, execution evidence or externally visible contracts.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-004, REQ-007, REQ-008

### Goal

Wire the passed planner/aggregate into the existing workflow, retaining native wrappers and exact direct commands. Integrate dependency-only caches and measured independent job partitioning; do not activate unproven change categories.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- .github/workflows/test.yml
- tests/verification-catalog.json (job/profile integration only)
- tests/verification-workflow.py (condition integration only)
- tests/ci-suite-wiring.tests.sh
- tests/verification-catalog.tests.py
- tests/verification-ci.tests.py
- tests/ci-dependency-cache.py (new only if needed for pinned package validation)

### Scope

Wire the passed planner/aggregate into the existing workflow, retaining native wrappers and exact direct commands. Integrate dependency-only caches and measured independent job partitioning; do not activate unproven change categories.

### Done When

- All assigned acceptance cases pass with workflow/fixture integration checks and existing ci-suite-wiring and catalog regression suites; preserve all original supported triggers, no path filters, four required context names and always-running aggregate.
- Use trusted-base planner execution on PRs, including first-adoption full fallback, exact run/checkout provenance and source-attempt receipt collection. Relevant plan outputs alone gate heavy work; native wrappers and integrity checks always run.
- Before/after full command/argument/shell/OS inventories match; any moved cloud/native group retains its exact obligation and aggregate/catalog registration. Use saved actual timing measurements to justify the partition.
- Validate pinned dependency bytes after cache hits; OS/runtime/lock/digest keys and event scopes remain separated. Bounded acquisition retries retain failure logs and never retry failed assertions. PR cancellation is scoped to workflow and PR number; non-PR runs do not cancel one another.
- Capture Red→Green evidence, with failing tests committed before implementation and each persisted field/counterpart/mismatch preflight recorded before product edits; record a named independent reviewer verdict and formal quality-gate result.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-002

## T-004 Documented model discovery and observations

Approval: Approved (user-recorded 2026-10-18T22:19:50Z)
Status: Done
Risk: high
Risk Rationale: Changes model observation, immutable identity evidence or externally visible selection contracts.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-012

### Goal

Implement documented read-only host discovery and strict scoped availability observation normalization. Own discover and observation validation only; model choice, binding, launch and adoption are downstream.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- contracts/model-observation.schema.json (new)
- contracts/model-policy-error.schema.json (new common error envelope)
- plugins/sdd-implementation/scripts/model-policy.py (discover/observation functions only)
- tests/model-observation.tests.py (new)
- tests/verification-catalog.json (observation suite/dependency entries only)

### Scope

Implement documented read-only host discovery and strict scoped availability observation normalization. Own discover and observation validation only; model choice, binding, launch and adoption are downstream.

### Done When

- AC-012 and all assigned TEST branches pass with python3 -B tests/model-observation.tests.py, including complete pagination, partial/duplicate/cursor-loop failures, stale data and changed client/account/provider/CLI context.
- Perform actual Codex model/list discovery without starting a turn, record sanitized CLI/schema/source/time and exact capability response scope, and validate diagnostic versus launch observation provenance. Never read credentials or claim listing proves inference access.
- Provide explicit unavailable/incomplete states for undocumented or unsupported native interfaces; verified configuration is distinctly labelled and cannot satisfy a consumer requiring live discovery. No unnecessary SDK or universal endpoint is added.
- Publish strict observation/error contracts and matching producer/validator tests for every persisted field; downstream selector and binding work consume these exact contracts without a second capability algorithm.
- Capture Red→Green evidence, with failing tests committed before implementation and each persisted field/counterpart/mismatch preflight recorded before product edits; record a named independent reviewer verdict and formal quality-gate result.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, candidate adoption, live notifications, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-003

## T-005 Immutable model binding and delivery identity

Approval: Approved (user-recorded 2026-10-18T22:19:50Z)
Status: Done
Risk: high
Risk Rationale: Changes model observation, immutable identity evidence or externally visible selection contracts.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-015, REQ-016

### Goal

Implement create-only binding/resume and actual host delivery/reroute verification for typed selection records. Own bind and verify-delivery and their reusable validation functions; consume schema-valid selection fixtures without choosing a model or launching inference.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- contracts/model-selection.schema.json (new)
- contracts/model-delivery.schema.json (new)
- plugins/sdd-implementation/scripts/model-policy.py (binding/resume/delivery functions only)
- tests/model-identity.tests.py (new)
- tests/verification-catalog.json (identity suite/dependency entries only)

### Scope

Implement create-only binding/resume and actual host delivery/reroute verification for typed selection records. Own bind and verify-delivery and their reusable validation functions; consume schema-valid selection fixtures without choosing a model or launching inference.

### Done When

- All assigned acceptance branches pass with python3 -B tests/model-identity.tests.py plus observation regressions. Bind requested/resolved configuration, effort, run/session/attempt and source hashes; retain identical resume and reject changed-model/effort reuse without a new attempt.
- Atomic create-only records and all field/counterpart mismatches are tested. Configured Codex Thread.model is never promoted into per-turn actual_id; scoped reroutes/mismatches invalidate pinned unchanged-model claims, and unrelated events cannot alter the run.
- A consuming gate requiring actual-ID proof blocks if unavailable; ordinary permitted delivery can record actual_id null/unverified with no stronger claim. Preserve the consumer contract and historical bytes; do not implement model choice or grant permission.
- Expose the typed unbound/bound selection and delivery validators for T-006 resolution and T-007 transports. Actual fixed model/skill comparison executions are owned by T-010 through TEST-103/104; this task proves only record binding and identity behavior.
- Capture Red→Green evidence, with failing tests committed before implementation and each persisted field/counterpart/mismatch preflight recorded before product edits; record a named independent reviewer verdict and formal quality-gate result.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, candidate adoption, live notifications, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-004

## T-006 Role policy and current model resolution

Approval: Approved (user-recorded 2026-10-18T22:19:50Z)
Status: Done
Risk: high
Risk Rationale: Changes model observation, immutable identity evidence or externally visible selection contracts.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-011, REQ-013, REQ-014, REQ-016, REQ-019

### Goal

Extend the existing Bash/PowerShell capability selector with policy-aware configuration and current verified candidate resolution, consuming T-004 observations and T-005 immutable record/resume functions. Own selection only; no discovery protocol, delivery parser, managed launch or candidate promotion.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- contracts/agent-model-capabilities.v2.json
- contracts/model-policy.v1.json (new)
- contracts/model-policy.schema.json (new)
- contracts/model-policy-request.schema.json (new)
- contracts/model-role-config.schema.json (new)
- plugins/sdd-implementation/scripts/select-agent-model.sh
- plugins/sdd-implementation/scripts/select-agent-model.ps1
- plugins/sdd-implementation/scripts/model-policy.py (configuration normalization/selection integration only; no competing tier algorithm)
- tests/model-policy.tests.py (new)
- tests/agent-model-routing.tests.sh
- tests/agent-model-routing.tests.ps1
- tests/verification-catalog.json (selection suite/dependency entries only)

### Scope

Extend the existing Bash/PowerShell capability selector with policy-aware configuration and current verified candidate resolution, consuming T-004 observations and T-005 immutable record/resume functions. Own selection only; no discovery protocol, delivery parser, managed launch or candidate promotion.

### Done When

- All assigned acceptance branches pass with python3 -B tests/model-policy.tests.py and existing Bash/PowerShell routing regressions; validated configuration precedence, explicit pin/conflicts, current lifecycle/role/access intersection, budget units and unknown successors match the frozen contracts.
- Reuse existing role/risk/escalation/effort rules, explicit native mappings and the passed observation/binding validators. Preserve v1/v2 legacy callers and historical IDs/evidence, and reject malformed shadowed supported inputs. Unknown price stays unknown; no fabricated zero-cost candidate or automatic max/ultra/delegation.
- Complete both operator-level and cmdlet/language-level PowerShell case-sensitivity sweeps with a mis-cased negative fixture per layer. Prove supported and unsupported host boundaries without treating adapter fixtures as native execution.
- Emit a schema-valid selection and honor the T-005 resume contract. New candidates remain unadopted until T-010 behavior evidence; existing verified current candidates may remain eligible. Actual role environment/native agent/installed launch reachability belongs to T-007/T-008.
- Capture Red→Green evidence, with failing tests committed before implementation and each persisted field/counterpart/mismatch preflight recorded before product edits; record a named independent reviewer verdict and formal quality-gate result.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, candidate adoption, live notifications, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-005

## T-007 Protected model launch and delivery

Approval: Approved (user-recorded 2026-10-18T22:19:50Z)
Status: Done
Risk: high
Risk Rationale: Changes runtime model transport, protected launch integration or installed managed entry contracts.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-011, REQ-014, REQ-018, REQ-019

### Goal

Integrate the T-006 immutable selection with protected review launch/validation, delivery/run-record emission and the existing optional panelist transports. Own transport enforcement only; generated role/installer/user-automation entry reachability is T-008 work.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- plugins/sdd-review-loop/scripts/launch-impl-review.py
- plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py
- plugins/sdd-implementation/scripts/model-policy.py (launch-binding integration only)
- plugins/sdd-quality-loop/scripts/emit-run-record.sh
- plugins/sdd-quality-loop/scripts/emit-run-record.ps1
- plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh and run-panelist-gpt.ps1
- plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh and run-panelist-gemini.ps1
- tests/model-policy-launch.tests.py (new)
- tests/quality-nontty-transport.tests.py
- tests/verification-catalog.json (transport suite/dependency entries only)

### Scope

Integrate the T-006 immutable selection with protected review launch/validation, delivery/run-record emission and the existing optional panelist transports. Own transport enforcement only; generated role/installer/user-automation entry reachability is T-008 work.

### Done When

- All assigned acceptance branches pass through transport unit/integration tests, both shell families and existing paired non-TTY/record/panelist regressions; CLI/configured model values reach real supported transport arguments or are explicitly rejected.
- Both specification/design/task reviewer transports and the quality evaluator consume bound role selection while preserving fresh context, canonical read-only/input/identity reservation, paired validator agreement and host-specific floors. Native precedence conflicts fail or are safely aligned; no static comment can prove a transport selection.
- GPT/Gemini optional transports retain existing per-vendor consent and record selected/resolved/actually reported identity separately. Run records bind the immutable selection and report unavailable telemetry honestly; no test sends live external panelist content without existing consent.
- Demonstrate the supported native Codex transport with an actual selected configuration and honest proof level. Claude/Copilot/Gemini unavailable native execution remains explicit; deterministic adapter fixtures are labelled. Installed role entry proof and complete maintained-caller inventory closure belong to T-008, not this transport-only acceptance.
- Capture Red→Green evidence, with failing tests committed before implementation and each persisted field/counterpart/mismatch preflight recorded before product edits; record a named independent reviewer verdict and formal quality-gate result.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, freshness maintenance, candidate adoption, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-006

## T-008 Managed role rendering and installed entries

Approval: Approved (user-recorded 2026-10-18T22:19:50Z)
Status: Done
Risk: high
Risk Rationale: Changes runtime model transport, protected launch integration or installed managed entry contracts.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-011, REQ-014, REQ-018, REQ-019

### Goal

Integrate generated role definitions and installation, then connect maintained skill and automation entries to the passed T-007 protected transports. Own current role/render/install/entry surfaces; do not change transport algorithms, freshness notification behavior or candidate adoption.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- render-agent-frontmatter.sh
- render-agent-frontmatter.ps1
- plugins/*/agents/* and copilot-agents/* (affected current roles only)
- .codex/agents/sdd-*.toml
- plugins/sdd-implementation/skills/diagnose/SKILL.md
- plugins/sdd-domain/skills/domain-review-loop/SKILL.md
- affected implementation/investigation/review/auditor skill instructions (managed invocation only)
- .github/workflows/self-improvement.yml
- install.sh and install.ps1 (affected packaging only)
- tests/model-policy-installed.tests.py (new)
- tests/render-agent-frontmatter.tests.sh
- tests/render-agent-frontmatter.tests.ps1
- tests/install.tests.sh
- tests/install.tests.ps1
- tests/verification-catalog.json (installed-entry suite/dependency entries only)

### Scope

Integrate generated role definitions and installation, then connect maintained skill and automation entries to the passed T-007 protected transports. Own current role/render/install/entry surfaces; do not change transport algorithms, freshness notification behavior or candidate adoption.

### Done When

- All assigned acceptance branches pass through renderer/installer and installed-entry integration tests. Existing protected-file/human-copy procedures remain honored through sanctioned current addenda; historical manifests are not overwritten.
- Implementation, investigation, domain reviewers A/B, workflow auditors A/B, diagnosis and scheduled/manual self-improvement resolve role policy and pass it through T-007 transports. Generated host-native fields and Copilot agent precedence match selection; comments alone fail the test. Existing schedules, secrets, permissions and external-send controls remain unchanged.
- Close the complete semantic caller inventory from reports/verification/model-selection-callers-20261018.json and INV-014, including installed Bash/PowerShell paths: every maintained runtime consumer is migrated or explicitly unsupported with tested typed behavior. Treat T-007 transport proofs as predecessor evidence; do not reimplement their algorithm.
- Demonstrate one actual installed supported host entry resolving its selected model and record its configured-versus-actual proof level; label fixture-only/noninstalled hosts accurately. Verify role separation and protected preflight remain effective through the installed entry. Candidate adoption is T-010 work.
- Capture Red→Green evidence, with failing tests committed before implementation and each persisted field/counterpart/mismatch preflight recorded before product edits; record a named independent reviewer verdict and formal quality-gate result.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, freshness maintenance, candidate adoption, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-007

## T-009 Existing model freshness maintenance

Approval: Approved (user-recorded 2026-10-18T22:19:50Z)
Status: Done
Risk: high
Risk Rationale: Changes untrusted-source parsing and existing external notification controls.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-017

### Goal

Extend the existing weekly/manual model freshness job to report source-dated candidate discoveries, deprecations and fetch failures against the shared policy, retaining its current schedule, deduplication and notification authority. No model adoption or managed-launch changes.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- .github/scripts/check-model-freshness.sh
- .github/workflows/model-freshness-check.yml
- tests/model-freshness-check.tests.sh
- tests/model-freshness-check.tests.ps1
- tests/verification-catalog.json (maintenance dependency entries only)

### Scope

Extend the existing weekly/manual model freshness job to report source-dated candidate discoveries, deprecations and fetch failures against the shared policy, retaining its current schedule, deduplication and notification authority. No model adoption or managed-launch changes.

### Done When

- AC-017 / TEST-111 through TEST-115 pass with Bash/PowerShell locking suites and fixture-driven protocol integration; failed fetches, candidate/deprecation differences, duplicate notifications and untrusted text have observable distinct outcomes.
- Preserve Monday 03:00 UTC and manual triggers, current issue markers/deduplication, existing permission scope and human adoption. Tests replace gh/network with controlled fixtures and do not create live issues or comments.
- Consume the T-006 shared policy/catalog with source/date provenance; fetched prose is never executed and registry files are never rewritten. Preserve existing fail-soft source-unavailable behavior without falsely claiming a successful fresh catalog.
- Publish exact commands/results and policy consumer/dependency mapping; confirm no new provider account, secret, SDK, scheduler or automatic merge.
- Capture Red→Green evidence, with failing tests committed before implementation and each persisted field/counterpart/mismatch preflight recorded before product edits; record a named independent reviewer verdict and formal quality-gate result.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-006

## T-010 Controlled model adoption evaluation

Approval: Approved (user-recorded 2026-10-18T22:19:50Z)
Status: In Progress
Risk: medium
Risk Rationale: Runs controlled evaluation and updates reviewed adoption references without changing capability or authorization algorithms.
Required Workflow: acceptance-first
Data Migration: None
Breaking API: No
Requirements: REQ-013, REQ-015, REQ-019

### Goal

Execute the pre-output candidate/baseline evaluation rubric and promote only the passing role-specific candidates through adoption evidence references. Own evaluation fixtures, actual experiment outputs and adoption metadata; no selector, capability, launcher or maintenance algorithm changes.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- reports/verification/model-selection-adoption-rubric-20261018.md (preserve frozen pre-output rubric; version later experiments separately)
- specs/ci-model-modernization/verification/T-010/ (fixtures, raw/scored outputs and scoped evidence)
- contracts/model-policy.v1.json (verified lifecycle/preferences/adoption references only)
- tests/model-policy.tests.py (adoption-reference regression fixtures only)

### Scope

Execute the pre-output candidate/baseline evaluation rubric and promote only the passing role-specific candidates through adoption evidence references. Own evaluation fixtures, actual experiment outputs and adoption metadata; no selector, capability, launcher or maintenance algorithm changes.

### Done When

- AC-013 / AC-019 and assigned TEST-103, TEST-104 and TEST-127: execute the prepared rubric with two fresh repetitions per model/case, identical prompt/fixture/effort/budget within each model comparison and a fixed blinded judge if used. Keep model labels/rubric outside candidate contexts; judge actual artifacts and held-out tests rather than self-report.
- Rediscover the actual installed host/CLI availability before trials; preserve configured/resolved versus actual-ID proof scope and scoped reroutes. Distinguish native model/host observations from adapter fixtures; unavailable other providers are not fabricated comparisons.
- Promote only roles satisfying every frozen rubric criterion in both repetitions with no material baseline regression. Failed candidates remain update candidates with retained results; any new experiment versions inputs instead of erasing failures. Existing verified current candidates may remain eligible.
- Validate the resulting policy/adoption path+hash references with the T-006 selector and model-policy regression suite, preserve historical IDs/evidence and explicit pinning, and record every adopted or withheld role plus its source/date and limitation.
- Actual model/list data is availability only. Model comparison holds prompts and judge fixed; the actual skill comparison holds the model fixed and changes only the skill under a separately versioned pre-output rubric, keeping the original model-adoption rubric unchanged. No live provider notification, cloud action, credential change or parent UI-model control occurs.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### External execution prerequisite and retained history

Attempt-1 recorded 20 accepted native requests that failed authentication before generation, with zero candidate outputs; preserve `verification/T-010/attempt-1/bounded-status-summary.json` and its source-bound receipts. Any later comparison requires an authenticated host, fresh scoped availability and separately versioned admitted inputs. This is retained attempt history, not a mutable statement of current authentication status; the Status field and later evidence govern progress. This note authorizes no credential change.

### Out of Scope

Other task-owned changes, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-008

## T-011 Verified rollout documentation and immutable release

Approval: Approved (user-recorded 2026-10-18T22:19:50Z)
Status: In Progress
Risk: high
Risk Rationale: Readiness repairs change runtime obligation selection, workflow context/cache binding and installer payload boundaries; require tests-first Red/Green, conservative unknown handling, platform and runtime dependency parity, compatibility review and subset rollback before measured rollout.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-004, REQ-006, REQ-009, REQ-010, REQ-020

### Goal

Publish measured rollout evidence and complete current user/contributor documentation for the already verified implementation; activate only proven categories and release one exact-tested immutable version. No main merge, tag move or live cloud operation is included.

### Must Read

- requirements.md, acceptance-tests.md, design.md, investigation.md, traceability.md and all four layer specs
- ../../AGENTS.md, the two current ADRs and current callers/contracts before edits

### Planned Files

- tests/phase2-guard-invariants.tests.sh and tests/phase2-guard-invariants.tests.ps1 (current ci-plan predicate and explicit ship successor checks)

- .github/workflows/test.yml (legal npm-cache context binding and actual CI validation)
- tests/verification-catalog.tests.py (workflow cache-context regressions)
- install.sh and install.ps1 (shared explicit distribution boundary for local and archive inputs)
- install-payload.txt (runtime file and directory allowlist, distributed with installers)
- tests/install.tests.sh and tests/install.tests.ps1 (payload, upgrade and required-runtime regressions)
- tests/lib/install-payload-check.py (shared assertion helper invoked by existing Bash/PowerShell installer suites)
- tests/model-policy-installed.tests.py and tests/install-cloud.tests.py (minimal install fixtures include the payload manifest)
- tests/loop-consistency.tests.sh and tests/loop-consistency.tests.ps1 (current anchor coordinates, preserving historical content hashes)
- tests/sdd-domain-multitarget-foundation.tests.py and specs/sdd-domain-multitarget/verification/T-001/current-consumer-inventory.json (current references and planner-dependent fixture)
- tests/ship-track-selection-migration.tests.sh and tests/ship-track-selection-migration.tests.ps1; tests/fixtures/ship-track-selection-current-publication.json (successor publication regression with historical evidence preserved)
- PLUGIN-CONTRACTS.md, docs/THREAT-MODEL.md, docs/architecture/overview.md, docs/cloud-orchestration.md and docs/contributor/weekly-local-codex-audit.md (installed documentation references and current installer contract)
- README.md
- CHANGELOG.md
- docs/verification.md
- docs/agent-capability-matrix.md
- docs/workflow-guide.md
- docs/contributor/workflow-detail.md
- docs/contributor/release-runbook.md
- affected plugin README and CLI/installer/model-maintenance guidance
- tests/verification-catalog.json (one exact cli-hook-enforcement setup classification and activation proof references)
- tests/verification-impact.py (bounded omission-readiness selection/parser correction)
- tests/verification-ci-plan.tests.py (tests-first focused readiness regressions)
- contracts/verification-ci-plan.schema.json (setup declaration kind counterpart)
- reports/verification/ci-model-modernization-*
- plugin/marketplace version manifests through existing release tooling

- scripts/human_copy_mirrors.py and tests/human-copy-mirrors-classification.tests.py (exact reviewed successor publication without changing historical snapshots)
- tests/human-copy-mirror-freshness.tests.sh and tests/human-copy-mirror-freshness.tests.ps1; tests/workflow-state-ci-integration.tests.sh; tests/fixtures/capability-resolver/caller-contract-baseline.json (current predicate and unchanged-anchor references)
- plugins/sdd-quality-loop/references/guard-invariants.json and its four scripts/generated/guard invariant outputs (protect newly chain-invoked entries); tests/guard-parity.tests.sh (protection and negative controls)
- tests/a9-advisory-evidence.tests.py (fixture-local Git maintenance); tests/cloud-orchestration-routing.tests.py (actual cloud-native dependency and coverage boundary); tests/model-policy.tests.py (native Windows Bash harness, coordinated with T-010 adoption tests)

### Scope

User-authorized continuation on 2026-10-21: complete remaining work 1–7 and audit installed plugin contents. Correct the observed pre-job GitHub Actions context rejection and unnecessary repository-history distribution in both installers, including archive/local parity and minimal MCP bundles. Preserve all required plugin/shared runtime dependencies, existing installation authorization and atomic rollback semantics. These additional corrections remain part of the named independent implementation review and final exact-revision verification. Actual full hosted run 39598838307 additionally exposed missing pinned YAML-parser dependencies in cloud-native, Windows test-runtime resolution, runtime-cache and disposable-Git cleanup interference, current mirror/anchor/predicate drift, and omitted chain-invoked files in the canonical protection registry. Correct these observed causes within this continuation; preserve all protection behavior and immutable historical evidence.

Root-authorized necessary continuation: integrate the reviewed bounded omission-readiness correction independently of T-010 execution. Final rollout, model adoption and immutable release remain blocked on T-010; this scope amendment does not mark either task Done or waive any acceptance case. Existing approval timestamp is preserved.

Publish measured rollout evidence and complete current user/contributor documentation for the already verified implementation; activate only proven categories and release one exact-tested immutable version. No main merge, tag move or live cloud operation is included.

### Readiness bugfix diagnostic path (TEST-017)

- Reproduce the original failure with the retained pre-correction workflow/catalog/source bytes: the real `readme-contract` category produces 443 full obligations and 443 selected obligations, omitting nothing, although unrelated CLI-hook work should be omittable only after its source-consumer and native proof passes. Preserve the actual command, source hashes and observed-versus-expected result; dry enumeration does not satisfy hosted TEST-017.
- Verify the causal boundary before choosing the minimal correction: trace validated generated `ci-plan` predicates returning unknown from `condition_value`, plus the undeclared exact CLI setup command forcing mandatory work. Use the recorded before bytes and regression controls to distinguish those causes from truly unknown predicates, missing matrix values or an unrecognized raw command, which must remain mandatory. Record producer/counterpart/mismatch evidence, including the old-parser/new-setup typed rejection rather than claiming a full fallback.
- Link diagnosis to the four tests-first regressions in `tests/verification-ci-plan.tests.py`; retain the meaningful baseline Red, the full prior50 plus new4 Green, source-consumer proof and exact subset rollback. Reuse the timestamped diagnostic and before-source records in `verification/T-011/preparation/rollout-comparison/` and `verification/T-011/readiness-implementation/`; this post-implementation provenance repair does not backdate or replace them.

### Additional correction diagnostics and chronology

- Before selecting the installer correction, retain source-bound measured inventories and trace unwanted specs/reports/tests/ledger files to the local Git-tracked broad-copy and remote recursive archive-copy producers in both installers. Inspect actual runtime callers and shared/plugin/contract/rendering/document dependencies to distinguish required payload from development records. Trace MCP recursive dist copying against the actual esbuild output and runtime entrypoint. Link those causal findings and before-source hashes to local/archive, upgrade, rollback and installed-caller controls; private candidate preparation is not product application.
- For each newly added runtime correction (workflow context/cache binding and installer payload selection), require its own meaningful failing regression, a separately identified failing-test commit before applying the product correction, source hashes, subsequent Green and subset rollback. Workflow regression commit 61e831b5f15ae24a985f77539a6f83446d14063e precedes product commit e845fbc8942b7ee496b9f9928e5ada61443048d9; record equivalent actual installer chronology before integration. Preserve real timestamps, including privately prepared candidates, without backdating. The original readiness commit does not substitute for these independent records. Require the named independent high-risk implementation verdict over each correction and the combined final scope.
- Diagnose current-test drift using exact failing commands and source hashes before fixing references or fixtures: preserve frozen historical evidence, verify unchanged anchor content, retain required ci-plan dependencies in synthetic workflows, and make successor publication checks sensitive to unauthorized current changes. Record Red/Green and disposable rollback; a reference repair must not delete a required behavior assertion. Re-run actual hosted native wrappers at the final revision.

- For the additional runtime corrections, retain separate source-bound cause and Red/Green/rollback: cloud parser setup reuses pinned Node/npm/cache conventions and existing committed parser-consumer regressions; mirror handling admits only the exact reviewed live/predecessor pair with both full hashes, keeping unknown changes rejected; protection registration adds each actual chain-invoked entry to the canonical source and regenerates all four counterparts. Commit meaningful mirror/protection regression changes before applying those product changes, retaining actual chronology. Test missing/mutated/duplicate successor pins, changed predecessor/live bytes, omitted protection entries and all platform counterparts; do not weaken scans or rewrite historical snapshots. Current test-harness fixes isolate cache/maintenance and select the intended platform runtime without excluding protected-file changes or swallowing cleanup failures. Include every added correction in the final independent high-risk implementation verdict.

### Done When

- Reproduce and retain the CI pre-job rejection: job-level `npm_config_cache` may not reference `runner.temp`. Preserve tests-first failure, move binding to a legal runtime context with the same cache path, verify all workflow syntax and real hosted startup, and retain cache key/path and platform parity.
- Reproduce the measured unnecessary installer payload (16,408 files / 189,910,946 bytes in both original local paths). Ship only the explicit runtime/user-documentation allowlist through both Git-tracked local and archive installs; exclude repository specs, reports, tests, workflow/developer state, credentials and caches. Preserve the shared plugin/contract/rendering dependencies and selection/Node gates; MCP payloads contain only required `dist/index.js` and `package.json`. Test local/archive parity, removal of old development payload on upgrade, rollback and actual installed callers on supported platforms. Record final file counts/bytes and inspect the final released installation again.
- Preserve and link the real failing-test commit `a72eab2ec5e5362f635b4814fecd9e791a300e68` committed before the readiness implementation, its recorded baseline Red, subsequent Green and product-application chronology (`verification/T-011/readiness-implementation/test-first-commit.json`, `focused-red.json`, `full54.json` and `product-apply.json`). Require a named independent reviewer verdict for the high-risk readiness correction and final task scope, with pinned reviewed inputs, requirement traceability and spec/environment provenance; an implementation report or this task-plan review cannot substitute for that implementation quality verdict. Preserve original timestamps and evidence without backdating.
- All assigned acceptance cases are linked to actual saved results. Compare docs/configuration, MCP, cloud and shared representative changes against full results and source-consumer/mutation evidence. Unproven classes remain full; record exact revision, selections, omissions, measured wall/job time and observed cache hits.
- Observe actual hosted small-change PR required contexts/native wrappers and selected omissions plus manual full execution; separate local fixtures and disclose unavailable real merge_group per OQ-001. Do not label fixture-only evidence hosted. If a required external action cannot proceed under existing authorization, record the concrete prepared action and blocker.
- Update README, capability/selector/launcher/installer/maintenance guidance, verification/contributor/release docs and CHANGELOG; validate examples and relative links and perform identifier/caller sweeps for stale current model defaults and CI claims. Preserve frozen historical records and the existing live-cloud acceptance limitation.
- Run required complete local profiles and hosted checks at the exact final committed product revision; any later product edit requires relevant repeat verification. Use existing version tooling and create a new annotated version tag only at that passing revision. Preserve v1.19.0 and all existing tag objects.
- Record the release revision, tag object/peeled commit, exact commands/results and honest pending external/native branches in a release addendum. Actual quality-gate acceptance, not implementation claims, controls Done.
- Document and test rollback in a disposable checkout, with before/after hashes and actual baseline results; retain task-local evidence and implementation report.

### Out of Scope

Other task-owned changes, external protection changes, new secrets/providers, automatic main merge, historical evidence edits and live cloud validation.

### Blockers

T-009, T-010

## Test Ownership

| Test ID | AC | Task | Planned validation |
|---|---|---|---|
| TEST-001 | AC-001 | T-001 | add/delete; exact assertion in acceptance-tests.md |
| TEST-002 | AC-001 | T-001 | rename; exact assertion in acceptance-tests.md |
| TEST-003 | AC-001 | T-001 | type/case; exact assertion in acceptance-tests.md |
| TEST-004 | AC-001 | T-001 | large diff; exact assertion in acceptance-tests.md |
| TEST-005 | AC-001 | T-001 | revision binding; exact assertion in acceptance-tests.md |
| TEST-006 | AC-001 | T-001 | fork and unusual paths; exact assertion in acceptance-tests.md |
| TEST-007 | AC-002 | T-001 | trusted base; exact assertion in acceptance-tests.md |
| TEST-008 | AC-002 | T-001 | shared files; exact assertion in acceptance-tests.md |
| TEST-009 | AC-002 | T-001 | unknown/empty/invalid; exact assertion in acceptance-tests.md |
| TEST-010 | AC-002 | T-001 | shadow compatibility; exact assertion in acceptance-tests.md |
| TEST-011 | AC-003 | T-001 | union/closure; exact assertion in acceptance-tests.md |
| TEST-012 | AC-003 | T-001 | fixture/generated; exact assertion in acceptance-tests.md |
| TEST-013 | AC-003 | T-001 | document boundary; exact assertion in acceptance-tests.md |
| TEST-014 | AC-003 | T-001 | omission mutation; exact assertion in acceptance-tests.md |
| TEST-015 | AC-003 | T-001 | unproven category; exact assertion in acceptance-tests.md |
| TEST-016 | AC-004 | T-011 | native names; exact assertion in acceptance-tests.md |
| TEST-017 | AC-004 | T-011 | optional omission; exact assertion in acceptance-tests.md |
| TEST-018 | AC-004 | T-003 | trigger integrity; exact assertion in acceptance-tests.md |
| TEST-019 | AC-005 | T-002 | positive proof; exact assertion in acceptance-tests.md |
| TEST-020 | AC-005 | T-002 | failure/cancel/skip; exact assertion in acceptance-tests.md |
| TEST-021 | AC-005 | T-002 | missing/malformed; exact assertion in acceptance-tests.md |
| TEST-022 | AC-005 | T-002 | identity/mutation; exact assertion in acceptance-tests.md |
| TEST-023 | AC-005 | T-002 | rerun; exact assertion in acceptance-tests.md |
| TEST-024 | AC-005 | T-002 | A9 activation; exact assertion in acceptance-tests.md |
| TEST-025 | AC-006 | T-001 | full events; exact assertion in acceptance-tests.md |
| TEST-026 | AC-006 | T-001 | force full; exact assertion in acceptance-tests.md |
| TEST-027 | AC-006 | T-011 | full parity; exact assertion in acceptance-tests.md |
| TEST-028 | AC-007 | T-003 | cache identity; exact assertion in acceptance-tests.md |
| TEST-029 | AC-007 | T-003 | cache recovery; exact assertion in acceptance-tests.md |
| TEST-030 | AC-007 | T-003 | cache trust; exact assertion in acceptance-tests.md |
| TEST-031 | AC-008 | T-003 | partition parity; exact assertion in acceptance-tests.md |
| TEST-032 | AC-008 | T-003 | concurrency; exact assertion in acceptance-tests.md |
| TEST-033 | AC-008 | T-003 | bounded retry; exact assertion in acceptance-tests.md |
| TEST-034 | AC-009 | T-011 | category comparison; exact assertion in acceptance-tests.md |
| TEST-035 | AC-009 | T-011 | hosted/fixture distinction; exact assertion in acceptance-tests.md |
| TEST-036 | AC-009 | T-011 | measurement; exact assertion in acceptance-tests.md |
| TEST-037 | AC-010 | T-011 | operator docs; exact assertion in acceptance-tests.md |
| TEST-038 | AC-010 | T-011 | release; exact assertion in acceptance-tests.md |
| TEST-039 | AC-001 | T-001 | case-only rename; exact assertion in acceptance-tests.md |
| TEST-040 | AC-001 | T-001 | missing base; exact assertion in acceptance-tests.md |
| TEST-041 | AC-001 | T-001 | wrong head; exact assertion in acceptance-tests.md |
| TEST-042 | AC-001 | T-001 | wrong merge; exact assertion in acceptance-tests.md |
| TEST-043 | AC-001 | T-001 | unusual paths; exact assertion in acceptance-tests.md |
| TEST-044 | AC-002 | T-001 | catalog change; exact assertion in acceptance-tests.md |
| TEST-045 | AC-002 | T-001 | workflow change; exact assertion in acceptance-tests.md |
| TEST-046 | AC-002 | T-001 | installer change; exact assertion in acceptance-tests.md |
| TEST-047 | AC-002 | T-001 | contract change; exact assertion in acceptance-tests.md |
| TEST-048 | AC-002 | T-001 | authorization change; exact assertion in acceptance-tests.md |
| TEST-049 | AC-002 | T-001 | empty diff; exact assertion in acceptance-tests.md |
| TEST-050 | AC-002 | T-001 | malformed input; exact assertion in acceptance-tests.md |
| TEST-051 | AC-003 | T-001 | generator input; exact assertion in acceptance-tests.md |
| TEST-052 | AC-003 | T-001 | AGENTS input; exact assertion in acceptance-tests.md |
| TEST-053 | AC-003 | T-001 | human-copy input; exact assertion in acceptance-tests.md |
| TEST-054 | AC-003 | T-001 | evidence input; exact assertion in acceptance-tests.md |
| TEST-055 | AC-005 | T-002 | cancelled selected work; exact assertion in acceptance-tests.md |
| TEST-056 | AC-005 | T-002 | unexpected selected skip; exact assertion in acceptance-tests.md |
| TEST-057 | AC-005 | T-002 | malformed plan; exact assertion in acceptance-tests.md |
| TEST-058 | AC-005 | T-002 | missing receipt; exact assertion in acceptance-tests.md |
| TEST-059 | AC-005 | T-002 | empty success; exact assertion in acceptance-tests.md |
| TEST-060 | AC-005 | T-002 | wrong run; exact assertion in acceptance-tests.md |
| TEST-061 | AC-005 | T-002 | changed hash; exact assertion in acceptance-tests.md |
| TEST-062 | AC-005 | T-002 | duplicate identity; exact assertion in acceptance-tests.md |
| TEST-063 | AC-005 | T-002 | wrong OS; exact assertion in acceptance-tests.md |
| TEST-064 | AC-006 | T-001 | merge_group full; exact assertion in acceptance-tests.md |
| TEST-065 | AC-006 | T-001 | release full; exact assertion in acceptance-tests.md |
| TEST-066 | AC-006 | T-001 | manual full; exact assertion in acceptance-tests.md |
| TEST-067 | AC-007 | T-003 | runtime cache key; exact assertion in acceptance-tests.md |
| TEST-068 | AC-007 | T-003 | lock cache key; exact assertion in acceptance-tests.md |
| TEST-069 | AC-007 | T-003 | tool digest cache key; exact assertion in acceptance-tests.md |
| TEST-070 | AC-007 | T-003 | corrupt cache; exact assertion in acceptance-tests.md |
| TEST-071 | AC-008 | T-003 | different PR concurrency; exact assertion in acceptance-tests.md |
| TEST-072 | AC-008 | T-003 | main concurrency; exact assertion in acceptance-tests.md |
| TEST-073 | AC-008 | T-003 | merge concurrency; exact assertion in acceptance-tests.md |
| TEST-074 | AC-008 | T-003 | release concurrency; exact assertion in acceptance-tests.md |
| TEST-075 | AC-009 | T-011 | MCP comparison; exact assertion in acceptance-tests.md |
| TEST-076 | AC-009 | T-011 | cloud comparison; exact assertion in acceptance-tests.md |
| TEST-077 | AC-009 | T-011 | shared comparison; exact assertion in acceptance-tests.md |
| TEST-078 | AC-001 | T-001 | API head versus tested merge; exact assertion in acceptance-tests.md |
| TEST-079 | AC-011 | T-006 | ordinary roles; exact assertion in acceptance-tests.md |
| TEST-080 | AC-011 | T-006 | role floor; exact assertion in acceptance-tests.md |
| TEST-081 | AC-011 | T-006 | risk escalation; exact assertion in acceptance-tests.md |
| TEST-082 | AC-011 | T-007 | cross-model consent; exact assertion in acceptance-tests.md |
| TEST-083 | AC-012 | T-004 | Codex pages; exact assertion in acceptance-tests.md |
| TEST-084 | AC-012 | T-004 | pagination failure; exact assertion in acceptance-tests.md |
| TEST-085 | AC-012 | T-004 | host identity; exact assertion in acceptance-tests.md |
| TEST-086 | AC-012 | T-004 | no discovery; exact assertion in acceptance-tests.md |
| TEST-087 | AC-012 | T-004 | stale discovery; exact assertion in acceptance-tests.md |
| TEST-088 | AC-012 | T-004 | no implicit inference; exact assertion in acceptance-tests.md |
| TEST-089 | AC-013 | T-006 | successor; exact assertion in acceptance-tests.md |
| TEST-090 | AC-013 | T-006 | unknown model; exact assertion in acceptance-tests.md |
| TEST-091 | AC-013 | T-006 | misleading name; exact assertion in acceptance-tests.md |
| TEST-092 | AC-013 | T-006 | deprecated; exact assertion in acceptance-tests.md |
| TEST-093 | AC-013 | T-006 | capability intersection; exact assertion in acceptance-tests.md |
| TEST-094 | AC-014 | T-006 | explicit pinned; exact assertion in acceptance-tests.md |
| TEST-095 | AC-014 | T-007 | role env; exact assertion in acceptance-tests.md |
| TEST-096 | AC-014 | T-007 | agent precedence; exact assertion in acceptance-tests.md |
| TEST-097 | AC-014 | T-006 | invalid policy; exact assertion in acceptance-tests.md |
| TEST-098 | AC-014 | T-006 | injection; exact assertion in acceptance-tests.md |
| TEST-099 | AC-014 | T-006 | organization allowlist; exact assertion in acceptance-tests.md |
| TEST-100 | AC-015 | T-005 | record identity; exact assertion in acceptance-tests.md |
| TEST-101 | AC-015 | T-005 | resume same model; exact assertion in acceptance-tests.md |
| TEST-102 | AC-015 | T-005 | resume changed model; exact assertion in acceptance-tests.md |
| TEST-103 | AC-015 | T-010 | fixed comparison; exact assertion in acceptance-tests.md |
| TEST-104 | AC-015 | T-010 | fixed skill evaluation; exact assertion in acceptance-tests.md |
| TEST-105 | AC-016 | T-006 | no compatible model; exact assertion in acceptance-tests.md |
| TEST-106 | AC-016 | T-006 | access loss; exact assertion in acceptance-tests.md |
| TEST-107 | AC-016 | T-005 | unknown actual ID; exact assertion in acceptance-tests.md |
| TEST-108 | AC-016 | T-005 | actual mismatch; exact assertion in acceptance-tests.md |
| TEST-109 | AC-016 | T-006 | budget unknown; exact assertion in acceptance-tests.md |
| TEST-110 | AC-016 | T-006 | older pinned label; exact assertion in acceptance-tests.md |
| TEST-111 | AC-017 | T-009 | existing schedule; exact assertion in acceptance-tests.md |
| TEST-112 | AC-017 | T-009 | fetch failure; exact assertion in acceptance-tests.md |
| TEST-113 | AC-017 | T-009 | dedupe; exact assertion in acceptance-tests.md |
| TEST-114 | AC-017 | T-009 | untrusted source; exact assertion in acceptance-tests.md |
| TEST-115 | AC-017 | T-009 | adoption boundary; exact assertion in acceptance-tests.md |
| TEST-116 | AC-018 | T-008 | Codex installed path; exact assertion in acceptance-tests.md |
| TEST-117 | AC-018 | T-007 | Claude transport; exact assertion in acceptance-tests.md |
| TEST-118 | AC-018 | T-008 | Copilot precedence; exact assertion in acceptance-tests.md |
| TEST-119 | AC-018 | T-007 | Gemini panelist; exact assertion in acceptance-tests.md |
| TEST-120 | AC-018 | T-008 | comment-only mutation; exact assertion in acceptance-tests.md |
| TEST-121 | AC-018 | T-007 | identity reservation; exact assertion in acceptance-tests.md |
| TEST-122 | AC-019 | T-006 | v1 compatibility; exact assertion in acceptance-tests.md |
| TEST-123 | AC-019 | T-006 | v2 compatibility; exact assertion in acceptance-tests.md |
| TEST-124 | AC-019 | T-006 | PowerShell parity; exact assertion in acceptance-tests.md |
| TEST-125 | AC-019 | T-006 | effort independence; exact assertion in acceptance-tests.md |
| TEST-126 | AC-019 | T-006 | historic evidence; exact assertion in acceptance-tests.md |
| TEST-127 | AC-019 | T-010 | native proof distinction; exact assertion in acceptance-tests.md |
| TEST-128 | AC-020 | T-011 | documentation; exact assertion in acceptance-tests.md |
| TEST-129 | AC-020 | T-011 | freshness source; exact assertion in acceptance-tests.md |
| TEST-130 | AC-020 | T-011 | release tag; exact assertion in acceptance-tests.md |
| TEST-131 | AC-015 | T-005 | configured versus actual identity; exact assertion in acceptance-tests.md |
| TEST-132 | AC-016 | T-005 | scoped reroute; exact assertion in acceptance-tests.md |
| TEST-133 | AC-016 | T-005 | telemetry unavailable; exact assertion in acceptance-tests.md |
| TEST-134 | AC-018 | T-008 | domain review entry; exact assertion in acceptance-tests.md |
| TEST-135 | AC-018 | T-008 | workflow auditors; exact assertion in acceptance-tests.md |
| TEST-136 | AC-018 | T-008 | diagnosis entry; exact assertion in acceptance-tests.md |
| TEST-137 | AC-018 | T-008 | self-improvement entry; exact assertion in acceptance-tests.md |
| TEST-138 | AC-011 | T-008 | implementation role; exact assertion in acceptance-tests.md |
| TEST-139 | AC-011 | T-008 | investigation role; exact assertion in acceptance-tests.md |
| TEST-140 | AC-011 | T-007 | specification-review role; exact assertion in acceptance-tests.md |
| TEST-141 | AC-011 | T-007 | design-review role; exact assertion in acceptance-tests.md |
| TEST-142 | AC-011 | T-007 | task-review role; exact assertion in acceptance-tests.md |
| TEST-143 | AC-011 | T-007 | quality-evaluator role; exact assertion in acceptance-tests.md |
| TEST-144 | AC-018 | T-008 | domain reviewer B; exact assertion in acceptance-tests.md |
| TEST-145 | AC-018 | T-008 | workflow auditor B; exact assertion in acceptance-tests.md |
| TEST-146 | AC-018 | T-008 | manual self-improvement; exact assertion in acceptance-tests.md |
| TEST-147 | AC-014 | T-006 | pinned without ID; exact assertion in acceptance-tests.md |
| TEST-148 | AC-014 | T-006 | flag-shaped ID; exact assertion in acceptance-tests.md |
| TEST-149 | AC-014 | T-006 | separator-shaped ID; exact assertion in acceptance-tests.md |
| TEST-150 | AC-013 | T-006 | native ID mapping; exact assertion in acceptance-tests.md |
| TEST-151 | AC-013 | T-006 | unverified successor notice; exact assertion in acceptance-tests.md |
| TEST-152 | AC-014 | T-006 | CLI versus environment and project; exact assertion in acceptance-tests.md |
| TEST-153 | AC-014 | T-006 | environment versus project; exact assertion in acceptance-tests.md |
| TEST-154 | AC-014 | T-006 | project and default; exact assertion in acceptance-tests.md |
| TEST-155 | AC-014 | T-006 | general model environment; exact assertion in acceptance-tests.md |
| TEST-156 | AC-014 | T-006 | policy precedence; exact assertion in acceptance-tests.md |
| TEST-157 | AC-014 | T-006 | project role policy; exact assertion in acceptance-tests.md |
| TEST-158 | AC-014 | T-006 | explicit ID versus latest policy; exact assertion in acceptance-tests.md |
| TEST-159 | AC-014 | T-006 | implicit and explicit pin; exact assertion in acceptance-tests.md |
| TEST-160 | AC-014 | T-006 | malformed shadowed setting; exact assertion in acceptance-tests.md |
| TEST-161 | AC-014 | T-007 | native precedence conflict; exact assertion in acceptance-tests.md |
| TEST-162 | AC-014 | T-007 | matching native setting; exact assertion in acceptance-tests.md |
