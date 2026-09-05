# {{DATE}} Adversarial Review — {{TARGET}} — Integrated Findings

Produced by a two-reviewer adversarial review (Reviewer A: design /
maintainability; Reviewer B: security / test / operations) with
cross-critique, on `{{BRANCH}}` @ `{{COMMIT}}`.

## Report Metadata (immutable target identity)

<!-- Fill all fields before publishing; do not edit post-publication.
     A report is STALE if head_sha or merge_base_sha no longer matches the
     branch's current state. A stale report MUST NOT satisfy
     "Adversarial-Lane: fired" in the PR body. -->

```yaml
schema_version:  adversarial-review-report.v1
merge_base_sha:  {{MERGE_BASE_SHA}}
head_sha:        {{HEAD_SHA}}
diff_sha256:     {{DIFF_SHA256}}
created_at:      {{ISO8601_UTC}}
skill_version:   {{SKILL_GIT_SHA_OR_DESCRIBE}}
reviewer_run_ids:
  - reviewer_a: {{RUN_ID_A}}
  - reviewer_b: {{RUN_ID_B}}
```

### Stale judgement rules

A report becomes stale when **any** of the following is true:

1. `head_sha` does not match `git rev-parse HEAD` on the branch.
2. `merge_base_sha` does not match `git merge-base HEAD <base-branch>`.
3. The `diff_sha256` computed from `git diff <merge_base_sha>..<head_sha>`
   does not match the stored value.

When a report is stale, it MUST be regenerated before it can satisfy
`Adversarial-Lane: fired`. It may be kept as historical context with a
`[STALE — superseded by <new-report-path>]` notice at the top.

## Verdict summary

- Overall: APPROVE | APPROVE-WITH-FIXES | BLOCK (any open CRITICAL ⇒ BLOCK)
- Adopted findings: {{N}} critical / {{N}} high / {{N}} medium / {{N}} low;
  {{N}} rejected or re-scoped
- Provenance: {{N}} by A, {{N}} by B, {{N}} by both, {{N}} surfaced in
  cross-critique (`*-C*` IDs)
- Cross-critique basis summary: {{N}} code_evidence, {{N}} spec_evidence,
  {{N}} concern-only; {{N}} PROPOSE-REJECT accepted, {{N}} rejected by author
- Scope summary: {{N}} in_scope, {{N}} out_of_scope (not implemented),
  {{N}} unclear (human decision pending)

## Confirmed findings

<!-- Merge converging IDs, e.g. `A-6+B-C2`. One table per severity;
     omit empty severities only if noted in the verdict summary.
     Include Scope column: in_scope | out_of_scope | unclear -->

### Critical

| ID | Location | Finding | Scope | Agreed fix |
|----|----------|---------|-------|------------|

### High

| ID | Location | Finding | Scope | Agreed fix |
|----|----------|---------|-------|------------|

### Medium

| ID | Location | Finding | Scope | Agreed fix |
|----|----------|---------|-------|------------|

### Low

| ID | Location | Finding | Scope | Agreed fix |
|----|----------|---------|-------|------------|

## Rejected and re-scoped findings

<!-- Kept on record so the same false alarm is not re-raised later.
     Include the cross-critique basis (code_evidence / spec_evidence / concern)
     that drove the rejection proposal. -->

| ID | Claim | Basis kind | Cross-critique verdicts | Ruling and evidence |
|----|-------|------------|-------------------------|---------------------|

## Verified non-findings

<!-- Union of both reviewers' checked-and-clean declarations, as prose.
     Example: "No hardcoded secrets; CI permissions/secrets usage sound; no
     blocking async calls; no empty catches; dependencies real and pinned." -->

## Remediation plan (phased)

<!-- Group by urgency and dependency, not just severity. Typical shape: -->

- **Phase 1 (immediate)**: {{quick guards, interim mitigations}}
- **Phase 2 (consolidation)**: {{extractions, dedup, structural cleanups}}
- **Phase 3 (tests)**: {{missing regression/concurrency/negative tests}}
- **Phase 4 (design)**: {{ADR-scale changes, staged decompositions}}

Constraints carried into fixes: {{e.g. no new frameworks; behavior-preserving
except where the behavior change is the point}}

### TODO

- [ ] {{ID}} — {{action}} (Phase 1)
- [ ] {{ID}} — {{action}} (Phase 2)

## Fix verification (fresh context)

<!-- Appended after fixes land — Phase R. Reviewer: a NEW agent with no prior
     involvement; input = adopted findings + fix diff only. -->

| ID | Verdict (VERIFIED / NOT-FIXED / PARTIALLY-FIXED / CLAIM-ERROR) | Evidence |
|----|----------------------------------------------------------------|----------|

New issues introduced by fixes: {{V-* findings or "none"}}

## Amendments (decision record)

<!-- Post-review corrections and human decisions, appended over time. -->

- {{ID}} correction: {{fact}} | human decision — {{decision}}
