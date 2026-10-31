# Current recovery readback and regressions

Owner HEAD: `654ce55d2b23b3a0cd0d72c3e45e46144399e90e` (dirty working tree preserved).

The current files are newer than the supplied three-file application receipt. All five match the previously recorded attempt-16 candidate hashes; no reapplication was performed:

- spec-review-precheck.sh: `0383b73b77cb9d0b9a0573c001f383b59cbafecb6283001231c6d6bd1ea11cf0`
- spec-review-precheck.ps1: `1996a519da1063770b3593b4f21bfb5e94a3bc926acc9ceb8d002d233202fe51`
- spec-review-loop/SKILL.md: `f11e6d93a45b3a43ac2b53075e50915d093bee24ce76e81b8f0591e3b6f5c323`
- failed-last-attempt.py: `f0172bcf8a5a4e1ae63741ab1566803075fc98ea782d2918469dbf5888cbf77a`
- fresh-review-recovery.py: `a276ae4fd2f8acb0bbe3e1898a6d53495cb113a300f3560f19e6d68e937478fc`

Executed in this owner worktree through `rtk proxy`:

- `python3 specs/epic-195-a7-compatibility/verification/spec-review-fresh-chain.fixture.py`: exit 0, 32 PASS (16 Bash, 16 PowerShell).
- `python3 specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py`: exit 0, 24 PASS (12 Bash, 12 PowerShell).
- `python3 -B tests/spec-reviewer-hash-capability.tests.py -v`: exit 0, 3 PASS.
- `git diff --check`: exit 0 before this report addition.

These 59 checks verify local fixture behavior only. They do not establish real attempt-16 admission, first-turn transport, independent review, Windows-native execution, CI or merge. No reservation, verdict, task status or Git operation was changed. The identity of the actor who applied the newer five-file candidate was not inferred from its byte match.

## Subsequent verification, 2026-10-05

The user subsequently supplied the five-file APPLIED_ONCE receipt and backup
identifier `a7-attempt16-human-backup-ea4r1961`; no reapplication was needed.
The failed-last-attempt fixture passed 18 checks. The full-caller fixture passed
4 checks using its isolated baseline, including Bash and PowerShell admission
and blocker-mismatch rejection. These are separate from native admission.

The real Bash precheck for attempt 16 round 1 exited 0. A fresh reviewer A was
reserved at sequence 1203. Complete first-turn delivery was confirmed against
the native transcript (1,513 characters). The reviewer then stopped before
substantive evaluation: its shell loop for hashing was outside the host command
allowlist. See the immutable round-1 `launch-blocker-note.md`.

A separate diagnostic session successfully ran the simple admitted `rtk proxy
shasum` command without disabling hooks or changing permissions. This resolves
the uncertainty about the hash tool itself, not the formal review.

Current status: application/readback and local regression checks succeeded;
actual precheck admission succeeded; independent specification evaluation,
quality gate, current-head CI and merge remain incomplete. Restarting after
this additional interruption exposes a history-shape limitation in
`fresh-review-recovery.py`; no historical verdict is being replaced to bypass it.
`git diff --check` also exited 0 on the current tree.

## Native diagnostic source identity

Read-only SHA-256 capture of the local native session files (not copied into
the repository or uploaded):

- Failed reviewer session `a116ed26-037a-4d24-a30f-2ccad5f8e7a7`:
  `a0bf4e609a9bc0b20816d12e65352b8b75468c89b0317bdf0218fb5ced8fb603`.
- Separate successful hash diagnostic `2d871b06-3100-4831-802d-eb0b12385a6c`:
  `1afbd8b8750fce5e90039bdefe117d31e3f4b116b1fa213ce56b7f6d05c2a255`.

These refer to distinct files in the owner's Claude project session directory.
The older `a7-private-attempt16/failed-host.jsonl` remains the attempt-15
transcript bound by the attempt-16 recovery contract; it was not replaced.
Session files may acquire subsequent host metadata; these are capture hashes,
not permission to modify or normalize historical evidence.
