# A8 attempt 9 round 2 continuation — 2026-10-06

## Owner and result

Owner checkout: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`.
Observed HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`. Existing dirty work is retained.

Formal round directory: `reports/impl-review/epic-196-a8-integration/attempt-9/round-2/`.
Reviewer A: PASS, 10 PASS / 1 SKIP / 0 FAIL.
Reviewer B: NEEDS_WORK, one Major `DESIGN-WITHIN-SCOPE` finding.
Integrated result: NEEDS_WORK, Critical 0 / Major 1 / Minor 0. Canonical reviewer files, integrated-summary.json, integrated-verdict.json and impl-review-contract.json are saved. Round 1 BLOCKED and all earlier records remain unchanged. Counts include findings, not textual advisories inside PASS checks.

No new reservation, protected application, task-status change, Git operation or CI run was performed for this handoff.

## Reviewer B delivery audit

Actual Sonnet 5.5 session `d5effa48-8ba6-4e98-92d1-6c8d299a5a64`, run `RUN-epic196-impl-a9r2-b-d5effa48`, exited 0 after 24 turns. The original CLI JSON result was preserved; only its enclosing Markdown fence was removed for reviewer-b.json. No result was reconstructed from redacted debug text.

Normal hooks remained active. The initial hash command encountered an ECC purpose gate. A subsequent SHA256 operation over the same 13 admitted inputs succeeded after removing unrelated wc/grep operations. Debug evidence does not retain intervening purpose prose; do not claim it does. No alternate executor or disabled hook was used.

The reviewer independently read all 13 admitted inputs and verified their hashes. Large files were split across ranges; investigation reached line 680 plus its terminal newline, and design reached line 1838. B received A's counts-only summary, never A's raw output.

Sequence 1208 receipt hash: `e581cbf1c49049b0c738473e15234950d24a0e02da1981a7806e40281b31c1ef`.
Previous record: `6bd7c32b08b2676fd2ea302fbc461d4e2c2579051760dafec81e9f84b52dc4ed`.
The reviewer recomputed the record from the actual manifest-order input digest `352ef93ed119ffe8a2c81a6bfddb4658d7b819e11eb27e28b8384fac785a817f`. A prompt's sorted-order instruction was incorrect: the reviewer tested it, observed its mismatch, and used the contract's manifest order. Preserve this correction in future invocation prompts. Sequence 1206 was not reused.

CLI debug: `/tmp/a8-a9r2-b-d5effa48-debug.log`; parent exec session 26725, exit 0. A delivery is recorded separately in `a8-a9r2-a-delivery-audit-20261006.md`.

## Confirmed remaining defect

AC-016 at requirements.md:441–448 requires all five migrated consumer entry points (`sdd-ship`, `sdd-bootstrap`, `sdd-bootstrap-interviewer`, `lite-spec`, `lite-gate`) per runtime/cell, with fingerprinted inventory and source citation; partial coverage cannot count as complete.

Design mentions the inventory (AC-015/016 mapping around line 523, classification around line 1522), but does not define its machine-readable shape, storage or completeness rejection. The live-proof record at design.md:571 uses exact keys. `plugins/sdd-quality-loop/scripts/validate-live-host-proof.py` has exact RECORD_KEYS near line 30 and requires schema v1 near line 337; inventory is absent. Its AC-016 reference near line 260 only identifies allowlisted cases. The five current live-proof records contain draft-SKIP prose in notes, not a consumer inventory. `tasks.md` T-008 references TEST-016 shape validation and a complete fingerprinted inventory, without a concrete inventory contract. Searches of existing proof tests and feature verification files found no reusable consumer-inventory format. The loop inventory is a different artifact and does not satisfy AC-016.

## Minimal amendment candidate (not applied)

Define one inventory entry for each of the five named consumers in each of the five existing semantic cells; require exact membership, uniqueness and correct cell binding. Each entry records the required consumer name, immutable A1 package/source citation and observed evidence binding. Missing, duplicate, unknown or mismatched entries must fail completeness; draft SKIP must never imply execution. Continue distinguishing correct unavailability detection from actual consumer execution.

Prefer extending the existing signed live-proof record explicitly under a versioned schema, with inline consumer entries included in the existing JCS/signature coverage. Reuse the current signers, nonce and proof-path checks; do not introduce a second ledger, new execution gate or new signing mechanism. This is only a candidate: current v1 rejects additional keys, so silently adding a field is not compatible. Before adopting a version transition, sweep all schema/version consumers, fixtures, signed-record generators, docs and tasks, and specify how historical v1 proofs remain preserved but cannot prove the new AC-016 completeness condition.

Do not hide the inventory in notes or alter native raw capture bytes. Neither produces a sound machine-checked, signed inventory. Do not claim unavailable cells executed all consumers.

## Next concrete operations

1. Read canonical reviewer-b.json and preserve its finding verbatim in the next proposed-change record.
2. Sweep `live-host-proof/v1`, RECORD_KEYS, signing/generator callers and TEST-016 across the owner checkout; pin the amendment to the existing record format rather than create an unrelated framework.
3. Resolve the smallest explicit schema transition and produce a design/contract candidate plus negative-case matrix (missing, duplicate, unknown consumer; wrong cell/source/evidence; draft SKIP; signature mutation). No protected originals are changed by this note.
4. Use the sanctioned protected-application path for approved candidate bytes, then normal next-round precheck and fresh independent reviewer identities. Do not reserve before prerequisites pass or overwrite round 2.
5. Only after design/task contracts and implementation regressions succeed proceed to native activation, latest-head CI, merge and post-merge checks. All remain unproven here.
