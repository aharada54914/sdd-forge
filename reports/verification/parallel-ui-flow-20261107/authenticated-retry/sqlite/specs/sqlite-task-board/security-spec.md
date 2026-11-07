# Security Specification: SQLite Task Board

## Trust Boundaries
| Boundary | Source | Destination | Assets | Validation | AuthN/AuthZ | REQ | AC |
|---|---|---|---|---|---|---|---|
| B1 | browser/local process | HTTP server | task operations | exact Host; same-origin mutations; bounded JSON | trusted local machine, no login | REQ-006 | AC-006 |
| B2 | HTTP server | SQLite/files | durable task text | fixed DB path, parameterized SQL, static allowlist | OS file permissions | REQ-004/006 | AC-004/006 |

## STRIDE Analysis
| Boundary | Threat | STRIDE | Abuse Case | Mitigation | Verification | REQ | AC |
|---|---|---|---|---|---|---|---|
| B1 | foreign website mutation | Tampering | cross-origin POST | application/json, exact Origin on supplied origins, reject foreign Host | TEST-006 | REQ-006 | AC-006 |
| B1 | script title | Elevation | stored HTML executes | textContent, CSP external scripts only | TEST-006 | REQ-006 | AC-006 |
| B1 | oversized body | Denial of Service | excessive allocation | 4096-byte cap and timeout | TEST-006 | REQ-006 | AC-006 |
| B2 | SQL injection | Tampering | crafted title changes schema | bound SQL parameters | TEST-006 | REQ-006 | AC-006 |
| B2 | file disclosure | Information Disclosure | arbitrary static path | explicit asset allowlist, no directory serving | TEST-006 | REQ-006 | AC-006 |

## Authentication Flow
No login, sessions, identity provider, MFA or credentials. Loopback is an exposure boundary, not user authentication. All local processes may access tasks. No authentication requirement inferred from directory name.

## Authorization
Single local role can list/add/complete/delete all tasks. Host whitelist must match 127.0.0.1 and configured port; reject other hosts. Mutations reject foreign Origin; nonbrowser callers without Origin are allowed only with validated Host and JSON media type. No CORS grants. Missing IDs return 404; invalid IDs 400. No tenant or ownership model.

## Data Classification and Protection
Personal local text; do not enter sensitive secrets. At rest use OS-controlled file access without application encryption. Plain HTTP is confined to loopback. Retain until delete; SQLite deletion is not forensic erasure. Do not log bodies or titles. No regulatory certification.

## OWASP Mapping
Injection: bound SQL and literal DOM text (TEST-006). Access control: loopback/Host/Origin with documented local-access limitation (TEST-006). Misconfiguration: fixed static allowlist, no directory listing or stacktrace responses (TEST-006). Cryptographic protection relies on host security; external transport prohibited.

## Secrets Management
No product secrets or tokens required. No real secrets in reports, examples or logs. Host-managed workflow identities must not be fabricated.

## SBOM and Supply Chain
No third-party runtime dependencies; record Python, SQLite and browser versions in verification evidence. OS-managed interpreter updates belong to operator. No build artifacts published; lockfile/SBOM registry/signature infrastructure is inapplicable to source-only local execution.

## Security Tests
TEST-006 checks Host/Origin rejection, wrong media type, malformed and oversized JSON, path traversal, unsupported methods, invalid IDs, literal HTML and SQL-like titles. Assert no write on rejected requests and no titles in logs. TEST-004 checks committed durability; no rate-limit or audit-service claim. Record all actual results; planned tests are not evidence.

## Open Questions
None under authorized local defaults; human must review permanent deletion and unauthenticated local access before approving tasks.
