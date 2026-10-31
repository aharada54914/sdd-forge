# A7 attempt 17 input readiness (read-only check)

2026-10-05. This is preparation, not a recovery contract, approval audit, precheck result, reservation, or formal review verdict. No protected original or existing review evidence was changed.

## Current boundary

- The three protected originals still match the **before** hashes in `a7-attempt17-recovery-candidate-20261005/human-apply.py`; revision-2 `recovery.patch` has not been applied. In particular the installed `spec-review-loop/SKILL.md` still restricts `failed_final_round` to the immediately preceding attempt, so the attempt-17 combined-history contract cannot be admitted by the installed helper yet.
- No **final** attempt-17 approval audit, contract, round directory, or reservation was found in this owner checkout. Non-formal candidate JSONs were subsequently prepared under `a7-attempt17-recovery-candidate-20261005/`; do not treat them as admitted records or reuse any attempt-15/16 reviewer identity.
- Current input SHA-256 values match the attempt-16 contract: requirements `492f54a812be75ca20d0a05ec41dcf225f9b1b17cd512148498e02cf954dd96c`; acceptance tests `dca8c1551ea0f268fc02944a8e0fe078b557c416ef3f37649c7c33590fff6d13`; investigation `7a908bed637e779925d11ef4bd396be0dfd88e20c2e300548302e055acafce57`; calibration `537f776558cf4b4a99ee455a974857a67e249242dce5806e23d37d6802f2a385`; combined input `6511157301430981ef7d5c182972acbdfce8c01c60c15b0e90a2b5a993b61a05` (from the attempt-16 contract, to be recalculated immediately before admission).

## Exact contract construction after permitted installation

Use `a7-spec-fresh-review-contract-attempt16-20261005.json` (SHA-256 `b561635431116926ac3195893f276a2e67ad6fde980de6ce867a0a834816eb03`) only as source data, not as the attempt-17 authority. Set `next_attempt` to 17; append 16 to `partial_attempts` (8–16); move the existing top-level `failed_final_round: 3` and `failed_turn` into the single `historical_failed_rounds` item with `attempt: 15`; omit those top-level keys because attempt 16 is a round-1 no-output partial. Keep the terminal attempt 7 and all previous evidence pins and historical disposition. Keep the existing attempt-15 transcript path and hash `7d66b08785d3e2c6d635608867a07771cb4a146833ef828a80efff8d0c7ad909` as contract transcript; attempt-16 diagnostic host transcript remains separately retained and must not be substituted as proof of a completed review.

Add exactly these four attempt-16 evidence pins, subject to fresh readback:

| Relative path | SHA-256 on this check |
|---|---|
| `reports/spec-review/epic-195-a7-compatibility/attempt-16/round-1/precheck-result.json` | `bc35f564ec1a0bd03eb1805a40fdec200d19c5f4b9e6835f06c7d5c264477acd` |
| `reports/spec-review/epic-195-a7-compatibility/attempt-16/round-1/reviewer-a-host-allocation.json` | `09d1c7951c26ef046e01f4fe34c9c24c8df81117f173a46179fd8e9b71089db1` |
| `reports/spec-review/epic-195-a7-compatibility/attempt-16/round-1/launch-blocker-note.md` | `04d73ceb0e6f560a31db9470cce2264f2b3e3518f34007cb07dfb2b58d6072ce` |
| `reports/review-context/epic-195-a7-compatibility-spec-a16r1-a-invocation.json` | `04f7b6e81a782a85e28fdf58d6ed05f9daaa47221c8f1ab5e7df7987bbcda21a` |

The attempt-16 approval audit pin must be removed and replaced by a new, next-attempt-17 approval audit under `reports/verification/`. The orchestrator must transcribe the existing user's exact authorization, identify its actual origin, bind the current input hashes, and then pin the new audit's actual bytes in the contract. Do not merely relabel the attempt-16 audit or claim a new human signature. The current ledger SHA-256 was `01656bd04a19434eedfbe5f34263ad8078ee286e2d30dad33456f245db562e19`; it is dynamic reservation state, not a hash to copy into the recovery evidence array.

Only after the approved protected patch is applied and read back, the actual audit and exact-evidence contract can be created and checked with the installed recovery validator. Normal `--reset --fresh-review-contract=<path>` precheck follows; it must run before any new host identity allocation or reservation. A rejected protected operation or failed precheck is a stop, not a reason to try another route. Independent review of revision 2 and actual host admission remain separate gates.

## Candidate preparation result

The non-formal approval audit candidate SHA-256 is `7b8ce385bb454910a24301072f969ab227aa860446243925522c6751e93d362c`; the non-formal contract candidate SHA-256 is `dacad1c54f869d1df9700aa994a97fb2090e23a853b5329c973424dbca3db497`. The contract contains 66 exact evidence pins and partial attempts 8–16. The candidate helper, with only its internal historical failed-attempt helper redirected to candidate bytes, validated current real owner evidence and returned the preserved completed rounds `(15, 1)` and `(15, 2)` (exit 0). No installed precheck or protected apply was executed; final authority transcription and immutable placement remain orchestrator responsibilities.
