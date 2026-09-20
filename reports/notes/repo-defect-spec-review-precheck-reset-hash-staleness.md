# Repo defect candidate: `spec-review-precheck.sh --reset` records a stale `requirements_sha256`

Status: candidate (not a formal WFI — `docs/workflow-improvements/**` is out
of scope for this orchestrator's task; filed here as evidence for a future
`workflow-retrospective` to triage and, if warranted, promote to a real
`WFI-NNN.md` under human review).

## Problem

`plugins/sdd-review-loop/scripts/spec-review-precheck.sh` computes
`requirements_sha256` (line 80, `requirements_sha="$(sha256 "$requirements")"`)
**before** its own `--reset` transition (lines 245-252) rewrites
`Spec-Review-Status: Passed` to `Spec-Review-Status: Pending` in the same
file. When `--reset` is invoked against a spec whose header still reads
`Passed`, the `requirements_sha256` value written into that round's
`precheck-result.json` reflects the file's pre-mutation bytes (with
`Passed`), while the live file on disk immediately afterward — the one any
reviewer, contract, or later validation step actually reads — has different
bytes (with `Pending`) and therefore a different SHA-256.

## Reproduction (epic-195-a7-compatibility, this worktree, 2026-07-22)

1. `specs/epic-195-a7-compatibility/requirements.md` had
   `Spec-Review-Status: Passed` and was edited (AC-042/TEST-042 added,
   commit `2ab5d09`) while still declaring `Passed`.
2. `spec-review-precheck.sh epic-195-a7-compatibility 2 1 --reset` was run
   (commit `ad67b5c`). It validated attempt-1's terminal PASS, then:
   - wrote `attempt-2/round-1/precheck-result.json` with
     `requirements_sha256: 0314f09c0e563ff276b6bb2db376e4491638ac37094c5238ab8373fbed3cea99`
     (hash of the file **with** `Passed` still in it, computed at line 80);
   - immediately after, performed its own sed (line 249) flipping the header
     to `Pending`, changing the live file's hash to
     `b93bb7985d757c6ef1674a89e16d7e499ea8ac46222d77fe1d94053d94ab5938`.
3. Both spec-reviewer-a (ledger seq 329) and spec-reviewer-b (ledger seq
   330) were reserved and launched using the live, post-reset hash
   (`b93bb798...`) — the only value `validate-review-context-set.sh`'s own
   live-file hash check (recomputes `sha256_file` against the real file on
   disk at reservation time) will accept. Both reviewers' own
   `allowed_input_manifest` therefore correctly carry `b93bb798...`.
4. `attempt-2/round-1/spec-review-contract.json` was built using the live
   hash (`b93bb798...`) as its own `requirements_sha256`, since that is the
   only value consistent with what the reviewers actually reviewed and with
   `validate_reviewer_output`'s self-consistency check (which compares a
   reviewer's own `allowed_input_manifest` against a value derived from the
   *contract's* `requirements_sha256`, not from `precheck-result.json`).

## Why this is a defect, not just an oddity

`spec-review-precheck.sh`'s own `validate_contract` function (used when
validating a **prior** round or a **prior attempt's terminal round**, e.g.
on entry to round 2 or on a later `--reset`) requires:

```
.requirements_sha256 == $requirements_sha   # precheck-result.json's own field == contract's own field
```

For this round (attempt-2/round-1), `precheck-result.json.requirements_sha256`
(`0314f09c0...`, frozen, stale) can never equal
`spec-review-contract.json.requirements_sha256` (`b93bb798...`, correctly
live) — the two artifacts are permanently inconsistent by construction. No
choice of contract value fixes this: using the stale value instead would
instead break the *other* self-consistency check between the contract and
the reviewers' own real `allowed_input_manifest` entries. This is a genuine
"no legal move" state produced entirely by the script's own line-80-before-
line-249 ordering, not by anything the orchestrator did wrong.

**Practical effect:** any `spec-review-precheck.sh` invocation for **round 2**
of an attempt whose round 1 was reached via a same-turn `--reset` (content
edit + `Passed`→`Pending` reset in one precheck call) will hit this
`validate_contract` check on the *round-1* contract and fail with
`"prior round contract is malformed or does not require work"` —
mechanically blocking the SKILL.md-sanctioned round-2 remedy path, through
no fault of the round-1 evidence itself.

## Root cause

`spec-review-precheck.sh:80` (`requirements_sha="$(sha256 "$requirements")"`)
executes before `spec-review-precheck.sh:245-252` (the `--reset` sed). The
script never recomputes `requirements_sha`/`input_sha` after its own mutation
before persisting `precheck-result.json` at lines 254-262.

## Recommended fix (not applied — `plugins/**` is out of scope here)

Move the `requirements_sha`/`input_sha` computation (and the `foundation_contract`
build at lines 240-243, which also embeds `input_sha`) to **after** the
`--reset` mutation block (lines 245-252), so `precheck-result.json` always
records the hash of the file state that reviewers will actually receive.

## Impact on this session — both SKILL.md-sanctioned recovery paths tested and confirmed blocked

Recorded honestly rather than worked around by rewriting existing evidence.
`attempt-2/round-1`'s own artifacts (`precheck-result.json`,
`spec-review-contract.json`) are left exactly as generated/authored — no
retroactive edits.

After committing round 1's NEEDS_WORK evidence (commit `c67bb80`) and the
content remedy for round 1's three findings (commit `d1dae1b`), both paths
`plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md`'s own
state-transition table allows from "Pending, round 1 NEEDS_WORK" were tried
empirically (both fail before any `mkdir`/evidence-directory creation, so
neither attempt left any partial state):

1. **Round 2 via `--edit-summary`** (`spec-review-precheck.sh
   epic-195-a7-compatibility 2 2 --edit-summary="..."`) — the
   SKILL.md-sanctioned normal next step. **Fails**:
   `ERROR: spec-review-precheck: prior round contract is malformed or does
   not require work` — exactly the `validate_contract` chain-failure this
   note predicted, because round 1's own `precheck-result.json`
   (`requirements_sha256: 0314f09c0...`, stale) can never equal round 1's
   own `spec-review-contract.json` (`requirements_sha256: b93bb798...`,
   correctly live), no matter which value either artifact uses.
2. **`--reset` to a new attempt 3** (`spec-review-precheck.sh
   epic-195-a7-compatibility 3 1 --reset`) — tested as the only other
   listed transition. **Also fails**, independently of the hash defect:
   `ERROR: spec-review-precheck: reset requires a terminal PASS or BLOCKED
   contract` — attempt 2's own round 1 verdict is `NEEDS_WORK`, which the
   script does not treat as terminal (`spec-review-precheck.sh:216`), so
   `--reset` is unavailable regardless of the hash issue.

**Conclusion: this is a genuine dead end via every mechanism SKILL.md's own
state-transition table sanctions from this state.** Continuing would require
either (a) a fix to `spec-review-precheck.sh` itself (`plugins/**`, out of
this orchestrator's scope and not something to edit unilaterally to unblock
its own gate), or (b) some other resolution outside the script's own
sanctioned transitions — both are guard/permission boundaries this
orchestrator does not bypass on its own authority ("ガード/権限denyは迂回
せず停止・報告"). Reported to the coordinator for a decision rather than
guessed at. See
`reports/spec-review/epic-195-a7-compatibility/attempt-2/round-1/spec-review-report.md`
("Orchestrator note") for the pointer from the affected round's own record.
