# PR #371: severity vocabulary and evidence publication

Date: 2026-09-12 JST
Base commit: 5f4c346d8cce9379047e8e469137427629431665

## Root cause and repair

The standalone reviewer prompts use CRITICAL/HIGH/MEDIUM/LOW, whereas the
shared cross-critique contract accepted only the SDD gate vocabulary
Critical/Major/Minor. The mandatory annex checker therefore rejected valid
standalone severity-change proposals. An optional root review_lane now selects
an exact vocabulary: omitted or sdd-gate retains legacy semantics;
standalone-adversarial selects the four standalone severities. Neither branch
maps values, rewrites persisted verdicts, nor relaxes evidence requirements.
The scope prompt and schema descriptions now match the existing REQ/AC/task
alternative-reference validation.

Publication documentation and the two-repository regression are ported from
PR #381 commit 97801ccfff5e27ddbfde43e7423b142f8fe5e53f. Reports are published
in a separate evidence checkout with immutable commit and digest references;
no evidence-only target-HEAD exemption is introduced. This documents and tests
existing runtime behavior, not a newly fixed currentness-validator defect.

## Verification

- Severity regressions before production repair: cross-critique suite 18 passed,
  2 failed (explicit lane rejected; standalone MEDIUM rejected).
- After repair: `npm test` in mcp/sdd-forge-mcp: 269 passed, 0 failed,
  0 skipped, exit 0. Includes lane case/null/unknown/mixed vocabulary rejection,
  read-only CLI validation, independent evidence publication, digest tampering,
  and stale target-HEAD rejection.
- `npm run typecheck`: exit 0.
- `npm audit --omit=dev`: 0 vulnerabilities, exit 0.
- Skill quick_validate.py using uv with pyyaml: Skill is valid, exit 0.
- `git diff --check`: exit 0.
- Independent read-only reviewer `/root/pr371_merge_review`: scoped delta PASS,
  37 additional severity/evidence probes passed, no remaining blocker in this
  delta. Existing full-PR review limitations and Issue acceptance conditions are
  not replaced by this scoped result.

## Remaining integration conditions

Latest-head CI after pushing this change is still required. This report does
not assert merge, postmerge validation, or closure of Issues #345–#350.
The user's all-PR approval-count bypass authorization does not waive CI,
substantive findings, or protection hooks.
