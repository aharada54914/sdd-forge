# PR #381: explicit zero-source-finding declaration

Base commit: dec16c722c6a51cb685ff2ec303b7c93fc475352
Finding: https://github.com/aharada54914/sdd-forge/pull/381#discussion_r3993185697

## Scope and decision

Require `source_finding_count: 0` for completed empty annexes. An absent count
is unknown, not zero; a positive count cannot accompany a completed empty
annex. Counts must be nonnegative integers, and zero cannot accompany any
verdicts. Preserve the existing unavailable-state rules and historical
nonempty annexes. This follows the review's explicit-count option, not its
alternative of independently loading and cross-checking source reports.

The skill instructs producers to read both original blind-review reports
before declaring zero, retain those reports, and mark missing/unavailable
outputs unavailable. Contract validation does not prove that a producer's
declaration is truthful, authenticate the reports, or establish completeness
of a nonempty annex. No historical evidence or gate verdict is rewritten.

## Verification

- RED: `node tests/adversarial-review-contracts.tests.mjs` exited 1 before
  the schema change: `empty annex requires an explicit source finding count:
  unexpectedly valid`.
- GREEN: the same root suite exits 0 after repair.
- `npm test` in `mcp/sdd-forge-mcp`: 270 passed, 0 failed, 0 skipped, exit 0.
  The canonical CLI matrix now covers 45 cases across absent/legacy,
  sdd-gate and standalone lanes, including missing count, numeric/string/
  null/boolean invalid values, conflicting zero/nonempty records, valid
  zero/empty records and the unchanged unavailable cases. Every case checks
  exit status, JSON status and unchanged input bytes.
- `npm run typecheck`: exit 0.
- Skill validator initially could not import PyYAML with the default Python.
  `uv run --with pyyaml python` running the existing `quick_validate.py`
  succeeds: `Skill is valid!` (exit 0), without modifying project dependencies.
- `git diff --check`: exit 0.
- MCP log: `/tmp/pr381-source-count-mcp-20260912.log`, SHA-256
  `8141c2740a614d66a9375d32c1a3a047f7848ad62678660fd2ebd0edc538732c`.

## Scope review and handoff

Reviewed schema conditions, CLI callers and producer wording. No new
dependencies or writes to source evidence are introduced. The condition is
restricted to completed empty annexes; unavailable annexes still require a
reason and cannot carry verdicts. Source count is explicitly a declaration,
not an authenticated source binding. Remaining scratch-root isolation review
findings, independent review and latest-head CI are not discharged by these
local checks. The full fallback run started before this repair remains a
separate run and must not be cited as latest-state verification of this change.
