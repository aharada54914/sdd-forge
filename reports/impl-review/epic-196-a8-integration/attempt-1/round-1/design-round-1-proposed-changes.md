# Implementation Policy Review Report: epic-196-a8-integration — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-196-a8-integration |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 3 |
| Minor Findings | 0 |
| Generated | 2026-07-23T09:45:00Z |

## Reviewer-A Findings (Structural Soundness)

- **DATA-COVERAGE (FAIL, Major)**: design.md's `## Data Plan` section
  (lines 183-874) is extensive (five fully-typed JSON schemas) but never
  uses the required labeled sub-fields `Data Entities:`,
  `Existing Data Affected:`, or `Migration Strategy:` anywhere in the
  document (zero grep matches for any of the three labels, and zero
  matches for an explicit "No data changes" statement). A downstream
  implementer must reconstruct what is new versus existing data from
  scattered prose rather than a single normative sub-field, and no
  migration/backfill strategy is stated anywhere for the new schema/
  ledger/registry files this package introduces.
- **ADR-PRESENT (FAIL, Major)**: design.md's `## ADR Change Log`
  (lines 177-181) states "None" and cites only ADR-0019 (an existing,
  unrelated defense-claim ADR) as a read-only source, but design.md
  itself introduces a new, repository-first Ed25519 digital-signature
  scheme with a maintainer-committed trusted-signer-key registry and a
  signed nonce-issuance ledger (Data Plan "Signing Contract," lines
  572-604) — no prior use of Ed25519/public-key signing exists anywhere
  else in this repository. ADR-0008 already treats a comparably-scoped
  decision (who may perform cryptographic signature verification, and
  where) as ADR-level material, requiring "this ADR's supersession and a
  new security review" for any component newly performing signature
  verification. design.md introduces this new signing/key-trust mechanism
  without listing or proposing a new ADR for it.

All other reviewer-A checks (ARCH-COVERAGE, NO-CIRCULAR-DEPS,
API-COVERAGE, SECURITY-COVERAGE, TEST-STRATEGY-COVERAGE,
NO-UNDEFINED-COMPONENT) are PASS; FRONTEND-BACKEND-CONSISTENCY,
DESIGN-SYSTEM-CONFORMANCE, and DOMAIN-CONFORMANCE are SKIP (no UI surface,
no `design-system/` directory, no `domain/` directory — see reviewer-a.json
for full rationale on each).

## Reviewer-B Findings (Implementability/Risk)

- **NO-REQ-CONTRADICTION (FAIL, Major)**: design.md has a
  `## Constraint Compliance` section (lines 1393-1401), so the Primary/
  TYPE-D check path applies. Its sole content is a CI-resilience
  convention carried verbatim from Epic A7's own precedent — it never
  mentions requirements.md's own Security Boundaries table (lines
  710-713), which names two concrete constraints: B1 (a genuine,
  real installed-toolchain session is required; synthetic/fixture-only
  results are never accepted) and B2 (the drift check must stay
  read-only, never remediate). Both ARE addressed with concrete
  mechanisms elsewhere in the same design.md, under the
  differently-named `## Security Boundaries` section (lines 1342-1358)
  and reinforced in `## API / Contract Plan` and `## Global Constraints`
  — so the constraint is not absent from the design as a whole (the
  Critical bar), only absent from the one section this check inspects. A
  reader auditing only `## Constraint Compliance` for security-constraint
  coverage, as the check instructs, would incorrectly conclude none
  exists. Reviewer-B's own recommendation: the Constraint Compliance
  section should explicitly cross-reference or restate B1/B2 compliance.

All other reviewer-B checks (DECISION-JUSTIFIED, OPEN-QUESTIONS-RESOLVABLE,
ASSUMPTIONS-VALID, PERF-ADDRESSED, DEPLOYMENT-CONCRETE, MIGRATION-PLANNED,
INTEGRATION-IDENTIFIED, DESIGN-WITHIN-SCOPE, VERIFICATION-PATH-CONCRETE)
are PASS; DOMAIN-CONFORMANCE is SKIP (no `domain/` directory — see
reviewer-b.json for rationale).

## Proposed Changes

1. **`## Data Plan` (DATA-COVERAGE)**: add the three required labeled
   sub-fields. `Data Entities:` and `Existing Data Affected:` will name
   the new file-based JSON record schemas (already enumerated in the
   section) versus the existing files this package reads/observes
   (installed hook-config files, `~/.codex/config.toml`'s MCP block, the
   nonce ledger's `consumed_by_record` field). `Migration Strategy:` will
   state "No migration required" with rationale — every new schema this
   design proposes is a net-new file with no prior version to migrate
   from, matching the pattern reviewer-B's own MIGRATION-PLANNED check
   already independently confirmed is functionally "no data changes" for
   database-migration purposes.
2. **New ADR for the Ed25519 signing/trusted-key mechanism
   (ADR-PRESENT)**: draft and register a new ADR under `docs/adr/`
   documenting the decision to introduce Ed25519 signing, the
   trusted-signer-key registry, and the signed nonce ledger as this
   epic's own live-host-proof integrity mechanism, referencing ADR-0008's
   precedent for signature-verification-scoped decisions. design.md's
   `## ADR Change Log` will then cite the new ADR instead of "None."
   Whether this can be applied directly or requires a human-apply path
   depends on whether `docs/adr/` is a protected path in this session —
   checked separately from this report.
3. **`## Constraint Compliance` (NO-REQ-CONTRADICTION)**: add an explicit
   cross-reference/restatement of B1/B2 (requirements.md's Security
   Boundaries table) to the section, pointing to `## Security Boundaries`
   (lines 1342-1358) where both are already concretely addressed. This is
   the lower-effort remedy reviewer-B itself recommended over duplicating
   the full mechanism description.

## Next Steps

Per this task's orchestrator assignment ("findings が出たら spec を修正して再
attempt"), matching the established precedent for this pipeline
(`epic-195-a7-compatibility` round 1), the orchestrator applies remedies
1 and 3 directly to design.md (mechanical, review-finding-driven edits
that introduce no new judgment beyond what the findings themselves
specify), determines the correct path for remedy 2 (direct application or
human-apply, per the `docs/adr/` protected-path check), records an
`--edit-summary`, and re-invokes the loop at round 2 (same attempt 1)
rather than waiting on separate human action. No finding is waived; each
remedy directly closes the cited gap.
