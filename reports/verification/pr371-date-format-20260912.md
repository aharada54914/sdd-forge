# PR #371 / Issue #349: enforce report creation timestamp format

Base head: `07724142d29f37d4c9cb2ec3afa7b93da7db90e7`.
Observed 2026-09-12 JST. This is verification evidence, not a quality-gate verdict.

## Cause and bounded repair

`mcp/sdd-forge-mcp/scripts/check-adversarial-report.mjs` compiled its schema
with `validateFormats: false`. The schema's `created_at` date-time constraint
therefore did not reject invalid timestamps. Enable AJV's existing date-time
format implementation and declare ajv-formats as a direct dev dependency,
matching the repair already present on PR #381. No schema weakening, Git
identity exemption, review-state change or protected-hook edit is included.

## Observed regression

After adding the timestamp cases, `npm run pretest` succeeded and
`node --test dist-test/tests/adversarial-report-current.test.js` failed:
the invalid metadata was accepted with exit 0 instead of required exit 1.
After the repair, the same test succeeded. The cases cover invalid text,
February 30, date-only and timezone-less timestamps; leap day and an explicit
timezone offset remain accepted. Existing head/base/diff/report tampering
checks remain enabled.

All commands were run with `rtk proxy` from `mcp/sdd-forge-mcp`:

- `npm test`: 263 passed, 0 failed, 0 skipped; exit 0.
- `npm run typecheck`: exit 0.
- `npm audit --omit=dev`: 0 vulnerabilities; exit 0 (production dependencies only).
- Repository `git diff --check`: exit 0.

Full local suite log: `/tmp/pr371-date-mcp-20260912.log`.
SHA-256: `468fdd80a6dfe4596626a822cc9df2e5a5dfc9a28e3b53b369d680ebacffbc68`.
This local log is not a publicly uploaded CI artifact.

## Review and remaining work

Self-review found no additional critical finding in this bounded diff:
read-only behavior, fail-closed diagnostics and hash comparisons are unchanged.
This is not an independent review. Fresh latest-head CI is required after push.
PR #381 still contains citation-contract and evidence-publication repairs that
have not all reached #371; this date fix alone does not establish merge readiness
or complete Issue #349. No Issue closure or merge is claimed.
