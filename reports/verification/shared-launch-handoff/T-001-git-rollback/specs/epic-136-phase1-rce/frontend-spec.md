# Frontend Specification: epic-136-phase1-rce

N/A — no change: the affected implementation is a local Bash script with an
existing PowerShell equivalent, not a browser or frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Runtime | Bash and Python 3 | existing supported runtimes | existing HMAC consent path | no new dependency |
| UI | N/A | N/A | no rendered UI | REQ-001 through REQ-004 |
| Test | Bash fixture suite and Windows PowerShell parity check | existing | execute real consent path | no network or real secrets |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists. The shell's local `consent_kind` transition is the
canonical behavior in design.md and security-spec.md.

## Performance and Size Budget

N/A — no change: no frontend asset is built. The HMAC helper performs a
constant-size digest operation over the existing token fields.

## Dependencies

No new dependency. Python uses only `hmac`, `hashlib`, and `os` from the
standard library; PowerShell continues to use .NET cryptography.

## Testing

TEST-001 through TEST-007 in acceptance-tests.md cover the command behavior.
No component, accessibility, browser performance, or E2E frontend test applies.

## Open Questions

None. Owner: maintainers; non-blocking.
