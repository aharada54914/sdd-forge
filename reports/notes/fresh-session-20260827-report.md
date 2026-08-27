# Fresh session report — 2026-08-27

Scope: the two jobs in the session brief — finish epic-195's impl round 3 and
re-bind what that unblocked, then drive epic-194's T-001/T-002/T-003 toward Done.

Outcome in one line: **epic-195 is done and green; epic-194 is stopped, and could
not have finished, because its own Done When requires a human action.**

---

## Job 1 — epic-195: complete

Worktree `sdd-forge-wt-epic-195`, branch `feature/epic-195-a7-compatibility`,
commit `ad84a280`, pushed. PR #247 taken out of draft and updated onto main.

### impl-review, attempt 4 round 3

The brief was accurate: round 3 stood with reviewer A alone (seq 941, PASS, zero
FAIL) and no seal, because reviewer B had never been reserved. Verified before
acting that the live spec hashes still matched the round's precheck — they did,
exactly — so the round was resumable rather than stale.

| | verdict | checks |
|---|---|---|
| reviewer A (seq 941) | PASS | 11, 0 FAIL |
| reviewer B (seq 942) | PASS | 11, 0 FAIL, 1 SKIP (DOMAIN-CONFORMANCE — no `domain/` exists) |
| merged | **PASS (clean)** | 0 Critical / 0 Major / 0 Minor |

`Impl-Review-Status` was already `Passed` and was left untouched. This attempt is
a provenance re-review; flipping the header would change design.md's hash without
changing its content, which is precisely the failure the convergence rule exists
to avoid.

Round 2 of this attempt turned out never to have been sealed — it holds both
reviewer outputs but no contract and no integrated verdict. Rather than invent a
chain link, round 3's `prior_round_contract_sha256` points at round 1's contract,
the most recent one actually persisted, and the contract's `human_edit_summary`
states that plainly.

### task stage, attempt 6 round 1 (re-bind)

Sealing impl exposed what the brief predicted: `check-workflow-state.sh` failed
with `task reviewer manifest input hash is stale`, because the attempt-4
amendment wave moved design.md and three layer specs after the task stage last
sealed at attempt-5 round-2. Ran the re-binding lane.

| | verdict | checks |
|---|---|---|
| reviewer A (seq 943) | PASS | 14, 0 FAIL |
| reviewer B (seq 944) | PASS | 9, 0 FAIL, 1 SKIP |
| merged | **PASS (clean)** | — |

Reviewer B recorded that no TYPE-H suppression was needed: every check passed on
its own merits against the amended content. No specification document was edited
by either stage.

`check-workflow-state.sh` now reports **ok**. The two remaining lines are the
tolerated investigation.md amendment-record growth notices the brief flagged as
acceptable.

---

## Job 2 — epic-194: stopped, and structurally unfinishable this session

Branch `feature/epic-194-done-transitions`, commit `f369bba2`, pushed. No task
flipped to Done. No PR opened — the brief's PR step was conditioned on a gate
PASS that did not happen.

### The decisive blocker is a human action, not a gate outcome

T-001, T-002 and T-003 each name the HUMAN APPLY STEP as a **Done-gating** item,
and their own implementation reports record it as still pending:

- `reports/implementation/epic-194-a6-lite-integration/T-002.md:70`
- `reports/implementation/epic-194-a6-lite-integration/T-003.md:81`

Applying a staged payload to protected live paths is a human action. No amount of
remediation, gate running, or panel work moves these tasks to Done while that step
is outstanding. This should be stated up front in any future brief for this epic,
because it bounds what an agent session can achieve regardless of effort spent.

### The panel evidence on disk could not have been gated at all

The three sanitized bundles were regenerated after the remediation wave
(`94925cf1`, `2499e813`, `dc621c83`). The OpenAI and Google slots ran against
those new bundles, but the Anthropic verdicts still carried the digests of the
superseded generation. `check-cross-model.sh` compares every verdict's
`input_digest` against one expected value and hard-fails on any mismatch, so the
stored panel was not merely stale — it was ungateable.

Re-ran the Anthropic slot blind against the current bundles. All three tasks now
carry three vendors on a single matching digest:

| task | digest | Anthropic | Google | OpenAI |
|---|---|---|---|---|
| T-001 | `862d1d4d…` | NEEDS_WORK C3/M4/m5 | NEEDS_WORK M3 | NEEDS_WORK C1/M4 |
| T-002 | `ae927054…` | NEEDS_WORK C1/M6/m3 | NEEDS_WORK M4 | NEEDS_WORK C1/M3 |
| T-003 | `b887b6c4…` | NEEDS_WORK C2/M4/m3 | NEEDS_WORK M4/m1 | NEEDS_WORK C1/M2 |

Unanimous NEEDS_WORK. The findings are recorded as a pre-repair snapshot, not as
resolved items.

### Blockers that survive across vendors

- The required `regression` and `placeholder-scan` checks are `passes: false` in
  all three contracts, and no quality-gate report exists to carry the human
  acceptance the placeholder scanner demands.
- All three contracts pin a stale `spec_revision` (`2740928c…`) against a current
  digest of `466465e0…`, disclosed in the contracts themselves and never reissued.
- No independent quality-gate PASS verdict exists for any of the three.
- T-001's security review covers a deleted draft, records no digest of the bytes
  it reviewed, and explicitly declines to reissue its verdict.

### One severity disagreement, verified in source

The panel splits on the `upgrade_reasons` handling in `check-risk-upgrade`.
OpenAI and Google both rate it **Critical**; Anthropic rates it **Minor**, on the
grounds that it is consistent across runtimes and fail-closed in effect.

Verified directly rather than taking either side on trust
(`specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/check-risk-upgrade.ps1`):

- `Test-PythonFalsy` (line 59) documents in its own comment that a falsy-but-
  present value (`0`, `""`, `false`) is deliberately treated as absent.
- The whole validation sits inside `if ($entry.eligible -eq $false)` (line 177),
  so an `eligible:true` entry carrying a malformed `upgrade_reasons` value is
  **never shape-checked at all**.

The severity is a judgement call. That the `eligible:true` path is unguarded is
not — it is a fact about the code, and it is the half of the finding the Minor
rating does not address.

---

## Controls encountered

**Guard false positive (WFI-053 class).** The guard denied a read-only
*execution* of `impl-review-precheck.sh` on the grounds that agents must not
*modify* gate scripts. The denied command was compound (pipe + semicolon +
`$?`); the identical invocation with those removed was evaluated correctly and
ran. The tokenizer appears to fail closed on compound commands and fall back to
raw substring scanning, so a protected path is flagged by mention rather than by
being a write target. Reported rather than routed around: the fix applied was to
give the tokenizer a parseable command, not to evade the check.

**Fact-forcing gate.** Fires on every `Write` of a new file and on the session's
first `Bash`. Facts were supplied each time.

---

## Traps worth carrying forward

**`tasks.md` is hashed in a normalized form.** `precheck-result.json` discloses
this as `tasks_sha256_form: "normalized"` (lifecycle status lines folded). Two
distinct failures follow from getting it wrong, and both were hit here:

1. A raw byte hash in a reservation manifest is rejected immediately and legibly
   with `REVIEW_CONTEXT_ROUND: the document changed mid-round`.
2. Mixing the two forms between a reviewer's output and the contract is rejected
   much later by `check-workflow-state` as *"task reviewer outputs or integrated
   summary contradict the final PASS"* — a message that names neither the file
   nor the field. Localising it required diffing the jq predicate at
   `check-workflow-state.sh:1105` by hand.

**Reviewer output corrections go to the reviewer.** Reviewer B had recomputed
tasks.md's hash itself and written the raw value. The correction was requested
from reviewer B rather than applied by the orchestrator, and the resulting edit
was verified independently: one `sha256` value changed, verdict/checks/findings
untouched, no file under `specs/` modified.

---

## Left alone deliberately

**Uncommitted gate-script changes in the epic-195 worktree.**
`plugins/sdd-review-loop/scripts/spec-review-precheck.{sh,ps1}` carry an
uncommitted change (WFI-052: letting an investigation.md-only remedy open the
next round). It is workflow-framework work, not epic-195 feature code, and it is
not needed at the impl stage. Committing it would have smuggled a gate relaxation
into a feature PR, so it was left unstaged. Disposition is the owner's call.

**`ANTHROPIC-SLOT-READY.txt`** at the primary root is an untracked scratch note
from the prior session recording the three regenerated bundle paths. It has served
its purpose. Not deleted without instruction.

**The primary worktree changed hands mid-session.** Another session checked out
`main` in `/Users/jrmag/Projects/active/sdd-forge` and pulled, moving HEAD off
`feature/epic-194-done-transitions`. Commit `f369bba2` was already made and is
intact as the branch tip; nothing was lost. The checkout was not taken back, and
the branch was pushed by refspec instead. Anyone resuming epic-194 there should
confirm ownership first.

---

## Remaining human actions

1. **epic-194 HUMAN APPLY STEP** — apply the staged protected-file payloads via
   T-001's runner and verify installed hashes. Blocks Done on all three tasks.
2. **epic-194 remediation** — close the cross-vendor findings above, then re-run
   the panel; the current verdicts are bound to bundles that will change.
3. **The `eligible:true` validation gap** — decide the severity, then fix or
   document it in both runtime twins with tests.
4. **WFI-052 precheck change** — commit it somewhere appropriate, or discard it.
5. **PR #247** — review and merge.
