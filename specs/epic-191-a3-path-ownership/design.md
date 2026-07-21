# Design: epic-191-a3-path-ownership

Impl-Review-Status: Pending
Feature Type: deterministic script + Implementation Gate check + reference
documentation (component path resolver, git-diff basis, Reverse Coverage
Gate, `ownership_digest`, cross-cutting pre-registration rule, fixtures,
dual-runtime parity harness)

## Technical Summary

Six deliverables land in dependency order: a component path resolver
(T-001) that classifies paths as EXCLUSIVE/SHARED/OVERLAP/UNOWNED (with
`EXCLUDED_MATCH` evidence) against a `components[].paths`/`shared_paths`
configuration shaped per decision-document v2 §12; a git-diff collector
(T-002) that wraps the resolver with the real baseline/NUL-framing/rename/
submodule-symlink/single-writer rules §12's "v2 新設" section fixes; an
`ownership_digest` emitter (T-003) that binds the *entire* declared
ownership input (every component's paths, every `shared_paths` entry,
unconditionally — not a per-resolve-scoped subset, since per-path
classification is a function of every declared entry simultaneously) and
depends on Epic A1's canonicalizer; the Reverse Coverage Gate
`check-component-coverage` (T-004) that wires the resolver+diff collector
into `quality-gate`'s Implementation Gate, derives one of three states
(`disabled-legacy`/`advisory`/`required`) from
`workflow.capability_enforcement`/`disabled-legacy` (ADR-0016) rather than
Facet Manifest file presence — always running, always emitting a real,
producer-digest-bound evidence record regardless of state (NEW-001) — and
is registered both as a protected script (content) and as a protected
required-check-set member whose evidence is producer-digest-verified
(reachability + tamper-evidence); a cross-epic seed-inventory validation
(T-005) that treats Epic A1's `contracts/project-context.template.yaml`
as the single canonical source of the default cross-cutting seed list
(a cross-epic instruction already assigned to Epic A1 by the
orchestrator; A3 authors no competing list of its own) and proves that
inventory both matches exactly and is effective via a fixture/integration
test reading that template directly; and a dual-runtime parity harness
(T-006) that feeds
identical fixture+argv directly to the two product wrapper pairs
(`resolve-component-paths.{sh,ps1}`, `check-component-coverage.{sh,ps1}`)
and proves them behaviorally, not just nominally, identical. These T-00N
labels are a forward-looking plan for this feature's Phase 2 task
decomposition (not yet authored — see requirements.md Dependencies,
investigation.md INV-012); they organize this design document only.

The guiding principle is the same one `docs/ai-dlc-foundation-decision-v2.md`
already applies elsewhere in Foundation: no security property is asserted
by reimplementation, and no mode is selected by incidental file existence
(ADR-0016). This feature does not redefine Epic A1's schema, does not
reimplement Epic A1's canonicalizer, and does not redefine Epic A4's Facet
Manifest or Epic A1's Provider Bindings schema — it consumes each by
reference, and derives its own Gate's applicability from the same explicit
`workflow.*` axes every other capability-driven component in this
repository already reads.

## Architecture

```
project-context.yaml (Epic A1 schema; consumed, not redefined)
        │  components[].paths.{include,exclude}; shared_paths[]
        │  workflow.capability_enforcement (ADR-0016; read, not a new field)
        ▼
resolve-component-paths.py  (T-001: pure classification function)
   ├─ glob compiler (**, *, zero-segment, NFC + separator normalization,
   │    raw-path identity preserved, unsupported-meta rejection)
   ├─ shared_paths precedence check (bounded vs. cross-cutting)
   ├─ per-component (include − exclude) set arithmetic
   └─ EXCLUDED_MATCH evidence emission (Fail-5's reachable trigger)
        │  EXCLUSIVE | SHARED(bounded) | SHARED(cross-cutting) | OVERLAP | UNOWNED
        ▼
git-diff collector (T-002, invoked by the .sh/.ps1 wrappers)
   ├─ baseline = rev-parse --verify(source, target) → git merge-base
   ├─ change set = baseline..worktree ∪ untracked (NUL-framed git porcelain only)
   ├─ rename-follow (pinned threshold/limit, old + new independently classified)
   ├─ submodule/symlink → reference-only evaluation (4-case contract)
   └─ single-writer snapshot check (HEAD/index/worktree fingerprint, retry-once)
        │  resolver's own affected_components list + full ownership input
        ▼
ownership_digest emitter (T-003; binds the ENTIRE declared ownership
   input — every component's paths + every shared_paths entry,
   unconditionally, never a per-resolve-scoped subset — + matcher
   semantics version; calls Epic A1 canonicalizer — not reimplemented;
   BLOCKED until that utility exists)
        │  ownership_digest (ADR-0021 context_binding field; identical for
        │  every Feature sharing a config — selectivity moves entirely to
        │  ADR-0021's downstream semantic-output comparison)
        ▼
check-component-coverage (T-004, stage: implementation; ALWAYS RUNS)
   ├─ reads workflow.capability_enforcement/disabled-legacy (ADR-0016) to
   │    derive one of three states (NEW-001: state-aware, not a static
   │    required-check-set assumption):
   │    ├─ disabled-legacy → zero ownership evaluation; emits a real,
   │    │     producer-digest-bound evidence record, state:
   │    │     "not-applicable (disabled-legacy)"; exit 0
   │    ├─ advisory → Facet Manifest REQUIRED; full Fail-1..Fail-6
   │    │     evaluation + evidence; ALWAYS exit 0 (non-blocking)
   │    └─ required → identical evaluation to advisory; exit non-zero iff
   │          a Fail condition triggers (blocking)
   │    (both advisory/required: manifest missing/unreadable → HARD ERROR,
   │    distinct exit code, in either state)
   └─ registered in check-contract's protected required-check-set, which
        ALSO verifies the evidence's producer.sha256 against the live
        check-component-coverage.py (reachability + tamper-evidence,
        independent of the SKILL.md text below)
        │
        ▼
quality-gate ## Process (documents the new check; unprotected edit, INV-005)
   + check-contract required-check-set entry + producer-digest pass
     (protected, INV-017, NEW-001)

resolve-component-paths --diagnose (T-004, independent of the Gate above):
   Fail-1/3/5/6(cond.)-only diagnostics, any time, never Gate-blocking.

(T-005, independent of the pipeline above): NO new reference document —
Epic A1's contracts/project-context.template.yaml shared_paths section IS
the sole canonical default cross-cutting seed list (specs/**, reports/**,
docs/**, .github/**, tests/fixtures/**, CHANGELOG.md; contracts/**
excluded — stays bounded shared), embedded there per a cross-epic
instruction already assigned to Epic A1 by the orchestrator; A3's only
artifact is a fixture/integration test (REQ-007, AC-042, AC-044) that
reads that template directly and proves the inventory matches exactly and
is effective.

(T-006, independent of the pipeline above): dual-runtime parity harness —
feeds identical fixture+argv DIRECTLY to the two product wrapper pairs
(resolve-component-paths.{sh,ps1}, check-component-coverage.{sh,ps1}; T-002/
T-003 are internal stages of the former, not separate wrapper pairs),
compares canonical normalized stdout JSON / exit code / WARN category /
argv pass-through (incl. $LASTEXITCODE) directly between the two runtimes
of each wrapper — never a suite-twin-to-suite-twin comparison.
```

## Components

| Component | Responsibility | Technology | New/Existing | Protected? |
|---|---|---|---|---|
| `resolve-component-paths.py` | glob compiler (incl. zero-segment, unsupported-meta rejection, NFC+raw-identity), include/exclude/shared classification, `EXCLUDED_MATCH` evidence, NUL-framed diff collector, rename/submodule/symlink/single-writer contract | Python | new | no |
| `resolve-component-paths.sh` / `.ps1` | thin wrappers invoking the Python master (INV-008 convention) | Bash / PowerShell | new | no |
| `resolve-component-paths --diagnose` (same script, distinct subcommand/flag) | resolver-only diagnostics (Fail-1/3/5/6-cond.), never invoked by quality-gate, never Gate-blocking | Python (same wrappers) | new | no |
| `check-component-coverage.py` | Reverse Coverage Gate: reads `workflow.capability_enforcement`/`disabled-legacy` to derive `disabled-legacy` (zero evaluation, real N/A evidence) / `advisory` (full evaluation, evidence recorded, always exit 0) / `required` (full evaluation, blocking exit); every emitted evidence record carries an `emit-run-record`-conformant `producer.sha256` (NEW-001) | Python | new | **yes, once registered (T-004)** |
| `check-component-coverage.sh` / `.ps1` | thin wrappers | Bash / PowerShell | new | **yes, once registered (T-004)** |
| `plugins/sdd-quality-loop/references/guard-invariants.json` | gains **three** new `PROTECTED_GATE_SUFFIXES` entries (the three coverage-gate files — not four, corrected) | JSON | existing, human-applied | **yes (pre-existing)** |
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | **edited** — its own fixed `PHASE2_TARGETS` tuple gains the identical three entries; without this edit its `load_and_validate()` exact-match check rejects the edited `guard-invariants.json` before `--check` ever runs (INV-015) | Python | existing, **edited**, human-applied (corrects this feature's own earlier "unchanged, read-only" mischaracterization) | **yes (pre-existing)** |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` + 3 generated siblings | regenerated output reflecting the new protected entries; parity with the edited generator + JSON verified via `--check` against the staged tree | generated Python/JS/PS1/sh | existing, human-applied | **yes (pre-existing)** |
| `plugins/sdd-quality-loop/references/risk-gate-matrix.md` | gains `check-component-coverage` as a required contract-check id at `high`/`critical` tier (reachability, INV-017) | Markdown | existing, edited (unprotected, direct edit) | no |
| `plugins/sdd-quality-loop/scripts/check-contract.{sh,ps1,py}` | protected hardcoded tier-minimum set gains `check-component-coverage` at `high`/`critical`, kept equal to `risk-gate-matrix.md`'s text per `tests/gates.tests.sh` T-003's existing invariant; **additionally gains a producer-digest verification pass** that recomputes `check-component-coverage.py`'s live sha256 and rejects a `passes:true` evidence entry whose `producer.sha256` does not match (NEW-001; two-tier defense scope, ADR-0019) | Bash/PowerShell/Python | existing, edited, human-applied | **yes (pre-existing)** |
| `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` | `## Process` gains a documented `check-component-coverage` step (defense-in-depth; the required-check-set registration above is the actual reachability guarantee) | Markdown (skill) | existing, edited | no (verified, INV-005) |
| ~~`plugins/sdd-quality-loop/references/default-shared-paths.md`~~ | **withdrawn** — the default cross-cutting seed list's sole canonical source is Epic A1's own `contracts/project-context.template.yaml`; A3 authors no competing reference document (REQ-006, Dependencies) | N/A | **removed from scope** | n/a |
| `tests/fixtures/component-path-ownership/` | monorepo fixture: ≥2 components, overlapping candidate paths, nested excluded subtree, bounded `contracts/**`-shaped `shared_paths` entry, 4 submodule/symlink fixtures, NFC-collision fixture, one fixture per glob clause id, a day-one cross-epic fixture reading Epic A1's `contracts/project-context.template.yaml` directly (FAILS closed/block while absent, never a stand-in) | fixture tree | new | no |
| `tests/component-path-resolver.tests.sh` / `.ps1` | glob-semantics (incl. clause ids), overlap, unowned, exclude-misuse + `EXCLUDED_MATCH` evidence, NFC-collision cases | Bash / PowerShell | new | no |
| `tests/component-path-diff-basis.tests.sh` / `.ps1` | baseline/rev-resolution, NUL-framing, rename contract, 4 submodule/symlink cases, single-writer/TOCTOU cases | Bash / PowerShell | new | no |
| `tests/check-component-coverage.tests.sh` / `.ps1` | applicability derivation (`disabled-legacy` truthful non-evaluation, manifest-required hard error), full evaluation identical across `advisory`/`required` (only exit code/blocking differs), Fail-2/4 mutual-exclusivity, Fail-5 Gate-level reachability, Fail-6 adapter_paths, reachability (required-check-set) + producer-digest verification proof, protected-registration proof | Bash / PowerShell | new | no |
| `tests/ownership-digest.tests.sh` / `.ps1` | full ownership-input digest binding (unconditional, not a per-resolve-scoped subset), non-match stale regression, selective-stale positive/negative matrix incl. semantic-output comparison | Bash / PowerShell | new | no |
| `tests/component-path-ownership-parity.tests.sh` / `.ps1` | dual-runtime parity harness feeding identical fixture+argv DIRECTLY to the two product wrapper pairs (`resolve-component-paths.{sh,ps1}`, `check-component-coverage.{sh,ps1}`), diffing canonical normalized stdout JSON / exit code / WARN category / argv pass-through (incl. `$LASTEXITCODE`) — not a suite-twin comparison | Bash / PowerShell | new | no |
| `tests/run-all.sh` / `.ps1` | suite registration for the five new suites | Bash / PowerShell | existing, edited | no (verified) |
| `.github/workflows/test.yml` | CI step registration for the five new suites | YAML | existing, human-applied via staged candidate + `MANIFEST.sha256` | **yes** (INV-010) |
| `docs/adr/0025-component-path-ownership-resolver-semantics.md` (provisional number, re-verified at drafting time) | records glob semantics, precedence rules, six Fail-condition definitions, applicability-derivation decision, reachability-registration decision | Markdown (ADR) | new | no |
| `CHANGELOG.md` | REQ-008 doc-following surface | Markdown | existing, edited | no |

## Protected-File Statement

Verified directly against
`plugins/sdd-quality-loop/references/guard-invariants.json`, its generated
module `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`,
and `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`'s own
exact-match validation (investigation.md INV-005, INV-006, INV-010,
INV-015, INV-017) at design-authoring time. THREE different
protected-file situations apply to this feature, and they must not be
conflated:

1. **Already-protected files this feature edits indirectly (protected-
   suffix registration)**: `plugins/sdd-quality-loop/references/guard-invariants.json`,
   `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` (this is
   an **edit**, not a read-only regeneration input — its `PHASE2_TARGETS`
   tuple must gain the same three entries `guard-invariants.json` gains, or
   `load_and_validate()`'s exact-match check rejects the JSON before
   `--check` ever runs, INV-015), `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
   and its three `generated/guard-invariants.generated.{js,ps1,sh}`
   siblings, plus `.github/workflows/test.yml` — six protected files in
   this bundle (guard-invariants.json:14-19 shows the closest precedent,
   `check-contract.*`; line 40 shows `.github/workflows/test.yml`; lines
   34-39 show the guard-invariants toolchain's own self-protection). None
   of these is opened for write by any agent-run script in this feature —
   every corrected copy is staged under
   `specs/epic-191-a3-path-ownership/human-copy/<real-relative-path>` with
   a `MANIFEST.sha256` entry, exactly as `specs/epic-136-phase2-gates/human-copy/`
   (INV-007) already establishes for this *exact* file set (its own
   `MANIFEST.sha256` already carries a `generate-guard-invariants.py`
   entry — INV-015 corrects this feature's own prior claim that the
   generator was "unchanged, read-only"). A human maintainer runs the `cp`
   for each staged file and verifies its SHA-256 against the manifest, and
   runs `generate-guard-invariants.py --check` against the applied tree
   (must exit 0), before the registering task can be marked Done.

2. **Already-protected files this feature edits for reachability, not
   content-protection (required-check-set registration, INV-017)**:
   `plugins/sdd-quality-loop/scripts/check-contract.{sh,ps1,py}` (already
   R-10 protected, `guard-invariants.json:14-16`) gain
   `check-component-coverage` in their hardcoded tier-minimum set for
   `high`/`critical` — three more protected files in this bundle, staged
   the same way. This is a *different* situation from (1): it exists
   because suffix-protecting the new Gate script's own *content* does not,
   by itself, stop an agent from deleting or renaming the unprotected
   `quality-gate/SKILL.md` line that invokes it (INV-017) — registering
   `check-component-coverage` as a required contract-check id closes that
   gap independently of SKILL.md's own text. The **same** staged edit
   additionally adds a producer-digest verification pass to
   `check-contract.{sh,ps1,py}` (NEW-001; formerly a NOT_RESOLVED
   verification finding): it independently recomputes
   `check-component-coverage.py`'s live sha256 and rejects a `passes:true`
   evidence entry whose recorded `producer.sha256` field does not match —
   no additional protected file is introduced by this, only an additional
   validation pass inside the same three-file edit already staged here.
   Per the two-tier defense-claim scope this mirrors
   (`docs/adr/0019-approval-sidecar-protection.md:70-77,96-103`), this
   closes footgun/tamper-evidence exposure (an unprotected caller replaced
   and paired with a fabricated same-id `passes:true` evidence entry), not
   an unconditional adversarial-agent-proof reachability guarantee — that
   additionally depends on the protected files, the `high`/`critical`
   HMAC-signed evidence bundle, branch protection/CODEOWNERS, and human
   review as the external boundary.

3. **New files this feature creates that BECOME protected as a design
   decision, not a pre-existing fact**: `check-component-coverage.{sh,ps1,py}`
   do not exist yet (INV-001), so they cannot currently appear in
   `guard-invariants.json`. This design adds them to
   `protected_gate_suffixes` — the design decision recorded in "Design
   Decisions" below — by the same precedent `check-contract.*`/
   `check-evidence-bundle.*` already set (a deterministic, security-relevant
   Implementation Gate validator). Making this addition requires editing
   `guard-invariants.json` (situation 1, above), so it is staged the same
   way, never written directly.

No other file this feature creates or edits (`resolve-component-paths.*`,
its test suites, the fixture tree,
`risk-gate-matrix.md`, the new ADR, `CHANGELOG.md`) appears in
`PROTECTED_GATE_SUFFIXES` or `PROTECTED_GATE_PLUGIN_JSON_SUFFIXES`, and
each is agent-editable directly — `risk-gate-matrix.md` is unprotected
(not in the list read at investigation time) even though the machine-form
set it documents is protected via `check-contract.*` (situation 2, above).
`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` is likewise
unprotected (INV-005) — its `## Process` edit is a direct agent edit, not
human-copy, and is defense-in-depth documentation, not this feature's
reachability guarantee (situation 2 is). Per requirements.md's Assumptions
discipline, this is a live-repository snapshot re-verified at
design-authoring time, not a permanent guarantee; the Phase 2 task that
performs each edit re-verifies `PROTECTED_GATE_SUFFIXES`'s and
`check-contract`'s then-current contents at its own implementation-start
time.

Total staged files under `specs/epic-191-a3-path-ownership/human-copy/`:
six (situation 1) + three (situation 2) + `.github/workflows/test.yml`'s
CI-step registration (existing bundle, INV-010) = ten files, each with its
own `MANIFEST.sha256` entry.

## Layer Specifications

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | N/A — no user-facing surface; CLI/script + gate + reference doc only | ux-spec.md (N/A content — no UI to specify) | maintainers | N/A |
| Frontend | N/A — no browser/frontend surface | frontend-spec.md (N/A content — no browser/frontend surface) | maintainers | N/A |
| Infrastructure | CI suite registration for five new test pairs (incl. ownership-digest and the parity harness); `.github/workflows/test.yml` human-copy staging (T-004/T-005/T-006 share) | infra-spec.md (expands design.md Deployment/CI Plan) | maintainers | Planned |
| Security | protected-file write boundary (guard-invariants.json + generator + generated siblings + test.yml; check-contract.* required-check-set); new-script protection registration; reachability registration; submodule/symlink reference-only boundary; Provider Binding credential exclusion | security-spec.md (expands design.md Security Boundaries / Protected-File Statement) | maintainers | Planned |

This feature's spec package includes all four layer-spec files
(`ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, `security-spec.md`)
under this feature's directory, each expanding the relevant section of this
design document (Design System Compliance, Components/Architecture,
Deployment/CI Plan, and Security Boundaries/Protected-File Statement,
respectively), consistent with the repository's other `profile: full`
features.

## Design System Compliance

N/A — `ds_profile: none`. No UI application, no mockup, no visualization.

## Cross-Layer Dependencies

| From | To | Contract / Decision | REQ | AC |
|---|---|---|---|---|
| requirements.md | design.md | glob compiler semantics (`**`/`*`/zero-segment/unsupported-meta, NFC + raw identity, separator, case, empty-set clauses, NFC collision) | REQ-001 | AC-001..011 |
| requirements.md | design.md | shared/exclusive/overlap/unowned classification + exclude-misuse invariant + `EXCLUDED_MATCH` evidence | REQ-002 | AC-012..018 |
| requirements.md | design.md | git-diff basis (rev-resolution, merge-base, NUL framing, rename contract, submodule/symlink 4-case, single-writer/TOCTOU) | REQ-003 | AC-019..025 |
| requirements.md | design.md | Reverse Coverage Gate: 3-state (`disabled-legacy`/`advisory`/`required`) derived applicability, Fail-1..6 (incl. mutual-exclusivity, Gate-level Fail-5, Fail-6 adapter_paths), reachability + protected-suffix registration + evidence producer binding | REQ-004 | AC-026..036, AC-052..055 |
| requirements.md | design.md | `ownership_digest` full-input (unconditional, not per-resolve-scoped) binding, ADR-0021 binding, selective-stale matrix, suite wiring | REQ-005 | AC-037..041 |
| requirements.md | design.md | cross-epic seed-inventory single-source-of-truth (Epic A1's `contracts/project-context.template.yaml`, no A3-authored competing list) + inventory-conformance and day-one integration proof + `contracts/**` exclusion | REQ-006 | AC-042..044 |
| requirements.md | design.md | monorepo fixture + sh/ps1 suites (incl. contracts bounded-shared, submodule/symlink, NFC-collision, glob-clause fixtures) | REQ-007 | AC-045..047 |
| requirements.md | design.md | ADR authorship, CHANGELOG, version-bump discipline, single-source count discipline | REQ-008 | AC-048..049 |
| requirements.md | design.md | dual-runtime parity harness (product-wrapper-direct comparison) + its own CI registration | REQ-009 | AC-050..051 |
| requirements.md | ADR-0021 | `ownership_digest` context_binding shape + semantic-output exclusion + full-input binding | REQ-005 | AC-037, AC-038 |
| requirements.md | ADR-0017 | Gate stage classification (`stage: implementation`) | REQ-004 | AC-030 |
| requirements.md | ADR-0016 | 3-state derivation (`disabled-legacy`/`advisory`/`required`) from `capability_enforcement`, never file presence | REQ-004 | AC-026, AC-027, AC-028, AC-029, AC-052, AC-053 |

## ADR Change Log

**New ADR**: provisionally `docs/adr/0025-component-path-ownership-resolver-semantics.md`
(investigation.md INV-014 — `0025` is the next free number as of this
investigation; re-verified via `ls docs/adr/` at drafting time, renumbering
if a concurrent merge has occupied it, per the precedent
`specs/epic-159-pillar-c/design.md:201-236` set for ADR-0012). This ADR
records: (a) the glob-matching algorithm (`**`/`*` semantics incl.
zero-segment, unsupported-metacharacter rejection, NFC + raw-identity
normalization, separator, case-sensitivity rule) as a NEW design decision
this feature establishes; (b) the shared-vs-exclusive precedence order and
the bounded-vs-cross-cutting `shared_paths` shapes, including
`contracts/**` remaining a bounded (not cross-cutting) example; (c) the six
Fail-condition definitions (Fail-1 through Fail-6), including the Fail-2/
Fail-4 mutual-exclusivity fix, Fail-5's `EXCLUDED_MATCH`-driven Gate-level
reachability, and Fail-6's `adapter_paths` rule, as this feature's
authoritative, unambiguous formalization of decision-document v2 §12's
one-line list; (d) `check-component-coverage`'s three-state applicability
derivation (`disabled-legacy`/`advisory`/`required`) from
`workflow.capability_enforcement`/`disabled-legacy` (ADR-0016) instead of
Facet Manifest file presence, why the earlier file-presence-driven design
was rejected, and why an earlier two-bucket ("capability-active" merging
`advisory` and `required`) draft was also rejected as silently promoting
`advisory` to `required`'s blocking strength (NEW-001); (e) the decision to
register `check-component-coverage.{sh,ps1,py}` as a new protected-gate-
suffix entry *and* as a required contract-check id in `check-contract`'s
protected tier-minimum set (two independent registrations, one for
content, one for reachability); (f) the evidence producer-binding decision
(NEW-001, formerly a NOT_RESOLVED verification finding): every
`check-component-coverage` evidence record, in any state, is an
`emit-run-record`-conformant record carrying a `producer.sha256`
`check-contract` independently verifies against the live script, and why
this is scoped as footgun-prevention/tamper-evidence rather than an
unconditional adversarial-agent-proof reachability claim (two-tier defense
scope, ADR-0019). No existing ADR currently states any of these — ADR-0021
fixes `ownership_digest`'s *binding* shape (which this ADR references, not
restates) but not the resolver's own matching algorithm; ADR-0017 fixes
the Gate *stage* model (`stage: implementation`, referenced not restated)
but not this Gate's specific Fail conditions; ADR-0016 fixes the *axis*
model (referenced, not restated) but not this Gate's own three-state
consumption of it, nor the evidence producer-binding mechanism.

**Drafting ownership**: authored as part of the Phase 2 task that
implements T-001 (the resolver's matching algorithm is the change this ADR
records), in the same commit that adds `resolve-component-paths.py` —
mirroring `specs/epic-159-pillar-c/design.md:224-236`'s ADR-0012 drafting
ownership precedent.

## Data Plan

Data Entities:

- Component path config (Epic A1 schema, consumed not redefined, hard
  schema-shape dependency per requirements.md Dependencies):
  `components[].paths.include: string[]`, `components[].paths.exclude:
  string[]`, `shared_paths[]` (`pattern: string`, and either `components:
  string[]` or `classification: "cross-cutting"`); also read (not
  redefined): `workflow.capability_enforcement` (ADR-0016).
- Resolver output (new, this feature's own shape — not a repository
  contract file, an in-process/CLI JSON structure `resolve-component-paths`
  emits): per changed path, `{raw_path, normalized_path,
  classification: EXCLUSIVE|SHARED_BOUNDED|SHARED_CROSS_CUTTING|OVERLAP|
  UNOWNED, owning_components: string[], evidence:
  {excluded_match: {component, pattern}[] | null}}`, sorted by `raw_path`
  bytes (stable, deterministic even under an NFC-collision, AC-010); plus
  a top-level `affected_components: string[]` (the union of all EXCLUSIVE
  owners and all bounded-`shared_paths` declared components actually
  touched) and `ownership_input` (**every** component's `paths` entries and
  **every** `shared_paths` entry declared in the config, unconditionally —
  not a per-resolve-scoped subset of what this particular diff touched —
  plus the matcher semantics/rule-set version; input to `ownership_digest`,
  REQ-005; identical across every resolve against the same config).
- `ownership_digest` (new, ADR-0021 `context_binding` field, T-003):
  `sha256:...`, computed over the canonicalized, *complete*
  `ownership_input` (every declared entry, matched or not, for this or any
  other resolve against the same config) via Epic A1's canonicalizer —
  identical for every Feature sharing a config, changing only when the
  config's ownership section (or the matcher semantics version) itself
  changes.
- Gate verdict / evidence record (new, `check-component-coverage`'s own
  output, consumed by `quality-gate`'s evidence bundle; emitted in **every**
  derived state, NEW-001): `{schema: "check-component-coverage-verdict/v1",
  check_id: "check-component-coverage", producer: {script:
  "plugins/sdd-quality-loop/scripts/check-component-coverage.py", sha256:
  "<hex>"}, state: "not-applicable (disabled-legacy)"|"advisory"|
  "required", manifest_status: "not-consulted"|"present"|"missing"|
  "unreadable", fail_conditions: [{id: "Fail-1".."Fail-6", triggered: bool,
  detail}], warnings: string[]}`. In `disabled-legacy`,
  `manifest_status: "not-consulted"` and `fail_conditions: []` — a real,
  truthful record of a genuine no-op execution, not an absent object and
  not a fabricated pass. In `advisory`/`required` with
  `manifest_status != "present"`, `fail_conditions` is empty/absent and a
  top-level `error` field carries the hard-error diagnostic instead
  (distinct exit code from an ordinary Fail-condition trigger). In
  `advisory`, exit is always 0 regardless of `fail_conditions`; in
  `required`, exit is non-zero iff any `fail_conditions[].triggered` is
  true. The `producer.sha256` field is what `check-contract`'s producer-
  digest verification pass (Dependencies, AC-055) independently
  recomputes and compares against the live `check-component-coverage.py`.
- `specs/epic-191-a3-path-ownership/human-copy/` (new, committed as a
  review artifact — never deleted by any test): staged corrected
  `guard-invariants.json`, `generate-guard-invariants.py`, the four
  regenerated `generated/*` files, `check-contract.{sh,ps1,py}`, and the
  `.github/workflows/test.yml` candidate, plus `MANIFEST.sha256` (ten
  entries).

Existing Data Affected: `guard-invariants.json`, `generate-guard-invariants.py`
and its generated siblings, `check-contract.{sh,ps1,py}`, and
`.github/workflows/test.yml` are read but never written by any agent-run
script in this feature (Protected-File Statement).

Migration Strategy: none. No database, no runtime storage, and no schema
migration exists anywhere in this feature (infra-spec.md's Data Residency
and Retention section: "No database, no migration, no runtime storage
anywhere in this feature"). The three new data shapes this feature
introduces — the resolver output structure, `ownership_digest`, and the
`check-component-coverage-verdict/v1` Gate evidence record — are each a
net-new, additive artifact with no prior version to migrate from or
reconcile against; they are consumed by `quality-gate`'s existing evidence
bundle under that bundle's own already-established conventions, not a new
storage or compatibility mechanism this feature defines.

## API / Contract Plan

### `resolve-component-paths.sh`/`.ps1` (T-001/T-002)

Invocation shape: `resolve-component-paths --config <project-context.yaml>
[--source-rev HEAD] --target-rev main [--include-untracked] [--json]`.
Both `--source-rev` (default `HEAD`) and `--target-rev` (required, a
complete ref/OID) are resolved via `git rev-parse --verify <rev>^{commit}`
before `git merge-base` is computed. Exit code 0 on a clean resolve (even
with UNOWNED/OVERLAP results present in the JSON output — classification
results are data, not failure by themselves; only
`check-component-coverage`, T-004, turns a classification into a Gate
Fail). Non-zero exit on a config-shape error (REQ-002's fail-closed
`shared_paths` shape check, or an unsupported-metacharacter pattern,
REQ-001), an unresolvable rev or unattainable `git merge-base` (REQ-003),
an NFC-collision (REQ-001), an exceeded rename limit (REQ-003), or a
single-writer/TOCTOU mismatch after one retry (REQ-003).

### `resolve-component-paths --diagnose` (T-004, resolver-only diagnostics)

Same script, a distinct subcommand/flag, no `--facet-manifest` input:
emits Fail-1/3/5/6(conditional)-only findings for early feedback. Never
invoked by `quality-gate`'s `## Process`; its exit code carries no
Implementation Gate meaning.

### `check-component-coverage.sh`/`.ps1` (T-004)

Invocation shape: `check-component-coverage --config <project-context.yaml>
[--source-rev HEAD] --target-rev main --facet-manifest <path>`. The script
**always runs to completion and always emits an evidence record** (Data
Plan) with a `producer.sha256` binding — never a bare skip line with no
evidence artifact (NEW-001). It first reads
`workflow.capability_enforcement`/the ADR-0016 file-absence fallback from
`--config` to derive one of three states:

- `disabled-legacy` → zero ownership Fail-condition evaluation;
  `--facet-manifest` is not consulted at all in this state (accepted but
  ignored, never validated for existence); emits the evidence record with
  `state: "not-applicable (disabled-legacy)"`, `manifest_status:
  "not-consulted"`, `fail_conditions: []`; exit 0.
- `advisory` → `--facet-manifest` is structurally required (its absence
  from the invocation is a usage error, distinct from the
  manifest-unreadable case below); when the supplied path is missing or
  unreadable, exit with a **hard-error** code (distinct from an ordinary
  Fail-condition exit) and an `error` diagnostic (Data Plan) — never a
  WARN + exit 0. When present and readable, all six Fail conditions are
  evaluated and recorded in the evidence output, but exit is **always 0**
  regardless of any `fail_conditions[].triggered` value — evaluated and
  recorded, never blocking.
- `required` → identical Facet-Manifest-required/hard-error behavior and
  full six-Fail-condition evaluation as `advisory`, but exit is non-zero
  **iff** at least one Fail condition triggers.

In both `advisory` and `required`, WARN-only conditions (N/A Fail-6 with
no Provider Bindings file; WARN "evaluation not possible" Fail-6 when a
binding lacks `adapter_paths`) never affect exit code by themselves.

### `plugins/sdd-quality-loop/references/guard-invariants.json` (human-applied)

Three new entries appended to `protected_gate_suffixes`:
`plugins/sdd-quality-loop/scripts/check-component-coverage.sh`,
`plugins/sdd-quality-loop/scripts/check-component-coverage.ps1`,
`plugins/sdd-quality-loop/scripts/check-component-coverage.py`. No other
key in the file changes.

### `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` (human-applied, edited not merely regenerated)

`PHASE2_TARGETS` (currently lines 37-56) gains the identical three entries
listed above, in the same relative order `guard-invariants.json`'s
`protected_gate_suffixes` places them, so `load_and_validate()`'s exact-
match comparison (`expected_protected = BASELINE_SUFFIXES + (PHASE2_TARGETS
not already in BASELINE_SUFFIXES)`, lines 145-147) continues to hold. No
other constant in this file changes.

### `plugins/sdd-quality-loop/references/risk-gate-matrix.md` (direct edit) + `check-contract.{sh,ps1,py}` (human-applied)

`risk-gate-matrix.md`'s "Required check ids (machine form)" gains
`check-component-coverage` in the `high` (and therefore `critical`, by the
superset rule) tier set, alongside `requirement-traceability`. The
identical id is added to `check-contract`'s own hardcoded machine-form
set, kept equal per `tests/gates.tests.sh` T-003's existing invariant. This
registration is independent of, and does not replace, the
`quality-gate/SKILL.md` `## Process` documentation edit. **New in this
feature (NEW-001, AC-054/AC-055)**: `check-contract`'s validation for the
`check-component-coverage` check id is extended with a producer-digest
pass — when that check's `passes:true`, `check-contract` reads its
`evidence` path's JSON, requires a `producer.sha256` field, independently
computes the live sha256 of `check-component-coverage.py`, and fails the
contract if the two do not match (or if `producer` is absent). This is an
addition to the same staged human-copy edit `check-contract.{sh,ps1,py}`
already receives above — no new protected-file family, only a new
validation pass within it.

## Test Strategy

Each of the five new suites (`component-path-resolver`,
`component-path-diff-basis`, `check-component-coverage`,
`ownership-digest`, `component-path-ownership-parity`) is fixture-driven
against `tests/fixtures/component-path-ownership/`, deterministic, and
requires no LLM invocation, no network call, and no `gh` invocation.

- `component-path-resolver.tests.sh`/`.ps1`: glob semantics incl. every
  clause id (AC-001..009, the shared zero-match clause AC-009 fixing no
  Fail-4 trigger without implying any `ownership_digest` scope exemption),
  the NFC-collision + raw-identity/stable-sort case (AC-010), the A1
  schema-conformance fixture (AC-011, **FAIL-closed on schema absence** —
  never a skip or conditional pass, so this suite fails deterministically
  while Epic A1's schema is unlanded or divergent), exclusive/shared/
  overlap/unowned classification (AC-012, AC-015..017), the exclude-misuse
  invariant and its `EXCLUDED_MATCH` evidence (AC-013, AC-014), and the
  `shared_paths` config-shape fail-closed check (AC-018).
- `component-path-diff-basis.tests.sh`/`.ps1`: rev-resolution + merge-base
  baseline and its fail-closed unattainable case (AC-019), untracked+
  staged+unstaged collection without double counting (AC-020), NUL-safe
  framing incl. TAB/LF/invalid-UTF-8 fixtures (AC-021), rename-follow
  including the cross-component case and the pinned threshold/limit
  contract (AC-022, AC-023), the four submodule/symlink fixtures
  (AC-024), and the single-writer/TOCTOU retry-then-fail-closed case
  (AC-025).
- `check-component-coverage.tests.sh`/`.ps1`: applicability derivation
  (`disabled-legacy` runs, evaluates nothing, and emits a real, truthful
  `state: "not-applicable (disabled-legacy)"` evidence record regardless
  of manifest-file presence, AC-026, AC-027; manifest-required hard error
  in `advisory` or `required`, AC-028; resolver-only diagnostics never
  Gate-invoked, AC-029), one dedicated fixture per Fail-1..Fail-6,
  identically evaluated in both `advisory` and `required` (AC-030), the
  Fail-2/Fail-4 mutual-exclusivity boundary fixture (AC-031), Fail-5's
  Gate-level `EXCLUDED_MATCH`-driven reachability fixture (AC-032),
  Fail-6's `adapter_paths` rule and its own N/A-when-absent case (AC-033,
  AC-034), `advisory` non-blocking exit-0-despite-Fail-trigger (AC-052),
  `required` blocking exit-non-zero-iff-Fail-trigger (AC-053), the
  reachability/required-check-set fixture (SKILL.md-deletion /
  script-rename still fails the Gate, AC-035, scoped to the two-tier
  footgun/tamper-evidence claim, not unconditional adversarial-agent
  reachability), the evidence producer-binding + `emit-run-record`
  conformance fixture across all three states (AC-054), the
  `check-contract` producer-digest verification fixture (a substituted
  script + stale/unrelated evidence fails the contract, AC-055), and the
  protected-suffix + generator-inventory registration proof (staged
  six-file candidate set with a correct manifest;
  `generate-guard-invariants.py --check` exits 0 against the staged tree;
  the live files are byte-unchanged before/after; a post-human-copy
  self-registration grep confirms the three `check-component-coverage.*`
  entries are present) mirroring `specs/epic-159-pillar-c/acceptance-tests.md`'s
  TEST-027 multi-part shape (AC-036).
- `ownership-digest.tests.sh`/`.ps1`: full ownership-**input** digest
  binding — the entire declared config, unconditionally, never a
  per-resolve-scoped subset — incl. non-matching entries and the
  matcher-semantics-version component (AC-037), presence in
  `context_binding` and semantic-output exclusion (AC-038), the non-match
  stale regression as a specific instance of the full-input guarantee
  (AC-039), and the full selective-stale positive/negative matrix proving
  selectivity now lives entirely in ADR-0021's semantic-output comparison,
  never in the digest's own scope (AC-040) — this suite's own registration
  in `tests/run-all.sh`/`.ps1`, `.github/workflows/test.yml`, and this
  design document's own Components table is itself self-tested (AC-041),
  closing the gap where an earlier draft assigned TEST-021/022 to a suite
  pair this design never wired in.
- `component-path-ownership-parity.tests.sh`/`.ps1`: feeds identical
  fixture+argv **directly to each product wrapper pair**
  (`resolve-component-paths.{sh,ps1}`, `check-component-coverage.{sh,ps1}`
  — the only two product wrapper pairs this feature ships) and diffs the
  **canonical normalized stdout JSON** form (defined below), exit code,
  WARN/error category, and argv pass-through (incl. `$LASTEXITCODE`)
  directly between each wrapper's two runtimes — never a suite-twin-to-
  suite-twin comparison (AC-050); its own registration is likewise
  verified (AC-051).

**Canonical normalized stdout JSON form** (REQ-009, used by the parity
harness only): parse each wrapper's stdout as JSON — a parse failure is
itself a parity-harness failure — then re-serialize with object keys
sorted lexicographically at every nesting level, arrays left in their
original order (order is itself semantically meaningful, e.g. the
resolver's raw-path stable sort, AC-010), numbers in canonical minimal
form, and no trailing whitespace or newline; the two wrappers'
re-serialized forms are then compared byte-for-byte. This single
definition is what makes "byte-for-byte identical" unambiguous across
both wrapper pairs.
- REQ-006's fixtures — the cross-epic inventory-conformance fixture that
  reads Epic A1's `contracts/project-context.template.yaml` directly and
  asserts its six-entry cross-cutting set matches exactly (AC-042), the
  no-op proof that a diff confined to those entries never trips Fail-1
  (AC-043), and the day-one cross-epic integration proof (AC-044) — and
  REQ-007's overall fixture-tree shape (AC-045, AC-046, AC-047), including
  the `contracts/**` bounded-shared Fail-4 fixture (AC-046), are shared
  across the suites above rather than owned by a sixth.

CI resilience (mirroring `specs/epic-159-pillar-c/tasks.md` Global
Constraints' own convention): no possibly-empty array expanded under
`set -u`; every mktemp root normalized with `pwd -P` immediately after
creation; any `jq` output consumption piped through `tr -d '\r'`
unconditionally; no suite drives a real validator gate directly.

## Design Decisions (resolving open questions)

- **Glob semantics** (REQ-001): `**` = zero or more whole path segments
  (including the zero-segment case), crossing `/`; bare `*` = within one
  segment only; `?`/`[...]`/regex are explicitly unsupported and rejected
  at load time — a deliberately restricted subset, chosen for the same
  determinism rationale decision-document v2 §11 (Q10) already applies to
  Predicate DSL conditions, extended here by this feature's own design
  authority (Q10's DSL and this feature's glob patterns are different
  mechanisms; this design decision is new, not inherited).
- **Path/case normalization and raw-identity preservation** (REQ-001):
  comparison inputs (both pattern strings and `git`-reported paths) are
  NFC-normalized and `\`→`/` normalized before compilation *for matching
  purposes only*; every output record separately preserves the path's
  original raw bytes for identity and stable-sort ordering, and two
  distinct raw paths colliding under NFC normalization is a fail-closed
  configuration error, never a silent merge — chosen because a matching
  algorithm that discards raw identity cannot distinguish "the same file,
  differently encoded" from "two different files that happen to
  normalize identically," and the latter must never be silently
  conflated.
- **shared_paths precedence** (REQ-002): a `shared_paths` match is checked
  BEFORE per-component `(include − exclude)` classification and, when
  matched, exempts the path from OVERLAP/UNOWNED entirely — chosen because
  it gives config authors an unambiguous escape hatch (declare it shared)
  for any path that would otherwise need increasingly precise
  include/exclude patterns across every component. This also makes
  EXCLUSIVE and bounded-SHARED mutually exclusive classifications for any
  single path, which is what makes Fail-2/Fail-4 mutual exclusivity
  (below) a structural guarantee rather than an ad hoc rule.
- **`shared_paths` entry shape** (REQ-002): exactly one of `components:
  [...]` (bounded) or `classification: cross-cutting` (unbounded) — chosen
  to keep Fail-4's check simple and total (bounded entries always have a
  concrete list to check the Facet Manifest against; cross-cutting entries
  are always exempt, never partially so). `contracts/**` is a bounded
  example (decision-document v2 §12's own `components: [desktop-client,
  sync-api]`), never promoted to the unbounded cross-cutting seed list
  (REQ-006) — doing so would silently drop the very component enumeration
  Fail-4 needs to check for it.
- **`EXCLUDED_MATCH` evidence** (REQ-002): the resolver emits this tag
  whenever an UNOWNED classification's cause is every otherwise-matching
  component's `exclude` list, distinct from an ordinary "no `include`
  ever matched" UNOWNED record — chosen so Fail-5 has a concrete,
  Gate-reachable trigger (below) instead of relying solely on a
  resolver-level invariant test to argue the case can never occur in
  practice.
- **Fail-2/Fail-4 mutual exclusivity** (REQ-004): Fail-2 fires only for an
  EXCLUSIVE-owner mismatch; Fail-4 fires only for a bounded
  `shared_paths` entry's declared-components shortfall — corrected from an
  earlier draft where Fail-2's definition also covered "a required party
  to a matched bounded shared_paths entry," duplicating Fail-4's own
  condition for the identical underlying event. Because `shared_paths`
  precedence (above) makes EXCLUSIVE and bounded-SHARED mutually
  exclusive per path, this scoping is a structural guarantee, not a
  runtime coincidence — chosen over a cross-path aggregation rule
  (considered and rejected, investigation.md OQ discussion) because it is
  simpler, total, and independently testable per fixture.
- **Fail-5 as a Gate-reachable check, not only an assertion** (REQ-002/
  REQ-004): the exclude-as-include invariant is enforced by the `(include
  − exclude)` set arithmetic itself, AND surfaced via `EXCLUDED_MATCH`
  evidence the Gate consumes against real Facet Manifest data as an
  ordinary runtime path — corrected from an earlier draft that treated
  Fail-5 as reachable only via a mutation/invariant test, which the
  acceptance-tests.md package nonetheless (inconsistently) required a
  dedicated runtime fixture for.
- **Fail-6 scope and `adapter_paths`** (REQ-004): conditional on
  `sdd/provider-bindings.yaml` existing; join key is the component's
  `provider_binding_ids` field (already fixed by decision-document v2
  §5/§12); the exact sub-path rule (OQ-001, resolved) is a new optional
  `adapter_paths: string[]` glob-array field per binding, matched with
  REQ-001's own glob engine — a schema addition attributed to Epic A1
  (Dependencies), not defined by this feature. A binding lacking
  `adapter_paths` is WARN "evaluation not possible," distinct from the
  file-absent N/A case, so the gap in evaluability is always visible.
- **Capability-derived, three-state Gate applicability — always running,
  never file-presence-derived** (REQ-004, ADR-0016, NEW-001): rejects an
  earlier draft's degraded/resolver-only mode keyed off Facet Manifest
  file presence — the exact anti-pattern ADR-0016 forbids (INV-016) — and
  a *later* draft's two-bucket "capability-active" model that merged
  `advisory` and `required` into identical blocking behavior, silently
  promoting `advisory` to `required`'s enforcement strength (NEW-001,
  INV-018; contrary to ADR-0016's own "governs whether capability-specific
  gates are advisory or required" distinction,
  `docs/adr/0016-workflow-axes-separation.md:44-45`). Instead,
  `check-component-coverage` **always runs to completion and always emits
  a real, producer-digest-bound evidence record** (Data Plan), deriving
  one of three states from `workflow.capability_enforcement`/
  `disabled-legacy`: `disabled-legacy` (zero evaluation, a truthful
  `state: "not-applicable (disabled-legacy)"` record, exit 0); `advisory`
  (Facet Manifest required, hard error if missing/unreadable, full
  six-Fail-condition evaluation and recording, but always exit 0 —
  non-blocking); `required` (identical evaluation, exit non-zero iff a
  Fail condition triggers — blocking). Always running and always emitting
  evidence, rather than "not invoked at all" in `disabled-legacy`, is what
  keeps `check-contract`'s required-check-set satisfiable with genuine,
  non-fabricated evidence in every state (NEW-001). The Fail-1/3/5/6-
  conditional resolver-only checks are retained but repackaged as an
  independent, non-Gate diagnostic command, never a Gate mode. This
  resolves the Epic A4 forward dependency (INV-003) by construction: a
  project only sets `capability_enforcement` to `advisory` or `required`
  once the pipeline it depends on (Facet Manifest generation, Epic A4/A5)
  is operational (epic sequencing, §19), so the "evaluating but manifest
  genuinely unavailable" case is a visible, intentional hard error, not a
  steady-state mode requiring a silent WARN-and-continue design.
- **Protected-gate-suffix registration + generator-inventory parity**
  (REQ-004, INV-006, INV-015): chosen by direct precedent
  (`check-contract.*`/`check-evidence-bundle.*`, INV-006) — a
  deterministic, security-relevant Implementation Gate validator whose
  purpose (preventing `affected_components` under-reporting) would be
  defeated by an agent that could edit or bypass it. Corrected from an
  earlier draft that omitted `generate-guard-invariants.py`'s own
  `PHASE2_TARGETS` tuple from the staged edit set — its exact-match
  validation makes that omission a guaranteed rejection, not a latent risk
  (INV-015), and the epic-136 precedent this feature cites already staged
  exactly this file.
- **Protected required-check-set registration, independent of suffix
  protection** (REQ-004, INV-017): chosen because suffix-protecting
  `check-component-coverage.*`'s own content does not prevent an agent
  from deleting or renaming the unprotected `quality-gate/SKILL.md` line
  that invokes it — registering the check as a required contract-check id
  in `check-contract`'s already-protected tier-minimum set (mirrored in
  the unprotected `risk-gate-matrix.md` documentation, kept in sync per
  `tests/gates.tests.sh` T-003's existing invariant) gives this Gate the
  same reachability guarantee every tier-minimum-registered check already
  has, independent of SKILL.md's own text.
- **`ownership_digest` binds the entire declared ownership input（宣言され
  た全 ownership 入力）, never a consumed/evaluated subset** (REQ-005):
  corrected from an earlier draft that bound only the matched
  component/shared-path entries, which left a blind spot where a
  previously non-matching pattern's edit (now matching the same
  changed-path set) would not change the digest — defeating ADR-0021's
  own staleness rationale, which requires the digest to widen to the
  complete declared ownership input rather than only what a given resolve
  happened to consume or evaluate
  (`docs/adr/0021-context-projection-staleness.md` lines 48-53).
- **Dual-runtime parity harness, independent of each suite's own
  same-language assertions** (REQ-009): chosen because "both `.sh` and
  `.ps1` files exist and each independently passes" does not prove the two
  runtimes behave identically — a harness that feeds identical
  fixture+argv to both and diffs normalized output directly is the only
  way to catch a `.ps1`-only argument-handling or `$LASTEXITCODE` defect
  that each suite's own separately-authored assertions could miss.
- **T-001/T-002 not hard-blocked on Epic A1 landing, but T-001's Done
  state gains a FAIL-closed conformance gate** (OQ-002, Dependencies): the
  resolver's fixtures are authored against decision-document v2 §12's
  already-fixed field shape, and implementation may proceed now
  (unblocked); T-001's own **Done** state additionally requires the
  schema-conformance fixture (requirements.md AC-011), authored as part of
  T-001's own test suite from the start, to FAIL deterministically — never
  skip or conditionally pass — while Epic A1's schema is unlanded or
  divergent, and only then to pass once it actually lands and matches — a
  middle path between "fully blocked from starting implementation" and
  "reconciliation is a mere follow-up with no enforcement," corrected from
  an earlier draft whose conditional "once Epic A1's schema lands" phrasing
  left the FAIL-on-absence behavior ambiguous and untracked by any actual
  test. T-003 (canonicalizer) and part of T-004 (Facet Manifest artifact,
  not merely shape) remain hard-blocked on their respective epics landing
  as artifacts.
- **Cross-cutting seed inventory: single canonical source, no A3-authored
  copy** (REQ-006, new): an earlier draft had A3 author its own reference
  document (`plugins/sdd-quality-loop/references/default-shared-paths.md`)
  as the canonical seed list for Epic A1's template to embed — this
  created two documents (A3's list, A1's embedded copy) that could
  silently drift apart. This design instead treats Epic A1's shipped
  `contracts/project-context.template.yaml` `shared_paths` section as the
  **sole** canonical source (`specs/**`, `reports/**`, `docs/**`,
  `.github/**`, `tests/fixtures/**`, `CHANGELOG.md`, all cross-cutting;
  `docs/**` subsumes the narrower `docs/adr/**`); A3 authors no competing
  list, and REQ-007's day-one fixture reads that template artifact
  directly once it lands — FAILING closed (block), never passing via a
  stand-in, while it is absent — rather than a fixture built from A3's own
  now-withdrawn document — closing the divergence risk by construction
  rather than by a periodic manual sync.

## Global Constraints

- **Two-commit landing plan per Phase-2 task** (implementation + docs),
  the same convention `specs/epic-159-pillar-c/tasks.md` Global Constraints
  established, is recorded here for that future phase to apply; it does
  not change this spec-phase package's own commit structure (Task 1 =
  spec package, Task 2 = registration, per this feature's own delivery
  instructions).
- **Version bumps only via `scripts/bump-version.sh`**; this feature
  introduces no version-mutation path.
- **`tests/run-all.sh`/`.ps1`**: direct edits, one array-append per new
  suite, serialized T-001 → T-002 → T-003 → T-004 → T-006 (T-005 shares
  T-001's fixture, no new suite of its own).
- **`.github/workflows/test.yml`**: human-copy staged, same serialization,
  so no two Phase-2 tasks' staged candidates race each other under
  `specs/epic-191-a3-path-ownership/human-copy/`.
- **`guard-invariants.json` + `generate-guard-invariants.py` + generated
  siblings**: T-004 is the sole editor (via human-copy) within this
  feature.
- **`check-contract.{sh,ps1,py}` + `risk-gate-matrix.md`**: T-004 is the
  sole editor of both (protected via human-copy for the former, direct
  edit for the latter) within this feature.
- Preserve unrelated changes; implement one task at a time (once Phase 2
  authors `tasks.md`).

## Security Boundaries

See requirements.md Security Boundaries; this design additionally notes:
`check-component-coverage`'s own verdict object (Data Plan) never embeds
raw file contents from a changed path — only path strings and component
ids — so the Gate's evidence output cannot itself become a channel for
smuggling sensitive file content into a report artifact. Suffix-protecting
`check-component-coverage.*`'s content (situation 1, Protected-File
Statement) and registering it as a required contract-check id (situation
2) are two independent boundaries; neither alone is sufficient (INV-017).
The producer-digest verification pass (NEW-001, situation 2, Data Plan)
adds a third: it does not by itself make either boundary unconditionally
adversarial-agent-proof (that additionally requires the external boundary
— protected files, HMAC-signed evidence bundle, branch protection,
human review, per the two-tier defense scope this mirrors from
ADR-0019) — it closes the specific, narrower gap where a same-id
`passes:true` evidence entry could point at any pre-existing file
regardless of which script actually produced it.

## External Integrations

None. This feature calls only local `git` plumbing commands and (T-003) a
local Epic A1 canonicalizer utility — no network call, no external
service, no `gh` invocation.

## Deployment / CI Plan

Five new `.sh`/`.ps1` suite pairs (`component-path-resolver`,
`component-path-diff-basis`, `check-component-coverage`,
`ownership-digest`, `component-path-ownership-parity`) register in
`tests/run-all.sh`/`.ps1` (direct edit) and stage their CI step additions
into `.github/workflows/test.yml` via human-copy (INV-010). No new CI
job/matrix dimension is introduced — the new suites run in the existing
deterministic, 3-OS lane alongside `agent-model-routing`,
`render-agent-frontmatter`, etc.

This feature's own rollout is staged, not all-or-nothing: `check-component-
coverage`'s three-state capability-derived applicability model
(`disabled-legacy`/`advisory`/`required`, REQ-004, ADR-0016 — see
Architecture and Design Decisions "Capability-derived, three-state Gate
applicability") is the mechanism that governs whether the newly-registered
required-check-set entry actually blocks a consuming project's
Implementation Gate. This repository's own immediate adoption of this CI
registration resolves to the safe, non-blocking `disabled-legacy` path via
the ADR-0016 file-absence fallback, because no `project-context.yaml`
exists in this repository yet (investigation.md INV-002) and
`check-contract`'s tier-minimum set has no capability-state axis of its own
to consult (investigation.md INV-018) — the Gate still runs and records a
real `state: "not-applicable (disabled-legacy)"` evidence entry (Data Plan,
NEW-001) rather than an unexpected block. No separate feature-flag
mechanism, canary stage, or phased CI rollout beyond this existing
capability axis is introduced by this feature (Security Boundaries B5).

## Constraint Compliance

| Constraint | How this feature complies |
|---|---|
| Protected-file write boundary | See Protected-File Statement; every protected-path edit (guard-invariants.json bundle, check-contract bundle) is staged under `human-copy/` |
| CI resilience (no unbound `set -u` array, `pwd -P`, `tr -d '\r'`) | Test Strategy |
| Doc-following (REQ-008) | ADR Change Log; CHANGELOG entries per Phase-2 task; single-source count discipline |
| Version-bump discipline | Global Constraints |
| No Registry/Epic A2 coupling | Architecture — Gate wired directly into `quality-gate`'s `## Process` (+ required-check-set), no Registry projection dependency |
| No file-presence mode selection | ADR-0016 — Design Decisions "Capability-derived Gate applicability" |
| Cross-OS path semantics (requirements.md Target Users, lines 64-69: "path and case semantics must not depend on host OS") | Design Decisions "Glob semantics" and "Path/case normalization and raw-identity preservation"; REQ-009's dual-runtime parity harness proves the `.sh`/`.ps1` wrappers behaviorally identical, not merely both present |
| Submodule/symlink reference-only boundary (requirements.md Security Boundaries) | Architecture (git-diff collector's "submodule/symlink → reference-only evaluation"); Security Boundaries; security-spec.md Trust Boundaries B4 |
| Fail-6 credential exclusion (requirements.md Security Boundaries) | Security Boundaries; security-spec.md Secrets Management — Fail-6 never reads `sdd/provider-bindings.yaml`'s `credentials` block |

## Assumptions

Carried from requirements.md Assumptions; additionally: this design assumes
`quality-gate`'s `## Process` section (`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:30-204`)
is structured as an ordered list of named checks that a new check can be
appended to without restructuring the surrounding checks, and that
`risk-gate-matrix.md`'s "Required check ids (machine form)" section and
`check-contract`'s hardcoded tier-minimum set can each accept one more id
without restructuring their own existing sets — both verified at Phase-2
implementation time, not asserted as unconditionally permanent.

## Open Questions

Carried from requirements.md Open Questions (OQ-002; OQ-001 is resolved —
see requirements.md Dependencies, Design Decisions "Fail-6 scope"); no new
open question is introduced at design time.

## Risks

Carried from requirements.md Risks. Additionally: authoring the new ADR
(0025, provisional) in the same commit as T-001 (ADR Change Log) risks a
renumbering collision if a sibling Epic-191 sub-feature (A1/A2, both
currently in-flight in sibling worktrees per this session's own
coordination) claims `0025` first — mitigated by the explicit
re-verify-at-drafting-time instruction already carried from the
`ADR-0012` precedent. Additionally: widening this feature's protected-file
touch surface to include `check-contract.{sh,ps1,py}` and
`risk-gate-matrix.md` (reachability registration, INV-017) means T-004's
human-copy staging now spans two independent already-protected file
families instead of one — mitigated by keeping the two staged bundles
(protected-suffix vs. required-check-set) clearly distinguished in the
Protected-File Statement and MANIFEST.sha256, so a partial human-copy
application (one bundle applied, the other not) is detectable rather than
silently assumed complete.
