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
exists yet (`design.md`'s own Test Strategy names seventeen suites this
feature's future `tasks.md` schedules authoring; `Spec-Review-Status`/
`Impl-Review-Status` must both reach `Passed` first, per `AGENTS.md`'s
Required Workflow). `Status` below is `Planned` for every row.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | schema-shape lock | `tests/lite-policy-schema.tests.sh`/`.ps1` (design.md Test Strategy item 2's own fixture family): a `lite_policy` fixture with all three keys (`eligible`, `upgrade_reasons`, `required_lite_checks`) validates against the designed v1.1 fragment; a fixture with a fourth, unrecognized key is rejected (`additionalProperties: false`) | Planned |
| AC-002 | REQ-001 | TEST-002 | v1-compatibility lock | design.md Test Strategy item 2 (`lite-policy-v1-compat`): a `lite_policy: {eligible: true, upgrade_reasons: []}` fixture with no `required_lite_checks` key validates under the v1.1 schema design; a downstream-consumption fixture (REQ-003's own reader) confirms this Capability's own contribution to any aggregate is `[]`, never a validation error | Planned |
| AC-003 | REQ-001 | TEST-003 | catalog-shape and fail-closed lock | design.md Test Strategy item 1 (`lite-check-catalog-conformance`): `contracts/lite-check-catalog.json`'s designed shape validates with `checks: ["build", "test", "installer-dry-run"]` (revised, Blocker [M1]); a `required_lite_checks: ["unknown-check"]` fixture fails the new validator check with `unknown-lite-check: <capability-id>: unknown-check`, never a schema-level rejection | Planned |
| AC-004 | REQ-001 | TEST-004 | catalog-growth non-destructive lock | design.md Test Strategy item 3 (`lite-upgrade-reason-catalog-v2`): every one of the twelve `catalog_version`-2 tokens validates; a fixture using only a pre-v2 token (e.g. `pii`) still validates unchanged, confirming no existing token was removed or renamed | Planned |
| AC-005 | REQ-001 | TEST-005 | check-(j)-independent-of-check-(h) lock | same suite as TEST-003: a fixture with a fully valid `upgrade_reasons` array but an unrecognized `required_lite_checks` token fails **only** check (j), not check (h) — and the symmetric fixture (valid `required_lite_checks`, unrecognized `upgrade_reasons` token) fails only check (h) — proving the two checks are independently triggerable | Planned |
| AC-006 | REQ-001 | TEST-006 | schema-const stability lock | repository-wide grep-based self-check (registration-time and CI-gated, reusing this feature's own investigation.md citation as the baseline): no `contracts/*.schema.json` anywhere in the repository carries a decimal `schema` const string; the designed v1.1 fragment's own Registry-instance discriminator stays `"capability-registry/v1"`, unchanged | Planned |
| AC-007 | REQ-002 | TEST-007 | byte-identical no-second-argument lock | design.md Test Strategy item 4 (`check-risk-upgrade-byte-identical`): the six-row keyword scan's own existing live fixture set (positive and negative), invoked with no second argument against the designed extension, produces output byte-identical to today's live `check-risk-upgrade.{sh,ps1}` | Planned |
| AC-008 | REQ-002 | TEST-008 | merge-ordering lock | design.md Test Strategy item 5 (`check-risk-upgrade-capability-merge`): a fixture with both a keyword match and a `--capability-reasons` fragment places the keyword-derived trigger(s) first, Capability-derived trigger(s) appended in supplied order, in the `triggers=` output; exit code `10` | Planned |
| AC-009 | REQ-002 | TEST-009 | no-logic-duplication lock | design.md's own API / Contract Plan (REQ-002): a static-review fixture over the designed extension's own algorithm confirms the six-row keyword table gains no new row and the extension's own step 2 never re-evaluates a Predicate DSL expression or re-reads a Registry/Project-Context path — a fixture asserts the extension's own code path calls no function this feature did not itself name for the merge step | Planned |
| AC-010 | REQ-002 | TEST-010 | human-copy staging lock | future implementation-phase check: `specs/epic-194-a6-lite-integration/human-copy/`'s own **payload file set** (recursive staged paths excluding this batch's own control files — `MANIFEST.sha256` and the runner script itself, design.md Protected-File Statement, "Payload file set, defined") mirrors the live repository tree for exactly `risk-upgrade-policy.md`, `check-risk-upgrade.sh`, `check-risk-upgrade.ps1`, and `lite-spec/SKILL.md`, each with a correct `MANIFEST.sha256` entry — no payload path outside that declared four-target set is staged under this directory; the directory's own control files (`MANIFEST.sha256`, the runner) are present alongside the payload and excluded from this comparison by the same rule, never counted as extraneous payload; applied only via the feature-scoped anchored runner AC-031 names, never a bare `cp` (Major [M3], payload/control-file definition corrected 2026-07-22 adversarial final verification, investigation.md INV-020) | Planned (Status resolves through the AC-031 runner, not a bare human `cp`) |
| AC-011 | REQ-003 | TEST-011 | disabled-legacy absent-Summary lock (narrowed, Blocker [B6]) | design.md Test Strategy item 8 (`lite-gate-summary-absent`): no Project Context at all (`disabled-legacy`) and no `capability-summary.yaml` → `lite-gate`'s designed extension runs exactly its five baseline checks, output identical to today's live `lite-gate` behavior — narrowed from an earlier revision that also treated an *active-enforcement* zero-matched-Capability absence as this same legitimate case (AC-030, below, now covers that case separately, since it is a present-but-empty Summary, never an absence) | Planned |
| AC-012 | REQ-003 | TEST-012 | schema-validation-before-trust lock | design.md Test Strategy item 9 (`lite-gate-summary-invalid`): a `capability-summary.yaml` fixture that fails A4's own schema causes the designed extension's own `VERDICT: FAIL`, `Status` unchanged, reason naming the validation failure — never a silent trust of malformed content | Planned |
| AC-013 | REQ-003 | TEST-013 | no-re-aggregation lock | static-review fixture over design.md's own API / Contract Plan (REQ-003/REQ-004 step "c"): confirms the designed extension reads `required_lite_checks` as a single already-aggregated field, with no per-Capability loop or union computation of its own anywhere in `lite-gate`'s designed Process | Planned |
| AC-014 | REQ-004 | TEST-014 | Step-2b insertion-point lock | design.md's own Architecture diagram: a fixture confirms the designed Step 2b sits between the existing Step 2 and Step 3, and that the existing "順序が重要" ordering note (Done-transition-before-final-verification) is textually preserved, unchanged, in the designed extension | Planned |
| AC-015 | REQ-004 | TEST-015 | baseline-duplicate no-op lock | design.md Test Strategy item 7 (`lite-gate-summary-consumption`): a `required_lite_checks` entry equal to `build` (an existing baseline check) is not re-executed and produces no second report line in the designed quality-report shape | Planned |
| AC-016 | REQ-004 | TEST-016 | unmapped-required-check FAIL lock (reversed, Blocker [B7]; safety-hardened, NEW-01) | same suite as TEST-015: a `required_lite_checks` entry the command-discovery contract cannot resolve (neither a `package.json` script nor a `scripts/<id>.{sh,ps1}` pair, e.g. `installer-dry-run` in a fixture repository with neither) is `VERDICT: FAIL` with a stated reason — never `N/A` and never silently dropped from the quality report; a companion fixture confirms Step 2's own pre-existing, non-Registry-sourced missing-local-command convention is unchanged (still `N/A`). Paired `bash`+`ps1` negative fixtures (NEW-01) additionally confirm: a check-id containing `../` or a path separator, and an option-like id (e.g. `--help`), are rejected by the grammar check before discovery runs; a `scripts/<id>` symlink/reparse point resolving inside `scripts/` is rejected by the regular-file rule; and a fixture staging only one of `scripts/<id>.sh`/`scripts/<id>.ps1` confirms the id is unmapped, not resolved-for-the-running-runtime-only (the dual-runtime pairing rule) | Planned |
| AC-017 | REQ-004 | TEST-017 | direct-edit protection-status lock | design.md's own Protected-File Statement: a fixture re-runs `grep -n "sdd-lite" plugins/sdd-quality-loop/references/guard-invariants.json` immediately before the designed `lite-gate/SKILL.md` edit is applied (future implementation phase) and confirms `lite-gate/SKILL.md` is still absent from both arrays before proceeding with a direct edit — if present, the implementation task halts and re-routes through human-copy instead (OQ-001 contingency, restated as a testable gate) | Planned |
| AC-018 | REQ-004 | TEST-018 | no-heavy-machinery lock | static-review fixture over the designed Step 2b: confirms it invokes no evidence-bundle generator, no cross-model-verification call, no second-approval check, and no risk-hierarchy classification — only bounded execution of a Registry-named, `capability-summary.yaml`-capped check list | Planned |
| AC-019 | REQ-005 | TEST-019 | Block-contract shape lock | design.md Test Strategy item 6 (`lite-spec-capability-block`): a fixture whose Capability-derived signal names an ineligible Capability Blocks before any `specs/<feature>/` file exists, with the identical exit code (`10`), message shape (`full-required: ...`), and non-overridability (`--lite` never overrides) as an existing keyword-match fixture | Planned |
| AC-020 | REQ-005 | TEST-020 | OQ-002 resolved-selection lock (revised, Blocker [B1]) | design-content review (no automated test, Spec-Authoring-Time Manual Review Record, below): confirms `design.md`'s Design Decisions section states candidate (a) as **selected**, retains the `ship`-time recheck as a mandatory second stage (not superseded), and that both the Architecture diagram and the API / Contract Plan's REQ-005 algorithm state this concretely, not as a parameterized, unruled choice | Planned |
| AC-021 | REQ-005 | TEST-021 | single-file, human-copy-only lock | future implementation-phase check: the designed REQ-005 edit touches only `lite-spec/SKILL.md`, staged under the same `specs/epic-194-a6-lite-integration/human-copy/` directory TEST-010 verifies, with no separate, REQ-005-specific application path introduced | Planned |
| AC-022 | REQ-006 | TEST-022 | fixture-to-AC coverage lock | design-content review (no automated test, Spec-Authoring-Time Manual Review Record, below): confirms `design.md`'s Test Strategy items 1-17 collectively exercise every one of AC-002, AC-007, AC-008, AC-011, AC-015, AC-016, AC-026, AC-027, and AC-028, with no listed fixture that exercises no AC | Planned |

| AC-026 | REQ-003/REQ-004 | TEST-026 | `full_upgrade_required` backstop lock | design.md Test Strategy item 12 (`lite-gate-full-upgrade-backstop`): a schema-valid `capability-summary.yaml` with `full_upgrade_required: true` causes `lite-gate`'s Step 2a to `VERDICT: FAIL` before Step 2b runs; `false` continues normally | Planned |
| AC-027 | REQ-002 | TEST-027 | supplied-invalid-fragment fail-closed lock | design.md Test Strategy item 13 (`check-risk-upgrade-fragment-fail-closed`): a `--capability-reasons` path to an unreadable/malformed/shape-invalid file exits `2` with no trigger output, distinct from TEST-007's own omitted-argument fixture | Planned |
| AC-028 | REQ-002 | TEST-028 | ineligible-no-reasons synthetic-trigger lock | design.md Test Strategy item 14 (`check-risk-upgrade-ineligible-no-reasons`): a fragment entry `{"id": "x", "eligible": false, "upgrade_reasons": []}` produces `triggers=ineligible:x` and exit `10` | Planned |
| AC-029 | REQ-001 | TEST-029 | required-enforcement field-presence contract lock | design-content review (no automated test in this package — REQ-001 is out of this feature's own build scope for A5's Resolver, Non-goals; Spec-Authoring-Time Manual Review Record, below): confirms `requirements.md`'s Field Definitions/Edge Cases state the per-matched-Capability, `required`-enforcement-only field-presence contract and name A5's own `lite-check-source-undefined` diagnostic as its enforcement owner — this lock is checked against this package's own text only; it becomes a mutually consistent, enforceable cross-epic contract once A5's own addendum (orchestrator ruling 2026-07-22, B5) narrowing that diagnostic's trigger condition and its REQ-003/AC-016 byte-identity guarantee to this exact case is itself normalized in A5's own package — a dependency this row records in the A6→A5 direction, not the reverse | Planned |
| AC-030 | REQ-003 | TEST-030 | active-enforcement absent-Summary FAIL lock, paired with present-empty-Summary pass-through lock (spec-review round 1, EDGE-CASE-COVERAGE) | design.md Test Strategy item 15 (`lite-gate-summary-absent-active-enforcement`): `workflow.capability_enforcement: required` or `advisory` with no `capability-summary.yaml` at all is `VERDICT: FAIL`, distinct from TEST-011's own `disabled-legacy` fixture. A companion fixture confirms the other half of AC-030's own claim: `workflow.capability_enforcement: required` or `advisory` with a *present*, schema-valid, empty-array (`required_lite_checks`-contributing) `capability-summary.yaml` — the zero-matched-Capability resolve case — is never `VERDICT: FAIL` on that basis; `lite-gate`'s designed extension runs exactly its five baseline checks, the same observable output as TEST-011's `disabled-legacy` fixture, distinct only in that a Project Context is active and the Summary is present-but-empty rather than absent | Planned |
| AC-031 | REQ-002/REQ-005 | TEST-031 | feature-scoped human-copy runner contract lock | design-content review (design.md Protected-File Statement) plus a future implementation-phase runner-conformance fixture (design.md Test Strategy item 17): confirms the runner's own payload-file-set-defined (control files excluded, investigation.md INV-020) exact-set/hash/post-copy-verification contract is stated — a three-way equality among the declared four-target payload list, the manifest's own target set, and the enumerated payload set — and (once authored) rejects a staged directory whose payload file set doesn't exactly match the declared four-target list, rejects a hash mismatch, and re-verifies post-copy | Planned |

## Spec-Authoring-Time Manual Review Record

AC-020, AC-022, and AC-029 are design-content review items, not automated
tests: each is a fact about this specific package's own text, not a
reusable, fixture-driven regression test a future code change could break
— the same reasoning `specs/epic-193-a5-capability-resolver/
acceptance-tests.md` already records for its own AC-029 through AC-032
design-content-review class. Verified by direct inspection, recorded here
once, at this package's own spec-authoring time:

- **AC-020** (revised, Blocker [B1]): `design.md`'s "Design Decisions
  (resolving open questions)" section, subsection "OQ-002 resolution:
  candidate (a) selected, `ship`-time recheck retained as a mandatory
  second stage," states candidate (a) (Project-Context-wide,
  diff-independent evaluation) as **selected**, and candidate (b)'s own
  `ship`-time recheck as **retained**, not superseded, as a mandatory
  second stage. The Architecture diagram's own pre-generation-gate block
  now names candidate (a) concretely (`evaluate-predicate` against every
  Project-Context-declared component), and the API / Contract Plan's
  REQ-005 algorithm's own step 2 is a concrete procedure, not a
  placeholder awaiting ruling. Confirmed present.
- **AC-022** (updated for the expanded fixture inventory, 2026-07-22
  adversarial review): `design.md`'s Test Strategy section lists
  seventeen numbered items; cross-referencing each item's own
  requirements.md AC citation against requirements.md's own Acceptance
  Criteria table confirms AC-002 (item 2), AC-007 (item 4), AC-008
  (item 5), AC-011/AC-030 (items 8/15), AC-015/AC-016 (item 7), AC-026
  (item 12), AC-027 (item 13), and AC-028 (item 14) are each named by at
  least one Test Strategy item, and that every one of the seventeen items
  names at least one requirements.md AC or Global concern (item 10,
  AC-025). Confirmed present.
- **AC-029** (NEW, Blocker [B5]): `requirements.md`'s Field Definitions
  section (`lite_policy.required_lite_checks` bullet) and Edge Cases
  section (`v1 Registry, field absent entirely`, revised) state that a
  matched Capability under `workflow.capability_enforcement: required`
  whose own `lite_policy` carries no `required_lite_checks` key at all is
  not usable on the Lite track, and name A5's own existing
  `lite-check-source-undefined` diagnostic (A5 `requirements.md` REQ-002
  table) as the mechanism whose trigger condition this field's existence
  extends to cover this exact case — distinct from the same absence
  tolerated under `advisory`, and from a zero-matched-Capability resolve
  (a third, non-Blocking state). This is a fact about this package's own
  text stating a contract for a sibling epic's (A5's) own Resolver to
  enforce, not a fixture this package's own future test suite executes
  (A5's Resolver is out of this feature's own build scope, Non-goals) —
  confirmed present. This contract's cross-epic half is not yet mutually
  consistent with A5's own currently-`Pending` text (2026-07-22
  adversarial final verification, B5) — it becomes normative once A5's
  own addendum narrowing the `lite-check-source-undefined` trigger to
  this exact required-enforcement/key-absence case, and correspondingly
  narrowing A5's own REQ-003/AC-016 byte-identity guarantee, is itself
  normalized in A5's own package; this record states that dependency in
  the A6→A5 direction (A6 specifies, A5's own addendum must adopt), not
  the reverse, and this package's own Spec-Review-Status advancement is
  not itself blocked on that addendum landing first.

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

None of these six requires a `tests/*.tests.sh` suite of its own: all six
(AC-020, AC-022, AC-029, AC-023, AC-024, AC-025) are one-shot facts about
this specific package's own text and commit scope, not reusable,
fixture-driven regression tests a future code change could break — the
same reasoning `specs/epic-193-a5-capability-resolver/acceptance-tests.md`'s
AC-029/030/031/032/035/036/037 and `specs/epic-192-a4-facet-manifest/
acceptance-tests.md`'s AC-036/037/038 each already record for their own,
structurally identical exceptions.

- **`lite-check-catalog.json` draft-07 metaschema conformance** (`design.
  md`'s own Data Plan schema fragment): a future implementation-phase
  check validates the authored `contracts/lite-check-catalog.schema.json`
  against the JSON Schema draft-07 metaschema itself, matching every
  sibling epic's own identical check for its own new `contracts/*.
  schema.json` file.
