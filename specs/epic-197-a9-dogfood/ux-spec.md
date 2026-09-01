# UX Specification: epic-197-a9-dogfood

## Operator Journeys

| Journey | Entry | Success | Failure presentation |
|---|---|---|---|
| Phase-1 adoption | approved Context/Pack task | advisory evidence names affected component and disposition, with `specs/`-type growing paths cross-cutting from bootstrap | named dependency/schema/ownership diagnostic |
| Release-cycle dogfood | bounded advisory release cycle | every PR has a visible passing capability-mode Gate result | missing or failed PR result names the PR and leaves cycle incomplete |
| Promotion | promotion evidence set | human can audit every threshold and bound digest before approval, then inspect one real required-mode feature E2E | unmet/stale criterion or incomplete feature listed without mutation |
| Rollback | policy-weakening request | correct two-party or cooldown branch is explicit | identity, signature, binding, or effective-time error |
| Friction capture | completed dogfood cycle | Draft WFI links evidence and root-cause hypothesis, or result is `none` when zero | missing terminal result leaves Done condition incomplete |

CLI output must be concise, deterministic, non-color-dependent, and actionable.
No graphical UI, wireframe, animation, or design-system work is in scope.

## Accessibility

Machine-readable evidence is primary; human-readable diagnostics must not encode
status by color alone and must include stable error identifiers where the merged
dependency contract supplies them.

## Wireframe Attachments

N/A — developer-tooling configuration and CLI evidence only.

## Open Questions

OQ-003 determines the promotion review presentation; OQ-004 determines rollback
operator steps. Both remain human-pending.
