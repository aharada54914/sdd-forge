# Design: epic-194-a6-lite-integration

Impl-Review-Status: Pending
Feature Type: an additive schema-revision *design* for two Epic-A2-owned
Registry artifacts (`contracts/capability-registry.schema.json`'s
`lite_policy` object; `contracts/lite-upgrade-reason-catalog.json`'s
`reasons` vocabulary), one new, small, A6-owned catalog contract
(`contracts/lite-check-catalog.json`), a documented (not implemented)
extension to two already-protected `sdd-lite` scripts/policy files
(`check-risk-upgrade.{sh,ps1}`, `risk-upgrade-policy.md`) and one
already-protected skill (`lite-spec/SKILL.md`), and a documented
extension to one currently-unprotected skill (`lite-gate/SKILL.md`). No
live schema file, no live script edit, and no live `tests/*.tests.sh`
suite is authored by this package (requirements.md Non-goals) — this is a
Phase 1, contract-fixing design, exactly like every sibling Foundation
epic's own Phase 1 package.

## Technical Summary

Epic A6 is the epic decision document v2 §19/§20 sequences immediately
after Epic A5, specifically so that Registry/Resolver/Manifest machinery
is already fixed before Lite-track Capability-awareness is wired up. This
design's job is almost entirely combinatorial, matching A5's own framing
of its own scope one epic earlier: connect five already-fixed or
already-in-progress contracts — A2's Registry schema and catalog
mechanism, A4's Capability Summary schema, A5's Lite-track Resolver
contract, ADR-0022's own Combination Matrix and forced-upgrade rule, and
the existing, live `sdd-lite` plugin's own risk-upgrade gate and quality
gate — without re-deriving, duplicating, or re-deciding any of them. Two
genuinely new decisions this design does make, narrowly scoped and
explicitly flagged (mirroring A5's own "two new decisions" framing in its
own Technical Summary): (1) the exact eleven-category-to-token mapping for
`lite-upgrade-reason-catalog.json`'s vocabulary growth (requirements.md
Field Definitions; Design Decisions, below); and (2) the exact merge
ordering/no-op rules for `check-risk-upgrade`'s new optional second
argument and `lite-gate`'s new Registry-sourced-check step (Design
Decisions, below). One question this design does **not** resolve —
requirements.md OQ-002, what supplies the Capability-derived signal at
`lite-spec`'s pre-generation Risk-Upgrade Gate — is carried forward here as
two named, non-selected candidates (Design Decisions, "OQ-002 candidates,"
below), per this task's own instruction not to add independent design
judgment where no正本 source resolves the question.

## Architecture

```
 ── REQ-001: Registry v1.1 extension (design only; applied by Epic A2's
    own Phase 2 or a follow-up A2-owned revision task) ──────────────────

  contracts/capability-registry.schema.json (A2, v1 today)
        │  lite_policy: {eligible, upgrade_reasons}  ← 2 keys, frozen shape
        ▼
  + required_lite_checks (3rd key, optional, default [])  ── this design
        │
        ├─→ contracts/lite-check-catalog.json (NEW, A6-owned)
        │     {schema, catalog_version, checks: ["installer-dry-run"]}
        │
        └─→ contracts/lite-upgrade-reason-catalog.json (A2-owned, catalog_
              version bump, no schema change)
              reasons: [...5 existing..., +7 new tokens]  ── this design

  validate-capability-registry (A2, extended): + check (j) lite-check-
  catalog conformance, mirroring check (h) exactly
  generate-gate-capabilities (A2, unmodified): passively re-derives from
  the extended, re-validated Registry on its next --check/regenerate cycle

 ── REQ-002/REQ-005: pre-generation gate wiring (design only; applied by
    a future Epic A6 Phase 2 implementation task, via human-copy for the
    three already-protected files, direct edit for lite-gate/SKILL.md) ──

  lite-spec/SKILL.md "Risk-Upgrade Gate" (existing, protected)
        │  today: one checker call, one positional argument (source path)
        ▼
  + Capability-derived signal source (OQ-002 candidate a or b, NOT
    selected by this design — Design Decisions, below)
        │
        ▼
  check-risk-upgrade.{sh,ps1} (existing, protected) ── extended I/O:
        [source-path] [--capability-reasons <fragment-path>]  (2nd arg
        optional; omitted → byte-identical to today)
        │
        ├─ keyword scan (unmodified 6-row table) ─┐
        │                                          ├─ merge (OR), keyword
        └─ Capability-derived tokens (if supplied) ─┘  triggers first
        │
        ▼
  exit 0 lite-eligible | exit 10 full-required: ... | exit 2 input
  unavailable  (unchanged exit-code contract, requirements.md AC-007)

 ── REQ-003/REQ-004: post-implementation gate wiring (design only;
    applied by a future Epic A6 Phase 2 implementation task, direct edit
    for lite-gate/SKILL.md per investigation.md INV-008/OQ-001) ─────────

  specs/<feature>/capability-summary.yaml (A5 writes; A4 schema)
        │  absent → 0 extra checks (REQ-003)
        │  present → validate (A4/A5-owned validator, not reimplemented)
        ▼
  required_lite_checks[]  ──┐
  full_upgrade_required     │  (read-only; OQ-003 scopes lite-gate's own
                             │   use of this field)
                             ▼
  lite-gate/SKILL.md Process (existing, unprotected) ── extended:
    Step 1: placeholder-scan (unchanged)
    Step 2: project lint/typecheck/build/test (unchanged)
    Step 2b (NEW): run every required_lite_checks entry not already one
      of {placeholder, lint, typecheck, build, test}; unmapped check-id →
      N/A with reason; duplicate of a baseline name → no-op
    Step 3: quality report generation (unchanged position, now includes
      Step 2b's own results)
    Step 4: Status: Done only on VERDICT: PASS (unchanged)
    Step 5: check-task-state-lite final verification (unchanged)
```

## Components

| Component | Responsibility | Technology | New/Existing | Protected? |
|---|---|---|---|---|
| `contracts/capability-registry.schema.json`'s `lite_policy` sub-schema | this feature's target for the new `required_lite_checks` key | JSON Schema | v1.1 extension of an A2-owned, not-yet-authored file (investigation.md INV-013) | not yet applicable — file does not exist; once authored, it is A2's own registered protected file, per A2's own REQ-005 plan |
| `contracts/lite-check-catalog.json` | new versioned catalog `required_lite_checks` tokens validate against | JSON | new, A6-owned | to be registered as protected at the same time the extended `capability-registry.schema.json` is (Roles and Permissions, requirements.md) |
| `contracts/lite-upgrade-reason-catalog.json` | `catalog_version`-2 vocabulary growth (data only, no schema change) | JSON | existing (A2-owned), this feature designs its `catalog_version`-2 content | already registered protected by A2's own REQ-005 plan; this feature's edit reuses that same registration, no new one |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.{py,sh,ps1}` | gains one new check, "(j) lite-check-catalog conformance" | Python + sh/ps1 wrappers | existing (A2-owned), this feature designs one additional check only | not protected (matches A2's own REQ-003 script, agent-editable) |
| `plugins/sdd-lite/scripts/check-risk-upgrade.sh` / `.ps1` | gains an optional second argument, merges Capability-derived trigger tokens into existing output | bash / PowerShell | existing, extended | **YES** (investigation.md INV-008) — human-copy |
| `plugins/sdd-lite/references/risk-upgrade-policy.md` | documents the extended two-source contract | Markdown (reference) | existing, extended | **YES** — human-copy |
| `plugins/sdd-lite/skills/lite-spec/SKILL.md` | Risk-Upgrade Gate section gains the Capability-derived Block path (REQ-005) | Markdown (skill) | existing, extended | **YES** — human-copy |
| `plugins/sdd-lite/skills/lite-gate/SKILL.md` | Process gains Step 2b (Registry-sourced check execution) | Markdown (skill) | existing, extended | **NO**, per live `guard-invariants.json` (investigation.md INV-008) — direct edit, re-verified at implementation time (OQ-001) |
| a Capability-aware signal source (OQ-002 candidates) | supplies the pre-generation-gate Capability-derived trigger fragment REQ-002's second argument consumes | TBD, per OQ-002 ruling | new, not designed further by this package until OQ-002 is ruled on | TBD |
| `contracts/capability-summary.schema.json` | read-only dependency; `lite-gate` validates against it (not reimplemented) | JSON Schema | existing (A4-owned, content-frozen), unmodified by this feature | already A4's own registered protection, if any; this feature does not touch it |

## Protected-File Statement

Verified directly against `plugins/sdd-quality-loop/references/guard-
invariants.json` (this worktree, at design-authoring time — investigation.
md INV-008, `grep -n "sdd-lite" plugins/sdd-quality-loop/references/guard-
invariants.json`): exactly four `sdd-lite`-owned paths are protected today
— `risk-upgrade-policy.md`, `check-risk-upgrade.sh`, `check-risk-upgrade.
ps1`, `lite-spec/SKILL.md`, present in both `protected_gate_suffixes` and
`phase2_human_copy_targets`. `lite-gate/SKILL.md` is **not** present in
either array, and neither is it named by ADR-0022 item 5 or decision
document v2 §6's identical note.

This design therefore splits its own file edits into two distinct
application paths, unlike every sibling epic's own single-path Protected-
File Statement:

1. **Human-copy path (REQ-002, REQ-005)** — `check-risk-upgrade.sh`,
   `check-risk-upgrade.ps1`, `risk-upgrade-policy.md`, `lite-spec/
   SKILL.md`. A future implementation task develops and tests the edited
   file content at an unprotected working location, then stages the
   finished content under `specs/epic-194-a6-lite-integration/human-copy/
   <repository-relative-path>` with a `MANIFEST.sha256` entry, for a human
   to apply via `apply-protected-files` (ADR-0011), the same pattern
   `specs/epic-136-phase2-gates/human-copy/` already establishes in this
   repository (confirmed directly: that directory exists, mirrors the
   live repository tree under `specs/`/`plugins/`/`.github/`, and carries
   its own `apply-protected-files.ps1` + `MANIFEST.sha256` — this design
   reuses that exact structure, not a new one).
2. **Direct-edit path (REQ-004)** — `lite-gate/SKILL.md`. Per the live
   `guard-invariants.json` evidence above, a future implementation task
   edits this file directly, the same way any ordinary, unprotected skill
   file is edited — **but only after re-confirming, at implementation-
   start time, that `guard-invariants.json` still does not name this
   path** (the same "live-repository snapshot, re-verified at
   implementation-start time" discipline every sibling epic's own
   Protected-File Statement already applies to its own citations,
   requirements.md OQ-001). If a human ruling on requirements.md OQ-001
   adds `lite-gate/SKILL.md` to the protected inventory before this
   feature's own implementation begins, path 1 (human-copy) applies to it
   instead, and this design's Component table above is revised
   accordingly — this design does not pre-commit to that outcome on its
   own authority.

No file this design touches is registered as newly protected by this
feature's own authority — `contracts/lite-check-catalog.json`'s own future
protection registration (Roles and Permissions, requirements.md) is
performed by whichever future task also applies the `capability-registry.
schema.json` v1.1 edit (A2's own REQ-005 plan, or a follow-up A2-owned
revision task), not by this feature's own Phase 2, since this feature's
own build scope never touches `contracts/**` at all (requirements.md
Non-goals).

## Layer Specifications

Not applicable — this feature has no `ux-spec.md`/`frontend-spec.md`/
`infra-spec.md`/`security-spec.md` at this phase (requirements.md
Non-goals; investigation.md, matching A2's/A4's/A5's own identical
precedent of adding those later, at impl-review-prep time). This feature
ships no UI and no new infrastructure; its security posture is covered
directly below (Security Boundaries).

## Design System Compliance

Not applicable — no UI surface.

## Cross-Layer Dependencies

- **REQ-001 → Epic A2's Registry schema, validator check-suite pattern,
  and `lite-upgrade-reason-catalog.json`'s additive-versioning
  mechanism**: blocked until A2's own Phase 2 lands (`contracts/
  capability-registry.schema.json` does not exist yet, investigation.md
  INV-013); this feature's own design is authored against A2's `design.
  md` text, not against a live file, exactly as A5's own REQ-001 already
  is against the same not-yet-existing file.
- **REQ-001 → A5's own `required_lite_checks` naming expectation**: this
  feature's field-naming choice is grounded in A5's current (`Pending`)
  text (investigation.md INV-004); if A5 renames the field before reaching
  `Passed`, this design's own API / Contract Plan (below) requires a
  matching revision (Risks, requirements.md).
- **REQ-003/REQ-004 → Epic A4's Capability Summary schema (content-
  frozen, `Passed`) and Epic A5's Resolver-side aggregation contract
  (`Pending`)**: `lite-gate`'s new Step 2b reads only what A5's Resolver
  already writes in A4's already-fixed shape; no field, no aggregation
  rule, and no validation logic is redefined here.
- **REQ-002/REQ-005 → ADR-0011's human-copy mechanism and ADR-0022 item
  5's own authorization to use it for these exact four files**: this
  feature's own file edits do not invent a new protected-file application
  path.
- **REQ-005 → requirements.md OQ-002**: this design does not commit to a
  signal source; both `design.md`'s own Architecture diagram (above) and
  Design Decisions (below) show the extension point as parameterized by
  that open ruling, not resolved.

## ADR Change Log

No new ADR is proposed by this design. Every rule this design applies
(the Combination Matrix, the `lite_policy`/Capability-Summary shapes, the
protected-file/human-copy boundary, the Gate Stage Model) is already
Accepted (ADR-0016, ADR-0017, ADR-0022) or already-`Passed`-content-frozen
(A2/A4's own schemas). Two of this design's own new decisions — the
eleven-category-to-token mapping (Design Decisions, below) and, pending
requirements.md OQ-002's ruling, whichever Capability-derived-signal
mechanism is chosen — are recorded here as **candidates for a possible
future ADR** if spec review finds either warrants one, the same
"anticipated, low-cost follow-up" framing A5's own ADR Change Log already
applies to its own two new (non-upstream-fixed) decisions (multi-component
matching rule, facet-name aggregation rule) — neither is proposed as an
ADR by this package itself.

## Data Plan

- **`lite_policy` (Registry, v1.1 design)** —
  ```json
  {
    "type": "object",
    "additionalProperties": false,
    "required": ["eligible"],
    "properties": {
      "eligible": { "type": "boolean" },
      "upgrade_reasons": {
        "type": "array", "items": { "type": "string", "minLength": 1 },
        "default": []
      },
      "required_lite_checks": {
        "type": "array",
        "items": { "type": "string", "minLength": 1 },
        "uniqueItems": true,
        "default": []
      }
    }
  }
  ```
  (`default` here documents intended value when absent for a
  Resolver/consumer's own materialization step, matching A4's own
  explicit "materialized by the Resolver, never merely a JSON Schema
  `default` annotation" caution, investigation.md INV-005/INV-006 — a
  schema `default` never changes what is schema-valid when the key is
  omitted; REQ-001's own migration rule, requirements.md, is the operative
  statement of what "absent" means at the consumer level, this schema
  fragment only fixes shape.)
- **`contracts/lite-check-catalog.json` (new)** —
  ```json
  {
    "schema": "lite-check-catalog/v1",
    "catalog_version": 1,
    "checks": ["installer-dry-run"]
  }
  ```
  Schema for this instance (mirroring `lite-upgrade-reason-catalog.
  schema.json`'s own shape, A2 `design.md`, one-to-one):
  ```json
  {
    "type": "object",
    "additionalProperties": false,
    "required": ["schema", "catalog_version", "checks"],
    "properties": {
      "schema": { "const": "lite-check-catalog/v1" },
      "catalog_version": { "type": "integer", "minimum": 1 },
      "checks": {
        "type": "array",
        "items": { "type": "string", "minLength": 1 },
        "uniqueItems": true, "minItems": 1
      }
    }
  }
  ```
- **`contracts/lite-upgrade-reason-catalog.json` (`catalog_version` 2,
  data-only change)** —
  ```json
  {
    "schema": "lite-upgrade-reason-catalog/v1",
    "catalog_version": 2,
    "reasons": [
      "public_distribution", "production_cloud_runtime", "durable_workflow",
      "external_identity", "pii", "public_package_registry",
      "store_distribution", "auto_update", "code_signing", "payments",
      "multi_tenant", "high_risk_migration"
    ]
  }
  ```
  (Stable-sorted by first-seeded-first convention, not lexicographic — the
  five already-live tokens keep their existing relative position, the
  seven new tokens are appended in ADR-0022 prose order; this matches how
  an additive `catalog_version` bump in this repository's own established
  convention, A2's own catalog seed itself, is not itself required to be
  lexicographically sorted, only unique and non-shrinking. A validator
  consuming this file only checks *membership*, per REQ-003(h)'s own
  design, never array order.)
- **Capability-derived trigger fragment (REQ-002, new, in-process/CLI JSON
  — not a `contracts/` file)** —
  ```json
  { "upgrade_reasons": ["pii", "durable_workflow"] }
  ```
  `check-risk-upgrade`'s new optional second argument names a path to a
  file of exactly this shape; an absent/unreadable/malformed file at that
  path is treated identically to "no second argument supplied" (Non-goals,
  requirements.md — the two-source merge degrades to the keyword-only
  path, never a hard error on the optional argument specifically, keeping
  the fail-closed posture scoped to the *values inside* the array, whose
  own catalog-membership was already validated upstream by whatever
  produced this fragment, not re-validated here — Design Decisions,
  below, "no re-validation inside check-risk-upgrade").

## API / Contract Plan

**REQ-001 — `validate-capability-registry` check (j):**

```
(j) lite-check-catalog conformance
    for each capabilities[].lite_policy.required_lite_checks[] token:
      token ∈ contracts/lite-check-catalog.json.checks
      else → FAIL "unknown-lite-check: <capability-id>: <token>"
    (mirrors check (h)'s own per-token loop and diagnostic-string shape
     exactly, requirements.md AC-005)
```

**REQ-002 — `check-risk-upgrade` extended CLI (design; applied via
human-copy):**

```
check-risk-upgrade.sh <source-path> [--capability-reasons <fragment-path>]
check-risk-upgrade.ps1 -Path <source-path> [-CapabilityReasons <fragment-path>]
```

Processing (added steps only; everything else is today's live logic,
unmodified, requirements.md AC-007):

```
1. run today's existing 6-row keyword scan over <source-path>, exactly as
   today → keyword_triggers[] (possibly empty)
2. if --capability-reasons/-CapabilityReasons is supplied:
     a. attempt to read <fragment-path> as UTF-8 JSON
     b. if unreadable/malformed/missing "upgrade_reasons" key:
          capability_triggers[] = []   (never an error exit of its own —
          Data Plan, above)
     c. else: capability_triggers[] = fragment["upgrade_reasons"]
        (already catalog-validated upstream; not re-validated here,
        Design Decisions "no re-validation inside check-risk-upgrade")
   else: capability_triggers[] = []
3. all_triggers[] = keyword_triggers[] ++ capability_triggers[]
   (keyword_triggers first, in their existing fixed order; capability_
   triggers appended in the order supplied — requirements.md AC-008)
4. if all_triggers[] is empty: print "lite-eligible"; exit 0
5. else: print "full-required: {all_triggers[0]}; triggers=
   {join(all_triggers, ',')}"; exit 10
   (primary id is now the FIRST entry of the merged list — if
   keyword_triggers[] is non-empty, the primary is unchanged from today's
   behavior, since keyword_triggers still occupies position 0; if
   keyword_triggers[] is empty and only capability_triggers[] is
   non-empty, the primary is the first Capability-derived token — this is
   the one behavior-visible difference from today's contract, and only
   occurs when the second argument is supplied and non-empty, which no
   existing call site does yet, requirements.md AC-007's own byte-
   identical-when-omitted guarantee is unaffected)
```

**REQ-005 — `lite-spec` Risk-Upgrade Gate extension (design; applied via
human-copy; signal source parameterized by OQ-002):**

```
Before beginning the Process or creating any file under specs/<feature>/:
1. resolve the complete user-supplied requirement/source body into one
   local, readable UTF-8 file (unchanged from today)
2. [NEW, position/mechanism per OQ-002 ruling] obtain a Capability-derived
   trigger fragment (Data Plan, above), or determine none applies
3. run:
   plugins/sdd-lite/scripts/check-risk-upgrade.sh <resolved-source-file>
     [--capability-reasons <fragment-path-from-step-2>]
   (or the .ps1 equivalent)
4. exit 0 lite-eligible → continue to Process (unchanged)
   exit 10 full-required: ... → stop before any lite artifact write,
     direct to /sdd-bootstrap:sdd-bootstrap-interviewer, --lite never
     overrides (unchanged contract, now reachable via either source)
   exit 2 input unavailable → stop before any lite artifact write
     (unchanged)
```

**REQ-003/REQ-004 — `lite-gate` Process extension (design; direct edit):**

```
Step 1 (unchanged): check-placeholders
Step 2 (unchanged): project lint/typecheck/build/test, self-executed
Step 2b (NEW):
  a. locate specs/<feature>/capability-summary.yaml
  b. if absent: required_lite_checks = [] ; continue (no error)
  c. if present: validate against contracts/capability-summary.schema.
     json (call A4/A5-owned validator; do not reimplement)
     - invalid → this task's own VERDICT: FAIL, reason = validation
       failure text, Status unchanged (Edge Cases, requirements.md)
     - valid → required_lite_checks = summary.required_lite_checks
  d. for each id in required_lite_checks:
       if id ∈ {placeholder, lint, typecheck, build, test}: no-op
       elif <local command mapping exists for id>: run it, self-executed,
         same capture/record discipline as Step 2
       else: record "<id>: N/A — no local command mapping" (requirements.
         md AC-016)
Step 3 (unchanged position, now includes Step 2b's own results): quality
  report generation, VERDICT: PASS only if Steps 1/2/2b all PASS or N/A
Step 4 (unchanged): Status: Done only on VERDICT: PASS
Step 5 (unchanged): check-task-state-lite final verification
```

## Test Strategy

Every fixture below is a **design-phase target** (requirements.md REQ-006)
— no `tests/*.tests.sh`/`.tests.ps1` file is authored by this package; a
future implementation task authors them. This section is a design-phase
**elaboration** of requirements.md REQ-006's own seven-item, lettered
(a)-(g) illustrative fixture inventory into ten concrete, numbered suites
— each lettered item maps to at least one numbered item below (item 2 ↔
(c); item 5/6 ↔ (b); item 7 ↔ (a)/(d)/(e); item 8 ↔ (g); item 1 ↔ (f)),
and this design adds three numbered items no lettered item named
verbatim (item 3, catalog-growth non-destructiveness; item 4, the
byte-identical regression baseline; item 9, schema-invalid-Summary
handling) plus one Global item (item 10, AC-025) — an addition, never a
narrowing, of requirements.md's own inventory, the same "expands, never
drops, the earlier lettered/numbered scope" relationship A5's own design.
md Test Strategy already has to its own requirements.md REQ-006 fixture-
matrix items a-h.

1. `lite-check-catalog-conformance` (REQ-001, check (j)) — a
   `capabilities[]` fixture with `required_lite_checks: ["installer-dry-
   run"]` passes; a fixture with `required_lite_checks: ["unknown-check"]`
   fails with `unknown-lite-check: <id>: unknown-check`, independent of
   any `upgrade_reasons` value in the same fixture (requirements.md AC-005).
2. `lite-policy-v1-compat` (REQ-001, migration rule) — a `lite_policy:
   {eligible: true, upgrade_reasons: []}` fixture (no `required_lite_
   checks` key at all) validates successfully under the v1.1 schema
   design; a downstream consumer fixture confirms it is treated as `[]`
   (requirements.md AC-002).
3. `lite-upgrade-reason-catalog-v2` (REQ-001) — every one of the twelve
   `catalog_version`-2 tokens (Data Plan, above) validates; a fixture
   using a pre-v2 token (e.g. `pii`) still validates (no removal, AC-004).
4. `check-risk-upgrade-byte-identical` (REQ-002) — the six-row keyword
   scan's own existing fixture set (both positive and negative), invoked
   with **no** second argument, produces output byte-identical to today's
   live scripts (requirements.md AC-007) — this fixture set is the
   existing live behavior, reused as a regression baseline, not
   reauthored.
5. `check-risk-upgrade-capability-merge` (REQ-002) — a fixture with a
   clean (no-keyword-match) source file plus a `--capability-reasons`
   fragment naming one token produces `full-required: <token>;
   triggers=<token>`, exit `10`; a fixture with **both** a keyword match
   and a capability-reasons fragment produces the keyword trigger first,
   capability trigger(s) appended (requirements.md AC-008); a fixture with
   an unreadable/malformed `--capability-reasons` path and no keyword
   match produces `lite-eligible`, exit `0` (Data Plan's own degrade rule).
6. `lite-spec-capability-block` (REQ-005) — per whichever OQ-002 candidate
   is ruled on, a fixture whose Capability-derived signal names an
   ineligible Capability Blocks before any `specs/<feature>/` file exists,
   with the same message/exit-code/non-overridability shape as an existing
   keyword-match fixture (requirements.md AC-019).
7. `lite-gate-summary-consumption` (REQ-003/REQ-004) — a well-formed
   `capability-summary.yaml` naming `required_lite_checks: ["build",
   "installer-dry-run"]` causes `lite-gate` to no-op on `build`
   (already a baseline check) and to run/record `installer-dry-run`
   (mapped or `N/A`, per whether a local command mapping fixture supplies
   one) (requirements.md AC-015/AC-016).
8. `lite-gate-summary-absent` (REQ-003) — no `capability-summary.yaml`
   at all → `lite-gate` runs exactly its five baseline checks, output
   identical to today's live behavior (requirements.md AC-011).
9. `lite-gate-summary-invalid` (REQ-003, Edge Cases) — a `capability-
   summary.yaml` that fails A4's schema → `VERDICT: FAIL`, `Status`
   unchanged, reason names the validation failure.
10. `registration-drift` (Global, AC-025) — `bash scripts/check-sdd-
    structure.sh .` and `bash plugins/sdd-quality-loop/scripts/check-
    workflow-state.sh` both exit `0` after this package's registration
    commit, re-run as a fixture, not only as a one-time manual check.

## Design Decisions (resolving open questions)

- **Field name `required_lite_checks`, not a new/renamed term** — chosen
  because (a) A5's own current text already uses this exact name for the
  per-Capability contribution it cannot yet source (investigation.md
  INV-004, A5 `design.md:947`), and (b) the aggregation is a plain set
  union across matched Capabilities (investigation.md INV-006), the same
  relationship `required_facets` already has between its own per-
  Capability and Feature-level forms, unlike the renamed `lite_policy`→
  `lite_eligibility`/`minimum_enforcement`→`capability_minimum_
  enforcement` pairs (both of which carry derived, non-union aggregation).
  This is not an independent invention — it is the most direct reading of
  two already-written sibling texts, cited exactly (requirements.md
  Dependencies).
- **`lite-check-catalog.json` seeded with exactly one token** —
  `installer-dry-run` is the only Lite-specific check-id decision document
  v2 §6 itself names (its own worked Capability Summary example);
  `build`/`test` from that same example are already `lite-gate` baseline
  checks, not new catalog entries. This design does not invent additional
  seed tokens no正本 source names (requirements.md Non-goals) — a real
  Capability author is expected to grow the catalog via its own additive
  `catalog_version` mechanism, the same restraint A2 itself already
  exercised for the (now-being-expanded) upgrade-reason catalog's own
  five-token seed (investigation.md INV-007).
- **Eleven-category-to-token mapping (`lite-upgrade-reason-catalog.json`
  `catalog_version` 2)** — Data Plan's table maps ADR-0022's forced-
  upgrade prose to snake_case tokens by direct paraphrase, reusing the
  five already-seeded tokens' own naming register (lowercase, underscore-
  separated, noun-phrase). This is this design's own new decision (A2's
  own text explicitly defers it to this feature, investigation.md
  INV-007) — flagged here, per this task's own instruction, as a
  candidate for spec-review correction or a follow-up ADR if a different
  tokenization proves more consistent with the existing seed (ADR Change
  Log, above; requirements.md Risks).
- **Merge ordering: keyword triggers before Capability-derived triggers**
  — chosen because it keeps every existing single-argument call site's
  own `full-required: <primary-id>; triggers=...` output's *primary*
  diagnostic unchanged whenever a keyword match exists (API / Contract
  Plan, above), minimizing the behavior-visible surface of this
  extension to exactly the one case (`ship`/future callers eventually
  supplying a non-empty second argument on an otherwise-clean source)
  where the existing contract had no prior primary diagnostic to
  preserve.
- **No re-validation inside `check-risk-upgrade`** — the script's own new
  second argument is treated as already-catalog-validated data (Data
  Plan), never re-checked against `lite-upgrade-reason-catalog.json`
  itself; this keeps the script's own logic exactly what it is today (a
  keyword scanner plus, now, a trivial merge step) and avoids a second,
  competing validation surface for the identical catalog A2's own
  `validate-capability-registry` already fail-closes on at Registry-
  authoring time (requirements.md Non-goals — "does not duplicate...
  logic").
- **`lite-gate` Step 2b's own no-op/unmapped rules** — a baseline-name
  duplicate is a no-op (never a second execution or a second report line)
  because `lite-gate`'s own five baseline checks are already fixed,
  independent commands; re-running one under a Registry-sourced alias
  would either silently double-report a false-negative-risk PASS/FAIL pair
  or require inventing an idempotence contract no正本 source names. An
  unmapped check-id is `N/A` with a reason, reusing Step 2's own existing
  convention for a missing project command (`lite-gate/SKILL.md:37`,
  investigation.md INV-010) rather than inventing a second, stricter
  failure mode this task's own Non-goals do not authorize.
- **OQ-002 candidates, presented without selection** (requirements.md
  Open Questions; this design's Architecture/API-Contract-Plan sections
  above both parameterize on this ruling rather than assume one):
  - **Candidate (a) — Project-Context-wide, diff-independent evaluation.**
    At the pre-generation gate, evaluate every Registry Capability's own
    `trigger` against every component the Project Context already
    declares (Epic A1, static), reusing only A2's `evaluate-predicate`
    CLI (one call per Capability × declared component, the identical
    per-component fan-out shape A5's own Resolver already uses, but
    against the *full declared set*, never a diff-derived `affected_
    components` subset). Advantage: available at the exact pre-generation
    position decision document v2 §19's own literal Epic A6 line
    requires, with no dependency on a Feature-specific diff existing yet.
    Cost: a whole-project, not Feature-scoped, evaluation may Block a
    Feature that would not actually have touched the flagged component
    (over-broad, in the fail-closed direction decision document v2's own
    "曖昧な場合はBlock" governing philosophy already accepts as the safer
    error).
  - **Candidate (b) — defer to the existing `ship`-time recheck only.**
    Leave the pre-generation gate's own Capability-awareness inert (no
    second argument ever populated there); wire REQ-002's extension only
    into the *second* existing `check-risk-upgrade` invocation point
    (`ship`, where a real Feature-specific diff already exists via
    whatever mechanism resolves it at that point, investigation.md
    INV-010), which can then reuse A5's own Resolver output directly (a
    Capability Summary or Facet Manifest may already exist by `ship`
    time). Advantage: reuses A5's already-designed aggregation rule
    exactly, with no new diff-independent evaluation mode. Cost: decision
    document v2 §19's own literal "artifact 生成前 Block — lite-spec の
    risk-upgrade gate と同じ位置" line is not satisfied at that exact
    position for the Capability-derived source specifically (only for the
    keyword-scan source, unchanged); a Lite-ineligible Feature could reach
    three-file generation before its first Capability-aware recheck.
  - Neither candidate is chosen here (requirements.md AC-020) — this
    design records both, with their own named tradeoffs, for spec-review
    or human ruling.

## Global Constraints

- No new plugin — every script/skill this design touches already lives in
  `plugins/sdd-lite/` or `plugins/sdd-quality-loop/`; no `sdd-capability`
  or similar new plugin is introduced (matching A2's/A4's own rejected-
  new-plugin precedent, investigation.md).
- No new heavy machinery on the Lite track — `lite-gate` gains a bounded,
  Registry-named check list, never evidence-bundle/cross-model/second-
  approval/risk-hierarchy machinery (ADR-0022 item 4's own "never grows
  into a second `quality-gate`" boundary, requirements.md AC-018).
- Cross-runtime parity — every script edit this design names
  (`check-risk-upgrade.{sh,ps1}`) keeps its existing `sh`/`ps1` pair
  structure; this design introduces no `.py`/`.js` master for either file
  (their existing implementation is native shell/PowerShell, not a
  Python-master-plus-wrappers pattern — unlike A2's own new scripts, this
  design does not change that).

## Security Boundaries

(Restated and design-elaborated from requirements.md's own Security
Boundaries.)

- Fail-closed degrade, not fail-open, for every new optional input: an
  unreadable/malformed `--capability-reasons` fragment degrades to "no
  Capability-derived trigger" (API / Contract Plan), never to "treat as a
  match" — matching this repository's own established posture that an
  ambiguous or unreadable *input* is a Block/degrade condition, while an
  unrecognized *catalog token* (a different failure class, upstream at
  Registry-authoring time) is fail-closed the opposite direction (REQ-001,
  check (j)) — both directions independently reduce the chance a
  Lite-ineligible Capability is silently treated as eligible.
- No new agent-writable approval-like record — `contracts/lite-check-
  catalog.json` and the `lite-upgrade-reason-catalog.json` `catalog_
  version` bump are both maintainer-authored, versioned data files, not
  runtime state; neither carries an `Approval`/`Status` field this design
  introduces.
- Protected-file boundary preserved, not widened by this feature's own
  authority — REQ-002/REQ-005's four file edits use the existing ADR-0011
  human-copy mechanism exactly as ADR-0022 item 5 already authorizes;
  REQ-004's `lite-gate/SKILL.md` edit stays outside that mechanism unless
  and until a human ruling (OQ-001) adds it, never widened unilaterally by
  this design.

## External Integrations

None. Every artifact this design reads or extends is already internal to
this repository (Registry, Capability Summary, `sdd-lite` scripts/skills).

## Deployment / CI Plan

- CI's existing `--check` drift-detection cycle for A2's own projection
  generator (`generate-gate-capabilities.py --check`) re-runs, unmodified
  in its own logic, once the v1.1 schema and the new/expanded catalogs
  land (requirements.md REQ-001 item 5) — this feature adds no new CI job.
- A future implementation task's own `tests/*.tests.sh`/`.tests.ps1` pairs
  (Test Strategy, above) are wired into `.github/workflows/test.yml` the
  same way every sibling epic's own new test pairs already are — this
  design does not itself edit that file (Non-goals).

## Constraint Compliance

- **1ファイル500行以内**: not applicable in the sense that governs source
  code — this is a specification package; no script/skill file this
  design edits is authored by this package at all (every edit is a design
  target for a future implementation task). The future implementation
  task's own `lite-gate/SKILL.md`/`check-risk-upgrade.{sh,ps1}` edits are
  additive, bounded extensions of already-small existing files
  (`lite-gate/SKILL.md` is 51 lines today, `check-risk-upgrade.sh` is 75
  lines today, investigation.md INV-009/INV-010) — this design's own
  Step-2b/second-argument additions are each a few lines, not a rewrite.
- **型安全・エラーハンドリング**: this design's own API / Contract Plan
  fixes an explicit degrade path (not a silent exception) for every new
  malformed/absent input (Data Plan, Security Boundaries, above).

## Assumptions

(Restated from requirements.md's own Assumptions, design-elaborated.)

- A2's `design.md` text (the source for this feature's own `lite_policy`/
  catalog schema fragments, since no live `contracts/capability-registry.
  schema.json` exists yet) will not change in a way that breaks this
  design's own citations before this feature's own spec review completes.
- A5's `required_lite_checks` naming and union-match aggregation reasoning
  (both cited from A5's current, `Pending` text) are treated as the best
  available grounding, not a guarantee — this design's own field-naming
  choice would need revision if A5 changes either before reaching
  `Passed`.
- `lite-gate/SKILL.md`'s currently-unprotected status is re-verified, not
  assumed permanently true, at the future implementation task's own start
  time (Protected-File Statement, above).

## Open Questions

Restated from requirements.md (OQ-001, OQ-002, OQ-003) — this design does
not resolve any of the three on its own authority; see requirements.md's
own Open Questions section for the full statement of each, and this
document's Design Decisions section above for how each is parameterized
in the Architecture/API-Contract-Plan pending ruling.

## Risks

Restated and design-elaborated from requirements.md's own Risks section.

- **A5 is not yet `Passed`** — this design's own field name and
  aggregation assumption are grounded in A5's current text; a rename or
  aggregation-rule change in A5 before its own `Passed` status would
  require a corresponding revision here (requirements.md Risks, restated).
- **OQ-002 is a genuine, unresolved timing gap, not a drafting omission**
  — whichever candidate spec review selects, the `ship`-time recheck
  (already existing, unmodified by this design beyond the same optional-
  argument extension REQ-002 already applies uniformly to both call
  sites) remains a second, independent enforcement point regardless
  (Design Decisions, above, candidate (a)'s own stated cost).
- **The eleven-category-to-token mapping is this design's own
  interpretation of ADR-0022's prose, not a table the ADR itself
  provides** — flagged for possible spec-review correction (ADR Change
  Log, above).
- **`installer-dry-run` as the sole catalog seed may prove too narrow** —
  accepted as a low-cost, additive-catalog follow-up risk rather than a
  reason to pre-populate a larger, non-正本-grounded vocabulary (Design
  Decisions, above).
