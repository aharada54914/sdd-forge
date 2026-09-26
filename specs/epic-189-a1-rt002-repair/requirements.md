# Requirements: A1 RT002 bounded repair

Spec-Review-Status: Pending
Feature Type: bugfix

## Overview

Revalidate and complete only the authorized Codex host-denial evidence repair. Separate its current evidence from the completed A1 task and failed historical reviews. Authority: `docs/review-tickets/RT-20260909-002.yml` and `reports/verification/hook-recovery-entry-contract-20260909.md` (normative byte templates and recovery limits).

## Target Users

Maintainers and calling skills deciding whether the current host actually denied this invocation's canary operation.

## Problems

The observed host denial lacked legacy plugin flags; their absence cannot establish disabled configuration (parent ticket `12-26`). Existing exact-response code is present (`plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py:381-424`), but historical test-first ordering, fresh feature review, native Windows and installed-host proof are not established; see `investigation.md`.

## Goals

- REQ-001: Accept the exact versioned operation-bound Codex denial defined in the recovery contract; emit `HOOK_ACTIVE`, exit 0, without claiming plugin provenance.
- REQ-002: Fail closed on invalid selector, structure, type, runtime, nonce or raw envelope. Preserve documented category/exit behavior and never substitute fabricated metadata.
- REQ-003: Reject duplicate JSON members at every object depth in both response and cleanup modes. Preserve other legacy runtime, cleanup, stale-start and non-mutation behavior.
- REQ-004: Generate the exact fixed-path Codex patch with its fresh 32-lowercase-hex nonce; preserve complete Claude/Copilot templates.
- REQ-005: Independently verify this bounded repair using current inputs and original-path suites, native Windows CI and fresh installed-host proof; preserve all historical task/verdict evidence.

## Non-goals

No guard-policy relaxation, general shell parser rewrite, caller-authentication service, persistent replay ledger, A8 cross-runtime completion, or reopening/retargeting A1 T-008. No ordinary-entry exception; recovery authorization permits only repair-specific provenance reviews.

## User Stories

A caller can distinguish an operation-bound guard denial from missing metadata, arbitrary errors and executed writes. A maintainer can identify exactly which fresh checks justify resuming ordinary execution without rewriting previous FAIL evidence.

## Acceptance Criteria

- AC-001 (REQ-001): The five-field `sdd-codex-host-denial/v1` record with CLI and recorded runtime `codex-cli`, matching well-formed nonce, boolean false executed and exact normative raw string produces exit 0 / `HOOK_ACTIVE`.
- AC-002 (REQ-002): Explicit unknown/null/wrong-type selectors never fall through to legacy success. Missing/extra keys, invalid executed/raw types and non-Codex runtime combinations reject. Structural/signature errors are 64, nonce mismatches 62, executed true 63; response malformed/duplicate JSON is 61. All emit `CAPABILITY_RUNTIME_UNAVAILABLE`. Removing schema selects the legacy contract, whose missing plugin flag yields 65, not an inferred claim that host configuration is disabled.
- AC-003 (REQ-002): Outer and echoed nonce must match the expected 32-lowercase-hex nonce. Reject prefix, quoting, suffix, truncation, changed guard message, case changes, other target, extra operation, old empty patch, leading/trailing newline and CRLF. No normalization or trimming.
- AC-004 (REQ-003): Valid no-schema Claude, Copilot and Codex responses retain their predicates. Response duplicates reject with 61; cleanup duplicates with 71 / unconfirmed. Cleanup schema fields are not selectors, nonce and boolean-executed predicates remain unchanged, and no cleanup result turns capability active. Existing stale sentinel detection and file non-mutation remain intact.
- AC-005 (REQ-004): Each challenge emits the normative Codex patch with exactly the generated nonce and no terminal newline. Claude/Copilot emitted objects remain `Write` to `sdd/.hook-canary-sentinel` with empty content. Generating/verifying evidence does not perform the canary write or cleanup itself.
- AC-006 (REQ-005): New repair-only spec/design/task reviews pass with normal identities, hashes and other preconditions. The new task is human-approved before ordinary execution; actual activation is required for ordinary entry. Both original-path suites and latest-head required CI including native Windows pass. After permitted protected application, an actual fresh challenge, one native dispatch, unchanged response and original installed verifier prove `HOOK_ACTIVE`. Retain actual failures, parent target, prior task state and review history. Fixtures alone do not satisfy live proof.

## Roles and Permissions

The implementer may prepare repair-specific inputs and verification within the approved scope. Independent reviewers own review outcomes; only quality-gate owns Done. Human-only protected application remains human-only if the guard denies agent editing. The trusted collector records its own actual native response; it may not fabricate flags or normalize that response.

## Main Workflows

Prepare repair inputs → repair-only provenance reviews → human task approval and permitted protected application → fresh installed-host activation → ordinary task verification / independent quality gate → required CI, safe merge and ticket closure. A newly discovered code defect requires a failing focused regression before its fix; existing code is acceptance-first revalidation, not retroactive TDD.

## Edge Cases

`acceptance-tests.md` expands the selector, member, runtime, nonce, envelope and duplicate branches. Existing compatibility cases are explicitly reused rather than replaced. Missing live evidence leaves AC-006 incomplete even when all fixture cases pass.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| Collector record → verifier | Validate exact content; trust only this session's actual capture, not arbitrary caller provenance | Local diagnostic evidence; no credentials | No new regulated data |
| Reviewed candidate → installed host | Permitted human protected application; fresh real dispatch; no protection bypass | Local version/hash and canary nonce | Existing repository controls |

## Assumptions

The exact documented host envelope is a contract, not a promise that every host emits it. If actual bytes differ, remain unavailable and investigate. Re-check current shared guard membership, installed path/hash and runtime before live verification; never infer them from old reports. Shared main and source hashes must be refreshed at each review/merge. There is no cryptographic collector attestation or persistent replay ledger.

## Open Questions

None requiring new product scope decisions. Installed-host activation and native Windows results are pending verification obligations, not assumed facts.

## Risks

High/security-sensitive: false acceptance permits progress without an actual denial. Overly narrow host formatting may refuse a legitimate changed host; fail closed. A changed candidate invalidates prior bound evidence. Historical tests do not establish test-first ordering.
