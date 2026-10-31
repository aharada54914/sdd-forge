# Authorization-boundary repair verification

Human application reported backup `issue423-auth-backup.e7YfiU`.
The following commands were executed in the owner worktree after application:

| Command | Observed result |
| --- | --- |
| `git apply --reverse --check reports/verification/issue423-quality-auth-boundary-candidate.patch` | Exit 0; applied candidate matches. |
| `python3 tests/issue311-scratch-isolation.tests.py --repo .` | Exit 0; PASS: 60, FAIL: 0, Bash and PowerShell. |
| `python3 tests/review-scratch-history.tests.py --repo .` | Exit 0; PASS: 26, FAIL: 0, Bash and PowerShell. |
| `bash tests/review-context-boundary.tests.sh` | Exit 1; document's validator line 442 no longer contains the schema predicate. |

The behavioral suite rejected undeclared dependency inputs and accepted exact
report-output declarations in both runtimes. It also retained source/hash,
identity, duplicate-member, symlink, scratch-root and snapshot refusal checks.

The citation regression remains unresolved at this observation. These results
are fixture verification, not independent review, CI, native activation or merge.
No task status or review verdict is changed by this report.

## Citation repair follow-up

The delegated verification agent aligned the boundary document and its test's
line-reference anchors with the current validator; no validation rule was removed.
It reported `bash tests/review-context-boundary.tests.sh` exit 0, 32 citation
anchors matched, PASS: 84, FAIL: 0 (including Bash and PowerShell), and
`git diff --check` exit 0. This resolves the citation failure above.
Formal review, CI and merge remain pending.

## Remaining T-002 gate condition

The independent read-only audit found that `verification/T-002.contract.json`
still declares `stack: code` and requires lint, typecheck and build, none recorded
as passed. `plugins/sdd-quality-loop/references/risk-gate-matrix.md` limits the
current exemption to non-code stacks; the Python implementation cannot be
reclassified as shell to obtain that exemption. The proposed toolchain policy in
`verification/T-002/qg-prep-20261003/toolchain-applicability.md` is not applied.
These verification paths are relative to `specs/sdd-domain-multitarget/`.

The auditor's CI/package-script content search was rejected before execution by
PreToolUse. Therefore that audit does not establish that applicable commands are
absent everywhere. Existing fixture success does not satisfy these three fields.
No waiver, PASS verdict or task-status change is made here. Root cause resolution
requires identifying applicable checks or an explicit reviewed contract change,
not substituting unrelated MCP builds or marking unexecuted checks successful.
