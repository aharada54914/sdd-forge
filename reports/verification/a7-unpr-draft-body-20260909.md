## Purpose

Expose the existing post-#247 branch work for integration tracking. This is
a draft inventory publication, not an implementation change or gate verdict.

Pinned head: e1e019be691b40dcb292fa16c3fb14f578d4433f.
Compared main: 4366438f3b243210a4ece5a17f873ca2d920600a.
The contribution diff contains 49 files, 2933 insertions and 32 deletions;
these are Git diff counts, not proof that every change is semantically unique.

## Existing work

- T-010: SKIP allowlist manifest and evaluator/tests.
- T-011: suite registration and staged CI workflow.
- T-012: live-model structural refresh test and historical attempt evidence.
- T-013: golden-baseline CI write refusal checks.

## Not ready to merge

Historical Implementation Complete/Passed text is not a current gate PASS.
Preserve T-004 evidence-repair findings, pending live refresh proof, current
dependency/SKIP reconciliation, full required CI, and independent formal
provenance/quality review. Do not copy the old staged workflow over newer main;
all existing checks and dependencies must survive integration.

Local evidence-repair work and uncommitted changes in other worktrees are NOT
included in this remote head. No tests were rerun for this draft publication.
Ordinary implementation/integration remains subject to the unresolved hook
activation gate; this PR does not extend the recovery-only admission.

Related issue: #195. Do not automatically close it on publication.
