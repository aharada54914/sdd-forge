# PR #371 / #381 contract integration finding

Compared current heads:

- #371: `24f2c88da3e83473f4c8e775fed392cd13257f47`
- #381: `f4833f9f55ec915ad851ca552e1a9d7900024861`

This is a pre-merge compatibility finding, not a failed GitHub CI run and
not a replacement formal review verdict. Existing independent records remain
unchanged.

## Reproduced behavior

Loaded each head's actual `contracts/cross-critique.v1.schema.json` with Ajv
from the installed CI MCP dependencies (`strict:false`,
`validateFormats:false`). Both schemas were compiled without modification.

| Input | #371 | #381 |
|---|---|---|
| Complete annex with zero verdicts | accepted | rejected |
| SUPPORT verdict with a nonblank concern claim and in-scope REQ-A1 reference | accepted | rejected |

The second fixture uses `basis: {kind: "concern", claim: "Investigate a concrete possible regression"}`
and `scope: {assessment: "in_scope", related_requirements: ["REQ-A1"]}`.
The surrounding fields and reviewer role are otherwise valid. This reproduces
an integration incompatibility rather than merely comparing schema text.

## Required reconciliation

Do not resolve shared contracts by taking an entire branch version:

- Preserve #371's required nonblank concern claim, required proposed severity
  for a severity change, and supported nonnumeric REQ/AC/T identifiers.
- Preserve #381's complete/unavailable verdict cardinality constraints,
  full target SHA checks, and Phase R outcome completeness.
- Preserve #371's explicit unavailable telemetry representation; do not
  convert missing measurements to zero or discard its producer contract.
- Run both the MCP contract/currentness tests from #371 and the POSIX
  adversarial contract checks from #381 against the reconciled schemas.
- Reconcile protocol/template and historical-record differences explicitly;
  do not rewrite historical verdicts or identities to make new tests pass.

The changes must then receive latest-head CI. Separate green CI on these two
pre-integration heads does not prove the combined result. This finding does
not require disabling any existing check or adding a new feature.

## Cross-critique repair — local verification, 2026-09-12

Changed `contracts/cross-critique.v1.schema.json` and the existing
`tests/adversarial-review-contracts.tests.mjs` suite. Each of the following
was first observed failing against the preceding implementation, then passing
after the scoped schema repair:

1. Nonblank concern claim: rejected as an additional property before repair.
2. Severity-change proposal without proposed severity: incorrectly accepted.
3. Namespaced scope identifier: REQ-A1 incorrectly rejected as nonnumeric.

Added 29 assertions covering these behaviors, all three scope ID families,
empty/whitespace/missing concern claims, malformed/empty/duplicate IDs, and
rejection/severity proposals based only on an unverified concern. The existing
concern-with-citations negative now includes a valid claim so it tests the
citation prohibition itself, not a missing-field side effect.

Executed `rtk proxy node tests/adversarial-review-contracts.tests.mjs`
after each repair, then `rtk proxy bash tests/adversarial-review-contracts.tests.sh`:
exit 0, `adversarial-review contract tests passed`.
`rtk proxy git diff --check`: exit 0.

Local self-review found no critical issue in this cross-critique slice;
this is not an independent approval or a whole-PR verdict. Complete-annex
cardinality, evidence citation requirements, full SHA validation, and Phase R
checks remain in the existing suite. No historical report or verdict changed.

Still required: evaluation telemetry and producer protocol/template
reconciliation, combined MCP coverage, independent review, commit/push,
latest-head CI and integration. The local slice must not be represented as
completion of either PR.

## Evaluation repair and remaining digest integration

Restored `token_usage` measured-total/source versus null/unavailable-reason
alternatives and nullable `duration_ms`, retaining #381's two-reviewer minimum,
path validation and all Phase R conditional requirements. Added 17 assertions:
11 token cases and 6 duration cases. Observed intended RED failures for both
newly accepted forms before changing the schema (additional property rejected;
null duration rejected), then GREEN. The existing Bash contract wrapper and
whitespace check both exit 0. Restored producer instructions and its telemetry
example, plus the reviewer concern-claim prompt. Historical evaluations remain
unchanged; missing telemetry is not fabricated.

Remaining concrete mismatch: #371's
`mcp/sdd-forge-mcp/scripts/check-adversarial-report.mjs:33` hashes
`git diff --no-ext-diff --no-textconv BASE..HEAD`, whereas #381's producer and
template request `git diff --binary --no-ext-diff BASE..HEAD`.
The commands differ for binary changes and textconv configuration. #381 does
not yet contain that checker or #371's two MCP regression test files. Import
those changes through the branch integration and reconcile the digest
producer/consumer together, with binary/textconv regression coverage, before
claiming currentness compatibility. Do not weaken the saved report digest,
head/base binding, or any stale-report rejection.

CI #371 run 34620741058 remained in progress when checked after these edits
(macOS test and Windows version gates still running). CI #381 run 34620742908
also remained in progress. Neither run covers these uncommitted edits.

## Digest repair — supersedes the mismatch above

PR #371 commits `749e7966` and `07724142` now use
`git diff --binary --no-ext-diff --no-textconv` in the currentness checker
and producer instructions. This branch's producer and report template use
the identical flags, enforced by the existing contract test.

The currentness fixture now commits actual binary bytes. It failed against
the old checker and passed after the one-flag repair. It also configures
unavailable external-diff and textconv drivers; the checker still succeeds,
demonstrating that these host settings cannot alter the bound diff. Existing
head/base/report/diff rejection cases remain enabled and pass.

Executed on #371: MCP full suite 263 passed, 0 failed, 0 skipped; typecheck
exit 0. After adding the host-driver fixture, recompiled and reran the
currentness test: 1 passed, 0 failed. On #381, the Bash adversarial contract
suite and whitespace check exit 0. Self-review found no critical issue in
this limited digest repair; this is not an independent whole-PR verdict.

Still pending: bringing #371's MCP files into #381 through integration,
combined-suite verification, independent review and latest-head CI. No
historical review verdict, receipt, or Issue completion claim was changed.
