# Issue 290 approved implementation handoff

## Confirmed state

- Owner branch: `codex/issue290-concept-test-phase1`.
- Human applied T-001 through T-006 approval; all statuses remain Planned.
- `specs/sdd-domain-concept-test/tasks.md` SHA-256: `907bdbc4649f98c62bd025b863352d62c1643acfa7a4270ab43d95ea0c6d1802`.
- No implementation, task status, review verdict, commit, push, or merge was performed during this preparation.
- Preserve existing identity-ledger modifications and untracked specification/review artifacts.

## Activation boundary

The original handshake challenge command was rejected by PreToolUse before execution. No nonce or HOOK_ACTIVE proof was obtained. A separate ordinary filesystem read found no `sdd/project-context.yaml`; acceptance-tests.md and traceability.md exist. The ship skill's DISABLED_LEGACY/full path applies; it is not native activation evidence. Do not reroute the refused command.

## Next task

T-001 only: extend the concept-test contract and existing signed approval validation, with real-signature regression checks and a high-risk field/counterpart/mismatch-test preflight. Reuse the standard validator rather than the provenance-only path. Bootstrap routing and proposal authoring belong to later tasks.

## Fresh implementation handoff preparation

Read the task and applicable skills again before launch. Use checked-in model selection, immutable snapshot preparation and input-manifest validation. Do not reuse reviewer identities or modify frozen documents.

Two preparation constraints remain, not new findings against the approved feature:

1. The checked-in model registry contains older Codex identifiers absent from the current native tool catalog. Its registered `anthropic/sonnet` route is available: Claude Code `2.1.278`, authenticated subscription route, a fresh no-tool print invocation returned `READY` with `is_error:false`, `terminal_reason:completed`, and runtime model `claude-sonnet-5`. This is availability evidence only, not task validation. Gemini is prohibited.
2. `validate-task-input-manifest.sh` rejects overlapping input/output paths. T-001 modifies existing files needed as inputs. Determine the supported separate snapshot/output-artifact convention from existing contracts; do not silently bypass the overlap check, omit required inputs, or edit the validator under this task.

Implementation has not started. Do not set Implementation Complete or claim RED/GREEN results.

## Read-only preparation completed

A fresh Claude Sonnet print invocation completed a read-only T-001 impact survey (session `09fd3a49-9ac6-4bc4-a1ba-645b5c8474bf`, runtime `claude-sonnet-5`, terminal completed, no permission denials). It made no edits, reservations or review verdicts.

The orchestrator verified the existing independent real-HMAC fixture helper at `tests/validate-approval-sidecar.tests.sh:114-172`. Reuse that pattern with a temporary test key and registered test approver. A missing production signer route does not prevent genuine T-001 validator fixtures; do not misreport it as a fixture blocker. The production signer currently admits only the existing two schemas, so human end-to-end signing support remains a separate integration question, not demonstrated by fixture success.

Preflight fields to bind: feature, proposal, rationale, confirmed relation, each input path and hash, optional decision; cross-check the acceptance-test matrix TEST-051 through TEST-078. Reuse existing canonicalization and HMAC verification rather than introducing new cryptography. No RED/GREEN test has run and no implementation source has changed.

## Resume boundary

The orchestration context compacted before implementation launch. Re-read this file and the approved tasks before proceeding. A fresh implementation context must receive only a checked input manifest and immutable snapshot. Investigate the declared candidate-output convention (separate output directory/patch artifact) rather than overlapping input/output paths or bypassing validation. Validate the complete batch manifest set before launch. Record high-risk preflight before changing implementation. Keep the current tasks Planned until the fresh launch prerequisites are met.

## Independent CI observation

PR #535 run `36882890633` completed successfully for head `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. This does not resolve its independent formal implementation-identity blocker or authorize treating the draft as merge-ready.

## Fresh worker launched — 2026-10-02

The parent inspected the high-risk preflight and changed only T-001 from
Planned to In Progress. All six human approvals remain unchanged; T-002–006
remain Planned. This supersedes the earlier instruction to keep T-001 Planned.

The coordinator reports `TASK_INPUT_OK` for the immutable snapshot and a
separate candidate-patch output. Claude Sonnet session
`0d8fce7c-75ef-403b-a8a9-43a4d4cfb8c0`, exec handle `41234`, is running with
Run ID `issue290-concept-t001-20261002-01`. The coordinator owns that handle;
do not start a duplicate worker. Candidate output is not an applied repair.
RED/GREEN results and independent review remain pending. A supported
implementation-identity registration path is still required before the
quality-gate launch; do not fabricate historical ledger entries.

## Current resume point — 2026-10-02

The launch paragraph above is historical. The RED handoff records that session
`0d8fce7c-75ef-403b-a8a9-43a4d4cfb8c0` completed with exit 0; handle `41234`
is no longer available. Do not restart that worker. The implementation report
records subsequent human application, cardinality repair, and captured macOS
Bash 113/0 and PowerShell 112/0 regressions against validator
`5f1fe69df13bc90baac757aefa56e2e36c82a175b6db1000cee71592e22cbc74`.
These are saved observations, not tests rerun during this handoff correction.
Resume from `reports/implementation/sdd-domain-concept-test/T-001.md`, especially
its final current-source section. Canonical report declarations and a supported
implementation-identity recovery remain prerequisites for the independent
quality gate; do not replay task review or invent a historical reservation.
Native Windows verification, current-head CI, merge and completion remain pending.
