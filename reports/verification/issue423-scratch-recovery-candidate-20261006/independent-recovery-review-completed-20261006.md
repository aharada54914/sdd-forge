# RT-20261006-001 independent limited recovery review

Outcome: PASS (limited recovery only; not a quality-gate verdict)
Reviewer: /root/issue423_recovery_independent
Recorded by: coordinating agent, from the reviewer's completed response
Owner: /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge
Observed HEAD: 3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9

The independent read-only reviewer directly inspected the native source, the
three artifacts below, and both applied recovery implementations. No concrete
inconsistency was found. This record preserves that result, not a new evaluation.

## Native source inspected

Source: /Users/jrmag/.codex/sessions/2026/10/04/rollout-2026-10-04T03-36-26-01a1030d-9eeb-7453-95eb-5fece30a5976.jsonl
Native session: 01a1030d-9eeb-7453-95eb-5fece30a5976

- 2026-10-03T18:36:26.877Z: initial cwd was /Users/jrmag/sdd-forge, not the owner.
- 2026-10-03T18:36:35.103Z: call_XcNupzVnw5fa4DfyQ5z8tDYu requested pwd and the T-003 attempt-2 manifest with the exact owner workdir.
- 2026-10-03T18:36:35.296Z: the same call returned exit 0 and the owner absolute path.
- 2026-10-03T18:37:59.449Z: call_ECDtQqZFMmmFK1iRegNywasr requested creation of the exact owner report below with run t003-20261004-30ca86925cd6, attempt 2, logical session logical-30ca86925cd6-session, and relative Scratch Root specs/sdd-domain-multitarget/verification/T-003/run-30ca86925cd6/.
- 2026-10-03T18:37:59.531Z: the matching tool result completed with {}. This is not a signature or a creation-time digest.

## Independently recomputed artifact hashes

| Path | SHA-256 |
|---|---|
| reports/implementation/sdd-domain-multitarget/T-003-attempt2.md | a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462 |
| reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.scratch-owner.candidate.json | 1a2a624f1b6ef291384172914f851cc90a150a60bfdde045bd8403b939ae34d0 |
| reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.owner-observation.candidate.json | 4114ddada34bdf7d76d158f5321c4f8b3772517372980a86be726e0b8a04d679 |

The reviewer inspected recover_legacy_root and callers in Bash and PowerShell:
exact fields/types, same-owner binding, admitted hashes, report identity, safe
relative root and existing overlap checks agree with the contract.
Inspected implementation hashes: Bash e59da652db0accb86b93ef00ce763efc83dbc5d0443685d2e1473181d5365ab0;
PowerShell 9f7a259070605c0520eb48186fcb466d586cdc3f36d63617f17f794f86ecac03;
boundary 47dde31388cd0ec008608397eb7ab0406329e8bd13cd2cf45c38cefed3e07f03.

## Limits and remaining admission

This proves only the declared owner association, not creation-time stored bytes,
historical execution, scratch existence, OS isolation, or native activation.
The logical session is not asserted to be the native session. Regression logs
were inspected but not rerun by this reviewer. The adjacent canonical receipt was
absent at review time. No reservation, admission, task state, ledger, formal
verdict, Git operation or source edit was made by the reviewer.

Before admission, the actual authorized current-cycle declaration must pin the
historical report, canonical receipt, observation and this completed review;
all four must be explicit allowed inputs. Ordinary preflight and fresh quality
evaluation remain required. Historical records must remain unchanged.
