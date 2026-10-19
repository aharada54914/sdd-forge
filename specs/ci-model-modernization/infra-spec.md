# Infra spec: CI efficiency and current model selection

## Deployment Topology

### CI workstream

Existing GitHub hosted Linux/macOS/Windows jobs. Add one small planning job and aggregate verification within the existing workflow. No persistent service, production environment, new secrets or cloud provisioning.

### Model workstream

Existing local/host CLI entry points, installed plugin files and scheduled GitHub workflows. Reuse current processes, no model gateway service or database. REQ-011–REQ-020 / AC-011–AC-020.

## CI/CD Sequence

### CI workstream

REQ-001–006: checkout trusted base and exact tested tree; create one bound plan; expose only bounded condition outputs; retain three required native jobs; execute selected existing steps/groups; upload existing runner receipts; read actual current-run job/step metadata with pagination; validate all required obligations in always-running required-checks. Non-PR, adoption without trusted planner, unknown/shared inputs and explicit force-full take full.

The Actions API collector must handle reruns by unique expanded job identity and keep original attempt IDs. It rejects incomplete pagination, duplicate names, wrong head/run and missing steps. Direct step success only proves the exact commands admitted by the bounded workflow interpreter. Selected runner steps additionally need their own valid receipt.

### Model workstream

Run deterministic selector, discovery/protocol and evidence contract tests through the existing catalog. Apply the approved CI dependency selection to every changed caller group. Actual adoption evaluations run on available authorized hosts with fixed fixtures and bounded budgets; unrelated CI does not start paid inference or post live notifications.

## Runtime and Dependencies

### CI workstream

REQ-007: preserve Node/Python/PowerShell requirements. Reuse npm caches; cache dependency downloads with exact runtime/lock keys and immutable tool archives with digests. Use SHA-pinned official cache actions only after confirming supported workflow/job cache-mode syntax. Validate downloaded/restored tool checksums before execution. Pester acquisition is version-pinned with package/file digest verification after restoration; bounded retry records each failed acquisition. Never retry assertions to hide failure.

### Model workstream

Use existing Bash/PowerShell selectors and Python standard library for host normalization. Codex app-server model/list supports paged availability; record schema/CLI identity and all pages. Do not add a provider SDK solely to substitute for unavailable documented host metadata. Claude/Copilot/Gemini adapters must validate actual supported interfaces or state unsupported/unverified; no fictitious shared endpoint.

## Parallelism and Concurrency

### CI workstream

REQ-008: retain existing measurement-weighted partitions and move only proven-independent expensive work to additional lanes where measurement supports improvement. Preserve exact invocation/OS multiset. Cancel only superseded attempts of the same workflow/event/PR number. main/merge/release use unique run groups.

### Model workstream

Model policy never enables delegation or changes concurrency authorization. Preserve existing isolated reviewer sequencing and identity reservations. Each run freezes its model/effort; resume with changed selection is a new attempt.

## Observability and Operations

### CI workstream

REQ-009/010: record plan reason, revision, executed/omitted obligations, actual timings and cache hit state when exposed. Separate total elapsed time, job execution sum and waiting time; do not label sums as billed costs. The single repository variable SDD_CI_FORCE_FULL permits proven PR selection only at exact lowercase false; absent/true/invalid values restore full. Missing Actions metadata or receipts fails aggregation; operators can rerun failed acquisition/collection with history preserved.

### Model workstream

REQ-015/REQ-016: requested policy/ID, effective override source, resolved native/catalog IDs, effort/control, host/CLI, source dates and hashes, actual reported identity/proof level, scoped reroute events and typed failures. Do not dump secrets or raw account responses. Thread.model in Codex is configuration metadata, not per-turn execution telemetry; no actual-ID proof is inferred from it.

## Release and Rollback

### CI workstream

Stage activation by category. Missing source/consumer/mutation/full-comparison evidence keeps full. Release after exact-commit full local and native hosted success; new tag only, preserving v1.19.0. Reverting selection does not remove tests. No automatic merge, ruleset changes or release asset publication is implied.

### Model workstream

Ship policy and all managed caller changes together. Explicit pinned mode is the supported model rollback; all existing capability/access/consent checks still apply. Keep historical model IDs/evidence. New immutable release tag only after required exact-commit local and hosted checks; do not move v1.19.0.

## Open Questions

### CI workstream

OQ-001: actual merge_group execution may be unavailable. Owner: repository administrator. Validate structural trigger/full policy and local event fixtures; record actual event proof only when observed. Do not enable merge queue as an implementation side effect.

### Model workstream

OQ-002: documented discovery and execution identity on installed host versions. Owner: integration maintainer. Validate official schema and current CLI, use explicit verified settings where allowed, and block gates requiring unavailable proof. No new credentials are requested; native validation gaps remain disclosed.

## Environments

### CI workstream

Local isolated committed checkouts run complete POSIX/PowerShell profiles. GitHub hosted Linux/macOS/Windows run PR and full lanes. No staging/production cloud environment is provisioned. REQ-006/010; AC-006/010.

### Model workstream

Current shell has observed Codex 0.159.2. Other native hosts are unverified unless actually exercised. Provider account and organization restrictions remain authoritative; fixtures do not establish live access.

## Infrastructure as Code

### CI workstream

The existing GitHub workflow YAML is the configuration surface. No Terraform state or external resource migration. Source review owns changes; structural coverage tests detect drift.

### Model workstream

Existing workflow YAML and installed role definitions. Maintain current self-improvement schedule/permissions/guards; change only model-policy integration. Existing weekly freshness remains Monday03:00UTC plus manual invocation.

## Scaling Strategy

### CI workstream

Use finite matrices and existing runner quotas; preserve fail-fast=false where complete failure collection is needed. Partition only independent work with exact coverage; no autoscaling service is added. REQ-008; AC-008.

### Model workstream

Discovery is bounded by timeout, response size and cursor-cycle checks. Cache no capability observation across an account/client/version boundary or beyond the defined freshness window. No background daemon or automatic unlimited retries.

## Service Level Objectives

### CI workstream

No invented time SLO. Hard correctness target: zero omitted required suite/OS obligations and all four required contexts for each validated run. Measure per-category wall/job time before claiming improvement. REQ-004/009; AC-004/009.

### Model workstream

Correctness target: every managed invocation consumes its bound selection and reports identity scope honestly. No model-quality/time SLA or permanent availability promise.

## Data Residency and Retention

### CI workstream

Use repository-configured GitHub artifact retention and access controls; no region, backup or retention policy change. Plans contain public repository paths and hashes, not credentials. REQ-005/007.

### Model workstream

Use current repository/local evidence retention. No new external storage/provider or cross-model consent. Record sanitized model metadata, not credentials, email addresses or account tokens.

## Observability

### CI workstream

See Observability and Operations. Correlate run, attempt, revision, plan digest and expanded job identity. Missing telemetry is unknown, not zero duration or a cache hit.

### Model workstream

See Observability and Operations. Preserve retrieval errors and actual evaluation failures. Never convert an unavailable measurement into a successful zero result.

## Cost Estimate

### CI workstream

No monthly estimate without workload volume and billing terms. Compare observed job-duration sums and actual wall time on equivalent revisions; startup/API overhead may offset savings. REQ-009; AC-009.

### Model workstream

No fabricated USD estimate from subscription credits or unknown prices. A configured budget requires a compatible estimate/unit; otherwise block. Approved current-generation preference may increase cost. Actual evaluation records retain a fixed bounded budget and known usage only.

## Rollback

### CI workstream

Maintainer enables the single force-full switch; the next run executes the complete inventory. Verify mode=full and full coverage. No data migration or tag movement is required. REQ-006/010; AC-006/010.

### Model workstream

Set an explicit available verified pinned model, start a new attempt and confirm resolved launch identity. Do not rewrite a prior attempt or label the pinned older model latest.

