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
Decisions, below). requirements.md OQ-002 (what supplies the
Capability-derived signal at `lite-spec`'s pre-generation Risk-Upgrade
Gate) is now **resolved** by orchestrator ruling 2026-07-22 (2026-07-22
adversarial review, Blocker [B1]): candidate (a) is selected, layered with
the existing `ship`-time recheck as a mandatory second stage (Design
Decisions, "OQ-002 resolution," below, restates the ruling and its
reasoning).

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
        │     {schema, catalog_version, checks: ["build", "test",
        │      "installer-dry-run"]}  (3-token seed, M1)
        │
        └─→ contracts/lite-upgrade-reason-catalog.json (A2-owned, catalog_
              version bump, no schema change)
              reasons: [...5 existing..., +7 new tokens]  ── this design

  validate-capability-registry (A2, extended): + check (j) lite-check-
  catalog conformance, mirroring check (h) exactly
  generate-gate-capabilities (A2, unmodified): never carries lite_policy/
  required_lite_checks in its own output (M2, investigation.md INV-018) —
  its own --check cycle only re-verifies the projection's _generated.
  sha256 metadata against the now-larger Registry file; A5 reads
  lite_policy directly from the full Registry, not through this projection

 ── REQ-002/REQ-005: pre-generation gate wiring (design only; applied by
    a future Epic A6 Phase 2 implementation task, via human-copy for the
    three already-protected files, direct edit for lite-gate/SKILL.md) ──

  lite-spec/SKILL.md "Risk-Upgrade Gate" (existing, protected)
        │  today: one checker call, one positional argument (source path)
        ▼
  + Capability-derived signal source (OQ-002 RESOLVED: candidate (a) —
    evaluate-predicate against every Project-Context-declared component —
    Design Decisions, below)
        │
        ▼
  check-risk-upgrade.{sh,ps1} (existing, protected) ── extended I/O:
        [source-path] [--capability-reasons <fragment-path>]  (2nd arg
        optional; omitted → byte-identical to today; supplied-but-invalid
        → exit 2, Blocker [B3])
        │
        ├─ keyword scan (unmodified 6-row table) ─┐
        │                                          ├─ merge (OR), keyword
        └─ Capability-derived tokens (if supplied) ─┘  triggers first
        │
        ▼
  exit 0 lite-eligible | exit 10 full-required: ... | exit 2 input
  unavailable / fragment invalid  (requirements.md AC-007/AC-027)

  ── ship-time recheck (existing, 2nd check-risk-upgrade invocation) ──
  mandatory second stage, not a fallback — layered with the intake Block
  above (OQ-002 resolution)

 ── REQ-003/REQ-004: post-implementation gate wiring (design only;
    applied by a future Epic A6 Phase 2 implementation task, direct edit
    for lite-gate/SKILL.md per investigation.md INV-008, OQ-001 CLOSED) ──

  workflow.capability_enforcement (Project Context, if any) ── read only
        │  disabled-legacy → absent Summary is legitimate (REQ-003)
        │  advisory/required → absent Summary is VERDICT: FAIL (B6)
        ▼
  specs/<feature>/capability-summary.yaml (A5 writes; A4 schema)
        │  present → validate (A4/A5-owned validator, not reimplemented)
        │             invalid → VERDICT: FAIL (unchanged)
        ▼
  required_lite_checks[]  ──┐
  full_upgrade_required     │  true → VERDICT: FAIL (Step 2a, B2,
                             │   resolves OQ-003) / false → continue
                             ▼
  lite-gate/SKILL.md Process (existing, unprotected) ── extended:
    Step 1: placeholder-scan (unchanged)
    Step 2: project lint/typecheck/build/test (unchanged)
    Step 2a (NEW, B2): full_upgrade_required true → VERDICT: FAIL
    Step 2b (Registry-sourced checks): run every required_lite_checks
      entry not already one of {placeholder, lint, typecheck, build,
      test}; command-discovery contract resolves a command or not (NEW);
      resolved → run, PASS/FAIL; unresolved → VERDICT: FAIL, not N/A
      (B7, reversed); duplicate of a baseline name → no-op
    Step 3: quality report generation (unchanged position, now includes
      Step 2a/2b's own results)
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
| `plugins/sdd-lite/skills/lite-gate/SKILL.md` | Process gains Step 2a (full_upgrade_required backstop) and Step 2b (Registry-sourced check execution) | Markdown (skill) | existing, extended | **NO**, per live `guard-invariants.json` (investigation.md INV-008) — direct edit, re-verified at implementation time (OQ-001, CLOSED) |
| A Capability-aware signal source (OQ-002 resolved: candidate (a)) | supplies the pre-generation-gate Capability-derived trigger fragment REQ-002's second argument consumes — a call to A2's `evaluate-predicate` against every Project-Context-declared component | A2's existing `evaluate-predicate` CLI | invocation only, not a new evaluator (REQ-005) | not protected — reuses an existing, unprotected A2 script |
| `contracts/capability-summary.schema.json` | read-only dependency; `lite-gate` validates against it (not reimplemented) | JSON Schema | existing (A4-owned, content-frozen), unmodified by this feature | already A4's own registered protection, if any; this feature does not touch it |
| Project Context (`workflow.capability_enforcement`, Epic A1) | read-only source distinguishing `disabled-legacy` from `advisory`/`required` for REQ-003's own absent-Summary handling (Step 2a, Blocker [B6]) | YAML (Epic A1 schema) | existing (A1-owned), read-only, no new field | not protected — ordinary project data |
| A feature-scoped anchored human-copy application runner | applies this feature's own `specs/epic-194-a6-lite-integration/human-copy/` batch (4 files) — exact-set/hash/post-copy verified (Blocker [M3]) | PowerShell (mirroring Epic-136's own runner shape) | new, to be authored by a future implementation task, self-hosted under `specs/epic-194-a6-lite-integration/human-copy/` | the runner itself is not a protected file (mirrors the Epic-136 runner, which is likewise self-hosted inside its own human-copy directory) |

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
   `guard-invariants.json` evidence above, and per OQ-001's now-**closed**
   ruling (investigation.md, Minor finding — this design does not itself
   propose expanding the protected-file inventory), a future
   implementation task edits this file directly, the same way any
   ordinary, unprotected skill file is edited — **re-confirming, at
   implementation-start time, that `guard-invariants.json` still does not
   name this path** (the same "live-repository snapshot, re-verified at
   implementation-start time" discipline every sibling epic's own
   Protected-File Statement already applies to its own citations) remains
   a live-repository-snapshot check for reasons entirely outside this
   feature's own scope, not an open design question this package still
   carries. If `guard-invariants.json` is found, independently of this
   feature, to already name this path by the time implementation begins,
   path 1 (human-copy) applies to it instead, and this design's Component
   table above is revised accordingly.

**Human-copy application runner (Major [M3]).** The only runner that
exists today, `specs/epic-136-phase2-gates/human-copy/apply-protected-
files.ps1`, is hard-anchored to its own fixed `specs/epic-136-phase2-
gates/human-copy` prefix (`$HumanCopyPrefix`, investigation.md INV-019)
and additionally requires a staged canonical `guard-invariants.json` copy
at that same fixed prefix, cross-checked against the live file's own
`phase2_human_copy_targets` array — a file this feature's own four-target
batch does not stage (this feature does not propose changing the
protected-file inventory, OQ-001, CLOSED, above). This runner therefore
**cannot** apply this feature's own `specs/epic-194-a6-lite-integration/
human-copy/` batch as-is. This design accordingly fixes the **contract** a
future implementation task's own runner must satisfy, without itself
authoring that runner (Non-goals, requirements.md — this feature does not
touch `plugins/**`/`scripts/**`, and the runner itself, mirroring the
Epic-136 runner's own self-hosted placement, lives at
`specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1`
— inside this feature's own `specs/**` tree, not under `plugins/**`):

1. **Feature-scoped, not fixed-prefix** — reads targets and digests from
   `specs/epic-194-a6-lite-integration/human-copy/` (a parameterized
   prefix, or a dedicated copy of the Epic-136 runner with this feature's
   own prefix hard-coded the same way Epic-136's own copy is,
   `apply-protected-files.ps1:31`) — never the Epic-136 prefix.
2. **Exact-set verification** — the staged directory's own file set
   matches, exactly, the four declared targets (`risk-upgrade-policy.md`,
   `check-risk-upgrade.sh`, `check-risk-upgrade.ps1`, `lite-spec/
   SKILL.md`) — no fewer, no more, no path outside that declared set
   (mirrors `Get-CanonicalTargets`'s own no-duplicate/exact-count
   discipline, `apply-protected-files.ps1:68-79`, reused as a pattern, not
   a literal call into Epic-136's own fixed-prefix instance).
3. **Per-target hash verification** — each staged file's own sha256
   matches a `MANIFEST.sha256` entry (the same shape TEST-010 already
   verifies exists, acceptance-tests.md) before any copy is attempted.
4. **Post-copy re-verification** — after every file is installed, each
   live, installed file's own hash is re-read and re-compared against the
   staged/manifest hash (mirroring `VerifyPublished`/
   `Invoke-PostInstallVerification`, `apply-protected-files.ps1:598-641`)
   — never a bare `cp` with no confirmation the bytes actually landed
   correctly.

A future implementation task authors and has this runner security-
reviewed before this feature's own human-copy batch is ever applied —
this design fixes the contract, not the code (matching this feature's own
Phase-1 boundary, Non-goals, requirements.md).

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
- **REQ-003/REQ-004 → Epic A1's Project Context (`workflow.
  capability_enforcement`, read-only, NEW dependency, Blocker [B6])**:
  `lite-gate`'s own Step 2a reads this single, already-derived field to
  distinguish a legitimate `disabled-legacy` absent-Summary state from an
  active-enforcement one that must FAIL — this is a read of an
  already-fixed Epic A1 field, never a re-derivation of A3's own
  three-state logic.
- **REQ-002/REQ-005 → ADR-0011's human-copy mechanism and ADR-0022 item
  5's own authorization to use it for these exact four files**: this
  feature's own file edits do not invent a new protected-file application
  path.
- **REQ-002/REQ-005 → a feature-scoped anchored human-copy runner (NEW
  obligation, Major [M3])**: `specs/epic-136-phase2-gates/human-copy/
  apply-protected-files.ps1` cannot apply this feature's own staged batch
  (investigation.md INV-019); this design fixes the runner's own required
  contract (Protected-File Statement, above) for a future implementation
  task to satisfy.
- **REQ-005 → requirements.md OQ-002 (RESOLVED)**: this design commits to
  candidate (a) as the signal source, layered with the existing
  `ship`-time recheck; both `design.md`'s own Architecture diagram (above)
  and Design Decisions (below) state the extension point concretely, not
  as a parameterized, unruled choice.

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
- **`contracts/lite-check-catalog.json` (new; seed revised, Blocker
  [M1], investigation.md INV-017)** —
  ```json
  {
    "schema": "lite-check-catalog/v1",
    "catalog_version": 1,
    "checks": ["build", "test", "installer-dry-run"]
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
  — not a `contracts/` file; revised shape, Blocker [B4])** —
  ```json
  {
    "capabilities": [
      {"id": "durable-workflow-svc", "eligible": false,
       "upgrade_reasons": ["durable_workflow"]},
      {"id": "internal-tool-only", "eligible": false,
       "upgrade_reasons": []}
    ]
  }
  ```
  `check-risk-upgrade`'s new optional second argument names a path to a
  file of exactly this shape. **Two distinct failure modes, not one**
  (Blocker [B3], investigation.md INV-014, correcting an earlier revision
  that treated every failure mode identically):
  - **Second argument omitted entirely** — legacy path, byte-identical to
    today (AC-007); no fragment is ever read.
  - **Second argument supplied, file unreadable/malformed/shape-invalid**
    — hard error, exit `2`, no trigger reporting (API / Contract Plan,
    below) — never silently degraded to "no Capability-derived trigger."

  On a successfully read/validated fragment, every entry with
  `eligible: false` contributes: its own `upgrade_reasons` tokens if
  non-empty, or else a single synthetic token `ineligible:<id>` (Blocker
  [B4] — an entry with `eligible: false` and no named reason must still
  produce a non-empty trigger, never silently contribute nothing); an
  entry with `eligible: true` contributes nothing. Each `<token>` inside
  `upgrade_reasons` is already validated upstream against `lite-upgrade-
  reason-catalog.json` by whatever produced this fragment, not
  re-validated here (Design Decisions, below, "no re-validation inside
  check-risk-upgrade" — unchanged in principle, now scoped to the
  *values*, never to the fragment's own shape/readability, which REQ-002
  now validates eagerly, Blocker [B3]).

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
     b. if unreadable/not-valid-JSON/missing "capabilities" key/
        "capabilities" not an array/any entry missing "id" or "eligible":
          print "risk-upgrade: capability-reasons fragment invalid";
          exit 2   (Blocker [B3] — a hard error, never a silent degrade;
          this is the ONE new exit-2 condition this REQ adds, distinct
          from the primary source file's own existing exit-2 condition)
     c. else: capability_triggers[] = for each entry in
        fragment["capabilities"] where entry["eligible"] == false, in
        array order: entry["upgrade_reasons"] if non-empty, else
        [ "ineligible:" + entry["id"] ]   (Blocker [B4] — flattened,
        in order, into one capability_triggers[] list; each
        upgrade_reasons token is already catalog-validated upstream, not
        re-validated here, Design Decisions "no re-validation inside
        check-risk-upgrade")
   else: capability_triggers[] = []   (second argument omitted entirely —
        the ONLY condition AC-007's byte-identical guarantee covers)
3. all_triggers[] = keyword_triggers[] ++ capability_triggers[]
   (keyword_triggers first, in their existing fixed order; capability_
   triggers appended in the order derived above — requirements.md AC-008)
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
human-copy; signal source resolved, OQ-002, Blocker [B1]):**

```
Before beginning the Process or creating any file under specs/<feature>/:
1. resolve the complete user-supplied requirement/source body into one
   local, readable UTF-8 file (unchanged from today)
2. [NEW, OQ-002 resolved: candidate (a)] for every Registry Capability,
   call A2's evaluate-predicate once per component the Project Context
   already declares (Epic A1, static, diff-independent); union-match
   (investigation.md INV-006's own reasoning, applied at whole-project
   granularity here) determines the matched set; assemble every matched,
   ineligible (lite_policy.eligible: false) Capability into the Data
   Plan's own trigger-fragment shape and write it to a temp path — or,
   if no Project Context exists at all (disabled-legacy, Edge Cases,
   requirements.md), skip this step entirely (no fragment is produced)
3. run:
   plugins/sdd-lite/scripts/check-risk-upgrade.sh <resolved-source-file>
     [--capability-reasons <fragment-path-from-step-2>]
   (or the .ps1 equivalent)
4. exit 0 lite-eligible → continue to Process (unchanged)
   exit 10 full-required: ... → stop before any lite artifact write,
     direct to /sdd-bootstrap:sdd-bootstrap-interviewer, --lite never
     overrides (unchanged contract, now reachable via either source)
   exit 2 input unavailable / capability-reasons fragment invalid → stop
     before any lite artifact write (Blocker [B3] adds the second exit-2
     condition; both stop identically)
```

This intake-time Block is layered with, not a substitute for, the existing
`ship`-time recheck (second `check-risk-upgrade` invocation,
investigation.md INV-010) — both stages are mandatory (OQ-002 resolution,
requirements.md Open Questions).

**REQ-003/REQ-004 — `lite-gate` Process extension (design; direct edit):**

```
Step 1 (unchanged): check-placeholders
Step 2 (unchanged): project lint/typecheck/build/test, self-executed
Step 2a (NEW, Blocker [B6]/[B2]):
  a. read workflow.capability_enforcement from the Project Context, if
     one exists (a read, not a re-derivation of A3's own three-state
     logic)
  b. if no Project Context at all (disabled-legacy): absent
     capability-summary.yaml is legitimate; required_lite_checks = [];
     skip to Step 2b with an empty list (unchanged from an earlier
     revision's own rule for this one case)
  c. else (capability_enforcement is advisory or required):
     - locate specs/<feature>/capability-summary.yaml
     - absent → this task's own VERDICT: FAIL, reason = "capability-
       summary.yaml missing under active capability_enforcement"
       (Blocker [B6] — a successful Lite resolve always stages a Summary
       under active enforcement, investigation.md INV-016)
     - present → validate against contracts/capability-summary.schema.
       json (call A4/A5-owned validator; do not reimplement)
       - invalid → VERDICT: FAIL, reason = validation failure text,
         Status unchanged (Edge Cases, requirements.md, unchanged)
       - valid → required_lite_checks = summary.required_lite_checks;
         if summary.full_upgrade_required == true: VERDICT: FAIL,
         reason names the field, Status unchanged, direct to full
         workflow (Blocker [B2], resolves OQ-003) — else continue
Step 2b (Registry-sourced check execution, position unchanged):
  for each id in required_lite_checks:
    if id ∈ {placeholder, lint, typecheck, build, test}: no-op
    elif <command-discovery contract resolves a command for id> (NEW,
      below): run it, self-executed, same capture/record discipline as
      Step 2
    else: VERDICT: FAIL, reason "<id>: required Lite check has no
      discoverable command" (Blocker [B7], reversed — never N/A; N/A
      stays reserved for Step 2's own pre-existing, non-Registry-sourced
      missing-local-command convention only)
Step 3 (unchanged position, now includes Step 2a/2b's own results):
  quality report generation, VERDICT: PASS only if Steps 1/2/2a/2b all
  PASS or (Step 2's own pre-existing convention only) N/A
Step 4 (unchanged): Status: Done only on VERDICT: PASS
Step 5 (unchanged): check-task-state-lite final verification
```

**Lite-check command-discovery contract (NEW, Blocker [B7]):** for a
given Registry-sourced check-id not already one of the five baseline
names, `lite-gate` resolves an executable command in this fixed,
bounded, portable order:
1. a repo-root `package.json` (if one exists) whose own `scripts[<id>]`
   key is present → run via the ecosystem's own cross-runtime script
   invocation (`npm run <id>` / equivalent), the identical convention-
   over-configuration discovery this repository's own tooling already
   relies on elsewhere;
2. a repo-root `scripts/<id>.sh` (POSIX runtime) / `scripts/<id>.ps1`
   (Windows runtime) pair — the same cross-runtime pair convention this
   repository's own `plugins/**/scripts/*.{sh,ps1}` files already
   establish;
3. neither found → **unmapped** (Step 2b, above, states the FAIL
   consequence).
This contract is bounded (two, fixed, checked-in-order locations, never
an open-ended search) and portable (no OS-specific-only lookup) — it
adds no evidence-bundle/cross-model/second-approval machinery (ADR-0022
item 4's own boundary, unchanged, Global Constraints, below).

## Test Strategy

Every fixture below is a **design-phase target** (requirements.md REQ-006)
— no `tests/*.tests.sh`/`.tests.ps1` file is authored by this package; a
future implementation task authors them. This section is a design-phase
**elaboration** of requirements.md REQ-006's own twelve-item, lettered
(a)-(l) illustrative fixture inventory (revised, 2026-07-22 adversarial
review, adding (h)-(l)) into seventeen concrete, numbered suites — each
lettered item maps to at least one numbered item below (item 2 ↔ (c);
item 5/6 ↔ (b); item 7 ↔ (a)/(d)/(e); item 8 ↔ (g); item 1 ↔ (f); item 12
↔ (h); item 13 ↔ (i); item 14 ↔ (j); item 15 ↔ (k); item 16 ↔ (l)), and
this design adds four numbered items no lettered item names verbatim
(item 3, catalog-growth non-destructiveness; item 4, the byte-identical
regression baseline; item 9, schema-invalid-Summary handling; item 11,
the M2 projection-non-carriage correction) plus one Global item (item 10,
AC-025) and one further design-content-review-only item (item 17, the M3
runner contract) — an addition, never a narrowing, of requirements.md's
own inventory, the same "expands, never drops, the earlier lettered/
numbered scope" relationship A5's own design.md Test Strategy already has
to its own requirements.md REQ-006 fixture-matrix items a-h.

1. `lite-check-catalog-conformance` (REQ-001, check (j)) — a
   `capabilities[]` fixture with `required_lite_checks: ["build", "test",
   "installer-dry-run"]` (all three canonical seed tokens, revised M1)
   passes; a fixture with `required_lite_checks: ["unknown-check"]` fails
   with `unknown-lite-check: <id>: unknown-check`, independent of any
   `upgrade_reasons` value in the same fixture (requirements.md AC-005).
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
   fragment naming one ineligible-Capability entry with a non-empty
   `upgrade_reasons` produces `full-required: <token>;
   triggers=<token>`, exit `10`; a fixture with **both** a keyword match
   and a capability-reasons fragment produces the keyword trigger first,
   capability trigger(s) appended (requirements.md AC-008).
6. `lite-spec-capability-block` (REQ-005) — per OQ-002's resolved
   candidate (a), a fixture whose Capability-derived signal (via A2's
   `evaluate-predicate` against every Project-Context-declared component)
   names an ineligible Capability Blocks before any `specs/<feature>/`
   file exists, with the same message/exit-code/non-overridability shape
   as an existing keyword-match fixture (requirements.md AC-019); a
   companion fixture confirms the existing `ship`-time recheck still
   independently Blocks even when the intake-time evaluation did not flag
   the component in question (OQ-002 resolution, defense-in-depth).
7. `lite-gate-summary-consumption` (REQ-003/REQ-004) — a well-formed
   `capability-summary.yaml` naming `required_lite_checks: ["build",
   "installer-dry-run"]` causes `lite-gate` to no-op on `build`
   (already a baseline check) and to run/record `installer-dry-run` via
   the command-discovery contract if resolvable, or `VERDICT: FAIL` —
   never `N/A` — if not (requirements.md AC-015/AC-016, reversed, Blocker
   [B7]).
8. `lite-gate-summary-absent` (REQ-003, `disabled-legacy` only, narrowed
   Blocker [B6]) — no Project Context and no `capability-summary.yaml`
   at all → `lite-gate` runs exactly its five baseline checks, output
   identical to today's live behavior (requirements.md AC-011).
9. `lite-gate-summary-invalid` (REQ-003, Edge Cases) — a `capability-
   summary.yaml` that fails A4's schema → `VERDICT: FAIL`, `Status`
   unchanged, reason names the validation failure.
10. `registration-drift` (Global, AC-025) — `bash scripts/check-sdd-
    structure.sh .` and `bash plugins/sdd-quality-loop/scripts/check-
    workflow-state.sh` both exit `0` after this package's registration
    commit, re-run as a fixture, not only as a one-time manual check.
11. `gate-capabilities-projection-unaffected` (REQ-001 item 5, Major
    [M2]) — confirms `generate-gate-capabilities`'s own generated
    `gate-capabilities.json` never carries a `lite_policy`/
    `required_lite_checks` key in any fixture, before or after the v1.1
    schema/catalog land; a companion fixture confirms only the
    projection's own `_generated.sha256` value changes once the
    underlying Registry file's bytes change, with no other content diff
    — proving the "passive flow through the projection" claim this item
    corrected never held and does not need to.
12. `lite-gate-full-upgrade-backstop` (REQ-004 Step 2a, Blocker [B2]) — a
    schema-valid `capability-summary.yaml` with `full_upgrade_required:
    true` causes `VERDICT: FAIL` at Step 2a, before Step 2b ever runs;
    `false` continues normally (requirements.md AC-026).
13. `check-risk-upgrade-fragment-fail-closed` (REQ-002, Blocker [B3]) —
    a `--capability-reasons` path to an unreadable/malformed/shape-invalid
    file exits `2` with no trigger output, distinct from item 4's own
    omitted-argument byte-identical fixture (requirements.md AC-027).
14. `check-risk-upgrade-ineligible-no-reasons` (REQ-002, Blocker [B4]) —
    a fragment entry `{"id": "x", "eligible": false, "upgrade_reasons":
    []}` produces `triggers=ineligible:x` and exit `10` (requirements.md
    AC-028).
15. `lite-gate-summary-absent-active-enforcement` (REQ-003 Step 2a,
    Blocker [B6]) — `workflow.capability_enforcement: required` (or
    `advisory`) with no `capability-summary.yaml` at all is `VERDICT:
    FAIL`, distinct from item 8's own `disabled-legacy` fixture
    (requirements.md AC-011/AC-030).
16. `required-lite-checks-field-presence-contract` (REQ-001, Blocker
    [B5], design-content review only, matching AC-020/AC-022's own
    class) — confirms requirements.md's Field Definitions/Edge Cases
    text states the per-matched-Capability, `required`-enforcement-only
    field-presence contract, and names A5's own `lite-check-source-
    undefined` diagnostic as its enforcement owner, distinct from
    `advisory` tolerance and from a zero-matched-Capability resolve
    (requirements.md AC-029).
17. `human-copy-runner-contract` (Protected-File Statement, Major [M3],
    design-content review only) — confirms design.md states the
    feature-scoped anchored runner's own exact-set/hash/post-copy-
    verification contract, distinct from the Epic-136 fixed-prefix
    runner it cannot reuse unmodified (requirements.md AC-031).

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
- **`lite-check-catalog.json` seeded with all three of ADR-0022/A4's own
  canonical tokens** (revised, Major [M1], investigation.md INV-017) —
  `build`, `test`, `installer-dry-run` are the exact three check-ids
  ADR-0022 item 3's own worked `capability-summary.yaml` example and A4's
  own AC-013 canonical fixture both name. An earlier revision of this
  design seeded only `installer-dry-run`, reasoning `build`/`test` are
  already `lite-gate` baseline checks and therefore "not new catalog
  entries" — but the catalog governs which tokens validator check (j)
  accepts as a legitimate Registry-level *declaration*, independent of
  whether `lite-gate` treats a matching token as a no-op at execution time
  (REQ-004, AC-015); the single-token seed rejected this design's own
  `build`+`installer-dry-run` Test Strategy fixture (item 7, above) at
  check (j), a self-contradiction the adversarial review caught. This
  design still does not invent tokens beyond what ADR-0022/A4 already name
  (requirements.md Non-goals) — a real Capability author still grows the
  catalog via its own additive `catalog_version` mechanism for anything
  beyond these three, the same restraint A2 itself already exercised for
  the (now-being-expanded) upgrade-reason catalog's own five-token seed
  (investigation.md INV-007).
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
- **`lite-gate` Step 2b's own no-op/unmapped rules (unmapped case
  reversed, Blocker [B7])** — a baseline-name duplicate is a no-op (never
  a second execution or a second report line) because `lite-gate`'s own
  five baseline checks are already fixed, independent commands;
  re-running one under a Registry-sourced alias would either silently
  double-report a false-negative-risk PASS/FAIL pair or require inventing
  an idempotence contract no正本 source names. An unmapped check-id is now
  `VERDICT: FAIL` with a reason, not `N/A` — an earlier revision reused
  Step 2's own existing missing-project-command convention (`lite-gate/
  SKILL.md:37`, investigation.md INV-010) for this case too, but a
  Registry-sourced `required_lite_checks` declaration is a promise the
  check runs, and letting an unmapped one silently PASS-by-`N/A` breaks
  that promise; `N/A` stays reserved for Step 2's own original,
  non-Registry-sourced convention only (API / Contract Plan, "Lite-check
  command-discovery contract," above).
- **OQ-002 resolution: candidate (a) selected, `ship`-time recheck
  retained as a mandatory second stage (orchestrator ruling 2026-07-22,
  Blocker [B1])** (requirements.md Open Questions; this design's
  Architecture/API-Contract-Plan sections above both now state this
  concretely, not parameterized on an unruled question):
  - **Candidate (a) — Project-Context-wide, diff-independent evaluation —
    SELECTED.** At the pre-generation gate, evaluate every Registry
    Capability's own `trigger` against every component the Project
    Context already declares (Epic A1, static), reusing only A2's
    `evaluate-predicate` CLI (one call per Capability × declared
    component, the identical per-component fan-out shape A5's own
    Resolver already uses, but against the *full declared set*, never a
    diff-derived `affected_components` subset). Selected because it is
    available at the exact pre-generation position decision document
    v2 §19's own literal Epic A6 line requires, with no dependency on a
    Feature-specific diff existing yet — the property candidate (b) alone
    could not satisfy. Accepted cost: a whole-project, not Feature-scoped,
    evaluation may Block a Feature that would not actually have touched
    the flagged component (over-broad, in the fail-closed direction
    decision document v2's own "曖昧な場合はBlock" governing philosophy
    already accepts as the safer error) — this cost is accepted, not
    eliminated, by this ruling.
  - **Candidate (b) — defer to the existing `ship`-time recheck only —
    NOT selected as the sole mechanism, but retained as a mandatory
    second stage alongside (a).** Leaving the pre-generation gate's own
    Capability-awareness inert (as candidate (b) alone would) does not
    satisfy decision document v2 §19's own literal "artifact生成前Block"
    requirement for the Capability-derived source specifically — this is
    why candidate (b) is not selected *in place of* candidate (a). It is,
    however, retained in its original, already-existing form (the
    `ship`-time recheck was never contingent on this ruling — REQ-002's
    own optional-argument extension already applies uniformly to both
    call sites, requirements.md Main Workflows step 6) as the second,
    independent layer that catches a Feature whose real diff touches a
    component the whole-project, intake-time evaluation in candidate (a)
    did not itself flag as relevant (a component added or changed after
    intake) — this residual gap is the accepted cost candidate (a)'s own
    advantage does not itself close (Risks, below, restates it as an
    accepted, non-blocking property of the two-stage design, not an
    unresolved question).

## Global Constraints

- No new plugin — every script/skill this design touches already lives in
  `plugins/sdd-lite/` or `plugins/sdd-quality-loop/`; no `sdd-capability`
  or similar new plugin is introduced (matching A2's/A4's own rejected-
  new-plugin precedent, investigation.md).
- No new heavy machinery on the Lite track — `lite-gate` gains a bounded,
  Registry-named check list, never evidence-bundle/cross-model/second-
  approval/risk-hierarchy machinery (ADR-0022 item 4's own "never grows
  into a second `quality-gate`" boundary, requirements.md AC-018) — the
  Lite-check command-discovery contract (REQ-004, Blocker [B7]) and the
  fragment-shape/fail-closed reversal (REQ-002, Blockers [B3]/[B4]) are
  both designed to stay within this same bound: a fixed, two-location
  command lookup and a stricter input-validation rule, never a new
  verification subsystem.
- Cross-runtime parity — every script edit this design names
  (`check-risk-upgrade.{sh,ps1}`) keeps its existing `sh`/`ps1` pair
  structure; this design introduces no `.py`/`.js` master for either file
  (their existing implementation is native shell/PowerShell, not a
  Python-master-plus-wrappers pattern — unlike A2's own new scripts, this
  design does not change that).

## Security Boundaries

(Restated and design-elaborated from requirements.md's own Security
Boundaries.)

- Fail-closed for every new input and every new read this design adds: a
  **supplied-but-invalid** `--capability-reasons` fragment now Blocks
  (exit `2`, API / Contract Plan) rather than degrading (Blocker [B3],
  correcting an earlier revision that degraded silently and mislabeled
  that degrade "fail-closed," investigation.md INV-014) — the *only*
  remaining degrade path is the second argument's own total absence (the
  legacy, byte-identical case, AC-007); an unrecognized *catalog token* (a
  different failure class, upstream at Registry-authoring time) is
  fail-closed the opposite direction (REQ-001, check (j)); a Capability
  Summary absent under active `capability_enforcement` (Blocker [B6]),
  `full_upgrade_required: true` (Blocker [B2]), and an unmapped
  `required_lite_checks` entry (Blocker [B7]) are all now `VERDICT: FAIL`
  at `lite-gate`, never a silent pass-through — every one of these
  directions independently reduces the chance a Lite-ineligible
  Capability, or an unfulfilled required check, is silently treated as
  eligible/satisfied.
- No new agent-writable approval-like record — `contracts/lite-check-
  catalog.json` and the `lite-upgrade-reason-catalog.json` `catalog_
  version` bump are both maintainer-authored, versioned data files, not
  runtime state; neither carries an `Approval`/`Status` field this design
  introduces.
- Protected-file boundary preserved, not widened by this feature's own
  authority — REQ-002/REQ-005's four file edits use the existing ADR-0011
  human-copy mechanism exactly as ADR-0022 item 5 already authorizes;
  REQ-004's `lite-gate/SKILL.md` edit stays outside that mechanism, per
  OQ-001's now-**closed** ruling, never widened unilaterally by this
  design. The feature-scoped human-copy runner this design's Protected-
  File Statement now names (Major [M3]) must itself be security-reviewed
  before use, since it operates on protected-file targets — a future
  implementation-phase obligation this design records, not performs.

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

Restated from requirements.md (OQ-001, OQ-002, OQ-003) — all three are now
CLOSED/RESOLVED by orchestrator ruling 2026-07-22 (requirements.md's own
Open Questions section states each ruling; investigation.md states the
full reasoning); this document's Design Decisions section above, and the
Architecture/API-Contract-Plan sections, state the resolved behavior
normatively, not as a still-pending parameterization.

## Risks

Restated and design-elaborated from requirements.md's own Risks section.

- **A5 is not yet `Passed`** — this design's own field name and
  aggregation assumption are grounded in A5's current text; a rename or
  aggregation-rule change in A5 before its own `Passed` status would
  require a corresponding revision here (requirements.md Risks, restated).
- **The intake-time Block (OQ-002, resolved, candidate (a)) is a
  defense-in-depth, early-exit optimization, not the sole enforcement
  point** — the `ship`-time recheck (already existing, unmodified by this
  design beyond the same optional-argument extension REQ-002 already
  applies uniformly to both call sites) remains a second, independent,
  mandatory enforcement point regardless (Design Decisions, above,
  candidate (a)'s own stated cost).
- **The eleven-category-to-token mapping is this design's own
  interpretation of ADR-0022's prose, not a table the ADR itself
  provides** — flagged for possible spec-review correction (ADR Change
  Log, above).
- **`build`/`test`/`installer-dry-run` as the catalog seed** (revised,
  three tokens, investigation.md INV-017) may still prove too narrow once
  a real Capability Pack is authored — accepted as a low-cost,
  additive-catalog follow-up risk rather than a reason to pre-populate a
  larger, non-正本-grounded vocabulary (Design Decisions, above).
