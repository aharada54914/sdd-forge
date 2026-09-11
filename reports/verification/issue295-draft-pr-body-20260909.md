## Scope

Refs #295 and #380. This draft exposes the existing, previously pushed
`auto/improve-20260817` commit `f6e7427c9648085ca86a0d0835fa28df8e5ff300`
for review. It is NOT ready to merge and does not close either issue.

The Python and PowerShell shell-command approval checks use their existing
primary-approval counting helpers instead of a raw substring regex. The intent
is to preserve denial while reporting the correct Second Approval reason.
Node already uses the subtraction-aware helper. Four files change (+44/-2).

## Duplicate branch reconciliation

`auto/improve-20260831` at `32a81f5ebe3b71d72ef274c7bc3776b6db12a70c`
contains the same two production changes with different comments and weaker
regression assertions. The August17 branch is selected for its Python/Node
exit-code and reason assertions, not because its old baseline is current.
Neither branch has been deleted or force-pushed. Do not merge both.

## Verification and outstanding gates

- Read the complete commit diff and confirmed exactly one commit outside main.
- `git diff --check origin/main...origin/auto/improve-20260817`: exit 0.
- Live main at inspection: `4366438f3b243210a4ece5a17f873ca2d920600a`.
- No current runtime PASS is claimed. A previous local original-guard probe
  was rejected by the host before execution; that is not a product test result.
- Historical issue test counts are not validation of this integration head.

Before marking ready or merging:

- [ ] Complete the applicable approved SDD task/specification and formal reviews.
- [ ] Reconcile against current main without overwriting unrelated changes.
- [ ] Strengthen regressions to assert parsed denial decision, exact reason class,
      and exit status across Python, Node and PowerShell; cover primary-only,
      secondary-only and mixed inputs while preserving existing sudo-denial tests.
- [ ] Replace early-exit grep assertions with full-output consumption where needed.
- [ ] Run admitted original test suites; do not bypass protective hooks.
- [ ] Require all mandatory CI and independent quality verification on final SHA.

The issue's other findings (CI inventory, installer tar failure handling and
documentation links) remain separately outstanding. CI inventory work overlaps
PR #381. This PR alone is not evidence that either audit issue is fully resolved.
Administrator approval bypass, if used later, does not waive any validation gate.
