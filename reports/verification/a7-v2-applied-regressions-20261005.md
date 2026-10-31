# A7 v2 applied recovery regression results

Observed on 2026-10-05 in the a7-t005-intake worktree. This record is not a formal review verdict or native activation proof.

## Applied bytes

All five live targets matched the v2 candidate hashes before execution:

- spec-review-precheck.sh: `13edd6165b011ee877eadb84d4cc39b5a0243c24bfd37cfb1b9490d1781bac62`
- spec-review-precheck.ps1: `ca23b15becbf404038d3dca0b2ea407d96695fa74ee34af0febebe17938a9d08`
- spec-review-loop/SKILL.md: `f1aeafb2ae59551743867c5d96a64679f056bb831c9ae266f83a060ed45f0264`
- fresh-review-recovery.py: `dd6f639b9e15d0f2668c308c219636e273a5d54e19cba701d62509db9c65ba01`
- spec-review-fresh-recovery.fixture.py: `9305fc715d36af779c4adb83ba16f903064e36e0e4710c1378da5825d7b595e1`

## Executed checks

Commands ran through `rtk proxy`, with `TMPDIR=/private/tmp`, from the owner worktree:

1. `python3 specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py`: exit 0; 24 PASS groups (12 Bash, 12 PowerShell). Includes current-input, wrong-attempt, evidence-hash, missing-reservation, B-invocation, transcript-session, historical-disposition, authority-scope, authority-hash, terminal-contract and post-lock-ledger negative checks, plus valid recovery.
2. `python3 specs/epic-195-a7-compatibility/verification/spec-review-interrupted-recovery.fixture.py`: exit 0; 30 PASS groups (15 Bash, 15 PowerShell), including replay, immutability, missing/altered reservations, occupied destination, external paths and malformed arguments.
3. `git diff --check`: exit 0.

Total: 54 PASS groups, zero failed groups. PowerShell was executed on macOS; this is not native Windows evidence.

## Boundaries

Historical attempts and reservations remain preserved. The resumed attempt-9 output is not adopted as valid first-turn review evidence. A real scoped approval transcription, hash-bound recovery contract, precheck admission, fresh host allocation and independent first-turn review remain separate required steps. No task status, review verdict, commit, push or merge was changed by these checks.

## Subsequent launch preparation

Attempt 10 / round 1 precheck was subsequently admitted at
`2026-10-04T15:24:42Z`; its `precheck-result.json` is preserved. Do not reset or
repeat this admission merely because reviewer startup is pending. No reviewer
identity has been reserved for this round.

At continuation, the owner reviewer roles still list only `Read, Grep, Glob`,
while requiring independent SHA-256 computation. A separate diagnostic is
checking host allocation and read/hash capability before any formal first turn.
The app-server idle-thread allocation observation is not a review or activation
verdict. Any capability repair must preserve read-only, manifest-bound inputs.

## Later launch observation (2026-10-05)

The preceding preparation notes describe the earlier state, not the current
reservation count. The separate hash-capability repair and its focused tests
are recorded in `a7-spec-reviewer-hash-capability-20261005.md`.
Reviewer A was subsequently reserved once at sequence 1193 for native Claude
session `c7fc70c9-630c-45ed-800e-dca0c8f775f6`. Its receipt is in
`reports/spec-review/epic-195-a7-compatibility/attempt-10/round-1/reviewer-a-host-allocation.json`.
The launch coordinator observed same-session resume with saved options and
submitted the manifest and reservation record as the first formal turn.
Execution was in progress at this observation; no review verdict is claimed.

### Terminal observation (2026-10-05)

The same reviewer subsequently returned `BLOCKED` with `checks: []`, preserved
in the round's `reviewer-a.json`. Required SHA-256 calculation was denied by
Claude's `dontAsk` tool permission policy; making Bash available with `--tools`
did not grant permission to execute it. No alternative executor was used.
Sequence 1193 is consumed, reviewer B was not launched, and no substantive
review check is claimed as passed or failed. The 54 regression groups above
remain local recovery-test evidence, not formal review completion. A subsequent
launch must establish the approved, narrowly scoped read/hash permission at
initial allocation and use a fresh review identity under the recovery contract.
