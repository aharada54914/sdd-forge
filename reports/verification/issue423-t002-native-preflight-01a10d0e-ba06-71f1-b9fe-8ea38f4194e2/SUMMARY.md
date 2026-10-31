# Issue #423 / T-002 native caller preflight

Bounded native activation/preflight only. No evaluation or formal verdict.

- Native session / CODEX_THREAD_ID / CODEX_SESSION_ID: `01a10d0e-ba06-71f1-b9fe-8ea38f4194e2`.
- Actual cwd: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`.
- Branch: `codex/issue423-boundary-checkpoint`.
- HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
- Target: `specs/sdd-domain-multitarget/tasks.md#T-002`; observed Approved / Implementation Complete, Risk medium.
- Scope/risk: observe the existing protected activation/evidence boundary only; no contract or implementation edits. Required checks: owner/concurrency, structure, fresh caller challenge, native canary, original verifier, post-handshake physical track probe, cleanup.
- Existing tracked and untracked dirty work observed before any write and retained. The only task artifacts created by this session are this directory's evidence. The canary was created and then removed by native apply_patch.
- Permissions/sandbox were unchanged. All shell calls used rtk proxy and login=false.
- Read AGENTS.md, docs/development-policy.md, complete ship SKILL.md and evaluator-resume-20261006.md. Advisory get_next_sdd_command was unavailable in the callable tool inventory; file-based ship flow used.
- Structure precheck: `rtk proxy sh scripts/check-sdd-structure.sh . sdd-domain-multitarget`, exit 0, exact output:
```text
advisory: CLAUDE.md
host: github
check-sdd-structure: OK
```

## Concurrency observations before writes

Process/cwd inventory showed this native caller PID 92129 (parent rtk PID 92128) and its children in the owner. The only other owner cwd shell, PID 1322, was idle with no child process. No other owner caller or active reservation/handshake process was observed. No reports/review-context lock paths were found. This is a point-in-time observation, not an acquired lock or a reservation.

Ledger SHA-256 on repeated reads before writes and after cleanup:
`46927fa5bb5dcca8885e8fe18634018871e4a56f96e82b489fb0969ae8a08ff6`.
Tip sequence 1195; tip record SHA-256:
`518f8e2150aace36c470ea659ca931535bb83eaa59e14d834322d79c3f1c9539`.
No identity was reserved.

## Handshake observation

Original command path: `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh`.
Fresh nonce: `0e20e8ea51a3999ff33fac0aa5804631`.
No stale sentinel existed before the challenge. The real native apply_patch used the challenge's exact codex-cli template once.

Exact surfaced raw tool result: `{}` (empty object), preserved in `canary-tool-result.raw.json`.
Physical readback: sentinel present, regular file, not a symlink, size 1, bytes newline.
The recorded envelope's executed=true is grounded in that before/after readback; no plugin-hook flags or denial signature were invented.
Original --verify-response exit 63, CAPABILITY_RUNTIME_UNAVAILABLE / WRITE_EXECUTED.
Exact combined stdout/stderr is preserved in `verify-response.raw.txt`, with the complete returned tool envelope alongside it.
This is not HOOK_ACTIVE and not a quality-gate verdict. No actual native refusal was observed and no refused operation was retried.

## Physical state and track resolution (after handshake)

- `sdd/project-context.yaml`: lexists=false, absent.
- `specs/sdd-domain-multitarget/acceptance-tests.md`: regular file, non-symlink, 12030 bytes.
- `specs/sdd-domain-multitarget/traceability.md`: regular file, non-symlink, 5649 bytes.
- No `spec_profile: lite` line in AGENTS.md; no override flag requested.
- Ship G4/C1: DISABLED_LEGACY / COMPATIBILITY_FALLBACK.
- [sdd-ship] Track: full (no lite profile detected)

No Project Context validation was applicable because the file was physically absent.
The handshake's CAPABILITY_RUNTIME_UNAVAILABLE observation remains unchanged; the project-level route is DISABLED_LEGACY, not a valid-Context G2 stop.

## Cleanup and stopping boundary

One native apply_patch delete attempt returned `{}`. Physical readback confirmed sentinel absent.
Original --confirm-cleanup exit 0: SENTINEL_CLEANUP_CONFIRMED; capability_status remains CAPABILITY_RUNTIME_UNAVAILABLE.
No evaluation, evaluator launch, identity reservation, task/review status modification, protected-source edit, commit, push, merge, or other-session evidence reuse was performed.
Stop after this bounded preflight; native hook activation remains unproven. Diagnostic structure and cleanup results are not formal PASS.
