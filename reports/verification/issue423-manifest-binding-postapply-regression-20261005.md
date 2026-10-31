# Issue #423 manifest binding: post-apply readback and regression (2026-10-05)

Status: applied bytes confirmed; behavioral regression **FAILED**. This is an owner-side verification note, not independent review, a quality-gate verdict, reservation, task transition, CI, or native Windows result. No protected target, frozen artifact, ledger, or existing report was edited during this check.

## Scope and readback

- Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`; branch `codex/issue423-boundary-checkpoint`; HEAD `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. The checkout contains pre-existing dirty and untracked work; it was preserved.
- Issue/task: #423, `sdd-domain-multitarget` T-002, Approved / Implementation Complete. T-003 remains Approved / Blocked on T-002 and a separate protected read refusal.
- Human apply helper `reports/verification/issue423-manifest-binding-human-apply.py` SHA-256: `7a0732632570770c853f915a85f51a698c053375bf06eed96d63dd90420e098c`.
- Backup: `reports/verification/issue423-manifest-binding-backup-1_l1uzsl/`. Its three files retain exactly the before hashes in `issue423-manifest-binding-human-batch-20261004.md`; the original dirty bytes remain recoverable. The helper's terminal execution output was not captured by this verifier, so this note proves current readback and backup bytes, not the historical command transcript.

| Target | Backup SHA-256 (before) | Current SHA-256 (expected after) |
| --- | --- | --- |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` | `011f1d9c068e7b2f033f02bbae0fd15cf3a9c9c2c7f409c963fc1d9e941fc09b` | `2d004b63ba7ec99fa109120c86f91bb7aed7f41b5a461e3b8538b890c7a6aaba` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1` | `e8424eb27598222fe527ffaaa296cd287a4c52f850ed05b91e98023c8c4e7925` | `84264f9eb02a25be788c3fe7660950f9a971d926ae5930089b0ea53746bb6bc7` |
| `plugins/sdd-review-loop/references/review-context-boundary.md` | `07f7834c17561b3b69093f91b32c7c5d4d655e9bc21bf2ff8bec6322fb02152a` | `94cf8bf3ed973cc7240d3fa264b150f3f654642831095eb3d433cb4dc62baab4` |

## Commands and observed results

All commands used `login=false`, cwd the owner checkout, and `rtk proxy`. Test source `tests/issue311-scratch-isolation.tests.py` SHA-256 was `05c0dd308f81dc276a5d468f618382392edfc098f7f6f10c60b0ad9586c71bf8`.

| Command | Exit | Observed cases | Scope |
| --- | ---: | --- | --- |
| `rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo . --manifest-only` | 1 | PASS 10, FAIL 4 | Bash and local PowerShell; versioned manifest positive, citation/hash mismatch and malformed-path negatives, temporary fixture ledgers only |
| `rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo .` | 1 | PASS 70, FAIL 4 | Same two runtimes; full 37-case-per-runtime fixture set |
| `rtk proxy git diff --check` | 0 | no whitespace errors | Working-tree diff check; not behavior verification |
| `rtk proxy git apply --check reports/verification/issue423-manifest-binding-preflight-candidate-20261005.patch` | 0 | patch applies cleanly to current owner bytes | Read-only candidate syntax/context check; patch was not applied |

The versioned positive case passed preflight, fixture reservation, unchanged snapshot verification and changed/omitted scratch-root refusal in Bash and PowerShell. Four negative assertions failed: `manifest-citation-mismatch` and `manifest-hash-mismatch` each returned `REVIEW_CONTEXT_OK` with exit 0 from the **no-reserve preflight**, where the test requires exit 1. These are two cases in each runtime, not four distinct root causes. The fixture did not touch the owner identity ledger. Local PowerShell execution is not native Windows proof.

## Cause and bounded candidate

The fixture does create both discrepancies. For citation mismatch, `tests/issue311-scratch-isolation.tests.py:85-87` changes the report's manifest path and repins that report's allowed-input hash. For hash mismatch, `:88-89` changes the invocation's `implementation_manifest.sha256` to 64 zeroes while the allowed-input pair retains the real manifest hash. The test calls preflight without reserve at `:171-176` and requires rejection without ledger change.

Both validators do the full implementation manifest/report binding only under reservation (`validate-review-context-set.sh:986-995`; `.ps1:1060-1071`). Therefore no-reserve preflight can emit `REVIEW_CONTEXT_OK` for those mismatches. The manifest filename edit made the positive path reachable but did not create this call-site condition. Neither negative expectation should be weakened to conceal the gap.

The un-applied candidate `reports/verification/issue423-manifest-binding-preflight-candidate-20261005.patch` (SHA-256 `c64e10e95b7ccf2a0e033a235363624d44ac3a2c612bc0e4b763179ecc844b53`) calls the existing binding check during no-reserve preflight **when an implementation manifest is declared**, while keeping ledger uniqueness and evaluator/implementer identity collision checks under reserve. It preserves the existing no-manifest legacy preflight condition. This is a protected enforcement change and requires scoped human application through the sanctioned path and independent review. No GREEN has been run or claimed.

## Human-only apply preparation

`reports/verification/issue423-manifest-preflight-human-apply.py` has SHA-256 `26d48d3ebcb68addf3d54a9530b7b6d528f3ca8d318f44d5f90072868d77c31f`. Its `--dry-run` was executed from the owner checkout with `rtk proxy python3 reports/verification/issue423-manifest-preflight-human-apply.py --dry-run`: exit 0; Bash and PowerShell parser checks each reported `SYNTAX_OK`; the exact two-target unified diff and all before/after hashes were printed. The helper did not write protected files. A separate `rtk proxy git diff --check` returned exit 0. There has been no `--apply-human` invocation, no post-apply GREEN and no independent verdict.

The helper pins the current two validator hashes above, refuses absent/ambiguous or already-replaced byte spans and unexpected HEAD/owner path, creates a unique backup before either write, and compares exact bytes and SHA-256 immediately and finally after each write. Expected after hashes are Bash `134fd5fad980cdbfc08cb18126aea8b4f9f81c8a92e8036338d36609a9a18f6d` and PowerShell `3f0d4a9d7f3d40c0ab2543d0b8b7a2397b0399429c46b38450a9183cb4ad65f1`. The requested human-only command, to be run from the owner checkout after review, is `rtk proxy python3 reports/verification/issue423-manifest-preflight-human-apply.py --apply-human`. A hook refusal remains a refusal; no alternate executor or route is authorized.

After the human command completes, first independently hash-read both validators and the unique backup directory reported by the helper, comparing them with the pinned before/after values. Then, in the same owner checkout, execute these regression commands in order and record each exit, PASS/FAIL count and output path:

```text
rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo . --manifest-only
rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo .
rtk proxy git diff --check
```

Do not infer GREEN from the helper's syntax check. The focused suite must move from PASS 10 / FAIL 4 to PASS 14 / FAIL 0, and the full suite from PASS 70 / FAIL 4 to PASS 74 / FAIL 0; any other result requires diagnosis before reservation or formal T-002 evaluation. Recheck current source/test hashes and independently review the final protected diff before treating the behavioral repair as ready. The separate role-file read refusal and 72-input revalidation remain pending; no ledger reservation or task status change is authorized by this handoff.

## Quality launch boundary

The prepared 72-input candidate `issue423-t002-evaluator-input-candidate-20261005-final.json` remains at SHA-256 `aa4b2d9a99d81b6d988c3ab4d164043d6cdc66645af60ebbb921525708a155f9`; its declaration remains at `3f5a4aa22b735e7e227cc99348754eea2a2963ad1b10bafa8d38a9912a7e1a87`. Only these two metadata files were rehashed here; the 72 entries were not revalidated this turn. The report and manifest cited by T-002 retain hashes `3f2ae5bf8d85e7a28b87165f9f699068801562ca77b88ab4d8877c38e5a1d2b4` and `7c6fef1602a1fa5608b7b78a4dd6a57d1838ffcc1f1ff8e58a98a79d51d70163`.

Next: obtain sanctioned protected application and fresh readback of the bounded preflight fix; rerun focused and full issue311 suites and `git diff --check`; independently review the protected diff. Then revalidate every evaluator input and declaration hash, resolve the previously refused role-file read through the normal path, and coordinate a fresh single reservation and formal evaluation. Do not launch T-002 quality-gate or start T-003 implementation on the current failed regression. CI, native host/Windows checks, merge and post-merge evidence remain separate.

## Later human-application readback and GREEN (2026-10-05)

This section supersedes only the earlier *current* failed-regression state, not its RED observations or the separate quality-launch limitations. A human reported running the human-only helper; this verifier did not capture that command's terminal transcript. The unique backup `reports/verification/issue423-manifest-preflight-backup-9ddyb_1a/` contains exactly two regular files: Bash SHA-256 `2d004b63ba7ec99fa109120c86f91bb7aed7f41b5a461e3b8538b890c7a6aaba` and PowerShell SHA-256 `84264f9eb02a25be788c3fe7660950f9a971d926ae5930089b0ea53746bb6bc7`. Current validator readback is Bash `134fd5fad980cdbfc08cb18126aea8b4f9f81c8a92e8036338d36609a9a18f6d` and PowerShell `3f0d4a9d7f3d40c0ab2543d0b8b7a2397b0399429c46b38450a9183cb4ad65f1`, exactly the helper's pinned after hashes.

All following checks ran via `rtk proxy` with `login=false` in the owner checkout. The test fixture uses temporary ledgers; no owner reservation was made.

| Command | Exit | Result |
| --- | ---: | --- |
| `rtk proxy shasum -a 256` on the two backup and two live validators | 0 | four hashes match the pinned values above |
| `rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo . --manifest-only` | 0 | PASS 14 / FAIL 0; citation and manifest hash mismatches now reject at no-reserve preflight in both local runtimes |
| `rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo .` | 0 | PASS 74 / FAIL 0; both local runtimes |
| `rtk proxy git diff --check` | 0 | no whitespace errors |
| read-only `rtk proxy python3 -c` count/uniqueness/hash check of the prepared evaluator JSON | 0 | `entries 72`, `unique 72`, `mismatches 0`; also checked its implementation-manifest and declaration references |
| `rtk proxy shasum -a 256` on evaluator JSON, declaration, and implementation manifest | 0 | `aa4b2d9a99d81b6d988c3ab4d164043d6cdc66645af60ebbb921525708a155f9`, `3f5a4aa22b735e7e227cc99348754eea2a2963ad1b10bafa8d38a9912a7e1a87`, and `7c6fef1602a1fa5608b7b78a4dd6a57d1838ffcc1f1ff8e58a98a79d51d70163`, respectively |

This is owner-side local GREEN, **not** independent review, native Windows verification, CI, quality-gate PASS, or Done. The previously refused protected role-file read was not rerouted; coordinate that unresolved preflight and a fresh single evaluator reservation with the task owner before any formal T-002 launch. Keep T-003 blocked until its separate prerequisites are met.

## Two-validator diff inspection (2026-10-06)

The backup-to-live diff contains only the two intended call-site changes, at Bash `validate-review-context-set.sh:986-999` and PowerShell `validate-review-context-set.ps1:1060-1076`. The no-reserve path now calls the existing binding validator when `implementation_manifest` is declared; the manifest-less legacy preflight remains unchanged, and `--reserve` still requires binding. The schema rejects empty or malformed declared manifest paths (Bash `:400-460`, PowerShell `:489-503`), so Bash's nonempty-path guard and PowerShell's `ContainsKey` guard are equivalent for admitted invocations. Existing binding routines read the pinned manifest and report, compare task/run/session and the report citation, and do not persist state (Bash `:251-282`, PowerShell `:113-154`). Ledger reuse/identity collision checks remain under reserve; the only ledger write remains in the existing reserve transaction (Bash `:1220+`, PowerShell `:1331+`). No concrete defect was found in this bounded review. The author of this note also prepared the patch, so this inspection is **not an independent third-party review** and cannot replace the formal evaluator or a separately assigned reviewer.

The negative fixture edits the report citation while repinning its report hash, or edits only the invocation's declared manifest hash, then requires preflight exit 1 and unchanged fixture ledger (`tests/issue311-scratch-isolation.tests.py:85-89,171-176`). Both local runtimes passed those cases and the full suite above. This evidence does not cover native Windows, arbitrary unseen malformed inputs, or exact final-head CI.

Minimum remaining formal-launch conditions from the existing quality contract and handoff are: resolve the actual role/reference read refusal through the normal protected path and check role/model drift; choose an actually available strong evaluator model/effort and provide the declared local dependency without silent substitution; enter via `ship` with its current-session handshake, verify exact admission/output permissions, construct a complete one-role invocation with fresh run/session, distinct absolute scratch and live ledger tip, then let the coordinator reserve once and require `REVIEW_CONTEXT_OK` before a fresh independent evaluator starts. The 72 prepared input hashes match, but the preparation JSON is not an invocation and carries no reservation receipt. The prior refusal is recorded in `specs/sdd-domain-multitarget/verification/T-002/qg-prep-20261003/evaluator-launch-blocked.md`; no alternate read was attempted.

## Latest role-read blocker reported by coordinator (2026-10-06)

After a human reported applying six guard updates, the coordinator attempted the original ordinary `rtk proxy rg` role-file read again, without changing executor or splitting/translating the request. The live PreToolUse hook again classified that read as a prohibited role-file write and denied it before execution. This verifier did not observe the coordinator's terminal output directly; the outcome is a coordinator report and is not a successful read, activation proof, or gate verdict. No further retry or alternative route was taken. The actual protected-role read remains the immediate T-002 launch blocker; keep reservation and formal evaluation unstarted until it succeeds through the sanctioned ordinary path.
