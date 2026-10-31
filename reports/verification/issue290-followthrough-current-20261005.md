# Issue 290 current follow-through — 2026-10-05

Scope: read-only verification of the task-plan provenance re-review prerequisite. Owner: `/Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge`; HEAD `badbb7aa5d16114be542c33018967c58770d1a41`. This worktree has existing dirty implementation, contracts, tests, ledger, and untracked review evidence; all were retained. Risk: high for the protected reviewer identity wording and formal provenance/ledger contract. No protected file, task status, reservation, or verdict was changed by this follow-through.

| Command (`rtk proxy`, `login=false`, owner checkout) | Exit | Result |
|---|---:|---|
| `bash plugins/sdd-review-loop/scripts/task-review-precheck.sh sdd-domain-concept-test 7 1 --verify-inputs` | 0 | `task-review-precheck: inputs verified for reviewer invocation.` |
| `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature sdd-domain-concept-test` | 1 | `stage-provenance: task plan hash is stale` |
| `shasum -a 256` of both reviewer roles, boundary, and `tasks.md` | 0 | A `e114b7a61b673e5230a691df3cc8f338df934b2ecf883fcd1b58206d14bae4a8`; B `4f0add219de40b025d8bf0b73b5fe048e4d94728de2bd7616da728c930498ae9`; boundary `b537052a70eb52e73cd9add1ab2bb6e19f2b29796efd58bf7df2684b8bd318c1`; task plan `8e8c8dafa256652f3ac9adb77b4adf1a54a00bbb59d549bef95970adf6470e02`. |

The three protected preimages still match the current-byte human-apply candidate recorded in `issue290-role-identity-current-candidate-evidence-20261005.md`; its application remains unperformed. The earlier PreToolUse refusal is documented in `issue290-a6-b-distinct-clarification-candidate-20261004.md`. The current precheck proves consistent inputs, not a reviewer verdict or provenance binding. Attempt 7 round 1 contains precheck and dependency graph only. No reviewer identity was reserved because the protected wording repair has not been applied and read back.

Next authorized sequence: human protected application/readback of the already prepared exact three-insertion candidate; verify attempt-7 inputs again; allocate fresh independent A and B identities; run A, counts-only summary, then B; persist canonical integrated evidence; require `check-workflow-state` exit 0. T-001 remains Approved/In Progress and T-005 Approved/Planned. T-005 implementation, formal quality gate, current-head CI, commit, push, and PR were not run in this follow-through.
