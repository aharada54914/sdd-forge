# Security Specification: epic-197-a9-dogfood

## Trust Boundaries

| ID | Boundary | Trusted decision | Control |
|---|---|---|---|
| B1 | agent to Context approval | human approved this exact content | protected sidecar + external HMAC |
| B2 | Context/Registry to resolver evidence | evidence binds current inputs | revision and digest binding |
| B3 | rollback requester to policy | weakening is genuinely authorized | approver cardinality + two distinct identities or cooldown |
| B4 | CI-MCP to GitHub | token is read-only and undisclosed | preserve fixed-host GET-only contract |
| B5 | release workflow to publication | release gate passed | existing loop gate, OIDC, attestation permissions |

## STRIDE Analysis

| Threat | Scenario | Mitigation | Tests |
|---|---|---|---|
| Spoofing | one identity fills both rollback approvals | distinct registry identities | TEST-016, TEST-018 |
| Tampering | Context changes after approval | content binding + HMAC | TEST-002, TEST-018 |
| Repudiation | promotion has no evidence identity | promotion record and saved artifacts | TEST-012 |
| Information disclosure | token/host data enters evidence | synthetic fixtures and redaction | TEST-007, TEST-024 |
| Denial of service | required mode promoted on noisy Pack | OQ-003 thresholds, advisory phase | TEST-013 |
| Elevation | agent applies protected rollback | human-copy boundary | TEST-002, TEST-018 |

## Authentication Flow

Approval authenticity follows ADR-0019's external-key HMAC. This feature adds no
new user authentication.

## Authorization

Humans resolve OQs, approve tasks, issue sidecars, and apply protected copies.
Agents may draft candidates after task approval but may not approve them.

## Data Classification and Protection

Context metadata and test evidence are internal repository data. Tokens and HMAC
keys are secrets and never committed or emitted. Release permissions are
privileged workflow configuration, not component metadata defaults.

## OWASP Mapping

- A01 Broken Access Control: protected human-copy and approval roles.
- A02 Cryptographic Failures: external-key HMAC and canonical binding.
- A05 Security Misconfiguration: schema/exact-tuple/ownership validation.
- A08 Integrity Failures: bound resolver evidence and release attestations.

## Secrets Management

Use existing environment-provided keys/tokens. Tests use fixtures; no real secret
is required. No consent-token or approval-token file is created by bootstrap.

## SBOM and Supply Chain

No dependency addition is planned. Existing GitHub Release provenance remains a
regression target.

## Security Tests

TEST-002, TEST-007, TEST-012–018, and TEST-024 cover the named boundaries.
High-risk implementation tasks must complete AGENTS.md's persisted-field
mismatch-test preflight before production edits.

## Open Questions

OQ-004 is security-significant and requires an explicit human ruling. OQ-002 and
OQ-005 also require security review because path scope and required gates can
weaken policy.
