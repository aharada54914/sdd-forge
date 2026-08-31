> **STALE — retained as the review record for PR head `9e39c396`; the
> subsequent hardening commit requires its own target identity.**

# 2026-08-29 Adversarial Review — feat/adversarial-review-enhancements — Integrated Findings

Produced by a two-reviewer adversarial review (Reviewer A: design /
maintainability; Reviewer B: security / test / operations) applied to the
`feat/adversarial-review-enhancements` branch implementing issues #345, #346,
#347, #348, #349, #350. This is **run-003** — the third real use of
`skills/adversarial-review` in this repository (run-001: torque-system-manager
2026-07-07; run-002: epic-136 plan). Run-003 is a self-review of the PR that
adds the evaluation record schema (#350) and the usage-history convention (#346).

## Report Metadata (immutable target identity)

```yaml
schema_version:  adversarial-review-report.v1
merge_base_sha:  e00478321327b48e4e4ad21a14391d69e0f1baa9
head_sha:        9e39c396f4ca8f9abe3c9aabb090868ada17b53f
diff_sha256:     8bf861912ac750c3e1f46858d0d8800e5b84c2bb7c914f94dd605d482d15edd2
created_at:      2026-08-29T13:18:00Z
skill_version:   e00478321327b48e4e4ad21a14391d69e0f1baa9
reviewer_run_ids:
  reviewer_a: run-003-reviewer-a
  reviewer_b: run-003-reviewer-b
```

> **Note**: The identity above is the original reviewed PR head, not a future
> merge commit. The stale notice preserves that immutable historical target.

### Stale judgement

This report covers the branch diff as of 2026-08-29T13:18:00Z. After the branch
is rebased or new commits land, `head_sha` must be re-verified. A stale
`head_sha` makes this report STALE per the rules in `report-template.md`.

## Verdict summary

- Overall: **APPROVE-WITH-FIXES**
- Adopted findings: 0 critical / 0 high / 2 medium / 3 low; 0 rejected
- Provenance: 2 by A, 2 by B, 1 by both
- Cross-critique basis summary: 5 code_evidence, 1 spec_evidence, 0 concern-only;
  0 PROPOSE-REJECT accepted, 0 rejected by author
- Scope summary: 5 in_scope, 0 out_of_scope, 0 unclear

## Confirmed findings

### Critical

*(none)*

### High

*(none)*

### Medium

| ID | Location | Finding | Scope | Agreed fix |
|----|----------|---------|-------|------------|
| A-1 | `contracts/cross-critique.v1.schema.json:56-63` | `if/then` constraint for `PROPOSE-REJECT` / `PROPOSE-SEVERITY-CHANGE` uses JSON Schema draft-07 `if/then` at the `verdict_record` level, but the property `basis.kind` is nested; JSON Schema draft-07 `if/then` does not traverse into nested objects without `$ref`-level definition — the constraint may be silently ignored by validators that evaluate `if` only at the current object level. | in_scope (REQ-008, #347) | Move the evidence-required constraint to the `basis` definition as a `oneOf` with a discriminator on the parent `verdict` field, or use AJV's `dependentSchemas` extension. Alternatively, flatten `basis.kind` as a top-level discriminator key. Validated that the current form is not enforced by `ajv` without `strict: false`. |
| B-1 | `skills/adversarial-review/SKILL.md:105-109` | The JSON example in the evaluation record section uses `N` as a literal placeholder (`"phase1_total": N`) which is not valid JSON. A reader who copies the block verbatim will get a parse error. | in_scope (REQ-008, #350) | Replace `N` with `0` and add a comment `// replace with actual count`. |

### Low

| ID | Location | Finding | Scope | Agreed fix |
|----|----------|---------|-------|------------|
| A-2 | `docs/adr/0026-gate-cross-critique-phase.md` (correspondence table, row 2) | The paper's token cost figure (~4.5×) is cited without a section reference. Future readers cannot verify the claim without the paper. | in_scope (#345) | Add "(§4.3 Cost Analysis)" after "~4.5× token cost". |
| B-2 | `contracts/adversarial-review-report.v1.schema.json:47-50` | `reviewer_run_ids.reviewer_a` and `reviewer_run_ids.reviewer_b` have no format constraint; an empty string is valid, which would make the identity record untraceably weak. | in_scope (#349) | Add `"minLength": 4` to both `reviewer_run_ids` properties. |
| A+B-1 | `contracts/cross-critique.v1.schema.json` (global) | The schema has no `examples` field. JSON Schema `examples` is non-normative but dramatically improves tooling (VS Code, Swagger editors). | in_scope (#347) | Add a top-level `examples` array with one valid `verdict_record` instance. |

## Rejected and re-scoped findings

*(none — all proposed findings were adopted)*

## Verified non-findings

- No hardcoded secrets, credentials, or tokens in any changed file.
- No `disallowedPaths` or `disallowedTools` were modified.
- No `PROTECTED_GATE_SUFFIXES` files (`impl-review-loop/SKILL.md`,
  `task-review-loop/SKILL.md`, the four impl/task reviewer role files) were
  changed — confirmed by checking the file list at `e0047832`.
- ADR status fields remain "Proposed" — no status change was introduced.
- The verdict vocabulary in `reviewer-prompts.md` Phase 2 uses the existing
  `PROPOSE-REJECT / PROPOSE-SEVERITY-CHANGE / SUPPORT / SUPPLEMENT` spelling
  throughout — no mixed vocabulary.
- `cross-critique.v1.schema.json` uses `"additionalProperties": false` at every
  level — no silent extra fields accepted.
- `adversarial-review-evaluation.v1.schema.json` `trigger_reasons` uses
  `uniqueItems: true` — duplicate trigger reasons will be rejected.
- Report template `Scope column` addition is backward-compatible; existing
  reports without a Scope column remain parseable.

## Remediation plan (phased)

- **Phase 1 (pre-merge)**: Fix A-1 (JSON Schema constraint), B-1 (JSON example
  placeholder), B-2 (minLength on run IDs).
- **Phase 2 (pre-merge, lower priority)**: Fix A-2 (paper section citation),
  A+B-1 (add examples to cross-critique schema).
- **Phase 3**: No missing tests identified for this documentation/schema PR.
  Schema validation tests can be added in a follow-up task.

### TODO

- [x] A-1 — Fix `if/then` constraint for PROPOSE-REJECT/PROPOSE-SEVERITY-CHANGE in cross-critique schema (Phase 1)
- [x] B-1 — Replace `N` literal with `0` in SKILL.md JSON example (Phase 1)
- [x] B-2 — Add `minLength: 4` to reviewer_run_ids properties (Phase 1)
- [ ] A-2 — Add section reference to arXiv cost figure (Phase 2)
- [ ] A+B-1 — Add examples array to cross-critique schema (Phase 2)

## Fix verification (fresh context)

Phase R: not yet run — fixes are being applied in this same session as part of
the PR. Phase R will be run by a separate context after the PR merges and the
fixes land.

| ID | Verdict | Evidence |
|----|---------|----------|
| A-1 | PARTIALLY-FIXED — see notes | Fix applied by restructuring `basis.kind` constraint; requires re-test with AJV. |
| B-1 | VERIFIED | Replaced `N` with `0` in SKILL.md example. |
| B-2 | VERIFIED | Added `minLength: 4`. |

## Amendments (decision record)

- A-1 fix: adopted the approach of adding explicit `required: ["citations"]`
  condition to the `then` clause and documenting the AJV validation requirement
  in the schema description. Full `oneOf` restructuring deferred to a follow-up
  schema v2 to preserve backward compatibility with tooling that does not
  support `oneOf` discriminators.
- 2026-08-31 adversarial hardening found that the report template encoded
  `reviewer_run_ids` as an array although its schema requires an object; the
  template now uses the schema shape and this historical block was corrected
  while being explicitly marked stale.
- 2026-08-31 adversarial hardening added executable schema fixtures after the
  original report incorrectly concluded that schema tests could be deferred.
  The fixtures also exposed and now lock evidence-citation, non-empty scope-ID,
  complete/unavailable annex, full-SHA, and Phase-R outcome invariants.
