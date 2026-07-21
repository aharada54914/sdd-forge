# Requirements: epic-191-a3-path-ownership

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/191,
https://github.com/aharada54914/sdd-forge/issues/187
Epic: https://github.com/aharada54914/sdd-forge/issues/187 (AI-DLC
Foundation tracking) — Epic A3 (Component Path Ownership), issue #191, per
`docs/ai-dlc-foundation-decision-v2.md` §19
Investigation: specs/epic-191-a3-path-ownership/investigation.md
(INV-001..INV-017, OQ-001..OQ-002)

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
its git-diff input basis (REQ-003), the Gate that consumes it (REQ-004),
the `ownership_digest` it emits (REQ-005), the operational rule that keeps
everyday cross-cutting paths (specs, reports, ADRs, CI config) from
tripping the Gate (REQ-006), the monorepo fixture + test suite that locks
all of the above (REQ-007), the documentation/versioning discipline every
task shares (REQ-008), and a dual-runtime (`sh`/`ps1`) parity contract
(REQ-009) so the two wrapper runtimes are proven behaviorally identical,
not merely both-present.

This feature does **not** define `project-context.yaml`'s schema (Epic
A1's deliverable) and does **not** define the Facet Manifest schema (Epic
A4's deliverable) — see Dependencies for exactly which parts of those
schemas this feature now treats as a hard (not follow-up) dependency.

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
- Windows-hosted contributors and CI runners, for whom path-separator,
  encoding, and case-sensitivity semantics must be identical to
  Linux/macOS runners (decision-document v2 §7 "各Epicの3環境対応",
  applied here as "path and case semantics must not depend on host OS"),
  and for whom the `sh`/`ps1` wrapper twins must be *provably*, not merely
  nominally, behaviorally identical (REQ-009).
- A maintainer operating this repository's own capability pipeline (ADR-
  0016), who needs `check-component-coverage`'s applicability to follow the
  same explicit `workflow.capability_enforcement`/`disabled-legacy` axis
  every other capability-driven component already follows, not an
  incidental Facet Manifest file's presence.

## Problems

- `affected_components` is currently self-reported by whichever process
  resolves a Feature's Facet Manifest, with no independent check against
  the actual `git diff` (INV-001: no resolver or Gate exists today) — a
  Feature can silently omit a component it actually touched.
- No documented algorithm exists for how `paths.include`/`paths.exclude`
  glob patterns are matched, what `**` versus `*` mean, how
  cross-platform path separators, Unicode normalization, and case
  sensitivity are handled, or how a path that is excluded from one
  component's ownership must never be silently misattributed to it
  (decision-document v2 §12 names the Fail conditions but does not define
  the matching algorithm itself).
- No git-diff basis is defined: earlier planning (v1, per
  `docs/ai-dlc-foundation-decision-v2.md` §12's "v1 では diff の入力が
  未定義だった") left baseline resolution, byte-level path framing,
  rename-following thresholds, submodule/symlink handling, and
  cross-command snapshot consistency all unspecified — each of which is a
  distinct way a legal repository state can defeat ownership
  classification if left to an implementation's discretion rather than a
  normative contract.
- An earlier draft of this feature used the mere *presence* of a Facet
  Manifest file as `check-component-coverage`'s mode selector — the exact
  anti-pattern `docs/adr/0016-workflow-axes-separation.md` forbids
  (incidental file existence as an implicit mode variable) — and let
  Fail-2/Fail-4 be bypassed by an agent simply omitting the manifest
  input, with only a WARN recorded. The Gate's applicability must instead
  be derived from the same explicit `workflow.capability_enforcement`/
  `disabled-legacy` axis every other capability-driven component in this
  repository already reads (INV-016).
- Registering the new Gate script as a protected, R-10 enforcement-chain
  file (the natural precedent set by `check-contract.*`/
  `check-evidence-bundle.*`, INV-006) requires editing
  `plugins/sdd-quality-loop/references/guard-invariants.json`, which is
  itself already protected (INV-006), **and** editing
  `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`'s own
  fixed `PHASE2_TARGETS` inventory tuple, without which the generator's
  own exact-match validation rejects the edited JSON before it ever
  reaches a staleness check (INV-015) — an agent cannot make either change
  directly.
- Suffix-protecting the Gate's own script content (`PROTECTED_GATE_SUFFIXES`)
  does not, by itself, stop an agent from deleting or renaming the
  unprotected `quality-gate/SKILL.md` bullet that invokes it, or
  substituting an unregistered replacement script — suffix protection
  alone leaves the Gate's *reachability* unprotected even once its *content*
  is protected (INV-017).

## Dependencies

- **Epic A1 (Project Context) — schema shape (hard dependency)**: Epic A1
  owns the `project-context.yaml` schema, including the exact field types
  for `components[].paths.include`, `components[].paths.exclude`, and
  `shared_paths[]` (decision-document v2 §12's example). This feature does
  not redefine that schema, but — unlike an earlier draft that treated
  divergence-reconciliation as a purely tracked follow-up — T-001's own
  Done state is now gated on a schema-conformance fixture (AC-011) that
  validates this feature's parser against Epic A1's *landed* schema's
  actual field names/types/version once that schema exists in the
  repository; a documented blocker, not a silent pass, if it diverges from
  decision-document v2 §12's shape before then. The matching *algorithm*
  itself (glob semantics, NFC/case rules) remains this feature's own
  design authority and ADR-0025 candidate — only the schema *shape*
  conformance is elevated here.
- **Epic A1's canonicalizer** (YAML 1.2 + JCS, Python single implementation
  + thin wrappers, decision-document v2 §18.3/§21 Epic A1) is a hard
  dependency for REQ-005 (`ownership_digest` emission) — there is no
  shape-only substitute for calling a canonicalization utility that does
  not yet exist (INV-002). REQ-005's task is blocked on Epic A1 shipping
  this utility.
- **Epic A1's Provider Bindings schema addition — `adapter_paths`**: Fail-6
  (REQ-004) requires Epic A1 to add an optional `adapter_paths: string[]`
  (glob array) field per binding entry to `sdd/provider-bindings.yaml`'s
  schema (OQ-001, resolved; investigation.md OQ-001). This feature
  consumes that field (matched via REQ-001's own glob engine against the
  binding's declared `provider_binding_ids` join key already fixed by
  decision-document v2 §5/§12) — it does not otherwise define or
  redefine the Provider Bindings file schema (Non-goals).
- **Epic A4 (Facet Manifest)** owns the schema for
  `facet-manifest.affected_components`, the field Fail-2 and Fail-4 (REQ-004)
  compare the resolver's output against. This is a genuine forward
  dependency created by the decision document's own epic ordering
  (§19: A1 → A2 → A3 → A4 → A5; INV-003). REQ-004 resolves this not with a
  file-presence-driven degraded mode (rejected, see Problems and REQ-004),
  but by deriving the Gate's *invocation* itself from the
  `workflow.capability_enforcement`/`disabled-legacy` axis (ADR-0016,
  INV-016): the Gate is not invoked at all while the capability pipeline is
  `disabled-legacy`, and by the epic sequencing above, a project only sets
  `capability_enforcement` active once the pipeline it depends on
  (including Facet Manifest generation, Epic A4/A5) is operational — so
  the practical window in which the Gate is "active but manifest-less" is
  a misconfiguration to fail closed on, not a steady-state mode to design
  a silent WARN-and-continue path for.
- **Epic A2 (Capability Registry)** is not a dependency of this feature.
  `check-component-coverage` is an Implementation Gate check wired directly
  into `quality-gate`'s existing `## Process` section (INV-005), not a
  Registry-declared gate; Registry-driven gate projection is out of scope
  (Non-goals).
- **`check-contract`'s protected required-check-set (new touch point,
  REQ-004)**: registering `check-component-coverage` as reachable-by-
  construction (not merely content-protected) requires editing
  `plugins/sdd-quality-loop/references/risk-gate-matrix.md` (unprotected,
  direct edit) and `check-contract.{sh,ps1,py}`'s own hardcoded
  tier-minimum set (protected, `guard-invariants.json:14-16`) — a fourth
  protected-file family this feature touches, in addition to
  `guard-invariants.json`+siblings and `.github/workflows/test.yml`
  (INV-017).

## Goals

- REQ-001 (component path resolver — glob semantics, normalization, and
  schema conformance; INV-002, OQ-002): Implement a deterministic script
  (`resolve-component-paths.py` master + `.sh`/`.ps1` wrappers, INV-008)
  that, given a `components[].paths`/`shared_paths` structure matching
  decision-document v2 §12's shape and a list of changed paths, classifies
  every path.

  - Matching rules (this feature's own design decision, not redefined
    elsewhere): `**` matches zero or more whole path segments, including
    across `/` boundaries and including the **zero-segment** case (a
    pattern like `a/**/b` matches literal `a/b`); a bare `*` matches
    within a single path segment and never crosses `/`; `?` and `[...]`
    (and every other glob metacharacter, and regex, and dynamic code) are
    explicitly **unsupported** — a pattern string containing either is
    rejected as a fail-closed configuration error at load time, mirroring
    the restricted-DSL philosophy decision-document v2 §11 (Q10) already
    established for a different fragment (predicate conditions).
  - All comparison inputs (pattern strings from config, path strings from
    `git diff` output) are normalized to Unicode NFC before *matching
    only* — the resolver separately preserves each path's original,
    exact-bytes raw form (as `git` reported it) for identity and output
    purposes (AC-010); any backslash in a pattern string is normalized to
    forward slash before compilation (patterns may be authored on any OS;
    path strings from `git`'s own plumbing commands are always
    forward-slash-separated regardless of host OS, so no separate
    diff-side separator normalization is required — this feature's scripts
    assert this as a fixture-tested invariant rather than merely
    documenting it, per INV-010's existing CRLF-parity-test precedent).
  - Matching is always case-sensitive, byte-wise, independent of the host
    filesystem's own case sensitivity, because the resolver only ever
    compares strings returned by `git` plumbing commands — it never lists
    a filesystem directory itself.
  - Every clause this matching contract makes a judgment call about — the
    `**`/`*` distinction, the zero-segment case, unsupported metacharacters,
    an empty changed-paths diff, an empty `include` list, and a
    `shared_paths` entry matching zero changed paths — has its own unique
    clause identifier and is independently, not merely representatively,
    tested (AC-001..AC-009).
  - The resolver's config parser is conformance-tested against Epic A1's
    landed canonical schema once it exists (Dependencies) — a hard, not
    follow-up, dependency for this REQ's own Done state (AC-011).

- REQ-002 (exclusive/shared classification, overlap detection, unowned
  detection, and excluded-match evidence; §12): For each changed path, the
  resolver first checks every `shared_paths` entry; a match there exempts
  the path from component-exclusivity classification entirely (Design
  Decisions). A `shared_paths` entry is one of two mutually exclusive
  shapes: a bounded form (`components: [...]`, an explicit list) or an
  unbounded form (`classification: cross-cutting`, no components list,
  any/no component may touch it) — a config carrying both or neither on
  the same entry is a fail-closed configuration error, distinct from the
  six Gate Fail conditions. For a path not matched by any `shared_paths`
  entry, the resolver computes, per component, `(include patterns
  matched) MINUS (exclude patterns matched)`; exactly one component's
  residual match → **EXCLUSIVE**, owned by that component; zero
  components' residual match → **UNOWNED** (Fail-1); two or more
  components' residual match → **OVERLAP** (Fail-3). The `exclude`
  subtraction is evaluated strictly within the same component (a path
  inside component C's own `exclude` is never attributed to C, even if it
  is also nested inside one of C's `include` patterns) — this is the
  Fail-5 invariant ("exclude pathの include扱い"), asserted directly as a
  resolver correctness property. Where this invariant is the *reason* a
  path is UNOWNED (every component whose `include` would otherwise have
  matched excluded it), the resolver's per-path output record carries an
  explicit `EXCLUDED_MATCH` evidence tag (the excluding component id(s) +
  matched exclude pattern(s)), distinguishable from an ordinary UNOWNED
  record where no `include` pattern ever matched at all — this is the
  concrete, reachable trigger Fail-5 uses at the Gate level (REQ-004),
  not merely an inference from set arithmetic (AC-013, AC-014).

- REQ-003 (git diff basis; §12 "v2 新設"): Wrap the resolver with a
  deterministic git-diff collector, normatively fixed on every axis a
  legal repository state could otherwise vary:

  - **Baseline contract**: source = `HEAD` by default, or an explicit
    `--source-rev` when supplied; target = a complete ref or OID supplied
    as `--target-rev` (no partial/ambiguous shorthand). Both are resolved
    to a commit OID via `git rev-parse --verify <rev>^{commit}` *before*
    computing `git merge-base`, so detached-HEAD and unresolvable-rev
    cases fail closed with a diagnostic at OID-resolution time rather than
    reaching an ambiguous merge-base call; an unrelated-histories
    merge-base failure is likewise a fail-closed diagnostic, never a
    silently empty change set.
  - **Change set**: `baseline..worktree` (working tree, not merely `HEAD`)
    **plus** untracked files, collected via
    `git status --porcelain=v1 -z --untracked-files=all` or
    `git ls-files --others --exclude-standard -z` — staged, unstaged, and
    untracked changes are each counted exactly once.
  - **NUL-safe path framing**: every git plumbing invocation that
    enumerates paths (`git diff --name-status`, `git status --porcelain`,
    `git ls-files --others`) is invoked with its NUL-delimited output mode
    (`-z`) and parsed as raw bytes on that protocol, never newline-split
    text parsing — a path containing a literal TAB or LF round-trips
    correctly, and a path containing invalid-UTF-8 bytes fails closed with
    a diagnostic rather than being silently truncated, misparsed, or
    dropped (this closes the framing gap a plain `--name-status` /
    line-oriented parse would leave open for a legal, if unusual, filename).
  - **Rename contract**: renames are followed with a pinned similarity
    threshold and a pinned `diff.renameLimit`, with `--no-ext-diff` set so
    no external diff driver can alter detection; both the pre-rename and
    post-rename path are independently classified, and a rename that
    crosses component boundaries (old path EXCLUSIVE to component A, new
    path EXCLUSIVE to component B) is surfaced as its own distinct case,
    not silently collapsed into "component A changed a file." A rename
    whose limit is exceeded is a fail-closed diagnostic, never a silent
    fallback to an unrelated `D`+`A` pair with no indication that the
    fallback occurred.
  - **Submodule/symlink reference-only boundary**: submodule (gitlink) and
    symlink entries are evaluated only for the reference/pointer change
    itself (the gitlink OID, or the symlink's target text) — the resolver
    never follows a symlink or descends into a submodule's own working
    tree, and a dirty-but-pointer-unchanged submodule (working tree
    modified, gitlink OID unchanged) is not reported as a change at all
    (`--ignore-submodules=dirty`-equivalent semantics), distinguished from
    a gitlink-OID change (reported, evaluated only as a pointer bump) and
    from a symlink target-text change (reported) versus a referent-only
    content change (not reported, since the resolver never dereferences
    the link).
  - **Single-writer / snapshot contract**: the collector assumes a single
    writer to the working tree/index across its own multi-command
    sequence; it captures the HEAD OID and an index/worktree fingerprint
    at the start and re-checks them at the end, retrying once on a
    mismatch and then failing closed with a diagnostic — never silently
    returning a mixed-snapshot result assembled from commands that ran
    against different underlying states.

- REQ-004 (Reverse Coverage Gate `check-component-coverage`, stage:
  implementation; §12, ADR-0017, ADR-0016): A new Implementation Gate
  check, documented in
  `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`'s existing
  `## Process` section (INV-005 — a direct, unprotected edit) **and**
  registered into `check-contract`'s protected required-check-set
  (INV-017 — see below), because SKILL.md text alone is not a sufficient
  reachability guarantee.

  - **Applicability is derived, never file-presence-selected** (rejects
    the earlier degraded-mode design, Problems; INV-016): the script reads
    `workflow.capability_enforcement` (and the ADR-0016 file-absence
    fallback) directly from the same `--config` `project-context.yaml`
    input REQ-001 already requires — it does not accept a separate
    "mode" flag, and it never infers applicability from whether a Facet
    Manifest file happens to exist.
    - **Capability-disabled (`disabled-legacy`)**: `check-component-coverage`
      is **not invoked at all** — it exits 0 immediately with a
      single-line, logged (not silent) skip diagnostic, and
      `quality-gate`'s `## Process` step treats that skip as an expected
      no-op, never a WARN needing suppression. This mirrors ADR-0016 §4's
      requirement that the entire capability evaluation pipeline sits
      outside its own domain in this state.
    - **Capability-active** (`capability_enforcement` is `advisory` or
      `required`): the Gate **is** invoked, and by construction requires a
      Facet Manifest — `--facet-manifest <path>` is a structurally
      required flag in this state (its own argument-parsing enforces
      presence; an agent cannot silently omit it and receive a degrade).
      If the supplied manifest path is missing or unreadable, this is a
      **hard error** (a distinct, non-zero exit code from an ordinary
      Fail-condition trigger) — never a WARN + exit 0. When the manifest
      is present and readable, the Gate judges all six Fail conditions
      from decision-document v2 §12.
  - **Fail-1** (changed path belongs to no component and no `shared_paths`
    entry — UNOWNED).
  - **Fail-2** (an EXCLUSIVE owner of a changed path is missing from
    `facet-manifest.affected_components`) — scoped **only** to
    exclusive-owner mismatches; it does not also cover bounded
    `shared_paths` shortfalls (that is Fail-4's sole responsibility,
    resolving the earlier duplication between the two, Problems). Because
    REQ-002's `shared_paths`-precedence check makes EXCLUSIVE and
    bounded-SHARED mutually exclusive classifications for any single path,
    Fail-2 and Fail-4 never both fire for the same path by construction.
  - **Fail-3** (OVERLAP — an exclusive path resolves to two or more
    components).
  - **Fail-4** (a changed path matches a bounded `shared_paths` entry, but
    `facet-manifest.affected_components` is missing one or more of that
    entry's declared `components`) — the sole condition for bounded-shared
    component-set shortfalls.
  - **Fail-5** (the exclude-as-include misuse invariant from REQ-002):
    triggered at the Gate level by the resolver's `EXCLUDED_MATCH`
    evidence (REQ-002) reaching the Gate against real Facet Manifest data
    — a reachable, ordinary runtime path through `check-component-coverage`
    itself, not only a resolver-level mutation/invariant test.
  - **Fail-6** (Provider Adapter / Provider Binding drift): evaluated only
    when `sdd/provider-bindings.yaml` exists. A binding that declares the
    Dependencies-scoped `adapter_paths` field and whose glob (REQ-001
    semantics) matches an EXCLUSIVE-owned changed path without the
    corresponding binding facet/binding revision also present in the same
    diff triggers Fail-6. A binding that exists but does not declare
    `adapter_paths` records Fail-6 as WARN "evaluation not possible"
    (evidence-logged) rather than silently passing. When
    `sdd/provider-bindings.yaml` itself is absent, Fail-6 is recorded N/A
    with a WARN.
  - **Resolver-only diagnostics are not a Gate mode.** The subset of
    checks that need only the resolver's own output (Fail-1/3/5/6-
    conditional) is retained, but repackaged as an independent, non-Gate
    diagnostic command (`resolve-component-paths --diagnose`, or an
    equivalently named standalone entry point decided at task
    decomposition) that a maintainer or CI job may run for early feedback
    at any time, regardless of capability state, whose exit code never
    affects the Implementation Gate and which `quality-gate`'s
    `## Process` never invokes.
  - **Protected required-check-set registration (reachability, INV-017)**:
    `check-component-coverage` is registered as a required contract-check
    id for `high`/`critical` tier tasks in
    `plugins/sdd-quality-loop/references/risk-gate-matrix.md` (unprotected,
    direct edit) *and* in `check-contract`'s own protected, hardcoded
    tier-minimum set (`check-contract.{sh,ps1,py}`, staged via human-copy
    since `check-contract.*` is already R-10 protected,
    `guard-invariants.json:14-16`) — so that deleting or renaming the
    `quality-gate/SKILL.md` invocation, or substituting an unregistered
    replacement script, still fails a `high`/`critical` task's Gate,
    because `check-contract`'s required-check-set enforcement is
    independent of SKILL.md's own (unprotected) text.
  - **Protected-suffix registration (content protection, INV-006, INV-015)**:
    `check-component-coverage.{sh,ps1,py}` is added to
    `PROTECTED_GATE_SUFFIXES`, which requires editing
    `plugins/sdd-quality-loop/references/guard-invariants.json` (itself
    protected) **and** `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`'s
    own fixed `PHASE2_TARGETS` inventory tuple (gains the identical three
    entries — without this, the generator's own exact-match validation
    rejects the edited JSON, INV-015) **and** regenerating
    `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` plus
    its three generated siblings — six files total, staged under
    `specs/epic-191-a3-path-ownership/human-copy/` with a `MANIFEST.sha256`
    entry per staged file, never written directly, per the established
    human-copy procedure (INV-007, INV-015, ADR-0011). Running
    `generate-guard-invariants.py --check` against a copy of the current
    tree with the six staged candidates overlaid must exit 0 (no exact-
    match validation error, no staleness) before the registering task can
    be marked Done.

- REQ-005 (`ownership_digest` emission — full consumed-input binding; §16
  Q15, ADR-0021): The resolver emits `ownership_digest` — a digest of
  **every** component's `paths` entries and **every** `shared_paths` entry
  actually *evaluated* while resolving a given Feature's affected
  components, **including entries that were evaluated but did not
  match** (non-owner components, non-matching `shared_paths` entries),
  plus the matcher semantics/rule-set version (ADR-0025 candidate)
  identifier used for that evaluation — not merely the entries that
  matched. This closes the selective-stale blind spot where a previously
  non-matching pattern's edit (e.g. a component's `include` list widening
  to now cover a path it previously didn't) would otherwise leave a stale
  Feature's digest unchanged because the *matched* set alone was bound.
  Canonicalized via Epic A1's YAML-1.2-plus-JCS canonicalizer
  (decision-document v2 §18.3; not reimplemented here, per the task's
  scope-boundary instruction). `ownership_digest` populates the
  `context_binding` block exactly as ADR-0021
  (`docs/adr/0021-context-projection-staleness.md` lines 34-46) specifies,
  alongside `resolver.version`/`resolver.rule_set_revision`; it is
  binding/provenance metadata, excluded from ADR-0021's "semantic output"
  comparison (lines 55-68) — a digest-only update, with no change to which
  components are reported affected, never by itself marks a Feature stale.
  A regression/positive-and-negative test matrix (owner added, owner
  removed, non-match→match transition, a bounded-shared-entry change, a
  consumed-input change, and a non-consumed-input change — i.e. an edit to
  a component/shared entry never evaluated for this Feature's diff) proves
  both the digest's own change/no-change behavior *and* ADR-0021's wider
  semantic-output comparison and `context_binding`/`resolver` metadata
  update behavior, not the digest value in isolation.

- REQ-006 (cross-cutting path pre-registration rule; §12 "v2 新設"): A
  reference document (`plugins/sdd-quality-loop/references/default-shared-paths.md`
  or `.json`, design.md decides the exact format) enumerates the default
  cross-cutting `shared_paths` seed list — at minimum `specs/**`,
  `reports/**`, `docs/adr/**`, `CHANGELOG.md`, `.github/**`, and
  `tests/fixtures/**` — that Epic A1's bootstrap flow is expected to seed
  into a newly-created `project-context.yaml`, so that ordinary changes to
  these paths never trip Fail-1 on day one of Project Context adoption.
  `contracts/**` is deliberately **not** on this list (Design Decisions) —
  decision-document v2 §12 itself shows `contracts/**` as a **bounded**
  shared example (`components: [desktop-client, sync-api]`), distinct from
  `docs/**`'s unbounded cross-cutting example; treating it as unbounded
  cross-cutting would silently drop the very component-enumeration Fail-4
  is meant to enforce for it. This feature's fixture/integration test
  (REQ-007) proves the seed list, once applied to a Project Context, is
  actually effective — this feature is no longer limited to documenting
  the list without proving it works (see Non-goals for the narrower scope
  that remains genuinely out of bounds).

- REQ-007 (monorepo fixture + `.sh`/`.ps1` test pairs; §19 Epic A3): A
  fixture monorepo under `tests/fixtures/component-path-ownership/`
  (INV-009) with at least two components with candidate-overlapping owned
  paths, a nested excluded subtree under one component, a bounded
  `shared_paths` entry shaped after decision-document v2 §12's own
  `contracts/**` example (with a dedicated fixture proving an
  out-of-enumeration component touching it triggers Fail-4, not a silent
  pass), the four submodule/symlink fixtures (dirty-only, gitlink-OID
  change, symlink target-text change, referent-only change), an
  NFC-collision fixture (two distinct raw paths normalizing to the same
  comparison key), and one fixture per REQ-001 glob clause id, is created
  and exercised by new `.sh`/`.ps1` test suite twins covering each of the
  six named cases this task's owner (the orchestrating instruction)
  specifies: overlap, unowned, rename, untracked, exclude misuse, and
  shared-undeclared — registered in `tests/run-all.sh`/`.ps1` (direct
  edit) and staged into `.github/workflows/test.yml` via human-copy
  (INV-010, protected file). The `ownership-digest` suite (REQ-005) is
  registered in the same inventory, run-all array, and CI staging as the
  other three suites — not left out of design.md's own component/suite
  inventory (a self-test confirms all four suites appear in every
  registration surface).

- REQ-008 (documentation and versioning discipline; shared across every
  task, same "ドキュメント追従・バージョン改訂" convention as
  `specs/epic-159-pillar-c/requirements.md` REQ-009): every task adds its
  own `CHANGELOG.md` `## Unreleased` entry citing issue #191; the new ADR
  (provisionally `docs/adr/0025-component-path-ownership-resolver-semantics.md`,
  re-verified at drafting time per INV-014) records the glob-matching
  semantics, precedence rules, and six Fail-condition definitions this
  requirements/design pair establishes; version bumps happen exclusively
  via `scripts/bump-version.sh`, never a hand-edited version string. The
  number of new `PROTECTED_GATE_SUFFIXES` entries this feature adds is
  derived from a single source (the three coverage-gate script suffixes,
  REQ-004) everywhere it is cited in this spec package — no independent
  "four" figure may appear anywhere (design.md's own prior "four new
  entries" text is corrected as part of this REQ's documentation
  discipline).

- REQ-009 (dual-runtime parity contract, new): An independent parity
  harness feeds the *identical* fixture and argv to every `.sh` suite and
  its `.ps1` twin (across all four suites: resolver, diff-basis, coverage,
  ownership-digest) and asserts byte-for-byte identical normalized stdout
  JSON, identical exit code, identical WARN/error category strings, and
  identical argument pass-through behavior (including an unrecognized or
  extra argument) — a fixture where only the `.ps1` twin drops an
  untracked argument, or mishandles `$LASTEXITCODE`, must fail this
  harness even when each suite independently passes its own same-language
  assertions (the failure mode this feature's earlier "both files exist"
  proof could not catch). The parity harness is itself registered in
  `tests/run-all.sh`/`.ps1` and staged into `.github/workflows/test.yml`
  via human-copy, alongside the four suite pairs.

## Non-goals

- Defining or modifying `project-context.yaml`'s schema, including the
  exact JSON-Schema type for `components[].paths`/`shared_paths` — that is
  Epic A1's deliverable (Dependencies); this feature only conformance-
  tests against it once landed.
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
- Defining Provider Bindings' file schema (`sdd/provider-bindings.yaml`)
  — Fail-6 only consumes the component-level `provider_binding_ids` field
  decision-document v2 §5/§12 already fixed and the new `adapter_paths`
  field (Dependencies) Epic A1 is expected to add; this feature does not
  define the file's schema, and Fail-6 is N/A with a WARN when the file is
  absent.
- Implementing Epic A1's production `sdd-bootstrap-interviewer` flow
  itself — REQ-006 delivers the reference document that flow is expected
  to consume, and REQ-007's fixture/integration test proves the seed list
  is effective once applied; authoring the actual interviewer question
  flow that seeds a brand-new `project-context.yaml` remains Epic A1's
  (narrower than an earlier draft's blanket "no bootstrap proof at all"
  non-goal — see REQ-006).
- Any change to `sdd-hook-guard.*`'s own enforcement logic — this feature
  only adds new entries to protected *data*/*policy* files
  (`guard-invariants.json`, `generate-guard-invariants.py`'s inventory
  tuple, `check-contract`'s tier-minimum set, `risk-gate-matrix.md`) the
  existing guard/gate scripts already read.

## User Stories

- As a quality-gate evaluator, I need `check-component-coverage` to fail
  closed when a Feature's declared `affected_components` omits a component
  its diff actually touched, so that per-component review coverage is
  never silently skipped (REQ-004).
- As a maintainer authoring `project-context.yaml`'s `paths`/`shared_paths`
  fields on Windows, I need glob matching to behave identically to a
  Linux/macOS teammate's, so a change that passes locally does not
  unexpectedly fail (or pass) in CI on a different OS (REQ-001), and I
  need the `sh`/`ps1` wrappers I invoke to be *provably* identical, not
  merely both present (REQ-009).
- As a maintainer renaming a file across component boundaries, I need the
  resolver to tell me both the old and new owner, not silently attribute
  the whole rename to one side, so I can correct `affected_components`
  before the Gate runs (REQ-003).
- As an Epic A1 bootstrap-flow implementer, I need a documented, and
  fixture-proven, default cross-cutting `shared_paths` seed list so a
  brand-new Project Context does not immediately fail every Feature's Gate
  on routine `specs/**` changes (REQ-006).
- As a maintainer relying on ADR-0021's staleness mechanism, I need
  `ownership_digest` to change if and only if the ownership fragment my
  Feature actually consumed (matched or not) changes, so an unrelated
  path-ownership edit elsewhere in the monorepo does not spuriously stale
  my in-progress Feature, and so a *previously non-matching* pattern
  becoming a match is never missed (REQ-005).
- As a maintainer whose project has not yet adopted the capability
  pipeline, I need `check-component-coverage` to simply not run — never a
  confusing WARN — so ADR-0016's `disabled-legacy` guarantee holds for
  this Gate the same way it holds for every other capability-driven
  component (REQ-004).

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
  path and an NFC-encoded pattern match) — matching only; see AC-010 for
  raw-identity preservation.
- AC-005 (REQ-001): matching is byte-wise case-sensitive regardless of
  host OS (a fixture path differing only in case from a pattern does not
  match, on every OS this suite runs on).
- AC-006 (REQ-001, glob clause: unsupported metacharacters): a pattern
  string containing `?` or `[...]` (or any other unsupported glob
  metacharacter) is rejected as a fail-closed configuration error at load
  time.
- AC-007 (REQ-001, glob clause: `**` zero-segment): a pattern such as
  `a/**/b` matches the literal path `a/b` (zero intervening segments), not
  only paths with one or more segments between `a` and `b`.
- AC-008 (REQ-001, glob clauses: empty sets): an empty changed-paths diff
  set resolves vacuously (no classification work, no error); a
  component with an empty `include` list is flagged as a config-load-time
  error, never conflated with a runtime UNOWNED result.
- AC-009 (REQ-001, glob clause: shared zero-match): a `shared_paths` entry
  whose pattern matches zero changed paths in a given resolve is not
  evaluated at all for that resolve (in particular, it never triggers a
  Fail-4 check).
- AC-010 (REQ-001, NFC collision + raw identity): two distinct raw git
  paths that differ only in Unicode normalization form (one NFD-encoded,
  one NFC-encoded) and therefore normalize to the identical comparison key
  is a fail-closed collision error — the resolver never silently merges,
  drops, or arbitrarily picks one; every output record preserves the
  path's original raw bytes (not the normalized comparison key) for
  identity purposes, and output ordering is a stable sort over raw path
  bytes, deterministic even when a collision is present.
- AC-011 (REQ-001, schema conformance, hard dependency): once Epic A1's
  canonical `project-context.yaml` schema lands in the repository, a
  dedicated schema-conformance fixture validates this feature's parser
  against that schema's actual field names/types/version for
  `components[].paths.include/exclude` and `shared_paths[]`; a divergence
  from decision-document v2 §12's shape this feature currently builds
  against is a documented blocker for T-001's Done state, not a silently
  accepted or indefinitely deferred follow-up.
- AC-012 (REQ-002): a path matching exactly one component's `(include −
  exclude)` set, and no `shared_paths` entry, classifies EXCLUSIVE to that
  component.
- AC-013 (REQ-002): a path nested inside component C's own `exclude`
  pattern, while also matching one of C's `include` patterns, is NEVER
  classified as owned by C (Fail-5 invariant, asserted at the resolver
  level independent of any Gate).
- AC-014 (REQ-002, `EXCLUDED_MATCH` evidence): where AC-013's invariant is
  the reason a path is UNOWNED (every component whose `include` would
  otherwise have matched it excluded it), the resolver's per-path record
  carries an explicit `EXCLUDED_MATCH` evidence tag (excluding
  component id(s) + matched exclude pattern(s)), distinguishable in the
  output from an ordinary UNOWNED record where no `include` pattern ever
  matched.
- AC-015 (REQ-002): a path matching zero components' `(include − exclude)`
  sets, and no `shared_paths` entry, classifies UNOWNED (Fail-1).
- AC-016 (REQ-002): a path matching two or more components' `(include −
  exclude)` sets, and no `shared_paths` entry, classifies OVERLAP
  (Fail-3).
- AC-017 (REQ-002): a path matched by any `shared_paths` entry is exempt
  from OVERLAP/UNOWNED classification regardless of how many (including
  zero) components' `include` patterns it also happens to match.
- AC-018 (REQ-002): a `shared_paths` entry carrying both `components` and
  `classification: cross-cutting`, or neither, is rejected as a
  fail-closed configuration error at load time, distinct from the six
  Gate Fail conditions.
- AC-019 (REQ-003, baseline contract): source defaults to `HEAD` or an
  explicit `--source-rev`; target is a complete ref/OID supplied via
  `--target-rev`; both are resolved to a commit OID via
  `git rev-parse --verify <rev>^{commit}` before `git merge-base` is
  computed; an unresolvable rev, or a fixture repository with unrelated
  histories, produces a fail-closed diagnostic, never a silently empty
  change set.
- AC-020 (REQ-003): the change set includes staged, unstaged, AND
  untracked files with no path counted twice, collected via git porcelain
  commands (never a raw filesystem walk).
- AC-021 (REQ-003, NUL-safe framing): every path-enumerating git plumbing
  invocation uses NUL-delimited output (`-z`), parsed as raw bytes; a
  fixture path containing a TAB or a literal LF round-trips correctly, and
  a fixture path containing invalid-UTF-8 bytes fails closed with a
  diagnostic rather than being truncated, misparsed, or silently dropped.
- AC-022 (REQ-003): a rename is followed — both the old and new path are
  independently classified; a cross-component rename (old path EXCLUSIVE
  to A, new path EXCLUSIVE to B) is reported as a distinct case, not
  merged into a single-component result.
- AC-023 (REQ-003, rename contract): rename detection uses a pinned
  similarity threshold and a pinned `diff.renameLimit`, with
  `--no-ext-diff` set; the output contract distinguishes a followed rename
  (a single two-path record) from a limit-exceeded fallback (independent
  `D`+`A` records); a fixture exceeding the pinned `renameLimit` produces a
  fail-closed diagnostic, never a silent, unindicated fallback.
- AC-024 (REQ-003, submodule/symlink, 4 fixtures): (a) a dirty-only
  submodule (working tree modified, gitlink OID unchanged) is not reported
  as a change; (b) a gitlink OID change is reported as a change to the
  submodule path itself, never descended into; (c) a symlink target-text
  change is reported as a change to the symlink path, evaluated only for
  the target text; (d) a referent-only content change (the symlink's
  target file changes, the symlink entry itself does not) is not reported
  as a change to the symlink path.
- AC-025 (REQ-003, single-writer/TOCTOU): the collector captures HEAD OID
  and an index/worktree fingerprint at the start and end of its
  multi-command sequence; a fixture that mutates HEAD or the index
  mid-sequence triggers one retry, then a fail-closed diagnostic, never a
  silently mixed-snapshot result.
- AC-026 (REQ-004, applicability derivation): `check-component-coverage`'s
  applicability is derived solely from `workflow.capability_enforcement`/
  `disabled-legacy` (read from the same `--config` input as REQ-001),
  never from Facet Manifest file presence; a fixture where the manifest
  file happens to be present but `capability_enforcement` is
  `disabled-legacy` still results in the Gate not being invoked, proving
  file presence is not consulted as a selector.
- AC-027 (REQ-004, capability-disabled): in the `disabled-legacy` derived
  state, `check-component-coverage` is not invoked at all — no Fail
  conditions are evaluated, no WARN is recorded; the skip is logged, not
  silent, and `quality-gate`'s `## Process` treats it as an expected no-op.
- AC-028 (REQ-004, manifest-required hard error): in the capability-active
  derived state, a missing or unreadable `--facet-manifest` path produces
  a hard error — a distinct, non-zero exit code from an ordinary
  Fail-condition trigger — never a WARN + exit 0 degrade.
- AC-029 (REQ-004, resolver-only diagnostics separated): the Fail-1/3/5/6-
  conditional resolver-only checks exist only as an independent, non-Gate
  diagnostic command; `quality-gate`'s `## Process` never invokes it, and
  its exit code never affects the Implementation Gate.
- AC-030 (REQ-004): each of Fail-1 through Fail-6 has at least one
  dedicated fixture that deterministically triggers it when the Gate is
  invoked with a present, readable Facet Manifest (Fail-6's fixture
  includes a `sdd/provider-bindings.yaml` file with `adapter_paths`
  declared).
- AC-031 (REQ-004, Fail-2/Fail-4 mutual exclusivity): a fixture where a
  bounded `shared_paths` entry's declared `components` list is incomplete
  in the Facet Manifest triggers Fail-4 only (never also counted as
  Fail-2); a separate fixture where an EXCLUSIVE path's owner is missing
  from the manifest triggers Fail-2 only (never Fail-4, since an
  EXCLUSIVE path never also matches a `shared_paths` entry by
  construction, REQ-002).
- AC-032 (REQ-004, Fail-5 Gate-level reachability): a dedicated fixture
  exercises Fail-5 as an ordinary runtime path through
  `check-component-coverage` — driven by the resolver's `EXCLUDED_MATCH`
  evidence (AC-014) against real Facet Manifest data — distinguished from
  a same-fixture UNOWNED trigger, not only a resolver-level
  mutation/invariant test.
- AC-033 (REQ-004, Fail-6 adapter-path rule): a binding declaring
  `adapter_paths` whose glob matches an EXCLUSIVE-owned changed path
  without the corresponding binding facet/revision also present in the
  diff triggers Fail-6; a binding lacking `adapter_paths` records Fail-6
  as WARN "evaluation not possible" (not N/A, not a silent pass).
- AC-034 (REQ-004): with no `sdd/provider-bindings.yaml` present, Fail-6 is
  recorded N/A with a WARN, never silently omitted without a trace.
- AC-035 (REQ-004, reachability registration): `check-component-coverage`
  is registered as a required contract-check id for `high`/`critical` tier
  in `risk-gate-matrix.md` and in `check-contract`'s protected hardcoded
  tier-minimum set; a fixture that deletes or renames the
  `quality-gate/SKILL.md` invocation, or substitutes an unregistered
  replacement script, still fails a `high`/`critical` task's Gate because
  `check-contract`'s required-check-set enforcement has no passing
  evidence entry to satisfy — independent of SKILL.md's own text.
- AC-036 (REQ-004, protected-suffix registration + generator inventory):
  `check-component-coverage.{sh,ps1,py}` appear in `PROTECTED_GATE_SUFFIXES`
  only via the staged `specs/epic-191-a3-path-ownership/human-copy/`
  candidates + `MANIFEST.sha256`, covering all **six** files this
  registration touches — `guard-invariants.json`,
  `generate-guard-invariants.py` (its `PHASE2_TARGETS` tuple gains the
  identical three entries), and the four regenerated
  `generated/guard_invariants.py` + `generated/guard-invariants.generated.{js,ps1,sh}`
  siblings; running `generate-guard-invariants.py --check` against a
  staged copy of the tree (the six candidates overlaid on the current
  repo) exits 0 (no exact-match validation error, no staleness); the live
  files are byte-identical before/after this feature's own commits; a
  human `cp` + SHA-256 verification is required before the registering
  task can be marked Done. The expected count of new
  `protected_gate_suffixes`/`PHASE2_TARGETS` entries is exactly **three**,
  derived from a single source (REQ-004's own suffix list) everywhere it
  is cited.
- AC-037 (REQ-005, digest full-input binding): `ownership_digest` is
  computed over **every** component's `paths` entries and **every**
  `shared_paths` entry actually evaluated for a given resolve — matched or
  not — plus the matcher semantics/rule-set version identifier, via Epic
  A1's canonicalizer; if that canonicalizer does not exist in the
  repository at implementation time, the implementing task records this
  as a documented blocker rather than reimplementing canonicalization.
- AC-038 (REQ-005): `ownership_digest` is present in `context_binding`
  alongside `resolver.version`/`resolver.rule_set_revision`, and is
  excluded from ADR-0021's semantic-output comparison — a fixture where
  only `ownership_digest` changes (no resolved-component-set change) does
  not mark the Feature stale.
- AC-039 (REQ-005, non-match stale regression): a fixture where a
  previously non-matching component `include`/`exclude` entry or
  `shared_paths` entry (evaluated, not matched, for a given diff) changes
  such that it now would match the identical changed-path set changes
  `ownership_digest`, even though the resolver was invoked against the
  same paths — proving the digest is not scoped to matched-only entries.
- AC-040 (REQ-005, selective-stale positive/negative matrix): the full
  matrix — owner added, owner removed, non-match→match transition, a
  bounded-shared-entry change, a consumed-input change (digest changes,
  re-resolve required), and a non-consumed-input change (an edit to an
  entry never evaluated for this Feature's diff — digest unchanged, no
  re-resolve) — is each independently tested, and each case additionally
  verifies ADR-0021's semantic-output comparison (resolved facets, gate
  set, effective minimum enforcement, lite eligibility) and
  `context_binding`/`resolver` metadata update behavior, not merely the
  digest value in isolation.
- AC-041 (REQ-005, suite wiring): `tests/ownership-digest.tests.sh`/`.ps1`
  is registered in `tests/run-all.sh`/`.ps1`, staged into
  `.github/workflows/test.yml` via human-copy, and appears in design.md's
  own Components/suite inventory; a self-test (grep-based) confirms the
  suite is present in all three registration surfaces.
- AC-042 (REQ-006): the reference document lists at least `specs/**`,
  `reports/**`, `docs/adr/**`, `CHANGELOG.md`, `.github/**`, and
  `tests/fixtures/**` as default cross-cutting `shared_paths` seed
  entries; `contracts/**` does **not** appear on this list (Design
  Decisions — it remains a bounded shared example, REQ-006, REQ-007).
- AC-043 (REQ-006): a fixture diff confined to the default cross-cutting
  entries, with zero components declared to own them, never triggers
  Fail-1.
- AC-044 (REQ-006, bootstrap integration proof): a fixture/integration test
  applies REQ-006's default seed list to a fixture `project-context.yaml`
  representing a project adopting Project Context for the first time, and
  proves an ordinary day-one `specs/**`/`reports/**` change against that
  seeded fixture does not trip Fail-1 immediately after the Gate is
  introduced — the seed list's effectiveness is proven, not only
  documented.
- AC-045 (REQ-007, fixture shape): the fixture tree under
  `tests/fixtures/component-path-ownership/` has at least two components
  with overlapping candidate owned paths, a nested excluded subtree, and a
  bounded `shared_paths` entry.
- AC-046 (REQ-007, contracts bounded-shared enforcement): the fixture tree
  includes a `contracts/**`-shaped bounded `shared_paths` entry (an
  explicit `components: [...]` enumeration, mirroring decision-document v2
  §12's own example) and a dedicated fixture where an artifact under
  `contracts/**` is touched by a component *not* in that entry's
  enumerated list — this fixture asserts Fail-4, not a silent pass as
  unbounded cross-cutting.
- AC-047 (REQ-007, suite registration + 6-case + expanded fixtures):
  `.sh`/`.ps1` test-suite twins exist, are registered in
  `tests/run-all.sh`/`.ps1`, and are staged into
  `.github/workflows/test.yml` via human-copy; each of the six named
  cases (overlap, unowned, rename, untracked, exclude misuse,
  shared-undeclared) has at least one passing positive case and one
  red/failing-then-fixed case across the suites; the fixture tree
  additionally carries the four submodule/symlink fixtures (AC-024), the
  NFC-collision fixture (AC-010), and one fixture per REQ-001 glob clause
  id (AC-006..009).
- AC-048 (REQ-008): every task's commit lands its own `CHANGELOG.md`
  `## Unreleased` entry citing #191; the new ADR is authored (re-verified
  number) recording this feature's glob-semantics, precedence, and
  Fail-condition design decisions.
- AC-049 (REQ-008): a grep-based self-check confirms no version string is
  mutated anywhere in this feature's diff outside a `scripts/bump-version.sh`
  invocation.
- AC-050 (REQ-009, dual-runtime parity harness): an independent harness
  feeds the identical fixture and argv to every `.sh`/`.ps1` twin across
  all four suites and asserts byte-identical normalized stdout JSON,
  identical exit code, identical WARN/error category strings, and
  identical argument pass-through; a fixture where the `.ps1` twin alone
  drops an untracked argument, or mishandles `$LASTEXITCODE`, fails this
  harness even though both twins independently pass their own
  same-language suite.
- AC-051 (REQ-009, parity harness registration): the parity harness is
  registered in `tests/run-all.sh`/`.ps1` and staged into
  `.github/workflows/test.yml` via human-copy, alongside the four suite
  pairs.

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
- **EXCLUDED_MATCH**: the resolver-emitted evidence tag for an UNOWNED
  path whose every otherwise-matching component excluded it (the Fail-5
  invariant's concrete, reachable trigger) — distinct from an ordinary
  UNOWNED record with no matching `include` pattern at all.
- **ownership fragment**: the *entire* subset of `components[].paths` and
  `shared_paths` entries a given resolve actually evaluated — matched or
  not — plus the matcher semantics/rule-set version, used to compute
  `ownership_digest` (ADR-0021).
- **capability-disabled (`disabled-legacy`)**: the ADR-0016 derived
  internal state in which `check-component-coverage` is not invoked at
  all.
- **capability-active**: the ADR-0016 derived state
  (`capability_enforcement: advisory | required`) in which
  `check-component-coverage` is invoked and requires a Facet Manifest;
  missing/unreadable manifest in this state is a hard error, not a mode.
- **resolver-only diagnostics**: the independent, non-Gate command
  exposing Fail-1/3/5/6-conditional checks without a Facet Manifest input
  — never invoked by `quality-gate` and never affecting the Implementation
  Gate's exit code.

## Roles and Permissions

- **Implementing agent**: authors `resolve-component-paths.{py,sh,ps1}`,
  `check-component-coverage.{py,sh,ps1}`, the resolver-only diagnostic
  entry point, their test suites and fixtures (including the parity
  harness), the reference documents (REQ-006, the new ADR), directly edits
  `risk-gate-matrix.md` (unprotected), and stages every protected-file
  candidate — `guard-invariants.json`, `generate-guard-invariants.py`, the
  four `generated/*` siblings, `check-contract.{sh,ps1,py}`, and
  `.github/workflows/test.yml` — under
  `specs/epic-191-a3-path-ownership/human-copy/` — never writes a
  protected path directly (Rules, AGENTS.md).
- **Human maintainer**: reviews and applies each staged human-copy
  candidate (`cp` + SHA-256 verification) for
  `plugins/sdd-quality-loop/references/guard-invariants.json`,
  `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`, their
  generated siblings, `check-contract.{sh,ps1,py}`, and
  `.github/workflows/test.yml`'s registration additions; approves tasks
  (Approval: Draft → Approved is a human-only action, never performed in
  this spec-phase package).
- **quality-gate evaluator**: consumes `check-component-coverage`'s
  verdict as part of the Implementation Gate; only `quality-gate` (or
  `lite-gate`) may mark a Task Done (AGENTS.md invariant, unchanged by
  this feature).

## Main Workflows

1. A component/shared-path config (matching decision-document v2 §12's
   shape) and a feature branch are supplied to
   `resolve-component-paths.{sh,ps1}`.
2. The script resolves source/target OIDs (`rev-parse --verify ...^{commit}`),
   computes baseline via `git merge-base`, collects the change set
   (baseline..worktree + untracked, NUL-framed, renames followed under the
   pinned threshold/limit, submodules/symlinks reference-only, a
   single-writer snapshot check), and classifies every path EXCLUSIVE /
   SHARED (bounded or unbounded) / OVERLAP / UNOWNED (with `EXCLUDED_MATCH`
   evidence where applicable).
3. The script emits `ownership_digest` for the *entire* ownership fragment
   it evaluated (matched or not), plus its own computed
   `affected_components` list.
4. `check-component-coverage` (stage: implementation) reads
   `workflow.capability_enforcement`/`disabled-legacy` from the same
   config; in the `disabled-legacy` state it is not invoked at all; in the
   capability-active state it requires a Facet Manifest (missing/unreadable
   is a hard error) and cross-checks the resolver's output against
   `facet-manifest.affected_components` for all six Fail conditions. It is
   both documented in `quality-gate`'s `## Process` (direct edit) and
   registered in `check-contract`'s protected required-check-set, so
   deleting the SKILL.md invocation does not bypass it.
5. Any Fail condition, or a manifest-required hard error, blocks the
   Implementation Gate; a human resolves the underlying config or Facet
   Manifest and re-runs.
6. Epic A1's bootstrap flow is expected to seed the REQ-006 default
   cross-cutting list into a new `project-context.yaml`; this feature's own
   fixture/integration test (REQ-007) proves that seeding is effective
   before steps 1-5 run against a day-one adopter.
7. A maintainer may separately invoke the resolver-only diagnostic command
   at any time, regardless of capability state, for early feedback — its
   result never feeds back into the Implementation Gate.

## Edge Cases

- A `shared_paths` pattern and a component `include` pattern match the
  *identical* literal path string — resolved per AC-017 (shared always
  wins; no OVERLAP/UNOWNED classification is attempted).
- A rename where BOTH old and new paths are EXCLUSIVE to the SAME
  component — not a cross-component case; classified as a normal
  single-component change (no Fail-2/4 special-casing beyond the ordinary
  EXCLUSIVE path).
- A rename where the OLD path was UNOWNED and the NEW path is EXCLUSIVE
  (or vice versa) — both are independently classified; the UNOWNED side
  still triggers Fail-1 in the capability-active state as it would for any
  other UNOWNED path.
- An empty `changed paths` set (no diff at all between baseline and
  worktree, including untracked) — the Gate passes vacuously; this is
  distinct from, and must not be confused with, a fail-closed
  merge-base-unattainable diagnostic (AC-019), which is an error, not an
  empty result.
- A component with an empty `include` list (a config error, not a runtime
  Fail condition) — flagged at config-load time, not conflated with
  UNOWNED path detection.
- A `shared_paths` entry whose pattern matches zero changed paths in a
  given diff — not evaluated at all for that resolve (no Fail-4 check
  fires for an entry the diff never touches).
- A Facet Manifest file happens to exist on disk while
  `capability_enforcement` is `disabled-legacy` — the Gate is still not
  invoked; file presence never overrides the derived state (AC-026).
- A `sdd/provider-bindings.yaml` binding exists for a component but does
  not declare `adapter_paths` — Fail-6 records WARN "evaluation not
  possible" for that binding, distinct from the file-absent N/A case
  (AC-033, AC-034).

## Security Boundaries

- `check-component-coverage.{sh,ps1,py}` becomes a protected,
  R-10-enforced Implementation Gate script (REQ-004) — an agent cannot
  directly weaken or bypass its *content* once the human-copy
  registration in `guard-invariants.json` is applied, the same boundary
  `check-contract.*`/`check-evidence-bundle.*` already enforce (INV-006).
  This alone does not guarantee the Gate is *reached*: REQ-004's
  registration into `check-contract`'s protected required-check-set
  (INV-017) is the boundary that additionally prevents an unprotected
  `quality-gate/SKILL.md` edit from bypassing invocation.
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
- `check-component-coverage`'s applicability derivation (REQ-004) never
  trusts file existence as a security-relevant selector (ADR-0016,
  INV-016) — an agent cannot force a degrade merely by omitting a file,
  because there is no degrade path left to force into.

## Assumptions

- Decision-document v2 §12's `components[].paths`/`shared_paths` example
  shape is stable enough to build fixtures against now, ahead of Epic A1
  landing its own schema file (Dependencies, OQ-002) — subject to the
  schema-conformance fixture (AC-011) once that schema lands.
- `git rev-parse --verify`, `git merge-base`, `git diff -M --name-status -z`,
  and `git status --porcelain=v1 -z --untracked-files=all` are available
  on every CI runner this repository already uses for its 3-OS matrix
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
- A project only sets `capability_enforcement` to `advisory`/`required`
  once the capability pipeline it depends on (including Facet Manifest
  generation, Epic A4/A5) is genuinely operational for that project — the
  epic sequencing (§19) and ADR-0016's own axis-adoption discipline are
  assumed to hold; a project that sets `capability_enforcement` active
  prematurely will see the Gate's hard error (REQ-004) as intended
  fail-closed behavior, not a spec defect.

## Open Questions

- OQ-002 (investigation.md): whether T-001/T-002 (resolver core, git-diff
  integration) should hard-block on Epic A1 merging, versus proceeding
  against self-contained fixtures matching the already-fixed field shape.
  This requirements/design pair adopts a middle path: implementation
  proceeds now against the documented shape (unblocked), but T-001's own
  **Done** state is additionally gated on the schema-conformance fixture
  (AC-011) passing against Epic A1's actual landed schema — not merely a
  tracked follow-up with no enforcement mechanism.

OQ-001 (Fail-6 exact matching rule) is resolved — see Dependencies and
investigation.md OQ-001.

## Risks

- A resolver bug that under-classifies OVERLAP as EXCLUSIVE (or vice
  versa) would defeat the entire purpose of Q11's Reverse Coverage Gate —
  mitigated by treating REQ-001/REQ-002 as `Risk: high` /
  `Required Workflow: tdd` in this feature's future task decomposition
  (Phase 2, deferred per investigation.md INV-012), with the
  exclude-as-include invariant (Fail-5) tested as its own dedicated,
  independent fixture, reachable through the Gate itself (AC-032), not
  folded into a general "matching works" assertion.
- The Epic A4 forward-dependency (Dependencies, INV-003) is no longer
  mitigated by a file-presence-driven degraded mode (rejected, Problems);
  it is instead resolved by gating the Gate's own *invocation* on the
  derived capability-active state (ADR-0016) — the residual risk is a
  project that flips `capability_enforcement` active before Epic A4/A5's
  artifacts genuinely exist, which this design treats as an intentional,
  visible hard error (Assumptions), not a silent gap.
- Registering a new protected-gate-suffix entry, and a new protected
  required-check-set entry (REQ-004), via human-copy introduces a window
  between an agent staging the candidates and a human applying them,
  during which `check-component-coverage.*` is NOT yet protected or
  reachability-registered — mitigated by the same window every prior
  protected-file addition in this repository has already accepted
  (INV-006, INV-007, INV-015, INV-017); no new risk class is introduced.
- Widening `ownership_digest` to bind non-matching entries (REQ-005) means
  more path-ownership edits than before will change the digest and
  trigger a re-resolve for affected Features — mitigated by ADR-0021's own
  selective-stale design (only a Feature whose *semantic output* actually
  changes becomes stale; a digest-only change never does), so this is a
  correctness fix, not a new blast-radius problem.
