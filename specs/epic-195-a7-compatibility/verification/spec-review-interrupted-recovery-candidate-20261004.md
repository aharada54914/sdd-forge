# Spec-review interrupted round-1 recovery candidate (2026-10-04)

Status: **implemented; recovery regressions passed; reviewer A output is NOT admissible for the formal gate**. This is a
non-frozen implementation handoff, not a reviewer verdict or a terminal
contract. The prior reservation and attempt-8/round-1 bytes remain untouched.

## Verification update

- Repeated the fixture after real attempt-9 existed. The original fixture
  incorrectly copied that occupied destination and failed before exercising
  recovery. It now selects only the required historical attempt-7/8 inputs;
  all 30 groups passed (15 Bash, 15 PowerShell). Real reports and ledger were
  unchanged. Fixture SHA-256:
  `9f675c2c31fe56e23ea50cb54e90d685aa68623ffb3568a78b41edf37384079c`.
- A separate non-review Claude Sonnet diagnostic session
  `2404cd77-098b-42ad-a0c8-3323125f1a0e` confirmed actual hash-command and Read
  success with hooks enabled. Its first Bash call was denied by the
  fact-forcing hook; the same command then succeeded within the first turn,
  following that hook's instruction. This proves tool availability only,
  not formal review admission or a reviewer verdict.
- Authorized implementation is present in both prechecks and the review-loop
  instructions. The isolated interrupted-recovery fixture passed 15 groups
  on Bash and 15 groups on PowerShell. The existing spec-review-loop suite
  passed in the disposable checkout. Native Windows execution is not claimed.
- Original Bash precheck `9 1 --reset --recover-interrupted` completed with
  exit 0. New precheck SHA-256:
  `5a7dc3ffd060060c62f1416ee81175274620f08c8805ea37ed84a50fc7e0d27d`.
- Reviewer A was allocated before reservation: run `db5cb845`, session
  `db5cb845-09ec-4c4a-b27e-e7c461e8a380`; reservation sequence 1192,
  record `a28bab122e95ec6a2d0cdb24fbe1264ebb07c541094073bf6ff4e348ebf9bc83`.
- First review turn stopped before substantive inputs: the fact-forcing hook
  required an explanation, then the permission layer rejected a compound
  command containing receipt hashing outside the hash-only allow rule.
  This is not a spec finding or PASS. The same persisted session was resumed
  with explicit read-only `shasum`, `printf`, and `cut` permissions; hooks and
  write prohibitions remain enabled. No second reservation was made.
- Resumed session completed with no permission denials, independently verified
  all five file hashes and the reservation receipt, and returned reviewer A
  PASS (six PASS checks, DOMAIN-CONFORMANCE SKIP). Its unchanged canonical
  JSON was extracted to `reports/spec-review/epic-195-a7-compatibility/attempt-9/round-1/reviewer-a.json`.
  This establishes actual resumption only. Subsequent launch-contract audit
  found that stopping the first turn and using `--resume` for a later turn
  violates this skill's Identity-allocation failure handling rule requiring
  a new context for a later permitted attempt. The returned PASS must NOT be
  used as formal gate evidence. Retain the output and reservation unchanged;
  do not fabricate a terminal verdict or delete evidence to admit a retry.
- Reviewer B launch is withheld until a valid fresh-context recovery path is
  established. Integrated verdict, independent implementation evaluation, CI
  and merge remain pending. The historical proposal below records the original failure
  and is not a statement that implementation remains unapplied.

## Observed boundary

- `attempt-8/round-1` contains only `precheck-result.json`,
  `reviewer-a-host-allocation.json`, and `launch-blocker-note.md`. Reviewer A's
  invocation `reports/review-context/epic-195-a7-compatibility-spec-a8r1-a-invocation.json`
  is reserved as sequence 1191 in the identity ledger. No reviewer output,
  summary, integrated verdict, or B allocation exists in that round.
- Bash and PowerShell prechecks both reject `9 1 --reset` with
  `reset requires a terminal PASS or BLOCKED contract`. Bash also rejects
  replay of `8 1` and advance to `8 2` (no NEEDS_WORK contract). These are
  expected current-code failures, not a new independent review result.
- A normal `apply_patch` of the protected Bash precheck was denied by the
  PreToolUse deterministic gate: agents may not modify gate scripts, hook
  configuration, or critical tests. No script byte was changed. Do not edit
  only the PowerShell twin or run a modified copy as a workaround.

## Minimal, explicit recovery contract for human implementation

Add an opt-in `--recover-interrupted` / `-RecoverInterrupted` flag to the
respective prechecks, valid only together with `--reset` for target attempt
`N+1`, round 1. Leave ordinary reset and round-advance behavior unchanged.
Before taking the existing lock or writing a target, require all of:

1. The immediate prior attempt `N` has exactly round 1 as its latest round,
   with regular, non-symlink `precheck-result.json`, status `Pending`,
   `reset:true`, the matching feature/attempt/round and well-formed pinned
   SHA-256 fields. The prior round has **no** reviewer output, integrated
   summary/verdict, or terminal contract. Do not synthesize any such artifact.
2. The prior round has an original host allocation and blocker note, plus a
   reviewer-A invocation in `reports/review-context/`. Validate the exact
   precheck path/hash in its allowed-input manifest; compare its run/session,
   sequence, previous-record hash, and allowed-input binding to one and only
   one existing `identity-ledger.json.records[]` entry. Validate the ledger
   record chain, not just a matching string. Do **not** require the record to
   be the current ledger tip: unrelated later reservations are legitimate.
   Require no B invocation file, host receipt, or reviewer output for this
   round. The ledger has no feature/attempt/round fields, so a B record alone
   cannot be attributed to this round and must not be claimed as disproved.
   Identity sequence
   1190 from the earlier task review is not reusable.
3. Attempt `N-1` still has a valid terminal PASS/BLOCKED contract under the
   existing `validate_contract` / `Test-ValidateContract` logic. This is
   proof that the interrupted `N` was itself a legitimate reset, **not** a
   fabricated terminal verdict for `N`.
4. The target `N+1/round-1` does not exist. Re-read and hash the *current*
   requirements, acceptance, investigation and calibration inputs, and write
   a fresh ordinary precheck in the new destination. The current inputs need
   not equal the interrupted round's pinned bytes; the invocation must keep
   its original pins. Recheck destination/exact source state under the normal
   lock. Do not mutate or rewrite `N`, its invocation, or its ledger entry.

This candidate is intentionally narrower than the unimplemented A9
round-2/3 recovery design and does not rely on A9 code. The human applying
it should bind the exact authorization to this incident and retain the
launch-blocker note; the option must not become a general bypass for a
completed or partially reviewed round.

## Protected targets and human-only apply boundary

- `plugins/sdd-review-loop/scripts/spec-review-precheck.sh` pre-apply SHA-256:
  `81e345db1d1d96acec6a5ddd2159e01d6653cfb879ad2cf2a032e20b887b4c1b`
- `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` pre-apply SHA-256:
  `ac2532f6450dde24b78e4ab7b577a04ef9b1e8d165a180152737789b5ac6fb85`

Human-owned application should first re-check both hashes and inspect the
exact proposed diff; if either hash differs, stop and rebase the candidate.
Apply both runtime changes in one authorized operation under the native guard,
without disabling hooks. An agent must not use `git apply`, a copy, or a
different executor to force past the observed denial.

## Required regression after authorized application

Run the same fixture matrix through both runtimes: normal terminal reset
still succeeds; interrupted first-round recovery succeeds only as a fresh
`N+1/round-1`; old precheck/invocation/ledger hashes remain unchanged;
replay, wrong target round/attempt, missing or mismatched reservation,
changed invocation/precheck hash, B invocation/receipt, reviewer/summary/verdict
output, non-terminal `N-1`, malformed/symlink source, and occupied destination
all reject *without new evidence writes*. Include a later unrelated ledger
reservation positive case. Then run `tests/spec-review-loop.tests.sh` and the
new isolated fixture against both runtimes, and only after those checks run the real
`9 1 --reset --recover-interrupted` precheck. Its success alone is not a
review PASS; reviewer A/B must receive fresh host-issued identities and
manifest-bound launches.
