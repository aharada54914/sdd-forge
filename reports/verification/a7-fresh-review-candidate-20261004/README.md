# A7 fresh-review recovery — human apply candidate

Status: CANDIDATE / NOT VERIFIED. Protected owner source was not applied.
Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`
HEAD: `d64cffcb22b114779202847be33e41700c4ba11f`

## Exact human action

Run this only as the authorized human owner after reviewing `recovery.patch`.
The agent must not execute this command or switch executors to evade the hook.

```sh
rtk proxy python3 /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/verification/a7-fresh-review-candidate-20261004/human-apply.py --apply --expect-runner-sha256 cb5ca21647a2a0efdcc817eea8561ce60222a79d9dcdf40ea0a0477e0955b69d
```

Runner SHA-256: `cb5ca21647a2a0efdcc817eea8561ce60222a79d9dcdf40ea0a0477e0955b69d`
Review patch SHA-256: `12982f5184a4898624bdb962500373b6a7b46588ce839d4828cde29a7540b125`

Five exact targets below are pinned to current dirty bytes, not Git HEAD content.
The runner validates HEAD, non-symlink paths, all before/after hashes, takes
read-back-verified backups before the first write, rejects repeated apply and
changed bytes, and verifies every applied file. It does not alter ledger,
specification status, review reports or identity reservations. It never executes
the candidate scripts. Successful output is only `Applied once ... NOT VERIFIED`.

Dry-run uses the same command with both `--apply` and
`--expect-runner-sha256 ...` omitted. Default mode writes nothing.

## Exact target pins

| Target | Before SHA-256 | After SHA-256 |
|---|---|---|
| `plugins/sdd-review-loop/scripts/spec-review-precheck.sh` | `486966e2f2aaa176ed0b8ca6b5418649d7fb24d3b7ee9b7a2a04a240fc6016e1` | `7c540cb425de6ee430689d0d4bb02ba6068c0c9dee7401c8d6e5dd8b1a1f24d6` |
| `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` | `145795e1c7e7fda82224e961f8c869c08b633f94fb9ff43e065dc42e43cc2250` | `294956150a5bcfafc2d500e35aa9d6d247e5470162431dd5eb45a965ebb52528` |
| `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` | `bda27737bc7074d1f802aad52b69bde0eed47d20e256554acf0341180f515c24` | `8828e5103b669e39385f60720d2cc6a02e40f14d6e1e7758d3c07a94dfbfa7d4` |
| `plugins/sdd-review-loop/scripts/fresh-review-recovery.py` | `446cc12db071ebd8c80a30a83a91e47b9d7d2ba377dd8db3d0bfe1f740113e16` | `b45adc1a7cb445819ce98f58aeb42db630cc4f32b36e0b950279404c3a8528f0` |
| `specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py` | `ddb788633808ad5eaf5168542bb8b7751aa3e92c3f5194fd892825e27edcaa2e` | `b42bef4065a3c40f95eb5d96e3b1c76201086fad1e568cf0f76c408bdcd6dd11` |

## Verification performed

All checks ran in the owner checkout on 2026-10-04, with exit 0:

- `rtk proxy bash -n reports/verification/a7-fresh-review-candidate-20261004/spec-review-precheck.sh.candidate`
- PowerShell `Language.Parser.ParseFile` on the PS candidate; zero parse errors.
- Python `ast.parse` on runner, helper candidate and fixture candidate.
- `rtk proxy git apply --check reports/verification/a7-fresh-review-candidate-20261004/recovery.patch` (check only).
- `rtk proxy python3 reports/verification/a7-fresh-review-candidate-20261004/human-apply.py`

Dry-run output:

```text
DRY RUN OK: 5 exact targets; no writes; no candidate execution; NOT VERIFIED
```

No candidate precheck, helper, or fixture was executed. The old recovery fixture's
30 passing groups are parent-reported pre-candidate evidence, not proof of this
change. Actual apply, new behavioral regression, independent review and formal
gate are NOT VERIFIED / not performed by this preparation.

The initial fixture's missing `make_fixture_contract` reference is eliminated in
the candidate by a fixture-local builder. Test-only transcript data is explicitly
synthetic and must never be reused for real recovery. The new fixture covers
current-input mismatch, next-attempt mismatch, evidence hashes, missing ledger,
B invocation, transcript session, invalid terminal anchor, post-lock ledger
mutation, replay and historical byte preservation in Bash and PowerShell.
These are planned executable checks, not reported passes.

## Scope and invariants

- Existing no-output `--recover-interrupted` admission remains unchanged except
  Bash now repeats persisted reservation validation after acquiring the lock,
  matching existing PowerShell behavior.
- New opt-in `--fresh-review-contract` / `-FreshReviewContract` is mutually
  exclusive with old recovery and requires reset, next-attempt round 1 and Pending
  current inputs. Python 3 is required only on the new path.
- Shared read-only helper checks pinned 7 → 8 → 9-style history and diagnostic
  host transcript. Existing terminal and reservation validators remain
  authoritative and are called both before and after the lock. No source output
  is promoted into a verdict.
- The exact contract bytes parsed are hashed at read time and checked unchanged
  at return; both wrappers compare helper hashes with initial cached input hashes
  and repeat full admission under lock.
- Only a precheck containing `fresh_review_contract_sha256` may be emitted.
  No fresh reviewer identity is invented, allocated or reserved by this change.
- Skill text distinguishes hook-authorized same-first-turn retry from prohibited
  new-turn resume after BLOCKED end_turn. Permission diagnostics run separately.

## Persisted evidence consistency checklist

| Persisted field | Counterpart | Negative regression planned |
|---|---|---|
| fresh_review_contract_sha256 | exact immutable contract bytes | contract/evidence digest mismatch; replay |
| requirements/acceptance/investigation/calibration/input hashes | current bytes and authorized input_hashes | current-input mismatch |
| attempt/round/feature/reset | consecutive historical attempts and Pending header | wrong-attempt; invalid terminal |
| previous diagnostic output and transcript identity | reserved invocation, allocation, host session | transcript-session; missing-reservation; B invocation |
| historical output/ledger preservation | pre-run byte snapshots | valid-case immutability; post-lock-ledger rejection |

## Restore exact pre-apply bytes

The apply prints an absolute `Backup:` path under this package before source
writes. Retain it. For a failed/partial apply, inspect output and current hashes;
do not retry apply. Restore admits only targets still matching pinned before or
after bytes and refuses unrelated subsequent edits.

Use the printed exact backup directory (do not use a glob):

```sh
rtk proxy python3 /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/verification/a7-fresh-review-candidate-20261004/human-apply.py --restore <printed-absolute-backup-directory> --expect-runner-sha256 cb5ca21647a2a0efdcc817eea8561ce60222a79d9dcdf40ea0a0477e0955b69d
```

Restore verifies backup receipts/hashes and read-back, preserves the backup and
leaves all unrelated dirty changes intact. A crash may retain the package's
`.human-apply.lock`; confirm no apply process is running and inspect the backup
before the human removes that empty lock directory. Do not remove it automatically
or change expected hashes to force execution.

## Resume after human application

First verify the five exact after hashes and receipt. Then run both old and new
fixtures against the applied source in isolated repositories; do not execute
candidate copies as a protected-write workaround. Recheck casing parity and
fresh contract/reservation input bindings. Only after passing behavioral
regressions and independent review may the separately approved orchestrator
prepare an actual fresh contract from preserved host evidence and start a new
attempt. An actual future contract and host transcript are deliberately not
created or fabricated by this package.
