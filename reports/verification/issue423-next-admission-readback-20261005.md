# Issue #423 next-admission readback — 2026-10-05

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`  
HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`  
Scope: read-only reconciliation and handoff; no product execution, protected apply, reservation, evaluator, verdict, task-status, or frozen-document edit.

## Canonical state

`specs/sdd-domain-multitarget/tasks.md` is the task source of truth. T-002 is Approved / Implementation Complete, and its AC-002/AC-012 ownership and boundary Done When remain open pending quality verification. T-003 is Approved / Blocked, with T-002 not Done as a prerequisite and an actual PreToolUse refusal of required read-only snapshot inputs in attempt 4. Its high-risk preflight, RED/GREEN, implementation and independent review did not run. Do not reinterpret older preparation notes as an unblocking decision.

## Fresh byte readback

All paths below were read in this owner checkout. `issue423-manifest-binding-human-apply.py` is `7a0732632570770c853f915a85f51a698c053375bf06eed96d63dd90420e098c`. The three guarded targets still match that batch's *before* pins, so the batch is **not applied**:

| Target | Current SHA-256 (= before pin) |
| --- | --- |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` | `011f1d9c068e7b2f033f02bbae0fd15cf3a9c9c2c7f409c963fc1d9e941fc09b` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1` | `e8424eb27598222fe527ffaaa296cd287a4c52f850ed05b91e98023c8c4e7925` |
| `plugins/sdd-review-loop/references/review-context-boundary.md` | `07f7834c17561b3b69093f91b32c7c5d4d655e9bc21bf2ff8bec6322fb02152a` |

The validators still require basename `manifest.json` (`validate-review-context-set.sh:422`, `.ps1:495`), while the canonical T-002 report cites `handoffs/issue423-t002-recovery-20261003/manifest-archive-input.json` at line 72. Its current SHA is `7c6fef1602a1fa5608b7b78a4dd6a57d1838ffcc1f1ff8e58a98a79d51d70163`; the report SHA is `3f2ae5bf8d85e7a28b87165f9f699068801562ca77b88ab4d8877c38e5a1d2b4`. A new quality invocation cannot cure this by silently switching to `manifest.json` because the validator also matches the report citation.

The human FilesOnly runner SHA is `d1c2ede3c719ea144190f5baa2d45bc3afd5436abbf4cd7e5bb4e5bb3c895642`. Its three source pins match current bytes: installer `87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50`, validator `4794ef81888e83a4d45f37a680ab65436cd1ca97e1d01c59acf8a22dae898788`, helper `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea`. The retained `issue423-t002-build-human.log.h2HQDSYl` proves a prior FilesOnly run against installer `9b43d5eaf93a9cefffc562a3108f43ab2bc2a64c675a710ec5c59250f7abe719`, not the current installer. Existing owner-side regression and cross-runtime tests were already reported in `issue423-owner-regression-addendum-20261004.md` and `issue423-distribution-cross-runtime-20261004.md`; they were not rerun here.

## Exact next execution boundary

1. In a human-controlled terminal, after confirming the pins are still current and no concurrent edit is in progress, follow `issue423-manifest-binding-human-batch-20261004.md` and run `rtk proxy python3 reports/verification/issue423-manifest-binding-human-apply.py --apply-human`. Its prior dry-run exited 0; the agent must not invoke protected apply or chain older overlapping batches. Then verify the three expected after hashes from that note, focused/full issue311 regressions, and `git diff --check`. This resolves only the filename binding, not quality approval.
2. In a human-controlled terminal, run `rtk proxy bash /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge/reports/verification/issue423-t002-build-human-run.sh`. Capture its new log, staged tree, complete output and exit status. It verifies isolated FilesOnly payload assembly and installed validator behavior; it does not prove native host registration.
3. Preserve old declarations and history. Put any new current-build evidence in a non-frozen note, admit each evaluator-facing new artifact by exact path/hash in a new post-fix declaration, and construct a fresh T-002 one-role quality invocation. Resolve the genuine available evaluator model and protected role/reference read boundary without bypass. Only the coordinator may take the current ledger tip, allocate a distinct real session/scratch, reserve once, and launch after `REVIEW_CONTEXT_OK` through the required ship/quality-gate path.

Parallel work without protected apply or reservation: audit current T-002 evidence and prepare the new declaration/invocation *draft* after the new human-run log exists; inspect T-003 non-protected planning material. Do not start T-003 implementation until T-002 is Done and its own protected-read/preflight blocker is resolved. Native Windows, independent quality verdict, CI, merge, and post-merge proof remain separate unmet gates; no existing local green result is represented as any of them.
