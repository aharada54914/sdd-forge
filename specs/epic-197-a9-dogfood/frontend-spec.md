# Frontend Specification: epic-197-a9-dogfood

## Technology Stack

No browser or mobile frontend. Surfaces are YAML/JSON contracts, Python-backed
deterministic tools, thin shell/PowerShell entry points, Markdown records, and
existing GitHub Actions. The exact merged A1–A8 entry points must be discovered
by T-001 rather than frozen from another branch.

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A for UI concepts. The analogous state machine is:

`absent -> phase1-advisory -> promotion-ready -> phase2-required`, with a
governed `phase2-required -> phase1-advisory` rollback. Invalid or stale evidence
leaves state unchanged.

## Dependencies

Existing Project Context, Registry, ownership, Manifest, Resolver,
compatibility, and cross-runtime contracts from A1–A8.

## Testing

Contract fixtures, resolver fixtures, negative transition fixtures, Bash/
PowerShell parity, and existing three-OS CI. No snapshot/UI tests.

## Open Questions

OQ-005 controls Pack state shape; no frontend decision is pending.

