# T-005 citation repair diagnostic addendum

Run ID: citation-repair-20261009-local-diagnostic
Task Attempt Count: not applicable (citation-only diagnostic; no formal task execution or reservation)

Issue/task: shared-review-launch-repair T-005 (Approved, Implementation Complete,
Risk high as observed in the canonical task plan). No lifecycle update is made.
Owner checkout: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`.
HEAD before repair: `9ce19abe90df0cb83e385f96855e4843318a8807`.

Scope: only stale validator line references in
`plugins/sdd-review-loop/references/review-context-boundary.md` and their matching
anchor addresses in `tests/review-context-boundary.tests.sh`, plus this non-frozen
addendum. Both target files were already dirty; their existing content is retained.
The checkout also has numerous existing source, test, report, spec and ledger
changes; none belongs to this subtask. Parent owns concurrent fixture delivery work.

Risk classification remains high under the existing task. This delta changes no
contract text, assertions, validator behavior, admission, approval, identity,
reservation, evidence status or frozen artifact. Consumers are boundary-document
readers and the existing anchor test. No callers, fixtures, config or exports need
changes for line-address corrections.

Before SHA-256:
- document: `d627ed207f1bc8e89a5f0f9bd32b637259205bf695966ab052d92a0ecbf39477`
- test: `653df82aaef2d5b70d1052a959c4994904a7741320eb49eccd1a9d12bf169b1b`

Preflight field/counterpart/mismatch checklist:
- Persisted field: each validator citation address in the boundary document.
  Counterpart: unchanged anchor pattern in the test and actual validator construct.
  Mismatch test: existing bidirectional citation/anchor check and fixed-text span
  check in `tests/review-context-boundary.tests.sh`.
- Persisted field: matching test anchor address. Counterpart: document citation and
  unchanged validator text. Mismatch test: same checks, including rejection of
  absent document citations and missing anchor patterns.
- No contract/verdict/traceability field is introduced or modified.

Before edit, `rtk proxy bash tests/review-context-boundary.tests.sh` returned 1:
`not ok: review-context-boundary.md cites validate-review-context-set.sh:459 for ".schema == "review-context-invocation/v2"", but those lines no longer contain it; the citation has slid off the construct it describes`.

Validation plan: run the same actual-path boundary suite after correction; inspect
the numeric-only delta and final file hashes. Parent independently reviews the
bounded delta. Formal quality gate, current-head CI, native host activation and
delivery are NOT RUN by this subtask. No installed baseline changes or git writes.

Policy reference: checkout AGENTS.md was read. This older checkout has no
docs/development-policy.md; the parent checkout policy at
`/Users/jrmag/sdd-forge/docs/development-policy.md` was read as requested, without
copying it into this checkout or treating it as task migration authority.

## Results

`rtk proxy bash tests/review-context-boundary.tests.sh` completed with exit 0 at
the actual owning checkout path. It verified 32 citation anchors; all
TEST-RCB-001..010 and TEST-RCB-005b cases passed on Bash and PowerShell; the three
investigation runtime tests passed; investigation completeness ran for regular,
hardlink and symlink fixtures, ending `PASS: 84; FAIL: 0` for the final symlink
suite. No test criterion or skip branch was changed.

`rtk proxy git diff --check -- plugins/sdd-review-loop/references/review-context-boundary.md tests/review-context-boundary.tests.sh`
returned 0. Applying the inverse citation-number mapping in memory reproduced
each exact before SHA-256, proving all non-citation bytes were preserved.

After SHA-256:
- document: `95f994a868ed6a64299fdbca4eb5c5953e3a42fae303649fb66683d4ccb62fe1`
- test: `f8d6a0835d28285e74543f587798e9e4bba73bf15ff1c97ee19ea41cca1a8cff`

One citation-only correction was applied. A preliminary Node command used to
construct the patch failed with SyntaxError before producing or applying a patch;
the corrected command generated the patch for apply_patch. No retry bypassed a
protection refusal. Formal independent review and quality-gate remain the parent
workflow's responsibility; this diagnostic adds no verdict or lifecycle claim.
