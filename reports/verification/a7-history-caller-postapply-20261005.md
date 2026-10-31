# A7 history caller: post-application verification

## Recheck 2026-10-04T23:38:19Z

After the supplied three-file application receipt, readback again matched all three hashes below. The owner checkout HEAD was `654ce55d2b23b3a0cd0d72c3e45e46144399e90e`; existing uncommitted changes were preserved. Both fixture commands listed below were executed again against the working-tree files: chain 32 PASS (16 Bash, 16 PowerShell), recovery 24 PASS (12 Bash, 12 PowerShell), both exit 0. `git diff --check` also exited 0. These are local fixture results, not Windows-native or independent-review acceptance. No reservation, verdict, task status, commit, push or merge was changed.

Date: 2026-10-05

The three human-applied files match the supplied SHA-256 values:

| File | SHA-256 |
|---|---|
| plugins/sdd-review-loop/scripts/spec-review-precheck.sh | 230feaa639b5931447f88d3e720d6d52fed15c697de7e19e5bbc6efdb277d8a4 |
| plugins/sdd-review-loop/scripts/spec-review-precheck.ps1 | 9eb8111754b4a3b355da4d465eb53b369c9f2ef09e4d0d246bf2da1478e95ab8 |
| plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md | 107dd754c3514a34fcba28a2b2bf18d35d004e1dd0a92599956906a9315b45e4 |

Executed from the A7 owner worktree, with `rtk proxy`:

- `python3 specs/epic-195-a7-compatibility/verification/spec-review-fresh-chain.fixture.py`: exit 0; 16 Bash and 16 PowerShell cases PASS.
- `python3 specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py`: exit 0; 12 Bash and 12 PowerShell cases PASS.
- `git diff --check`: exit 0.

The independent attempt-15/round-2 outputs exist. Read-only validation confirmed distinct host session identities, all 11 admitted input hashes across both manifests, contract-to-reviewer identity and manifest equality, the sanitized A summary, and derived NEEDS_WORK with one Critical and one Major finding. This check is not a substitute for the complete next-round admission validator.

## Remaining findings

Additional local verification on 2026-10-05: `rtk proxy python3 -B tests/spec-reviewer-hash-capability.tests.py -v` exited 0, with all three tests passing. The checks cover both reviewer roles' read-only hash capability, exact file/record hashing without file mutation, and literal shell metacharacters remaining data. These contract/recipe tests do not establish native host permission enforcement or resolve the independent findings below.

- AC-OBSERVABLE: distinguish mandatory local producer coverage (success, mismatch, nonzero exit, missing expected state) from TEST-019's separately governed context-present integration SKIP conditions. Do not remove any of the four mandatory producer branches.
- APPROVAL-BOUNDARY: the current amendment record labels its date as a transcription date and explicitly says the original approval timestamp is unavailable. Preserve that truthful historical record; do not invent an original date or reinterpret it as a new scoped approval.

The review launch interruption is no longer the immediate blocker: both independent first turns completed. Specification acceptance remains Pending. These results do not establish implementation acceptance, native activation, current-head CI, merge, or Done. No Git or review-status mutation was performed by this verification.
