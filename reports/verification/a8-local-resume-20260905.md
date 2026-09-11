# A8 local verification continuation — 2026-09-05

This is a non-frozen verification addendum, not a quality-gate verdict.
No task is marked Done and no merge is authorized by these results alone.

## Target

- Isolated worktree: `/Users/jrmag/.local/share/sdd-forge-a8-verify-20260905`
- Existing remote branch: `origin/feature/epic-196-a8-integration`
- Tested HEAD: `a1b958bc648aaf4b22a99a45262df490d64438c7`
- Branch tasks T-001 through T-008 are Implementation Complete; main's older task states are not this branch's state.
- Structure precheck: exit 0, `check-sdd-structure: OK`.

## Actual results

| Scope | Result | Evidence |
| --- | --- | --- |
| T-004 PowerShell CLI-hook enforcement | exit 0; 17 passed, 0 failed | `/tmp/a8-t004-verify.jZAptU/cli-hook-enforcement.log`; SHA256 `581961622bd0c9411593345795cb5e2831a27e6bc50332a076ca25d448e5ce0b` |
| T-001 Bash cross-runtime handoff | exit 1; TEST-001–005 pass, TEST-006 fails | `/tmp/a8-t001-verify.jGtTV5/green-sh.log`; SHA256 `7f0a1d35453b5bd929fceb593b5afb78b606b5f483ea3666d09e08269eb65826` |
| T-001 PowerShell twin | exit 1; TEST-001–005 pass, TEST-006 fails | `/tmp/a8-t001-verify.jGtTV5/green-ps1.log`; SHA256 `c1219b516c27d15b951e418ebc03114d19e6a21ea37efb67a75dc7a7c0f3d019` |
| T-002 drift suite | Tester reports SH exit 0 and PS1 exit 0, TEST-022/023 and read-only digest assertions pass | Agent session 49903; no persistent raw logs supplied, not independently rerun by primary. Two successful suites, not two assertions. Windows default case deferred to Windows CI. Earlier missing-file and A6-payload claims were wrong and discarded |
| T-003 matrix | Investigator reports Bash exit 141 during fixture archive; PowerShell timeout before assertions | Raw-log and pipeline-status follow-up pending; root cause not yet confirmed |

The T-001 log filenames contain `green` but their contents and exit status are FAIL.
T-004 checks are local fixture/direct-guard checks, not proof of real CLI host activation or three-OS CI.

## Confirmed T-001 integration inconsistency

At this HEAD, `tests/cross-runtime-handoff.tests.sh:121` requires the allowlist to contain exactly one entry. The actual `plugins/sdd-review-loop/references/a8-skip-allowlist.json` contains AC-006, AC-015 and AC-016; the latter two are the T-008 extension. The count constraint is inconsistent with that extension.

Independently, the live T-005 state activates the AC-006 canary. Fixing the count alone must not be represented as discharging the active canary or producing live-host evidence. Task scope and the canary's substantive verification need reconciliation before any claim of completion.

## External blocker

Fresh `gh auth status` exits 1: the default GitHub token for aharada54914 is invalid. PR/CI freshness and merge cannot be established through this CLI until reauthentication. No token was printed or modified.

Superseded on continuation: GitHub CLI authentication is restored and live PR/CI queries succeed. This historical authentication failure is no longer a current blocker.

## Preservation

No tracked A8 implementation files were edited. An untracked NFC `café-manifest.txt` appears alongside the tracked NFD spelling in the path-lineending fixture on macOS; it is preserved, not deleted. Existing main-checkout user changes are preserved.

## T-003 diagnostic follow-up

Investigator reproduced the archive pipeline exit 141; archiving to a saved file and then extracting each exit 0. Stderr files are empty. This narrows the failure to the combined pipeline but does not yet establish the underlying cause. Logs: `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/tmp.wqTDrIruuO/logs/{stdout.txt,git.err,tar.err}`. PowerShell execution was interrupted before assertions; it is not a failed product assertion or a passing suite. Initial investigator timeout-duration descriptions differed, so no precise duration is asserted here.

## Fresh T-002 verification

Lightweight tester ran `rtk proxy bash tests/check-installed-plugin-drift.tests.sh` and `rtk proxy /opt/homebrew/bin/pwsh -NoLogo -NoProfile -File tests/check-installed-plugin-drift.tests.ps1` in the exact A8 worktree at `a1b958bc648aaf4b22a99a45262df490d64438c7`. Both exited 0. Primary read both complete raw logs and independently checked their hashes:

- `/tmp/a8-t002-verify.KGrnGY/check-installed-plugin-drift.tests.sh.log`: `4a273ea92adb29e1f1c58af405347a4a0e8727199fab447eb28277637facf72c`.
- `/tmp/a8-t002-verify.KGrnGY/check-installed-plugin-drift.tests.ps1.log`: `019e7c6b222d6cc58f4b2c74c66b15cb1f8bb1f458f07251466cae66848db5ae`.

Each log contains 36 `ok` lines and one PASS summary. One PowerShell `ok` line explicitly defers the Windows default to Windows CI: this is not an executed Windows assertion and remains unverified here despite the misleading success prefix. TEST-022/023 contract mismatch, per-surface divergence, mode and lifecycle checks ran. These results do not establish three-OS verification or formal quality-gate PASS.

Primary `ls -l` confirms both `check-installed-plugin-drift.sh` and `.ps1` wrappers exist in this worktree; previous investigator claims that the PowerShell wrapper is absent are rejected. No tracked A8 files changed; the pre-existing NFC fixture remains preserved.

## T-003 PowerShell oracle review

Lightweight investigation followed by primary source inspection confirms that `tests/install-uninstall-matrix.tests.ps1:80-83` captures checker text without checking its exit status. Lines 107-130 then hard-code every phase result to PASS, empty registration/diff/residue arrays, and merely attach the parsed drift JSON. The second install does not invoke the drift checker. This is broader than archive portability: checking the first checker exit alone would not establish T-003's registration-table, second-install verification, idempotency or residue requirements. No repair or fresh RED/GREEN execution is claimed in this review.

The approved task block at `tasks.md:510-646` requires those real observations and depends on T-001 and T-002. An unrelated quality-gate T-003 report is not evidence for this feature. Frozen requirements, tasks, traceability and historical evidence remain unchanged.

The installed ship skill's gate G4 explicitly permits legacy-mode continuation when Project Context is physically absent even if handshake is not HOOK_ACTIVE. Primary `ls -l` found no `sdd/project-context.yaml` in this A8 worktree. Therefore a handshake failure must not be treated as a universal implementation blocker; the correct per-worktree track, dependency and repair-entry checks are still required. This observation does not authorize bypassing a denied tool operation or marking a handshake successful.

## Deterministic preflight continuation

At the same A8 HEAD, the primary ran the structure check (exit 0), T-003 quality-gate cycle-limit check (`continue`, exit 0), and task-state check (8 tasks passed, exit 0). These are structural checks, not product-test or quality-gate verdicts.

The subsequent global `check-workflow-state.sh` completed with exit 1. It reported two actionable failures: `spec-review-fixture-8870-64363: registry-unregistered-directory` and `epic-196-a8-integration: stage-order: Impl Passed requires Spec Passed`. The A6 amendment-growth messages were explicitly marked tolerated, not failures.

`git ls-files --stage` confirms the fixture's `requirements.md` and `acceptance-tests.md` are tracked. It must not be treated as disposable untracked output or registered as a real feature merely to pass the check. A read-only provenance investigation is assigned to identify its introducing commit and the A8 stage mismatch before choosing a correction. No A8 tracked files or task statuses have been changed.

Primary provenance correction: fixture introduction `1dc6959a` is an ancestor of the A8 head (exit 0) and is NOT an ancestor of main `ca023cc8` (exit 1). The delegated investigator inverted these exit codes; that conclusion is rejected. The latest A8 requirements change is `12a5589c` (September 1), which deliberately changes Passed to Pending following attempt 4 round 1 NEEDS_WORK. The older August 24 pass `326b89ee` does not supersede that later failure.

Primary read the actual attempt-4/round-1 report and both reviewer results: the unresolved Critical APPROVAL-BOUNDARY finding concerns unbound references at investigation.md:151-153 (T-002 implementation report) and :506-508 (T-005 evidence directory). The declared amendment context requires commit/hash bindings for every referenced implementation/evidence artifact. Restoring the old Passed header would hide this finding and is not an acceptable repair. A narrow read-only binding inventory is assigned before drafting the amendment and rerunning the applicable independent review. No gate result has been changed.

Further source inspection avoids duplicating existing work: commit `dcba8112b62216eabdec2926d61ad09f6a66252b` already adds the T-002 binding and all eight T-005 hashes in investigation.md. Primary read the current complete spans at lines 151-157 and 511-532 and the introducing diff. The next step is to verify those existing bindings and resume the authorized spec-review sequence, not write the same amendment again. The later passing round has not been established, so Pending remains unchanged. This supersedes the earlier assumption that the source correction itself was still missing.

## 2026-09-06 binding verification and precheck runtime diagnosis

Primary verified the current-file hashes of the T-002 implementation report and all eight T-005 artifacts against investigation.md; the lightweight investigator also verified their blobs at the declared commits (`28a346ae3108665962765555c63096aaae31d220` for T-002, `4f02732c45ce8dfa942bcafafc8801ce9f429936` for T-005). All nine bindings match. This verifies references, not the substantive product claims within them.

The normal specification-review precheck for attempt 4 round 2 was invoked with the existing correction as its edit summary. It stalled without output before creating round-2 artifacts. The owned invocation is session 59364 / PID chain 87916, 88301, 88404, 88405. Sampling the final Bash child shows `do_redirections -> heredoc_write -> write`; the source's combined reviewer-check JSON has length 3201. This is evidence for a runtime input-redirection stall, not yet proof of its root cause. No protected script was changed, no reviewer was launched, and no precheck PASS was recorded. Issue #61 is closed, so the temporary manual-precheck fallback does not apply.

The stalled owned invocation was then terminated (exit 143). Running the identical unmodified precheck and arguments through `/bin/bash` completed with exit 0 (session 9167), producing the round-2 precheck at `2026-09-05T15:10:54Z`. A separate lightweight subprocess experiment reports Homebrew Bash timeouts for 1024/3201/32768-byte here-string payloads, versus success for all those sizes under system Bash; 131072 bytes succeeded under both. These observations isolate a runtime-sensitive redirection problem; they do not establish a patched Bash or script. No manual-precheck fallback was used. The next boundary is fresh host-issued reviewer identity reservation before substantive independent review. Specification status remains Pending.
