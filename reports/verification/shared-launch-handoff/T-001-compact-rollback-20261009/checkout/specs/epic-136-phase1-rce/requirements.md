# Requirements: epic-136-phase1-rce

Spec-Review-Status: Passed
Source Issue: https://github.com/aharada54914/sdd-forge/issues/108

## Overview

Correct the SDD_SUDO HMAC verification in
`plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh`. Token fields and
the HMAC key are currently interpolated into an unquoted Python heredoc. A
crafted value can terminate a Python string literal and execute code before the
signature comparison. The correction must retain valid SDD_SUDO consent while
treating every operand strictly as data.

## Target Users

- Maintainers running local cross-model verification.
- Operators using a valid SDD_SUDO token as an explicit consent signal.
- Auditors relying on the consent gate to prevent an unauthorized external
  panelist send.

## Problems

- Untrusted SDD_SUDO fields and environment-derived key material cross from the
  shell into Python source code rather than a data boundary.
- Existing PP-007 only tests `SDD_SUDO_SKIP_SIG=1`; it cannot prove the real
  HMAC verifier accepts a valid token or rejects a tampered one.

## Goals

- REQ-001: Invoke Python using a quoted heredoc and pass the HMAC key, issuer,
  nonce, repository, epochs, and signature through explicitly named environment
  variables read with `os.environ`.
- REQ-002: Preserve fail-closed consent: a token grants SDD_SUDO consent only
  when its nonce, TTL, repository binding, and real HMAC-SHA256 signature are
  valid. Each condition is independently enforced even when every other
  condition, including the signature, is valid.
- REQ-003: Treat quote, backslash, newline, and Python-looking payloads in all
  HMAC operands as data. They must neither execute code nor cause an external
  send or output bundle when authentication fails.
- REQ-004: Add isolated regression tests for a real-HMAC positive case, a
  tampered token denial, independently invalid nonce/TTL/repository-binding
  tokens that remain correctly signed, and adversarial field/key values. The
  tests must not use real credentials or modify repository SDD_SUDO state.
- REQ-005: Preserve the existing PowerShell implementation's equivalent
  fail-closed HMAC behavior. `tests/prepare-panelist.tests.ps1` must prove a
  real-HMAC acceptance and a tampered-token denial using its .NET verifier;
  `security-spec.md` is the canonical document for its byte-array safety
  difference. Do not introduce a divergent consent rule.

## Non-goals

- Changing the SDD_SUDO token format, nonce rule, TTL, repository binding, or
  `SDD_SUDO_SKIP_SIG=1` test-scaffolding policy.
- Changing panelist execution, sanitization rules, evidence contracts, or the
  cross-model consensus gate.
- Adding a user-facing interface, network call, or persistent data store.

## User Stories

As an operator with a valid signed SDD_SUDO token, I can use it as consent and
receive the normal sanitized bundle. As a maintainer, I can trust that a
malformed or malicious token is rejected before it can execute code or enable
an external-send path.

## Acceptance Criteria

- AC-001: `prepare-panelist-input.sh` receives all HMAC operands as data in a
  quoted Python heredoc; no untrusted value is rendered into Python source.
- AC-002: A token signed with a test-only, real HMAC-SHA256 key grants SDD_SUDO
  consent and produces the normal sanitized output.
- AC-003: Altering one signed token field after signing produces a non-zero
  exit, no output bundle, and no consent.
- AC-004: An adversarial triple-quote/backslash payload in a token field or key
  neither creates a controlled sentinel nor enables consent without a valid
  signature.
- AC-005: `tests/prepare-panelist.tests.ps1` proves the PowerShell .NET
  HMACSHA256 path accepts a valid test-only signature and rejects a tampered
  signed field with no output bundle; its byte-array implementation is
  documented in `security-spec.md`.
- AC-006: Correctly signed fixture tokens with an independently invalid nonce,
  expired or overlong TTL, or incorrect repository binding exit non-zero and
  leave no output bundle in both shell and PowerShell test suites.
- AC-007: Both focused test suites cover AC-002 through AC-006 with isolated
  fixtures and remain runnable without secrets or network access.

## Roles and Permissions

- Human operator: creates a valid SDD_SUDO token or enables the explicit
  Cross-Model flag.
- Collection script: validates consent, sanitizes input, and may only proceed
  after consent succeeds.
- Python HMAC helper: computes a digest from supplied data; it has no authority
  to execute token content.

## Main Workflows

1. The script reads SDD_SUDO fields and a locally resolved key as untrusted
   strings.
2. The shell supplies those strings as environment values to a quoted Python
   program.
3. Python recomputes HMAC-SHA256 from the canonical five-line message and uses
   constant-time comparison with the supplied signature.
4. Only a complete valid token selects `consent_kind=sudo`; all other outcomes
   follow the existing no-consent denial path.

## Edge Cases

- A missing key or Python runtime leaves the token inactive.
- A key or field containing quotes, backslashes, newlines, or Python syntax is
  data, not source code.
- A token whose signature was computed before any signed-field modification is
  invalid.
- A correctly signed token remains inactive if its nonce is malformed, its TTL
  is expired or exceeds the policy maximum, or its repository field does not
  bind to the SDD_SUDO directory.
- `SDD_SUDO_SKIP_SIG=1` remains test scaffolding and does not substitute for
  the real-HMAC acceptance or tampering tests.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: SDD_SUDO and key material to HMAC helper | Valid HMAC, nonce, TTL, and repository binding before consent | restricted secret-derived key and untrusted token data | none identified |
| B2: consent gate to panelist bundle creation | default deny; no bundle before successful consent | sanitized internal review content | local-only, no automatic CI send |

The key is resolved only from the existing environment or local key-file
locations, must never be logged, and must be passed to Python as process data
rather than generated source text.

## Assumptions

- `python3` is the existing required HMAC runtime for the shell implementation.
- The PowerShell implementation uses .NET byte arrays and does not interpolate
  token values into executable source; its behavior is verified for parity.
- The user-provided epic handoff is the authoritative scope decision for this
  bugfix.

## Open Questions

None. The scope, mechanism, and test matrix are fixed by epic #136 handoff
section 3, issue #108.

## Risks

- Critical: an incomplete fix can still execute attacker-controlled Python or
  accidentally accept an invalid consent token.
- Medium: changing canonical message encoding could invalidate valid tokens.
  The real-HMAC positive test and tampering-negative test constrain this risk.
