# Approved Sonnet routing alignment

Task: shared-review-launch-repair T-004 bounded regression repair.
Owner: shared-review-launch-integration checkout.
Base HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807 (detached).

The checkout already contains shared-launch implementation and evidence changes.
The four targets below were clean before this repair; all other changes are retained.
The combined rollback worker confirmed these targets are outside its 62-file snapshot.

Scope: docs/agent-capability-matrix.md, the implement-task agent-delegation-policy.md,
and tests/agent-model-routing.tests.sh/.ps1. The user approved the Claude evaluator
Sonnet selection and this limited repair. Align the stale Opus assertions with that
selection; retain generic strong/Opus mapping and Codex strong/high routing.

Risk: part of the high-risk shared-launch change; this is not a new authorization
or a waiver of independent review. No frozen review output or task state is changed.
Affected contract: host-specific evaluator model selection.

Observed failure before repair: the full Bash suite reports
`not ok: Claude evaluator must remain Opus`, while evaluator.md declares Sonnet.
Required validation: both routing suites, independent diff review, final combined
regressions and applicable exact-head CI. Prior rollback evidence excludes this repair.

Verification after repair: `bash tests/agent-model-routing.tests.sh` and
`pwsh -NoProfile -File tests/agent-model-routing.tests.ps1` both exited 0.
Their deliberate inconsistent-risk fixture prints a failure diagnostic; the driver
verifies that rejection and succeeds. Output was observed directly, not saved as a log.
Independent diff review by sonnet_alignment_review found no concrete defects in
the four targets and confirmed generic Opus and Codex strong/high routing remain.
This diff review is not the formal quality gate. The full-suite runs started before
this repair and cannot prove the final snapshot; exact-head CI remains pending.

Approved generator repair: Claude evaluator rendering must retain Sonnet/medium,
while selector defaults and Codex evaluator strong/high remain unchanged. Scope
extends to the v2 registry, both frontmatter renderers, evaluator effort metadata,
their Bash/PowerShell regression drivers and PLUGIN-CONTRACTS.md. Existing dirty
changes are retained. This host-specific contract change remains high risk.
Before repair, renderer checks TEST-014 and TEST-017 fail because regeneration
uses the shared strong/high defaults. Validate override, absent-override fallback,
malformed/case rejection, both runtimes and unchanged selector/Codex behavior;
independent review and final-head CI remain required.

Generator repair verification: Bash renderer suite passed 30 checks; PowerShell
renderer suite passed 34 checks. The initial PowerShell null-input case exposed
property access before type validation; validation now checks the object type
first, and the complete rerun passed. Both routing drivers also exited 0.
Independent diff review found no blocking implementation defect and confirmed
Claude-only override resolution and unchanged Codex/base-selector behavior.
Its minor documentation finding (base fields versus resolved fields) was corrected.
This review excluded the pre-existing supplemental/gate declaration changes in
evaluator.md and did not rerun tests or constitute formal quality-gate acceptance.
Full regressions, native activation, exact-head CI and merge remain unverified.
