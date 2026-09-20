# Issue #347: retain the substance of a concern

Status: locally verified; CI, required approval, merge and post-merge checks pending.

## Root cause and bounded change

At baseline `206c25cad969675fd00aa9712a4e077e62d2a3a6`, the `basis`
definition in `contracts/cross-critique.v1.schema.json` required only `kind`
for concerns and rejected `claim` as an additional property. Thus a content-free
concern was valid while the assertion field requested in Issue #347 was invalid.

The schema now permits a nonblank `basis.claim` and requires it for concerns.
The Phase 2 prompt requests the same field. Evidence-backed records retain their
existing citation claims without requiring a duplicate top-level assertion.
Enum validation, evidence requirements for rejection/severity changes, scope
checks, persisted verdicts and blind-review inputs are unchanged.

## Actual verification

- Test-first focused run: 13 passed, 2 failed, exit 1. The failures demonstrated
  both the rejected populated claim and the accepted absent claim.
- After the fix, `npm test` in `mcp/sdd-forge-mcp`: 263 passed, 0 failed,
  0 skipped, exit 0. The added regression covers missing, empty, whitespace,
  null and numeric claims, and a populated concern.
- Actual macOS PowerShell `Test-Json` using the same repository schema:
  16 passed, 0 failed, exit 0. Both SUPPORT and SUPPLEMENT reject absent/invalid
  claims and accept populated claims; concerns still cannot propose rejection
  or severity changes; both evidence kinds retain citation-only compatibility.
- `npm run typecheck` and `git diff --check`: exit 0.
- Author-side review found no Critical issue in the bounded diff. This is not
  an independent GitHub approval or a formal SDD gate result.

## Remaining Issue #347 scope

This fixes the data-loss contract defect, not the entire Issue. The schema and
standalone reviewer prompt do not by themselves prove integration into every
Shell/PowerShell review gate or Claude/Codex runtime. No existing review report
was rewritten, and no currentness identity was rebound. The schema is still part
of an unmerged PR; this change must not be described as deployed or the Issue
closed before the remaining acceptance criteria and integration are verified.
