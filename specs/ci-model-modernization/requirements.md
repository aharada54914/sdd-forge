# Requirements: CI efficiency and current model selection

Spec-Review-Status: Passed

## Overview

This feature combines the two already-approved workstreams into one delivery. Implement CI changes first, model policy second, and complete shared documentation/full validation/one immutable release in a final task. Each task retains independent verification. No scope or permission expansion is implied.

### CI workstream

Implement the CI portion of the user-approved proposals of 2026-10-18. Approval is recorded in `reports/verification/ci-efficiency-approval-20261018.md`; approval authorizes development and scoped release delivery, not changing external branch protection or merging main automatically.

### Model workstream

Implement the user-approved research proposal in reports/verification/model-selection-policy-research-20261018.md. The approval is recorded in model-selection-policy-approval-20261018.md. Latest-compatible means a verified current model available to the host/account and adequate for the role, not every newly announced model without validation.

## Target Users

### CI workstream

Contributors awaiting pull-request feedback, maintainers reviewing evidence, and release operators requiring a complete tested revision.

### Model workstream

Implementers, independent reviewers, evaluators and maintainers using supported sdd-forge hosts.

## Problems

### CI workstream

The current impact tool emits observational shadow output and does not skip checks (`tests/verification-impact.py:124`). The workflow retains an unconditional aggregate and native matrix (`.github/workflows/test.yml:244`, `:1553`), while bounded workflow coverage currently admits only runner/matrix conditions (`tests/verification-workflow.py:63`). Selection must preserve their obligations rather than bypass the checks.

### Model workstream

The current selector only admits registry-defined names (plugins/sdd-implementation/scripts/select-agent-model.sh:335–407), and final ordering has no current-generation preference (:437–443). The actual host observation lists GPT-6.1 Sol as default, but the existing-selector baseline rejects it. Existing rendering uses reference comments in Codex TOML (render-agent-frontmatter.sh:211), while review launch/validation enforce Sonnet separately (plugins/sdd-review-loop/scripts/launch-impl-review.py:342–348; validate-nontty-spec-launch.py:109–113). These surfaces must move coherently.

## Investigation Traceability

### CI workstream

INV-001/002 establish the existing shadow interface and Git diff foundation (REQ-001/002). INV-003/005 establish catalog and bounded coverage obligations (REQ-003/005). INV-004/006 establish receipts and required-context aggregation (REQ-004/005). INV-007/009 establish concurrency and existing partition behavior (REQ-008). INV-008 establishes dependency-cache reuse (REQ-007). Each observation has a file:line citation in investigation.md and must be rechecked when its shared source changes.

### Model workstream

INV-010/INV-011 establish live discovery and current selector behavior (REQ-012/REQ-013). INV-012 covers the existing Google panelist (REQ-018). INV-013 covers host execution-identity limitations (REQ-015/REQ-016). INV-014 covers additional domain/auditor/diagnosis/automation entry points (REQ-011/REQ-018). Reverify shared source and host schemas at review and adoption; observations are not permanent capabilities.

## Goals

### CI workstream

| ID | Requirement |
|---|---|
| REQ-001 | **Complete revision-bound change input.** Derive a complete NUL-delimited Git diff with additions, removals, rename old/new paths, type and case changes, without an API file-count cap. Bind event, exact base, PR head, merge base and actual tested commit; reject inconsistent identities and use full verification when selective classification cannot be established. |
| REQ-002 | **Trusted conservative planning.** On a pull request, use the exact trusted-base planner/rules for selection. Changes to planner, catalog, workflow, installation, contracts, authorization or shared infrastructure force full; unclassified paths, empty changes, invalid/missing input and first adoption without a base planner also force full. Preserve the observational v1 interface. |
| REQ-003 | **Dependency-aware selection.** Select the union and transitive dependency closure of documented consumers, fixtures and generated outputs using the existing catalog. Record reasons for selection and every omission. Markdown extension alone never implies safe omission. A category becomes active only after recorded full-versus-selected validation. |
| REQ-004 | **Stable required contexts.** Always start the test workflow on its existing supported events and retain test (windows-latest), test (macos-latest), test (ubuntu-latest), and required-checks. Keep native wrappers and cheap integrity checks even for a small change. Only proven-unnecessary heavy steps or optional jobs may be omitted. |
| REQ-005 | **Evidence-based aggregation.** Require a valid plan bound to the tested revision and actual selected job/step/OS completion. Missing, changed, wrong-run, wrong-revision, duplicate, failed, cancelled or unexpectedly skipped evidence must not pass. Distinguish planned NOT_SELECTED from an executed PASS. Preserve actual existing runner receipts and A9 activation semantics. |
| REQ-006 | **Full verification escape hatch.** main pushes, merge_group, release validation and manual runs default to full. A single force-full setting restores full execution without editing rules. Unsupported settings must not enable selection. Full execution retains pre-change suites, invocation arguments, assertions and native OS obligations. |
| REQ-007 | **Safe dependency caching.** Reuse existing dependency setup, cache only reproducible dependency bytes keyed by OS, runtime, lockfile or tool digest, verify integrity on reuse and retain event trust isolation. Never cache source trees, authorization, verification verdicts or cloud state; cache miss/corruption must not fabricate success. |
| REQ-008 | **Measured parallel execution.** Reduce critical-path delay by partitioning independent existing work using recorded measurements and preserving each native obligation. Cancel superseded runs only within the same PR number and workflow; do not cancel another fork PR, main, merge or release run. Acquisition retries must be bounded and must not retry failed assertions as success. |
| REQ-009 | **Rollout and measurable results.** Compare selected plans against full results for documentation/configuration, MCP, cloud and shared changes before enabling each category. Record revision, selected/omitted work, timing, cache observations and misses; keep unproven categories full. Distinguish real hosted runs from fixtures and disclose unavailable event validation. |
| REQ-010 | **Documentation and release delivery.** Update verification, contributor, workflow/release and affected README documentation with operation, failure reasons, rollback and measured limitations. Publish a new version tag only at the exact commit passing required full local and hosted checks; do not move previous tags or imply live-cloud validation. |

### Model workstream

| ID | Requirement |
|---|---|
| REQ-011 | **Role policy.** Use one source of truth for model policy across implementation, investigation, specification/design/task review, quality evaluation, domain review, workflow auditing, diagnosis, existing self-improvement automation and optional panelists. The ordinary mode is latest-compatible; explicit pinned runs remain supported. Preserve existing role floors, risk/escalation rules, host/provider restrictions and separate cross-model consent. |
| REQ-012 | **Live discovery.** Before a new run, discover model availability and supported capabilities through documented host interfaces, including complete pagination and client/account identity scope. Listing is not inference success. Missing/unsupported discovery must yield explicit unverified/unavailable status, not invented capability or access. |
| REQ-013 | **Current eligible candidates.** Select the current verified compatible candidates for the role using source-dated lifecycle/successor metadata and official host hints. Do not infer chronology or quality from lexical IDs, list order or creation timestamps alone. A newly discovered unregistered successor is a visible update candidate, not automatically a trusted evaluator. |
| REQ-014 | **Explicit configuration.** Resolve validated role-specific explicit model overrides and pinned policy consistently across CLI/config/environment/agent definition precedence. An override cannot bypass organization allowlists, minimum capability, consent or protected launch behavior. Reject unknown policies and injection-shaped values. |
| REQ-015 | **Run identity and reproduction.** Freeze the resolved model/effort for each run and record requested policy/ID or alias, resolved and actually reported IDs, host/CLI, catalog hash/source date, availability observation and selection reason. Resumption cannot silently change model; changed selection starts a new attempt. A pinned comparison preserves dataset, prompts, evaluator and budget. |
| REQ-016 | **Unavailable and mismatch behavior.** Stop with a typed reason when compatible current candidates, access, required actual-ID evidence or configured budget information are unavailable. An explicit older pinned run remains possible only when all capability/authorization checks pass and is not reported as latest. Unexpected provider fallback or actual-ID mismatch cannot count as successful pinned execution. |
| REQ-017 | **Maintenance.** Reuse the existing weekly/manual freshness workflow, distinguishing verified metadata, candidate discoveries, deprecations and fetch failures. Keep deduplicated existing notifications and human-reviewed adoption. Never execute fetched prose, silently rewrite registry or auto-merge model changes. |
| REQ-018 | **Launch integration.** Make the real selected model reach current host launchers and installed agent paths, including validation/transport counterparts and existing panelists. Generated comments alone are insufficient. Preserve read-only review isolation, exact input/identity reservation, privacy and per-vendor consent. |
| REQ-019 | **Compatibility and evaluation.** Preserve historical model IDs and evidence and supported v1/v2 input/effort contracts, while documenting intentional new-policy defaults. Test Bash/PowerShell parity and host adapter boundaries. Validate adoption using actual representative artifacts; compare model changes with a fixed judge, and skill changes with the same model. Do not claim native-host or model-quality evidence from fixtures. |
| REQ-020 | **Documentation and delivery.** Update README, capability matrix, selector/launcher/installer guidance, maintenance/runbook and CHANGELOG; state host limitations, source freshness and fixed-run operation. Publish the latest deliverable only with exact-commit required validation and a new immutable tag; preserve previous tags. |

## Non-goals

### CI workstream

No new monorepo engine, privileged pull_request_target execution, external protection/ruleset changes, new secrets, automated main merge, actions.lock preview adoption, nightly full-suite expansion, production cloud execution, or rewriting frozen historical evidence.

### Model workstream

No parent ChatGPT UI model control, automatic organization access changes, new provider accounts/keys, automatic maximum effort or subagent activation, blind use of preview/experimental latest aliases, autonomous registry merge or rewriting historical evaluations. Latest generation does not guarantee lower cost or better task accuracy. The CI workstream in this specification owns test-skipping infrastructure.

## User Stories

### CI workstream

- Contributors receive relevant PR checks and explicit omission reasons (REQ-001–004).
- Maintainers can prove every selected native obligation ran on the tested revision (REQ-005–006).
- Operators reuse safe dependencies and parallel work without dropping assertions (REQ-007–008).
- Maintainers measure rollout and can return to full verification and install an immutable validated tag (REQ-009–010).

### Model workstream

- Implementers automatically use current compatible models without editing every agent file.
- Evaluators retain independence and can identify the exact model used.
- Maintainers compare updates under fixed evaluation conditions and diagnose unavailability honestly.
- Users can pin a supported model to reproduce a run without labelling it current by default.

## Acceptance Criteria

### CI workstream

AC-001 through AC-010 in acceptance-tests.md map one-to-one to these requirements; individual TEST rows expand their branches. Required checks failing or unavailable do not become PASS. Unproven selection categories execute full until validation evidence exists.

### Model workstream

AC-011–AC-020 correspond to REQ-011–REQ-020 and are expanded into individual observable branches in acceptance-tests.md before review. Model listing and deterministic adapter fixtures are distinct from actual inference and behavior evaluation.

## Roles and Permissions

### CI workstream

Planner reads Git objects and trusted-base rules with read-only repository permissions. Test jobs run within existing PR trust restrictions. Aggregate reads actual same-run job/step evidence and bound receipts with minimal Actions read permission. Maintainers review rule changes; deployment/environment administrators retain cloud privileges. No cloud privilege is required for CI selection.

### Model workstream

Host authentication and organization model access remain authoritative. Role configuration never grants tools, write access, secrets or external-send consent. Model discovery obtains only documented non-secret metadata; it does not dump credential files or account tokens. Independent reviewers are still allocated/reserved before substantive turns.

## Main Workflows

### CI workstream

Classify event → bind revisions → resolve dependencies → emit full/affected plan → retain required wrappers → execute selected work → compare actual observations → report PASS/FAIL plus explicit omissions. Unknown information takes full verification where execution remains possible; missing mandatory aggregation evidence fails rather than fabricating a plan.

### Model workstream

Read policy → discover host capabilities → intersect verified catalog/role/access conditions → resolve current or pinned choice → bind launch and run record → verify actual returned identity → retain result with exact provenance. Unknown new models go to update-candidate maintenance; invalid or unverifiable required properties stop execution with a reason.

## Edge Cases

### CI workstream

See the individual acceptance rows for rename/deletion/type/case, more than 3,000 changes, fork identity, unavailable base, stale merge, unknown consumer, empty selection, injection, acquisition failure, receipt drift, reruns, cancellation and missing real merge_group access.

### Model workstream

Partial pagination, host/CLI change, stale discovery, deprecation during execution, unsupported effort, different provider billing units, ambiguous aliases, explicit override conflicts, unavailable exact model, unknown actual model, inherited agent model precedence, implicit provider fallback and non-Codex hosts without discovery. Each requires explicit result/record behavior; none implies successful latest selection by default.

## Model configuration precedence

For REQ-014, resolve the effective model ID and policy from these sources in descending order: explicit CLI option, role-specific environment value, project role configuration, shipped role default. Resolve each field separately by the first present source and record that source. No global model-ID environment fallback is supported; a supplied generic SDD_MODEL value is rejected rather than competing with a role-specific ID. SDD_MODEL_POLICY is the one general environment policy key and occupies the environment tier; there is no additional role-specific policy environment key. A project role policy overrides a project default policy within the project tier. All present supported values must be syntactically valid even if shadowed; malformed values do not disappear through precedence.

Any effective explicit model ID implies pinned selection when no explicit policy was supplied. An explicit latest-compatible policy combined with any effective explicit model ID is rejected as a configuration conflict; an explicit pinned policy requires an effective explicit ID. A lower-priority valid ID may be shadowed, but never grants access or bypasses role floors. A native agent model with higher runtime precedence must match the resolved model after managed generation; if the launcher cannot safely align it through the existing supported path, reject launch with a native-precedence conflict. No silent native override is accepted.

## Security Boundaries

### CI workstream

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| PR tree → selection | Exact trusted-base implementation; PR data never executes in privileged context | Paths and revision metadata | Existing repository policy |
| Cache → job | Exact dependency identity and integrity; existing event isolation | Public dependencies, no credentials | Existing CI policy |
| Jobs → aggregate | Exact run, attempt, revision, plan, OS and admitted execution mapping | Test outcomes; redact raw secrets | Existing artifact retention |

A trusted planner does not defend a workflow from every malicious same-PR workflow rewrite. Existing workflow review and CODEOWNERS boundaries remain required; this feature makes no stronger external enforcement claim.

### Model workstream

| Boundary | Requirement | Data |
|---|---|---|
| Host discovery → selector | Strict typed capabilities, complete response and provenance | Non-secret model metadata |
| User config → launch | Validated values and precedence; preserve permissions | Model IDs and policy |
| Launch → evidence | Actual runtime identity and frozen run binding | Model/run metadata |
| Official sources → catalog maintenance | Untrusted data, reviewed adoption | Model/lifecycle references |

## Assumptions

### CI workstream

The four required context names are observed in the approved proposal's ruleset record. Reverify current rulesets and workflow names before design review and final hosted validation; do not mutate them. No domain/ or active project context was present in the preceding cloud investigation; recheck before bootstrap and preserve applicable existing configuration.

### Model workstream

Current official APIs and actual model availability can change. Reverify host CLI/schema and shared registry/guard/role definitions at design review and before adoption; do not make fixed availability claims from this observation. Codex was observed available; Claude/Copilot/Gemini native execution has not yet been verified in this shell.

## Open Questions

### CI workstream

OQ-001: Real merge_group execution may be unavailable because visible rulesets do not enable a merge queue and legacy protection read access is denied. Owner: repository administrator. Resolution: preserve the trigger and full behavior, test local event cases, inspect actual hosted availability at rollout, and report an unverified real-event branch if unavailable. This does not authorize configuration changes or a fabricated successful event. It does not block planner implementation.

### Model workstream

OQ-002: Exact discovery and actual-ID reporting support on each installed host version. Owner: integration maintainer. Resolution: inspect official interfaces and installed supported versions, then implement verified adapters and explicit unsupported/unverified behavior. Blocks unsupported host adoption, not core selector implementation. No new credentials are requested just to hide this limitation.

## Risks

### CI workstream

Incomplete dependency declarations can hide regressions: keep unknown/unproven categories full and use mutation/comparison checks. Caching can reuse incorrect bytes: key and validate dependencies. Additional planner/aggregate startup may exceed savings for small jobs: report measured wall time and job-minute sums without billing claims. New docs/specs can affect gates: register current inputs and preserve frozen old reports.

### Model workstream

New models can regress despite improved general capability; require representative adoption evaluation. Evolving aliases can break comparisons; record resolved actual IDs and disallow unproved pinned claims. Newer generation may cost more; respect configured budgets and never fabricate USD estimates for subscription credit usage.

