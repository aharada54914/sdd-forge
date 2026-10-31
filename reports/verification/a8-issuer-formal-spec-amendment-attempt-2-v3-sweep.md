# A8 issuer amendment attempt 2 v3 — author sweep

Session: `01a100bf-a245-7560-8501-71c04f506483`

Status: candidate only; no frozen artifact was modified, no review was launched,
and no test implementation or cross-platform execution occurred.

## Supersession

The following retained candidates are malformed or incomplete and were not
applied: `a8-issuer-formal-spec-amendment-attempt-2.patch` and
`a8-issuer-formal-spec-amendment-attempt-2-native-apply.patch`. This v3
candidate explicitly supersedes them. Their evidence remains retained.

## WFI-023 identifier sweep

Command (read-only):

`rtk proxy rg -n "AC-015|AC-016|AC-026|AC-027|AC-028|sole nonce issuer|sole issuer|sole authorized|issues nonce|signs ledger|one write|Epic A1.*writes|handshake script.*write|issuer|issuance|nonce|consumer entry point" specs/epic-196-a8-integration/{requirements.md,design.md,acceptance-tests.md,ux-spec.md,frontend-spec.md,infra-spec.md,security-spec.md,tasks.md,traceability.md,investigation.md}`

Resolved in the proposed bytes:

- `requirements.md`: AC-015/026 issuance language distinguishes A1 generation,
  external issuer signing, broker verification/append, and native proof.
- `design.md`: component table, dependency statement, existing-data/migration
  text, ledger writer text, and broker contract use the same responsibility split.
- `frontend-spec.md`: the complete row 47 source line is replaced; the earlier
  prefix-only deletion is not reused.
- `infra-spec.md`: storage row and lines 214–220 describe both additive writers.
- `security-spec.md`: Mermaid B4 edge, B4 row 65, authorization row 99, and OWASP
  row 122 no longer say A1 writes or signs the ledger entry.
- `acceptance-tests.md`: TEST-031–093 split signature/trust, each signed field,
  duplicate-cell variants, concurrency/storage/interruption, pre/post-append,
  overrides/paths, expiry, role separation, every semantic cell, every named A1
  consumer, OS case behavior, and LF/CRLF behavior into concrete rows.

Legitimately unchanged:

- Existing ledger schema, field names, JCS/hash/domain-separation rules, keys,
  signer registry, signatures, approval model, live-host record schema, five
  semantic cells, five consumer names, SKIP activation, and validator error names.
- `ux-spec.md` contains only generic consumption prose and no issuer/write claim.
- Requirements/design references to A1 as challenge/nonce source remain valid.
- `investigation.md:46` remains historical evidence about five consumers; its
  stale pre-merge wording is superseded by the proposed design note, not edited.
- `tasks.md`, `traceability.md`, and all approvals/statuses remain frozen and
  byte-unchanged. Stale task wording (including `tasks.md:838`) is explicitly
  deferred to Phase 2 task drafting/re-review after the amended design gate.

## WFI-014 and execution boundary

All new TEST rows are `Planned`. TEST-077–086 remain manual-required native
session/consumer cases. TEST-087–093 are planned automated cross-platform
fixtures; this author session did not run macOS/Linux/Windows implementation
tests and makes no such execution claim.

## Applicability validation contract

The companion validator parses the native apply_patch candidate, requires every
old/context block to occur exactly once in the current frozen source bytes,
reconstructs every target wholly in memory, and reports original/reconstructed
SHA-256 values. It never writes a frozen target. A marker count or JSON-shape
check is not treated as applicability evidence.

Recorded command output: `APPLICABLE_IN_MEMORY`; all 17 hunks matched their old
blocks exactly once. The result file records per-file source, reconstructed, and
unified-diff SHA-256 values plus addition/deletion counts. An earlier validation
run found a zero-match design hunk; the candidate-only spacing error was fixed,
that failed output remains visible in the author-session transcript, and the
successful validation was then recorded. No protected operation was denied.
