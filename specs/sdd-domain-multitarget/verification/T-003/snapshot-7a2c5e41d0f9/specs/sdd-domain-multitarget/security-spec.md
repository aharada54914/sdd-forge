# Security Specification: sdd-domain-multitarget

## Security boundary

This slice adds no outbound communication and no new authority. Capability
selection, provider bindings, and host adapters remain separate: provider
credentials and binding identifiers stay outside Core requirements, approval,
risk, and evidence policy (see ADR-0018 and `design.md`, Architecture and
Ownership).

## Required controls

- Preserve the legacy no-context fallback and existing approval/evidence rules.
- Resolve target obligations only from the approved Registry and context; do
  not add an editable project escape hatch for protected baseline checks.
- Treat unknown, unavailable, or ambiguous required checks as failures.
- Keep host-specific invocation and hook transport adapter-owned; do not copy
  credentials or provider state into shared artifacts.
- Retain the always-on security impact assessment, including for non-UI
  targets; marking a facet not applicable does not waive security review.

## Residual risk and scope

This phase does not execute provider commands, access cloud resources, or
change egress consent. Provider-specific threat models and resource-state
validation are deferred to their adapter designs.

## Open questions

None for this phase.
