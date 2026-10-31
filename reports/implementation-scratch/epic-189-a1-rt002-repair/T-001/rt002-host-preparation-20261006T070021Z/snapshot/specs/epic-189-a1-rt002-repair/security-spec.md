# Security Specification: A1 RT002 bounded repair

Risk: high
Security-Sensitive: yes

Authorized amendment (2026-09-28, limited extra1): exact two-envelope contract adopted for formal re-review. Existing review/status/approval lines remain historical, not a PASS of these changed bytes. No implementation, execution proof, task-attempt reset or correction-budget reset. Governing dated precedence: [amendment addendum](verification/T-001/two-envelope-extra1-20260928/candidate-precedence-20260928.md).

## Trust Boundaries

| Boundary | Source | Destination | Assets | Validation | AuthN/AuthZ | REQ | AC |
|---|---|---|---|---|---|---|---|
| B1 | Trusted session's capture file | Verifier verdict | Permission to resume ordinary work | Exact selector/key/type/nonce and either complete B(N) or P+B(N); duplicate rejection | No cryptographic capture authentication; session must record its own actual dispatch | REQ-001–REQ-004 | AC-001–AC-005 |
| B2 | Reviewed repository candidate | Installed host | Enforcement and live proof | Installed version/hash plus fresh native canary denial | Existing protected application path; no bypass | REQ-005 | AC-006 |

## STRIDE Analysis

| Boundary | Threat | STRIDE | Abuse Case | Mitigation | Verification | REQ | AC |
|---|---|---|---|---|---|---|---|
| B1 | Reused denial | Spoofing | Earlier nonce accepted for new invocation | Bind expected, recorded and echoed nonce; session consumes one new challenge | TEST-036, TEST-037, TEST-089 | REQ-002, REQ-005 | AC-003, AC-006 |
| B1 | Parser ambiguity | Tampering | Duplicate key or altered operation changes interpretation | Shared duplicate-member rejection and exact whole-string matching of B(N) or P+B(N), with no other wrapper | TEST-044–TEST-073, TEST-092–TEST-097 | REQ-002, REQ-003 | AC-003, AC-004 |
| B2 | Unreviewed installed bytes | Tampering | Fixture candidate differs from active verifier | Verify actual installed path/hash after permitted application | TEST-089 | REQ-005 | AC-006 |
| B2 | Fixture presented as activation | Elevation of privilege | Ordinary workflow resumes without native denial | Actual dispatch and unmodified raw result; no fixture substitution | TEST-087, TEST-089 | REQ-005 | AC-006 |

## Authorization and Evidence Limits

Recovery entry only permits this repair's provenance reviews. It does not permit ordinary implementation, quality-gate completion or integration while activation is unavailable. Actual denied operations cannot be reissued through a renamed/copied executable or another executor. New feature separation changes evidence ownership, not enforcement.

Exact content is not cryptographic host attestation. A fully forged collector-authored file is outside the plain-file verifier's detection capability; no claim of plugin origin, persistent single-use ledger or arbitrary-process authenticity is made. The trusted current session must perform and record the one real invocation. Only the exact presence/absence of one decoded `P = "Script error:\n"` changes in this candidate; unknown host/tool, malformed or repeated wrapper and every other changed format remain unavailable. Apply each versioned response negative to both base envelopes per acceptance-tests.md; success requires TEST-090 and TEST-091 independently. No trimming, partial match, Unicode normalization, CRLF conversion, new key or inferred metadata is allowed.

## High-Risk Persisted-Field Preflight

Before any new implementation, the implementation report must record these field/counterpart/failing-mismatch pairs (WFI-001). Existing passing tests do not count as historical RED.

| Field | Contract counterpart | Mismatch assertion |
|---|---|---|
| schema/runtime | Version selector and both Codex runtime values | TEST-002–TEST-009, TEST-020–TEST-025 |
| nonce | Fresh expected and exact echoed nonce | TEST-036–TEST-043 |
| executed | Boolean nonexecution | TEST-013, TEST-015–TEST-019 |
| raw_result | Normative whole B(N) or P+B(N), one nonce capture and fixed canary operation | TEST-031–TEST-035, TEST-044–TEST-057, TEST-090–TEST-097 |
| status/reason/exit | Authorized actual denial; unavailable on invalid evidence | All negative rows plus TEST-089 |
| cleanup_status | Legacy cleanup predicate, never activation | TEST-070–TEST-080 |

## Data Classification and Secrets

Local diagnostic evidence contains nonce, fixed canary path, version/hash and denial text, not credentials. Do not include unrelated tool payloads or secrets in reviews. No new authentication, credential storage, external transmission or retention service. Preserve historical evidence instead of overwriting it.

## OWASP / Supply Chain

Access-control and input-validation risks are addressed by fail-closed explicit predicates and negative assertions. Reuse Python stdlib and installed shell runtimes; no new dependency or lockfile exception. Existing repository dependency/secret checks remain enabled. Shared membership and installed artifact claims must be re-verified immediately before use.

## Open Questions

None requiring a broader threat model. Actual Windows and native host results remain unproven until recorded under AC-006.
