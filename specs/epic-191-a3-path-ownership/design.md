# Design: epic-191-a3-path-ownership

Impl-Review-Status: Pending
Feature Type: deterministic script + Implementation Gate check + reference
documentation (component path resolver, git-diff basis, Reverse Coverage
Gate, `ownership_digest`, cross-cutting pre-registration rule, fixtures)

## Technical Summary

Five deliverables land in dependency order: a component path resolver
(T-001) that classifies paths as EXCLUSIVE/SHARED/OVERLAP/UNOWNED against a
`components[].paths`/`shared_paths` configuration shaped per
decision-document v2 §12; a git-diff collector (T-002) that wraps the
resolver with the real baseline/untracked/rename/submodule-symlink rules
§12's "v2 新設" section fixes; an `ownership_digest` emitter (T-003) that
depends on Epic A1's canonicalizer; the Reverse Coverage Gate
`check-component-coverage` (T-004) that wires the resolver+diff collector
into `quality-gate`'s Implementation Gate and is registered as a new
protected script; and a cross-cutting path pre-registration reference doc
(T-005) that Epic A1's bootstrap flow is expected to consume. These T-00N
labels are a forward-looking plan for this feature's Phase 2 task
decomposition (not yet authored — see requirements.md Dependencies,
investigation.md INV-012); they organize this design document only.

The guiding principle is the same one `docs/ai-dlc-foundation-decision-v2.md`
already applies elsewhere in Foundation: no security property is asserted
by reimplementation. This feature does not redefine Epic A1's schema, does
not reimplement Epic A1's canonicalizer, and does not redefine Epic A4's
Facet Manifest — it consumes each by reference, and is explicit (via a
degraded/resolver-only mode, T-004) about which of its own checks can run
before those other epics land.

## Architecture

```
project-context.yaml (Epic A1 schema; consumed, not redefined)
        │  components[].paths.{include,exclude}; shared_paths[]
        ▼
resolve-component-paths.py  (T-001: pure classification function)
   ├─ glob compiler (**, *, NFC + separator normalization)
   ├─ shared_paths precedence check (bounded vs. cross-cutting)
   └─ per-component (include − exclude) set arithmetic
        │  EXCLUSIVE | SHARED(bounded) | SHARED(cross-cutting) | OVERLAP | UNOWNED
        ▼
git-diff collector (T-002, invoked by the .sh/.ps1 wrappers)
   ├─ baseline = git merge-base <feature-branch> main
   ├─ change set = baseline..worktree ∪ untracked (git porcelain only)
   ├─ rename-follow (old + new path independently classified)
   └─ submodule/symlink → reference-only evaluation
        │  resolver's own affected_components list + ownership fragment
        ▼
ownership_digest emitter (T-003; calls Epic A1 canonicalizer — not
   reimplemented; BLOCKED until that utility exists)
        │  ownership_digest (ADR-0021 context_binding field)
        ▼
check-component-coverage (T-004, stage: implementation)
   ├─ full mode:   cross-check against facet-manifest.affected_components
   │               (Epic A4 — Fail-1..Fail-6)
   └─ degraded mode (no Facet Manifest supplied): Fail-1/3/5/6(cond.) only,
                     WARN on skipped Fail-2/4
        │
        ▼
quality-gate ## Process (documents the new check; unprotected edit, INV-005)

(T-005, independent of the pipeline above): reference doc enumerating the
default cross-cutting shared_paths seed list, for Epic A1's bootstrap flow.
```

## Components

| Component | Responsibility | Technology | New/Existing | Protected? |
|---|---|---|---|---|
| `resolve-component-paths.py` | glob compiler, include/exclude/shared classification, overlap/unowned/exclude-misuse invariant | Python | new | no |
| `resolve-component-paths.sh` / `.ps1` | thin wrappers invoking the Python master (INV-008 convention) | Bash / PowerShell | new | no |
| git-diff collector (same script, `--baseline-branch`/`--include-untracked` flags) | merge-base baseline, untracked collection, rename-follow, submodule/symlink reference-only handling | Python (invoked via the same `.sh`/`.ps1` wrappers) | new | no |
| `check-component-coverage.py` | Reverse Coverage Gate: full-mode Fail-1..Fail-6 / degraded-mode Fail-1/3/5/6(cond.) | Python | new | **yes, once registered (T-004)** |
| `check-component-coverage.sh` / `.ps1` | thin wrappers | Bash / PowerShell | new | **yes, once registered (T-004)** |
| `plugins/sdd-quality-loop/references/guard-invariants.json` | gains four new `PROTECTED_GATE_SUFFIXES` entries (the three coverage-gate files) | JSON | existing, human-applied | **yes (pre-existing)** |
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | unchanged; read as the generator that re-renders `generated/guard_invariants.py` from the edited JSON | Python | existing, unmodified (read-only input to a human-run regeneration) | **yes (pre-existing)** |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` + 3 generated siblings | regenerated output reflecting the new protected entries | generated Python/JS/PS1/sh | existing, human-applied | **yes (pre-existing)** |
| `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` | `## Process` gains a documented `check-component-coverage` step | Markdown (skill) | existing, edited | no (verified, INV-005) |
| `plugins/sdd-quality-loop/references/default-shared-paths.md` | default cross-cutting `shared_paths` seed list for Epic A1's bootstrap flow | Markdown | new | no |
| `tests/fixtures/component-path-ownership/` | monorepo fixture: ≥2 components, overlapping candidate paths, nested excluded subtree, bounded `shared_paths` entry | fixture tree | new | no |
| `tests/component-path-resolver.tests.sh` / `.ps1` | glob-semantics, overlap, unowned, exclude-misuse cases | Bash / PowerShell | new | no |
| `tests/component-path-diff-basis.tests.sh` / `.ps1` | rename, untracked, submodule/symlink cases | Bash / PowerShell | new | no |
| `tests/check-component-coverage.tests.sh` / `.ps1` | full-mode Fail-1..6, degraded-mode WARN behavior, protected-registration proof | Bash / PowerShell | new | no |
| `tests/run-all.sh` / `.ps1` | suite registration for the three new suites | Bash / PowerShell | existing, edited | no (verified) |
| `.github/workflows/test.yml` | CI step registration for the three new suites | YAML | existing, human-applied via staged candidate + `MANIFEST.sha256` | **yes** (INV-010) |
| `docs/adr/0025-component-path-ownership-resolver-semantics.md` (provisional number, re-verified at drafting time) | records glob semantics, precedence rules, six Fail-condition definitions | Markdown (ADR) | new | no |
| `CHANGELOG.md` | REQ-008 doc-following surface | Markdown | existing, edited | no |

## Protected-File Statement

Verified directly against
`plugins/sdd-quality-loop/references/guard-invariants.json` and its
generated module `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
(investigation.md INV-005, INV-006, INV-010) at design-authoring time. Two
DIFFERENT protected-file situations apply to this feature, and they must
not be conflated:

1. **Already-protected files this feature edits indirectly**:
   `plugins/sdd-quality-loop/references/guard-invariants.json`,
   `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` (read
   as the regeneration tool, not itself content-edited),
   `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`, and
   its three `generated/guard-invariants.generated.{js,ps1,sh}` siblings,
   plus `.github/workflows/test.yml` — all already in
   `PROTECTED_GATE_SUFFIXES` (guard-invariants.json lines 14-19 show the
   closest precedent, `check-contract.*`; line 40 shows
   `.github/workflows/test.yml`; lines 34-39 show the guard-invariants
   toolchain's own self-protection). None of these is opened for write by
   any agent-run script in this feature — every corrected copy is staged
   under `specs/epic-191-a3-path-ownership/human-copy/<real-relative-path>`
   with a `MANIFEST.sha256` entry, exactly as
   `specs/epic-136-phase2-gates/human-copy/` (INV-007) and
   `specs/epic-159-pillar-c/design.md:110-167`'s `.github/workflows/test.yml`
   procedure already establish. A human maintainer runs the `cp` for each
   staged file and verifies its SHA-256 against the manifest before the
   registering task can be marked Done.

2. **New files this feature creates that BECOME protected as a design
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
its test suites, the fixture tree, `default-shared-paths.md`, the new ADR,
`CHANGELOG.md`) appears in `PROTECTED_GATE_SUFFIXES` or
`PROTECTED_GATE_PLUGIN_JSON_SUFFIXES` and each is agent-editable directly.
`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` is likewise
unprotected (INV-005) — its `## Process` edit is a direct agent edit, not
human-copy. Per requirements.md's Assumptions discipline, this is a
live-repository snapshot re-verified at design-authoring time, not a
permanent guarantee; the Phase 2 task that performs each edit re-verifies
`PROTECTED_GATE_SUFFIXES`'s then-current contents at its own
implementation-start time.

## Layer Specifications

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | N/A — no user-facing surface; CLI/script + gate + reference doc only | N/A (Non-goals; no ux-spec.md authored, INV-013) | maintainers | N/A |
| Frontend | N/A — no browser/frontend surface | N/A | maintainers | N/A |
| Infrastructure | CI suite registration for three new test pairs; `.github/workflows/test.yml` human-copy staging (T-004/T-005 share) | design.md Deployment/CI Plan | maintainers | Planned |
| Security | protected-file write boundary (guard-invariants.json + generated siblings + test.yml); new-script protection registration; submodule/symlink reference-only boundary; Provider Binding credential exclusion | design.md Security Boundaries; requirements.md Security Boundaries | maintainers | Planned |

This feature's spec package intentionally omits `ux-spec.md`/
`frontend-spec.md`/`infra-spec.md`/`security-spec.md` — `check-sdd-structure.sh`
only requires them in `--feature` mode (INV-013), which the task's
specified verification commands do not invoke for this directory, and this
feature has no UI/frontend surface to specify. Infrastructure and Security
concerns are instead captured directly in this design document's own
Deployment/CI Plan and Security Boundaries sections.

## Design System Compliance

N/A — `ds_profile: none`. No UI application, no mockup, no visualization.

## Cross-Layer Dependencies

| From | To | Contract / Decision | REQ | AC |
|---|---|---|---|---|
| requirements.md | design.md | glob compiler semantics (`**`/`*`, NFC, separator, case) | REQ-001 | AC-001..005 |
| requirements.md | design.md | shared/exclusive/overlap/unowned classification + exclude-misuse invariant | REQ-002 | AC-006..011 |
| requirements.md | design.md | git-diff basis (merge-base, untracked, rename-follow, submodule/symlink) | REQ-003 | AC-012..015 |
| requirements.md | design.md | Reverse Coverage Gate, full/degraded mode, protected registration | REQ-004 | AC-016..020 |
| requirements.md | design.md | `ownership_digest`, ADR-0021 binding | REQ-005 | AC-021..022 |
| requirements.md | design.md | cross-cutting pre-registration reference doc | REQ-006 | AC-023..024 |
| requirements.md | design.md | monorepo fixture + sh/ps1 suites | REQ-007 | AC-025..026 |
| requirements.md | design.md | ADR authorship, CHANGELOG, version-bump discipline | REQ-008 | AC-027..028 |
| requirements.md | ADR-0021 | `ownership_digest` context_binding shape + semantic-output exclusion | REQ-005 | AC-021, AC-022 |
| requirements.md | ADR-0017 | Gate stage classification (`stage: implementation`) | REQ-004 | AC-016 |

## ADR Change Log

**New ADR**: provisionally `docs/adr/0025-component-path-ownership-resolver-semantics.md`
(investigation.md INV-014 — `0025` is the next free number as of this
investigation; re-verified via `ls docs/adr/` at drafting time, renumbering
if a concurrent merge has occupied it, per the precedent
`specs/epic-159-pillar-c/design.md:201-236` set for ADR-0012). This ADR
records: (a) the glob-matching algorithm (`**`/`*` semantics, NFC and
separator normalization, case-sensitivity rule) as a NEW design decision
this feature establishes (not previously fixed by any existing ADR); (b)
the shared-vs-exclusive precedence order and the bounded-vs-cross-cutting
`shared_paths` shapes; (c) the six Fail-condition definitions (Fail-1
through Fail-6) as this feature's authoritative, unambiguous formalization
of decision-document v2 §12's one-line list; (d) the full-mode/degraded-mode
split for `check-component-coverage` and why it exists (Epic A4 forward
dependency, INV-003); (e) the decision to register
`check-component-coverage.{sh,ps1,py}` as a new protected-gate-suffix
entry. No existing ADR currently states any of these — ADR-0021 fixes
`ownership_digest`'s *binding* shape (which this ADR references, not
restates) but not the resolver's own matching algorithm; ADR-0017 fixes the
Gate *stage* model (`stage: implementation`, which this ADR references, not
restates) but not this Gate's specific Fail conditions.

**Drafting ownership**: authored as part of the Phase 2 task that
implements T-001 (the resolver's matching algorithm is the change this ADR
records), in the same commit that adds `resolve-component-paths.py` —
mirroring `specs/epic-159-pillar-c/design.md:224-236`'s ADR-0012 drafting
ownership precedent.

## Data Plan

Data Entities:

- Component path config (Epic A1 schema, consumed not redefined):
  `components[].paths.include: string[]`, `components[].paths.exclude:
  string[]`, `shared_paths[]` (`pattern: string`, and either `components:
  string[]` or `classification: "cross-cutting"`).
- Resolver output (new, this feature's own shape — not a repository
  contract file, an in-process/CLI JSON structure `resolve-component-paths`
  emits): per changed path, `{path, classification: EXCLUSIVE|SHARED_BOUNDED|
  SHARED_CROSS_CUTTING|OVERLAP|UNOWNED, owning_components: string[]}`; plus
  a top-level `affected_components: string[]` (the union of all EXCLUSIVE
  owners and all bounded-`shared_paths` declared components actually
  touched) and `ownership_fragment` (the specific config subset consumed,
  input to `ownership_digest`).
- `ownership_digest` (new, ADR-0021 `context_binding` field, T-003):
  `sha256:...`, computed over the canonicalized `ownership_fragment` via
  Epic A1's canonicalizer.
- Gate verdict (new, `check-component-coverage`'s own output, consumed by
  `quality-gate`'s evidence bundle): `{mode: full|degraded, fail_conditions:
  [{id: "Fail-1".."Fail-6", triggered: bool, detail}], warnings: string[]}`.
- `specs/epic-191-a3-path-ownership/human-copy/` (new, committed as a
  review artifact — never deleted by any test): staged corrected
  `guard-invariants.json`, the four regenerated `generated/*` files, and
  the `.github/workflows/test.yml` candidate, plus `MANIFEST.sha256`.

Existing Data Affected: `guard-invariants.json` and its generated siblings,
and `.github/workflows/test.yml`, are read but never written by any
agent-run script in this feature (Protected-File Statement).

## API / Contract Plan

### `resolve-component-paths.sh`/`.ps1` (T-001/T-002)

Invocation shape: `resolve-component-paths --config <project-context.yaml>
--baseline-branch main [--include-untracked] [--json]`. Exit code 0 on a
clean resolve (even with UNOWNED/OVERLAP results present in the JSON output
— classification results are data, not failure by themselves; only
`check-component-coverage`, T-004, turns a classification into a Gate
Fail). Non-zero exit only on a config-shape error (REQ-002's fail-closed
`shared_paths` shape check) or an unattainable `git merge-base` (REQ-003).

### `check-component-coverage.sh`/`.ps1` (T-004)

Invocation shape: `check-component-coverage --config <project-context.yaml>
--baseline-branch main [--facet-manifest <path>]`. Full mode when
`--facet-manifest` is supplied and readable; degraded mode otherwise (never
an error merely for the flag's absence — REQ-004's degraded mode is a
first-class, intentional mode, not a fallback-on-error). Exit code non-zero
iff at least one Fail condition triggers in the applicable mode; WARN-only
conditions (skipped Fail-2/Fail-4 in degraded mode; N/A Fail-6 with no
Provider Bindings file) never affect exit code by themselves.

### `plugins/sdd-quality-loop/references/guard-invariants.json` (human-applied)

Three new entries appended to `protected_gate_suffixes`:
`plugins/sdd-quality-loop/scripts/check-component-coverage.sh`,
`plugins/sdd-quality-loop/scripts/check-component-coverage.ps1`,
`plugins/sdd-quality-loop/scripts/check-component-coverage.py`. No other
key in the file changes.

## Test Strategy

Each of the three new suites (`component-path-resolver`,
`component-path-diff-basis`, `check-component-coverage`) is fixture-driven
against `tests/fixtures/component-path-ownership/`, deterministic, and
requires no LLM invocation, no network call, and no `gh` invocation.

- `component-path-resolver.tests.sh`/`.ps1`: glob semantics (AC-001..005),
  exclusive/shared/overlap/unowned classification (AC-006, AC-008..010),
  the exclude-misuse invariant (AC-007), and the `shared_paths` config-shape
  fail-closed check (AC-011).
- `component-path-diff-basis.tests.sh`/`.ps1`: merge-base baseline and its
  fail-closed unattainable case (AC-012), untracked+staged+unstaged
  collection without double counting (AC-013), rename-follow including the
  cross-component case (AC-014), and submodule/symlink reference-only
  evaluation (AC-015).
- `check-component-coverage.tests.sh`/`.ps1`: one dedicated fixture per
  Fail-1..Fail-6 in full mode (AC-016, AC-017), the degraded-mode WARN
  behavior (AC-018), the Fail-6 N/A-when-absent case (AC-019), and the
  protected-registration proof (three-part: staged candidate exists with a
  correct manifest entry; the live `guard-invariants.json`/generated files
  are byte-unchanged before/after; a post-human-copy self-registration grep
  confirms the three entries are present) mirroring
  `specs/epic-159-pillar-c/acceptance-tests.md`'s TEST-027 three-part shape
  (AC-020).
- REQ-006's fixture (default cross-cutting entries never trip Fail-1,
  AC-024) and REQ-007's overall fixture-tree shape (AC-025, AC-026) are
  shared across all three suites rather than owned by a fourth.

CI resilience (mirroring `specs/epic-159-pillar-c/tasks.md` Global
Constraints' own convention): no possibly-empty array expanded under
`set -u`; every mktemp root normalized with `pwd -P` immediately after
creation; any `jq` output consumption piped through `tr -d '\r'`
unconditionally; no suite drives a real validator gate directly.

## Design Decisions (resolving open questions)

- **Glob semantics** (REQ-001): `**` = zero or more whole path segments,
  crossing `/`; bare `*` = within one segment only; no `?`/`[...]`/regex —
  a deliberately restricted subset, chosen for the same determinism
  rationale decision-document v2 §11 (Q10) already applies to Predicate DSL
  conditions, extended here by this feature's own design authority (Q10's
  DSL and this feature's glob patterns are different mechanisms; this
  design decision is new, not inherited).
- **Path/case normalization** (REQ-001): comparison inputs (both pattern
  strings and `git`-reported paths) are NFC-normalized and `\`→`/`
  normalized before compilation; comparison is always case-sensitive,
  independent of host filesystem case sensitivity, because inputs are
  always `git` plumbing output, never a filesystem listing.
- **shared_paths precedence** (REQ-002): a `shared_paths` match is checked
  BEFORE per-component `(include − exclude)` classification and, when
  matched, exempts the path from OVERLAP/UNOWNED entirely — chosen because
  it gives config authors an unambiguous escape hatch (declare it shared)
  for any path that would otherwise need increasingly precise
  include/exclude patterns across every component.
- **`shared_paths` entry shape** (REQ-002): exactly one of `components:
  [...]` (bounded) or `classification: cross-cutting` (unbounded) — chosen
  to keep Fail-4's check simple and total (bounded entries always have a
  concrete list to check the Facet Manifest against; cross-cutting entries
  are always exempt, never partially so).
- **Fail-2/Fail-4 formalization** (REQ-004): Fail-2 fires when a component
  the resolver determines is EXCLUSIVE-owner of a changed path (or a
  declared party to a matched bounded `shared_paths` entry) is missing from
  `facet-manifest.affected_components`; Fail-4 fires when a bounded
  `shared_paths` entry's declared `components` list has a member missing
  from `facet-manifest.affected_components`. Both are per-manifest
  completeness checks against the resolver's own deterministic output —
  chosen over a cross-path aggregation rule (considered and rejected,
  investigation.md OQ discussion) because it is simpler, total, and
  independently testable per fixture.
- **Fail-5 as an assertion, not a runtime branch** (REQ-002/REQ-004): the
  exclude-as-include invariant is enforced by the `(include − exclude)` set
  arithmetic itself (a path in C's exclude is never in C's residual
  ownership set) — Fail-5's fixture exists to catch a *regression* in that
  arithmetic (e.g. an implementation that checks only `include`), not to
  add a separate runtime code path.
- **Fail-6 scope** (REQ-004): conditional on `sdd/provider-bindings.yaml`
  existing; join key is the component's `provider_binding_ids` field
  (already fixed by decision-document v2 §5/§12); the exact sub-path rule
  is deferred (OQ-001) until Epic A1 ships the file's real shape — recorded
  as an explicit Open Question, not silently assumed.
- **Full/degraded Gate mode** (REQ-004): chosen specifically to resolve the
  Epic A4 forward dependency (INV-003) without either (a) blocking this
  entire feature's implementation on Epic A4 landing first, or (b) silently
  shipping a Gate that can never exercise two of its six Fail conditions
  with no visible indication. Degraded mode's WARN is mandatory, never a
  silent PASS, so the gap is always auditable.
- **New protected-gate-suffix registration** (REQ-004): chosen by direct
  precedent (`check-contract.*`/`check-evidence-bundle.*`, INV-006) — a
  deterministic, security-relevant Implementation Gate validator whose
  purpose (preventing affected_components under-reporting) would be
  defeated by an agent that could edit or bypass it.
- **T-001/T-002 not hard-blocked on Epic A1 landing** (OQ-002, Dependencies):
  the resolver's fixtures are authored against decision-document v2 §12's
  already-fixed field shape; only T-003 (canonicalizer) and part of T-004
  (Facet Manifest, full mode only) are hard-blocked on their respective
  epics landing as artifacts, not merely as shapes.

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
  suite, serialized T-001 → T-002 → T-004 (T-005 shares T-001's fixture,
  no new suite of its own).
- **`.github/workflows/test.yml`**: human-copy staged, same serialization,
  so no two Phase-2 tasks' staged candidates race each other under
  `specs/epic-191-a3-path-ownership/human-copy/`.
- **`guard-invariants.json` + generated siblings**: T-004 is the sole
  editor (via human-copy) within this feature.
- Preserve unrelated changes; implement one task at a time (once Phase 2
  authors `tasks.md`).

## Security Boundaries

See requirements.md Security Boundaries; this design additionally notes:
`check-component-coverage`'s own verdict object (Data Plan) never embeds
raw file contents from a changed path — only path strings and component
ids — so the Gate's evidence output cannot itself become a channel for
smuggling sensitive file content into a report artifact.

## External Integrations

None. This feature calls only local `git` plumbing commands and (T-003) a
local Epic A1 canonicalizer utility — no network call, no external
service, no `gh` invocation.

## Deployment / CI Plan

Three new `.sh`/`.ps1` suite pairs register in `tests/run-all.sh`/`.ps1`
(direct edit) and stage their CI step additions into
`.github/workflows/test.yml` via human-copy (INV-010). No new CI job/matrix
dimension is introduced — the new suites run in the existing deterministic,
3-OS lane alongside `agent-model-routing`, `render-agent-frontmatter`, etc.

## Constraint Compliance

| Constraint | How this feature complies |
|---|---|
| Protected-file write boundary | See Protected-File Statement; every protected-path edit is staged under `human-copy/` |
| CI resilience (no unbound `set -u` array, `pwd -P`, `tr -d '\r'`) | Test Strategy |
| Doc-following (REQ-008) | ADR Change Log; CHANGELOG entries per Phase-2 task |
| Version-bump discipline | Global Constraints |
| No Registry/Epic A2 coupling | Architecture — Gate wired directly into `quality-gate`'s `## Process`, no Registry projection dependency |

## Assumptions

Carried from requirements.md Assumptions; additionally: this design assumes
`quality-gate`'s `## Process` section (`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:30-204`)
is structured as an ordered list of named checks that a new check can be
appended to without restructuring the surrounding checks — verified at
Phase-2 implementation time, not asserted as unconditionally permanent.

## Open Questions

Carried from requirements.md Open Questions (OQ-001, OQ-002); no new
open question is introduced at design time.

## Risks

Carried from requirements.md Risks. Additionally: authoring the new ADR
(0025, provisional) in the same commit as T-001 (ADR Change Log) risks a
renumbering collision if a sibling Epic-191 sub-feature (A1/A2, both
currently in-flight in sibling worktrees per this session's own
coordination) claims `0025` first — mitigated by the explicit
re-verify-at-drafting-time instruction already carried from the
`ADR-0012` precedent.
