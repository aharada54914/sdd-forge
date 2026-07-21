# Requirements: epic-191-a3-path-ownership

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/191,
https://github.com/aharada54914/sdd-forge/issues/187
Epic: https://github.com/aharada54914/sdd-forge/issues/187 (AI-DLC
Foundation tracking) — Epic A3 (Component Path Ownership), issue #191, per
`docs/ai-dlc-foundation-decision-v2.md` §19
Investigation: specs/epic-191-a3-path-ownership/investigation.md
(INV-001..INV-014, OQ-001..OQ-002)

## Overview

`docs/ai-dlc-foundation-decision-v2.md` §12 (Q11) identifies that a
Feature's self-reported `affected_components` can under-report which
components a change actually touches, silently skipping per-component
review coverage. The remedy is a deterministic **component path resolver**
(include/exclude ownership per component, plus declared `shared_paths`) and
a **Reverse Coverage Gate** (`check-component-coverage`) that cross-checks
the real `git diff` against that ownership declaration and against the
Facet Manifest's claimed `affected_components`, failing closed on six named
conditions (§12). §16 (Q15) additionally requires the resolver to emit an
`ownership_digest` so that a path-ownership change invalidates only the
Features whose resolved output actually changes (ADR-0021).

This feature (Epic A3) delivers: the resolver itself (REQ-001, REQ-002),
its git-diff input basis (REQ-003), the Gate that consumes it
(REQ-004), the `ownership_digest` it emits (REQ-005), the operational rule
that keeps everyday cross-cutting paths (specs, reports, ADRs, CI config)
from tripping the Gate (REQ-006), and the monorepo fixture + test suite
that locks all of the above (REQ-007), plus the documentation/versioning
discipline every task shares (REQ-008).

This feature does **not** define `project-context.yaml`'s schema (Epic
A1's deliverable — this feature consumes the `components[].paths` /
`shared_paths` field shape already fixed by decision-document v2 §12,
without redefining it) and does **not** define the Facet Manifest schema
(Epic A4's deliverable — see Dependencies).

## Target Users

- Spec/design/task reviewers and the quality-gate evaluator, who need
  `check-component-coverage` to catch an under-reported
  `affected_components` claim before a Task reaches Done
  (`docs/ai-dlc-foundation-decision-v2.md` §3.1 lists it as one of the
  Implementation Gate's common checks).
- Maintainers of multi-component (monorepo-style) `project-context.yaml`
  configurations, who author `paths.include`/`paths.exclude`/`shared_paths`
  and need unambiguous, documented matching semantics (INV-002; this
  feature is the first place those semantics are pinned down, since Epic
  A1 only fixes the field *shape*, not the matching *algorithm*).
- ADR-0021's staleness mechanism, which needs `ownership_digest` to bind a
  Feature's Facet Manifest to the ownership fragment it actually consumed
  (`docs/adr/0021-context-projection-staleness.md` lines 41-42, 78-88).
- Epic A1's bootstrap flow, which needs a documented default cross-cutting
  `shared_paths` seed list (REQ-006) so that ordinary spec/report/CI
  changes do not trip Fail-1 on day one of adopting Project Context.
- Windows-hosted contributors and CI runners, for whom path-separator and
  case-sensitivity semantics must be identical to Linux/macOS runners
  (decision-document v2 §7 "各Epicの3環境対応", applied here as "path and
  case semantics must not depend on host OS").

## Problems

- `affected_components` is currently self-reported by whichever process
  resolves a Feature's Facet Manifest, with no independent check against
  the actual `git diff` (INV-001: no resolver or Gate exists today) — a
  Feature can silently omit a component it actually touched.
- No documented algorithm exists for how `paths.include`/`paths.exclude`
  glob patterns are matched, what `**` versus `*` mean, how
  cross-platform path separators and case sensitivity are handled, or how
  a path that is excluded from one component's ownership must never be
  silently misattributed to it (decision-document v2 §12 names the
  Fail conditions but does not define the matching algorithm itself).
- No git-diff basis is defined: earlier planning (v1, per
  `docs/ai-dlc-foundation-decision-v2.md` §12's "v1 では diff の入力が
  未定義だった") left baseline, untracked-file handling, rename-following,
  and submodule/symlink handling all unspecified.
- The Reverse Coverage Gate's own Fail-2/Fail-4 conditions structurally
  depend on the Facet Manifest's `affected_components` field, which is an
  Epic A4 deliverable sequenced *after* this epic (INV-003) — without an
  explicit design decision, this either blocks the entire Gate on Epic A4
  landing first, or silently ships a Gate that can never fail those two
  conditions.
- Without a pre-registered cross-cutting `shared_paths` list, ordinary
  changes to `specs/**`, `reports/**`, or CI configuration would trip
  Fail-1 (unowned path) on essentially every Feature, defeating adoption
  (decision-document v2 §12: "運用上必ず増える path…は bootstrap 時に
  cross-cutting の shared_paths へ確定登録し、日常運用での unowned-path
  FAIL を防ぐ").
- Registering the new Gate script as a protected, R-10 enforcement-chain
  file (the natural precedent set by `check-contract.*` /
  `check-evidence-bundle.*`, INV-006) requires editing
  `plugins/sdd-quality-loop/references/guard-invariants.json`, which is
  itself already protected (INV-006) — an agent cannot make this change
  directly.

## Dependencies

- **Epic A1 (Project Context)** owns the `project-context.yaml` schema,
  including the exact field types for `components[].paths.include`,
  `components[].paths.exclude`, and `shared_paths[]` (decision-document v2
  §12's example). This feature does not redefine that schema — REQ-001's
  matching *algorithm* operates on whatever string arrays those fields
  hold, and this feature's own fixtures construct standalone YAML matching
  the documented shape (INV-002, OQ-002) rather than depending on Epic A1's
  actual schema file existing in `contracts/`. If Epic A1's landed schema
  diverges from decision-document v2 §12's shape, reconciling this
  feature's parsing is a tracked follow-up, not a blocker, for REQ-001/
  REQ-002/REQ-003 (design.md Assumptions).
- **Epic A1's canonicalizer** (YAML 1.2 + JCS, Python single implementation
  + thin wrappers, decision-document v2 §18.3/§21 Epic A1) is a hard
  dependency for REQ-005 (`ownership_digest` emission) — there is no
  shape-only substitute for calling a canonicalization utility that does
  not yet exist (INV-002). REQ-005's task is blocked on Epic A1 shipping
  this utility.
- **Epic A4 (Facet Manifest)** owns the schema for
  `facet-manifest.affected_components`, the field Fail-2 and Fail-4 (REQ-004)
  compare the resolver's output against. This is a genuine forward
  dependency created by the decision document's own epic ordering
  (§19: A1 → A2 → A3 → A4 → A5; INV-003). REQ-004 isolates the checks that
  need Facet Manifest (Fail-2, Fail-4, and Fail-6 when Provider Bindings
  exist) from the checks that do not (Fail-1, Fail-3, Fail-5), so this
  feature's implementation is not fully blocked on Epic A4 — only the
  full-mode Gate behavior is (see Acceptance Criteria AC-017/AC-018).
- **Epic A1's Provider Bindings** (`sdd/provider-bindings.yaml`) is an
  optional dependency for Fail-6 (Provider Adapter / Provider Binding
  drift, REQ-004) — conditional/N/A when absent (INV-004, OQ-001).
- **Epic A2 (Capability Registry)** is not a dependency of this feature.
  `check-component-coverage` is an Implementation Gate check wired directly
  into `quality-gate`'s existing `## Process` section (INV-005), not a
  Registry-declared gate; Registry-driven gate projection is out of scope
  (Non-goals).

## Goals

- REQ-001 (component path resolver — glob semantics; INV-002, OQ-002):
  Implement a deterministic script (`resolve-component-paths.py` master +
  `.sh`/`.ps1` wrappers, INV-008) that, given a `components[].paths`/
  `shared_paths` structure matching decision-document v2 §12's shape and a
  list of changed paths, classifies every path. Matching rules (this
  feature's own design decision, not redefined elsewhere): `**` matches
  zero or more whole path segments, including across `/` boundaries;
  a bare `*` matches within a single path segment and never crosses `/`;
  no other glob metacharacter (`?`, `[...]`) is supported, mirroring the
  restricted-DSL philosophy decision-document v2 §11 (Q10) already
  established for a different fragment (predicate conditions) — no
  regex, no arbitrary JSONPath, no dynamic code. All comparison inputs
  (pattern strings from config, path strings from `git diff` output) are
  normalized to Unicode NFC before matching, and any backslash in a
  pattern string is normalized to forward slash before compilation
  (patterns may be authored on any OS; path strings from `git`'s own
  plumbing commands are always forward-slash-separated regardless of host
  OS, so no separate diff-side normalization is required — this feature's
  scripts assert this as a fixture-tested invariant rather than merely
  documenting it, per INV-010's existing CRLF-parity-test precedent).
  Matching is always case-sensitive, byte-wise, independent of the host
  filesystem's own case sensitivity, because the resolver only ever
  compares strings returned by `git` plumbing commands — it never lists a
  filesystem directory itself.

- REQ-002 (exclusive/shared classification, overlap detection, unowned
  detection; §12): For each changed path, the resolver first checks every
  `shared_paths` entry; a match there exempts the path from
  component-exclusivity classification entirely (Design Decisions). A
  `shared_paths` entry is one of two mutually exclusive shapes: a bounded
  form (`components: [...]`, an explicit list) or an unbounded form
  (`classification: cross-cutting`, no components list, any/no component
  may touch it) — a config carrying both or neither on the same entry is a
  fail-closed configuration error, distinct from the six Gate Fail
  conditions. For a path not matched by any `shared_paths` entry, the
  resolver computes, per component, `(include patterns matched) MINUS
  (exclude patterns matched)`; exactly one component's residual match →
  **EXCLUSIVE**, owned by that component; zero components' residual match →
  **UNOWNED** (Fail-1); two or more components' residual match →
  **OVERLAP** (Fail-3). The `exclude` subtraction is evaluated strictly
  within the same component (a path inside component C's own `exclude` is
  never attributed to C, even if it is also nested inside one of C's
  `include` patterns) — this is the Fail-5 invariant ("exclude pathの
  include扱い"), asserted directly as a resolver correctness property, not
  merely relied upon via the R-10 guard or any downstream consumer.

- REQ-003 (git diff basis; §12 "v2 新設"): Wrap the resolver with a
  deterministic git-diff collector. Baseline = `git merge-base
  <feature-branch> main` (fail-closed with a diagnostic, never a silently
  empty diff, if the merge-base cannot be computed — e.g. unrelated
  histories, detached HEAD without a resolvable branch). Change set =
  `baseline..worktree` (working tree, not merely `HEAD`) **plus** untracked
  files, collected via `git status --porcelain=v1 -z --untracked-files=all`
  or `git ls-files --others --exclude-standard` (never a raw filesystem
  walk, so path separator and case fidelity always match git's own
  guarantees) — staged, unstaged, and untracked changes are each counted
  exactly once (no double counting a path that is both staged and further
  modified unstaged). Renames are followed with `git diff -M
  --name-status` (or equivalent): both the pre-rename and post-rename path
  are independently classified, and a rename that crosses component
  boundaries (old path EXCLUSIVE to component A, new path EXCLUSIVE to
  component B) is surfaced as its own distinct case, not silently collapsed
  into "component A changed a file." Submodule (gitlink) entries and
  symlink entries in the diff are evaluated only for the reference/pointer
  change itself (the gitlink SHA, or the symlink's target text) — the
  resolver never follows a symlink or descends into a submodule's own
  working tree to evaluate its content as part of this Feature's diff.

- REQ-004 (Reverse Coverage Gate `check-component-coverage`, stage:
  implementation; §12, ADR-0017): A new Implementation Gate check,
  documented in `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`'s
  existing `## Process` section (INV-005 — a direct, unprotected edit).
  In **full mode** (a Facet Manifest is available — Epic A4 landed), the
  Gate judges all six Fail conditions from decision-document v2 §12:
  Fail-1 (changed path belongs to no component and no `shared_paths`
  entry — UNOWNED), Fail-2 (a component the resolver determines is
  affected — EXCLUSIVE owner of a changed path, or a required party to a
  matched bounded `shared_paths` entry — is missing from
  `facet-manifest.affected_components`), Fail-3 (OVERLAP — an exclusive
  path resolves to two or more components), Fail-4 (a changed path matches
  a bounded `shared_paths` entry, but `facet-manifest.affected_components`
  is missing one or more of that entry's declared `components`), Fail-5
  (the exclude-as-include misuse invariant from REQ-002, additionally
  asserted at the Gate level against real Facet Manifest data, not just
  the resolver's own unit tests), and Fail-6 (a component with a non-empty
  `provider_binding_ids` had an EXCLUSIVE-owned path change in this diff,
  but `sdd/provider-bindings.yaml` was not also touched in the same diff —
  evaluated only when that file exists in the repository; otherwise
  recorded as N/A with a WARN, per OQ-001, since Provider Binding adoption
  is optional per component). In **degraded (resolver-only) mode** (no
  Facet Manifest available — the common case until Epic A4 lands, or for
  a project that has not adopted Facet Manifest at all), the Gate still
  enforces Fail-1, Fail-3, Fail-5, and Fail-6 (when applicable) — the
  three/four conditions that need only the resolver's own output, not a
  Manifest — and records an explicit WARN (never a silent PASS) that
  Fail-2 and Fail-4 were skipped because no Facet Manifest was supplied.
  `check-component-coverage.{sh,ps1,py}` is added to
  `PROTECTED_GATE_SUFFIXES` (INV-006 — the same precedent as
  `check-contract.*`/`check-evidence-bundle.*`), which requires editing
  `plugins/sdd-quality-loop/references/guard-invariants.json` (itself
  protected) and regenerating
  `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` plus its
  three generated siblings — staged under
  `specs/epic-191-a3-path-ownership/human-copy/` with a `MANIFEST.sha256`
  entry per staged file, never written directly, per the established
  human-copy procedure (INV-007, ADR-0011).

- REQ-005 (`ownership_digest` emission; §16 Q15, ADR-0021): The resolver
  emits `ownership_digest` — a digest of exactly the ownership fragment
  (the specific components' `paths` entries and the specific
  `shared_paths` entries) actually consumed while resolving a given
  Feature's affected components — canonicalized via Epic A1's
  YAML-1.2-plus-JCS canonicalizer (decision-document v2 §18.3; not
  reimplemented here, per the task's scope-boundary instruction).
  `ownership_digest` populates the `context_binding` block exactly as
  ADR-0021 (`docs/adr/0021-context-projection-staleness.md` lines 34-46)
  specifies, alongside `resolver.version` / `resolver.rule_set_revision`;
  it is binding/provenance metadata, excluded from ADR-0021's "semantic
  output" comparison (`docs/adr/0021-context-projection-staleness.md`
  lines 55-68) — a digest-only update, with no change to which components
  are reported affected, never by itself marks a Feature stale.

- REQ-006 (cross-cutting path pre-registration rule; §12 "v2 新設"): A
  reference document (`plugins/sdd-quality-loop/references/default-shared-paths.md`
  or `.json`, design.md decides the exact format) enumerates the default
  cross-cutting `shared_paths` seed list — at minimum `specs/**`,
  `reports/**`, `docs/adr/**`, `CHANGELOG.md`, `.github/**`,
  `tests/fixtures/**`, and `contracts/**` (the last already shown as a
  bounded example in decision-document v2 §12) — that Epic A1's bootstrap
  flow is expected to seed into a newly-created `project-context.yaml`, so
  that ordinary changes to these paths never trip Fail-1 on day one of
  Project Context adoption.

- REQ-007 (monorepo fixture + `.sh`/`.ps1` test pairs; §19 Epic A3): A
  fixture monorepo under `tests/fixtures/component-path-ownership/`
  (INV-009) with at least two components with candidate-overlapping owned
  paths, a nested excluded subtree under one component, and a bounded
  `shared_paths` entry, is created and exercised by new `.sh`/`.ps1` test
  suite twins covering each of the six named cases this task's owner
  (the orchestrating instruction) specifies: overlap, unowned, rename,
  untracked, exclude misuse, and shared-undeclared — registered in
  `tests/run-all.sh`/`.ps1` (direct edit) and staged into
  `.github/workflows/test.yml` via human-copy (INV-010, protected file).

- REQ-008 (documentation and versioning discipline; shared across every
  task, same "ドキュメント追従・バージョン改訂" convention as
  `specs/epic-159-pillar-c/requirements.md` REQ-009): every task adds its
  own `CHANGELOG.md` `## Unreleased` entry citing issue #191; the new ADR
  (provisionally `docs/adr/0025-component-path-ownership-resolver-semantics.md`,
  re-verified at drafting time per INV-014) records the glob-matching
  semantics, precedence rules, and six Fail-condition definitions this
  requirements/design pair establishes; version bumps happen exclusively
  via `scripts/bump-version.sh`, never a hand-edited version string.

## Non-goals

- Defining or modifying `project-context.yaml`'s schema, including the
  exact JSON-Schema type for `components[].paths`/`shared_paths` — that is
  Epic A1's deliverable (Dependencies).
- Defining or modifying the Facet Manifest schema, including
  `facet-manifest.affected_components`'s own type — that is Epic A4's
  deliverable (Dependencies).
- Implementing Epic A1's canonicalizer, or any new canonicalization
  algorithm — REQ-005 calls Epic A1's utility; it does not reimplement
  YAML-1.2/JCS canonicalization.
- Implementing or modifying the Capability Registry (Epic A2), Registry
  gate projection, or `gate-capabilities.json` generation — this feature's
  Gate is wired directly into `quality-gate`'s `## Process` section, not
  through a Registry-driven mechanism.
- Defining Provider Bindings' file schema (`sdd/provider-bindings.yaml`) —
  Fail-6 only consumes the component-level `provider_binding_ids` field
  decision-document v2 §5/§12 already fixed, and is N/A when the Provider
  Bindings file is absent (OQ-001).
- Implementing the actual bootstrap-interviewer flow that seeds the
  default cross-cutting `shared_paths` list into a new
  `project-context.yaml` — REQ-006 delivers the reference document Epic A1
  is expected to consume, not the bootstrap flow itself.
- Any change to `sdd-hook-guard.*`'s own enforcement logic — this feature
  only adds new entries to the *data* file
  (`guard-invariants.json`) the existing guard already reads.

## User Stories

- As a quality-gate evaluator, I need `check-component-coverage` to fail
  closed when a Feature's declared `affected_components` omits a component
  its diff actually touched, so that per-component review coverage is
  never silently skipped (REQ-004).
- As a maintainer authoring `project-context.yaml`'s `paths`/`shared_paths`
  fields on Windows, I need glob matching to behave identically to a
  Linux/macOS teammate's, so a change that passes locally does not
  unexpectedly fail (or pass) in CI on a different OS (REQ-001).
- As a maintainer renaming a file across component boundaries, I need the
  resolver to tell me both the old and new owner, not silently attribute
  the whole rename to one side, so I can correct `affected_components`
  before the Gate runs (REQ-003).
- As an Epic A1 bootstrap-flow implementer, I need a documented default
  cross-cutting `shared_paths` seed list so a brand-new Project Context
  does not immediately fail every Feature's Gate on routine `specs/**`
  changes (REQ-006).
- As a maintainer relying on ADR-0021's staleness mechanism, I need
  `ownership_digest` to change if and only if the ownership fragment my
  Feature actually used changes, so an unrelated path-ownership edit
  elsewhere in the monorepo does not spuriously stale my in-progress
  Feature (REQ-005).

## Acceptance Criteria

- AC-001 (REQ-001): `**` matches zero or more whole path segments,
  including crossing `/` boundaries (e.g. `src/desktop/**` matches
  `src/desktop/file.ts` AND `src/desktop/sub/deep/file.ts`).
- AC-002 (REQ-001): a bare `*` matches only within a single path segment
  and never crosses `/` (e.g. `src/*.ts` does not match
  `src/sub/file.ts`).
- AC-003 (REQ-001): a pattern string containing `\` is normalized to `/`
  before compilation; a fixture using `\`-separated patterns matches
  identically to its `/`-separated equivalent.
- AC-004 (REQ-001): both pattern strings and diff-reported path strings
  are normalized to Unicode NFC before comparison (an NFD-encoded fixture
  path and an NFC-encoded pattern match).
- AC-005 (REQ-001): matching is byte-wise case-sensitive regardless of
  host OS (a fixture path differing only in case from a pattern does not
  match, on every OS this suite runs on).
- AC-006 (REQ-002): a path matching exactly one component's `(include −
  exclude)` set, and no `shared_paths` entry, classifies EXCLUSIVE to that
  component.
- AC-007 (REQ-002): a path nested inside component C's own `exclude`
  pattern, while also matching one of C's `include` patterns, is NEVER
  classified as owned by C (Fail-5 invariant, asserted at the resolver
  level independent of any Gate).
- AC-008 (REQ-002): a path matching zero components' `(include − exclude)`
  sets, and no `shared_paths` entry, classifies UNOWNED (Fail-1).
- AC-009 (REQ-002): a path matching two or more components' `(include −
  exclude)` sets, and no `shared_paths` entry, classifies OVERLAP
  (Fail-3).
- AC-010 (REQ-002): a path matched by any `shared_paths` entry is exempt
  from OVERLAP/UNOWNED classification regardless of how many (including
  zero) components' `include` patterns it also happens to match.
- AC-011 (REQ-002): a `shared_paths` entry carrying both `components` and
  `classification: cross-cutting`, or neither, is rejected as a
  fail-closed configuration error at load time, distinct from the six
  Gate Fail conditions.
- AC-012 (REQ-003): baseline is computed as `git merge-base
  <feature-branch> main`; a fixture repository with unrelated histories
  produces a fail-closed diagnostic, never a silently empty change set.
- AC-013 (REQ-003): the change set includes staged, unstaged, AND
  untracked files with no path counted twice, collected via git porcelain
  commands (never a raw filesystem walk).
- AC-014 (REQ-003): a rename is followed — both the old and new path are
  independently classified; a cross-component rename (old path EXCLUSIVE
  to A, new path EXCLUSIVE to B) is reported as a distinct case, not
  merged into a single-component result.
- AC-015 (REQ-003): a submodule (gitlink) entry and a symlink entry are
  each evaluated only for their own reference/pointer text — the resolver
  never expands into the referenced content.
- AC-016 (REQ-004): `check-component-coverage` runs as a `stage:
  implementation` check; a fully-declared, non-overlapping, fully-owned
  diff fixture passes cleanly in full mode.
- AC-017 (REQ-004): each of Fail-1 through Fail-6 has at least one
  dedicated fixture that deterministically triggers it in full mode
  (Fail-6's fixture includes a `sdd/provider-bindings.yaml` file).
- AC-018 (REQ-004): with no Facet Manifest supplied, the Gate still
  enforces Fail-1/Fail-3/Fail-5 (and Fail-6 when a Provider Bindings file
  is present) and records an explicit WARN — never a silent PASS — that
  Fail-2/Fail-4 were skipped.
- AC-019 (REQ-004): with no `sdd/provider-bindings.yaml` present, Fail-6 is
  recorded N/A with a WARN, never silently omitted without a trace.
- AC-020 (REQ-004): `check-component-coverage.{sh,ps1,py}` appear in
  `PROTECTED_GATE_SUFFIXES` only via the staged
  `specs/epic-191-a3-path-ownership/human-copy/` candidates +
  `MANIFEST.sha256`; the live `guard-invariants.json` and every
  `generated/guard_invariants*` file are byte-identical before/after this
  feature's own commits, and a human `cp` + SHA-256 verification is
  required before the registering task can be marked Done.
- AC-021 (REQ-005): `ownership_digest` is computed only over the
  components'/`shared_paths` entries actually consumed for a given
  resolve, via Epic A1's canonicalizer; if that canonicalizer does not
  exist in the repository at implementation time, the implementing task
  records this as a documented blocker rather than reimplementing
  canonicalization.
- AC-022 (REQ-005): `ownership_digest` is present in `context_binding`
  alongside `resolver.version`/`resolver.rule_set_revision`, and is
  excluded from ADR-0021's semantic-output comparison — a fixture where
  only `ownership_digest` changes (no resolved-component-set change)
  does not mark the Feature stale.
- AC-023 (REQ-006): the reference document lists at least `specs/**`,
  `reports/**`, `docs/adr/**`, `CHANGELOG.md`, `.github/**`,
  `tests/fixtures/**`, and `contracts/**` as default cross-cutting
  `shared_paths` seed entries.
- AC-024 (REQ-006): a fixture diff confined to the default cross-cutting
  entries, with zero components declared to own them, never triggers
  Fail-1.
- AC-025 (REQ-007): the fixture tree under
  `tests/fixtures/component-path-ownership/` has at least two components
  with overlapping candidate owned paths, a nested excluded subtree, and a
  bounded `shared_paths` entry.
- AC-026 (REQ-007): `.sh`/`.ps1` test-suite twins exist, are registered in
  `tests/run-all.sh`/`.ps1`, and are staged into
  `.github/workflows/test.yml` via human-copy; each of the six named
  cases (overlap, unowned, rename, untracked, exclude misuse,
  shared-undeclared) has at least one passing positive case and one
  red/failing-then-fixed case.
- AC-027 (REQ-008): every task's commit lands its own `CHANGELOG.md`
  `## Unreleased` entry citing #191; the new ADR is authored (re-verified
  number) recording this feature's glob-semantics, precedence, and
  Fail-condition design decisions.
- AC-028 (REQ-008): a grep-based self-check confirms no version string is
  mutated anywhere in this feature's diff outside a `scripts/bump-version.sh`
  invocation.

## Field Definitions

- **EXCLUSIVE**: a changed path resolves to exactly one component's
  `(include − exclude)` set and matches no `shared_paths` entry.
- **SHARED (bounded)**: a changed path matches a `shared_paths` entry that
  carries an explicit `components: [...]` list.
- **SHARED (unbounded / cross-cutting)**: a changed path matches a
  `shared_paths` entry that carries `classification: cross-cutting` (no
  `components` list) — any or no component may touch it without
  restriction.
- **OVERLAP**: a changed path resolves to two or more components'
  `(include − exclude)` sets and matches no `shared_paths` entry
  (Fail-3).
- **UNOWNED**: a changed path resolves to zero components' `(include −
  exclude)` sets and matches no `shared_paths` entry (Fail-1).
- **ownership fragment**: the specific subset of `components[].paths` and
  `shared_paths` entries a given resolve actually evaluated (used to
  compute `ownership_digest`, ADR-0021).
- **resolver-only (degraded) mode**: `check-component-coverage` run
  without a Facet Manifest input — enforces Fail-1/3/5/6(conditional)
  only, WARNs on the skipped Fail-2/4.
- **full mode**: `check-component-coverage` run with a Facet Manifest
  input available — enforces all six Fail conditions.

## Roles and Permissions

- **Implementing agent**: authors `resolve-component-paths.{py,sh,ps1}`,
  `check-component-coverage.{py,sh,ps1}`, their test suites and fixtures,
  the reference documents (REQ-006, the new ADR), and stages every
  protected-file candidate under `specs/epic-191-a3-path-ownership/human-copy/`
  — never writes a protected path directly (Rules, AGENTS.md).
- **Human maintainer**: reviews and applies each staged human-copy
  candidate (`cp` + SHA-256 verification) for
  `plugins/sdd-quality-loop/references/guard-invariants.json` and its
  generated siblings, and for `.github/workflows/test.yml`'s registration
  addition; approves tasks (Approval: Draft → Approved is a human-only
  action, never performed in this spec-phase package).
- **quality-gate evaluator**: consumes `check-component-coverage`'s
  verdict as part of the Implementation Gate; only `quality-gate` (or
  `lite-gate`) may mark a Task Done (AGENTS.md invariant, unchanged by
  this feature).

## Main Workflows

1. A component/shared-path config (matching decision-document v2 §12's
   shape) and a feature branch are supplied to
   `resolve-component-paths.{sh,ps1}`.
2. The script computes baseline via `git merge-base`, collects the change
   set (baseline..worktree + untracked, renames followed, submodules/
   symlinks reference-only), and classifies every path EXCLUSIVE / SHARED
   (bounded or unbounded) / OVERLAP / UNOWNED.
3. The script emits `ownership_digest` for the ownership fragment it
   consumed, plus its own computed `affected_components` list.
4. `check-component-coverage` (stage: implementation) is invoked by
   `quality-gate`'s `## Process`; when a Facet Manifest is available, it
   cross-checks the resolver's output against
   `facet-manifest.affected_components` (full mode, all six Fail
   conditions); when absent, it runs in degraded mode (Fail-1/3/5/6 only,
   WARN on the rest).
5. Any Fail condition blocks the Implementation Gate; a human resolves the
   underlying config or Facet Manifest and re-runs.
6. Epic A1's bootstrap flow (out of scope here) is expected to seed the
   REQ-006 default cross-cutting list into a new `project-context.yaml` so
   that steps 1-5 do not immediately fail on routine `specs/**`/
   `reports/**` changes.

## Edge Cases

- A `shared_paths` pattern and a component `include` pattern match the
  *identical* literal path string — resolved per AC-010 (shared always
  wins; no OVERLAP/UNOWNED classification is attempted).
- A rename where BOTH old and new paths are EXCLUSIVE to the SAME
  component — not a cross-component case; classified as a normal
  single-component change (no Fail-2/4 special-casing beyond the ordinary
  EXCLUSIVE path).
- A rename where the OLD path was UNOWNED and the NEW path is EXCLUSIVE
  (or vice versa) — both are independently classified; the UNOWNED side
  still triggers Fail-1 in full/degraded mode as it would for any other
  UNOWNED path.
- An empty `changed paths` set (no diff at all between baseline and
  worktree, including untracked) — the Gate passes vacuously; this is
  distinct from, and must not be confused with, a fail-closed
  merge-base-unattainable diagnostic (AC-012), which is an error, not an
  empty result.
- A component with an empty `include` list (a config error, not a runtime
  Fail condition) — flagged at config-load time, not conflated with
  UNOWNED path detection.
- A `shared_paths` entry whose pattern matches zero changed paths in a
  given diff — not evaluated at all for that resolve (no Fail-4 check
  fires for an entry the diff never touches).

## Security Boundaries

- `check-component-coverage.{sh,ps1,py}` becomes a protected,
  R-10-enforced Implementation Gate script (REQ-004) — an agent cannot
  directly weaken or bypass it once the human-copy registration in
  `guard-invariants.json` is applied, the same boundary
  `check-contract.*`/`check-evidence-bundle.*` already enforce (INV-006).
- The resolver and Gate never write any repository path as a side effect
  of *reading* a diff — every write this feature performs lands either in
  a new, unprotected script/test/reference file, or in the
  `specs/epic-191-a3-path-ownership/human-copy/` staging area (never a
  live protected path).
- Submodule/symlink reference-only evaluation (REQ-003) is itself a
  security boundary: the resolver never dereferences a symlink or descends
  into a submodule's working tree, which would otherwise let a diff smuggle
  in ownership-classification input the resolver's own repository does not
  control.
- Fail-6's Provider Binding check (REQ-004) never reads
  `sdd/provider-bindings.yaml`'s `credentials` block (out of scope,
  decision-document v2 §4/§9 note credential values are a Provider Binding
  concern, never surfaced to the resolver or Gate).

## Assumptions

- Decision-document v2 §12's `components[].paths`/`shared_paths` example
  shape is stable enough to build fixtures against now, ahead of Epic A1
  landing its own schema file (Dependencies, OQ-002).
- `git merge-base`, `git diff -M --name-status`, and
  `git status --porcelain=v1 -z --untracked-files=all` are available on
  every CI runner this repository already uses for its 3-OS matrix
  (INV-010's existing `tests/crlf-parity.tests.sh`-style precedent for
  path/line-ending-sensitive suites running on all three OSes).
- Epic A1's canonicalizer will expose a stable CLI/library entry point
  this feature's `resolve-component-paths.py` can call — the exact
  invocation shape is deferred to Epic A1 landing (Dependencies).
- Epic A4's Facet Manifest will expose `affected_components` as a
  JSON/YAML-readable list keyed by component id, consistent with every
  other Facet Manifest field decision-document v2 §16 already shows
  (`context_binding`, etc.) — the exact read path is deferred to Epic A4
  landing (Dependencies).

## Open Questions

- OQ-001 (investigation.md): Fail-6's exact "which sub-path counts as
  touching the Provider Adapter" rule is deferred until Epic A1 ships
  `sdd/provider-bindings.yaml`'s real file-level structure; this feature
  only fixes the join key (`provider_binding_ids`) and the file-presence
  gate (N/A when absent).
- OQ-002 (investigation.md): whether T-001/T-002 (resolver core, git-diff
  integration) should hard-block on Epic A1 merging, versus proceeding
  against self-contained fixtures matching the already-fixed field shape.
  This requirements/design pair adopts the latter (Dependencies), with
  reconciliation as a tracked follow-up if a divergence is later found.

## Risks

- A resolver bug that under-classifies OVERLAP as EXCLUSIVE (or vice
  versa) would defeat the entire purpose of Q11's Reverse Coverage Gate —
  mitigated by treating REQ-001/REQ-002 as `Risk: high` /
  `Required Workflow: tdd` in this feature's future task decomposition
  (Phase 2, deferred per investigation.md INV-012), with the
  exclude-as-include invariant (Fail-5) tested as its own dedicated,
  independent fixture rather than folded into a general "matching works"
  assertion.
- The Epic A4 forward-dependency (Dependencies, INV-003) risks shipping a
  Gate that can never exercise Fail-2/Fail-4 for an extended period if
  Epic A4 is delayed — mitigated by the explicit degraded/resolver-only
  mode (REQ-004) with a mandatory WARN, so the gap is always visible
  rather than silently unverified.
- Registering a new protected-gate-suffix entry (REQ-004) via human-copy
  introduces a window between an agent staging the candidate and a human
  applying it, during which `check-component-coverage.*` is NOT yet
  protected — mitigated by the same window every prior protected-file
  addition in this repository has already accepted (INV-006, INV-007); no
  new risk class is introduced.
