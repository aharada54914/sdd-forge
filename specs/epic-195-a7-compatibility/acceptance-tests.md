# Acceptance Tests: epic-195-a7-compatibility

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-006 | TEST-001 | static / doc-review | golden-baseline capture/promote script contract: two named commands (`capture-golden-baseline.sh`, `promote-golden-baseline.sh`), candidate/canonical separation, fully scripted | Planned |
| AC-002 | REQ-001 | TEST-002 | integration, negative self-check | byte-identical suite vs. a deliberately mutated fixture | Planned |
| AC-003 | REQ-001 | TEST-003 | integration | representative script per REQ-001's canonical target inventory (AC-038, including directory listing + plugin manifest) and the 6-cell CLI submatrix, two invocations, fixed env | Planned |
| AC-004 | REQ-001, REQ-007 | TEST-004 | integration (named SKIP, allowlist-governed, until Epic A5 merges) | Context-absent: no capability subprocess invoked — adopts Epic A5's `design.md` item 10(b) fixture directly | Planned |
| AC-005 | REQ-002 | TEST-005 | integration | Context-absent generation: exact track-appropriate file set — legacy-seven-layer (`full`/F1) or the `requirements.md`/`design.md`/`tasks.md` lite-spec set (`lite`/F2, INV-024) — no capability/Facet files | Planned |
| AC-006 | REQ-002 | TEST-006 | static / regex | `REQ-NNN`/`AC-NNN` identifier format unchanged | Planned |
| AC-007 | REQ-002, REQ-007 | TEST-007 | integration (named SKIP, allowlist-governed, until Epic A4 merges) | Context-present-required, full-track only (F4 — never F6, see AC-043): no Facet reference leaks into legacy-shaped output | Planned |
| AC-008 | REQ-003 | TEST-008 | static / registration-forcing | `tests/loops/loop-inventory.json` entry count stays 8 | Planned |
| AC-009 | REQ-003 | TEST-009 | static / schema | `quality-gate` entry carries additive `capability_applicability`; `assert_terminal`/`assert_artifacts_schema` remain unmodified; the new `assert_capability_applicability` helper reads it | Planned |
| AC-010 | REQ-003 | TEST-010 | integration | `TEST-019` in `tests/loop-escalation.tests.sh`: quality-gate-outcome event kind, via `assert_event_trace`, vs. golden trace | Planned |
| AC-011 | REQ-003 | TEST-011 | regression, byte-identical | `emit-run-record.sh` no-flag output unchanged | Planned |
| AC-012 | REQ-003 | TEST-012 | integration | `emit-run-record.sh` both-flags combination emits the additive `capability` object alongside `effort` | Planned |
| AC-013 | REQ-004 | TEST-013 | traceability review | decision doc §4 requirement decomposed into ≥3 traced, mutually exclusive clauses (AC-029's own boundary) | Planned |
| AC-014 | REQ-005 | TEST-014 | integration | fixture-matrix builder constructs F1–F4, the F3/F4-invalid variants, and the 6-cell Context-absent CLI submatrix | Planned |
| AC-015 | REQ-005 | TEST-015 | static / registration-forcing | every new/extended suite has a `.sh`/`.ps1` pair registered in `run-all.{sh,ps1}` and `test.yml` | Planned |
| AC-016 | REQ-007 | TEST-016 | static | every upstream-dependent assertion's `SKIP` line is read from the REQ-007 allowlist manifest (AC-034) | Planned |
| AC-017 | REQ-004 (process) | TEST-017 | doc-review | every factual claim in this package cites file:line evidence (WFI-011) | Planned |
| AC-018 | REQ-006 | TEST-018 | static / doc-review | baseline manifest records the pre-capability merge-base SHA, fixed env, script sha256; an update requires a candidate→canonical PR | Planned |
| AC-019 | REQ-005, REQ-007 | TEST-019 | integration (named SKIP until Epic A1 merges) | F3-invalid/F4-invalid: a distinct `PROJECT_CONTEXT_INVALID` stop event is recorded | Planned |
| AC-020 | REQ-005, REQ-007 | TEST-020 | integration (named SKIP until Epic A1 merges) | F3-invalid/F4-invalid: the event trace never reaches the compatibility-fallback path | Planned |
| AC-021 | REQ-005, REQ-007 | TEST-021 | integration (named SKIP until Epic A1 and Epic A5 merge) | F3-invalid/F4-invalid: Resolver subprocess never invoked — adopts A5's own spy fixture for the invalid variant | Planned |
| AC-022 | REQ-003 | TEST-022 | integration | `TEST-018` in `tests/loop-consistency.tests.sh`: skill-invocation-order event kind vs. golden trace | Planned |
| AC-023 | REQ-003 | TEST-023 | integration | same `TEST-018` case: review-loop-presence event kind vs. golden trace | Planned |
| AC-024 | REQ-003 | TEST-024 | integration | same `TEST-018` case: approval-checkpoint event kind vs. golden trace | Planned |
| AC-025 | REQ-003 | TEST-025 | integration | `TEST-019`'s own quality-gate-outcome event kind: producer/ordering/value-normalization fixed and asserted | Planned |
| AC-026 | REQ-003 | TEST-026 | integration | Done-transition event kind asserted as the last event within both `TEST-018` and `TEST-019` | Planned |
| AC-027 | REQ-003 | TEST-027 | integration | skip-stop-message event kind asserted against the allowlist manifest's own fixed template string | Planned |
| AC-028 | REQ-005 | TEST-028 | static / doc-review | Compatibility Matrix (F1–F8 × REQ-001/002/003, plus the CLI submatrix): every AC cited in a cell carries its own single disposition — ASSERT / SKIP-with-activation / N-A | Planned |
| AC-029 | REQ-004 | TEST-029 | static / doc-review | observable×fixture-state judgment table is exhaustive and mutually exclusive (byte vs. event vs. structural) | Planned |
| AC-030 | REQ-002 | TEST-030 | integration | deterministic recorded-response injection seam + Markdown/frontmatter AST canonicalizer | Planned |
| AC-031 | REQ-002 | TEST-031 | integration, non-gating | live-model structural-comparison refresh test, registered outside the gating suite/CI job | Planned |
| AC-032 | REQ-003 | TEST-032 | integration | `TEST-018` in `tests/loop-consistency.tests.sh` exists, calls `assert_event_trace`, and asserts a Context-absent round's own event trace | Planned |
| AC-033 | REQ-003 | TEST-033 | integration + golden negative test | `emit-run-record.sh`'s four flag-combination outcomes; capability-only usage-error golden negative test | Planned |
| AC-034 | REQ-007 | TEST-034 | static / doc-review | REQ-007 allowlist manifest: assertion→`dependencies[]` (epic/issue/`fingerprints[]` sha256-digest array)→`merged`/`fingerprint_match` activation-condition grammar, enumerating A1–A6 | Planned |
| AC-035 | REQ-007 | TEST-035 | integration, negative self-check ×3 | dependency-present SKIP / unknown SKIP / fingerprint drift each independently hard-fail the suite | Planned |
| AC-036 | REQ-003 | TEST-036 | integration (named SKIP until Epic A5 merges) | anchor-fingerprint drift check against the live `sdd-bootstrap-interviewer/SKILL.md`, owned by this epic's existing suite (OQ-001) | Planned |
| AC-037 | REQ-003 | TEST-037 | integration (named SKIP until Epic A5 merges) | a REQ-002 Block surfaces as a visible stop/error event, never a silent fallback (OQ-001) | Planned |
| AC-038 | REQ-001 | TEST-038 | static / doc-review | REQ-001 canonical target inventory: each target 1:1 with a capture format and an AC/TEST, including directory listing + plugin manifest | Planned |
| AC-039 | REQ-003 | TEST-039 | static / doc-review | INV-014's pattern is scoped to `check-component-coverage`; a per-component disabled-legacy expectation table (Resolver = event absent, coverage Gate = N/A evidence present) | Planned |
| AC-040 | REQ-006 | TEST-040 | static / doc-review | CI-workflow-scan check: `.github/workflows/test.yml` never references `promote-golden-baseline.sh` or `--write-candidate` | Planned |
| AC-041 | REQ-006 | TEST-041 | integration, negative self-check ×2 | `promote-golden-baseline.sh` runtime refusal exercised directly: `CI` env var set to a non-empty value → non-zero exit, no file read/write; `--approved-by` omitted or empty → non-zero exit, no canonical write | Planned |
| AC-042 | REQ-002, REQ-007 | TEST-042 | integration (named SKIP, allowlist-governed, until Epic A1 merges) | Context-present-advisory (F3): generated artifacts remain structurally identical to the full-track legacy-seven-layer file set (AC-005 full-track clause) — closes the F3/REQ-002 structural-assertion gap design.md's Compatibility Matrix and Observable×fixture-state table already name | Planned |
| AC-043 | REQ-002, REQ-007 | TEST-043 | integration (named SKIP, allowlist-governed, until Epic A1 and Epic A6 both merge) | Context-present, lite-track (F5 advisory / F6 required): generated artifacts remain structurally identical to the lite-track three-file set (AC-005 lite-track clause) — closes the F5/F6×REQ-002 structural-assertion gap design.md's Compatibility Matrix already names via its "A1+A6 compound entry" citation | Planned |

This is internal test-infrastructure specification work with no
user-facing entry point; the UI Integration Checklist is not applicable.

Every `Planned` status above is a Phase 1 (specification-only) placeholder:
no test code exists yet. Test IDs and targets are fixed here so the Phase
2/3 implementation task has no remaining test-identity ambiguity to
resolve, matching this repository's own precedent for fixing a deferred
suite's contract at design time (investigation.md INV-016, citing Epic
A5's `resolve-project-context-caller-contract`). The `Test ID` column
above (`TEST-001`–`TEST-043`) is this package's own Phase 1 AC-to-test
placeholder index — one entry per AC, in AC order — and is a distinct
namespace from the *real*, per-suite-file case numbers Phase 2/3 actually
implements (e.g. `TEST-018` in `tests/loop-consistency.tests.sh` and
`TEST-019` in `tests/loop-escalation.tests.sh`, design.md Design
Decisions): wherever a row's own real suite case number differs from its
package placeholder ID, the `Test Target` column names that real case
number explicitly (e.g. AC-010's/AC-022–027's/AC-032's rows above), so no
row is ever ambiguous about which of the two identifiers it means.
