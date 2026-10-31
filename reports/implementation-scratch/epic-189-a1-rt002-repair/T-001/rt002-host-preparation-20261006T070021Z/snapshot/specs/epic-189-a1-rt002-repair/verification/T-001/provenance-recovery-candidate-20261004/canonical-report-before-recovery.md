# Implementation Report: T-001

- Task ID: T-001
- Model: Codex (collaboration agent)
- Effort: inherited host setting

Feature: epic-189-a1-rt002-repair
Run ID: rt002-t001-report-20261003-061eb712-6eee-4195-a0b2-3ebb32508e10
Task Attempt Count: 1

Report Schema: implementation-report/v2

**Snapshot Notice**: This report records the candidate at `1e86fb272643e798db4e1ca0c89f0402317a2fc8` on 2026-10-03. Later same-feature edits or gate normalization may supersede this inventory. The quality-gate report, not this report, is authoritative for the gate-time state.

## Target

Approved high-risk T-001 in `specs/epic-189-a1-rt002-repair/tasks.md`: repair the shared host-denial verifier, preserve both original suites, prove actual installed activation, and hand the exact candidate to independent quality verification. T-002 owns native Windows, latest-head CI, merge and post-merge acceptance.

## Summary

The candidate verifier selects the bounded schema only for response verification, rejects duplicate JSON members at the shared loader, and accepts only the exact optional-prefix/whole-string bare-denial envelope with one matching nonce. The original wrapper dispatchers and legacy cleanup semantics remain intact. The historical implementation, preflight, chronology and raw-log references are preserved in `reports/implementation/epic-189-a1-rt002-repair-T-001.md`; this fresh report-assembly agent did not reimplement those changes or invent a new historical TDD run.

Current source hashes, both current full-suite runs, the original differential logs, actual native owner refusal, and task-scoped provenance/traceability checks support Done When 1–5. A new isolated original-path pre-fix run reproduced the two-envelope RED in both shells, with byte-identical hashes to the unavailable historical RED logs; a new isolation self-test passed. These are new executions, not recovered historical temporary originals. A retained maintainer-owned `bb388...c3d5` backup was made for a later root-source three-file application, not for the currently installed 1.18.0 verifier; the two retained installed backups instead hash to `d927...d0064`. A human-only, current-1.18.0-targeted procedure now pins the installed `1057` hash and the real source backup's `bb388` hash; its isolated test with that actual backup restored exact prior bytes and refused two hash and two symlink mismatches. No installed restore occurred. This meets the amended Done When 4's current backup/procedure/isolation terms without claiming historical advance preparation or falsely labeling the source backup as an installed backup. Done When 6 remains the independent quality-gate decision.

## Files Changed

The implementation candidate comprises `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` and both original-path suites. This report is a non-frozen evidence assembly; source/specification and historical review artifacts were not edited in this assembly. The exact candidate file hashes are in Outputs.

## Tests Added Or Updated

Both original suites cover TEST-079/080, TEST-084/085 and TEST-090–097 alongside retained legacy checks and both-envelope negatives. The two-envelope TEST-090 regression commit `6aa67116af3b7c8609767df4ee367f8741254811` precedes fix commit `ed936b69c15cb9fdeb9d6d4caa9d1975f54d0587`. Earlier already-correct behavior has genuine pre-repair differential-baseline RED, not a claim that every new assertion individually failed before its implementation.

## Outputs

| Path | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` | `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` |
| `tests/check-hook-activation-handshake.tests.sh` | `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` |
| `tests/check-hook-activation-handshake.tests.ps1` | `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd` |
| `specs/epic-189-a1-rt002-repair/verification/T-001-results.md` | `38c08a31c091d52175eb9a56d9df546c4e9fc7114b69b0e4269811f6c622b656` |
| `specs/epic-189-a1-rt002-repair/verification/T-001-traceability.json` | `7cd901486a25f88190a7734f34172e136e1e54e85f67949e637ad0ea0045c334` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/owner-regression-readback-20261003.md` | `9a6a82f19c7c227857ef3bda535c427e1ffe8dcb5f1079e3b1180d2433d8c142` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/native-owner-cli-20261003-f31929/observation.md` | `0accd27872d5340c53f5de96bbeb1a0964c4b5a8cd4bfca5311611d710e82937` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/native-owner-cli-20261003-f31929/host-response.json` | `4b6a5bd7ac5c2ec04f3a2d89e0ca9ca3bcb7775a1a8608c3e92a6f99a37f6e42` |
| `reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py` | `3ce86f7d4fb2da837ab4160cfeba33e98071cf6da8516f3718f675af1973e4f1` |
| `reports/implementation/epic-189-a1-rt002-repair-T-001.md` | `b2c9adb9047aadfd2cd6ec3ffbfc248de20b302b7b79e13e4efe052618d02a87` |
| `reports/verification/rt002-t001-current-evidence-20261002.md` | `e3afd5485404f2fdba1d69d9c21a5ac3a038cbfc77ef6f15738db31012ef4479` |
| `reports/verification/rt002-two-envelope-validation-20260929.md` | `efa247cfbb8e4aa566b0425e1fc22201f5654d858db3df39022f896f8a4a3ab6` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/legacy-differential/third-baseline-bash-20260927.txt` | `51303df41675fe9987dd42f0463744c914a8983194653d9fdb9f58bbf2c494c4` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/legacy-differential/third-candidate-bash-20260927.txt` | `abd21bd9ad742c07ce01e6d548ee592662fea32d7e6ec58bc15103a12765a9a7` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/legacy-differential/third-baseline-pwsh-20260927.txt` | `ba80f5ce1014922417c2e8d22a5a5d59a40d05133d67f938a5247752cafc9ba9` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/legacy-differential/third-candidate-pwsh-20260927.txt` | `bebcfd9304511ac24ad023b20ba7811b7cf3eb01a840d8e726ece73abd73a2d0` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/two-envelope-red-bash-20261003.txt` | `e8361f4975b2bcdf1cc9fa0d262690e2481dea583bdd6d15fcb2c762a8d706e5` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/two-envelope-red-pwsh-20261003.txt` | `7037c9c4d9bbb749db636045553aea433514083bc287c7760060ec2a46ccbb0e` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/red-and-restore-readback-20261003.md` | `50ea1e6bc8244aea646fdf6f4bb2c47190def8b7adacde6cb63952805d850568` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/restore-installed-118-human.py` | `410a34408f02ba577c0c0c9491a309963378369d1189210b5a15e24060a72c8a` |
| `reports/verification/rt002-source-three-file-human-20261003.py` | `5fd3353a3769d0879ca5fe06b6ad9758bcfa6cec750929a81e6f0752677e84e8` |
| `reports/verification/rt002-installed-118-human-20261003.py` | `1a1df7982c37444bf1b8d5e8e5f8b77b3d58a03fd50402708bb16ac2eb99047e` |
| `reports/verification/rt002-installed-118-readback-20261003.md` | `2e64f419773742499b93cd203936d67c58e8f6b5663e6baddfde2cdfd804aa17` |

## Test Evidence

- **Test Command**: `bash tests/check-hook-activation-handshake.tests.sh`; `pwsh -NoLogo -NoProfile -File tests/check-hook-activation-handshake.tests.ps1`
- **Test Result**: PASS
- **Test Evidence Path**: `specs/epic-189-a1-rt002-repair/verification/T-001/owner-regression-readback-20261003.md`

The direct current owner runs exited 0 with Bash 984 PASS / 0 FAIL and PowerShell 985 PASS / 0 FAIL. The readback note is an index, not a byte-complete raw log.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: `specs/epic-189-a1-rt002-repair/verification/T-001/`
- **Run ID**: `rt002-t001-report-20261003-061eb712-6eee-4195-a0b2-3ebb32508e10`
- **Session ID**: `/root/rt002_evidence_completion`
- **Agent Instance ID**: `/root/rt002_evidence_completion`
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

This Run ID identifies this report-assembly run only. The historical implementation report retains the original implementation and continuation run identities; they are not reassigned to this agent.

## Regression Tests Run

Current direct suites: Bash 984/0 and PowerShell 985/0, both exit 0 (readback above). Historical original-path differential logs, independently rehashed today and copied byte-for-byte into the four declared T-001 `legacy-differential/*.txt` paths, record each shell's baseline at 199 PASS / 211 FAIL and candidate at 410 PASS / 0 FAIL; the prior report records baseline exit 1 and candidate exit 0. The old two-envelope temporary raw originals/handoff are absent; a fresh isolated original-path run of committed regression `6aa67116` against its genuine pre-fix verifier `bb388...c3d5` exited 1 in both shells, with Bash 980 PASS / 4 FAIL and PowerShell 981 PASS / 4 FAIL. Its two complete raw logs are declared above and match the previously recorded historical SHA-256 values byte-for-byte. This is a fresh reproduction, not a claim that the old temporary files or their original execution provenance were recovered. The four failures were bare TEST-090 acceptance/status and `nonce:inner` exit/reason; no current GREEN rerun was needed beyond the already recorded direct 984/985 exits. The separate refused focused command was not executed or substituted for RED.

The owner native observation records installed Codex CLI 0.160.0, installed verifier hash equal to the source candidate, fresh nonce `f319296577f0515fb95f3b29cf131580`, one actual native `tools.apply_patch` PreToolUse refusal, unchanged same-call-ID response, wrapper `--verify-response` exit 0 / HOOK_ACTIVE, and absent sentinel. This is actual owner activation for TEST-089, not native Windows or independent gate proof.

The earlier human-only `apply-human.py` helper pins restoration from installed hash `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` to prior hash `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`. Its fresh `--self-test` exited 0 and covered isolation restoration, two hash refusals and two symlink refusals, but reconstructed the prior bytes and targets now-absent installed 1.17.0. Read-only checks found a real maintainer-owned, 29,144-byte, mode-0600, single-link `bb388...c3d5` file in a `rt002-source-three-backups-*` batch; its Git blob matches the exact verifier in pre-fix commit `6aa67116` (`c0d24c9435e7cb731c5b5a50d3955733d99b4c34`). Its helper and matching current root-source three-file hashes associate it with the **source checkout application**, not with installed application. The separately recorded old `rt002-human-originals-*` path is absent. Two retained installed `prior.py` backups are 26,244 bytes, mode 0600 and hash `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`.

The new human-only `restore-installed-118-human.py` procedure targets the current installed 1.18.0 verifier, requires current hash `1057...e0d` and the actual source-backup prior hash `bb388...c3d5`, checks regular/single-link/owner-only backup and invokes the pinned reviewed atomic restore only after those checks. Its `--self-test --backup <maintainer-held-backup>` ran against the **real** backup, exited 0, restored an isolated copy of current installed bytes to exact prior bytes, and refused wrong-current, wrong-backup, symlink-backup and symlink-target cases without mutating the test target. Current source and installed verifier remained `1057...e0d` afterward. The raw self-test log contains a private OS path and is intentionally not a public Output; the declared sanitized readback records its SHA and result. `--restore` was **not** invoked. The source backup is not relabeled as an installed backup, and no actual installed restoration was performed after successful activation. The human-authorized amendment does not claim this procedure was prepared before the historical application.

Task-scoped structure, workflow, task-state, high-risk and traceability checks exited 0; five REQ-001–004/AC-001–005 links required evidence. Component coverage exited 0 as `not-applicable (disabled-legacy)`, not an ownership PASS. Owner input assembly compared 31 specification/review files byte-for-byte to source, recomputed `spec_revision` as `dd6c53d41ea62dd121f89aa49b218727e78a5614350dc571fb4302247fe709d3`, and preserved amended task-review attempt 4 round 1 PASS. These are provenance/structural results, not quality-gate approval.

## Specification Differences

No frozen specification bytes were changed by this report. The authorized task-body amendment is already represented in the passed amended task-review artifacts. Historical failures and the uncertain pre-application restoration chronology remain explicitly retained.

## Unresolved Items

The old two-envelope RED/handoff and old `rt002-human-originals-*` backup path are missing from their recorded temporary locations. The new RED byte streams match the old recorded hashes but are explicitly fresh executions. Historical installed-prior backups remain `d927...d0064`, distinct from the source-application `bb388...c3d5` backup used by the current 1.18.0 restoration procedure. Neither a historical advance restoration command nor an actual installed restore is claimed. Independent T-001 quality gate and its canonical identity/count report are pending. T-002 remains Draft / Planned and owns native Windows, latest-head CI, safe merge, post-merge and final acceptance. The latest direct-suite tool output was truncated, so the 2026-10-03 GREEN readback is not a byte-complete raw-log hash.

## Quality Gate Focus

Check the full high-risk preflight pairs in the legacy report, real RED/GREEN source ancestry and original-path exit evidence, current suite hashes, fresh owner native refusal/HOOK_ACTIVE, backup and isolated restoration/refusal evidence, current specification provenance, and the distinction between T-001 implementation readiness and T-002 release acceptance. Do not infer QG PASS from earlier review verdicts.

## Working Notes

No delegated implementation investigation occurred in this report-assembly run. This agent read the task, legacy report, native observation, regression readback, relevant feature evidence and current checkout. Historical implementation and reviewer work remain attributed to their dated records.

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Launch independent T-001 quality gate only after its required deterministic checks, canonical manifest/ledger precheck and distinct evaluator reservation succeed. Do not run actual installed restoration. No reviewer identity was reserved in this report-assembly run.
- **Unresolved Items**: T-001 independent quality-gate verdict and T-002 release obligations. The unavailable historical raw files are not represented as recovered originals; the backup is explicitly source-application provenance, not historical installed-prior provenance.
