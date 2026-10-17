# Issue 423 T-003 cloud continuation

## Current continuation (2026-10-17)

The sections below retain the original checkpoint history. The current published
baseline is `e6673e683ed45aa49b6a9b2efad9ce4dd76e2589`; its GitHub Actions run
`38964412245` completed successfully (37 jobs). That result does not cover later
commits or establish formal task completion. T-003 regression coverage now has
28 passing tests; see `issue423-t003-cloud-20261017/README.md` and
`issue423-portable-prerequisites-20261017.md` in this directory for evidence and
the remaining T-001/T-002 formal admission limitations.

For subsequent tasks, read
[T-004/T-005 research handoff](issue423-t004-t005-research-handoff-20261017.md).
Preserve historical verdicts. Do not start dependent implementation merely
because regression or CI is green; reconcile the canonical prerequisite gates.

## Checkpoint scope

Continue on `codex/issue423-boundary-checkpoint`. This checkpoint reconciles local
commit `3a3c963f15e84cb9af8add07fd182f1288cb1bb3` with remote base
`874d95540d91a40fea18fab9af5d2d6c880546dd`, preserving the four intervening remote
commits. Most local functional changes were already published. This follow-up
contains only evaluator typing/schema-identity validation, its regression, and
this handoff. Unrelated dirty local work is not part of this checkpoint.

Read `AGENTS.md`, `docs/development-policy.md`, the authoritative
`specs/sdd-domain-multitarget/` task and contracts, and
`reports/verification/issue423-cloud-inputs-20261016/README.md` before editing.
This is an existing high-risk task, not a new routine task or a Done declaration.

## Executed validation

On the reconciled candidate, the following commands exited zero:

- `python3 tests/sdd-domain-multitarget-T-003.tests.py`: 22 tests passed.
- `bash tests/registry-discovery.tests.sh`: 21 checks passed.
- `pwsh -NoProfile -File tests/registry-discovery.tests.ps1`: 21 checks passed.
- `python3 plugins/sdd-quality-loop/scripts/vendor-capability-registry.py --check`: no drift.

These are local regressions, not full CI, native Windows proof, independent
acceptance or quality-gate completion. Historical evidence remains unchanged.

## Next authorized work

The user approved a test-only additional repair and independent re-review to
resolve the outstanding Major: five target fixtures currently share the same
selection shape and mostly assert names, rather than concrete target-specific
inclusion/exclusion behavior for AC-003a through AC-003e. Inspect the original
finding and approved requirements; add distinct assertions for CLI contracts/
package/security, UI UX/API/data/security, design-only required unit/acceptance/
build with only the approved compile waiver, IaC validate/plan/policy without an
apply claim, and low-code data/permissions/process/package without a universal
code-build requirement. Do not substitute these summaries for the contracts.

Preserve mandatory checks: unexecuted or unavailable means BLOCKED. Only checks
already optional and not selected may be not-applicable with a reason. Do not
invent conditional predicates absent from the Registry. Keep scope test-only;
record a concrete blocker if a production contract change proves necessary.

After regression and an independent no-history review, use the legitimate
quality-gate transition to Done only if every required condition is satisfied.
Do not overwrite old NEEDS_WORK verdicts or count this checkpoint as a PASS.

## Formal admission limitations

The cloud-input README records published historical originals and the remaining
nonportable prerequisites. In particular, the canonical T-002 evidence bundle
is absent, public task states differ from local historical completion records,
archived reviewed helper/installer bytes are not the active public bytes, and
one historical manifest input remains private. Published originals are useful
evidence, not proof that current formal admission succeeds. Reconcile through
the authorized process; do not fabricate or mechanically promote task states.

Do not publish private original reports, credentials, absolute workstation paths,
or the local private evidence archive. If formal admission requires unavailable
private material or a new contract decision, identify the exact condition and
continue independent authorized test work. Do not relabel a redacted summary as
the hash-identical original.

No reinstall, global trust/permission change, Gemini use, fabricated identity,
protection bypass, or frozen-evidence rewrite is authorized by this handoff.
Commit/push were authorized for continuity; full CI, formal PASS, merge and Done
must be reported separately when actually achieved.
