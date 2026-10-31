# Implementation Policy Review Report: sdd-domain-concept-contract — Round 1 / Attempt 2

## Verdict: BLOCKED

| Field | Value |
|---|---|
| Feature | sdd-domain-concept-contract |
| Round | 1 of 3 |
| Attempt | 2 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | BLOCKED |
| Critical Findings | 1 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-08-17T06:35:20Z |

Attempt 2 is a **post-implementation provenance re-review**, run with
`impl-review-precheck.sh sdd-domain-concept-contract 2 1 --provenance-rereview`.
Its purpose was to re-bind impl-stage evidence with a complete reviewer input
manifest — specifically to add `investigation.md`, which attempt 1's contract
omitted and which `task-review-precheck.sh:212-214` requires. Both reviewer
manifests in this attempt do include it.

`design.md` content is byte-identical to attempt 1 apart from the
`Impl-Review-Status:` header line, which the `--reset` attempt toggled
`Passed → Pending → Passed` (SHA-256 `28bb9247…` → `28bd5415…`).

## Reviewer-A Findings (Structural Soundness)

No FAIL findings. All 11 checks PASS or SKIP.

`legacy_design: true` in precheck-result.json converted two absent template
fields into `[LEGACY COMPAT]` Minor advisories rather than findings:

- **DATA-COVERAGE** — `## Data Plan` absent. Substantive content exists in
  `## v2 Schema Shape` and requirements.md `## Field Definitions`, but not
  under the required headings.
- **API-COVERAGE** — `## API / Contract Plan` absent. The feature has no HTTP
  or RPC surface; the CLI validator entry points are documented in
  `## Architecture` and frontend-spec.md `## Technology Stack`.
- **SECURITY-COVERAGE** — `## Security Boundaries` absent from design.md;
  TYPE-H fallback found no PII keywords in requirements.md `## User Stories`,
  so this is a non-blocking advisory.

`FRONTEND-BACKEND-CONSISTENCY` SKIP (no frontend surface exists).
`DESIGN-SYSTEM-CONFORMANCE` and `DOMAIN-CONFORMANCE` PASS-as-skipped (no
`design-system/` or `domain/` directory in this repository).

## Reviewer-B Findings (Implementability/Risk)

Three FAIL findings. Each was independently re-verified against the repository
by the orchestrator before being recorded; all three are confirmed facts about
design.md, not reviewer error.

### 1. NO-REQ-CONTRADICTION — Critical (TYPE-D)

design.md has a `## Constraint Compliance` section (design.md:138-146), so the
Primary/TYPE-D branch applies: every constraint in requirements.md must be
addressed there.

requirements.md `## Security Boundaries` carries three bullets. Two are covered
by the table (`content-as-data`, `外部依存禁止`). The third —
**「fixture に秘密情報・実在の個人情報を含めない」** — appears nowhere in
design.md.

Orchestrator verification:

```
$ grep -n -E '秘密情報|個人情報|PII|credential|secret' specs/sdd-domain-concept-contract/design.md
(該当なし)
```

This is not merely a missing table row. design.md `## Test Strategy` is the
section that specifies the 73-fixture negative corpus and the 5 positive
fixture families, and it gives no design-level directive against putting
secrets or real personal data into those hand-authored fixtures. The
constraint is stated in requirements.md and in traceability.md's Security
layer row, but the design that will be implemented against does not carry it.

### 2. OPEN-QUESTIONS-RESOLVABLE — Major (TYPE-H)

design.md uses `## Open Items` (design.md:148-154) rather than the template's
`## Open Questions`, and its entries carry none of the three required fields
(`Owner:`, `Blocks Implementation: yes|no`, `Resolution Path:`). OQ-001 (v1
ファイルの最終処遇) defers to "Phase 3" in prose with no named owner.

Orchestrator verification — this is the only such design.md in the repository:

```
$ grep -l '^## Open Questions' specs/*/design.md | wc -l   → 28
$ grep -l '^## Open Items'     specs/*/design.md | wc -l   → 1
$ ls specs/*/design.md | wc -l                             → 38
```

Correction to the reviewer's own text: it states "37 use it directly". The
actual count is 28; the remaining 9 use neither heading. The substantive claim
— that this feature's design.md is the sole `## Open Items` user, and that the
required fields are absent — is confirmed.

### 3. DEPLOYMENT-CONCRETE — Major (TYPE-H)

design.md has no `## Deployment / CI Plan` section. Substantively equivalent
content exists in infra-spec.md (`## CI / Release Impact`, `## Rollback`), but
the check requires it inside design.md.

Orchestrator verification:

```
$ grep -n '^## ' specs/sdd-domain-concept-contract/design.md
7:## Technical Summary      20:## Design Decisions    32:## v2 Schema Shape
80:## Architecture          98:## Error Handling     115:## Test Strategy
138:## Constraint Compliance 148:## Open Items
$ grep -l '^## Deployment' specs/*/design.md | wc -l   → 32
```

## Proposed Changes

Findings are facts and are not waived. The three changes that would resolve
them are stated below. **They are not applied**, because design.md is a frozen
artifact under a provenance re-review, and the re-review's own boundary rule
is that it "re-binds review evidence to the current artifact hashes; it does
not license content changes to frozen artifacts". Whether to unfreeze is a
human decision.

1. **Add a `## Constraint Compliance` row for the fixture secrets/PII
   constraint** (resolves the Critical). Mirror requirements.md
   `## Security Boundaries` bullet 3, and state where it is enforced — the
   natural place is `## Test Strategy`, since fixtures are authored there.
   Reference REQ-005, which owns the fixture corpus.

2. **Rename `## Open Items` to `## Open Questions` and add the three required
   fields to OQ-001** (`Owner:`, `Blocks Implementation: no`,
   `Resolution Path:` — the concrete action being the Phase 3 decision on the
   v1 schema file's disposition). OQ-003 is already resolved and can be marked
   as such or dropped.

3. **Add a `## Deployment / CI Plan` section to design.md** carrying (or
   explicitly cross-referencing) infra-spec.md's existing content: deployment
   target, no feature-flag strategy needed, no CI pipeline change (INV-007 /
   OQ-002), and "no schema migration" for the migration-order field.

## Next Steps

Two decisions are the human's:

**A. What to do about the three findings.** They are real defects in design.md
measured against the current reviewer contract. Applying the three changes
above requires unfreezing design.md, which changes its SHA-256 and therefore
invalidates attempt 1's binding — acceptable inside a re-review, but it is a
content change to a frozen artifact and needs explicit authorization. After
editing, re-invoke:

```bash
/sdd-review-loop:impl-review-loop --feature sdd-domain-concept-contract --edit-summary "..."
```

**B. Whether the framework asymmetry that produced part of this is a defect
worth fixing first.** Three observations, recorded here as evidence rather
than as an argument for waiving anything:

- `legacy_design: true` is honoured by impl-reviewer-a, whose role file has a
  "Legacy Design Mode" section converting absent-template-field findings into
  Minor advisories. impl-reviewer-b's role file has no such section.
  DEPLOYMENT-CONCRETE is exactly an absent-template-field finding of the class
  reviewer A downgraded.
- attempt 1's reviewer B returned PASS on design.md content byte-identical to
  this one. attempt 2's reviewer B returns BLOCKED. Two of the three findings
  are TYPE-H, where fresh-instance calibration variance is expected;
  `task-review-loop`'s SKILL.md carries an explicit "TYPE-H convergence rule"
  for exactly this situation in provenance re-reviews.
  `impl-review-loop`'s SKILL.md carries no equivalent, so the rule is not in
  force here and was not applied.
- The Critical finding is **TYPE-D**, and the task-stage convergence rule
  explicitly leaves TYPE-D unaffected. So finding 1 would stand even if that
  rule were adopted for the impl stage. It is a genuine gap in design.md.

Both observations are recorded in `docs/workflow-improvements/WFI-029.md`.

**Consequence for the downstream gate.** This attempt did add
`investigation.md` to both reviewer manifests, which was its purpose — but the
persisted contract now records `verdict: BLOCKED`, so it does not satisfy
`task-review-precheck.sh`'s predecessor-PASS requirement either. The task-review
gate remains blocked, now on verdict rather than on manifest completeness.
`design.md` retains `Impl-Review-Status: Passed` from attempt 1; the
orchestrator did not and may not change it.
