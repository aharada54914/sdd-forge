# A7 spec attempt 9: failed-first-turn audit

Date: 2026-10-04
Scope: read-only launch-lifecycle audit; not a specification verdict.
Outcome: reviewer B was not allocated, reserved, or launched. Existing reviewer A output and reservation remain unchanged. No integrated summary, terminal contract, status edit, or Git operation was produced.

## Evidence and conclusion

The current owner `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` was read in full, together with the launch boundary, both reviewer roles and supplied templates. Its lines 150–154 require that a failed first turn preserve the consumed reservation and use a new context for a later permitted attempt; they explicitly do not authorize same-session fallback.

Read-only inspection of the real host JSONL confirms a failed first turn followed by a second turn, not an internal continuation of a single successful turn:

Source: `/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge/db5cb845-09ec-4c4a-b27e-e7c461e8a380.jsonl`.

| JSONL line | UTC timestamp | Actual event |
|---|---|---|
| 64 | 2026-10-04T14:01:30.768Z | Bash tool error: `PreToolUse:Bash hook error: [Fact-Forcing Gate]`; requires statement of request and command purpose. Hook's suggested disabling route was not used by this audit and is not a recovery recommendation. |
| 73 | 2026-10-04T14:01:39.247Z | Bash tool error: `Permission to use Bash has been denied because Claude Code is running in don't ask mode.` |
| 83 | 2026-10-04T14:01:47.464Z | Assistant `stop_reason: end_turn`, `entrypoint: cli`, explicitly `結果：BLOCKED（レビュー未実施）`. It states hashes/receipt were not verified and substantive inputs and all seven checks were unevaluated. |
| 98 | 2026-10-04T14:05:46.002Z | New user prompt, `entrypoint: sdk-cli`: `Continue the same reserved review, without reserving again.` It expanded hash-only permission to shasum/printf/cut. |
| 224 | 2026-10-04T14:06:57.701Z | New assistant `stop_reason: end_turn`, `entrypoint: sdk-cli`, returned prose followed by fenced PASS JSON. |

Every event uses session `db5cb845-09ec-4c4a-b27e-e7c461e8a380`. Parent additionally confirmed the actual orchestration was `claude stop db5cb845` followed by `claude -p --resume db5cb845-09ec-4c4a-b27e-e7c461e8a380 ...`; the JSONL independently establishes the first `end_turn` and later same-session prompt. The later PASS therefore cannot supply the normal fresh-first-turn A prerequisite for B. This is a launch-lifecycle defect, not a synthesized Critical/Major specification finding.

The preserved JSON has the canonical A shape and seven ordered checks, but shape and later matching hashes cannot repair the failed-first-turn lifecycle. No counts-and-IDs summary was emitted from this inadmissible A result.

## Preserved bytes

| Artifact | SHA-256 observed |
|---|---|
| `reports/spec-review/epic-195-a7-compatibility/attempt-9/round-1/reviewer-a.json` | `3bd5f237fec511016434eb64562b700c140d62ef2353b2087d8526cf4c749fe7` |
| `reports/spec-review/epic-195-a7-compatibility/attempt-9/round-1/reviewer-a-host-allocation.json` | `d3f53cd877d625c26fc15e18d6bfc338e2cb55e7210be1d637c2f32046526d81` |
| `reports/review-context/epic-195-a7-compatibility-spec-a9r1-a-invocation.json` | `e167c75cffb504e6c1fc5722061270ad739be3f6f80a2f33c48eb19ec507ef51` |

Reservation remains consumed: run `db5cb845`, sequence `1192`, record `a28bab122e95ec6a2d0cdb24fbe1264ebb07c541094073bf6ff4e348ebf9bc83`. Do not re-reserve it, delete its output, change its identity, or rewrite its receipt.

## Minimum legitimate recovery

1. Preserve attempt 9 as diagnostic history. Do not relabel the first failed turn as completed or retrospectively relax the contract to accept its resumed PASS.
2. The existing recovery flag is not sufficient for this state: skill lines 40–49 require no reviewer output; `spec-review-precheck.sh:405–408` requires exactly blocker note, precheck and allocation in the interrupted round. Attempt 9 already contains `reviewer-a.json`. Normal reset at lines 446–449 requires a valid terminal PASS/BLOCKED contract, which this interrupted review does not establish. Do not manufacture one or remove the output to satisfy inventory.
3. An explicitly authorized, narrow forward recovery path is needed for failed-first-turn histories that already have diagnostic returned output. It must admit the preserved interrupted evidence without treating it as review success, determine the next legal attempt through deterministic precheck, and retain all old reservations. This audit does not implement or authorize such a protected workflow change.
4. Only after that legal path is available: allocate a genuinely new idle Claude Sonnet context; persist host-issued identity evidence; prepare manifest-bound inputs and predeclared read-only permissions; reserve once against the latest ledger; start its first turn. Use a separate non-review diagnostic to check the intended hash command permissions beforehand, not the future reviewer context. A new successful independent A is required before sanitized summary and fresh B allocation. If its first turn fails, preserve it and stop; never resume it into a formal PASS.

No existing human-only boundary or guard refusal is bypassed by this proposal. B evaluation and all formal status transitions remain unperformed.

## Narrow forward-recovery contract candidate (not implemented)

Do **not** relax `--recover-interrupted` or its exact no-output inventory. Introduce a separately authorized fresh-review execution contract, with its own exact schema and dedicated admission route, solely for a failed-first-turn diagnostic history. It cannot make attempt 9 valid or convert any old verdict.

Minimum fields/constraints:

- Bind feature, failed attempt/round, next attempt/round, the current Pending input hashes, and the specific approved recovery authority. Next destination must be new and exactly the legal successor; no arbitrary jump or replay.
- Hash-pin the failed invocation, host allocation, original precheck, retained returned output, and a read-only host failure transcript export. Bind both first-turn BLOCKED/end-turn and later same-session resumed output so omission of either fails. Preserve original paths and bytes; an invalidated result remains diagnostic, never a source for a success summary.
- Bind and validate the complete predecessor transition chain back to the last genuine terminal contract, not merely the previous attempt's number. Observed inventory is attempt 7 round 2 terminal `PASS`, attempt 8 round 1 interruption, attempt 9 round 1 reset followed by this lifecycle failure. Attempt 9's precheck records `reset: true` but no recovery-source pins; that file alone cannot prove the 8→9 recovery edge. The new contract must explicitly bind/validate attempt 8's original no-output evidence and original reservation and the complete 7→8→9 chain. This audit has not declared that chain valid.
- Validate every historical reservation using the existing canonical chain rules; never mutate or release them. Require fresh host-issued run/session IDs disjoint from the full ledger, idle allocation receipt, manifest reservation exactly once, then first turn. New A and B are independent; no past raw A reaches either new reviewer.
- The new contract is control-plane authorization for a forward attempt, not a new reviewer output schema and not substantive review evidence. Existing role checks, input allowlists, ordered checks, severity derivation, first-turn rule, and status/contract consumers remain unchanged.

Minimal potential implementation surface, only after separate approval: a dedicated admission validator/route that verifies the new contract and invokes the ordinary current-input precheck publication logic; matching .sh/.ps1 behavior, a small skill routing clause, and focused tests. Reuse existing canonical path/hash, persisted reservation, terminal contract, and immutable-destination validators. Do not introduce alternate ledger writers or weaken the old recovery path. Required negative cases include omitted resumed output, changed diagnostic bytes, forged host receipt, missing/broken predecessor edge, mismatched terminal binding, reused identity, non-next attempt, existing destination, and any attempted old-verdict promotion. Positive case must produce only a fresh precheck and no reviewer/status success.

This is a proposal only. No new contract, protected change, reservation, or state transition was made by this audit.
