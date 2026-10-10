# Security Specification: a9-interrupted-review-recovery

## Trust Boundaries

| Boundary | Source -> destination | Assets / validation | AuthN/AuthZ | REQ | AC |
|---|---|---|---|---|---|
| B1 | Caller record -> recovery validator | Closed schema, scoped authorization, hash pins | Original human user-channel approval/application verified by orchestrator; validator content/hash/binding; default deny | REQ-002,003 | AC-002,003 |
| B2 | Repository evidence -> destination writer | Full persisted identity verification, contained real paths, lock/recheck | Only validated new target; no historical write rights | REQ-004,005 | AC-004,005 |

## STRIDE Analysis

| Boundary | Threat | STRIDE | Mitigation | Verification |
|---|---|---|---|---|
| B1 | Agent fabricates human authorization | Spoofing | Orchestrator matches original user-channel approval and actual human application report; validator verifies contents/hash only; agent claims/artifacts alone reject | TEST-035-043 |
| B1 | Changed source pins/record accepted | Tampering | Closed types, duplicate-key rejection, every hash independently checked | TEST-044-068,081-083 |
| B2 | Symlink redirects evidence/write | Elevation of privilege | Reject each symlink ancestor and escape; exact contained destination | TEST-084-090 |
| B2 | Ledger collision/race legitimizes replay | Tampering / denial of service | Existing full-chain verification without reserve; lock/revalidate | TEST-069-080,091-095 |

## Authentication Flow / Authorization

No new credential, SSO, session or signature algorithm. Explicit human-origin artifact is required before real recovery. Unsigned prose is not a signed receipt. The orchestrator must match the actual human approval and human report of applying the exact bounded artifact in the user channel, retaining the original user-message reference and approved content/binding digest. Only the human's own message is an origin source; an agent summary, self-claim, file alone, or human-copy transaction log alone is insufficient. This is the existing human-outside-agent boundary (plugins/sdd-quality-loop/references/deterministic-check-policy.md:124-132), not cryptographic human authentication. Before invoking recovery the orchestrator establishes that origin prerequisite; the validator checks the artifact's eight contents, raw hash and recovery binding only. Unknown or mismatched origin blocks launch. No new approval is requested; AUTH-001 records the existing approval and actual human application. Hash match alone is not origin proof. A human owns AUTH-001. Reject if origin cannot be established. This proposal introduces no global approval sidecar or bypass.

| Role | Resource / action | Decision | Denial | REQ / AC |
|---|---|---|---|---|
| Human | Authorize exact source -> target and three-round limit | Explicit scoped evidence | Missing/mismatched evidence rejects | REQ-003 / AC-003 |
| Orchestrator | New Pending precheck / blank report | All validation plus lock | Fail closed | REQ-004 / AC-004 |
| Agent | Historical rounds, status, ledger, reservations | No write permission from recovery | No mutation | REQ-004 / AC-004 |

## Data Classification and Protection

Internal provenance only, local repository retention unchanged; no new PII, transport, encryption or deletion policy. Old evidence immutable, SHA256 integrity pins; SHA256 is not author attestation (TEST-041-043). No secret values in documents, fixtures or logs.

## OWASP Mapping / Secrets Management / SBOM and Supply Chain

Broken access control: scoped authorization and B absence checks (TEST-024-043,080). Injection/path traversal: closed JSON, no eval/shell expansion of record fields, contained paths (TEST-050-057,083-088). Integrity failure: verify full chain and every pin (TEST-058-079). Existing secret handling, dependency lock/provenance and scanning policies remain unchanged; no dependency or credential added. No break-glass path introduced.

## Security Tests

Canonical exhaustive matrix: acceptance-tests.md. B1 tests 016-083; B2 tests 084-107. Both runtimes must reject mis-cased operator and cmdlet fixtures independently; tests must not become detection-gate false positives. Old ledger/inputs/status hash equality is mandatory on failure and success.

## Open Questions

AUTH-001 is missing real execution evidence, owned by human/orchestrator; resolve by recording existing original human approval and actual human application report, matched by orchestrator to the exact artifact/content/binding digest before real recovery; agent selfclaims and artifact/log alone are insufficient. Product decisions are settled. No approval signature is generated in Phase1.
