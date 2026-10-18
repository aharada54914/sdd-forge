# Security Specification: cloud-orchestration

## Trust Boundaries

| Boundary | Source | Destination | Assets | Validation | AuthN/AuthZ | REQ | AC |
|---|---|---|---|---|---|---|---|
| B1 | Agent/repository | Protected CI | Input artifact/preview authority | Strict schemas, canonical paths/digests, trusted workflow revision | Authenticated environment approval bound to run/attempt | REQ-004–005 | AC-004–005 |
| B2 | CI | Azure/AWS | Cloud resources and write credentials | Scope, operation, fresh preview, exact artifact | OIDC and operation-specific least privilege | REQ-005–007 | AC-005–007 |
| B3 | Provider/collector | Evidence reducer | Verification truth and sensitive metadata | Native IDs, freshness, check set, redaction, safe publication | Trusted collector principal and artifact provenance | REQ-009–010 | AC-009–010 |

## STRIDE Analysis

| Boundary | Threat | STRIDE | Abuse Case | Mitigation | Verification | REQ | AC |
|---|---|---|---|---|---|---|---|
| B1 | Fake approval | Spoofing | Agent writes approved:true | Resolve trusted CI evidence; local JSON has no authority | TEST-005 | REQ-005 | AC-005 |
| B1 | Input swap | Tampering | Change assembly/parameters after approval | Rehash at executor call site; immutable revision | TEST-004 | REQ-004 | AC-004 |
| B1 | Command injection | Elevation | Provider text becomes shell command | Fixed command argument arrays, no eval | TEST-010 | REQ-010 | AC-010 |
| B2 | Confused deputy | Elevation | Approved sandbox request executes in another account | OIDC target readback and exact scope binding | TEST-005 | REQ-005 | AC-005 |
| B2 | Replay/concurrency | Tampering | Same approval applies twice or units overlap | Run/attempt binding, serialized scope, operation reconciliation | TEST-006 | REQ-006 | AC-006 |
| B2 | Indefinite polling | Denial of Service | Lost response creates endless execution/retries | Deadline, UNKNOWN and read-only recovery | TEST-006 | REQ-006 | AC-006 |
| B3 | Fake health | Spoofing | Fixture/deployment-success becomes VERIFIED | Actual post-deploy collector and mandatory profile checks | TEST-009 | REQ-009 | AC-009 |
| B3 | Secret leak | Information Disclosure | Raw errors/parameters stored publicly | Redaction/allowlisted output, restricted raw storage | TEST-010 | REQ-010 | AC-010 |
| B3 | Evidence escape | Tampering | Symlink/path traversal overwrites evidence | Contained canonical paths, no overwrite, digest checks | TEST-010 | REQ-010 | AC-010 |

## Authentication Flow

Human signs into the CI provider and approves a protected environment for the
exact run and manifest. A trusted job obtains a short-lived OIDC token whose
issuer, audience, subject/repository/ref/environment claims are restricted by
cloud trust policy. It assumes the prepare or apply principal only for that
operation. Record principal identity and expiry, never the token. Expiry,
revocation or inability to validate identity blocks; reauthentication cannot
reuse expired approval. MFA/account recovery belongs to the CI identity owner.

## Authorization

| Actor / Role | Resource | Action | Decision Point | Default | Denial Evidence | REQ | AC |
|---|---|---|---|---|---|---|---|
| Local author | Local IaC | Route/edit/validate | Local CLI | No cloud write | Typed blocked result | REQ-005 | AC-005 |
| Prepare identity | Approved asset/preview scope | Publish assets/create Change Set or preview | Protected environment and provider IAM | Deny other writes | CI/provider denial | REQ-005 | AC-005 |
| Apply identity | Exact deployment unit | Execute approved artifact/Change Set | Immediate pre-write validation and IAM | Deny unmatched run/artifact/scope | Admission evidence | REQ-004–005 | AC-004–005 |
| Observer | Target resource scope | Read status/health | IAM | Deny writes | Query result | REQ-009 | AC-009 |

IAM trust cannot depend only on user-supplied workflow inputs. Do not grant
arbitrary role passing, public network access or broad resource mutation in
example policies. IAM identities and CI policy are controlled externally to
the untrusted source being deployed. Unsupported authorization integrations
must block; no fallback to local production credentials.

## Data Classification and Protection

| Entity | Classification | At Rest | In Transit | Retention | Deletion | Access Log | REQ | AC |
|---|---|---|---|---|---|---|---|---|
| Plans/receipts/observations | Internal | Restricted encrypted CI artifacts | TLS | Owner-configured before live use | Artifact retention policy | CI audit | REQ-010 | AC-010 |
| OIDC/session tokens | Restricted | No persisted artifact | Provider TLS | Token lifetime only | Process teardown | Identity audit, no token values | REQ-005 | AC-005 |
| Secret parameter values | Restricted | Provider secret store | Provider-supported secret references | Owner policy | Provider lifecycle | Provider audit | REQ-010 | AC-010 |

## OWASP Mapping

| OWASP Risk | Exposure | Control | Verification | Owner |
|---|---|---|---|---|
| Broken Access Control | Local JSON masquerading as approval | External CI/IAM authority | TEST-005 | Platform/security owner |
| Injection | IaC arguments and provider output | Strict parsing, argument arrays, no shell interpolation | TEST-010 | Adapter maintainer |
| Cryptographic Failures | Unbound or misleading hashes | Exact byte digests plus trusted provenance, never hash-only authorization | TEST-004 | Shared validation maintainer |
| Software Supply Chain | Mutable skills/tools/actions | Pinned sources, transitive hashes and compatibility probes | TEST-004 | Plugin maintainer |

## Secrets Management

Use OIDC and cloud secret references. Never add real credentials to examples,
source, logs, review inputs or manifests. Disable verbose token-bearing output;
sanitize provider errors before storing them. Scanner failures block artifact
publication. Rotation/revocation is owned by provider/CI administrators.
Break-glass operations require external human procedure and are not automated
by these plugins. TEST-010 uses synthetic canaries, not real secrets.

## SBOM and Supply Chain

Pin upstream Git commits, consumed/transitively referenced file hashes, action
commit SHAs, CLI packages and integrity records. Record runtime versions and
package inventory; scan dependencies/licenses with existing repository tools.
Upstream upgrades are explicit reviewed changes. Stable managed MCP URLs do
not imply immutable implementations: probe tool schemas and block incompatible
drift. No `latest` dependency may silently acquire write authority.

## Security Tests

| Test | Boundary | Attack / Control | Expected Result | Evidence | AC |
|---|---|---|---|---|---|
| TEST-004 | B1/B2 | Artifact/dependency/preview mutation | Block before write | New verification addendum | AC-004 |
| TEST-005 | B1/B2 | Fake/expired/wrong-target approval | Deny, no cloud submission | CI and fixture results distinguished | AC-005 |
| TEST-006 | B2 | Replay, overlap, timeout | Serialized or blocked, reconcile only | Native/fixture operation trace | AC-006 |
| TEST-009 | B3 | Unhealthy or missing real observation | Not VERIFIED | Per-check evidence | AC-009 |
| TEST-010 | B1/B3 | Injection, path escape, secret canary, evidence tamper | Reject/redact and no complete evidence | Adversarial test output | AC-010 |

## Open Questions

Live environment policy/retention and IAM trust must be supplied by the owner.
Until then no claim of live IAM enforcement or secret-store integration is made.
