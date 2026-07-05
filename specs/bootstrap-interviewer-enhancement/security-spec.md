# Security Specification: Bootstrap Interviewer Enhancement

## Trust Boundaries

| Boundary | Assets | Control |
|---|---|---|
| Feature selector → filesystem | repository files | strict slug grammar and root-relative join |
| Artifact → reviewer | specification integrity | canonical path and SHA-256 manifest |
| Local visual input → documentation | confidential mockup | explicit human action; no automatic upload |

## STRIDE

| Boundary | Threat | Mitigation |
|---|---|---|
| Selector/filesystem | Tampering | reject traversal, underscore, uppercase, and empty selectors |
| Selector/filesystem | Information disclosure | never access outside `specs/` |
| Artifact/reviewer | Spoofing | canonical allowlist |
| Artifact/reviewer | Tampering | SHA-256 equality before review |
| Visual/documentation | Information disclosure | local/manual workflow and limitation notice |
| Visual/documentation | Repudiation | generated artifact and review evidence remain in repository |

## Authentication, Authorization, and Classification

No application authentication is added. Task authorization remains human edit
or active signed `sdd-sudo`. Specs are internal repository data; mockups may be
confidential. Secrets must never appear in templates or review manifests.

## OWASP, Supply Chain, and Testing

Path traversal and unsafe file selection are the primary OWASP-class concerns.
No new dependency is required. Tests cover traversal, symlinks/canonical paths,
tampered hashes, Draft rejection, and authorized approval.
