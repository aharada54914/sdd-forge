# T-003 attempt 2: native-source inspection candidate

Status: independent read-only candidate inspection for Issue #423, not a formal
quality-gate review, reservation, approval, or verdict. The private native source
was inspected locally; its full transcript is not reproduced here.

Source session ID: `01a1030d-9eeb-7453-95eb-5fece30a5976`.
Local source: `/Users/jrmag/.codex/sessions/2026/10/04/rollout-2026-10-04T03-36-26-01a1030d-9eeb-7453-95eb-5fece30a5976.jsonl`.
Observed owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`.
Report: `reports/implementation/sdd-domain-multitarget/T-003-attempt2.md`.
Run ID: `t003-20261004-30ca86925cd6`.

## Bounded source observations

- Session metadata at `2026-10-03T18:36:26.877Z` records the initial cwd as
  `/Users/jrmag/sdd-forge`, **not** the owner checkout.
- The tool request at `2026-10-03T18:36:35.103Z` specifies
  `workdir=/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`
  for `rtk proxy pwd` and the exact T-003 attempt-2 input-manifest read. The
  matching response at `18:36:35.296Z` reports exit 0 and that owner path.
- The `apply_patch` request at `2026-10-03T18:37:59.449Z` names the absolute
  owner-checkout path of `T-003-attempt2.md` as an added file. Its request
  includes the same Run ID and relative Scratch Root as the current report.
  The matching tool response completed at `18:37:59.531Z` with `{}`. This
  response is not a content hash or a cryptographic signature.

The tool-level owner cwd and report-creation association support resolving
this report's *declared location* against the observed owner for the proposed
limited recovery. They do not establish that the historical scratch directory
existed, ran, or was OS-isolated. The current report digest below is a readback
of present bytes, not a hash observed at creation time. The source review is
limited to cwd, tool request/result, path and identity metadata; no internal
reasoning or credentials are imported as evidence.

## Current candidate byte pins

| Artifact | SHA-256 |
|---|---|
| `reports/implementation/sdd-domain-multitarget/T-003-attempt2.md` | `a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462` |
| `reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.scratch-owner.candidate.json` | `1a2a624f1b6ef291384172914f851cc90a150a60bfdde045bd8403b939ae34d0` |
| `reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.owner-observation.candidate.json` | `4114ddada34bdf7d76d158f5321c4f8b3772517372980a86be726e0b8a04d679` |

Inspection outcome: owner association supported for this candidate only; formal
admission remains blocked pending contract adoption, canonical adjacent receipt
placement, an authorized current-cycle review/declaration, and normal launch
checks. Neither a self-authored observation nor these hashes authenticate the
native source independently of this recorded inspection.
