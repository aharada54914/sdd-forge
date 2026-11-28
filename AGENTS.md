# AGENTS.md

Map for human contributors and AI agents. Standardizes on `AGENTS.md` across all tiers (R-04: no `CLAUDE.md`).

## Required Workflow

1. Use `sdd-bootstrap-interviewer` Phase 1 to create requirements, design, and acceptance tests.
2. Run `spec-review-loop` with independent reviewers until `Spec-Review-Status: Passed`.
3. Run `impl-review-loop` with separate independent reviewers until `Impl-Review-Status: Passed`.
4. Use `sdd-bootstrap-interviewer` Phase 2 to create Draft tasks, then run `task-review-loop` until `Task-Review-Status: Passed`.
5. A human reviews the specification and changes selected tasks to Approved.
6. Use `implement-task` for one Approved task.
7. Use `quality-gate` for independent verification and the Done decision.
8. Use `fix-by-review-ticket` for approved review-ticket fixes, then rerun `quality-gate`.

## Rules & Domain Pointers

- Golden conventions (R-01..R-05) & pitfall catalog: `docs/coding-conventions.md`, `contracts/pitfalls-catalog.json`
- SSOT sync & verification: `node scripts/sync-ssot.mjs --check` (never edit generated artifacts directly)
- Scoped domain rules (lazy-loaded): `plugins/AGENTS.md`, `mcp/AGENTS.md`, `tests/AGENTS.md`, `docs/contributor/workflow-detail.md`
- Core invariants: do not implement Draft tasks; do not self-approve; only `quality-gate` sets Done; API/architecture changes update `contracts/` and `docs/adr/NNNN-*.md`.

## Active Spec Directories

- `specs/sdd-forge-refactor/`
- `specs/claude-workflow-compatibility/`
- `specs/sdd-forge-mcp/`
- `specs/workflow-state-integrity/`
- `specs/bootstrap-interviewer-enhancement/`
- `specs/agent-cost-context-isolation/`
- `specs/sdd-domain/`
- `specs/sdd-domain-multitarget/`
- `specs/local-env-mcp/`
- `specs/ci-mcp/`
- `specs/epic-136-phase2-gates/`
- `specs/epic-136-phase1-rce/`
- `specs/epic-136-phase1-guards/`
- `specs/epic-159-pillar-a/`
- `specs/epic-159-pillar-a2/`
- `specs/epic-159-pillar-b/`
- `specs/epic-159-pillar-c/`
- `specs/epic-159-pillar-d/`
- `specs/epic-189-a1-project-context/`
- `specs/epic-192-a4-facet-manifest/`
- `specs/epic-136-phase3/`
- `specs/epic-136-phase4-docs/`
- `specs/epic-136-phase4-mcp/`
- `specs/mcp-readonly-preflight/`
- `specs/review-cross-critique/`
- `specs/design-sync-consent/`
- `specs/epic-193-a5-capability-resolver/`
- `specs/epic-194-a6-lite-integration/`
- `specs/epic-195-a7-compatibility/`
- `specs/epic-196-a8-integration/`
- `specs/design-sync-scan/`
- `specs/design-sync-standing-consent/`
- `specs/epic-190-a2-capability-registry/`
- `specs/epic-191-a3-path-ownership/`
- `specs/cross-model-verification/`
- `specs/evidence-deep-verify/`
- `specs/p0-hardening/`
- `specs/quality-loop-fixes/`
- `specs/risk-adaptive-layer/`
- `specs/sdd-diagnose/`
- `specs/sdd-lite/`
- `specs/second-approval-mask/`
- `specs/uninstall-workflow/`
- `specs/sdd-domain-concept-contract/`
- `specs/epic-197-a9-dogfood/`
- `specs/a9-interrupted-review-recovery/`
- `specs/sdd-domain-concept-test/`
- `specs/shared-review-launch-repair/`
- `specs/sql-development-flow/`
- `specs/visual-spec-decisions/`
- `specs/v2-lightweight-guardrails/`
- `specs/ssot-unification-v22/`

## Project Settings

| Key | Values | Default | Meaning |
|---|---|---|---|
| `ds_upload_consent` | `standing` \| `per-feature` \| `off` | `per-feature` | Exact lowercase match; governs `design-sync-loop` uploads to claude.ai/design (absent or invalid literal falls back to `per-feature`). |
