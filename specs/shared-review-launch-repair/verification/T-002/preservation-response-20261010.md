# T-002 AC-004 preservation evidence

This is supplemental evidence, not a verdict or an amendment to approved criteria.
Keep the preceding NEEDS_WORK report and all historical records unchanged.
RT-20261009-001's alternative RED authorization does not apply to T-002.

The approved design's AC-004 row explicitly says “Existing WFI-030 traceability
normalization; no other cell or body exemption” (`design.md:20`). Its scope
reuses existing behavior (`design.md:7,11`); the task requires preserving authorized
normalization and rejecting other changes (`tasks.md:163`). TEST-007 and
TEST-008a–d enumerate those preservation assertions (`acceptance-tests.md:23-27`).
No AC-004 implementation defect or pre-fix failure is claimed.

The accompanying results and admitted baseline copies compare both complete
workflow validators against Git commit
`9ce19abe90df0cb83e385f96855e4843318a8807`. Exact byte equality is checked before
delivery. This proves unchanged implementation, not that the baseline is generally
verified or approved for installation. Existing behavioral evidence remains
required: authorized lifecycle changes, unknown/annotated states, Evidence-cell
and body changes, and raw prelaunch rejection are mapped in the implementation
report at lines 309–318 and the admitted traceability fixtures/logs.

The task-level genuine historical extraction RED/GREEN applies to the new AC-005
common helper work, as documented in the existing report. It is not an AC-004
failure. Evaluate whether the approved preservation requirements and task-level
RED/GREEN requirement are satisfied on that basis; do not invent an old defect or
silently waive any criterion. If a per-AC historical failure is required, identify
the exact governing requirement rather than deriving it from this response.

The new helper only reads Git/source/ledger and writes new supplemental evidence
and an isolated input copy. It does not reserve, change task state, alter frozen
inputs, install, commit, or turn diagnostic success into PASS. Native Windows,
full CI and merge remain unproved by this comparison.
