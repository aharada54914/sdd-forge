# PR #381 citation validation

Date: 2026-09-12 (JST)
Base commit: 97801ccfff5e27ddbfde43e7423b142f8fe5e53f
Finding: https://github.com/aharada54914/sdd-forge/pull/381#discussion_r3991438196

The citation schema allowed missing coordinates and blank paths/claims.
Added code/spec evidence tests first: both failed with `missing line_start`,
actual true, expected false. After requiring both positive coordinates and
nonblank path/claim, the focused schema tests passed.

Added the read-only `check-cross-critique.mjs` command because Draft-07 alone
cannot compare sibling numeric values. It validates the schema and timestamp
before checking every citation for an ordered range. It emits JSON and returns
nonzero for invalid JSON, schema failure, reversed ranges, or an unavailable
validator. It does not read cited source files, execute annex content, modify
review verdicts, or prove the factual truth of an assertion. The skill now
requires this check before using the annex as evidence.

The new command test initially failed because the requested command did not
exist; this is distinct from the reproduced existing schema defect above.
The completed command is tested with equal/ascending/reversed coordinates,
malformed JSON, blank path/claim, missing coordinates and nonpositive lines
for both code and specification evidence.

## Actual verification

- Focused contract/CLI suite: 18 passed, 0 failed before additional negative
  cases were added to the same CLI test.
- Final full MCP suite: 267 passed, 0 failed, 0 skipped, exit 0; includes the
  expanded CLI test.
- `npm run typecheck --prefix mcp/sdd-forge-mcp`: exit 0.
- `bash tests/adversarial-review-contracts.tests.sh`: passed, exit 0.
- `git diff --check`: exit 0.

Log: `/tmp/pr381-citations-mcp-20260912.log`
SHA-256: `08f07da3cd3a5234cf2dd3fe7eab6af00ac2e2897789cb878f8c3bf917ac9a81`

Scoped self-review found no critical issue. Independent re-review, latest-head
CI and integration remain outstanding. Cross-task scratch-root separation is
still an open finding. No Issue closure or merge is claimed here.
