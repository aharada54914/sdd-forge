# Investigation: sdd-domain-multitarget (Issue #423 Phase 1)

## Scope and baseline

Issue #423 proposes a bounded extension of the existing SDD workflow to
software and system-design targets. It explicitly defers implementation of
new provider runtimes and must not weaken the existing gates. The Issue's
investigation baseline is `08baf03a45c7d47f5bc5e73bf2519e47ea500a5d` (2026-09-13).
This investigation rechecked the cited consumers at `origin/main`
`2b328e4050f6a2e3fbb647fc9530fcc55ac7ec70` on 2026-09-23. The baseline is a
review input, not a claim that any future target integration is implemented.
Re-run the checks at specification review, task decomposition, and immediately
before implementation planning because main is shared.

## Existing decisions and boundaries

- ADR-0016 defines three independent workflow axes and makes
  `project-context.yaml.workflow` authoritative when present; absence is only
  the compatibility fallback (`docs/adr/0016-workflow-axes-separation.md:28-75`).
- ADR-0018 keeps Capability data provider-neutral and places concrete provider
  details in `sdd/provider-bindings.yaml` (`docs/adr/0018-provider-binding-separation.md:25-78`).
- ADR-0017 limits the Foundation to the `implementation` gate stage and
  separates artifact/promotion evidence from implementation completion
  (`docs/adr/0017-gate-stage-model.md:25-56`).

These decisions are reused by this Phase 1 specification; they are not
reimplemented or replaced here.

## Consumer observations

| Consumer | Evidence at the review baseline | Consequence for #423 |
|---|---|---|
| Bootstrap track selection | The interviewer requires the hook-activation handshake before track resolution and distinguishes absent, invalid, and valid Project Context (`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:194-235`). | Target selection must be explicit and must preserve the compatibility fallback and fail-closed invalid-context path. |
| Design/UI integration | `design-sync-loop` is explicitly for UI projects, records manual fallback when the tool/authentication is unavailable, and resolves egress consent only after capability detection (`plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md:8-30`, `:66-72`). | Non-UI targets must not invoke this provider; UI provider extraction must retain no-upload fallback and consent semantics. |
| Design responsibilities | The design template requires ownership/non-ownership, contracts, state/failure blast radius, layer status, and cross-layer REQ/AC/TEST links (`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md:14-50`). | The target boundary must be documented as ownership and contract decisions, not only as a new directory or plugin name. |
| Architecture review | The checklist requires single ownership, stable contracts, migration/rollback, observability, and security boundaries before tasks leave Draft (`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/architecture-review-checklist.md:15-64`). | Phase 1 remains specification-only until these review gates and human approval are satisfied. |
| Verification contract | `check-contract.py` keeps the baseline/risk check sets hard-coded and accepts only `code`, `shell`, `docs`, and `spec` stacks (`plugins/sdd-quality-loop/scripts/check-contract.py:35-51`). | A future IaC/low-code profile needs an approved, versioned contract migration; simply adding a string or waiving required checks would be unsafe. |

## Findings and decision

1. The repository already has the workflow-axis, provider-binding, and gate-
   stage foundations required for a bounded multi-target design. Reimplementing
   those foundations would create conflicting sources of truth.
2. The remaining gap is responsibility mapping: target-specific selection and
   verification guidance must be explicit while Core, Provider, and Host
   ownership remains singular.
3. UI service operations are a separable provider boundary, but their current
   fallback and consent behavior is part of the compatibility contract.
4. New target check vocabularies (for example IaC) are deferred until a
   versioned contract, migration, and evidence semantics are approved. No
   implementation task is implied by this investigation.

The Phase 1 requirements, design, acceptance tests, and traceability artifact
therefore describe a staged boundary migration only. They do not claim that
Resolver, cloud providers, or facet-native artifacts are implemented.

## Reproduction and verification notes

The source observations above were obtained from the review checkout with
read-only `nl`/`git diff` checks. The traceability validator was run against
the new artifact and requirements and passed. No external service, provider,
credential, or deployment state was used.
