# PR #381: evidence publication without target HEAD mutation

Date: 2026-09-12 (JST)
Base commit: 06df1c63b2aecd2934bbf8903af25e111bf7b089
Scope: publication instructions, proposed ADR-0027, schema description,
report template, and a real-Git integration regression.

Addresses the publication failure described in
https://github.com/aharada54914/sdd-forge/pull/381#discussion_r3991438187.
Issue #349 requires exact current target HEAD identity. Committing a report
on that same target changes HEAD and invalidates the report. The documented
publication path now uses a separate evidence checkout and an immutable
evidence-commit link plus a separately saved report digest.

No checker exemption or schema-validation relaxation was introduced. The
existing external absolute report path already supports this workflow.
This is an operational documentation correction with added regression
coverage, not a claim of a previously failing product test becoming green.

## Observed verification

- Focused compiled currentness suite: 2 passed, 0 failed, exit 0.
- Full MCP suite (`npm test --prefix mcp/sdd-forge-mcp`): 264 passed,
  0 failed, 0 skipped, exit 0.
- `npm run typecheck --prefix mcp/sdd-forge-mcp`: exit 0.
- `bash tests/adversarial-review-contracts.tests.sh`: passed, exit 0.
- `git diff --check`: exit 0.

Full local test log: `/tmp/pr381-publication-mcp-20260912.log`.
SHA-256: `1431efb47b1ff3ed4509ab3d3a2c03fc3530fac5ab9f0acc2530e629d96bbfe8`.

The new test uses two real temporary Git repositories. Evidence publication
and a later receipt commit leave the target clean and current; report-byte
tampering fails the saved digest; committing evidence on the target still
fails with `head-mismatch`. The test also reads back the exact report bytes
from the immutable evidence commit.

## Remaining boundaries

Scoped self-review found no critical issue in these changes; this is not an
independent approval. ADR-0027 remains Proposed. Citation completeness and
cross-task scratch-root separation findings remain unresolved. Latest-head
CI, independent re-review, merge, and post-merge verification are not claimed
complete by this report. Unrelated Issue #288 notes are excluded.
