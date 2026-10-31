# Issue #423: independent bounded native-source inspection (candidate)

Status: read-only management-recovery inspection only. This is not a formal
quality-gate verdict, reviewer reservation, signature, approval, or input
admission. No private session transcript is copied into this record.

- Owner checkout: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`
- Observed HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`
- Risk/scope: high-risk historical scratch declaration recovery; only the
  specified native owner/workdir and report-creation events were inspected.
- Native source session ID: `01a1030d-9eeb-7453-95eb-5fece30a5976`
- Local native source: `/Users/jrmag/.codex/sessions/2026/10/04/rollout-2026-10-04T03-36-26-01a1030d-9eeb-7453-95eb-5fece30a5976.jsonl`

## Observed native events (UTC)

| Time | Bounded observation |
|---|---|
| 2026-10-03 18:36:26.877 | Session metadata records initial cwd `/Users/jrmag/sdd-forge`, **not** the owner checkout. |
| 2026-10-03 18:36:35.103 | Tool request `call_XcNupzVnw5fa4DfyQ5z8tDYu` specifies the owner checkout as `workdir` for `rtk proxy pwd` and an exact T-003 attempt-2 input-manifest read. |
| 2026-10-03 18:36:35.296 | Matching tool response reports exit 0 and the owner checkout path. |
| 2026-10-03 18:37:59.449 | `apply_patch` request `call_ECDtQqZFMmmFK1iRegNywasr` adds the absolute owner-checkout path of `reports/implementation/sdd-domain-multitarget/T-003-attempt2.md`; its request includes Run ID `t003-20261004-30ca86925cd6`, attempt count 2, logical Session ID `logical-30ca86925cd6-session`, and relative Scratch Root `specs/sdd-domain-multitarget/verification/T-003/run-30ca86925cd6/`. |
| 2026-10-03 18:37:59.531 | Matching tool response completed and returned `{}`. This is a tool-result observation, not a signature or a report-content digest. |

The tool-level workdir and report-add request/result support associating this
report's **declared location**, run, and relative scratch declaration with the
same owner checkout. The native session ID is distinct from the report's logical
Session ID; their equivalence is not established by these events. The session's
initial cwd must not be represented as the owner checkout.

## Current byte readback

| Current artifact | SHA-256 |
|---|---|
| `reports/implementation/sdd-domain-multitarget/T-003-attempt2.md` | `a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462` |
| `reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.scratch-owner.candidate.json` | `1a2a624f1b6ef291384172914f851cc90a150a60bfdde045bd8403b939ae34d0` |
| `reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.owner-observation.candidate.json` | `4114ddada34bdf7d76d158f5321c4f8b3772517372980a86be726e0b8a04d679` |

These are current file hashes, not hashes observed at report creation. The
candidate receipt and observation are self-authored transcriptions; their hashes
alone do not authenticate the native source. No historical scratch-directory
existence, execution, OS isolation, report bytes at creation, or reviewer
identity/independence beyond this bounded source inspection is proven.

## Candidate boundary checked

The two candidate validator patches passed `git apply --check` without
application. The bounded diff routes only a relative historical root through
receipt, report, observation, owner/path, identity, and admitted-byte checks
before the existing canonical overlap check. No concrete safety defect was
identified in that bounded diff inspection. Candidate fixture regressions
reported elsewhere are not formal evaluation or native-source authentication;
they were not rerun for this record.

The canonical adjacent receipt does not yet exist. The current-cycle
declaration is draft-only and does not admit these artifacts. Contract adoption,
sanctioned protected application, an authorized completed recovery review tied
to the actual cycle, ordinary launch prerequisites, and a fresh quality gate
remain separate and incomplete. Apart from this candidate record, no historical
implementation report, ledger, task state, protected target, reservation, verdict,
Git index, or Git history was changed by this inspection.
