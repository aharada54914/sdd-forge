# Issue #290 task provenance re-review: launch-readiness preparation (2026-10-03)

Status: preparation only. This is not a reviewer input, a reservation, an adopted
reviewer result, a verdict, or authorization to edit the protected role files.

## Current boundary

- `task-review-precheck.sh sdd-domain-concept-test 4 1 --verify-inputs`
  succeeds against the persisted attempt-4/round-1 precheck.
- The attempt-4/round-1 reviewer-A launch diagnostic records a real denied
  attempt to read `reports/review-context/identity-ledger.json`. Its sequence
  1206 is consumed; the unadopted reviewer output must not be reused.
- Both `task-reviewer-a.md` (lines 68-77) and `task-reviewer-b.md` (lines
  74-83) instruct the reviewer to read
  `plugins/sdd-review-loop/references/review-context-boundary.md`.
  `validate-review-context-set.sh` `path_is_authorized` (lines 273-285) does
  not authorize that reference for either task role. Adding it to an invocation
  manifest would fail validation; supplying its text via chat would not meet
  the file-manifest requirement. The ledger is likewise not an authorized
  reviewer input. No read through another route is permitted.
- The role files and `validate-review-context-set.sh` are protected gate-chain
  files (`plugins/sdd-quality-loop/references/guard-invariants.json`); this
  preparation does not alter them.

## Narrow correction candidate requiring separate authorization

Amend the same two paragraphs in both protected task-reviewer role files, not
the validator allowlist or the ledger. Retain the instruction never to rerun
the reservation validator after `--reserve`. Replace the direction to read
`review-context-boundary.md` and to inspect the ledger record chain with a
self-contained launch check using only the caller-quoted `REVIEW_CONTEXT_OK`
receipt and the role's own invocation manifest:

1. Match receipt `sequence` and `previous_record_sha256` to the manifest;
   require `sequence = pre_append_tip_sequence + 1` for a new reservation.
2. Recompute the quoted record hash from the manifest fields using the
   validator's task-stage record recipe, and require `identity_unique=yes`.
3. Check manifest schema/stage/role/feature, `input_mode: file-manifest`,
   `fallback_mode: none`, `read_only: true`, the canonical ledger-path
   *string*, and each listed input's path/hash. Read no unlisted file.
4. State that `identity_ledger_sha256` describes the pre-append ledger and is
   validator-owned; it must not be compared with the post-reservation ledger.
   The reviewer must not open or hash the ledger itself.

For a new task-stage reservation, the current validator computes the record
hash as SHA-256 of UTF-8 text with no terminal newline:
`<sequence>|task|<role>|<run_id>|<host_session_id>|<previous_record_sha256>`.
The task stage has no `allowed-inputs-v1` or scratch-declaration suffix in the
current validator (`validate-review-context-set.sh`, lines 530-536 and
1117-1124). A protected edit must still compare this recipe with the then-current
validator before approval. A role-only correction avoids expanding the
reviewer input set. This candidate is not yet applied or validated as a
protected-file change.

## Fresh launch conditions after an authorized correction

1. Re-run attempt-4/round-1 `--verify-inputs`; if any bound input changed,
   stop and follow the task-review-loop state machine rather than reusing this
   precheck. The normalized `tasks_sha256` is taken from `precheck-result.json`.
2. Obtain fresh, actual reviewer-A run/session identities. Build a new
   one-role canonical invocation manifest from the then-current ledger and
   exact allowed inputs. Do not reuse sequence 1206 or its invocation file.
3. Reserve once with `validate-review-context-set.sh ... --reserve`, quote its
   actual `REVIEW_CONTEXT_OK` receipt, and launch fresh reviewer A. Adopt its
   output only if no permission denial occurred and the complete output
   validates. Reviewer B needs a separate fresh context and reservation after
   the deterministic integrated summary exists.
4. Only after both formal outputs and the task-review contract are persisted,
   run `check-workflow-state.sh --feature sdd-domain-concept-test`. Its current
   `stage-provenance: task plan hash is stale` failure is expected until the
   amended plan is re-bound. Independent quality-gate review is a later step.
