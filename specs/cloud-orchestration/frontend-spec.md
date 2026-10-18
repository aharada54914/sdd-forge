# Frontend Specification: cloud-orchestration

## Technology Stack

N/A — no change: this feature adds CLI/skill integration and CI templates, with
no web frontend, browser runtime, UI framework or client bundle.

## Component Tree

N/A — no change: no frontend components. CLI entry ownership is in design.md.

## State Shape

N/A — no change to frontend state. Operation records follow the separate cloud
contracts and cannot be treated as SDD task status.

## Routes and Components

N/A — no change to web routes. CLI reachability is covered by REQ-011/AC-011.

## API Client Strategy

N/A — no browser client. Provider CLI calls, timeouts, identity, redaction and
reconciliation are owned by the adapters described in design.md.

## Code Splitting and Size Budget

N/A — no frontend bundle or code splitting.

## Performance Budget

N/A — no LCP/INP/CLS surface. Provider polling must be bounded and timeouts must
return UNKNOWN as specified in REQ-006, rather than waiting indefinitely.

## Empty, Loading, Error, and Success Behavior

CLI equivalents are defined in ux-spec.md; no duplicate frontend state machine.

## Dependencies

No frontend dependencies. CLI/tool locks are defined in design.md and
security-spec.md, including transitive upstream skill references.

## Testing

TEST-011 covers CLI entry reachability and non-cloud compatibility; browser
component, visual, accessibility and web performance tests are inapplicable.

## Open Questions

None for this layer.
