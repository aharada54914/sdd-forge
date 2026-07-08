# {{DATE}} Adversarial Review — {{TARGET}} — Integrated Findings

Produced by a two-reviewer adversarial review (Reviewer A: design /
maintainability; Reviewer B: security / test / operations) with
cross-critique, on `{{BRANCH}}` @ `{{COMMIT}}`.

## Verdict summary

- Overall: APPROVE | APPROVE-WITH-FIXES | BLOCK (any open CRITICAL ⇒ BLOCK)
- Adopted findings: {{N}} critical / {{N}} high / {{N}} medium / {{N}} low;
  {{N}} rejected or re-scoped
- Provenance: {{N}} by A, {{N}} by B, {{N}} by both, {{N}} surfaced in
  cross-critique (`*-C*` IDs)

## Confirmed findings

<!-- Merge converging IDs, e.g. `A-6+B-C2`. One table per severity;
     omit empty severities only if noted in the verdict summary. -->

### Critical

| ID | Location | Finding | Agreed fix |
|----|----------|---------|------------|

### High

| ID | Location | Finding | Agreed fix |
|----|----------|---------|------------|

### Medium

| ID | Location | Finding | Agreed fix |
|----|----------|---------|------------|

### Low

| ID | Location | Finding | Agreed fix |
|----|----------|---------|------------|

## Rejected and re-scoped findings

<!-- Kept on record so the same false alarm is not re-raised later. -->

| ID | Claim | Cross-critique verdicts | Ruling and evidence |
|----|-------|-------------------------|---------------------|

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
