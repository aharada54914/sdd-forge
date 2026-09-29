# Issue 137 — minimal contract completion addendum

Date: 2026-09-29
Scope: T-001 contract completion only; non-frozen addendum.

## Authority and unchanged boundaries

The human approved the four completions below on 2026-09-29, as relayed by the root orchestrator. This record does not change any frozen specification, approval/status field, review verdict, ledger, or production code. It is a candidate for independent review, not a review PASS or implementation/native proof.

Previously read sources: `specs/sdd-context-continuity/design.md:77–95,135–144`; `specs/sdd-context-continuity/verification/T-001/schema-definition-map.md:13–18`; `contracts/sdd-forge-mcp-tools.v1.schema.json:79–96`; `mcp/sdd-forge-mcp/src/parsers/task-types.ts:8–35`; `specs/sdd-context-continuity/tasks.md:39,57,75,89`. These citations use evidence retained from the prior read-only investigation; original files were not re-read for this addendum. Current source hashes were not re-verified here.

## Approved completions

1. **Opaque identifiers:** every identifier described by the existing design as an opaque ID is a nonempty, well-formed Unicode string whose UTF-8 encoding is at most **1,024 bytes**, inclusive. Over-limit values reject; do not truncate, normalize, hash, or substitute them to gain admission. This bound does not redefine path, conversation-text, hash, timestamp, or complete-response budgets. Existing invalid-Unicode rejection and shared trusted deadline remain mandatory.
2. **ProjectionV1.authorityHashes:** an array of closed entries `{path, sha256}`. Each entry requires both fields; `path` is a string and `sha256` uses the existing lowercase 64-hex SHA-256 contract. Paths are unique: duplicate path entries reject, even when their hashes match. This representation does not expand path access authority or select the complete authoritative dependency set; existing canonical/path/freshness checks remain required.
3. **ProjectionV1.taskLifecycle:** an array of the existing closed `taskEntry` contract, not `taskStateData`. Reuse the existing required fields `id`, `approval`, `status`, `blockersNonEmpty` and optional fields `approvalAnnotation`, `risk`, `requiredWorkflow`, `secondApproval`, including their existing validators/enums. Do not copy `tasksFile`, free-form `failures`, or start the MCP transport. Preserve the existing `parseTaskState` reuse requirement.
4. **ProjectionV1.journalCursor:** a `CursorV1` reference, or `null` only when the journal is empty. A nonempty journal with a null cursor rejects. `CursorV1` retains its existing closed fields and owner validation; a cursor does not authorize foreign/cross-session replay.

## Review and regression targets

- ID boundary: 1,024 UTF-8 bytes accepts; 1,025 rejects; multibyte strings use bytes rather than code units; empty/malformed Unicode rejects without normalization or persistence.
- authority hashes: valid closed entries accept; duplicate paths, unknown keys, missing fields and non-lowercase/non-64-hex hashes reject. Foreign/escaping paths must not become authorized by membership in this array.
- lifecycle: existing valid taskEntry fixtures accept; unknown fields, invalid status/approval/risk and taskStateData-only fields reject. Preserve existing parser behavior.
- cursor: empty journal plus null accepts; nonempty journal plus null rejects; malformed/foreign CursorV1 rejects. Cross-session relationship checks remain separate prerequisites.

These are targets, not executed test results. Independent review and meaningful RED→GREEN evidence are still required before implementation-completion claims.

## Not completed or newly authorized

No reasonCode/diagnostic vocabulary, complete authority dependency inventory, journal chain-start null convention, or additional entity-kind mapping is approved by this addendum. Details not retained or not defined remain unknown, rather than inferred. No generic framework or internal API is introduced.

T-001 remains the validation/privacy/owner/path and safe-store-preparation task. Durable journal append/sync belongs to T-002, authoritative resolver/recovery to T-003, and native lifecycle adapters to T-004. This addendum does not implement or claim their behavior, nor release native owner/path/ACL evidence requirements or existing post-review freezes.
