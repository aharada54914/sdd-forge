# Frontend Specification: epic-136-phase2-gates

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Runtime | Python, Node, PowerShell, POSIX shell | existing repository support | Guard and generator execution | No browser runtime |
| UI | N/A | N/A | No frontend surface | N/A |
| Test | Existing shell/PowerShell suites | existing repository support | Cross-runtime deterministic tests | Must run on CI matrix |

## Component Tree

N/A - no browser component tree. Native modules are implementation details of
the CLI guard and are specified in [design.md](design.md#architecture).

## State Shape

N/A - no frontend state. Guard decisions are process-local; no UI state is
persisted.

## Routes and Components

N/A - no route or UI component exists.

## API Client Strategy

N/A - no browser API client is added. The risk-upgrade check is local and
performs no network request.

## Code Splitting and Size Budget

N/A - no browser bundle is produced.

## Performance Budget

The guard remains bounded by existing command parsing plus a fixed 32-byte XOR
scan (REQ-002). Generated module import is local and constant-size; no runtime
JSON I/O is permitted (AC-012).

## Empty, Loading, Error, and Success Behavior

N/A - CLI paths emit deterministic allow/deny or track diagnostics. Tests
assert their exit-code behavior.

## Dependencies

No new dependency. The generator uses the repository's existing Python
standard library only.

## Testing

TEST-001..004 and TEST-010..012 validate native runtime parity. No component,
accessibility, visual, or browser E2E test is applicable.

## Open Questions

None.
