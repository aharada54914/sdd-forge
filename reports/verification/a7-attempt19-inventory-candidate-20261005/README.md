# A7 attempt-19 interrupted-inventory recovery candidate

2026-10-06. Non-formal candidate only. The protected helper is not changed; A19 has no precheck, reservation, reviewer launch, or verdict. The attempt-18 round-1 files remain in place and byte-unchanged. Its previous reviewer output remains diagnostic-only and is not adopted as a result.

## Cause and exact scope

The current `fresh-review-recovery.py` requires an interrupted round-1 directory to contain exactly the three no-output evidence files. A18 contains those three plus four launcher diagnostics saved before the interrupted first reviewer turn. Moving them or amending the historical allocation reference would rewrite history. This candidate adds only an opt-in `interrupted_evidence_inventory` contract key for feature `epic-195-a7-compatibility`, next attempt 19, predecessor attempt 18. It accepts exactly the seven names and SHA-256 bytes below, cross-checks the contract's inventory with its separately pinned `evidence` entries, and keeps unknown files rejected. All earlier partial attempts use the unchanged branches. The helper's existing manifest, reservation, ledger, session-uniqueness, approval-audit, and full-evidence-set checks still run.

| A18 round-1 name | Actual SHA-256 |
|---|---|
| `launch-blocker-note.md` | `bf8567992c455ee37bf890530c70683edd1ca0bf171bff933278764df9d8c621` |
| `precheck-result.json` | `3ee3a996576106de56423931eecfcf6cedb027ad8f64d850c671b1102b173740` |
| `reviewer-a-first-turn.txt` | `845f0c4d06153767fbebfa6ec6b4c158539ba43a9797bf028f9ece98bdff9f85` |
| `reviewer-a-host-allocation.json` | `18785b66c6b9fd1ccb8e76cd5ebc6cacc9215788ff8ad051a5fcce6e395b94d3` |
| `reviewer-a-nontty-preflight.json` | `217bd5693476afe70128b4a184294c94785dadbdd7746f93cdbe243fb9d8e078` |
| `reviewer-a-reservation-receipt.txt` | `e1b96325621fd95a93f851568fa6eabfe33f257d7749e40452fdd63f1e80cdf4` |
| `reviewer-a-role-config.json` | `9e041233ee4fea5dd253541de62296517ff014f16227abf3f6d104b6cea111f4` |

## Candidate pins and verification

Protected target before: `plugins/sdd-review-loop/scripts/fresh-review-recovery.py` SHA `8d95150acc8e0b539f3acba755e57fd402d315b0be7b591d9ec9c11f2732776e`; predicted after SHA `0461760864371ed8995de5caa6631117ed674b2a7a16ab5988af11e54e26a6de`.

| Candidate | SHA-256 |
|---|---|
| `recovery.patch` | `bd32eed89c566125e7fdcbfc186ab2cc04022d080dd293cfd1ca37c4eaf2f5a2` |
| `inventory.fixture.py` | `c1f5d57289d5ac816adba1c877e80bf2dabbaea351236e2c61244a9c47eaf5e5` |
| `human-apply.py` | `dcac9299ab8cd73e95da3cefce30f7815a3d4e3caf138cb99596a87e3a05b86f` |
| A19 draft contract (`../a7-attempt19-formal-20261005/fresh-review-contract-attempt19.json`) | `ebbd78ca8c5e95333bcb23b6ee624927c8f4b1e4f9e78484ca575f9765fb39f1` |

- `rtk proxy git apply --check .../recovery.patch`: exit 0, no write.
- `rtk proxy python3 -B .../inventory.fixture.py`: exit 0; exact seven-file real-history copy admitted, unknown eighth file rejected, changed historical bytes rejected even after both contract lists were repinned, incomplete inventory rejected. Isolated temporary fixture only; not native precheck.
- `rtk proxy python3 -B .../human-apply.py --check`: exit 0, old hash, patch hash, one-target inventory and `git apply --check` match; no write.
- The current unpatched helper rejects the new contract key with `unexpected fresh-review contract keys`, as expected.

The primary agent independently read the patch and fixture and reran `inventory.fixture.py` in the owner checkout on 2026-10-06. It observed the candidate hash `0461760864371ed8995de5caa6631117ed674b2a7a16ab5988af11e54e26a6de` and all five printed PASS lines (exact seven-file admission, unknown eighth-file rejection, repinned-history-change rejection, missing-inventory rejection, and owner-history preservation). This is independent non-formal technical verification, not a formal reviewer verdict, native launch, or A19 precheck/admission.

`human-apply.py --apply-human` is prepared for the sanctioned human-only guarded path. It backs up and reads back the old target, performs one ordinary guarded `git apply`, and reads back the exact new hash. Any protection refusal is a stop, not permission to use a different executor. The helper has not been run in apply mode. After authorized application, recheck the contract and input/ledger heads and run the normal A19 precheck before any reservation; a new identity and exact `--session-id` are required for each formal launch. Independent review, real precheck, and A/B delivery remain pending.
