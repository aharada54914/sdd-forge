# Acceptance Tests: epic-194-a6-lite-integration

TEST IDs are namespaced to this feature
(`specs/epic-194-a6-lite-integration/`) and map 1:1 to `requirements.md`'s
Acceptance Criteria by matching row number (AC-NNN ↔ TEST-NNN), with one
documented class of exception:

- **AC-023, AC-024, and AC-025 have no TEST-023/024/025 rows.** All three
  are spec-commit-bound scope-boundary statements about *this Phase 1
  package's own registration commit*, not automated implementation-phase
  tests a future `tests/*.tests.sh` suite would run — they are checked
  directly against the live repository at registration time, mirroring
  `specs/epic-193-a5-capability-resolver/acceptance-tests.md`'s identical
  AC-035/036/037 exception and `specs/epic-192-a4-facet-manifest/
  acceptance-tests.md`'s AC-036/037/038 exception before it. See
  "Spec-Authoring-Time Manual Review Record", below.

Every other row named below is a **design-phase target**: no suite file
exists yet (`design.md`'s own Test Strategy names ten suites this
feature's future `tasks.md` schedules authoring; `Spec-Review-Status`/
`Impl-Review-Status` must both reach `Passed` first, per `AGENTS.md`'s
Required Workflow). `Status` below is `Planned` for every row.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | schema-shape lock | `tests/lite-policy-schema.tests.sh`/`.ps1` (design.md Test Strategy item 2's own fixture family): a `lite_policy` fixture with all three keys (`eligible`, `upgrade_reasons`, `required_lite_checks`) validates against the designed v1.1 fragment; a fixture with a fourth, unrecognized key is rejected (`additionalProperties: false`) | Planned |
| AC-002 | REQ-001 | TEST-002 | v1-compatibility lock | design.md Test Strategy item 2 (`lite-policy-v1-compat`): a `lite_policy: {eligible: true, upgrade_reasons: []}` fixture with no `required_lite_checks` key validates under the v1.1 schema design; a downstream-consumption fixture (REQ-003's own reader) confirms this Capability's own contribution to any aggregate is `[]`, never a validation error | Planned |
| AC-003 | REQ-001 | TEST-003 | catalog-shape and fail-closed lock | design.md Test Strategy item 1 (`lite-check-catalog-conformance`): `contracts/lite-check-catalog.json`'s designed shape validates with `checks: ["installer-dry-run"]`; a `required_lite_checks: ["unknown-check"]` fixture fails the new validator check with `unknown-lite-check: <capability-id>: unknown-check`, never a schema-level rejection | Planned |
| AC-004 | REQ-001 | TEST-004 | catalog-growth non-destructive lock | design.md Test Strategy item 3 (`lite-upgrade-reason-catalog-v2`): every one of the twelve `catalog_version`-2 tokens validates; a fixture using only a pre-v2 token (e.g. `pii`) still validates unchanged, confirming no existing token was removed or renamed | Planned |
| AC-005 | REQ-001 | TEST-005 | check-(j)-independent-of-check-(h) lock | same suite as TEST-003: a fixture with a fully valid `upgrade_reasons` array but an unrecognized `required_lite_checks` token fails **only** check (j), not check (h) — and the symmetric fixture (valid `required_lite_checks`, unrecognized `upgrade_reasons` token) fails only check (h) — proving the two checks are independently triggerable | Planned |
| AC-006 | REQ-001 | TEST-006 | schema-const stability lock | repository-wide grep-based self-check (registration-time and CI-gated, reusing this feature's own investigation.md citation as the baseline): no `contracts/*.schema.json` anywhere in the repository carries a decimal `schema` const string; the designed v1.1 fragment's own Registry-instance discriminator stays `"capability-registry/v1"`, unchanged | Planned |
| AC-007 | REQ-002 | TEST-007 | byte-identical no-second-argument lock | design.md Test Strategy item 4 (`check-risk-upgrade-byte-identical`): the six-row keyword scan's own existing live fixture set (positive and negative), invoked with no second argument against the designed extension, produces output byte-identical to today's live `check-risk-upgrade.{sh,ps1}` | Planned |
| AC-008 | REQ-002 | TEST-008 | merge-ordering lock | design.md Test Strategy item 5 (`check-risk-upgrade-capability-merge`): a fixture with both a keyword match and a `--capability-reasons` fragment places the keyword-derived trigger(s) first, Capability-derived trigger(s) appended in supplied order, in the `triggers=` output; exit code `10` | Planned |
| AC-009 | REQ-002 | TEST-009 | no-logic-duplication lock | design.md's own API / Contract Plan (REQ-002): a static-review fixture over the designed extension's own algorithm confirms the six-row keyword table gains no new row and the extension's own step 2 never re-evaluates a Predicate DSL expression or re-reads a Registry/Project-Context path — a fixture asserts the extension's own code path calls no function this feature did not itself name for the merge step | Planned |
| AC-010 | REQ-002 | TEST-010 | human-copy staging lock | future implementation-phase check: `specs/epic-194-a6-lite-integration/human-copy/` mirrors the live repository tree for exactly `risk-upgrade-policy.md`, `check-risk-upgrade.sh`, `check-risk-upgrade.ps1`, and `lite-spec/SKILL.md`, each with a correct `MANIFEST.sha256` entry; no other path is staged under this directory | Planned (Status resolves through a human `cp` action) |
| AC-011 | REQ-003 | TEST-011 | absent-Summary lock | design.md Test Strategy item 8 (`lite-gate-summary-absent`): no `capability-summary.yaml` at all → `lite-gate`'s designed extension runs exactly its five baseline checks, output identical to today's live `lite-gate` behavior; zero-matched-Capability and pre-Epic-A5-implementation are both fixture variants of this same row | Planned |
| AC-012 | REQ-003 | TEST-012 | schema-validation-before-trust lock | design.md Test Strategy item 9 (`lite-gate-summary-invalid`): a `capability-summary.yaml` fixture that fails A4's own schema causes the designed extension's own `VERDICT: FAIL`, `Status` unchanged, reason naming the validation failure — never a silent trust of malformed content | Planned |
| AC-013 | REQ-003 | TEST-013 | no-re-aggregation lock | static-review fixture over design.md's own API / Contract Plan (REQ-003/REQ-004 step "c"): confirms the designed extension reads `required_lite_checks` as a single already-aggregated field, with no per-Capability loop or union computation of its own anywhere in `lite-gate`'s designed Process | Planned |
| AC-014 | REQ-004 | TEST-014 | Step-2b insertion-point lock | design.md's own Architecture diagram: a fixture confirms the designed Step 2b sits between the existing Step 2 and Step 3, and that the existing "順序が重要" ordering note (Done-transition-before-final-verification) is textually preserved, unchanged, in the designed extension | Planned |
| AC-015 | REQ-004 | TEST-015 | baseline-duplicate no-op lock | design.md Test Strategy item 7 (`lite-gate-summary-consumption`): a `required_lite_checks` entry equal to `build` (an existing baseline check) is not re-executed and produces no second report line in the designed quality-report shape | Planned |
| AC-016 | REQ-004 | TEST-016 | unmapped-check N/A lock | same suite as TEST-015: a `required_lite_checks` entry with no local command mapping (e.g. `installer-dry-run` in a fixture repository with no such command configured) is recorded `N/A` with a stated reason, never a FAIL and never silently dropped from the quality report | Planned |
| AC-017 | REQ-004 | TEST-017 | direct-edit protection-status lock | design.md's own Protected-File Statement: a fixture re-runs `grep -n "sdd-lite" plugins/sdd-quality-loop/references/guard-invariants.json` immediately before the designed `lite-gate/SKILL.md` edit is applied (future implementation phase) and confirms `lite-gate/SKILL.md` is still absent from both arrays before proceeding with a direct edit — if present, the implementation task halts and re-routes through human-copy instead (OQ-001 contingency, restated as a testable gate) | Planned |
| AC-018 | REQ-004 | TEST-018 | no-heavy-machinery lock | static-review fixture over the designed Step 2b: confirms it invokes no evidence-bundle generator, no cross-model-verification call, no second-approval check, and no risk-hierarchy classification — only bounded execution of a Registry-named, `capability-summary.yaml`-capped check list | Planned |
| AC-019 | REQ-005 | TEST-019 | Block-contract shape lock | design.md Test Strategy item 6 (`lite-spec-capability-block`): a fixture whose Capability-derived signal names an ineligible Capability Blocks before any `specs/<feature>/` file exists, with the identical exit code (`10`), message shape (`full-required: ...`), and non-overridability (`--lite` never overrides) as an existing keyword-match fixture | Planned |
| AC-020 | REQ-005 | TEST-020 | OQ-002 non-selection lock | design-content review (no automated test, Spec-Authoring-Time Manual Review Record, below): confirms `design.md`'s Design Decisions section states both OQ-002 candidates without selecting one, and that neither the Architecture diagram nor the API / Contract Plan hard-codes a specific mechanism at the Step-2/signal-acquisition point | Planned |
| AC-021 | REQ-005 | TEST-021 | single-file, human-copy-only lock | future implementation-phase check: the designed REQ-005 edit touches only `lite-spec/SKILL.md`, staged under the same `specs/epic-194-a6-lite-integration/human-copy/` directory TEST-010 verifies, with no separate, REQ-005-specific application path introduced | Planned |
| AC-022 | REQ-006 | TEST-022 | fixture-to-AC coverage lock | design-content review (no automated test, Spec-Authoring-Time Manual Review Record, below): confirms `design.md`'s Test Strategy items 1-10 collectively exercise every one of AC-002, AC-007, AC-008, AC-011, AC-015, and AC-016, with no listed fixture that exercises no AC | Planned |

## Spec-Authoring-Time Manual Review Record

AC-020 and AC-022 are design-content review items, not automated tests:
both are facts about this specific package's own `design.md` text, not
reusable, fixture-driven regression tests a future code change could
break — the same reasoning `specs/epic-193-a5-capability-resolver/
acceptance-tests.md` already records for its own AC-029 through AC-032
design-content-review class. Verified by direct inspection, recorded here
once, at this package's own spec-authoring time:

- **AC-020**: `design.md`'s "Design Decisions (resolving open questions)"
  section, subsection "OQ-002 candidates, presented without selection,"
  states candidate (a) (Project-Context-wide, diff-independent evaluation)
  and candidate (b) (defer to the existing `ship`-time recheck only),
  each with its own named advantage and cost, and explicitly states
  "Neither candidate is chosen here." The Architecture diagram's own
  pre-generation-gate block is labeled "OQ-002 candidate a or b, NOT
  selected by this design," and the API / Contract Plan's REQ-005
  algorithm names the signal-acquisition step "[NEW, position/mechanism
  per OQ-002 ruling]" rather than a concrete call. Confirmed present.
- **AC-022**: `design.md`'s Test Strategy section lists ten numbered
  items; cross-referencing each item's own requirements.md AC citation
  against requirements.md's own Acceptance Criteria table confirms AC-002
  (item 2), AC-007 (item 4), AC-008 (item 5), AC-011 (item 8), AC-015
  (item 7), and AC-016 (item 7) are each named by at least one Test
  Strategy item, and that every one of the ten items names at least one
  requirements.md AC or Global concern (item 10, AC-025). Confirmed
  present.

AC-023, AC-024, and AC-025 (Global, requirements.md) are verified directly
against the live repository as part of this Phase 1 package's own
registration commit, not by an automated test suite:

- **AC-023** (registration commit touches only `specs/epic-194-a6-lite-
  integration/**` plus the two registration files): verified by `git
  status`/`git diff --stat` at commit time, across both this package's own
  commits (the spec-package commit and the registration commit).
- **AC-024** (`Spec-Review-Status: Pending` / `Impl-Review-Status:
  Pending`, no `Approved`/`Passed` written anywhere): verified by direct
  inspection of `requirements.md`'s and `design.md`'s own header lines at
  commit time.
- **AC-025** (`check-sdd-structure.sh .` and `check-workflow-state.sh`
  both exit `0` post-registration): verified by running both commands
  from the repository root after the registration commit lands — no
  feature argument to `check-sdd-structure.sh` (matching the documented
  usage this feature's own investigation.md INV-011 already ran as its
  pre-registration baseline, both green).

None of the five requires a `tests/*.tests.sh` suite of its own: all five
are one-shot facts about this specific package's own text and commit
scope, not reusable, fixture-driven regression tests a future code change
could break — the same reasoning `specs/epic-193-a5-capability-resolver/
acceptance-tests.md`'s AC-029/030/031/032/035/036/037 and `specs/epic-192-
a4-facet-manifest/acceptance-tests.md`'s AC-036/037/038 each already
record for their own, structurally identical exceptions.

- **`lite-check-catalog.json` draft-07 metaschema conformance** (`design.
  md`'s own Data Plan schema fragment): a future implementation-phase
  check validates the authored `contracts/lite-check-catalog.schema.json`
  against the JSON Schema draft-07 metaschema itself, matching every
  sibling epic's own identical check for its own new `contracts/*.
  schema.json` file.
